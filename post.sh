#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

#this is provided while using Utility OS
source /opt/bootstrap/functions

# --- Cleanup ---
if [ $freemem -lt 6291456 ]; then
    run "Cleaning up" \
        "killall dockerd &&
        sleep 3 &&
        swapoff $ROOTFS/swap &&
        rm $ROOTFS/swap &&
        rm -fr $ROOTFS/tmp/" \
        "$TMP/provisioning.log"
fi

umount $BOOTFS &&
    umount $ROOTFS &&
    if [[ $param_diskencrypt == 'true' ]]; then
        cryptsetup luksClose root 2>&1 | tee -a /dev/tty0
    fi

if [[ $param_release == 'prod' ]]; then
    poweroff
else
    reboot
fi
