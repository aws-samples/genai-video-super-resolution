#!/bin/bash
SECONDS=0
echo "downloading ffmpeg" >> /tmp/.node-status
tmp_dir=/tmp/ffmpeg
mkdir -p ${tmp_dir}
wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz -P ${tmp_dir}
cd ${tmp_dir}
echo "extracting ffmpeg" >> /tmp/.node-status
tar -xf ffmpeg-release-amd64-static.tar.xz
cd ffmpeg-*-amd64-static/
sudo mv ffmpeg ffprobe /usr/local/bin
echo "ffmpeg installed successfully." >> /tmp/.node-status