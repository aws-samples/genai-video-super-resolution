import torch
import torch.nn as nn
import json
from pathlib import Path
import numpy as np
import cv2
import os

from basicsr.archs.rrdbnet_arch import RRDBNet
from basicsr.utils.download_util import load_file_from_url

from realesrgan.realesrgan import RealESRGANer
from realesrgan.realesrgan.archs.srvgg_arch import SRVGGNetCompact
from gfpgan import GFPGANer

# RealESR-Gan configuration
netscale = 4
outscale = 4
dni_weight = None

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
realesr_gan_model_name = 'RealESRGAN_x4plus.pth'
realesr_gan_face_enhance_model_name = "GFPGANv1.3.pth"
realesr_gan_anime_video_model_name = "realesr-animevideov3.pth"

def model_fn(model_dir):
    # loads SwinIR model
    realesr_gan_model_path = os.path.join(model_dir, realesr_gan_model_name)
    realesr_gan_face_enhanced_model_path = os.path.join(model_dir, realesr_gan_face_enhance_model_name)
    realesr_gan_anime_model_path = os.path.join(model_dir, realesr_gan_anime_video_model_name)

    #loads RealESRGan Model
    realesr_gan_model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
    realesr_gan_anime_video_model = SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=16, upscale=4, act_type='prelu')

    real_esr_gan_upsampler = RealESRGANer(
        scale=netscale,
        model_path=realesr_gan_model_path,
        dni_weight=dni_weight,
        model=realesr_gan_model,
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=True,
        gpu_id=0)

    print(f"===============loaded RealESRGanNer model====================")
    real_esr_gan_anime_video_upsampler = RealESRGANer(
        scale=netscale,
        model_path=realesr_gan_anime_model_path,
        dni_weight=dni_weight,
        model=realesr_gan_anime_video_model,
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=True,
        gpu_id=0)

    print(f"===============loaded Anime model====================")
    face_enhancer = GFPGANer(
            model_path=realesr_gan_face_enhanced_model_path,
            upscale=4,
            arch='clean',
            channel_multiplier=2,
            bg_upsampler=real_esr_gan_upsampler)
    print(f"===============loaded Face Enhancer model====================")
    model = {}
    model['face_enhancer'] = face_enhancer
    model['realesr_gan'] = real_esr_gan_upsampler
    model['realesr_gan_anime'] = real_esr_gan_anime_video_upsampler
    return model


def input_fn(request_body, request_content_type):
    if request_content_type == "application/json":
        data = json.loads(request_body)
        return data
    raise ValueError("Unsupported content type: {}".format(request_content_type))


def predict_fn(input_data, model):
    # forward pass
    input_file_path = input_data['input_file_path']
    output_file_path = input_data['output_file_path']
    job_id = input_data['job_id']
    batch_id = input_data['batch_id']
   
    imgname, extension = os.path.splitext(os.path.basename(input_file_path))
    img = cv2.imread(input_file_path, cv2.IMREAD_UNCHANGED)

    try:
       if 'face_enhanced' in input_data:
          if input_data['face_enhanced'].lower() == "yes":
             face_enhancer = model['face_enhancer'] 
             _, _, output = face_enhancer.enhance(img, has_aligned=False, only_center_face=False, paste_back=True)
          else:
             upsampler = model['realesr_gan'] 
             output, _ = upsampler.enhance(img, outscale=outscale)

       else:
          if ('is_anime' in input_data) and ((input_data['is_anime'].lower() == "yes") or (input_data['is_anime'].lower() == "true")):
             upsampler = model['realesr_gan_anime']
          else:
             upsampler = model['realesr_gan'] 
          output, _ = upsampler.enhance(img, outscale=outscale)

    except RuntimeError as error:
            print('Error', error)
            print('If you encounter CUDA out of memory, try to set --tile with a smaller number.')

    print(f"output: {output} output_file_path: {output_file_path}")
    cv2.imwrite(output_file_path, output)
    return { "status" : 200, "output_file_path" : output_file_path, "job_id" : job_id, "batch_id" : batch_id }


if __name__ == "__main__":
    model = model_fn("/opt/ml/model")
    print("model loaded")
    input_data = {}
    input_data['input_file_path'] = '/workdir/test/SD/frames/0001.png'
    input_data['output_file_path'] = '/tmp/0001-esrgan-torch.png'
    input_data['job_id'] = 123
    input_data['batch_id'] = 1

    output_data = predict_fn(input_data, model)
    print("image upscaling complete")
    print(output_data)
