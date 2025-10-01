# Copyright 2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ prev }:
prev.google-chrome.overrideAttrs (oldAttrs: {
  version = "138.0.7204.183";
  src = prev.fetchurl {
    inherit (oldAttrs.src) url;
    hash = "sha256-GxdfHU6pskOL0i/rmN7kwGsuLYTotL1mEw6RV7qfl50=";
  };
})
