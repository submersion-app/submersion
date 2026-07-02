# Android dive-computer download — process isolation (issue #318)

Status: design approved 2026-06-30
Branch: `worktree-issue-318-process-isolation`

## Problem

Downloading from a Mares Puck Pro over USB-serial on Android crashes the whole
app with a **silent native `SIGSEGV`/`SIGABRT`** inside libdivecomputer's C /
USB-stack code. Four functional fixes have shipped (#318: 16 KB alignment,
ProGuard keep, serial-read accumulation, JNI local-ref release) and it still
crashes.

The prior "the app won't crash" hardening was a Kotlin `try/catch(Throwable)`
backstop around the download plus Dart global error handlers. Those catch
**Java/Kotlin exceptions** — but a native signal is not a `Throwable`; the kernel
terminates the process before any `catch` or zone handler runs. So the backstop
cannot contain a native crash, and the app dies.

## Goal

Guarantee the **app process never dies** because of a native dive-computer
download crash — regardless of which native bug causes it (this one or a future
one). On a native crash the app reports a normal "download failed" error and
stays alive and responsive.

This is a **robustness** change (stop the app dying). It is deliberately
decoupled from **functionality** (making the Mares download actually succeed),
which is pursued separately via the Subsurface-mirrored `read()` and the
diagnostic logging already added on this branch.

## Non-goals

- Making the Mares download succeed (separate effort).
- Isolating BLE downloads now (see Scope — the infrastructure is built to accept
  BLE later, but this spec implements serial only).
- Any change to iOS/macOS/Windows/Linux (they run in-process and are unaffected).
- Any change to the Flutter/Dart layer or the Pigeon contract.

## Approach

Run the native serial download in a **separate Android process** (`:dc`). A
native crash there kills only that child process; the main app detects the death
over the binder and reports an error. This is the process-level generalization of
the `catch(Throwable)` backstop — you cannot reliably catch `SIGSEGV` in-process
(a signal handler runs on top of already-corrupted memory), so isolation is the
correct mechanism.

### Key constraint that shapes the design

A `UsbDeviceConnection` cannot cross a process boundary, and
`usb-serial-for-android` requires one. Therefore the **entire serial stack — USB
enumeration, permission, open, `usb-serial-for-android`, and the
`nativeDownloadRun` JNI call — must live in the child process.** The main process
only sends "download device X" and listens for results. (This also rules out
`android:isolatedProcess="true"`, which has no `UsbManager` access.)

## Scope

- **Serial-USB downloads run in `:dc`.** This is the crashing path.
- **BLE downloads stay in the main process for now.** BLE also runs native
  libdivecomputer and is technically still vulnerable, but it currently works and
  its IPC needs are much harder (async GATT bridge, bonding, blocking PIN-code
  prompts). The service / AIDL / client are named and structured transport-
  agnostically so a BLE download can move into `:dc` as a follow-up.
- **Device discovery stays in the main process.** `getDeviceDescriptors` /
  version enumerate the descriptor table with no device I/O and are not
  crash-prone; isolating them is unnecessary. (The native `.so` therefore loads
  in both processes — each process has its own copy; that is fine.)

## Architecture

```
┌─ Main process (Flutter app) ────────────┐        ┌─ :dc child process ─────────────┐
│  Flutter (Dart)                          │  AIDL  │  DiveDownloadService            │
│    │ Pigeon (UNCHANGED)                  │  bind  │    │                            │
│  DiveComputerHostApiImpl                 │ ◄────► │  SerialDownloadRunner           │
│    ├─ discovery/version   (stays)        │        │    ├─ UsbSerialProber + perms   │
│    ├─ BLE download        (stays)        │        │    ├─ UsbSerialIoStream (moved) │
│    └─ serial download → SerialDownload   │        │    └─ LibdcWrapper.native-      │
│         Client ──────────────────────────┼────────┤         DownloadRun (moved)     │
└──────────────────────────────────────────┘        └─────────────────────────────────┘
```

### Components

| Component | Process | Purpose | Interface | Depends on |
| --- | --- | --- | --- | --- |
| `DiveComputerHostApiImpl` (modify) | main | Pigeon `HostApi`. Serial path delegates to `SerialDownloadClient` and re-emits its callbacks to Flutter via the existing `flutterApi.*`. **Pigeon surface unchanged.** | existing `startDownload`/`cancelDownload` | `SerialDownloadClient`, `flutterApi` |
| `SerialDownloadClient` (new) | main | Owns one serial download's bound-service lifecycle: bind, forward request, receive AIDL callbacks, hold the `DeathRecipient`, unbind. | `start(request, emitter)`, `cancel()` | AIDL stubs, `Context` |
| `DiveDownloadService` (new) | `:dc` | Bound `Service` (`android:process=":dc"`). Implements the AIDL interface; delegates to `SerialDownloadRunner`. One download at a time. | `IDiveDownloadService` | `SerialDownloadRunner` |
| `SerialDownloadRunner` (new class; logic adapted from `performUsbSerialDownload`) | `:dc` | The serial download itself: enumerate USB, request permission, open, run `nativeDownloadRun` with `UsbSerialIoStream`, multi-port probe buffering. Emits via the callback. | `run(request, callback)`, `cancel()` | `UsbSerialIoStream`, `LibdcWrapper`, `UsbManager` |
| `UsbSerialIoStream` (~unchanged; now instantiated in `:dc`) | `:dc` | `SerialIoHandler` bridging libdivecomputer I/O to the USB port. Same class/package as today, just constructed by `SerialDownloadRunner` in the child. Already `NativeTrace`-instrumented. | `SerialIoHandler` | `usb-serial-for-android` |
| `IDiveDownloadService.aidl` / `IDiveDownloadCallback.aidl` (new) | shared | The IPC contract. | see below | — |
| `SerialDownloadRequest` (new, `Parcelable`) | shared | vendor, product, model, name, fingerprint bytes. | `Parcelable` | — |

### AIDL contract

```
interface IDiveDownloadService {
    void startSerialDownload(in SerialDownloadRequest req, IDiveDownloadCallback cb);
    void cancel();
}

interface IDiveDownloadCallback {
    void onProgress(int current, int max);
    void onDive(in byte[] pigeonEncodedDive);   // ParsedDive encoded via the plugin's Pigeon codec
    void onError(String code, String message);
    void onComplete(long serial, long firmware);
}
```

## Data flow (normal download)

1. Flutter calls the Pigeon download method → `DiveComputerHostApiImpl` (main)
   detects a serial transport → `SerialDownloadClient.start(request, emitter)`.
2. `SerialDownloadClient` binds `DiveDownloadService` (spins up `:dc`); on
   connect it calls `startSerialDownload(request, callback)`.
3. In `:dc`, `SerialDownloadRunner` enumerates USB, requests permission, opens
   the port, and runs `nativeDownloadRun` with `UsbSerialIoStream` — today's
   logic, relocated.
4. Progress/dive events → AIDL `onProgress`/`onDive` → main → re-emitted through
   the existing `flutterApi.onDownloadProgress` / `onDiveDownloaded` → Flutter.
5. `onComplete` → `flutterApi.onDownloadComplete` → Flutter; main unbinds `:dc`.

### USB permission from the child

`UsbManager.requestPermission()` is system-mediated: the child service calls it,
Android draws the dialog over the foreground app, the user taps OK, and the grant
goes to the **requesting (child) process**. The UX is unchanged — the dialog
appears when the user taps download — but permission now belongs to `:dc`; the
main process neither needs nor holds it.

### Dive marshaling

`onProgress` / `onError` / `onComplete` carry primitives — trivial. The dive
payload crosses as `onDive(byte[])` where the bytes are the `ParsedDive` **encoded
with the plugin's own Pigeon codec**: the child encodes, the main process decodes
back to an identical `ParsedDive` and forwards it to Flutter unchanged. This
reuses the existing serialization, duplicates no schema, and automatically tracks
future `ParsedDive` changes. (A single dive's encoded size stays well under the
~1 MB binder transaction limit; see Risks.)

## Crash / death handling (the core)

- `SerialDownloadClient` registers `binder.linkToDeath(deathRecipient)` (fires
  promptly on binder death — the primary crash signal) and uses
  `ServiceConnection.onServiceDisconnected` as a backup.
- If `:dc` dies while a download is in-flight → emit
  `onDownloadError("download_crashed", "The download process stopped
  unexpectedly — please try again.")` through the existing Pigeon path. **The
  main process never receives a signal; it stays alive.**
- Normal teardown calls `unlinkToDeath` before intentional unbind and tracks
  in-flight state, so the `DeathRecipient` never fires spuriously.
- An OS low-memory kill of `:dc` is handled identically — graceful, not a crash.
- The child's `NativeTrace` breadcrumbs are still written synchronously to
  `submersion.log` (the child shares the app's `filesDir`), so we also learn
  *where* it died.

### No in-process fallback (decision)

If the service fails to bind, or `:dc` dies instantly and repeatedly, the app
reports the error — it does **not** run the download in the main process. An
in-process fallback would reintroduce the exact `SIGSEGV`-kills-the-app risk we
are removing. Serial downloads always go through `:dc`; a broken child means
serial downloads fail *recoverably*, never fatally. This is a deliberate
robustness-over-availability choice.

### Cancel & partial dives

- Cancel forwards to `IDiveDownloadService.cancel()` → the existing
  libdivecomputer cancel flag in the child.
- Dives stream one-by-one as they parse. The multi-port probe buffering stays in
  the child (flush-on-success, as today). A crash *before* flush loses only
  unconfirmed buffered dives (correct); dives already streamed to the main
  process are **kept and imported** — each emitted dive is complete.

## Testing

- **Crash-isolation test (the key one, no hardware needed):** a debug-only crash
  hook in `SerialDownloadRunner` (e.g. a reserved device name / debug flag that
  triggers a deliberate native `abort()`/null-deref mid-run). The test asserts
  `:dc` dies, the main process emits `download_crashed`, and the app is still
  alive and responsive. This validates the guarantee on any emulator, decoupled
  from the Mares bug.
- **Marshaling round-trips (pure JVM):** `ParsedDive → bytes → ParsedDive`
  equality; `SerialDownloadRequest` parcel round-trip.
- **Lifecycle:** bind / cancel / death-detection handling (Robolectric or
  instrumented where feasible).
- **CI manifest guard:** a small script (sibling to the existing #318 guards)
  asserting `DiveDownloadService` keeps `android:process=":dc"`, so the isolation
  can't be silently removed.
- Full end-to-end (a real Mares download) still needs hardware; the
  crash-isolation guarantee does not.

## Relationship to existing work on this branch

The `NativeTrace` diagnostic logging already on this branch moves with
`UsbSerialIoStream` / `DiveComputerHostApiImpl` into the child process and keeps
working (synchronous writes to the shared `submersion.log`). Diagnostics
(find the bug) and isolation (survive the bug) compose.

## Risks / open questions

- **USB permission dialog from a service** should work (system-mediated) but must
  be device-verified; some OEM skins may behave differently. If it ever fails to
  surface from `:dc`, the fallback is to trigger `requestPermission` from the
  main activity and hand the granted device identity to the child (permission is
  per-process, so the child still re-opens) — noted, not designed here.
- **Binder transaction size:** a single very long dive's encoded samples must fit
  under ~1 MB. Expected fine; add a guard/log if an encoded dive approaches the
  limit.
- **Service startup latency:** binding adds ~100 ms to the first download —
  negligible.
- **BLE remains in-process** and vulnerable until the follow-up; acceptable per
  scope.
