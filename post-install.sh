arch-chroot /mnt <<EOF
sudo -i -u $username flatpak install -y org.mozilla.firefox com.github.tchx84.Flatseal \
                                        com.github.wwmm.easyeffects com.valvesoftware.Steam \
                                        org.flameshot.Flameshot org.gimp.Gimp org.libreoffice.LibreOffice \
                                        org.polymc.PolyMC org.qbittorrent.qBittorrent sh.ppy.osu
EOF
