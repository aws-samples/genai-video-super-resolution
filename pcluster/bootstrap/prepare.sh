#!/bin/bash

usage () {
 echo "prepare.sh -b [ s3 bucket name where the bootstrap scripts are located] -s [source s3 video content location] -d [s3 location for upscaled media content ] -a [ aws account ] -r [ aws region ]"
 echo "For example: prepare.sh -b my-video-super-resolution -s s3://my-video-super-resolution-bucket/data/original  -d s3://my-video-super-resolution-bucket/data/final -a 123456789012 -r us-east-1"
}

while getopts ":s:d:a:r:b:" flag
do
    case "${flag}" in
        s) source_video_s3_path=${OPTARG};;
        d) dest_video_s3_path=${OPTARG};;
        a) aws_account=${OPTARG};;
        r) aws_region=${OPTARG};;
        b) s3_bucket_name=${OPTARG};;
        *)  usage
            exit;
    esac
done
shift "$((OPTIND-1))"

if [ "${source_video_s3_path}" == "" ]
then
  echo "A valid source video content location (bucket and prefix) on S3 is required"
  usage
  exit 1
fi

if [ "${dest_video_s3_path}" == "" ]
then
  echo "A valid destination video content location (bucket and prefix) on S3 is required"
  usage
  exit 1
fi

if [ "${aws_account}" == "" ]
then
  echo "A valid AWS account where the solution is to be deployed is required"
  usage
  exit 1
fi

if [ "${aws_region}" == "" ]
then
  echo "A valid AWS region where the solution is to be deployed is required"
  usage
  exit 1
fi

if [ "${s3_bucket_name}" == "" ]
then
  echo "A valid S3 bucket is required for the bootstrap script"
  usage
  exit 1
fi

is_s3_uri=$(echo ${source_video_s3_path} | grep ^s3://)

if [ "${is_s3_uri}" == "" ]
then
  echo "${source_video_s3_path} is not a valid s3 path"
  usage
  exit 1
fi

is_s3_uri=$(echo ${dest_video_s3_path} | grep ^s3://)
if [ "${is_s3_uri}" == "" ]
then
  echo "${dest_video_s3_path} is not a valid s3 path"
  usage
  exit 1
fi

echo "creating a config file for headnode"
echo "S3_UPLOAD_URI=${source_video_s3_path}" > headnode/scripts/config
echo "S3_DOWNLOAD_URI=${dest_video_s3_path}" >> headnode/scripts/config

echo "creating a create_extract_job.sh from a template"
sed "s|{{DEST_VIDEO_S3_PATH}}|$dest_video_s3_path|g" headnode/scripts/create_extract_job_template.sh > headnode/scripts/create_extract_job.sh
chmod +x headnode/scripts/create_extract_job.sh

echo "creating a docker-compose file from a template"
sed "s|{{AWS_ACCOUNT}}|$aws_account|g; s|{{AWS_REGION}}|$aws_region|g" compute-node-gpu/docker/docker-compose-template.yaml > compute-node-gpu/docker/docker-compose.yaml

echo "creating a compute-node-configure.sh from a template"
sed "s|{{S3_BUCKET_NAME}}|$s3_bucket_name|g; s|{{AWS_ACCOUNT}}|$aws_account|g; s|{{AWS_REGION}}|$aws_region|g" compute-node-gpu/scripts/compute-node-configured-template.sh > /tmp/compute-node-configured.sh
echo "Done!"
