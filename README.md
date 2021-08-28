# Ubuntu OS Profile

<img align="right" src="https://assets.ubuntu.com/v1/29985a98-ubuntu-logo32.png">

Intended to be used with [Edge Software Provisioner](https://github.com/intel/Edge-Software-Provisioner) and Ubuntu base profile, this Ubuntu OS profile contains a few files that ultimately will install Ubuntu OS to disk.

## Software Stack in this profile

* Ubuntu Linux w/ Docker

## Target Device Prerequisites

* x86 Bare Metal or x86 Virtual Machine
* At Least 5 GB of Disk Space
  * Supports the following drive types:
    * SDD
    * NVME
    * MMC
* 4 GB of RAM

## Getting Started

**A necessary prerequisite to using this profile is having an Edge Software Provisioner deployed**. Please refer to Edge Software Provisioner project documentation for [installation](https://github.com/intel/Edge-Software-Provisioner) in order to deploy it.

Out of the box, the Ubuntu profile should _just work_. Therefore, no specific steps are required in order to use this profile that have not already been described in the Edge Software Provisioner documentation. Simply boot a client device using legacy BIOS PXE boot and the Ubuntu profile should automatically launch after a brief waiting period.

If you do encounter issues PXE booting, please review the steps outlined in the Edge Software Provisioner documentation and ensure you've followed them correctly. See the [Known Issues](https://github.com/intel/Edge-Software-Provisioner) section for possible solutions.

After installing Ubuntu, the default login username is `sys-admin` and the default password is `P@ssw0rd!`. This password is defined in the `bootstrap.sh` script and in the `conf/config.yml` as a kernel argument.

## Kernel Paramaters used at build time

The following kernel parameters can be added to `conf/config.yml`

* `bootstrap` - RESERVED, do not change
* `ubuntuversion` - Use the Ubuntu release name. Defaults to 'cosmic' release
* `debug` - [TRUE | FALSE] Enables a more verbose output
* `httppath` - RESERVED, do not change
* `kernparam` - Used to pass additional kernel parameters to the targeted system.  Example format: kernparam=splash:quiet#enable_gvt:1
* `parttype` - RESERVED, do not change
* `password` - Initial user password. Defaults to 'password'
* `proxy` - Add proxy settings if behind proxy during installation.  Example: http://proxy-us.intel.com:912
* `proxysocks` - Add socks proxy settings if behind proxy during installation.  Example: http://proxy-us.intel.com:1080
* `release` - [prod | dev] If set to prod the system will shutdown after it is provisioned.  Altnerativily it will reboot.
* `token` - GitHub token for private repositories, if this profile is in a private respository this token should have access to this repo
* `username` - Initial user name. Defaults to 'sys-admin'
* `docker_login_user` - Add user name of docker hub login if user wants to login to docker hub repository service during provisioning.
* `docker_login_pass` - Add password of docker hub login if user wants to login to docker hub repository service during provisioning.
* `network` - By default this installs a basic systemd dhcp network if omitted.  Valid options are `bridged` which enables a bonded bridged networks accross all network devices or `network-manager` which gives management to the Network Manager utility.
* `wpassid` - uOS WPA SSID if no ethernet is found
* `wpapsk` - uOS WPA Pre-Shared Key if no ethernet is found
* `wifissid` - Target system WiFi SSID
* `wifipsk` - Target system WiFi Pre-Shared Key

## Sample Profile Section

* To use base profile with custom profile, Please refer below sample profile section of config.yml for Edge Software Provisioner 

```yaml
# Please make sure to define ALL of the variables below, even if they
# are empty. Otherwise, this application will not be configured properly.
profiles:
  - git_remote_url: https://github.com/intel/rni-profile-base-ubuntu.git
    profile_branch: slim
    profile_base_branch: master
    git_username: ""
    git_token: ""
    name: Ubuntu_with_Docker
    custom_git_arguments: --depth=1
```

## Known Limitations

* Currently does not support full disk encryption
* Currently does not install Secure Boot features

## Customization

If you want to customize your Edge Software Provisioner profile, follow these steps:

* Duplicate this repository locally and push it to a separate/new git repository
* Make changes after reading the information below
* Update your Edge Software Provisioner configuration to point to the git repository, base branch (such as master or base) and custom branch(such as rwo).

The flexibility of Edge Software Provisioner comes to fruition with the following profile-side file structures:

* `conf/config.yml` - This file contains the arguments that are passed to the Linux kernel upon PXE boot. Alter these arguments according to the needs of your scripts. The following kernel arguments are always prepended to the arguments specified in `conf/config.yml`:
  * `console=tty0`
  * `httpserver=@@HOST_IP@@`
  * `bootstrap=http://@@HOST_IP@@/profile/${profileName}/bootstrap.sh`
* `conf/files.yml` - This file contains a few definitions that tell Edge Software Provisioner to download specific files that you can customize. **Please check if there are any [Known Limitations](#Known-Limitations) before changing this file from the default.** User can specify an `initrd` and `vmlinuz`, as shown in the `conf/files.sample.yml` file. See `conf/files.sample.yml` for a full example.
* `bootstrap.sh` - A profile is required to have a `bootstrap.sh` as an entry point. This is an arbitrary script that you can control. Custom bootstrap.sh should always call pre.sh and post.sh from base branch inorder to install OS(Please refer *rwo* custom branch for reference). User can also write a seprate script(such as profile.sh) to perform specific task and call it from bootstrap.sh.

Currently the following variables are processed:
  * `@@DHCP_MIN@@`
  * `@@DHCP_MAX@@`
  * `@@NETWORK_BROADCAST_IP@@`
  * `@@NETWORK_GATEWAY_IP@@`
  * `@@HOST_IP@@`
  * `@@NETWORK_DNS_SECONDARY@@`
  * `@@PROFILE_NAME@@`

### Customization Requirements

A profile **must** have all of the following:

* a `bootstrap.sh` file at the root of the repository
* a `profile.sh` file at the root of the repository
