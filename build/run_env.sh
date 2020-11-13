#! /bin/sh
DOCKER_ENV_1=datenlord/rust_bcc:ubuntu20.04-bcc0.17.0
DOCKER_ENV_2=rust-bcc-test-env


WORK_DIR=/home/pwang/rust_cargo/rust-bcc
docker run -it --rm --privileged -v /lib/modules:/lib/modules:ro -v /usr/src:/usr/src:ro -v /etc/localtime:/etc/localtime:ro -v /sys/kernel/debug:/sys/kernel/debug -v `pwd`:$WORK_DIR $DOCKER_ENV_1 /bin/bash

WORK_DIR=/tmp/rust_cargo
docker run --privileged --rm --runtime=kata-runtime -it -v `pwd`:$WORK_DIR -e BCC=0.17.0 -e BUILD_BCC_INSIDE_KATA=false -e FEATURES=v0_17_0 -e LLVM=9 -e WORK_DIR=$WORK_DIR -e STATIC=true $DOCKER_ENV_2 /bin/bash
