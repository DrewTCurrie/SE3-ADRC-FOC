FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential kmod bc flex bison libssl-dev software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository -y universe && \
  apt update --snapshot 20250515T000000Z && \
  apt install --snapshot 20250515T000000Z linux-headers-6.8.0-1015-xilinx

WORKDIR /work

