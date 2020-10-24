#! /bin/bash

set -xv # enable debug
set -e # exit on error
set -u # unset var as error

BCC=$1
LLVM=$2

apt-get update
apt-get --yes install bison build-essential cmake flex git libedit-dev python zlib1g-dev libelf-dev llvm-$LLVM-dev libclang-$LLVM-dev
git clone https://github.com/iovisor/bcc.git
mkdir bcc/build; cd bcc/build
git checkout tags/v$BCC
cmake ..
make install
cmake -DPYTHON_CMD=python3 .. # build python3 binding
pushd src/python/
apt-get --yes install python3-distutils
make
make install
popd
find . -name "*.a" -exec cp -v {} /usr/lib/ \; # copy static lib
apt-get --yes install libxml2-dev liblzma-dev # used by rust-bcc
