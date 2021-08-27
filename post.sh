#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

#this is provided while using Utility OS
source /opt/bootstrap/functions

# --- Cleanup ---
if [ ! -z "${param_docker_login_user}" ] && [ ! -z "${param_docker_login_pass}" ]; then
    run "Logout from a Docker registry" \
        "docker logout" \
        "$TMP/provisioning.log"
fi

if [ $freemem -lt 6291456 ]; then
    run "Cleaning up" \
        "killall dockerd &&
        sleep 3 &&
        swapoff $ROOTFS/swap &&
        rm $ROOTFS/swap &&
        while (! rm -fr $ROOTFS/tmp/ > /dev/null ); do sleep 2; done" \
        "$TMP/provisioning.log"
fi

umount $BOOTFS &&
umount $ROOTFS &&
if [[ $param_diskencrypt == 'true' ]]; then
    cryptsetup luksClose root 2>&1 | tee -a /dev/console
fi

if [[ $param_release == 'prod' ]]; then
    poweroff
else
    reboot
fi
