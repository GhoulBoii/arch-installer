#!/usr/bin/env bash 
# Part 1: Getting Partitions Ready

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
read -p "Enter username: " username
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
    mdkir /mnt/boot
    mount $bios /mnt/boot
    ;;
esac 
pacstrap /mnt base base-devel linux-zen linux-firmware btrfs-progs intel-ucode 
genfstab -U /mnt >> /mnt/etc/fstab

# Part 2: Users and Base System

printf '\033c'
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /mnt/etc/pacman.conf
ln -sf /usr/share/zoneinfo/Asia/Kolkata /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo $hostname > /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts
echo "Enter your root password: "
arch-chroot /mnt passwd
pacman -Sy --noconfirm grub os-prober networkmanager reflector linux-headers xdg-user-dirs xdg-utils pipewire pipewire-pulse openssh tlp \
  virt-manager qemu virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat flatpak ntfs-3g tlp
case $bios in
     /dev/*)
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    ;;
      n)
        arch-chroot /mnt grub-install --target=i386-pc $drive
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    ;;
esac
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable tlp
arch-chroot /mnt systemctl enable reflector.timer
archroot /mnt useradd -mG libvirt wheel -s /bin/zsh $username
arch-chroot /mnt passwd $username
sed '/# %wheel ALL=(ALL:ALL) ALL/s/^#//' /mnt/etc/sudoers
