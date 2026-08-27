# Raw dive parsing (re-parse) on Android and Linux

Date: 2026-07-08

## Problem

Re-parsing a downloaded dive from its archived raw bytes fails on Android with:

```
Re-parse failed: PlatformException(UNSUPPORTED, Raw dive parsing not yet
implemented on Android, null, null)
```

`DiveComputerHostApi.parseRawDiveData` is implemented on macOS/iOS (Swift) and
Windows (C++), but is a stub that returns `UNSUPPORTED` on Android (Kotlin) and
Linux (C/GObject).

## Background

The C function that does the work, `libdc_parse_raw_dive()`, lives in
`packages/libdivecomputer_plugin/macos/Classes/libdc_download.c:703`. All four
platform builds already compile that translation unit:

| Platform | Build file | Compiles `libdc_download.c` |
| --- | --- | --- |
| macOS/iOS | `darwin/Package.swift` | yes |
| Windows | `windows/CMakeLists.txt:156` | yes |
| Linux | `linux/CMakeLists.txt:158` | yes |
| Android | `android/src/main/cpp/CMakeLists.txt:135` | yes |

No build-system changes are required. Only the platform-channel plumbing is
missing.

The Dart layer (`lib/features/dive_computer/data/services/reparse_service.dart`)
is platform-agnostic and needs no changes.

## Reference implementation

`windows/dive_computer_host_api_impl.cc:158` (`ParseRawDiveData`) is the
canonical shape and both new implementations follow it:

1. Reject `model` values outside `unsigned int` range with `PARSE_ERROR`.
2. Zero-initialise a `libdc_parsed_dive_t` and a 256-byte `error_buf`.
3. Call `libdc_parse_raw_dive(vendor, product, model, data, size, &dive, ...)`.
4. On non-zero return: free `dive.samples` and `dive.events`, respond
   `PARSE_ERROR` with `"Failed to parse raw dive data: <error_buf>"`.
5. On success: convert to the Pigeon `ParsedDive`, free `dive.samples` and
   `dive.events`, respond with the value.

Only `samples` and `events` are heap-allocated. `gasmixes` and `tanks` are
fixed-size inline arrays; `fingerprint` is an inline buffer.

## Android

### Memory ownership

Kotlin cannot see the C struct layout, so unlike Swift it cannot hold
`libdc_parsed_dive_t` as a local. Android instead reads fields through ~25
`nativeGetDiveXxx(divePtr: Long)` accessors that `reinterpret_cast` the
pointer. The struct must therefore outlive the parse call.

Chosen approach: **opaque handle plus explicit free**, mirroring the existing
`nativeDownloadSessionNew` / `nativeDownloadSessionFree` pair in
`LibdcWrapper.kt:33-35`.

Rejected alternatives:

- *Callback-scoped pointer* (parse onto a C stack local, invoke a Kotlin
  callback, free before returning). Leak-proof by construction, but drags
  Kotlin exception state across a JNI frame and makes the native code harder to
  test in isolation. The leak it prevents is already prevented by `try/finally`.
- *Marshal entirely in JNI* (construct the Kotlin `ParsedDive` from C++).
  Duplicates all of `convertParsedDive` in fragile `FindClass`/`GetMethodID`
  code.

### JNI (`android/src/main/cpp/libdc_jni.cpp`)

Two exports, appended to the existing "Dive Data Access" section:

```cpp
extern "C" JNIEXPORT jlong JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeParseRawDive(
    JNIEnv *env, jclass, jstring vendor, jstring product,
    jint model, jbyteArray data, jbyteArray errorBuf);

extern "C" JNIEXPORT void JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeParsedDiveFree(
    JNIEnv *, jclass, jlong divePtr);
```

`nativeParseRawDive` allocates one zeroed `libdc_parsed_dive_t`, calls
`libdc_parse_raw_dive`, and:

- on success returns the struct pointer as a `jlong`;
- on failure copies `error_buf` into the caller's `errorBuf`, releases the
  struct (via the same free path), and returns `0`.

`nativeParsedDiveFree` frees `samples`, then `events`, then the struct. This is
the single place the ownership rule is expressed.

The `errorBuf: ByteArray` out-parameter follows the convention already used by
`nativeDownloadRun` (`LibdcWrapper.kt:44`).

### Kotlin (`DiveComputerHostApiImpl.kt:672`)

`parseRawDiveData` replaces its `FlutterError("UNSUPPORTED", ...)` body with:

1. **Native-library guard.** If `LibdcWrapper.loadError != null`, fail the
   callback with `native_library_unavailable`. Without this, calling an
   `external fun` on a 16 KB-page device (issue #318) throws
   `UnsatisfiedLinkError` and kills the process instead of surfacing an error.
2. **Model range guard.** `model < 0 || model > 0xFFFFFFFF` yields
   `PARSE_ERROR` with `"Invalid dive computer model number: <model>"`, matching
   Windows.
3. **Dispatch to a dedicated `parseExecutor`**, a new
   `Executors.newSingleThreadExecutor()`. The existing `executor` (line 38) is
   the download worker; reusing it would queue a re-parse behind an in-flight
   BLE download. Like `executor`, `parseExecutor` is never shut down: the
   `HostApi` impl lives for the process lifetime.
4. Call `nativeParseRawDive`. If it returns `0`, fail with `PARSE_ERROR` and
   the message from `errorBuf`.
5. Otherwise `try { convertParsedDive(ptr) } finally {
   LibdcWrapper.nativeParsedDiveFree(ptr) }`.
6. Deliver the result via `mainHandler.post { callback(...) }`.

`convertParsedDive` (line 526) is reused unchanged; it already converts a
native dive pointer produced by the download path.

## Linux (`linux/dive_computer_host_api_impl.cc:693`)

`handle_parse_raw_dive_data` is rewritten as a direct port of the Windows
implementation. `convert_parsed_dive()` already exists (used by
`on_dive_downloaded`, line 192) and is reused. The handler responds via
`libdivecomputer_plugin_dive_computer_host_api_respond_parse_raw_dive_data` on
success and `..._respond_error_parse_raw_dive_data` on failure.

Execution is synchronous on the calling thread, matching Windows. Raw dive
blobs are a few kilobytes and parse in well under a frame.

## Error contract

All platforms converge on the same two codes:

| Condition | Code | Message |
| --- | --- | --- |
| Native library unavailable (Android only) | `native_library_unavailable` | existing #318 text |
| `model` outside `unsigned int` | `PARSE_ERROR` | `Invalid dive computer model number: <model>` |
| Parse failure | `PARSE_ERROR` | `Failed to parse raw dive data: <error_buf>` |

## Non-goals

`libdc_parse_raw_dive` `memset`s its result, so `raw_data` and
`raw_fingerprint` come back null and a re-parsed `ParsedDive` reports no raw
bytes. This is already the behaviour on macOS and Windows, and
`reparse_service.dart:340` preserves the stored blob by passing
`const Value.absent()` when the parser supplies none. No change.

Restoring `raw_data` round-tripping, and any change to the Dart re-parse
service, are out of scope.

## Testing

### Instrumented (`android/src/androidTest/.../RawDiveParseTest.kt`, new)

Sits alongside `DiveMarshalingTest.kt`. Runs on an emulator because it needs
the ART runtime and `liblibdc_jni.so`.

1. **Round trip.** Parse the fixture and assert max depth `28.56 m` and
   duration `1256 s`, plus a non-zero sample count and a well-formed
   date/time. These are the values the same blob already yields on macOS.
2. **Parse failure.** A garbage blob returns `0` and writes a non-empty
   NUL-terminated message into `errorBuf`.
3. **Free.** `nativeParsedDiveFree` on a successful result completes without
   crashing, and parsing in a loop does not leak.

The fixture is `android/src/androidTest/assets/shearwater_teric_dive.bin`: a
22,144-byte raw blob taken from the `dive_data_sources.raw_data` column of the
development database, whose descriptor triple is
`vendor="Shearwater", product="Teric", model=8`. It is loaded through
`InstrumentationRegistry.getInstrumentation().context.assets`. A real vendor
blob is used because a synthetic one would not exercise a genuine backend
parser.

### Manual

Re-parse a dive on an Android emulator and confirm the dive detail page updates
without a `Re-parse failed` snackbar.

Linux has no CI device; it is verified by compilation and by code review against
the Windows implementation.

## Files touched

| File | Change |
| --- | --- |
| `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` | add two JNI exports |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` | declare two `external fun`s |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` | implement `parseRawDiveData`, add `parseExecutor` |
| `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/RawDiveParseTest.kt` | new test |
| `packages/libdivecomputer_plugin/android/src/androidTest/assets/shearwater_teric_dive.bin` | new fixture (22,144 bytes) |
| `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc` | implement `handle_parse_raw_dive_data` |

No `CMakeLists.txt`, Pigeon, or Dart changes.
