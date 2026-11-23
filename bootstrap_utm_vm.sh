#!/usr/bin/env bash
set -Eeuo pipefail

DISK="${1:-}"

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta como root: sudo $0 /dev/vda" >&2
  exit 1
fi

if [[ -z "$DISK" || ! -b "$DISK" ]]; then
  echo "Uso: $0 /dev/DISCO (por ejemplo, /dev/vda o /dev/nvme0n1)" >&2
  lsblk -dpno NAME,SIZE,MODEL
  exit 1
fi

if ! command -v parted >/dev/null || ! command -v nixos-install >/dev/null; then
  echo "Ejecuta este script desde el entorno live de instalación de NixOS." >&2
  exit 1
fi

echo "Se BORRARÁ todo el contenido de: $DISK"
lsblk -d -o NAME,SIZE,MODEL "$DISK"
read -r -p "Para continuar, escribe exactamente: BORRAR $DISK : " CONFIRM
[[ "$CONFIRM" == "BORRAR $DISK" ]] || {
  echo "Cancelado."
  exit 1
}

# Desmonta cualquier partición del disco que ya esté montada.
while read -r PART; do
  umount "$PART" 2>/dev/null || true
  swapoff "$PART" 2>/dev/null || true
done < <(lsblk -lnpo NAME "$DISK" | tail -n +2)

parted --script "$DISK" \
  mklabel gpt \
  mkpart primary 1GiB -8GiB \
  mkpart primary linux-swap -8GiB 100% \
  mkpart ESP fat32 1MiB 512MiB \
  set 3 esp on

partprobe "$DISK"
udevadm settle

# Obtiene las particiones por número, válido también para nombres como nvme0n1.
if [[ "$DISK" =~ [0-9]$ ]]; then
  P1="${DISK}p1"
  P2="${DISK}p2"
  P3="${DISK}p3"
else
  P1="${DISK}1"
  P2="${DISK}2"
  P3="${DISK}3"
fi

mkfs.ext4 -F -L nixos "$P1"
mkswap -L swap "$P2"
mkfs.fat -F 32 -n boot "$P3"

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

nixos-generate-config --root /mnt

echo "Configuración generada en /mnt/etc/nixos."
echo "Edita configuration.nix para definir, como mínimo, tu contraseña y opciones del sistema."
read -r -p "¿Ejecutar nixos-install ahora? [s/N] " INSTALL
if [[ "$INSTALL" =~ ^[sS]$ ]]; then
  nixos-install
else
  echo "Instalación pausada. Cuando termines de editar, ejecuta: nixos-install"
fi
