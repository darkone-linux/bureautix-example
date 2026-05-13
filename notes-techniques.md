<!--
SPDX-FileCopyrightText: 2026 Bureautix authors

SPDX-License-Identifier: MIT
-->

# Documentation technique — Bureautix

## Présentation rapide

Bureautix est un **modèle NixOS** dérivé de [Sécurix](https://github.com/cloud-gouv/securix/) permettant de déployer un parc de postes bureautiques durcis, déclaratifs et reproductibles. L'ensemble du parc (machines, utilisateurs, profils matériels) est décrit comme code dans le dépôt Git, sans annuaire centralisé type LDAP/FreeIPA.

Caractéristiques principales :

- Système NixOS nominatif (un poste = une machine identifiée + des utilisateurs nommés)
- Chiffrement disque **LUKS** déverrouillé par clé **FIDO2** au démarrage
- Authentification utilisateur renforcée par **PAM U2F** (Yubikey ou équivalent)
- **Secure Boot** via lanzaboote (hérité de Sécurix)
- Comptes DSI séparés (`*-adm`) pour les opérations d'administration
- Accès distant SSH réservé aux *superadmins* pour le support

Public visé : équipes DSI souhaitant un poste de travail bureautique homogène, vérifiable et maintenable avec un minimum d'infrastructure.

## Architecture technique

### Point d'entrée

Toute la composition vit dans `default.nix` à la racine du dépôt. Il expose les *attributes* suivants :

| Attribut | Description |
|----------|-------------|
| `usb-installer` | ISO USB bootable embarquant l'installeur générique |
| `net-installer` | Serveur netboot (Pixiecore + Caddy) pour installations en masse |
| `terminals.<SERIAL>` | Système NixOS construit pour la machine identifiée par son numéro de série |
| `toplevelRegistry` | Registre listant tous les *toplevels* pour le serveur netboot |
| `shell` | Shell de développement (hooks pre-commit, outils) |

### Pattern d'inventaire

Le parc est décrit par des fichiers Nix individuels, lus automatiquement par `securix.lib.readInventory2` :

```
inventory/
├── machines/<SERIAL>.nix    # SKU matériel, disque principal, utilisateurs assignés
└── users/<USERNAME>.nix     # email, username, mot de passe haché, shell par défaut
defaults/<SKU>.nix           # Réglages par défaut par famille matérielle (ex. x280)
```

Chaque machine importe automatiquement les modules `common/` et reçoit la liste des modules utilisateurs déclarés dans `machine.users`.

### Modules communs (`common/`)

Importés par tous les terminaux via `common/default.nix` :

| Fichier | Rôle |
|---------|------|
| `filesystems.nix` | Layout BTRFS `office_v1` (`/home`, `/nix`, `/var`) + LUKS FIDO2 + swap chiffré |
| `pam_u2f.nix` | `appId`/`origin` U2F pour la session graphique |
| `admins.nix` | Comptes DSI privilégiés + leurs clés U2F |
| `superadmins.nix` | Accès SSH distant (clés SSH à ajouter ici) |
| `known-hosts.nix` | Known hosts SSH et CAs |
| `browser.nix` | Bookmarks Firefox et page de démarrage |
| `tools.nix` | Suite bureautique, communication, dépannage réseau, etc. |
| `printing.nix` | Pilotes d'imprimantes (CUPS) |
| `laptop.nix` | Gestion d'énergie (`upower`, `power-profiles-daemon`) |

Le profil graphique par défaut est **KDE Plasma 6** avec terminal **Kitty**. La locale par défaut est `fr_FR.UTF-8` (surchargeable).

### Modèle de sécurité

Chaîne de confiance complète au démarrage :

1. **UEFI Secure Boot** valide le bootloader (lanzaboote)
2. **LUKS + FIDO2** : la partition chiffrée est déverrouillée par présence physique de la clé matérielle
3. Session utilisateur : **PAM U2F** exige à nouveau la clé pour ouvrir/déverrouiller la session
4. Opérations d'admin : un compte `*-adm` séparé, lui-même protégé par U2F
5. Support distant : SSH limité aux *superadmins* listés

Pas de directory centralisé : les utilisateurs sont propagés par commit Git et déploiement.

## Outils et dépendances

### Dépendances externes (pin via `npins`)

Toutes les sources externes sont figées dans `npins/sources.json` :

| Pin | Source | Usage |
|-----|--------|-------|
| `securix` | github:cloud-gouv/securix | Fondation Sécurix (lib, modules durcis) |
| `nixpkgs` | `nixpkgs-unstable` (canal NixOS 25.11) | Paquets Nix |
| `disko` | github:raitobezarius/disko (branche `fido2-disko`) | Partitionnement déclaratif avec patch `office_v1` |
| `snowboot` | git.mbosch.me/linus/snowboot | Récupération du système via cache binaire en netboot |
| `git-hooks` | cachix/git-hooks.nix | Hooks pre-commit |
| `nix-actions`, `nix-reuse` | DGNum | Génération CI GitHub Actions, conformité REUSE |

### Shell de développement

`nix-shell` (alias de `(import ./. { }).shell`) fournit :

- `treefmt` + `nixfmt-rfc-style` — formatage
- `npins` — gestion des pins
- `reuse` — conformité SPDX/licences
- Hooks **pre-push** : `statix`, `nixfmt-rfc-style`, `reuse`

### CI

Définie dans `workflows/`, générée par `nix-actions` vers `.github/workflows/` :

- `pre-commit.yaml` — formatage + lint
- `build-toplevels.yaml` — build de tous les terminaux

### Logiciels embarqués (extrait `common/tools.nix`)

Bureautique : LibreOffice, WPS Office, OnlyOffice, Typst, Thunderbird, Signal, Element, VLC, Obsidian, Xournal++, VeraCrypt, Firefox, Chromium.
Outillage DSI : `pam_u2f`, `gh`, `jujutsu`, `tmux`, `ripgrep`, `fd`, `bitwarden-cli`/`rbw`, `magic-wormhole-rs`, `tcpdump`, `wireshark`, `iperf3`, `strace`, `gdb`, `tmate`, `sshx`.

## Comment créer son poste bureautique

### 1. Cloner et personnaliser

```bash
git clone <url> mon-bureautix
cd mon-bureautix
nix-shell
```

### 2. Adapter les modules communs

Éditer les points de personnalisation recommandés (`common/README.md`) :

- `common/pam_u2f.nix` — choisir un `appId` et un `origin` propres à l'organisation
- `common/admins.nix` — déclarer les comptes DSI et leurs clés U2F (générées via `pamu2fcfg --appid pam://<votre-org> --origin pam://<votre-org> -n`)
- `common/superadmins.nix` — ajouter les clés SSH du support distant
- `common/known-hosts.nix` — CAs et hosts SSH internes
- `common/browser.nix` — bookmarks et page de démarrage
- `common/tools.nix` — paquets métiers manquants
- `common/printing.nix` — pilotes d'imprimantes

### 3. Déclarer un utilisateur

Créer `inventory/users/<username>.nix` :

```nix
{ pkgs, ... }:
{
  securix.self.user = {
    email = "prenom.nom@example.com";
    username = "pnom";
    hashedPassword = "<sortie de `mkpasswd -m yescrypt`>";
    defaultLoginShell = pkgs.zsh;
  };
}
```

### 4. Déclarer une machine

Créer `inventory/machines/<NUMÉRO-DE-SÉRIE>.nix` :

```nix
{
  securix.self.mainDisk = "/dev/nvme0n1";
  securix.self.machine = {
    hardwareSKU = "x280";          # doit correspondre à defaults/<SKU>.nix
    serialNumber = "PC140V35";
    users = [ "pnom" ];            # logins déclarés dans inventory/users/
  };
}
```

Si le SKU n'existe pas encore, créer `defaults/<SKU>.nix` avec les réglages matériels propres à la famille.

### 5. Construire l'installeur

```bash
# Clé USB universelle (la plus simple)
nix-build -A usb-installer
# → result/iso/*.iso à flasher

# OU serveur netboot (parc important)
nix-build -A net-installer
```

### 6. Installer le poste

1. Démarrer le poste cible sur l'installeur (clé USB ou PXE)
2. Insérer la clé FIDO2 quand demandé (pour générer la phrase LUKS)
3. L'installeur :
   - Partitionne le disque selon le layout `office_v1`
   - Inscrit la clé FIDO2 dans LUKS
   - Récupère le *toplevel* correspondant au numéro de série (netboot) ou le système par défaut (USB)
   - Active le Secure Boot (lanzaboote)
4. Au premier boot : enregistrer la clé U2F utilisateur via `pamu2fcfg` côté session

### 7. Vérifier le build avant déploiement

```bash
nix-build -A terminals.<SERIAL>    # un poste précis
nix-build -A toplevelRegistry      # tous les postes (ce que fait la CI)
```

## Commandes de maintenance utiles

### Build et test

```bash
nix-shell                          # shell de dev (treefmt, npins, hooks)
nix-build -A terminals.<SERIAL>    # build d'un poste précis
nix-build -A toplevelRegistry      # build de tous les postes (parité CI)
nix-build -A usb-installer         # ISO USB
nix-build -A net-installer         # serveur netboot
```

### Format et lint

```bash
treefmt                            # formate tous les fichiers Nix
statix check .                     # lint Nix (aussi en pre-push)
reuse lint                         # conformité licences SPDX
```

### Gestion des pins

```bash
npins show                         # liste des dépendances pinnées
npins update                       # tout mettre à jour
npins update securix               # ne mettre à jour qu'une source
npins update nixpkgs               # mise à jour nixpkgs
```

### Netboot (poste de provisionnement)

```bash
# Ouvrir les ports requis
sudo nixos-firewall-tool udp/67
sudo nixos-firewall-tool udp/69
sudo nixos-firewall-tool tcp/8000

# Démarrer Pixiecore + Caddy
sudo hivemind
```

Voir `netboot/README.md` pour les prérequis client/serveur détaillés.

### Mise à jour d'un parc déployé

Si l'auto-update Sécurix est activé (cf. `infraRepositoryPath = "/etc/bureautix"` dans `common/default.nix`), un simple push sur le dépôt suffit : les postes récupèrent leur nouveau toplevel par leur numéro de série. Sinon, distribuer manuellement le résultat de `nix-build -A terminals.<SERIAL>` via `nixos-rebuild switch` ou copie de closure (`nix-copy-closure`).

### Débogage U2F / FIDO2

```bash
# Enregistrer une clé U2F pour la session (à exécuter en tant qu'utilisateur)
pamu2fcfg --appid pam://<votre-org> --origin pam://<votre-org> -n

# Vérifier l'inscription FIDO2 dans LUKS
sudo systemd-cryptenroll /dev/<partition-luks>
```

### Identifiants d'exemple (tests uniquement)

Les utilisateurs d'exemple (`alice`, `bob`, `heloise`, `abelard`) ont le mot de passe `test` et root `nixos`.
