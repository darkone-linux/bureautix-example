# SPDX-FileCopyrightText: 2026 Bureautix authors
#
# SPDX-License-Identifier: MIT
#
# Configuration de démo *autonome* pour lancer un Bureautix simplifié dans QEMU.
#
# ATTENTION : cette configuration ne reflète PAS le modèle de sécurité réel de
# Bureautix. Elle désactive volontairement :
#   - LUKS + FIDO2 (pas de token dans une VM)
#   - PAM U2F (idem)
#   - Secure Boot + lanzaboote (pas de clés enrôlées dans la VM)

{ pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
  ];

  system.stateVersion = "25.11";

  virtualisation = {
    memorySize = 4096;
    cores = 2;
    diskSize = 16384;
    graphics = true;
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
  };

  networking = {
    hostName = "bureautix-demo";
    firewall.enable = false;
    networkmanager.enable = true;
  };

  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";
  time.timeZone = "Europe/Paris";

  services = {
    xserver.xkb.layout = "fr";
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    desktopManager.plasma6.enable = true;
    displayManager.autoLogin = {
      enable = true;
      user = "demo";
    };
    openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
    };
  };

  users.users.demo = {
    isNormalUser = true;
    description = "Démo Bureautix";
    initialPassword = "demo";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
  users.users.root.initialPassword = "demo";

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    libreoffice
    vscodium
    kitty
    git
    ripgrep
    fd
    zellij
  ];

  nixpkgs.config.allowUnfree = true;
}
