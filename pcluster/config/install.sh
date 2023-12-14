#!/bin/bash

usage () {
 echo "./install.sh -s [s3 bucket name] -k [ssh key pair name] -v [vpc private subnet id ] -u [ vpc public subnet id ] -b [gpu compute node bootstrap script s3 location] -d [cpu compute node bootstrap script s3 location] -n [head node bootstrap script s3 location] -g [ custom ami for gpu compute node] -r [aws region]"
 echo "For example: ./install.sh -s my-video-super-resolution-bucket -k my-ssh-key-pair  -v subnet-xxxxxx -u subnet-yyyyyyy -b s3://my-video-super-resolution-bucket/bootstrap/compute-gpu-node-bootstrap-script.sh -d s3://my-video-super-resolution-bucket/bootstrap/compute-cpu-configured.sh -n s3://my-video-super-resolution-bucket/bootstrap/headnode-configured.sh -g ami-xxxxxxx -r us-east-1"
}

while getopts ":s:k:v:u:b:d:n:g:r:" flag
do
    case "${flag}" in
        s) s3_bucket_name=${OPTARG};;
        k) ssh_key_pair_name=${OPTARG};;
        v) vpc_private_subnet_id=${OPTARG};;
        u) vpc_public_subnet_id=${OPTARG};;
        b) on_node_started_script_gpu_compute_node=${OPTARG};;
        d) on_node_started_script_cpu_compute_node=${OPTARG};;
        n) on_node_started_script_head_node=${OPTARG};;
        g) custom_ami_gpu=${OPTARG};;
        r) aws_region=${OPTARG};;
        *) usage
            exit;
    esac
done
shift "$((OPTIND-1))"

if [ "${s3_bucket_name}" == "" ]
then
  echo "S3 bucket name is required"
  usage
  exit 1
fi

if [ "${vpc_private_subnet_id}" == "" ]
then
  echo "VPC private subnet id is required"
  usage
  exit 1
fi

if [ "${vpc_public_subnet_id}" == "" ]
then
  echo "VPC public subnet id is required"
  usage
  exit 1
fi

if [ "${on_node_started_script_gpu_compute_node}" == "" ]
then
  echo "on_node startup script for GPU compute node is required"
  usage
  exit 1
fi

if [ "${on_node_started_script_cpu_compute_node}" == "" ]
then
  echo "on_node startup script for CPU compute node is required"
  usage
  exit 1
fi

if [ "${custom_ami_gpu}" == "" ]
then
  echo "custom GPU AMI id is required"
  usage
  exit 1
fi

if [ "${ssh_key_pair_name}" == "" ]
then
  echo "ssh key pair name is required"
  usage
  exit 1
fi

if [ "${on_node_started_script_head_node}" == "" ]
then
  echo "on_node startup script for HeadNode is required"
  usage
  exit 1
fi

if [ "${aws_region}" == "" ]
then
  echo "AWS region is required"
  usage
  exit 1
fi

output_file_path=/tmp/cluster-config.yaml
formatted_s3_dest_loc=$(echo ${s3_dest_loc} | sed '/\/$/! s|$|/|')
sed "s|{{S3_BUCKET}}|$s3_bucket_name|g; s|{{VPC_PRIVATE_SUBNET_ID}}|$vpc_private_subnet_id|g; s|{{VPC_PUBLIC_SUBNET_ID}}|$vpc_public_subnet_id|g; s|{{SSH_KEY_PAIR_NAME}}|$ssh_key_pair_name|g; s|{{ON_NODE_STARTED_SCRIPT_GPU_COMPUTE_NODE}}|$on_node_started_script_gpu_compute_node|g; s|{{GPU_COMPUTE_NODE_CUSTOM_AMI}}|$custom_ami_gpu|g; s|{{ON_NODE_STARTED_SCRIPT_CPU_COMPUTE_NODE}}|$on_node_started_script_cpu_compute_node|g; s|{{ON_NODE_STARTED_SCRIPT_HEAD_NODE}}|$on_node_started_script_head_node|g; s|{{AWS_REGION}}|$aws_region|g" cluster-config-template.yaml > /tmp/cluster-config.yaml
echo "Parallel cluster config file created successfully. The config file location is: ${output_file_path}"
