#!/usr/bin/env bash
set -Eeuo pipefail

# NixOS UTM first-boot installer.
# Usage: bash bootstrap_utm_vm.sh [/dev/vda]
# This script intentionally does not run nixos-install: review/edit the
# generated configuration first, then run: sudo nixos-install

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: sudo bash $0 [/dev/vda]" >&2
  exit 1
fi

for cmd in lsblk parted partprobe udevadm mkfs.ext4 mkswap mkfs.fat \
           mount umount swapoff nixos-generate-config; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    echo "Run this script from the NixOS installer environment." >&2
    exit 1
  fi
done

DISK="${1:-}"

if [[ -z "$DISK" ]]; then
  echo "Available disks:"
  lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$4 == "disk"'
  echo
  read -r -p "Target disk (for example /dev/vda): " DISK
fi

if [[ ! -b "$DISK" ]]; then
  echo "Error: '$DISK' is not a valid block device." >&2
  exit 1
fi

DISK_TYPE="$(lsblk -dn -o TYPE "$DISK" | xargs)"
if [[ "$DISK_TYPE" != "disk" ]]; then
  echo "Error: '$DISK' is not a whole disk." >&2
  exit 1
fi

DISK_BYTES="$(lsblk -bnd -o SIZE "$DISK" | xargs)"
MIN_BYTES=$((16 * 1024 * 1024 * 1024))
if (( DISK_BYTES < MIN_BYTES )); then
  echo "Error: disk must be at least 16 GiB for this partition layout." >&2
  exit 1
fi

echo
echo "============================================================"
echo "WARNING: ALL DATA ON THIS DISK WILL BE DESTROYED"
echo "============================================================"
lsblk -d -o NAME,SIZE,MODEL "$DISK"
echo
read -r -p "To confirm, type exactly 'ERASE $DISK': " CONFIRM
if [[ "$CONFIRM" != "ERASE $DISK" ]]; then
  echo "Cancelled. No disk changes were made."
  exit 1
fi

echo
echo "Preparing $DISK..."

# Unmount any mounted child partitions and disable swap on them.
while read -r PART; do
  [[ -n "$PART" ]] || continue
  umount "$PART" 2>/dev/null || true
  swapoff "$PART" 2>/dev/null || true
done < <(lsblk -lnpo NAME "$DISK" | tail -n +2)

# Keep the original layout: root, swap, and EFI system partition.
parted --script "$DISK" \
  mklabel gpt \
  mkpart primary 1GiB -8GiB \
  mkpart primary linux-swap -8GiB 100% \
  mkpart ESP fat32 1MiB 512MiB \
  set 3 esp on

partprobe "$DISK"
udevadm settle

# Handle both /dev/vda and /dev/nvme0n1-style device names.
if [[ "$DISK" =~ [0-9]$ ]]; then
  P1="${DISK}p1"
  P2="${DISK}p2"
  P3="${DISK}p3"
else
  P1="${DISK}1"
  P2="${DISK}2"
  P3="${DISK}3"
fi

for PART in "$P1" "$P2" "$P3"; do
  if [[ ! -b "$PART" ]]; then
    echo "Error: expected partition $PART was not created." >&2
    exit 1
  fi
done

mkfs.ext4 -F -L nixos "$P1"
mkswap -L swap "$P2"
mkfs.fat -F 32 -n boot "$P3"

mkdir -p /mnt
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/disk/by-label/swap

nixos-generate-config --root /mnt

echo
echo "============================================================"
echo "Bootstrap preparation completed."
echo "============================================================"
echo "Generated configuration:"
echo "  /mnt/etc/nixos/configuration.nix"
echo "  /mnt/etc/nixos/hardware-configuration.nix"
echo
echo "Next steps:"
echo "  1. Review/edit /mnt/etc/nixos/configuration.nix"
echo "  2. Set up your user, SSH access, networking and boot loader."
echo "  3. Run: nixos-install"
echo
echo "When installation finishes, shut down and remove the installer ISO."
