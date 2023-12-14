#!/bin/bash

echo "downloading  bootstrap scripts from s3" >> /tmp/.node-status
aws s3 cp s3://{{S3_BUCKET_NAME}}/bootstrap/bootstrap-headnode.tar.gz /tmp/genai-video-super-resolution/
cd /tmp/genai-video-super-resolution
tar -xvzf bootstrap-headnode.tar.gz -C /home/ec2-user
pip3 install boto3
echo "completed  bootstrap scripts from s3" >> /tmp/.node-status
