# linuxbox

A Linux terminal in the browser for students. Nothing to install on their side.

- Alpine Linux (BusyBox userland, glibc-free) running in the v86 emulator (BSD licensed)
- Internet access through v86's public WebSocket relay; the guest gets a DHCP
  lease at boot
- bash as the shell for every account, plus nano and vim with syntax
  highlighting, less, man with POSIX pages and apropos, bc, tree, htop,
  doas (a tiny sudo) and gcc
- US and French (AZERTY) keyboard layouts, switchable at runtime
- Phone and tablet friendly: tap the screen to type, and a Termux-style key bar
  adds Esc, Tab, arrows, Home/End, PgUp/PgDn, Ctrl and Alt
- Sidebar with one-click commands that you can edit and add to; a click puts the
  command on the prompt, Shift+click runs it
- The whole machine (users, files, packages, running state) is saved in the
  student's browser and resumes on the next visit
- Export / Import buttons to back the machine up as a file

## Run it

The guest filesystem is generated, not committed. Build it once, then serve
the folder:

```
./build.sh
python3 -m http.server 8000
```

`./build.sh` needs Docker, git, python3 and zstd. The first run clones v86 into
`.build/`, downloads the Alpine packages and takes a few minutes; later runs
reuse that cache. It writes `alpine-fs.json`, `alpine-rootfs-flat/` and
`image-version.json` next to `index.html`.

Open http://localhost:8000. The first boot takes a while. After that the machine
is saved automatically (once a minute when it has changed, and whenever the tab
is hidden), and the next visit resumes where the student left off.

The page has to be served over HTTP; opening `index.html` by double-clicking it
does not work.

## Share it

Upload the whole folder to any static host (GitHub Pages, Netlify, a school
server). Each student gets a private machine, stored in their own browser.

## What is in the repository

```
index.html            the whole application
libv86.js             emulator, from npm v86
v86.wasm              emulator
seabios.bin           BIOS
vgabios.bin           BIOS
build.sh              builds the guest image (generated files are ignored)
build/Dockerfile      how the guest image is built
build/build.sh        the build itself: alpine-fs.json and alpine-rootfs-flat/
build/rootfs/         files copied into the guest (motd, doas.conf, bashrc…)
```

`alpine-fs.json`, `alpine-rootfs-flat/` and `image-version.json` are generated
by `./build.sh` and deliberately kept out of git; `build/build.sh` clones v86
(pinned commit) into `.build/` only to use its filesystem tools.

## The guest machine

Everything needed offline is installed at build time, in `build/Dockerfile`.
At runtime the guest also has internet through the relay, so `apk add` and
`wget` work; the image is still complete without it.

- `student` / `student` is the account on the console, autologin, `wheel` group
- `root` has no password; the serial console autologins as root (used by tooling)
- `doas` is configured as passwordless for `wheel`, so the "Run as root" button
  cannot get stuck on a password prompt
- new accounts created with `adduser` get bash: a small wrapper in
  `/usr/local/sbin/adduser` adds `-s /bin/bash` when it is creating a user
- keymaps for both layouts are in `/usr/share/bkeymaps/`; the page changes the
  kernel keymap over the serial console, so the student's shell is not disturbed

To add packages, edit `build/Dockerfile` and run `./build.sh` (or
`build/build.sh`); the generated files stay in place and are not committed.
Rebuilding changes `image-version.json`, and old saved machines are then
discarded automatically instead of being restored against a mismatched image.

## Saving

- The machine is a memory dump, compressed with gzip before it goes into
  IndexedDB. `MEMORY` at the top of the script in `index.html` sets its size.
- Compressing a dump is the heaviest thing the page does: it briefly holds the
  machine dump twice (up to 192 MB each time). The compressor is fed in 1 MB
  slices so it never makes a third copy, saves are skipped while a dump is
  already running, idle tabs skip the periodic dump, and the first boot writes
  the machine and the reset snapshot from a single dump.
- The first successful boot stores a "golden" clean machine. Reset restores that
  snapshot in about a second instead of booting again.
- Saved machines live in the browser. Clearing site data, or using another
  browser or computer, starts a fresh machine. Export is the backup.
- The page asks the browser for persistent storage, so the snapshot is not
  evicted when the disk gets full.

## Keyboard

Ctrl+Alt+K, or the "Keyboard" button in the header, switches between US and
French AZERTY. The layout is remembered. Ctrl+Alt+- and Ctrl+Alt+= change the
terminal text size.

## Notes and limits

- The first boot takes about 45 seconds; later visits resume instantly from the
  saved machine.
- `man` has the POSIX pages for the standard commands (`man ls`, `man cp`,
  `man 5 passwd`) and the Linux C library pages (`man 3 printf`). `apropos` and
  `whatis` work. BusyBox applets outside POSIX (`apk`, `doas`, `adduser`) have no
  man page; use `<command> --help` for those.
- `vim` keeps a working editor and a set of syntax files (C, shell, Python,
  HTML, JSON, Makefiles...), but not the 30 MB `:help` documentation tree.
- There is no copy-paste with the system clipboard in the terminal. Use the
  Paste box in the sidebar to send text into the machine.
- The guest has internet through v86's public relay
  (`wss://relay.widgetry.org/`). That is a third-party service: it carries the
  raw Ethernet frames (HTTPS inside the guest still protects page contents),
  it is unfiltered and best-effort, and it can disappear. For a classroom, run
  your own relay and allowlist hosts, or remove `network_relay_url` from
  `index.html` to go back to an offline machine.
- On a phone or tablet, tap the terminal to open the keyboard. The key bar above
  it has the keys phone keyboards lack; Ctrl and Alt stay pressed for the next
  key when tapped. The command list lives behind the Menu button.
- Alpine Linux, busybox and the packages inside the guest keep their own
  licenses; v86 is BSD licensed (see https://github.com/copy/v86).
