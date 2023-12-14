#!/bin/bash

usage () {
 echo "build_and_push_docker.sh -a [AWS account number] -r [AWS Region]"
 echo "For example: build_and_push_docker.sh -a 123456789012 -r us-east-1"
}

while getopts ":a:r:" flag
do
    case "${flag}" in
        a) aws_account_number=${OPTARG};;
        r) aws_region_name=${OPTARG};;
        *)  usage
            exit;
    esac
done
shift "$((OPTIND-1))"

if [ "${aws_account_number}" == "" ]
then
  aws_account_number=$(aws sts get-caller-identity --query Account --output text)
  echo "AWS account number not provided, use the current AWS account: ${aws_account_number}"
fi

if [ "${aws_region_name}" == "" ]
then
  aws_region_name=$(aws configure get region)
  echo "AWS region name not provided, use the current AWS region: ${aws_region_name}"
fi

docker_image_base_name="genai-realesrgan-4x-super-resolution"
aws ecr describe-repositories  --repository-names ${docker_image_base_name} 2>/dev/null
status=$?

# create a repository if it doesn't exist
if [ $status != 0 ]
then
  aws ecr create-repository --repository-name ${docker_image_base_name} 
else
  echo "repository ${docker_image_base_name} exists, will reuse this repository"
fi
local_docker_image_name="${docker_image_base_name}:latest"
aws ecr get-login-password --region ${aws_region_name} | docker login --username AWS --password-stdin 763104351884.dkr.ecr.${aws_region_name}.amazonaws.com
docker build -t ${local_docker_image_name} --build-arg="AWS_REGION=${aws_region_name}" . -f Dockerfile.realesrgan.gpu
aws ecr get-login-password --region ${aws_region_name} | docker login --username AWS --password-stdin ${aws_account_number}.dkr.ecr.${aws_region_name}.amazonaws.com
docker_image_name=${aws_account_number}.dkr.ecr.${aws_region_name}.amazonaws.com/${local_docker_image_name}
docker tag ${local_docker_image_name} ${docker_image_name}
docker push ${docker_image_name}
