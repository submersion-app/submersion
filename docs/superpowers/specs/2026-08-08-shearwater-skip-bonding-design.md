# Skip Android BLE bonding for Shearwater devices

Issue: #910 (follow-up to #766, PR #909)
Date: 2026-08-08

## Problem

The Android BLE download path (`DiveComputerHostApiImpl.performBleDownload`)
calls `BleIoStream.ensureBonded()` unconditionally after connecting, creating
an Android bond with the dive computer on the first download. Shearwater's
BLE protocol has no encrypted characteristics and Shearwater Cloud connects
without bonding; once Submersion holds the bond, Shearwater Cloud cannot
connect until the user unpairs the computer in Android Bluetooth settings.

## Decision

Gate the proactive bond on the libdc vendor string: skip `ensureBonded()` for
`Shearwater`, keep it for every other vendor.

## Design

- New pure-Kotlin `BondPolicy` object in the plugin's Android source set with
  a single function `requiresProactiveBond(vendor: String): Boolean`.
  Vendor comparison is case-insensitive; every vendor except Shearwater
  returns true.
- `performBleDownload` consults `BondPolicy` before calling `ensureBonded()`
  and logs when it skips, so field logs show which path ran.
- No change to `BleIoStream` (transport stays vendor-agnostic), the
  stale-bond repair paths (GATT status 5 → `removeBond` + retry), or existing
  bonds (`ensureBonded()` already returns immediately when bonded — this
  change only stops creating new bonds).

## Alternatives considered

- Gate inside `BleIoStream.ensureBonded()`: mixes vendor policy into the
  vendor-agnostic transport layer; rejected.
- Constant set inside `DiveComputerHostApiImpl`: not testable from plain JVM
  unit tests because that class is saturated with Android framework types;
  rejected.
- Also remove an existing bond for Shearwater devices: more invasive, races
  the Bluetooth stack (see `BOND_REPAIR_SETTLE_MS`), and the user can unpair
  once themselves; out of scope.

## Safety

If a Shearwater unit ever did require encryption, the Android BLE stack
pairs transparently during the first encrypted GATT operation (documented on
`connectAndDiscover()`), so skipping the proactive bond cannot strand a
download.

## Testing

JVM unit test `BondPolicyTest` alongside the existing
`SerialReadBufferTest`: Shearwater (any case) is exempt, other vendors and
the empty string require bonding. The call-site wiring is exercised on
hardware only — validation on a real Petrel 3 / Nerd 2 (downloads work
without bond; Shearwater Cloud connects afterward) is tracked in #910.
