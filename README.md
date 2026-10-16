# Arcade-OS

> A lightweight, fast, and customized Arch Linux distribution designed to run smoothly on low-end hardware while still providing a modern desktop experience.

[![Arch Linux](https://img.shields.io/badge/based%20on-Arch%20Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org)
[![License](https://img.shields.io/badge/license-GPL--v3-blue)](LICENSE)
[![Status](https://img.shields.io/badge/status-alpha-orange)]()

---

> ⚠️ This repository is still in active development.
>
> Some steps may not work on every machine yet. For daily use, download the latest stable release.

## Requirements

- Arch Linux host or VM for building
- `archiso` and `git`

```bash
sudo pacman -S archiso git
```

---

## Build the ISO

You can use the automated build script which automatically configures local repository paths and dependencies:

```bash
# 1) Clone the repository
git clone https://github.com/ArcadeSoftwares/Arcade-OS
cd Arcade-OS

# 2) Build ISO (will prompt for sudo when invoking mkarchiso)
./build.sh

# 3) Clean rebuild
./build.sh --clean

# 4) Sync latest Calamares assets from ArcadeLinux-Core and rebuild
./build.sh --sync --clean
```

### Manual Build

If you prefer building manually without `build.sh`:

```bash
# Clean previous build directories
sudo rm -rf work/ out/ Profile/work Profile/out

# Build
sudo mkarchiso -v -w work/ -o out/ Profile/
```

---

## Testing in QEMU

```bash
# Install QEMU (if not already installed)
sudo pacman -S qemu-full

# Boot the ISO
qemu-system-x86_64 \
  -m 2G \
  -cdrom out/arcadelinux-*.iso \
  -boot d \
  -vga std \
  -enable-kvm
```

## Booting on Real Hardware

```bash
# Find your USB drive first (for example: /dev/sdb)
lsblk

# Write the ISO to USB (replace /dev/sdX with your actual device)
sudo dd if=Profile/out/arcadelinux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Then reboot and choose the USB device from your firmware/BIOS boot menu.

---

## Project Structure

```text
Arcade-OS/
├── changelog.md
├── LICENSE
├── README.md
├── local-repo/
│   ├── arcade-local.db
│   ├── arcade-local.files
│   └── calamares-3.4.2-2-x86_64.pkg.tar.zst
└── Profile/
    ├── bootstrap_packages
    ├── packages.x86_64
    ├── pacman.conf
    ├── profiledef.sh
    ├── airootfs/
    │   ├── etc/
    │   │   ├── calamares/
    │   │   ├── systemd/
    │   │   ├── pam.d/
    │   │   ├── modprobe.d/
    │   │   └── ...
    │   ├── home/arcade/
    │   ├── root/
    │   └── usr/
    │       ├── local/
    │       └── share/
    ├── efiboot/
    ├── grub/
    ├── syslinux/
    ├── out/          # generated build output
    └── work/         # generated build workspace
```

---

## Live Session Credentials

| Field | Value |
| --- | --- |
| Username | `arcade` |
| Password | `arcade` |

## License

GPL-3.0. See [LICENSE](LICENSE) for details.