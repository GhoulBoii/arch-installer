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

