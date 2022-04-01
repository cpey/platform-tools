#!/bin/sh

mount -t proc none /proc
mount -t sysfs none /sys

echo -e "\nBoot took \$(cut -d' ' -f1 /proc/uptime) seconds\n"
exec /bin/sh
