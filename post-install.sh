flatpak install -y org.mozilla.firefox com.github.tchx84.Flatseal \
                                        com.github.wwmm.easyeffects com.google.Chrome com.valvesoftware.Steam \
                                        org.flameshot.Flameshot org.gimp.Gimp/x86_64/stable org.libreoffice.LibreOffice \
                                        com.obsproject.Studio org.polymc.PolyMC org.qbittorrent.qBittorrent sh.ppy.osu \
                                        org.freedesktop.Platform.ffmpeg-full/x86_64/21.08

# Installing Lutris from Beta repositories (May have to change when it comes to stable)
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak update --appstream
flatpak install -y flatpak install flathub org.gnome.Platform.Compat.i386 org.freedesktop.Platform.GL32.default org.freedesktop.Platform.GL.default \
flatpak install -y flathub-beta net.lutris.Lutris
