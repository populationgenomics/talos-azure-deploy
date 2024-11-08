# Generally speaking, we're just going to do the same things that the talos/Dockerfile does, but with a few modifications inserted where necessary.
# - Because we're starting from a different base image, we need to install Python 3.10 manually.
# - We're not going to bother installing the Google Cloud SDK, as we don't need it for the purposes of this image.
# - We're going to install the talos-deploy scripts/ directory
#
# The result is that we will have a single image that can be used to run both VEP and Talos. 
# This will simplify the process of configuring Azure Container Apps to run both tools.

FROM talosacr.azurecr.io/vep:release_110.1

ENV DEBIAN_FRONTEND=noninteractive

# Same first step as talos/Dockerfile, however we're also installing python3.10
RUN apt update && apt install -y --no-install-recommends \
        apt-transport-https \
        bzip2 \
        ca-certificates \
        git \
        gnupg \
        openjdk-11-jdk-headless \
        wget \
        zip \
        software-properties-common

# RUN add-apt-repository ppa:deadsnakes/ppa && \
#     apt-get update

#     && \
#     apt-get install -y --no-install-recommends python3.10 \
#     && \
#         rm -r /var/lib/apt/lists/* && \
#         rm -r /var/cache/apt/*

# RUN mkdir /talos
# WORKDIR /talos
# COPY talos/requirements*.txt talos/README.md talos/setup.py .
# COPY talos/src src/
# RUN pip install .[cpg]

# RUN mkdir /talos-deploy
# WORKDIR /talos-deploy
# COPY scripts scripts/

# ARG TALOS_BASE_IMAGE="talosacr.azurecr.io/talos:latest"
# FROM ${TALOS_BASE_IMAGE} as talos_base

# COPY scripts scripts/


