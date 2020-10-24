#! /bin/sh

docker run -it --rm --privileged -v /lib/modules:/lib/modules:ro -v /usr/src:/usr/src:ro -v /etc/localtime:/etc/localtime:ro -v /sys/kernel/debug:/sys/kernel/debug -v `pwd`:/tmp/rust_cargo datenlord/rust_bcc:ubuntu20.04-bcc0.17.0 /bin/bash
