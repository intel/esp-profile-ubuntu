#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

pull_sysdockerimagelist="alpine:3.9"
wget_sysdockerimagelist="\
http://${PROVISIONER}${param_httppath}/files/glusterfs-rest.tar \
http://${PROVISIONER}${param_httppath}/files/glusterfs-plugin.tar \
http://${PROVISIONER}${param_httppath}/files/serf.tar \
http://${PROVISIONER}${param_httppath}/files/dho.tar \
http://${PROVISIONER}${param_httppath}/files/console-alpine.tar \
http://${PROVISIONER}${param_httppath}/files/app-docker.tar \
http://${PROVISIONER}${param_httppath}/files/docker-dind.tar \
http://${PROVISIONER}${param_httppath}/files/docker.tar"

pull_appdockerimagelist=""
wget_appdockerimagelist=""

# --- Preload Software Stack ---
run "Installing Retail Workload Orchestrator" "apk add --no-cache openssh-client && \
    mkdir -p $ROOTFS/opt/ && \
    cd $ROOTFS/opt/ && \
    git clone -b ${param_rwo} https://github.com/intel/RetailWorkloadOrchestrator.git rwo && \
    mv rwo/systemd/rwo.service $ROOTFS/etc/systemd/system/ && rmdir rwo/systemd/ && \
    ln -s /etc/systemd/system/rwo.service $ROOTFS/etc/systemd/system/multi-user.target.wants/rwo.service && \
    cd -" "$TMP/provisioning.log"


if [ ! -z "${param_proxy}" ]; then
    cat $ROOTFS/opt/rwo/compose/docker-compose.yml | sed "s#- HTTP_PROXY#- HTTP_PROXY=${HTTP_PROXY}#g" | sed "s#- HTTPS_PROXY#- HTTPS_PROXY=${HTTPS_PROXY}#g" | sed "s#- NO_PROXY#- NO_PROXY=${NO_PROXY}#g" > $ROOTFS/opt/rwo/compose/docker-compose.yml.tmp
    mv $ROOTFS/opt/rwo/compose/docker-compose.yml.tmp $ROOTFS/opt/rwo/compose/docker-compose.yml
fi

# --- Create app-docker database on $ROOTFS ---
run "Preparing app-docker database" \
    "mkdir -p $ROOTFS/var/lib/app-docker && \
    docker run -d --privileged --name app-docker ${DOCKER_PROXY_ENV} -v $ROOTFS/var/lib/app-docker:/var/lib/docker docker:18.06-dind ${REGISTRY_MIRROR}" \
    "$TMP/provisioning.log"

#--- Pull any and load any system images ---
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

# --- Pull any and load any user images ---
for image in $pull_appdockerimagelist; do
    run "Installing app-docker image $image" \
        "docker exec -i app-docker docker pull $image" \
        "$TMP/provisioning.log"
done

for image in $wget_appdockerimagelist; do
    run "Installing app-docker image $image" \
        "wget -O- $image 2>> $TMP/provisioning.log | docker exec -i app-docker docker load" \
        "$TMP/provisioning.log"
done

run "Snapshotting App Docker" \
    "rsync -a $ROOTFS/var/lib/app-docker $ROOTFS/opt/rwo/" \
    "$TMP/provisioning.log"
