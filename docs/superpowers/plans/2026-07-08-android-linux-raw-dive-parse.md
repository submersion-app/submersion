# Raw Dive Parsing on Android and Linux Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `DiveComputerHostApi.parseRawDiveData` on Android and Linux so re-parsing a dive from its archived raw bytes stops failing with `PlatformException(UNSUPPORTED, ...)`.

**Architecture:** The C function that does the work, `libdc_parse_raw_dive()`, is already compiled into both platform binaries. Android gets two new JNI exports (`nativeParseRawDive` returning an opaque `jlong` handle, `nativeParsedDiveFree`) plus Kotlin glue that reuses the existing `convertParsedDive(divePtr)`. Linux gets a direct port of the existing Windows implementation, reusing the existing `convert_parsed_dive()`.

**Tech Stack:** C++/JNI (Android NDK, CMake), Kotlin (Pigeon host API), C++/GObject (Flutter Linux embedder), AndroidX instrumented tests.

**Spec:** `docs/superpowers/specs/2026-07-08-android-linux-raw-dive-parse-design.md`

## Global Constraints

- **No build-system changes.** `libdc_wrapper.c` and `libdc_download.c` are already compiled on every platform (`android/src/main/cpp/CMakeLists.txt:135`, `linux/CMakeLists.txt:158`). Do not touch any `CMakeLists.txt`.
- **No Pigeon or Dart changes.** `parseRawDiveData` is already declared in the Pigeon API and `lib/features/dive_computer/data/services/reparse_service.dart` is platform-agnostic.
- **Reference implementation is `windows/dive_computer_host_api_impl.cc:158`.** Error codes and message strings must match it exactly.
- **Error contract**, identical on both platforms:
  - `model` outside `unsigned int` range → code `PARSE_ERROR`, message `Invalid dive computer model number: <model>`
  - parse failure → code `PARSE_ERROR`, message `Failed to parse raw dive data: <error_buf>`
  - Android only, native library failed to load → code `native_library_unavailable`
- **Memory ownership of `libdc_parsed_dive_t`:** only `samples` and `events` are heap-allocated. `gasmixes`, `tanks` and `fingerprint` are inline arrays and must **not** be freed.
- **No `Co-Authored-By` lines in commit messages.**
- All paths below are relative to `packages/libdivecomputer_plugin/` unless stated otherwise.

## File Structure

| File | Responsibility |
| --- | --- |
| `android/src/main/cpp/libdc_jni.cpp` | Two new JNI exports and one static free helper. The free helper is the single place the ownership rule is written down. |
| `android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` | Two new `external fun` declarations. |
| `android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` | Implements `parseRawDiveData`: guards, threading, `try/finally` free, main-thread callback. |
| `android/src/androidTest/assets/shearwater_teric_dive.bin` | 22,144-byte real Shearwater Teric raw blob (new). |
| `android/src/androidTest/kotlin/com/submersion/libdivecomputer/RawDiveParseTest.kt` | Instrumented tests for the JNI boundary (new). |
| `linux/dive_computer_host_api_impl.cc` | Implements `handle_parse_raw_dive_data`. |

Task 1 delivers a tested JNI boundary. Task 2 delivers the Android host-API method on top of it. Task 3 is independent of both and delivers Linux. A reviewer could reject any one while approving the others.

---

### Task 1: Android JNI raw-parse boundary

**Files:**
- Create: `packages/libdivecomputer_plugin/android/src/androidTest/assets/shearwater_teric_dive.bin`
- Create: `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/RawDiveParseTest.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` (append after the Dive Data Access section, which ends at line 1101)
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt:89` (after `nativeGetDiveRawFingerprint`)

**Interfaces:**
- Consumes: `libdc_parse_raw_dive()` from `macos/Classes/libdc_wrapper.h:284`; the existing `nativeGetDiveXxx(divePtr: Long)` accessors.
- Produces:
  - `LibdcWrapper.nativeParseRawDive(vendor: String, product: String, model: Int, data: ByteArray, errorBuf: ByteArray): Long` — returns a `libdc_parsed_dive_t*` as a `Long`, or `0` on failure (with a NUL-terminated message written into `errorBuf`).
  - `LibdcWrapper.nativeParsedDiveFree(divePtr: Long)` — frees a handle returned above. Safe to call with `0`.

  Task 2 relies on both.

**Context an implementer needs:**

`model` is declared `jint` (signed 32-bit) but libdivecomputer wants an `unsigned int`. Kotlin therefore range-checks against `0xFFFFFFFF` *before* narrowing to `Int` (Task 2), and C reinterprets the bit pattern via `static_cast<unsigned int>`. This is exactly what `nativeDownloadRun` already does with its `model: Int` parameter.

The `errorBuf: ByteArray` out-parameter is the established convention in this file — see the copy-back block at `libdc_jni.cpp:780-787`, which this task's code mirrors.

- [ ] **Step 1: Extract the test fixture from the development database**

The fixture is a real Shearwater Teric blob. The same DB row records what the macOS parser produced from these exact bytes, which is where the expected values in Step 2 come from.

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
mkdir -p packages/libdivecomputer_plugin/android/src/androidTest/assets
DB="$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db"
sqlite3 "$DB" \
  "SELECT writefile('packages/libdivecomputer_plugin/android/src/androidTest/assets/shearwater_teric_dive.bin', raw_data) FROM dive_data_sources WHERE length(raw_data)=22144;"
```

Verify:

```bash
wc -c packages/libdivecomputer_plugin/android/src/androidTest/assets/shearwater_teric_dive.bin
```

Expected: `22144`

Ground truth recorded for this blob (`descriptor_vendor="Shearwater"`, `descriptor_product="Teric"`, `descriptor_model=8`):

| Field | Value |
| --- | --- |
| `max_depth` | `28.55976` m |
| `duration` | `1256` s |
| `entry_time` | epoch `1777820921` = `2026-05-03 15:08:41` (wall clock) |

Dive times are stored wall-clock-as-UTC by design, so those date parts are exactly what `nativeGetDiveYear`/`Month`/`Day`/`Hour`/`Minute`/`Second` must return.

- [ ] **Step 2: Write the failing test**

Create `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/RawDiveParseTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

// Exercises the nativeParseRawDive / nativeParsedDiveFree JNI boundary against
// a real Shearwater Teric raw dive blob. Instrumented rather than a plain JVM
// test because it needs ART and liblibdc_jni.so.
@RunWith(AndroidJUnit4::class)
class RawDiveParseTest {
    private lateinit var rawDive: ByteArray

    @Before
    fun setUp() {
        assertNull("native library failed to load", LibdcWrapper.loadError)
        rawDive = InstrumentationRegistry.getInstrumentation().context
            .assets.open(FIXTURE).use { it.readBytes() }
        assertEquals(22144, rawDive.size)
    }

    @Test
    fun parsesFixtureIntoExpectedFields() {
        val errorBuf = ByteArray(256)
        val ptr = LibdcWrapper.nativeParseRawDive(VENDOR, PRODUCT, MODEL, rawDive, errorBuf)
        assertNotEquals(errorMessage(errorBuf), 0L, ptr)
        try {
            assertEquals(28.55976, LibdcWrapper.nativeGetDiveMaxDepth(ptr), 0.001)
            assertEquals(1256, LibdcWrapper.nativeGetDiveDuration(ptr))
            assertEquals(2026, LibdcWrapper.nativeGetDiveYear(ptr))
            assertEquals(5, LibdcWrapper.nativeGetDiveMonth(ptr))
            assertEquals(3, LibdcWrapper.nativeGetDiveDay(ptr))
            assertEquals(15, LibdcWrapper.nativeGetDiveHour(ptr))
            assertEquals(8, LibdcWrapper.nativeGetDiveMinute(ptr))
            assertEquals(41, LibdcWrapper.nativeGetDiveSecond(ptr))
            assertTrue(LibdcWrapper.nativeGetDiveSampleCount(ptr) > 0)
        } finally {
            LibdcWrapper.nativeParsedDiveFree(ptr)
        }
    }

    @Test
    fun unknownDescriptorReturnsZeroAndWritesError() {
        val errorBuf = ByteArray(256)
        val ptr = LibdcWrapper.nativeParseRawDive(
            "Nonexistent", "Device", 0, rawDive, errorBuf
        )
        assertEquals(0L, ptr)
        assertTrue(errorMessage(errorBuf).contains("No descriptor"))
    }

    // A truncated blob must fail cleanly (or parse to a freeable handle) rather
    // than read past the end of the buffer.
    @Test
    fun truncatedDataDoesNotCrash() {
        val ptr = LibdcWrapper.nativeParseRawDive(
            VENDOR, PRODUCT, MODEL, rawDive.copyOf(32), ByteArray(256)
        )
        LibdcWrapper.nativeParsedDiveFree(ptr)
    }

    // Repeated parse/free must not accumulate native memory: nativeParsedDiveFree
    // has to release samples and events, not just the struct.
    @Test
    fun repeatedParseAndFreeSucceeds() {
        repeat(50) {
            val ptr = LibdcWrapper.nativeParseRawDive(
                VENDOR, PRODUCT, MODEL, rawDive, ByteArray(256)
            )
            assertNotEquals(0L, ptr)
            LibdcWrapper.nativeParsedDiveFree(ptr)
        }
    }

    private fun errorMessage(errorBuf: ByteArray) = String(errorBuf).trim('\u0000')

    private companion object {
        const val FIXTURE = "shearwater_teric_dive.bin"
        const val VENDOR = "Shearwater"
        const val PRODUCT = "Teric"
        const val MODEL = 8
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Start an emulator first (the `Medium Phone API 36.1` AVD is fine), then:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter pub get
cd android
./gradlew :libdivecomputer_plugin:connectedAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.submersion.libdivecomputer.RawDiveParseTest
```

Expected: compilation failure — `Unresolved reference: nativeParseRawDive`.

- [ ] **Step 4: Declare the natives in `LibdcWrapper.kt`**

Insert after `external fun nativeGetDiveRawFingerprint(divePtr: Long): ByteArray?` (line 89):

```kotlin

    // Standalone raw dive parsing (re-parse of archived bytes).
    // nativeParseRawDive returns a libdc_parsed_dive_t* as a Long, or 0 on
    // failure, in which case errorBuf receives a NUL-terminated message.
    // The returned handle must be released with nativeParsedDiveFree.
    external fun nativeParseRawDive(
        vendor: String,
        product: String,
        model: Int,
        data: ByteArray,
        errorBuf: ByteArray
    ): Long

    external fun nativeParsedDiveFree(divePtr: Long)
```

- [ ] **Step 5: Implement the JNI exports**

Append to the end of `android/src/main/cpp/libdc_jni.cpp`:

```cpp

// ============================================================
// Standalone Raw Dive Parsing
// ============================================================

// Releases a dive allocated by nativeParseRawDive. Inside libdc_parsed_dive_t
// only `samples` and `events` are heap-allocated; `gasmixes`, `tanks` and
// `fingerprint` are inline arrays and must not be freed. This is the only
// place that rule is expressed.
static void free_parsed_dive(libdc_parsed_dive_t *dive) {
    if (dive == nullptr) return;
    free(dive->samples);
    free(dive->events);
    free(dive);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeParseRawDive(
    JNIEnv *env, jclass,
    jstring vendor, jstring product, jint model,
    jbyteArray data, jbyteArray errorBuf) {

    // Heap-allocated because Kotlin reads the fields afterwards through the
    // nativeGetDiveXxx accessors, which need the struct to outlive this call.
    auto *dive = static_cast<libdc_parsed_dive_t *>(
        calloc(1, sizeof(libdc_parsed_dive_t)));
    if (dive == nullptr) return 0;

    const char *vendorStr = env->GetStringUTFChars(vendor, nullptr);
    const char *productStr = env->GetStringUTFChars(product, nullptr);
    jsize dataLen = env->GetArrayLength(data);
    jbyte *dataPtr = env->GetByteArrayElements(data, nullptr);

    char error_buf[256] = {0};

    // model was range-checked in Kotlin against UINT32_MAX before narrowing to
    // jint, so this reinterprets the bit pattern rather than losing a value.
    int rc = libdc_parse_raw_dive(
        vendorStr, productStr, static_cast<unsigned int>(model),
        reinterpret_cast<const unsigned char *>(dataPtr),
        static_cast<unsigned int>(dataLen),
        dive, error_buf, sizeof(error_buf));

    env->ReleaseByteArrayElements(data, dataPtr, JNI_ABORT);
    env->ReleaseStringUTFChars(vendor, vendorStr);
    env->ReleaseStringUTFChars(product, productStr);

    if (rc != 0) {
        if (errorBuf != nullptr && error_buf[0]) {
            jsize len = env->GetArrayLength(errorBuf);
            jsize msgLen = static_cast<jsize>(strlen(error_buf));
            if (msgLen > len) msgLen = len;
            env->SetByteArrayRegion(errorBuf, 0, msgLen,
                reinterpret_cast<const jbyte *>(error_buf));
        }
        free_parsed_dive(dive);
        return 0;
    }

    return reinterpret_cast<jlong>(dive);
}

extern "C" JNIEXPORT void JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeParsedDiveFree(
    JNIEnv *, jclass, jlong divePtr) {
    free_parsed_dive(reinterpret_cast<libdc_parsed_dive_t *>(divePtr));
}
```

`libdc_parse_raw_dive` already fails cleanly on a partly-filled struct, so `free_parsed_dive` is correct on the error path too.

If the build reports `strlen` or `free` as undeclared, add `#include <cstring>` and `#include <cstdlib>` to the file's existing include block. Do not add anything else.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/android
./gradlew :libdivecomputer_plugin:connectedAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.submersion.libdivecomputer.RawDiveParseTest
```

Expected: 4 tests, 0 failures.

If `parsesFixtureIntoExpectedFields` fails on a date field, do **not** loosen the assertion — a mismatch means the timezone handling differs from macOS and is a real bug. Stop and report.

- [ ] **Step 7: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git add packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt \
        packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/RawDiveParseTest.kt \
        packages/libdivecomputer_plugin/android/src/androidTest/assets/shearwater_teric_dive.bin
git commit -m "feat(android): add nativeParseRawDive JNI binding

Exposes libdc_parse_raw_dive to Kotlin as an opaque handle plus an
explicit free, mirroring the nativeDownloadSessionNew/Free pairing.
Covered by an instrumented test against a real Shearwater Teric blob."
```

---

### Task 2: Android `parseRawDiveData` host-API method

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt:38` (add `parseExecutor`)
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt:672-684` (replace the `UNSUPPORTED` stub)

**Interfaces:**
- Consumes: `LibdcWrapper.nativeParseRawDive` and `LibdcWrapper.nativeParsedDiveFree` from Task 1; the existing private `convertParsedDive(divePtr: Long): ParsedDive` at line 526.
- Produces: a working `parseRawDiveData` override. Nothing downstream depends on new symbols.

**Context an implementer needs:**

Three non-obvious requirements, all of which the naive implementation gets wrong:

1. **`LibdcWrapper.loadError` must be checked first.** On a 16 KB-page Android 15+ device the native library fails to load (issue #318) and calling any `external fun` throws `UnsatisfiedLinkError` on a background thread, killing the process. The download path guards this via `nativeLibraryReady()`; that helper reports through `flutterApi.onError` and returns `Boolean`, which is the wrong shape here — a re-parse must fail *its own* Pigeon callback. So check `LibdcWrapper.loadError` directly.

2. **Do not reuse `executor` (line 38).** It is a single-thread executor dedicated to downloads. A re-parse submitted to it would sit behind an in-flight BLE download. Add a separate `parseExecutor`. Like `executor`, it is never shut down: this class lives for the process lifetime.

3. **`convertParsedDive` must be wrapped in `try/finally`.** If it throws, the native struct leaks.

- [ ] **Step 1: Add the parse executor**

In `DiveComputerHostApiImpl.kt`, immediately after line 38 (`private val executor = Executors.newSingleThreadExecutor()`):

```kotlin
    // Re-parsing archived raw bytes runs here rather than on [executor], which
    // is the download worker: a re-parse must not queue behind an in-flight
    // BLE download. Never shut down, matching [executor] -- this instance lives
    // for the process lifetime.
    private val parseExecutor = Executors.newSingleThreadExecutor()
```

- [ ] **Step 2: Replace the `UNSUPPORTED` stub**

Replace the body of `parseRawDiveData` (lines 672-684) with:

```kotlin
    override fun parseRawDiveData(
        vendor: String,
        product: String,
        model: Long,
        data: ByteArray,
        callback: (Result<ParsedDive>) -> Unit
    ) {
        // Guard before touching any external fun: on a 16 KB-page device the
        // native library never loaded (issue #318) and the JNI call would throw
        // UnsatisfiedLinkError on the executor thread, killing the process.
        val loadError = LibdcWrapper.loadError
        if (loadError != null) {
            callback(Result.failure(FlutterError(
                "native_library_unavailable",
                "Dive computer support could not be loaded on this device " +
                    "(${loadError.javaClass.simpleName}). Please update Submersion " +
                    "to the latest version.",
                null)))
            return
        }

        // model crosses Pigeon as an int64 but libdivecomputer expects an
        // unsigned int descriptor id. Reject out-of-range values up front so a
        // corrupt model yields a clear error instead of a silently wrapped cast
        // and a misleading "no descriptor" failure downstream.
        if (model < 0 || model > 0xFFFFFFFFL) {
            callback(Result.failure(FlutterError(
                "PARSE_ERROR",
                "Invalid dive computer model number: $model",
                null)))
            return
        }

        parseExecutor.execute {
            val errorBuf = ByteArray(256)
            val divePtr = LibdcWrapper.nativeParseRawDive(
                vendor, product, model.toInt(), data, errorBuf
            )

            if (divePtr == 0L) {
                val errorMsg = String(errorBuf).trim('\u0000')
                mainHandler.post {
                    callback(Result.failure(FlutterError(
                        "PARSE_ERROR",
                        "Failed to parse raw dive data: $errorMsg",
                        null)))
                }
                return@execute
            }

            val parsedDive = try {
                convertParsedDive(divePtr)
            } finally {
                LibdcWrapper.nativeParsedDiveFree(divePtr)
            }

            mainHandler.post { callback(Result.success(parsedDive)) }
        }
    }
```

- [ ] **Step 3: Verify it compiles and the Task 1 tests still pass**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/android
./gradlew :libdivecomputer_plugin:assembleDebug
./gradlew :libdivecomputer_plugin:connectedAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.submersion.libdivecomputer.RawDiveParseTest
```

Expected: `BUILD SUCCESSFUL`, 4 tests, 0 failures.

- [ ] **Step 4: Smoke-test on the emulator**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter run -d emulator-5554
```

In the app: open a dive that was downloaded from a dive computer (it must have archived raw bytes), open the overflow menu on Dive Details, and tap **Re-parse**.

Expected: no `Re-parse failed` snackbar. The dive detail page refreshes and the profile, tanks and events are unchanged.

Expected failure mode if something is wrong: a `PARSE_ERROR` snackbar naming the libdivecomputer error, rather than an `UNSUPPORTED` one.

- [ ] **Step 5: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt
git commit -m "feat(android): implement parseRawDiveData

Re-parsing an archived dive no longer fails with UNSUPPORTED. Guards the
#318 native-library load failure and out-of-range model ids, and runs the
parse on a dedicated executor so it cannot queue behind a BLE download."
```

---

### Task 3: Linux `parse_raw_dive_data` handler

**Files:**
- Modify: `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc:1-12` (add one include)
- Modify: `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc:693-703` (replace `handle_parse_raw_dive_data`)

**Interfaces:**
- Consumes: `libdc_parse_raw_dive()` from `libdc_wrapper.h` (already included at line 9); `convert_parsed_dive(const libdc_parsed_dive_t*)` from `dive_converter.h` (already included at line 8).
- Produces: a working `handle_parse_raw_dive_data`. It is already wired into the VTable at line 728; that line does not change.

**Context an implementer needs:**

`convert_parsed_dive` returns a new `LibdivecomputerPluginParsedDive*` that the caller owns. The existing `dive_callback_idle` (line 180) shows the pattern: pass it to the respond/notify function, then `g_object_unref` it. It returns `nullptr` on failure.

This handler is synchronous, matching Windows. Raw dive blobs are a few kilobytes and parse in well under a frame.

- [ ] **Step 1: Add the `limits.h` include**

`UINT_MAX` is not currently in scope. In the include block at the top of the file, change:

```cpp
#include <string.h>
```

to:

```cpp
#include <limits.h>
#include <string.h>
```

- [ ] **Step 2: Replace the stub handler**

Replace lines 693-703 (`handle_parse_raw_dive_data`) with:

```cpp
static void handle_parse_raw_dive_data(
    const gchar* vendor,
    const gchar* product,
    int64_t model,
    const uint8_t* data,
    size_t data_length,
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  // model arrives as an int64 across the Pigeon boundary but libdivecomputer
  // expects an unsigned int descriptor id. Reject out-of-range values up front
  // so a corrupt model yields a clear error instead of a silently wrapped cast
  // and a misleading "no descriptor" failure downstream.
  if (model < 0 || model > static_cast<int64_t>(UINT_MAX)) {
    g_autofree gchar* msg = g_strdup_printf(
        "Invalid dive computer model number: %" G_GINT64_FORMAT, model);
    libdivecomputer_plugin_dive_computer_host_api_respond_error_parse_raw_dive_data(
        response_handle, "PARSE_ERROR", msg, nullptr);
    return;
  }

  libdc_parsed_dive_t dive = {};
  char error_buf[256] = {};

  int rc = libdc_parse_raw_dive(
      vendor, product, static_cast<unsigned int>(model),
      data, static_cast<unsigned int>(data_length),
      &dive, error_buf, sizeof(error_buf));

  if (rc != 0) {
    // Only samples and events are heap-allocated; gasmixes, tanks and
    // fingerprint are inline arrays.
    free(dive.samples);
    free(dive.events);
    g_autofree gchar* msg =
        g_strdup_printf("Failed to parse raw dive data: %s", error_buf);
    libdivecomputer_plugin_dive_computer_host_api_respond_error_parse_raw_dive_data(
        response_handle, "PARSE_ERROR", msg, nullptr);
    return;
  }

  LibdivecomputerPluginParsedDive* parsed = convert_parsed_dive(&dive);
  free(dive.samples);
  free(dive.events);

  if (parsed == nullptr) {
    libdivecomputer_plugin_dive_computer_host_api_respond_error_parse_raw_dive_data(
        response_handle, "PARSE_ERROR",
        "Failed to convert parsed dive data", nullptr);
    return;
  }

  libdivecomputer_plugin_dive_computer_host_api_respond_parse_raw_dive_data(
      response_handle, parsed);
  g_object_unref(parsed);
}
```

- [ ] **Step 3: Verify it compiles**

There is no Linux CI runner and no Linux hardware here, so compilation plus review against `windows/dive_computer_host_api_impl.cc:158` is the verification.

If a Linux toolchain is available:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter build linux --debug
```

Expected: `Building Linux application... done`.

If no Linux toolchain is available, say so explicitly rather than claiming the build passed. Then confirm by inspection that:
- every early return responds exactly once on `response_handle`;
- `dive.samples` and `dive.events` are freed on both the error and success paths;
- `parsed` is unreffed after the success response.

- [ ] **Step 4: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git add packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc
git commit -m "feat(linux): implement parse_raw_dive_data

Ports the Windows implementation: model range guard, libdc_parse_raw_dive
into a stack struct, convert_parsed_dive, free samples/events on every
path. Re-parsing an archived dive no longer fails with UNSUPPORTED."
```

---

## Out of scope

`libdc_parse_raw_dive` `memset`s its result, so `raw_data` and `raw_fingerprint` come back null and a re-parsed `ParsedDive` reports no raw bytes. This is already true on macOS and Windows, and `lib/features/dive_computer/data/services/reparse_service.dart:340` preserves the stored blob by passing `const Value.absent()` when the parser supplies none. Do not "fix" this.

No changes to `CMakeLists.txt`, Pigeon definitions, or any Dart file.
