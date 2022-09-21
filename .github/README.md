# Arch Installer 

Automated Arch Linux Installer for Different Scenarios and Scemes.

## Features

- Setup a working environment in less than 30 minutes
- Uses dwm (window manager), wezterm (terminal emulator) and rofi (application switcher)

## Usage

Get the latest archlinux [ISO](https://archlinux.org/download/) and flash it on a usb with [Ventoy](https://github.com/ventoy/Ventoy) (Recommended) or [Balena Etcher](https://github.com/balena-io/etcher). Then run the following commands when you boot into the live environment:
```
pacman -Sy git
git clone https://github.com/ghoulboii/arch-installer
cd arch-installer
./arch-installer.sh
```

## License 

This project is licensed under the GPL-3.0 License - see the [License file](LICENSE) for details.

## Credits to:

- [Bugswriter](https://github.com/Bugswriter/arch-linux-magic)
- [Chris Titus Tech](https://github.com/ChrisTitusTech/ArchTitus)
- [EFlinux](https://gitlab.com/eflinux/arch-basic)
