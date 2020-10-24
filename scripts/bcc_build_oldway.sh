#!/bin/bash

set -xv # enable debug
set -e # exit on error
set -u # unset var as error

BCC=$1
LLVM=$2
STATIC=$3

## Update apt
apt-get update

## Determine version number format for CLANG/LLVM packages
if [[ "${LLVM}" == "6" ]]; then
    export LLVM_PACKAGE="6.0";
else
    export LLVM_PACKAGE="${LLVM}"
fi

## Install libc debugging symbols
apt-get --yes install libc6-dbg

## Install kernel headers
#apt-get --yes install linux-headers-"$(uname -r)"
apt-get --yes install libssl-dev libelf-dev
dpkg --install linux-headers-*.deb || (echo "You need to download linux-headers-$(uname -r)*.deb first" && /bin/false)
## Install dependencies
apt-get remove *llvm* *clang* *gtk*
apt-get --yes install clang-"${LLVM_PACKAGE}" \
    libclang-"${LLVM_PACKAGE}"-dev libelf-dev libfl-dev \
    llvm-"${LLVM_PACKAGE}"-dev libz-dev llvm-"${LLVM_PACKAGE}"

# For static builds, we need to compile the following
if [[ $STATIC == true ]]; then
    export CPPFLAGS="-P"
    export CFLAGS="-fPIC"

    apt-get --yes install build-essential curl git cmake autoconf libtool pkg-config bison python binutils zlib1g-dev liblzma-dev libncurses-dev libxml2-dev elfutils

    #echo "build binutils"
    #curl -L -O ftp://sourceware.org/pub/binutils/snapshots/binutils-2.34.90.tar.xz
    #tar xf binutils-2.34.90.tar.xz
    #cd binutils-2.34.90
    #./configure --prefix=/usr
    #make -j2
    #make install
    #cd ..

    #echo "build zlib"
    #curl -L -O https://zlib.net/zlib-1.2.11.tar.gz
    #tar xzf zlib-1.2.11.tar.gz
    #cd zlib-1.2.11
    #./configure --prefix=/usr
    #make -j2
    #make install
    #cd ..

    #echo "build xz"
    #curl -L -O https://tukaani.org/xz/xz-5.2.5.tar.gz
    #tar xzf xz-5.2.5.tar.gz
    #cd xz-5.2.5
    #./configure --prefix=/usr
    #make -j2
    #make install
    #cd ..

    #echo "build ncurses"
    #curl -L -O ftp://ftp.invisible-island.net/ncurses/ncurses-6.2.tar.gz
    #tar xzf ncurses-6.2.tar.gz
    #cd ncurses-6.2
    #./configure --prefix=/usr --with-termlib
    #make -j2
    #make install
    #cd ..

    #echo "build libxml2"
    #git clone https://gitlab.gnome.org/GNOME/libxml2
    #cd libxml2
    #git checkout 41a34e1f4ffae2ce401600dbb5fe43f8fe402641
    #autoreconf -fvi
    #./configure --prefix=/usr --without-python
    #make -j2
    #make install
    #cd ..

    #echo "build elfutils"
    #curl -L -O ftp://sourceware.org/pub/elfutils/0.180/elfutils-0.180.tar.bz2
    #tar xjf elfutils-0.180.tar.bz2
    #cd elfutils-0.180
    #./configure --prefix=/usr --disable-debuginfod
    #make -j2
    #make install
    #cd ..
fi

## build/install BCC
#git clone https://github.com/iovisor/bcc || true
cd bcc
git checkout master
git pull
if [[ "${BCC}" == "0.4.0" ]]; then
    git checkout remotes/origin/tag_v0.4.0
elif [[ "${BCC}" == "0.5.0" ]]; then
    git checkout remotes/origin/tag_v0.5.0
elif [[ "${BCC}" == "0.6.0" ]]; then
    git checkout remotes/origin/tag_v0.6.0
elif [[ "${BCC}" == "0.6.1" ]]; then
    git checkout remotes/origin/tag_v0.6.1
elif [[ "${BCC}" == "0.7.0" ]]; then
    git checkout remotes/origin/tag_v0.7.0
elif [[ "${BCC}" == "0.8.0" ]]; then
    git checkout remotes/origin/tag_v0.8.0
elif [[ "${BCC}" == "0.9.0" ]]; then
    git checkout remotes/origin/tag_v0.9.0
elif [[ "${BCC}" == "0.10.0" ]]; then
    git checkout remotes/origin/tag_v0.10.0
elif [[ "${BCC}" == "0.11.0" ]]; then
    git checkout 0fa419a64e71984d42f107c210d3d3f0cc82d59a
elif [[ "${BCC}" == "0.12.0" ]]; then
    git checkout 368a5b0714961953f3e3f61607fa16cb71449c1b
elif [[ "${BCC}" == "0.13.0" ]]; then
    git checkout 942227484d3207f6a42103674001ef01fb5335a0
elif [[ "${BCC}" == "0.14.0" ]]; then
    git checkout ceb458d6a07a42d8d6d3c16a3b8e387b5131d610
elif [[ "${BCC}" == "0.15.0" ]]; then
    git checkout e41f7a3be5c8114ef6a0990e50c2fbabea0e928e
elif [[ "${BCC}" == "0.16.0" ]]; then
    git checkout fecd934a9c0ff581890d218ff6c5101694e9b326
elif [[ "${BCC}" == "0.17.0" ]]; then
    git checkout tags/v${BCC}
fi
mkdir -p _build
cd _build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j2
make install
find . -name "*.a" -exec cp -v {} /usr/lib/ \;
cd ../..
