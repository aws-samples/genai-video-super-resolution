## Overview
This is a repository that contains code for building a docker image for providing video super resolution using family of Real-ESRGan models. 

## Quick Start
How to run this model locally:

1. build the docker image by running ./build_docker.sh script
2. once the script is completed, you can start the container.
3. The following command assumes an fsx lustre is setup and mounted on the local instance. 

```
docker run -d --gpus all --name realesrgan -v $PWD/test:/videos/test -p8889:8080 602900100639.dkr.ecr.us-east-1.amazonaws.com/genai-realesrgan-4x-super-resolution serve
```

## Testing
1. cd test && ./test.sh
2. verify upscaled version of the image is created under HD/frames directory.


