## SwinIR Model Performance Optimization (Experimentation) 
The following section walksthrough the steps to optimize the Swin2SR model by converting the torch model into [ONNX](https://onnx.ai/get-started.html) and [TensorRT](https://docs.nvidia.com/deeplearning/tensorrt/developer-guide/index.html). The converted model could improve overall throughput by up to 30%. (based on internal benchmark)

This process involves 3 steps: 

1. Convert the python model to ONNX format. 
2. Convert the ONNX model to tensorrt format.
3. Build and push a docker image with the trt model to ECR.

### Step 1: Convert torch model to ONNX
```
cd swinir2-tensorrt/onnx
pip install -r requirements.txt
python torch2onnx.py —task real_sr —scale 4 —model_path model_zoo/swin2sr/Swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.pth —folder_lq testsets
```

The ONNX file should be created in the onnx/output directory: swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.onnx

### Step 2: Convert ONNX to TensorRT
```
docker run —gpus all -v $PWD/tensorrt:/workdir -v $PWD/onnx/output:/onnx nvcr.io/nvidia/tensorrt:23.06-py3 /workdir/onnx2trt.sh
```

The tensorrt output engine file should be found in tensorrt/engine-1080-1080.trt.


### Step 3: Build and Push Image to ECR
```
./build_and_push_docker.sh -a <aws account number> -r <aws region name>
```

The resulting docker image will be <aws-account-nbr>.dkr.ecr.<aws region name>.amazonaws.com/genai-swinir2-4x-super-resolution:trt

### Deploy and test model endpoint locally

```
docker run -d --gpus all --name swinir -v $PWD/test:/videos/test -p8888:8080 <aws-account>.dkr.ecr.<aws-region>.amazonaws.com/genai-swinir-4x-super-resolution:trt serve
cd test && ./test.sh 
```

Verify upscaled version of the image is created under HD/frames directory.
