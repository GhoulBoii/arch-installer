#!/bin/bash 

# Part 1: Getting Partitions Ready and Stuff

echo "GhoulBoi's ArchInstaller Script"
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf
pacman --noconfirm -Sy 
timedatectl set-ntp true
lsblk
read -p "Enter drive (Ex. - /dev/sda): " drive
cfdisk $drive
read -p "Enter the Linux Partition: " linux
mkfs.btrfs -L Linux $linux 
read -p "Was a SWAP parition created? [y/n]: " swapcreation
if [[ $swapcreation = y ]] ; then
  read -p "Enter SWAP partition (Ex. - /dev/sda2): " swap
  mkswap $swap
  swapon $swap
fi

mount $linux /mnt
pacstrap /mnt base base-devel linux-zen linux-firmware intel-ucode 
genfstab -U /mnt >> /mnt/etc/fstab
sed '1,/^#Part 2$/d' `basename $0` > /mnt/arch_install2.sh
chmod +x /mnt/arch_install2.sh
arch-chroot /mnt ./arch_install2.sh

# Part 2: Users and Base System

sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf
sed -i '/^#\[multilib]/{N;s/\n#/\n/}' /etc/pacman.conf
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
read -p "Enter the hostname: " hostname
echo $hostname > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts
mkinitcpio -P
passwd
pacman -S --no-confirm grub os-prober networkmanager reflector linux-headers xdg-user-dirs xdg-utils pipewire pipewire-pulse openssh tlp \
  virt-manager qemu virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat flatpak ntfs-3g
read -P 
