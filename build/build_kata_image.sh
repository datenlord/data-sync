export ROOTFS_DIR=$PWD/rootfs-bionic/
sudo apt update && sudo apt install debootstrap qemu-utils
cd /tmp/go/src/github.com/kata-containers/osbuilder/rootfs-builder
sudo -E PATH=$PATH  GOPATH=$GOPATH AGENT_INIT=yes ./rootfs.sh -r $ROOTFS_DIR  ubuntu

cd ../initrd-builder/
sudo -E AGENT_INIT=yes ./initrd_builder.sh ${ROOTFS_DIR}

cd ../image-builder/
sudo -E ./image_builder.sh ${ROOTFS_DIR}
