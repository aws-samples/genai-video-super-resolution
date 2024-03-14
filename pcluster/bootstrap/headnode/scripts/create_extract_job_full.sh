#!/bin/bash
set -e

. $(dirname $0)/config

vid_src=$1
is_anime=$2
frame_type=$3
output_bucket=${S3_DOWNLOAD_URI}

output_base=/fsx/dev/extract_job

## extract task ID
vid_src_suffix=${vid_src/$output_bucket/}

task_id=$(if [[ "$vid_src_suffix" =~ \/[^\/]*\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/.* ]]; then echo ${BASH_REMATCH[1]}; fi)
output_dir=${output_base}_${task_id}

if [[ ! -d $output_dir ]]; then
        echo "${output_dir} not found"
        mkdir -p $output_dir 
fi

echo ${task_id} > ${output_dir}/task_id
echo ${frame_type} > ${output_dir}/frame_type
echo ${output_bucket} > ${output_dir}/output_bucket

die() { status=$1; shift; echo "FATAL: $*"; exit $status; }
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
#head_instance=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id || die \"wget instance-id has failed: $?\")
head_instance=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || die \"wget instance-id has failed: $?\")

echo ${head_instance} > ${output_dir}/head_instance
echo ${vid_src} > ${output_dir}/vid_src
echo ${is_anime} > ${output_dir}/is_anime

sbatch -c 15 -o ${output_dir}/logs/extract_%j.out -p q2 /home/ec2-user/extract_frames_audio.sh ${output_dir}

echo task id: ${task_id}
echo Job work dir: ${output_dir}
echo pending > ${output_dir}/pipeline_status
