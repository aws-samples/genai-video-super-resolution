#!/bin/bash
set -e

vid_src=$1
is_anime=$2
frame_type=$3

/home/ec2-user/create_extract_job_full.sh $vid_src $is_anime $frame_type {{DEST_VIDEO_S3_PATH}}
