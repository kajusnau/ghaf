# SPDX-FileCopyrightText: 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# Module which adds option ghaf.boot.loader.systemd-boot-dtb.enable
#
# By setting this option to true, device tree file gets copied to
# /boot-partition, and gets added to systemd-boot's entry.
#
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ghaf.hardware.aarch64.systemd-boot-dtb;
  inherit (lib) mkEnableOption mkIf;
in
{
  _file = ./systemd-boot-dtb.nix;

  options.ghaf.hardware.aarch64.systemd-boot-dtb = {
    enable = mkEnableOption "systemd-boot-dtb";
  };

  config = mkIf cfg.enable {
    boot.loader.systemd-boot = {
      extraFiles."dtbs/${config.hardware.deviceTree.name}" =
        "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
      extraInstallCommands = ''
        # Find out the latest generation from loader.conf
        default_cfg=$(${lib.getExe' pkgs.coreutils "cat"} /boot/loader/loader.conf | ${lib.getExe pkgs.gnugrep} default | ${lib.getExe' pkgs.gawk "awk"} '{print $2}')
        FILEHASH=$(${lib.getExe' pkgs.coreutils "sha256sum"} "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}" | ${lib.getExe' pkgs.coreutils "cut"} -d ' ' -f 1)
        FILENAME="/dtbs/$FILEHASH.dtb"
        ${lib.getExe' pkgs.coreutils "cp"} -fv "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}" "/boot$FILENAME"
        echo "devicetree $FILENAME" >> /boot/loader/entries/$default_cfg
      '';
    };
  };
}
