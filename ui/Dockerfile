FROM python:3.10
COPY . /workdir
WORKDIR /workdir
RUN pip install -r requirements.txt
EXPOSE 7860
ENV PYTHONUNBUFFERED=1
ENTRYPOINT [ "python" , "app.py" ]
