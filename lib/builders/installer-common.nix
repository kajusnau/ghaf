# SPDX-FileCopyrightText: 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# installer-common - the media-agnostic half of the Ghaf installer
#
# Everything the installer needs regardless of how it was booted: the TUI unit,
# plymouth, the installer packages, hostname and getty text. The media layer on
# top adds the boot medium and says where the image lives:
#
#   mkGhafInstaller.nix         ISO   -> imageSource = "/iso/ghaf-image"
#   mkGhafNetbootInstaller.nix  PXE   -> imageSource = an http(s) URL
#
# WHY THIS IS A SEPARATE MODULE RATHER THAN ONE SHARED nixosSystem:
# ISO and netboot cannot coexist in a single evaluation. nixpkgs'
# installer/cd-dvd/iso-image.nix and installer/netboot/netboot.nix both define
# config.lib.isoFileSystems."/nix/.ro-store".device at the same priority (and
# disagree on image.extension / image.filePath / system.build.image), so
# importing both is a conflicting-definition error. Sharing therefore has to
# mean sharing a *module*, evaluated twice, rather than one system built twice.
#
# KEEP THE TWO BUILDERS IN SYNC: anything added directly to mkGhafInstaller.nix
# that is not genuinely ISO-specific will silently be missing from the netboot
# installer. If it is not about the boot medium, it belongs here.
#
# Takes `self` and `system` at import time rather than reading them from module
# arguments: the builders construct their nixosSystem with
# `specialArgs = { inherit lib; }` only, so there is no `self` in scope inside
# the modules themselves.
{
  self,
  system,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ghaf.installer;

  # cage runs outputs at scale 1 and libcosmic ignores its own scale setting, so
  # scale each output to keep at least 900 logical pixels of height.
  guiLauncher = pkgs.writeShellScript "ghaf-installer-gui-launcher" ''
    ${pkgs.wlr-randr}/bin/wlr-randr --json |
      ${pkgs.jq}/bin/jq -r '.[] | select(.enabled) | "\(.name) \(.modes[] | select(.current) | .height)"' |
      while read -r name height; do
        scale=$((height / 900))
        ${pkgs.wlr-randr}/bin/wlr-randr --output "$name" --scale "$((scale > 1 ? scale : 1))"
      done
    exec ${pkgs.ghaf-setup}/bin/ghaf-installer-gui
  '';
in
{
  imports = [
    # Enable plymouth graphical boot
    "${self}/modules/desktop/graphics/boot.nix"
    "${self}/modules/development/usb-serial.nix"
    self.nixosModules.theming
  ];

  options.ghaf.installer.imageSource = lib.mkOption {
    type = lib.types.str;
    default = "/iso/ghaf-image";
    example = "http://192.0.2.1:8080/ghaf-image";
    description = ''
      Where ghaf-installer and ghaf-installer-tui look for ghaf-image.raw.zst
      and ghaf-image.bmap.

      A local directory (the ISO case) or an http(s) base URL (the netboot
      case). Exported as IMG_PATH; the installer scripts branch on the scheme.
      A `ghaf.image_url=` kernel parameter overrides it at runtime, which is how
      one netboot artefact can serve every target.
    '';
  };

  config = {
    environment = {
      sessionVariables.IMG_PATH = cfg.imageSource;
      variables.IMG_PATH = cfg.imageSource;
      systemPackages = [
        self.packages.${system}.ghaf-installer-tui
        self.packages.${system}.ghaf-installer
        self.packages.${system}.hardware-scan
        pkgs.ghaf-setup
        pkgs.cage
      ];
    };

    ghaf = {
      theming = {
        enable = true;
        # Defaults to the COSMIC desktop being enabled; the installer GUI needs it without.
        cosmic.enable = true;
        # Without it boot.nix falls back to the stock theme and its NixOS watermark.
        plymouth = {
          enable = true;
          bootLabel = "Starting Ghaf installer...";
        };
      };
      locales.enable = true;
      graphics.boot = {
        enable = true;
        renderer = "simpledrm";
      };
      development.usb-serial.enable = true;
    };

    # installation-cd-minimal disables it, which leaves the theme's fonts uninstalled.
    fonts.fontconfig.enable = true;

    # cage needs a userspace GL/GBM driver in /run/opengl-driver; the DRM node alone isn't enough.
    hardware.graphics.enable = true;

    boot = {
      # Boot straight through; hold Shift/Esc for the menu and its rescue options.
      loader.timeout = lib.mkForce 0;

      kernelPackages = pkgs.linuxPackages_latest;
      # Disable ZFS support - not compatible with latest. only supported on LTS.
      supportedFilesystems.zfs = lib.mkForce false;

      # Serial console in the installers.
      kernelParams = [
        "console=tty0"
        "console=ttyUSB0,115200"
      ];

      # NOTE: Stop nixos complains about "warning:
      # mdadm: Neither MAILADDR nor PROGRAM has been set. This will cause the `mdmon` service to crash."
      # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/installation-device.nix#L112
      swraid.mdadmConf = "PROGRAM ${pkgs.coreutils}/bin/true";
    };

    image.baseName = lib.mkForce "ghaf";

    networking = {
      hostName = "ghaf-installer";
      networkmanager.enable = true;
    };

    services = {
      getty = {
        greetingLine = "<<< Welcome to the Ghaf installer >>>";
        helpLine = lib.mkAfter ''

          The Ghaf installer starts on its own at boot. To start it again, run
          `sudo systemctl start ghaf-installer`; it is graphical where there
          is a display, and falls back to the text installer otherwise.

          To use the text installer directly, run `sudo ghaf-installer-tui`.

          To install without prompts, run `sudo ghaf-installer`;
          see `ghaf-installer -h` for its options.
        '';
      };

      # A live installer has no saved brightness; use the panel's full backlight.
      udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.runtimeShell} -c 'cat /sys$devpath/max_brightness > /sys$devpath/brightness'"
      '';
    };

    systemd.services = {
      wpa_supplicant.wantedBy = lib.mkForce [ "multi-user.target" ];
      sshd.wantedBy = lib.mkForce [ "multi-user.target" ];

      # Autostart the installer on tty1, replacing the default getty.
      ghaf-installer = {
        description = "Ghaf Installer";
        after = [ "multi-user.target" ];
        wantedBy = [ "multi-user.target" ];
        conflicts = [ "getty@tty1.service" ];
        environment = {
          IMG_PATH = cfg.imageSource;
          # cage is a system service, not a login session: give it a socket dir of its own.
          XDG_RUNTIME_DIR = "/run/ghaf-installer-gui";
          # A system service gets no XDG_DATA_DIRS; the GUI reads the Ghaf theme from here.
          XDG_DATA_DIRS = "/run/current-system/sw/share";
          # The installer has no icon themes; without cursors the pointer cannot change shape.
          XCURSOR_THEME = "Pop";
          XCURSOR_PATH = "${pkgs.pop-icon-theme}/share/icons";
        };
        serviceConfig = {
          RuntimeDirectory = "ghaf-installer-gui";
          ExecStart = pkgs.writeShellScript "ghaf-installer-autostart" ''
            # ghaf-installer reads ghaf.install_target/_encrypt/_secureboot and
            # ghaf.image_url itself, so the dispatch here is only about which of
            # the two front-ends to run.
            if grep -q 'ghaf\.install_target=' /proc/cmdline 2>/dev/null; then
              echo "ghaf.install_target= on the kernel command line: installing unattended." >&2
              # Tee'd rather than exec'd: StandardOutput is the tty, so without
              # this an unattended install's only record is a screen nobody is
              # watching -- and its warnings are exactly what you need after a
              # machine comes back unbootable. tee keeps the console copy.
              set -o pipefail
              ${self.packages.${system}.ghaf-installer}/bin/ghaf-installer 2>&1 |
                ${pkgs.coreutils}/bin/tee >(${pkgs.systemd}/bin/systemd-cat -t ghaf-installer)
              exit "''${PIPESTATUS[0]}"
            fi
            # Any card, not just card0: on hybrid graphics the usable device can be card1+.
            ${pkgs.systemd}/bin/udevadm settle --timeout=5
            if ls /dev/dri/card* > /dev/null 2>&1; then
              ${pkgs.cage}/bin/cage -- ${guiLauncher} && exit 0
              echo "cage exited non-zero; falling back to the text installer." >&2
            else
              echo "No DRM device found; falling back to the text installer." >&2
            fi
            exec ${self.packages.${system}.ghaf-installer-tui}/bin/ghaf-installer-tui
          '';
          ExecStartPre = [
            # Suppress kernel printk noise on tty1 while TUI is active
            "${pkgs.util-linux}/bin/dmesg -n 1"
          ]
          # Plymouth holds DRM and deadlocks with cage; best-effort, it may already be gone.
          ++ lib.optional config.ghaf.graphics.boot.enable "-${pkgs.systemd}/bin/systemctl stop plymouth-start.service";
          # Restore kernel log level and hand tty1 back to getty on exit
          ExecStopPost = [
            "${pkgs.util-linux}/bin/dmesg -n 7"
            "${pkgs.systemd}/bin/systemctl start getty@tty1.service"
          ];
          StandardInput = "tty";
          StandardOutput = "tty";
          StandardError = "tty";
          TTYPath = "/dev/tty1";
          TTYReset = true;
          TTYVHangup = true;
          PrivateTmp = true;
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };

    # Configure nixpkgs with Ghaf overlays for extended lib support
    nixpkgs = {
      hostPlatform.system = system;
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "jitsi-meet-1.0.8043"
          "qtwebengine-5.15.19"
        ];
      };
      overlays = [ self.overlays.default ];
    };
  };
}
