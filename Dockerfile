FROM talosacr.azurecr.io/vep:release_110.1

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

# Since we're staring from a different base image than talos/Dockerfile, manually install 3.10
RUN apt-get install -y python3.10 python3.10-venv python3.10-dev python3-pip

RUN mkdir /talos
WORKDIR /talos
COPY talos/requirements*.txt talos/README.md talos/setup.py .
COPY talos/src src/
RUN pip install .[cpg]

RUN mkdir /talos-deploy
WORKDIR /talos-deploy
COPY scripts scripts/

# ARG TALOS_BASE_IMAGE="talosacr.azurecr.io/talos:latest"
# FROM ${TALOS_BASE_IMAGE} as talos_base

# COPY scripts scripts/


