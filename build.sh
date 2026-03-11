#!/usr/bin/env bash
# build.sh — Build Arch Linux ISO for NVIDIA DGX Spark (GB10)
#
# Usage:
#   ./build.sh              # full build (copy packages + build ISO)
#   ./build.sh repo         # only create the local package repository
#   ./build.sh iso          # only build the ISO (repo must exist)
#
# Prerequisites:
#   - Docker (with linux/arm64 support, e.g. Apple Silicon)
#
# If kernel packages aren't found locally, the script will clone
# linux-dgx-spark and build them automatically.

set -euo pipefail

IMAGE_NAME="dgx-spark-iso-builder"
PLATFORM="linux/arm64"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="${KERNEL_DIR:-$(cd "${REPO_DIR}/../linux-dgx-spark" 2>/dev/null && pwd || echo "")}"
KERNEL_REPO="https://github.com/rageltd/linux-dgx-spark.git"
PKG_DIR="${REPO_DIR}/pkgs"
OUT_DIR="${REPO_DIR}/out"
LOG_FILE="${REPO_DIR}/build.log"

log()  { echo "==> $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

# Tee all output to build.log while still showing on terminal
exec > >(tee "$LOG_FILE") 2>&1
echo "=== Build started: $(date -u) ==="

# ── Steps ────────────────────────────────────────────────────────────────────

find_kernel_packages() {
  # Check KERNEL_DIR for pre-built packages
  if [[ -n "$KERNEL_DIR" && -d "$KERNEL_DIR" ]]; then
    local pkgs
    pkgs=$(find "$KERNEL_DIR" -maxdepth 1 -name 'linux-dgx-spark-*.pkg.tar.*' 2>/dev/null)
    if [[ -n "$pkgs" ]]; then
      log "Found kernel packages in ${KERNEL_DIR}"
      return 0
    fi
  fi
  return 1
}

build_kernel() {
  local kernel_build_dir="${REPO_DIR}/../linux-dgx-spark"

  if [[ ! -d "$kernel_build_dir" ]]; then
    log "Cloning linux-dgx-spark..."
    git clone "$KERNEL_REPO" "$kernel_build_dir"
  else
    log "Using existing linux-dgx-spark at ${kernel_build_dir}"
  fi

  log "Building kernel packages (this will take a while)..."
  (cd "$kernel_build_dir" && ./build.sh)

  # Update KERNEL_DIR to point to the freshly built packages
  KERNEL_DIR="$(cd "$kernel_build_dir" && pwd)"

  # Verify packages were produced
  if ! find_kernel_packages; then
    die "Kernel build completed but no packages found in ${KERNEL_DIR}"
  fi
}

create_repo() {
  log "Setting up local package repository..."

  # If packages aren't available locally, clone and build the kernel
  if ! find_kernel_packages; then
    log "No kernel packages found — building from source..."
    build_kernel
  fi

  mkdir -p "$PKG_DIR"

  # Copy packages to local repo dir
  log "Copying kernel packages..."
  cp -v "$KERNEL_DIR"/linux-dgx-spark-*.pkg.tar.* "$PKG_DIR/"

  # Create pacman repository database
  # This runs inside the container because repo-add is a pacman tool
  log "Building package database..."
  docker run \
    --platform "$PLATFORM" \
    --rm \
    -v "${PKG_DIR}":/repo \
    -w /repo \
    "$IMAGE_NAME" \
    bash -c 'repo-add dgx-spark.db.tar.gz /repo/linux-dgx-spark-*.pkg.tar.*'

  log "Local repository ready in pkgs/"
}

build_container() {
  log "Building container image: ${IMAGE_NAME}"
  docker build --platform "$PLATFORM" -t "$IMAGE_NAME" "$REPO_DIR"
}

build_iso() {
  if [[ ! -f "${PKG_DIR}/dgx-spark.db.tar.gz" ]]; then
    die "Package repository not found — run './build.sh repo' first"
  fi

  mkdir -p "$OUT_DIR"

  log "Building ISO..."
  # mkarchiso needs to run as root inside the container.
  # Mount the full repo as /build so the profile can reference /build/pkgs.
  docker run \
    --platform "$PLATFORM" \
    --rm \
    --privileged \
    -v "${REPO_DIR}":/build \
    -v "${OUT_DIR}":/out \
    -v dgx-spark-iso-pacman-cache:/var/cache/pacman/pkg \
    -w /build \
    "$IMAGE_NAME" \
    bash -c '
      set -euo pipefail

      # Bundle kernel packages into the live system so archinstall can find them.
      # airootfs/etc/pacman.conf points to /var/lib/dgx-spark-repo.
      LIVE_REPO="/build/airootfs/var/lib/dgx-spark-repo"
      mkdir -p "$LIVE_REPO"
      cp /build/pkgs/linux-dgx-spark-*.pkg.tar.* "$LIVE_REPO/"
      repo-add "$LIVE_REPO/dgx-spark.db.tar.gz" "$LIVE_REPO"/linux-dgx-spark-*.pkg.tar.*

      # mkarchiso expects the profile dir as the last argument.
      # Work directory must be on a real filesystem (not overlayfs).
      WORK_DIR="/tmp/archiso-work"
      mkdir -p "$WORK_DIR"

      mkarchiso -v -w "$WORK_DIR" -o /out /build

      # Clean up bundled packages from the source tree
      rm -rf "$LIVE_REPO"

      echo "==> ISO built successfully!"
      ls -lh /out/*.iso
    '

  log "Done! ISO written to:"
  ls -lh "$OUT_DIR"/*.iso 2>/dev/null || echo "  (no ISO found — check build output above)"
}

# ── Main ─────────────────────────────────────────────────────────────────────

cmd="${1:-all}"

case "$cmd" in
  repo)
    build_container
    create_repo
    ;;
  iso)
    build_container
    build_iso
    ;;
  all)
    build_container
    create_repo
    build_iso
    ;;
  *)
    echo "Usage: $0 [all|repo|iso]"
    exit 1
    ;;
esac
