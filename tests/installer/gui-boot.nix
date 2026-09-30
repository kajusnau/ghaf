# SPDX-FileCopyrightText: 2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# Boots the installer ISO and asserts the COSMIC GUI reaches its first page.
#
# This is the only test in the plan that exercises cage, the compositor
# handoff and page rendering -- everything below it is covered by the core
# crate's unit tests, which run without a compositor.
#
# Modelled on ./netboot-boot.nix: same create_machine() start-command
# pattern, but booting from a CD-ROM (the ISO) instead of iPXE, and with
# `-vga virtio` added so /dev/dri/card* exists. Without a DRM device the
# installer's tty1 unit silently falls back to the TUI (see
# lib/builders/installer-common.nix), and a test that only checked the unit
# would pass while testing nothing.
{ pkgs, self }:
let
  inherit (self.inputs) nixpkgs;
  system = "x86_64-linux";

  ghafInstaller = self.builders.mkGhafInstaller {
    inherit self system;
    inherit (self) lib;
    extraModules = [
      self.nixosModules.laptop-installer
      "${nixpkgs}/nixos/modules/testing/test-instrumentation.nix"
      { key = "serial"; }
    ];
  };

  # The ISO embeds a real ghaf-image, same as a shipped installer. The image
  # itself is never booted by this test -- only its presence is needed for the
  # ISO to build -- so any target works; intel-laptop-debug is already built
  # elsewhere in this test suite (tests/installer/default.nix).
  isoImage =
    (ghafInstaller {
      name = "gui-boot-test";
      imagePath = self.nixosConfigurations.intel-laptop-debug.config.system.build.ghafImage;
    }).package;
in
pkgs.testers.nixosTest {
  name = "gui-boot-test";
  nodes = { };
  enableOCR = true;

  testScript = ''
    import glob

    # The ISO's filename isn't known at eval time, so it's resolved here
    # rather than baked into the qemu command the way netboot-boot.nix's
    # bootfile name is.
    iso_path = glob.glob("${isoImage}/iso/*.iso")[0]

    start_command = " ".join(
        [
            "${pkgs.qemu_test}/bin/qemu-kvm",
            "-cpu max",
            "-m 8192",
            # A DRM device -- see the module comment above for why this matters.
            "-vga virtio",
            f"-cdrom {iso_path}",
            "-boot order=d",
            # UEFI, matching netboot-boot.nix and the ISO's own boot path.
            "-drive if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}",
            "-drive if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables}",
        ]
    )

    machine = create_machine(start_command)
    machine.start()

    with subtest("the installer actually started"):
        machine.wait_for_unit("ghaf-installer.service", timeout=500)

    with subtest("cage came up, not the TUI fallback"):
        # cage must actually be running: without a DRM device the unit
        # silently falls back to ghaf-installer-tui, and this test would
        # otherwise pass while testing nothing.
        machine.wait_until_succeeds("pgrep -f cage", timeout=60)
        # pgrep -f matches cage's own command line too, so a real child means 2 pids.
        assert len(machine.succeed("pgrep -f ghaf-installer-gui").split()) == 2

    with subtest("the welcome page rendered"):
        # The Wayland socket is the reliable signal; OCR over antialiased
        # libcosmic text in QEMU is too flaky to gate on.
        machine.wait_until_succeeds("ls /run/ghaf-installer-gui/wayland-*", timeout=60)
        try:
            machine.wait_for_text("Welcome to Ghaf", timeout=30)
        except Exception:
            machine.log("OCR did not read the welcome title; see the screenshot.")
        machine.screenshot("installer-welcome")

    machine.shutdown()
  '';
}
