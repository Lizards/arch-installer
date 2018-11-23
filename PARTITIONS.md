# Starting out

__Confirm UEFI mode:__ `ls /sys/firmware/efi/efivars`

__List devices:__ `lsblk`

__Verify internets:__ `ping google.com`

# OK!

`timedatectl set-ntp true`

#### Partitioning

__Create the partitions__

`gdisk`

- Type `/dev/sda` or whatever
- __Create EFI system partition (`/boot`) - GPT mode__
	- `n` for new partition
	- Enter (partition 1)
	- Enter (default)
	- `+550M`
	- `ef00`
- __Create swap__
	- `n` for new
	- Enter (Partition 2)
	- Enter (default)
	- `+8G`
	- `8200` (Linux swap)
- __Create `/`__
	- `n` for new
	- Enter, Enter, Enter, Enter
	- `w` to save and exit

__Format the partitions__

__`EFI`__ - https://wiki.archlinux.org/index.php/EFI_system_partition#Format_the_partition

`mkfs.fat -F32 /dev/sda1`

__Swap__

```
mkswap /dev/sda2
```

__/__

`mkfs.ext4 /dev/sda3`
