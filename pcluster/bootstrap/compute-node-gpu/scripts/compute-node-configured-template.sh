#!/bin/bash
SECONDS=0
sudo usermod -aG docker $USER
sudo service docker restart

echo "downloading  bootstrap scripts from s3" >> /tmp/.node-status
aws s3 cp s3://{{S3_BUCKET_NAME}}/bootstrap/bootstrap.tar.gz /tmp/genai-video-super-resolution-pcluster/
echo "completed  bootstrap scripts from s3" >> /tmp/.node-status
cd /tmp/genai-video-super-resolution-pcluster
tar -xvzf bootstrap.tar.gz

# adding GPU metrics to cloudwatch agent
cp cloudwatch/cloudwatch-agent-gpu-config.json /opt/aws/amazon-cloudwatch-agent/bin/config.json
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json &>> /tmp/.node-status

# docker pull the latest images
aws ecr get-login-password --region {{AWS_REGION}} | docker login --username AWS --password-stdin {{AWS_ACCOUNT}}.dkr.ecr.{{AWS_REGION}}.amazonaws.com
echo "login successful" >> /tmp/.node-status

echo "install docker-compose" >> /tmp/.node-status
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
echo "docker-compose installed successfully." >> /tmp/.node-status

docker-compose -f docker/docker-compose.yaml up -d &>> /tmp/.node-status

success=0
cd test
while  [ $success -ne 1 ]
do
 ./test.sh realesrgan &>> /tmp/.node-status
 if [ $?  -eq 0 ]
 then
   echo "done initialize realesrgan" >> /tmp/.node-status
   success=1
 else
   echo "failed to initialize realesrgan, keep trying.." >> /tmp/.node-status
   sleep 15
 fi
done

success=0
while  [ $success -ne 1 ]
do
 ./test.sh swinir2  &>> /tmp/.node-status
 if [ $?  -eq 0 ]
 then
   echo "done initialize swinir2" >> /tmp/.node-status
   success=1
 else
   echo "failed to initialize swinir, keep trying.." >> /tmp/.node-status
   sleep 15
 fi
done
cd ~
echo "bootstrap took $SECONDS seconds" >> /tmp/.node-status
