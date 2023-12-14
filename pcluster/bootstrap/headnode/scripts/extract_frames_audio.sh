#!/bin/bash
set -e

OUT_DIR=$1

S3_SRC=$(cat ${OUT_DIR}/vid_src)
FRAME_TYPE=$(cat ${OUT_DIR}/frame_type)
HEAD_INSTANCE=$(cat ${OUT_DIR}/head_instance)
is_anime=$(cat ${OUT_DIR}/is_anime)
task_id=$(cat ${OUT_DIR}/task_id)
output_bucket=$(cat ${OUT_DIR}/output_bucket)

echo extracting > ${OUT_DIR}/pipeline_status

source_url_presign=$(aws s3 presign ${S3_SRC})

#VID_SRC=${source_url_presign%\?*}
VID_SRC=${source_url_presign}
VID_BASE=$(basename $VID_SRC)
VID_FILE=${VID_BASE%.*}
VID_EXT=${VID_BASE##*.}

VCODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nokey=1:noprint_wrappers=1 ${VID_SRC})
ACODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nokey=1:noprint_wrappers=1 ${VID_SRC})
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ${VID_SRC})
VRES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 ${VID_SRC})
frames=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of default=nokey=1:noprint_wrappers=1 ${VID_SRC})
pad_len=${#frames}
probed_vfps=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate ${VID_SRC})
vfps=$(echo "scale=2;${probed_vfps}" | bc)
vduration=$(ffprobe -v error -show_streams -select_streams v -v quiet ${VID_SRC} | grep "duration=" | cut -d '=' -f 2)
aduration=$(ffprobe -v error -show_streams -select_streams a -v quiet ${VID_SRC} | grep "duration=" | cut -d '=' -f 2)
abitrate=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1  ${VID_SRC})

mkdir -p ${OUT_DIR}/SRC_FRAMES
mkdir -p ${OUT_DIR}/AUDIO
mkdir -p ${OUT_DIR}/TGT_FRAMES

echo ${VID_SRC} > ${OUT_DIR}/source
echo ${VID_FILE} > ${OUT_DIR}/vid_filename
echo ${duration} > ${OUT_DIR}/duration
echo ${vduration} > ${OUT_DIR}/vduration
echo ${aduration} > ${OUT_DIR}/aduration
echo $frames > ${OUT_DIR}/frames
echo $ACODEC > ${OUT_DIR}/acodec
echo $VCODEC > ${OUT_DIR}/vcodec
echo ${vfps} > ${OUT_DIR}/vfps
echo ${VRES} > ${OUT_DIR}/vres
echo ${abitrate} > ${OUT_DIR}/abitrate

if [ ${is_anime,,} == "yes" ] ||  [ ${is_anime,,} == "true" ]
then
	is_anime_param="-a yes"
fi

SECONDS=0
ffmpeg -i $VID_SRC -map 0:a ${OUT_DIR}/AUDIO/${VID_FILE}.${ACODEC} -acodec copy -s ${VRES}  -fps_mode passthrough ${OUT_DIR}/SRC_FRAMES/${VID_FILE}_%0${pad_len}d.${FRAME_TYPE}
extract_duration=$SECONDS

aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $extract_duration --dimensions task_id=$task_id,phase=extract --metric-name duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $extract_duration --dimensions phase=extract --metric-name duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions task_id=$task_id --metric-name video_duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --metric-name video_duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value $frames --dimensions task_id=$task_id --metric-name frame_count
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value $frames --metric-name frame_count

ssm_command="sudo su - ec2-user -c '/home/ec2-user/frame-super-resolution-array.sh -s ${OUT_DIR}'"

aws --region us-east-1 ssm send-command --instance-ids "${HEAD_INSTANCE}" \
    --document-name "AWS-RunShellScript" \
    --comment "upscale frames and re-encode" \
    --parameters "{\"commands\":[\"${ssm_command}\"]}" \
    --output text
