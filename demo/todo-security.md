<!--
SPDX-FileCopyrightText: 2026 Bureautix authors

SPDX-License-Identifier: MIT
-->

# TODO — VM de démo avec la pile de sécurité complète

État actuel : `launch-qemu.sh` lance une VM **sans** Secure Boot, sans LUKS+FIDO2, sans PAM U2F.

## Défi à relever

1. **swtpm + OVMF**
   - Firmware UEFI avec vars persistantes (`OVMF_CODE.fd` + `OVMF_VARS.fd` par VM).
   - Démon `swtpm` lancé sur socket UNIX **avant** QEMU, branché via `-chardev socket / -tpmdev emulator`.
   - Enrôlement Secure Boot (PK/KEK/db) via `sbctl` dans la VM ; lanzaboote signe chaque génération.
   - État *stateful* hors du Nix store : vars OVMF perdues = système non bootable.

2. **FIDO2 pour LUKS**
   - Pas de Yubikey émulée prête à l'emploi dans QEMU. Deux pistes :
     - **passthrough USB** (`-device usb-host`) d'une vraie clé : casse la reproductibilité, vol de device sur l'hôte.
     - **authenticator logiciel** (`virtual-fido`, `softfido`, `umockdev`) injecté dans l'initrd : peu documenté, casse au gré des maj kernel/systemd, `systemd-cryptenroll --fido2-device=` exige un vrai `/dev/hidraw` avec les bonnes HID caps.

3. **PAM U2F en session**
   - `pam_u2f` veut un device U2F visible côté userland.
   - Base `~/.config/Yubico/u2f_keys` à pré-provisionner avec un `appId` cohérent avec la clé virtuelle.

4. **Combinatoire** — les trois doivent marcher *ensemble* (TPM mesure le boot signé OVMF → LUKS FIDO2 → session PAM U2F). Un maillon cassé = pas de boot, diagnostic à travers firmware/initrd/systemd/PAM.

## Piste de solution à creuser

### Palier 1 — UEFI + Secure Boot + TPM (sans FIDO2)

- Ajouter à `demo.nix` :
  ```nix
  virtualisation = {
    useBootLoader = true;
    useEFIBoot = true;
    useSecureBoot = true;     # NixOS ≥ 24.05
    tpm.enable = true;        # lance swtpm automatiquement
  };
  ```
- Importer le module `lanzaboote` et générer des clés `sbctl` au premier boot (script `postBoot`).
- Persister `OVMF_VARS.fd` à côté du qcow2 dans `vm-state/demo/`.
- **Critère** : la VM boote, `bootctl status` indique Secure Boot actif, `tpm2_pcrread` répond.

### Palier 2 — LUKS avec FIDO2 émulé

- Évaluer **`virtual-fido`** (https://github.com/bulwarkid/virtual-fido) ou **`softfido`** : créent un `/dev/hidraw` U2F via uhid.
- Lancer le daemon sur l'hôte, exposer le device dans la VM via `-device usb-host` (ou côté invité si daemon dans la VM).
- Adapter le layout `office_v1` : générer un keyfile au build, enrôler avec `systemd-cryptenroll --fido2-device=auto` au premier boot, puis basculer en mode FIDO2 strict.
- **Critère** : reboot → l'initrd demande la présence du token virtuel et déverrouille `/`.

### Palier 3 — PAM U2F en session

- Réutiliser le même authenticator virtuel.
- Pré-générer `u2f_keys` (via `pamu2fcfg` scripté avec `expect`/headless), l'injecter dans le home de `demo` au premier boot.
- Activer `common/pam_u2f.nix` avec `appId = "pam://bureautix-demo"`.
- **Critère** : `sudo` et déverrouillage de session exigent une présence sur le device virtuel.

## Outillage à packager

- `demo/launch-qemu.sh` doit alors orchestrer : démarrer `swtpm` + `virtual-fido` daemons, lancer QEMU, les nettoyer en sortie (`trap`).
- Considérer un wrapper Nix (`demo.vm = pkgs.writeShellApplication { ... }`) pour figer les versions.

## Hors scope

- Mesure d'attestation TPM réelle (PCR policies).
- Récupération clé / rotation FIDO2 multi-tokens.
- Tests automatisés (`nixosTest`) de la chaîne complète — probablement infaisable sans émulation FIDO2 upstream.
