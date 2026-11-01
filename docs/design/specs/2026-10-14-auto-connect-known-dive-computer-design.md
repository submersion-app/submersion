# Auto-Connect for Known Dive Computers - Design

**Date:** 2026-10-14
**Status:** Draft
**Phase:** TBD

---

## Overview

Today, downloading dives from a Bluetooth dive computer always starts with a
manual tap: open the Transfer tab, go to the Dive Computers section, tap a
known computer, and tap download (or run the "Connect new computer" wizard
for a first-time pairing). Divers who come out of the water with their known
computer already paired still have to find and tap through this flow by hand.

This design adds a passive, automatic path: while the diver is looking at the
Dive Computers section, the app scans in the background of that screen and,
if a computer it already knows is reachable over Bluetooth, connects and
starts the download on its own.

### Scope

**In scope:**

- Auto-scan active only while the Dive Computers section of the Transfer tab
  is the visible screen (`_ComputersSectionContent`,
  `lib/features/transfer/presentation/pages/transfer_page.dart:615`).
- Auto-connect and auto-download when a scan match is found for an existing
  `DiveComputer` record.
- A global on/off switch for this behavior, presented in the Dive Computers
  section.
- A per-device opt-out, so one known computer can be excluded from
  auto-download even while the global switch is on.
- Visible feedback while scanning and when an automatic download starts.
- Coordination with the existing manual flows (discovery wizard, manual
  download) so the two never fight over the same connection.

**Out of scope (see "Rejected / deferred" below):**

- Any form of OS-level background execution (app suspended, backgrounded
  outside this screen, or terminated). This was the subject of the first
  draft of this design and has been dropped in favor of the
  screen-scoped approach described here.
- Windows and Linux, where BLE dive-computer import is still a stub
  (`docs/design/specs/2026-02-24-platform-parity-design.md`). This design
  applies to Android, iOS and macOS, where BLE import is already "Full".

---

## Current State (reference)

- **Known devices:** `DiveComputer` entity
  (`lib/features/dive_log/domain/entities/dive_computer.dart`) already
  stores `bluetoothAddress`, `manufacturer`, `model`, etc., backed by Drift
  tables in `lib/core/database/tables/dive_computer_connection_tables.dart`.
- **Address-rotation matching already solved:** computers whose BLE address
  changes between sessions (e.g. the Ratio iX3M, issue #1423) are already
  re-identified by `sameModelFallbackDevice()` in
  `lib/features/dive_computer/domain/services/known_computer_reacquisition.dart`.
  Auto-connect reuses this matcher rather than inventing new matching logic.
- **Scan and download state machines:** `DiscoveryNotifier`
  (`lib/features/dive_computer/presentation/providers/discovery_providers.dart`)
  and `DownloadNotifier`
  (`lib/features/dive_computer/presentation/providers/download_providers.dart`)
  already do the scanning and downloading; today both are triggered only by
  a manual tap.
- **No existing permissions gap:** BLE scan/connect permissions are already
  requested the first time a computer is paired through the discovery
  wizard (`/dive-computers/discover`). Scoping auto-scan to a screen the
  user navigated into after that point needs no new permission request and
  no manifest/Info.plist change.

---

## Behavior

1. The diver opens Transfer -> Dive Computers
   (`_ComputersSectionContent`).
2. If the global auto-scan switch is on, a passive BLE scan starts
   automatically - no tap needed. A small inline indicator shows that a scan
   is running (distinct from the existing "Connect new computer" wizard,
   which keeps its own explicit, user-initiated scan). With no known
   computer that can be auto-downloaded there is no scan at all, so a
   diver who has none is never asked for Bluetooth access here.
3. Each scan result is matched against the stored `DiveComputer` records
   using the existing reacquisition matcher. A match that belongs to a
   computer with auto-download opted out is ignored for this purpose (it
   still shows up for manual download as today).
4. On a match that is not opted out: open that computer's download page
   automatically (`/dive-computers/<id>/download`, the page its own
   "Download dives" button opens), and surface a snackbar/toast
   ("Downloading from <computer name>...") so the action is never silent.
   Calling `DownloadNotifier.startDownload()` directly is not enough: it
   only collects the dives, while importing them and updating the dive
   count, last download time, resume fingerprint and connection record all
   happen in that page's import steps. The page also asks for a date
   cutoff on a computer's first download, as it does for a manual one.
   The passive scan pauses before the page opens, so it neither competes
   with the page's own scan nor opens a second page.
5. If more than one known, non-opted-out computer is reachable at once,
   their pages open one at a time, in the order the devices were
   discovered: the next one opens once the diver comes back from the
   previous one. A computer already opened is not reopened during the same
   visit to the section.
6. If a manual download or the manual discovery wizard is already in
   progress when a match would otherwise trigger, the automatic trigger is
   suppressed for that cycle rather than interrupting the manual action.
7. Leaving the Dive Computers section (navigating elsewhere in the app)
   stops the passive scan.

---

## Settings

- **Global switch:** a toggle in the Dive Computers section (e.g. in its
  header or an overflow menu), persisted the same way other transfer-related
  preferences are stored. Off by default or on by default is an open
  product decision (see below) - either way, this is one new boolean
  setting.
- **Per-device opt-out:** one boolean per `DiveComputer` record (schema
  addition), editable from each computer's detail page
  (`/dive-computers/{id}`), that excludes that single device from
  auto-download regardless of the global switch. A computer with auto-scan
  opted out is otherwise unaffected - it can still be downloaded manually.

---

## Rejected / deferred: OS-level background execution

The first draft of this design explored making this work even while the app
is backgrounded or suspended. That direction is dropped for this design in
favor of the screen-scoped approach above, because it would have required,
for comparatively low payoff:

- **iOS/macOS:** `CBCentralManagerOptionRestoreIdentifierKey` state
  restoration and scanning by manufacturer service UUID instead of address
  (the `bluetooth-central` entry already present in
  `ios/Runner/Info.plist:187-192` is unused today and was never wired to any
  Dart-level restoration logic).
- **Android:** a new `connectedDevice`-type foreground service with a
  persistent, Play-Store-mandated notification (today's only foreground
  service, `FOREGROUND_SERVICE_LOCATION`, is for GPS track recording, not
  Bluetooth).
- Battery and app-review scrutiny that a standing background BLE scan
  invites on both platforms.

If true background auto-download (e.g. "downloads while the app sits in the
background doing something else, or is fully closed") turns out to still be
wanted later, it should get its own design built on top of this one, since it
needs the foreground-service/background-restoration work above regardless of
how the screen-scoped matching logic is implemented.

---

## Open questions for implementation

1. Default state of the global switch: on by default (convenient, matches
   "it just works" expectation) vs. off by default (opt-in, more
   conservative for first release)?
2. Multi-computer-in-range sequencing: confirm whether `DownloadNotifier`
   already serializes downloads from distinct computers, or whether a
   small queue needs to be added for this feature.
3. Exact placement of the global switch (section header vs. a settings
   page) and of the per-device opt-out (device detail page vs. inline on
   the card in the known-computers list).
4. Whether the "searching" indicator should be able to show connection
   progress for an ongoing automatic download, already covered by
   `DownloadState`'s existing phases
   (`lib/features/dive_computer/presentation/providers/download_providers.dart:75`),
   or needs a lighter-weight screen-local variant.

---

## Test Strategy

- Unit tests for the auto-trigger logic: match found while section visible
  and switch on -> download starts; switch off -> no download; per-device
  opt-out set -> that device is skipped while others still trigger.
- Widget test: entering/leaving the Dive Computers section starts/stops the
  scan.
- Conflict test: manual wizard or manual download already running ->
  automatic trigger does not interfere.
- Regression test: existing manual discovery/download flow (the "Connect new
  computer" wizard and the per-computer manual download button) is
  unaffected when the global switch is off.
