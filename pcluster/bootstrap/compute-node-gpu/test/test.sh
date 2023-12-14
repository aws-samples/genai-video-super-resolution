#!/bin/bash
set -e
mkdir -p HD/frames
model=$1
if [ ${model} == "realesrgan" ]
then
  curl -X POST -d@payload.json -H"Content-Type: application/json" http://localhost:8888/invocations 
elif [ ${model} == "swinir2" ]
then
  curl -X POST -d@payload.json -H"Content-Type: application/json" http://localhost:8889/invocations
fi
