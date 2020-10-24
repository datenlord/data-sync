ARG UBUNTU_VERSION=bionic
FROM ubuntu:${UBUNTU_VERSION} as builder

ARG BCC_VERSION=0.16.0
ARG LLVM_VERSION=9
ARG STATIC_BUILD=true
WORKDIR /tmp/build
COPY . .
COPY sources.list /etc/apt/sources.list
ENV DEBIAN_FRONTEND=noninteractive 
RUN scripts/bcc_build.sh $BCC_VERSION $LLVM_VERSION

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        libc6-dev \
        wget \
        ; \
    \
    url="https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init"; \
    wget "$url"; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --default-toolchain nightly; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
    rustup --version; \
    cargo --version; \
    rustc --version; \
    \
    apt-get remove -y --auto-remove \
        wget \
        ; \
    rm -rf /var/lib/apt/lists/*;
ENV RUSTFLAGS="-L /usr/lib -L /usr/lib64 -L /usr/lib/x86_64-linux-gnu -L /usr/lib/llvm-${LLVM_VERSION}/lib"