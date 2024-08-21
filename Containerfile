ARG CORE_BRANCH=main
ARG SUFFIX=
ARG DESKTOP=nogui

FROM ghcr.io/commonarch/system-base${SUFFIX}-${DESKTOP}:main

ARG CORE_BRANCH=main
ARG VARIANT=general
ARG DESKTOP=nogui

RUN install-packages-build distrobox openssh curl wget git

RUN useradd -m -s /bin/bash aur && \
    echo "aur ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/aur && \
    mkdir -p /tmp_aur_build && chown -R aur /tmp_aur_build && \
    install-packages-build base-devel; \
    runuser -u aur -- env -C /tmp_aur_build git clone 'https://aur.archlinux.org/paru-bin.git' && \
    runuser -u aur -- env -C /tmp_aur_build/paru-bin makepkg -si --noconfirm && \
    rm -rf /tmp_aur_build && \
    runuser -u aur -- paru -S --noconfirm ptyxis podman apx-gui; \
    userdel -rf aur; rm -rf /home/aur /etc/sudoers.d/aur

COPY overlays/common overlay[s]/${DESKTOP} /

RUN <<EOF
cd /

git clone https://github.com/Vanilla-OS/vanilla-apx-configs /usr/share/apx
rm -rf /usr/share/apx/.git*
cat > /etc/apx/apx.json <<'EOT'
{
    "apxPath": "/usr/share/apx",
    "distroboxPath": "/usr/bin/distrobox",
    "storageDriver": "overlay"
}
EOT
mkdir -p /usr/share/icons/hicolor/{symbolic,scalable}/{actions,apps,legacy}

for icon in container-terminal-symbolic history-undo-symbolic package-symbolic puzzle-piece-symbolic; do
    wget -O "/usr/share/icons/hicolor/symbolic/actions/vanilla-${icon}.svg" \
        "https://raw.githubusercontent.com/Vanilla-OS/first-setup/main/data/icons/hicolor/symbolic/actions/vanilla-${icon}.svg"
    cp "/usr/share/icons/hicolor/symbolic/actions/vanilla-${icon}.svg" "/usr/share/icons/hicolor/scalable/actions"
done

wget -O /usr/share/icons/hicolor/symbolic/apps/org.gnome.SystemMonitor-symbolic.svg \
    https://gitlab.gnome.org/GNOME/gnome-system-monitor/-/raw/master/data/icons/public/hicolor/symbolic/apps/org.gnome.SystemMonitor-symbolic.svg?ref_type=heads&inline=false

if [ "$DESKTOP" = gnome ]; then
    pacman -Rcns --noconfirm gnome-console

    find /usr/share/metainfo \
        ! -name "org.freedesktop.appstream.cli.metainfo.xml" \
        ! -name "org.freedesktop.appstream.compose.metainfo.xml" \
        ! -name "org.gnome.Software.Plugin.Flatpak.metainfo.xml" \
        ! -name "org.gnome.Software.Plugin.Fwupd.metainfo.xml" -type f -exec rm -f {} +
elif [ "$DESKTOP" = plasma ]; then
    pacman -Rcns --noconfirm konsole yakuake
    install-packages-build spectacle

    cp /usr/share/icons/Adwaita/symbolic/legacy/preferences-desktop-apps-symbolic.svg /usr/share/icons/hicolor/symbolic/legacy
    wget -O /usr/share/icons/hicolor/scalable/apps/org.gnome.SystemMonitor-symbolic.svg \
        https://gitlab.gnome.org/GNOME/gnome-system-monitor/-/raw/master/data/icons/public/hicolor/symbolic/apps/org.gnome.SystemMonitor-symbolic.svg?ref_type=heads&inline=false
fi

glib-compile-schemas /usr/share/glib-2.0/schemas

rm -f /usr/share/applications/stoken-gui.desktop
rm -f /usr/share/applications/stoken-gui-small.desktop
rm -f /usr/share/applications/qvidcap.desktop
rm -f /usr/share/applications/qv4l2.desktop
rm -f /usr/share/applications/bvnc.desktop
rm -f /usr/share/applications/electron*.desktop
rm -f /usr/share/applications/avahi-discover.desktop
rm -f /usr/share/applications/bssh.desktop

gtk-update-icon-cache

if [ "$VARIANT" = nvidia ]; then
    install-packages-build nvidia-settings nvidia-prime

    echo >> /etc/default/grub
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} nvidia_drm.modeset=1"' >> /etc/default/grub

    mkdir -p /etc/modprobe.d
    echo 'options nvidia "NVreg_PreserveVideoMemoryAllocations=1"' > /etc/modprobe.d/nvidia.conf

    systemctl enable nvidia-suspend nvidia-hibernate nvidia-resume
EOF

RUN rm -f /.gitkeep
RUN yes | pacman -Scc
