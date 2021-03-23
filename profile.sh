#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

PROVISIONER=$1

# --- Add Packages
ubuntu_bundles="openssh-server"
ubuntu_packages=""

# --- List out any docker images you want pre-installed separated by spaces. ---
pull_sysdockerimagelist=""

# --- List out any docker tar images you want pre-installed separated by spaces.  We be pulled by wget. ---
wget_sysdockerimagelist=""

# --- Install Extra Packages ---
run "Installing Extra Packages on Ubuntu ${param_ubuntuversion}" \
    "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
    'mount --bind dev /target/root/dev && \
    mount -t proc proc /target/root/proc && \
    mount -t sysfs sysfs /target/root/sys && \
    LANG=C.UTF-8 chroot /target/root sh -c \
        \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
        mount ${BOOT_PARTITION} /boot && \
        export DEBIAN_FRONTEND=noninteractive && \
        apt install -y tasksel && \
        tasksel install ${ubuntu_bundles} && \
        apt install -y ${ubuntu_packages} && \
	apt install -y --install-recommends linux-generic-hwe-18.04 && \
        update-grub\"'" \
    ${PROVISION_LOG}


esm_params=$(cat /proc/cmdline)

if [[ $esm_params == *"product_key="* ]]; then
    tmp="${esm_params##*product_key=}"
    export param_product_key="${tmp%% *}"
fi

if [[ $esm_params == *"docker_registry="* ]]; then
    tmp="${esm_params##*docker_registry=}"
    export param_docker_registry="${tmp%% *}"
fi

if [[ $esm_params == *"edge_id="* ]]; then
    tmp="${esm_params##*edge_id=}"
    export param_edge_id="${tmp%% *}"
fi

if [[ $esm_params == *"recipe_container_name="* ]]; then
    tmp="${esm_params##*recipe_container_name=}"
    export param_recipe_container_name="${tmp%% *}"
fi

param_hostname=$(cat $ROOTFS/etc/hostname)

run "Writing Edge Configuration Paramteres to Environment Variables" \
    "echo -e '\
    PRODUCT_KEY=${param_product_key}\n\
    HOSTNAME=${param_hostname}\n\
    DOCKER_REGISTRY=${param_docker_registry}\n\
    EDGE_ID=${param_edge_id}\n\
    RECIPE_CONTAINER_NAME=${param_recipe_container_name}'>> $ROOTFS/etc/environment_profile" \
    ${PROVISION_LOG}

chmod 600 $ROOTFS/etc/environment_profile

run "Enable ESM systemd service" \
    "mkdir -p $ROOTFS/opt/esm/stacks && \
    wget -O $ROOTFS/opt/esm/stacks/docker-compose.yml ${param_bootstrapurl}/esm/stacks/docker-compose.yml && \
    wget -O $ROOTFS/opt/esm/stacks/docker-compose-agent.yml ${param_bootstrapurl}/esm/stacks/docker-compose-agent.yml && \
    wget -O $ROOTFS/etc/systemd/system/esm.service ${param_bootstrapurl}/esm/systemd/esm.service && \
    ln -s /etc/systemd/system/esm.service $ROOTFS/etc/systemd/system/multi-user.target.wants/esm.service" \
    ${PROVISION_LOG}


run "Add CA certificate to docker certs.d directory" \
    "mkdir -p $ROOTFS/etc/docker/certs.d/${param_docker_registry} && \
    wget -O $ROOTFS/etc/docker/certs.d/${param_docker_registry}/esm-ca.crt ${param_bootstrapurl}/esm-ca.crt" \
     ${PROVISION_LOG}

if [ ! -z "${param_proxy}" ]; then
    run "Update no_proxy environment variable" \
        "sed -i 's#no_proxy=localhost,127.0.0.1#no_proxy=localhost,127.0.0.1,${PROVISIONER}#g' $ROOTFS/etc/environment && \
        sed -i 's#NO_PROXY=localhost,127.0.0.1#NO_PROXY=localhost,127.0.0.1,${PROVISIONER}#g' $ROOTFS/etc/environment && \
        sed -i 's#NO_PROXY=localhost,127.0.0.1#NO_PROXY=localhost,127.0.0.1,${PROVISIONER}#g' $ROOTFS/etc/systemd/system/docker.service.d/https-proxy.conf && \
	echo -e '\
        http_proxy=${param_proxy}\n\
        https_proxy=${param_proxy}\n\
        HTTP_PROXY=${param_proxy}\n\
        HTTPS_PROXY=${param_proxy}' >> $ROOTFS/etc/environment_profile" \
        ${PROVISION_LOG}
fi

run "Enabling Serial console" \
    "sed -i 's#^GRUB_CMDLINE_LINUX_DEFAULT=\"kvmgt vfio-iommu-type1 vfio-mdev i915.enable_gvt=1 kvm.ignore_msrs=1 intel_iommu=on drm.debug=0\"#GRUB_CMDLINE_LINUX_DEFAULT=\"kvmgt vfio-iommu-type1 vfio-mdev i915.enable_gvt=1 kvm.ignore_msrs=1 intel_iommu=on drm.debug=0 console=ttyS0 console=tty0\"#' $ROOTFS/etc/default/grub && \
    docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root -v $BOOTFS:/target/root/boot ubuntu:${param_ubuntuversion} sh -c \
    'mount --bind dev /target/root/dev && \
    mount -t proc proc /target/root/proc && \
    mount -t sysfs sysfs /target/root/sys && \
    LANG=C.UTF-8 chroot /target/root sh -c \
    \"$(echo ${INLINE_PROXY} | sed "s#'#\\\\\"#g") export TERM=xterm-color && \
    export DEBIAN_FRONTEND=noninteractive && \
    update-grub\"'" \
    "$TMP/provisioning.log"

# --- Pull any and load any system images ---
for image in $pull_sysdockerimagelist; do
        run "Installing system-docker image $image" "docker exec -i system-docker docker pull $image" "$TMP/provisioning.log"
done

for image in $wget_sysdockerimagelist; do
        run "Installing system-docker image $image" "wget -O- $image 2>> $TMP/provisioning.log | docker exec -i system-docker docker load" "$TMP/provisioning.log"
done
