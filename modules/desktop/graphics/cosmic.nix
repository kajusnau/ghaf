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
        mkdir -p "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_CONFIG_HOME/gtk-4.0"

        echo -e "${gtk-settings}" > "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
        echo -e "${gtk-settings}" > "$XDG_CONFIG_HOME/gtk-4.0/settings.ini"
      '';
  };

  gtk-settings = ''
    [Settings]
    gtk-application-prefer-dark-theme=1
    gtk-icon-theme-name=Papirus-Dark
    gtk-button-images=1
    gtk-menu-images=1
    gtk-enable-event-sounds=1
    gtk-enable-input-feedback-sounds=1
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=hintslight
    gtk-xft-rgba=rgb
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

    programs.dconf = {
      enable = true;
      profiles.user = {
        databases = [
          {
            lockAll = false;
            settings = {
              "org/gnome/desktop/interface" = {
                color-scheme = "prefer-dark";
                #gtk-theme = cfg.gtk.theme;
                icon-theme = "Papirus-Dark";
                #font-name = "${cfg.gtk.fontName} ${cfg.gtk.fontSize}";
                #clock-format = "24h";
              };
            };
          }
        ];
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

    users.users.cosmic-greeter.extraGroups = [ "video" ];
  };
}
