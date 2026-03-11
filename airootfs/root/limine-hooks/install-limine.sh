#!/usr/bin/env bash
# install-limine.sh — Install Limine bootloader with auto-config hook
# Run inside arch-chroot of the installed system.

set -euo pipefail

echo "==> Installing Limine bootloader..."

# Copy EFI binary to fallback boot path
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTAA64.EFI /boot/EFI/BOOT/

# Install the config generator
install -Dm755 /root/limine-hooks/limine-mkconfig /usr/local/bin/limine-mkconfig

# Install pacman hook (auto-regenerates limine.conf on kernel updates)
install -Dm644 /root/limine-hooks/90-limine.hook /usr/share/limine/90-limine.hook
ln -sf /usr/share/limine/90-limine.hook /etc/pacman.d/hooks/90-limine.hook
mkdir -p /etc/pacman.d/hooks

# Generate initial config
limine-mkconfig

# Decompress kernel if needed (Limine on aarch64 needs raw Image)
if file /boot/vmlinuz-linux-dgx-spark | grep -q gzip; then
  echo "==> Decompressing kernel for Limine compatibility..."
  mv /boot/vmlinuz-linux-dgx-spark /boot/vmlinuz-linux-dgx-spark.gz
  gunzip /boot/vmlinuz-linux-dgx-spark.gz
fi

echo "==> Limine installed successfully!"
