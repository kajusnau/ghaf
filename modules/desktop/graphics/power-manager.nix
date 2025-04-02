# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.ghaf.graphics.power-manager;

  ghaf-powercontrol = pkgs.ghaf-powercontrol.override { ghafConfig = config.ghaf; };

  logindSuspendListener = pkgs.writeShellApplication {
    name = "logind-suspend-listener";
    runtimeInputs = [
      pkgs.dbus
      pkgs.systemd
      pkgs.toybox
      ghaf-powercontrol
    ];
    text = ''
      systemd-inhibit --what=sleep --who="ghaf-powercontrol" \
        --why="Handling ghaf suspend" --mode=delay \
          dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" | \
            while read -r line; do
              if echo "$line" | grep -q "boolean true"; then
                echo "Found prepare for sleep signal"
                echo "Suspending via ghaf-powercontrol"
                ghaf-powercontrol suspend
              fi
            done
    '';
  };

  logindShutdownListener = pkgs.writeShellApplication {
    name = "logind-shutdown-listener";
    runtimeInputs = [
      pkgs.dbus
      pkgs.systemd
      ghaf-powercontrol
    ];
    text = ''
      systemd-inhibit --what=shutdown --who="ghaf-powercontrol" \
        --why="Handling system shutdown/reboot" --mode=delay \
          dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForShutdownWithMetadata'" | \
            while read -r line; do
              if echo "$line" | grep -q "boolean true"; then
                echo "Found prepare for shutdown signal. Checking type..."
                while read -r subline; do
                    if echo "$subline" | grep -q "reboot"; then
                        echo "Found type: reboot"
                        echo "Rebooting via ghaf-powercontrol"
                        ghaf-powercontrol reboot
                    elif echo "$subline" | grep -q "poweroff"; then
                        echo "Found type: power-off"
                        echo "Powering off via ghaf-powercontrol"
                        ghaf-powercontrol poweroff
                    fi
                done
              fi
            done
    '';
  };
in
{
  options.ghaf.graphics.power-manager = {
    enable = lib.mkEnableOption "Override logind power management using ghaf-powercontrol";
  };

  config = lib.mkIf cfg.enable {
    systemd.services = {
      logind-shutdown-listener = {
        enable = true;
        description = "Ghaf logind shutdown listener";
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "5";
          ExecStart = "${lib.getExe logindShutdownListener}";
        };
        partOf = [ "graphical.target" ];
        wantedBy = [ "graphical.target" ];
      };

      logind-suspend-listener = {
        # Currently not working as expected,
        # system continues to suspend even after ghaf-powercontrol suspend is called
        enable = true;
        description = "Ghaf logind suspend listener";
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "5";
          ExecStart = "${lib.getExe logindSuspendListener}";
        };
        partOf = [ "graphical.target" ];
        wantedBy = [ "graphical.target" ];
      };
    };
  };
}
