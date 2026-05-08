# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ lib, ... }:
{
  securix = {
    filesystems.enable = lib.mkForce false;
    pam.u2f.enable = lib.mkForce false;
    admins.enable = lib.mkForce false;
  };

  users.users.bob = {
    isNormalUser = true;
    password = "test";
    extraGroups = [ "wheel" ];
  };

  services.qemuGuest.enable = true;

  boot.loader.timeout = 10;

  disko.devices.disk.main = {
    device = "/dev/vda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "500M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "/root" = {
                mountpoint = "/";
              };
              "/home" = {
                mountpoint = "/home";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
            };
            mountpoint = "/partition-root";
          };
        };
      };
    };
  };
}
