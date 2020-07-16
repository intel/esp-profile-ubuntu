#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

param_httpserver=$1

# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

if [[ $kernel_params == *"token="* ]]; then
    tmp="${kernel_params##*token=}"
    export param_token="${tmp%% *}"
fi

if [[ $kernel_params == *"basebranch="* ]]; then
    tmp="${kernel_params##*basebranch=}"
    export param_basebranch="${tmp%% *}"
fi

if [[ $kernel_params == *"bootstrap="* ]]; then
    tmp="${kernel_params##*bootstrap=}"
    export param_bootstrap="${tmp%% *}"
    export param_bootstrapurl=$(echo $param_bootstrap | sed "s#/$(basename $param_bootstrap)\$##g")
fi

# --- Call pre.sh from base_profile ---
source <(wget --header "Authorization: token ${param_token}" -O - ${param_basebranch}/pre.sh) && \
wget --header "Authorization: token ${param_token}" -O - ${param_bootstrapurl}/profile.sh | bash -s - $param_httpserver && \
wget --header "Authorization: token ${param_token}" -O - ${param_basebranch}/post.sh | bash -s - $param_httpserver
