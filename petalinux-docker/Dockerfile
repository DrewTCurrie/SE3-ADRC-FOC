FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive

# Setup for the Petalinux environment with packages and board support
RUN dpkg --add-architecture i386

RUN apt-get update && apt-get install -y \
    sudo make net-tools libncurses5-dev zlib1g-dev libssl-dev \
    flex bison libselinux1 gnupg wget xz-utils cpio libtinfo5 libstdc++6 \
    locales xterm autoconf libtool texinfo gcc-multilib build-essential \
    tofrodos iproute2 python3 python3-pip python3-pexpect diffstat chrpath \
    socat python3-pycryptodome python3-git python3-jinja2 python3-subunit \
    mesa-common-dev libegl1-mesa libsdl1.2-dev pylint xdg-utils qemu-user \
    gcc g++ make git autoconf automake libtool flex bison gawk libc6:i386 \
    libstdc++6:i386 libgcc1:i386 libncurses5:i386 zlib1g:i386 zlib1g-dev \
    libncurses5-dev libglib2.0-dev tftp tftpd-hpa dos2unix \
    tar unzip gzip xvfb curl patch bzip2 coreutils rsync lsb-release sed \
    findutils file bc time vim neovim iputils-ping dnsutils  \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN useradd -m -s /bin/bash builder && echo "builder:password" | chpasswd
RUN usermod -aG sudo builder
RUN echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER builder
WORKDIR /home/builder/workspace
SHELL ["/bin/bash","-c"]
ENV DISPLAY=:0
WORKDIR /home/builder/workspace
VOLUME /home/builder/workspace
