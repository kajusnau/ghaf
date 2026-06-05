# SPDX-FileCopyrightText: 2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{
  lib,
  fetchFromGitHub,
  python3Packages,
  meson,
  ninja,
  gettext,
  wrapGAppsHook3,
  gobject-introspection,
  gtk3,
  xapp,
  glib,
  pkg-config,
  pam,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "fingwit";
  version = "1.0.8";
  format = "other";

  src = fetchFromGitHub {
    owner = "xapp-project";
    repo = "fingwit";
    tag = finalAttrs.version;
    hash = "sha256-Pyyl79cwKHAfir8uQ4nzjcxc6yz50EbX6VCJDBNLJTs=";
  };

  nativeBuildInputs = [
    meson
    ninja
    gettext
    wrapGAppsHook3
    gobject-introspection
    pkg-config
  ];

  buildInputs = [
    gtk3
    xapp
    glib
    pam
  ];

  dependencies = with python3Packages; [
    pygobject3
    setproctitle
    python-pam
  ];

  patches = [ ./0001-check-all-pam-services-for-fprintd.patch ];

  postPatch = ''
    # /usr/bin/env python3 is not resolvable during meson install in the Nix sandbox;
    # replace the install script with a shell no-op and compile schemas in postInstall
    printf '#!/bin/sh\n' > data/meson_install_schemas.py
  '';

  postInstall = ''
    substituteInPlace $out/bin/fingwit \
      --replace-fail '/usr/share/fingwit/fingwit.ui' "$out/share/fingwit/fingwit.ui" \
      --replace-fail '/usr/share/fingwit/fingwit.css' "$out/share/fingwit/fingwit.css" \
      --replace-fail '/usr/share/locale' "$out/share/locale"
    glib-compile-schemas $out/share/glib-2.0/schemas
  '';

  meta = {
    description = "Fingerprint configuration tool (XApp)";
    homepage = "https://github.com/xapp-project/fingwit";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "fingwit";
  };
})
