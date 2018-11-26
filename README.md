# Arch Installation Scripts

Personal scripts for bootstrapping an Arch Linux system with i3.

- Installs Arch Linux per the [Installation Guide](https://wiki.archlinux.org/index.php/installation_guide)
- Configures systemd-boot (assumes system supports EFI)
- Creates a user and adds it to common groups, plus any groups defined in [`chroot/packages/groups`](chroot/packages/groups)
- Installs [`aurutils`](https://github.com/AladW/aurutils) and configures a local pacman repository
- Optionally, installs packages listed in [`chroot/packages`](chroot/packages)
- Optionally, enables services listed in [`chroot/services`](chroot/services)
- Detects CPU manufacturer and installs microcode package
- Detects a VirtualBox environment, installs the guest libraries and enables `vboxservice.service`
- Optionally, installs my [dotfiles](https://github.com/Lizards/dotfiles) (e.g. `.Xresources`, i3 config, bash aliases) and [system-specific configuration files](https://github.com/Lizards/arch-system-config) (e.g. mouse/trackpad settings, pacman hooks, bluetooth audio config)


### Usage

1. [Boot with Arch ISO](https://wiki.archlinux.org/index.php/USB_flash_installation_media): https://www.archlinux.org/download/

1. [Prepare the partitions](https://wiki.archlinux.org/index.php/Installation_guide#Partition_the_disks) ([Cheat sheet](PARTITIONS.md))

1. Make sure the internet is available

1. Download and extract the project:
    ```console
    $ curl -L https://github.com/Lizards/arch-installer/tarball/master | tar -xz --strip-component=1
    ```

1. Edit the variables in `.config`

    | Variable                 | Description                                                                                                                                                                                                                                       |    Required    |
    |--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------------:|
    | `BOOT_PART`              | Device name of boot partition, mounted at `/boot`                                                                                                                                                                                                                | :black_circle: |
    | `ROOT_PART`              | Device name of root partition, mounted at `/`                                                                                                                                                                                                                    | :black_circle: |
    | `SWAP_PART`              | Device name of swap partition, optional                                                                                                                                                                                                                           |                |
    | `HOME_PART`              | Device name of `/home` partition, optional                                                                                                                                                                                                                        |                |
    | `USERNAME`               | The installer will create a user with this username.  This user will be added to groups defined by `USER_GROUPS`, and the groups listed in [`chroot/packages/groups`](chroot/packages/groups) that are provided by installed packages                                               | :black_circle: |
    | `PASS`                   | Password for the user created by the installer                                                                                                                                                                                                  | :black_circle: |
    | `USER_GROUPS`            | Default: `wheel,optical,audio,video,lp`                                                                                                                                                                                                           |                |
    | `ROOT_PASS`              | Root password                                                                                                                                                                                                                                     | :black_circle: |
    | `HOSTNAME`               | Computer's hostname, also used to install machine-specific system configs<br/><br/>With `INSTALL_DOTFILES=1`, accepted values are `asds-laptop` (ThinkPad W540), `boris` (ThinkPad X1 Carbon), or `mikhail` (a desktop PC with dual monitors).  If `HOSTNAME` matches none of these, a generic system config base package and `mikhail`'s dotfiles will be installed.  If installing in VirtualBox, a branch of the dotfiles specific to VirtualBox will be installed. | :black_circle: |
    | `INSTALL_PACKAGES`       | Default: `1`<br/><br/>With `1`, install the packages in [`chroot/packages/arch`](chroot/packages/arch) and [`chroot/packages/aur`](chroot/packages/aur), enable the services in [`chroot/services/system`](chroot/services/system) and [`chroot/services/user`](chroot/services/user), and add the `USERNAME` user to the groups in [`chroot/packages/groups`](chroot/packages/groups).  Edit these files and opt out of installing the dotfiles to install an alternative Desktop Environment.                  |                |
    | `INSTALL_DOTFILES`       | Default: `1`<br/><br/>With `1`, install [system configs](https://github.com/Lizards/arch-system-config) and [dotfiles](https://github.com/Lizards/dotfiles).  See `HOSTNAME` below. Set to `0` to disable.  Dotfiles will not be installed with `INSTALL_PACKAGES=0`.                             |                |
    | `TIMEZONE`               | Default: `US/Eastern`                                                                                                                                                                                                                       |                |
    | `COUNTRY`                | Default: `United States`<br/><br/>Used with `reflector` to generate pacman mirror list                                                                                                                                                             |                |
    | `PAUSE_BETWEEN_STEPS`    | For debugging, set to `1` to pause and wait for keyboard input between steps                                                                                                                                                                      |                |
    | `CHROOT_SCRIPT_DIR`      | Default: `/usr/local/lib/bootstrap`<br/><br/>Directory where the install scripts are copied during `chroot` step, deleted on successful installation                                                                                                          |                |

1. Run the install script:
    ```console
    $ ./install.sh
    ```

	You will be prompted at least once for the user password.  This happens during the installation of AUR packages, as `aursync` is run as the user to build the packages, then the user must authenticate to install them.

1. System will reboot upon successful installation.  You should be greeted with an LXDM login screen.  Select `i3` under `Desktop` in the bottom left corner before logging in for the first time.

## Wait, not done yet

- __Networking requires setup__: `wicd` service should be running, but network connectivity will not work without first running `wicd-client` to configure the interface(s).  Use `ip link` to list them.

- __If screen resolution is wrong__, use `arandr` to change it.  Export an `xrandr` command from `arandr`.  If dotfiles were installed, update `$HOME/dotfiles/bin/xrandr.local` with it, then run `make` in `$HOME/dotfiles` to fix permanently.  If not, put it in the i3 config as an `exec_always` command.

- __If dotfiles were not installed__, there is no Polybar and the default `i3bar` display is broken.
    - Install `i3status` then `Win+Shift+R` to fix the `i3bar` display, __or__
	- Launch Polybar with its default config with `polybar -c /usr/share/doc/polybar/config example > /dev/null 2>&1 &`

### If dotfiles were installed...

- __If Polybar doesn't appear__, run `polybar.local` to inspect errors.  A common culprit is the `monitor` value in the bar definitions in `$HOME/dotfiles/.config/polybar/config`.  Run `polybar -m` to find active display names.

- __If network status is missing from Polybar__, update the `eth` and `wlan` modules in `$HOME/dotfiles/.config/polybar/config` with the correct interface names.  This can be done with `POLYBAR_ETH_INTERFACE` and `POLYBAR_WLAN_INTERFACE` environment variables (look in `.xprofile`).

- __Opening a terminal will show the error__ `bash: /home/user/.private_aliases: No such file or directory`.  `$HOME/.bash_aliases` sources this file.  `make` in the dotfiles project expects this file to be in `$HOME/Dropbox` and creates a symlink to it, if found.  To fix it...
	- Configure Dropbox (it is already installed), create the file in there, then run `make` in `$HOME/dotfiles` to create a symlink to the Dropbox file, __or__,
	- Create this file in the home directory, __or__,
	- Delete the line from `$HOME/.bash_aliases`

- __If using a Mac__, i3 keyboard controls probably won't work as configured, which means you can't do *anything* in i3. You must drop to a shell (`Fn+Ctrl+Opt+F2`?) to do anything further. Edit `$HOME/.config/i3/config`, adding the line `bindsym Shift+Return exec i3-sensible-terminal` to temporarily enable `Shift+Enter` to open a terminal in i3, reboot, and...
	- Use `i3-config-wizard` to generate a new config, then replace the key bindings in the existing config with the newly generated ones, __or__
    - Bind some other key to `Mod4`:
    	- `sudo pacman -Syu xorg-xmodmap` to install `xmodmap`
    	- Use `xev` to capture key input, and configure `xmodmap` to map the Command or some other key to `Mod4`

## VirtualBox

The installer will detect a VirtualBox environment and install the guest libraries.  If dotfiles are being installed, they will be installed from a dedicated `virtualbox` branch with some small tweaks.

## Credit

Originally forked from [leomao/arch-bootstrap](https://github.com/leomao/arch-bootstrap)
