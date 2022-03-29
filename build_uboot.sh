#!/bin/bash
set -e

CC=/opt/toolchains/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
ROOT_DIR=`pwd`
UBOOT_DIR=u-boot
VBOOT_DIR=${ROOT_DIR}/verified-boot/out2
CONFIG=vexpress_ca9x4_defconfig
BUILD_DIR=build

SECURE_BOOT=0
MENUCONFIG=0
CLEAN_BUILD=0
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
       -d|--defconfig)
            CONFIG=$2
            shift
            shift
            ;;
       -c|--clean)
            CLEAN_BUILD=1
            shift
            ;;
        -s|--secure)
            SECURE_BOOT=1
            shift
            ;;
        -m|--menuconfig)
            MENUCONFIG=1
            shift
            ;;
        *)
            echo "Invalid argument"
            exit 1
            ;;
    esac
done

pushd `pwd`
cd ${UBOOT_DIR}

if [[ ${SECURE_BOOT} -eq 1 ]]; then
    make O=${BUILD_DIR} ARCH=arm CROSS_COMPILE=${CC} EXT_DTB=${VBOOT_DIR}/vexpress-v2p-ca9-pubkey.dtb -j`nproc`
    popd
    exit 0
fi

if [[ ${CLEAN_BUILD} -eq 1 ]]; then
    make O=${BUILD_DIR} ARCH=arm CROSS_COMPILE=${CC} distclean
    make O=${BUILD_DIR} ARCH=arm CROSS_COMPILE=${CC} ${CONFIG}
fi

if [[ ${MENUCONFIG} -eq 1 ]]; then
    make O=${BUILD_DIR} ARCH=arm CROSS_COMPILE=${CC} menuconfig
    make O=${BUILD_DIR} ARCH=arm CROSS_COMPILE=${CC} savedefconfig
fi

make O=${BUILD_DIR} ARCH=arm CROSS_COMPILE=${CC} -j`nproc`

popd
