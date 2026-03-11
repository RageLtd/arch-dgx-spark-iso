# Arch Linux ISO for NVIDIA DGX Spark (GB10)

Bootable Arch Linux installer ISO with the custom `linux-dgx-spark` kernel for the NVIDIA DGX Spark (GB10 Grace-Blackwell).

## Prerequisites

- Docker with `linux/arm64` support (Apple Silicon or native aarch64)
- Built kernel packages from [linux-dgx-spark](https://github.com/rageltd/linux-dgx-spark) — the `.pkg.tar.xz` files should be in `../linux-dgx-spark/`

## Build

```bash
./build.sh          # full build (container + repo + ISO)
```

Or step-by-step:

```bash
./build.sh repo     # copy kernel packages and create local pacman repo
./build.sh iso      # build the ISO using mkarchiso
```

If your kernel packages are elsewhere, set `KERNEL_DIR`:

```bash
KERNEL_DIR=/path/to/linux-dgx-spark ./build.sh
```

Output ISO is written to `out/`.

## Boot

The ISO boots via UEFI (the DGX Spark uses UEFI, not device trees). Three boot options:

1. **Arch Linux DGX Spark** — standard graphical console boot
2. **Serial console** — boots with `console=ttyS0,921600` for headless/serial access
3. **Copy to RAM** — copies the squashfs to RAM before booting (frees the USB drive)

## Project Structure

```
profiledef.sh         # archiso profile configuration
packages.aarch64      # packages included in the live ISO
pacman.conf           # pacman config (includes custom kernel repo)
airootfs/             # root filesystem overlay for the live environment
grub/grub.cfg         # GRUB boot menu (UEFI)
efiboot/              # systemd-boot entries (UEFI fallback)
Dockerfile            # container image for building the ISO
build.sh              # build orchestration script
```

## Installing Arch on the DGX Spark

After booting the ISO:

### Guided (archinstall)

```bash
archinstall --config /root/archinstall-config.json
```

The config pre-selects `linux-dgx-spark` kernel, Limine bootloader, and automatically installs `limine-mkinitcpio-hook` and `limine-snapper-sync` from the AUR via custom post-install commands.

> **Important:** Running `archinstall` without `--config` will default to the standard `linux` kernel, which does not support the DGX Spark hardware.

### Manual

1. Partition the disk (`fdisk` or `parted`)
2. Format and mount partitions
3. `pacstrap /mnt base linux-dgx-spark linux-firmware limine efibootmgr`
4. `genfstab -U /mnt >> /mnt/etc/fstab`
5. `arch-chroot /mnt`
6. Configure locale, timezone, hostname
7. `limine-install`
8. `limine-scan`

## Related

- [linux-dgx-spark](https://github.com/rageltd/linux-dgx-spark) — kernel package build
