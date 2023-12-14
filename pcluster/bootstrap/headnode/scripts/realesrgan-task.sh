#!/bin/bash
set -e

real_src_dir=$1
real_dest_dir=$2
base_name=$3
total_frames=$4
image_type=$5
task_id=$6

int_len=${#total_frames}
task_frame=$(printf "%0${int_len}d" ${SLURM_ARRAY_TASK_ID})
payload="{ \"input_file_path\" : \"${real_src_dir}/${base_name}_${task_frame}.${image_type}\", \"output_file_path\" : \"${real_dest_dir}/${base_name}_${task_frame}.${image_type}\", \"job_id\" : \"1234\", \"batch_id\" : \"01\", \"is_anime\" : \"yes\" }"

SECONDS=0
time curl -X POST -d ''"$payload"'' -H"Content-Type: application/json" http://localhost:8889/invocations
duration=$SECONDS

aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions task_id=$task_id,phase=realesrgan-upscale --metric-name duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions phase=realesrgan-upscale --metric-name duration

