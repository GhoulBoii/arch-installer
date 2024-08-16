<h1 align="center">Arch Installer</h1>
<h3 align="center">Quick & Simple Arch Linux Installer</h3>

## ✨ Features

- Partitions the drive with support of UEFI & BIOS
- Installs necessary packages (bluetooth, audio, firewall)
- Rices with [my dotfiles](https://github.com/GhoulBoii/dotfiles)
- Setup a working environment in less than **30 minutes**

## 🔧 Usage

- Grab the latest [Arch Linux ISO](https://archlinux.org/download/)
- Flash it on a USB Drive using [Ventoy](https://github.com/ventoy/Ventoy) [**Recommended**] or [Balena Etcher](https://github.com/balena-io/etcher)
- Boot into the live environment and run the following commands:
```bash
pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm git
git clone https://github.com/ghoulboii/arch-installer
cd arch-installer
./arch-installer.sh
```

## 📜 License

This project is licensed under the GPL-3.0 License - see the [License file](LICENSE.md) for details.

## ❤️ Credits

- [Bugswriter](https://github.com/Bugswriter/arch-linux-magic)
- [Chris Titus Tech](https://github.com/ChrisTitusTech/ArchTitus)
- [EFlinux](https://gitlab.com/eflinux/arch-basic)
