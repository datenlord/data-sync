#! /bin/bash

set -xv # enable debug
set -e # exit on error
set -u # unset var as error

DIST=`lsb_release -i | awk '{print $3}'`
if [[ $DIST == Ubuntu ]]; then
   UBUNTU_VERSION=`lsb_release -r | awk '{print $2}'` 
   BCC_VERSION=0.16.0
   cargo clean
   cp /etc/apt/sources.list .
   docker build --build-arg UBUNTU_VERSION=$UBUNTU_VERSION --build-arg BCC_VERSION=$BCC_VERSION . -f Dockerfile -t datenlord/rust_bcc:ubuntu$UBUNTU_VERSION-bcc$BCC_VERSION
else
    echo "Only support Ubuntu" && /bin/false
fi
