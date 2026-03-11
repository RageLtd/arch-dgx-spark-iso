#!/usr/bin/env bash
# archiso profile for NVIDIA DGX Spark (GB10 Grace-Blackwell)

iso_name="archlinux-dgx-spark"
iso_label="ARCH_DGX_$(date --utc +%Y%m)"
iso_publisher="Arch Linux DGX Spark <https://github.com/rageltd/arch-dgx-spark-iso>"
iso_application="Arch Linux DGX Spark Live/Installer"
iso_version="$(date --utc +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi.grub')
arch="aarch64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'arm' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/post-install.sh"]="0:0:755"
)
