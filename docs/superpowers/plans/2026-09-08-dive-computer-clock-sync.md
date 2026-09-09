# Dive Computer Clock Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a successful dive download, optionally set the dive computer's clock to the host's local time through libdivecomputer's `dc_device_timesync()`, controlled by installation-local settings, and tell the diver what happened.

**Architecture:** One shared C download core (`libdc_download.c`) gains a `sync_clock` input and a `clock_sync_out` output on `libdc_download_run`; the five platform bindings and the Android cross-process serial request thread those two values through the pigeon interface. On the Dart side an immutable `ClockSyncSettings` value (global switch, per-computer override, per-computer learned support) lives in SharedPreferences and is read by `DownloadNotifier` when a download starts. The completion event carries the outcome back into `DownloadState`, which the download step renders and the wizard step records.

**Tech Stack:** C (libdivecomputer fork), pigeon 22 (Swift, Kotlin, GObject, C++ outputs), Swift, Kotlin + JNI + AIDL, Flutter/Riverpod (StateNotifier), SharedPreferences, mockito, flutter_test, CMake/ctest for native tests.

**Spec:** `docs/superpowers/specs/2026-09-08-dive-computer-clock-sync-design.md`

## Global Constraints

- No em-dashes anywhere (code, comments, commits, docs, ARB values). Use commas, colons, or two sentences.
- No AI-tool attribution of any kind in commits, comments, or PR text: no co-author trailers, no generated-with lines, no session links.
- TDD: write the failing test, run it red, implement, run it green, commit.
- Run `dart format .` from the repo root before every Dart commit.
- No emojis in code or comments. Immutability: never mutate a `DownloadState` or `ClockSyncSettings`, always return a new instance.
- New user-facing strings go into all 11 ARB files (`en ar de es fr he hu it nl pt zh`). Run `flutter gen-l10n` only once, after every locale has its translation (Task 10), and commit the ARBs with the generated `lib/l10n/arb/app_localizations*.dart`.
- Wire names for the clock sync status are exactly `not_requested`, `synced`, `unsupported`, `failed`. Null on the Dart side reads as `not_requested`.
- SharedPreferences keys: `dive_computer_clock_sync_enabled` (bool), `dive_computer_clock_sync_override.<computerId>` (`always` or `never`), `dive_computer_clock_sync_support.<computerId>` (`supported` or `unsupported`).
- Widget keys: `clock_sync_global_switch`, `clock_sync_override`, `clock_sync_check_again`, `clock_sync_result`.
- The sync runs only after `dc_device_foreach` returned `DC_STATUS_SUCCESS` and the session was not cancelled. It never changes the download's return code or error buffer.
- A bare `build` token in a Bash command is refused by a deny rule (`Read(./build/**)`). Every command below that would contain one runs through a scratchpad script: `bash "$SCRATCH/codegen.sh"` for build_runner, `bash "$SCRATCH/native_tests.sh"` for cmake/ctest, `bash "$SCRATCH/build_macos.sh"` and `bash "$SCRATCH/build_apk.sh"` for platform compile checks. `$SCRATCH` is the session scratchpad directory named in the system prompt.
- Worktree root (`$R` in commands): the checkout you are executing in, `git rev-parse --show-toplevel` run from it. Plugin root (`$P`): `$R/packages/libdivecomputer_plugin`. Never `cd` to the main checkout; the shell cwd can reset, so use absolute paths. Export both once per shell: `R="$(git rev-parse --show-toplevel)"; P="$R/packages/libdivecomputer_plugin"`.

## Deviations from the spec, for the reviewer

1. **Native test shape.** The spec proposed a scripted OSTC serial conversation through `libdc_download_run`. That needs the full OSTC3 handshake, logbook and dive protocol scripted byte for byte, which cannot be specified reliably here. Instead the sync step is factored into `libdc_sync_device_clock(device, requested, download_succeeded)` and tested against a hand-built `dc_device_t` with a fake vtable, linking the real `dc_device_timesync` dispatcher and the real `dc_datetime_*` helpers. The gating (not requested, failed download) is covered through the same function's two flags. `libdc_download_run` itself only computes those flags and forwards the result.
2. **Where support is recorded.** Both download flows (saved computer and first discovery) run through `DcAdapterDownloadStep`, which already calls `ensureComputer`, so support is recorded once there instead of also inside `DownloadNotifier`. `DownloadNotifier` only resolves and forwards the flag.
3. **AIDL nullability.** The AIDL completion callback uses nullable Strings (AIDL Strings are nullable) rather than empty-string sentinels.
4. **Kotlin name table.** The Kotlin side gets a JVM twin of the status name table (the repo's existing convention for `libdcEventTypeName`, pinned by a JVM test) rather than a JNI string call, because the `:dc` process and JVM unit tests both need it without a native call.

## File structure

Native plugin (`$P`):

| File | Responsibility |
|---|---|
| `macos/Classes/libdc_wrapper.h` | Public C API: status enum, name function, `libdc_sync_device_clock`, widened `libdc_download_run` |
| `macos/Classes/libdc_download.c` | Status name table beside the event table; sync step; gating inside `libdc_download_run` |
| `test/native/test_download_clock_sync.c` (new) | Pins the sync step against a hand-built device |
| `test/native/test_event_type_names.c` | Gains the four status name assertions |
| `test/native/CMakeLists.txt` | Registers the new test target |
| `pigeons/dive_computer_api.dart` + five generated outputs | `syncClock` in, `clockSyncStatus` out |
| `lib/src/dive_computer_service.dart` | Forwards `syncClock`; `DownloadCompleteEvent.clockSyncStatus` |
| `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` | Threads the flag and status through `runOnce` |
| `android/.../LibdcDownloadInfo.kt` (new) | Kotlin twin of the status names plus unsigned device-info formatting |
| `android/.../LibdcWrapper.kt`, `android/src/main/cpp/libdc_jni.cpp` | `syncClock` in, `infoOut` (serial, firmware, status code) out |
| `android/.../DiveComputerHostApiImpl.kt` | BLE path threads the flag, reports real serial/firmware/status |
| `android/.../SerialDownloadRequest.kt`, `aidl/IDiveDownloadCallback.aidl`, `SerialDownloadRunner.kt`, `SerialDownloadClient.kt` | Cross-process serial path |
| `linux/dive_computer_host_api_impl.cc`, `windows/dive_computer_host_api_impl.{h,cc}` | Desktop bindings |

App (`$R`):

| File | Responsibility |
|---|---|
| `lib/features/dive_computer/domain/entities/clock_sync.dart` (new) | Enums and the immutable `ClockSyncSettings` value with resolve rules |
| `lib/features/dive_computer/data/clock_sync_preferences.dart` (new) | SharedPreferences key layout, load and write |
| `lib/features/dive_computer/presentation/providers/clock_sync_providers.dart` (new) | `ClockSyncSettingsNotifier` and its provider (in-memory default) |
| `lib/core/providers/root_overrides.dart` | Installs the SharedPreferences-backed notifier |
| `lib/features/dive_computer/presentation/providers/download_providers.dart` | `DownloadState.clockSyncStatus`; notifier resolves and forwards the flag |
| `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` | Records learned support after `ensureComputer` |
| `lib/features/dive_log/presentation/providers/dive_computer_providers.dart` | `delete` forgets the computer's keys |
| `lib/features/dive_computer/presentation/pages/device_list_page.dart` | Global switch above the list |
| `lib/features/dive_computer/presentation/pages/device_detail_page.dart` | Per-computer override card |
| `lib/features/dive_computer/presentation/widgets/download_step_widget.dart` | Completion line |
| `lib/l10n/arb/app_*.arb` | 14 new keys in 11 locales |

---

### Task 0: Initialise the worktree

**Files:** none changed.

- [ ] **Step 1: Initialise submodules, dependencies and generated code**

```bash
cd "$R" && git submodule update --init --recursive && bash scripts/setup.sh
```

Expected: ends without error; `$P/third_party/libdivecomputer/include/libdivecomputer/device.h` exists; `$R/lib/core/database/database.g.dart` exists.

- [ ] **Step 2: Create the scratchpad helper scripts**

In each script below replace `WORKTREE_ROOT` with the absolute path printed by `git rev-parse --show-toplevel` from the worktree.

Write `$SCRATCH/codegen.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd WORKTREE_ROOT
dart run build_runner build --delete-conflicting-outputs
```

Write `$SCRATCH/native_tests.sh` (an optional first argument is a ctest `-R` filter):

```bash
#!/bin/bash
set -euo pipefail
R=WORKTREE_ROOT
OUT="$(dirname "$0")/libdc-native-tests"
cmake -S "$R/packages/libdivecomputer_plugin/test/native" -B "$OUT"
cmake --build "$OUT"
if [ -n "${1:-}" ]; then
  ctest --test-dir "$OUT" --output-on-failure -R "$1"
else
  ctest --test-dir "$OUT" --output-on-failure
fi
```

Write `$SCRATCH/build_macos.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd WORKTREE_ROOT
flutter build macos --debug
```

Write `$SCRATCH/build_apk.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd WORKTREE_ROOT
flutter build apk --debug
```

- [ ] **Step 3: Confirm the native suite is green before any change**

Run: `bash "$SCRATCH/native_tests.sh"`
Expected: every existing ctest target passes (`100% tests passed`).

---

### Task 1: Clock sync status table and sync step in the C core

**Files:**
- Modify: `$P/macos/Classes/libdc_wrapper.h` (after the `libdc_event_type_name` declaration, around line 236)
- Modify: `$P/macos/Classes/libdc_download.c` (after `libdc_event_type_name`, and after `libdc_logfunc_wrapper`)
- Modify: `$P/test/native/test_event_type_names.c`
- Create: `$P/test/native/test_download_clock_sync.c`
- Modify: `$P/test/native/CMakeLists.txt`

**Interfaces:**
- Produces (C):
  - `typedef enum { LIBDC_CLOCK_SYNC_NOT_REQUESTED = 0, LIBDC_CLOCK_SYNC_SYNCED = 1, LIBDC_CLOCK_SYNC_UNSUPPORTED = 2, LIBDC_CLOCK_SYNC_FAILED = 3 } libdc_clock_sync_status_t;`
  - `const char *libdc_clock_sync_status_name(libdc_clock_sync_status_t status);` returning `"not_requested"`, `"synced"`, `"unsupported"`, `"failed"`, else `"unknown"`.
  - `libdc_clock_sync_status_t libdc_sync_device_clock(struct dc_device_t *device, int requested, int download_succeeded);`

- [ ] **Step 1: Add the status name assertions to the existing name test**

In `$P/test/native/test_event_type_names.c`, add before `int main(void)`:

```c
/* The clock sync outcome crosses every binding as one of these names; the
   Dart side switches on the spelling, so it is pinned here beside the event
   table (issue #1216). */
static void test_clock_sync_status_names(void) {
    assert(strcmp(libdc_clock_sync_status_name(LIBDC_CLOCK_SYNC_NOT_REQUESTED),
                  "not_requested") == 0);
    assert(strcmp(libdc_clock_sync_status_name(LIBDC_CLOCK_SYNC_SYNCED),
                  "synced") == 0);
    assert(strcmp(libdc_clock_sync_status_name(LIBDC_CLOCK_SYNC_UNSUPPORTED),
                  "unsupported") == 0);
    assert(strcmp(libdc_clock_sync_status_name(LIBDC_CLOCK_SYNC_FAILED),
                  "failed") == 0);
    assert(strcmp(libdc_clock_sync_status_name((libdc_clock_sync_status_t)99),
                  "unknown") == 0);
    printf("PASS: test_clock_sync_status_names\n");
}
```

and call it inside `main` after `test_codes_outside_the_enum_are_unknown();`:

```c
    test_clock_sync_status_names();
```

- [ ] **Step 2: Write the sync step test**

Create `$P/test/native/test_download_clock_sync.c`:

```c
// Pins the clock sync step that runs after a successful download (issue
// #1216). The real dc_device_timesync dispatcher and the real dc_datetime
// helpers are linked in; the device is built by hand around a fake vtable so
// the test can see exactly what timesync received without scripting a whole
// device protocol.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/common.h>
#include <libdivecomputer/datetime.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/device.h>

#include "device-private.h"
#include "libdc_wrapper.h"

static int g_timesync_calls = 0;
static dc_datetime_t g_received;
static dc_status_t g_timesync_result = DC_STATUS_SUCCESS;

static dc_status_t fake_timesync(dc_device_t *device,
                                 const dc_datetime_t *datetime) {
    (void)device;
    g_timesync_calls++;
    g_received = *datetime;
    return g_timesync_result;
}

static const dc_device_vtable_t vtable_with_timesync = {
    sizeof(dc_device_t), DC_FAMILY_NULL,
    NULL, NULL, NULL, NULL, NULL, fake_timesync, NULL,
};

static const dc_device_vtable_t vtable_without_timesync = {
    sizeof(dc_device_t), DC_FAMILY_NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
};

static char g_last_log[256];
static int g_last_level = 0;

static void capture_log(int level, const char *message, void *userdata) {
    (void)userdata;
    g_last_level = level;
    strncpy(g_last_log, message, sizeof(g_last_log) - 1);
    g_last_log[sizeof(g_last_log) - 1] = '\0';
}

static void reset(void) {
    g_timesync_calls = 0;
    memset(&g_received, 0, sizeof(g_received));
    g_timesync_result = DC_STATUS_SUCCESS;
    g_last_log[0] = '\0';
    g_last_level = 0;
}

static dc_device_t make_device(const dc_device_vtable_t *vtable) {
    dc_device_t device;
    memset(&device, 0, sizeof(device));
    device.vtable = vtable;
    return device;
}

static void test_not_requested_never_touches_the_device(void) {
    reset();
    dc_device_t device = make_device(&vtable_with_timesync);
    assert(libdc_sync_device_clock(&device, 0, 1) ==
           LIBDC_CLOCK_SYNC_NOT_REQUESTED);
    assert(g_timesync_calls == 0);
    printf("PASS: test_not_requested_never_touches_the_device\n");
}

static void test_failed_download_skips_the_sync(void) {
    reset();
    dc_device_t device = make_device(&vtable_with_timesync);
    assert(libdc_sync_device_clock(&device, 1, 0) ==
           LIBDC_CLOCK_SYNC_NOT_REQUESTED);
    assert(g_timesync_calls == 0);
    printf("PASS: test_failed_download_skips_the_sync\n");
}

static void test_synced_sends_host_local_time_with_offset(void) {
    reset();
    dc_device_t device = make_device(&vtable_with_timesync);
    dc_datetime_t before;
    dc_datetime_t after;
    assert(dc_datetime_localtime(&before, dc_datetime_now()) != NULL);
    libdc_clock_sync_status_t status =
        libdc_sync_device_clock(&device, 1, 1);
    assert(dc_datetime_localtime(&after, dc_datetime_now()) != NULL);

    assert(status == LIBDC_CLOCK_SYNC_SYNCED);
    assert(g_timesync_calls == 1);
    // The real clock cannot be pinned, so bracket it between two readings.
    dc_ticks_t received = dc_datetime_mktime(&g_received);
    assert(received >= dc_datetime_mktime(&before));
    assert(received <= dc_datetime_mktime(&after));
    // The host offset travels with the time so each backend can convert.
    assert(g_received.timezone != DC_TIMEZONE_NONE);
    assert(g_received.timezone == before.timezone);
    printf("PASS: test_synced_sends_host_local_time_with_offset\n");
}

static void test_backend_without_timesync_is_unsupported(void) {
    reset();
    dc_device_t device = make_device(&vtable_without_timesync);
    assert(libdc_sync_device_clock(&device, 1, 1) ==
           LIBDC_CLOCK_SYNC_UNSUPPORTED);
    // Expected for most models, so it must not log as a warning.
    assert(g_last_log[0] == '\0');
    printf("PASS: test_backend_without_timesync_is_unsupported\n");
}

static void test_backend_error_is_failed_and_logged(void) {
    reset();
    g_timesync_result = DC_STATUS_IO;
    dc_device_t device = make_device(&vtable_with_timesync);
    assert(libdc_sync_device_clock(&device, 1, 1) ==
           LIBDC_CLOCK_SYNC_FAILED);
    assert(g_last_level == 2);  // DC_LOGLEVEL_WARNING
    assert(strstr(g_last_log, "Clock sync failed") != NULL);
    printf("PASS: test_backend_error_is_failed_and_logged\n");
}

int main(void) {
    libdc_set_log_callback(capture_log, NULL);
    test_not_requested_never_touches_the_device();
    test_failed_download_skips_the_sync();
    test_synced_sends_host_local_time_with_offset();
    test_backend_without_timesync_is_unsupported();
    test_backend_error_is_failed_and_logged();
    libdc_set_log_callback(NULL, NULL);
    printf("All clock sync tests passed.\n");
    return 0;
}
```

- [ ] **Step 3: Register the test target**

In `$P/test/native/CMakeLists.txt`, after the `test_event_type_names` block (the one ending with its `if(WIN32) ... endif()`), add:

```cmake
# The clock sync step after a download (issue #1216) is shared by every
# binding, so its gating and status mapping are pinned here once.
add_executable(test_download_clock_sync
    test_download_clock_sync.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_download_clock_sync PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_download_clock_sync PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_download_clock_sync PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_download_clock_sync PRIVATE SetupAPI.lib ws2_32.lib)
endif()
```

and after `add_test(NAME test_event_type_names COMMAND test_event_type_names)` add:

```cmake
add_test(NAME test_download_clock_sync COMMAND test_download_clock_sync)
```

- [ ] **Step 4: Run the native tests to see them fail**

Run: `bash "$SCRATCH/native_tests.sh"`
Expected: the build FAILS with `libdc_clock_sync_status_t` and `libdc_sync_device_clock` undeclared.

- [ ] **Step 5: Declare the enum and the two functions**

In `$P/macos/Classes/libdc_wrapper.h`, directly after the line `const char *libdc_event_type_name(unsigned int type);`, add:

```c

// Outcome of the optional clock sync that runs after a successful download
// (issue #1216). NOT_REQUESTED also covers a download that failed or was
// cancelled, because the sync never runs then.
typedef enum {
    LIBDC_CLOCK_SYNC_NOT_REQUESTED = 0,
    LIBDC_CLOCK_SYNC_SYNCED = 1,
    LIBDC_CLOCK_SYNC_UNSUPPORTED = 2,
    LIBDC_CLOCK_SYNC_FAILED = 3,
} libdc_clock_sync_status_t;

// Wire name for a clock sync status: "not_requested", "synced",
// "unsupported" or "failed" ("unknown" outside the enum). This is the single
// table every binding must report through; the Dart side switches on it.
// Statically allocated (do not free).
const char *libdc_clock_sync_status_name(libdc_clock_sync_status_t status);

// Sets the device clock to the host's current local time (with the host UTC
// offset) when `requested` and `download_succeeded` are both non-zero.
// Returns NOT_REQUESTED without touching the device otherwise, SYNCED on
// success, UNSUPPORTED when the backend has no timesync, FAILED (and logs a
// warning through the log callback) for any other libdivecomputer status.
struct dc_device_t;
libdc_clock_sync_status_t libdc_sync_device_clock(struct dc_device_t *device,
                                                   int requested,
                                                   int download_succeeded);
```

- [ ] **Step 6: Implement the name table**

In `$P/macos/Classes/libdc_download.c`, directly after the closing brace of `libdc_event_type_name` (the function that ends with `default: return "unknown";`), add:

```c

const char *libdc_clock_sync_status_name(libdc_clock_sync_status_t status) {
    switch (status) {
    case LIBDC_CLOCK_SYNC_NOT_REQUESTED: return "not_requested";
    case LIBDC_CLOCK_SYNC_SYNCED: return "synced";
    case LIBDC_CLOCK_SYNC_UNSUPPORTED: return "unsupported";
    case LIBDC_CLOCK_SYNC_FAILED: return "failed";
    default: return "unknown";
    }
}
```

- [ ] **Step 7: Implement the sync step**

In `$P/macos/Classes/libdc_download.c`, directly after the closing brace of `libdc_logfunc_wrapper` (so the `extern g_log_callback` declarations above it are in scope) and before `libdc_download_session_new`, add:

```c

libdc_clock_sync_status_t libdc_sync_device_clock(struct dc_device_t *device,
                                                   int requested,
                                                   int download_succeeded) {
    if (!requested || !download_succeeded) {
        return LIBDC_CLOCK_SYNC_NOT_REQUESTED;
    }

    // Host wall-clock time with the host's UTC offset filled in. Each backend
    // applies its own conversion (Shearwater sends UTC to a Teric and local
    // time to everything else, Mares strips the offset, OSTC sends the raw
    // fields), so no timezone logic lives here.
    dc_datetime_t now;
    memset(&now, 0, sizeof(now));
    if (dc_datetime_localtime(&now, dc_datetime_now()) == NULL) {
        if (g_log_callback != NULL) {
            g_log_callback((int)DC_LOGLEVEL_WARNING,
                           "Clock sync failed: host time unavailable",
                           g_log_userdata);
        }
        return LIBDC_CLOCK_SYNC_FAILED;
    }

    dc_status_t status = dc_device_timesync(device, &now);
    if (status == DC_STATUS_SUCCESS) {
        return LIBDC_CLOCK_SYNC_SYNCED;
    }
    if (status == DC_STATUS_UNSUPPORTED) {
        // The normal answer for most models, not an error.
        return LIBDC_CLOCK_SYNC_UNSUPPORTED;
    }
    if (g_log_callback != NULL) {
        char msg[96];
        snprintf(msg, sizeof(msg),
                 "Clock sync failed (libdivecomputer status %d)", (int)status);
        g_log_callback((int)DC_LOGLEVEL_WARNING, msg, g_log_userdata);
    }
    return LIBDC_CLOCK_SYNC_FAILED;
}
```

- [ ] **Step 8: Run the native tests to see them pass**

Run: `bash "$SCRATCH/native_tests.sh"`
Expected: `100% tests passed`, and the output of `test_download_clock_sync` shows five `PASS:` lines. Also run `bash "$SCRATCH/native_tests.sh" test_event_type_names` and confirm `PASS: test_clock_sync_status_names` is printed.

- [ ] **Step 9: Commit**

```bash
cd "$R" && git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h packages/libdivecomputer_plugin/macos/Classes/libdc_download.c packages/libdivecomputer_plugin/test/native/test_download_clock_sync.c packages/libdivecomputer_plugin/test/native/test_event_type_names.c packages/libdivecomputer_plugin/test/native/CMakeLists.txt && git commit -m "feat(libdc): add the clock sync step and status table (#1216)"
```

---

### Task 2: Thread the flag and status through `libdc_download_run`

Every caller of `libdc_download_run` is updated in this task so each platform still compiles, passing `0` and `NULL` for now. Tasks 3 to 5 replace those placeholders with the real values.

**Files:**
- Modify: `$P/macos/Classes/libdc_wrapper.h` (`libdc_download_run` prototype, around line 292)
- Modify: `$P/macos/Classes/libdc_download.c` (`libdc_download_run`, around lines 852 to 976)
- Modify: `$P/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` (`runOnce`, two calls)
- Modify: `$P/android/src/main/cpp/libdc_jni.cpp` (one call, around line 827)
- Modify: `$P/linux/dive_computer_host_api_impl.cc` (four calls, around lines 385, 443, 491, 531)
- Modify: `$P/windows/dive_computer_host_api_impl.cc` (two calls, around lines 415 and 508)

**Interfaces:**
- Consumes: `libdc_sync_device_clock`, `libdc_clock_sync_status_t` (Task 1).
- Produces (C):

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

- [ ] **Step 1: Change the prototype**

In `$P/macos/Classes/libdc_wrapper.h` replace:

```c
// Run the download. Blocks until complete or cancelled.
// Returns 0 on success, non-zero on error.
// serial_out/firmware_out receive device info from DC_EVENT_DEVINFO (may be NULL).
// error_buf receives a human-readable error message (optional, may be NULL).
int libdc_download_run(
    libdc_download_session_t *session,
    const char *vendor, const char *product, unsigned int model,
    unsigned int transport,
    const libdc_io_callbacks_t *io_callbacks,
    const unsigned char *fingerprint, unsigned int fsize,
    const libdc_download_callbacks_t *callbacks,
    unsigned int *serial_out,
    unsigned int *firmware_out,
    char *error_buf, size_t error_buf_size);
```

with:

```c
// Run the download. Blocks until complete or cancelled.
// Returns 0 on success, non-zero on error.
// sync_clock: non-zero to set the device clock to the host's local time after
// a successful download (issue #1216). The result lands in clock_sync_out
// (may be NULL) and never affects the return code or error_buf.
// serial_out/firmware_out receive device info from DC_EVENT_DEVINFO (may be NULL).
// error_buf receives a human-readable error message (optional, may be NULL).
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

- [ ] **Step 2: Change the definition and add the gated sync**

In `$P/macos/Classes/libdc_download.c` replace the function header:

```c
int libdc_download_run(
    libdc_download_session_t *session,
    const char *vendor, const char *product, unsigned int model,
    unsigned int transport,
    const libdc_io_callbacks_t *io_callbacks,
    const unsigned char *fingerprint, unsigned int fsize,
    const libdc_download_callbacks_t *callbacks,
    unsigned int *serial_out,
    unsigned int *firmware_out,
    char *error_buf, size_t error_buf_size)
{
```

with:

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
    char *error_buf, size_t error_buf_size)
{
```

Then replace:

```c
    // 7. Download dives.
    status = dc_device_foreach(device, dive_callback, &state);

    int result = 0;
```

with:

```c
    // 7. Download dives.
    status = dc_device_foreach(device, dive_callback, &state);

    // 7b. Optional clock sync, only after a fully successful download so a
    // slow or failing timesync can never cost the diver their dives, and
    // never after a cancel (issue #1216). Its outcome is reported separately
    // and never changes `result` or the error buffer.
    libdc_clock_sync_status_t clock_sync = libdc_sync_device_clock(
        device, sync_clock,
        status == DC_STATUS_SUCCESS && !session->cancelled);

    int result = 0;
```

And replace:

```c
    if (firmware_out != NULL) {
        *firmware_out = state.firmware;
    }
```

with:

```c
    if (firmware_out != NULL) {
        *firmware_out = state.firmware;
    }
    if (clock_sync_out != NULL) {
        *clock_sync_out = clock_sync;
    }
```

- [ ] **Step 3: Update the Swift caller with placeholders**

In `$P/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`, inside `runOnce`, both `libdc_download_run(` calls currently pass:

```swift
                    &dl,
                    &serial, &firmware,
                    &errorBuf, errorBuf.count
```

(the second call is indented one level less). Change both to:

```swift
                    0,
                    &dl,
                    &serial, &firmware, nil,
                    &errorBuf, errorBuf.count
```

keeping each call's indentation. `0` goes between the fingerprint pair and `&dl`; `nil` goes after `&firmware`.

- [ ] **Step 4: Update the JNI caller with placeholders**

In `$P/android/src/main/cpp/libdc_jni.cpp` replace:

```cpp
        &io_callbacks,
        fp_data, fp_size,
        &dl_callbacks,
        nullptr, nullptr,
        error_buf, sizeof(error_buf));
```

with:

```cpp
        &io_callbacks,
        fp_data, fp_size,
        0,
        &dl_callbacks,
        nullptr, nullptr, nullptr,
        error_buf, sizeof(error_buf));
```

- [ ] **Step 5: Update the four Linux callers with placeholders**

In `$P/linux/dive_computer_host_api_impl.cc` each of the four `libdc_download_run(` calls contains these consecutive lines (indentation varies per call):

```cpp
        fp_data, fp_size,
        &dl_callbacks,
        &serial_number, &firmware_version,
        error_buf, sizeof(error_buf));
```

Change each to:

```cpp
        fp_data, fp_size,
        0,
        &dl_callbacks,
        &serial_number, &firmware_version, nullptr,
        error_buf, sizeof(error_buf));
```

Confirm with `grep -c "&serial_number, &firmware_version, nullptr," $P/linux/dive_computer_host_api_impl.cc` printing `4`.

- [ ] **Step 6: Update the two Windows callers with placeholders**

In `$P/windows/dive_computer_host_api_impl.cc` both `libdc_download_run(` calls contain:

```cpp
                static_cast<unsigned int>(fp_bytes.size()),
                &dl_callbacks,
                &serial, &firmware,
                error_buf, sizeof(error_buf));
```

Change each to:

```cpp
                static_cast<unsigned int>(fp_bytes.size()),
                0,
                &dl_callbacks,
                &serial, &firmware, nullptr,
                error_buf, sizeof(error_buf));
```

Confirm with `grep -c "&serial, &firmware, nullptr," $P/windows/dive_computer_host_api_impl.cc` printing `2`.

- [ ] **Step 7: Verify the C core and the darwin binding compile**

Run: `bash "$SCRATCH/native_tests.sh"`
Expected: `100% tests passed` (the wrapper compiles with the new signature; `test_parse_raw_dive` links `libdc_download.c`).

Run: `bash "$SCRATCH/build_macos.sh"`
Expected: `Built build/macos/Build/Products/Debug/submersion.app` (the Swift placeholder call compiles). Android, Linux and Windows are compile-checked by CI on push; the edits above are mechanical.

- [ ] **Step 8: Commit**

```bash
cd "$R" && git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h packages/libdivecomputer_plugin/macos/Classes/libdc_download.c packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc && git commit -m "feat(libdc): thread clock sync through libdc_download_run (#1216)"
```

---

### Task 3: Pigeon interface, Dart service, and the darwin binding

After the pigeon regeneration in this task, the Android, Linux and Windows bindings will not compile until Tasks 4 and 5 land. That is expected inside this one PR.

**Files:**
- Modify: `$P/pigeons/dive_computer_api.dart` (lines 275 and 300 to 304)
- Regenerate: `$P/lib/src/generated/dive_computer_api.g.dart`, `$P/ios/Classes/DiveComputerApi.g.swift` (and its macOS twin), `$P/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt`, `$P/linux/dive_computer_api.g.{h,cc}`, `$P/windows/dive_computer_api.g.{h,cc}`
- Modify: `$P/lib/src/dive_computer_service.dart`
- Modify: `$P/test/dive_computer_service_test.dart`, `$P/test/serial_transport_test.dart`
- Modify: `$P/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`

**Interfaces:**
- Produces (pigeon): `startDownload(DiscoveredDevice device, String? fingerprint, bool syncClock)`; `onDownloadComplete(int totalDives, String? serialNumber, String? firmwareVersion, String? clockSyncStatus)`.
- Produces (Dart): `DiveComputerService.startDownload(DiscoveredDevice device, {String? fingerprint, bool syncClock = false})`; `DownloadCompleteEvent(int totalDives, {String? serialNumber, String? firmwareVersion, String? clockSyncStatus})`.
- Generated native signatures the later tasks implement: Swift `startDownload(device:fingerprint:syncClock:completion:)` and `onDownloadComplete(totalDives:serialNumber:firmwareVersion:clockSyncStatus:completion:)`; Kotlin `startDownload(device, fingerprint, syncClock: Boolean, callback)` and `onDownloadComplete(totalDives, serialNumber, firmwareVersion, clockSyncStatus, callback)`; GObject handler `start_download(device, const gchar* fingerprint, gboolean sync_clock, response_handle, user_data)` and `..._on_download_complete(api, total_dives, serial, firmware, clock_sync_status, cancellable, callback, user_data)`; C++ `StartDownload(const DiscoveredDevice&, const std::string* fingerprint, bool sync_clock, result)` and `OnDownloadComplete(int64_t, const std::string*, const std::string*, const std::string* clock_sync_status, on_success, on_error)`.

- [ ] **Step 1: Write the failing plugin tests**

In `$P/test/dive_computer_service_test.dart`, change the mock's field list and `startDownload`:

```dart
  DiscoveredDevice? lastDownloadDevice;
  String? lastDownloadFingerprint;
  bool? lastDownloadSyncClock;
```

```dart
  @override
  Future<void> startDownload(
    DiscoveredDevice device,
    String? fingerprint,
    bool syncClock,
  ) async {
    startDownloadCalled = true;
    lastDownloadDevice = device;
    lastDownloadFingerprint = fingerprint;
    lastDownloadSyncClock = syncClock;
  }
```

Add to the `download` group:

```dart
    test('startDownload forwards syncClock and defaults it to false', () async {
      final device = DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 1,
        address: '00:11:22:33:44:55',
        transport: TransportType.ble,
      );

      await service.startDownload(device);
      expect(mockHostApi.lastDownloadSyncClock, isFalse);

      await service.startDownload(device, syncClock: true);
      expect(mockHostApi.lastDownloadSyncClock, isTrue);
    });

    test('completion carries the clock sync status', () async {
      expectLater(
        service.downloadEvents,
        emits(
          isA<DownloadCompleteEvent>().having(
            (e) => e.clockSyncStatus,
            'clockSyncStatus',
            'synced',
          ),
        ),
      );

      service.onDownloadComplete(5, null, null, 'synced');
    });
```

and change the existing completion test's call to `service.onDownloadComplete(5, null, null, null);`.

In `$P/test/serial_transport_test.dart`, change the mock's `startDownload` to take the third positional parameter `bool syncClock` (the body stays as it is).

- [ ] **Step 2: Run the plugin tests to see them fail**

Run: `cd "$P" && flutter test test/dive_computer_service_test.dart`
Expected: FAIL to compile (`syncClock` undefined, `onDownloadComplete` takes 3 arguments).

- [ ] **Step 3: Change the pigeon definition and regenerate**

In `$P/pigeons/dive_computer_api.dart` replace:

```dart
  @async
  void startDownload(DiscoveredDevice device, String? fingerprint);
```

with:

```dart
  @async
  void startDownload(
    DiscoveredDevice device,
    String? fingerprint,
    bool syncClock,
  );
```

and replace:

```dart
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
  );
```

with:

```dart
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
    String? clockSyncStatus,
  );
```

Regenerate:

```bash
cd "$P" && dart run pigeon --input pigeons/dive_computer_api.dart && dart format lib/src/generated
```

Then confirm the macOS Swift output follows the iOS one: `ls -la "$P/macos/Classes/DiveComputerApi.g.swift"`. If it is a symlink to `../../ios/Classes/DiveComputerApi.g.swift` nothing more is needed; if it is a regular file, copy: `cp "$P/ios/Classes/DiveComputerApi.g.swift" "$P/macos/Classes/DiveComputerApi.g.swift"`.

- [ ] **Step 4: Update the Dart service**

In `$P/lib/src/dive_computer_service.dart` replace the event class:

```dart
class DownloadCompleteEvent extends DownloadEvent {
  final int totalDives;
  final String? serialNumber;
  final String? firmwareVersion;
  DownloadCompleteEvent(
    this.totalDives, {
    this.serialNumber,
    this.firmwareVersion,
  });
}
```

with:

```dart
class DownloadCompleteEvent extends DownloadEvent {
  final int totalDives;
  final String? serialNumber;
  final String? firmwareVersion;

  /// Wire name of the clock sync outcome ("synced", "unsupported", "failed")
  /// or null when no sync was requested. Parsed by the app layer.
  final String? clockSyncStatus;

  DownloadCompleteEvent(
    this.totalDives, {
    this.serialNumber,
    this.firmwareVersion,
    this.clockSyncStatus,
  });
}
```

Replace the start method:

```dart
  /// Start downloading dives from a discovered device.
  Future<void> startDownload(DiscoveredDevice device, {String? fingerprint}) {
    return _hostApi.startDownload(device, fingerprint);
  }
```

with:

```dart
  /// Start downloading dives from a discovered device.
  ///
  /// [syncClock] asks the native side to set the computer's clock to the
  /// host's local time once the download has succeeded (issue #1216).
  Future<void> startDownload(
    DiscoveredDevice device, {
    String? fingerprint,
    bool syncClock = false,
  }) {
    return _hostApi.startDownload(device, fingerprint, syncClock);
  }
```

Replace the completion callback:

```dart
  @override
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
  ) {
    _downloadEventsController.add(
      DownloadCompleteEvent(
        totalDives,
        serialNumber: serialNumber,
        firmwareVersion: firmwareVersion,
      ),
    );
  }
```

with:

```dart
  @override
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
    String? clockSyncStatus,
  ) {
    _downloadEventsController.add(
      DownloadCompleteEvent(
        totalDives,
        serialNumber: serialNumber,
        firmwareVersion: firmwareVersion,
        clockSyncStatus: clockSyncStatus,
      ),
    );
  }
```

- [ ] **Step 5: Run the plugin tests to see them pass**

Run: `cd "$P" && flutter test`
Expected: all plugin tests pass.

- [ ] **Step 6: Implement the darwin binding**

In `$P/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`:

Replace:

```swift
    func startDownload(device: DiscoveredDevice, fingerprint: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.performDownload(device: device, fingerprint: fingerprint)
        }
    }
```

with:

```swift
    func startDownload(device: DiscoveredDevice, fingerprint: String?, syncClock: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.performDownload(device: device, fingerprint: fingerprint, syncClock: syncClock)
        }
    }
```

Replace:

```swift
    /// Result of a single libdc_download_run attempt.
    private struct RunResult {
        let rc: Int32
        let serial: UInt32
        let firmware: UInt32
        let errorMessage: String
    }

    private func performDownload(device: DiscoveredDevice, fingerprint: String?) {
```

with:

```swift
    /// Result of a single libdc_download_run attempt.
    private struct RunResult {
        let rc: Int32
        let serial: UInt32
        let firmware: UInt32
        /// Wire name from libdc_clock_sync_status_name (issue #1216).
        let clockSyncStatus: String
        let errorMessage: String
    }

    private func performDownload(device: DiscoveredDevice, fingerprint: String?, syncClock: Bool) {
```

Replace the dispatch:

```swift
        case .ble:
            performBleDownload(
                device: device, session: session,
                downloadCallbacks: downloadCallbacks, fingerprint: fingerprintBytes)
        case .serial, .usb:
            // Serial-over-USB (e.g. Mares Puck Pro on an FTDI cable). The Dart
            // layer folds libdivecomputer's serial transport into `.usb`, so both
            // route here and download over LIBDC_TRANSPORT_SERIAL.
            performSerialDownload(
                device: device, session: session,
                downloadCallbacks: downloadCallbacks, fingerprint: fingerprintBytes)
```

with:

```swift
        case .ble:
            performBleDownload(
                device: device, session: session,
                downloadCallbacks: downloadCallbacks, fingerprint: fingerprintBytes,
                syncClock: syncClock)
        case .serial, .usb:
            // Serial-over-USB (e.g. Mares Puck Pro on an FTDI cable). The Dart
            // layer folds libdivecomputer's serial transport into `.usb`, so both
            // route here and download over LIBDC_TRANSPORT_SERIAL.
            performSerialDownload(
                device: device, session: session,
                downloadCallbacks: downloadCallbacks, fingerprint: fingerprintBytes,
                syncClock: syncClock)
```

Replace the whole `runOnce` function with:

```swift
    /// Runs a single blocking download attempt over the given I/O callbacks.
    /// Callbacks are passed by value and copied to locals so libdc_download_run
    /// can take mutable pointers to them.
    private func runOnce(
        session: OpaquePointer,
        device: DiscoveredDevice,
        transportValue: UInt32,
        ioCallbacks: libdc_io_callbacks_t,
        fingerprint: [UInt8]?,
        downloadCallbacks: libdc_download_callbacks_t,
        syncClock: Bool
    ) -> RunResult {
        var io = ioCallbacks
        var dl = downloadCallbacks
        var serial: UInt32 = 0
        var firmware: UInt32 = 0
        var clockSync = LIBDC_CLOCK_SYNC_NOT_REQUESTED
        var errorBuf = [CChar](repeating: 0, count: 256)
        let syncFlag: Int32 = syncClock ? 1 : 0
        let result: Int32
        if let fp = fingerprint, !fp.isEmpty {
            result = fp.withUnsafeBufferPointer { buf in
                libdc_download_run(
                    session,
                    device.vendor, device.product, UInt32(device.model),
                    transportValue,
                    &io,
                    buf.baseAddress, UInt32(buf.count),
                    syncFlag,
                    &dl,
                    &serial, &firmware, &clockSync,
                    &errorBuf, errorBuf.count
                )
            }
        } else {
            result = libdc_download_run(
                session,
                device.vendor, device.product, UInt32(device.model),
                transportValue,
                &io,
                nil, 0,
                syncFlag,
                &dl,
                &serial, &firmware, &clockSync,
                &errorBuf, errorBuf.count
            )
        }
        return RunResult(
            rc: result, serial: serial, firmware: firmware,
            clockSyncStatus: String(cString: libdc_clock_sync_status_name(clockSync)),
            errorMessage: String(cString: errorBuf))
    }
```

In `reportDownloadResult`, replace:

```swift
        let serialStr: String? = result.serial > 0 ? String(result.serial) : nil
        let firmwareStr: String? = result.firmware > 0 ? String(result.firmware) : nil
```

with:

```swift
        let serialStr: String? = result.serial > 0 ? String(result.serial) : nil
        let firmwareStr: String? = result.firmware > 0 ? String(result.firmware) : nil
        // Null means "nothing was asked", so the Dart side shows no line.
        let clockSyncStr: String? =
            result.clockSyncStatus == "not_requested" ? nil : result.clockSyncStatus
        NativeLogger.i("DiveComputerHost", category: "LDC",
            "Clock sync: \(result.clockSyncStatus)")
```

and change both `onDownloadComplete` calls in that function from:

```swift
                self?.flutterApi.onDownloadComplete(
                    totalDives: 0, serialNumber: serialStr, firmwareVersion: firmwareStr) { _ in }
```

to:

```swift
                self?.flutterApi.onDownloadComplete(
                    totalDives: 0, serialNumber: serialStr, firmwareVersion: firmwareStr,
                    clockSyncStatus: clockSyncStr) { _ in }
```

Replace `performBleDownload`:

```swift
    private func performBleDownload(
        device: DiscoveredDevice, session: OpaquePointer,
        downloadCallbacks: libdc_download_callbacks_t, fingerprint: [UInt8]?
    ) {
        guard let ioCallbacks = connectBle(device: device) else { return }
        let result = runOnce(
            session: session, device: device,
            transportValue: UInt32(LIBDC_TRANSPORT_BLE),
            ioCallbacks: ioCallbacks, fingerprint: fingerprint,
            downloadCallbacks: downloadCallbacks)
        reportDownloadResult(result)
    }
```

with:

```swift
    private func performBleDownload(
        device: DiscoveredDevice, session: OpaquePointer,
        downloadCallbacks: libdc_download_callbacks_t, fingerprint: [UInt8]?,
        syncClock: Bool
    ) {
        guard let ioCallbacks = connectBle(device: device) else { return }
        let result = runOnce(
            session: session, device: device,
            transportValue: UInt32(LIBDC_TRANSPORT_BLE),
            ioCallbacks: ioCallbacks, fingerprint: fingerprint,
            downloadCallbacks: downloadCallbacks, syncClock: syncClock)
        reportDownloadResult(result)
    }
```

Change the `performSerialDownload` signature:

```swift
    private func performSerialDownload(
        device: DiscoveredDevice, session: OpaquePointer,
        downloadCallbacks: libdc_download_callbacks_t, fingerprint: [UInt8]?
    ) {
```

to:

```swift
    private func performSerialDownload(
        device: DiscoveredDevice, session: OpaquePointer,
        downloadCallbacks: libdc_download_callbacks_t, fingerprint: [UInt8]?,
        syncClock: Bool
    ) {
```

Inside it, both `runOnce(` calls end with:

```swift
                ioCallbacks: opened.callbacks, fingerprint: fingerprint,
                downloadCallbacks: downloadCallbacks)
```

Change both to:

```swift
                ioCallbacks: opened.callbacks, fingerprint: fingerprint,
                downloadCallbacks: downloadCallbacks, syncClock: syncClock)
```

And replace the probe-loop seed:

```swift
        var lastResult = RunResult(
            rc: Int32(LIBDC_STATUS_IO), serial: 0, firmware: 0, errorMessage: "")
```

with:

```swift
        var lastResult = RunResult(
            rc: Int32(LIBDC_STATUS_IO), serial: 0, firmware: 0,
            clockSyncStatus: "not_requested", errorMessage: "")
```

- [ ] **Step 7: Compile the darwin binding**

Run: `bash "$SCRATCH/build_macos.sh"`
Expected: `Built build/macos/Build/Products/Debug/submersion.app`. Fix any Swift error before continuing (typical slip: a `runOnce` call missing `syncClock:`).

- [ ] **Step 8: Commit**

```bash
cd "$R" && git add packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart packages/libdivecomputer_plugin/ios/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/macos/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt packages/libdivecomputer_plugin/linux/dive_computer_api.g.h packages/libdivecomputer_plugin/linux/dive_computer_api.g.cc packages/libdivecomputer_plugin/windows/dive_computer_api.g.h packages/libdivecomputer_plugin/windows/dive_computer_api.g.cc packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart packages/libdivecomputer_plugin/test/dive_computer_service_test.dart packages/libdivecomputer_plugin/test/serial_transport_test.dart packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift && git commit -m "feat(dive-computer): clock sync flag and status over pigeon, darwin binding (#1216)"
```

---

### Task 4: Android binding, in-process BLE and the `:dc` serial process

**Files:**
- Create: `$P/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcDownloadInfo.kt`
- Create: `$P/android/src/test/kotlin/com/submersion/libdivecomputer/LibdcDownloadInfoTest.kt`
- Modify: `$P/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` (lines 36 to 47)
- Modify: `$P/android/src/main/cpp/libdc_jni.cpp` (signature around line 664, call around line 827)
- Modify: `$P/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`
- Modify: `$P/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRequest.kt`
- Modify: `$P/android/src/main/aidl/com/submersion/libdivecomputer/IDiveDownloadCallback.aidl`
- Modify: `$P/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`
- Modify: `$P/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadClient.kt`

**Interfaces:**
- Consumes: the Kotlin generated signatures from Task 3; `libdc_download_run` from Task 2.
- Produces (Kotlin): `internal fun libdcClockSyncStatusName(status: Int): String`; `internal fun libdcUnsignedOrNull(value: Int): String?`; `LibdcWrapper.nativeDownloadRun(sessionPtr, vendor, product, model, transport, ioHandler, devName, fingerprint, syncClock: Boolean, downloadCallback, errorBuf, infoOut: IntArray): Int` where `infoOut` has three slots: serial, firmware, clock sync status code.
- Produces (AIDL): `void onComplete(long totalDives, String serialNumber, String firmwareVersion, String clockSyncStatus);` with nullable strings.

- [ ] **Step 1: Write the failing JVM test for the name twin**

Create `$P/android/src/test/kotlin/com/submersion/libdivecomputer/LibdcDownloadInfoTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins [libdcClockSyncStatusName] to `libdc_clock_sync_status_t` in
 * `macos/Classes/libdc_wrapper.h`. The C table is checked against the enum by
 * `test/native/test_event_type_names.c`; this JVM twin cannot see the header,
 * so the values are spelled out here and must be kept in step.
 */
class LibdcDownloadInfoTest {
    @Test
    fun clockSyncStatusNamesFollowTheCEnum() {
        assertEquals("not_requested", libdcClockSyncStatusName(0))
        assertEquals("synced", libdcClockSyncStatusName(1))
        assertEquals("unsupported", libdcClockSyncStatusName(2))
        assertEquals("failed", libdcClockSyncStatusName(3))
        assertEquals("unknown", libdcClockSyncStatusName(4))
        assertEquals("unknown", libdcClockSyncStatusName(-1))
    }

    @Test
    fun deviceInfoIsFormattedUnsignedAndZeroMeansAbsent() {
        assertNull(libdcUnsignedOrNull(0))
        assertEquals("74691", libdcUnsignedOrNull(74691))
        // A serial above 2^31 arrives as a negative Int through JNI.
        assertEquals("4294967295", libdcUnsignedOrNull(-1))
    }
}
```

- [ ] **Step 2: Implement the Kotlin twin**

Create `$P/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcDownloadInfo.kt`:

```kotlin
package com.submersion.libdivecomputer

/**
 * Wire name of the clock sync outcome reported by `libdc_download_run`
 * (issue #1216): the JVM twin of `libdc_clock_sync_status_name` in the C
 * wrapper, which every other platform calls directly. Kept in Kotlin because
 * the `:dc` process and the JVM unit tests both need it without a native
 * call. Pinned to `libdc_clock_sync_status_t` by [LibdcDownloadInfoTest].
 */
internal fun libdcClockSyncStatusName(status: Int): String = when (status) {
    0 -> "not_requested"
    1 -> "synced"
    2 -> "unsupported"
    3 -> "failed"
    else -> "unknown"
}

/**
 * Formats a device serial or firmware number the way the other bindings do
 * (decimal, unsigned), or null when libdivecomputer reported none. The value
 * crosses JNI as a signed Int, so a high serial arrives negative.
 */
internal fun libdcUnsignedOrNull(value: Int): String? =
    if (value == 0) null else (value.toLong() and 0xFFFFFFFFL).toString()
```

- [ ] **Step 3: Widen the JNI entry point**

In `$P/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` replace:

```kotlin
    external fun nativeDownloadRun(
        sessionPtr: Long,
        vendor: String,
        product: String,
        model: Int,
        transport: Int,
        ioHandler: IoHandler,
        devName: String?,
        fingerprint: ByteArray?,
        downloadCallback: DownloadCallback,
        errorBuf: ByteArray
    ): Int
```

with:

```kotlin
    // infoOut receives three slots after the run: device serial, firmware
    // version, and the clock sync status code (libdc_clock_sync_status_t).
    external fun nativeDownloadRun(
        sessionPtr: Long,
        vendor: String,
        product: String,
        model: Int,
        transport: Int,
        ioHandler: IoHandler,
        devName: String?,
        fingerprint: ByteArray?,
        syncClock: Boolean,
        downloadCallback: DownloadCallback,
        errorBuf: ByteArray,
        infoOut: IntArray
    ): Int
```

In `$P/android/src/main/cpp/libdc_jni.cpp` replace the JNI signature:

```cpp
    jstring devName,
    jbyteArray fingerprint,
    jobject downloadCallback,
    jbyteArray errorBuf) {
```

with:

```cpp
    jstring devName,
    jbyteArray fingerprint,
    jboolean syncClock,
    jobject downloadCallback,
    jbyteArray errorBuf,
    jintArray infoOut) {
```

Replace the call (the Task 2 placeholder form):

```cpp
    // Run the download.
    char error_buf[256] = {0};
    int result = libdc_download_run(
        session,
        vendorStr, productStr,
        static_cast<unsigned int>(model),
        static_cast<unsigned int>(transport),
        &io_callbacks,
        fp_data, fp_size,
        0,
        &dl_callbacks,
        nullptr, nullptr, nullptr,
        error_buf, sizeof(error_buf));
```

with:

```cpp
    // Run the download.
    char error_buf[256] = {0};
    unsigned int serial_out = 0;
    unsigned int firmware_out = 0;
    libdc_clock_sync_status_t clock_sync_out = LIBDC_CLOCK_SYNC_NOT_REQUESTED;
    int result = libdc_download_run(
        session,
        vendorStr, productStr,
        static_cast<unsigned int>(model),
        static_cast<unsigned int>(transport),
        &io_callbacks,
        fp_data, fp_size,
        syncClock == JNI_TRUE ? 1 : 0,
        &dl_callbacks,
        &serial_out, &firmware_out, &clock_sync_out,
        error_buf, sizeof(error_buf));
```

And after the block that copies `error_buf` into `errorBuf` (ending with `reinterpret_cast<const jbyte *>(error_buf));` and its closing `}`), add:

```cpp

    // Device info and the clock sync outcome, in the slot order the Kotlin
    // side reads: serial, firmware, clock sync status code (issue #1216).
    if (infoOut != nullptr && env->GetArrayLength(infoOut) >= 3) {
        jint info[3] = {
            static_cast<jint>(serial_out),
            static_cast<jint>(firmware_out),
            static_cast<jint>(clock_sync_out),
        };
        env->SetIntArrayRegion(infoOut, 0, 3, info);
    }
```

- [ ] **Step 4: Thread the flag through the in-process BLE path**

In `$P/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`:

Replace the `startDownload` head and its serial request:

```kotlin
    override fun startDownload(
        device: DiscoveredDevice,
        fingerprint: String?,
        callback: (Result<Unit>) -> Unit
    ) {
        callback(Result.success(Unit))

        if (device.transport == TransportType.SERIAL || device.transport == TransportType.USB) {
            // Serial-over-USB runs in the :dc process so a native libdivecomputer
            // crash takes down only that process, not the app (issue #318). No
            // in-process fallback.
            serialDownloadActive = true
            serialDownloadClient.start(
                SerialDownloadRequest(
                    vendor = device.vendor,
                    product = device.product,
                    model = device.model,
                    name = device.name,
                    fingerprint = decodeFingerprint(fingerprint),
                )
            )
            return
        }
```

with:

```kotlin
    override fun startDownload(
        device: DiscoveredDevice,
        fingerprint: String?,
        syncClock: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        callback(Result.success(Unit))

        if (device.transport == TransportType.SERIAL || device.transport == TransportType.USB) {
            // Serial-over-USB runs in the :dc process so a native libdivecomputer
            // crash takes down only that process, not the app (issue #318). No
            // in-process fallback.
            serialDownloadActive = true
            serialDownloadClient.start(
                SerialDownloadRequest(
                    vendor = device.vendor,
                    product = device.product,
                    model = device.model,
                    name = device.name,
                    fingerprint = decodeFingerprint(fingerprint),
                    syncClock = syncClock,
                )
            )
            return
        }
```

Replace `performDownload(device, fingerprint)` inside the executor's `try` with `performDownload(device, fingerprint, syncClock)`.

Replace the `performDownload` signature:

```kotlin
    private fun performDownload(device: DiscoveredDevice, fingerprint: String? = null, isRetry: Boolean = false) {
```

with:

```kotlin
    private fun performDownload(
        device: DiscoveredDevice,
        fingerprint: String? = null,
        syncClock: Boolean = false,
        isRetry: Boolean = false
    ) {
```

and its BLE dispatch `performBleDownload(device, sessionPtr, fingerprint, isRetry)` with `performBleDownload(device, sessionPtr, fingerprint, syncClock, isRetry)`.

Replace the `performBleDownload` signature:

```kotlin
    private fun performBleDownload(
        device: DiscoveredDevice,
        sessionPtr: Long,
        fingerprint: String?,
        isRetry: Boolean
    ) {
```

with:

```kotlin
    private fun performBleDownload(
        device: DiscoveredDevice,
        sessionPtr: Long,
        fingerprint: String?,
        syncClock: Boolean,
        isRetry: Boolean
    ) {
```

Replace the BLE native call:

```kotlin
        val errorBuf = ByteArray(256)
        NativeLogger.d(TAG, "LDC", "nativeDownloadRun: vendor=${device.vendor} product=${device.product} model=${device.model} name=${device.name}")
        val result = try {
            LibdcWrapper.nativeDownloadRun(
                sessionPtr,
                device.vendor, device.product,
                device.model.toInt(), LIBDC_TRANSPORT_BLE,
                bleStream, device.name,
                fingerprintBytes,
                downloadCallback, errorBuf
            )
```

with:

```kotlin
        val errorBuf = ByteArray(256)
        val infoOut = IntArray(3)
        NativeLogger.d(TAG, "LDC", "nativeDownloadRun: vendor=${device.vendor} product=${device.product} model=${device.model} name=${device.name} syncClock=$syncClock")
        val result = try {
            LibdcWrapper.nativeDownloadRun(
                sessionPtr,
                device.vendor, device.product,
                device.model.toInt(), LIBDC_TRANSPORT_BLE,
                bleStream, device.name,
                fingerprintBytes, syncClock,
                downloadCallback, errorBuf, infoOut
            )
```

Replace the BLE completion post:

```kotlin
        if (result == 0) {
            mainHandler.post { flutterApi.onDownloadComplete(0, null, null) { } }
        } else if (result != LIBDC_STATUS_CANCELLED) {
```

with:

```kotlin
        if (result == 0) {
            // Serial and firmware were never reported from Android before
            // this; they ride the same out-array as the clock sync outcome.
            val serial = libdcUnsignedOrNull(infoOut[0])
            val firmware = libdcUnsignedOrNull(infoOut[1])
            val clockSync = libdcClockSyncStatusName(infoOut[2])
                .takeIf { it != "not_requested" }
            NativeLogger.i(TAG, "LDC", "Device info: serial=$serial firmware=$firmware clockSync=${clockSync ?: "not_requested"}")
            mainHandler.post {
                flutterApi.onDownloadComplete(0, serial, firmware, clockSync) { }
            }
        } else if (result != LIBDC_STATUS_CANCELLED) {
```

Replace the stale-bond retry `performDownload(device, fingerprint, isRetry = true)` with `performDownload(device, fingerprint, syncClock, isRetry = true)`.

The guarded, unreachable in-process serial path must still compile. Replace its signature:

```kotlin
    private fun performUsbSerialDownload(
        device: DiscoveredDevice,
        sessionPtr: Long,
        fingerprint: String?
    ) {
```

with:

```kotlin
    private fun performUsbSerialDownload(
        device: DiscoveredDevice,
        sessionPtr: Long,
        fingerprint: String?,
        syncClock: Boolean = false
    ) {
```

Inside it, replace:

```kotlin
            val errorBuf = ByteArray(256)
            var thrownMsg: String? = null
```

with:

```kotlin
            val errorBuf = ByteArray(256)
            val infoOut = IntArray(3)
            var thrownMsg: String? = null
```

and its native call arguments:

```kotlin
                    stream, device.name,
                    fingerprintBytes,
                    downloadCallback, errorBuf
                )
```

with:

```kotlin
                    stream, device.name,
                    fingerprintBytes, syncClock,
                    downloadCallback, errorBuf, infoOut
                )
```

and its completion `mainHandler.post { flutterApi.onDownloadComplete(0, null, null) { } }` with `mainHandler.post { flutterApi.onDownloadComplete(0, null, null, null) { } }`.

- [ ] **Step 5: Carry the flag into the `:dc` process and the status back**

Replace the whole of `$P/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRequest.kt` with:

```kotlin
package com.submersion.libdivecomputer

import android.os.Parcel
import android.os.Parcelable

/** The serial-download request marshaled from the main process into :dc (#318). */
class SerialDownloadRequest(
    val vendor: String,
    val product: String,
    val model: Long,
    val name: String?,
    val fingerprint: ByteArray?,
    /** Set the computer's clock after a successful download (issue #1216). */
    val syncClock: Boolean = false,
) : Parcelable {

    constructor(parcel: Parcel) : this(
        vendor = parcel.readString() ?: "",
        product = parcel.readString() ?: "",
        model = parcel.readLong(),
        name = parcel.readString(),
        fingerprint = parcel.createByteArray(),
        syncClock = parcel.readInt() != 0,
    )

    override fun writeToParcel(dest: Parcel, flags: Int) {
        dest.writeString(vendor)
        dest.writeString(product)
        dest.writeLong(model)
        dest.writeString(name)
        dest.writeByteArray(fingerprint)
        dest.writeInt(if (syncClock) 1 else 0)
    }

    override fun describeContents(): Int = 0

    companion object CREATOR : Parcelable.Creator<SerialDownloadRequest> {
        override fun createFromParcel(parcel: Parcel) = SerialDownloadRequest(parcel)
        override fun newArray(size: Int): Array<SerialDownloadRequest?> = arrayOfNulls(size)
    }
}
```

In `$P/android/src/main/aidl/com/submersion/libdivecomputer/IDiveDownloadCallback.aidl` replace:

```aidl
    void onComplete(long totalDives);
```

with:

```aidl
    // Strings are nullable: null serial/firmware when the device reported
    // none, null clockSyncStatus when no sync was requested (issue #1216).
    void onComplete(long totalDives, String serialNumber, String firmwareVersion, String clockSyncStatus);
```

In `$P/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`, after `var lastErrorMsg = ""` add:

```kotlin
        var lastInfo = IntArray(3)
```

Replace:

```kotlin
            val errorBuf = ByteArray(256)
            var thrownMsg: String? = null
            NativeTrace.d("nativeDownloadRun begin vendor=${request.vendor} product=${request.product} model=${request.model}")
            val result = try {
                LibdcWrapper.nativeDownloadRun(
                    session, request.vendor, request.product,
                    request.model.toInt(), RUNNER_LIBDC_TRANSPORT_SERIAL,
                    stream, request.name, fingerprintBytes, downloadCallback, errorBuf
                )
```

with:

```kotlin
            val errorBuf = ByteArray(256)
            val infoOut = IntArray(3)
            var thrownMsg: String? = null
            NativeTrace.d("nativeDownloadRun begin vendor=${request.vendor} product=${request.product} model=${request.model} syncClock=${request.syncClock}")
            val result = try {
                LibdcWrapper.nativeDownloadRun(
                    session, request.vendor, request.product,
                    request.model.toInt(), RUNNER_LIBDC_TRANSPORT_SERIAL,
                    stream, request.name, fingerprintBytes, request.syncClock,
                    downloadCallback, errorBuf, infoOut
                )
```

After `lastResult = result` in that loop add `lastInfo = infoOut`.

Replace the completion branch:

```kotlin
            lastResult == 0 || lastResult == RUNNER_LIBDC_STATUS_CANCELLED ->
                cb.onComplete(divesToFlush.size.toLong())
```

with:

```kotlin
            lastResult == 0 || lastResult == RUNNER_LIBDC_STATUS_CANCELLED ->
                cb.onComplete(
                    divesToFlush.size.toLong(),
                    libdcUnsignedOrNull(lastInfo[0]),
                    libdcUnsignedOrNull(lastInfo[1]),
                    libdcClockSyncStatusName(lastInfo[2]).takeIf { it != "not_requested" },
                )
```

In `$P/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadClient.kt` replace:

```kotlin
        override fun onComplete(totalDives: Long) {
            finish()
            mainHandler.post { flutterApi.onDownloadComplete(totalDives, null, null) { } }
        }
```

with:

```kotlin
        override fun onComplete(
            totalDives: Long,
            serialNumber: String?,
            firmwareVersion: String?,
            clockSyncStatus: String?,
        ) {
            finish()
            mainHandler.post {
                flutterApi.onDownloadComplete(
                    totalDives, serialNumber, firmwareVersion, clockSyncStatus
                ) { }
            }
        }
```

- [ ] **Step 6: Build the APK and run the JVM tests**

Run: `bash "$SCRATCH/build_apk.sh"`
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk` (compiles the Kotlin, the AIDL stubs and the JNI). If the build reports a bare `26.0.2.1` from Gradle, the default JDK is too new: prefix the script's flutter line with `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`.

Then run the JVM tests (gradlew exists only after that APK build):

```bash
cd "$R/android" && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --tests "com.submersion.libdivecomputer.LibdcDownloadInfoTest"
```

Expected: `BUILD SUCCESSFUL`. Control: rerun with `--tests "com.submersion.libdivecomputer.NoSuchTest"` and confirm Gradle fails with `No tests found for given includes`, which proves the positive run executed the new class.

- [ ] **Step 7: Commit**

```bash
cd "$R" && git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcDownloadInfo.kt packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/LibdcDownloadInfoTest.kt packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRequest.kt packages/libdivecomputer_plugin/android/src/main/aidl/com/submersion/libdivecomputer/IDiveDownloadCallback.aidl packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadClient.kt && git commit -m "feat(android): clock sync plus serial and firmware on completion (#1216)"
```

---

### Task 5: Linux and Windows bindings

These cannot be compiled on the development Mac. Make the edits exactly as written, re-read each changed call for balanced parentheses, and let the Linux and Windows CI jobs confirm on push.

**Files:**
- Modify: `$P/linux/dive_computer_host_api_impl.cc`
- Modify: `$P/windows/dive_computer_host_api_impl.h` (lines 41 to 44 and 60 to 61)
- Modify: `$P/windows/dive_computer_host_api_impl.cc`

**Interfaces:**
- Consumes: the GObject and C++ generated signatures from Task 3; `libdc_download_run` from Task 2.

- [ ] **Step 1: Linux thread data and handler**

In `$P/linux/dive_computer_host_api_impl.cc` replace:

```cpp
struct DownloadThreadData {
  HostApiContext* ctx;
  gchar* vendor;
  gchar* product;
  guint32 model;
  gchar* address;
  gchar* fingerprint;
  LibdivecomputerPluginTransportType transport;
};
```

with:

```cpp
struct DownloadThreadData {
  HostApiContext* ctx;
  gchar* vendor;
  gchar* product;
  guint32 model;
  gchar* address;
  gchar* fingerprint;
  LibdivecomputerPluginTransportType transport;
  // Set the device clock after a successful download (issue #1216).
  gboolean sync_clock;
};
```

Replace the handler head:

```cpp
static void handle_start_download(
    LibdivecomputerPluginDiscoveredDevice* device,
    const gchar* fingerprint,
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data) {
```

with:

```cpp
static void handle_start_download(
    LibdivecomputerPluginDiscoveredDevice* device,
    const gchar* fingerprint,
    gboolean sync_clock,
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data) {
```

and after `td->fingerprint = (fingerprint != NULL) ? g_strdup(fingerprint) : NULL;` add:

```cpp
  td->sync_clock = sync_clock;
```

- [ ] **Step 2: Linux thread body**

Replace:

```cpp
  unsigned int serial_number = 0;
  unsigned int firmware_version = 0;
  char error_buf[256] = {0};
```

with:

```cpp
  unsigned int serial_number = 0;
  unsigned int firmware_version = 0;
  libdc_clock_sync_status_t clock_sync = LIBDC_CLOCK_SYNC_NOT_REQUESTED;
  char error_buf[256] = {0};
```

Each of the four `libdc_download_run(` calls currently has (Task 2 form):

```cpp
        fp_data, fp_size,
        0,
        &dl_callbacks,
        &serial_number, &firmware_version, nullptr,
        error_buf, sizeof(error_buf));
```

Change every one to:

```cpp
        fp_data, fp_size,
        td->sync_clock ? 1 : 0,
        &dl_callbacks,
        &serial_number, &firmware_version, &clock_sync,
        error_buf, sizeof(error_buf));
```

The two probe-loop calls (USBHID and serial) reset `serial_number = 0; firmware_version = 0;` before the call; add `clock_sync = LIBDC_CLOCK_SYNC_NOT_REQUESTED;` on the line after each `firmware_version = 0;` (two places).

Replace the completion block:

```cpp
    struct CompleteData {
        LibdivecomputerPluginDiveComputerFlutterApi* api;
        gchar* serial;
        gchar* firmware;
    };
    auto* cd = new CompleteData{ctx->flutter_api,
                                g_strdup(serial_str), g_strdup(firmware_str)};
    g_idle_add([](gpointer data) -> gboolean {
        auto* d = static_cast<CompleteData*>(data);
        libdivecomputer_plugin_dive_computer_flutter_api_on_download_complete(
            d->api, 0, d->serial, d->firmware,
            nullptr, nullptr, nullptr);
        g_free(d->serial);
        g_free(d->firmware);
        delete d;
        return G_SOURCE_REMOVE;
    }, cd);
```

with:

```cpp
    // Null means no sync was requested, so the Dart side shows no line.
    gchar* clock_sync_str = (clock_sync != LIBDC_CLOCK_SYNC_NOT_REQUESTED)
        ? g_strdup(libdc_clock_sync_status_name(clock_sync)) : nullptr;

    struct CompleteData {
        LibdivecomputerPluginDiveComputerFlutterApi* api;
        gchar* serial;
        gchar* firmware;
        gchar* clock_sync;
    };
    auto* cd = new CompleteData{ctx->flutter_api,
                                g_strdup(serial_str), g_strdup(firmware_str),
                                g_strdup(clock_sync_str)};
    g_idle_add([](gpointer data) -> gboolean {
        auto* d = static_cast<CompleteData*>(data);
        libdivecomputer_plugin_dive_computer_flutter_api_on_download_complete(
            d->api, 0, d->serial, d->firmware, d->clock_sync,
            nullptr, nullptr, nullptr);
        g_free(d->serial);
        g_free(d->firmware);
        g_free(d->clock_sync);
        delete d;
        return G_SOURCE_REMOVE;
    }, cd);
    g_free(clock_sync_str);
```

(`g_strdup(nullptr)` returns NULL and `g_free(NULL)` is a no-op, matching how `serial_str` is already handled.)

- [ ] **Step 3: Windows header**

In `$P/windows/dive_computer_host_api_impl.h` replace:

```cpp
  void StartDownload(
      const DiscoveredDevice& device,
      const std::string* fingerprint,
      std::function<void(std::optional<FlutterError> reply)> result) override;
```

with:

```cpp
  void StartDownload(
      const DiscoveredDevice& device,
      const std::string* fingerprint,
      bool sync_clock,
      std::function<void(std::optional<FlutterError> reply)> result) override;
```

and:

```cpp
  void PerformDownload(const DiscoveredDevice& device,
                       const std::optional<std::string>& fingerprint = std::nullopt);
```

with:

```cpp
  void PerformDownload(const DiscoveredDevice& device,
                       const std::optional<std::string>& fingerprint = std::nullopt,
                       bool sync_clock = false);
```

- [ ] **Step 4: Windows source**

In `$P/windows/dive_computer_host_api_impl.cc` replace:

```cpp
void DiveComputerHostApiImpl::StartDownload(
    const DiscoveredDevice& device,
    const std::string* fingerprint,
    std::function<void(std::optional<FlutterError> reply)> result) {
```

with:

```cpp
void DiveComputerHostApiImpl::StartDownload(
    const DiscoveredDevice& device,
    const std::string* fingerprint,
    bool sync_clock,
    std::function<void(std::optional<FlutterError> reply)> result) {
```

and the thread launch:

```cpp
    download_thread_ = std::thread(
        [this, dev = std::move(device_copy), fp = std::move(fp_copy)]() {
            PerformDownload(dev, fp);
        });
```

with:

```cpp
    download_thread_ = std::thread(
        [this, dev = std::move(device_copy), fp = std::move(fp_copy), sync_clock]() {
            PerformDownload(dev, fp, sync_clock);
        });
```

Replace:

```cpp
void DiveComputerHostApiImpl::PerformDownload(
    const DiscoveredDevice& device,
    const std::optional<std::string>& fingerprint) {
```

with:

```cpp
void DiveComputerHostApiImpl::PerformDownload(
    const DiscoveredDevice& device,
    const std::optional<std::string>& fingerprint,
    bool sync_clock) {
```

Replace:

```cpp
    int rc = -1;
    unsigned int serial = 0;
    unsigned int firmware = 0;
    char error_buf[256] = {};
```

with:

```cpp
    int rc = -1;
    unsigned int serial = 0;
    unsigned int firmware = 0;
    libdc_clock_sync_status_t clock_sync = LIBDC_CLOCK_SYNC_NOT_REQUESTED;
    char error_buf[256] = {};
```

Both `libdc_download_run(` calls currently have (Task 2 form):

```cpp
                static_cast<unsigned int>(fp_bytes.size()),
                0,
                &dl_callbacks,
                &serial, &firmware, nullptr,
                error_buf, sizeof(error_buf));
```

Change both to:

```cpp
                static_cast<unsigned int>(fp_bytes.size()),
                sync_clock ? 1 : 0,
                &dl_callbacks,
                &serial, &firmware, &clock_sync,
                error_buf, sizeof(error_buf));
```

In the serial candidate loop, after `firmware = 0;` (the line before `memset(error_buf, 0, sizeof(error_buf));`) add `clock_sync = LIBDC_CLOCK_SYNC_NOT_REQUESTED;`.

Replace the completion:

```cpp
    std::optional<std::string> firmware_str =
        (firmware > 0) ? std::optional<std::string>(std::to_string(firmware))
                       : std::nullopt;

    // Report completion or error.
    if (rc == 0 || rc == LIBDC_STATUS_CANCELLED) {
        flutter_api_->OnDownloadComplete(
            0,
            serial_str ? &*serial_str : nullptr,
            firmware_str ? &*firmware_str : nullptr,
            [] {}, [](const auto&) {});
```

with:

```cpp
    std::optional<std::string> firmware_str =
        (firmware > 0) ? std::optional<std::string>(std::to_string(firmware))
                       : std::nullopt;
    // Null means no sync was requested, so the Dart side shows no line.
    std::optional<std::string> clock_sync_str =
        (clock_sync != LIBDC_CLOCK_SYNC_NOT_REQUESTED)
            ? std::optional<std::string>(libdc_clock_sync_status_name(clock_sync))
            : std::nullopt;

    // Report completion or error.
    if (rc == 0 || rc == LIBDC_STATUS_CANCELLED) {
        flutter_api_->OnDownloadComplete(
            0,
            serial_str ? &*serial_str : nullptr,
            firmware_str ? &*firmware_str : nullptr,
            clock_sync_str ? &*clock_sync_str : nullptr,
            [] {}, [](const auto&) {});
```

- [ ] **Step 5: Check the edits**

Run: `grep -n "libdc_download_run(" -A12 "$P/linux/dive_computer_host_api_impl.cc" | grep -c "&clock_sync,"` and expect `4`; the same grep on the Windows file expects `2`. Run `grep -n "nullptr,$" "$P/linux/dive_computer_host_api_impl.cc" "$P/windows/dive_computer_host_api_impl.cc" | grep -i "firmware"` and expect no output (no placeholder left).

- [ ] **Step 6: Commit**

```bash
cd "$R" && git add packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.h packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc && git commit -m "feat(linux,windows): thread clock sync through the download bindings (#1216)"
```

---

### Task 6: Clock sync settings model

**Files:**
- Create: `$R/lib/features/dive_computer/domain/entities/clock_sync.dart`
- Create: `$R/test/features/dive_computer/domain/entities/clock_sync_test.dart`

**Interfaces:**
- Produces:

```dart
enum ClockSyncOverride { inherit, always, never }
enum ClockSyncSupport { unknown, supported, unsupported }
enum ClockSyncStatus { notRequested, synced, unsupported, failed }
ClockSyncStatus.fromWireName(String? name)  // static; unknown or null -> notRequested
class ClockSyncSettings extends Equatable {
  const ClockSyncSettings({bool globalEnabled = false, Map<String, ClockSyncOverride> overrides = const {}, Map<String, ClockSyncSupport> support = const {}});
  bool get globalEnabled; Map<String, ClockSyncOverride> get overrides; Map<String, ClockSyncSupport> get support;
  ClockSyncOverride overrideFor(String computerId);
  ClockSyncSupport supportFor(String computerId);
  bool resolve(String? computerId);
  ClockSyncSettings withGlobalEnabled(bool value);
  ClockSyncSettings withOverride(String computerId, ClockSyncOverride value);
  ClockSyncSettings withSupport(String computerId, ClockSyncSupport value);
  ClockSyncSettings withSupportFromStatus(String computerId, ClockSyncStatus status);
  ClockSyncSettings without(String computerId);
}
```

- [ ] **Step 1: Write the failing tests**

Create `$R/test/features/dive_computer/domain/entities/clock_sync_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';

void main() {
  group('ClockSyncStatus.fromWireName', () {
    test('parses the four wire names', () {
      expect(ClockSyncStatus.fromWireName('synced'), ClockSyncStatus.synced);
      expect(
        ClockSyncStatus.fromWireName('unsupported'),
        ClockSyncStatus.unsupported,
      );
      expect(ClockSyncStatus.fromWireName('failed'), ClockSyncStatus.failed);
      expect(
        ClockSyncStatus.fromWireName('not_requested'),
        ClockSyncStatus.notRequested,
      );
    });

    test('null and unknown names read as not requested', () {
      expect(ClockSyncStatus.fromWireName(null), ClockSyncStatus.notRequested);
      expect(
        ClockSyncStatus.fromWireName('something-new'),
        ClockSyncStatus.notRequested,
      );
    });
  });

  group('ClockSyncSettings.resolve', () {
    test('defaults to off everywhere', () {
      const settings = ClockSyncSettings();
      expect(settings.globalEnabled, isFalse);
      expect(settings.resolve('c1'), isFalse);
      expect(settings.resolve(null), isFalse);
    });

    test('an unsaved device follows the global switch only', () {
      final settings = const ClockSyncSettings().withGlobalEnabled(true);
      expect(settings.resolve(null), isTrue);
    });

    test('inherit follows the global switch', () {
      final on = const ClockSyncSettings().withGlobalEnabled(true);
      expect(on.overrideFor('c1'), ClockSyncOverride.inherit);
      expect(on.resolve('c1'), isTrue);
      expect(on.withGlobalEnabled(false).resolve('c1'), isFalse);
    });

    test('always wins over a global off', () {
      final settings = const ClockSyncSettings().withOverride(
        'c1',
        ClockSyncOverride.always,
      );
      expect(settings.resolve('c1'), isTrue);
      expect(settings.resolve('c2'), isFalse);
    });

    test('never wins over a global on', () {
      final settings = const ClockSyncSettings()
          .withGlobalEnabled(true)
          .withOverride('c1', ClockSyncOverride.never);
      expect(settings.resolve('c1'), isFalse);
      expect(settings.resolve('c2'), isTrue);
    });

    test('setting inherit removes the stored override', () {
      final settings = const ClockSyncSettings()
          .withOverride('c1', ClockSyncOverride.always)
          .withOverride('c1', ClockSyncOverride.inherit);
      expect(settings.overrides, isEmpty);
    });

    test('a recorded unsupported model still resolves from the switches', () {
      // The flag is still sent; the device answers unsupported again, which
      // is what makes "Check again" trivially correct.
      final settings = const ClockSyncSettings()
          .withGlobalEnabled(true)
          .withSupport('c1', ClockSyncSupport.unsupported);
      expect(settings.resolve('c1'), isTrue);
    });
  });

  group('ClockSyncSettings support', () {
    test('unknown by default and removable', () {
      const settings = ClockSyncSettings();
      expect(settings.supportFor('c1'), ClockSyncSupport.unknown);
      final known = settings.withSupport('c1', ClockSyncSupport.supported);
      expect(known.supportFor('c1'), ClockSyncSupport.supported);
      expect(
        known.withSupport('c1', ClockSyncSupport.unknown).support,
        isEmpty,
      );
    });

    test('synced records supported, unsupported records unsupported', () {
      const settings = ClockSyncSettings();
      expect(
        settings
            .withSupportFromStatus('c1', ClockSyncStatus.synced)
            .supportFor('c1'),
        ClockSyncSupport.supported,
      );
      expect(
        settings
            .withSupportFromStatus('c1', ClockSyncStatus.unsupported)
            .supportFor('c1'),
        ClockSyncSupport.unsupported,
      );
    });

    test('failed and not requested change nothing', () {
      final known = const ClockSyncSettings().withSupport(
        'c1',
        ClockSyncSupport.supported,
      );
      expect(
        identical(
          known.withSupportFromStatus('c1', ClockSyncStatus.failed),
          known,
        ),
        isTrue,
      );
      expect(
        identical(
          known.withSupportFromStatus('c1', ClockSyncStatus.notRequested),
          known,
        ),
        isTrue,
      );
    });
  });

  group('ClockSyncSettings.without', () {
    test('drops both per-computer entries and leaves others alone', () {
      final settings = const ClockSyncSettings()
          .withOverride('c1', ClockSyncOverride.never)
          .withSupport('c1', ClockSyncSupport.supported)
          .withOverride('c2', ClockSyncOverride.always);
      final after = settings.without('c1');
      expect(after.overrideFor('c1'), ClockSyncOverride.inherit);
      expect(after.supportFor('c1'), ClockSyncSupport.unknown);
      expect(after.overrideFor('c2'), ClockSyncOverride.always);
    });
  });

  test('value equality', () {
    expect(
      const ClockSyncSettings().withGlobalEnabled(true),
      const ClockSyncSettings(globalEnabled: true),
    );
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

Run: `cd "$R" && flutter test test/features/dive_computer/domain/entities/clock_sync_test.dart`
Expected: FAIL to compile (`clock_sync.dart` does not exist).

- [ ] **Step 3: Implement the model**

Create `$R/lib/features/dive_computer/domain/entities/clock_sync.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Per-computer choice for the clock sync after a download (issue #1216).
enum ClockSyncOverride { inherit, always, never }

/// What this installation has learned about a computer's model.
enum ClockSyncSupport { unknown, supported, unsupported }

/// Outcome of the clock sync reported on download completion.
enum ClockSyncStatus {
  notRequested,
  synced,
  unsupported,
  failed;

  /// Parses the wire name from the native layer. Null (an older binding that
  /// set nothing) and any unknown name read as [notRequested], so the UI
  /// shows nothing rather than a wrong line.
  static ClockSyncStatus fromWireName(String? name) {
    return switch (name) {
      'synced' => ClockSyncStatus.synced,
      'unsupported' => ClockSyncStatus.unsupported,
      'failed' => ClockSyncStatus.failed,
      _ => ClockSyncStatus.notRequested,
    };
  }
}

/// Installation-local clock sync settings: a global switch, per-computer
/// overrides, and what each computer answered last time.
///
/// Immutable; every setter returns a new value. Maps only hold explicit
/// entries: an absent override means [ClockSyncOverride.inherit] and an
/// absent support entry means [ClockSyncSupport.unknown].
class ClockSyncSettings extends Equatable {
  final bool globalEnabled;
  final Map<String, ClockSyncOverride> overrides;
  final Map<String, ClockSyncSupport> support;

  const ClockSyncSettings({
    this.globalEnabled = false,
    this.overrides = const {},
    this.support = const {},
  });

  ClockSyncOverride overrideFor(String computerId) =>
      overrides[computerId] ?? ClockSyncOverride.inherit;

  ClockSyncSupport supportFor(String computerId) =>
      support[computerId] ?? ClockSyncSupport.unknown;

  /// Whether a download of [computerId] should sync the clock. A device that
  /// is not saved yet (null id) follows the global switch alone. A recorded
  /// unsupported model does not change the answer: the flag is still sent and
  /// the device answers unsupported again, which keeps "Check again" simple.
  bool resolve(String? computerId) {
    if (computerId == null) return globalEnabled;
    return switch (overrideFor(computerId)) {
      ClockSyncOverride.always => true,
      ClockSyncOverride.never => false,
      ClockSyncOverride.inherit => globalEnabled,
    };
  }

  ClockSyncSettings withGlobalEnabled(bool value) => ClockSyncSettings(
    globalEnabled: value,
    overrides: overrides,
    support: support,
  );

  ClockSyncSettings withOverride(String computerId, ClockSyncOverride value) {
    final next = Map<String, ClockSyncOverride>.from(overrides);
    if (value == ClockSyncOverride.inherit) {
      next.remove(computerId);
    } else {
      next[computerId] = value;
    }
    return ClockSyncSettings(
      globalEnabled: globalEnabled,
      overrides: Map.unmodifiable(next),
      support: support,
    );
  }

  ClockSyncSettings withSupport(String computerId, ClockSyncSupport value) {
    final next = Map<String, ClockSyncSupport>.from(support);
    if (value == ClockSyncSupport.unknown) {
      next.remove(computerId);
    } else {
      next[computerId] = value;
    }
    return ClockSyncSettings(
      globalEnabled: globalEnabled,
      overrides: overrides,
      support: Map.unmodifiable(next),
    );
  }

  /// Learns support from a completion status. Only a definite answer counts:
  /// a failed sync says nothing about the model, and returns this instance
  /// unchanged so callers can skip the write.
  ClockSyncSettings withSupportFromStatus(
    String computerId,
    ClockSyncStatus status,
  ) {
    return switch (status) {
      ClockSyncStatus.synced =>
        withSupport(computerId, ClockSyncSupport.supported),
      ClockSyncStatus.unsupported =>
        withSupport(computerId, ClockSyncSupport.unsupported),
      ClockSyncStatus.failed || ClockSyncStatus.notRequested => this,
    };
  }

  /// Drops every entry for [computerId], for when it is deleted.
  ClockSyncSettings without(String computerId) => withOverride(
    computerId,
    ClockSyncOverride.inherit,
  ).withSupport(computerId, ClockSyncSupport.unknown);

  @override
  List<Object?> get props => [globalEnabled, overrides, support];
}
```

- [ ] **Step 4: Run the test to see it pass**

Run: `cd "$R" && flutter test test/features/dive_computer/domain/entities/clock_sync_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Format and commit**

```bash
cd "$R" && dart format . && git add lib/features/dive_computer/domain/entities/clock_sync.dart test/features/dive_computer/domain/entities/clock_sync_test.dart && git commit -m "feat(dive-computer): clock sync settings model (#1216)"
```

---

### Task 7: Preferences store, notifier, provider and root override

**Files:**
- Create: `$R/lib/features/dive_computer/data/clock_sync_preferences.dart`
- Create: `$R/lib/features/dive_computer/presentation/providers/clock_sync_providers.dart`
- Modify: `$R/lib/core/providers/root_overrides.dart`
- Create: `$R/test/features/dive_computer/data/clock_sync_preferences_test.dart`
- Create: `$R/test/features/dive_computer/presentation/providers/clock_sync_providers_test.dart`
- Modify: `$R/test/core/providers/root_overrides_test.dart`

**Interfaces:**
- Consumes: `ClockSyncSettings` and the enums (Task 6); `sharedPreferencesProvider` from `settings_providers.dart`.
- Produces:

```dart
class ClockSyncPreferences {
  static const globalKey = 'dive_computer_clock_sync_enabled';
  static const overridePrefix = 'dive_computer_clock_sync_override.';
  static const supportPrefix = 'dive_computer_clock_sync_support.';
  ClockSyncPreferences(SharedPreferences prefs);
  ClockSyncSettings load();
  Future<void> writeGlobal(bool value);
  Future<void> writeOverride(String computerId, ClockSyncOverride value);
  Future<void> writeSupport(String computerId, ClockSyncSupport value);
  Future<void> forget(String computerId);
}
class ClockSyncSettingsNotifier extends StateNotifier<ClockSyncSettings> {
  ClockSyncSettingsNotifier(ClockSyncPreferences prefs);
  ClockSyncSettingsNotifier.unstored();
  Future<void> setGlobalEnabled(bool value);
  Future<void> setOverride(String computerId, ClockSyncOverride value);
  Future<void> recordSupport(String computerId, ClockSyncStatus status);
  Future<void> clearSupport(String computerId);
  Future<void> forget(String computerId);
}
final clockSyncSettingsNotifierProvider = StateNotifierProvider<ClockSyncSettingsNotifier, ClockSyncSettings>(...);  // unstored by default; rootProviderOverrides installs the stored one
```

- [ ] **Step 1: Write the failing preferences test**

Create `$R/test/features/dive_computer/data/clock_sync_preferences_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ClockSyncPreferences> makePrefs(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    return ClockSyncPreferences(await SharedPreferences.getInstance());
  }

  test('load reads an empty store as the defaults', () async {
    final prefs = await makePrefs({});
    expect(prefs.load(), const ClockSyncSettings());
  });

  test('load reads the global switch and per-computer keys', () async {
    final prefs = await makePrefs({
      'dive_computer_clock_sync_enabled': true,
      'dive_computer_clock_sync_override.c1': 'always',
      'dive_computer_clock_sync_override.c2': 'never',
      'dive_computer_clock_sync_support.c1': 'supported',
      'dive_computer_clock_sync_support.c3': 'unsupported',
      'unrelated_key': 'ignored',
    });
    final settings = prefs.load();
    expect(settings.globalEnabled, isTrue);
    expect(settings.overrideFor('c1'), ClockSyncOverride.always);
    expect(settings.overrideFor('c2'), ClockSyncOverride.never);
    expect(settings.supportFor('c1'), ClockSyncSupport.supported);
    expect(settings.supportFor('c3'), ClockSyncSupport.unsupported);
    expect(settings.overrides.length, 2);
    expect(settings.support.length, 2);
  });

  test('load ignores a value it does not recognise', () async {
    final prefs = await makePrefs({
      'dive_computer_clock_sync_override.c1': 'sometimes',
      'dive_computer_clock_sync_support.c1': 'maybe',
    });
    final settings = prefs.load();
    expect(settings.overrideFor('c1'), ClockSyncOverride.inherit);
    expect(settings.supportFor('c1'), ClockSyncSupport.unknown);
  });

  test('writes round-trip through load', () async {
    final prefs = await makePrefs({});
    await prefs.writeGlobal(true);
    await prefs.writeOverride('c1', ClockSyncOverride.never);
    await prefs.writeSupport('c1', ClockSyncSupport.supported);
    final settings = prefs.load();
    expect(settings.globalEnabled, isTrue);
    expect(settings.overrideFor('c1'), ClockSyncOverride.never);
    expect(settings.supportFor('c1'), ClockSyncSupport.supported);
  });

  test('inherit and unknown remove their keys', () async {
    final prefs = await makePrefs({
      'dive_computer_clock_sync_override.c1': 'always',
      'dive_computer_clock_sync_support.c1': 'supported',
    });
    await prefs.writeOverride('c1', ClockSyncOverride.inherit);
    await prefs.writeSupport('c1', ClockSyncSupport.unknown);
    final raw = await SharedPreferences.getInstance();
    expect(raw.containsKey('dive_computer_clock_sync_override.c1'), isFalse);
    expect(raw.containsKey('dive_computer_clock_sync_support.c1'), isFalse);
  });

  test('forget removes both keys for one computer only', () async {
    final prefs = await makePrefs({
      'dive_computer_clock_sync_override.c1': 'always',
      'dive_computer_clock_sync_support.c1': 'supported',
      'dive_computer_clock_sync_override.c2': 'never',
    });
    await prefs.forget('c1');
    final settings = prefs.load();
    expect(settings.overrideFor('c1'), ClockSyncOverride.inherit);
    expect(settings.supportFor('c1'), ClockSyncSupport.unknown);
    expect(settings.overrideFor('c2'), ClockSyncOverride.never);
  });
}
```

- [ ] **Step 2: Write the failing notifier and provider tests**

Create `$R/test/features/dive_computer/presentation/providers/clock_sync_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClockSyncSettingsNotifier with storage', () {
    late SharedPreferences raw;
    late ClockSyncSettingsNotifier notifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'dive_computer_clock_sync_support.c9': 'unsupported',
      });
      raw = await SharedPreferences.getInstance();
      notifier = ClockSyncSettingsNotifier(ClockSyncPreferences(raw));
    });

    tearDown(() => notifier.dispose());

    test('seeds its state from the store', () {
      expect(notifier.state.supportFor('c9'), ClockSyncSupport.unsupported);
    });

    test('setGlobalEnabled updates state and persists', () async {
      await notifier.setGlobalEnabled(true);
      expect(notifier.state.globalEnabled, isTrue);
      expect(raw.getBool('dive_computer_clock_sync_enabled'), isTrue);
    });

    test('setOverride updates state and persists', () async {
      await notifier.setOverride('c1', ClockSyncOverride.always);
      expect(notifier.state.overrideFor('c1'), ClockSyncOverride.always);
      expect(raw.getString('dive_computer_clock_sync_override.c1'), 'always');
    });

    test('recordSupport keeps a definite answer and ignores failed', () async {
      await notifier.recordSupport('c1', ClockSyncStatus.synced);
      expect(notifier.state.supportFor('c1'), ClockSyncSupport.supported);
      expect(
        raw.getString('dive_computer_clock_sync_support.c1'),
        'supported',
      );

      await notifier.recordSupport('c1', ClockSyncStatus.failed);
      expect(notifier.state.supportFor('c1'), ClockSyncSupport.supported);

      await notifier.recordSupport('c1', ClockSyncStatus.unsupported);
      expect(notifier.state.supportFor('c1'), ClockSyncSupport.unsupported);
    });

    test('clearSupport forgets the answer so the next download asks', () async {
      await notifier.clearSupport('c9');
      expect(notifier.state.supportFor('c9'), ClockSyncSupport.unknown);
      expect(raw.containsKey('dive_computer_clock_sync_support.c9'), isFalse);
    });

    test('forget drops every key for the computer', () async {
      await notifier.setOverride('c9', ClockSyncOverride.never);
      await notifier.forget('c9');
      expect(notifier.state.overrideFor('c9'), ClockSyncOverride.inherit);
      expect(notifier.state.supportFor('c9'), ClockSyncSupport.unknown);
      expect(raw.containsKey('dive_computer_clock_sync_override.c9'), isFalse);
      expect(raw.containsKey('dive_computer_clock_sync_support.c9'), isFalse);
    });
  });

  group('clockSyncSettingsNotifierProvider', () {
    test('defaults to an unstored notifier that still works', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(clockSyncSettingsNotifierProvider).globalEnabled, isFalse);
      await container
          .read(clockSyncSettingsNotifierProvider.notifier)
          .setGlobalEnabled(true);
      expect(container.read(clockSyncSettingsNotifierProvider).globalEnabled, isTrue);
    });
  });
}
```

Extend `$R/test/core/providers/root_overrides_test.dart`: add the imports

```dart
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
```

and this test inside `main()` after the existing one:

```dart
  test('backs the clock sync settings with SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'dive_computer_clock_sync_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final logFileService = LogFileService(logDirectory: '/tmp/submersion-test');

    final container = ProviderContainer(
      overrides: rootProviderOverrides(
        prefs: prefs,
        logFileService: logFileService,
      ).cast(),
    );
    addTearDown(container.dispose);

    expect(container.read(clockSyncSettingsNotifierProvider).globalEnabled, isTrue);
    await container
        .read(clockSyncSettingsNotifierProvider.notifier)
        .setGlobalEnabled(false);
    expect(prefs.getBool('dive_computer_clock_sync_enabled'), isFalse);
  });
```

- [ ] **Step 3: Run the tests to see them fail**

Run: `cd "$R" && flutter test test/features/dive_computer/data/clock_sync_preferences_test.dart test/features/dive_computer/presentation/providers/clock_sync_providers_test.dart test/core/providers/root_overrides_test.dart`
Expected: FAIL to compile (missing files and provider).

- [ ] **Step 4: Implement the preferences store**

Create `$R/lib/features/dive_computer/data/clock_sync_preferences.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';

/// SharedPreferences layout for the clock sync settings (issue #1216).
///
/// Installation-local on purpose: whether a phone with automatic time should
/// set a computer's clock is a property of that phone, not of the diver, so
/// nothing here goes near the settings table or the sync serializer. Keeping
/// it out of `dive_computers` also sidesteps a schema rung and the whole-row
/// upsert the sync import performs on that table.
class ClockSyncPreferences {
  static const globalKey = 'dive_computer_clock_sync_enabled';
  static const overridePrefix = 'dive_computer_clock_sync_override.';
  static const supportPrefix = 'dive_computer_clock_sync_support.';

  final SharedPreferences _prefs;

  ClockSyncPreferences(this._prefs);

  ClockSyncSettings load() {
    final overrides = <String, ClockSyncOverride>{};
    final support = <String, ClockSyncSupport>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(overridePrefix)) {
        final value = _overrideFromName(_prefs.getString(key));
        if (value != ClockSyncOverride.inherit) {
          overrides[key.substring(overridePrefix.length)] = value;
        }
      } else if (key.startsWith(supportPrefix)) {
        final value = _supportFromName(_prefs.getString(key));
        if (value != ClockSyncSupport.unknown) {
          support[key.substring(supportPrefix.length)] = value;
        }
      }
    }
    return ClockSyncSettings(
      globalEnabled: _prefs.getBool(globalKey) ?? false,
      overrides: Map.unmodifiable(overrides),
      support: Map.unmodifiable(support),
    );
  }

  Future<void> writeGlobal(bool value) => _prefs.setBool(globalKey, value);

  Future<void> writeOverride(String computerId, ClockSyncOverride value) {
    final key = '$overridePrefix$computerId';
    return switch (value) {
      ClockSyncOverride.inherit => _prefs.remove(key),
      ClockSyncOverride.always => _prefs.setString(key, 'always'),
      ClockSyncOverride.never => _prefs.setString(key, 'never'),
    };
  }

  Future<void> writeSupport(String computerId, ClockSyncSupport value) {
    final key = '$supportPrefix$computerId';
    return switch (value) {
      ClockSyncSupport.unknown => _prefs.remove(key),
      ClockSyncSupport.supported => _prefs.setString(key, 'supported'),
      ClockSyncSupport.unsupported => _prefs.setString(key, 'unsupported'),
    };
  }

  Future<void> forget(String computerId) async {
    await _prefs.remove('$overridePrefix$computerId');
    await _prefs.remove('$supportPrefix$computerId');
  }

  static ClockSyncOverride _overrideFromName(String? name) => switch (name) {
    'always' => ClockSyncOverride.always,
    'never' => ClockSyncOverride.never,
    _ => ClockSyncOverride.inherit,
  };

  static ClockSyncSupport _supportFromName(String? name) => switch (name) {
    'supported' => ClockSyncSupport.supported,
    'unsupported' => ClockSyncSupport.unsupported,
    _ => ClockSyncSupport.unknown,
  };
}
```

- [ ] **Step 5: Implement the notifier and provider**

Create `$R/lib/features/dive_computer/presentation/providers/clock_sync_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';

/// Holds the installation-local clock sync settings (issue #1216) and writes
/// each change through to SharedPreferences.
///
/// Seeded synchronously from the store so the first frame of the computers
/// list draws the switch in the right position.
class ClockSyncSettingsNotifier extends StateNotifier<ClockSyncSettings> {
  ClockSyncSettingsNotifier(ClockSyncPreferences prefs)
    : _prefs = prefs,
      super(prefs.load());

  /// State with nothing behind it, for a container that has no
  /// SharedPreferences (a widget test, or an early frame). Writes update the
  /// state and are otherwise dropped rather than throwing.
  ClockSyncSettingsNotifier.unstored()
    : _prefs = null,
      super(const ClockSyncSettings());

  final ClockSyncPreferences? _prefs;

  Future<void> setGlobalEnabled(bool value) async {
    state = state.withGlobalEnabled(value);
    await _prefs?.writeGlobal(value);
  }

  Future<void> setOverride(String computerId, ClockSyncOverride value) async {
    state = state.withOverride(computerId, value);
    await _prefs?.writeOverride(computerId, value);
  }

  /// Remembers what the computer answered. Only synced and unsupported are
  /// definite; a failed sync leaves the record untouched.
  Future<void> recordSupport(String computerId, ClockSyncStatus status) async {
    final next = state.withSupportFromStatus(computerId, status);
    if (identical(next, state)) return;
    state = next;
    await _prefs?.writeSupport(computerId, next.supportFor(computerId));
  }

  /// Forgets a recorded answer so the next download asks the device again,
  /// for the "Check again" action after a libdivecomputer update.
  Future<void> clearSupport(String computerId) async {
    state = state.withSupport(computerId, ClockSyncSupport.unknown);
    await _prefs?.writeSupport(computerId, ClockSyncSupport.unknown);
  }

  /// Drops every key for a computer that is being deleted.
  Future<void> forget(String computerId) async {
    state = state.without(computerId);
    await _prefs?.forget(computerId);
  }
}

/// Defaults to an unstored notifier on purpose, like
/// `mediaProvenanceBadgesProvider`: this is watched from the computers list
/// and the device detail page, and `sharedPreferencesProvider` throws unless
/// the root scope overrode it, which would put those pages into an error
/// state in any container without the override. `rootProviderOverrides`
/// installs the stored notifier for the running app.
final clockSyncSettingsNotifierProvider =
    StateNotifierProvider<ClockSyncSettingsNotifier, ClockSyncSettings>(
      (ref) => ClockSyncSettingsNotifier.unstored(),
    );
```

- [ ] **Step 6: Install the stored notifier at the root**

In `$R/lib/core/providers/root_overrides.dart` add the imports:

```dart
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
```

(keep the import block sorted: these two sort before the `settings` imports) and add to the returned list after the `mediaProvenanceBadgesProvider.overrideWith(...)` entry:

```dart
    // Same reasoning as the badges: the default is unstored so pages that
    // watch it never error in a container without prefs; here it gains
    // persistence (issue #1216).
    clockSyncSettingsNotifierProvider.overrideWith(
      (ref) => ClockSyncSettingsNotifier(ClockSyncPreferences(prefs)),
    ),
```

- [ ] **Step 7: Run the tests to see them pass**

Run: `cd "$R" && flutter test test/features/dive_computer/data/clock_sync_preferences_test.dart test/features/dive_computer/presentation/providers/clock_sync_providers_test.dart test/core/providers/root_overrides_test.dart`
Expected: all pass.

- [ ] **Step 8: Format and commit**

```bash
cd "$R" && dart format . && git add lib/features/dive_computer/data/clock_sync_preferences.dart lib/features/dive_computer/presentation/providers/clock_sync_providers.dart lib/core/providers/root_overrides.dart test/features/dive_computer/data/clock_sync_preferences_test.dart test/features/dive_computer/presentation/providers/clock_sync_providers_test.dart test/core/providers/root_overrides_test.dart && git commit -m "feat(dive-computer): installation-local clock sync preferences (#1216)"
```

---

### Task 8: Request the sync from `DownloadNotifier` and keep the result in `DownloadState`

Changing `DiveComputerService`'s signature breaks every `implements pigeon.DiveComputerService` fake at compile time, so this task also updates those five copies and regenerates the mockito mocks.

**Files:**
- Modify: `$R/lib/features/dive_computer/presentation/providers/download_providers.dart`
- Modify (fakes): `$R/test/features/dive_computer/presentation/widgets/download_step_widget_test.dart`, `$R/test/features/dive_computer/presentation/widgets/usb_search_test.dart`, `$R/test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart`, `$R/test/helpers/fake_import_adapter_deps.dart`
- Create: `$R/test/features/dive_computer/presentation/providers/download_notifier_clock_sync_test.dart`

**Interfaces:**
- Consumes: `DiveComputerService.startDownload(..., syncClock:)` and `DownloadCompleteEvent.clockSyncStatus` (Task 3); `ClockSyncStatus` (Task 6); `clockSyncSettingsNotifierProvider` (Task 7).
- Produces: `DownloadState.clockSyncStatus` (`ClockSyncStatus?`), `DownloadState.copyWith({..., ClockSyncStatus? clockSyncStatus, bool clearClockSyncStatus = false})`; `DownloadNotifier({required service, required repository, bool Function()? trimTankPressureAtSurfacing, bool Function(String? computerId)? resolveClockSync})`.

- [ ] **Step 1: Update the four fake services so the tree compiles**

In each of `download_step_widget_test.dart`, `usb_search_test.dart`, `dc_adapter_steps_test.dart` and `test/helpers/fake_import_adapter_deps.dart`, the private `_FakeDiveComputerService` has:

```dart
  @override
  Future<void> startDownload(
    pigeon.DiscoveredDevice device, {
    String? fingerprint,
  }) async {}
```

Change it in all four files to:

```dart
  @override
  Future<void> startDownload(
    pigeon.DiscoveredDevice device, {
    String? fingerprint,
    bool syncClock = false,
  }) async {}
```

and:

```dart
  @override
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
  ) {}
```

to:

```dart
  @override
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
    String? clockSyncStatus,
  ) {}
```

Confirm with `grep -rL "bool syncClock = false" test/features/dive_computer/presentation/widgets/download_step_widget_test.dart test/features/dive_computer/presentation/widgets/usb_search_test.dart test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart test/helpers/fake_import_adapter_deps.dart` printing nothing.

- [ ] **Step 2: Regenerate the mockito mocks**

Run: `bash "$SCRATCH/codegen.sh"`
Expected: finishes without error; the generated `MockDiveComputerService.startDownload` now has a `syncClock` named parameter. Existing stubs written as `when(mockService.startDownload(any, fingerprint: anyNamed('fingerprint')))` keep matching because the generated mock carries the same `syncClock = false` default and every existing test resolves to false.

- [ ] **Step 3: Write the failing notifier test**

Create `$R/test/features/dive_computer/presentation/providers/download_notifier_clock_sync_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

@GenerateMocks([DiveComputerRepository, DiveComputerService])
import 'download_notifier_clock_sync_test.mocks.dart';

void main() {
  late MockDiveComputerRepository mockRepository;
  late MockDiveComputerService mockService;

  final device = DiscoveredDevice(
    id: 'device-1',
    name: 'Perdix',
    connectionType: DeviceConnectionType.ble,
    address: '00:11:22:33:44:55',
    discoveredAt: DateTime(2026, 1, 1),
  );

  final computer = DiveComputer(
    id: 'computer-1',
    name: 'My Perdix',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockRepository = MockDiveComputerRepository();
    mockService = MockDiveComputerService();
    when(mockService.downloadEvents).thenAnswer((_) => const Stream.empty());
    when(
      mockService.startDownload(
        any,
        fingerprint: anyNamed('fingerprint'),
        syncClock: anyNamed('syncClock'),
      ),
    ).thenAnswer((_) async {});
  });

  bool capturedSyncClock() {
    return verify(
          mockService.startDownload(
            any,
            fingerprint: anyNamed('fingerprint'),
            syncClock: captureAnyNamed('syncClock'),
          ),
        ).captured.single
        as bool;
  }

  group('startDownload resolves the clock sync flag', () {
    test('asks the resolver with the saved computer id', () async {
      String? seenId;
      final notifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
        resolveClockSync: (id) {
          seenId = id;
          return true;
        },
      );
      addTearDown(notifier.dispose);

      await notifier.startDownload(device, computer: computer);

      expect(seenId, 'computer-1');
      expect(capturedSyncClock(), isTrue);
    });

    test('asks with a null id for a device that is not saved yet', () async {
      String? seenId = 'unset';
      final notifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
        resolveClockSync: (id) {
          seenId = id;
          return false;
        },
      );
      addTearDown(notifier.dispose);

      await notifier.startDownload(device);

      expect(seenId, isNull);
      expect(capturedSyncClock(), isFalse);
    });

    test('never syncs when no resolver is wired', () async {
      final notifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
      );
      addTearDown(notifier.dispose);

      await notifier.startDownload(device, computer: computer);

      expect(capturedSyncClock(), isFalse);
    });
  });

  group('completion carries the clock sync status', () {
    late StreamController<DownloadEvent> controller;
    late DownloadNotifier notifier;

    setUp(() {
      controller = StreamController<DownloadEvent>.broadcast();
      addTearDown(controller.close);
      when(mockService.downloadEvents).thenAnswer((_) => controller.stream);
      notifier = DownloadNotifier(
        service: mockService,
        repository: mockRepository,
      );
      addTearDown(notifier.dispose);
    });

    test('parses the wire name into state', () async {
      await notifier.startDownload(device);
      controller.add(DownloadCompleteEvent(0, clockSyncStatus: 'unsupported'));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.phase, DownloadPhase.complete);
      expect(notifier.state.clockSyncStatus, ClockSyncStatus.unsupported);
    });

    test('a completion without a status reads as not requested', () async {
      await notifier.startDownload(device);
      controller.add(DownloadCompleteEvent(0));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.clockSyncStatus, ClockSyncStatus.notRequested);
    });

    test('a new download clears the previous status', () async {
      await notifier.startDownload(device);
      controller.add(DownloadCompleteEvent(0, clockSyncStatus: 'synced'));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.clockSyncStatus, ClockSyncStatus.synced);

      await notifier.startDownload(device);

      expect(notifier.state.clockSyncStatus, isNull);
    });
  });

  test('DownloadState.copyWith keeps and clears the status', () {
    const initial = DownloadState();
    final synced = initial.copyWith(clockSyncStatus: ClockSyncStatus.synced);
    expect(synced.clockSyncStatus, ClockSyncStatus.synced);
    expect(
      synced.copyWith(phase: DownloadPhase.complete).clockSyncStatus,
      ClockSyncStatus.synced,
    );
    expect(synced.copyWith(clearClockSyncStatus: true).clockSyncStatus, isNull);
  });
}
```

- [ ] **Step 4: Run the codegen (for the new mocks file) and the test to see it fail**

Run: `bash "$SCRATCH/codegen.sh" && cd "$R" && flutter test test/features/dive_computer/presentation/providers/download_notifier_clock_sync_test.dart`
Expected: FAIL to compile (`resolveClockSync`, `clockSyncStatus` and `clearClockSyncStatus` do not exist).

- [ ] **Step 5: Implement the state and notifier changes**

In `$R/lib/features/dive_computer/presentation/providers/download_providers.dart` add the import (in the `dive_computer` group, sorted):

```dart
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
```

In `DownloadState` replace:

```dart
  final String? firmwareVersion;
  final DateTime? sinceCutoff;

  const DownloadState({
    this.phase = DownloadPhase.initializing,
    this.progress,
    this.downloadedDives = const [],
    this.errorMessage,
    this.errorCode,
    this.newDivesOnly = true,
    this.serialNumber,
    this.firmwareVersion,
    this.sinceCutoff,
  });

  DownloadState copyWith({
    DownloadPhase? phase,
    DownloadProgress? progress,
    List<DownloadedDive>? downloadedDives,
    String? errorMessage,
    String? errorCode,
    bool? newDivesOnly,
    String? serialNumber,
    String? firmwareVersion,
    DateTime? sinceCutoff,
    bool clearError = false,
  }) {
    return DownloadState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      downloadedDives: downloadedDives ?? this.downloadedDives,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      newDivesOnly: newDivesOnly ?? this.newDivesOnly,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      sinceCutoff: sinceCutoff ?? this.sinceCutoff,
    );
  }
```

with:

```dart
  final String? firmwareVersion;
  final DateTime? sinceCutoff;

  /// Outcome of the clock sync that ran after this download (issue #1216).
  /// Null until a completion event arrives; [ClockSyncStatus.notRequested]
  /// when the download completed without asking for one.
  final ClockSyncStatus? clockSyncStatus;

  const DownloadState({
    this.phase = DownloadPhase.initializing,
    this.progress,
    this.downloadedDives = const [],
    this.errorMessage,
    this.errorCode,
    this.newDivesOnly = true,
    this.serialNumber,
    this.firmwareVersion,
    this.sinceCutoff,
    this.clockSyncStatus,
  });

  DownloadState copyWith({
    DownloadPhase? phase,
    DownloadProgress? progress,
    List<DownloadedDive>? downloadedDives,
    String? errorMessage,
    String? errorCode,
    bool? newDivesOnly,
    String? serialNumber,
    String? firmwareVersion,
    DateTime? sinceCutoff,
    ClockSyncStatus? clockSyncStatus,
    bool clearError = false,
    bool clearClockSyncStatus = false,
  }) {
    return DownloadState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      downloadedDives: downloadedDives ?? this.downloadedDives,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      newDivesOnly: newDivesOnly ?? this.newDivesOnly,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      sinceCutoff: sinceCutoff ?? this.sinceCutoff,
      clockSyncStatus: clearClockSyncStatus
          ? null
          : (clockSyncStatus ?? this.clockSyncStatus),
    );
  }
```

In `DownloadNotifier` replace:

```dart
  final bool Function()? _trimTankPressureAtSurfacing;

  DownloadNotifier({
    required pigeon.DiveComputerService service,
    required DiveComputerRepository repository,
    bool Function()? trimTankPressureAtSurfacing,
  }) : _service = service,
       _repository = repository,
       _trimTankPressureAtSurfacing = trimTankPressureAtSurfacing,
       super(const DownloadState());
```

with:

```dart
  final bool Function()? _trimTankPressureAtSurfacing;

  /// Whether a download should set the computer's clock afterwards, given
  /// the saved computer's id (null for a device not saved yet). A callback
  /// rather than a value so a switch flipped between downloads applies to
  /// the next one without rebuilding the notifier. Null means never
  /// (issue #1216).
  final bool Function(String? computerId)? _resolveClockSync;

  DownloadNotifier({
    required pigeon.DiveComputerService service,
    required DiveComputerRepository repository,
    bool Function()? trimTankPressureAtSurfacing,
    bool Function(String? computerId)? resolveClockSync,
  }) : _service = service,
       _repository = repository,
       _trimTankPressureAtSurfacing = trimTankPressureAtSurfacing,
       _resolveClockSync = resolveClockSync,
       super(const DownloadState());
```

In `startDownload` replace:

```dart
      state = state.copyWith(
        phase: DownloadPhase.connecting,
        clearError: true,
        downloadedDives: [],
        progress: DownloadProgress.connecting(),
      );
```

with:

```dart
      state = state.copyWith(
        phase: DownloadPhase.connecting,
        clearError: true,
        clearClockSyncStatus: true,
        downloadedDives: [],
        progress: DownloadProgress.connecting(),
      );
```

and replace:

```dart
      await _service.startDownload(device.toPigeon(), fingerprint: fingerprint);
```

with:

```dart
      final syncClock = _resolveClockSync?.call(computer?.id) ?? false;
      await _service.startDownload(
        device.toPigeon(),
        fingerprint: fingerprint,
        syncClock: syncClock,
      );
```

In `_onDownloadEvent` replace:

```dart
      case pigeon.DownloadCompleteEvent(
        :final totalDives,
        :final serialNumber,
        :final firmwareVersion,
      ):
        state = state.copyWith(
          phase: DownloadPhase.complete,
          progress: DownloadProgress.complete(totalDives),
          serialNumber: serialNumber,
          firmwareVersion: firmwareVersion,
        );
```

with:

```dart
      case pigeon.DownloadCompleteEvent(
        :final totalDives,
        :final serialNumber,
        :final firmwareVersion,
        :final clockSyncStatus,
      ):
        state = state.copyWith(
          phase: DownloadPhase.complete,
          progress: DownloadProgress.complete(totalDives),
          serialNumber: serialNumber,
          firmwareVersion: firmwareVersion,
          clockSyncStatus: ClockSyncStatus.fromWireName(clockSyncStatus),
        );
```

In the provider at the bottom replace:

```dart
      return DownloadNotifier(
        service: service,
        repository: repository,
        trimTankPressureAtSurfacing: () =>
            ref.read(settingsProvider).trimTankPressureAtSurfacing,
      );
```

with:

```dart
      return DownloadNotifier(
        service: service,
        repository: repository,
        trimTankPressureAtSurfacing: () =>
            ref.read(settingsProvider).trimTankPressureAtSurfacing,
        // Read at download time, not provider build time, so a switch flipped
        // on the computers list applies to the very next download.
        resolveClockSync: (computerId) =>
            ref.read(clockSyncSettingsNotifierProvider).resolve(computerId),
      );
```

and add the import (sorted into the `dive_computer` group):

```dart
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
```

- [ ] **Step 6: Run the new test and every test that touches the download stack**

Run:

```bash
cd "$R" && flutter test test/features/dive_computer test/features/import_wizard
```

Expected: all pass (no pipe, so the exit status is real). Rerun any failing file on its own before changing anything.

- [ ] **Step 7: Format and commit**

```bash
cd "$R" && dart format . && git add lib/features/dive_computer/presentation/providers/download_providers.dart test/features/dive_computer/presentation/providers/download_notifier_clock_sync_test.dart test/features/dive_computer/presentation/widgets/download_step_widget_test.dart test/features/dive_computer/presentation/widgets/usb_search_test.dart test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart test/helpers/fake_import_adapter_deps.dart && git commit -m "feat(dive-computer): request clock sync on download and keep its result (#1216)"
```

---

### Task 9: Remember learned support and forget it on delete

**Files:**
- Modify: `$R/lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` (`_captureAndAdvance`, around line 560)
- Modify: `$R/lib/features/dive_log/presentation/providers/dive_computer_providers.dart` (`delete`, around line 234)
- Modify: `$R/test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart`
- Create: `$R/test/features/dive_log/presentation/providers/dive_computer_notifier_clock_sync_test.dart`

**Interfaces:**
- Consumes: `DownloadState.clockSyncStatus` (Task 8); `ClockSyncSettingsNotifier.recordSupport`, `forget` (Task 7); `DiveComputerAdapter.computer` (existing getter, resolved by `ensureComputer`).

- [ ] **Step 1: Write the failing wizard-step test**

In `$R/test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart` add the imports:

```dart
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
```

and, directly after the issue #865 test (`'a completed download with no dives still saves the dive computer'`), add:

```dart
    testWidgets('a completed download records what the model answered', (
      tester,
    ) async {
      final repository = _RecordingDiveComputerRepository();
      final adapter = _makeAdapter(computerRepository: repository);

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );
      container
          .read(downloadNotifierProvider.notifier)
          .state = const DownloadState(
        phase: DownloadPhase.complete,
        downloadedDives: [],
        clockSyncStatus: ClockSyncStatus.unsupported,
      );
      await tester.pumpAndSettle();

      final savedId = repository.created.single.id;
      expect(
        container.read(clockSyncSettingsNotifierProvider).supportFor(savedId),
        ClockSyncSupport.unsupported,
      );
    });

    testWidgets('a failed clock sync records nothing about the model', (
      tester,
    ) async {
      final repository = _RecordingDiveComputerRepository();
      final adapter = _makeAdapter(computerRepository: repository);

      await tester.pumpWidget(
        _buildDownloadStep(
          adapter: adapter,
          discoveryState: DiscoveryState(selectedDevice: _testDevice),
        ),
      );
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DcAdapterDownloadStep)),
      );
      container
          .read(downloadNotifierProvider.notifier)
          .state = const DownloadState(
        phase: DownloadPhase.complete,
        downloadedDives: [],
        clockSyncStatus: ClockSyncStatus.failed,
      );
      await tester.pumpAndSettle();

      final savedId = repository.created.single.id;
      expect(
        container.read(clockSyncSettingsNotifierProvider).supportFor(savedId),
        ClockSyncSupport.unknown,
      );
    });
```

- [ ] **Step 2: Write the failing delete test**

Create `$R/test/features/dive_log/presentation/providers/dive_computer_notifier_clock_sync_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  test('delete forgets the clock sync keys for that computer only', () async {
    await insertComputer('computer-1');
    await insertComputer('computer-2');
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final clockSync = container.read(clockSyncSettingsNotifierProvider.notifier);
    await clockSync.setOverride('computer-1', ClockSyncOverride.always);
    await clockSync.recordSupport('computer-1', ClockSyncStatus.synced);
    await clockSync.setOverride('computer-2', ClockSyncOverride.never);

    await container.read(diveComputerNotifierProvider.notifier).delete(
      'computer-1',
    );

    final settings = container.read(clockSyncSettingsNotifierProvider);
    expect(settings.overrideFor('computer-1'), ClockSyncOverride.inherit);
    expect(settings.supportFor('computer-1'), ClockSyncSupport.unknown);
    expect(settings.overrideFor('computer-2'), ClockSyncOverride.never);
  });
}
```

- [ ] **Step 3: Run both tests to see them fail**

Run: `cd "$R" && flutter test test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart test/features/dive_log/presentation/providers/dive_computer_notifier_clock_sync_test.dart`
Expected: the two new wizard tests fail on `supportFor` returning `unknown` for the unsupported case, and the delete test fails on `overrideFor('computer-1')` still being `always`.

- [ ] **Step 4: Record support after `ensureComputer`**

In `$R/lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` add the import (sorted into the `dive_computer` group):

```dart
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
```

and replace:

```dart
      if (device != null) {
        // Serial and firmware ride on the completion event, not on the dives,
        // so the hardware-identity rebind still works with an empty download.
        await widget.adapter.ensureComputer(
          device: device,
          serialNumber: state.serialNumber,
          firmwareVersion: state.firmwareVersion,
        );
      }
```

with:

```dart
      if (device != null) {
        // Serial and firmware ride on the completion event, not on the dives,
        // so the hardware-identity rebind still works with an empty download.
        await widget.adapter.ensureComputer(
          device: device,
          serialNumber: state.serialNumber,
          firmwareVersion: state.firmwareVersion,
        );
        if (!mounted) return;

        // Remember what the model answered about clock sync so the detail
        // page can say so (issue #1216). ensureComputer resolved the
        // computer in both the first-download and known-computer flows, so
        // this one site covers every download.
        final computer = widget.adapter.computer;
        final clockSyncStatus = state.clockSyncStatus;
        if (computer != null && clockSyncStatus != null) {
          await ref
              .read(clockSyncSettingsNotifierProvider.notifier)
              .recordSupport(computer.id, clockSyncStatus);
        }
      }
```

- [ ] **Step 5: Forget on delete**

In `$R/lib/features/dive_log/presentation/providers/dive_computer_providers.dart` add the import (sorted into the `dive_computer` group):

```dart
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
```

and replace:

```dart
  Future<void> delete(String id) async {
    await _repository.deleteComputer(id);
    await _load();
```

with:

```dart
  Future<void> delete(String id) async {
    await _repository.deleteComputer(id);
    // The installation-local clock sync keys for this computer would
    // otherwise outlive it in SharedPreferences (issue #1216).
    await _ref.read(clockSyncSettingsNotifierProvider.notifier).forget(id);
    await _load();
```

- [ ] **Step 6: Run the tests to see them pass**

Run: `cd "$R" && flutter test test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart test/features/dive_log/presentation/providers/dive_computer_notifier_clock_sync_test.dart test/features/dive_computer/presentation/pages`
Expected: all pass, including the existing device list and detail page tests (their fake notifiers use `noSuchMethod`, so the new `forget` call inside the real `delete` never reaches them).

- [ ] **Step 7: Format and commit**

```bash
cd "$R" && dart format . && git add lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart lib/features/dive_log/presentation/providers/dive_computer_providers.dart test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart test/features/dive_log/presentation/providers/dive_computer_notifier_clock_sync_test.dart && git commit -m "feat(dive-computer): remember clock sync support per computer (#1216)"
```

---

### Task 10: Localisation for every locale

This task lands before the UI tasks so `context.l10n.diveComputer_clockSync_*` exists when they compile. Run `flutter gen-l10n` exactly once, at the end, after all eleven ARBs carry their translations; running it earlier bakes English fallbacks into the generated Dart.

**Files:**
- Modify: `$R/lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `$R/lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces the getters `diveComputer_clockSync_globalTitle`, `diveComputer_clockSync_globalSubtitle`, `diveComputer_clockSync_cardTitle`, `diveComputer_clockSync_overrideInherit`, `diveComputer_clockSync_overrideAlways`, `diveComputer_clockSync_overrideNever`, `diveComputer_clockSync_appSettingOn`, `diveComputer_clockSync_appSettingOff`, `diveComputer_clockSync_supported`, `diveComputer_clockSync_unsupported`, `diveComputer_clockSync_checkAgain`, `diveComputer_downloadStep_clockSyncFailed`, `diveComputer_downloadStep_clockSyncUnsupported`, `diveComputer_downloadStep_clockSynced` on `AppLocalizations`.

Two insertion anchors per file. Block A (`diveComputer_clockSync_*`, 11 keys): in `app_en.arb` insert directly BEFORE the line `"diveComputer_connectionType_ble": "Bluetooth LE",` (keeps the English file alphabetical); in the ten other ARBs insert directly AFTER the line that starts with `"diveComputer_connectionType_wifi":` (those files group keys by feature, not alphabetically). Block B (`diveComputer_downloadStep_clockSync*`, 3 keys): in every file insert directly AFTER the line that starts with `"diveComputer_downloadStep_cancelled":`. Every inserted line ends with a comma, matching its neighbours. None of these keys has placeholders, so no `@` metadata entries are needed.

- [ ] **Step 1: English (`app_en.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "App setting: off",
  "diveComputer_clockSync_appSettingOn": "App setting: on",
  "diveComputer_clockSync_cardTitle": "Clock sync",
  "diveComputer_clockSync_checkAgain": "Check again",
  "diveComputer_clockSync_globalSubtitle": "Sets the clock to this device's time after each download. Applies to this device only.",
  "diveComputer_clockSync_globalTitle": "Sync dive computer clocks",
  "diveComputer_clockSync_overrideAlways": "Always",
  "diveComputer_clockSync_overrideInherit": "App setting",
  "diveComputer_clockSync_overrideNever": "Never",
  "diveComputer_clockSync_supported": "Supported by this model",
  "diveComputer_clockSync_unsupported": "This model does not support clock sync",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "Clock sync failed",
  "diveComputer_downloadStep_clockSyncUnsupported": "Clock sync is not supported by this model",
  "diveComputer_downloadStep_clockSynced": "Clock synced",
```

- [ ] **Step 2: German (`app_de.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "App-Einstellung: aus",
  "diveComputer_clockSync_appSettingOn": "App-Einstellung: ein",
  "diveComputer_clockSync_cardTitle": "Uhrzeit-Abgleich",
  "diveComputer_clockSync_checkAgain": "Erneut prüfen",
  "diveComputer_clockSync_globalSubtitle": "Stellt die Uhr nach jedem Download auf die Zeit dieses Geräts. Gilt nur für dieses Gerät.",
  "diveComputer_clockSync_globalTitle": "Uhren der Tauchcomputer abgleichen",
  "diveComputer_clockSync_overrideAlways": "Immer",
  "diveComputer_clockSync_overrideInherit": "App-Einstellung",
  "diveComputer_clockSync_overrideNever": "Nie",
  "diveComputer_clockSync_supported": "Von diesem Modell unterstützt",
  "diveComputer_clockSync_unsupported": "Dieses Modell unterstützt keinen Uhrzeit-Abgleich",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "Uhrzeit-Abgleich fehlgeschlagen",
  "diveComputer_downloadStep_clockSyncUnsupported": "Uhrzeit-Abgleich wird von diesem Modell nicht unterstützt",
  "diveComputer_downloadStep_clockSynced": "Uhrzeit abgeglichen",
```

- [ ] **Step 3: Spanish (`app_es.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "Ajuste de la app: desactivado",
  "diveComputer_clockSync_appSettingOn": "Ajuste de la app: activado",
  "diveComputer_clockSync_cardTitle": "Sincronización del reloj",
  "diveComputer_clockSync_checkAgain": "Comprobar de nuevo",
  "diveComputer_clockSync_globalSubtitle": "Ajusta el reloj a la hora de este dispositivo tras cada descarga. Solo se aplica a este dispositivo.",
  "diveComputer_clockSync_globalTitle": "Sincronizar relojes de ordenadores de buceo",
  "diveComputer_clockSync_overrideAlways": "Siempre",
  "diveComputer_clockSync_overrideInherit": "Ajuste de la app",
  "diveComputer_clockSync_overrideNever": "Nunca",
  "diveComputer_clockSync_supported": "Compatible con este modelo",
  "diveComputer_clockSync_unsupported": "Este modelo no admite la sincronización del reloj",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "Error al sincronizar el reloj",
  "diveComputer_downloadStep_clockSyncUnsupported": "Este modelo no admite la sincronización del reloj",
  "diveComputer_downloadStep_clockSynced": "Reloj sincronizado",
```

- [ ] **Step 4: French (`app_fr.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "Réglage de l'app : désactivé",
  "diveComputer_clockSync_appSettingOn": "Réglage de l'app : activé",
  "diveComputer_clockSync_cardTitle": "Synchronisation de l'horloge",
  "diveComputer_clockSync_checkAgain": "Vérifier à nouveau",
  "diveComputer_clockSync_globalSubtitle": "Règle l'horloge sur l'heure de cet appareil après chaque téléchargement. S'applique uniquement à cet appareil.",
  "diveComputer_clockSync_globalTitle": "Synchroniser l'horloge des ordinateurs de plongée",
  "diveComputer_clockSync_overrideAlways": "Toujours",
  "diveComputer_clockSync_overrideInherit": "Réglage de l'app",
  "diveComputer_clockSync_overrideNever": "Jamais",
  "diveComputer_clockSync_supported": "Pris en charge par ce modèle",
  "diveComputer_clockSync_unsupported": "Ce modèle ne prend pas en charge la synchronisation de l'horloge",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "Échec de la synchronisation de l'horloge",
  "diveComputer_downloadStep_clockSyncUnsupported": "La synchronisation de l'horloge n'est pas prise en charge par ce modèle",
  "diveComputer_downloadStep_clockSynced": "Horloge synchronisée",
```

- [ ] **Step 5: Italian (`app_it.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "Impostazione app: disattivata",
  "diveComputer_clockSync_appSettingOn": "Impostazione app: attiva",
  "diveComputer_clockSync_cardTitle": "Sincronizzazione orologio",
  "diveComputer_clockSync_checkAgain": "Controlla di nuovo",
  "diveComputer_clockSync_globalSubtitle": "Imposta l'orologio sull'ora di questo dispositivo dopo ogni download. Vale solo per questo dispositivo.",
  "diveComputer_clockSync_globalTitle": "Sincronizza l'orologio dei computer subacquei",
  "diveComputer_clockSync_overrideAlways": "Sempre",
  "diveComputer_clockSync_overrideInherit": "Impostazione app",
  "diveComputer_clockSync_overrideNever": "Mai",
  "diveComputer_clockSync_supported": "Supportata da questo modello",
  "diveComputer_clockSync_unsupported": "Questo modello non supporta la sincronizzazione dell'orologio",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "Sincronizzazione dell'orologio non riuscita",
  "diveComputer_downloadStep_clockSyncUnsupported": "La sincronizzazione dell'orologio non è supportata da questo modello",
  "diveComputer_downloadStep_clockSynced": "Orologio sincronizzato",
```

- [ ] **Step 6: Dutch (`app_nl.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "App-instelling: uit",
  "diveComputer_clockSync_appSettingOn": "App-instelling: aan",
  "diveComputer_clockSync_cardTitle": "Kloksynchronisatie",
  "diveComputer_clockSync_checkAgain": "Opnieuw controleren",
  "diveComputer_clockSync_globalSubtitle": "Zet de klok na elke download op de tijd van dit apparaat. Geldt alleen voor dit apparaat.",
  "diveComputer_clockSync_globalTitle": "Klok van duikcomputers synchroniseren",
  "diveComputer_clockSync_overrideAlways": "Altijd",
  "diveComputer_clockSync_overrideInherit": "App-instelling",
  "diveComputer_clockSync_overrideNever": "Nooit",
  "diveComputer_clockSync_supported": "Ondersteund door dit model",
  "diveComputer_clockSync_unsupported": "Dit model ondersteunt geen kloksynchronisatie",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "Kloksynchronisatie mislukt",
  "diveComputer_downloadStep_clockSyncUnsupported": "Kloksynchronisatie wordt niet ondersteund door dit model",
  "diveComputer_downloadStep_clockSynced": "Klok gesynchroniseerd",
```

- [ ] **Step 7: Portuguese (`app_pt.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "Definição da app: desligada",
  "diveComputer_clockSync_appSettingOn": "Definição da app: ligada",
  "diveComputer_clockSync_cardTitle": "Sincronização do relógio",
  "diveComputer_clockSync_checkAgain": "Verificar novamente",
  "diveComputer_clockSync_globalSubtitle": "Acerta o relógio pela hora deste dispositivo após cada download. Aplica-se apenas a este dispositivo.",
  "diveComputer_clockSync_globalTitle": "Sincronizar relógios dos computadores de mergulho",
  "diveComputer_clockSync_overrideAlways": "Sempre",
  "diveComputer_clockSync_overrideInherit": "Definição da app",
  "diveComputer_clockSync_overrideNever": "Nunca",
  "diveComputer_clockSync_supported": "Suportado por este modelo",
  "diveComputer_clockSync_unsupported": "Este modelo não suporta a sincronização do relógio",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "Falha na sincronização do relógio",
  "diveComputer_downloadStep_clockSyncUnsupported": "A sincronização do relógio não é suportada por este modelo",
  "diveComputer_downloadStep_clockSynced": "Relógio sincronizado",
```

- [ ] **Step 8: Hungarian (`app_hu.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "Alkalmazásbeállítás: ki",
  "diveComputer_clockSync_appSettingOn": "Alkalmazásbeállítás: be",
  "diveComputer_clockSync_cardTitle": "Óraszinkronizálás",
  "diveComputer_clockSync_checkAgain": "Ellenőrzés újra",
  "diveComputer_clockSync_globalSubtitle": "Minden letöltés után ennek az eszköznek az idejére állítja az órát. Csak erre az eszközre vonatkozik.",
  "diveComputer_clockSync_globalTitle": "Búvárkomputerek órájának szinkronizálása",
  "diveComputer_clockSync_overrideAlways": "Mindig",
  "diveComputer_clockSync_overrideInherit": "Alkalmazásbeállítás",
  "diveComputer_clockSync_overrideNever": "Soha",
  "diveComputer_clockSync_supported": "Ez a modell támogatja",
  "diveComputer_clockSync_unsupported": "Ez a modell nem támogatja az óraszinkronizálást",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "Az óraszinkronizálás nem sikerült",
  "diveComputer_downloadStep_clockSyncUnsupported": "Az óraszinkronizálást ez a modell nem támogatja",
  "diveComputer_downloadStep_clockSynced": "Óra szinkronizálva",
```

- [ ] **Step 9: Arabic (`app_ar.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "إعداد التطبيق: معطّل",
  "diveComputer_clockSync_appSettingOn": "إعداد التطبيق: مفعّل",
  "diveComputer_clockSync_cardTitle": "مزامنة الساعة",
  "diveComputer_clockSync_checkAgain": "التحقق مرة أخرى",
  "diveComputer_clockSync_globalSubtitle": "يضبط الساعة على وقت هذا الجهاز بعد كل تنزيل. ينطبق على هذا الجهاز فقط.",
  "diveComputer_clockSync_globalTitle": "مزامنة ساعات كمبيوترات الغوص",
  "diveComputer_clockSync_overrideAlways": "دائمًا",
  "diveComputer_clockSync_overrideInherit": "إعداد التطبيق",
  "diveComputer_clockSync_overrideNever": "أبدًا",
  "diveComputer_clockSync_supported": "مدعومة في هذا الطراز",
  "diveComputer_clockSync_unsupported": "هذا الطراز لا يدعم مزامنة الساعة",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "فشلت مزامنة الساعة",
  "diveComputer_downloadStep_clockSyncUnsupported": "مزامنة الساعة غير مدعومة في هذا الطراز",
  "diveComputer_downloadStep_clockSynced": "تمت مزامنة الساعة",
```

- [ ] **Step 10: Hebrew (`app_he.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "הגדרת האפליקציה: כבויה",
  "diveComputer_clockSync_appSettingOn": "הגדרת האפליקציה: פעילה",
  "diveComputer_clockSync_cardTitle": "סנכרון שעון",
  "diveComputer_clockSync_checkAgain": "בדיקה חוזרת",
  "diveComputer_clockSync_globalSubtitle": "מכוון את השעון לשעת המכשיר הזה אחרי כל הורדה. חל על מכשיר זה בלבד.",
  "diveComputer_clockSync_globalTitle": "סנכרון שעוני מחשבי צלילה",
  "diveComputer_clockSync_overrideAlways": "תמיד",
  "diveComputer_clockSync_overrideInherit": "הגדרת האפליקציה",
  "diveComputer_clockSync_overrideNever": "אף פעם",
  "diveComputer_clockSync_supported": "נתמך בדגם זה",
  "diveComputer_clockSync_unsupported": "דגם זה אינו תומך בסנכרון שעון",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "סנכרון השעון נכשל",
  "diveComputer_downloadStep_clockSyncUnsupported": "סנכרון שעון אינו נתמך בדגם זה",
  "diveComputer_downloadStep_clockSynced": "השעון סונכרן",
```

- [ ] **Step 11: Chinese (`app_zh.arb`)**

Block A:

```json
  "diveComputer_clockSync_appSettingOff": "应用设置：关",
  "diveComputer_clockSync_appSettingOn": "应用设置：开",
  "diveComputer_clockSync_cardTitle": "时钟同步",
  "diveComputer_clockSync_checkAgain": "重新检查",
  "diveComputer_clockSync_globalSubtitle": "每次下载后将时钟设为本设备的时间。仅适用于本设备。",
  "diveComputer_clockSync_globalTitle": "同步潜水电脑时钟",
  "diveComputer_clockSync_overrideAlways": "总是",
  "diveComputer_clockSync_overrideInherit": "应用设置",
  "diveComputer_clockSync_overrideNever": "从不",
  "diveComputer_clockSync_supported": "此型号支持",
  "diveComputer_clockSync_unsupported": "此型号不支持时钟同步",
```

Block B:

```json
  "diveComputer_downloadStep_clockSyncFailed": "时钟同步失败",
  "diveComputer_downloadStep_clockSyncUnsupported": "此型号不支持时钟同步",
  "diveComputer_downloadStep_clockSynced": "时钟已同步",
```

- [ ] **Step 12: Verify every locale has all 14 keys, then generate**

```bash
cd "$R" && for f in lib/l10n/arb/app_*.arb; do printf "%s %s\n" "$f" "$(grep -c '"diveComputer_clockSync_\|"diveComputer_downloadStep_clockSync' "$f")"; done
```

Expected: each of the 11 files prints `14`. Also confirm the files are still valid JSON and still LF:

```bash
cd "$R" && for f in lib/l10n/arb/app_*.arb; do python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$f" || echo "BROKEN $f"; done; git diff --numstat -- lib/l10n/arb | awk '$1 != 14 || $2 != 0 {print "UNEXPECTED", $0}'
```

Expected: no `BROKEN` and no `UNEXPECTED` lines (exactly 14 added, 0 removed per ARB). Then:

```bash
cd "$R" && flutter gen-l10n && dart analyze lib/l10n
```

Expected: gen-l10n prints no errors; `dart analyze lib/l10n` reports no issues. Spot-check one locale: `grep -n "clockSynced" lib/l10n/arb/app_localizations_de.dart` shows `'Uhrzeit abgeglichen'`, not the English text.

- [ ] **Step 13: Commit**

```bash
cd "$R" && git add lib/l10n/arb && git commit -m "i18n: clock sync strings in every locale (#1216)"
```

---

### Task 11: Global switch on the Dive Computers list page

**Files:**
- Modify: `$R/lib/features/dive_computer/presentation/pages/device_list_page.dart` (body, around lines 95 to 130)
- Create: `$R/test/features/dive_computer/presentation/pages/device_list_page_clock_sync_test.dart`

**Interfaces:**
- Consumes: `clockSyncSettingsNotifierProvider`, `ClockSyncSettingsNotifier.setGlobalEnabled` (Task 7); l10n getters (Task 10).

- [ ] **Step 1: Write the failing widget test**

Create `$R/test/features/dive_computer/presentation/pages/device_list_page_clock_sync_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_list_page.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

import '../../../../helpers/test_app.dart';

const _switchKey = ValueKey('clock_sync_global_switch');

Widget _build({List<DiveComputer> computers = const []}) {
  return testApp(
    locale: const Locale('en'),
    overrides: [
      allDiveComputersProvider.overrideWith((ref) async => computers),
    ],
    child: const DeviceListPage(),
  );
}

DiveComputer _computer(String id) => DiveComputer(
  id: id,
  name: 'Perdix $id',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('shows the switch, off, above the empty state', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();

    expect(find.byKey(_switchKey), findsOneWidget);
    expect(find.text('Sync dive computer clocks'), findsOneWidget);
    expect(find.text('Find Computers'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(_switchKey)).value, isFalse);
  });

  testWidgets('shows the switch above a populated list', (tester) async {
    await tester.pumpWidget(_build(computers: [_computer('c1')]));
    await tester.pumpAndSettle();

    final switchTop = tester.getTopLeft(find.byKey(_switchKey)).dy;
    final cardTop = tester.getTopLeft(find.byType(Card).first).dy;
    expect(switchTop, lessThan(cardTop));
  });

  testWidgets('toggling the switch updates the setting', (tester) async {
    await tester.pumpWidget(_build(computers: [_computer('c1')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_switchKey));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeviceListPage)),
    );
    expect(container.read(clockSyncSettingsNotifierProvider).globalEnabled, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(_switchKey)).value, isTrue);
  });

  testWidgets('reflects a setting that is already on', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeviceListPage)),
    );
    await container
        .read(clockSyncSettingsNotifierProvider.notifier)
        .setGlobalEnabled(true);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(find.byKey(_switchKey)).value, isTrue);
  });
}
```

(The empty-state button text `Find Computers` is the existing `diveComputer_list_findComputers` English value; check it with `grep '"diveComputer_list_findComputers"' "$R/lib/l10n/arb/app_en.arb"` and use the exact value.)

- [ ] **Step 2: Run the test to see it fail**

Run: `cd "$R" && flutter test test/features/dive_computer/presentation/pages/device_list_page_clock_sync_test.dart`
Expected: FAIL on `findsOneWidget` for the switch key.

- [ ] **Step 3: Add the switch above the body**

In `$R/lib/features/dive_computer/presentation/pages/device_list_page.dart` add the imports (sorted into the `dive_computer` group):

```dart
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
```

Replace:

```dart
          body: computersAsync.when(
            data: (computers) {
              if (computers.isEmpty) {
                return _buildEmptyState(context, colorScheme);
              }
              return _buildComputerList(context, ref, computers);
            },
```

with:

```dart
          body: Column(
            children: [
              _buildClockSyncSwitch(context, ref),
              const Divider(height: 1),
              Expanded(
                child: computersAsync.when(
                  data: (computers) {
                    if (computers.isEmpty) {
                      return _buildEmptyState(context, colorScheme);
                    }
                    return _buildComputerList(context, ref, computers);
                  },
```

and close the two new wrappers: the `computersAsync.when(...)` call that used to end with

```dart
            ),
          ),
          floatingActionButton: selection.isActive
```

now ends with

```dart
                ),
              ),
            ],
          ),
          floatingActionButton: selection.isActive
```

(re-indent the `loading:` and `error:` branches by four spaces to match; `dart format` will settle the rest).

Add the builder next to `_buildEmptyState`:

```dart
  /// Installation-local: whether downloads from THIS device set each
  /// computer's clock (issue #1216). Lives here rather than in Settings so it
  /// sits beside the per-computer override on the detail page.
  Widget _buildClockSyncSwitch(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      clockSyncSettingsNotifierProvider.select((s) => s.globalEnabled),
    );
    return SwitchListTile(
      key: const ValueKey('clock_sync_global_switch'),
      secondary: const Icon(Icons.schedule),
      title: Text(context.l10n.diveComputer_clockSync_globalTitle),
      subtitle: Text(context.l10n.diveComputer_clockSync_globalSubtitle),
      value: enabled,
      onChanged: (value) => ref
          .read(clockSyncSettingsNotifierProvider.notifier)
          .setGlobalEnabled(value),
    );
  }
```

- [ ] **Step 4: Run the new test and the existing list page tests**

Run: `cd "$R" && flutter test test/features/dive_computer/presentation/pages/device_list_page_clock_sync_test.dart test/features/dive_computer/presentation/pages/device_list_page_test.dart test/features/dive_computer/presentation/pages/device_list_page_merge_test.dart`
Expected: all pass. If the selection contract test fails on `find.byType(Card).first`, the switch is not a `Card` so the finder is unaffected; investigate before changing any existing test.

- [ ] **Step 5: Format and commit**

```bash
cd "$R" && dart format . && git add lib/features/dive_computer/presentation/pages/device_list_page.dart test/features/dive_computer/presentation/pages/device_list_page_clock_sync_test.dart && git commit -m "feat(dive-computer): clock sync switch on the computers list (#1216)"
```

---

### Task 12: Per-computer override card on the device detail page

**Files:**
- Modify: `$R/lib/features/dive_computer/presentation/pages/device_detail_page.dart` (card assembly around line 122, new builder next to `_buildActionsCard`)
- Create: `$R/test/features/dive_computer/presentation/pages/device_detail_page_clock_sync_test.dart`

**Interfaces:**
- Consumes: `ClockSyncOverride`, `ClockSyncSupport`, `ClockSyncStatus` (Task 6); `clockSyncSettingsNotifierProvider` with `setOverride`, `recordSupport`, `clearSupport` (Task 7); l10n getters (Task 10).

- [ ] **Step 1: Write the failing widget test**

Create `$R/test/features/dive_computer/presentation/pages/device_detail_page_clock_sync_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _computerId = 'comp-1';
const _overrideKey = ValueKey('clock_sync_override');
const _checkAgainKey = ValueKey('clock_sync_check_again');

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DiveComputer _computer() {
  final now = DateTime(2026, 1, 1);
  return DiveComputer(
    id: _computerId,
    name: 'My Perdix',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    serialNumber: 'SN-12345',
    connectionType: 'ble',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _build() {
  final router = GoRouter(
    initialLocation: '/dive-computers/$_computerId',
    routes: [
      GoRoute(
        path: '/dive-computers/:id',
        builder: (context, state) =>
            DeviceDetailPage(computerId: state.pathParameters['id']!),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      diveComputerNotifierProvider.overrideWith(
        (ref) => _MockDiveComputerNotifier(),
      ),
      diveComputerByIdProvider(
        _computerId,
      ).overrideWith((ref) async => _computer()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DeviceDetailPage)));

void main() {
  testWidgets('shows the override control defaulting to the app setting', (
    tester,
  ) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_overrideKey), 200);

    expect(find.text('Clock sync'), findsOneWidget);
    final control = tester.widget<SegmentedButton<ClockSyncOverride>>(
      find.byKey(_overrideKey),
    );
    expect(control.selected, {ClockSyncOverride.inherit});
    expect(find.text('App setting: off'), findsOneWidget);
    expect(find.byKey(_checkAgainKey), findsNothing);
  });

  testWidgets('choosing Always stores the override', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_overrideKey), 200);

    await tester.tap(find.text('Always'));
    await tester.pumpAndSettle();

    expect(
      _containerOf(tester)
          .read(clockSyncSettingsNotifierProvider)
          .overrideFor(_computerId),
      ClockSyncOverride.always,
    );
  });

  testWidgets('names the app setting when it is on', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await _containerOf(tester)
        .read(clockSyncSettingsNotifierProvider.notifier)
        .setGlobalEnabled(true);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_overrideKey), 200);

    expect(find.text('App setting: on'), findsOneWidget);
  });

  testWidgets('says so when the model is known to support sync', (
    tester,
  ) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await _containerOf(tester)
        .read(clockSyncSettingsNotifierProvider.notifier)
        .recordSupport(_computerId, ClockSyncStatus.synced);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_overrideKey), 200);

    expect(find.text('Supported by this model'), findsOneWidget);
    expect(find.byKey(_overrideKey), findsOneWidget);
  });

  testWidgets('replaces the control with a note for an unsupported model', (
    tester,
  ) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await _containerOf(tester)
        .read(clockSyncSettingsNotifierProvider.notifier)
        .recordSupport(_computerId, ClockSyncStatus.unsupported);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_checkAgainKey), 200);

    expect(find.text('This model does not support clock sync'), findsOneWidget);
    expect(find.byKey(_overrideKey), findsNothing);

    await tester.tap(find.byKey(_checkAgainKey));
    await tester.pumpAndSettle();

    expect(
      _containerOf(tester)
          .read(clockSyncSettingsNotifierProvider)
          .supportFor(_computerId),
      ClockSyncSupport.unknown,
    );
    expect(find.byKey(_overrideKey), findsOneWidget);
    expect(find.byKey(_checkAgainKey), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

Run: `cd "$R" && flutter test test/features/dive_computer/presentation/pages/device_detail_page_clock_sync_test.dart`
Expected: FAIL (`scrollUntilVisible` cannot find the override key).

- [ ] **Step 3: Add the card**

In `$R/lib/features/dive_computer/presentation/pages/device_detail_page.dart` add the imports (sorted into the `dive_computer` group):

```dart
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
```

Replace:

```dart
            _buildActionsCard(context, ref, computer, colorScheme),
            if (computer.notes.isNotEmpty) ...[
```

with:

```dart
            _buildActionsCard(context, ref, computer, colorScheme),
            const SizedBox(height: 16),
            _buildClockSyncCard(context, ref, computer),
            if (computer.notes.isNotEmpty) ...[
```

Add the builder directly before `Widget _buildActionsCard(`:

```dart
  /// Per-computer clock sync choice (issue #1216). Installation-local like
  /// the switch on the computers list: the values live in SharedPreferences,
  /// never on the synced computer record.
  Widget _buildClockSyncCard(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final settings = ref.watch(clockSyncSettingsNotifierProvider);
    final notifier = ref.read(clockSyncSettingsNotifierProvider.notifier);
    final support = settings.supportFor(computer.id);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.diveComputer_clockSync_cardTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (support == ClockSyncSupport.unsupported) ...[
              // A control that could never do anything would mislead; say
              // why instead, and let the diver ask the device again after a
              // libdivecomputer update.
              Text(
                l10n.diveComputer_clockSync_unsupported,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('clock_sync_check_again'),
                  onPressed: () => notifier.clearSupport(computer.id),
                  child: Text(l10n.diveComputer_clockSync_checkAgain),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ClockSyncOverride>(
                  key: const ValueKey('clock_sync_override'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ClockSyncOverride.inherit,
                      label: Text(l10n.diveComputer_clockSync_overrideInherit),
                    ),
                    ButtonSegment(
                      value: ClockSyncOverride.always,
                      label: Text(l10n.diveComputer_clockSync_overrideAlways),
                    ),
                    ButtonSegment(
                      value: ClockSyncOverride.never,
                      label: Text(l10n.diveComputer_clockSync_overrideNever),
                    ),
                  ],
                  selected: {settings.overrideFor(computer.id)},
                  onSelectionChanged: (selection) =>
                      notifier.setOverride(computer.id, selection.first),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                settings.globalEnabled
                    ? l10n.diveComputer_clockSync_appSettingOn
                    : l10n.diveComputer_clockSync_appSettingOff,
                style: captionStyle,
              ),
              if (support == ClockSyncSupport.supported) ...[
                const SizedBox(height: 4),
                Text(l10n.diveComputer_clockSync_supported, style: captionStyle),
              ],
            ],
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run the new test and the existing detail page tests**

Run: `cd "$R" && flutter test test/features/dive_computer/presentation/pages/device_detail_page_clock_sync_test.dart test/features/dive_computer/presentation/pages/device_detail_page_test.dart test/features/dive_computer/presentation/pages/device_detail_page_gear_twin_test.dart test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart test/features/dive_computer/presentation/pages/device_detail_page_merge_test.dart`
Expected: all pass. A `RenderFlex overflowed` exception from the segmented button means the labels do not fit the test viewport; shorten nothing, instead wrap the `SegmentedButton` in a `FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart)` and rerun.

- [ ] **Step 5: Format and commit**

```bash
cd "$R" && dart format . && git add lib/features/dive_computer/presentation/pages/device_detail_page.dart test/features/dive_computer/presentation/pages/device_detail_page_clock_sync_test.dart && git commit -m "feat(dive-computer): per-computer clock sync override card (#1216)"
```

---

### Task 13: Completion line on the download step

**Files:**
- Modify: `$R/lib/features/dive_computer/presentation/widgets/download_step_widget.dart` (build body around lines 208 to 260)
- Modify: `$R/test/features/dive_computer/presentation/widgets/download_step_widget_test.dart`

**Interfaces:**
- Consumes: `DownloadState.clockSyncStatus` (Task 8); `ClockSyncStatus` (Task 6); l10n getters (Task 10).

- [ ] **Step 1: Write the failing widget tests**

In `$R/test/features/dive_computer/presentation/widgets/download_step_widget_test.dart` add the import:

```dart
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
```

and inside the `DownloadStepWidget` group, after the `'does not show cancel button in complete state'` test, add:

```dart
    // -----------------------------------------------------------------------
    // Clock sync result (issue #1216)
    // -----------------------------------------------------------------------

    Future<void> pumpComplete(
      WidgetTester tester,
      ClockSyncStatus? status,
    ) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.complete,
            progress: DownloadProgress.complete(1),
            clockSyncStatus: status,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('reports a synced clock on completion', (tester) async {
      await pumpComplete(tester, ClockSyncStatus.synced);
      expect(find.byKey(const ValueKey('clock_sync_result')), findsOneWidget);
      expect(find.text('Clock synced'), findsOneWidget);
    });

    testWidgets('reports an unsupported model on completion', (tester) async {
      await pumpComplete(tester, ClockSyncStatus.unsupported);
      expect(
        find.text('Clock sync is not supported by this model'),
        findsOneWidget,
      );
    });

    testWidgets('reports a failed sync on completion', (tester) async {
      await pumpComplete(tester, ClockSyncStatus.failed);
      expect(find.text('Clock sync failed'), findsOneWidget);
    });

    testWidgets('shows nothing when no sync was requested', (tester) async {
      await pumpComplete(tester, ClockSyncStatus.notRequested);
      expect(find.byKey(const ValueKey('clock_sync_result')), findsNothing);
    });

    testWidgets('shows nothing before a completion arrives', (tester) async {
      await pumpComplete(tester, null);
      expect(find.byKey(const ValueKey('clock_sync_result')), findsNothing);
    });

    testWidgets('shows nothing while still downloading', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          initialState: DownloadState(
            phase: DownloadPhase.downloading,
            progress: DownloadProgress.downloading(1, 2),
            clockSyncStatus: ClockSyncStatus.synced,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('clock_sync_result')), findsNothing);
    });
```

- [ ] **Step 2: Run the test file to see the new tests fail**

Run: `cd "$R" && flutter test test/features/dive_computer/presentation/widgets/download_step_widget_test.dart`
Expected: the three "reports" tests fail on `findsOneWidget`; the rest pass.

- [ ] **Step 3: Render the line**

In `$R/lib/features/dive_computer/presentation/widgets/download_step_widget.dart` add the import (sorted into the `dive_computer` group):

```dart
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
```

Replace:

```dart
    final percentText = showPercent
        ? context.l10n.diveComputer_downloadStep_percentAccessibility(
            (downloadState.progress!.percentage * 100).toStringAsFixed(0),
          )
        : '';
```

with:

```dart
    final percentText = showPercent
        ? context.l10n.diveComputer_downloadStep_percentAccessibility(
            (downloadState.progress!.percentage * 100).toStringAsFixed(0),
          )
        : '';
    final clockSyncText = downloadState.isComplete
        ? _clockSyncText(context, downloadState.clockSyncStatus)
        : null;
```

Replace:

```dart
            const SizedBox(height: 4),
            if (showPercent)
              Text(
                context.l10n.diveComputer_downloadStep_progressPercent(
                  (downloadState.progress!.percentage * 100).toStringAsFixed(0),
                ),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            const SizedBox(height: 16),
```

with:

```dart
            const SizedBox(height: 4),
            if (showPercent)
              Text(
                context.l10n.diveComputer_downloadStep_progressPercent(
                  (downloadState.progress!.percentage * 100).toStringAsFixed(0),
                ),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            if (clockSyncText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  clockSyncText,
                  key: const ValueKey('clock_sync_result'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
```

Add the helper directly before `Widget _buildCutoffPrompt(BuildContext context) {`:

```dart
  /// One line about the clock sync that ran after the download (issue
  /// #1216), or null when none was requested so the layout reserves no
  /// space for it.
  String? _clockSyncText(BuildContext context, ClockSyncStatus? status) {
    return switch (status) {
      ClockSyncStatus.synced =>
        context.l10n.diveComputer_downloadStep_clockSynced,
      ClockSyncStatus.unsupported =>
        context.l10n.diveComputer_downloadStep_clockSyncUnsupported,
      ClockSyncStatus.failed =>
        context.l10n.diveComputer_downloadStep_clockSyncFailed,
      ClockSyncStatus.notRequested || null => null,
    };
  }
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `cd "$R" && flutter test test/features/dive_computer/presentation/widgets`
Expected: all pass.

- [ ] **Step 5: Format and commit**

```bash
cd "$R" && dart format . && git add lib/features/dive_computer/presentation/widgets/download_step_widget.dart test/features/dive_computer/presentation/widgets/download_step_widget_test.dart && git commit -m "feat(dive-computer): report the clock sync result on completion (#1216)"
```

---

### Task 14: Whole-project verification and PR notes

**Files:** none new; fixes only where a check fails.

- [ ] **Step 1: Format and analyse the whole project**

```bash
cd "$R" && dart format . && dart analyze
```

Expected: `dart format` changes nothing (every task formatted); `dart analyze` reports `No issues found!`. CI treats infos as fatal, so fix any info-level finding too. If `dart format` did change a file, commit it as `style: format (#1216)`.

- [ ] **Step 2: Run the plugin's own checks**

```bash
cd "$P" && dart analyze && flutter test
```

Expected: no issues, all tests pass.

- [ ] **Step 3: Run the native suite and the darwin build once more**

Run: `bash "$SCRATCH/native_tests.sh"` then `bash "$SCRATCH/build_macos.sh"`.
Expected: `100% tests passed`; the macOS app builds.

- [ ] **Step 4: Run the full Flutter suite, once**

```bash
cd "$R" && flutter test --concurrency=4 > "$SCRATCH/full-suite.log" 2>&1; echo "exit=$?"; tail -5 "$SCRATCH/full-suite.log"
```

Expected: `exit=0` and a final `All tests passed!` line. The redirect keeps the exit status honest (a pipe would hide it). Do not start a second run while this one is going. If a test fails, run that file alone to separate a real failure from a known flake, fix real failures with their own test-first cycle and commit, and rerun only the affected files.

- [ ] **Step 5: Confirm the l10n generated files match the ARBs**

```bash
cd "$R" && flutter gen-l10n && git status --short lib/l10n
```

Expected: no output from `git status` (nothing drifted).

- [ ] **Step 6: Scan the branch for forbidden text**

```bash
cd "$R" && git diff origin/main...HEAD | grep -nP "^\+.*(\x{2014}|Co-Authored-By|Generated with|/code/session_)" || echo "clean"
```

Expected: `clean`.

- [ ] **Step 7: Write the PR description notes (do not open the PR unless asked)**

Save to `$SCRATCH/pr-body.md` for whoever opens the PR. It must state, in plain words:

- What the feature does and where the three controls live (list switch, detail override card, completion line).
- Every setting is installation-local in SharedPreferences; nothing crosses sync.
- The sync runs only after a successful, uncancelled download and never changes the download result.
- Android now reports serial and firmware on completion, which it never did before.
- The synced path was verified only by the native unit test against a fake device and by compiling each platform; it was NOT exercised against real hardware, and Linux and Windows were compiled by CI only.
- The four deviations from the spec listed at the top of this plan.
- A separate issue should be filed for the suspected sync-import wipe of `dive_computers.bluetoothAddress` (spec section "Out of scope").

No attribution lines, no session links.

---

## Self-review notes

- Spec coverage: requirement 1 (Task 11), 2 (Task 12), 3 (Tasks 1, 2, 8), 4 (Task 13), 5 (Tasks 7, 9, 12), 6 (Task 1, host offset via `dc_datetime_localtime`), 7 (Task 4). Spec section 1 bindings: Swift (Task 3), Android (Task 4), Linux and Windows (Task 5). Spec section 2 deletion cleanup (Task 9), localisation keys (Task 10, all 14 names match the spec). Spec section 3 tests: native (Task 1, shape changed as noted in deviation 1), preferences (Task 7), notifier (Task 8), service (Task 3), widgets (Tasks 11 to 13), wizard step (Task 9), delete (Task 9).
- Type consistency: the C enum values, the four wire names, `libdc_sync_device_clock(device, requested, download_succeeded)`, `DiveComputerService.startDownload(..., syncClock:)`, `DownloadCompleteEvent.clockSyncStatus` (String?), `DownloadState.clockSyncStatus` (ClockSyncStatus?), `resolveClockSync: bool Function(String?)`, and `clockSyncSettingsNotifierProvider` are spelled the same in every task that names them.
