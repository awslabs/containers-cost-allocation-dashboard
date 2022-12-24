FROM python:3.8-slim-buster

RUN pip install --upgrade pip

RUN adduser -u 10001 worker
USER worker
WORKDIR /home/worker

COPY --chown=worker:worker requirements.txt .

RUN pip3 install --user -r requirements.txt

COPY --chown=worker:worker main.py .

CMD ["python3", "./main.py"]
