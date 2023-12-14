import gradio as gr
import os
import uuid
import boto3
from botocore.exceptions import ClientError
import botocore
import time
import json
import requests

s3_client = boto3.client("s3")
ssm_client = boto3.client('ssm')
create_task_command_str = "sudo -u ec2-user /home/ec2-user/create_task.sh"
get_task_status_command_str = "sudo -u ec2-user /home/ec2-user/get_task_status.sh"
dataset_mapping = {
    "videos/anime/bbb/bbb-10s.mp4": "videos/anime/bbb/bbb-sr-10s.mp4"
}

dataset_mapping_demo = {
} # placeholder for demo contents. It'll automatically show up in the list of examples when the application is launched.

user_states = {}
s3 = boto3.client("s3")
is_demo_env = os.environ.get("IS_DEMO_ENV", "No")
allow_user_upload = True
if is_demo_env == "Yes":
    allow_user_upload = False

head_node = os.environ.get("HEAD_NODE", "")
default_source_video = gr.Video(interactive=False, include_audio=True, autoplay=True, width=2096, height=600, container=True, label="STANDARD RESOLUTION")
default_dest_video = gr.Video(interactive=False,  autoplay=True, width=2096, height=600, container=True, label="SUPER RESOLUTION (4x)")
s3_bucket = os.environ.get("S3_BUCKET", "")
s3_input_prefix = os.environ.get("S3_BUCKET_PREFIX", "data/video-super-resolution/demos/original")
css = """.svelte-1kyws56 { min-width: 100%}; .svelte-1kyws56 { min-height: 100%};"""


def call_ssm_command(command, instance_id):
  response = ssm_client.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={'commands': [command]}, )

  command_id = response['Command']['CommandId']
  success = False
  while not success:
    try:
      response = ssm_client.get_command_invocation(
          CommandId=command_id,
          InstanceId=instance_id,
        )
      if "Status" in response:
        if response["Status"] == "Success":
            print(f"output from SSM Command:{response['StandardOutputContent']}")
            output = response['StandardOutputContent']
            return output
        elif response["Status"] in ['Pending','InProgress','Delayed']:
            time.sleep(1)
            continue
        else:
            gr.Error("Internal Error. Please contact your system adminstrator for assistance")
            raise Exception(f"SSM Command: {command} failed with response code: {response['Status']}")
      else:
          gr.Error("Internal Error. Please contact your system adminstrator for assistance")
          raise Exception(f"SSM Command: {command} failed")

    except botocore.exceptions.ClientError as e:
      if e.response['Error']['Code'] == 'InvocationDoesNotExist':
        print("command has not returned. Will sleep and call again")
        time.sleep(1)
      else:
        raise e

with gr.Blocks(css = css, theme=gr.themes.Default(text_size=gr.themes.sizes.text_lg,
                                       font=[gr.themes.GoogleFont("Source Sans Pro"), "Arial", "sans-serif"])) as demo:
    user_state = gr.State({})
    def get_user_session_id(request: gr.Request):
        if 'headers' in request.kwargs:
            if 'cookie' in request.kwargs['headers']:
                cookies_data = request.kwargs['headers']['cookie'].split(";")
                for cookie_data in cookies_data:
                    c_key, c_val = cookie_data.split("=")
                    if c_key.strip() in ['access-token', "access-token-unsecure"]:
                        access_token = c_val.strip()
                        return access_token
        else:
            if request.username:
                return request.username

        return "anonymous"

    def upload_video(file, is_anime, request: gr.Request):
        global user_states
        global dataset_mapping
        file_path = file.name
        if file_path and len(file_path) > 0:
            session_id = get_user_session_id(request)
            if session_id in user_states:
                user_state = user_states[session_id]
            else:
                user_state = {}
                user_states[session_id] = user_state
            media_type = "anime" if is_anime else "real"

            basename = os.path.basename(file_path)
            create_task_command = f"{create_task_command_str} {media_type} {basename}"
            response_str = call_ssm_command(create_task_command, head_node)
            response = json.loads(response_str)
            user_state['unique_id'] = response['task_id']
            upload_url = response['upload_url']
            try:
                with open(file_path, "rb") as object_file:
                    object_data = object_file.read()
                upload_response = requests.put(upload_url, data=object_data)
                if upload_response is not None:
                    gr.Info(f"media s3 upload status: {upload_response.status_code}")
                else:
                    gr.Error(f"media s3 upload failed: {upload_response.status_code}")
                    raise Exception("S3 upload failed")
                dataset_mapping[file_path] = {"task_id": f"{user_state['unique_id']}"}
                updated_samples = [[x] for x in dataset_mapping.keys()]
                updated_dataset = gr.Dataset.update(
                    samples=updated_samples)
                return updated_dataset

            except FileNotFoundError as e:
                gr.Error(f"Couldn't find {file_path}. Please contact your system administrator for assistance")
                raise e
            except Exception as e:
                raise e

    def find_video(video: str):
        video_basename = os.path.basename(video)

        matching_key = [ x for x in dataset_mapping.keys() if os.path.basename(x) == video_basename]
        return dataset_mapping[matching_key[0]]

    def play_video(video: str):
        global dataset_mapping
        if is_demo_env == "Yes":
            dest_video = dataset_mapping_demo[video[0]]
        else:
            dest_video = find_video(video[0])

        if isinstance(dest_video, dict):
            task_id = dest_video['task_id']
            task_status_str = call_ssm_command(get_task_status_command_str + f" {task_id}", head_node)
            task_status = json.loads(task_status_str)
            pipeline_status = task_status["pipeline_status"]
            upscaled_video_location = task_status["upscaled_video_location"]
            if upscaled_video_location:
                show_dest_video = upscaled_video_location
            else:
                gr.Info(f"video upscaling task for {os.path.basename(video[0])} status: {pipeline_status}")
                show_dest_video = None # nothing to show, the upscaling process is in progress
        else:
            show_dest_video = dest_video
        return video[0], show_dest_video

    with gr.Row():
        # with gr.Column(scale=4):
        gr.Markdown('<b><p style="text-align: center; padding: 2px 100px;"><font family="Lucida Console" size="+5">AI VIDEO SUPER RESOLUTION ASSISTANT</font></p></b>')
    with gr.Row():
        gr.Markdown('<p style="text-align:center; color:grey;"><font size="+2">Upscale any standard resolution videos by 4x with GenAI in minutes</font></p>')
    with gr.Row():
        if is_demo_env == "Yes":
            samples = [[x] for x in dataset_mapping_demo.keys()]
        else:
            samples = [[x] for x in dataset_mapping.keys()]
        examples = gr.Dataset(components=[gr.Video(visible=False)],
                              samples=samples, label="Media Collection")
    with gr.Row():
        with gr.Column():
            source_video = default_source_video.render()
            with gr.Row():
                submit_button = gr.UploadButton(label="Upscale My Video!", visible=allow_user_upload, variant="primary")
                is_anime = gr.Checkbox(label="is anime", show_label=True, visible=allow_user_upload)
        with gr.Column():
            dest_video = default_dest_video.render()
    examples.click(play_video, inputs=[examples],outputs=[source_video, dest_video])
    submit_button.upload(upload_video, inputs=[submit_button, is_anime], outputs=[examples])

demo.queue()
if ("GRADIO_USERNAME" in os.environ) and ("GRADIO_PASSWORD" in os.environ):
  demo.launch(server_name="0.0.0.0", auth=(os.environ['GRADIO_USERNAME'], os.environ['GRADIO_PASSWORD']), allowed_paths=["img", "videos"] )
else:
  demo.launch(server_name="0.0.0.0", allowed_paths=["img", "videos"])
