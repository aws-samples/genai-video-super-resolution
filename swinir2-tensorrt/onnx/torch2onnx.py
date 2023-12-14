import argparse
import cv2
import glob
import numpy as np
from collections import OrderedDict
import os
import torch
import requests

from models.network_swin2sr import Swin2SR as net
from utils import util_calculate_psnr_ssim as util


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--task', type=str, default='color_dn', help='classical_sr, lightweight_sr, real_sr, '
                                                                     'gray_dn, color_dn, jpeg_car, color_jpeg_car')
    parser.add_argument('--scale', type=int, default=1, help='scale factor: 1, 2, 3, 4, 8') # 1 for dn and jpeg car
    parser.add_argument('--large_model', action='store_true', help='use large model, only provided for real image sr')
    parser.add_argument('--model_path', type=str,
                        default='model_zoo/swin2sr/Swin2SR_ClassicalSR_X2_64.pth')
    parser.add_argument('--folder_lq', type=str, default=None, help='input low-quality test image folder')
    args = parser.parse_args()

    device = "cpu"
    # set up model
    if os.path.exists(args.model_path):
        print(f'loading model from {args.model_path}')        
    else:
        os.makedirs(os.path.dirname(args.model_path), exist_ok=True)
        url = 'https://github.com/mv-lab/swin2sr/releases/download/v0.0.1/{}'.format(os.path.basename(args.model_path))
        r = requests.get(url, allow_redirects=True)
        print(f'downloading model {args.model_path}')
        open(args.model_path, 'wb').write(r.content)

    model = define_model(args)
    model.eval()
    model = model.to(device)

    folder = args.folder_lq
    window_size = 8
    path=os.path.join(folder,"test.png")
    img_lq = cv2.imread(path, cv2.IMREAD_COLOR).astype(np.float32) / 255.
    img_lq = np.transpose(img_lq if img_lq.shape[2] == 1 else img_lq[:, :, [2, 1, 0]], (2, 0, 1))  # HCW-BGR to CHW-RGB
    img_lq = torch.from_numpy(img_lq).float().unsqueeze(0).to(device)  # CHW-RGB to NCHW-RGB
    # convert to ONNX
    with torch.no_grad():
        # pad input image to be a multiple of window_size
        _, _, h_old, w_old = img_lq.size()
        h_pad = (h_old // window_size + 1) * window_size - h_old
        w_pad = (w_old // window_size + 1) * window_size - w_old
        img_lq = torch.cat([img_lq, torch.flip(img_lq, [2])], 2)[:, :, :h_old + h_pad, :]
        img_lq = torch.cat([img_lq, torch.flip(img_lq, [3])], 3)[:, :, :, :w_old + w_pad]
        to_onnx(img_lq, model, args)

def define_model(args):
    # use 'nearest+conv' to avoid block artifacts
    model = net(upscale=args.scale, in_chans=3, img_size=64, window_size=8,
                img_range=1., depths=[6, 6, 6, 6, 6, 6], embed_dim=180, num_heads=[6, 6, 6, 6, 6, 6],
                mlp_ratio=2, upsampler='nearest+conv', resi_connection='1conv')
    param_key_g = 'params_ema'
    pretrained_model = torch.load(args.model_path)
    model.load_state_dict(pretrained_model[param_key_g] if param_key_g in pretrained_model.keys() else pretrained_model, strict=True)

    return model

def to_onnx(img_lq, model, args):
    output_dir = os.path.join(os.getcwd(), "output") 
    os.makedirs(output_dir, exist_ok=True)
    output = model(img_lq)
    torch.onnx.export(model, img_lq, f"{output_dir}/Swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.onnx", export_params=True, opset_version=17, do_constant_folding=True, verbose=True, input_names = ['input'], output_names = ['output'], dynamic_axes={'input' : {2 : 'h', 3 : 'w'}, 'output' : {2 : 'h', 3 : 'w'}})

if __name__ == '__main__':
    main()
