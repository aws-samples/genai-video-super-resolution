import json
from pathlib import Path
import os
import numpy as np
import os
import pycuda.driver as cuda
import pycuda.autoinit
import tensorrt as trt
import cv2
import torch

# SwinIR configuration
scale_factor = 4
window_size = 8
device = "cpu" # only uses device for loading/unloading tensors
model_name = "engine-1080-1080.trt"
TRT_LOGGER = trt.Logger()

def preprocess(input_file_path):
    img_lq = cv2.imread(input_file_path, cv2.IMREAD_COLOR).astype(np.float32) / 255
    img_lq = np.transpose(img_lq if img_lq.shape[2] == 1 else img_lq[:, :, [2, 1, 0]], (2, 0, 1))  # HCW-BGR to CHW-RGB
    img_lq = torch.from_numpy(img_lq).float().unsqueeze(0).to(device)  # CHW-RGB to NCHW-RGB
    _, _, h_old, w_old = img_lq.size()
    h_pad = (h_old // window_size + 1) * window_size - h_old
    w_pad = (w_old // window_size + 1) * window_size - w_old
    img_lq = torch.cat([img_lq, torch.flip(img_lq, [2])], 2)[:, :, :h_old + h_pad, :]
    img_lq = torch.cat([img_lq, torch.flip(img_lq, [3])], 3)[:, :, :, :w_old + w_pad]
    return img_lq

def model_fn(model_dir):
    # loads SwinIR tensorrt model
    model_path = os.path.join(model_dir, model_name)
    with open(model_path, "rb") as f, trt.Runtime(TRT_LOGGER) as runtime:
        print(f"========returning model ======")
        engine = runtime.deserialize_cuda_engine(f.read())
        context = engine.create_execution_context()
        return { "engine" : engine, "context" : context }

def input_fn(request_body, request_content_type):
    if request_content_type == "application/json":
        data = json.loads(request_body)
        return data
    raise ValueError("Unsupported content type: {}".format(request_content_type))

def predict_fn(input_data, model):
    input_file_path = input_data['input_file_path']
    output_file_path = input_data['output_file_path']
    input_image = preprocess(input_file_path)
    image_channel = input_image.shape[1]
    image_height = input_image.shape[2]
    image_width = input_image.shape[3]
    input_image = input_image.cpu().numpy()
    engine = model["engine"]
    context = model["context"]
    # Set input shape based on image dimensions for inference
    context.set_binding_shape(engine.get_binding_index("input"), (1, 3, image_height, image_width))
    # Allocate host and device buffers
    bindings = []
    for binding in engine:
        binding_idx = engine.get_binding_index(binding)
        size = trt.volume(context.get_binding_shape(binding_idx))
        dtype = trt.nptype(engine.get_binding_dtype(binding))
        if engine.binding_is_input(binding):
            input_buffer = np.ascontiguousarray(input_image)
            input_memory = cuda.mem_alloc(input_image.nbytes)
            bindings.append(int(input_memory))
        else:
            output_buffer = cuda.pagelocked_empty(size, dtype)
            output_memory = cuda.mem_alloc(output_buffer.nbytes)
            bindings.append(int(output_memory))

    stream = cuda.Stream()
    # Transfer input data to the GPU.
    cuda.memcpy_htod_async(input_memory, input_buffer, stream)
    # Run inference
    context.execute_async_v2(bindings=bindings, stream_handle=stream.handle)
    # Transfer prediction output from the GPU.
    cuda.memcpy_dtoh_async(output_buffer, output_memory, stream)
    # Synchronize the stream
    stream.synchronize()

    img = np.reshape(output_buffer, (image_channel, image_height*scale_factor, image_width*scale_factor))
    img = np.clip(img, 0, 1)
    if img.ndim == 3:
      img = np.transpose(img[[2, 1, 0], :, :], (1, 2, 0))  # CHW-RGB to HCW-BGR
    img = (img * 255.0).round().astype(np.uint8)  # float32 to uint8
    cv2.imwrite(output_file_path, img)
    torch.cuda.empty_cache()
    engine.__del__()
    context.__del__()
    return { "status" : 200, "output_file_path" : output_file_path }

if __name__ == "__main__":
    model = model_fn("/opt/ml/model")
    print("model loaded")
    input_data = {}
    input_data['input_file_path'] = '/opt/ml/model/code/0001.png'
    input_data['output_file_path'] = '/opt/ml/model/code/0001-output.png'
    output_data = predict_fn(input_data, model)
    print("image upscaling complete")
    print(output_data)
