#!/usr/bin/env bash 
# Part 1: Partition Setup

clear
echo "GhoulBoi's Arch Installer"
echo "Part 1: Partition Setup"
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf
pacman --noconfirm -Sy archlinux-keyring 
timedatectl set-ntp true
lsblk
read -p "Enter drive (Ex. - /dev/sda): " drive
cfdisk $drive
lsblk
read -p "Enter the Linux Partition (Ex. - /dev/sda2): " linux
read -p "Enter SWAP partition (Skip if no SWAP): " swapcreation
read -p "Enter EFI partition (Skip if using BIOS): " bios
read -p "Enter the hostname: " hostname
read -p "Enter username: " username
read -p "Enter password: " password
echo "Amd and Intel Drivers will automatically work with the mesa package. The option below is only for Nvidia Graphics Card users."
read -p "Enter which graphics driver you use (Enter \"N\" for Nvidia or \"n\" for Legacy Nvidia Drivers (Driver 390): " nvidia
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

# Pacman Config
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /mnt/etc/pacman.conf
grep -q "ILoveCandy" /mnt/etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /mnt/etc/pacman.conf
sed -i "/^#ParallelDownloads/s/=.*/= 5/;s/^#Color$/Color/" /mnt/etc/pacman.conf

# Locale and Hosts
ln -sf /mnt/usr/share/zoneinfo/Asia/Kolkata /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf
echo $hostname > /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /mnt/etc/hosts

arch-chroot /mnt <<EOF
echo "root:$password" | chpasswd
EOF
arch-chroot /mnt <<EOF
pacman -Sy --noconfirm bridge-utils btop dash dnsmasq dunst emacs feh flatpak \
                       gamemode git grub lib32-pipewire libvirt linux-zen-headers lutris man-db \
                       mesa mesa-utils mpv ncdu neofetch neovim networkmanager ntfs-3g \
                       openbsd-netcat openssh optimus-manager os-prober pcmanfm pipewire pipewire-pulse playerctl \
                       python-pywal qemu-desktop reflector ripgrep rofi rsync tlp vde2 \
                       virt-manager virt-viewer wezterm wine-nine wine-staging \
                       winetricks wireplumber xbindkeys xclip \
                       xcompmgr xdg-desktop-portal-gtk xdg-user-dirs xdg-utils \
                       xdotool xf86-input-libinput xorg-server xorg-xinit \
                       xorg-xinput xorg-xrandr xorg-xset yt-dlp \
                       zsh zsh-autosuggestions
EOF
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
arch-chroot /mnt <<EOF
echo "$username:$password" | chpasswd
EOF
sed -i '/# %wheel ALL=(ALL:ALL) ALL/s/^#//' /mnt/etc/sudoers

# Part 3: Graphical Interface

clear
arch-chroot /mnt sudo -i -u $username bash <<EOF
cd

# DOTFILES
git clone --depth=1 --separate-git-dir=.dotfiles https://github.com/ghoulboii/dotfiles.git tmpdotfiles
rsync --recursive --verbose --exclude '.git' tmpdotfiles/ .
rm -rf tmpdotfiles
/usr/bin/git --git-dir=~/.dotfiles/ --work-tree=~ config --local status.showUntrackedFiles no

# DWM (Window manager)
git clone --depth=1 https://github.com/ghoulboii/dwm.git ~/.local/src/dwm
sudo make -C ~/.local/src/dwm install

# YAY (AUR helper)
git clone --depth=1 https://aur.archlinux.org/yay-bin.git ~/.local/src/yay
cd ~/.local/src/yay
makepkg --noconfirm -rsi
cd
rm -rf ~/.local/src/yay

# DOOM EMACS (CODE EDITOR)
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs/
~/.config/emacs/bin/doom -y install
EOF

arch-chroot /mnt <<EOF
sudo -i -u $username yay -S --noconfirm autojump-rs devour jdk-temurin jdk8-adoptopenjdk \
                                        lf-bin libxft-bgra-git nerd-fonts-hack pywal-git \
                                        ttf-ms-fonts zsh-fast-syntax-highlighting
EOF
case $nvidia in
  N)
    arch-chroot /mnt sudo -i -u $username yay -S nvidia-dkms nvidia-utils lib32-nvidia-utils
    ;;
  n)
    arch-chroot /mnt sudo -i -u $username yay -S nvidia-390xx-dkms nvidia-390xx-utils lib32-nvidia-390xx-utils
    ;;
esac

arch-chroot /mnt <<EOF
sudo -i -u $username flatpak install -y com.brave.Browser com.github.tchx84.Flatseal \
                                        com.github.wwmm.easyeffects com.valvesoftware.Steam \
                                        org.flameshot.Flameshot org.gimp.Gimp org.libreoffice.LibreOffice \
                                        org.polymc.PolyMC org.qbittorrent.qBittorrent sh.ppy.osu
EOF
exit
