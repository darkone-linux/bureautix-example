# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ lib, pkgs, ... }:
{
  imports = [ ./vm.nix ];

  boot.initrd.kernelModules = [ "tpm_tis" ];

  environment.systemPackages = with pkgs; [
    tpm2-tss
    tpm2-tools
  ];
}
