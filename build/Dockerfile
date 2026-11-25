# Linux Classroom guest image.
#
# Everything a student needs must be installed here, at build time. The guest
# also has internet at runtime through the page's relay, but the image has to
# be useful without it.
#
# Build with build/build.sh (needs Docker). Based on
# v86/tools/docker/alpine/Dockerfile.

FROM docker.io/i386/alpine:3.21.0

ENV KERNEL=virt

RUN apk add --no-cache \
      openrc alpine-base agetty alpine-conf \
      linux-$KERNEL linux-firmware-none \
      kbd-bkeymaps shadow doas

# Same packages as before, split so a slow network or a restarted build only
# redoes the layer that was interrupted instead of the whole toolchain.
RUN apk add --no-cache build-base
RUN apk add --no-cache bash bash-completion
RUN apk add --no-cache nano nano-syntax less
RUN apk add --no-cache vim vim-doc
RUN apk add --no-cache mandoc man-pages man-pages-posix mandoc-apropos
RUN apk add --no-cache bc file tree htop

# ---------------------------------------------------------------------------
# vim: keep the editor, drop the 30 MB of help pages, spell files and syntax
# definitions for 700 languages. The guest filesystem is served to v86 one
# file per HTTP request, so file count costs first-boot time as much as bytes.
# ---------------------------------------------------------------------------
RUN set -eux; \
    vimdir=$(echo /usr/share/vim/vim[0-9]*); \
    rm -rf "$vimdir"/doc "$vimdir"/spell "$vimdir"/indent "$vimdir"/ftplugin \
           "$vimdir"/macros "$vimdir"/tools "$vimdir"/print \
           "$vimdir"/lang "$vimdir"/keymap "$vimdir"/compiler; \
    find "$vimdir"/syntax -maxdepth 1 -type f -name '*.vim' | while read -r f; do \
      case "$(basename "$f")" in \
        syncolor.vim|synload.vim|syntax.vim|nosyntax.vim|\
        c.vim|cpp.vim|sh.vim|python.vim|html.vim|css.vim|javascript.vim|\
        json.vim|markdown.vim|make.vim|perl.vim|php.vim|ruby.vim|java.vim|\
        sql.vim|xml.vim|yaml.vim|vim.vim|diff.vim|lua.vim|go.vim|rust.vim|\
        asm.vim|man.vim|tex.vim|nroff.vim|config.vim|dosini.vim|gitcommit.vim|\
        vb.vim|pod.vim|dtd.vim|sqloracle.vim) ;; \
        *) rm -f "$f" ;; \
      esac; \
    done

# Fail the build instead of shipping a silently broken editor: the filetype
# must be detected from the extension, the C syntax file must define groups,
# and a file with no known type must still open (Vim loads syntax/nosyntax.vim
# for those, and the trimmed runtime must keep every file the kept syntaxes
# include: xml/dtd, html/vb, markdown/html, perl/pod).
RUN set -eux; \
    printf 'int main(void){ /* hi */ return 0; }\n' > /tmp/probe.c; \
    vim -N -E -s -c 'syntax on' \
        -c 'call writefile([&filetype, string(len(filter(getcompletion("","highlight"), "v:val =~# \"^c\"")))], "/tmp/hl")' \
        -c 'qa!' /tmp/probe.c; \
    grep -qx 'c' /tmp/hl; \
    awk 'NR==2 && $1+0 > 10 { found=1 } END { exit !found }' /tmp/hl; \
    for ext in cpp sh py html css js json md pl php rb java sql xml yml vim diff lua go rs asm man tex xyz; do \
        printf 'x /* y */ # z\n' > "/tmp/probe.$ext"; \
        vim -N -E -s -c 'syntax on' -c 'qa!' "/tmp/probe.$ext"; \
    done; \
    rm -f /tmp/probe.* /tmp/hl

# nano: the syntax definitions are installed but their include line in
# /etc/nanorc ships commented out.
RUN grep -q '^include "/usr/share/nano/\*.nanorc"' /etc/nanorc 2>/dev/null || \
    sed -i 's|^# *include /usr/share/nano/\*.nanorc|include "/usr/share/nano/*.nanorc"|' /etc/nanorc; \
    grep -q '^include "/usr/share/nano/\*.nanorc"' /etc/nanorc

# man -k / apropos work from an index; the guest has no network to build it.
RUN makewhatis /usr/share/man

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

# ---------------------------------------------------------------------------
# network: the page gives v86 a ne2k NIC through a WebSocket relay; the guest
# just needs the driver and DHCP at boot.
# ---------------------------------------------------------------------------
RUN echo ne2k-pci >> /etc/modules
RUN printf 'auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet dhcp\n' > /etc/network/interfaces
RUN rc-update add networking boot

# initramfs with 9p modules (the root filesystem is a 9p share)
RUN mkinitfs -F "base virtio 9p" $(cat /usr/share/kernel/$KERNEL/kernel.release)

RUN rm -rf /var/cache/apk/*
