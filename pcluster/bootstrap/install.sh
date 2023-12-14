#!/bin/bash
set -e 

if [ $# -ne 1 ]
then
 echo "Usage: install.sh <S3 bucket name>"
 echo "e.g. install.sh my-s3-bucket"
 exit 1
fi

s3_bucket_name=$1
cd compute-node-cpu && ./install.sh ${s3_bucket_name} && cd ..
cd compute-node-gpu && ./install.sh ${s3_bucket_name} && cd ..
cd headnode && ./install.sh ${s3_bucket_name} && cd ..
