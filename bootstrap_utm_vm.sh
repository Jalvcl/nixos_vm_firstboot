#!/usr/bin/env bash
set -Eeuo pipefail

# Preparación de disco para una instalación de NixOS en UTM.
# Uso: sudo bash bootstrap_utm_vm.sh [/dev/vda]
#
# Este script particiona y formatea el disco, monta los sistemas de
# archivos y genera la configuración. No ejecuta nixos-install.

if [[ "$EUID" -ne 0 ]]; then
  echo "Ejecuta como root: sudo bash $0 [/dev/vda]" >&2
  exit 1
fi

for cmd in \
  awk grep lsblk parted partprobe udevadm \
  mkfs.ext4 mkswap mkfs.fat mount swapon \
  nixos-generate-config readlink; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Falta el comando requerido: $cmd" >&2
    echo "Ejecuta este script desde el entorno instalador de NixOS." >&2
    exit 1
  fi
done

DISK="${1:-}"

if [[ -z "$DISK" ]]; then
  echo "Discos disponibles:"
  lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$4 == "disk"'
  echo
  read -r -p "Disco de destino (por ejemplo, /dev/vda): " DISK
fi

if [[ ! -b "$DISK" ]]; then
  echo "Error: '$DISK' no es un dispositivo de bloques válido." >&2
  exit 1
fi

DISK_TYPE="$(lsblk -dn -o TYPE "$DISK" | xargs)"
if [[ "$DISK_TYPE" != "disk" ]]; then
  echo "Error: '$DISK' no es un disco completo." >&2
  exit 1
fi

DISK_BYTES="$(lsblk -bnd -o SIZE "$DISK" | xargs)"
MIN_BYTES=$((16 * 1024 * 1024 * 1024))

if ((DISK_BYTES < MIN_BYTES)); then
  echo "Error: el disco debe tener al menos 16 GiB." >&2
  exit 1
fi

# Rechaza el disco si alguna de sus particiones está montada.
while IFS= read -r MOUNTPOINT; do
  if [[ -n "$MOUNTPOINT" ]]; then
    echo "Error: hay un sistema de archivos del disco montado en: $MOUNTPOINT" >&2
    echo "Desmóntalo antes de continuar." >&2
    exit 1
  fi
done < <(lsblk -nrpo MOUNTPOINT "$DISK")

# Rechaza el disco si alguna de sus particiones está activa como swap.
while IFS= read -r SWAP_DEVICE; do
  [[ -n "$SWAP_DEVICE" ]] || continue

  SWAP_REAL="$(readlink -f "$SWAP_DEVICE" 2>/dev/null || true)"
  while IFS= read -r PART; do
    [[ -n "$PART" ]] || continue
    PART_REAL="$(readlink -f "$PART" 2>/dev/null || true)"

    if [[ -n "$SWAP_REAL" && "$SWAP_REAL" == "$PART_REAL" ]]; then
      echo "Error: $PART está activa como swap." >&2
      echo "Desactívala antes de continuar." >&2
      exit 1
    fi
  done < <(lsblk -lnpo NAME "$DISK" | tail -n +2)
done < <(swapon --show=NAME --noheadings)

echo
echo "============================================================"
echo "ADVERTENCIA: SE BORRARÁN TODOS LOS DATOS DE ESTE DISCO"
echo "============================================================"
lsblk -d -o NAME,SIZE,MODEL "$DISK"
echo
read -r -p "Para confirmar, escribe exactamente 'ERASE $DISK': " CONFIRM

if [[ "$CONFIRM" != "ERASE $DISK" ]]; then
  echo "Cancelado. No se realizaron cambios en el disco."
  exit 1
fi

echo
echo "Preparando $DISK..."

# Tabla GPT y tres particiones:
#   1: EFI, aproximadamente 511 MiB
#   2: raíz ext4, desde 512 MiB hasta 8 GiB antes del final
#   3: swap, últimos 8 GiB

MIB=$((1024 * 1024))
SWAP_MIB=$((8 * 1024))
DISK_MIB=$((DISK_BYTES / MIB))
ROOT_END_MIB=$((DISK_MIB - SWAP_MIB))

parted --script "$DISK" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 512MiB \
  set 1 esp on \
  mkpart primary ext4 512MiB "${ROOT_END_MIB}MiB" \
  mkpart primary linux-swap "${ROOT_END_MIB}MiB" 100%

partprobe "$DISK"
udevadm settle

# Admite nombres como /dev/vda y /dev/nvme0n1.
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
    echo "Error: no se creó la partición esperada $PART." >&2
    exit 1
  fi
done

# Formateo según el orden de las particiones:
#   P1 = EFI, P2 = raíz, P3 = swap
mkfs.fat -F 32 -n boot "$P1"
mkfs.ext4 -F -L nixos "$P2"
mkswap -L swap "$P3"

mkdir -p /mnt
mount /dev/disk/by-label/nixos /mnt

mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

swapon /dev/disk/by-label/swap

nixos-generate-config --root /mnt

# echo
# echo "============================================================"
# echo "Preparación completada."
# echo "============================================================"
# echo "Archivos de configuración generados:"
# echo "  /mnt/etc/nixos/configuration.nix"
# echo "  /mnt/etc/nixos/hardware-configuration.nix"
# echo
# echo "Próximos pasos:"
# echo "  1. Revisa y edita /mnt/etc/nixos/configuration.nix."
# echo "  2. Configura el usuario, la red, el acceso SSH y el cargador de arranque."
# echo "  3. Ejecuta: nixos-install"
# echo
# echo "Al terminar la instalación, apaga la máquina virtual y retira la ISO."
#
#
echo
echo "Instalando temporalmente git y GitHub CLI..."

if ! command -v nix-shell >/dev/null 2>&1; then
  echo "Error: no se encontró nix-shell en el instalador de NixOS." >&2
  exit 1
fi

# Instala gh y git de forma temporal para esta sesión del instalador.
nix-shell -p gh git --run '
  set -e
  gh auth login --web --git-protocol https
  gh auth status
  gh repo clone Jalvcl/configuraciones /mnt/etc/nixos/configuraciones
'
REPO_DIR="/mnt/etc/nixos/configuraciones/NixOS"
REPO_CONFIG="$REPO_DIR/configuration.nix"
HW_CONFIG="/mnt/etc/nixos/hardware-configuration.nix"

if [[ ! -f "$REPO_CONFIG" ]]; then
  echo "Error: no se encontró $REPO_CONFIG" >&2
  echo "Revisa la ruta del archivo en el repositorio clonado." >&2
  exit 1
fi

if [[ ! -f "$HW_CONFIG" ]]; then
  echo "Error: falta la configuración de hardware generada: $HW_CONFIG" >&2
  exit 1
fi

echo
echo "Repositorio clonado y archivos encontrados."
echo "Configuración que se usará: $REPO_CONFIG"
echo "La instalación aún no se ha ejecutado."

echo
echo "Se instalará NixOS usando:"
echo "  Raíz:          /mnt"
echo "  Configuración: $REPO_CONFIG"
echo
read -r -p "¿Ejecutar nixos-install ahora? Escribe 'INSTALL' para confirmar: " CONFIRM_INSTALL

if [[ "$CONFIRM_INSTALL" == "INSTALL" ]]; then
  if ! command -v nixos-install >/dev/null 2>&1; then
    echo "Error: no se encontró nixos-install." >&2
    exit 1
  fi

  nixos-install --root /mnt -I nixos-config="$REPO_CONFIG"
else
  echo "Instalación cancelada. El sistema no se instaló."
  echo "Puedes ejecutarla después con:"
  echo "  nixos-install --root /mnt -I nixos-config=\"$REPO_CONFIG\""
fi
