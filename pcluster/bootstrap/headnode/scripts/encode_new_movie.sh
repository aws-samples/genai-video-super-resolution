#!/bin/bash
set -e
OUT_DIR=$1
echo encoding > ${OUT_DIR}/pipeline_status

TGT_S3_PREFIX=$(cat ${OUT_DIR}/output_bucket)
task_id=$(cat ${OUT_DIR}/task_id)
frames=$(cat ${OUT_DIR}/frames)
vfps=$(cat ${OUT_DIR}/vfps)
acodec=$(cat ${OUT_DIR}/acodec)
base_name=$(cat ${OUT_DIR}/vid_filename)
image_type=$(cat ${OUT_DIR}/frame_type)
pad_len=${#frames}
abitrate=$(cat ${OUT_DIR}/abitrate)

SECONDS=0
ffmpeg -framerate ${vfps} -i ${OUT_DIR}/TGT_FRAMES/${base_name}_%0${pad_len}d.${image_type}  -i ${OUT_DIR}/AUDIO/${base_name}.${acodec} -c:a copy -b:a ${abitrate} -shortest -c:v libx264 -pix_fmt yuv420p ${OUT_DIR}/${base_name}_final_upscaled.mp4
duration=$SECONDS

aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions task_id=$task_id,phase=encode --metric-name duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions phase=encode --metric-name duration

output_s3_key=${TGT_S3_PREFIX}/${task_id}/${base_name}_final_upscaled.mp4

aws s3 cp ${OUT_DIR}/${base_name}_final_upscaled.mp4 ${output_s3_key}
echo ${output_s3_key} > ${OUT_DIR}/output_s3_key
echo uploaded > ${OUT_DIR}/pipeline_status
