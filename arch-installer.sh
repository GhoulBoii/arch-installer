#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
blue=$(tput setaf 6)
normal=$(tput sgr0)

# TODO: Secure boot

# TODO: Check if this works or not
# Update the sudo timestamp immediately
if ! sudo -v; then
  echo "${red}Password incorrect or sudo failed. Exiting.${normal}"
  exit 1
fi

# BACKGROUND JOB: Keep-alive for sudo
# This loop runs in the background and refreshes the sudo timeout every 60 seconds.
# It checks if the parent process ($$) is still running; if not, it exits.
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

conf_makepkg() {
  echo -e "${green}MAKEPKG CONFIG${normal}"
  nc=$(grep -c ^processor /proc/cpuinfo)
  sudo sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
  sudo sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf
}

conf_pacman() {
  echo -e "${green}PACMAN CONFIG${normal}"
  grep -q "ILoveCandy" /etc/pacman.conf || sudo sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
  sudo sed -i "s/^#Color$/Color/" /etc/pacman.conf
}

setup_aur() {
  if [ ! -d "$HOME/.local/src/aur_helper" ]; then
    echo "AUR helper present. Skipping."
    return
  fi
  echo -e "${blue}AUR Helper${normal}"
  sudo pacman -S --noconfirm --needed git base-devel
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git ~/.local/src/aur_helper
  makepkg --clean --install --noconfirm --rmdeps --syncdeps --dir ~/.local/src/aur_helper
  rm -rf ~/.local/src/aur_helper
}

install_packages() {
  echo -e "${blue}PACKAGES${normal}"
  # Read file into 'packages' array, filtering out:
  # 1. Comments (^#)
  # 2. Empty lines (^$)
  mapfile -t packages < <(grep -vE '^#|^$' packages.txt)
  yay -S --noconfirm --needed "${packages[@]}"
}

setup_firewall() {
  echo -e "${green}FIREWALL${normal}"
  ufw enable
  ufw logging off
  ufw default deny
  ufw allow from 192.168.1.0/24
  ufw limit ssh
}

setup_dotfiles() {
  echo -e "${blue}DOTFILES${normal}"
  sudo pacman -S --noconfirm --needed chezmoi
  chezmoi init --apply ksharizard
}

setup_neovim() {
  if [ ! -d "$HOME/.config/nvim" ]; then
    echo "Neovim config present. Skipping."
    return
  fi
  echo -e "${blue}NEOVIM${normal}"
  sudo pacman -S --noconfirm --needed neovim
  git clone --depth=1 https://github.com/ghoulboii/nvim ~/.config/nvim
  git --git-dir=~/.config/nvim/.git --work-tree=~/.config/nvim remote set-url origin git@github.com:ghoulboii/nvim
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

  conf_makepkg
  conf_pacman
  setup_aur
  install_packages

  setup_firewall
  setup_dotfiles
  setup_neovim
  rm -rf ~/.bash*

  # systemctl enable paccache.timer

  echo -e "${green}Script finished without errors ^_^${normal}"
}
main "$@"
