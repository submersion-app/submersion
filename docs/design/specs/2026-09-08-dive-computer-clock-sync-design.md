# Dive computer clock sync (issue #1216)

Date: 2026-09-08
Issue: https://github.com/submersion-app/submersion/issues/1216
Status: approved; implementation plan at docs/superpowers/plans/2026-09-08-dive-computer-clock-sync.md

## Goal

Optionally set a dive computer's clock to the host's current local time and
timezone offset at the end of a dive download, using libdivecomputer's
`dc_device_timesync()`. The feature is opt-in, defaults to off, and every
setting that controls it is local to the installation so that a phone with
automatic time can sync while a laptop with a manually configured timezone
does not.

## Non-goals

- Reading the device clock back or reporting drift. `DC_EVENT_CLOCK` is a
  separate read path and stays untouched.
- Syncing outside a download. There is no standalone "set clock" action,
  because a second connection is fragile on every BLE platform.
- Any per-diver or cloud-synced setting. Nothing in this feature crosses the
  sync serializer.
- Adding timesync support to backends that lack it in the libdivecomputer
  fork.

## Requirements

1. A global, installation-local switch, default off, on the Dive Computers
   list page.
2. A per-computer, installation-local override on the device detail page:
   use app setting (default), always, or never.
3. The effective flag is passed with every download. Sync runs only after a
   successful download and can never change the download's outcome.
4. The diver sees one line on the download completion step: synced, not
   supported by this model, or failed. Nothing is shown when sync was not
   requested.
5. The installation remembers whether each saved computer's model supports
   sync, so the detail page can say so instead of showing a switch that does
   nothing. A "Check again" action clears that record.
6. Host local time with the host's UTC offset is what gets sent. Each
   libdivecomputer backend applies its own conversion (Shearwater sends UTC
   to a Teric and local time to everything else, Mares strips the offset,
   OSTC sends raw wall-clock fields).
7. Android reports serial and firmware on completion, closing the gap where
   it reports `onDownloadComplete(0, null, null)` today.

## Architecture

All five platforms compile one download core, `libdc_download.c`, so the
timesync call itself is a single edit. The work is in the plumbing: one flag
in and one status out through the C signature, its five call sites, the
Android cross-process serial request, the pigeon interface, and the Dart
download notifier.

```
DeviceListPage switch / DeviceDetailPage override
        |
        v
ClockSyncPreferences (SharedPreferences, installation-local)
        |  resolve(computerId) -> bool
        v
DownloadNotifier.startDownload  --syncClock-->  DiveComputerService
        |                                             |
        |                                     DiveComputerHostApi.startDownload(device, fingerprint, syncClock)
        |                                             |
        |                       Swift / Kotlin+JNI / :dc AIDL / Linux / Windows
        |                                             |
        |                                     libdc_download_run(..., sync_clock, &clock_sync_out, ...)
        |                                             |
        |                                     dc_device_foreach -> success -> dc_device_timesync
        |                                             |
        <--- onDownloadComplete(total, serial, firmware, clockSyncStatus) ---
        |
DownloadState.clockSyncStatus -> completion line; recordSupport(computerId)
```

## Section 1: native path and interface

### C core (`packages/libdivecomputer_plugin/macos/Classes/`)

`libdc_wrapper.h` gains:

```c
typedef enum {
    LIBDC_CLOCK_SYNC_NOT_REQUESTED = 0,
    LIBDC_CLOCK_SYNC_SYNCED = 1,
    LIBDC_CLOCK_SYNC_UNSUPPORTED = 2,
    LIBDC_CLOCK_SYNC_FAILED = 3,
} libdc_clock_sync_status_t;

// Stable wire names: "not_requested", "synced", "unsupported", "failed".
const char *libdc_clock_sync_status_name(libdc_clock_sync_status_t status);
```

`libdc_download_run` gains two parameters, placed after the fingerprint pair
to keep the in/out grouping readable:

```c
int libdc_download_run(
    libdc_download_session_t *session,
    const char *vendor, const char *product, unsigned int model,
    unsigned int transport,
    const libdc_io_callbacks_t *io_callbacks,
    const unsigned char *fingerprint, unsigned int fsize,
    int sync_clock,
    const libdc_download_callbacks_t *callbacks,
    unsigned int *serial_out,
    unsigned int *firmware_out,
    libdc_clock_sync_status_t *clock_sync_out,
    char *error_buf, size_t error_buf_size);
```

Behaviour, inserted between the existing step 7 (`dc_device_foreach`) and
the result mapping:

- If `sync_clock` is zero, or the foreach did not return
  `DC_STATUS_SUCCESS`, or the session was cancelled, the out-param is
  `NOT_REQUESTED` and nothing is sent.
- Otherwise build the timestamp with
  `dc_datetime_localtime(&dt, dc_datetime_now())`, which fills
  `dt.timezone` with the host's UTC offset in seconds, and call
  `dc_device_timesync(device, &dt)`.
- `DC_STATUS_SUCCESS` maps to `SYNCED`. `DC_STATUS_UNSUPPORTED` maps to
  `UNSUPPORTED`. Anything else maps to `FAILED` and logs one warning through
  the existing log callback naming the libdc status.
- The download's return code and `error_buf` are never touched by this step.
- `clock_sync_out` may be NULL, in which case the status is dropped.

`libdc_clock_sync_status_name` lives next to `libdc_event_type_name` so all
bindings share one string table.

### Pigeon (`packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`)

```dart
@async
void startDownload(DiscoveredDevice device, String? fingerprint, bool syncClock);

void onDownloadComplete(
  int totalDives,
  String? serialNumber,
  String? firmwareVersion,
  String? clockSyncStatus,
);
```

`clockSyncStatus` carries one of the four wire names. Null is treated as
`not_requested` on the Dart side. Pigeon is regenerated for all five outputs.

### Bindings

| Platform | Change |
|---|---|
| Swift (`darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`) | `startDownload` takes `syncClock`; `runOnce` passes it and reads `clock_sync_out` into `RunResult.clockSyncStatus`; `reportDownloadResult` forwards the name string. Both BLE and serial callers pass the flag. |
| Kotlin in-process (`DiveComputerHostApiImpl.kt`, `LibdcWrapper.kt`, `libdc_jni.cpp`, `LibdcDownloadInfo.kt`) | `nativeDownloadRun` gains `syncClock: Boolean` and an `IntArray(3)` out-param for serial, firmware, and clock status code (replacing the `nullptr, nullptr` out-params in the JNI). The status code is named by a Kotlin twin of the C table, `libdcClockSyncStatusName`, pinned by a JVM test the way `libdcEventTypeName` already is, because the `:dc` process and JVM tests need it without a native call. `onDownloadComplete` reports the real serial, firmware, and status. |
| Kotlin cross-process serial (`SerialDownloadRequest.kt` + `.aidl`, `IDiveDownloadCallback.aidl`, `SerialDownloadRunner.kt`, `SerialDownloadClient.kt`) | `SerialDownloadRequest` gains `syncClock`. `onComplete` gains `String serialNumber, String firmwareVersion, String clockSyncStatus`, all nullable (AIDL strings are nullable), null meaning absent. |
| Linux (`linux/dive_computer_host_api_impl.cc`) | `DownloadThreadData.sync_clock`; every `libdc_download_run` call in the serial probe loop passes it; the `g_idle_add` completion carries the status. |
| Windows (`windows/dive_computer_host_api_impl.cc`) | Same shape as Linux: a copied flag on the thread, status threaded into `OnDownloadComplete`. |

Serial and firmware on Android use the same integer-to-string formatting the
Swift binding already applies, so a given computer reports identical values
on every platform.

## Section 2: Dart settings, state and UI

### Preferences store

New file `lib/features/dive_computer/data/clock_sync_preferences.dart`.

Keys (all in SharedPreferences, never in the database):

| Key | Type | Meaning |
|---|---|---|
| `dive_computer_clock_sync_enabled` | bool | Global switch. Absent means false. |
| `dive_computer_clock_sync_override.<computerId>` | string `always` or `never` | Per-computer override. Absent means inherit. |
| `dive_computer_clock_sync_support.<computerId>` | string `supported` or `unsupported` | Learned from the last download that reported a definite result. Absent means unknown. |

API:

```dart
enum ClockSyncOverride { inherit, always, never }
enum ClockSyncSupport { unknown, supported, unsupported }

class ClockSyncPreferences {
  bool get globalEnabled;
  Future<void> setGlobalEnabled(bool value);
  ClockSyncOverride overrideFor(String computerId);
  Future<void> setOverride(String computerId, ClockSyncOverride value);
  ClockSyncSupport supportFor(String computerId);
  Future<void> recordSupport(String computerId, ClockSyncSupport value);
  Future<void> clearSupport(String computerId);
  Future<void> forget(String computerId);   // removes both per-computer keys
  bool resolve(String? computerId);         // null id: global only
}
```

`resolve` returns true when the override is `always`, false when `never`,
and the global switch otherwise. A recorded `unsupported` does not change
`resolve`; the flag is still sent and the device answers unsupported again,
which is cheap and keeps "Check again" trivially correct.

A `ClockSyncSettingsNotifier extends StateNotifier<ClockSyncSettings>` in
`lib/features/dive_computer/presentation/providers/clock_sync_providers.dart`
follows `debug_mode_provider.dart`: seeded from prefs in the constructor,
each setter writes prefs then publishes new state. `ClockSyncSettings` is an
immutable snapshot (global flag plus the two per-computer maps) so widgets
rebuild on any change. Provider name: `clockSyncSettingsNotifierProvider`.

### Download flow

- `DownloadNotifier.startDownload` reads
  `ref.read(clockSyncSettingsNotifierProvider.notifier).resolve(computer?.id)`
  and passes `syncClock:` to `DiveComputerService.startDownload`, which
  passes it to the host API.
- `DownloadState` gains `final ClockSyncStatus? clockSyncStatus` with an enum
  `ClockSyncStatus { notRequested, synced, unsupported, failed }` parsed from
  the wire name in `DiveComputerService`. `DownloadCompleteEvent` carries it.
- On `DownloadCompleteEvent`, the notifier only stores the parsed status in
  state.
- Support is recorded in one place: `DcAdapterDownloadStep`, which both the
  saved-computer and first-discovery flows run through, already calls
  `ensureComputer` after completion and then reads the adapter's resolved
  `computer`. It records support for that id from the captured
  `DownloadState.clockSyncStatus`: `synced` records supported,
  `unsupported` records unsupported, and a `failed` result records nothing.
- `DiveComputerNotifier.deleteComputer` calls `forget(id)` after the
  repository delete succeeds.

### Dive Computers list page

`DeviceListPage` renders a `SwitchListTile` at the top of the body, above
both the populated list and the empty state, bound to the global switch.
Title: "Sync dive computer clocks". Subtitle: "Sets the clock to this
device's time after each download. Applies to this device only." A
`Divider` separates it from the list.

### Device detail page

A new `_buildClockSyncCard` below the actions card:

- Header "Clock sync".
- When support is `unknown` or `supported`: a three-segment
  `SegmentedButton<ClockSyncOverride>` with labels "Use app setting",
  "Always", "Never", plus a caption reading "App setting: on" or
  "App setting: off". When support is `supported`, a second caption reads
  "Supported by this model".
- When support is `unsupported`: the control is replaced by the note "This
  model does not support clock sync" and a `TextButton` "Check again" that
  calls `clearSupport`.

### Completion line

`DownloadStepWidget` in its completed state renders one extra line under the
dive count, driven by `DownloadState.clockSyncStatus`:

| Status | Text |
|---|---|
| synced | "Clock synced" |
| unsupported | "Clock sync is not supported by this model" |
| failed | "Clock sync failed" |
| notRequested or null | nothing |

The widget is shared by the saved-computer flow and the import wizard, so
one site covers both.

### Localisation

New keys, added to every locale's ARB and regenerated:

- `diveComputer_clockSync_globalTitle`
- `diveComputer_clockSync_globalSubtitle`
- `diveComputer_clockSync_cardTitle`
- `diveComputer_clockSync_overrideInherit`
- `diveComputer_clockSync_overrideAlways`
- `diveComputer_clockSync_overrideNever`
- `diveComputer_clockSync_appSettingOn`
- `diveComputer_clockSync_appSettingOff`
- `diveComputer_clockSync_supported`
- `diveComputer_clockSync_unsupported`
- `diveComputer_clockSync_checkAgain`
- `diveComputer_downloadStep_clockSynced`
- `diveComputer_downloadStep_clockSyncUnsupported`
- `diveComputer_downloadStep_clockSyncFailed`

## Section 3: error handling and testing

### Error handling

- Timesync runs only after a successful foreach; a cancelled or failed
  download never reaches it.
- Its result never alters the download's return code or error buffer.
- `DC_STATUS_UNSUPPORTED` is the expected answer for most models and is
  reported as a status, not an error.
- Other failures log one warning naming the libdc status through the
  existing log callback so they appear in exported debug logs.
- A null or unknown wire name on the Dart side parses to `notRequested`,
  so an out-of-date binding degrades to silence.
- A `failed` result never records support, so a flaky link cannot mark a
  model unsupported.

### Native tests (`packages/libdivecomputer_plugin/test/native/`)

- The sync step is factored out of `libdc_download_run` as
  `libdc_sync_device_clock(device, requested, download_succeeded)`, which
  the run function calls with `sync_clock` and
  `status == DC_STATUS_SUCCESS && !session->cancelled`. A scripted
  whole-device download cannot be specified reliably, so
  `test_download_clock_sync.c` (linked like `test_parse_raw_dive` against
  the full libdivecomputer plus wrapper) drives that function with a
  hand-built `dc_device_t` whose vtable is a fake, exercising the real
  `dc_device_timesync` dispatcher and the real `dc_datetime_*` helpers:
  1. `requested = 0`: status `NOT_REQUESTED`, timesync never called.
  2. `download_succeeded = 0`: status `NOT_REQUESTED`, timesync never called.
  3. A vtable whose timesync records its argument and succeeds: status
     `SYNCED`; the received `dc_datetime_t` converts to an instant between
     `dc_datetime_localtime(dc_datetime_now())` captured immediately before
     and after the call (the real clock cannot be pinned, so the test
     brackets it), and its `timezone` equals the host offset, not
     `DC_TIMEZONE_NONE`.
  4. A vtable with a NULL timesync slot: status `UNSUPPORTED` and no warning
     logged.
  5. A vtable whose timesync returns `DC_STATUS_IO`: status `FAILED` and one
     warning naming the status through the log callback.
- `test_event_type_names.c` gains assertions for the four
  `libdc_clock_sync_status_name` strings.
- Both are registered in `CMakeLists.txt` and run by
  `native-plugin-tests.yml`.

### Dart tests (written before the implementation)

- `test/features/dive_computer/data/clock_sync_preferences_test.dart`:
  resolve precedence, absent keys, `forget`, `clearSupport`, and the
  support recording rules.
- `test/features/dive_computer/presentation/providers/download_notifier_clock_sync_test.dart`:
  the resolved flag reaches the fake host API; the completion status lands in
  `DownloadState`; support is recorded for synced and unsupported only.
- `packages/libdivecomputer_plugin/test/dive_computer_service_test.dart`:
  the new parameter is forwarded and the widened completion event is
  parsed, including null and unknown names.
- Widget tests: `device_list_page_clock_sync_test.dart` (switch toggles the
  pref), `device_detail_page_clock_sync_test.dart` (segmented control,
  captions, unsupported note, Check again), and
  `download_step_widget_clock_sync_test.dart` (each completion line and the
  absent case).
- `dc_adapter_steps_test.dart` extended: support is recorded after
  `ensureComputer` in the first-download path.
- The `DiveComputerNotifier` delete test extended to assert `forget`.

### Manual verification

The synced path needs real hardware. Automated suites and a build of every
platform are what this change can verify; the PR description states that the
hardware path was not exercised.

## Files touched (summary)

Native plugin:
- `macos/Classes/libdc_wrapper.h`, `macos/Classes/libdc_download.c`
  (the status name table sits beside `libdc_event_type_name` here)
- `pigeons/dive_computer_api.dart` and the five generated outputs
- `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`
- `android/.../DiveComputerHostApiImpl.kt`, `LibdcWrapper.kt`,
  `LibdcDownloadInfo.kt` (new, with a JVM test),
  `SerialDownloadRequest.kt`, `SerialDownloadRunner.kt`,
  `SerialDownloadClient.kt`, `aidl/.../SerialDownloadRequest.aidl`,
  `aidl/.../IDiveDownloadCallback.aidl`, `src/main/cpp/libdc_jni.cpp`
- `linux/dive_computer_host_api_impl.cc`
- `windows/dive_computer_host_api_impl.cc`
- `lib/src/dive_computer_service.dart`
- `test/native/test_download_clock_sync.c`, `test/native/CMakeLists.txt`,
  `test/native/test_event_type_names.c`

App:
- `lib/features/dive_computer/data/clock_sync_preferences.dart` (new)
- `lib/features/dive_computer/presentation/providers/clock_sync_providers.dart` (new)
- `lib/features/dive_computer/presentation/providers/download_providers.dart`
- `lib/features/dive_computer/presentation/pages/device_list_page.dart`
- `lib/features/dive_computer/presentation/pages/device_detail_page.dart`
- `lib/features/dive_computer/presentation/widgets/download_step_widget.dart`
- `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart`
- `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`
- `lib/features/dive_log/presentation/providers/dive_computer_providers.dart`
- `lib/l10n/arb/*.arb`

## Out of scope, filed separately

- The sync import path upserts a whole `dive_computers` row with
  `toCompanion(false)`, which most likely writes null over the locally
  stored `bluetoothAddress` that export deliberately strips. This design
  avoids the route entirely by keeping its state in SharedPreferences, and
  the suspected wipe deserves its own issue.
