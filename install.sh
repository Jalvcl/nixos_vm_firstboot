#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/Jalvcl/nixos_vm_firstboot/refs/heads/main"
SCRIPT_URL="${REPO_RAW}/bootstrap_utm_vm.sh"

TMP_DIR="$(mktemp -d)"
BOOTSTRAP="${TMP_DIR}/bootstrap_utm_vm.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required."
  exit 1
fi

if [[ ! -r /dev/tty ]]; then
  echo "Error: interactive terminal required."
  exit 1
fi

echo "Downloading NixOS UTM bootstrap..."

if ! curl -fLsS "$SCRIPT_URL" -o "$BOOTSTRAP"; then
  echo "Download failed."
  exit 1
fi

if [[ ! -s "$BOOTSTRAP" ]]; then
  echo "Error: downloaded file is empty."
  exit 1
fi

echo
echo "Download completed."
echo "The next step will identify the target disk and ask for confirmation."
echo "No disk changes will be made unless you confirm."
echo

if [[ "$EUID" -eq 0 ]]; then
  bash "$BOOTSTRAP" "$@" </dev/tty
else
  sudo bash "$BOOTSTRAP" "$@" </dev/tty
fi
