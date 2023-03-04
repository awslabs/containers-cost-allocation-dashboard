# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

FROM --platform=$TARGETPLATFORM python:3.11.2-slim-bullseye AS build

RUN useradd -u 10001 worker -m
USER worker
WORKDIR /home/worker
ENV PATH="/home/worker/.local/bin:${PATH}"

RUN pip3 install --upgrade pip

COPY --chown=worker:worker requirements.txt .

RUN pip3 install -r requirements.txt

COPY --chown=worker:worker main.py .

CMD ["python3", "./main.py"]