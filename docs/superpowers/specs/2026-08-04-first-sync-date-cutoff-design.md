# First-Sync Date Cutoff for Dive Computer Downloads

**Date:** 2026-08-04
**Status:** Approved (revised — see Revision Note)

## Revision Note

The originally approved design assumed the Shearwater driver delivers dives
newest-first and proposed an app-side early-stop of the transfer. That premise
was wrong: our vendored fork ships **oldest-first delivery** on main (the
issue #480 fix; the #621 revert of it was retracted after hardware testing
exonerated the driver). App-side early-stop therefore cannot shorten a
Shearwater first download — the old dives arrive first.

The revised Tier 2 below replaces early-stop with a **fingerprint timestamp
floor**: a small fork patch plus app-side fingerprint synthesis, exploiting
the fact that the Shearwater petrel fingerprint *is* the dive start timestamp.
Tier 1 is unchanged from the original design.

## Problem

A user who imports their dive history from another logbook (e.g., Subsurface
UDDF/XML export) and then connects their dive computer gets a full download of
every dive on the device. The incremental-download mechanism relies on
`lastDiveFingerprint` — bytes captured from a previously *downloaded* dive —
which a file import cannot provide. libdivecomputer has no "download since
date" concept; the fingerprint is the only stop mechanism.

Today the consequences are:

- The first connect transfers every dive on the device (slow over BLE for
  hundreds of dives).
- The review step lists hundreds of matched duplicates.
- If the user cancels at the download step out of confusion, the fingerprint
  is never persisted, and the full download recurs on every connect.

Duplicate protection already works: the download matcher
(`findMatchingDiveWithScore`, SQL ±5 min gate) matches downloaded dives
against imported ones and the wizard defaults them to skip/consolidate. On
normal wizard completion the fingerprint is advanced from **all** downloaded
dives (`dive_computer_adapter.dart`, `_updateComputerAfterImport`), so the
flow self-heals after one full run-through. The problem is the cost and
confusion of that first run.

## Goals

- After a file import, the first computer connect should download only recent
  dives, not the whole device.
- Seed the fingerprint so all later syncs are incremental.
- No changes to native protocol request *ordering* or request *types* (the
  #621 lesson: hardware-unvalidated request-pattern changes are dangerous).
  Issuing *fewer* of the same requests is acceptable.

## Non-Goals

- Reordering the profile-download loop or the manifest walk.
- Changing duplicate-matching or consolidation behavior.
- Importing fingerprints from Subsurface data (not present in its exports).

## Key Driver Facts (verified in the vendored fork)

In `src/shearwater_petrel.c`:

- Manifest records are 32 bytes, ordered newest→oldest. Offset +0: header
  (`0xA5C4` valid, `0x5A23` deleted); offset +4: 4-byte fingerprint field;
  offset +20: dive data address.
- The dive callback passes `buf + 12` of the dive data as the fingerprint,
  and `shearwater_predator_parser_get_datetime` reads the dive start time as
  `array_uint32_be(data + opening[0] + 12)` — i.e., **the petrel fingerprint
  is the dive start timestamp**, a big-endian u32 ticks value, mirrored at
  manifest offset +4.
- The fingerprint stop-check is an exact `memcmp` during the manifest walk.
- The profile loop walks the manifest in reverse: **delivery is
  oldest-first**.
- Ticks cross the platform boundary as `dc_datetime_gmtime(ticks)` broken
  into Y/M/D h:m:s fields, reassembled in Dart by `parsedDiveToDownloaded` as
  `DateTime.utc(...)` — so `startTime` (UTC-wallclock) ↔ ticks round-trips
  exactly via `millisecondsSinceEpoch ~/ 1000`.
- The fingerprint travels app→native as a hex string decoded to bytes and
  passed to `dc_device_set_fingerprint` identically on every platform. No
  pigeon API change is needed to deliver a synthesized fingerprint.

## Design Overview

Two tiers, sharing one cutoff concept:

- **Tier 1 (all backends):** an import-stage date filter. The full download
  still runs, but dives at-or-before the cutoff are auto-marked skip and
  collapsed in the review list.
- **Tier 2 (Shearwater petrel family):** a fingerprint **timestamp floor**.
  The app synthesizes a 4-byte fingerprint from the cutoff date and passes it
  through the existing fingerprint parameter. A fork patch makes the petrel
  driver treat a *non-matching* fingerprint as a timestamp floor: profile
  fetches are simply not issued for manifest records whose timestamp field is
  at-or-before it. Old dives are never transferred.

### Cutoff semantics

- Active only when the selected computer has **no** `lastDiveFingerprint`,
  the active diver's log has at least one dive, and the full-download path
  (`forceFullDownload`) was not chosen.
- Default: start time of the newest dive in the active diver's log
  (diverId-scoped). Editable via a date picker; a user-picked date becomes
  start-of-day (00:00) so the picked day's dives are included.
- Skip condition everywhere: `dive.startTime <= cutoff` (strictly-newer dives
  are fetched/imported), matching existing fingerprint "dives after"
  semantics.
- Ticks conversion is wallclock-based: `DateTime.utc(y, m, d, h, min, s)` of
  the cutoff's wallclock fields, then `millisecondsSinceEpoch ~/ 1000` —
  robust regardless of the source `DateTime`'s `isUtc` flag.

### Tier 2 mechanics

**Fork patch (`shearwater_petrel.c`, dive-download loop only):**

- Track whether the manifest walk's exact fingerprint `memcmp` matched
  (`found` flag).
- After manifest collection, when `!found` and the fingerprint is non-zero:
  treat `array_uint32_be(device->fingerprint)` as a floor; pre-scan the
  collected records and subtract skippable ones (valid header, ticks <=
  floor) from the progress maximum; in the profile loop, `continue` past
  those records without issuing their download request.
- When the fingerprint matched exactly (normal incremental case), behavior is
  bit-for-bit identical to today — the manifest is already truncated at the
  match and the floor logic is gated off by `found`.
- Unset fingerprint (all zeros) → floor gated off → identical to today.
- No request ordering or request types change; the patch only skips issuing
  some dive-fetch requests. Mirrored as a `patches/` diff per house style.

**App-side synthesis (`DownloadNotifier.startDownload`):**

- When "new dives only" applies and `_computer?.lastDiveFingerprint` is null
  and a cutoff is set and the device's recognized model is a Shearwater
  non-Predator product: fingerprint = 8-char hex of the cutoff's wallclock
  ticks (big-endian u32).
- Any other backend: no synthesized fingerprint (Tier 1 only). A wrong-size
  fingerprint is never sent to non-Shearwater drivers.

**Fingerprint seeding after import:** unchanged code. On completion,
`_updateComputerAfterImport` stores the newest downloaded dive's *real*
fingerprint (which for petrel is its timestamp) — a correct high-water mark.
With zero new dives the download completes empty, nothing is stored, and the
next connect synthesizes again — cheap, since only the manifest transfers.

## UX

**Download step (`DownloadStepWidget`):**

- When the cutoff condition holds, the step shows a brief pre-download prompt
  instead of auto-starting: "Only download dives after 12 Jun 2026" (tappable
  date row) with actions "Download new dives" (primary) and "Download all
  dives". Choosing either starts the download; the chosen cutoff (or null) is
  set on the notifier after `reset()`, exactly like `forceFullDownload`.
- When the condition does not hold (fingerprint present, empty log, or
  forced full download), the step auto-starts as today.

**Review step:** dives at-or-before the cutoff are auto-marked skip and
collapsed into one expandable summary row: "N older dives skipped — already
in your log". Only genuinely new dives are listed individually. (On
Shearwater this row rarely appears, since old dives are not transferred at
all.)

**Recovery path:** "Download all dives" (and the existing re-import-all flow)
remains the way to fetch older dives later.

## Components

- **Fork:** `third_party/libdivecomputer/src/shearwater_petrel.c` patch +
  native test in the existing mocked-transport harness
  (`test/native/test_shearwater_petrel_foreach.c`) + `patches/` mirror.
- **`first_sync_cutoff.dart`** (new, `dive_computer/domain/services/`):
  `supportsTimestampFingerprintFloor(vendor, product)` (Shearwater,
  non-Predator) and `synthesizeShearwaterFingerprint(DateTime)` (wallclock
  ticks → 8-char hex).
- **Dive repository:** `getNewestDiveDateTime({required String diverId})` +
  a `firstSyncCutoffDefaultProvider` reading `currentDiverIdProvider`.
- **`DownloadState`/`DownloadNotifier`:** new `sinceCutoff` field +
  `setSinceCutoff`; synthesis logic in `startDownload`; `reset()` clears it.
- **`DiveComputerAdapter`:** new `setSinceCutoff(DateTime?)` (called from
  `_captureAndAdvance` in `dc_adapter_steps.dart` off `DownloadState`);
  populates `EntityGroup.autoSkipIndices` for below-cutoff dives.
- **`EntityGroup`** (`import_bundle.dart`): new optional
  `autoSkipIndices: Set<int>?`; the wizard provider's pre-selection loop
  (alongside `matchedExistingSource`) marks them `DuplicateAction.skip`.
- **Review step UI:** collapsed auto-skipped summary row.

## Edge Cases

- Empty log or fingerprint present: no prompt, identical to today.
- Cutoff edited far into the past: more dives download; all still subject to
  normal duplicate matching.
- Device clock reset backwards (newer dives with older ticks): such dives
  would be skipped by the floor; recoverable via "Download all dives".
  Accepted risk, same class as fingerprint resume today.
- Non-Shearwater backends: never receive a synthesized fingerprint; Tier 1
  auto-skip still trims the review list.
- Teric local-time offsets: the ticks field itself is wallclock and
  round-trips through `DateTime.utc` regardless of the device's UTC-offset
  metadata; synthesis uses the same convention.
- User cancels mid-download: existing cancel semantics untouched
  (fingerprint advances only through processed dives).

## Testing

- **Native (mocked-transport harness, TDD):** floor skips older records and
  progress completes; exact-match behavior unchanged; zero fingerprint
  downloads all; deleted records interact correctly with the floor pre-scan.
  Configure CMake with no build type (Release strips assert-based tests).
- **Unit:** synthesis hex encoding + wallclock-ticks conversion (isUtc and
  local inputs); family gate matrix; newest-dive query diverId scoping.
- **Notifier:** synthesized fingerprint passed when conditions hold; stored
  fingerprint always wins; no synthesis for unsupported vendors or when
  cutoff null; reset clears cutoff.
- **Adapter/provider:** `autoSkipIndices` computed from cutoff; pre-selection
  marks them skip; import counts report them as skipped.
- **Widget:** prompt visibility rules; date picker roundtrip; summary row.
- **l10n:** new keys in all 11 locales.
- **Hardware smoke (release gate):** one real-Shearwater download with a
  synthesized fingerprint (post-import scenario) and one normal incremental
  download, per the #621 convention. Fork commits must be pushed to
  `submersion-app/libdivecomputer` before the app repo push (CI submodule
  checkout trap).
