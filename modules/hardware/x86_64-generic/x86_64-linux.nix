# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ghaf.hardware.x86_64.common;
in
{
  options.ghaf.hardware.x86_64.common = {
    enable = lib.mkEnableOption "Common x86 configs";
  };

  config = lib.mkIf cfg.enable {

    # Add this for x86_64 hosts to be able to more generically support hardware.
    # For example Intel NUC 11's graphics card needs this in order to be able to
    # properly provide acceleration.
    hardware.enableRedistributableFirmware = true;
    hardware.enableAllFirmware = true;

    boot = {
      # Enable normal Linux console on the display
      kernelParams = [ "console=tty0" ];

      # To enable installation of ghaf into NVMe drives
      initrd.availableKernelModules = [
        "nvme"
        "uas"
      ];
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot.enable = true;
      };

      # TODO the kernel latest is currently broken for zfs.
      # try to fix on the next update.
      kernelPackages = pkgs.linuxPackages;
    };
  };
}
