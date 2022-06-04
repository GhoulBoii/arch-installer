#!/usr/bin/env bash 
clear
echo -e "\e[1;32mGhoulBoi's Arch Installer"
echo -e "\e[1;32mPart 1: Partition Setup"

lsblk
read -p "Enter drive (Ex. - /dev/sda): " drive
cfdisk $drive
lsblk
read -p "Enter the Linux Partition (Ex. - /dev/sda2): " linux
read -p "Would you like swap? (Answer y for swap): " swapcreation
read -p "Enter EFI partition (Ex. - /dev/sda2): " bios
read -p "Enter the hostname: " hostname
read -p "Enter username: " username
read -sp "Enter password: " pass1
echo ""
read -sp "Re-enter password: " pass2
while ! [ "$pass1" = "$pass2"]; do 
  echo -e "\n Passwords don't match."
  read -sp "Enter password: " pass1
  echo ""
  read -sp "Re-enter password: " pass2
done
echo "\nAmd and Intel Drivers will automatically work with the mesa package. The option below is only for Nvidia Graphics Card users."
read -p "Enter which graphics driver you use (Enter \"1\" for Nvidia or \"2\" for Legacy Nvidia Drivers (Driver 390): " nvidia
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf

pacman --noconfirm -Sy archlinux-keyring reflector
reflector -a 48 -c $(curl -4 ifconfig.co/country-iso)iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
timedatectl set-ntp true

echo -e "\e[1;36mCREATING SUBVOLUMES"
mkfs.btrfs -fL Linux $linux
mount $linux /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@.snapshots
umount /mnt

echo -e "\e[1;36mMOUNTING SUBVOLUMES"
mount -o noatime,discard=async,compress=zstd:2,subvol=@ $linux /mnt
mkdir /mnt/{home,var,tmp,.snapshots}
mount -o noatime,compress=zstd:2,subvol=@home $linux /mnt/home
mount -o nodatacow,subvol=@var $linux /mnt/var
mount -o noatime,compress=zstd:2,subvol=@tmp $linux /mnt/tmp
mount -o noatime,subvol=@.snapshots $linux /mnt/.snapshots

case $swapcreation in
  y)
    echo -e "\e[1;36mCREATING SWAP"
    mkdir -p /mnt/opt/swap # make a dir that we can apply NOCOW to to make it btrfs-friendly.
    chattr +C /mnt/opt/swap # apply NOCOW, btrfs needs that.
    dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
    chmod 600 /mnt/opt/swap/swapfile # set permissions.
    chown root /mnt/opt/swap/swapfile
    mkswap /mnt/opt/swap/swapfile
    swapon /mnt/opt/swap/swapfile
    echo "/opt/swap/swapfile	none	swap	sw	0	0" >> /mnt/etc/fstab # Add swap to fstab, so it KEEPS working after installation.
    ;;
esac
case $bios in
  /dev/*)
    echo -e "\e[1;36mCREATING UEFI PARTITION"
    mkfs.fat -F 32 $bios
    mdkir /mnt/boot
    mount $bios /mnt/boot
    ;;
esac

echo -e "\e[1;36mINSTALLING BASIC PACKAGES"
pacstrap /mnt base base-devel linux-zen linux-firmware btrfs-progs intel-ucode 
genfstab -U /mnt >> /mnt/etc/fstab

clear
echo -e "\e[1;32mPart 2: Base System"

echo -e "\e[1;32PACMAN CONFIG"
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /mnt/etc/pacman.conf
grep -q "ILoveCandy" /mnt/etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /mnt/etc/pacman.conf
sed -i "/^#ParallelDownloads/s/=.*/= 5/;s/^#Color$/Color/" /mnt/etc/pacman.conf
echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf

ln -sf /mnt/usr/share/zoneinfo/Asia/Kolkata /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf
echo $hostname > /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /mnt/etc/hosts
sed 's/MODULES=/MODULES=(btrfs)/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt <<EOF
echo "root:$password" | chpasswd
EOF

echo -e "\e[1;32mPACMAN PACKAGES"
arch-chroot /mnt <<EOF
pacman -Sy --noconfirm bridge-utils btop dash dnsmasq dunst emacs feh flatpak \
                       gamemode git grub lib32-pipewire libvirt linux-zen-headers lutris man-db \
                       mesa mesa-utils mpv ncdu neofetch neovim networkmanager ntfs-3g \
                       openbsd-netcat openssh os-prober pcmanfm pipewire pipewire-pulse playerctl \
                       python-pywal qemu-desktop reflector ripgrep rofi rsync tlp vde2 \
                       virt-manager virt-viewer wezterm wine-nine wine-staging \
                       winetricks wireplumber xbindkeys xclip \
                       xcompmgr xdg-desktop-portal-gtk xdg-user-dirs xdg-utils \
                       xdotool xf86-input-libinput xorg-server xorg-xinit \
                       xorg-xinput xorg-xrandr xorg-xset yt-dlp \
                       zsh zsh-autosuggestions
EOF

echo -e "\e[1;32mGRUB"
case $bios in
     /dev/*)
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    ;;
     *)
        arch-chroot /mnt grub-install --target=i386-pc $drive
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    ;;
esac

echo -e "\e[1;32mUSER CREATION"
arch-chroot /mnt systemctl enable NetworkManager tlp reflector.timer
arch-chroot /mnt useradd -mG wheel -s /bin/zsh $username
arch-chroot /mnt usermod -aG libvirt $username
arch-chroot /mnt <<EOF
echo "$username:$password" | chpasswd
EOF
echo -e "$username ALL=(ALL) NOPASSWD: ALL\n%wheel ALL=(ALL) NOPASSWD: ALL\n" >> /mnt/etc/sudoers

echo -e "\e[1;35mPart 3: Graphical Interface"
clear

arch-chroot /mnt sudo -i -u $username bash <<EOF
cd
echo -e "\e[1;35mDOTFILES"
git clone --depth=1 --separate-git-dir=.dots https://github.com/ghoulboii/dotfiles.git tmpdotfiles
rsync --recursive --verbose --exclude '.git' tmpdotfiles/ .
rm -rf tmpdotfiles
/usr/bin/git --git-dir=~/.dotfiles/ --work-tree=~ config --local status.showUntrackedFiles no
ln -sf ~/.config/shell/profile ~/.zprofile
mkdir ~/{dl,doc,music,pics}
xdg-user-dirs-update

echo -e "\e[1;35m# DWM"
git clone --depth=1 https://github.com/ghoulboii/dwm.git ~/.local/src/dwm
sudo make -sC ~/.local/src/dwm install

echo -e "\e[1;35mDWMBLOCKS"
git clone --depth=1 https://github.com/ghoulboii/dwmblocks ~/.local/src/dwmblocks
sudo make -sC ~/.local/src/dwmblocks install

echo -e "\e[1;35mYAY"
git clone --depth=1 https://aur.archlinux.org/yay-bin.git ~/.local/src/yay
cd ~/.local/src/yay
makepkg --noconfirm -rsi
rm -rf ~/.local/src/yay
EOF

echo -e "\e[1;35mAUR PACKAGES"
arch-chroot /mnt <<EOF
sudo -i -u $username yay -S --noconfirm autojump-rs devour jdk-temurin \
                                        lf-bin nerd-fonts-hack optimus-manager  \
                                        ttf-ms-fonts zsh-fast-syntax-highlighting
EOF

echo -e "\e[1;35mNVIDIA DRIVERS"
case $nvidia in
  1)
    arch-chroot /mnt sudo -i -u $username yay -S --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils
    ;;
  2)
    arch-chroot /mnt sudo -i -u $username yay -S --noconfirm nvidia-390xx-dkms nvidia-390xx-utils lib32-nvidia-390xx-utils
    ;;
esac

sed -i '$d' /mnt/etc/sudoers
exit
