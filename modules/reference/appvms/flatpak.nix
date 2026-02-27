# SPDX-FileCopyrightText: 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# Flatpak App Store VM
#
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ghaf.reference.appvms.flatpak;

  runAppCenter = pkgs.writeShellApplication {
    name = "run-flatpak";
    runtimeInputs = [
      pkgs.systemd
      pkgs.cosmic-store
    ];
    text = ''
      export XDG_SESSION_TYPE="wayland"
      export DISPLAY=":0"
      export PATH=/run/wrappers/bin:/run/current-system/sw/bin

      systemctl --user start run-xwayland
      systemctl --user set-environment WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
      systemctl --user restart xdg-desktop-portal-gtk.service

      RUST_LOG=info cosmic-store
    '';
  };

  runAppCenterApp = pkgs.writeShellApplication {
    name = "run-flatpak-app";
    runtimeInputs = [
      pkgs.systemd
      pkgs.gnused
      pkgs.flatpak
    ];
    text = ''
      export XDG_SESSION_TYPE="wayland"
      export WAYLAND_DISPLAY="wayland-1"
      export DISPLAY=":0"
      export PATH=/run/wrappers/bin:/run/current-system/sw/bin

      systemctl --user start run-xwayland
      systemctl --user set-environment WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
      systemctl --user restart xdg-desktop-portal-gtk.service
      # GIVC does not support passing simple arguments to apps,
      # so we pass a fake URL, which we then trim here
      app="$1"
      app="''${app#http://}"

      ${config.ghaf.givc.appPrefix}/run-waypipe \
        ${lib.getExe pkgs.flatpak} run "$app"
    '';
  };

  createAppList = pkgs.writeShellApplication {
    name = "create-flatpak-app-list";
    text = ''
      APP_DIR="/var/lib/flatpak/app"
      OUTPUT_FILE="/home/${config.ghaf.users.appUser.name}/Unsafe share/.apps"
      UNSAFE_SHARE_DIR="/home/${config.ghaf.users.appUser.name}/Unsafe share/.flatpak-share"
      DESKTOP_DIR="$UNSAFE_SHARE_DIR/share/applications"
      EXPORTS_DIR="/var/lib/flatpak/exports/share"

      # Ensure directory exists
      if [[ ! -d "$APP_DIR" ]]; then
          echo "Directory $APP_DIR does not exist."
          exit 1
      fi

      # List only directories and write their names to the output file
      find "$APP_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort > "$OUTPUT_FILE"

      echo "App list written to $OUTPUT_FILE"

      rm -rf "$UNSAFE_SHARE_DIR"
      mkdir -p "$UNSAFE_SHARE_DIR"

      # Copy flatpak export shares to the Unsafe share,
      # so gui-vm can see the .desktop files and icons for installed flatpak apps
      cp -rL "$EXPORTS_DIR" "$UNSAFE_SHARE_DIR" \
        && echo "Copied flatpak 'exports/share' to $UNSAFE_SHARE_DIR" \
        || echo "Failed to copy flatpak desktop entries to $UNSAFE_SHARE_DIR"

      # Fix desktop entry Exec fields to run from gui-vm
      if [[ -d "$DESKTOP_DIR" ]]; then
        for desktop in "$DESKTOP_DIR"/*.desktop; do
          # Skip if no .desktop files exist
          [[ -e "$desktop" ]] || continue

          # Extract the base name (APP-ID) without .desktop
          app_id="$(basename "$desktop" .desktop)"

          # Replace the Exec line
          # -i ensures in-place edit
          # Only replace lines that start with Exec=
          sed -i "s|^Exec=.*|Exec=ghaf-open flatpak-run -- http://$app_id|" "$desktop"
        done
        echo "Updated Exec lines in .desktop files under $DESKTOP_DIR"
      else
        echo "No desktop files found in $DESKTOP_DIR"
      fi
    '';
  };

  # XDG item for URL
  xdgUrlFlatpakItem = pkgs.makeDesktopItem {
    name = "ghaf-url-xdg-flatpak";
    desktopName = "Ghaf URL Opener";
    exec = "${urlScript}/bin/xdgflatpakurl %u";
    mimeTypes = [
      "text/html"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    noDisplay = true;
  };

  urlScript = pkgs.writeShellApplication {
    name = "xdgflatpakurl";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      url="$1"

      if [[ -z "$url" ]]; then
        echo "xdgflatpakurl: No URL provided"
        exit 1
      fi

      echo "XDG open url: $url"

      # Function to check if a binary exists in the givc app prefix
      search_bin() {
        [ -x "${config.ghaf.givc.appPrefix}/$1" ]
      }

      start_browser() {
        ${config.ghaf.givc.appPrefix}/run-waypipe "${config.ghaf.givc.appPrefix}/$1" \
          --disable-gpu --enable-features=UseOzonePlatform --ozone-platform=wayland "$url"
      }

      start_flatpak_browser() {

        local browsers="com.google.Chrome org.chromium.Chromium org.mozilla.firefox com.brave.Browser com.opera.Opera"
        local browser=""

        for app in $browsers; do
            if ${lib.getExe pkgs.flatpak} info --system "$app" 1>/dev/null 2>&1; then
                browser="$app"
                break
            fi
        done
        if [[ -z "$browser" ]]; then
            return 1
        fi
        if [ "$browser" = "org.mozilla.firefox" ]; then
          options="--new-window"
        else
          options="--disable-gpu --enable-features=UseOzonePlatform --ozone-platform=wayland"
        fi

        XDG_SESSION_TYPE="wayland" WAYLAND_DISPLAY="wayland-1" DISPLAY=":0" ${config.ghaf.givc.appPrefix}/run-waypipe \
              ${lib.getExe pkgs.flatpak} run "$browser" \
                "$options" "$url"
        return 0
      }

      # Attempt to open URL in an App Store browser
      if ! start_flatpak_browser; then

        echo "No supported App Store browser found, trying local browsers..."
        # Try to detect locally installed available browsers
        if search_bin google-chrome-stable; then
          echo "Google Chrome detected, opening URL locally."
          start_browser google-chrome-stable
        elif search_bin chromium; then
          echo "Chromium detected, opening URL locally."
          start_browser chromium
        else
          echo "No supported browser found on the system"
          # Assignment in order to avoid build warning
          if ${lib.getExe pkgs.yad} --title="No App Store Browser Found" \
              --image=dialog-warning \
              --width=500 \
              --text="<b>No browser installed through App Store was found in this VM.</b>\n\nFor optimal security and functionality, please install a browser:\n  • Firefox\n  • Chrome\n  • Brave\n  • Chromium\n\nInstall from the App Store and try again.\n\n<i>Alternatively, continue with the standard browser (may malfunction).</i>" \
              --button="Exit:0" \
              --button="Continue:1" \
              --button-layout=spread \
              --center;
          then # user chose to exit
            exit 1
          else # user chose to continue
            ${config.ghaf.givc.appPrefix}/xdg-open-ghaf url "$url"
          fi
        fi
      fi

    '';
  };
in
{
  _file = ./flatpak.nix;

  options.ghaf.reference.appvms.flatpak = {
    enable = lib.mkEnableOption "Flatpak App Store VM";
  };

  # Only configure when both enabled AND laptop-x86 profile is available
  # (reference appvms use laptop-x86.mkAppVm which doesn't exist on other profiles like Orin)
  config = lib.mkIf (cfg.enable && config.ghaf.profiles.laptop-x86.enable or false) {
    # DRY: Only enable and evaluatedConfig at host level.
    # All values (name, mem, borderColor, applications, vtpm) are derived from vmDef.
    ghaf.virtualization.microvm.appvm.vms.flatpak = {
      enable = lib.mkDefault true;

      evaluatedConfig = config.ghaf.profiles.laptop-x86.mkAppVm {
        name = "flatpak";
        mem = 6144;
        vcpu = 4;
        bootPriority = "low";
        borderColor = "#FFA500";
        ghafAudio.enable = lib.mkDefault true;
        vtpm.enable = lib.mkDefault true;
        applications = [
          {
            name = "com.system76.CosmicStore";
            desktopName = "App Store";
            categories = [
              "System"
              "PackageManager"
            ];
            description = "App Store to install Flatpak applications";
            packages = [
              pkgs.cosmic-store
              runAppCenter
            ];
            icon = "rocs";
            exec = "run-flatpak";
          }
          {
            name = "flatpak-run";
            desktopName = "Flatpak Run";
            description = "Run an installed Flatpak application by its app ID";
            packages = [
              pkgs.flatpak
              runAppCenterApp
            ];
            givcArgs = [ "url" ];
            exec = "run-flatpak-app";
            noDisplay = true;
          }
        ];
        extraModules = [
          {
            services = {
              flatpak.enable = lib.mkDefault true;
              packagekit.enable = lib.mkDefault true;
            };
            security = {
              rtkit.enable = lib.mkForce true;
              polkit = {
                enable = lib.mkDefault true;
                debug = true;
                extraConfig = ''
                    polkit.addRule(function(action, subject) {
                      if (action.id.startsWith("org.freedesktop.Flatpak.") &&
                          subject.user == "${config.ghaf.users.appUser.name}") {
                            return polkit.Result.YES;
                      }
                  });
                '';
              };
            };
            ghaf = {
              xdgitems.enable = lib.mkDefault true;

              users.appUser.extraGroups = [
                "flatpak"
              ];

              # For persistant storage
              storagevm = {
                directories = [
                  {
                    directory = "/var/lib/flatpak";
                    user = "root";
                    group = "root";
                    mode = "0755";
                  }
                ];
                maximumSize = 200 * 1024; # 200 GB space allocated
                mountOptions = [
                  "rw"
                  "nodev"
                  "nosuid"
                  "exec" # For Bubblewrap sandbox to execute the file
                ];
              };
            };

            environment.systemPackages = [
              xdgUrlFlatpakItem
            ];

            xdg = {
              portal = {
                xdgOpenUsePortal = true;
                enable = lib.mkDefault true;
                extraPortals = [
                  pkgs.xdg-desktop-portal-cosmic
                  pkgs.xdg-desktop-portal-gtk
                ];
                config = {
                  common = {
                    default = [
                      "gtk"
                    ];
                  };
                };
              };
              mime = {
                enable = lib.mkDefault true;
                defaultApplications = {
                  "text/html" = lib.mkForce "ghaf-url-xdg-flatpak.desktop";
                  "x-scheme-handler/http" = lib.mkForce "ghaf-url-xdg-flatpak.desktop";
                  "x-scheme-handler/https" = lib.mkForce "ghaf-url-xdg-flatpak.desktop";
                };
              };
            };

            programs.dconf.enable = lib.mkDefault true;

            systemd = {
              services = {
                flatpak-repo = {
                  description = "Add Flathub system-wide Flatpak repository";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "network-online.target" ];
                  requires = [ "network-online.target" ];
                  serviceConfig = {
                    Type = "oneshot";
                    Restart = "on-failure";
                    RestartSec = "2s";
                  };
                  path = [ pkgs.flatpak ];
                  script = ''
                    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
                    flatpak update --appstream --noninteractive
                  '';
                };
                installed-apps = {
                  description = "Update list of installed apps";
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig.ExecStart = "${lib.getExe createAppList}";
                };
              };

              paths.installed-apps = {
                description = "Watch for flatpak app changes";
                wantedBy = [ "multi-user.target" ];
                pathConfig.PathModified = "/var/lib/flatpak/app";
              };

              user.services."run-xwayland" = {
                description = "Grants rootless Xwayland integration to any Wayland compositor";
                serviceConfig = {
                  ExecStart = "${config.ghaf.givc.appPrefix}/run-waypipe  ${lib.getExe pkgs.xwayland-satellite}";
                  Restart = "on-failure";
                  RestartSec = "2s";
                };
              };
            };
          }
        ];
      };
    };
  };
}
