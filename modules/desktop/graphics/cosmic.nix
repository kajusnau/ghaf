# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.ghaf.graphics.cosmic;

  inherit (import ../../../lib/launcher.nix { inherit pkgs lib; }) rmDesktopEntries;

  autostart = pkgs.writeShellApplication {
    name = "autostart";

    runtimeInputs = [
      pkgs.systemd
      pkgs.dbus
      pkgs.glib
    ];

    text = ''
      systemctl --user stop ghaf-session.target
      systemctl --user start ghaf-session.target
    '';
  };

  cosmicOverrides = [
    # Add DBUS proxy socket for audio, network, and bluetooth applets
    (pkgs.cosmic-applets.overrideAttrs (oldAttrs: {
      postInstall =
        oldAttrs.postInstall or ""
        + ''
          sed -i 's|^Exec=.*|Exec=env DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbusproxy_net.sock cosmic-applet-network|' $out/share/applications/com.system76.CosmicAppletNetwork.desktop
          sed -i 's|^Exec=.*|Exec=env PULSE_SERVER="audio-vm:${toString config.ghaf.services.audio.pulseaudioTcpControlPort}" DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbusproxy_snd.sock cosmic-applet-audio|' $out/share/applications/com.system76.CosmicAppletAudio.desktop
          sed -i 's|^Exec=.*|Exec=env DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbusproxy_snd.sock cosmic-applet-bluetooth|' $out/share/applications/com.system76.CosmicAppletBluetooth.desktop
        '';
    }))
  ];

  ghaf-cosmic-config = pkgs.stdenv.mkDerivation rec {
    pname = "ghaf-cosmic-config";
    version = "0.1";

    phases = [
      "installPhase"
      "postInstall"
    ];

    src = ./cosmic-config/cosmic;

    installPhase = ''
      mkdir -p $out/share/cosmic
      cp -r $src/* $out/share/cosmic
    '';

    postInstall = ''
      substituteInPlace $out/share/cosmic/com.system76.CosmicBackground/v1/all \
        --replace "None" "Path(\"${pkgs.ghaf-artwork}/ghaf-desert-sunset.jpg\")"
    '';

    meta = with lib; {
      description = "Installs default Ghaf COSMIC configuration";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
  };
in
{
  options.ghaf.graphics.cosmic = {
    enable = lib.mkEnableOption "cosmic";

    autologinUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.ghaf.users.admin.name;
      description = ''
        Username of the account that will be automatically logged in to the desktop.
        If unspecified, the login manager is shown as usual.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Login is handled by cosmic-greeter
    ghaf.graphics.login-manager.enable = false;

    environment = {
      systemPackages =
        [
          pkgs.dconf-editor
          pkgs.papirus-icon-theme
          pkgs.adwaita-icon-theme
          pkgs.pamixer
          pkgs.d-spy
          ghaf-cosmic-config
          (import ./launchers.nix { inherit pkgs config; })
        ]
        ++ cosmicOverrides
        ++ (rmDesktopEntries [

        ]);
      sessionVariables = {
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_STATE_HOME = "$HOME/.local/state";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_PICTURES_DIR = "$HOME/Pictures";
        XDG_VIDEOS_DIR = "$HOME/Videos";
        #GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
      };
    };

    # Needed for the greeter to query systemd-homed users correctly
    systemd.services.cosmic-greeter-daemon = {
      environment = {
        LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ pkgs.systemd ]}";
      };
    };

    security.pam.services = {
      cosmic-greeter = {
        rules.auth = {
          systemd_home.order = 11399; # Re-order to allow either password _or_ fingerprint
          fprintd.args = [ "maxtries=3" ];
        };
      };
      greetd = {
        fprintAuth = false; # User needs to enter password to decrypt home
        rules = {
          account.group_video = {
            enable = true;
            control = "requisite";
            modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
            order = 10000;
            args = [
              "user"
              "ingroup"
              "video"
            ];
          };
          account.systemd_home = {
            enable = true;
            control = "sufficient";
            order = 500;
          };
        };
      };
    };

    services = {
      seatd = {
        enable = true;
        group = "video";
      };
    };

    systemd.user.services = {
      autostart = {
        enable = true;
        description = "Ghaf autostart";
        serviceConfig = {
          ExecStart = "${autostart}/bin/autostart";
        };
        partOf = [ "cosmic-session.target" ];
        wantedBy = [ "cosmic-session.target" ];
      };

      audio-control = {
        enable = true;
        description = "Audio Control application";
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "5";
          ExecStart = "${pkgs.ghaf-audio-control}/bin/GhafAudioControlStandalone --pulseaudio_server=audio-vm:${toString config.ghaf.services.audio.pulseaudioTcpControlPort} --deamon_mode=true --indicator_icon_name=audio-subwoofer";
        };
        partOf = [ "cosmic-session.target" ];
        wantedBy = [ "cosmic-session.target" ];
      };

      # We use existing blueman services and create overrides for both
      blueman-applet = {
        enable = false;
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "1";
          ExecStart = [
            ""
            "${pkgs.bt-launcher}/bin/bt-launcher applet"
          ];
        };
        partOf = [ "cosmic-session.target" ];
        wantedBy = [ "cosmic-session.target" ];
      };

      blueman-manager = {
        enable = false;
        serviceConfig.ExecStart = [
          ""
          "${pkgs.bt-launcher}/bin/bt-launcher"
        ];
      };
    };

    systemd.user.targets.ghaf-session = {
      enable = true;
      description = "Ghaf labwc session";
      unitConfig = {
        BindsTo = [ "graphical-session.target" ];
        After = [ "graphical-session-pre.target" ];
        Wants = [ "graphical-session-pre.target" ];
      };
    };

    environment.sessionVariables = {
      PULSE_SERVER = "audio-vm:${toString config.ghaf.services.audio.pulseaudioTcpControlPort}";
    };

    hardware.bluetooth.enable = lib.mkForce false;

    services.acpid.enable = lib.mkForce false;

    services.gvfs.enable = lib.mkForce false;

    services.avahi.enable = lib.mkForce false;

    security.rtkit.enable = lib.mkForce false;

    services.geoclue2.enable = lib.mkForce false;

    networking.networkmanager.enable = lib.mkForce false;

    services.pipewire = {
      enable = lib.mkForce false;
      alsa.enable = lib.mkForce false;
      pulse.enable = lib.mkForce false;
    };

    services.playerctld.enable = true;

    #xdg.portal.enable = lib.mkForce false;

    users.users.cosmic-greeter.extraGroups = [ "video" ];
  };
}
