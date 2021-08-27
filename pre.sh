#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

# --- Ubuntu Packages ---
ubuntu_packages="net-tools"
ubuntu_tasksel="" # standard

ntpd -d -N -q -n -p us.pool.ntp.org

PROVISION_LOG="/tmp/provisioning.log"
run "Begin provisioning process..." \
    "while (! docker ps > /dev/null ); do sleep 0.5; done" \
    ${PROVISION_LOG}

PROVISIONER=$1

# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

if [[ $kernel_params == *"proxy="* ]]; then
	tmp="${kernel_params##*proxy=}"
	export param_proxy="${tmp%% *}"

	export http_proxy=${param_proxy}
	export https_proxy=${param_proxy}
	export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
	export HTTP_PROXY=${param_proxy}
	export HTTPS_PROXY=${param_proxy}
	export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
	export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
	export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}';"
elif [ $( nc -vz -w 2 ${PROVISIONER} 3128; echo $?; ) -eq 0 ] && [ $( nc -vz -w 2 ${PROVISIONER} 4128; echo $?; ) -eq 0 ]; then
	PROXY_DOCKER_BIND="-v /tmp/ssl:/etc/ssl/ -v /usr/local/share/ca-certificates/EB.pem:/usr/local/share/ca-certificates/EB.crt"
    export http_proxy=http://${PROVISIONER}:3128/
	export https_proxy=http://${PROVISIONER}:4128/
	export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
	export HTTP_PROXY=http://${PROVISIONER}:3128/
	export HTTPS_PROXY=http://${PROVISIONER}:4128/
	export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
	export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}' ${PROXY_DOCKER_BIND}"
	export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}'; if [ ! -f /usr/local/share/ca-certificates/EB.crt ]; then if (! which wget > /dev/null ); then apt update && apt -y install wget; fi; wget -O - http://${PROVISIONER}/squid-cert/CA.pem > /usr/local/share/ca-certificates/EB.crt && update-ca-certificates; fi;"
    wget -O - http://${PROVISIONER}/squid-cert/CA.pem > /usr/local/share/ca-certificates/EB.pem
    update-ca-certificates
elif [ $( nc -vz -w 2 ${PROVISIONER} 3128; echo $?; ) -eq 0 ]; then
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

if [[ $kernel_params == *"wifissid="* ]]; then
	tmp="${kernel_params##*wifissid=}"
	export param_wifissid="${tmp%% *}"
elif [ ! -z "${SSID}" ]; then
	export param_wifissid="${SSID}"
fi

if [[ $kernel_params == *"wifipsk="* ]]; then
	tmp="${kernel_params##*wifipsk=}"
	export param_wifipsk="${tmp%% *}"
elif [ ! -z "${PSK}" ]; then
	export param_wifipsk="${PSK}"
fi

if [[ $kernel_params == *"network="* ]]; then
	tmp="${kernel_params##*network=}"
	export param_network="${tmp%% *}"
fi

if [[ $kernel_params == *"httppath="* ]]; then
	tmp="${kernel_params##*httppath=}"
	export param_httppath="${tmp%% *}"
fi

if [[ $kernel_params == *"parttype="* ]]; then
	tmp="${kernel_params##*parttype=}"
	export param_parttype="${tmp%% *}"
elif [ -d /sys/firmware/efi ]; then
	export param_parttype="efi"
else
	export param_parttype="msdos"
fi

if [[ $kernel_params == *"bootstrap="* ]]; then
	tmp="${kernel_params##*bootstrap=}"
	export param_bootstrap="${tmp%% *}"
	export param_bootstrapurl=$(echo $param_bootstrap | sed "s#/$(basename $param_bootstrap)\$##g")
fi

if [[ $kernel_params == *"basebranch="* ]]; then
	tmp="${kernel_params##*basebranch=}"
	export param_basebranch="${tmp%% *}"
fi

if [[ $kernel_params == *"token="* ]]; then
	tmp="${kernel_params##*token=}"
	export param_token="${tmp%% *}"
fi

if [[ $kernel_params == *"agent="* ]]; then
	tmp="${kernel_params##*agent=}"
	export param_agent="${tmp%% *}"
else
	export param_agent="master"
fi

if [[ $kernel_params == *"kernparam="* ]]; then
	tmp="${kernel_params##*kernparam=}"
	temp_param_kernparam="${tmp%% *}"
	export param_kernparam=$(echo ${temp_param_kernparam} | sed 's/#/ /g' | sed 's/:/=/g')
fi

if [[ $kernel_params == *"ubuntuversion="* ]]; then
	tmp="${kernel_params##*ubuntuversion=}"
	export param_ubuntuversion="${tmp%% *}"
else
	export param_ubuntuversion="cosmic"
fi

# The following is bandaid for Disco Dingo
if [ $param_ubuntuversion = "disco" ]; then
	export DOCKER_UBUNTU_RELEASE="cosmic"
else
	export DOCKER_UBUNTU_RELEASE=$param_ubuntuversion
fi

if [[ $kernel_params == *"arch="* ]]; then
	tmp="${kernel_params##*arch=}"
	export param_arch="${tmp%% *}"
else
	export param_arch="amd64"
fi

if [[ $kernel_params == *"kernelversion="* ]]; then
	tmp="${kernel_params##*kernelversion=}"
	export param_kernelversion="${tmp%% *}"
else
	export param_kernelversion="linux-image-generic"
fi

if [[ $kernel_params == *"insecurereg="* ]]; then
	tmp="${kernel_params##*insecurereg=}"
	export param_insecurereg="${tmp%% *}"
fi

if [[ $kernel_params == *"username="* ]]; then
	tmp="${kernel_params##*username=}"
	export param_username="${tmp%% *}"
else
	export param_username="sys-admin"
fi

if [[ $kernel_params == *"password="* ]]; then
	tmp="${kernel_params##*password=}"
	export param_password="${tmp%% *}"
else
	export param_password="password"
fi

if [[ $kernel_params == *"debug="* ]]; then
	tmp="${kernel_params##*debug=}"
	export param_debug="${tmp%% *}"
	export debug="${tmp%% *}"
fi

if [[ $kernel_params == *"release="* ]]; then
	tmp="${kernel_params##*release=}"
	export param_release="${tmp%% *}"
else
	export param_release='dev'
fi

if [[ $kernel_params == *"docker_login_user="* ]]; then
	tmp="${kernel_params##*docker_login_user=}"
	export param_docker_login_user="${tmp%% *}"
fi

if [[ $kernel_params == *"docker_login_pass="* ]]; then
	tmp="${kernel_params##*docker_login_pass=}"
	export param_docker_login_pass="${tmp%% *}"
fi

if [[ $param_release == 'prod' ]]; then
	export kernel_params="$param_kernparam" # ipv6.disable=1
else
	export kernel_params="$param_kernparam"
fi

MIRROR_STATUS=$(wget --method=HEAD http://${PROVISIONER}${param_httppath}/distro/ 2>&1 | grep "404 Not Found")
if [[ $kernel_params == *"mirror="* ]]; then
    tmp="${kernel_params##*mirror=}"
    export param_mirror="${tmp%% *}"
elif wget -q --method=HEAD http://${PROVISIONER}${param_httppath}/build/dists/${param_ubuntuversion}/InRelease; then
    export param_mirror="http://${PROVISIONER}${param_httppath}/build"
elif wget -q --method=HEAD http://${PROVISIONER}${param_httppath}/distro/dists/${param_ubuntuversion}/InRelease; then
    export param_mirror="http://${PROVISIONER}${param_httppath}/distro"
fi
if [ ! -z "${param_mirror}" ]; then
    export PKG_REPO_LIST=""
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}/main/binary-${param_arch}/Release; then
        export PKG_REPO_LIST="${PKG_REPO_LIST} main"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}/restricted/binary-${param_arch}/Release; then
        export PKG_REPO_LIST="${PKG_REPO_LIST} restricted"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}/universe/binary-${param_arch}/Release; then
        export PKG_REPO_LIST="${PKG_REPO_LIST} universe"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}/multiverse/binary-${param_arch}/Release; then
        export PKG_REPO_LIST="${PKG_REPO_LIST} multiverse"
    fi
    export PKG_REPO_SEC_LIST=""
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}-security/main/binary-${param_arch}/Release; then
        export PKG_REPO_SEC_LIST="${PKG_REPO_SEC_LIST} main"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}-security/restricted/binary-${param_arch}/Release; then
        export PKG_REPO_SEC_LIST="${PKG_REPO_SEC_LIST} restricted"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}-security/universe/binary-${param_arch}/Release; then
        export PKG_REPO_SEC_LIST="${PKG_REPO_SEC_LIST} universe"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}-security/multiverse/binary-${param_arch}/Release; then
        export PKG_REPO_SEC_LIST="${PKG_REPO_SEC_LIST} multiverse"
    fi
fi

# --- Get free memory
export freemem=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# --- Detect HDD ---
if [ -d /sys/block/nvme[0-9]n[0-9] ]; then
	export DRIVE=$(echo /dev/`ls -l /sys/block/nvme* | grep -v usb | head -n1 | sed 's/^.*\(nvme[a-z0-1]\+\).*$/\1/'`);
	export BOOT_PARTITION=${DRIVE}p1
	export SWAP_PARTITION=${DRIVE}p2
	export ROOT_PARTITION=${DRIVE}p3
elif [ -d /sys/block/[vsh]da ]; then
	export DRIVE=$(echo /dev/`ls -l /sys/block/[vsh]da | grep -v usb | head -n1 | sed 's/^.*\([vsh]d[a-z]\+\).*$/\1/'`);
	export BOOT_PARTITION=${DRIVE}1
	export SWAP_PARTITION=${DRIVE}2
	export ROOT_PARTITION=${DRIVE}3
elif [ -d /sys/block/mmcblk[0-9] ]; then
	export DRIVE=$(echo /dev/`ls -l /sys/block/mmcblk[0-9] | grep -v usb | head -n1 | sed 's/^.*\(mmcblk[0-9]\+\).*$/\1/'`);
	export BOOT_PARTITION=${DRIVE}p1
	export SWAP_PARTITION=${DRIVE}p2
	export ROOT_PARTITION=${DRIVE}p3
else
	echo "No supported drives found!" 2>&1 | tee -a /dev/console
	sleep 300
	reboot
fi

export BOOTFS=/target/boot
export ROOTFS=/target/root
mkdir -p $BOOTFS
mkdir -p $ROOTFS

echo "" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console
echo "Installing on ${DRIVE}" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console

# --- Partition HDD ---
run "Partitioning drive ${DRIVE}" \
    "if [[ $param_parttype == 'efi' ]]; then
        parted --script ${DRIVE} \
        mklabel gpt \
        mkpart ESP fat32 1MiB 551MiB \
        set 1 esp on \
        mkpart primary linux-swap 551MiB 1575MiB \
        mkpart primary 1575MiB 100%;
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
if [[ $param_parttype == 'efi' ]]; then
    run "Creating boot partition on drive ${DRIVE}" \
        "mkfs -t vfat -n BOOT ${BOOT_PARTITION} && \
        mkdir -p $BOOTFS && \
        mount ${BOOT_PARTITION} $BOOTFS" \
        ${PROVISION_LOG}
else
    run "Creating boot partition on drive ${DRIVE}" \
        "mkfs -t ext4 -L BOOT -F ${BOOT_PARTITION} && \
        e2label ${BOOT_PARTITION} BOOT && \
        mkdir -p $BOOTFS && \
        mount ${BOOT_PARTITION} $BOOTFS" \
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
    export TMP=/tmp
fi
export PROVISION_LOG="$TMP/provisioning.log"

if [ $(wget http://${PROVISIONER}:5557/v2/_catalog -O-) ] 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5557"
elif [ $(wget http://${PROVISIONER}:5000/v2/_catalog -O-) ] 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5000"
fi

# -- Configure Image database ---
run "Configuring Image Database" \
    "mkdir -p $ROOTFS/tmp/docker && \
    chmod 777 $ROOTFS/tmp && \
    killall dockerd && sleep 2 && \
    /usr/local/bin/dockerd ${REGISTRY_MIRROR} --data-root=$ROOTFS/tmp/docker > /dev/null 2>&1 &" \
    "$TMP/provisioning.log"

while (! docker ps > /dev/null ); do sleep 0.5; done; sleep 3

if [ ! -z "${param_docker_login_user}" ] && [ ! -z "${param_docker_login_pass}" ]; then
    run "Log in to a Docker registry" \
    	"docker login -u ${param_docker_login_user} -p ${param_docker_login_pass}" \
    	"$TMP/provisioning.log"
fi

# --- Begin Ubuntu Install Process ---
run "Preparing Ubuntu ${param_ubuntuversion} installer" \
    "docker pull ubuntu:${param_ubuntuversion}" \
    "$TMP/provisioning.log"


rootfs_partuuid=$(lsblk -no UUID ${ROOT_PARTITION})
bootfs_partuuid=$(lsblk -no UUID ${BOOT_PARTITION})
swapfs_partuuid=$(lsblk -no UUID ${SWAP_PARTITION})

if [[ $param_parttype == 'efi' ]]; then
    run "Installing Ubuntu ${param_ubuntuversion} (~10 min)" \
        "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
        'if [ \"${PKG_REPO_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion} ${PKG_REPO_LIST}\" > /etc/apt/sources.list; fi && \
        if [ \"${PKG_REPO_SEC_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion}-security ${PKG_REPO_SEC_LIST}\" >> /etc/apt/sources.list; fi && \
        apt update && \
        apt install -y debootstrap && \
        debootstrap --arch ${param_arch} ${param_ubuntuversion} /target/root ${param_mirror} && \
        if [ -z ${param_mirror} ]; then cp /etc/apt/sources.list /target/root/etc/apt/sources.list; fi && \
        if [ \"${PKG_REPO_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion} ${PKG_REPO_LIST}\" > /target/root/etc/apt/sources.list; fi && \
        if [ \"${PKG_REPO_SEC_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion}-security ${PKG_REPO_SEC_LIST}\" >> /target/root/etc/apt/sources.list; fi && \
        mount --bind dev /target/root/dev && \
        mount -t proc proc /target/root/proc && \
        mount -t sysfs sysfs /target/root/sys && \
        LANG=C.UTF-8 chroot /target/root sh -c \
            \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
            export DEBIAN_FRONTEND=noninteractive && \
            chmod a+rw /dev/null /dev/zero && \
            mkdir -p /boot/efi && \
            mount ${BOOT_PARTITION} /boot/efi && \
            apt update && \
            apt install -y wget ${param_kernelversion} && \
            apt install -y grub-efi shim && \
            \\\$(grub-install ${BOOT_PARTITION} --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --no-nvram; exit 0) && \
            update-grub && \
            adduser --quiet --disabled-password --shell /bin/bash --gecos \\\"\\\" ${param_username} && \
            addgroup --system admin && \
            echo \\\"${param_username}:${param_password}\\\" | chpasswd && \
            usermod -a -G admin ${param_username} && \
            if [ \\\"${ubuntu_tasksel}\\\" != "" ]; then \
                apt install -y tasksel && \
                tasksel install ${ubuntu_tasksel}; \
            fi && \
            if [ \\\"${ubuntu_packages}\\\" != "" ]; then apt install -y ${ubuntu_packages}; fi && \
            apt clean\"' && \
        wget --header \"Authorization: token ${param_token}\" -O - ${param_basebranch}/files/etc/fstab | sed -e \"s#ROOT#UUID=${rootfs_partuuid}#g\" | sed -e \"s#BOOT#UUID=${bootfs_partuuid}                 /boot/efi       vfat    umask=0077        0       1#g\" | sed -e \"s#SWAP#UUID=${swapfs_partuuid}#g\" > $ROOTFS/etc/fstab" \
        "$TMP/provisioning.log"

    EFI_BOOT_NAME="Ubuntu OS"
    run "EFI Boot Manager" \
        "efibootmgr -c -d ${DRIVE} -p 1 -L \"${EFI_BOOT_NAME}\" -l '\\EFI\\ubuntu\\grubx64.efi'" \
        "$TMP/provisioning.log"

    export MOUNT_DURING_INSTALL="chmod a+rw /dev/null /dev/zero && mount ${BOOT_PARTITION} /boot/efi"
else
    run "Installing Ubuntu ${param_ubuntuversion} (~10 min)" \
        "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
        'if [ \"${PKG_REPO_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion} ${PKG_REPO_LIST}\" > /etc/apt/sources.list; fi && \
        if [ \"${PKG_REPO_SEC_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion}-security ${PKG_REPO_SEC_LIST}\" >> /etc/apt/sources.list; fi && \
        apt update && \
        apt install -y debootstrap && \
        debootstrap --arch ${param_arch} ${param_ubuntuversion} /target/root ${param_mirror} && \
        if [ -z ${param_mirror} ]; then cp /etc/apt/sources.list /target/root/etc/apt/sources.list; fi && \
        if [ \"${PKG_REPO_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion} ${PKG_REPO_LIST}\" > /target/root/etc/apt/sources.list; fi && \
        if [ \"${PKG_REPO_SEC_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion}-security ${PKG_REPO_SEC_LIST}\" >> /target/root/etc/apt/sources.list; fi && \
        mount --bind dev /target/root/dev && \
        mount -t proc proc /target/root/proc && \
        mount -t sysfs sysfs /target/root/sys && \
        LANG=C.UTF-8 chroot /target/root sh -c \
            \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
            export DEBIAN_FRONTEND=noninteractive && \
            chmod a+rw /dev/null /dev/zero && \
            mount ${BOOT_PARTITION} /boot && \
            apt update && \
            apt install -y wget ${param_kernelversion} && \
            apt install -y grub-pc && \
            grub-install ${DRIVE} && \
            adduser --quiet --disabled-password --shell /bin/bash --gecos \\\"\\\" ${param_username} && \
            addgroup --system admin && \
            echo \\\"${param_username}:${param_password}\\\" | chpasswd && \
            usermod -a -G admin ${param_username} && \
            if [ \\\"${ubuntu_tasksel}\\\" != "" ]; then \
                apt install -y tasksel && \
                tasksel install ${ubuntu_tasksel}; \
            fi && \
            if [ \\\"${ubuntu_packages}\\\" != "" ]; then apt install -y ${ubuntu_packages}; fi && \
            apt clean\"' && \
        wget --header \"Authorization: token ${param_token}\" -O - ${param_basebranch}/files/etc/fstab | sed -e \"s#ROOT#UUID=${rootfs_partuuid}#g\" | sed -e \"s#BOOT#UUID=${bootfs_partuuid}                 /boot           ext4    defaults        0       2#g\" | sed -e \"s#SWAP#UUID=${swapfs_partuuid}#g\" > $ROOTFS/etc/fstab" \
        "$TMP/provisioning.log"

    export MOUNT_DURING_INSTALL="chmod a+rw /dev/null /dev/zero && mount ${BOOT_PARTITION} /boot"
fi

# --- Enabling Ubuntu boostrap items ---
HOSTNAME="ubuntu-$(tr </dev/urandom -dc a-f0-9 | head -c10)"
run "Enabling Ubuntu boostrap items" \
    "wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/system/show-ip.service ${param_basebranch}/systemd/show-ip.service && \
    mkdir -p $ROOTFS/etc/systemd/system/network-online.target.wants/ && \
    ln -s /etc/systemd/system/show-ip.service $ROOTFS/etc/systemd/system/network-online.target.wants/show-ip.service; \
    wget --header \"Authorization: token ${param_token}\" -O - ${param_basebranch}/files/etc/hosts | sed -e \"s#@@HOSTNAME@@#${HOSTNAME}#g\" > $ROOTFS/etc/hosts && \
    mkdir -p $ROOTFS/etc/systemd/network/ && \
    wget --header \"Authorization: token ${param_token}\" -O - ${param_basebranch}/files/etc/systemd/network/wired.network > $ROOTFS/etc/systemd/network/wired.network && \
    sed -i 's#^GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"#GRUB_CMDLINE_LINUX_DEFAULT=\"kvmgt vfio-iommu-type1 vfio-mdev i915.enable_gvt=1 kvm.ignore_msrs=1 intel_iommu=on drm.debug=0\"#' $ROOTFS/etc/default/grub && \
    echo \"${HOSTNAME}\" > $ROOTFS/etc/hostname && \
    echo \"LANG=en_US.UTF-8\" >> $ROOTFS/etc/default/locale && \
    docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
        'mount --bind dev /target/root/dev && \
        mount -t proc proc /target/root/proc && \
        mount -t sysfs sysfs /target/root/sys && \
        LANG=C.UTF-8 chroot /target/root sh -c \
        \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
        export DEBIAN_FRONTEND=noninteractive && \
        ${MOUNT_DURING_INSTALL} && \
        apt purge -y netplan.io && \
        rm -rf /etc/netplan && \
        systemctl enable systemd-networkd && \
        update-grub && \
        locale-gen --purge en_US.UTF-8 && \
        dpkg-reconfigure --frontend=noninteractive locales\"'" \
    "$TMP/provisioning.log"

if [ "${param_network}" == "bridged" ]; then
    run "Installing the bridged network" \
        "mkdir -p $ROOTFS/etc/systemd/network/ && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/wired.network ${param_basebranch}/files/etc/systemd/network/bridged/wired.network && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/bond0.netdev ${param_basebranch}/files/etc/systemd/network/bridged/bond0.netdev && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/bond0.network ${param_basebranch}/files/etc/systemd/network/bridged/bond0.network && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/br0.netdev ${param_basebranch}/files/etc/systemd/network/bridged/br0.netdev && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/br0.network ${param_basebranch}/files/etc/systemd/network/bridged/br0.network" \
        "$TMP/provisioning.log"

elif [ "${param_network}" == "network-manager" ]; then
    run "Installing Network Manager Packages on Ubuntu ${param_ubuntuversion}" \
        "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
        'mount --bind dev /target/root/dev && \
        mount -t proc proc /target/root/proc && \
        mount -t sysfs sysfs /target/root/sys && \
        LANG=C.UTF-8 chroot /target/root sh -c \
            \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
            export DEBIAN_FRONTEND=noninteractive && \
            apt install -y network-manager\"'" \
        ${PROVISION_LOG}
fi

if [ -d "/sys/class/ieee80211" ] && ( find /sys/class/net/wl* > /dev/null 2>&1 ); then
    if [ -n "${param_wifissid}" ]; then
        WIFI_NAME_ONBOARD=$(udevadm test-builtin net_id /sys/class/net/wl* 2> /dev/null | grep ID_NET_NAME_ONBOARD | awk -F'=' '{print $2}' | head -1)
        WIFI_NAME_PATH=$(udevadm test-builtin net_id /sys/class/net/wl* 2> /dev/null | grep ID_NET_NAME_PATH | awk -F'=' '{print $2}' | head -1)
        if [ ! -z ${WIFI_NAME_ONBOARD} ]; then 
            WIFI_NAME=${WIFI_NAME_ONBOARD} 
        else 
            WIFI_NAME=${WIFI_NAME_PATH}
        fi
        if [ "${param_network}" == "bridged" ]; then
            run "Installing Wifi on Ubuntu ${param_ubuntuversion}" \
                "wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/wireless.network ${param_basebranch}/files/etc/systemd/network/bridged/wireless.network.template && \
                sed -i -e \"s#@@WIFI_NAME@@#${WIFI_NAME}#g\" $ROOTFS/etc/systemd/network/wireless.network && \
                sed -i -e \"s#@@WPA_SSID@@#${param_wifissid}#g\" $ROOTFS/etc/systemd/network/wireless.network && \
                sed -i -e \"s#@@WPA_PSK@@#${param_wifipsk}#g\" $ROOTFS/etc/systemd/network/wireless.network" \
                ${PROVISION_LOG}
        elif [ "${param_network}" == "network-manager" ]; then
            run "Installing Wifi on Ubuntu ${param_ubuntuversion}" \
                "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
                'mount --bind dev /target/root/dev && \
                mount -t proc proc /target/root/proc && \
                mount -t sysfs sysfs /target/root/sys && \
                LANG=C.UTF-8 chroot /target/root sh -c \
                    \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
                    export DEBIAN_FRONTEND=noninteractive && \
                    nmcli radio wifi on && \
                    nmcli dev wifi connect ${param_wifissid} password '${param_wifipsk}' || true \"'" \
                ${PROVISION_LOG}
        else
            run "Installing Wifi on Ubuntu ${param_ubuntuversion}" \
                "wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/wireless.network ${param_basebranch}/files/etc/systemd/network/wireless.network.template && \
                sed -i -e \"s#@@WIFI_NAME@@#${WIFI_NAME}#g\" $ROOTFS/etc/systemd/network/wireless.network && \
                sed -i -e \"s#@@WPA_SSID@@#${param_wifissid}#g\" $ROOTFS/etc/systemd/network/wireless.network && \
                sed -i -e \"s#@@WPA_PSK@@#${param_wifipsk}#g\" $ROOTFS/etc/systemd/network/wireless.network" \
                ${PROVISION_LOG}
        fi

        run "Installing Wireless Packages on Ubuntu ${param_ubuntuversion}" \
            "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
            'mount --bind dev /target/root/dev && \
            mount -t proc proc /target/root/proc && \
            mount -t sysfs sysfs /target/root/sys && \
            LANG=C.UTF-8 chroot /target/root sh -c \
                \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
                export DEBIAN_FRONTEND=noninteractive && \
                ${MOUNT_DURING_INSTALL} && \
                apt install -y wireless-tools wpasupplicant && \
                mkdir -p /etc/wpa_supplicant && \
                wpa_passphrase ${param_wifissid} '${param_wifipsk}' > /etc/wpa_supplicant/wpa_supplicant-${WIFI_NAME}.conf && \
                systemctl enable wpa_supplicant@${WIFI_NAME}.service\"'" \
            ${PROVISION_LOG}
    fi
fi

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

# Check for local docker repo
if [ ! -z "${param_mirror}" ]; then
    if wget -q --method=HEAD ${param_mirror}/docker/dists/${param_ubuntuversion}/stable/binary-${param_arch}/Release; then
        echo "deb [arch=amd64] ${param_mirror} ${param_ubuntuversion} stable" >> $ROOTFS/etc/apt/sources.list
    fi
fi

run "Installing Docker on Ubuntu ${param_ubuntuversion}" \
    "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
    'mount --bind dev /target/root/dev && \
    mount -t proc proc /target/root/proc && \
    mount -t sysfs sysfs /target/root/sys && \
    LANG=C.UTF-8 chroot /target/root sh -c \
        \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
        export DEBIAN_FRONTEND=noninteractive && \
        ${MOUNT_DURING_INSTALL} && \
        apt-get update && \
        DOCKER_PKG=$(apt-cache search docker-ce) && \
        if [ \\\"${DOCKER_PKG}\\\" != \\\"\\\" ]; then \
            echo \\\"package exists\\\"; \
        else \
            apt install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg-agent \
            software-properties-common && \
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - && \
            apt-key fingerprint 0EBFCD88 && \
            sudo add-apt-repository \\\"deb [arch=amd64] https://download.docker.com/linux/ubuntu ${DOCKER_UBUNTU_RELEASE} stable\\\" && \
            apt-get update;
        fi && \
        apt-get install -y docker-ce docker-ce-cli containerd.io\"'" \
    "$TMP/provisioning.log"

if [ ! -z "${param_insecurereg}" ]; then
    mkdir -p $ROOTFS/etc/docker &&
    echo "{\"insecure-registries\": [\"${param_insecurereg}\"]}" >$ROOTFS/etc/docker/daemon.json
fi

# --- Create system-docker database on $ROOTFS ---
run "Preparing system-docker database" \
    "mkdir -p $ROOTFS/var/lib/docker && \
    docker run -d --privileged --name system-docker ${DOCKER_PROXY_ENV} -v $ROOTFS/var/lib/docker:/var/lib/docker docker:stable-dind ${REGISTRY_MIRROR}" \
    "$TMP/provisioning.log"

# --- Installing docker compose ---
run "Installing Docker Compose" \
    "mkdir -p $ROOTFS/usr/local/bin/ && \
    if wget -q --method=HEAD ${param_mirror}/docker/docker-compose; then \
        wget -O $ROOTFS/usr/local/bin/docker-compose \"${param_mirror}/docker/docker-compose\"; \
    else \
        wget -O $ROOTFS/usr/local/bin/docker-compose \"https://github.com/docker/compose/releases/download/1.26.0/docker-compose-$(uname -s)-$(uname -m)\"; \
    fi && \
    chmod a+x $ROOTFS/usr/local/bin/docker-compose" \
    "$TMP/provisioning.log"
