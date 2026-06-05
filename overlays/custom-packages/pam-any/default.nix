# SPDX-FileCopyrightText: 2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ prev }:
prev.pam-any.overrideAttrs (oldAttrs: {
  # Don't install default cosmic themes and layouts
  postPatch = oldAttrs.postPatch or "" + ''
    substituteInPlace src/lib.rs \
      --replace-fail 'str: self.format_msg(prompt)' 'str: prompt'
  '';
})
