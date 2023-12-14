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
output_filename="bootstrap.tar.gz"
rm -rf ${output_folder}/${output_filename}
tar -cvzf ${output_folder}/${output_filename} .
formatted_s3_dest_loc="s3://${s3_bucket_name}/bootstrap/"
aws s3 cp ${output_folder}/${output_filename} ${formatted_s3_dest_loc}
aws s3 cp /tmp/compute-node-configured.sh ${formatted_s3_dest_loc}
echo "bootstrap data has been uploaded to the S3 bucket"

# cleaning up
rm -rf /tmp/compute-node-configured.sh
rm -rf ${output_folder}/${output_filename}
