# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

FROM --platform=$TARGETPLATFORM python:3.11.6-slim-bookworm

RUN set -ex \
    && apt-get update \
    && apt-get -y install libssl3=3.0.11-1~deb12u2 openssl=3.0.11-1~deb12u2 \
    && apt-get -y autoremove \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 uninstall -y pip

RUN useradd -u 10001 worker -m
USER worker
ENV PATH="/home/worker/.local/bin:${PATH}"

RUN python3 -m ensurepip --user
RUN pip3 install --user --upgrade pip==23.3.1

COPY --chown=worker:worker requirements.txt .
RUN pip3 install -r requirements.txt --target /home/worker/app
RUN pip3 uninstall -y pip

WORKDIR /home/worker/app
COPY --chown=worker:worker main.py .

CMD ["python3", "./main.py"]