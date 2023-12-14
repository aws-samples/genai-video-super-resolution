#!/bin/bash
set -e

trtexec --onnx=/onnx/Swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.onnx --saveEngine=/workdir/engine-1080-1080.trt --useCudaGraph --minShapes=input:1x3x128x168 --optShapes=input:1x3x248x328 --maxShapes=input:1x3x1088x1088 --fp16 --tacticSources=-CUDNN,+CUBLAS,+CUBLAS_LT

