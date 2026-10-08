# BLE PIN Code Authentication

## Problem

Dive computers using the Pelagic i330R chipset (Aqualung i300R, i330R, i470TC, i770R, Apeks DSX, etc.) require a PIN code for BLE authentication. The dive computer displays a 6-digit passcode on its screen, and the app must capture this PIN and pass it to libdivecomputer via ioctl callbacks.

Currently, all four platform BLE I/O stream implementations only handle `DC_IOCTL_BLE_GET_NAME` and return `UNSUPPORTED` for all other ioctls. When libdivecomputer calls `DC_IOCTL_BLE_GET_PINCODE`, it gets an unsupported status, causing the download to fail with "Access denied, no access code."

This is a generic problem -- any BLE dive computer backend in libdivecomputer can use the PIN/access code ioctl mechanism, not just Pelagic.

## Solution

Implement three new ioctl handlers across all four platforms:

- `DC_IOCTL_BLE_GET_PINCODE` (ioctl 'b', 1) -- request PIN from user
- `DC_IOCTL_BLE_GET_ACCESSCODE` (ioctl 'b', 2, read) -- retrieve cached access code
- `DC_IOCTL_BLE_SET_ACCESSCODE` (ioctl 'b', 2, write) -- store access code for reuse

Use a semaphore-based bridge to connect libdivecomputer's synchronous ioctl call to Flutter's async PIN entry dialog. Persist access codes per device address using platform-native key-value stores so users only enter the PIN once per device.

## Data Flow

```
1. User taps "Download" -> Flutter calls startDownload()
2. Native connects BLE, libdc opens device
3. libdc calls DC_IOCTL_BLE_GET_ACCESSCODE
   -> Native checks stored access code for this device address
   -> If found and valid: auth succeeds, skip to step 8
   -> If not found or invalid: falls through to PIN request
4. libdc calls DC_IOCTL_BLE_GET_PINCODE
   -> Native sends onPinCodeRequired(deviceAddress) to Dart via Pigeon
   -> Native blocks on semaphore (60s timeout)
5. Dart receives callback -> emits PinCodeRequestEvent on download stream
6. Flutter UI shows modal AlertDialog for PIN entry
7. User enters PIN -> Flutter calls submitPinCode(pin) on HostApi
   -> Native stores PIN, signals semaphore
   -> ioctl handler copies PIN to libdc buffer, returns SUCCESS
8. libdc derives access code from PIN, calls DC_IOCTL_BLE_SET_ACCESSCODE
   -> Native stores access code persistently (keyed by device address)
9. Download proceeds normally (progress, dives, complete)
```

Cancellation: dismissing the dialog submits an empty string, ioctl returns `LIBDC_STATUS_CANCELLED`, download aborts gracefully.

Timeout: if the semaphore times out (60s), ioctl returns `LIBDC_STATUS_TIMEOUT`. libdivecomputer may retry internally. 60 seconds gives users enough time to locate the PIN on the dive computer screen and enter it.

## Pigeon API Changes

### New FlutterApi callback (native -> Dart)

```dart
@FlutterApi()
abstract class DiveComputerFlutterApi {
  // ... existing callbacks ...
  void onPinCodeRequired(String deviceAddress);
}
```

### New HostApi method (Dart -> native)

```dart
@HostApi()
abstract class DiveComputerHostApi {
  // ... existing methods ...
  void submitPinCode(String pinCode);
}
```

## Native Layer Changes

All four platforms follow the same pattern. Each platform's BLE I/O stream gets:

1. A PIN semaphore (using platform-native synchronization primitive)
2. A pending PIN string variable
3. A callback/reference to notify Dart when PIN is needed
4. Access code storage using platform key-value store

### Platform Matrix

| Platform | BLE I/O File | Sync Primitive | Access Code Storage |
|----------|-------------|----------------|-------------------|
| iOS/macOS | `BleIoStream.swift` | `DispatchSemaphore` | `UserDefaults` |
| Android | `BleIoStream.kt` + `libdc_jni.cpp` | `java.util.concurrent.Semaphore` | `SharedPreferences` |
| Windows | `ble_io_stream.cc` | `std::condition_variable` | WinRT `ApplicationData` |
| Linux | `ble_io_stream.c` | `GMutex` / `GCond` | `GKeyFile` (XDG config) |

Access code storage key format: `ble_access_code_<deviceAddress>` where deviceAddress is the platform-native address string (UUID on Darwin, MAC on Android/Linux, hex uint64 on Windows).

### Ioctl Handler Logic (pseudocode, same across all platforms)

```
performIoctl(request, data, size):
  type = (request >> 8) & 0xFF
  number = request & 0xFF
  direction = (request >> 30) & 0x3  // 1=read(IOR), 2=write(IOW)

  if type != 'b': return UNSUPPORTED

  switch number:
    case 0:  // BLE_GET_NAME (existing)
      copy device name to buffer
      return SUCCESS

    case 1:  // BLE_GET_PINCODE
      dispatch onPinCodeRequired(deviceAddress) to main/UI thread asynchronously
      wait on PIN semaphore (60s timeout) on background/download thread
      if timed out: return TIMEOUT
      if PIN is empty: return CANCELLED
      copy PIN string to buffer (null-terminated)
      return SUCCESS

    case 2:  // BLE_GET_ACCESSCODE or BLE_SET_ACCESSCODE
      if direction == read (GET):
        load access code from persistent storage keyed by deviceAddress
        if not found: return UNSUPPORTED
        copy access code bytes to buffer
        return SUCCESS
      if direction == write (SET):
        read access code bytes from buffer
        save to persistent storage keyed by deviceAddress
        return SUCCESS

    default: return UNSUPPORTED
```

### Android-Specific Architecture

Android's ioctl handler lives in C++ (`jni_io_ioctl` in `libdc_jni.cpp`), but the Pigeon FlutterApi is in Kotlin. The PIN bridge crosses the JNI boundary:

1. Add `onPinCodeRequired(address: String): String` to the `BleIoHandler` interface (blocking call that returns PIN)
2. `BleIoStream.kt` implements it: dispatches `onPinRequired` callback to trigger FlutterApi, then blocks on a `java.util.concurrent.Semaphore` waiting for the PIN
3. `BleIoStream.kt` gets a `submitPinCode(pin: String)` method that stores the PIN and releases the semaphore
4. C++ `jni_io_ioctl` calls `ioHandler.onPinCodeRequired(address)` via JNI for ioctl 1 -- this blocks until the Kotlin side returns the PIN string
5. C++ copies the returned PIN into libdivecomputer's buffer

This keeps all semaphore logic in Kotlin (matching the existing `read()` pattern in `BleIoStream.kt` which also blocks on a queue) and avoids splitting synchronization between C++ and Kotlin.

For access codes on Android, `BleIoStream.kt` also gets `getAccessCode(address: String): ByteArray?` and `setAccessCode(address: String, code: ByteArray)` methods (or these can be added to `BleIoHandler`). The C++ ioctl handler calls these via JNI for ioctl 2.

### DiveComputerHostApiImpl Changes (all platforms)

- Store reference to active BLE I/O stream
- Wire `onPinCodeRequired` from BLE stream to Pigeon `flutterApi.onPinCodeRequired()` (dispatched asynchronously to main/UI thread)
- Implement `submitPinCode()` HostApi method: forward PIN to active BLE stream's `submitPinCode()`, which stores the PIN and signals the semaphore
- Set `deviceAddress` on the BLE stream before connecting
- Remove the existing no-op `setDialogContext()` method and its call sites

### Threading Invariant

On all platforms, the FlutterApi callback (`onPinCodeRequired`) MUST be dispatched asynchronously to the main/UI thread BEFORE the semaphore wait begins on the download thread. The order is:

1. Dispatch `onPinCodeRequired` to main thread (non-blocking)
2. Block on semaphore (on download thread)

This matches the existing pattern used for `onDownloadProgress` and `onDiveDownloaded` throughout the codebase (e.g., `DispatchQueue.main.async` on Darwin, `mainHandler.post` on Android).

## Dart Service Layer Changes

### New event type

```dart
class PinCodeRequestEvent extends DownloadEvent {
  final String deviceAddress;
  PinCodeRequestEvent(this.deviceAddress);
}
```

### DiveComputerService additions

```dart
@override
void onPinCodeRequired(String deviceAddress) {
  _downloadEventsController.add(PinCodeRequestEvent(deviceAddress));
}

Future<void> submitPinCode(String pinCode) {
  return _hostApi.submitPinCode(pinCode);
}
```

## DownloadNotifier Changes

### New phase

Add `DownloadPhase.pinRequired` to the enum (in `downloaded_dive.dart`).

Update `isDownloading` getter to include `pinRequired` (the download IS still in progress, just paused for user input):

```dart
bool get isDownloading =>
    phase == DownloadPhase.connecting ||
    phase == DownloadPhase.downloading ||
    phase == DownloadPhase.enumerating ||
    phase == DownloadPhase.pinRequired;
```

### Event handling

```dart
case pigeon.PinCodeRequestEvent(:final deviceAddress):
  state = state.copyWith(phase: DownloadPhase.pinRequired);
```

### PIN submission

```dart
Future<void> submitPinCode(String pin) async {
  state = state.copyWith(phase: DownloadPhase.connecting);
  await _service.submitPinCode(pin);
}
```

## Flutter UI

### PIN Code Dialog

A modal `AlertDialog` in a new file `lib/features/dive_computer/presentation/widgets/pin_code_dialog.dart`:

- Title: "PIN Code Required"
- Body: "Enter the code displayed on your dive computer"
- 6-character text field with numeric keyboard on mobile, autofocus
- Submit button (enabled when field is non-empty)
- Cancel button (dismisses dialog, submits empty string to abort download)

### Trigger

Both `DeviceDownloadPage` and `DeviceDiscoveryPage` use `ref.listen` on the download notifier to detect `DownloadPhase.pinRequired` and show the dialog. The listener logic can be extracted into a shared helper.

## Error Handling

### Wrong PIN

libdivecomputer handles retries internally (up to 3 attempts). Each retry calls `BLE_GET_PINCODE` again, triggering a new dialog.

### Stale access code

If a stored access code no longer works (e.g., device factory reset), libdivecomputer falls through from `BLE_GET_ACCESSCODE` to `BLE_GET_PINCODE`. The new PIN generates a new access code that overwrites the stale one.

### Thread safety

- PIN semaphore is per-BLE stream instance; only one download at a time
- `submitPinCode()` called from main thread, semaphore waited on background thread -- no deadlock
- Access code persistence uses thread-safe platform APIs

## What Does Not Change

- Database schema (access codes use platform key-value stores)
- libdivecomputer source code (we implement ioctls it already expects)
- Existing download flow for non-PIN devices (GET_ACCESSCODE returns UNSUPPORTED, GET_PINCODE is never called)

## Files to Modify

### Pigeon definition + codegen
- `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`
- `packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart` (regenerated)
- Platform-specific generated files (regenerated by `dart run pigeon`)

### Native -- Darwin (iOS/macOS)
- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift`
- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`

### Native -- Android
- `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` (BleIoHandler interface)

### Native -- Windows
- `packages/libdivecomputer_plugin/windows/ble_io_stream.cc`
- `packages/libdivecomputer_plugin/windows/ble_io_stream.h`
- `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc`

### Native -- Linux
- `packages/libdivecomputer_plugin/linux/ble_io_stream.c`
- `packages/libdivecomputer_plugin/linux/ble_io_stream.h`
- `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc`

### Dart service

- `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart`

### Flutter app

- `lib/features/dive_computer/domain/entities/downloaded_dive.dart` (DownloadPhase enum)
- `lib/features/dive_computer/presentation/providers/download_providers.dart`
- `lib/features/dive_computer/presentation/widgets/pin_code_dialog.dart` (new)
- `lib/features/dive_computer/presentation/widgets/download_step_widget.dart` (remove setDialogContext call)
- `lib/features/dive_computer/presentation/pages/device_download_page.dart`
- `lib/features/dive_computer/presentation/pages/device_discovery_page.dart`
