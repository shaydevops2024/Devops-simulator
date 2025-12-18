FROM python:3.11-slim
WORKDIR /app
RUN pip install aio-pika prometheus_client
COPY app ./app
CMD ["python", "app/worker.py"]

