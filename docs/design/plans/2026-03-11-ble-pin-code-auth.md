# BLE PIN Code Authentication Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable BLE PIN code authentication for dive computers that require it (Pelagic i330R chipset and others), with persistent access code storage so PINs are only entered once per device.

**Architecture:** Semaphore-based bridge connecting libdivecomputer's synchronous ioctl calls to Flutter's async PIN entry dialog. Each platform's BLE I/O stream handles three new ioctls (GET_PINCODE, GET_ACCESSCODE, SET_ACCESSCODE). Access codes are persisted per-device using platform-native key-value stores.

**Tech Stack:** Pigeon codegen (Dart/Swift/Kotlin/C++/GObject), CoreBluetooth (Darwin), Android BLE + JNI, WinRT BLE (Windows), BlueZ D-Bus (Linux), Flutter AlertDialog

**Spec:** `docs/superpowers/specs/2026-03-11-ble-pin-code-auth-design.md`

---

## File Structure

### Pigeon definition + codegen
- **Modify:** `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` -- add `onPinCodeRequired` callback and `submitPinCode` method
- **Regenerated:** `packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart` and all platform-generated files

### Dart service layer
- **Modify:** `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart` -- add `PinCodeRequestEvent`, implement `onPinCodeRequired`, add `submitPinCode`

### Flutter app -- domain
- **Modify:** `lib/features/dive_computer/domain/entities/downloaded_dive.dart` -- add `pinRequired` to `DownloadPhase` enum

### Flutter app -- state management
- **Modify:** `lib/features/dive_computer/presentation/providers/download_providers.dart` -- handle PIN events, add `submitPinCode`, update `isDownloading`, remove `setDialogContext`

### Flutter app -- UI
- **Create:** `lib/features/dive_computer/presentation/widgets/pin_code_dialog.dart` -- modal PIN entry dialog
- **Modify:** `lib/features/dive_computer/presentation/widgets/download_step_widget.dart` -- remove `setDialogContext`, add PIN phase listener
- **Modify:** `lib/features/dive_computer/presentation/pages/device_download_page.dart` -- remove `setDialogContext`, add PIN phase listener

### Native -- Darwin (iOS/macOS)
- **Modify:** `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift` -- add PIN semaphore, ioctl handlers for cases 1 and 2
- **Modify:** `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` -- wire PIN callback, implement `submitPinCode`

### Native -- Android
- **Modify:** `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` -- add `onPinCodeRequired`, `getAccessCode`, `setAccessCode` to `BleIoHandler`
- **Modify:** `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt` -- implement PIN semaphore, access code storage
- **Modify:** `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` -- handle ioctls 1 and 2 via JNI calls to BleIoHandler
- **Modify:** `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` -- wire PIN callback, implement `submitPinCode`

### Native -- Windows
- **Modify:** `packages/libdivecomputer_plugin/windows/ble_io_stream.h` -- add PIN members
- **Modify:** `packages/libdivecomputer_plugin/windows/ble_io_stream.cc` -- ioctl handlers for cases 1 and 2
- **Modify:** `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.h` -- add `SubmitPinCode` declaration
- **Modify:** `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc` -- wire PIN callback, implement `SubmitPinCode`

### Native -- Linux
- **Modify:** `packages/libdivecomputer_plugin/linux/ble_io_stream.h` -- add PIN members
- **Modify:** `packages/libdivecomputer_plugin/linux/ble_io_stream.c` -- ioctl handlers for cases 1 and 2
- **Modify:** `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc` -- wire PIN callback, implement `submit_pin_code`

---

## Chunk 1: Pigeon API + Dart Layer

### Task 1: Add PIN methods to Pigeon API definition

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart:176-207`

- [ ] **Step 1: Add `submitPinCode` to HostApi**

In `dive_computer_api.dart`, add `submitPinCode` to the `DiveComputerHostApi` class after `cancelDownload()` (line 188):

```dart
void submitPinCode(String pinCode);
```

- [ ] **Step 2: Add `onPinCodeRequired` to FlutterApi**

In `dive_computer_api.dart`, add `onPinCodeRequired` to the `DiveComputerFlutterApi` class after `onError` (line 206):

```dart
void onPinCodeRequired(String deviceAddress);
```

- [ ] **Step 3: Run Pigeon codegen**

Run:
```bash
cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart
```

Expected: Generates updated `.g.dart`, `.g.swift`, `.g.kt`, `.g.h`, `.g.cc` files for all platforms.

- [ ] **Step 4: Verify generated files compile**

Run:
```bash
cd packages/libdivecomputer_plugin && flutter pub get
```

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart packages/libdivecomputer_plugin/lib/src/generated/
git commit -m "feat: add PIN code Pigeon API (submitPinCode + onPinCodeRequired)"
```

---

### Task 2: Add PinCodeRequestEvent and service methods

**Files:**
- Modify: `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart:1-138`

- [ ] **Step 1: Add PinCodeRequestEvent class**

After `DownloadErrorEvent` (line 32), add:

```dart
class PinCodeRequestEvent extends DownloadEvent {
  final String deviceAddress;
  PinCodeRequestEvent(this.deviceAddress);
}
```

- [ ] **Step 2: Implement onPinCodeRequired callback**

After the `onError` override (line 128-130), add:

```dart
@override
void onPinCodeRequired(String deviceAddress) {
  _downloadEventsController.add(PinCodeRequestEvent(deviceAddress));
}
```

- [ ] **Step 3: Add submitPinCode method**

After the `cancelDownload` method (line 86-88), add:

```dart
/// Submit a PIN code entered by the user for BLE authentication.
Future<void> submitPinCode(String pinCode) {
  return _hostApi.submitPinCode(pinCode);
}
```

- [ ] **Step 4: Verify plugin compiles**

Run:
```bash
cd packages/libdivecomputer_plugin && flutter pub get
```

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart
git commit -m "feat: add PinCodeRequestEvent and submitPinCode to DiveComputerService"
```

---

### Task 3: Add pinRequired phase and update DownloadNotifier

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart:1-11`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart:81-84,105-306`

- [ ] **Step 1: Add pinRequired to DownloadPhase enum**

In `downloaded_dive.dart`, add `pinRequired` after `connecting` (line 4):

```dart
enum DownloadPhase {
  initializing,
  connecting,
  pinRequired,
  enumerating,
  downloading,
  processing,
  complete,
  error,
  cancelled,
}
```

- [ ] **Step 2: Update isDownloading getter**

In `download_providers.dart`, update `isDownloading` (line 81-84) to include `pinRequired`:

```dart
bool get isDownloading =>
    phase == DownloadPhase.connecting ||
    phase == DownloadPhase.downloading ||
    phase == DownloadPhase.enumerating ||
    phase == DownloadPhase.pinRequired;
```

- [ ] **Step 3: Handle PinCodeRequestEvent in _onDownloadEvent**

In `download_providers.dart`, add a case to `_onDownloadEvent` (after the `DownloadProgressEvent` case at line 173):

```dart
case pigeon.PinCodeRequestEvent():
  state = state.copyWith(phase: DownloadPhase.pinRequired);
```

- [ ] **Step 4: Add submitPinCode method to DownloadNotifier**

After `cancelDownload()` (line 253), add:

```dart
/// Submit a PIN code for BLE authentication.
///
/// Transitions back to connecting phase while the PIN is verified.
Future<void> submitPinCode(String pin) async {
  state = state.copyWith(phase: DownloadPhase.connecting);
  await _service.submitPinCode(pin);
}
```

- [ ] **Step 5: Remove setDialogContext method**

Delete the `setDialogContext` method (lines 128-130) from `DownloadNotifier`.

- [ ] **Step 6: Verify app compiles**

Run:
```bash
flutter analyze
```

Expected: No errors (may show warnings about unused imports from the removed method, which we'll fix in the UI tasks).

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_computer/domain/entities/downloaded_dive.dart lib/features/dive_computer/presentation/providers/download_providers.dart
git commit -m "feat: add pinRequired phase, submitPinCode, remove setDialogContext"
```

---

### Task 4: Create PIN code dialog widget

**Files:**
- Create: `lib/features/dive_computer/presentation/widgets/pin_code_dialog.dart`

- [ ] **Step 1: Create the PIN code dialog**

Create `lib/features/dive_computer/presentation/widgets/pin_code_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a modal dialog for entering a BLE PIN code.
///
/// Returns the entered PIN string, or null if cancelled.
Future<String?> showPinCodeDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _PinCodeDialog(),
  );
}

class _PinCodeDialog extends StatefulWidget {
  const _PinCodeDialog();

  @override
  State<_PinCodeDialog> createState() => _PinCodeDialogState();
}

class _PinCodeDialogState extends State<_PinCodeDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Autofocus the text field after the dialog animates in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN Code Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter the code displayed on your dive computer.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'PIN Code',
              hintText: '000000',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _controller.text.isNotEmpty ? _submit : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  void _submit() {
    if (_controller.text.isNotEmpty) {
      Navigator.of(context).pop(_controller.text);
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
flutter analyze lib/features/dive_computer/presentation/widgets/pin_code_dialog.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_computer/presentation/widgets/pin_code_dialog.dart
git commit -m "feat: create PIN code dialog widget for BLE authentication"
```

---

### Task 5: Wire PIN dialog into download UI pages

**Files:**
- Modify: `lib/features/dive_computer/presentation/widgets/download_step_widget.dart:57,315-333`
- Modify: `lib/features/dive_computer/presentation/pages/device_download_page.dart:176,576-594`

- [ ] **Step 1: Add shared PIN dialog helper**

Create a helper function at the top of `download_step_widget.dart` (or in a small shared file) that can be called from both pages. Since both pages need identical logic, add it to the `pin_code_dialog.dart` file:

In `pin_code_dialog.dart`, add this function after the `showPinCodeDialog` function:

```dart
/// Handles the PIN code request flow for download pages.
///
/// Shows the PIN dialog and submits the result to the notifier.
/// If cancelled, submits an empty string to abort the download.
Future<void> handlePinCodeRequest(
  BuildContext context,
  Future<void> Function(String) submitPinCode,
) async {
  final pin = await showPinCodeDialog(context);
  if (pin != null && pin.isNotEmpty) {
    await submitPinCode(pin);
  } else {
    // User cancelled -- submit empty string to signal cancellation.
    await submitPinCode('');
  }
}
```

- [ ] **Step 2: Update download_step_widget.dart**

In `download_step_widget.dart`:

a) Remove the `setDialogContext` call at line 57.

b) Add a `ref.listen` for `pinRequired` phase. In the `initState` or a `build` method, add:

```dart
ref.listen<DownloadState>(downloadNotifierProvider, (previous, next) {
  if (next.phase == DownloadPhase.pinRequired &&
      previous?.phase != DownloadPhase.pinRequired) {
    final notifier = ref.read(downloadNotifierProvider.notifier);
    handlePinCodeRequest(context, notifier.submitPinCode);
  }
});
```

c) Add `pinRequired` case to `_getPhaseIcon` (after `connecting` case, around line 318):

```dart
case DownloadPhase.pinRequired:
  return Icons.pin;
```

d) Add the import for the PIN dialog file.

- [ ] **Step 3: Update device_download_page.dart**

In `device_download_page.dart`:

a) Remove the `setDialogContext` call at line 176.

b) Add a `ref.listen` for `pinRequired` phase (same pattern as step 2b).

c) Add `pinRequired` case to `_getPhaseIcon` (after `connecting` case, around line 579):

```dart
case DownloadPhase.pinRequired:
  return Icons.pin;
```

d) Add the import for the PIN dialog file.

- [ ] **Step 4: Downgrade material.dart import**

In `download_providers.dart`, the `BuildContext` parameter from `setDialogContext` was the only reason for `import 'package:flutter/material.dart';`. However, `debugPrint` (used at line 244) comes from `package:flutter/foundation.dart` which is re-exported by `material.dart`. Change the import to:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 5: Format and analyze**

Run:
```bash
dart format lib/features/dive_computer/ && flutter analyze
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_computer/
git commit -m "feat: wire PIN code dialog into download UI pages"
```

---

## Chunk 2: Darwin (iOS/macOS) Native Layer

### Task 6: Add PIN members and ioctl handlers to Darwin BleIoStream

**Files:**
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift:33-34,47-62,412-440`

- [ ] **Step 1: Add ioctl constants and PIN members**

In `BleIoStream.swift`, add constants after `bleIoctlGetNameNumber` (line 34):

```swift
private static let bleIoctlGetPinCodeNumber: UInt32 = 1
private static let bleIoctlAccessCodeNumber: UInt32 = 2
private static let ioctlDirRead: UInt32 = 1
private static let ioctlDirWrite: UInt32 = 2
private static let pinTimeoutSeconds: TimeInterval = 60
```

Add PIN-related members after `consecutiveReadTimeouts` (line 62):

```swift
private let pinSemaphore = DispatchSemaphore(value: 0)
private var pendingPinCode: String?
private var deviceAddress: String = ""

/// Callback invoked on the main thread when a PIN code is needed.
/// Set by DiveComputerHostApiImpl before download starts.
var onPinCodeRequired: ((String) -> Void)?
```

- [ ] **Step 2: Add submitPinCode method**

Add after `makeCallbacks()`:

```swift
/// Called from main thread to supply PIN code for BLE authentication.
func submitPinCode(_ pin: String) {
    pendingPinCode = pin
    pinSemaphore.signal()
}

/// Set the device address for access code storage.
func setDeviceAddress(_ address: String) {
    deviceAddress = address
}
```

- [ ] **Step 3: Add access code storage helpers**

Add private helpers:

```swift
private static let accessCodeKeyPrefix = "ble_access_code_"

private func loadAccessCode() -> Data? {
    let key = Self.accessCodeKeyPrefix + deviceAddress
    return UserDefaults.standard.data(forKey: key)
}

private func saveAccessCode(_ data: Data) {
    let key = Self.accessCodeKeyPrefix + deviceAddress
    UserDefaults.standard.set(data, forKey: key)
}
```

- [ ] **Step 4: Extend performIoctl for PIN and access codes**

Replace the return statement at line 439 (`return Int32(LIBDC_STATUS_UNSUPPORTED)`) with handlers for ioctls 1 and 2:

```swift
if ioctlType == Self.bleIoctlType && ioctlNumber == Self.bleIoctlGetPinCodeNumber {
    guard let data, size > 0 else {
        return Int32(LIBDC_STATUS_INVALIDARGS)
    }

    NSLog("[BleIoStream] ioctl BLE_GET_PINCODE -> requesting PIN from user")
    pendingPinCode = nil

    // Dispatch callback to main thread BEFORE blocking.
    let address = deviceAddress
    DispatchQueue.main.async { [weak self] in
        self?.onPinCodeRequired?(address)
    }

    // Block on semaphore until submitPinCode() is called.
    let result = pinSemaphore.wait(timeout: .now() + Self.pinTimeoutSeconds)
    if result == .timedOut {
        NSLog("[BleIoStream] PIN entry timed out")
        return Int32(LIBDC_STATUS_TIMEOUT)
    }

    guard let pin = pendingPinCode, !pin.isEmpty else {
        NSLog("[BleIoStream] PIN entry cancelled")
        return Int32(LIBDC_STATUS_CANCELLED)
    }

    guard let cString = pin.cString(using: .utf8), !cString.isEmpty else {
        return Int32(LIBDC_STATUS_IO)
    }

    let maxCount = Int(size)
    let copyCount = min(cString.count, maxCount)
    _ = cString.withUnsafeBytes { bytes in
        memcpy(data, bytes.baseAddress!, copyCount)
    }
    if copyCount == maxCount {
        data.assumingMemoryBound(to: CChar.self)[maxCount - 1] = 0
    }
    NSLog("[BleIoStream] ioctl BLE_GET_PINCODE -> PIN provided (%d chars)", pin.count)
    return Int32(LIBDC_STATUS_SUCCESS)
}

if ioctlType == Self.bleIoctlType && ioctlNumber == Self.bleIoctlAccessCodeNumber {
    let direction = (request >> 30) & 0x3
    guard let data, size > 0 else {
        return Int32(LIBDC_STATUS_INVALIDARGS)
    }

    if direction == Self.ioctlDirRead {
        // GET access code
        guard let stored = loadAccessCode(), !stored.isEmpty else {
            NSLog("[BleIoStream] ioctl BLE_GET_ACCESSCODE -> not found")
            return Int32(LIBDC_STATUS_UNSUPPORTED)
        }
        let copyCount = min(stored.count, Int(size))
        stored.withUnsafeBytes { bytes in
            memcpy(data, bytes.baseAddress!, copyCount)
        }
        NSLog("[BleIoStream] ioctl BLE_GET_ACCESSCODE -> found (%d bytes)", stored.count)
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    if direction == Self.ioctlDirWrite {
        // SET access code
        let accessData = Data(bytes: data, count: Int(size))
        saveAccessCode(accessData)
        NSLog("[BleIoStream] ioctl BLE_SET_ACCESSCODE -> stored (%d bytes)", size)
        return Int32(LIBDC_STATUS_SUCCESS)
    }
}

return Int32(LIBDC_STATUS_UNSUPPORTED)
```

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift
git commit -m "feat(darwin): add PIN code and access code ioctl handlers to BleIoStream"
```

---

### Task 7: Wire PIN callback and submitPinCode in Darwin HostApiImpl

**Files:**
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:8-20,151-167,270-320`

- [ ] **Step 1: Implement submitPinCode in HostApi**

Add after `cancelDownload` (line 149):

```swift
func submitPinCode(pinCode: String) throws {
    guard let stream = activeBleStream else {
        throw PigeonError(code: "no_stream", message: "No active BLE stream", details: nil)
    }
    stream.submitPinCode(pinCode)
}
```

- [ ] **Step 2: Wire onPinCodeRequired in connectBle**

In `connectBle()`, BETWEEN `let stream = BleIoStream(...)` (line 315) and `stream.connectAndDiscover()` (line 316), set the device address, callback, AND `activeBleStream`. The callback MUST be set BEFORE `connectAndDiscover()` because BLE authentication can be triggered during connection.

IMPORTANT: `self.activeBleStream = stream` must also be set here (inside the retry loop, before `connectAndDiscover`) so that `submitPinCode()` can reach the stream during connection. Without this, `activeBleStream` is `nil` until after the loop and PIN submission silently no-ops:

```swift
stream.setDeviceAddress(device.address)
stream.onPinCodeRequired = { [weak self] address in
    self?.flutterApi.onPinCodeRequired(deviceAddress: address) { _ in }
}
self.activeBleStream = stream
```

- [ ] **Step 3: Build for macOS to verify**

Run:
```bash
cd packages/libdivecomputer_plugin && flutter build macos --debug 2>&1 | tail -20
```

Expected: Build succeeds (or at least Swift compilation succeeds).

- [ ] **Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift
git commit -m "feat(darwin): wire PIN code callback and submitPinCode in HostApiImpl"
```

---

## Chunk 3: Android Native Layer

### Task 8: Extend BleIoHandler interface and BleIoStream for PIN support

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt:79-84`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt:1-60`

- [ ] **Step 1: Add PIN methods to BleIoHandler interface**

In `LibdcWrapper.kt`, add to the `BleIoHandler` interface (after `close()` at line 83):

```kotlin
fun onPinCodeRequired(address: String): String
fun getAccessCode(address: String): ByteArray?
fun setAccessCode(address: String, code: ByteArray)
```

- [ ] **Step 2: Add PIN members to BleIoStream**

In `BleIoStream.kt`, add members after `connected` (line 60):

```kotlin
private val pinSemaphore = Semaphore(0)
private var pendingPinCode: String? = null

/// Callback invoked when PIN is needed. Set by HostApiImpl.
var onPinRequired: ((String) -> Unit)? = null
```

- [ ] **Step 3: Implement onPinCodeRequired in BleIoStream**

Add the implementation. Note: the `address` parameter comes from C++ JNI (`ctx->ble_name`) which holds the device NAME, not the MAC address. We ignore it and use `device.address` (the actual Bluetooth MAC address) which `BleIoStream` already has from its constructor:

```kotlin
override fun onPinCodeRequired(address: String): String {
    val deviceAddress = device.address
    Log.d(TAG, "PIN code requested for $deviceAddress")
    pendingPinCode = null

    // Dispatch callback to main thread BEFORE blocking.
    val callback = onPinRequired
    if (callback != null) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            callback(deviceAddress)
        }
    }

    // Block until submitPinCode() is called (60s timeout).
    val acquired = pinSemaphore.tryAcquire(60, TimeUnit.SECONDS)
    if (!acquired) {
        Log.w(TAG, "PIN entry timed out")
        return ""
    }

    return pendingPinCode ?: ""
}
```

- [ ] **Step 4: Add submitPinCode method to BleIoStream**

```kotlin
fun submitPinCode(pin: String) {
    pendingPinCode = pin
    pinSemaphore.release()
}
```

- [ ] **Step 5: Implement getAccessCode and setAccessCode**

Same as `onPinCodeRequired`, the `address` parameter from JNI holds the device name, not the MAC. Use `device.address` for storage keys:

```kotlin
override fun getAccessCode(address: String): ByteArray? {
    val deviceAddress = device.address
    val prefs = context.getSharedPreferences("ble_access_codes", Context.MODE_PRIVATE)
    val key = "ble_access_code_$deviceAddress"
    val encoded = prefs.getString(key, null) ?: return null
    return android.util.Base64.decode(encoded, android.util.Base64.NO_WRAP)
}

override fun setAccessCode(address: String, code: ByteArray) {
    val deviceAddress = device.address
    val prefs = context.getSharedPreferences("ble_access_codes", Context.MODE_PRIVATE)
    val key = "ble_access_code_$deviceAddress"
    val encoded = android.util.Base64.encodeToString(code, android.util.Base64.NO_WRAP)
    prefs.edit().putString(key, encoded).apply()
}
```

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt
git commit -m "feat(android): add PIN code and access code support to BleIoHandler/BleIoStream"
```

---

### Task 9: Add ioctl handlers for PIN/access code in JNI layer

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp:251-285`

- [ ] **Step 1: Add ioctl constants**

After `#define BLE_IOCTL_GET_NAME 0x6200` (line 253), add:

```cpp
#define BLE_IOCTL_GET_PINCODE_NR 1
#define BLE_IOCTL_ACCESSCODE_NR 2
```

- [ ] **Step 2: Add PIN code ioctl handler**

In `jni_io_ioctl`, after the `BLE_GET_NAME` handler (line 282) and before the final `return LIBDC_STATUS_UNSUPPORTED` (line 284), add:

```cpp
// Handle BLE_GET_PINCODE: request PIN from user via Kotlin.
if (ioctl_type == 0x62 && ioctl_nr == BLE_IOCTL_GET_PINCODE_NR) {
    if (data == nullptr || size == 0) {
        return LIBDC_STATUS_INVALIDARGS;
    }

    JNIEnv *env;
    bool attached = false;
    if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        ctx->jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }

    // Call ioHandler.onPinCodeRequired(address) -- blocks until PIN is entered.
    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jmethodID method = env->GetMethodID(cls, "onPinCodeRequired",
        "(Ljava/lang/String;)Ljava/lang/String;");

    jstring jAddress = env->NewStringUTF(ctx->ble_name);
    jstring jPin = (jstring)env->CallObjectMethod(ctx->ioHandler, method, jAddress);
    env->DeleteLocalRef(jAddress);

    int status = LIBDC_STATUS_SUCCESS;
    if (jPin == nullptr || env->GetStringLength(jPin) == 0) {
        status = LIBDC_STATUS_CANCELLED;
    } else {
        const char *pin_chars = env->GetStringUTFChars(jPin, nullptr);
        size_t pin_len = strlen(pin_chars) + 1;
        size_t copy_len = pin_len < size ? pin_len : size;
        memcpy(data, pin_chars, copy_len);
        static_cast<char *>(data)[copy_len - 1] = '\0';
        env->ReleaseStringUTFChars(jPin, pin_chars);
        __android_log_print(ANDROID_LOG_DEBUG, TAG,
            "ioctl BLE_GET_PINCODE -> PIN provided (%zu chars)", pin_len - 1);
    }

    if (jPin != nullptr) env->DeleteLocalRef(jPin);
    if (attached) ctx->jvm->DetachCurrentThread();
    return status;
}

// Handle BLE_GET_ACCESSCODE / BLE_SET_ACCESSCODE.
if (ioctl_type == 0x62 && ioctl_nr == BLE_IOCTL_ACCESSCODE_NR) {
    if (data == nullptr || size == 0) {
        return LIBDC_STATUS_INVALIDARGS;
    }

    unsigned int direction = (request >> 30) & 0x3;

    JNIEnv *env;
    bool attached = false;
    if (ctx->jvm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        ctx->jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }

    jclass cls = env->GetObjectClass(ctx->ioHandler);
    jstring jAddress = env->NewStringUTF(ctx->ble_name);
    int status;

    if (direction == 1) {
        // GET access code
        jmethodID method = env->GetMethodID(cls, "getAccessCode",
            "(Ljava/lang/String;)[B");
        jbyteArray jCode = (jbyteArray)env->CallObjectMethod(
            ctx->ioHandler, method, jAddress);

        if (jCode == nullptr) {
            status = LIBDC_STATUS_UNSUPPORTED;
            __android_log_print(ANDROID_LOG_DEBUG, TAG,
                "ioctl BLE_GET_ACCESSCODE -> not found");
        } else {
            jsize code_len = env->GetArrayLength(jCode);
            jsize copy_len = code_len < (jsize)size ? code_len : (jsize)size;
            env->GetByteArrayRegion(jCode, 0, copy_len,
                reinterpret_cast<jbyte *>(data));
            env->DeleteLocalRef(jCode);
            status = LIBDC_STATUS_SUCCESS;
            __android_log_print(ANDROID_LOG_DEBUG, TAG,
                "ioctl BLE_GET_ACCESSCODE -> found (%d bytes)", code_len);
        }
    } else {
        // SET access code
        jbyteArray jCode = env->NewByteArray((jsize)size);
        env->SetByteArrayRegion(jCode, 0, (jsize)size,
            reinterpret_cast<const jbyte *>(data));

        jmethodID method = env->GetMethodID(cls, "setAccessCode",
            "(Ljava/lang/String;[B)V");
        env->CallVoidMethod(ctx->ioHandler, method, jAddress, jCode);
        env->DeleteLocalRef(jCode);
        status = LIBDC_STATUS_SUCCESS;
        __android_log_print(ANDROID_LOG_DEBUG, TAG,
            "ioctl BLE_SET_ACCESSCODE -> stored (%zu bytes)", size);
    }

    env->DeleteLocalRef(jAddress);
    if (attached) ctx->jvm->DetachCurrentThread();
    return status;
}
```

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp
git commit -m "feat(android): handle PIN code and access code ioctls in JNI layer"
```

---

### Task 10: Wire PIN callback and submitPinCode in Android HostApiImpl

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt:27-37,142-164`

- [ ] **Step 1: Implement submitPinCode**

Add after `cancelDownload` (around line 140):

```kotlin
override fun submitPinCode(pinCode: String) {
    activeBleStream?.submitPinCode(pinCode)
}
```

- [ ] **Step 2: Wire onPinRequired callback on BleIoStream**

In `performDownload`, BETWEEN `val bleStream = BleIoStream(context, btDevice)` / `activeBleStream = bleStream` (lines 163-164) and `bleStream.connectAndDiscover()` (line 166). The callback MUST be set BEFORE `connectAndDiscover()` because BLE authentication can be triggered during connection. Add:

```kotlin
bleStream.onPinRequired = { address ->
    flutterApi.onPinCodeRequired(address) {}
}
```

- [ ] **Step 3: Build Android to verify**

Run:
```bash
cd packages/libdivecomputer_plugin && flutter build apk --debug 2>&1 | tail -20
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt
git commit -m "feat(android): wire PIN code callback and submitPinCode in HostApiImpl"
```

---

## Chunk 4: Windows Native Layer

### Task 11: Add PIN members and ioctl handlers to Windows BleIoStream

**Files:**
- Modify: `packages/libdivecomputer_plugin/windows/ble_io_stream.h:87-93`
- Modify: `packages/libdivecomputer_plugin/windows/ble_io_stream.cc:250-267`

- [ ] **Step 1: Add PIN members to header**

In `ble_io_stream.h`, add after `device_name_` (line 92):

```cpp
// PIN code authentication support.
std::mutex pin_mutex_;
std::condition_variable pin_cv_;
std::string pending_pin_;
bool pin_ready_ = false;
std::string device_address_;

// Callback when PIN code is needed (called on download thread,
// must dispatch to main thread internally).
std::function<void(const std::string&)> on_pin_code_required_;
```

Add public methods after `Close()`:

```cpp
// Submit a PIN code entered by the user.
void SubmitPinCode(const std::string& pin);

// Set the device address for access code storage.
void SetDeviceAddress(const std::string& address);

// Set callback for PIN code requests.
void SetOnPinCodeRequired(std::function<void(const std::string&)> callback);
```

- [ ] **Step 2: Implement SubmitPinCode and helpers in .cc**

Add after `Close()` implementation:

```cpp
void BleIoStream::SubmitPinCode(const std::string& pin) {
    std::lock_guard<std::mutex> lock(pin_mutex_);
    pending_pin_ = pin;
    pin_ready_ = true;
    pin_cv_.notify_one();
}

void BleIoStream::SetDeviceAddress(const std::string& address) {
    device_address_ = address;
}

void BleIoStream::SetOnPinCodeRequired(
    std::function<void(const std::string&)> callback) {
    on_pin_code_required_ = std::move(callback);
}
```

- [ ] **Step 3: Add access code storage helpers**

Add private helpers using WinRT `ApplicationData.Current.LocalSettings`:

```cpp
#include <winrt/Windows.Storage.h>

static std::wstring AccessCodeKey(const std::string& address) {
    std::wstring key = L"ble_access_code_";
    for (char c : address) key += static_cast<wchar_t>(c);
    return key;
}

std::vector<uint8_t> BleIoStream::LoadAccessCode() {
    try {
        auto settings = winrt::Windows::Storage::ApplicationData::Current()
            .LocalSettings();
        auto key = AccessCodeKey(device_address_);
        auto value = settings.Values().TryLookup(winrt::hstring(key));
        if (!value) return {};
        auto str = winrt::unbox_value<winrt::hstring>(value);
        // Stored as hex string.
        std::vector<uint8_t> result;
        std::string hex(winrt::to_string(str));
        for (size_t i = 0; i + 1 < hex.size(); i += 2) {
            result.push_back(
                static_cast<uint8_t>(std::stoi(hex.substr(i, 2), nullptr, 16)));
        }
        return result;
    } catch (...) {
        return {};
    }
}

void BleIoStream::SaveAccessCode(const uint8_t* data, size_t size) {
    try {
        auto settings = winrt::Windows::Storage::ApplicationData::Current()
            .LocalSettings();
        auto key = AccessCodeKey(device_address_);
        // Store as hex string.
        std::string hex;
        char buf[3];
        for (size_t i = 0; i < size; i++) {
            std::snprintf(buf, sizeof(buf), "%02x", data[i]);
            hex += buf;
        }
        settings.Values().Insert(
            winrt::hstring(key), winrt::box_value(winrt::to_hstring(hex)));
    } catch (...) {
        // Best effort.
    }
}
```

Add to header private section:
```cpp
std::vector<uint8_t> LoadAccessCode();
void SaveAccessCode(const uint8_t* data, size_t size);
```

- [ ] **Step 4: Extend IoctlCallback for PIN and access codes**

In `ble_io_stream.cc`, in `IoctlCallback`, after the `BLE_GET_NAME` handler (line 264) and before `return LIBDC_STATUS_UNSUPPORTED` (line 266), add:

```cpp
constexpr uint32_t kBleIoctlGetPinCode = 1;
constexpr uint32_t kBleIoctlAccessCode = 2;

if (ioctl_type == kBleIoctlType && ioctl_number == kBleIoctlGetPinCode) {
    if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;

    // Reset state.
    {
        std::lock_guard<std::mutex> lock(stream->pin_mutex_);
        stream->pending_pin_.clear();
        stream->pin_ready_ = false;
    }

    // Dispatch callback (must reach main thread).
    if (stream->on_pin_code_required_) {
        stream->on_pin_code_required_(stream->device_address_);
    }

    // Block until SubmitPinCode is called (60s timeout).
    {
        std::unique_lock<std::mutex> lock(stream->pin_mutex_);
        if (!stream->pin_cv_.wait_for(lock, std::chrono::seconds(60),
                [stream] { return stream->pin_ready_; })) {
            return LIBDC_STATUS_TIMEOUT;
        }
    }

    if (stream->pending_pin_.empty()) {
        return LIBDC_STATUS_CANCELLED;
    }

    size_t copy_len = std::min(stream->pending_pin_.size() + 1, size);
    std::memcpy(data, stream->pending_pin_.c_str(), copy_len);
    static_cast<char*>(data)[copy_len - 1] = '\0';
    return LIBDC_STATUS_SUCCESS;
}

if (ioctl_type == kBleIoctlType && ioctl_number == kBleIoctlAccessCode) {
    if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;
    uint32_t direction = (request >> 30) & 0x3;

    if (direction == 1) {
        // GET access code.
        auto stored = stream->LoadAccessCode();
        if (stored.empty()) return LIBDC_STATUS_UNSUPPORTED;
        size_t copy_len = std::min(stored.size(), size);
        std::memcpy(data, stored.data(), copy_len);
        return LIBDC_STATUS_SUCCESS;
    }
    if (direction == 2) {
        // SET access code.
        stream->SaveAccessCode(static_cast<const uint8_t*>(data), size);
        return LIBDC_STATUS_SUCCESS;
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/windows/ble_io_stream.h packages/libdivecomputer_plugin/windows/ble_io_stream.cc
git commit -m "feat(windows): add PIN code and access code ioctl handlers to BleIoStream"
```

---

### Task 12: Wire PIN callback and SubmitPinCode in Windows HostApiImpl

**Files:**
- Modify: `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.h:22-56`
- Modify: `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc:119-200`

- [ ] **Step 1: Add SubmitPinCode declaration to header**

In `dive_computer_host_api_impl.h`, add after `CancelDownload` (line 42):

```cpp
std::optional<FlutterError> SubmitPinCode(const std::string& pin_code) override;
```

- [ ] **Step 2: Implement SubmitPinCode**

In `dive_computer_host_api_impl.cc`, add after `CancelDownload`:

```cpp
std::optional<FlutterError> DiveComputerHostApiImpl::SubmitPinCode(
    const std::string& pin_code) {
    if (ble_stream_) {
        ble_stream_->SubmitPinCode(pin_code);
    }
    return std::nullopt;
}
```

- [ ] **Step 3: Wire onPinCodeRequired in PerformDownload**

In `PerformDownload`, after `ble_stream_ = std::make_unique<BleIoStream>()` (line 183), before `ConnectAndDiscover`:

```cpp
ble_stream_->SetDeviceAddress(device.address());
ble_stream_->SetOnPinCodeRequired(
    [this](const std::string& address) {
        flutter_api_->OnPinCodeRequired(
            address, [] {}, [](const auto&) {});
    });
```

- [ ] **Step 4: Build Windows to verify** (skip if not on Windows)

Run:
```bash
flutter build windows --debug 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.h packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc
git commit -m "feat(windows): wire PIN code callback and SubmitPinCode in HostApiImpl"
```

---

## Chunk 5: Linux Native Layer

### Task 13: Add PIN members and ioctl handlers to Linux BleIoStream

**Files:**
- Modify: `packages/libdivecomputer_plugin/linux/ble_io_stream.h:13-26`
- Modify: `packages/libdivecomputer_plugin/linux/ble_io_stream.c:371-392`

- [ ] **Step 1: Add PIN members to struct**

In `ble_io_stream.h`, add after `device_name` (line 25):

```c
GMutex pin_mutex;
GCond pin_cond;
gchar* pending_pin;
gboolean pin_ready;
gchar* device_address;

// Callback when PIN code is needed.
void (*on_pin_code_required)(const gchar* address, gpointer user_data);
gpointer pin_callback_data;
```

Add function declarations after `ble_io_stream_free`:

```c
// Submit a PIN code entered by the user.
void ble_io_stream_submit_pin(BleIoStream* stream, const gchar* pin);

// Set the device address for access code storage.
void ble_io_stream_set_device_address(BleIoStream* stream,
                                       const gchar* address);

// Set callback for PIN code requests.
void ble_io_stream_set_pin_callback(
    BleIoStream* stream,
    void (*callback)(const gchar* address, gpointer user_data),
    gpointer user_data);
```

- [ ] **Step 2: Initialize PIN members in ble_io_stream_new**

In `ble_io_stream.c`, in `ble_io_stream_new()`, add initialization:

```c
g_mutex_init(&stream->pin_mutex);
g_cond_init(&stream->pin_cond);
stream->pending_pin = NULL;
stream->pin_ready = FALSE;
stream->device_address = NULL;
stream->on_pin_code_required = NULL;
stream->pin_callback_data = NULL;
```

- [ ] **Step 3: Clean up PIN members in ble_io_stream_free**

Add to `ble_io_stream_free()`:

```c
g_mutex_clear(&stream->pin_mutex);
g_cond_clear(&stream->pin_cond);
g_free(stream->pending_pin);
g_free(stream->device_address);
```

- [ ] **Step 4: Implement public functions**

```c
void ble_io_stream_submit_pin(BleIoStream* stream, const gchar* pin) {
    g_mutex_lock(&stream->pin_mutex);
    g_free(stream->pending_pin);
    stream->pending_pin = g_strdup(pin);
    stream->pin_ready = TRUE;
    g_cond_signal(&stream->pin_cond);
    g_mutex_unlock(&stream->pin_mutex);
}

void ble_io_stream_set_device_address(BleIoStream* stream,
                                       const gchar* address) {
    g_free(stream->device_address);
    stream->device_address = g_strdup(address);
}

void ble_io_stream_set_pin_callback(
    BleIoStream* stream,
    void (*callback)(const gchar* address, gpointer user_data),
    gpointer user_data) {
    stream->on_pin_code_required = callback;
    stream->pin_callback_data = user_data;
}
```

- [ ] **Step 5: Add access code storage helpers**

Use `GKeyFile` with XDG config dir:

```c
static gchar* get_access_code_path(void) {
    return g_build_filename(
        g_get_user_config_dir(), "submersion", "ble_access_codes.ini", NULL);
}

static GBytes* load_access_code(const gchar* address) {
    g_autofree gchar* path = get_access_code_path();
    g_autoptr(GKeyFile) kf = g_key_file_new();

    if (!g_key_file_load_from_file(kf, path, G_KEY_FILE_NONE, NULL)) {
        return NULL;
    }

    gchar* key = g_strdup_printf("ble_access_code_%s", address);
    g_autofree gchar* hex = g_key_file_get_string(kf, "access_codes", key, NULL);
    g_free(key);

    if (hex == NULL) return NULL;

    // Decode hex string to bytes.
    gsize hex_len = strlen(hex);
    if (hex_len == 0 || hex_len % 2 != 0) return NULL;
    gsize byte_len = hex_len / 2;
    guint8* bytes = g_malloc(byte_len);
    for (gsize i = 0; i < byte_len; i++) {
        char buf[3] = { hex[i*2], hex[i*2+1], '\0' };
        bytes[i] = (guint8)g_ascii_strtoull(buf, NULL, 16);
    }
    return g_bytes_new_take(bytes, byte_len);
}

static void save_access_code(const gchar* address,
                              const void* data, gsize size) {
    g_autofree gchar* path = get_access_code_path();
    g_autofree gchar* dir = g_path_get_dirname(path);
    g_mkdir_with_parents(dir, 0700);

    g_autoptr(GKeyFile) kf = g_key_file_new();
    g_key_file_load_from_file(kf, path, G_KEY_FILE_NONE, NULL);

    // Encode bytes as hex string.
    GString* hex = g_string_sized_new(size * 2);
    const guint8* bytes = (const guint8*)data;
    for (gsize i = 0; i < size; i++) {
        g_string_append_printf(hex, "%02x", bytes[i]);
    }

    gchar* key = g_strdup_printf("ble_access_code_%s", address);
    g_key_file_set_string(kf, "access_codes", key, hex->str);
    g_free(key);
    g_string_free(hex, TRUE);

    g_key_file_save_to_file(kf, path, NULL);
}
```

- [ ] **Step 6: Extend ble_ioctl for PIN and access codes**

In `ble_ioctl`, after the `BLE_GET_NAME` handler (line 388) and before `return LIBDC_STATUS_UNSUPPORTED` (line 391), add:

```c
#define BLE_IOCTL_GET_PINCODE_NR 1
#define BLE_IOCTL_ACCESSCODE_NR 2

if (ioctl_type == BLE_IOCTL_TYPE && ioctl_number == BLE_IOCTL_GET_PINCODE_NR) {
    if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;

    g_mutex_lock(&stream->pin_mutex);
    g_free(stream->pending_pin);
    stream->pending_pin = NULL;
    stream->pin_ready = FALSE;
    g_mutex_unlock(&stream->pin_mutex);

    // Dispatch callback.
    if (stream->on_pin_code_required) {
        stream->on_pin_code_required(
            stream->device_address, stream->pin_callback_data);
    }

    // Block until submitPinCode is called (60s timeout).
    g_mutex_lock(&stream->pin_mutex);
    gint64 end_time = g_get_monotonic_time() + 60 * G_TIME_SPAN_SECOND;
    while (!stream->pin_ready) {
        if (!g_cond_wait_until(&stream->pin_cond, &stream->pin_mutex,
                                end_time)) {
            g_mutex_unlock(&stream->pin_mutex);
            return LIBDC_STATUS_TIMEOUT;
        }
    }

    if (stream->pending_pin == NULL || stream->pending_pin[0] == '\0') {
        g_mutex_unlock(&stream->pin_mutex);
        return LIBDC_STATUS_CANCELLED;
    }

    size_t pin_len = strlen(stream->pending_pin) + 1;
    size_t copy_len = MIN(pin_len, size);
    memcpy(data, stream->pending_pin, copy_len);
    ((char*)data)[copy_len - 1] = '\0';
    g_mutex_unlock(&stream->pin_mutex);
    return LIBDC_STATUS_SUCCESS;
}

if (ioctl_type == BLE_IOCTL_TYPE && ioctl_number == BLE_IOCTL_ACCESSCODE_NR) {
    if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;
    guint32 direction = (request >> 30) & 0x3;

    if (direction == 1) {
        // GET access code.
        GBytes* stored = load_access_code(stream->device_address);
        if (stored == NULL) return LIBDC_STATUS_UNSUPPORTED;
        gsize stored_size;
        const void* stored_data = g_bytes_get_data(stored, &stored_size);
        size_t copy_len = MIN(stored_size, size);
        memcpy(data, stored_data, copy_len);
        g_bytes_unref(stored);
        return LIBDC_STATUS_SUCCESS;
    }
    if (direction == 2) {
        // SET access code.
        save_access_code(stream->device_address, data, size);
        return LIBDC_STATUS_SUCCESS;
    }
}
```

- [ ] **Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/linux/ble_io_stream.h packages/libdivecomputer_plugin/linux/ble_io_stream.c
git commit -m "feat(linux): add PIN code and access code ioctl handlers to BleIoStream"
```

---

### Task 14: Wire PIN callback and submit_pin_code in Linux HostApiImpl

**Files:**
- Modify: `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc:13-22,154-194`

- [ ] **Step 1: Implement submit_pin_code VTable handler**

In `dive_computer_host_api_impl.cc`, find the `submit_pin_code` VTable handler (it should have been generated by Pigeon). Implement it:

```c
static LibdivecomputerPluginDiveComputerHostApiSubmitPinCodeResponse*
handle_submit_pin_code(
    const gchar* pin_code,
    gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);
  if (ctx->ble_stream != nullptr) {
    ble_io_stream_submit_pin(ctx->ble_stream, pin_code);
  }
  return libdivecomputer_plugin_dive_computer_host_api_submit_pin_code_response_new();
}
```

- [ ] **Step 2: Add PIN callback dispatch function**

Add a static callback that dispatches to the main thread via GLib idle:

```c
struct PinCallbackData {
    LibdivecomputerPluginDiveComputerFlutterApi* flutter_api;
    gchar* address;
};

static gboolean pin_callback_idle(gpointer data) {
    auto* cbd = static_cast<PinCallbackData*>(data);
    libdivecomputer_plugin_dive_computer_flutter_api_on_pin_code_required(
        cbd->flutter_api, cbd->address, nullptr, nullptr, nullptr);
    g_free(cbd->address);
    delete cbd;
    return G_SOURCE_REMOVE;
}

static void on_pin_code_required(const gchar* address, gpointer user_data) {
    auto* ctx = static_cast<HostApiContext*>(user_data);
    auto* cbd = new PinCallbackData();
    cbd->flutter_api = ctx->flutter_api;
    cbd->address = g_strdup(address);
    g_idle_add(pin_callback_idle, cbd);
}
```

- [ ] **Step 3: Wire PIN callback in download_thread_func**

In `download_thread_func`, BETWEEN `ctx->ble_stream = ble_io_stream_new()` (line 187) and `ble_io_stream_connect()` (line 188). The callback MUST be set BEFORE `ble_io_stream_connect()` because BLE authentication can be triggered during connection. Add:

```c
ble_io_stream_set_device_address(ctx->ble_stream, td->address);
ble_io_stream_set_pin_callback(ctx->ble_stream, on_pin_code_required, ctx);
```

- [ ] **Step 4: Register submit_pin_code handler in VTable**

Find where the VTable is set up (where `handle_start_download` etc. are registered) and add:

```c
vtable.submit_pin_code = handle_submit_pin_code;
```

- [ ] **Step 5: Build Linux to verify** (skip if not on Linux)

Run:
```bash
flutter build linux --debug 2>&1 | tail -20
```

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc
git commit -m "feat(linux): wire PIN code callback and submit_pin_code in HostApiImpl"
```

---

## Chunk 6: Integration Verification

### Task 15: Full build and format verification

**Files:** All modified files

- [ ] **Step 1: Format Dart code**

Run:
```bash
dart format lib/ packages/libdivecomputer_plugin/lib/ packages/libdivecomputer_plugin/pigeons/
```

Expected: No changes needed (or applies formatting fixes).

- [ ] **Step 2: Run Flutter analyze**

Run:
```bash
flutter analyze
```

Expected: No errors.

- [ ] **Step 3: Run tests**

Run:
```bash
flutter test
```

Expected: All existing tests pass.

- [ ] **Step 4: Build macOS**

Run:
```bash
flutter build macos --debug 2>&1 | tail -30
```

Expected: Build succeeds.

- [ ] **Step 5: Final commit (if any formatting fixes)**

```bash
git add -A && git commit -m "chore: format and clean up PIN code auth implementation"
```

---

### Task 16: Manual testing checklist

This task documents what to test with a real Pelagic device. No code changes.

- [ ] **Test 1: First-time PIN entry**

1. Pair with an Aqualung i300R (or other Pelagic device) for the first time
2. Tap Download -- device should display a 6-digit PIN
3. App should show PIN dialog
4. Enter the correct PIN and submit
5. Download should proceed normally
6. Verify device info (serial, firmware) is populated

- [ ] **Test 2: Subsequent downloads use cached access code**

1. Download from the same device again
2. No PIN dialog should appear (access code is cached)
3. Download proceeds normally

- [ ] **Test 3: PIN cancellation**

1. Trigger a PIN request
2. Tap Cancel on the PIN dialog
3. Download should abort gracefully with no crash

- [ ] **Test 4: Wrong PIN**

1. Enter an incorrect PIN
2. The device should reject it, libdivecomputer may retry (up to 3 times)
3. Each retry triggers a new PIN dialog

- [ ] **Test 5: Non-PIN device unaffected**

1. Download from a non-Pelagic BLE device (e.g., Shearwater, Suunto)
2. No PIN dialog should appear
3. Download proceeds normally as before
