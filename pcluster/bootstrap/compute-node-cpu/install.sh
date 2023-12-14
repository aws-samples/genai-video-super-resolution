#!/bin/bash
set -e 

if [ $# -ne 1 ] 
then
 echo "Usage: install.sh <S3 bucket name>"
 echo "e.g. install.sh my-s3-bucket"
 exit 1
fi

s3_bucket_name=$1
output_folder="/tmp"
formatted_s3_dest_loc="s3://${s3_bucket_name}/bootstrap/"
aws s3 cp compute-node-cpu-configured.sh ${formatted_s3_dest_loc}
echo "cpu bootstrap data has been uploaded to the S3 bucket"