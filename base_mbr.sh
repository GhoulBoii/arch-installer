#!/bin/bash 

echo "GhoulBoi's ArchInstaller Script"
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf
pacman --noconfirm -Sy 
timedatectl set-ntp true
lsblk
echo "Enter drive (Ex. - /dev/sda): "
read drive
cfdisk $drive
echo "Enter the Linux Partition: "
read linux
