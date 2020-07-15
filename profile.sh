#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

# --- Add Packages
ubuntu_bundles="openssh-server"
ubuntu_packages=""

# --- List out any docker images you want pre-installed separated by spaces. ---
pull_sysdockerimagelist="\
    portainer/agent:1.6.0"

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
        export DEBIAN_FRONTEND=noninteractive && \
        apt install -y tasksel && \
        tasksel install ${ubuntu_bundles} && \
        apt install -y ${ubuntu_packages}\"'" \
    ${PROVISION_LOG}

# --- Get ESH parameters
run "Reading Edge Configuration Paramteres" \
    "wget -O /opt/esm-cfg.yml ${param_bootstrapurl}/conf/esm-cfg.yml" \
    ${PROVISION_LOG}
    
esm_params=$(cat /opt/esm-cfg.yml)

if [[ $esm_params == *"product_key="* ]]; then
    tmp="${esm_params##*product_key=}"
    export param_product_key="${tmp%% *}"
fi

if [[ $esm_params == *"docker_registry="* ]]; then
    tmp="${esm_params##*docker_registry=}"
    export param_docker_registry="${tmp%% *}"
fi

if [[ $esm_params == *"portainer_url="* ]]; then
    tmp="${esm_params##*portainer_url=}"
    export param_portainer_url="${tmp%% *}"
fi

if [[ $esm_params == *"portainer_admin_username="* ]]; then
    tmp="${esm_params##*portainer_admin_username=}"
    export param_portainer_admin_username="${tmp%% *}"
fi

if [[ $esm_params == *"portainer_admin_password="* ]]; then
    tmp="${esm_params##*portainer_admin_password=}"
    export param_portainer_admin_password="${tmp%% *}"
fi

run "Writing Edge Configuration Paramteres to Environment Variables" \
    "echo -e '\
    PRODUCT_KEY=${param_product_key}\n\
    DOCKER_REGISTRY=${param_docker_registry}\n\
    PORTAINER_URL=${param_portainer_url}\n\
    PORTAINER_ADMIN_USERNAME=${param_portainer_admin_username}\n\
    PORTAINER_ADMIN_PASSWORD=${param_portainer_admin_password}'>> $ROOTFS/etc/environment_profile" \
     ${PROVISION_LOG}

chmod 600 $ROOTFS/etc/environment_profile

run "Enable ESM systemd service" \
    "mkdir -p $ROOTFS/opt/esm/src && \
    mkdir -p $ROOTFS/opt/esm/stacks && \
    wget -O $ROOTFS/opt/esm/src/endpoint.py ${param_bootstrapurl}/esm/src/endpoint.py && \
    chmod a+x $ROOTFS/opt/esm/src/endpoint.py && \
    wget -O $ROOTFS/opt/esm/stacks/docker-compose.yml ${param_bootstrapurl}/esm/stacks/docker-compose.yml && \
    wget -O $ROOTFS/opt/esm/stacks/docker-stack.yml ${param_bootstrapurl}/esm/stacks/docker-stack.yml && \
    wget -O $ROOTFS/etc/systemd/system/esm.service ${param_bootstrapurl}/esm/systemd/esm.service && \
    ln -s /etc/systemd/system/esm.service $ROOTFS/etc/systemd/system/multi-user.target.wants/esm.service" \
    ${PROVISION_LOG}

run "Add insecure registry conf" \
    "mkdir -p $ROOTFS/etc/docker && \
    echo '{\"insecure-registries\": [\"${param_docker_registry}\"]}' >$ROOTFS/etc/docker/daemon.json" \
     ${PROVISION_LOG}
     
# --- Pull any and load any system images ---
for image in $pull_sysdockerimagelist; do
        run "Installing system-docker image $image" "docker exec -i system-docker docker pull $image" "$TMP/provisioning.log"
done

for image in $wget_sysdockerimagelist; do
        run "Installing system-docker image $image" "wget -O- $image 2>> $TMP/provisioning.log | docker exec -i system-docker docker load" "$TMP/provisioning.log"
done
