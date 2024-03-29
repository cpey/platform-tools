#!/bin/bash
set -x

dir=$(dirname $0)
source ${dir}/config.sh
source ${dir}/helper.sh

SKIP_UBOOT=0
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -a|--arch)
            arch_arg="$2"
            shift
            shift
            ;;
        -c|--cmdline)
            cmdline_arg="$2"
            shift
            shift
            ;;
        -d|--dtb)
            dtb_arg="$2"
            shift
            shift
            ;;
        -f|--sd-card)
            sdcard_dfile_arg="$2"
            shift
            shift
            ;;
        -i|--initramfs)
            initramfs_arg="$2"
            shift
            shift
            ;;
        -k|--kernel)
            kernel_arg="$2"
            shift
            shift
            ;;
        -r|--rootfs)
            rootfs_arg="$2"
            shift
            shift
            ;;
        -s|--skip-uboot)
            SKIP_UBOOT=1
            shift
            ;;
        *)
            echo "Invalid argument"
            exit 1
            ;;
    esac
done

function mount_sdcard ()
{
	mounted=$(df ${DEV} | grep ${DEV})
	if [[ -n ${mounted} ]]; then
		return
	fi
	if [[ ! -d ${SDCARD_MOUNT_POINT} ]]; then
		mkdir ${SDCARD_MOUNT_POINT}
	fi
	sudo mount -o loop,rw ${sdcard_dfile} ${SDCARD_MOUNT_POINT}
}

function umount_sdcard ()
{
	mounted=$(df ${DEV} | grep ${DEV})
	if [[ -n ${mounted} ]]; then
	    sudo umount ${SDCARD_MOUNT_POINT}
	fi
	rm -r ${SDCARD_MOUNT_POINT}
}

function trap_ctrlc ()
{
    echo "Exiting..."
    umount_sdcard
}
trap "trap_ctrlc" 2

function parse_args ()
{
	if [[ ! -n ${sdcard_dfile_arg} ]]; then
		sdcard_dfile=${DEV_FILE}
	else
		sdcard_dfile=${sdcard_dfile_arg}
	fi

	if [[ ! -n ${kernel_arg} ]]; then
		mount_sdcard
		kernel=${SDCARD_MOUNT_POINT}/zImage
	else
		kernel=${kernel_arg}
	fi

	if [[ ! -n ${rootfs_arg} ]]; then
		mount_sdcard
		rootfs=${SDCARD_MOUNT_POINT}/rootfs.img
	else
		rootfs=${rootfs_arg}
	fi

	if [[ ! -n ${dtb_arg} ]]; then
		mount_sdcard
		dtb=${SDCARD_MOUNT_POINT}/vexpress-v2p-ca9.dtb
	else
		dtb=${dtb_arg}
	fi

	if [[ ! -n ${initramfs_arg} ]]; then
		initrd=""
	else
		initrd="-initrd ${initramfs_arg}"
	fi

	CMDLINE="root=/dev/mmcblk0 rw rootfstype=ext4 console=ttyAMA0"
	if [[ ! -n ${cmdline_arg} ]]; then
		cmdline=${CMDLINE}
	else
		cmdline="${CMDLINE} ${cmdline_arg}"
	fi

	if [[ ! -n ${arch_arg} ]]; then
		arch="arm"
	else
		arch=${arch_arg}
    fi
}

parse_args
qemu_bin=$(get_qemu_bin ${arch})

if [[ ${SKIP_UBOOT} -eq 1 ]]; then
	sudo ${qemu_bin} -M vexpress-a9 -m 1024 \
        ${initrd} \
		-serial stdio \
		-kernel ${kernel} \
		-dtb ${dtb} \
		-sd ${rootfs} \
		-append "${cmdline}" \
		-display none
else
	# --------------------------------
	# U-Boot commands for split images
	# --------------------------------
	# => fatload mmc 0:0 0x80200000 uImage
	# => fatload mmc 0:0 0x80100000 vexpress-v2p-ca9.dtb
	# => setenv bootargs 'root=/dev/mmcblk0p1 rw rootfstype=ext4 console=ttyAMA0'
	# => bootm 0x80200000 - 0x80100000

	# -----------------------------------
	# U-Boot commands to boot a FIT image
	# -----------------------------------
	# => fatload mmc 0:0 0x82000000 image.fit
	# => setenv bootargs 'root=/dev/mmcblk0p1 rw rootfstype=ext4 console=ttyAMA0'
	# => bootm 0x82000000
	sudo ${qemu_bin} -M vexpress-a9 -m 1024 \
        -sd ${sdcard_dfile} \
		-serial stdio \
		-kernel ${UBOOT}/${UBOOT_BIN} \
		-audiodev id=none,driver=none \
		-display none
fi
