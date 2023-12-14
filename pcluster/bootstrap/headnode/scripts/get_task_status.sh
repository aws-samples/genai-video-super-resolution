#!/bin/bash

task_id=$1
output_dir=/fsx/dev/extract_job_${task_id}
pipeline_status=$(cat ${output_dir}/pipeline_status)
upscaled_video_location=null
if [[ $pipeline_status == "uploaded" ]]; then
        output_s3_key=$(cat ${output_dir}/output_s3_key)
        upscaled_video_location=\"$(aws s3 presign ${output_s3_key} --expires-in 86400)\"
fi
echo "{ \"pipeline_status\": \"${pipeline_status}\", \"upscaled_video_location\": ${upscaled_video_location} }"
