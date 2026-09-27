# Cressi BLE Download and Model Relabel Implementation Plan (issue #422)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make BLE downloads from every Cressi Goa-family computer work on Android, iOS/macOS, Linux and Windows, and relabel a computer that advertised the wrong model (a Donatello behind the Cressi adapter scans as "Cartesio") from the model the device itself reports.

**Architecture:** libdivecomputer's Cressi Goa BLE backend reads its version block (serial, model, firmware) through the `DC_IOCTL_BLE_CHARACTERISTIC_READ` ioctl, which no platform BLE bridge implements, so every download dies at the handshake with "Failed to read the characteristic '6e400003-...'". A shared C helper in `libdc_wrapper.c` decodes the request and fills the reply; each platform bridge performs the GATT read. Separately, `libdc_download.c` keeps the `DC_EVENT_DEVINFO` model, maps it to a descriptor product for an allowlisted family (Cressi Goa only), and exposes it on the session; it travels to Dart on `onDownloadComplete`, where the saved computer, the new-computer record and the imported dives take the corrected model.

**Tech Stack:** C (libdivecomputer wrapper, native ctest), Kotlin + JNI C++ (Android), Swift/CoreBluetooth (iOS/macOS), C/GLib/BlueZ D-Bus (Linux), C++/WinRT (Windows), Pigeon 22, Dart/Flutter/Riverpod/mockito.

**Spec:** No separate spec document. The design was settled in the working session of 2026-09-26 and is restated in full under "Design decisions" below; executors treat that section as the spec.

## Design decisions (the spec)

1. Root cause: `third_party/libdivecomputer/src/cressi_goa.c:474-512` reads characteristics `6E400003` (5 bytes), `6E400004` (2), `6E400005` (2), all suffixed `-B5A3-F393-E0A9-E50E24DC10B8`, through `dc_iostream_ioctl(..., DC_IOCTL_BLE_CHARACTERISTIC_READ, request, 16 + n)`. The request buffer is the 16-byte big-endian UUID followed by `n` bytes the bridge must fill. Every bridge returns `LIBDC_STATUS_UNSUPPORTED` for ioctl nr 3 today.
2. Fix covers all four platforms in one PR.
3. The Cressi service `6e400001-b5a3-f393-e0a9-e50e24dc10b8` joins the preferred-service list on every platform that has one (Android, Darwin, Windows). Linux selects from a flat characteristic list with no service tier, so it gets no preference (documented in the Linux task).
4. The "Cressi Cartesio" label is fixed in this PR: the `DC_EVENT_DEVINFO` model replaces the scan-time model, for the Cressi Goa family ONLY (a C allowlist). Other families use private model codes and must never be relabeled.
5. The saved computer's `name` is rewritten only when it still equals the old default (`"<manufacturer> <old model>"`); a user-chosen name is kept.
6. Dives imported by the download that discovered the real model are stamped with the corrected descriptor product and model code.
7. The #1423 same-model fallback (`sameModelFallbackDevice`) treats the Cressi Goa BLE products as one identity, via a Dart constant pinned to `descriptor.c` by a test.
8. PR body says `Refs #422` (not Closes); the reporter is asked to test a build.

## Global Constraints

- Never write the character U+2014 (em-dash) or an en-dash used as punctuation in any file, comment, commit message or PR text.
- No AI-tool attribution of any kind in any file, commit message, trailer or PR text (see the Attribution section of the repo development guide). No `Co-Authored-By` trailers.
- Paths in Dart code and tests are built with `p.join(...)`, never with a literal `/` (issue #2279).
- Imports grouped dart, flutter, packages, local.
- No emojis in code or comments.
- Run `dart format .` from the repo root before every commit that touches Dart.
- Stage explicit paths only (never `git add -A` / `git add .` / `git add -u`): sibling worktrees and a stale submodule pointer get swept in otherwise.
- The `libdivecomputer` submodule pointer must NOT change in this PR. All C changes go in `packages/libdivecomputer_plugin/macos/Classes/` (the shared wrapper), never in `third_party/`.
- `libdc_wrapper.h` must stay free of libdivecomputer headers (it is included by Swift and by Kotlin JNI glue that do not see them).
- Native C tests use `assert` and must be built without `NDEBUG` (the existing CMake does this; do not add `-DNDEBUG`).
- Commit per task on branch `ericgriffin/github-issue-422-4959af`. Do not push.

## Review Focus

1. A characteristic read whose value arrives on the SAME characteristic libdc uses for data notifications (possible if a Cressi firmware exposes `6E400003` as notify): the 5 version bytes must not also land in the download's read queue. Darwin (shared `didUpdateValueFor`) and Linux (BlueZ `PropertiesChanged` echo) are the exposed platforms; Tasks 5 and 6 pin this.
2. A device whose read returns FEWER bytes than requested: must fail with `LIBDC_STATUS_DATAFORMAT`, never succeed with a zero-padded version block that libdc would parse as serial 0 / model 0. Task 1 pins it.
3. A saved computer already labeled "Cressi Cartesio" by an older build, downloaded again after the fix: it must be relabeled in place, not duplicated (first-time wizard hardware-identity rebind must try the scan-time model too). Task 10 pins it.
4. A user who renamed the computer ("My Cressi"): the relabel must change `model` but leave `name`. Task 9 pins it.
5. A disconnect while a characteristic read is in flight (Android, Darwin): the waiting libdc thread must wake with an error instead of blocking forever on a "no timeout" wait. Tasks 4 and 5 bound every read wait at 10 s and release the waiter on disconnect.

---

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` / `.c` | Shared ioctl decode/fill helpers; reported-product resolver | 1, 2 |
| `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c` | Keep DEVINFO model; session getter | 3 |
| `packages/libdivecomputer_plugin/test/native/test_ble_characteristic_read.c` | Unit test of the decode/fill helpers | 1 |
| `packages/libdivecomputer_plugin/test/native/test_reported_product.c` | Resolver against the real descriptor table | 2 |
| `packages/libdivecomputer_plugin/test/native/test_cressi_goa_ble_download.c` | End to end: `libdc_download_run` over a scripted Cressi BLE iostream | 3 |
| `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` | JNI ioctl nr 3; session reported-device natives | 4, 8 |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/.../BleIoStream.kt` | GATT characteristic read; Cressi preferred service | 4 |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/.../BleCharacteristicRead.kt` | Pure helper: UUID bytes to `java.util.UUID` | 4 |
| `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/PendingCharacteristicRead.swift` | Pure pending-read slot (thread-safe, testable) | 5 |
| `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift` | Darwin characteristic read | 5 |
| `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleCharacteristicSelector.swift` | Cressi preferred service | 5 |
| `packages/libdivecomputer_plugin/linux/ble_io_stream.{c,h}` | BlueZ `ReadValue` | 6 |
| `packages/libdivecomputer_plugin/windows/ble_io_stream.{cc,h}` | WinRT `ReadValueAsync`; Cressi preferred service | 7 |
| `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` + generated files | `onDownloadComplete` gains `reportedProduct`, `reportedModel` | 8 |
| Platform host API impls (Android BLE + serial AIDL, Darwin, Linux, Windows) | Read the session getter, pass the two new values | 8 |
| `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart` | `DownloadCompleteEvent.reportedProduct/reportedModel` | 8 |
| `lib/features/dive_computer/domain/services/reported_model_relabel.dart` | Pure relabel rule | 9 |
| `lib/features/dive_computer/presentation/providers/download_providers.dart` | State fields; saved-computer relabel | 9 |
| `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` + `presentation/widgets/dc_adapter_steps.dart` | New-computer identity, rebind, dive stamping | 10 |
| `lib/features/dive_computer/domain/services/known_computer_reacquisition.dart` | Family-aware fallback | 11 |

---

### Task 1: Shared decode and fill helpers for the characteristic-read ioctl

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` (append a section after the `libdc_io_callbacks_t` typedef, around line 160)
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.c` (append at end of file)
- Create: `packages/libdivecomputer_plugin/test/native/test_ble_characteristic_read.c`
- Modify: `packages/libdivecomputer_plugin/test/native/CMakeLists.txt`

**Interfaces:**
- Produces (used by Tasks 3-7):
  ```c
  #define LIBDC_BLE_UUID_SIZE 16
  #define LIBDC_BLE_UUID_STRING_SIZE 37
  #define LIBDC_IOCTL_BLE_CHARACTERISTIC_READ 0x40006203u
  #define LIBDC_BLE_CHAR_READ_NOT_THIS 0
  #define LIBDC_BLE_CHAR_READ_OK 1
  #define LIBDC_BLE_CHAR_READ_INVALID (-1)
  int libdc_ble_characteristic_read_decode(unsigned int request,
      const void *data, size_t size,
      char uuid_str[LIBDC_BLE_UUID_STRING_SIZE], size_t *value_size);
  int libdc_ble_characteristic_read_fill(void *data, size_t size,
      const unsigned char *value, size_t value_len);
  ```

- [ ] **Step 1: Write the failing test**

Create `test/native/test_ble_characteristic_read.c`:

```c
// Pins the shared decoding of libdivecomputer's BLE characteristic read
// ioctl (issue #422). Every platform BLE bridge routes the request through
// these two helpers, so the wire format is checked here once against the
// real libdivecomputer macros rather than four times against copies.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/ble.h>
#include <libdivecomputer/ioctl.h>

#include "libdc_wrapper.h"

// 6E400003-B5A3-F393-E0A9-E50E24DC10B8, the first Cressi version field.
static const unsigned char kCressiVersionUuid[16] = {
    0x6E, 0x40, 0x00, 0x03, 0xB5, 0xA3, 0xF3, 0x93,
    0xE0, 0xA9, 0xE5, 0x0E, 0x24, 0xDC, 0x10, 0xB8,
};

static void test_request_constant_matches_libdivecomputer(void) {
    assert(LIBDC_IOCTL_BLE_CHARACTERISTIC_READ ==
           (unsigned int)DC_IOCTL_BLE_CHARACTERISTIC_READ);
    assert(LIBDC_BLE_UUID_STRING_SIZE == DC_BLE_UUID_SIZE);
    printf("PASS: test_request_constant_matches_libdivecomputer\n");
}

static void test_decodes_uuid_and_value_size(void) {
    unsigned char request[16 + 5] = {0};
    memcpy(request, kCressiVersionUuid, 16);
    char uuid[LIBDC_BLE_UUID_STRING_SIZE];
    size_t value_size = 0;
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_CHARACTERISTIC_READ, request, sizeof(request),
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_OK);
    assert(strcmp(uuid, "6e400003-b5a3-f393-e0a9-e50e24dc10b8") == 0);
    assert(value_size == 5);
    printf("PASS: test_decodes_uuid_and_value_size\n");
}

static void test_other_requests_are_not_this(void) {
    unsigned char request[16 + 2] = {0};
    char uuid[LIBDC_BLE_UUID_STRING_SIZE];
    size_t value_size = 99;
    // The WRITE twin shares type and number; only the direction differs.
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_CHARACTERISTIC_WRITE, request, sizeof(request),
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_NOT_THIS);
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_GET_NAME, request, sizeof(request),
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_NOT_THIS);
    assert(value_size == 99);  // untouched
    printf("PASS: test_other_requests_are_not_this\n");
}

static void test_request_without_room_for_a_value_is_invalid(void) {
    unsigned char request[16] = {0};
    char uuid[LIBDC_BLE_UUID_STRING_SIZE];
    size_t value_size = 0;
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_CHARACTERISTIC_READ, request, 16,
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_INVALID);
    assert(libdc_ble_characteristic_read_decode(
               DC_IOCTL_BLE_CHARACTERISTIC_READ, NULL, 21,
               uuid, &value_size) == LIBDC_BLE_CHAR_READ_INVALID);
    printf("PASS: test_request_without_room_for_a_value_is_invalid\n");
}

static void test_fill_copies_exact_value_after_the_uuid(void) {
    unsigned char request[16 + 5];
    memcpy(request, kCressiVersionUuid, 16);
    memset(request + 16, 0, 5);
    const unsigned char value[5] = {0x01, 0x02, 0x03, 0x04, 0x04};
    assert(libdc_ble_characteristic_read_fill(request, sizeof(request),
                                              value, 5) ==
           LIBDC_STATUS_SUCCESS);
    assert(memcmp(request, kCressiVersionUuid, 16) == 0);  // UUID intact
    assert(memcmp(request + 16, value, 5) == 0);
    printf("PASS: test_fill_copies_exact_value_after_the_uuid\n");
}

static void test_fill_truncates_a_longer_value(void) {
    unsigned char request[16 + 2] = {0};
    const unsigned char value[4] = {0xAA, 0xBB, 0xCC, 0xDD};
    assert(libdc_ble_characteristic_read_fill(request, sizeof(request),
                                              value, 4) ==
           LIBDC_STATUS_SUCCESS);
    assert(request[16] == 0xAA && request[17] == 0xBB);
    printf("PASS: test_fill_truncates_a_longer_value\n");
}

// A short value would leave libdivecomputer's pre-zeroed tail in place and
// be parsed as serial 0 / model 0. Refuse it instead (Review Focus 2).
static void test_fill_rejects_a_shorter_value(void) {
    unsigned char request[16 + 5] = {0};
    const unsigned char value[3] = {0x01, 0x02, 0x03};
    assert(libdc_ble_characteristic_read_fill(request, sizeof(request),
                                              value, 3) ==
           LIBDC_STATUS_DATAFORMAT);
    assert(libdc_ble_characteristic_read_fill(request, sizeof(request),
                                              NULL, 0) ==
           LIBDC_STATUS_DATAFORMAT);
    assert(libdc_ble_characteristic_read_fill(NULL, 21, value, 3) ==
           LIBDC_STATUS_INVALIDARGS);
    printf("PASS: test_fill_rejects_a_shorter_value\n");
}

int main(void) {
    test_request_constant_matches_libdivecomputer();
    test_decodes_uuid_and_value_size();
    test_other_requests_are_not_this();
    test_request_without_room_for_a_value_is_invalid();
    test_fill_copies_exact_value_after_the_uuid();
    test_fill_truncates_a_longer_value();
    test_fill_rejects_a_shorter_value();
    printf("All BLE characteristic read tests passed.\n");
    return 0;
}
```

Add to `test/native/CMakeLists.txt`, after the `test_usbhid_descriptor_match` block (same minimal source set, since `libdc_wrapper.c` pulls in descriptor code):

```cmake
# Issue #422: the Cressi Goa BLE backend reads its version block through
# DC_IOCTL_BLE_CHARACTERISTIC_READ. Every platform bridge decodes and fills
# that request with the shared helpers pinned here.
add_executable(test_ble_characteristic_read
    test_ble_characteristic_read.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${LIBDC_DIR}/src/descriptor.c
    ${LIBDC_DIR}/src/iterator.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/platform.c
    ${LIBDC_DIR}/src/version.c
)
target_include_directories(test_ble_characteristic_read PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)
```

and at the bottom with the other registrations:

```cmake
add_test(NAME test_ble_characteristic_read COMMAND test_ble_characteristic_read)
```

- [ ] **Step 2: Run the test to verify it fails**

Run (from `packages/libdivecomputer_plugin`; a bare `build` token in a command is refused by a permission rule, so the build dir is passed absolute):
```bash
cmake -S test/native -B "$PWD/.native-test-out" && cmake --build "$PWD/.native-test-out" --target test_ble_characteristic_read
```
Expected: compile FAILS with undeclared `LIBDC_IOCTL_BLE_CHARACTERISTIC_READ` / implicit declaration of `libdc_ble_characteristic_read_decode`.

- [ ] **Step 3: Implement**

Append to `libdc_wrapper.h` after the `libdc_io_callbacks_t` typedef:

```c
// ============================================================
// BLE Characteristic Read ioctl (issue #422)
// ============================================================

// Some dive computers keep data outside the serial-over-GATT stream. The
// Cressi Goa family has no BLE version command: libdivecomputer reads the
// serial, model and firmware from three extra characteristics through
// DC_IOCTL_BLE_CHARACTERISTIC_READ. The request buffer is the 16-byte
// big-endian characteristic UUID followed by the bytes to fill with its
// value; `size` covers both. The constants mirror libdivecomputer's
// ioctl.h/ble.h so this header stays free of its headers;
// test_ble_characteristic_read.c pins them against the real macros.
#define LIBDC_BLE_UUID_SIZE 16
#define LIBDC_BLE_UUID_STRING_SIZE 37
// DC_IOCTL_IOR('b', 3, DC_IOCTL_SIZE_VARIABLE)
#define LIBDC_IOCTL_BLE_CHARACTERISTIC_READ 0x40006203u

#define LIBDC_BLE_CHAR_READ_NOT_THIS 0   // some other ioctl
#define LIBDC_BLE_CHAR_READ_OK 1         // decoded
#define LIBDC_BLE_CHAR_READ_INVALID (-1) // right ioctl, unusable buffer

// Decode a characteristic read request. On LIBDC_BLE_CHAR_READ_OK, uuid_str
// receives the lowercase 8-4-4-4-12 form and *value_size the number of value
// bytes the bridge must supply. Anything else leaves both untouched.
int libdc_ble_characteristic_read_decode(
    unsigned int request, const void *data, size_t size,
    char uuid_str[LIBDC_BLE_UUID_STRING_SIZE], size_t *value_size);

// Copy a characteristic value into the request buffer after its UUID.
// Returns LIBDC_STATUS_SUCCESS when value_len covers the requested size (a
// longer value is truncated to it), LIBDC_STATUS_DATAFORMAT when it falls
// short (a zero-padded version block would be misparsed), and
// LIBDC_STATUS_INVALIDARGS for a malformed buffer.
int libdc_ble_characteristic_read_fill(void *data, size_t size,
                                       const unsigned char *value,
                                       size_t value_len);
```

Append to `libdc_wrapper.c` (add `#include <stdio.h>` to the include block if it is not already there):

```c
// ============================================================
// BLE Characteristic Read ioctl (issue #422)
// ============================================================

int libdc_ble_characteristic_read_decode(
    unsigned int request, const void *data, size_t size,
    char uuid_str[LIBDC_BLE_UUID_STRING_SIZE], size_t *value_size) {
    if (request != LIBDC_IOCTL_BLE_CHARACTERISTIC_READ) {
        return LIBDC_BLE_CHAR_READ_NOT_THIS;
    }
    if (data == NULL || size <= LIBDC_BLE_UUID_SIZE || uuid_str == NULL ||
        value_size == NULL) {
        return LIBDC_BLE_CHAR_READ_INVALID;
    }
    const unsigned char *u = (const unsigned char *)data;
    snprintf(uuid_str, LIBDC_BLE_UUID_STRING_SIZE,
             "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-"
             "%02x%02x%02x%02x%02x%02x",
             u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9],
             u[10], u[11], u[12], u[13], u[14], u[15]);
    *value_size = size - LIBDC_BLE_UUID_SIZE;
    return LIBDC_BLE_CHAR_READ_OK;
}

int libdc_ble_characteristic_read_fill(void *data, size_t size,
                                       const unsigned char *value,
                                       size_t value_len) {
    if (data == NULL || size <= LIBDC_BLE_UUID_SIZE) {
        return LIBDC_STATUS_INVALIDARGS;
    }
    size_t wanted = size - LIBDC_BLE_UUID_SIZE;
    if (value == NULL || value_len < wanted) {
        return LIBDC_STATUS_DATAFORMAT;
    }
    memcpy((unsigned char *)data + LIBDC_BLE_UUID_SIZE, value, wanted);
    return LIBDC_STATUS_SUCCESS;
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cmake --build "$PWD/.native-test-out" --target test_ble_characteristic_read && "$PWD/.native-test-out/test_ble_characteristic_read"
```
Expected: `All BLE characteristic read tests passed.`

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.c packages/libdivecomputer_plugin/test/native/test_ble_characteristic_read.c packages/libdivecomputer_plugin/test/native/CMakeLists.txt
git commit -m "feat(libdc): shared decoding for the BLE characteristic read ioctl (#422)"
```

---

### Task 2: Resolve the product a Cressi Goa device reports about itself

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` (next to `libdc_descriptor_transports`, ~line 100)
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.c`
- Create: `packages/libdivecomputer_plugin/test/native/test_reported_product.c`
- Modify: `packages/libdivecomputer_plugin/test/native/CMakeLists.txt`

**Interfaces:**
- Produces (used by Task 3):
  ```c
  int libdc_resolve_reported_product(const char *vendor, const char *product,
      unsigned int model, unsigned int reported_model,
      char *product_out, size_t product_out_size);
  ```
  Returns 1 and writes the descriptor product when the reported model names a DIFFERENT row of the same vendor and an allowlisted family; 0 otherwise (and `product_out` is left untouched).

- [ ] **Step 1: Write the failing test**

Create `test/native/test_reported_product.c`:

```c
// Pins which self-reported models may relabel a computer (issue #422).
// Linked against the real descriptor table: the rows, families and model
// codes under test are libdivecomputer's own, not copies.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "libdc_wrapper.h"

static void test_cressi_goa_model_code_relabels(void) {
    char out[64] = "untouched";
    // The Cressi adapter advertises "1_..." (Cartesio); the version block
    // says model 4.
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 4,
                                          out, sizeof(out)) == 1);
    assert(strcmp(out, "Donatello") == 0);
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 10,
                                          out, sizeof(out)) == 1);
    assert(strcmp(out, "Nepto") == 0);
    printf("PASS: test_cressi_goa_model_code_relabels\n");
}

static void test_same_model_is_no_relabel(void) {
    char out[64] = "untouched";
    assert(libdc_resolve_reported_product("Cressi", "Donatello", 4, 4,
                                          out, sizeof(out)) == 0);
    assert(strcmp(out, "untouched") == 0);
    printf("PASS: test_same_model_is_no_relabel\n");
}

static void test_unknown_goa_model_code_keeps_label(void) {
    char out[64] = "untouched";
    // No Goa row has model 7: a future model must not be guessed at.
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 7,
                                          out, sizeof(out)) == 0);
    assert(strcmp(out, "untouched") == 0);
    printf("PASS: test_unknown_goa_model_code_keeps_label\n");
}

static void test_other_families_never_relabel(void) {
    char out[64] = "untouched";
    // Cressi Leonardo is a different family; its model 4 row (Giotto) must
    // not be reachable through a DEVINFO model.
    assert(libdc_resolve_reported_product("Cressi", "Leonardo", 1, 4,
                                          out, sizeof(out)) == 0);
    // A non-Cressi family whose model 10 row (Petrel 3) exists: Shearwater
    // DEVINFO models are a private code space.
    assert(libdc_resolve_reported_product("Shearwater", "Petrel", 3, 10,
                                          out, sizeof(out)) == 0);
    assert(strcmp(out, "untouched") == 0);
    printf("PASS: test_other_families_never_relabel\n");
}

static void test_bad_arguments(void) {
    char out[64] = "untouched";
    assert(libdc_resolve_reported_product(NULL, "Cartesio", 1, 4,
                                          out, sizeof(out)) == 0);
    assert(libdc_resolve_reported_product("Cressi", NULL, 1, 4,
                                          out, sizeof(out)) == 0);
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 4,
                                          NULL, 64) == 0);
    assert(libdc_resolve_reported_product("Nobody", "Nothing", 1, 4,
                                          out, sizeof(out)) == 0);
    // The app matches descriptors by EXACT product string, so a truncated
    // name is worse than none.
    char tiny[4] = "abc";
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 4,
                                          tiny, sizeof(tiny)) == 0);
    assert(strcmp(tiny, "abc") == 0);
    assert(strcmp(out, "untouched") == 0);
    printf("PASS: test_bad_arguments\n");
}

int main(void) {
    test_cressi_goa_model_code_relabels();
    test_same_model_is_no_relabel();
    test_unknown_goa_model_code_keeps_label();
    test_other_families_never_relabel();
    test_bad_arguments();
    printf("All reported product tests passed.\n");
    return 0;
}
```

The Shearwater rows are `Petrel` (model 3) and `Petrel 3` (model 10) in `DC_FAMILY_SHEARWATER_PETREL` (descriptor.c:370, :378), so the reported model names a real row and only the allowlist can reject it.

CMake (same minimal source set as Task 1):

```cmake
# Issue #422: which self-reported DEVINFO models may relabel a computer.
add_executable(test_reported_product
    test_reported_product.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${LIBDC_DIR}/src/descriptor.c
    ${LIBDC_DIR}/src/iterator.c
    ${LIBDC_DIR}/src/array.c
    ${LIBDC_DIR}/src/platform.c
    ${LIBDC_DIR}/src/version.c
)
target_include_directories(test_reported_product PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)
```
```cmake
add_test(NAME test_reported_product COMMAND test_reported_product)
```

- [ ] **Step 2: Run to verify it fails**

```bash
cmake -S test/native -B "$PWD/.native-test-out" && cmake --build "$PWD/.native-test-out" --target test_reported_product
```
Expected: FAIL, implicit declaration of `libdc_resolve_reported_product`.

- [ ] **Step 3: Implement**

`libdc_wrapper.h`, after `libdc_usbhid_match`:

```c
// The product a device reported about itself, when that differs from the
// descriptor it was opened with (issue #422).
//
// A Cressi Donatello behind Cressi's Bluetooth adapter advertises "1_...",
// the Cartesio's model code, so the scan labels it a Cartesio. The version
// block the Goa backend reads during the download carries the real model
// code, in the same code space as the descriptor table.
//
// Only families on an allowlist are consulted: most families report a
// DEVINFO model in a private code space that does not index the descriptor
// table, and reading it as one would mislabel hardware.
//
// Returns 1 and copies the product into product_out when reported_model names
// a different row of the same vendor and family. Returns 0 otherwise,
// including when product_out is too small for the whole name (the app matches
// descriptors by exact product string).
int libdc_resolve_reported_product(const char *vendor, const char *product,
                                   unsigned int model,
                                   unsigned int reported_model,
                                   char *product_out, size_t product_out_size);
```

`libdc_wrapper.c` (the file already includes `descriptor.h` and `iterator.h`):

```c
// Families whose DEVINFO model shares the descriptor table's code space. Add
// one only with evidence from its backend source: the model must be read
// from the device and compared against descriptor model codes there.
static int reported_model_family_allowed(dc_family_t family) {
    return family == DC_FAMILY_CRESSI_GOA;
}

int libdc_resolve_reported_product(const char *vendor, const char *product,
                                   unsigned int model,
                                   unsigned int reported_model,
                                   char *product_out,
                                   size_t product_out_size) {
    if (vendor == NULL || product == NULL || product_out == NULL ||
        product_out_size == 0 || reported_model == model) {
        return 0;
    }

    dc_iterator_t *iter = NULL;
    if (dc_descriptor_iterator(&iter) != DC_STATUS_SUCCESS || iter == NULL) {
        return 0;
    }

    // Pass 1: the family of the descriptor the download used.
    dc_family_t family = DC_FAMILY_NULL;
    int found = 0;
    dc_descriptor_t *desc = NULL;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        const char *v = dc_descriptor_get_vendor(desc);
        const char *p = dc_descriptor_get_product(desc);
        if (!found && v != NULL && p != NULL && strcmp(v, vendor) == 0 &&
            strcmp(p, product) == 0 &&
            dc_descriptor_get_model(desc) == model) {
            family = dc_descriptor_get_type(desc);
            found = 1;
        }
        dc_descriptor_free(desc);
    }
    dc_iterator_free(iter);
    if (!found || !reported_model_family_allowed(family)) {
        return 0;
    }

    // Pass 2: the row the device named.
    if (dc_descriptor_iterator(&iter) != DC_STATUS_SUCCESS || iter == NULL) {
        return 0;
    }
    int resolved = 0;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        const char *v = dc_descriptor_get_vendor(desc);
        const char *p = dc_descriptor_get_product(desc);
        if (!resolved && v != NULL && p != NULL && strcmp(v, vendor) == 0 &&
            dc_descriptor_get_type(desc) == family &&
            dc_descriptor_get_model(desc) == reported_model) {
            size_t len = strlen(p);
            if (len < product_out_size) {
                memcpy(product_out, p, len + 1);
                resolved = 1;
            }
        }
        dc_descriptor_free(desc);
    }
    dc_iterator_free(iter);
    return resolved;
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cmake --build "$PWD/.native-test-out" --target test_reported_product && "$PWD/.native-test-out/test_reported_product"
```
Expected: `All reported product tests passed.`

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.c packages/libdivecomputer_plugin/test/native/test_reported_product.c packages/libdivecomputer_plugin/test/native/CMakeLists.txt
git commit -m "feat(libdc): resolve the Cressi Goa model a device reports about itself (#422)"
```

---

### Task 3: Keep the DEVINFO model on the download session, end to end over a scripted Cressi BLE iostream

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c` (`struct libdc_download_session` ~line 28, `download_state_t` ~line 40, `event_callback` ~line 249, `libdc_download_run` ~line 902-1040)
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` (next to `libdc_download_run`, ~line 356)
- Create: `packages/libdivecomputer_plugin/test/native/test_cressi_goa_ble_download.c`
- Modify: `packages/libdivecomputer_plugin/test/native/CMakeLists.txt`

**Interfaces:**
- Consumes: Task 1 helpers, Task 2 `libdc_resolve_reported_product`.
- Produces (used by Task 8 on every platform):
  ```c
  // After libdc_download_run: the descriptor product and model the device
  // reported about itself, when it differs from the one the download was
  // opened with (see libdc_resolve_reported_product). Returns 1 and fills
  // both outputs, or 0 when there is nothing to relabel.
  int libdc_download_session_reported_device(
      const libdc_download_session_t *session,
      char *product_out, size_t product_out_size, unsigned int *model_out);
  ```

- [ ] **Step 1: Write the failing end-to-end test**

This drives the REAL `cressi_goa.c` through `libdc_download_run` with a scripted `libdc_io_callbacks_t`, the way each platform bridge will. The script serves the three characteristic reads through the Task 1 helpers, then fails the first data read with `LIBDC_STATUS_IO` (the logbook command). The download fails, but by then DEVINFO has fired, which is all this test needs.

Create `test/native/test_cressi_goa_ble_download.c`:

```c
// Issue #422, end to end: the Cressi Goa BLE backend over a scripted BLE
// iostream. The platform bridges all answer DC_IOCTL_BLE_CHARACTERISTIC_READ
// through libdc_ble_characteristic_read_decode/_fill; this fake does the
// same, so the whole request/reply contract with the real cressi_goa.c is
// exercised here once. Without the ioctl the backend fails with "Failed to
// read the characteristic '6e400003-...'" before emitting DEVINFO.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "libdc_wrapper.h"

typedef struct {
    int ioctl_reads;
    int serve_reads;       // 0 = answer UNSUPPORTED like the old bridges
    size_t short_by;       // bytes to drop from each reply
} fake_io_t;

// Serial 0x00012345 LE, model 4 (Donatello), firmware 300 LE (data format
// v5), then the 2-byte third field. 5 + 2 + 2 bytes, as cressi_goa.c reads.
static const unsigned char kVersion03[5] = {0x45, 0x23, 0x01, 0x00, 0x04};
static const unsigned char kVersion04[2] = {0x2C, 0x01};
static const unsigned char kVersion05[2] = {0x00, 0x00};

static int fake_ioctl(void *userdata, unsigned int request, void *data,
                      size_t size) {
    fake_io_t *io = (fake_io_t *)userdata;
    char uuid[LIBDC_BLE_UUID_STRING_SIZE];
    size_t value_size = 0;
    int decoded = libdc_ble_characteristic_read_decode(request, data, size,
                                                       uuid, &value_size);
    if (decoded != LIBDC_BLE_CHAR_READ_OK || !io->serve_reads) {
        return LIBDC_STATUS_UNSUPPORTED;
    }
    io->ioctl_reads++;
    const unsigned char *value = NULL;
    size_t len = 0;
    if (strcmp(uuid, "6e400003-b5a3-f393-e0a9-e50e24dc10b8") == 0) {
        value = kVersion03; len = sizeof(kVersion03);
    } else if (strcmp(uuid, "6e400004-b5a3-f393-e0a9-e50e24dc10b8") == 0) {
        value = kVersion04; len = sizeof(kVersion04);
    } else if (strcmp(uuid, "6e400005-b5a3-f393-e0a9-e50e24dc10b8") == 0) {
        value = kVersion05; len = sizeof(kVersion05);
    } else {
        return LIBDC_STATUS_NOACCESS;
    }
    return libdc_ble_characteristic_read_fill(data, size, value,
                                              len - io->short_by);
}

static int fake_read(void *userdata, void *data, size_t size,
                     size_t *actual) {
    (void)userdata; (void)data; (void)size;
    if (actual) *actual = 0;
    return LIBDC_STATUS_IO;  // end the run at the logbook command
}

static int fake_write(void *userdata, const void *data, size_t size,
                      size_t *actual) {
    (void)userdata; (void)data;
    if (actual) *actual = size;
    return LIBDC_STATUS_SUCCESS;
}

static int fake_close(void *userdata) { (void)userdata; return 0; }

static int on_dive(const libdc_parsed_dive_t *dive, void *userdata) {
    (void)dive; (void)userdata;
    return 1;
}

typedef struct {
    int rc;
    unsigned int serial;
    unsigned int firmware;
    int has_reported;
    char product[64];
    unsigned int model;
    char error[256];
} run_result_t;

static run_result_t run(fake_io_t *io, const char *product,
                        unsigned int model) {
    run_result_t r;
    memset(&r, 0, sizeof(r));
    libdc_io_callbacks_t cbs;
    memset(&cbs, 0, sizeof(cbs));
    cbs.read = fake_read;
    cbs.write = fake_write;
    cbs.ioctl = fake_ioctl;
    cbs.close = fake_close;
    cbs.userdata = io;
    libdc_download_callbacks_t dl;
    memset(&dl, 0, sizeof(dl));
    dl.on_dive = on_dive;

    libdc_download_session_t *session = libdc_download_session_new();
    assert(session != NULL);
    libdc_clock_sync_status_t clock = LIBDC_CLOCK_SYNC_NOT_REQUESTED;
    r.rc = libdc_download_run(session, "Cressi", product, model,
                              LIBDC_TRANSPORT_BLE, &cbs, NULL, 0, 0, &dl,
                              &r.serial, &r.firmware, &clock, r.error,
                              sizeof(r.error));
    r.has_reported = libdc_download_session_reported_device(
        session, r.product, sizeof(r.product), &r.model);
    libdc_download_session_free(session);
    return r;
}

static void test_unanswered_ioctl_reproduces_the_issue(void) {
    fake_io_t io = {0, 0, 0};
    run_result_t r = run(&io, "Cartesio", 1);
    assert(r.rc != 0);
    assert(strstr(r.error, "Failed to read the characteristic") != NULL);
    assert(r.has_reported == 0);
    printf("PASS: test_unanswered_ioctl_reproduces_the_issue\n");
}

static void test_served_reads_reach_devinfo_and_relabel(void) {
    fake_io_t io = {0, 1, 0};
    run_result_t r = run(&io, "Cartesio", 1);
    assert(io.ioctl_reads == 3);
    assert(r.serial == 0x00012345u);
    assert(r.firmware == 300u);
    assert(strstr(r.error, "Failed to read the characteristic") == NULL);
    assert(r.has_reported == 1);
    assert(strcmp(r.product, "Donatello") == 0);
    assert(r.model == 4);
    printf("PASS: test_served_reads_reach_devinfo_and_relabel\n");
}

static void test_correct_label_reports_nothing(void) {
    fake_io_t io = {0, 1, 0};
    run_result_t r = run(&io, "Donatello", 4);
    assert(r.serial == 0x00012345u);
    assert(r.has_reported == 0);
    printf("PASS: test_correct_label_reports_nothing\n");
}

static void test_short_reply_fails_instead_of_misparsing(void) {
    fake_io_t io = {0, 1, 1};
    run_result_t r = run(&io, "Cartesio", 1);
    assert(r.rc != 0);
    assert(r.serial == 0);
    assert(r.has_reported == 0);
    printf("PASS: test_short_reply_fails_instead_of_misparsing\n");
}

int main(void) {
    test_unanswered_ioctl_reproduces_the_issue();
    test_served_reads_reach_devinfo_and_relabel();
    test_correct_label_reports_nothing();
    test_short_reply_fails_instead_of_misparsing();
    printf("All Cressi Goa BLE download tests passed.\n");
    return 0;
}
```

CMake, modeled on `test_download_clock_sync` (full library + wrapper + download), placed after it:

```cmake
# Issue #422: the real Cressi Goa backend over a scripted BLE iostream that
# answers the characteristic read ioctl the way every platform bridge does.
add_executable(test_cressi_goa_ble_download
    test_cressi_goa_ble_download.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_cressi_goa_ble_download PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_cressi_goa_ble_download PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_cressi_goa_ble_download PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_cressi_goa_ble_download PRIVATE SetupAPI.lib ws2_32.lib)
endif()
```
```cmake
add_test(NAME test_cressi_goa_ble_download COMMAND test_cressi_goa_ble_download)
```

- [ ] **Step 2: Run to verify it fails**

```bash
cmake -S test/native -B "$PWD/.native-test-out" && cmake --build "$PWD/.native-test-out" --target test_cressi_goa_ble_download
```
Expected: FAIL to link/compile on `libdc_download_session_reported_device`. (Temporarily commenting the getter call out would show `test_unanswered_ioctl_reproduces_the_issue` passing and the served case reaching DEVINFO; that is the evidence the fake reproduces the reporter's log line. Do not commit that.)

- [ ] **Step 3: Implement in `libdc_download.c`**

1. In `struct libdc_download_session`, after `last_error`:
   ```c
       // The product and model the device reported about itself when they
       // differ from the descriptor the run was opened with (issue #422).
       // Reset at the start of every run; read back through
       // libdc_download_session_reported_device.
       int has_reported_device;
       unsigned int reported_model;
       char reported_product[64];
   ```
2. In `download_state_t`, after `firmware`:
   ```c
       unsigned int devinfo_model;
       int has_devinfo_model;
   ```
3. In `event_callback`'s `DC_EVENT_DEVINFO` branch, after `state->firmware = devinfo->firmware;`:
   ```c
           state->devinfo_model = devinfo->model;
           state->has_devinfo_model = 1;
   ```
4. In `libdc_download_run`, next to `session->last_error[0] = '\0';`:
   ```c
       session->has_reported_device = 0;
       session->reported_model = 0;
       session->reported_product[0] = '\0';
   ```
5. In `libdc_download_run`, directly after `status = dc_device_foreach(...)` (before the clock sync), regardless of `status`: DEVINFO precedes the dive transfer, so a run that fails later still identified the device.
   ```c
       // A device can name a different model than the one it advertised
       // (issue #422). Resolved here, where the opening descriptor is known,
       // so every binding reads one answer from the session.
       if (state.has_devinfo_model &&
           libdc_resolve_reported_product(
               vendor, product, dc_descriptor_get_model(state.descriptor),
               state.devinfo_model, session->reported_product,
               sizeof(session->reported_product))) {
           session->reported_model = state.devinfo_model;
           session->has_reported_device = 1;
       }
   ```
6. Add the getter near `libdc_download_cancel`:
   ```c
   int libdc_download_session_reported_device(
       const libdc_download_session_t *session,
       char *product_out, size_t product_out_size, unsigned int *model_out) {
       if (session == NULL || !session->has_reported_device ||
           product_out == NULL || product_out_size == 0) {
           return 0;
       }
       size_t len = strlen(session->reported_product);
       if (len >= product_out_size) {
           return 0;
       }
       memcpy(product_out, session->reported_product, len + 1);
       if (model_out != NULL) {
           *model_out = session->reported_model;
       }
       return 1;
   }
   ```
7. Declare it in `libdc_wrapper.h` after `libdc_download_cancel`, with the comment from the Interfaces block above.

- [ ] **Step 4: Run to verify it passes, then the whole native suite**

```bash
cmake --build "$PWD/.native-test-out" && ctest --test-dir "$PWD/.native-test-out" --output-on-failure
```
Expected: all tests pass, including the three new ones.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_download.c packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h packages/libdivecomputer_plugin/test/native/test_cressi_goa_ble_download.c packages/libdivecomputer_plugin/test/native/CMakeLists.txt
git commit -m "feat(libdc): keep the model a device reports on the download session (#422)"
```

---

### Task 4: Android characteristic read and Cressi service preference

**Files:**
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleCharacteristicRead.kt`
- Create: `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/BleCharacteristicReadTest.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` (`BleIoHandler`, :128-132)
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` (`jni_io_ioctl`, :449-601)
- Modify: `scripts/check_proguard_serial_keep.py` (`JNI_HANDLERS`, :74-77)

**Interfaces:**
- Consumes: Task 1 `libdc_ble_characteristic_read_decode` / `_fill` (from C++ via `libdc_wrapper.h`).
- Produces: `BleIoHandler.readCharacteristic(uuid: String): ByteArray?`, JNI signature `(Ljava/lang/String;)[B`. `null` means the read failed (not found, rejected, timed out, disconnected).

- [ ] **Step 1: Write the failing JVM test**

The Android framework cannot be instantiated in these JVM tests (plain JUnit 4, no Robolectric), so the testable logic lives in a pure object.

`BleCharacteristicReadTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BleCharacteristicReadTest {
    @Test
    fun parsesTheUuidStringTheJniLayerPasses() {
        assertEquals(
            UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dc10b8"),
            BleCharacteristicRead.parseUuid("6e400003-b5a3-f393-e0a9-e50e24dc10b8"),
        )
    }

    @Test
    fun rejectsAMalformedUuid() {
        assertNull(BleCharacteristicRead.parseUuid("not-a-uuid"))
        assertNull(BleCharacteristicRead.parseUuid(""))
    }

    @Test
    fun cressiServiceIsPreferred() {
        assertTrue(
            UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dc10b8") in
                BleCharacteristicRead.CRESSI_SERVICE_UUIDS
        )
    }

    // Every wait on the download thread must be bounded: libdivecomputer's
    // negative "no timeout" would otherwise block forever on a lost callback.
    @Test
    fun readWaitIsBounded() {
        assertEquals(10_000L, BleCharacteristicRead.readTimeoutMs(-1))
        assertEquals(10_000L, BleCharacteristicRead.readTimeoutMs(60_000))
        assertEquals(5_000L, BleCharacteristicRead.readTimeoutMs(5_000))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd packages/libdivecomputer_plugin/example/android 2>/dev/null || cd android; ./gradlew :libdivecomputer_plugin:testDebugUnitTest --tests '*BleCharacteristicReadTest*'
```
If there is no example app, run the plugin's unit tests the way CI does: `grep -n "testDebugUnitTest\|gradlew" .github/workflows/*.yml` and use that exact command (use the Android Studio JBR as `JAVA_HOME` if Gradle rejects the default JDK version string). Expected: FAIL, unresolved reference `BleCharacteristicRead`.

- [ ] **Step 3: Implement**

`BleCharacteristicRead.kt`:

```kotlin
package com.submersion.libdivecomputer

import java.util.UUID

// Pure helpers for libdivecomputer's BLE characteristic read ioctl (issue
// #422). The Cressi Goa backend reads its serial, model and firmware from
// three characteristics outside the serial-over-GATT stream, because its BLE
// protocol has no version command. libdc_jni.cpp decodes the request and
// calls BleIoStream.readCharacteristic with the UUID string.
object BleCharacteristicRead {
    // Cressi's UART-like service. Its UUIDs resemble Nordic UART but end in
    // ...e50e24dc10b8, and 6e400003 is a read-only version field here, not
    // the notify line.
    val CRESSI_SERVICE_UUIDS: Set<UUID> = setOf(
        UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dc10b8"),
    )

    private const val MAX_READ_TIMEOUT_MS = 10_000L

    fun parseUuid(value: String): UUID? =
        try {
            UUID.fromString(value)
        } catch (e: IllegalArgumentException) {
            null
        }

    fun readTimeoutMs(streamTimeoutMs: Int): Long =
        if (streamTimeoutMs < 0) MAX_READ_TIMEOUT_MS
        else minOf(streamTimeoutMs.toLong(), MAX_READ_TIMEOUT_MS)
}
```

`LibdcWrapper.kt`, in `interface BleIoHandler`, add:

```kotlin
    // Read a GATT characteristic by UUID (libdivecomputer's
    // DC_IOCTL_BLE_CHARACTERISTIC_READ, issue #422). Returns null on failure.
    fun readCharacteristic(uuid: String): ByteArray?
```

`BleIoStream.kt` changes:

1. Add `BleCharacteristicRead.CRESSI_SERVICE_UUIDS` into `PREFERRED_SERVICE_UUIDS` (spread it: `...UBLOX_SERVICE_UUID) + BleCharacteristicRead.CRESSI_SERVICE_UUIDS`, or list the UUID inline with a comment pointing to issue #422).
2. New fields next to `writeSemaphore`:
   ```kotlin
   // Characteristic read in flight (issue #422). Written on the download
   // thread before the read is issued, completed on the GATT callback thread.
   private val readCharacteristicSemaphore = Semaphore(0)
   @Volatile private var pendingReadUuid: UUID? = null
   @Volatile private var pendingReadValue: ByteArray? = null
   ```
3. In `gattCallback`, add both overloads (API 33+ and the deprecated one), each calling one private function:
   ```kotlin
   override fun onCharacteristicRead(
       gatt: BluetoothGatt,
       characteristic: BluetoothGattCharacteristic,
       value: ByteArray,
       status: Int
   ) {
       onReadComplete(characteristic, value, status)
   }

   @Deprecated("Deprecated in API 33")
   override fun onCharacteristicRead(
       gatt: BluetoothGatt,
       characteristic: BluetoothGattCharacteristic,
       status: Int
   ) {
       onReadComplete(characteristic, characteristic.value, status)
   }
   ```
   and on the outer class:
   ```kotlin
   private fun onReadComplete(
       characteristic: BluetoothGattCharacteristic,
       value: ByteArray?,
       status: Int
   ) {
       if (characteristic.uuid != pendingReadUuid) return
       pendingReadValue =
           if (status == BluetoothGatt.GATT_SUCCESS) value?.copyOf() else null
       NativeLogger.d(TAG, "BLE",
           "onCharacteristicRead ${characteristic.uuid} status=$status " +
               "bytes=${value?.size ?: 0}")
       readCharacteristicSemaphore.release()
   }
   ```
   A read reply arrives on `onCharacteristicRead`, never on `onCharacteristicChanged`, so it cannot leak into `readQueue`.
4. In the disconnect branch of `onConnectionStateChange` (next to `writeSemaphore.release()`), wake a waiting read:
   ```kotlin
   pendingReadValue = null
   readCharacteristicSemaphore.release()
   ```
5. The handler method (near `write()`):
   ```kotlin
   override fun readCharacteristic(uuid: String): ByteArray? {
       val target = BleCharacteristicRead.parseUuid(uuid) ?: return null
       val g = gatt ?: return null
       // libdivecomputer names only the characteristic, so search every
       // discovered service.
       val char = g.services
           ?.flatMap { it.characteristics }
           ?.firstOrNull { it.uuid == target }
       if (char == null) {
           NativeLogger.w(TAG, "BLE", "readCharacteristic: $uuid not found")
           return null
       }
       val timeout = BleCharacteristicRead.readTimeoutMs(currentTimeoutMs)
       // Same gate as command writes: Android runs one GATT operation at a
       // time, and a credit top-up must not be in flight.
       if (!gattOperation.tryAcquire(timeout, TimeUnit.MILLISECONDS)) {
           NativeLogger.e(TAG, "BLE", "readCharacteristic: GATT busy")
           return null
       }
       try {
           readCharacteristicSemaphore.drainPermits()
           pendingReadValue = null
           pendingReadUuid = target
           if (!g.readCharacteristic(char)) {
               NativeLogger.e(TAG, "BLE",
                   "readCharacteristic: readCharacteristic() returned false")
               return null
           }
           if (!readCharacteristicSemaphore.tryAcquire(
                   timeout, TimeUnit.MILLISECONDS)) {
               NativeLogger.e(TAG, "BLE", "readCharacteristic: $uuid timed out")
               return null
           }
           return pendingReadValue
       } finally {
           pendingReadUuid = null
           gattOperation.release()
       }
   }
   ```
   `currentTimeoutMs`: the JNI layer passes the stream timeout to `read`/`write` as an argument and nothing stores it on the Kotlin side. Keep the JNI signature to one string argument and use `BleCharacteristicRead.readTimeoutMs(-1)` (10 s), unless `BleIoStream` already keeps a timeout field (check with `grep -n "timeoutMs" BleIoStream.kt`; if it does, use it).

`libdc_jni.cpp`, in `jni_io_ioctl` before the final `return LIBDC_STATUS_UNSUPPORTED;`:

```cpp
    // Handle BLE characteristic reads (issue #422).
    {
        char uuid[LIBDC_BLE_UUID_STRING_SIZE];
        size_t value_size = 0;
        int decoded = libdc_ble_characteristic_read_decode(
            request, data, size, uuid, &value_size);
        if (decoded == LIBDC_BLE_CHAR_READ_INVALID) {
            return LIBDC_STATUS_INVALIDARGS;
        }
        if (decoded == LIBDC_BLE_CHAR_READ_OK) {
            JNIEnv *env;
            bool attached = false;
            if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env),
                                 JNI_VERSION_1_6) != JNI_OK) {
                ctx->jvm->AttachCurrentThread(&env, nullptr);
                attached = true;
            }
            jclass cls = env->GetObjectClass(ctx->ioHandler);
            jmethodID method = env->GetMethodID(cls, "readCharacteristic",
                "(Ljava/lang/String;)[B");
            env->DeleteLocalRef(cls);
            int status = LIBDC_STATUS_UNSUPPORTED;
            if (method == nullptr) {
                env->ExceptionClear();
            } else {
                jstring jUuid = env->NewStringUTF(uuid);
                auto jValue = (jbyteArray)env->CallObjectMethod(
                    ctx->ioHandler, method, jUuid);
                env->DeleteLocalRef(jUuid);
                if (env->ExceptionCheck()) {
                    env->ExceptionClear();
                    status = LIBDC_STATUS_IO;
                } else if (jValue == nullptr) {
                    status = LIBDC_STATUS_IO;
                } else {
                    jsize len = env->GetArrayLength(jValue);
                    jbyte *bytes = env->GetByteArrayElements(jValue, nullptr);
                    status = libdc_ble_characteristic_read_fill(
                        data, size, reinterpret_cast<unsigned char *>(bytes),
                        static_cast<size_t>(len));
                    env->ReleaseByteArrayElements(jValue, bytes, JNI_ABORT);
                    env->DeleteLocalRef(jValue);
                }
            }
            __android_log_print(ANDROID_LOG_DEBUG, TAG,
                "ioctl BLE_CHARACTERISTIC_READ %s (%zu bytes) -> %d",
                uuid, value_size, status);
            if (attached) ctx->jvm->DetachCurrentThread();
            return status;
        }
    }
```

`scripts/check_proguard_serial_keep.py`: add `"readCharacteristic"` to the `BleIoStream` tuple.

- [ ] **Step 4: Run tests and compile**

Rerun the Step 2 Gradle command (expected PASS), then compile the JNI + Kotlin: `flutter build apk --debug` from the repo root (or the CI's Android build command). Expected: builds. Run `python3.14 scripts/check_proguard_serial_keep.py --help` to confirm the script still parses (a full run needs a release mapping file; CI runs it).

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleCharacteristicRead.kt packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/BleCharacteristicReadTest.kt packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp scripts/check_proguard_serial_keep.py
git commit -m "fix(android): answer BLE characteristic reads for Cressi downloads (#422)"
```

---

### Task 5: Darwin characteristic read and Cressi service preference

**Files:**
- Create: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/PendingCharacteristicRead.swift`
- Create: `packages/libdivecomputer_plugin/darwin/Tests/PendingCharacteristicReadTests/main.swift`
- Create symlinks: `packages/libdivecomputer_plugin/ios/Classes/PendingCharacteristicRead.swift` and `packages/libdivecomputer_plugin/macos/Classes/PendingCharacteristicRead.swift`, both pointing at `../../darwin/Sources/LibDCDarwin/PendingCharacteristicRead.swift` (copy the relative form an existing symlink uses: `ls -l packages/libdivecomputer_plugin/ios/Classes/PacketReadBuffer.swift`)
- Modify: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift`
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleCharacteristicSelector.swift` (`preferredServiceUUIDs`, :126-133)
- Modify: `packages/libdivecomputer_plugin/darwin/Tests/BleCharacteristicSelectorTests/main.swift`

**Interfaces:**
- Consumes: Task 1 helpers (Swift sees `libdc_wrapper.h`).
- Produces: `final class PendingCharacteristicRead` with `begin(uuid: String)`, `complete(uuid: String, value: Data?) -> Bool`, `wait(timeout: DispatchTime) -> Data?`, `cancel()`.

- [ ] **Step 1: Write the failing tests**

`Tests/PendingCharacteristicReadTests/main.swift` (same harness style as `Tests/BleCharacteristicSelectorTests/main.swift`: an `expect(cond, msg)` helper and a `failures` counter, exit 1 on any failure):

```swift
import Foundation

var failures = 0
func expect(_ condition: Bool, _ message: String) {
    if !condition {
        failures += 1
        print("FAIL: \(message)")
    }
}

let uuid = "6E400003-B5A3-F393-E0A9-E50E24DC10B8"

// A reply for the characteristic being read is claimed and delivered.
do {
    let slot = PendingCharacteristicRead()
    slot.begin(uuid: uuid)
    let claimed = slot.complete(uuid: uuid, value: Data([1, 2, 3, 4, 4]))
    expect(claimed, "the pending read claims its own reply")
    expect(slot.wait(timeout: .now() + 1) == Data([1, 2, 3, 4, 4]),
        "the waiter receives the value")
}

// With nothing pending, a value update is NOT claimed, so it can go to the
// notification stream as before.
do {
    let slot = PendingCharacteristicRead()
    expect(!slot.complete(uuid: uuid, value: Data([9])),
        "no pending read claims nothing")
}

// A different characteristic's update is not claimed while a read waits.
do {
    let slot = PendingCharacteristicRead()
    slot.begin(uuid: uuid)
    expect(!slot.complete(uuid: "6E400002-B5A3-F393-E0A9-E50E24DC10B8",
                          value: Data([9])),
        "another characteristic's update is not claimed")
    slot.cancel()
}

// A second update for the same characteristic after the reply was claimed
// flows to the stream again (one reply per read).
do {
    let slot = PendingCharacteristicRead()
    slot.begin(uuid: uuid)
    _ = slot.complete(uuid: uuid, value: Data([1]))
    expect(!slot.complete(uuid: uuid, value: Data([2])),
        "only the first update after begin is the reply")
}

// An error reply (nil value) wakes the waiter with nil.
do {
    let slot = PendingCharacteristicRead()
    slot.begin(uuid: uuid)
    _ = slot.complete(uuid: uuid, value: nil)
    expect(slot.wait(timeout: .now() + 1) == nil, "an error reply yields nil")
}

// A timeout yields nil and clears the slot.
do {
    let slot = PendingCharacteristicRead()
    slot.begin(uuid: uuid)
    expect(slot.wait(timeout: .now() + .milliseconds(50)) == nil,
        "a timeout yields nil")
    expect(!slot.complete(uuid: uuid, value: Data([1])),
        "a late reply after the timeout is not claimed")
}

// cancel() (disconnect) wakes a waiter on another thread.
do {
    let slot = PendingCharacteristicRead()
    slot.begin(uuid: uuid)
    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(50)) {
        slot.cancel()
    }
    let start = Date()
    expect(slot.wait(timeout: .now() + 5) == nil, "cancel yields nil")
    expect(Date().timeIntervalSince(start) < 2, "cancel wakes the waiter")
}

// UUIDs compare case-insensitively (CBUUID.uuidString is uppercase, the C
// decoder emits lowercase).
do {
    let slot = PendingCharacteristicRead()
    slot.begin(uuid: uuid.lowercased())
    expect(slot.complete(uuid: uuid, value: Data([7])),
        "case differences do not matter")
}

if failures > 0 {
    print("\(failures) failure(s)")
    exit(1)
}
print("All PendingCharacteristicRead tests passed.")
```

Add to `Tests/BleCharacteristicSelectorTests/main.swift` (follow its existing construction of fake services; mirror the test that shows a preferred service beating a higher raw score):

```swift
// Issue #422: the Cressi service is preferred, as in Subsurface.
expect(BleCharacteristicSelector.preferredServiceUUIDs.contains(
    CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DC10B8")),
    "the Cressi service is preferred")
```
If the test file cannot import CoreBluetooth under `swiftc` (check how it builds CBUUIDs today), express the assertion in whatever UUID type it already uses.

`run_native_tests.sh`, next to the `packet_read_buffer_tests` block:

```bash
swiftc -o "$BUILD_DIR/pending_characteristic_read_tests" \
    Sources/LibDCDarwin/PendingCharacteristicRead.swift \
    Tests/PendingCharacteristicReadTests/main.swift
"$BUILD_DIR/pending_characteristic_read_tests"
```
(Match the script's existing pattern exactly: if it collects binaries and runs them in a loop, add the new one to that list instead of invoking it inline.)

- [ ] **Step 2: Run to verify it fails**

```bash
cd packages/libdivecomputer_plugin/darwin && ./run_native_tests.sh
```
Expected: FAIL, `cannot find 'PendingCharacteristicRead' in scope`.

- [ ] **Step 3: Implement**

`PendingCharacteristicRead.swift`:

```swift
import Foundation

/// One GATT characteristic read in flight (issue #422).
///
/// CoreBluetooth delivers a read reply through the same
/// `peripheral(_:didUpdateValueFor:error:)` callback as a notification, with
/// nothing to tell the two apart. While a read is pending, the first update
/// for its characteristic is the reply and must not reach the download's
/// packet buffer; every other update flows to it as before.
///
/// `begin`, `wait` and `cancel` run on the libdivecomputer thread; `complete`
/// runs on the CoreBluetooth delegate queue, which must never block (#394).
final class PendingCharacteristicRead {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var pendingUUID: String?
    private var value: Data?

    func begin(uuid: String) {
        while semaphore.wait(timeout: .now()) == .success {}
        lock.lock()
        pendingUUID = uuid.uppercased()
        value = nil
        lock.unlock()
    }

    /// Returns true when the update was this read's reply (consumed).
    func complete(uuid: String, value: Data?) -> Bool {
        lock.lock()
        guard let pending = pendingUUID, pending == uuid.uppercased() else {
            lock.unlock()
            return false
        }
        pendingUUID = nil
        self.value = value
        lock.unlock()
        semaphore.signal()
        return true
    }

    func wait(timeout: DispatchTime) -> Data? {
        let result = semaphore.wait(timeout: timeout)
        lock.lock()
        defer { lock.unlock() }
        pendingUUID = nil
        return result == .success ? value : nil
    }

    /// Wakes a waiter with no value (disconnect).
    func cancel() {
        lock.lock()
        let wasPending = pendingUUID != nil
        pendingUUID = nil
        value = nil
        lock.unlock()
        if wasPending { semaphore.signal() }
    }
}
```

`BleCharacteristicSelector.swift`: add to `preferredServiceUUIDs`:

```swift
        // Cressi (Goa family). Looks like Nordic UART but ends in
        // ...E50E24DC10B8; 6E400003 is a read-only version field here, read
        // through the characteristic read ioctl (issue #422).
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DC10B8"),
```

`BleIoStream.swift`:

1. Field: `private let pendingRead = PendingCharacteristicRead()` and `private static let characteristicReadTimeout: DispatchTimeInterval = .seconds(10)`.
2. `didUpdateValueFor`: route to the pending read FIRST, including the error case, before the existing error `return` and notify filter:
   ```swift
        // A characteristic read reply (issue #422) arrives here too. Claim it
        // before the notification path can buffer it as download data.
        if pendingRead.complete(uuid: characteristic.uuid.uuidString,
                                value: error == nil ? characteristic.value : nil) {
            return
        }
   ```
3. Where the stream handles a disconnect (the `didDisconnectPeripheral` delegate and `close`), call `pendingRead.cancel()`.
4. In `performIoctl`, before the final `return Int32(LIBDC_STATUS_UNSUPPORTED)`:
   ```swift
        var uuidBuffer = [CChar](repeating: 0,
                                 count: Int(LIBDC_BLE_UUID_STRING_SIZE))
        var valueSize: Int = 0
        let decoded = libdc_ble_characteristic_read_decode(
            request, data, size, &uuidBuffer, &valueSize)
        if decoded == LIBDC_BLE_CHAR_READ_INVALID {
            return Int32(LIBDC_STATUS_INVALIDARGS)
        }
        if decoded == LIBDC_BLE_CHAR_READ_OK, let data {
            let uuidString = String(cString: uuidBuffer)
            let target = CBUUID(string: uuidString)
            // libdivecomputer names only the characteristic; search every
            // discovered service.
            guard let characteristic = discoveredServices
                .flatMap({ $0.characteristics })
                .first(where: { $0.uuid == target }),
                  characteristic.properties.contains(.read) else {
                NativeLogger.w("BleIoStream", category: "BLE",
                    "ioctl BLE_CHARACTERISTIC_READ \(uuidString) not readable")
                return Int32(LIBDC_STATUS_NOACCESS)
            }
            pendingRead.begin(uuid: characteristic.uuid.uuidString)
            peripheral.readValue(for: characteristic)
            guard let value = pendingRead.wait(
                timeout: .now() + Self.characteristicReadTimeout) else {
                NativeLogger.e("BleIoStream", category: "BLE",
                    "ioctl BLE_CHARACTERISTIC_READ \(uuidString) failed")
                return Int32(LIBDC_STATUS_IO)
            }
            let status = value.withUnsafeBytes { bytes in
                libdc_ble_characteristic_read_fill(
                    data, size,
                    bytes.bindMemory(to: UInt8.self).baseAddress,
                    value.count)
            }
            NativeLogger.d("BleIoStream", category: "BLE",
                "ioctl BLE_CHARACTERISTIC_READ \(uuidString)"
                    + " bytes=\(value.count) -> \(status)")
            return status
        }
   ```
   The exact Swift spelling of the C constants (`LIBDC_BLE_CHAR_READ_INVALID` as `Int32`, `LIBDC_BLE_UUID_STRING_SIZE` as `Int32`) follows how the file already uses `LIBDC_STATUS_*`; adjust casts to compile. `peripheral.readValue` may be called from the libdc thread: CoreBluetooth methods are thread-safe to call, and the reply is delivered on the delegate queue, which is not blocked.

- [ ] **Step 4: Run tests and compile**

```bash
cd packages/libdivecomputer_plugin/darwin && ./run_native_tests.sh
```
Expected: all pass, including the new file. Then from the repo root `flutter build macos --debug` (compiles the plugin Swift). Expected: builds.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/PendingCharacteristicRead.swift packages/libdivecomputer_plugin/darwin/Tests/PendingCharacteristicReadTests/main.swift packages/libdivecomputer_plugin/ios/Classes/PendingCharacteristicRead.swift packages/libdivecomputer_plugin/macos/Classes/PendingCharacteristicRead.swift packages/libdivecomputer_plugin/darwin/run_native_tests.sh packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleCharacteristicSelector.swift packages/libdivecomputer_plugin/darwin/Tests/BleCharacteristicSelectorTests/main.swift
git commit -m "fix(darwin): answer BLE characteristic reads for Cressi downloads (#422)"
```

---

### Task 6: Linux characteristic read (BlueZ ReadValue)

**Files:**
- Modify: `packages/libdivecomputer_plugin/linux/ble_io_stream.h` (struct fields)
- Modify: `packages/libdivecomputer_plugin/linux/ble_io_stream.c` (`ble_ioctl` :777-859, `on_properties_changed` :330-380, connect loop :451-546)

There is no Linux native test harness and CI only builds Linux (`build-linux` in `.github/workflows/native-plugin-tests.yml`). The request decoding and reply filling are already tested once in Task 1/3; this task is compile-verified in CI. Keep the new code small and mechanical.

Linux selects characteristics from BlueZ's flat object list with no service tier, so there is no preferred-service list to extend (Design decision 3).

**Interfaces:**
- Consumes: Task 1 helpers.

- [ ] **Step 1: Store the characteristic map during connect**

In `ble_io_stream.h`, add to `BleIoStream`:

```c
    // Every GATT characteristic under the device, UUID (lowercase) -> object
    // path, for DC_IOCTL_BLE_CHARACTERISTIC_READ (issue #422).
    GHashTable* characteristic_paths;
    // A characteristic read of the notify characteristic makes BlueZ emit a
    // PropertiesChanged "Value" for it as well; that echo is not download
    // data. Guarded by read_mutex.
    GByteArray* suppress_notify_echo;
```

In `ble_io_stream_new`: `stream->characteristic_paths = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free); stream->suppress_notify_echo = NULL;`. Free both where the stream frees its other members (`g_hash_table_unref`, `g_byte_array_unref` if non-NULL). In the connect loop right after `const gchar* uuid = g_variant_get_string(uuid_var, NULL);`:

```c
        g_hash_table_replace(stream->characteristic_paths,
                             g_ascii_strdown(uuid, -1), g_strdup(obj_path));
```
Clear the table at the start of `ble_io_stream_connect` (`g_hash_table_remove_all`) so a reconnect does not keep stale paths.

- [ ] **Step 2: Implement the ioctl branch**

In `ble_ioctl`, before the final `return LIBDC_STATUS_UNSUPPORTED;`:

```c
    // Characteristic reads (issue #422): the Cressi Goa backend reads its
    // version block from three extra characteristics.
    {
        char uuid[LIBDC_BLE_UUID_STRING_SIZE];
        size_t value_size = 0;
        int decoded = libdc_ble_characteristic_read_decode(
            request, data, size, uuid, &value_size);
        if (decoded == LIBDC_BLE_CHAR_READ_INVALID) {
            return LIBDC_STATUS_INVALIDARGS;
        }
        if (decoded == LIBDC_BLE_CHAR_READ_OK) {
            const gchar* path =
                g_hash_table_lookup(stream->characteristic_paths, uuid);
            if (path == NULL) {
                g_warning("BleIoStream: characteristic %s not found", uuid);
                return LIBDC_STATUS_NOACCESS;
            }
            GVariantBuilder opts;
            g_variant_builder_init(&opts, G_VARIANT_TYPE("a{sv}"));
            g_autoptr(GError) error = NULL;
            GVariant* reply = g_dbus_connection_call_sync(
                stream->connection, "org.bluez", path,
                "org.bluez.GattCharacteristic1", "ReadValue",
                g_variant_new("(a{sv})", &opts), G_VARIANT_TYPE("(ay)"),
                G_DBUS_CALL_FLAGS_NONE, MIN(stream->timeout_ms, 10000),
                NULL, &error);
            if (error != NULL || reply == NULL) {
                g_warning("BleIoStream: ReadValue %s failed: %s", uuid,
                          error ? error->message : "no reply");
                return LIBDC_STATUS_IO;
            }
            GVariant* bytes_var = g_variant_get_child_value(reply, 0);
            gsize n_bytes = 0;
            const guint8* bytes = g_variant_get_fixed_array(
                bytes_var, &n_bytes, sizeof(guint8));
            int status = libdc_ble_characteristic_read_fill(
                data, size, bytes, n_bytes);
            if (status == LIBDC_STATUS_SUCCESS &&
                g_strcmp0(path, stream->notify_path) == 0) {
                g_mutex_lock(&stream->read_mutex);
                if (stream->suppress_notify_echo) {
                    g_byte_array_unref(stream->suppress_notify_echo);
                }
                stream->suppress_notify_echo =
                    g_byte_array_sized_new((guint)n_bytes);
                g_byte_array_append(stream->suppress_notify_echo, bytes,
                                    (guint)n_bytes);
                g_mutex_unlock(&stream->read_mutex);
            }
            g_variant_unref(bytes_var);
            g_variant_unref(reply);
            return status;
        }
    }
```

`stream->timeout_ms` is `G_MAXINT32` for "no timeout" (`ble_set_timeout`); `MIN(..., 10000)` bounds it.

- [ ] **Step 3: Drop the echo in `on_properties_changed`**

Inside the `if (n_bytes > 0 && bytes)` block, replace the push with:

```c
        g_mutex_lock(&stream->read_mutex);
        GByteArray* echo = stream->suppress_notify_echo;
        if (echo != NULL && echo->len == n_bytes &&
            memcmp(echo->data, bytes, n_bytes) == 0) {
            // The PropertiesChanged BlueZ emits for our own ReadValue on the
            // notify characteristic, not a packet (issue #422).
            g_byte_array_unref(echo);
            stream->suppress_notify_echo = NULL;
            g_mutex_unlock(&stream->read_mutex);
            g_variant_unref(value_var);
            return;
        }
        GByteArray* chunk = g_byte_array_sized_new((guint)n_bytes);
        g_byte_array_append(chunk, bytes, (guint)n_bytes);
        g_queue_push_tail(stream->read_chunks, chunk);
        g_cond_signal(&stream->read_cond);
        g_mutex_unlock(&stream->read_mutex);

        replenish_credits(stream);
```
(keep the original comment above `replenish_credits`). Also clear `suppress_notify_echo` in the purge callback when the input direction is purged, so a stale echo can never swallow a real packet later.

- [ ] **Step 4: Verify**

No local Linux toolchain or Docker (project rule: verification goes through Linux CI). Check syntax locally as far as possible: `clang -fsyntax-only $(pkg-config --cflags gio-2.0 2>/dev/null) -I packages/libdivecomputer_plugin/macos/Classes packages/libdivecomputer_plugin/linux/ble_io_stream.c` if GLib headers exist on this Mac (`brew list glib`); otherwise rely on the CI `build-linux` job, and say so in the final report.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/linux/ble_io_stream.h packages/libdivecomputer_plugin/linux/ble_io_stream.c
git commit -m "fix(linux): answer BLE characteristic reads for Cressi downloads (#422)"
```

---

### Task 7: Windows characteristic read and Cressi service preference

**Files:**
- Modify: `packages/libdivecomputer_plugin/windows/ble_io_stream.h`
- Modify: `packages/libdivecomputer_plugin/windows/ble_io_stream.cc` (`IoctlCallback` :809-880, `DiscoverCharacteristics` :240-513, preferred UUIDs :95-104 and :364)

WinRT's `ValueChanged` fires only for notifications, never for `ReadValueAsync`, so no echo handling is needed. Compile-verified in CI (`build-windows`); there is no Windows native test harness.

- [ ] **Step 1: Keep every discovered characteristic**

`ble_io_stream.h`: add a member `std::vector<winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::GattCharacteristic> all_characteristics_;` and a declaration `int ReadCharacteristic(const winrt::guid& uuid, void* data, size_t size);` plus `static const winrt::guid kCressiServiceUuid;`.

`ble_io_stream.cc`: at the top of `DiscoverCharacteristics` clear `all_characteristics_`; inside the per-service loop, where each service's `GetCharacteristicsAsync(...).get()` result is iterated (~:266-296), `all_characteristics_.push_back(ch);` for every characteristic.

- [ ] **Step 2: Prefer the Cressi service**

```cpp
// Cressi (Goa family). Looks like Nordic UART but ends in ...E50E24DC10B8;
// 6E400003 is a read-only version field here (issue #422).
const winrt::guid BleIoStream::kCressiServiceUuid{
    0x6E400001, 0xB5A3, 0xF393,
    {0xE0, 0xA9, 0xE5, 0x0E, 0x24, 0xDC, 0x10, 0xB8}};
```
and add `|| service.Uuid() == kCressiServiceUuid` to the `+1000` condition at :364.

- [ ] **Step 3: Implement the ioctl branch**

In `IoctlCallback`, before the final `return LIBDC_STATUS_UNSUPPORTED;`:

```cpp
    // Characteristic reads (issue #422).
    {
        char uuid[LIBDC_BLE_UUID_STRING_SIZE];
        size_t value_size = 0;
        int decoded = libdc_ble_characteristic_read_decode(
            request, data, size, uuid, &value_size);
        if (decoded == LIBDC_BLE_CHAR_READ_INVALID) {
            return LIBDC_STATUS_INVALIDARGS;
        }
        if (decoded == LIBDC_BLE_CHAR_READ_OK) {
            const auto* u = static_cast<const uint8_t*>(data);
            winrt::guid guid{
                (uint32_t(u[0]) << 24) | (uint32_t(u[1]) << 16) |
                    (uint32_t(u[2]) << 8) | uint32_t(u[3]),
                uint16_t((u[4] << 8) | u[5]),
                uint16_t((u[6] << 8) | u[7]),
                {u[8], u[9], u[10], u[11], u[12], u[13], u[14], u[15]}};
            return stream->ReadCharacteristic(guid, data, size);
        }
    }
```

and the member:

```cpp
int BleIoStream::ReadCharacteristic(const winrt::guid& uuid, void* data,
                                    size_t size) {
    try {
        for (const auto& ch : all_characteristics_) {
            if (ch.Uuid() != uuid) continue;
            auto result = ch.ReadValueAsync(BluetoothCacheMode::Uncached).get();
            if (result.Status() != GattCommunicationStatus::Success) {
                return LIBDC_STATUS_IO;
            }
            auto reader = DataReader::FromBuffer(result.Value());
            std::vector<uint8_t> value(reader.UnconsumedBufferLength());
            reader.ReadBytes(value);
            return libdc_ble_characteristic_read_fill(
                data, size, value.data(), value.size());
        }
        return LIBDC_STATUS_NOACCESS;
    } catch (...) {
        return LIBDC_STATUS_IO;
    }
}
```
Use the namespace aliases the file already uses for `BluetoothCacheMode`, `GattCommunicationStatus` and `DataReader` (check the `using` lines at the top; `DataReader` is already used at :649). Clear `all_characteristics_` in `Close()` with the other WinRT members.

- [ ] **Step 4: Verify**

No local Windows toolchain. Re-read the diff for WinRT API names against the existing uses in the same file, then rely on the CI `build-windows` job and say so in the final report.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/windows/ble_io_stream.h packages/libdivecomputer_plugin/windows/ble_io_stream.cc
git commit -m "fix(windows): answer BLE characteristic reads for Cressi downloads (#422)"
```

---

### Task 8: Carry the reported device to Dart (Pigeon + every platform caller)

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` (:311-316)
- Regenerate: `lib/src/generated/dive_computer_api.g.dart`, `android/.../DiveComputerApi.g.kt`, `ios/Classes/DiveComputerApi.g.swift`, `linux/dive_computer_api.g.{h,cc}`, `windows/dive_computer_api.g.{h,cc}`
- Modify: `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart` (:18-33, :144-155)
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`, `LibdcWrapper.kt`, `DiveComputerHostApiImpl.kt` (:449-491 and the in-process probe :596-649), `SerialDownloadRunner.kt` (:114-154), `SerialDownloadClient.kt` (:54-65), `android/src/main/aidl/.../IDiveDownloadCallback.aidl` (:12)
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` (`RunResult` :180-187, `runOnce` :306-352, `reportDownloadResult` :357-385, synthetic result :630)
- Modify: `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc` (:337-339, calls :388/:448/:497/:539, `CompleteData` :607-636)
- Modify: `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc` (:304-306, :419, :513, :544-549)
- Modify tests: `packages/libdivecomputer_plugin/test/dive_computer_service_test.dart` (:196, :227); hand-written fakes `test/helpers/fake_import_adapter_deps.dart`, `test/features/import_wizard/presentation/widgets/dc_adapter_steps_test.dart`, `test/features/dive_computer/presentation/widgets/download_step_widget_test.dart`, `test/features/dive_computer/presentation/widgets/scan_step_test_support.dart`

**Interfaces:**
- Consumes: Task 3 `libdc_download_session_reported_device`.
- Produces: `DiveComputerFlutterApi.onDownloadComplete(int totalDives, String? serialNumber, String? firmwareVersion, String? clockSyncStatus, String? reportedProduct, int? reportedModel)`; `DownloadCompleteEvent({..., String? reportedProduct, int? reportedModel})`.

- [ ] **Step 1: Write the failing plugin test**

In `packages/libdivecomputer_plugin/test/dive_computer_service_test.dart`, next to the existing `onDownloadComplete` tests:

```dart
    test('onDownloadComplete carries the model the device reported', () async {
      final events = <DownloadEvent>[];
      final sub = service.downloadEvents.listen(events.add);
      service.onDownloadComplete(3, '74565', '300', null, 'Donatello', 4);
      await pumpEventQueue();
      final complete = events.single as DownloadCompleteEvent;
      expect(complete.reportedProduct, 'Donatello');
      expect(complete.reportedModel, 4);
      await sub.cancel();
    });
```
(Use the file's existing setup for `service` and its existing event-collection idiom if it differs.)

- [ ] **Step 2: Run to verify it fails**

```bash
cd packages/libdivecomputer_plugin && flutter test test/dive_computer_service_test.dart
```
Expected: FAIL, too many positional arguments.

- [ ] **Step 3: Pigeon + Dart plugin**

`pigeons/dive_computer_api.dart`:
```dart
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
    String? clockSyncStatus,
    // The descriptor product and model code the device reported about
    // itself, when they differ from the ones it was scanned as (issue #422).
    String? reportedProduct,
    int? reportedModel,
  );
```
Regenerate: `cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart`. Confirm with `git status` that exactly the committed generated files changed and the header still says the same Pigeon version (if the local pigeon resolves to a different major/minor than the file headers' `v22.7.4`, stop and run `dart pub get` in the plugin so the locked version is used).

`dive_computer_service.dart`: add `final String? reportedProduct; final int? reportedModel;` to `DownloadCompleteEvent` (named, optional, with a doc comment naming issue #422), and forward both in `onDownloadComplete`.

Update the existing positional calls in `dive_computer_service_test.dart` (:196, :227) to pass `null, null`, and each hand-written fake's `onDownloadComplete` override to the new six-parameter signature.

- [ ] **Step 4: Android**

`libdc_jni.cpp`, a new JNI export next to `nativeDownloadCancel`:
```cpp
extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDownloadSessionReportedDevice(
    JNIEnv *env, jclass, jlong sessionPtr) {
    auto *session = reinterpret_cast<libdc_download_session_t *>(sessionPtr);
    char product[64];
    unsigned int model = 0;
    if (!libdc_download_session_reported_device(session, product,
                                                sizeof(product), &model)) {
        return nullptr;
    }
    jclass stringClass = env->FindClass("java/lang/String");
    jobjectArray result = env->NewObjectArray(2, stringClass, nullptr);
    env->SetObjectArrayElement(result, 0, env->NewStringUTF(product));
    char modelText[16];
    snprintf(modelText, sizeof(modelText), "%u", model);
    env->SetObjectArrayElement(result, 1, env->NewStringUTF(modelText));
    return result;
}
```
`LibdcWrapper.kt`: `external fun nativeDownloadSessionReportedDevice(sessionPtr: Long): Array<String>?` and in `LibdcDownloadInfo.kt` a pure helper with a JVM test:
```kotlin
// Decodes nativeDownloadSessionReportedDevice's [product, model] pair.
data class ReportedDevice(val product: String, val model: Long)

fun reportedDeviceOrNull(raw: Array<String>?): ReportedDevice? {
    if (raw == null || raw.size != 2 || raw[0].isEmpty()) return null
    val model = raw[1].toLongOrNull() ?: return null
    return ReportedDevice(raw[0], model)
}
```
Test in `LibdcDownloadInfoTest.kt`: `reportedDeviceOrNull(arrayOf("Donatello", "4")) == ReportedDevice("Donatello", 4)`, `null` for `null`, for `arrayOf("", "4")`, and for `arrayOf("Donatello", "x")`.

Call sites: in the BLE path (`DiveComputerHostApiImpl.kt` ~:485) read `val reported = reportedDeviceOrNull(LibdcWrapper.nativeDownloadSessionReportedDevice(sessionPtr))` BEFORE the session is freed and pass `reported?.product, reported?.model` to `onDownloadComplete`; log it next to the existing `Device info:` line. The in-process probe path (~:649) passes `null, null`. The `:dc` serial path: add `String reportedProduct, long reportedModel` to `IDiveDownloadCallback.onComplete` (AIDL has no nullable long; use `-1` for "none"), set them in `SerialDownloadRunner` from the runner's session, and map `-1`/empty back to `null` in `SerialDownloadClient` before calling `flutterApi.onDownloadComplete`.

- [ ] **Step 5: Darwin, Linux, Windows**

Each platform: after each `libdc_download_run` call and before the session is freed, call
```c
char reported_product[64];
unsigned int reported_model = 0;
int has_reported = libdc_download_session_reported_device(
    session, reported_product, sizeof(reported_product), &reported_model);
```
and pass `has_reported ? reported_product : NULL` / `has_reported ? reported_model : NULL` to the generated `onDownloadComplete` (Swift: add `reportedProduct: String?` and `reportedModel: Int64?` to `RunResult`, fill them in `runOnce`, pass them in both `reportDownloadResult` calls; the synthetic `RunResult` at :630 gets `nil`. Linux: add the two fields to `CompleteData` and free the string with the struct. Windows: `std::optional<std::string>` / `std::optional<int64_t>` following how `serial_str` is passed today). Use the generated signatures exactly as Pigeon produced them in Step 3.

- [ ] **Step 6: Verify**

```bash
cd packages/libdivecomputer_plugin && flutter test
cd ../.. && flutter test test/features/dive_computer test/features/import_wizard test/helpers
flutter build macos --debug && flutter build apk --debug
```
Run the plugin's Android JVM tests again (Task 4 Step 2 command). Expected: all pass, both builds succeed. Linux and Windows are verified by CI.

- [ ] **Step 7: Commit**

Stage every file listed under **Files** for this task explicitly (including each regenerated file), run `dart format .` from the repo root first, then:
```bash
git commit -m "feat(dive computer): report the model a device names during download (#422)"
```

---

### Task 9: Relabel a saved computer from the reported model

**Files:**
- Create: `lib/features/dive_computer/domain/services/reported_model_relabel.dart`
- Create: `test/features/dive_computer/domain/services/reported_model_relabel_test.dart`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart` (`DownloadState` :73-130, completion :309-326, `_persistDeviceInfo` :351-399)
- Create: `test/features/dive_computer/presentation/providers/download_notifier_reported_model_test.dart`

**Interfaces:**
- Consumes: Task 8 `DownloadCompleteEvent.reportedProduct/reportedModel`.
- Produces: `DiveComputer relabelToReportedProduct(DiveComputer computer, String? reportedProduct)`; `DownloadState.reportedProduct` (`String?`) and `DownloadState.reportedModel` (`int?`).

- [ ] **Step 1: Write the failing tests**

`reported_model_relabel_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/services/reported_model_relabel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

DiveComputer _computer({String name = 'Cressi Cartesio'}) {
  final now = DateTime(2026, 9, 26);
  return DiveComputer(
    id: 'dc-1',
    diverId: 'diver-1',
    name: name,
    manufacturer: 'Cressi',
    model: 'Cartesio',
    connectionType: 'bluetooth',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('relabelToReportedProduct (issue #422)', () {
    test('replaces the model and the default name', () {
      final relabeled = relabelToReportedProduct(_computer(), 'Donatello');
      expect(relabeled.model, 'Donatello');
      expect(relabeled.name, 'Cressi Donatello');
    });

    test('keeps a name the user chose', () {
      final relabeled = relabelToReportedProduct(
        _computer(name: 'My Cressi'),
        'Donatello',
      );
      expect(relabeled.model, 'Donatello');
      expect(relabeled.name, 'My Cressi');
    });

    test('treats surrounding whitespace in the default name as default', () {
      final relabeled = relabelToReportedProduct(
        _computer(name: ' Cressi Cartesio '),
        'Donatello',
      );
      expect(relabeled.name, 'Cressi Donatello');
    });

    test('is a no-op for null, blank or unchanged products', () {
      final computer = _computer();
      expect(identical(relabelToReportedProduct(computer, null), computer), isTrue);
      expect(identical(relabelToReportedProduct(computer, '  '), computer), isTrue);
      expect(identical(relabelToReportedProduct(computer, 'Cartesio'), computer), isTrue);
    });
  });
}
```

`download_notifier_reported_model_test.dart`: copy the setup of `download_notifier_address_rebind_test.dart` (mocks, `updates` capture, `completeDownload`) and change the fixtures to a Cressi computer (`manufacturer: 'Cressi'`, `model: 'Cartesio'`, `name: 'Cressi Cartesio'`, `serialNumber: '74565'`) and device (`recognizedModel: DeviceModel(id: 'cressi_cartesio', manufacturer: 'Cressi', model: 'Cartesio', connectionTypes: [DeviceConnectionType.ble], dcModel: 1)`). `completeDownload` sends `DownloadCompleteEvent(0, serialNumber: ..., firmwareVersion: ..., reportedProduct: ..., reportedModel: ...)`. Tests:

```dart
    test('relabels the saved computer to the reported model', () async {
      final saved = await completeDownload(
        computer: _savedComputer(),
        device: _device(_address),
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      expect(saved?.model, 'Donatello');
      expect(saved?.name, 'Cressi Donatello');
      expect(notifier.state.reportedProduct, 'Donatello');
      expect(notifier.state.reportedModel, 4);
    });

    test('keeps a custom name while relabeling', () async {
      final saved = await completeDownload(
        computer: _savedComputer(name: 'Dad\'s computer'),
        device: _device(_address),
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      expect(saved?.model, 'Donatello');
      expect(saved?.name, 'Dad\'s computer');
    });

    test('persists a relabel even when nothing else changed', () async {
      final saved = await completeDownload(
        computer: _savedComputer(),
        device: _device(_address),
        serialNumber: null,
        firmwareVersion: null,
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      expect(saved?.model, 'Donatello');
    });

    test('never relabels a record whose serial disagrees', () async {
      final saved = await completeDownload(
        computer: _savedComputer(serialNumber: '11111'),
        device: _device(_address),
        serialNumber: '74565',
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      expect(saved, isNull);
    });
```
Use one address for both the saved computer and the device so the address-rebind path does not by itself trigger a write in the "nothing else changed" test.

- [ ] **Step 2: Run to verify they fail**

```bash
flutter test test/features/dive_computer/domain/services/reported_model_relabel_test.dart test/features/dive_computer/presentation/providers/download_notifier_reported_model_test.dart
```
Expected: FAIL (missing file / missing named parameters). The mocks file for the new notifier test is generated by `dart run build_runner build --delete-conflicting-outputs`; run it once the test file exists.

- [ ] **Step 3: Implement**

`reported_model_relabel.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

/// The saved [computer] relabeled to the product the device reported about
/// itself during a download (issue #422).
///
/// A Cressi Donatello behind Cressi's Bluetooth adapter advertises the
/// Cartesio's model code, so it is saved as a "Cressi Cartesio". The version
/// block read during the download names the real model; the native layer
/// resolves it to an exact libdivecomputer product string, which is what
/// later downloads match descriptors against.
///
/// The name is replaced only while it is still the default one the app gave
/// the computer ("<manufacturer> <model>"); a name the diver chose is kept.
/// Returns [computer] itself when there is nothing to change.
DiveComputer relabelToReportedProduct(
  DiveComputer computer,
  String? reportedProduct,
) {
  final product = reportedProduct?.trim();
  if (product == null || product.isEmpty || product == computer.model) {
    return computer;
  }
  final hadDefaultName = computer.name.trim() == computer.fullName;
  final relabeled = computer.copyWith(model: product);
  return hadDefaultName
      ? relabeled.copyWith(name: relabeled.fullName)
      : relabeled;
}
```
(Check `DiveComputer.copyWith` accepts `model` and `name`; it must per project convention. `fullName` is `'$manufacturer $model'` when both are set.)

`download_providers.dart`:
1. `DownloadState`: add `final String? reportedProduct;` and `final int? reportedModel;` with a doc comment (issue #422), constructor params, and `copyWith` params following the `serialNumber` pattern.
2. Completion case: destructure `:final reportedProduct, :final reportedModel`, put them in `state.copyWith`, and call `_persistDeviceInfo(serialNumber, firmwareVersion, reportedProduct)`.
3. `_persistDeviceInfo(String? reportedSerialNumber, String? reportedFirmwareVersion, String? reportedProduct)`: after the serial-mismatch guard,
   ```dart
      final relabeled = relabelToReportedProduct(computer, reportedProduct);
      final address = _addressToRebind(computer);
      if (serialNumber == null &&
          firmwareVersion == null &&
          address == null &&
          identical(relabeled, computer)) {
        return;
      }
      final updated = relabeled.copyWith(
        serialNumber: serialNumber ?? computer.serialNumber,
        firmwareVersion: firmwareVersion ?? computer.firmwareVersion,
        bluetoothAddress: address ?? computer.bluetoothAddress,
      );
   ```
   and extend the method's doc comment with one sentence on the relabel.

- [ ] **Step 4: Run to verify they pass, plus the neighbours**

```bash
flutter test test/features/dive_computer
```
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_computer/domain/services/reported_model_relabel.dart test/features/dive_computer/domain/services/reported_model_relabel_test.dart lib/features/dive_computer/presentation/providers/download_providers.dart test/features/dive_computer/presentation/providers/download_notifier_reported_model_test.dart
git commit -m "feat(dive computer): relabel a saved computer from the model it reports (#422)"
```

---

### Task 10: New-computer identity, rebind and dive stamping in the import wizard

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` (`ensureComputer` :229-309)
- Modify: `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` (`_captureAndAdvance` :559-571)
- Test: `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`

**Interfaces:**
- Consumes: Task 9 `DownloadState.reportedProduct/reportedModel`, `relabelToReportedProduct`.
- Produces: `ensureComputer({required DiscoveredDevice device, String? serialNumber, String? firmwareVersion, String? reportedProduct, int? reportedModel})`.

- [ ] **Step 1: Write the failing tests**

In `dive_computer_adapter_test.dart`, follow the existing `ensureComputer` tests (find them with `grep -n "ensureComputer" test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`) and their mock repository. Add a Cressi `DiscoveredDevice` fixture scanned as Cartesio (`dcModel: 1`). Tests:

```dart
    test('creates a new computer under the reported model (issue #422)', () async {
      await adapter.ensureComputer(
        device: cressiScannedAsCartesio,
        serialNumber: '74565',
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      final created = verify(repository.createComputer(captureAny))
          .captured.single as DiveComputer;
      expect(created.manufacturer, 'Cressi');
      expect(created.model, 'Donatello');
      expect(created.name, 'Cressi Donatello');
    });

    test('rebinds and relabels a record an older build saved as Cartesio', () async {
      final old = cressiRecord(model: 'Cartesio', name: 'Cressi Cartesio');
      when(repository.findByHardwareIdentity(
        manufacturer: 'Cressi', model: 'Donatello',
        serialNumber: '74565', diverId: anyNamed('diverId'),
      )).thenAnswer((_) async => null);
      when(repository.findByHardwareIdentity(
        manufacturer: 'Cressi', model: 'Cartesio',
        serialNumber: '74565', diverId: anyNamed('diverId'),
      )).thenAnswer((_) async => old);

      await adapter.ensureComputer(
        device: cressiScannedAsCartesio,
        serialNumber: '74565',
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );

      verifyNever(repository.createComputer(any));
      final updated = verify(repository.updateComputer(captureAny))
          .captured.single as DiveComputer;
      expect(updated.id, old.id);
      expect(updated.model, 'Donatello');
      expect(updated.name, 'Cressi Donatello');
    });

    test('stamps imported dives with the reported descriptor', () async {
      await adapter.ensureComputer(
        device: cressiScannedAsCartesio,
        serialNumber: '74565',
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      // Read back through whatever the existing descriptor-capture test uses
      // (the fields feed the import service at :636-638, :708-726, :871-873).
      expect(adapter.descriptorProductForTest, 'Donatello');
      expect(adapter.descriptorModelForTest, 4);
    });

    test('without a reported model, behaviour is unchanged', () async {
      await adapter.ensureComputer(
        device: cressiScannedAsCartesio,
        serialNumber: '74565',
      );
      final created = verify(repository.createComputer(captureAny))
          .captured.single as DiveComputer;
      expect(created.model, 'Cartesio');
    });
```
If the adapter exposes no way to observe `_descriptorProduct`/`_descriptorModel`, check how an existing test asserts descriptor stamping (grep the test file for `descriptorProduct` or for the import-service call) and assert through the same seam; add `@visibleForTesting` getters only if no seam exists.

- [ ] **Step 2: Run to verify they fail**

```bash
flutter test test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart
```
Expected: FAIL, no named parameter `reportedProduct`.

- [ ] **Step 3: Implement**

In `ensureComputer`:

```dart
  Future<void> ensureComputer({
    required DiscoveredDevice device,
    String? serialNumber,
    String? firmwareVersion,
    String? reportedProduct,
    int? reportedModel,
  }) async {
    // Capture descriptor fields regardless of whether a computer record already
    // exists: these are always needed for the import service. A device that
    // named a different model during the download (issue #422) is stamped
    // with that one.
    final model = device.recognizedModel;
    final reported = reportedProduct?.trim();
    final hasReported =
        reported != null && reported.isNotEmpty && reportedModel != null;
    if (model != null) {
      _descriptorVendor = model.manufacturer;
      _descriptorProduct = hasReported ? reported : model.model;
      _descriptorModel = hasReported ? reportedModel : model.dcModel;
    }
```
Then, for the identity lookup, compute `final identityModel = hasReported ? reported : device.model?.trim();` and search with it first; when `hasReported` and nothing is found, search again with the scan-time `device.model` (records saved by older builds). On a match, build `rebound` from `relabelToReportedProduct(existing, hasReported ? reported : null).copyWith(...)` with the existing serial/firmware/connection/address fields. For a new record, use `model: identityModel` and `name: _customDeviceName ?? (hasReported ? '${device.manufacturer} $reported' : device.displayName)`. Keep every existing comment; add one line per new branch naming issue #422.

`dc_adapter_steps.dart` `_captureAndAdvance`: pass `reportedProduct: state.reportedProduct, reportedModel: state.reportedModel` to `ensureComputer`.

Update the other `ensureComputer` call sites, if any (`grep -rn "ensureComputer(" lib test`), only where they must compile; the new parameters are optional.

- [ ] **Step 4: Run to verify they pass, plus the neighbours**

```bash
flutter test test/features/import_wizard
```
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard/data/adapters/dive_computer_adapter.dart lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart
git commit -m "feat(import): save and stamp a new computer under the model it reports (#422)"
```

---

### Task 11: Family-aware same-model fallback

**Files:**
- Modify: `lib/features/dive_computer/domain/services/known_computer_reacquisition.dart`
- Test: `test/features/dive_computer/domain/services/known_computer_reacquisition_test.dart`

**Interfaces:**
- Produces: `const Map<String, Set<String>> interchangeableBleModels` (lowercase manufacturer to lowercase product set), exported for the pin test.

- [ ] **Step 1: Write the failing tests**

Add to `known_computer_reacquisition_test.dart` (reuse its fixture builders):

```dart
  group('interchangeable BLE models (issue #422)', () {
    test('a relabeled Cressi is found under its scan-time model', () {
      final computer = cressiComputer(model: 'Donatello');
      final scanned = bleDevice(manufacturer: 'Cressi', model: 'Cartesio');
      expect(
        sameModelFallbackDevice(computer: computer, discovered: [scanned]),
        same(scanned),
      );
    });

    test('two Cressi candidates are still ambiguous', () {
      final computer = cressiComputer(model: 'Donatello');
      expect(
        sameModelFallbackDevice(
          computer: computer,
          discovered: [
            bleDevice(manufacturer: 'Cressi', model: 'Cartesio'),
            bleDevice(manufacturer: 'Cressi', model: 'Donatello'),
          ],
        ),
        isNull,
      );
    });

    test('a Cressi Leonardo (other family) is not interchangeable', () {
      final computer = cressiComputer(model: 'Donatello');
      expect(
        sameModelFallbackDevice(
          computer: computer,
          discovered: [bleDevice(manufacturer: 'Cressi', model: 'Leonardo')],
        ),
        isNull,
      );
    });

    test('the Cressi group matches the Goa rows in descriptor.c', () {
      final source = File(p.join(
        'packages', 'libdivecomputer_plugin', 'third_party',
        'libdivecomputer', 'src', 'descriptor.c',
      )).readAsStringSync();
      final rows = RegExp(r'\{"Cressi",\s*"([^"]+)",\s*DC_FAMILY_CRESSI_GOA')
          .allMatches(source)
          .map((m) => m.group(1)!.toLowerCase())
          .toSet();
      expect(rows, isNotEmpty);
      expect(interchangeableBleModels['cressi'], rows);
    });
  });
```
Add `import 'dart:io';` and `import 'package:path/path.dart' as p;` at the top in the right groups. If the file has no `cressiComputer`/`bleDevice` builders, write small local ones next to the existing fixtures.

- [ ] **Step 2: Run to verify they fail**

```bash
flutter test test/features/dive_computer/domain/services/known_computer_reacquisition_test.dart
```
Expected: FAIL, `interchangeableBleModels` undefined and the first test returns null.

- [ ] **Step 3: Implement**

```dart
/// Models that one physical Bluetooth computer can be scanned as and saved as
/// under different names, keyed by lowercase manufacturer (issue #422).
///
/// The Cressi Goa family shares one protocol, and Cressi's Bluetooth adapter
/// advertises the Cartesio's model code whatever computer sits behind it. A
/// download relabels the saved record to the model the device reports, so the
/// saved "Donatello" is scanned again as a "Cartesio". Pinned to the
/// DC_FAMILY_CRESSI_GOA rows of libdivecomputer's descriptor table by a test.
const Map<String, Set<String>> interchangeableBleModels = {
  'cressi': {
    'cartesio',
    'goa',
    'leonardo 2.0',
    'donatello',
    'michelangelo',
    'neon',
    'nepto',
  },
};

bool _sameModel(String manufacturer, String a, String b) {
  if (a == b) return true;
  final group = interchangeableBleModels[manufacturer];
  return group != null && group.contains(a) && group.contains(b);
}
```
and in `sameModelFallbackDevice` replace `_normalize(device.model) == model` with `_sameModel(manufacturer, _normalize(device.model), model)`. Add one sentence to the function's doc comment: interchangeable models (see `interchangeableBleModels`) count as the same model.

- [ ] **Step 4: Run to verify they pass**

```bash
flutter test test/features/dive_computer/domain/services/known_computer_reacquisition_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_computer/domain/services/known_computer_reacquisition.dart test/features/dive_computer/domain/services/known_computer_reacquisition_test.dart
git commit -m "fix(dive computer): re-find a relabeled Cressi by its scan-time model (#422)"
```

---

### Task 12: Whole-branch verification

- [ ] **Step 1:** `dart format .` then `git diff --stat` (nothing should change).
- [ ] **Step 2:** `flutter analyze` from the repo root. Expected: `No issues found!` (infos are fatal in CI).
- [ ] **Step 3:** `flutter test test/architecture` (repo-wide guards scan all of `lib/`).
- [ ] **Step 4:** One full `flutter test` run (not overlapping any other test run; check `df -h /Volumes/fltmp` first if TMPDIR is that RAM disk). Expected: all pass.
- [ ] **Step 5:** Native: `ctest --test-dir "$PWD/.native-test-out" --output-on-failure` from `packages/libdivecomputer_plugin` and `darwin/run_native_tests.sh`. Expected: all pass. Delete `.native-test-out` afterwards (never commit it).
- [ ] **Step 6:** `git submodule status` shows the libdivecomputer pointer unchanged from `origin/main` (`git diff origin/main -- packages/libdivecomputer_plugin/third_party` is empty).
- [ ] **Step 7:** Grep the branch diff for the forbidden characters and names: `git diff origin/main | grep -nP '\x{2014}|\x{2013}'` and the attribution check from the repo development guide (no tool, model or vendor names, no co-author trailers) over `git log origin/main..HEAD` and the diff. Expected: nothing found.
