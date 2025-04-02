# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  writeShellApplication,
  lib,
  systemd,
  wlopm,
  wayland-logout,
  givc-cli ? null,
  ghafConfig ? { },
}:
let
  useGivc = ghafConfig.givc.enable;
in
writeShellApplication {
  name = "ghaf-powercontrol";

  bashOptions = [ ];

  runtimeInputs = [
    systemd
    wlopm
    wayland-logout
  ] ++ (lib.optional useGivc givc-cli);

  text = ''
    help_msg() {
        cat << EOF
    Usage: $(basename "$0") [OPTION]

    Control Ghaf power states and user sessions.

    Options:
      reboot        Reboot the system using 'givc-cli' if enabled, otherwise 'systemctl'.
      poweroff      Power off the system using 'givc-cli' if enabled, otherwise 'systemctl'.
      suspend       Lock session, turn off display, suspend, and restore display on wake.
      logout        Log out using 'wayland-logout' and force-kill user session processes.
      help, --help  Show this help message and exit.
    EOF
    }

    if [ -z "$1" ]; then
        help_msg
        exit 0
    fi

    case "$1" in
      reboot|poweroff)
        ${if useGivc then "givc-cli ${ghafConfig.givc.cliArgs}" else "systemctl"} "$1"
        ;;
      suspend)
        # Lock sessions
        loginctl lock-session

        if [ -z "$WAYLAND_DISPLAY" ]; then
          export WAYLAND_DISPLAY="/run/user/${toString ghafConfig.users.loginUser.uid}/wayland-0"
        fi

        # Switch off display before suspension
        wlopm --off '*' || true

        # Send suspend command to host, ensure screen is on in case of failure
        ${if useGivc then "givc-cli ${ghafConfig.givc.cliArgs}" else "systemctl"} suspend \
          || wlopm --on '*' || true

        # Switch on display on wakeup
        wlopm --on '*' || true
        ;;
      logout)
        wayland-logout
        loginctl kill-user "$USER" -s SIGKILL
        ;;
      help|--help)
          help_msg
          exit 0
          ;;
      *)
          help_msg
          exit 1
          ;;
    esac
  '';

  meta = {
    description = "Wrapper script to control Ghaf power states using systemctl or GIVC.";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
