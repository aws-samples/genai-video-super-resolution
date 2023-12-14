#!/bin/bash
set -e

usage () {
 echo "frame-super-resolution.sh -s [source_dir e.g. /fsx/dev/video/test/SD/frames ] -d [destination_dir e.g. /fsx/dev/video/test/HD/frames ] -a [is_anime, yes|no] -f [number of frames]"
 echo "For example: frame-super-resolution.sh -s /fsx/dev/video/test/SD/frames -d /fsx/dev/video/test/HD/frames -a no -f 1024"
}

while getopts ":s:" flag
do
    case "${flag}" in
        s) src_dir=${OPTARG};;
        *)  usage
            exit;
    esac
done
shift "$((OPTIND-1))"

echo upscaling > ${src_dir}/pipeline_status

REALESRGAN_VCPU_PER_TASK=1
SWINIR_VCPU_PER_TASK=4

is_anime=$(cat ${src_dir}/is_anime)
task_id=$(cat ${src_dir}/task_id)
output_bucket=$(cat ${src_dir}/output_bucket)

mkdir -p reports

real_src_dir=$(realpath ${src_dir}/SRC_FRAMES)
real_dest_dir=$(realpath ${src_dir}/TGT_FRAMES)

if [ -z $is_anime ]
then
  is_anime="no"
fi
base_name=$(cat ${src_dir}/vid_filename)
image_type=$(cat ${src_dir}/frame_type)
frames=$(cat ${src_dir}/frames)


if [ ${is_anime,,} == "yes" ] ||  [ ${is_anime,,} == "true" ]
then
   upscale_job_id=$(sbatch --parsable --array=1-${frames} -o ${src_dir}/logs/upscale_realesrgen_%A_%a.out -p q1 --cpus-per-task=${REALESRGAN_VCPU_PER_TASK} realesrgan-task.sh "${real_src_dir}" "${real_dest_dir}" "${base_name}" "${frames}" "${image_type}" "${task_id}")
else
   upscale_job_id=$(sbatch --parsable --array=1-${frames} -o ${src_dir}/logs/upscale_swinir_/%A_%a.out -p q1 --cpus-per-task=${SWINIR_VCPU_PER_TASK} swinir-task.sh "${real_src_dir}" "${real_dest_dir}" "${base_name}" "${frames}" "${image_type}" "${task_id}")
fi

sbatch --dependency=afterok:${upscale_job_id} -c 15 -o ${src_dir}/logs/encode_%j.out -p q2 /home/ec2-user/encode_new_movie.sh $src_dir
