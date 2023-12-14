import torch
import torch.nn as nn
import json
from pathlib import Path
from swinir.load_model import define_model
import numpy as np
import cv2
import os

# SwinIR configuration
scale_factor = 4
window_size = 8

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model_name = "Swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.pth"

def model_fn(model_dir):
    # loads SwinIR model
    model_path = os.path.join(model_dir, model_name)
    print(f"========model path: {model_path} ======")
    model = define_model(model_path, "real_sr", scale_factor)
    model = model.to(device)
    model.eval()
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

    img_lq = cv2.imread(input_file_path, cv2.IMREAD_COLOR).astype(np.float32) / 255.
    img_lq = np.transpose(img_lq if img_lq.shape[2] == 1 else img_lq[:, :, [2, 1, 0]], (2, 0, 1))  # HCW-BGR to CHW-RGB
    img_lq = torch.from_numpy(img_lq).float().unsqueeze(0).to(device)  # CHW-RGB to NCHW-RGB
    with torch.no_grad():
        # pad input image to be a multiple of window_size
        _, _, h_old, w_old = img_lq.size()
        h_pad = (h_old // window_size + 1) * window_size - h_old
        w_pad = (w_old // window_size + 1) * window_size - w_old
        img_lq = torch.cat([img_lq, torch.flip(img_lq, [2])], 2)[:, :, :h_old + h_pad, :]
        img_lq = torch.cat([img_lq, torch.flip(img_lq, [3])], 3)[:, :, :, :w_old + w_pad]
        print(f"==========================image input size: {img_lq.shape} ======================")
        output = model(img_lq)
        output = output[..., :h_old * scale_factor, :w_old * scale_factor]

        output = output.data.squeeze().float().cpu().clamp_(0, 1).numpy()
        if output.ndim == 3:
            output = np.transpose(output[[2, 1, 0], :, :], (1, 2, 0))  # CHW-RGB to HCW-BGR
        output = (output * 255.0).round().astype(np.uint8)  # float32 to uint8

        print(f'writing upscaled image to {output_file_path}')
        cv2.imwrite(f'{output_file_path}', output)
        torch.cuda.empty_cache()
        print(f'torch cache cleared')
        return { "status" : 200, "output_file_path" : output_file_path, "job_id" : job_id, "batch_id" : batch_id }


if __name__ == "__main__":
    model = model_fn("/opt/ml/model")
    print("model loaded")
    input_data = {}
    input_data['input_file_path'] = '/videos/test/SD/frames/0001.png'
    input_data['output_file_path'] = '/videos/test/HD/frames/0001.png'
    input_data['job_id'] = '001'
    input_data['batch_id'] = '001'
    output_data = predict_fn(input_data, model)
    print("image upscaling complete")
    print(output_data)
