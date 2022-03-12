#!/usr/bin/env bash 

# Part 1: Getting Partitions Ready

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "GhoulBoi's Arch Installer"
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
mkfs.btrfs -L Linux $linux 
mount $linux /mnt
case $swapcreation in
  /dev/*)
    mkswap $swapcreation
    swapon $swap
    ;;
esac
case $bios in
  /dev/*)
    mkfs.fat -F 32 $bios
    ;;
esac 
pacstrap /mnt base base-devel linux-zen linux-firmware intel-ucode 
genfstab -U /mnt >> /mnt/etc/fstab
sed '1,/^#Part 2$/d' `basename $0` > /mnt/arch_install2.sh
chmod +x /mnt/arch_install2.sh
arch-chroot /mnt ./arch_install2.sh

# Part 2: Users and Base System

sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf
gawk -i inplace '$0=="#[multilib]"{c=2} c&&c--{sub(/#/,"")} 1' /etc/pacman.conf 
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo $hostname > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts
mkinitcpio -P
passwd
pacman -S --no-confirm grub os-prober networkmanager reflector linux-headers xdg-user-dirs xdg-utils pipewire pipewire-pulse openssh tlp \
  virt-manager qemu virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat flatpak ntfs-3g
read -P    
