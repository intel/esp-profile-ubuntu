# Ubuntu OS Base Profile "master" branch

<img align="right" src="https://assets.ubuntu.com/v1/29985a98-ubuntu-logo32.png">

Intended to be used with [Edge Software Provisioner](https://github.com/intel/Edge-Software-Provisioner) and this Ubuntu profile repo.

This master branch of this repo is the "base" of the branches listed.  For example, the "desktop" and "slim" branches use the "master" branch as the base of the OS installation.  When creating a new profile, clone an existing branch such as the "slim" branch and the ingredients you want installed to your profile.  Documentation on how to use each profile can be found in the README of each profile branch.  For example: Ubuntu OS Desktop Profile project [documentation](https://github.com/intel/rni-profile-base-ubuntu/blob/desktop/README.md) in order to deploy Ubuntu.

The "legacy" branch is the old original monolithic profile that included the base and the ingredients.

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
* `network` - Add password of docker hub login if user wants to login to docker hub repository service during provisioning.
* `wpassid` - uOS WPA SSID if no ethernet is found
* `wpapsk` - uOS WPA Pre-Shared Key if no ethernet is found
* `wifissid` - Target system WiFi SSID
* `wifipsk` - Target system WiFi Pre-Shared Key
* `network` - By default this installs a basic network if omitted.  Valid options are `bridged` which enables a bonded bridged networks accross all network devices or `network-manager` which gives management to the Network Manager utility.

## Target Device Prerequisites

* x86 Bare Metal or x86 Virtual Machine
* At Least 5 GB of Disk Space
  * Supports the following drive types:
    * SDD
    * NVME
    * MMC
* 4 GB of RAM

## Known Limitations

* Currently does not support full disk encryption
* Currently does not install Secure Boot features
* Currently the "master" (the base profile), is intended to be used along with the other branch profiles.\
* Only partitions 1 drive in the target device. It can be made partition as many drives as you want.  Clone the "master" branch, edit file "pre.sh", got to the section "Detect HDD" and modify to your hardware specific situation.
* All LAN adapters on the system will be configured for DHCP by default.  Use `network` kernel parameter to change to a bonded bridged network with `network=bridged` or use NetworkManager using `network=networkmanager`.
