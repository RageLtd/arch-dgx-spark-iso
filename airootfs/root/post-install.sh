#!/usr/bin/env bash
# post-install.sh — Run after archinstall to set up Limine hooks from AUR
#
# Usage (from the live ISO, after archinstall completes):
#   ./post-install.sh /mnt

set -euo pipefail

MOUNT="${1:-/mnt}"

if [[ ! -d "$MOUNT/etc" ]]; then
  echo "ERROR: $MOUNT doesn't look like a mounted system" >&2
  echo "Usage: $0 /mnt" >&2
  exit 1
fi

echo "==> Installing AUR helper (yay) and Limine hooks..."

arch-chroot "$MOUNT" bash -c '
  set -euo pipefail

  # Need a non-root user for makepkg
  if ! id builder &>/dev/null; then
    useradd -m -G wheel builder
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder
  fi

  # Install yay
  if ! command -v yay &>/dev/null; then
    pacman -S --noconfirm --needed git base-devel
    su - builder -c "
      git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
      cd /tmp/yay-bin
      makepkg -si --noconfirm
      rm -rf /tmp/yay-bin
    "
  fi

  # Install Limine hooks from AUR
  su - builder -c "yay -S --noconfirm limine-mkinitcpio-hook limine-snapper-sync"

  # Clean up temp builder sudoers entry
  rm -f /etc/sudoers.d/builder
'

echo "==> Done! Limine hooks installed."
