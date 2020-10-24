ARG UBUNTU_VERSION=18.04
ARG BCC_VERSION=0.16.0
FROM datenlord/rust_bcc:ubuntu${UBUNTU_VERSION}-bcc${BCC_VERSION} as builder

ARG CWD=/tmp/rust_cargo
WORKDIR ${CWD}
COPY . .
RUN cargo build
CMD []
