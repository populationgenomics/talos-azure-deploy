FROM python:3.10-bullseye

RUN apt update && apt install -y --no-install-recommends \
        apt-transport-https \
        bzip2 \
        ca-certificates \
        git \
        gnupg \
        openjdk-11-jdk-headless \
        wget \
        zip && \
    rm -r /var/lib/apt/lists/* && \
    rm -r /var/cache/apt/*

COPY talos/requirements*.txt talos/README.md talos/setup.py .
COPY talos/src src/
RUN pip install .[cpg]

ENV REF_DIR=/talos-deploy/reference
ENV DATA_DIR=/talos-deploy/data

COPY scripts scripts/
