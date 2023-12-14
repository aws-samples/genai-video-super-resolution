#!/bin/bash
set -e


usage () {
 echo "frame-super-resolution.sh -s [source_dir e.g. /fsx/dev/video/test/SD/frames ] -d [destination_dir e.g. /fsx/dev/video/test/HD/frames ] -a [is_anime, yes|no]"
 echo "For example: frame-super-resolution.sh -s /fsx/dev/video/test/SD/frames -d /fsx/dev/video/test/HD/frames -a no"
}

while getopts ":s:d:a:" flag
do
    case "${flag}" in
        s) src_dir=${OPTARG};;
        d) dest_dir=${OPTARG};;
        a) is_anime=${OPTARG};;
        *)  usage
            exit;
    esac
done
shift "$((OPTIND-1))"

mkdir -p ${dest_dir}
mkdir -p reports

real_src_dir=$(realpath ${src_dir})
real_dest_dir=$(realpath ${dest_dir})

if [ -z $is_anime ]
then
  is_anime="no"
fi

for i in `ls -1 $src_dir`
do
  if [ ${is_anime,,} == "yes" ] ||  [ ${is_anime,,} == "true" ]   
  then
     payload="{ \"input_file_path\" : \"${real_src_dir}/${i}\", \"output_file_path\" : \"${real_dest_dir}/${i}\", \"job_id\" : \"1234\", \"batch_id\" : \"01\", \"is_anime\" : \"yes\" }"
     sbatch -o reports/%j.out -p q1 realesrgan.sh "$payload"
  else
     payload="{ \"input_file_path\" : \"${real_src_dir}/${i}\", \"output_file_path\" : \"${real_dest_dir}/${i}\", \"job_id\" : \"1234\", \"batch_id\" : \"01\" }"
     sbatch -o reports/%j.out -p q1 --cpus-per-task=2 swinir.sh "$payload"
  fi
done

