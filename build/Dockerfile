# Linux Classroom guest image.
#
# Everything a student needs is installed here, at build time. The virtual
# machine has no network, so `apk add` can never run inside it.
#
# Build with build/build.sh (needs Docker). Based on
# v86/tools/docker/alpine/Dockerfile.

FROM docker.io/i386/alpine:3.21.0

ENV KERNEL=virt

RUN apk add --no-cache \
      openrc alpine-base agetty alpine-conf \
      linux-$KERNEL linux-firmware-none \
      bash bash-completion \
      nano less \
      mandoc man-pages \
      kbd-bkeymaps \
      shadow \
      doas \
      build-base

# ---------------------------------------------------------------------------
# console: autologin as the student account on tty1
# ---------------------------------------------------------------------------
RUN sed -i 's/getty 38400 tty1/agetty --autologin student tty1 linux/' /etc/inittab
RUN echo 'ttyS0::respawn:/sbin/agetty --autologin root -s ttyS0 115200 vt100' >> /etc/inittab

# root works without a password (shadow's chpasswd refuses an empty password,
# so clear the field directly)
RUN sed -i 's/^root:[^:]*:/root::/' /etc/passwd

# ---------------------------------------------------------------------------
# the student account
# ---------------------------------------------------------------------------
RUN adduser -D -s /bin/bash student \
 && echo "student:student" | chpasswd \
 && addgroup student wheel

# bash everywhere: every existing account
RUN awk -F: 'BEGIN{OFS=":"} { if ($7=="/bin/sh" || $7=="/bin/ash") $7="/bin/bash"; print }' \
      /etc/passwd > /etc/passwd.new \
 && mv /etc/passwd.new /etc/passwd

# ---------------------------------------------------------------------------
# files from build/rootfs/ (same paths inside the image)
#   /usr/local/sbin/adduser        new accounts get bash
#   /etc/doas.conf                 passwordless doas for wheel
#   /etc/profile.d/classroom.sh    bash prompt and LANG
#   /etc/skel/.bashrc              bash defaults for new accounts
#   /etc/motd                      short welcome text
# ---------------------------------------------------------------------------
COPY rootfs/ /
RUN chmod 755 /usr/local/sbin/adduser \
 && cp /etc/skel/.bashrc /root/.bashrc

# ---------------------------------------------------------------------------
# US keyboard by default (the page can switch to French at runtime)
# ---------------------------------------------------------------------------
RUN echo 'KEYMAP="us"' > /etc/conf.d/keymaps 2>/dev/null || true
RUN echo us > /etc/keymap

# ---------------------------------------------------------------------------
# emulator plumbing (same as upstream v86 image)
# ---------------------------------------------------------------------------
RUN setup-hostname localhost

RUN echo -e 'rmmod ne2k-pci && modprobe ne2k-pci\nrmmod virtio-net && modprobe virtio-net\nhwclock -s\nsetup-interfaces -a -r' > /root/networking.sh && chmod +x /root/networking.sh

RUN for i in devfs dmesg mdev hwdrivers; do rc-update add $i sysinit; done
RUN for i in hwclock modules sysctl hostname syslog bootmisc; do rc-update add $i boot; done
RUN rc-update add killprocs shutdown

# initramfs with 9p modules (the root filesystem is a 9p share)
RUN mkinitfs -F "base virtio 9p" $(cat /usr/share/kernel/$KERNEL/kernel.release)

RUN rm -rf /var/cache/apk/*
