#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Darkone Linux
#
# SPDX-License-Identifier: MIT
#
# Build and run bureautix-vm-tpm with swtpm TPM2 simulation.
# VM state (disk image + TPM state) is persisted between runs in vm-state/vm-tpm/.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${VM_STATE_DIR:-$REPO_DIR/vm-state/vm-tpm}"
TPM_STATE="$STATE_DIR/tpm-state"
TPM_SOCK_DIR="$STATE_DIR/tpm-sock"

mkdir -p "$TPM_STATE" "$TPM_SOCK_DIR"

echo "[vm-tpm] Building..."
VM=$(nix-build "$REPO_DIR" -A vm-tpm --no-out-link)

echo "[vm-tpm] Getting swtpm..."
SWTPM=$(nix-build '<nixpkgs>' -A swtpm --no-out-link)/bin/swtpm

SWTPM_PID=""
cleanup() {
  [ -n "$SWTPM_PID" ] && kill "$SWTPM_PID" 2>/dev/null || true
  rm -f "$TPM_SOCK_DIR/swtpm.sock"
}
trap cleanup EXIT INT TERM

echo "[vm-tpm] Starting swtpm (TPM2)..."
"$SWTPM" socket \
  --tpmstate dir="$TPM_STATE" \
  --ctrl type=unixio,path="$TPM_SOCK_DIR/swtpm.sock" \
  --tpm2 &
SWTPM_PID=$!

for i in $(seq 1 20); do
  [ -S "$TPM_SOCK_DIR/swtpm.sock" ] && break
  sleep 0.1
done
if [ ! -S "$TPM_SOCK_DIR/swtpm.sock" ]; then
  echo "[vm-tpm] ERROR: swtpm socket not ready" >&2
  exit 1
fi

TPM_QEMU_OPTS="-chardev socket,id=chrtpm,path=$TPM_SOCK_DIR/swtpm.sock"
TPM_QEMU_OPTS+=" -tpmdev emulator,id=tpm0,chardev=chrtpm"
TPM_QEMU_OPTS+=" -device tpm-tis,tpmdev=tpm0"

echo "[vm-tpm] Launching QEMU (state: $STATE_DIR)..."
export NIX_DISK_IMAGE="$STATE_DIR/disk.qcow2"
export QEMU_OPTS="${QEMU_OPTS:-} $TPM_QEMU_OPTS"

"$VM/bin/run-securix-"*
