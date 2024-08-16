#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
blue=$(tput setaf 6)
normal=$(tput sgr0)

input_drive() {
  local drive
  lsblk >&2
  read -p "Enter drive (Ex. - /dev/sda): " drive
  cfdisk $drive >&2
  echo "$drive"
}

input_linux_part() {
  local linux
  lsblk >&2
  read -p "Enter the Linux Partition (Ex. - /dev/sda2): " linux
  echo "$linux"
}

input_efi_part() {
  local efi
  read -p "Enter EFI partition (Ex. - /dev/sda2): " efi
  echo "$efi"
}

input_host() {
  local hostname
  while true :; do
    read -p "Enter the hostname: " hostname
    if [[ "${hostname}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
      break
    fi
    echo -e "${red}Incorrect Hostname!${normal}" >&2
  done
  echo "$hostname"
}

input_user() {
  local username
  while true :; do
    read -p "Enter username: " username
    if [[ "${username}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
      break
    fi
    echo -e "${red}Incorrect Username!${normal}" >&2
  done
  echo "$username"
}

input_pass() {
  local pass1 pass2
  while true :; do
    read -sp "Enter password: " pass1
    echo "" >&2
    read -sp "Re-enter password: " pass2
    if [[ "${pass1}" = "${pass2}" ]]; then
      break
    fi
    echo -e "\n${red}Passwords don't match.${normal}" >&2
  done
  echo "$pass1"
}

input_nvidia() {
  local nvidia
  echo -e "\nAmd and Intel Drivers will automatically work with the mesa package. The option below is only for Nvidia Graphics Card users." >&2
  read -p "Enter which graphics driver you use [Enter \"1\" for Nvidia or \"2\" for Legacy Nvidia Drivers (Driver 390)]: " nvidia
  echo "$nvidia"
}

create_subvol() {
  local drive="$1"
  echo -e "${cyan}CREATING SUBVOLUMES${normal}"
  mkfs.btrfs -fL Linux "$drive"
  mount "$drive" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@swap
  btrfs subvolume create /mnt/@var
  btrfs subvolume create /mnt/@tmp
  umount /mnt
}

mount_subvol() {
  local drive="$1"
  echo -e "${cyan}MOUNTING SUBVOLUMES${normal}"
  mount -o noatime,discard=async,compress=zstd:2,subvol=@ "$drive" /mnt
  mkdir /mnt/{home,swap,var,tmp}
  mount -o noatime,compress=zstd:2,subvol=@home "$drive" /mnt/home
  mount -o nodatacow,subvol=@swap "$drive" /mnt/swap
  mount -o nodatacow,subvol=@var "$drive" /mnt/var
  mount -o noatime,compress=zstd:2,subvol=@tmp "$drive" /mnt/tmp
}

create_swap() {
  echo -e "${cyan}CREATING SWAP${normal}"
  btrfs filesystem mkswapfile --size 2G /mnt/swap/swapfile
  swapon /mnt/swap/swapfile
}

create_efi() {
  local efi="$1"
  echo -e "${cyan}CREATING UEFI PARTITION${normal}"
  mkfs.fat -F 32 "$efi"
  mkdir /mnt/boot
  mount "$efi" /mnt/boot
}

install_base_pkg() {
  echo -e "${cyan}INSTALLING BASIC PACKAGES${normal}"
  local packages=(
    base
    base-devel
    linux-zen
    linux-zen-headers
    linux-firmware
    btrfs-progs
    intel-ucode
    grub
    networkmanager
    git
    libvirt
    reflector
    rsync
    xdg-user-dirs
    xdg-utils
    zsh
    bluez
    bluez-utils
    blueman
    xorg-server
    xorg-xinit
    libxft
    libxinerama
    ufw
  )
  pacstrap /mnt "${packages[@]}"
  genfstab -U /mnt >>/mnt/etc/fstab
}

conf_pacman() {
  echo -e "${green}PACMAN CONFIG${normal}"
  sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /mnt/etc/pacman.conf
  grep -q "ILoveCandy" /mnt/etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /mnt/etc/pacman.conf
  sed -i "/^#ParallelDownloads/s/=.*/= 5/;s/^#Color$/Color/" /mnt/etc/pacman.conf
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
}

conf_locale_hosts() {
  local hostname="$1"
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
  arch-chroot /mnt hwclock --systohc
  echo "en_US.UTF-8 UTF-8" >>/mnt/etc/locale.gen
  arch-chroot /mnt locale-gen
  echo "LANG=en_US.UTF-8" >>/mnt/etc/locale.conf
  echo "$hostname" >/mnt/etc/hostname
  echo "127.0.0.1 localhost" >>/mnt/etc/hosts
  echo "::1       localhost" >>/mnt/etc/hosts
  echo "127.0.1.1 $hostname.localdomain $hostname" >>/mnt/etc/hosts
}

install_grub() {
  local efi="$1"
  local drive="$2"
  echo -e "${green}GRUB${normal}"
  case "$efi" in
    /dev/*)
      arch-chroot /mnt pacman -Sy --noconfirm efibootmgr
      arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
      ;;
    *)
      arch-chroot /mnt grub-install --target=i386-pc $drive
      ;;
  esac
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

create_user() {
  local username="$1"
  echo -e "${green}USER CREATION${normal}"
  arch-chroot /mnt systemctl enable NetworkManager libvirtd paccache.timer bluetooth ufw.service
  arch-chroot /mnt useradd -mG wheel -s /bin/zsh username
  arch-chroot /mnt usermod -aG libvirt username
}

pass_root() {
  local pass="$1"
  arch-chroot /mnt bash -c "echo root:$pass | chpasswd"
}

pass_user() {
  local username="$1"
  local pass="$2"
  arch-chroot /mnt bash -c "echo $username:$pass | chpasswd"
}

setup_ufw() {
  arch-chroot /mnt <<EOF
  ufw enable
  ufw logging off
  ufw default deny
  ufw allow from 192.168.0.0/24
  ufw allow 443
  ufw allow 80
  ufw limit 22
  ufw limit ssh
EOF
}

setup_dotfiles() {
  local username="$1"
  echo -e "${blue}DOTFILES${normal}"
  arch-chroot /mnt sudo -i -u $username bash <<EOF
  cd
  git clone --depth=1 --separate-git-dir=.dots https://github.com/ghoulboii/dotfiles.git tmpdotfiles
  rsync --recursive --verbose --exclude '.git' tmpdotfiles/ .
  rm -rf tmpdotfiles
  /usr/bin/git --git-dir=.dots/ --work-tree=~ config --local status.showUntrackedFiles no
  mkdir ~/{dl,doc,pics}
  xdg-user-dirs-update
  echo 'ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' > /etc/zsh/zshenv
EOF
}

setup_paru() {
  local username="$1"
  arch-chroot /mnt sudo -i -u "$username" bash <<EOF
  echo -e "${blue}PARU${normal}"
  git clone --depth=1 https://aur.archlinux.org/paru-bin.git ~/.local/src/paru
  cd ~/.local/src/paru
  makepkg --noconfirm -rsi
  rm -rf ~/.local/src/paru
EOF
}

setup_dwm() {
  local username="$1"
  arch-chroot /mnt sudo -i -u "$username" bash <<EOF
  echo -e "${blue}DWM${normal}"
  git clone --depth=1 https://github.com/ghoulboii/dwm.git ~/.local/src/dwm
  sudo make -sC ~/.local/src/dwm install
EOF
}

setup_dwmblocks() {
  local username="$1"
  arch-chroot /mnt sudo -i -u "$username" bash <<EOF
  echo -e "${blue}DWMBLOCKS${normal}"
  git clone --depth=1 https://github.com/ghoulboii/dwmblocks.git ~/.local/src/dwmblocks
  sudo make -sC ~/.local/src/dwmblocks install
EOF
}

setup_st() {
  local username="$1"
  arch-chroot /mnt sudo -i -u "$username" bash <<EOF
  echo -e "${blue}ST${normal}"
  git clone --depth=1 https://github.com/ghoulboii/st.git ~/.local/src/st
  sudo make -sC ~/.local/src/st install
EOF
}

setup_dmenu() {
  local username="$1"
  arch-chroot /mnt sudo -i -u "$username" bash <<EOF
  echo -e "${blue}DMENU${normal}"
  git clone --depth=1 https://github.com/ghoulboii/dmenu.git ~/.local/src/dmenu
  sudo make -sC ~/.local/src/dmenu install
EOF
}

setup_neovim() {
  local username="$1"
  arch-chroot /mnt sudo -i -u "$username" bash <<EOF
  echo -e "${blue}NEOVIM${normal}"
  git clone --depth=1 https://github.com/ghoulboii/nvim.git ~/.config/nvim
EOF
}

install_packages() {
  local username="$1"
  echo -e "\${blue}PACKAGES\${normal}"
  # FIX: Add a new gtk theme, need more testing
  # package_array=($(echo "$packages"))
  #
  # paru -S "${package_array[@]}"
  local packages=(
    acpi
    bat
    btop
    deno
    easyeffects
    exa
    fastfetch
    fd
    feh
    firefox
    fzf
    jdk8-openjdk
    jdk17-openjdk
    gamemode
    gimp
    gparted
    lf
    libqalculate
    man-db
    mesa
    mpv
    mpv-mpris
    ncdu
    neovim
    newsboat
    noto-fonts
    noto-fonts-emoji
    npm
    obs-studio
    openssh
    os-prober
    pavucontrol
    pacman-contrib
    pcmanfm-gtk3
    pipewire
    pipewire-pulse
    playerctl
    prismlauncher-bin
    python-pywal
    qbittorrent
    qt5-styleplugins
    qt6gtk2
    reflector
    ripgrep
    rose-pine-gtk-theme
    socat
    tldr
    tmux
    trash-cli
    ttf-firacode-nerd
    ttf-ms-fonts
    unclutter
    udiskie
    ueberzugpp
    webkit2gtk
    wget
    wine-staging
    winetricks
    wireplumber
    xbindkeys
    xclip
    xdg-desktop-portal-gtk
    xdotool
    xf86-input-libinput
    xorg-xev
    xorg-xinput
    xorg-xrandr
    xorg-xset
    xsel
    yt-dlp
    zathura
    zathura-pdf-mupdf
    zoxide
    zsh-autosuggestions
    zsh-completions
    zsh-fast-syntax-highlighting
    zsh-history-substring-search
    zstd
  )
  arch-chroot /mnt sudo -i -u "$username" paru -Sy --noconfirm --needed "${packages[@]}"
}

install_nvidia() {
  local nvidia="$1"
  local username="$2"
  case "$nvidia" in
    1)
      echo -e "${blue}NVIDIA DRIVERS${normal}"
      arch-chroot /mnt sudo -i -u "$username" paru -S --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils
      ;;
    2)
      echo -e "${blue}NVIDIA DRIVERS${normal}"
      arch-chroot /mnt sudo -i -u "$username" paru -S --noconfirm nvidia-390xx-dkms nvidia-390xx-utils lib32-nvidia-390xx-utils
      ;;
  esac
}

post_install_cleanup() {
  local username="$1"
  sed -i '$d' /mnt/etc/sudoers
  rm -rf /mnt/home/"$username"/.bash*
}


main() {
  clear
  cat <<"EOF"
         _nnnn_
        dGGGGMMb     ,""""""""""""""""".
       @p~qp~~qMb    | i use arch btw! |
       M|@||@) M|   _;.................'
       @,----.JM| -'
      JS^\__/  qKL
     dZP        qKRb
    dZP          qKKb
   fZP            SMMb
   HZM            MMMM
   FqM            MMMM
 __| ".        |\dS"qML
 |    `.       | `' \Zq
_)      \.___.,|     .'
\____   )MMMMMM|   .'
     `-'       `--'
EOF

  echo -e "${blue}Ksh's Arch Installer${normal}"
  echo -e "${blue}Script will take 15-30 min to run so sit back and enjoy a cup of coffee :)${normal}"
  echo -e "${blue}Part 1: Partition Setup${normal}"
  local drive=$(input_drive)
  local linux=$(input_linux_part)
  if [[ -d "/sys/firmware/efi" ]]; then
    local efi=$(input_efi_part)
  fi
  local hostname=$(input_host)
  local username=$(input_user)
  local pass=$(input_pass)
  local nvidia=$(input_nvidia)

  sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf
  pacman --noconfirm -Sy archlinux-keyring
  reflector -c $(curl https://ifconfig.co/country-iso) --sort rate -a 24 -f 5 -p https --save /etc/pacman.d/mirrorlist
  timedatectl set-ntp true

  umount -A --recursive /mnt
  create_subvol "$linux"
  mount_subvol "$linux"
  create_swap

  case $efi in
    /dev/*)
      create_efi "$efi"
  esac


  echo -ne "${green}Successful! Moving to Part 2${normal}"
  for i in {1..5}; do
    echo -n .
    sleep 1
  done
  clear
  echo -e "${blue}Part 2: Base System${normal}"

  install_base_pkg
  conf_pacman
  conf_locale_hosts "$hostname"
  install_grub "$efi" "$drive"
  create_user "$username"
  pass_root "$pass"
  pass_user "$username" "$pass"
  setup_ufw


  echo -ne "${green}Successful! Moving to Part 3${normal}"
  for i in {1..5}; do
    echo -n .
    sleep 1
  done
  clear
  echo -e "${blue}Part 3: Graphical Interface${normal}"

  echo -e "$username ALL=(ALL) NOPASSWD: ALL\n%wheel ALL=(ALL) NOPASSWD: ALL\n" >>/mnt/etc/sudoers
  nc=$(grep -c ^processor /proc/cpuinfo)
  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /mnt/etc/makepkg.conf
  sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /mnt/etc/makepkg.conf

  setup_dotfiles "$username"
  setup_paru "$username"
  setup_dwm "$username"
  setup_dwmblocks "$username"
  setup_st "$username"
  setup_dmenu "$username"
  setup_neovim "$username"

  install_packages "$username"
  install_nvidia "$nvidia" "$username"
  post_install_cleanup "$username"

  echo -e "${green}Script finished without errors! Reboot now and enjoy ^_^${normal}"
}
main "$@"
