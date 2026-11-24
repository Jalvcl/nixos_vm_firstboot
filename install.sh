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
  echo "Error: curl is required to download the installer." >&2
  exit 1
fi

echo "Downloading NixOS UTM bootstrap..."
if ! curl --fail --location --silent --show-error "$SCRIPT_URL" -o "$BOOTSTRAP"; then
  echo "Download failed. Nothing was changed." >&2
  exit 1
fi

if [[ ! -s "$BOOTSTRAP" ]]; then
  echo "Error: downloaded file is empty. Nothing was changed." >&2
  exit 1
fi

echo
echo "Download completed."
echo "The next step will identify the target disk and ask for confirmation."
echo "No disk changes will be made unless you confirm."
echo

if [[ "$EUID" -eq 0 ]]; then
  bash "$BOOTSTRAP" "$@"
elif command -v sudo >/dev/null 2>&1; then
  sudo bash "$BOOTSTRAP" "$@"
else
  echo "Error: root privileges are required (sudo was not found)." >&2
  exit 1
fi
