# Ubuntu OS Base Profile "master" branch

<img align="right" src="https://assets.ubuntu.com/v1/29985a98-ubuntu-logo32.png">

Intended to be used with [Retail Node Installer](https://github.com/intel/retail-node-installer) and this Ubuntu profile repo.

This master branch of this repo is the "base" of the branches listed.  For example, the "desktop" and "slim" branches use the "master" branch as the base of the OS installation.  When creating a new profile, clone an existing branch such as the "slim" branch and the ingredients you want installed to your profile.  Documentation on how to use each profile can be found in the README of each profile branch.  For example: Ubuntu OS Desktop Profile project [documentation](https://github.com/intel/rni-profile-base-ubuntu/blob/desktop/README.md) in order to deploy Ubuntu.

The "legacy" branch is the old original monolithic profile that included the base and the ingredients.

## Known Limitations

* Currently does not support full disk encryption
* Currently does not install Secure Boot features
* Currently the "master" (the base profile), is intended to be used along with the other branch profiles.\
* Only partitions 1 drive in the target device. It can be made partition as many drives as you want.  Clone the "master" branch, edit file "pre.sh", got to the section "Detect HDD" and modify to your hardware specific situation.
* All LAN adapters on the system will be configured for DHCP.  Clone the "master" branch, edit file "pre.sh" and "files/etc/systemd/wired.network", search for "wired.network" and modify to your hardware specific situation.
