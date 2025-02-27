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

  autostart = pkgs.writeShellApplication {
    name = "autostart";

    runtimeInputs = [
      pkgs.systemd
      pkgs.dbus
      pkgs.glib
    ];

    text =
      ''
        echo -ne "\"Papirus-Dark\"" > .config/cosmic/com.system76.CosmicTk/v1/icon_theme
      '';
  };

  system_actions_RON = ''
    {
        /// Opens the application library
        AppLibrary: "cosmic-app-library",
        /// Decreases screen brightness
        BrightnessDown: "busctl --user call com.system76.CosmicSettingsDaemon /com/system76/CosmicSettingsDaemon com.system76.CosmicSettingsDaemon DecreaseDisplayBrightness",
        /// Increases screen brightness
        BrightnessUp: "busctl --user call com.system76.CosmicSettingsDaemon /com/system76/CosmicSettingsDaemon com.system76.CosmicSettingsDaemon IncreaseDisplayBrightness",
        /// Switch between input sources
        InputSourceSwitch: "busctl --user call com.system76.CosmicSettingsDaemon /com/system76/CosmicSettingsDaemon com.system76.CosmicSettingsDaemon InputSourceSwitch",
        /// Opens the home folder in a system default file browser
        HomeFolder: "xdg-open ~",
        /// Logs out
        LogOut: "cosmic-osd log-out",
        /// Decreases keyboard brightness
        // KeyboardBrightnessDown,
        /// Increases keyboard brightness
        // KeyboardBrightnessUp,
        /// Opens the launcher
        Launcher: "cosmic-launcher",
        /// Locks the screen
        LockScreen: "loginctl lock-session",
        /// Mutes the active output device
        Mute: "amixer sset Master toggle",
        /// Mutes the active microphone
        MuteMic: "amixer sset Capture toggle",
        /// Plays and Pauses audio
        PlayPause: "playerctl play-pause",
        /// Goes to the next track
        PlayNext: "playerctl next",
        /// Goes to the previous track
        PlayPrev: "playerctl previous",
        /// Takes a screenshot
        Screenshot: "cosmic-screenshot",
        /// Opens the system default terminal
        Terminal: "cosmic-term",
        /// Lowers the volume of the active output device
        VolumeLower: "amixer sset Master on; amixer sset Master 5%-",
        /// Raises the volume of the active output device
        VolumeRaise: "amixer sset Master on; amixer sset Master 5%+",
        /// Opens the system default web browser
        WebBrowser: "xdg-open http://",
        /// Opens the (alt+tab) window switcher
        WindowSwitcher: "cosmic-launcher alt-tab",
        /// Opens the (alt+shift+tab) window switcher
        WindowSwitcherPrevious: "cosmic-launcher shift-alt-tab",
        /// Opens the workspace overview
        WorkspaceOverview: "cosmic-workspaces",
    }
  '';
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
          pkgs.cosmic-ext-ctl
          pkgs.papirus-icon-theme
          pkgs.adwaita-icon-theme
          (import ./launchers.nix { inherit pkgs config; })
        ];
      sessionVariables = {
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_STATE_HOME = "$HOME/.local/state";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_PICTURES_DIR = "$HOME/Pictures";
        XDG_VIDEOS_DIR = "$HOME/Videos";
        GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
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

      nm-applet = {
        enable = true;
        description = "Network manager applet";
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "1";
          Environment = "DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbusproxy_net.sock";
          ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
        };
        partOf = [ "cosmic-session.target" ];
        wantedBy = [ "cosmic-session.target" ];
      };

      # We use existing blueman services and create overrides for both
      blueman-applet = {
        enable = true;
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
        serviceConfig.ExecStart = [
          ""
          "${pkgs.bt-launcher}/bin/bt-launcher"
        ];
      };
    };

    environment.sessionVariables = {
      PULSE_SERVER="audio-vm:${toString config.ghaf.services.audio.pulseaudioTcpControlPort}";
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

    xdg.portal.enable = lib.mkForce false;

    users.users.cosmic-greeter.extraGroups = [ "video" ];
  };
}
