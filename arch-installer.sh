#!/usr/bin/env bash

input_drive() {
	lsblk >&2
	read -p "Enter drive (Ex. - /dev/sda): " drive
	cfdisk $drive >&2
	echo $drive
}

input_linux_part() {
	lsblk >&2
	read -p "Enter the Linux Partition (Ex. - /dev/sda2): " linux
	echo $linux
}

input_efi_part() {
	read -p "Enter EFI partition (Ex. - /dev/sda2): " efi
	echo $efi
}

input_host() {
	while true :; do
		read -p "Enter the hostname: " hostname
		if [[ "${hostname}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
			break
		fi
		echo -e "\e[1;31mIncorrect Hostname!\e[0m" >&2
	done
	echo $hostname
}

input_user() {
	while true :; do
		read -p "Enter username: " username
		if [[ "${username}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
			break
		fi
		echo -e "\e[1;31mIncorrect Username!\e[0m" >&2
	done
	echo $username
}

input_pass() {
	while true :; do
		read -sp "Enter password: " pass1
		echo "" >&2
		read -sp "Re-enter password: " pass2
		if [[ "${pass1}" = "${pass2}" ]]; then
			break
		fi
		echo -e "\n\e[1;31mPasswords don't match.\e[0m" >&2
	done
	echo $pass1
}

input_nvidia() {
	echo -e "\nAmd and Intel Drivers will automatically work with the mesa package. The option below is only for Nvidia Graphics Card users." >&2
	read -p "Enter which graphics driver you use (Enter \"1\" for Nvidia or \"2\" for Legacy Nvidia Drivers (Driver 390): " nvidia
	echo $nvidia
}

create_subvol() {
	echo -e "\e[1;36mCREATING SUBVOLUMES\e[0m"
	mkfs.btrfs -fL Linux $1
	mount $1 /mnt
	btrfs subvolume create /mnt/@
	btrfs subvolume create /mnt/@home
	btrfs subvolume create /mnt/@swap
	btrfs subvolume create /mnt/@var
	btrfs subvolume create /mnt/@tmp
	umount /mnt
}

mount_subvol() {
	echo -e "\e[1;36mMOUNTING SUBVOLUMES\e[0m"
	mount -o noatime,discard=async,compress=zstd:2,subvol=@ $1 /mnt
	mkdir /mnt/{home,swap,var,tmp}
	mount -o noatime,compress=zstd:2,subvol=@home $1 /mnt/home
	mount -o nodatacow,subvol=@swap $1 /mnt/swap
	mount -o nodatacow,subvol=@var $1 /mnt/var
	mount -o noatime,compress=zstd:2,subvol=@tmp $1 /mnt/tmp
}

create_swap() {
	echo -e "\e[1;36mCREATING SWAP\e[0m"
	truncate -s 0 /mnt/swap/swapfile
	chattr +C /mnt/swap/swapfile
	dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=2048
	chmod 600 /mnt/swap/swapfile
	chown root /mnt/swap/swapfile
	mkswap /mnt/swap/swapfile
	swapon /mnt/swap/swapfile
}

create_efi() {
  echo -e "\e[1;36mCREATING UEFI PARTITION\e[0m"
  mkfs.fat -F 32 $1
  mdkir /mnt/boot
  mount $1 /mnt/boot
}

install_base_pkg() {
	echo -e "\e[1;36mINSTALLING BASIC PACKAGES\e[0m"
	pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware btrfs-progs intel-ucode grub networkmanager git libvirt reflector rsync xdg-user-dirs xdg-utils zsh pacman-contrib bluez bluez-utils blueman xorg-server xorg-xinit
	genfstab -U /mnt >>/mnt/etc/fstab
}

conf_pacman() {
	echo -e "\e[1;32\PACMAN CONFIG\e[0m"
	sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /mnt/etc/pacman.conf
	grep -q "ILoveCandy" /mnt/etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /mnt/etc/pacman.conf
	sed -i "/^#ParallelDownloads/s/=.*/= 5/;s/^#Color$/Color/" /mnt/etc/pacman.conf
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
}

conf_locale_hosts() {
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
  arch-chroot /mnt hwclock --systohc
  echo "en_US.UTF-8 UTF-8" >>/mnt/etc/locale.gen
  arch-chroot /mnt locale-gen
  echo "LANG=en_US.UTF-8" >>/mnt/etc/locale.conf
  echo $hostname >/mnt/etc/hostname
  echo "127.0.0.1 localhost" >>/mnt/etc/hosts
  echo "::1       localhost" >>/mnt/etc/hosts
  echo "127.0.1.1 $hostname.localdomain $hostname" >>/mnt/etc/hosts
}

install_grub() {
  echo -e "\e[1;32mGRUB\e[0m"
  case $1 in
  /dev/*)
    arch-chroot /mnt pacman -Sy --noconfirm efibootmgr
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    ;;
  *)
    arch-chroot /mnt grub-install --target=i386-pc $2
    ;;
  esac
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

create_user() {
  echo -e "\e[1;32mUSER CREATION\e[0m"
  arch-chroot /mnt systemctl enable NetworkManager libvirtd paccache.timer bluetooth
  arch-chroot /mnt useradd -mG wheel -s /bin/zsh $1
  arch-chroot /mnt usermod -aG libvirt $1
}

pass_root() {
  arch-chroot /mnt echo "root:$1" | chpasswd
}

pass_user() {
  arch-chroot /mnt echo "$1:$2" | chpasswd
}

arch-chroot /mnt sudo -i -u $username bash <<EOF
cd
echo -e "\e[1;35mDOTFILES\e[0m"
git clone --depth=1 --separate-git-dir=.dots https://github.com/ghoulboii/dotfiles.git tmpdotfiles
rsync --recursive --verbose --exclude '.git' tmpdotfiles/ .
rm -rf tmpdotfiles
/usr/bin/git --git-dir=.dots/ --work-tree=~ config --local status.showUntrackedFiles no
mkdir ~/{dl,doc,pics}
xdg-user-dirs-update

echo -e "\e[1;35mPARU\e[0m"
git clone --depth=1 https://aur.archlinux.org/paru-bin.git ~/.local/src/paru
cd ~/.local/src/paru
makepkg --noconfirm -rsi
rm -rf ~/.local/src/paru

echo -e "\e[1;35mDWM\e[0m"
cd
paru -S --noconfirm libxft libxinerama
git clone --depth=1 https://github.com/ghoulboii/dwm.git ~/.local/src/dwm
sudo make -sC ~/.local/src/dwm install

echo -e "\e[1;35mDWMBLOCKS\e[0m"
git clone --depth=1 https://github.com/ghoulboii/dwmblocks.git ~/.local/src/dwmblocks
sudo make -sC ~/.local/src/dwmblocks install

echo -e "\e[1;35mST\e[0m"
git clone --depth=1 https://github.com/ghoulboii/st.git ~/.local/src/st
sudo make -sC ~/.local/src/st install

echo -e "\e[1;35mDMENU\e[0m"
git clone --depth=1 https://github.com/ghoulboii/dmenu.git ~/.local/src/dmenu
sudo make -sC ~/.local/src/dmenu install

echo -e "\e[1;35mNEOVIM\e[0m"
git clone --depth=1 https://github.com/ghoulboii/nvim.git ~/.config/nvim
EOF

echo -e "\e[1;35mPACKAGES\e[0m"
arch-chroot /mnt <<EOF
sudo -i -u $username paru -Sy --noconfirm acpi bat btop catppuccin-gtk-theme-mocha deno easyeffects exa fd feh \
                                          firefox fzf jdk8-openjdk jdk17-openjdk gamemode gimp gparted lf-bin \
                                          lib32-gamemode lib32-pipewire libqalculate libreoffice-fresh \
                                          man-db mesa \
                                          mpv mpv-mpris ncdu neofetch neovim ttf-firacode-nerd \
                                          newsboat noto-fonts noto-fonts-emoji npm obs-studio \
                                          openssh os-prober pavucontrol pcmanfm-gtk3 pipewire \
                                          pipewire-pulse playerctl prismlauncher-bin python-pywal \
                                          qbittorrent qt6ct reflector ripgrep socat tldr tmux trash-cli \
                                          ttf-ms-fonts ueberzug wget wine-staging winetricks wireplumber \
                                          xbindkeys xclip xdg-desktop-portal-gtk xdotool \
                                          xf86-input-libinput xorg-xev xorg-xinput xorg-xrandr xorg-xset \
                                          xsel yt-dlp zathura zathura-pdf-mupdf zoxide \
                                          zsh-autosuggestions zsh-completions \
                                          zsh-fast-syntax-highlighting zsh-history-substring-search zstd
EOF
install_nvidia() {
  case $nvidia in
  1)
    echo -e "\e[1;35mNVIDIA DRIVERS\e[0m"
    arch-chroot /mnt sudo -i -u $username paru -S --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils
    ;;
  2)
    echo -e "\e[1;35mNVIDIA DRIVERS\e[0m"
    arch-chroot /mnt sudo -i -u $username paru -S --noconfirm nvidia-390xx-dkms nvidia-390xx-utils lib32-nvidia-390xx-utils
    ;;
  esac
}
post_install_cleanup() {
  sed -i '$d' /mnt/etc/sudoers
  arch-chroot /mnt sudo -i -u $username ln -sf /home/$username/.config/shell/profile /home/$username/.zprofile
  rm -rf /mnt/home/$username/.bash*
}





main() {
  clear
  echo -e "\e[1;32mGhoulBoi's Arch Installer\e[0m"
  echo -e "\e[1;32mPart 1: Partition Setup\e[0m"
  drive=$(input_drive)
  linux=$(input_linux_part)
  if [[ -d "/sys/firmware/efi" ]]; then
    efi=$(input_efi_part)
  fi
  hostname=$(input_host)
  username=$(input_user)
  pass=$(input_pass)
  nvidia=$(input_nvidia)

  sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf
  pacman --noconfirm -Sy archlinux-keyring
  reflector -c $(curl https://ifconfig.co/country-iso) --sort rate -a 24 -f 5 -p https --save /etc/pacman.d/mirrorlist
  timedatectl set-ntp true

  create_subvol "$drive"
  mount_subvol "$drive"
  create_swap

  case $efi in
  /dev/*)
    create_efi "$efi"
  esac

  clear
  echo -e "\e[1;32mPart 2: Base System\e[0m"

  install_base_pkg
  conf_pacman
  conf_locale_hosts
  install_grub "$efi" "$drive"
  create_user "$username"
  pass_root "$pass"
  pass_user "$username" "$pass"
  sed -i 's/MODULES=()/MODULES=(btrfs)/' /mnt/etc/mkinitcpio.conf

  for i in {5..1}; do
    echo -e "\e[1;35mREBOOTING IN $i SECONDS...\e[0m"
    sleep 1
  done
  echo -e "\e[1;35mSCRIPT FINISHED! REBOOTING NOW...\e[0m"
  reboot
 }
 main "$@"
