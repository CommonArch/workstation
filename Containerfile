ARG CORE_BRANCH=main
ARG SUFFIX=
ARG DESKTOP=nogui

FROM ghcr.io/commonarch/system-base${SUFFIX}-${DESKTOP}:main

ARG CORE_BRANCH=main
ARG VARIANT=general
ARG DESKTOP=nogui

RUN install-packages-build distrobox

RUN useradd -m -s /bin/bash aur && \
    echo "aur ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/aur && \
    mkdir -p /tmp_aur_build && chown -R aur /tmp_aur_build && \
    install-packages-build git base-devel; \
    runuser -u aur -- env -C /tmp_aur_build git clone 'https://aur.archlinux.org/paru-bin.git' && \
    runuser -u aur -- env -C /tmp_aur_build/paru-bin makepkg -si --noconfirm && \
    rm -rf /tmp_aur_build && \
    runuser -u aur -- paru -S --noconfirm boxbuddy ptyxis waydroid; \
    userdel -rf aur; rm -rf /home/aur /etc/sudoers.d/aur

COPY overlays/common overlay[s]/${DESKTOP} /

RUN <<EOF
if [ "$DESKTOP" == gnome ]; then
    pacman -Rcns --noconfirm gnome-console

    find /usr/share/metainfo \
        ! -name "org.freedesktop.appstream.cli.metainfo.xml" \
        ! -name "org.freedesktop.appstream.compose.metainfo.xml" \
        ! -name "org.gnome.Software.Plugin.Flatpak.metainfo.xml" \
        ! -name "org.gnome.Software.Plugin.Fwupd.metainfo.xml" -type f -exec rm -f {} +
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
EOF

RUN rm -f /.gitkeep
RUN yes | pacman -Scc
