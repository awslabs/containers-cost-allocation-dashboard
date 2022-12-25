FROM --platform=$TARGETPLATFORM python:3.11.1-slim-bullseye AS build

RUN useradd -u 10001 worker
USER worker
WORKDIR /home/worker
ENV PATH="/home/worker/.local/bin:${PATH}"

RUN pip3 install --upgrade pip

COPY --chown=worker:worker requirements.txt .

RUN pip3 install -r requirements.txt

COPY --chown=worker:worker main.py .

CMD ["python3", "./main.py"]