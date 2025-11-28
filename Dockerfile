# Ghost Walker Build Environment
# Based on Ubuntu with Theos toolchain

FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    perl \
    build-essential \
    clang \
    unzip \
    curl \
    wget \
    fakeroot \
    libtinfo5 \
    libplist-dev \
    dpkg \
    zstd \
    xz-utils \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Install libssl1.1 (needed by ldid)
RUN wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    rm libssl1.1_1.1.1f-1ubuntu2_amd64.deb

# Set up Theos
ENV THEOS=/theos
RUN git clone --recursive https://github.com/theos/theos.git $THEOS

# Download iOS SDK
RUN mkdir -p $THEOS/sdks && cd $THEOS/sdks && \
    curl -LO https://github.com/theos/sdks/archive/refs/heads/master.zip && \
    unzip -q master.zip && mv sdks-master/* . && rm -rf sdks-master master.zip

# Download and install toolchain
RUN mkdir -p $THEOS/toolchain/linux/iphone && cd /tmp && \
    curl -LO https://github.com/sbingner/llvm-project/releases/download/v10.0.0-1/linux-ios-arm64e-clang-toolchain.tar.lzma && \
    tar --lzma -xf linux-ios-arm64e-clang-toolchain.tar.lzma && \
    cp -r /tmp/*/* $THEOS/toolchain/linux/iphone/ 2>/dev/null || \
    cp -r /tmp/linux*/* $THEOS/toolchain/linux/iphone/ 2>/dev/null || \
    (ls -la /tmp && find /tmp -type d -name "bin" -exec cp -r {}/../* $THEOS/toolchain/linux/iphone/ \;) && \
    rm -rf /tmp/*

# Set working directory
WORKDIR /project

# Default command
CMD ["make", "package", "FINALPACKAGE=1", "THEOS_PACKAGE_SCHEME=rootless"]
