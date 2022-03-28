#!/bin/bash

# This script prepares and image for the SD card to be emulated by QEMU as
# storage media
set -ex
DEV=/dev/loop0
DEV_FILE=loop
DEV_SIZE_G=1
SDCARD_MOUNT_POINT=sdcard

ROOT=`pwd`
LINUX=/home/cpey/dev/src/linux
UBOOT=${ROOT}/u-boot/
ROOTFS=${ROOT}/../debian-11.2-minimal-armhf-2021-12-20/armhf-rootfs-debian-bullseye.tar
VBOOT=${ROOT}/verified-boot/out2
ECDSA_PKEY_DTB=ecdsa_public_key.dtb

FIT_IMAGE=0
SETUP_DEVICE=0
ROOTFS=0
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
		-r|--rootfs)
			# Update rootfs
			ROOTFS=1
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
	OUT=$(losetup -l | { grep ${DEV} || true; } )
	echo $OUT
	[[ -n ${OUT} ]] && sudo losetup -d ${DEV} || echo loop0 device available
}

function setup_sdcard () 
{
	touch ${DEV_FILE}
	dd if=/dev/zero of=${DEV_FILE} bs=256 count=$((${DEV_SIZE_G} * 1024 ** 3 / 256))
	sudo losetup -P ${DEV} ${DEV_FILE}
	sleep 1
	sudo mkfs.vfat ${DEV}
	sudo sfdisk ${DEV} <<-__EOF__
	128M,,L,*
	__EOF__
}

function copy_os ()
{
	sudo mount ${DEV} ${SDCARD_MOUNT_POINT}
	if [[ ${FIT_IMAGE} -eq 0 ]]; then
		sudo cp ${LINUX}/arch/arm/boot/zImage ${SDCARD_MOUNT_POINT}
		sudo cp ${LINUX}/arch/arm/boot/uImage ${SDCARD_MOUNT_POINT}
		sudo cp ${LINUX}/arch/arm/boot/dts/*.dtb ${SDCARD_MOUNT_POINT}
	else
		sudo cp ${VBOOT}/image.fit ${SDCARD_MOUNT_POINT}
        if [[ ${ECDSA} -eq 1 ]]; then
		    sudo cp ${VBOOT}/${ECDSA_PKEY_DTB} ${SDCARD_MOUNT_POINT}
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
	sudo mount ${DEV}p1 ${SDCARD_MOUNT_POINT}
	sudo tar xvf ${ROOTFS} -C ${SDCARD_MOUNT_POINT}
	sync
	sudo umount ${DEV}p1
}

remove_loop_device
if [[ ${SETUP_DEVICE} -eq 1 ]]; then
	setup_sdcard
	sync
	# Force the kernel to scan the new partition table
	sudo losetup -d ${DEV}
	sudo losetup -P ${DEV} ${DEV_FILE}
	sudo mkfs.ext4 ${DEV}p1
else
	sudo losetup -P ${DEV} ${DEV_FILE}
fi

[[ -e ${SDCARD_MOUNT_POINT} ]] && rm -r ${SDCARD_MOUNT_POINT}
mkdir ${SDCARD_MOUNT_POINT}

copy_os
copy_uboot
if [[ ${SETUP_DEVICE} -eq 1 ]]; then
	copy_rootfs
fi

rm -r ${SDCARD_MOUNT_POINT}
echo Done
