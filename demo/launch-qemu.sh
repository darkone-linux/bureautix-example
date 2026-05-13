#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Bureautix authors
#
# SPDX-License-Identifier: MIT
#
# Construit et lance une VM de démo.
#
# Usage :
#   ./demo/launch-qemu.sh                 # boot graphique
#   ./demo/launch-qemu.sh -nographic      # console série
#   QEMU_OPTS="-smp 4" ./demo/launch-qemu.sh
#
# Identifiants :
#   - utilisateur : demo / demo
#   - root        : demo
#   - SSH         : ssh -p 2222 demo@localhost

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DISK_DIR="${REPO_ROOT}/vm-state/demo"
mkdir -p "${DISK_DIR}"
export NIX_DISK_IMAGE="${DISK_DIR}/disk.qcow2"

echo ">>> Construction de la VM de démo (long au premier lancement)…"
VM_DRV="$(
  nix-build --no-out-link \
    --argstr configurationPath "${SCRIPT_DIR}/demo.nix" \
    --argstr repoRoot "${REPO_ROOT}" \
    -E '
      { configurationPath, repoRoot }:
      let
        sources = import (repoRoot + "/npins");
        nixos = import "${sources.nixpkgs}/nixos" {
          configuration = import configurationPath;
        };
      in
      nixos.vm
    '
)"

RUN_SCRIPT="$(find "${VM_DRV}/bin" -name 'run-*-vm' -print -quit)"
if [[ -z "${RUN_SCRIPT}" ]]; then
  echo "Erreur : aucun script run-*-vm trouvé dans ${VM_DRV}/bin" >&2
  exit 1
fi

cat <<EOF
>>> VM prête.
    Image disque : ${NIX_DISK_IMAGE}
    Connexion SSH : ssh -p 2222 demo@localhost  (mot de passe : demo)
    Comptes      : demo/demo, root/demo
    Arrêt        : Ctrl+A puis x  (mode -nographic) ou fermer la fenêtre
EOF

exec "${RUN_SCRIPT}" ${QEMU_OPTS:-} "$@"
