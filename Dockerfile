FROM python:3.11.1-slim-buster

RUN adduser -u 10001 worker
USER worker
WORKDIR /home/worker

RUN pip install --upgrade pip

COPY --chown=worker:worker requirements.txt .

RUN pip3 install --user -r requirements.txt

COPY --chown=worker:worker main.py .

CMD ["python3", "./main.py"]
