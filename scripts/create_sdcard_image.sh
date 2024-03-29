#!/bin/bash

# This script prepares an image for the SD card to be emulated by QEMU as
# storage media. It will result in a VFAT partition containing the rootfs
# image.

set -ex

dir=$(dirname $0)
source ${dir}/config.sh

DEV_SIZE_G=2

FIT_IMAGE=0
SETUP_DEVICE=0
ECDSA=0
while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		-f|--fit)
			FIT_IMAGE=1
			shift
			;;
		-e|--ecdsa)
            # Used together with `-f`, to add ecdsa public key dtb
			ECDSA=1
			shift
			;;
		-s|--setup)
			SETUP_DEVICE=1
			shift
			;;
		-a|--add)
			ADD_FILE=$2
			shift
			shift
			;;
		*)
			echo "Invalid argument"
			exit 1
			;;
	esac
done

function trap_ctrlc ()
{
	echo "Exiting..."
	exit 130
}
trap "trap_ctrlc" 2

function remove_loop_device ()
{
	OUT=$(lsblk | { grep ${DEV_NAME}p1 || true; })
	[[ -n ${OUT} ]] && sudo umount ${DEV}p1 || echo loop0p1 device not mounted
	OUT=$(lsblk | { grep ${DEV_NAME} || true; })
	[[ -n ${OUT} ]] && sudo umount ${DEV} || echo loop0 device not mounted
	OUT=$(losetup -l | { grep ${DEV} || true; })
	[[ -n ${OUT} ]] && sudo losetup -d ${DEV} || echo loop0 device available
}

function setup_sdcard () 
{
	touch ${DEV_FILE_N_ROOTFS}
	dd if=/dev/zero of=${DEV_FILE_N_ROOTFS} bs=256 count=$((${DEV_SIZE_G} * 1024 ** 3 / 256))
	sudo losetup -P ${DEV} ${DEV_FILE_N_ROOTFS}
	sleep 1
	sudo mkfs.vfat ${DEV}
}

function copy_os ()
{
	sudo mount ${DEV} ${SDCARD_MOUNT_POINT}
	if [[ ${FIT_IMAGE} -eq 0 ]]; then
		sudo cp ${LINUX}/arch/arm/boot/zImage ${SDCARD_MOUNT_POINT}
		sudo cp ${LINUX}/arch/arm/boot/uImage ${SDCARD_MOUNT_POINT}
		sudo cp ${LINUX}/arch/arm/boot/dts/*.dtb ${SDCARD_MOUNT_POINT}
	else
		sudo cp ${VBOOT}/${VBOOT_OUT}/image.fit ${SDCARD_MOUNT_POINT}
		if [[ ${ECDSA} -eq 1 ]]; then
			sudo cp ${VBOOT}/${VBOOT_OUT}/${ECDSA_PKEY_DTB} ${SDCARD_MOUNT_POINT}
		fi
	fi
	sync
    sudo umount ${DEV}
}

function copy_uboot ()
{
	sudo mount ${DEV} ${SDCARD_MOUNT_POINT}
	sudo cp ${UBOOT}/build/u-boot ${SDCARD_MOUNT_POINT}
	sudo umount ${DEV}
}

function copy_rootfs ()
{
	sudo mount ${DEV} ${SDCARD_MOUNT_POINT}
	sudo cp ${DEV_FILE_ROOTFS} ${SDCARD_MOUNT_POINT}
	sync
	sudo umount ${DEV}
}

function copy_extra ()
{
	[[ ! -n ${ADD_FILE} ]] && return
	sudo mount ${DEV} ${SDCARD_MOUNT_POINT}
	sudo cp ${ADD_FILE} ${SDCARD_MOUNT_POINT}
	sync
	sudo umount ${DEV}
}

remove_loop_device

[[ ! -e ${OUT_DIR} ]] && mkdir ${OUT_DIR}

if [[ ${SETUP_DEVICE} -eq 1 ]]; then
	setup_sdcard
	sync
	# Force the kernel to scan the new partition table
	sudo losetup -d ${DEV}
	sudo losetup -P ${DEV} ${DEV_FILE_N_ROOTFS}
else
	sudo losetup -P ${DEV} ${DEV_FILE_N_ROOTFS}
fi

[[ -e ${SDCARD_MOUNT_POINT} ]] && rm -r ${SDCARD_MOUNT_POINT}
mkdir ${SDCARD_MOUNT_POINT}

copy_os
copy_uboot
if [[ ${SETUP_DEVICE} -eq 1 ]]; then
	copy_rootfs
fi
copy_extra

rm -r ${SDCARD_MOUNT_POINT}
remove_loop_device
echo Done
