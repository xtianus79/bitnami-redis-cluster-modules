# Stage 1: Build environment for RedisJSON with an appropriate Python version
FROM python:3.9 AS redisjson-build-env

# Install system dependencies and clean up in one layer
RUN apt-get update && \
    for i in $(seq 1 3); do \
        apt-get install -y --no-install-recommends build-essential git curl && break || sleep 15; \
    done && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 

# Set PATH for Rust
ENV PATH="/root/.cargo/bin:${PATH}"

# Clone and build RedisJSON
WORKDIR /build/redisjson
RUN git clone --recursive https://github.com/RedisJSON/RedisJSON.git . && \
    python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --upgrade pip setuptools wheel && \
    ./sbin/setup && \
    cargo build --release

# Verify the build artifacts for librejson.so
RUN echo "Verifying librejson.so build artifacts:" && \
    ls -la /build/redisjson/target/release/ && \
    echo "librejson.so build completed successfully if listed above."

# Stage 2: Build environment for RediSearch
FROM debian:bullseye-slim AS redisearch-build-env

# Install Python, build tools, CMake, and git
RUN apt-get update && \
    for i in $(seq 1 3); do \
        apt-get install -y --no-install-recommends \
        python3 python3-pip build-essential libboost-all-dev cmake git libssl-dev && break || sleep 15; \
    done && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Conan globally
RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install conan

# Verify Conan installation
RUN conan --version

# Clone and build RedisSearch
WORKDIR /build/redisearch
RUN git clone --recursive --branch v2.8.12 https://github.com/RediSearch/RediSearch.git .

# Build RediSearch and RediCoordination
RUN make COORD=1

# List the contents of the expected output directory to confirm the existence of build artifacts
RUN ls -la /build/redisearch/bin/linux-x64-release/coord-oss && \
    echo "module-oss.so build artifacts:" && \
    ls -la /build/redisearch/bin/linux-x64-release/coord-oss/module-oss.so && \
    echo "module-oss.so build completed successfully."

# Copy the libcrypto.so.1.1 and libssl.so.1.1 libraries from the Debian base image
RUN cp /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 /build/redisearch/ && \
    cp /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /build/redisearch/

# # Stage 3: Build environment for RediCoordination
# FROM debian:bullseye-slim AS rediscoordination-build-env

# # Install Python, build tools, CMake, git, OpenSSL development libraries, and other dependencies
# RUN apt-get update && \
#     for i in $(seq 1 3); do \
#         apt-get install -y --no-install-recommends \
#         python3 python3-pip python3-venv build-essential libboost-all-dev cmake git wget libssl-dev libuv1-dev && break || sleep 15; \
#     done && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Clone your forked RediSearch repository
# WORKDIR /build/redisearch
# RUN git clone --recursive https://github.com/xtianus79/RediSearch.git .

# # Install Boost 1.81.0
# RUN apt-get update && \
#     for i in $(seq 1 3); do \
#         apt-get install -y --no-install-recommends wget && break || sleep 15; \
#     done && \
#     mkdir /boost && \
#     cd /boost && \
#     wget https://boostorg.jfrog.io/artifactory/main/release/1.81.0/source/boost_1_81_0.tar.bz2 && \
#     tar -xvf boost_1_81_0.tar.bz2 && \
#     cd boost_1_81_0/ && \
#     ./bootstrap.sh && \
#     ./b2 install && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Set the LD_LIBRARY_PATH environment variable
# ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# # Set up the build environment
# RUN python3 -m venv venv && \
#     . venv/bin/activate && \
#     pip install --upgrade pip setuptools wheel && \
#     pip install conan

# # Build the project
# WORKDIR /build/redisearch/coord
# RUN mkdir build && \
#     cd build && \
#     cmake -DCOORD_TYPE=oss .. && \
#     make

# # After building, list the contents of the build directory to confirm the existence of module-oss.so
# RUN ls -la /build/redisearch/coord/build && \
#     echo "module-oss.so build artifacts:" && \
#     ls -la /build/redisearch/coord/build/module-oss.so && \
#     echo "module-oss.so build completed successfully."

# Stage 4: Build environment for RedisAI with GPU support
# FROM nvidia/cuda:12.3.1-devel-ubuntu20.04 AS redisai-build-env

# # Use DEBIAN_FRONTEND=noninteractive to avoid interactive prompts during build
# ENV DEBIAN_FRONTEND=noninteractive

# # Install base dependencies
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#     python3 python3-pip python3-venv \
#     git build-essential wget cmake unzip && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Copy the cuDNN local repository package
# COPY cudnn-local-repo-ubuntu2004-9.0.0_1.0-1_amd64.deb /tmp

# # Install the cuDNN local repository package
# RUN dpkg -i /tmp/cudnn-local-repo-ubuntu2004-9.0.0_1.0-1_amd64.deb && \
#     cp /var/cudnn-local-repo-ubuntu2004-9.0.0/cudnn-*-keyring.gpg /usr/share/keyrings/ && \
#     apt-get update && \
#     apt-get -y install cudnn-cuda-12

# # Set environment variables for dynamic linker
# ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# # Reset DEBIAN_FRONTEND to its default value
# ENV DEBIAN_FRONTEND=

# # [Insert additional installation steps here, such as CUDA if not included in the base image]

# # Clone RedisAI repository and setup virtual environment
# WORKDIR /build/redisai
# RUN git clone --recursive https://github.com/RedisAI/RedisAI.git . && \
#     python3 -m venv venv && \
#     . venv/bin/activate && \
#     pip install --upgrade pip setuptools wheel

# # Build dependencies with GPU support and build RedisAI module
# RUN bash get_deps.sh gpu && \
#     make -C opt clean ALL=1 && \
#     make -C opt GPU=1

# # After building, list the contents of the expected output directory
# # Adjust the path below if the build artifacts are placed in a different location
# # Confirm the existence of RedisAI build artifacts
# RUN echo "RedisAI build artifacts:" && \
#     ls -la /build/redisai/install-gpu

# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0
# Stage 5: Final image

FROM docker.io/bitnami/minideb:bookworm

ARG TARGETARCH

LABEL com.vmware.cp.artifact.flavor="sha256:c50c90cfd9d12b445b011e6ad529f1ad3daea45c26d20b00732fae3cd71f6a83" \
      org.opencontainers.image.base.name="docker.io/bitnami/minideb:bookworm" \
      org.opencontainers.image.created="2024-03-31T19:42:32Z" \
      org.opencontainers.image.description="Application packaged by VMware, Inc" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.ref.name="7.2.4-debian-12-r11" \
      org.opencontainers.image.title="redis-cluster" \
      org.opencontainers.image.vendor="VMware, Inc." \
      org.opencontainers.image.version="7.2.4"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
# Install required system packages and dependencies
USER root
RUN apt-get update && \
    apt-get install -y ca-certificates curl libgomp1 libssl3 procps libuv1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=redisjson-build-env /build/redisjson/target/release/librejson.so /opt/bitnami/redis/etc/rejson.so
# COPY --from=redisearch-build-env /build/redisearch/bin/linux-x64-release/search/redisearch.so /opt/bitnami/redis/etc/redisearch.so
COPY --from=redisearch-build-env /build/redisearch/bin/linux-x64-release/coord-oss/module-oss.so /opt/bitnami/redis/etc/module-oss.so

# Copy the libcrypto.so.1.1 and libssl.so.1.1 libraries from the redisearch-build-env stage
COPY --from=redisearch-build-env /build/redisearch/libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/
COPY --from=redisearch-build-env /build/redisearch/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/

# Ensure the library is found
RUN ldconfig

RUN mkdir -p /tmp/bitnami/pkg/cache/ ; cd /tmp/bitnami/pkg/cache/ ; \
    COMPONENTS=( \
      "wait-for-port-1.0.7-10-linux-${OS_ARCH}-debian-12" \
      "redis-7.2.4-3-linux-${OS_ARCH}-debian-12" \
    ) ; \
    for COMPONENT in "${COMPONENTS[@]}"; do \
      if [ ! -f "${COMPONENT}.tar.gz" ]; then \
        curl -SsLf "https://downloads.bitnami.com/files/stacksmith/${COMPONENT}.tar.gz" -O ; \
        curl -SsLf "https://downloads.bitnami.com/files/stacksmith/${COMPONENT}.tar.gz.sha256" -O ; \
      fi ; \
      sha256sum -c "${COMPONENT}.tar.gz.sha256" ; \
      tar -zxf "${COMPONENT}.tar.gz" -C /opt/bitnami --strip-components=2 --no-same-owner --wildcards '*/files' ; \
      rm -rf "${COMPONENT}".tar.gz{,.sha256} ; \
    done
RUN apt-get autoremove --purge -y curl && \
    apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt/bitnami
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

COPY rootfs /
RUN chmod +x /opt/bitnami/scripts/redis-cluster/postunpack.sh && /opt/bitnami/scripts/redis-cluster/postunpack.sh
# RUN /opt/bitnami/scripts/redis-cluster/postunpack.sh
ENV APP_VERSION="7.2.4" \
    BITNAMI_APP_NAME="redis-cluster" \
    PATH="/opt/bitnami/common/bin:/opt/bitnami/redis/bin:$PATH"

# Set modules allowance
RUN echo "enable-module-command yes" >> /opt/bitnami/redis/etc/redis.conf

# Set the execute permission for the entrypoint script
RUN chmod +x /opt/bitnami/scripts/redis-cluster/entrypoint.sh

# Set the execute permission for the setup script
RUN chmod +x /opt/bitnami/scripts/redis-cluster/setup.sh

# Set the execute permission for the run script
RUN chmod +x /opt/bitnami/scripts/redis-cluster/run.sh

EXPOSE 6379

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/redis-cluster/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/redis-cluster/run.sh" ]
