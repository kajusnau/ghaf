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
      echo -ne "\"Papirus-Dark\"" > .config/cosmic/com.system76.CosmicTk/v1/icon_theme

      systemctl --user stop ghaf-session.target
      systemctl --user start ghaf-session.target
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
        Mute: "pamixer --toggle-mute",
        /// Mutes the active microphone
        MuteMic: "pamixer --default-source --toggle-mute",
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
        VolumeLower: "pamixer --unmute --decrease 5",
        /// Raises the volume of the active output device
        VolumeRaise: "pamixer --unmute --increase 5",
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

  keybindings_RON = ''
    {
        (modifiers: [Super, Alt], key: "Escape"): Terminate,
        (modifiers: [Super, Shift], key: "Escape"): System(LogOut),
        (modifiers: [Super, Ctrl], key: "Escape"): Debug,
        (modifiers: [Super], key: "l"): System(LockScreen),
        (modifiers: [Alt], key: "F4"): Close,

        (modifiers: [Super, Alt], key: "1"): Workspace(1),
        (modifiers: [Super, Alt], key: "2"): Workspace(2),
        (modifiers: [Super, Alt], key: "3"): Workspace(3),
        (modifiers: [Super, Alt], key: "4"): Workspace(4),
        (modifiers: [Super, Alt], key: "5"): Workspace(5),
        (modifiers: [Super, Alt], key: "6"): Workspace(6),
        (modifiers: [Super, Alt], key: "7"): Workspace(7),
        (modifiers: [Super, Alt], key: "8"): Workspace(8),
        (modifiers: [Super, Alt], key: "9"): Workspace(9),
        (modifiers: [Super, Alt], key: "0"): LastWorkspace,
        (modifiers: [Super, Shift], key: "1"): MoveToWorkspace(1),
        (modifiers: [Super, Shift], key: "2"): MoveToWorkspace(2),
        (modifiers: [Super, Shift], key: "3"): MoveToWorkspace(3),
        (modifiers: [Super, Shift], key: "4"): MoveToWorkspace(4),
        (modifiers: [Super, Shift], key: "5"): MoveToWorkspace(5),
        (modifiers: [Super, Shift], key: "6"): MoveToWorkspace(6),
        (modifiers: [Super, Shift], key: "7"): MoveToWorkspace(7),
        (modifiers: [Super, Shift], key: "8"): MoveToWorkspace(8),
        (modifiers: [Super, Shift], key: "9"): MoveToWorkspace(9),
        (modifiers: [Super, Shift], key: "0"): MoveToLastWorkspace,
        (modifiers: [Super, Shift], key: "Right"): MoveToNextWorkspace,
        (modifiers: [Super, Shift], key: "Left"): MoveToPreviousWorkspace,

        (modifiers: [Super, Ctrl, Alt], key: "Left"): MoveToOutput(Left),
        (modifiers: [Super, Ctrl, Alt], key: "Down"): MoveToOutput(Down),
        (modifiers: [Super, Ctrl, Alt], key: "Up"): MoveToOutput(Up),
        (modifiers: [Super, Ctrl, Alt], key: "Right"): MoveToOutput(Right),
        (modifiers: [Super, Ctrl, Alt], key: "h"): MoveToOutput(Left),
        (modifiers: [Super, Ctrl, Alt], key: "k"): MoveToOutput(Down),
        (modifiers: [Super, Ctrl, Alt], key: "j"): MoveToOutput(Up),
        (modifiers: [Super, Ctrl, Alt], key: "l"): MoveToOutput(Right),

        (modifiers: [Super], key: "Period"): NextOutput,
        (modifiers: [Super], key: "Comma"): PreviousOutput,
        (modifiers: [Super, Shift], key: "Period"): MoveToNextOutput,
        (modifiers: [Super, Shift], key: "Comma"): MoveToPreviousOutput,

        (modifiers: [Super], key: "Left"): Focus(Left),
        (modifiers: [Super], key: "Right"): Focus(Right),
        (modifiers: [Super], key: "Up"): Focus(Up),
        (modifiers: [Super], key: "Down"): Focus(Down),
        (modifiers: [Super], key: "h"): Focus(Left),
        (modifiers: [Super], key: "j"): Focus(Down),
        (modifiers: [Super], key: "k"): Focus(Up),
        (modifiers: [Super], key: "l"): Focus(Right),
        (modifiers: [Super], key: "u"): Focus(Out),
        (modifiers: [Super], key: "i"): Focus(In),

        (modifiers: [Super, Shift], key: "Left"): Move(Left),
        (modifiers: [Super, Shift], key: "Right"): Move(Right),
        (modifiers: [Super, Shift], key: "Up"): Move(Up),
        (modifiers: [Super, Shift], key: "Down"): Move(Down),
        (modifiers: [Super, Shift], key: "h"): Move(Left),
        (modifiers: [Super, Shift], key: "j"): Move(Down),
        (modifiers: [Super, Shift], key: "k"): Move(Up),
        (modifiers: [Super, Shift], key: "l"): Move(Right),

        (modifiers: [Super], key: "o"): ToggleOrientation,
        (modifiers: [Super], key: "s"): ToggleStacking,
        (modifiers: [Super], key: "y"): ToggleTiling,
        (modifiers: [Super], key: "g"): ToggleWindowFloating,
        (modifiers: [Super], key: "x"): SwapWindow,

        (modifiers: [Super], key: "m"): Maximize,
        (modifiers: [Super], key: "r"): Resizing(Outwards),
        (modifiers: [Super, Shift], key: "r"): Resizing(Inwards),

        (modifiers: [Super], key: "equal"): ZoomIn,
        (modifiers: [Super], key: "minus"): ZoomOut,

        (modifiers: [Super], key: "b"): System(WebBrowser),
        (modifiers: [Super], key: "f"): System(HomeFolder),
        (modifiers: [Super], key: "space"): System(InputSourceSwitch),
        ${lib.optionalString (!config.ghaf.profiles.debug.enable) ''
          (modifiers: [Ctrl, Alt], key: "t"): System(Terminal),
        ''}

        (modifiers: [Super], key: "w"): System(WorkspaceOverview),
        (modifiers: [Super], key: "slash"): System(Launcher),
        (modifiers: [Super]): System(AppLibrary),
        (modifiers: [Alt], key: "Tab"): System(WindowSwitcher),
        (modifiers: [Alt, Shift], key: "Tab"): System(WindowSwitcherPrevious),
        (modifiers: [Super], key: "Tab"): System(WindowSwitcher),
        (modifiers: [Super, Shift], key: "Tab"): System(WindowSwitcherPrevious),

        (modifiers: [], key: "Print"): System(Screenshot),
        (modifiers: [], key: "XF86AudioRaiseVolume"): System(VolumeRaise),
        (modifiers: [], key: "XF86AudioLowerVolume"): System(VolumeLower),
        (modifiers: [], key: "XF86AudioMute"): System(Mute),
        (modifiers: [], key: "XF86AudioMicMute"): System(MuteMic),
        (modifiers: [], key: "XF86MonBrightnessUp"): System(BrightnessUp),
        (modifiers: [], key: "XF86MonBrightnessDown"): System(BrightnessDown),
        (modifiers: [], key: "XF86AudioPlay"): System(PlayPause),
        (modifiers: [], key: "XF86AudioPrev"): System(PlayPrev),
        (modifiers: [], key: "XF86AudioNext"): System(PlayNext),
    }
  '';

  applist_favorites = ''
    [
      "com.system76.CosmicFiles",
      "com.system76.CosmicEdit",
      ${lib.optionalString (!config.ghaf.profiles.debug.enable) ''
        "com.system76.CosmicTerm",
      ''}
      "com.system76.CosmicSettings",
    ]
  '';

  cosmic_bg_all_RON = ''
    (
        output: "all",
        source: Path("${pkgs.ghaf-artwork}/ghaf-desert-sunset.jpg"),
        filter_by_theme: true,
        rotation_frequency: 3600,
        filter_method: Lanczos,
        scaling_mode: Zoom,
        sampling_method: Alphanumeric,
    )
  '';

  cosmic_bg_backgrounds_RON = ''
    [All]
  '';

  xkb_config = ''
    (
        rules: "",
        model: "pc104",
        layout: "us,ara,fi",
        variant: ",,",
        options: Some("grp:alt_shift_toggle"),
        repeat_delay: 600,
        repeat_rate: 25,
    )
  '';

  cosmic_panel_dock_plugins_center_RON = ''
    Some([
        "com.system76.CosmicPanelLauncherButton",
        "com.system76.CosmicPanelWorkspacesButton",
        "com.system76.CosmicPanelAppButton",
        "com.system76.CosmicAppList",
        "com.system76.CosmicAppletMinimize",
    ])
  '';

  cosmic_panel_dock_plugins_wings_RON = ''
    Some(([], []))
  '';

  cosmic_panel_dock_autohide_RON = ''
    Some((
        wait_time: 1000,
        transition_time: 200,
        handle_size: 4,
    ))
  '';

  cosmic_panel_dock_anchor_gap_RON = ''
    true
  '';

  cosmic_panel_dock_margin_RON = ''
    4
  '';

  cosmic_panel_dock_border_radius_RON = ''
    15
  '';

  cosmic_panel_panel_plugins_center_RON = ''
    Some([
        "com.system76.CosmicAppletTime",
    ])
  '';

  cosmic_panel_panel_plugins_wings_RON = ''
    Some(([
        "com.system76.CosmicPanelWorkspacesButton",
        "com.system76.CosmicPanelAppButton",
    ], [
        "com.system76.CosmicAppletInputSources",
        "com.system76.CosmicAppletStatusArea",
        "com.system76.CosmicAppletTiling",
        "com.system76.CosmicAppletAudio",
        "com.system76.CosmicAppletNetwork",
        "com.system76.CosmicAppletBattery",
        "com.system76.CosmicAppletNotifications",
        "com.system76.CosmicAppletBluetooth",
        "com.system76.CosmicAppletPower",
    ]))
  '';

  cosmic_idle_screen_off_time_RON = ''
    Some(900000)
  '';

  cosmic_idle_suspend_on_ac_time_RON = ''
    Some(1800000)
  '';

  cosmic_idle_suspend_on_battery_time_RON = ''
    Some(1800000)
  '';

  cosmic_tk_icon_theme_RON = ''
    "Papirus-Dark"
  '';

  cosmic_applet_time_first_day_of_week_RON = ''
    0
  '';

  cosmicOverrides = [
    # Add DBUS proxy socket for audio, network, and bluetooth applets
    (pkgs.cosmic-applets.overrideAttrs (oldAttrs: {
      postInstall =
        oldAttrs.postInstall or ""
        + ''
          sed -i 's|^Exec=.*|Exec=env DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbusproxy_net.sock cosmic-applet-network|' $out/share/applications/com.system76.CosmicAppletNetwork.desktop
          sed -i 's|^Exec=.*|Exec=env PULSE_SERVER="audio-vm:${toString config.ghaf.services.audio.pulseaudioTcpControlPort}" DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbusproxy_snd.sock cosmic-applet-audio|' $out/share/applications/com.system76.CosmicAppletAudio.desktop
          sed -i 's|^Exec=.*|Exec=env DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbusproxy_snd.sock cosmic-applet-bluetooth|' $out/share/applications/com.system76.CosmicAppletBluetooth.desktop

          mkdir -p $out/share/cosmic/com.system76.CosmicAppletTime/v1

          # Override the default AppList favorites in the dock
          echo -ne '${applist_favorites}' > $out/share/cosmic/com.system76.CosmicAppList/v1/favorites
          # Override the default first day of the week
          echo -ne '${cosmic_applet_time_first_day_of_week_RON}' > $out/share/cosmic/com.system76.CosmicAppletTime/v1/first_day_of_week
        '';
    }))

    # Override compositor defaults
    (pkgs.cosmic-comp.overrideAttrs (oldAttrs: {
      postInstall =
        oldAttrs.postInstall or ""
        + ''
          mkdir -p $out/share/cosmic/com.system76.CosmicComp/v1
          mkdir -p $out/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1
          mkdir -p $out/share/cosmic/com.system76.CosmicTk/v1
          # Override the default xkb_config
          echo -ne '${xkb_config}' > $out/share/cosmic/com.system76.CosmicComp/v1/xkb_config
          # Override the default keybindings
          echo -ne '${keybindings_RON}' > $out/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/defaults
          # Override the default icon theme
          echo -ne '${cosmic_tk_icon_theme_RON}' > $out/share/cosmic/com.system76.CosmicTk/v1/icon_theme
        '';
    }))

    # Override compositor defaults
    (pkgs.cosmic-settings-daemon.overrideAttrs (oldAttrs: {
      postInstall =
        oldAttrs.postInstall or ""
        + ''
          mkdir -p $out/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1
          echo -ne '${xkb_config}' > $out/share/cosmic/com.system76.CosmicComp/v1/xkb_config
          # Override the default system actions
          echo -ne '${system_actions_RON}' > $out/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/system_actions
        '';
    }))

    # Override background defaults
    (pkgs.cosmic-bg.overrideAttrs (oldAttrs: {
      postInstall =
        oldAttrs.postInstall or ""
        + ''
          mkdir -p $out/share/cosmic/com.system76.CosmicBackground/v1
          # Override default background
          echo -ne '${cosmic_bg_all_RON}' > $out/share/cosmic/com.system76.CosmicBackground/v1/all
          # Override default backgrounds per display (currently set to default [All])
          echo -ne '${cosmic_bg_backgrounds_RON}' > $out/share/cosmic/com.system76.CosmicBackground/v1/backgrounds
        '';
    }))

    # Override panel defaults
    (pkgs.cosmic-panel.overrideAttrs (oldAttrs: {
      postInstall =
        oldAttrs.postInstall or ""
        + ''
          mkdir -p $out/share/cosmic/com.system76.CosmicPanel.Dock/v1
          mkdir -p $out/share/cosmic/com.system76.CosmicPanel.Panel/v1
          # Override default dock config
          echo -ne '${cosmic_panel_dock_autohide_RON}' > $out/share/cosmic/com.system76.CosmicPanel.Dock/v1/autohide
          echo -ne '${cosmic_panel_dock_anchor_gap_RON}' > $out/share/cosmic/com.system76.CosmicPanel.Dock/v1/anchor_gap
          echo -ne '${cosmic_panel_dock_margin_RON}' > $out/share/cosmic/com.system76.CosmicPanel.Dock/v1/margin
          echo -ne '${cosmic_panel_dock_border_radius_RON}' > $out/share/cosmic/com.system76.CosmicPanel.Dock/v1/border_radius
          echo -ne '${cosmic_panel_dock_plugins_center_RON}' > $out/share/cosmic/com.system76.CosmicPanel.Dock/v1/plugins_center
          echo -ne '${cosmic_panel_dock_plugins_wings_RON}' > $out/share/cosmic/com.system76.CosmicPanel.Dock/v1/plugins_wings
          # Override default panel config
          echo -ne '${cosmic_panel_panel_plugins_center_RON}' > $out/share/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_center
          echo -ne '${cosmic_panel_panel_plugins_wings_RON}' > $out/share/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings
        '';
    }))

    # Override idle defaults
    (pkgs.cosmic-idle.overrideAttrs (oldAttrs: {
      postInstall =
        oldAttrs.postInstall or ""
        + ''
          mkdir -p $out/share/cosmic/com.system76.CosmicIdle/v1
          # Override default idle config
          echo -ne '${cosmic_idle_screen_off_time_RON}' > $out/share/cosmic/com.system76.CosmicIdle/v1/screen_off_time
          echo -ne '${cosmic_idle_suspend_on_ac_time_RON}' > $out/share/cosmic/com.system76.CosmicIdle/v1/suspend_on_ac_time
          echo -ne '${cosmic_idle_suspend_on_battery_time_RON}' > $out/share/cosmic/com.system76.CosmicIdle/v1/suspend_on_battery_time
        '';
    }))

    # TODO: Add cosmic-settings (or other?) override to set some default settings for panel, dock, applist, etc.
  ];

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
