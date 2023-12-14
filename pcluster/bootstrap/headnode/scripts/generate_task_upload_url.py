#!/usr/bin/python3
import boto3, sys, os

bucket_name = sys.argv[1]
object_name = sys.argv[2]
expiration = sys.argv[3]

s3_client = boto3.client('s3')

try:
    print(s3_client.generate_presigned_url('put_object',
          Params={'Bucket': bucket_name,
          'Key': object_name},
          ExpiresIn=expiration))
except ClientError as e:
    sys.exit(e)

