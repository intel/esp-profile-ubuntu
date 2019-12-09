#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

#this is provided while using Utility OS
source /opt/bootstrap/functions

PROVISION_LOG="/tmp/provisioning.log"
run "Begin provisioning process..." \
    "sleep 0.5" \
    ${PROVISION_LOG}

PROVISIONER=$1

# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

if [[ $kernel_params == *"proxy="* ]]; then
    tmp="${kernel_params##*proxy=}"
    param_proxy="${tmp%% *}"

    export http_proxy=${param_proxy}
    export https_proxy=${param_proxy}
    export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
    export HTTP_PROXY=${param_proxy}
    export HTTPS_PROXY=${param_proxy}
    export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
    export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
    export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}';"
elif [ $(
    nc -vz ${PROVISIONER} 3128
    echo $?
) -eq 0 ]; then
    export http_proxy=http://${PROVISIONER}:3128/
    export https_proxy=http://${PROVISIONER}:3128/
    export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
    export HTTP_PROXY=http://${PROVISIONER}:3128/
    export HTTPS_PROXY=http://${PROVISIONER}:3128/
    export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
    export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
    export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}';"
fi

if [[ $kernel_params == *"proxysocks="* ]]; then
    tmp="${kernel_params##*proxysocks=}"
    param_proxysocks="${tmp%% *}"

    export FTP_PROXY=${param_proxysocks}

    tmp_socks=$(echo ${param_proxysocks} | sed "s#http://##g" | sed "s#https://##g" | sed "s#/##g")
    export SSH_PROXY_CMD="-o ProxyCommand='nc -x ${tmp_socks} %h %p'"
fi

if [[ $kernel_params == *"httppath="* ]]; then
    tmp="${kernel_params##*httppath=}"
    param_httppath="${tmp%% *}"
fi

if [[ $kernel_params == *"parttype="* ]]; then
    tmp="${kernel_params##*parttype=}"
    param_parttype="${tmp%% *}"
elif [ -d /sys/firmware/efi ]; then
    param_parttype="efi"
else
    param_parttype="msdos"
fi

if [[ $kernel_params == *"bootstrap="* ]]; then
    tmp="${kernel_params##*bootstrap=}"
    param_bootstrap="${tmp%% *}"
    param_bootstrapurl=$(echo $param_bootstrap | sed "s#/$(basename $param_bootstrap)\$##g")
fi

if [[ $kernel_params == *"token="* ]]; then
    tmp="${kernel_params##*token=}"
    param_token="${tmp%% *}"
fi

if [[ $kernel_params == *"agent="* ]]; then
    tmp="${kernel_params##*agent=}"
    param_agent="${tmp%% *}"
else
    param_agent="master"
fi

if [[ $kernel_params == *"kernparam="* ]]; then
    tmp="${kernel_params##*kernparam=}"
    temp_param_kernparam="${tmp%% *}"
    param_kernparam=$(echo ${temp_param_kernparam} | sed 's/#/ /g' | sed 's/:/=/g')
fi

if [[ $kernel_params == *"ubuntuversion="* ]]; then
    tmp="${kernel_params##*ubuntuversion=}"
    param_ubuntuversion="${tmp%% *}"
else
    param_ubuntuversion="cosmic"
fi

# The following is bandaid for Disco Dingo
if [ $param_ubuntuversion = "disco" ]; then
    DOCKER_UBUNTU_RELEASE="cosmic"
else
    DOCKER_UBUNTU_RELEASE=$param_ubuntuversion
fi

if [[ $kernel_params == *"arch="* ]]; then
    tmp="${kernel_params##*arch=}"
    param_arch="${tmp%% *}"
else
    param_arch="amd64"
fi

if [[ $kernel_params == *"insecurereg="* ]]; then
    tmp="${kernel_params##*insecurereg=}"
    param_insecurereg="${tmp%% *}"
fi

if [[ $kernel_params == *"username="* ]]; then
    tmp="${kernel_params##*username=}"
    param_username="${tmp%% *}"
else
    param_username="sys-admin"
fi

if [[ $kernel_params == *"password="* ]]; then
    tmp="${kernel_params##*password=}"
    param_password="${tmp%% *}"
else
    param_password="password"
fi

if [[ $kernel_params == *"debug="* ]]; then
    tmp="${kernel_params##*debug=}"
    param_debug="${tmp%% *}"
fi

if [[ $kernel_params == *"release="* ]]; then
    tmp="${kernel_params##*release=}"
    param_release="${tmp%% *}"
else
    param_release='dev'
fi

if [[ $param_release == 'prod' ]]; then
    kernel_params="$param_kernparam" # ipv6.disable=1
else
    kernel_params="$param_kernparam"
fi

# --- Config
ubuntu_bundles="standard openssh-server"
ubuntu_packages="net-tools"

pull_sysdockerimagelist=""
wget_sysdockerimagelist=""

# --- Get free memory
freemem=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# --- Detect HDD ---
if [ -d /sys/block/[vsh]da ]; then
    export DRIVE=$(echo /dev/$(ls -l /sys/block/[vsh]da | grep -v usb | head -n1 | sed 's/^.*\([vsh]d[a-z]\+\).*$/\1/'))
    if [[ $param_parttype == 'efi' ]]; then
        export EFI_PARTITION=${DRIVE}1
        export BOOT_PARTITION=${DRIVE}2
        export SWAP_PARTITION=${DRIVE}3
        export ROOT_PARTITION=${DRIVE}4
    else
        export BOOT_PARTITION=${DRIVE}1
        export SWAP_PARTITION=${DRIVE}2
        export ROOT_PARTITION=${DRIVE}3
    fi
elif [ -d /sys/block/nvme[0-9]n[0-9] ]; then
    export DRIVE=$(echo /dev/$(ls -l /sys/block/nvme* | grep -v usb | head -n1 | sed 's/^.*\(nvme[a-z0-1]\+\).*$/\1/'))
    if [[ $param_parttype == 'efi' ]]; then
        export EFI_PARTITION=${DRIVE}p1
        export BOOT_PARTITION=${DRIVE}p2
        export SWAP_PARTITION=${DRIVE}p3
        export ROOT_PARTITION=${DRIVE}p4
    else
        export BOOT_PARTITION=${DRIVE}p1
        export SWAP_PARTITION=${DRIVE}p2
        export ROOT_PARTITION=${DRIVE}p3
    fi
elif [ -d /sys/block/mmcblk[0-9] ]; then
    export DRIVE=$(echo /dev/$(ls -l /sys/block/mmcblk[0-9] | grep -v usb | head -n1 | sed 's/^.*\(mmcblk[0-9]\+\).*$/\1/'))
    if [[ $param_parttype == 'efi' ]]; then
        export EFI_PARTITION=${DRIVE}p1
        export BOOT_PARTITION=${DRIVE}p2
        export SWAP_PARTITION=${DRIVE}p3
        export ROOT_PARTITION=${DRIVE}p4
    else
        export BOOT_PARTITION=${DRIVE}p1
        export SWAP_PARTITION=${DRIVE}p2
        export ROOT_PARTITION=${DRIVE}p3
    fi
else
    echo "No supported drives found!" 2>&1 | tee -a /dev/tty0
    sleep 300
    reboot
fi

export BOOTFS=/target/boot
export ROOTFS=/target/root
mkdir -p $BOOTFS
mkdir -p $ROOTFS

echo "" 2>&1 | tee -a /dev/tty0
echo "" 2>&1 | tee -a /dev/tty0
echo "Installing on ${DRIVE}" 2>&1 | tee -a /dev/tty0
echo "" 2>&1 | tee -a /dev/tty0
echo "" 2>&1 | tee -a /dev/tty0

# --- Partition HDD ---
run "Partitioning drive ${DRIVE}" \
    "if [[ $param_parttype == 'efi' ]]; then
        parted --script ${DRIVE} \
        mklabel gpt \
        mkpart ESP fat32 1MiB 256MiB \
        set 1 esp on \
        mkpart primary ext4 256MiB 807MiB \
        mkpart primary linux-swap 807MiB 1831MiB \
        mkpart primary 1831MiB 100%;
    else
        parted --script ${DRIVE} \
        mklabel msdos \
        mkpart primary ext4 1MiB 551MiB \
        set 1 boot on \
        mkpart primary linux-swap 551MiB 1575MiB \
        mkpart primary 1575MiB 100%;
    fi" \
    ${PROVISION_LOG}

# --- Create file systems ---
run "Creating boot partition on drive ${DRIVE}" \
    "mkfs -t ext4 -L BOOT -F ${BOOT_PARTITION} && \
    e2label ${BOOT_PARTITION} BOOT && \
    mkdir -p $BOOTFS && \
    mount ${BOOT_PARTITION} $BOOTFS" \
    ${PROVISION_LOG}

if [[ $param_parttype == 'efi' ]]; then
    export EFIFS=$BOOTFS/efi
    mkdir -p $EFIFS
    run "Creating efi boot partition on drive ${DRIVE}" \
        "mkfs -t vfat -n BOOT ${EFI_PARTITION} && \
        mkdir -p $EFIFS && \
        mount ${EFI_PARTITION} $EFIFS" \
        ${PROVISION_LOG}
fi

# --- Create ROOT file system ---
run "Creating root file system" \
    "mkfs -t ext4 ${ROOT_PARTITION} && \
    mount ${ROOT_PARTITION} $ROOTFS && \
    e2label ${ROOT_PARTITION} STATE_PARTITION" \
    ${PROVISION_LOG}

run "Creating swap file system" \
    "mkswap ${SWAP_PARTITION}" \
    ${PROVISION_LOG}

# --- check if we need to add memory ---
if [ $freemem -lt 6291456 ]; then
    fallocate -l 2G $ROOTFS/swap
    chmod 600 $ROOTFS/swap
    mkswap $ROOTFS/swap
    swapon $ROOTFS/swap
fi

# --- check if we need to move tmp folder ---
if [ $freemem -lt 6291456 ]; then
    mkdir -p $ROOTFS/tmp
    export TMP=$ROOTFS/tmp
else
    mkdir -p /build
    export TMP=/build
fi

if [ $(wget http://${PROVISIONER}:5000/v2/_catalog -O-) ] 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5000"
fi

run "Configuring Image Database" \
    "mkdir -p $ROOTFS/tmp/docker && \
    chmod 777 $ROOTFS/tmp && \
    killall dockerd && sleep 2 && \
    /usr/local/bin/dockerd ${REGISTRY_MIRROR} --data-root=$ROOTFS/tmp/docker > /dev/null 2>&1 &" \
    "$TMP/provisioning.log"

sleep 2

# --- Begin Ubuntu Install Process ---
run "Preparing Ubuntu ${param_ubuntuversion} installer" \
    "docker pull ubuntu:${param_ubuntuversion}" \
    "$TMP/provisioning.log"

if [[ $param_parttype == 'efi' ]]; then
    run "Installing Ubuntu ${param_ubuntuversion} (~10 min)" \
        "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
        'apt update && \
        apt install -y debootstrap && \
        debootstrap --arch ${param_arch} ${param_ubuntuversion} /target/root && \
        mount --bind dev /target/root/dev && \
        mount -t proc proc /target/root/proc && \
        mount -t sysfs sysfs /target/root/sys && \
        LANG=C.UTF-8 chroot /target/root sh -c \
        \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
        export DEBIAN_FRONTEND=noninteractive && \
        mount ${BOOT_PARTITION} /boot && \
        mount ${EFI_PARTITION} /boot/efi && \
        echo \\\"deb http://security.ubuntu.com/ubuntu ${param_ubuntuversion}-security main\\\" >> /etc/apt/sources.list  && \
        echo \\\"deb-src http://security.ubuntu.com/ubuntu ${param_ubuntuversion}-security main\\\" >> /etc/apt/sources.list  && \
        apt update && \
        apt install -y wget linux-image-generic && \
        apt install -y grub-efi shim && \
        \\\$(grub-install ${EFI_PARTITION} --target=x86_64-efi --efi-directory=/boot/efi --bootloader=ubuntu; exit 0) && \
        echo \\\"search.fs_uuid $(lsblk -no UUID ${BOOT_PARTITION}) root\nset prefix=(\\\\\\\$root)\\\\\\\"/grub\\\\\\\"\nconfigfile \\\\\\\$prefix/grub.cfg\\\" > /boot/efi/EFI/ubuntu/grub.cfg && \
        update-grub && \
        adduser --quiet --disabled-password --shell /bin/bash --gecos \\\"\\\" ${param_username} && \
        addgroup --system admin && \
        echo \\\"${param_username}:${param_password}\\\" | chpasswd && \
        usermod -a -G admin ${param_username} && \
        apt install -y tasksel && \
        tasksel install ${ubuntu_bundles} && \
        apt install -y ${ubuntu_packages} && \
        apt clean\"' && \
        wget --header \"Authorization: token ${param_token}\" -O - ${param_bootstrapurl}/files/etc/fstab | sed -e \"s#ROOT#${ROOT_PARTITION}#g\" | sed -e \"s#BOOT#${BOOT_PARTITION}#g\" | sed -e \"s#SWAP#${SWAP_PARTITION}#g\" > $ROOTFS/etc/fstab && \
        echo \"${EFI_PARTITION}  /boot/efi       vfat    umask=0077      0       1\" >> $ROOTFS/etc/fstab" \
        "$TMP/provisioning.log"
else
    run "Installing Ubuntu ${param_ubuntuversion} (~10 min)" \
        "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
        'apt update && \
        apt install -y debootstrap && \
        debootstrap --arch ${param_arch} ${param_ubuntuversion} /target/root && \
        mount --bind dev /target/root/dev && \
        mount -t proc proc /target/root/proc && \
        mount -t sysfs sysfs /target/root/sys && \
        LANG=C.UTF-8 chroot /target/root sh -c \
        \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
        export DEBIAN_FRONTEND=noninteractive && \
        mount ${BOOT_PARTITION} /boot && \
        echo \\\"deb http://security.ubuntu.com/ubuntu ${param_ubuntuversion}-security main\\\" >> /etc/apt/sources.list  && \
        echo \\\"deb-src http://security.ubuntu.com/ubuntu ${param_ubuntuversion}-security main\\\" >> /etc/apt/sources.list  && \
        apt update && \
        apt install -y wget linux-image-generic && \
        apt install -y grub-pc && \
        grub-install ${DRIVE} && \
        adduser --quiet --disabled-password --shell /bin/bash --gecos \\\"\\\" ${param_username} && \
        addgroup --system admin && \
        echo \\\"${param_username}:${param_password}\\\" | chpasswd && \
        usermod -a -G admin ${param_username} && \
        apt install -y tasksel && \
        tasksel install ${ubuntu_bundles} && \
        apt install -y ${ubuntu_packages} && \
        apt clean\"' && \
        wget --header \"Authorization: token ${param_token}\" -O - ${param_bootstrapurl}/files/etc/fstab | sed -e \"s#ROOT#${ROOT_PARTITION}#g\" | sed -e \"s#BOOT#${BOOT_PARTITION}#g\" | sed -e \"s#SWAP#${SWAP_PARTITION}#g\" > $ROOTFS/etc/fstab" \
        "$TMP/provisioning.log"
fi

# --- Enabling Ubuntu boostrap items ---
HOSTNAME="ubuntu-$(tr </dev/urandom -dc a-f0-9 | head -c8)"
run "Enabling Ubuntu boostrap items" \
    "wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/system/show-ip.service ${param_bootstrapurl}/systemd/show-ip.service && \
    mkdir -p $ROOTFS/etc/systemd/system/network-online.target.wants/ && \
    ln -s /etc/systemd/system/show-ip.service $ROOTFS/etc/systemd/system/network-online.target.wants/show-ip.service; \
    wget --header \"Authorization: token ${param_token}\" -O - ${param_bootstrapurl}/files/etc/hosts | sed -e \"s#@@HOSTNAME@@#${HOSTNAME}#g\" > $ROOTFS/etc/hosts && \
    mkdir -p $ROOTFS/etc/systemd/network/ && \
    wget --header \"Authorization: token ${param_token}\" -O - ${param_bootstrapurl}/files/etc/systemd/network/wired.network > $ROOTFS/etc/systemd/network/wired.network && \
    sed -i 's#^GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"#GRUB_CMDLINE_LINUX_DEFAULT=\"kvmgt vfio-iommu-type1 vfio-mdev i915.enable_gvt=1 kvm.ignore_msrs=1 intel_iommu=on drm.debug=0\"#' $ROOTFS/etc/default/grub && \
    echo \"${HOSTNAME}\" > $ROOTFS/etc/hostname && \
    echo \"LANG=en_US.UTF-8\" >> $ROOTFS/etc/default/locale && \
    docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root -v $BOOTFS:/target/root/boot ubuntu:${param_ubuntuversion} sh -c \
    'mount --bind dev /target/root/dev && \
    mount -t proc proc /target/root/proc && \
    mount -t sysfs sysfs /target/root/sys && \
    LANG=C.UTF-8 chroot /target/root sh -c \
    \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
    export DEBIAN_FRONTEND=noninteractive && \
    systemctl enable systemd-networkd && \
    update-grub && \
    locale-gen --purge en_US.UTF-8 && \
    dpkg-reconfigure --frontend=noninteractive locales\"'" \
    "$TMP/provisioning.log"

run "Enabling Kernel Modules at boot time" \
    "mkdir -p $ROOTFS/etc/modules-load.d/ && \
    echo 'kvmgt' > $ROOTFS/etc/modules-load.d/kvmgt.conf && \
    echo 'vfio-iommu-type1' > $ROOTFS/etc/modules-load.d/vfio.conf && \
    echo 'dm-crypt' > $ROOTFS/etc/modules-load.d/dm-crypt.conf && \
    echo 'fuse' > $ROOTFS/etc/modules-load.d/fuse.conf && \
    echo 'nbd' > $ROOTFS/etc/modules-load.d/nbd.conf && \
    echo 'i915 enable_gvt=1' > $ROOTFS/etc/modules-load.d/i915.conf" \
    "$TMP/provisioning.log"

if [ -f $ROOTFS/etc/skel/.bashrc ]; then
    sed -i 's|#force_color_prompt=yes|force_color_prompt=yes|g' -f $ROOTFS/etc/skel/.bashrc
fi
if [ -f $ROOTFS/root/.bashrc ]; then
    sed -i 's|#force_color_prompt=yes|force_color_prompt=yes|g' -f $ROOTFS/root/.bashrc
fi
if [ -f $ROOTFS/home/${param_username}/.bashrc ]; then
    sed -i 's|#force_color_prompt=yes|force_color_prompt=yes|g' -f $ROOTFS/home/${param_username}/.bashrc
fi

if [ ! -z "${param_proxy}" ]; then
    run "Enabling Proxy Environment Variables" \
        "echo -e '\
        http_proxy=${param_proxy}\n\
        https_proxy=${param_proxy}\n\
        no_proxy=localhost,127.0.0.1\n\
        HTTP_PROXY=${param_proxy}\n\
        HTTPS_PROXY=${param_proxy}\n\
        NO_PROXY=localhost,127.0.0.1' >> $ROOTFS/etc/environment && \
        mkdir -p $ROOTFS/etc/systemd/system/docker.service.d && \
        echo -e '\
        [Service]\n\
        Environment=\"HTTPS_PROXY=${param_proxy}\" \"HTTP_PROXY=${param_proxy}\" \"NO_PROXY=localhost,127.0.0.1\"' > $ROOTFS/etc/systemd/system/docker.service.d/https-proxy.conf && \
        mkdir -p $ROOTFS/root/ && \
        echo 'source /etc/environment' >> $ROOTFS/root/.bashrc" \
        "$TMP/provisioning.log"
fi

if [ ! -z "${param_proxysocks}" ]; then
    run "Enabling Socks Proxy Environment Variables" \
        "echo -e '\
        ftp_proxy=${param_proxysocks}\n\
        FTP_PROXY=${param_proxysocks}' >> $ROOTFS/etc/environment" \
        "$TMP/provisioning.log"
fi

# --- Install Extra Packages ---
run "Installing Docker on Ubuntu ${param_ubuntuversion}" \
    "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
    'mount --bind dev /target/root/dev && \
    mount -t proc proc /target/root/proc && \
    mount -t sysfs sysfs /target/root/sys && \
    LANG=C.UTF-8 chroot /target/root sh -c \
    \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - && \
    apt-key fingerprint 0EBFCD88 && \
    sudo add-apt-repository \\\"deb [arch=amd64] https://download.docker.com/linux/ubuntu ${DOCKER_UBUNTU_RELEASE} stable\\\" && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io\"'" \
    "$TMP/provisioning.log"

# --- If an insecure registry was provided, update config to allow it
if [ ! -z "${param_insecurereg}" ]; then
    mkdir -p $ROOTFS/etc/docker &&
    echo "{\"insecure-registries\": [\"${param_insecurereg}\"]}" >$ROOTFS/etc/docker/daemon.json
fi

# --- Create system-docker database on $ROOTFS ---
run "Preparing system-docker database" \
    "mkdir -p $ROOTFS/var/lib/docker && \
    docker run -d --privileged --name system-docker ${DOCKER_PROXY_ENV} -v $ROOTFS/var/lib/docker:/var/lib/docker docker:dind ${REGISTRY_MIRROR}" \
    "$TMP/provisioning.log"

# --- Pull any and load any system images ---
for image in $pull_sysdockerimagelist; do
    run "Installing system-docker image $image" \
        "docker exec -i system-docker docker pull $image" \
        "$TMP/provisioning.log"
done

for image in $wget_sysdockerimagelist; do
    run "Installing system-docker image $image" \
        "wget -O- $image 2>> $TMP/provisioning.log | docker exec -i system-docker docker load" \
        "$TMP/provisioning.log"
done

# --- Preload Software Stack ---
run "Installing Docker Compose" \
    "mkdir -p $ROOTFS/usr/local/bin/ && \
    wget -O $ROOTFS/usr/local/bin/docker-compose \"https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)\" && \
    chmod a+x $ROOTFS/usr/local/bin/docker-compose" \
    "$TMP/provisioning.log"

# Add here any software you want pre installed.

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
