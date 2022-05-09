#!/usr/bin/env bash 
# Part 1: Partition Setup
# TODO: Graphics Card Driver Installer
clear
echo "GhoulBoi's Arch Installer"
echo "Part 1: Partition Setup"
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf
pacman --noconfirm -Sy archlinux-keyring 
timedatectl set-ntp true
lsblk
read -p "Enter drive (Ex. - /dev/sda): " drive
cfdisk $drive
read -p "Enter the Linux Partition (Ex. - /dev/sda2): " linux
read -p "Enter SWAP partition (Enter \"n\" if no SWAP): " swapcreation
read -p "Enter EFI partition (Enter \"n\" if using BIOS): " bios
read -p "Enter the hostname: " hostname
read -p "Enter username: " username
mkfs.btrfs -fL Linux $linux
mount $linux /mnt
case $swapcreation in
  /dev/*)
    mkswap $swapcreation
    swapon $swapcreation
    ;;
esac
case $bios in
  /dev/*)
    mkfs.fat -F 32 $bios
    mdkir /mnt/boot
    mount $bios /mnt/boot
    ;;
esac 
pacstrap /mnt base base-devel linux-zen linux-firmware btrfs-progs intel-ucode 
genfstab -U /mnt >> /mnt/etc/fstab

# Part 2: Base System

clear
echo "Part 2: Base System"
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /mnt/etc/pacman.conf
ln -sf /mnt/usr/share/zoneinfo/Asia/Kolkata /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf
echo $hostname > /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /mnt/etc/hosts
echo "Enter your root password: "
passwd
PKGS=(
  'bridge-utils'
  'btop'
  'btrfs-progs'
  'dash'
  'dnsmasq'
  'dunst'
  'emacs'
  'feh'
  'flatpak'
  'gamemode'
  'git'
  'grub'
  'intel-ucode'
  'lib32-pipewire'
  'libvirt'
  'linux-firmware'
  'linux-zen-headers'
  'lutris'
  'man-db'
  'mesa'
  'mesa-utils'
  'mpv'
  'ncdu'
  'neofetch'
  'neovim'
  'iwd'
  'ntfs-3g'
  'openbsd-netcat'
  'openssh'
  'os-prober'
  'pcmanfm'
  'pipewire'
  'pipewire-pulse'
  'playerctl'
  'python-pywal'
  'qemu-desktop'
  'reflector'
  'rofi'
  'rsync'
  'tlp'
  'vde2'
  'virt-manager'
  'virt-viewer'
  'wezterm'
  'wine-nine'
  'wine-staging'
  'winetricks'
  'wireplumber'
  'xbindkeys'
  'xclip'
  'xcompmgr'
  # TEST XDG DESKTOP PORTAL PACKAGES
  'xdg-desktop-portal-gtk'
  'xdg-user-dirs'
  'xdg-utils'
  'xdotool'
  # 'xf86-video-intel'
  'xf86-input-libinput'
  'xorg-server'
  'xorg-xinit'
  'xorg-xinput'
  'xorg-xrandr'
  'xorg-xset'
  'yt-dlp'
  'zsh'
  'zsh-autosuggestions'
)
for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    arch-chroot /mnt pacman -S "$PKG" --noconfirm --needed
done
case $bios in
     /dev/*)
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    ;;
      n)
        arch-chroot /mnt grub-install --target=i386-pc $drive
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    ;;
esac
arch-chroot /mnt systemctl enable NetworkManager tlp reflector.timer
arch-chroot /mnt useradd -mG wheel -s /bin/zsh $username
arch-chroot /mnt usermod -aG libvirt $username
arch-chroot /mnt passwd $username
sed -i '/# %wheel ALL=(ALL:ALL) ALL/s/^#//' /mnt/etc/sudoers

# Part 3: Graphical Interface

clear
arch-chroot /mnt sudo -i -u $username bash <<EOF
cd
git clone --depth=1 --separate-git-dir=.dotfiles https://github.com/ghoulboii/dotfiles.git tmpdotfiles
rsync --recursive --verbose --exclude '.git' tmpdotfiles/ .
rm -rf tmpdotfiles
git clone --depth=1 https://github.com/ghoulboii/dwm.git ~/.local/src/dwm
sudo make -C ~/.local/src/dwm install
git clone --depth=1 https://aur.archlinux.org/yay-bin.git ~/.local/src/yay
cd ~/.local/src/yay
makepkg --noconfirm -si
cd
rm -rf ~/.local/src/yay
ln -sf ~/.config/shell/profile ~/.zprofile
/usr/bin/git --git-dir=~/.dotfiles/ --work-tree=~ config --local status.showUntrackedFiles no
EOF
AURPKGS=(
  'autojump-rs'
  'devour'
  'jdk-temurin'
  'jdk8-adoptopenjdk'
  'lf-bin'
  'libxft-bgra-git'
  'nerd-fonts-hack'
  # 'nvidia-390xx-dkms'
  # 'optimus-manager'
  'pywal-git'
  'ttf-ms-fonts'
  'zsh-fast-syntax-highlighting'
  )
for AURPKG in "${AURPKGS[@]}"; do
    echo "INSTALLING: ${AURPKG}"
    arch-chroot /mnt sudo -i -u $username yay -S "$AURPKG" --noconfirm --needed
done
exit
