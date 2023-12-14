#!/bin/bash
set -e
OUT_DIR=$1

TGT_S3_PREFIX=$(cat ${OUT_DIR}/output_bucket)
task_id=$(cat ${OUT_DIR}/task_id)
frames=$(cat ${OUT_DIR}/frames)
vfps=$(cat ${OUT_DIR}/vfps)
acodec=$(cat ${OUT_DIR}/acodec)
base_name=$(cat ${OUT_DIR}/vid_filename)
image_type=$(cat ${OUT_DIR}/frame_type)
pad_len=${#frames}

SECONDS=0
ffmpeg -framerate ${vfps} -i ${OUT_DIR}/SRC_FRAMES/${base_name}_%0${pad_len}d.${image_type}  -i ${OUT_DIR}/AUDIO/${base_name}.${acodec} -c:a copy -shortest -c:v libx264 -pix_fmt yuv420p ${OUT_DIR}/${base_name}_reencoded_original.mp4
duration=$SECONDS

aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions task_id=$task_id --metric-name reencode_seconds

aws s3 cp ${OUT_DIR}/${base_name}_reencoded_original.mp4 ${TGT_S3_PREFIX}/${task_id}/${base_name}_reencoded_original.mp4
