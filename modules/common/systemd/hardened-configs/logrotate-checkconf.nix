# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{
  PrivateNetwork = true;
  IPAccounting = true;
  IPAddressDeny = "any";
  ProtectHome = true;
  ProtectSystem = "strict";
  ProtectProc = "noaccess";
  PrivateTmp = true;
  PrivateMounts = true;
  ProcSubset = "pid";
  PrivateUsers = true;
  DynamicUser = false;
  PrivateDevices = true;
  ProtectKernelTunables = true;
  ProtectKernelModules = true;
  ProtectKernelLogs = true;
  Delegate = false;
  KeyringMode = "private";
  NoNewPrivileges = true;
  UMask = 77;
  ProtectHostname = true;
  ProtectClock = true;
  ProtectControlGroups = true;
  RestrictNamespaces = true;
  LockPersonality = true;
  MemoryDenyWriteExecute = true;
  RestrictRealtime = true;
  RestrictSUIDSGID = true;
  RemoveIPC = true;
  SystemCallArchitectures = "native";
  NotifyAccess = "main";
  RestrictAddressFamilies = "none";
  CapabilityBoundingSet = "";

  SystemCallFilter = [
    "~@swap"
    "~@resources"
    "~@reboot"
    "~@raw-io"
    "~@privileged"
    "~@obsolete"
    "~@mount"
    "~@module"
    "~@debug"
    "~@cpu-emulation"
    "~@clock"
  ];
}
