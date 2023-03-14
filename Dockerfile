# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

FROM --platform=$TARGETPLATFORM python:3.11.2-slim-bullseye AS build

RUN apt-get -y install openssl=1.1.1n-0+deb11u4 libssl1.1=1.1.1n-0+deb11u4 libgnutls30=3.7.1-5+deb11u3

RUN useradd -u 10001 worker -m
USER worker
WORKDIR /home/worker
ENV PATH="/home/worker/.local/bin:${PATH}"

RUN pip3 install --upgrade pip

COPY --chown=worker:worker requirements.txt .

RUN pip3 install -r requirements.txt

COPY --chown=worker:worker main.py .

CMD ["python3", "./main.py"]