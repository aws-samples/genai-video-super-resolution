#!/bin/bash

real_or_anime=$1
basename=$2

. $(dirname $0)/config

if [[ $S3_UPLOAD_URI =~ s3:\/\/([^/]*)\/(.*) ]];
then
        output_bucket=${BASH_REMATCH[1]}
        prefix=${BASH_REMATCH[2]}
fi


output_base=/fsx/dev/extract_job
## create new task ID
task_id=$(uuidgen)
output_dir=${output_base}_${task_id}
## attempt to create new task directory with new task ID

mkdir -p ${output_dir}

## check if new directory was really created
task_dir_status=$?
while [ ${task_dir_status} -ne 0 ]
do
        ## try to create directory again with new task ID
        task_id=$(uuidgen)
        output_dir=${output_base}_${task_id}
        mkdir -p ${output_dir}
        task_dir_status=$?
done

mkdir -p ${output_dir}/logs
dirname=$(dirname $0)
upload_url=$(${dirname}/generate_task_upload_url.py ${output_bucket} ${prefix}/${real_or_anime}/${task_id}/${basename} 3600)
echo "{ \"task_id\": \"${task_id}\", \"upload_url\": \"${upload_url}\" }"
