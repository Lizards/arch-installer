# Arch Installation Scripts

Personal scripts for bootstrapping an Arch Linux system with i3.  By default it will install [system-specific configuration files](https://github.com/Lizards/arch-system-config) and [dotfiles](https://github.com/Lizards/dotfiles), but you can opt out of this step.

Assumes system supports EFI.


### Usage

1. [Boot with Arch ISO](https://wiki.archlinux.org/index.php/USB_flash_installation_media): https://www.archlinux.org/download/

1. [Prepare the partitions](https://wiki.archlinux.org/index.php/Installation_guide#Partition_the_disks) ([Cheat sheet](PARTITIONS.md))

1. Make sure the internet is available

1. Download and extact the project:
    ```console
    $ curl -L https://github.com/Lizards/arch-installer/tarball/master | tar -xz --strip-component=1
    ```

1. Edit the variables in `.config`

    | Variable                 | Description                                                                                                                                                                                                                                       |    Required    |
    |--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------------:|
    | `INSTALL_SYSTEM_CONFIGS` | Default: `1`<br/><br/>With `1`, install [system configuration files](https://github.com/Lizards/arch-system-config) and [dotfiles](https://github.com/Lizards/dotfiles).  See `HOSTNAME` below. Set to `0` to disable.                              |                |
    | `HOSTNAME`               | Computer's hostname, also used to install machine-specific configs<br/><br/>With `INSTALL_SYSTEM_CONFIGS=1`, accepted values are `asds-laptop` (ThinkPad W540), `boris` (ThinkPad X1 Carbon), or `mikhail` (a desktop PC with dual monitors).  If `HOSTNAME` matches none of these, a generic system config base package and `mikhail`'s dotfiles will be installed.  If installing in VirtualBox, a branch of the dotfiles specific to VirtualBox will be installed. | :black_circle: |
    | `BOOT_PART`              | Boot partition, mounted at `/boot`                                                                                                                                                                                                                | :black_circle: |
    | `ROOT_PART`              | Root partition, mounted at `/`                                                                                                                                                                                                                    | :black_circle: |
    | `SWAP_PART`              | Optional swap partition                                                                                                                                                                                                                           |                |
    | `HOME_PART`              | Optional `/home` partition                                                                                                                                                                                                                        |                |
    | `USERNAME`               | The installer will create a user with this username.  This user will be added to groups `wheel,optical,audio,video,lp`, and the groups provided by installed packages in `chroot/packages/groups`                                                | :black_circle: |
    | `PASS`                   | Password for the user created by the installer                                                                                                                                                                                                  | :black_circle: |
    | `ROOT_PASS`              | Root password                                                                                                                                                                                                                                     | :black_circle: |
    | `TIMEZONE`               | Default: `US/Eastern`                                                                                                                                                                                                                       |                |
    | `COUNTRY`                |  Default: `United States`<br/><br/>Used with `reflector` to generate Pacman mirror list                                                                                                                                                             |                |
    | `PAUSE_BETWEEN_STEPS`    | For debugging, set to `1` to pause and wait for keyboard input between steps                                                                                                                                                                      |                |
    | `CHROOT_SCRIPT_DIR`      | Default: `/usr/local/lib/bootstrap`<br/><br/>Directory where the install scripts are copied during `chroot` step, deleted on successful installation                                                                                                          |                |

6. Run the install script:
    ```console
    $ ./install.sh
    ```

	You will be prompted at least once for the user password.  This happens during the installation of AUR packages, as `aursync` is run as the user to build the packages, then the user must authenticate to install them.

7. System will reboot upon successful installation.  You should be greeted with an LXDM login screen.  Select `i3` under `Desktop` in the bottom left corner before logging in for the first time.

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
