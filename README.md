# Ubuntu OS Profile

<img align="right" src="https://assets.ubuntu.com/v1/29985a98-ubuntu-logo32.png">

Intended to be used with [Retail Node Installer](https://github.com/intel/retail-node-installer), this Ubuntu OS profile contains a few files that ultimately will install Ubuntu OS to disk.

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

**A necessary prerequisite to using this profile is having an Retail Node Installer deployed**. Please refer to Retail Node Installer project [documentation for installation](https://github.com/intel/retail-node-installer) in order to deploy it.

Out of the box, the Ubuntu profile should _just work_. Therefore, no specific steps are required in order to use this profile that have not already been described in the Retail Node Installer documentation. Simply boot a client device using legacy BIOS PXE boot and the Ubuntu profile should automatically launch after a brief waiting period.

If you do encounter issues PXE booting, please review the steps outlined in the Retail Node Installer documentation and ensure you've followed them correctly. See the [Known Issues](#Known-Issues) section for possible solutions.

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

## Known Limitations

* Currently does not support full disk encryption
* Currently does not install Secure Boot features

## Customization

If you want to customize your Retail Node Installer profile, follow these steps:

* Duplicate this repository locally and push it to a separate/new git repository
* Make changes after reading the information below
* Update your Retail Node Installer configuration to point to the git repository and branch (such as master).

The flexibility of Retail Node Installer comes to fruition with the following profile-side file structures:

* `conf/config.yml` - This file contains the arguments that are passed to the Linux kernel upon PXE boot. Alter these arguments according to the needs of your scripts. The following kernel arguments are always prepended to the arguments specified in `conf/config.yml`:
  * `console=tty0`
  * `httpserver=@@RNI_IP@@`
  * `bootstrap=http://@@RNI_IP@@/profile/${profileName}/bootstrap.sh`
* `conf/files.yml` - This file contains a few definitions that tell Retail Node Installer to download specific files that you can customize. **Please check if there are any [Known Issues](#Known-Issues) before changing this file from the default.** See `conf/files.sample.yml` for a full example.
* `bootstrap.sh` - A profile is required to have a `bootstrap.sh` as an entry point. This is an arbitrary script that you can control. If you plan to create profiles for other operating systems such as Ubuntu or Debian, it is recommended to use [preseed](https://wiki.debian.org/DebianInstaller/Preseed) to launch `bootstrap.sh` as the last step.
Currently the following variables are processed:
  * `@@RNI_DHCP_MIN@@`
  * `@@RNI_DHCP_MAX@@`
  * `@@RNI_NETWORK_BROADCAST_IP@@`
  * `@@RNI_NETWORK_GATEWAY_IP@@`
  * `@@RNI_IP@@`
  * `@@RNI_NETWORK_DNS_SECONDARY@@`
  * `@@PROFILE_NAME@@`

### Customization Requirements

A profile **must** have all of the following:

* a `bootstrap.sh` file at the root of the repository
* a `conf/files.yml` specifying an `initrd` and `vmlinuz`, as shown in the `conf/files.yml` file.