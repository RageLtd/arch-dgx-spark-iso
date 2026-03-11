# Build environment for arch-dgx-spark-iso
# Uses the same Arch Linux ARM base as the kernel build.
#
# Build:
#   docker build --platform linux/arm64 -t dgx-spark-iso-builder .

FROM menci/archlinuxarm:latest

# Fix pacman for Docker (same as kernel builder)
RUN sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf && \
    sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf

# Pacman keyring init + full system update
RUN pacman-key --init && \
    pacman-key --populate archlinuxarm && \
    pacman -Syu --noconfirm

# Install archiso dependencies (archiso itself is not packaged for ALARM)
RUN pacman -S --noconfirm --needed \
      arch-install-scripts \
      base-devel \
      dosfstools \
      e2fsprogs \
      erofs-utils \
      git \
      grub \
      libisoburn \
      mtools \
      squashfs-tools \
    && pacman -Scc --noconfirm

# Install archiso from upstream Arch Linux source (skip man page — rst2man not available)
RUN git clone https://gitlab.archlinux.org/archlinux/archiso.git /tmp/archiso && \
    make -C /tmp/archiso install-scripts install-profiles && \
    rm -rf /tmp/archiso

# Patch mkarchiso: remove x86-only GRUB modules from the hardcoded list.
# These modules don't exist for arm64-efi and cause grub-mkstandalone to fail.
RUN for mod in at_keyboard keylayouts usb usbserial_common usbserial_ftdi usbserial_pl2303 usbserial_usbdebug; do \
      sed -i "s/\b${mod}\b//g" /usr/local/bin/mkarchiso; \
    done

WORKDIR /build

CMD ["bash"]
