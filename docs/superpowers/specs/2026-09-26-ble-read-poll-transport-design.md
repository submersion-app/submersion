# Read-poll BLE transport for the Seac Tablet

Issue: #1454 (split out of #1419)

## Problem

The Seac Tablet cannot download over BLE on any platform. libdivecomputer
commit `415778c` documents its layout:

```
Service: 84968ffe-d26d-478a-b953-5010bcf58bca
Characteristics:
  - Rx/Tx: 43c620c2-1b09-4951-bc1e-9c75298cddeb (read, write)
```

The data characteristic supports neither notifications nor indications; the
host must read it. All four native BLE transports assume a write
characteristic plus a notify/indicate characteristic:

- Every platform skips a service with no notify/indicate characteristic
  (Android `BleIoStream.kt` `onServicesDiscovered`, Darwin
  `BleCharacteristicSelector.select`, Windows `DiscoverCharacteristics`, Linux
  `ble_io_stream_connect`).
- Every platform reports connect success only after a notification
  subscription succeeds (Android `dataNotifyReady`, Darwin `isReady`, Windows
  CCCD write, Linux `StartNotify`).
- No platform issues a GATT characteristic read anywhere. Every read queue is
  fed by the notification callback alone.

Discovery was fixed separately in #1456, so the Tablet now appears in the
wizard and then fails to connect.

## Evidence from upstream

- Subsurface commit `e8e0cea769` ("Support reading BLE characteristic without
  notify", Jef Driesen, the libdivecomputer maintainer) implements the read
  path as **read-on-demand**: each libdivecomputer `read()` with an empty queue
  issues one `readCharacteristic` and waits for the response. There is no
  background loop.
- libdivecomputer commit `15d6f6c` (weppos with Jef Driesen) logs the device:
  after a command, the first packet arrives after roughly 2.1 to 2.3 s
  (occasionally 5.6 s); later packets arrive about 15 ms apart, and each
  back-to-back read returns a **different** 128-byte packet. The Tablet keeps a
  response queue on its side and each GATT read pops one packet, so re-reading
  does not duplicate data.
- The same log shows the failure mode of an unguarded read-on-demand
  transport: a read times out, its ATT request stays outstanding, and the late
  response lands in the next read after `purge`, corrupting the retry until a
  CRC error forces another attempt.
- `seac_screen_device_open` sets a 6000 ms BLE timeout and wraps the stream in
  `dc_packet_open(..., 244, 244)`. `dc_packet_read` loops `while (nbytes <
  size)`, so a transport read that returns success with zero bytes is retried
  immediately with no timeout accounting. A transport must never return
  zero-byte success.

## Decisions

| Question | Decision |
| --- | --- |
| Platforms | Android, Darwin (iOS and macOS), Windows and Linux in one PR |
| Read strategy | Read-on-demand, hardened (not a background poll loop) |
| Selection scope | Allowlist of known read-poll services; today only Seac |
| Tier priority | Strict fallback: consulted only when the notify pass finds nothing |
| Empty read value | Re-read after a 100 ms backoff, bounded by the read deadline |
| Timed-out read | Stays in flight and is adopted by the next `read()` |
| Purge | Also discards the result of a read already in flight |
| Refactoring | Extract Android selection into a pure, tested unit |
| Tests | Darwin and Android unit tests; Windows and Linux compile in CI only |
| Issue linkage | `Refs #1454` while draft; `Closes #1454` after hardware passes |

## Design

### 1. Selection tier and connect gating

The existing write/notify selection runs unchanged on every platform. The read
tier is consulted only when that pass finds no usable service, so no device
that works today can change behaviour.

Each platform carries one allowlist table mapping a read-poll service UUID to
its data characteristic UUID. It holds one entry:

| Service | Data characteristic |
| --- | --- |
| `84968ffe-d26d-478a-b953-5010bcf58bca` | `43c620c2-1b09-4951-bc1e-9c75298cddeb` |

A service matches when that characteristic is present and has READ plus
(WRITE or WRITE_NO_RESPONSE). The same characteristic is both the write target
and the read source.

The selection result gains a response mode:

- Darwin `Selection`: `notifyIndex` becomes `responseIndex`, plus
  `responseMode: ResponseMode` (`.notify` or `.read`).
- Android: the new `BleCharacteristicSelector.Selection` mirrors the Darwin
  shape.
- Windows and Linux: an equivalent enum member on the stream.
- Linux walks a flat per-device characteristic list, so its read tier also
  checks the characteristic's parent `Service` UUID.

In read mode the connect performs no CCCD write, `setNotifyValue`,
`StartNotify`, `ValueChanged` or `PropertiesChanged` subscription, and no
credit handshake (the Seac service has no credit layout). The response path is
marked ready as soon as the characteristic is chosen:

- Android: `dataNotifyReady` is renamed `responsePathReady` and set directly.
- Darwin: `isReady` and `signalDiscoveryReady()` without subscribing.
- Windows and Linux: the connect returns success after the (no-op) credit
  step.

Close skips `StopNotify` and CCCD teardown in read mode.

Diagnostics: each platform logs `read-poll tier selected: service=...
characteristic=...`, and the "no usable service" error also lists read-only
candidates it saw.

### 2. Read-poll semantics

Every platform keeps its existing one-entry-per-packet queue, and `read()`
still returns bytes from at most one entry (the invariant from the i330R fix,
PR #321). In read mode a state machine with two flags, `readInFlight` and
`discardInFlight`, decides when a GATT read goes on the wire.

`read(size, timeout)`:

1. Leftover bytes or a queued chunk are returned immediately, with no GATT
   traffic.
2. Otherwise `deadline = now + timeout`, then loop:
   - If `!readInFlight`, issue one GATT read and set `readInFlight = true`. On
     Android this first `tryAcquire`s the one-permit `gattOperation` gate within
     the remaining time, since reads and writes share the single GATT slot.
   - Wait on the queue until the deadline, or until a completion without data
     wakes the waiter.
   - A chunk is returned.
   - At the deadline, return TIMEOUT and leave the read in flight. The next
     `read()` adopts it rather than issuing a second request.

Read completion (asynchronous on every platform):

- Clear `readInFlight`; on Android release the gate.
- If `discardInFlight` is set, drop the value and clear the flag.
- A non-empty value is enqueued and wakes the waiter.
- An empty value or a GATT error wakes the waiter, which re-issues after a
  100 ms backoff while the deadline allows. An error is logged once per
  `read()`, not once per retry.

`purge(input)` clears the queue as today and, if a read is in flight, sets
`discardInFlight`.

`poll(timeout)` (implemented on Darwin, Windows and Linux; Android has no poll
callback) issues a read in read mode if none is in flight, then waits for the
queue. The Seac driver does not call poll; this keeps the semantics
consistent.

Disconnect and close wake any waiter, fail the pending read and, on Android,
release a held gate permit. Every gate held across an async completion needs a
release on every terminal path.

Timeouts are unchanged. libdivecomputer requests 6000 ms for Seac BLE; Darwin,
Windows and Linux clamp to at least 3000 ms and Android passes it through.
Adopting in-flight reads means a response slower than one timeout still lands
in the next read.

The decisions (issue or wait; completion leads to enqueue, drop or retry after
backoff; purge) live in a pure `ReadPollPolicy` in Swift and Kotlin with unit
tests. Windows and Linux carry the same state machine in a small new source
file each.

### 3. Platform wiring

**Android**

- Extract the inline scoring from `onServicesDiscovered` into a pure
  `BleCharacteristicSelector.kt` operating on `(uuid, properties)` data
  classes. The preferred-UUID sets and credit-layout detection move with it.
- New `ReadPollPolicy.kt`.
- Read mode: skip the CCCD chain and set `responsePathReady`; `read()` issues
  `gatt.readCharacteristic()` while holding `gattOperation`; override both
  `onCharacteristicRead` overloads (API 33+ `(gatt, char, value, status)` and
  the deprecated `(gatt, char, status)`), filter by the selected
  characteristic and route through the policy; the disconnect branch and
  `close()` wake the waiter and release a held permit.
- Writes are unchanged. The Seac characteristic has no WRITE_NO_RESPONSE, so
  `writeLocked` uses WRITE_TYPE_DEFAULT.

**Darwin**

- The selector gains the read tier and `responseMode`.
- New `ReadPollPolicy.swift` in `darwin/Sources/LibDCDarwin/`, symlinked into
  `ios/Classes/` and `macos/Classes/`, and added to `run_native_tests.sh`.
- Read mode: `finalizeCharacteristicSelection` marks the connection ready
  without subscribing; `performRead` calls `peripheral.readValue(for:)` on the
  CoreBluetooth queue; `didUpdateValueFor` routes values for the selected
  characteristic through the policy (it has no notify property, so every value
  is a read response); the error branch signals the waiter instead of
  returning silently.

**Windows** (new `ble_read_poll.cc` and `.h`, added to `windows/CMakeLists.txt`)

- `DiscoverCharacteristics` gains the read tier; read mode skips the CCCD
  write and the `ValueChanged` registration.
- Reads use `ReadValueAsync(BluetoothCacheMode::Uncached)`. The default mode
  may return a cached value.
- The read is issued asynchronously with a `Completed` handler (not `.get()`),
  so a timed-out read keeps running and can be adopted. The handler captures a
  `shared_ptr` to the poll state, never `this`, and is registered with the
  state lock released because `Completed` runs inline on an already-finished
  operation. Results feed `read_chunks_` under `read_mutex_` and `read_cv_`.
- `Close()` detaches the poll state so a late completion is a no-op.

**Linux** (new `ble_read_poll.c` and `.h`, added to `linux/CMakeLists.txt`)

- The read tier matches the characteristic path by UUID and parent `Service`
  UUID.
- Read mode skips `StartNotify` and the `PropertiesChanged` subscription
  entirely, which also prevents BlueZ delivering a value twice (the
  `ReadValue` reply plus the `Value` property change).
- Reads are asynchronous `g_dbus_connection_call(... "ReadValue", {} ...)`
  with a refcounted poll state as user data. Replies feed `read_chunks`
  under `read_mutex` and `read_cond`.
- `ble_io_stream_close` skips `StopNotify` in read mode and detaches the
  state.

**Shared C bridge**: `libdc_download.c` is unchanged.

### 4. Testing, verification and rollout

Unit tests, written first:

- Darwin selector (`Tests/BleCharacteristicSelectorTests/main.swift`):
  - the Seac layout selects read mode with write index equal to response
    index;
  - the same READ+WRITE shape under a non-allowlisted service stays nil;
  - a device exposing both a working notify service and the Seac service
    selects the notify service;
  - the allowlisted service with the characteristic lacking READ, or lacking
    WRITE, stays nil;
  - every existing case (Halcyon, TIO, u-blox, the read-only 0x180A case)
    passes unchanged.
- Darwin `ReadPollPolicy` (new target in `run_native_tests.sh`): issue when
  idle; adopt in flight; enqueue on data; retry after 100 ms on empty or
  error, bounded by the deadline; purge while in flight discards the late
  value; disconnect fails the waiter.
- Android (`android/src/test/kotlin/...`, run in CI by
  `./gradlew :libdivecomputer_plugin:testDebugUnitTest`):
  `BleCharacteristicSelectorTest` ports the full Darwin case list so the
  extraction is pinned before the read tier is added; `ReadPollPolicyTest`
  mirrors the Swift policy tests.
- Windows and Linux: no unit harness exists. The new files compile in the
  "Build Windows" and "Build Linux" jobs of `native-plugin-tests.yml`, which
  run on any PR touching the plugin.

Regression safety: the read tier runs only after the notify pass finds
nothing, and only for allowlisted services. No existing device's path
changes; Android's selector moves files, pinned by the ported tests.

Hardware verification:

- The Android build from the PR's artifact-links comment goes to the
  reporter who offered to test on #1454. Contacting them is confirmed with the
  maintainer first.
- Their log answers the remaining unknown, what an empty read returns, via the
  debug lines logged for each read issued and each response.
- Darwin, Windows and Linux land with compile evidence only, and the PR body
  says so.

PR linkage: the PR opens as a draft with `Refs #1454` and stays a draft until
the Android hardware run passes; the keyword then becomes `Closes #1454`
before merge. No UI changes, so the Screenshots section is deleted.

## Out of scope

- A generic read-only tier for unknown devices.
- A background poll loop.
- Changes to libdivecomputer, `libdc_download.c` or any Dart code.
- Unit-test harnesses for the Windows and Linux BLE transports.
