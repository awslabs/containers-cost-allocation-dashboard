# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

FROM --platform=$TARGETPLATFORM python:3.11.6-slim-bookworm AS build

RUN pip3 uninstall -y pip

RUN useradd -u 10001 worker -m
USER worker
WORKDIR /home/worker
ENV PATH="/home/worker/.local/bin:${PATH}"

RUN python3 -m ensurepip --user
RUN pip3 install --user --upgrade pip==23.3.1

COPY --chown=worker:worker requirements.txt .

RUN pip3 install --user -r requirements.txt

COPY --chown=worker:worker main.py .

CMD ["python3", "./main.py"]