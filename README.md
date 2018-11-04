# Arch Bootstrap Scripts

My personal scripts for bootstrapping an Arch Linux system.

# Usage

1. Boot with Arch ISO: https://www.archlinux.org/download/
2. Prepare the partitions: https://wiki.archlinux.org/index.php/Installation_guide#Partition_the_disks [(Here's what I do)](PARTITIONS.md)
3. Make sure the internet is available.
4. Download and extact the project:
```console
$ curl -L https://github.com/Lizards/arch-installer/tarball/master | tar -xz --strip-component=1
```
5. Edit the config variables:
```console
$ vim .config
```
6. Run the bootstrap script:
```console
$ bash -ex bootstrap.sh
```
7. Reboot, log in to i3, install [dotfiles](https://github.com/Lizards/dotfiles)

# Credit

Originally forked from [leomao/arch-bootstrap](https://github.com/leomao/arch-bootstrap)
