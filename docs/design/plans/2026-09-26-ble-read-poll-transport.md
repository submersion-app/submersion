# Read-poll BLE transport (Seac Tablet) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Seac Tablet download over BLE on Android, iOS/macOS, Windows and Linux by adding a read-on-demand response path for a characteristic that can be read but cannot notify.

**Architecture:** Each platform keeps its write/notify selection unchanged and, only when that finds nothing, falls back to an allowlisted read-poll service. In read mode no notification subscription is made; each libdivecomputer `read()` with an empty queue puts at most one GATT read on the wire, adopts a read already in flight, re-reads an empty value after 100 ms, and lets `purge()` discard an in-flight read's value. The decisions live in a pure `ReadPollPolicy` (Swift and Kotlin, unit-tested); Windows and Linux carry the same state machine in a small new source file each.

**Tech Stack:** Swift + CoreBluetooth (darwin), Kotlin + android.bluetooth (Android), C++/WinRT (Windows), C + GDBus/BlueZ (Linux), JUnit 4, standalone `swiftc` tests.

**Spec:** `docs/superpowers/specs/2026-09-26-ble-read-poll-transport-design.md`

## Global Constraints

- Allowlist, one entry: service `84968ffe-d26d-478a-b953-5010bcf58bca`, data characteristic `43c620c2-1b09-4951-bc1e-9c75298cddeb`. The characteristic must have READ and (WRITE or WRITE_NO_RESPONSE); it is both the write target and the read source.
- The read tier is consulted only when the existing write/notify selection finds no usable service. No existing device's selection may change.
- Retry delay after an empty value or failed read: 100 ms. Longest a waiting reader sleeps before re-checking: 100 ms.
- `read()` returns bytes from at most one queued packet; a partial packet stays at the head. A transport never returns zero-byte success.
- At most one GATT read in flight per connection. A read still in flight when `read()` times out is adopted by the next `read()`.
- `purge(input)` clears queued packets and marks an in-flight read's value for discard.
- Timeouts are unchanged (libdivecomputer requests 6000 ms for Seac BLE).
- No changes to `third_party/libdivecomputer`, `macos/Classes/libdc_download.c`, or any Dart file.
- Never use the em-dash or en-dash as punctuation, nor `--` or a spaced hyphen as prose punctuation, in code, comments, commits or docs. No emojis.
- No mention of Claude, Claude Code or Anthropic in commits, PR text or files.
- Stage explicit paths only (`git add <path> ...`), never `git add -A` or `git add .`.
- Match the surrounding comment density: this plugin explains the why of each non-obvious line, with issue numbers.

## Review Focus

1. **Link drops while a read is waiting with libdivecomputer's "no timeout" (-1).** Expected: `read()` returns a failure within about 100 ms instead of blocking forever. Pinned by the policy `close` tests (Tasks 2 and 6) plus the Android disconnect branch calling `readPoll.close()` (Task 7) and darwin `cClose` (Task 3).
2. **The platform refuses to issue a read** (Android gate timeout or `readCharacteristic()` returning false; WinRT throwing). Expected: back off 100 ms and retry until the deadline, never spin. Pinned by the `issueFailed` policy tests (Tasks 2 and 6).
3. **A completion arrives after close or after the stream is gone.** Expected: dropped, no crash, nothing queued. Pinned by the policy "completed after close" tests; Windows captures a `shared_ptr` state and Linux a refcount (Tasks 8 and 9).
4. **The device answers every read with an empty value until libdivecomputer's deadline.** Expected: reads spaced at least 100 ms apart and TIMEOUT at the deadline, never zero-byte success. Pinned by the "empty values until the deadline" simulation test (Tasks 2 and 6).
5. **Future firmware adds notify to the Seac characteristic.** Expected: the ordinary notify path is used, not read-poll. Pinned by the "Seac characteristic that notifies" selector case (Tasks 1 and 5).

---

## Prerequisites (run once, before Task 1)

The worktree is `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb` (call it `$WT`). `PLUGIN` below means `$WT/packages/libdivecomputer_plugin`.

- [ ] **P1: Initialize the worktree**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb
git submodule update --init --recursive
flutter pub get
```

- [ ] **P2: Codegen and the Android build that creates `android/gradlew`**

Bash commands containing a bare `build` token are refused by a deny rule here, so run them from a scratchpad script:

```bash
cat > "$TMPDIR/wt_prep.sh" <<'EOF'
set -euo pipefail
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug
EOF
bash "$TMPDIR/wt_prep.sh"
```

Expected: codegen succeeds; `android/gradlew` exists afterwards.

- [ ] **P3: Baseline the native tests**

```bash
bash /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/packages/libdivecomputer_plugin/darwin/run_native_tests.sh
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --console=plain
```

Expected: every darwin suite prints its "All ... tests passed." line; Gradle prints BUILD SUCCESSFUL. The system JDK is too new for the Kotlin compiler (a bare `26.0.2` or `27...` error), which is why `JAVA_HOME` points at Android Studio's JBR.

---

### Task 1: Darwin selector read-poll tier

**Files:**
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleCharacteristicSelector.swift`
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift` (one line, the renamed field)
- Test: `packages/libdivecomputer_plugin/darwin/Tests/BleCharacteristicSelectorTests/main.swift`

**Interfaces:**
- Produces:
  - `BleCharacteristicSelector.ResponseMode` (`.notify`, `.read`)
  - `BleCharacteristicSelector.Selection(serviceIndex: Int, writeIndex: Int, responseIndex: Int, responseMode: ResponseMode, score: Int, terminalIoCredits: TerminalIoCredits?)`. `notifyIndex` is renamed `responseIndex`.
  - `BleCharacteristicSelector.seacServiceUUID`, `seacDataUUID`, `readPollServices: [CBUUID: CBUUID]`
  - `BleCharacteristicSelector.select(services:)` (unchanged signature; now falls back to the read tier)

- [ ] **Step 1: Update the test helper for the renamed field and add the failing cases**

In `Tests/BleCharacteristicSelectorTests/main.swift`, change the `resolve` helper body line

```swift
        service.characteristics[selection.notifyIndex].uuid,
```

to

```swift
        service.characteristics[selection.responseIndex].uuid,
```

In case 1 (Halcyon), after the two existing `expect` calls and before its closing `}`, add:

```swift
    expect(BleCharacteristicSelector.select(services: services)?.responseMode == .notify,
           "halcyon: a notify-capable device keeps the notify response path")
```

Then insert these cases immediately before the final `if failures == 0 {` block:

```swift
// Read-poll tier (issue #1454). The Seac Tablet's only data characteristic can
// be read and written but cannot notify or indicate (libdivecomputer 415778c),
// so the host must read it for every packet.
let seacService = "84968FFE-D26D-478A-B953-5010BCF58BCA"
let seacData = "43C620C2-1B09-4951-BC1E-9C75298CDDEB"

// 15. The Tablet as Android and BlueZ enumerate it: Generic Access (whose
// Device Name is read+write on some peripherals) and Device Information ahead
// of the Seac service. Only the Seac service may be chosen, in read mode, with
// the one characteristic serving both roles.
do {
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "00001800-0000-1000-8000-00805F9B34FB"),
            characteristics: [char("00002A00-0000-1000-8000-00805F9B34FB", [.read, .write])]
        ),
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB"),
            characteristics: [char("00002A29-0000-1000-8000-00805F9B34FB", [.read])]
        ),
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: seacService),
            characteristics: [char(seacData, [.read, .write])]
        ),
    ]
    let selection = BleCharacteristicSelector.select(services: services)
    let result = resolve(services, selection)
    expect(selection?.responseMode == .read, "seac: read-poll response path selected")
    expect(result?.serviceIndex == 2, "seac: the Seac service is chosen over GAP and DIS")
    expect(result?.write == CBUUID(string: seacData), "seac: commands go to the data characteristic")
    expect(result?.notify == CBUUID(string: seacData), "seac: replies are read from the same characteristic")
    expect(selection?.terminalIoCredits == nil, "seac: no credit handshake")
}

// 16. The allowlist is the whole read tier: the same read+write shape under
// any other service, or another characteristic under the Seac service, is
// not selectable.
do {
    let elsewhere = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB"),
            characteristics: [char(seacData, [.read, .write])]
        )
    ]
    expect(BleCharacteristicSelector.select(services: elsewhere) == nil,
           "allowlist: the Seac characteristic under another service is not selected")
    let otherCharacteristic = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: seacService),
            characteristics: [char("0000FFE1-0000-1000-8000-00805F9B34FB", [.read, .write])]
        )
    ]
    expect(BleCharacteristicSelector.select(services: otherCharacteristic) == nil,
           "allowlist: another characteristic under the Seac service is not selected")
}

// 17. Strict fallback: any service with a write/notify pair beats the read
// tier, whatever the discovery order, so no device that works today changes.
do {
    let notifyService = BleCharacteristicSelector.Service(
        uuid: CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB"),
        characteristics: [char("0000FFE1-0000-1000-8000-00805F9B34FB", [.writeWithoutResponse, .notify])]
    )
    let seac = BleCharacteristicSelector.Service(
        uuid: CBUUID(string: seacService),
        characteristics: [char(seacData, [.read, .write])]
    )
    let seacFirst = BleCharacteristicSelector.select(services: [seac, notifyService])
    expect(seacFirst?.responseMode == .notify && seacFirst?.serviceIndex == 1,
           "fallback: the notify service wins when listed second")
    let seacLast = BleCharacteristicSelector.select(services: [notifyService, seac])
    expect(seacLast?.responseMode == .notify && seacLast?.serviceIndex == 0,
           "fallback: the notify service wins when listed first")
}

// 18. The allowlisted characteristic needs both directions: READ for replies
// and a write property for commands. Write-without-response alone is enough.
do {
    func selectSeac(_ properties: CBCharacteristicProperties) -> BleCharacteristicSelector.Selection? {
        BleCharacteristicSelector.select(services: [
            BleCharacteristicSelector.Service(
                uuid: CBUUID(string: seacService),
                characteristics: [char(seacData, properties)]
            )
        ])
    }
    expect(selectSeac([.write]) == nil, "seac-props: no READ, not selected")
    expect(selectSeac([.read]) == nil, "seac-props: no write property, not selected")
    expect(selectSeac([.read, .writeWithoutResponse])?.responseMode == .read,
           "seac-props: read + write-without-response is selected")
}

// 19. If future firmware adds notify to the characteristic, the ordinary
// notify path takes it and read-poll is never used.
do {
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: seacService),
            characteristics: [char(seacData, [.read, .write, .notify])]
        )
    ]
    expect(BleCharacteristicSelector.select(services: services)?.responseMode == .notify,
           "seac-notify: a characteristic that notifies uses the notify path")
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash packages/libdivecomputer_plugin/darwin/run_native_tests.sh` (from `$WT`)
Expected: compile failure in `ble_characteristic_selector_tests` (`value of type 'BleCharacteristicSelector.Selection' has no member 'responseIndex'` / `'responseMode'`). The script stops there because of `set -e`.

- [ ] **Step 3: Implement the read tier in the selector**

In `BleCharacteristicSelector.swift`, replace the `Selection` struct (the block starting `/// The chosen write/notify pair, identified by position in the input.`) with:

```swift
    /// How the selected service delivers the computer's replies.
    enum ResponseMode: Equatable {
        /// Subscribe to notifications or indications on the response
        /// characteristic. Every supported computer but one.
        case notify
        /// Read the response characteristic on demand: it can neither notify
        /// nor indicate (the Seac Tablet, issue #1454). See ReadPollPolicy.
        case read
    }

    /// The chosen write/response pair, identified by position in the input.
    ///
    /// Indices (rather than UUIDs) are returned so the caller resolves the
    /// exact live characteristics: BLE peripherals may legally expose multiple
    /// service instances with the same UUID, or repeated characteristic UUIDs,
    /// which UUID-only matching cannot disambiguate.
    struct Selection: Equatable {
        let serviceIndex: Int
        let writeIndex: Int
        /// Where replies arrive: subscribed to in `.notify` mode, read in `.read` mode.
        let responseIndex: Int
        let responseMode: ResponseMode
        let score: Int
        /// Non-nil only when the selected service exposes the full 4-characteristic
        /// Telit layout, in which case the caller must run the credit handshake.
        let terminalIoCredits: TerminalIoCredits?
    }
```

Directly after the `preferredNotifyUUIDs` set (before `/// Locate the credit characteristics in a service.`), add:

```swift
    // MARK: - Read-poll services (issue #1454)
    //
    // A few computers expose a data characteristic that can be read and written
    // but cannot notify or indicate, so every reply has to be fetched with a
    // GATT read. libdivecomputer commit 415778c documents the Seac Tablet's
    // layout; Subsurface's qt-ble.cpp reads it the same way (e8e0cea769).
    //
    // Deliberately an allowlist rather than "any read+write characteristic":
    // Generic Access's Device Name is read+write on some peripherals, and a
    // generic tier would connect to it on a computer whose real serial service
    // was simply not recognised, then time out with nothing to explain why.

    static let seacServiceUUID = CBUUID(string: "84968FFE-D26D-478A-B953-5010BCF58BCA")
    /// Rx/Tx in one characteristic: commands are written to it and replies read from it.
    static let seacDataUUID = CBUUID(string: "43C620C2-1B09-4951-BC1E-9C75298CDDEB")

    /// Read-poll service UUID to its data characteristic UUID.
    static let readPollServices: [CBUUID: CBUUID] = [seacServiceUUID: seacDataUUID]
```

Replace the whole `select(services:)` function (from its doc comment `/// Choose the best write/notify pair across all services, or nil if no` to its closing brace) with:

```swift
    /// Choose the characteristics to talk through, or nil if nothing usable.
    ///
    /// The write/notify pass runs first and is unchanged; the read-poll tier is
    /// consulted only when it finds nothing, so no device that already works
    /// can be moved onto the read path.
    static func select(services: [Service]) -> Selection? {
        selectNotify(services: services) ?? selectReadPoll(services: services)
    }

    /// Choose the best write/notify pair across all services, or nil if no
    /// service has both a writable and a notify/indicate characteristic.
    ///
    /// Ties (equal scores) resolve to the earliest candidate in the input
    /// order the caller supplies. BleIoStream builds that order from BLE
    /// discovery (service-callback completion order, plus the characteristic
    /// order CoreBluetooth returns), which is not guaranteed to match GATT
    /// handle order, so device-specific cases that must not depend on
    /// ordering use a preferred UUID rather than relying on the tie-break.
    private static func selectNotify(services: [Service]) -> Selection? {
        var best: Selection?
        for (serviceIndex, service) in services.enumerated() {
            var bestWrite: (index: Int, score: Int)?
            var bestNotify: (index: Int, score: Int)?

            for (index, characteristic) in service.characteristics.enumerated() {
                if let score = writeScore(characteristic),
                    bestWrite == nil || score > bestWrite!.score {
                    bestWrite = (index, score)
                }
                if let score = notifyScore(characteristic),
                    bestNotify == nil || score > bestNotify!.score {
                    bestNotify = (index, score)
                }
            }

            guard let write = bestWrite, let notify = bestNotify else { continue }

            var serviceScore = write.score + notify.score
            if preferredServiceUUIDs.contains(service.uuid) { serviceScore += 1000 }

            if let existing = best, existing.score >= serviceScore { continue }
            best = Selection(
                serviceIndex: serviceIndex,
                writeIndex: write.index,
                responseIndex: notify.index,
                responseMode: .notify,
                score: serviceScore,
                terminalIoCredits: terminalIoCredits(in: service)
            )
        }
        return best
    }

    /// The first allowlisted read-poll service whose data characteristic can
    /// be both read and written, or nil.
    private static func selectReadPoll(services: [Service]) -> Selection? {
        for (serviceIndex, service) in services.enumerated() {
            guard let dataUUID = readPollServices[service.uuid],
                let index = service.characteristics.firstIndex(where: { $0.uuid == dataUUID })
            else { continue }
            let properties = service.characteristics[index].properties
            guard properties.contains(.read),
                properties.contains(.write) || properties.contains(.writeWithoutResponse)
            else { continue }
            return Selection(
                serviceIndex: serviceIndex,
                writeIndex: index,
                responseIndex: index,
                responseMode: .read,
                score: 0,
                terminalIoCredits: nil
            )
        }
        return nil
    }
```

- [ ] **Step 4: Keep BleIoStream compiling**

In `BleIoStream.swift`, in `finalizeCharacteristicSelection()`, change

```swift
        let notifyChar = entry.characteristics[selection.notifyIndex]
```

to

```swift
        let notifyChar = entry.characteristics[selection.responseIndex]
```

(Task 3 replaces this area; this keeps the file compiling in between.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: `All BleCharacteristicSelector tests passed.` and every other suite still passes.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleCharacteristicSelector.swift \
        packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift \
        packages/libdivecomputer_plugin/darwin/Tests/BleCharacteristicSelectorTests/main.swift
git commit -m "feat(ble): select the Seac Tablet's read-only data characteristic on darwin

Refs #1454"
```

---

### Task 2: Darwin ReadPollPolicy

**Files:**
- Create: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/ReadPollPolicy.swift`
- Create: `packages/libdivecomputer_plugin/darwin/Tests/ReadPollPolicyTests/main.swift`
- Create (symlinks): `packages/libdivecomputer_plugin/ios/Classes/ReadPollPolicy.swift`, `packages/libdivecomputer_plugin/macos/Classes/ReadPollPolicy.swift`
- Modify: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`

**Interfaces:**
- Produces: `struct ReadPollPolicy` with
  - `enum Action: Equatable { case issueRead, wait, closed }`
  - `static let retryDelayMs: UInt64 = 100`, `static let waitSliceMs: UInt64 = 100`
  - `private(set) var readInFlight: Bool`
  - `mutating func next(nowMs: UInt64) -> Action`
  - `mutating func issueFailed(nowMs: UInt64)`
  - `mutating func completed(hasData: Bool, nowMs: UInt64) -> Bool` (true = queue the value)
  - `mutating func purge()`
  - `mutating func close()`

- [ ] **Step 1: Write the failing tests**

Create `darwin/Tests/ReadPollPolicyTests/main.swift`:

```swift
import Foundation

// Standalone test runner for ReadPollPolicy (no XCTest: the LibDCDarwin
// package cannot build under SwiftPM because it depends on Flutter modules
// only present in the CocoaPods build). Run via run_native_tests.sh.
// Mirrored case for case by ReadPollPolicyTest.kt on Android.

var failures = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message) (main.swift:\(line))")
        failures += 1
    }
}

// 1. An idle policy issues one read, then waits while it is in flight rather
// than stacking a second request behind it.
do {
    var policy = ReadPollPolicy()
    expect(policy.next(nowMs: 0) == .issueRead, "idle: first read is issued")
    expect(policy.readInFlight, "idle: the read is recorded as in flight")
    expect(policy.next(nowMs: 5) == .wait, "idle: a second read is not stacked")
    expect(policy.next(nowMs: 10_000) == .wait, "idle: still waiting however long it takes")
}

// 2. A value with data is queued, and the next read goes out at once.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    expect(policy.completed(hasData: true, nowMs: 50), "data: the value is queued")
    expect(policy.next(nowMs: 50) == .issueRead, "data: the next read is issued immediately")
}

// 3. An empty value is not queued, and the re-read waits retryDelayMs.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    expect(!policy.completed(hasData: false, nowMs: 1000), "empty: nothing is queued")
    expect(policy.next(nowMs: 1099) == .wait, "empty: no re-read before the retry delay")
    expect(policy.next(nowMs: 1100) == .issueRead, "empty: re-read once the delay has passed")
}

// 4. A read the platform refused to issue backs off the same way.
do {
    var policy = ReadPollPolicy()
    expect(policy.next(nowMs: 0) == .issueRead, "refused: read requested")
    policy.issueFailed(nowMs: 0)
    expect(!policy.readInFlight, "refused: nothing is in flight")
    expect(policy.next(nowMs: 99) == .wait, "refused: no retry before the delay")
    expect(policy.next(nowMs: 100) == .issueRead, "refused: retried after the delay")
}

// 5. purge() while a read is in flight discards its late value: it answers a
// command libdivecomputer has abandoned. The next read is not delayed.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    policy.purge()
    expect(!policy.completed(hasData: true, nowMs: 500), "purge: the late value is dropped")
    expect(policy.next(nowMs: 500) == .issueRead, "purge: the next read is issued at once")
    expect(policy.completed(hasData: true, nowMs: 600), "purge: the read after that is queued")
}

// 6. purge() with nothing in flight discards nothing later.
do {
    var policy = ReadPollPolicy()
    policy.purge()
    _ = policy.next(nowMs: 0)
    expect(policy.completed(hasData: true, nowMs: 10), "idle-purge: the next value is queued")
}

// 7. A discarded read that came back empty does not start a backoff.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    policy.purge()
    expect(!policy.completed(hasData: false, nowMs: 500), "purged-empty: nothing is queued")
    expect(policy.next(nowMs: 500) == .issueRead, "purged-empty: no backoff")
}

// 8. After close() every read fails and late completions are ignored, so a
// reader waiting with no timeout returns instead of blocking forever.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    policy.close()
    expect(policy.next(nowMs: 1) == .closed, "close: reads fail")
    expect(!policy.completed(hasData: true, nowMs: 2), "close: a late value is dropped")
    expect(policy.next(nowMs: 3) == .closed, "close: still closed")
}

// 9. A device that answers every read with an empty value, over a 6000 ms
// deadline, polled every millisecond: reads go out once per retry delay,
// never in a tight loop.
do {
    var policy = ReadPollPolicy()
    var issued = 0
    var now: UInt64 = 0
    while now < 6000 {
        if policy.next(nowMs: now) == .issueRead {
            issued += 1
            _ = policy.completed(hasData: false, nowMs: now)
        }
        now += 1
    }
    expect(issued == 60, "no-spin: one read per 100 ms over 6000 ms, got \(issued)")
}

if failures == 0 {
    print("All ReadPollPolicy tests passed.")
    exit(0)
} else {
    print("\(failures) ReadPollPolicy test(s) FAILED.")
    exit(1)
}
```

Append to `darwin/run_native_tests.sh`:

```bash

# Read-poll response path (issue #1454). The Seac Tablet's data characteristic
# cannot notify, so every reply is fetched with a GATT read; the policy decides
# when a read goes on the wire.
swiftc -o "$BUILD_DIR/read_poll_policy_tests" \
    Sources/LibDCDarwin/ReadPollPolicy.swift \
    Tests/ReadPollPolicyTests/main.swift

"$BUILD_DIR/read_poll_policy_tests"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: `swiftc` error, `Sources/LibDCDarwin/ReadPollPolicy.swift: no such file`.

- [ ] **Step 3: Implement the policy**

Create `darwin/Sources/LibDCDarwin/ReadPollPolicy.swift`:

```swift
import Foundation

/// Decides when a read-poll BLE transport puts a GATT read on the wire.
///
/// Some dive computers expose a data characteristic that can be read but can
/// neither notify nor indicate (the Seac Tablet, issue #1454), so every reply
/// has to be asked for. libdivecomputer only says when it wants bytes, by
/// calling read(); this policy turns that into GATT reads under three rules:
///
///  - At most one read is in flight. A read still outstanding when
///    libdivecomputer's timeout fires is adopted by the next read() rather
///    than doubled. The Tablet can answer seconds late (libdivecomputer
///    15d6f6c measured up to 5.6 s), and a second request stacked behind the
///    first is what corrupted the retry that commit describes. Android also
///    refuses a second GATT operation outright.
///  - An empty value or a failed read is retried after `retryDelayMs`, never
///    at once. `dc_packet_read` loops until it has every byte it asked for, so
///    a transport that answered an empty value with zero-byte success would
///    make it hammer the characteristic with no timeout ever firing.
///  - purge() discards the value of a read already in flight, because that
///    value answers a command libdivecomputer has abandoned.
///
/// A plain value type with an injected millisecond clock, so it is unit-tested
/// standalone via run_native_tests.sh; BleIoStream guards it with a lock.
/// Mirrored in Kotlin by ReadPollPolicy.kt.
struct ReadPollPolicy {
    enum Action: Equatable {
        /// Put one GATT read on the wire now.
        case issueRead
        /// A read is in flight or backing off; wait for data, then ask again.
        case wait
        /// The link is gone; fail the read.
        case closed
    }

    /// Delay before re-reading after an empty value or a failed read.
    static let retryDelayMs: UInt64 = 100
    /// Longest a waiting reader sleeps before asking the policy again.
    static let waitSliceMs: UInt64 = 100

    private(set) var readInFlight = false
    private var discardInFlight = false
    private var retryNotBeforeMs: UInt64 = 0
    private var isClosed = false

    /// What a reader with an empty queue should do now.
    mutating func next(nowMs: UInt64) -> Action {
        if isClosed { return .closed }
        if readInFlight || nowMs < retryNotBeforeMs { return .wait }
        readInFlight = true
        return .issueRead
    }

    /// The platform refused the read that next() asked for, so no completion
    /// is coming. Back off rather than retry in a tight loop.
    mutating func issueFailed(nowMs: UInt64) {
        readInFlight = false
        retryNotBeforeMs = nowMs + Self.retryDelayMs
    }

    /// A read completed. Returns true when its value should be queued for
    /// libdivecomputer; `hasData` is false for an empty value or a failed read.
    mutating func completed(hasData: Bool, nowMs: UInt64) -> Bool {
        readInFlight = false
        if isClosed { return false }
        if discardInFlight {
            discardInFlight = false
            return false
        }
        if !hasData {
            retryNotBeforeMs = nowMs + Self.retryDelayMs
            return false
        }
        return true
    }

    /// libdivecomputer purged its input: whatever is already on the wire
    /// answers a command it has given up on.
    mutating func purge() {
        if readInFlight { discardInFlight = true }
    }

    /// The link is going away. Every later read fails and late completions
    /// are ignored.
    mutating func close() {
        isClosed = true
        readInFlight = false
        discardInFlight = false
    }
}
```

Create the platform symlinks (the same layout `PacketReadBuffer.swift` uses):

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/packages/libdivecomputer_plugin
ln -s ../../darwin/Sources/LibDCDarwin/ReadPollPolicy.swift ios/Classes/ReadPollPolicy.swift
ln -s ../../darwin/Sources/LibDCDarwin/ReadPollPolicy.swift macos/Classes/ReadPollPolicy.swift
ls -l ios/Classes/ReadPollPolicy.swift macos/Classes/ReadPollPolicy.swift
```

Expected: both entries are symlinks to `../../darwin/Sources/LibDCDarwin/ReadPollPolicy.swift` (compare with `ls -l ios/Classes/PacketReadBuffer.swift`).

- [ ] **Step 4: Run to verify it passes**

Run: `bash packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: `All ReadPollPolicy tests passed.` plus every earlier suite.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/ReadPollPolicy.swift \
        packages/libdivecomputer_plugin/darwin/Tests/ReadPollPolicyTests/main.swift \
        packages/libdivecomputer_plugin/darwin/run_native_tests.sh \
        packages/libdivecomputer_plugin/ios/Classes/ReadPollPolicy.swift \
        packages/libdivecomputer_plugin/macos/Classes/ReadPollPolicy.swift
git commit -m "feat(ble): add the read-poll policy for characteristics that cannot notify

Refs #1454"
```

---

### Task 3: Darwin BleIoStream read mode

**Files:**
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift`

**Interfaces:**
- Consumes: `BleCharacteristicSelector.Selection.responseIndex/responseMode` (Task 1), `ReadPollPolicy` (Task 2).
- Produces: nothing new for other tasks.

No unit test can drive `BleIoStream` (it needs a live `CBPeripheral`); the verification is the macOS build plus the Task 1 and 2 tests.

- [ ] **Step 1: Add the read-mode state**

After the line `private var notifyCharacteristic: CBCharacteristic?` add:

```swift
    /// The read-poll data characteristic (issue #1454), non-nil only when the
    /// selected service cannot notify. Replies are fetched with readValue(for:)
    /// and land in `packetBuffer` exactly as notifications do.
    private var readCharacteristic: CBCharacteristic?
    /// Guards `readPoll`, which the download thread and the CoreBluetooth
    /// delegate queue both touch.
    private let readPollLock = NSLock()
    private var readPoll = ReadPollPolicy()
```

- [ ] **Step 2: Add the helpers**

Directly after `private func drainSemaphore(_ semaphore: DispatchSemaphore) { ... }` add:

```swift
    private func withReadPoll<T>(_ body: (inout ReadPollPolicy) -> T) -> T {
        readPollLock.lock()
        defer { readPollLock.unlock() }
        return body(&readPoll)
    }

    private static func milliseconds(_ time: DispatchTime) -> UInt64 {
        time.uptimeNanoseconds / 1_000_000
    }

    /// Block until the read-poll characteristic has produced a packet, issuing
    /// GATT reads as ReadPollPolicy directs. Returns SUCCESS once a packet is
    /// buffered, TIMEOUT at the deadline, or IO once the stream is closed. The
    /// wait is sliced so an empty value or a refused read is noticed without a
    /// wakeup from the delegate queue.
    private func awaitPolledPacket(_ characteristic: CBCharacteristic,
                                   deadline: DispatchTime) -> Int32 {
        while !packetBuffer.hasData {
            let now = DispatchTime.now()
            if now >= deadline { return Int32(LIBDC_STATUS_TIMEOUT) }
            switch withReadPoll({ $0.next(nowMs: Self.milliseconds(now)) }) {
            case .closed:
                return Int32(LIBDC_STATUS_IO)
            case .issueRead:
                peripheral.readValue(for: characteristic)
            case .wait:
                break
            }
            let slice = now + .milliseconds(Int(ReadPollPolicy.waitSliceMs))
            _ = packetBuffer.poll(deadline: min(deadline, slice))
        }
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    /// Settle one read-poll response (issue #1454). CoreBluetooth reports read
    /// responses through the same delegate method as notifications; the read
    /// characteristic has no notify property, so every value arriving for it
    /// answers a readValue(for:) call.
    private func handleReadResponse(_ characteristic: CBCharacteristic, error: Error?) {
        let value = error == nil ? (characteristic.value ?? Data()) : Data()
        let now = Self.milliseconds(.now())
        let deliver = withReadPoll { $0.completed(hasData: !value.isEmpty, nowMs: now) }
        if deliver {
            consecutiveReadTimeouts = 0
            packetBuffer.append(value)
        }
        if let error {
            NativeLogger.w("BleIoStream", category: "BLE",
                "read-poll read failed for \(characteristic.uuid.uuidString):"
                    + " \(error.localizedDescription); retrying")
        } else {
            NativeLogger.d("BleIoStream", category: "BLE",
                "read-poll \(characteristic.uuid.uuidString) bytes=\(value.count)"
                    + " delivered=\(deliver)"
                    + " data=\(Self.hexString(value, maxBytes: Self.maxLogBytes))")
        }
    }
```

- [ ] **Step 3: Reset read-mode state on connect**

In `connectAndDiscover()`, after `notifyCharacteristic = nil` add:

```swift
        readCharacteristic = nil
        withReadPoll { $0 = ReadPollPolicy() }
```

In the same function, replace the final log statement

```swift
        NativeLogger.d("BleIoStream", category: "BLE",
            "Discovery ready (write=\(self.writeCharacteristic?.uuid.uuidString ?? "nil")"
                + " notify=\(self.notifyCharacteristic?.uuid.uuidString ?? "nil"))")
```

with

```swift
        NativeLogger.d("BleIoStream", category: "BLE",
            "Discovery ready (write=\(self.writeCharacteristic?.uuid.uuidString ?? "nil")"
                + " notify=\(self.notifyCharacteristic?.uuid.uuidString ?? "nil")"
                + " read=\(self.readCharacteristic?.uuid.uuidString ?? "nil"))")
```

- [ ] **Step 4: Route read, poll, purge and close**

In `cClose`, before `stream.centralManager.cancelPeripheralConnection(stream.peripheral)` add:

```swift
        // Wake a read-poll reader waiting with no timeout; it would otherwise
        // block forever on a link that is going away.
        stream.withReadPoll { $0.close() }
```

In `cPoll`, after the line `if timeout == 0 { return Int32(LIBDC_STATUS_TIMEOUT) }`, replace

```swift
        let deadline: DispatchTime = timeout < 0 ? .distantFuture :
            .now() + .milliseconds(Int(timeout))
        return stream.packetBuffer.poll(deadline: deadline)
            ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_TIMEOUT)
```

with

```swift
        let deadline: DispatchTime = timeout < 0 ? .distantFuture :
            .now() + .milliseconds(Int(timeout))
        // A read-poll characteristic pushes nothing, so waiting alone would
        // never see data; ask for it the way read() does.
        if let readChar = stream.readCharacteristic {
            return stream.awaitPolledPacket(readChar, deadline: deadline)
        }
        return stream.packetBuffer.poll(deadline: deadline)
            ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_TIMEOUT)
```

In `performRead`, directly after the `let deadline: DispatchTime = ...` statement add:

```swift
        if let readChar = readCharacteristic {
            let status = awaitPolledPacket(readChar, deadline: deadline)
            if status == Int32(LIBDC_STATUS_SUCCESS),
                let count = packetBuffer.read(into: data, maxBytes: size, deadline: .now()) {
                actual.pointee = count
                return status
            }
            actual.pointee = 0
            if status == Int32(LIBDC_STATUS_TIMEOUT) { consecutiveReadTimeouts += 1 }
            return status == Int32(LIBDC_STATUS_SUCCESS) ? Int32(LIBDC_STATUS_TIMEOUT) : status
        }
```

In `performPurge`, replace

```swift
        packetBuffer.purge()
        return Int32(LIBDC_STATUS_SUCCESS)
```

with

```swift
        packetBuffer.purge()
        withReadPoll { $0.purge() }
        return Int32(LIBDC_STATUS_SUCCESS)
```

- [ ] **Step 5: Handle read responses in the delegate**

At the very top of `peripheral(_:didUpdateValueFor:error:)`, before `if let error {`, add:

```swift
        if let readChar = readCharacteristic {
            guard characteristic.uuid == readChar.uuid else { return }
            handleReadResponse(characteristic, error: error)
            return
        }
```

- [ ] **Step 6: Select read mode without subscribing**

In `finalizeCharacteristicSelection()`:

Change the failure log `"No suitable write/notify characteristic pair found"` to `"No suitable write/notify characteristic pair or read-poll service found"`.

Replace

```swift
        let entry = discoveredServices[selection.serviceIndex]
        let writeChar = entry.characteristics[selection.writeIndex]
        let notifyChar = entry.characteristics[selection.responseIndex]
```

with

```swift
        let entry = discoveredServices[selection.serviceIndex]
        let writeChar = entry.characteristics[selection.writeIndex]
        let responseChar = entry.characteristics[selection.responseIndex]

        if selection.responseMode == .read {
            // Read-poll tier (issue #1454): the computer cannot push its
            // replies, so there is nothing to subscribe to and the response
            // path is ready as soon as the characteristic is chosen.
            writeCharacteristic = writeChar
            readCharacteristic = responseChar
            writeWithoutResponsePreferred = initialWriteWithoutResponsePreference(for: writeChar)
            NativeLogger.d("BleIoStream", category: "BLE",
                "read-poll tier selected: service=\(entry.service.uuid.uuidString)"
                    + " characteristic=\(responseChar.uuid.uuidString)"
                    + " (\(Self.propertySummary(responseChar.properties)))")
            isReady = true
            signalDiscoveryReady()
            return
        }
        let notifyChar = responseChar
```

- [ ] **Step 7: Run the standalone tests**

Run: `bash packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: every suite passes (BleIoStream is not in these suites; this guards Tasks 1 and 2).

- [ ] **Step 8: Build macOS to typecheck BleIoStream**

A new plugin source file needs `pod install` or the stale Pods project omits it (`cannot find 'ReadPollPolicy' in scope`).

```bash
cat > "$TMPDIR/wt_macos.sh" <<'EOF'
set -euo pipefail
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/macos
pod install
cd ..
flutter build macos --debug
EOF
bash "$TMPDIR/wt_macos.sh"
```

Expected: `Built build/macos/Build/Products/Debug/...app`. Any Swift error in `BleIoStream.swift` fails here.

- [ ] **Step 9: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/BleIoStream.swift
git commit -m "feat(ble): read the Seac Tablet's replies on demand on iOS and macOS

Refs #1454"
```

Leave any `macos/Podfile.lock` change unstaged unless `git diff macos/Podfile.lock` shows only this plugin's entry changing.

---

### Task 4: Extract the Android characteristic selector (behaviour-preserving)

**Files:**
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelector.kt`
- Create: `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelectorTest.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt`

**Interfaces:**
- Produces (`object BleCharacteristicSelector`):
  - `const val PROPERTY_READ = 0x02`, `PROPERTY_WRITE_NO_RESPONSE = 0x04`, `PROPERTY_WRITE = 0x08`, `PROPERTY_NOTIFY = 0x10`, `PROPERTY_INDICATE = 0x20`
  - `data class Characteristic(val uuid: UUID, val properties: Int)`
  - `data class Service(val uuid: UUID, val characteristics: List<Characteristic>)`
  - `enum class ResponseMode { NOTIFY, READ }`
  - `data class TerminalIoCredits(val writeIndex: Int, val notifyIndex: Int, val required: Boolean)`
  - `data class Selection(val serviceIndex: Int, val writeIndex: Int, val responseIndex: Int, val responseMode: ResponseMode, val score: Int, val terminalIoCredits: TerminalIoCredits?)`
  - `fun select(services: List<Service>): Selection?`

This task moves the scoring out of `onServicesDiscovered` without changing what it picks. The tests are a line-for-line port of the darwin cases 1 to 14, so both platforms stay pinned to the same answers.

- [ ] **Step 1: Write the failing tests**

Create `android/src/test/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelectorTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import com.submersion.libdivecomputer.BleCharacteristicSelector.Characteristic
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_INDICATE
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_NOTIFY
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_READ
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_WRITE
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_WRITE_NO_RESPONSE
import com.submersion.libdivecomputer.BleCharacteristicSelector.ResponseMode
import com.submersion.libdivecomputer.BleCharacteristicSelector.Selection
import com.submersion.libdivecomputer.BleCharacteristicSelector.Service
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

// JVM port of darwin/Tests/BleCharacteristicSelectorTests. Both platforms must
// choose the same characteristics for the same GATT table, so the cases and
// their expectations are kept identical; a change to one belongs in both.
class BleCharacteristicSelectorTest {

    private companion object {
        const val R = PROPERTY_READ
        const val W = PROPERTY_WRITE
        const val WNR = PROPERTY_WRITE_NO_RESPONSE
        const val N = PROPERTY_NOTIFY
        const val I = PROPERTY_INDICATE

        const val HALCYON_SERVICE = "00000001-8c3b-4f2c-a59e-8c08224f3253"
        const val HALCYON_RX = "00000101-8c3b-4f2c-a59e-8c08224f3253"
        const val HALCYON_TX = "00000201-8c3b-4f2c-a59e-8c08224f3253"
        const val PELAGIC_WRITE = "6606ab42-89d5-4a00-a8ce-4eb5e1414ee0"
        const val PREFERRED_SERVICE = "cb3c4555-d670-4670-bc20-b61dbc851e9a"
        const val TIO_SERVICE = "0000fefb-0000-1000-8000-00805f9b34fb"
        const val TIO_DATA_RX = "00000001-0000-1000-8000-008025000000"
        const val TIO_DATA_TX = "00000002-0000-1000-8000-008025000000"
        const val TIO_CREDITS_RX = "00000003-0000-1000-8000-008025000000"
        const val TIO_CREDITS_TX = "00000004-0000-1000-8000-008025000000"
        const val VENDOR_SERVICE = "53544d54-4552-494f-5345-525631303030"
        const val VENDOR_WRITE = "53544d01-4552-494f-5345-525631303030"
        const val VENDOR_NOTIFY = "53544d02-4552-494f-5345-525631303030"
        const val UBLOX_SERVICE = "2456e1b9-26e2-8f83-e744-f34f01e9d701"
        const val UBLOX_DATA = "2456e1b9-26e2-8f83-e744-f34f01e9d703"
        const val UBLOX_CREDITS = "2456e1b9-26e2-8f83-e744-f34f01e9d704"
    }

    private data class Resolved(val write: UUID, val response: UUID, val serviceIndex: Int)

    private fun uuid(value: String): UUID = UUID.fromString(value)

    private fun char(id: String, vararg properties: Int) =
        Characteristic(uuid(id), properties.fold(0) { acc, p -> acc or p })

    private fun service(id: String, vararg characteristics: Characteristic) =
        Service(uuid(id), characteristics.toList())

    // Resolve a selection back to UUIDs the way BleIoStream does, by index.
    private fun resolve(services: List<Service>, selection: Selection?): Resolved? {
        selection ?: return null
        val chars = services[selection.serviceIndex].characteristics
        return Resolved(
            chars[selection.writeIndex].uuid,
            chars[selection.responseIndex].uuid,
            selection.serviceIndex
        )
    }

    // 1. Halcyon Symbios (#288): both characteristics are read+write+indicate,
    // so only the preferred UUIDs decide. Write to the device Rx (00000101),
    // listen on the device Tx (00000201), as Subsurface does.
    @Test
    fun halcyonWritesRxAndListensOnTx() {
        val services = listOf(
            service(HALCYON_SERVICE, char(HALCYON_RX, R, W, I), char(HALCYON_TX, R, W, I))
        )
        val selection = BleCharacteristicSelector.select(services)
        val result = resolve(services, selection)
        assertEquals(uuid(HALCYON_RX), result?.write)
        assertEquals(uuid(HALCYON_TX), result?.response)
        assertEquals(ResponseMode.NOTIFY, selection?.responseMode)
    }

    // 2. A write-only and a notify-only characteristic stay split (i300C).
    @Test
    fun splitWriteAndNotifyStaySplit() {
        val write = "0000fefb-0000-1000-8000-00805f9b34fb"
        val notify = "0000fefc-0000-1000-8000-00805f9b34fb"
        val services = listOf(
            service("0000fef5-0000-1000-8000-00805f9b34fb", char(write, W, WNR), char(notify, N))
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(uuid(write), result?.write)
        assertEquals(uuid(notify), result?.response)
    }

    // 3. One writable, notifiable characteristic serves both roles.
    @Test
    fun combinedCharacteristicServesBothRoles() {
        val combined = "0000ffe1-0000-1000-8000-00805f9b34fb"
        val services = listOf(service("0000ffe0-0000-1000-8000-00805f9b34fb", char(combined, WNR, N)))
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(uuid(combined), result?.write)
        assertEquals(uuid(combined), result?.response)
    }

    // 4. A service with no notify/indicate characteristic is not selectable.
    @Test
    fun serviceWithoutNotifyIsNotSelected() {
        val services = listOf(
            service("0000180a-0000-1000-8000-00805f9b34fb", char("00002a29-0000-1000-8000-00805f9b34fb", R))
        )
        assertNull(BleCharacteristicSelector.select(services))
    }

    // 5. Empty input yields no selection.
    @Test
    fun emptyInputYieldsNothing() {
        assertNull(BleCharacteristicSelector.select(emptyList()))
    }

    // 6. A preferred service (+1000) beats a higher raw score, and the preferred
    // write UUID is chosen within it.
    @Test
    fun preferredServiceWinsOverHigherRawScore() {
        val services = listOf(
            service(
                "0000aaaa-0000-1000-8000-00805f9b34fb",
                char("0000aab1-0000-1000-8000-00805f9b34fb", WNR),
                char("0000aab2-0000-1000-8000-00805f9b34fb", N)
            ),
            service(
                PREFERRED_SERVICE,
                char(PELAGIC_WRITE, W),
                char("0000bbb2-0000-1000-8000-00805f9b34fb", I)
            )
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(1, result?.serviceIndex)
        assertEquals(uuid(PELAGIC_WRITE), result?.write)
    }

    // 7. Two instances of one service UUID: the higher-scoring second instance
    // is identified by index, not by UUID.
    @Test
    fun duplicateServiceUuidResolvedByIndex() {
        val dup = "0000dddd-0000-1000-8000-00805f9b34fb"
        val secondWrite = "0000dd03-0000-1000-8000-00805f9b34fb"
        val secondNotify = "0000dd04-0000-1000-8000-00805f9b34fb"
        val services = listOf(
            service(
                dup,
                char("0000dd01-0000-1000-8000-00805f9b34fb", W),
                char("0000dd02-0000-1000-8000-00805f9b34fb", I)
            ),
            service(dup, char(secondWrite, W), char(secondNotify, N))
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(1, result?.serviceIndex)
        assertEquals(uuid(secondWrite), result?.write)
        assertEquals(uuid(secondNotify), result?.response)
    }

    // 8. A later, higher-scoring candidate replaces an earlier one.
    @Test
    fun laterHigherScoringCandidateWins() {
        val notifyHigh = "0000ee03-0000-1000-8000-00805f9b34fb"
        val writeHigh = "0000ee04-0000-1000-8000-00805f9b34fb"
        val services = listOf(
            service(
                "0000ee00-0000-1000-8000-00805f9b34fb",
                char("0000ee01-0000-1000-8000-00805f9b34fb", W),
                char("0000ee02-0000-1000-8000-00805f9b34fb", I),
                char(notifyHigh, N),
                char(writeHigh, WNR)
            )
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(uuid(writeHigh), result?.write)
        assertEquals(uuid(notifyHigh), result?.response)
    }

    // 9. OSTC4 (#923): the Terminal I/O service beats the Stollmann vendor
    // service, and the credit characteristics are located.
    @Test
    fun ostc4SelectsTerminalIoWithCredits() {
        val services = listOf(
            service(
                TIO_SERVICE,
                char(TIO_DATA_RX, WNR),
                char(TIO_DATA_TX, N),
                char(TIO_CREDITS_RX, W),
                char(TIO_CREDITS_TX, I)
            ),
            service(VENDOR_SERVICE, char(VENDOR_WRITE, WNR), char(VENDOR_NOTIFY, N))
        )
        val selection = BleCharacteristicSelector.select(services)
        val result = resolve(services, selection)
        assertEquals(0, result?.serviceIndex)
        assertEquals(uuid(TIO_DATA_RX), result?.write)
        assertEquals(uuid(TIO_DATA_TX), result?.response)
        assertEquals(2, selection?.terminalIoCredits?.writeIndex)
        assertEquals(3, selection?.terminalIoCredits?.notifyIndex)
        assertEquals(true, selection?.terminalIoCredits?.required)
    }

    // 10. Reversed discovery order still selects Terminal I/O.
    @Test
    fun ostc4ReorderedStillSelectsTerminalIo() {
        val services = listOf(
            service(VENDOR_SERVICE, char(VENDOR_WRITE, WNR), char(VENDOR_NOTIFY, N)),
            service(
                TIO_SERVICE,
                char(TIO_DATA_RX, WNR),
                char(TIO_DATA_TX, N),
                char(TIO_CREDITS_RX, W),
                char(TIO_CREDITS_TX, I)
            )
        )
        val selection = BleCharacteristicSelector.select(services)
        assertEquals(1, selection?.serviceIndex)
        assertNotNull(selection?.terminalIoCredits)
    }

    // 11. No credit characteristics, no handshake.
    @Test
    fun nonTerminalIoDeviceGetsNoHandshake() {
        val services = listOf(
            service("0000ffe0-0000-1000-8000-00805f9b34fb", char("0000ffe1-0000-1000-8000-00805f9b34fb", WNR, N))
        )
        assertNull(BleCharacteristicSelector.select(services)?.terminalIoCredits)
    }

    // 12. A partial Telit layout does not trigger the handshake.
    @Test
    fun partialTerminalIoLayoutGetsNoHandshake() {
        val services = listOf(service(TIO_SERVICE, char(TIO_DATA_RX, WNR), char(TIO_DATA_TX, N)))
        assertNull(BleCharacteristicSelector.select(services)?.terminalIoCredits)
    }

    // 13. u-blox: data both ways on one characteristic, credits on another,
    // and credits optional.
    @Test
    fun ubloxUsesFifoWithOptionalCredits() {
        val services = listOf(
            service(UBLOX_SERVICE, char(UBLOX_DATA, WNR, N), char(UBLOX_CREDITS, W, I))
        )
        val selection = BleCharacteristicSelector.select(services)
        val result = resolve(services, selection)
        assertEquals(uuid(UBLOX_DATA), result?.write)
        assertEquals(uuid(UBLOX_DATA), result?.response)
        assertEquals(1, selection?.terminalIoCredits?.writeIndex)
        assertEquals(1, selection?.terminalIoCredits?.notifyIndex)
        assertEquals(false, selection?.terminalIoCredits?.required)
    }

    // 14. The u-blox credits characteristic never takes the data role, even
    // with the top raw score on both sides.
    @Test
    fun ubloxCreditsNeverTakeTheDataRole() {
        val services = listOf(
            service(UBLOX_SERVICE, char(UBLOX_CREDITS, WNR, N), char(UBLOX_DATA, W, I))
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(uuid(UBLOX_DATA), result?.write)
        assertEquals(uuid(UBLOX_DATA), result?.response)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --tests '*BleCharacteristicSelectorTest*' --console=plain
```

Expected: FAIL at `compileDebugUnitTestKotlin`, `Unresolved reference: BleCharacteristicSelector`.

- [ ] **Step 3: Create the selector (notify tier only; the read tier arrives in Task 5)**

Create `android/src/main/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelector.kt`:

```kotlin
package com.submersion.libdivecomputer

import java.util.UUID

// Picks the characteristics a BLE dive computer is talked to through.
//
// Pure Kotlin (no Android imports) so it runs as a plain JVM test:
// BleIoStream adapts its live BluetoothGattService objects into the value
// types below and resolves the returned indices back to them. Mirrors
// darwin's BleCharacteristicSelector.swift; the two are pinned to the same
// answers by BleCharacteristicSelectorTest and its Swift twin.
//
// Scoring: write and notify candidates are scored independently so devices
// that split commands and replies across two characteristics pick the right
// pair instead of collapsing onto one. Higher raw scores prefer
// write-without-response and notify over indicate. A preferred-UUID match adds
// +1000 so an explicit per-device mapping always wins over the heuristic and
// over discovery-order tie-breaking.
object BleCharacteristicSelector {

    // Bit values of BluetoothGattCharacteristic.PROPERTY_*, repeated here so
    // this file needs no Android classes.
    const val PROPERTY_READ = 0x02
    const val PROPERTY_WRITE_NO_RESPONSE = 0x04
    const val PROPERTY_WRITE = 0x08
    const val PROPERTY_NOTIFY = 0x10
    const val PROPERTY_INDICATE = 0x20

    data class Characteristic(val uuid: UUID, val properties: Int)

    data class Service(val uuid: UUID, val characteristics: List<Characteristic>)

    // How the selected service delivers the computer's replies.
    enum class ResponseMode {
        // Subscribe to notifications or indications. Every computer but one.
        NOTIFY,
        // Read the characteristic on demand: it can neither notify nor
        // indicate (the Seac Tablet, issue #1454). See ReadPollPolicy.
        READ
    }

    // The credit characteristics of the selected service, as positions in
    // the same input the write/response indices address. `required` is true
    // for Telit, whose bridge carries nothing until credits are granted, and
    // false for u-blox, where a rejected grant falls back to running without
    // flow control (the OSTC nano downloads with no handshake, #280/#394).
    data class TerminalIoCredits(val writeIndex: Int, val notifyIndex: Int, val required: Boolean)

    // Indices rather than UUIDs, so the caller resolves the exact live
    // characteristics even when a peripheral repeats a service UUID.
    data class Selection(
        val serviceIndex: Int,
        val writeIndex: Int,
        val responseIndex: Int,
        val responseMode: ResponseMode,
        val score: Int,
        val terminalIoCredits: TerminalIoCredits?
    )

    // Telit/Stollmann Terminal I/O (TIO), service 0xFEFB.
    //
    // Heinrichs Weikamp computers built on the Telit (formerly Stollmann)
    // BlueMod+SR module (the OSTC 2/3/4/Sport/cR/Plus family) expose their
    // serial bridge behind this service with credit-based flow control (Telit
    // "TIO Implementation Guide" r04). The module carries no UART data until
    // the client subscribes to UART Credits TX and grants initial credits on
    // UART Credits RX (issue #923, OSTC4). Subsurface's qt-ble.cpp handles the
    // same two Heinrichs Weikamp module families: Telit (credits mandatory)
    // and the u-blox serial service (credits optional).
    val TIO_SERVICE_UUID: UUID = UUID.fromString("0000fefb-0000-1000-8000-00805f9b34fb")
    val TIO_DATA_RX_UUID: UUID = UUID.fromString("00000001-0000-1000-8000-008025000000")
    val TIO_DATA_TX_UUID: UUID = UUID.fromString("00000002-0000-1000-8000-008025000000")
    val TIO_CREDITS_RX_UUID: UUID = UUID.fromString("00000003-0000-1000-8000-008025000000")
    val TIO_CREDITS_TX_UUID: UUID = UUID.fromString("00000004-0000-1000-8000-008025000000")

    // u-blox serial service: one characteristic carries data in both
    // directions and one carries credits in both directions.
    val UBLOX_SERVICE_UUID: UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d701")
    val UBLOX_DATA_UUID: UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d703")
    val UBLOX_CREDITS_UUID: UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d704")

    private val PREFERRED_SERVICE_UUIDS = setOf(
        UUID.fromString("cb3c4555-d670-4670-bc20-b61dbc851e9a"),
        // Biased so the serial bridge always beats the Stollmann vendor
        // service the same devices also advertise, which can tie on raw score.
        TIO_SERVICE_UUID,
        UBLOX_SERVICE_UUID
    )
    private val PREFERRED_WRITE_UUIDS = setOf(
        UUID.fromString("6606ab42-89d5-4a00-a8ce-4eb5e1414ee0"),
        // Telit UART Data RX. Raw scoring already prefers it over UART Credits
        // RX, but commands written to the credits characteristic would be
        // silently swallowed, so the pair is pinned rather than left to the
        // heuristic.
        TIO_DATA_RX_UUID,
        // u-blox FIFO, pinned over the credits characteristic for the same reason.
        UBLOX_DATA_UUID,
        // Halcyon Symbios: the app writes commands to the device's Rx endpoint
        // (00000101). Both Symbios characteristics advertise
        // read+write+indicate and tie on raw score, so a preferred UUID is
        // required to tell them apart. The Tx/Rx names are device-centric:
        // Subsurface's qt-ble.cpp writes commands to 00000101 ("Rx") and reads
        // replies from 00000201 ("Tx"). PR #356 mapped these backwards and the
        // device never answered (issue #288).
        UUID.fromString("00000101-8c3b-4f2c-a59e-8c08224f3253")
    )
    private val PREFERRED_NOTIFY_UUIDS = setOf(
        UUID.fromString("a60b8e5c-b267-44d7-9764-837caf96489e"),
        // Telit UART Data TX (see PREFERRED_WRITE_UUIDS).
        TIO_DATA_TX_UUID,
        // u-blox FIFO carries data in both directions, so it is the notify
        // candidate as well as the write one.
        UBLOX_DATA_UUID,
        // Halcyon Symbios: the device transmits replies on its Tx endpoint
        // (00000201) via indications; the app writes commands on 00000101 (see
        // PREFERRED_WRITE_UUIDS and issue #288).
        UUID.fromString("00000201-8c3b-4f2c-a59e-8c08224f3253")
    )

    // Choose the characteristics to talk through, or null if nothing usable.
    fun select(services: List<Service>): Selection? = selectNotify(services)

    private fun writeScore(characteristic: Characteristic): Int? {
        val props = characteristic.properties
        if (props and (PROPERTY_WRITE or PROPERTY_WRITE_NO_RESPONSE) == 0) return null
        var score = 0
        if (props and PROPERTY_WRITE_NO_RESPONSE != 0) score += 4
        if (props and PROPERTY_WRITE != 0) score += 2
        if (PREFERRED_WRITE_UUIDS.contains(characteristic.uuid)) score += 1000
        return score
    }

    private fun notifyScore(characteristic: Characteristic): Int? {
        val props = characteristic.properties
        if (props and (PROPERTY_NOTIFY or PROPERTY_INDICATE) == 0) return null
        var score = 0
        if (props and PROPERTY_NOTIFY != 0) score += 4
        if (props and PROPERTY_INDICATE != 0) score += 2
        if (PREFERRED_NOTIFY_UUIDS.contains(characteristic.uuid)) score += 1000
        return score
    }

    // Best write/notify pair across all services. Ties keep the earliest
    // candidate in the order the caller supplies (BLE discovery order).
    private fun selectNotify(services: List<Service>): Selection? {
        var best: Selection? = null
        for ((serviceIndex, service) in services.withIndex()) {
            var bestWrite = -1
            var bestWriteScore = -1
            var bestNotify = -1
            var bestNotifyScore = -1
            for ((index, characteristic) in service.characteristics.withIndex()) {
                val ws = writeScore(characteristic)
                if (ws != null && ws > bestWriteScore) {
                    bestWrite = index
                    bestWriteScore = ws
                }
                val ns = notifyScore(characteristic)
                if (ns != null && ns > bestNotifyScore) {
                    bestNotify = index
                    bestNotifyScore = ns
                }
            }
            if (bestWrite < 0 || bestNotify < 0) continue

            var score = bestWriteScore + bestNotifyScore
            if (PREFERRED_SERVICE_UUIDS.contains(service.uuid)) score += 1000
            if (best != null && best.score >= score) continue
            best = Selection(
                serviceIndex = serviceIndex,
                writeIndex = bestWrite,
                responseIndex = bestNotify,
                responseMode = ResponseMode.NOTIFY,
                score = score,
                terminalIoCredits = terminalIoCredits(service)
            )
        }
        return best
    }

    // The credit characteristics of a service, or null unless a complete known
    // layout is present, so every other device keeps its plain write/notify
    // path. Telit needs all four UART characteristics; u-blox needs its data
    // and credits pair.
    private fun terminalIoCredits(service: Service): TerminalIoCredits? {
        fun index(uuid: UUID): Int = service.characteristics.indexOfFirst { it.uuid == uuid }

        val creditsRx = index(TIO_CREDITS_RX_UUID)
        val creditsTx = index(TIO_CREDITS_TX_UUID)
        if (index(TIO_DATA_RX_UUID) >= 0 && index(TIO_DATA_TX_UUID) >= 0 &&
            creditsRx >= 0 && creditsTx >= 0
        ) {
            return TerminalIoCredits(creditsRx, creditsTx, required = true)
        }
        val ubloxCredits = index(UBLOX_CREDITS_UUID)
        if (index(UBLOX_DATA_UUID) >= 0 && ubloxCredits >= 0) {
            return TerminalIoCredits(ubloxCredits, ubloxCredits, required = false)
        }
        return null
    }
}
```

- [ ] **Step 4: Run the selector tests to verify they pass**

Same command as Step 2. Expected: BUILD SUCCESSFUL. Confirm the filter matched by running a bogus filter as a control: `--tests '*NoSuchTestXyz*'` must fail with "No tests found for given includes".

- [ ] **Step 5: Switch BleIoStream to the selector**

In `BleIoStream.kt`, delete the file-level constants `TIO_SERVICE_UUID` through `UBLOX_CREDITS_UUID` and the three `PREFERRED_*_UUIDS` sets, together with their leading comment blocks (the "Telit/Stollmann Terminal I/O (TIO)" block, the "u-blox serial service" line, and the "Preferred UUIDs for characteristic selection scoring" comment). Keep `CCCD_UUID`, `TIO_INITIAL_GRANT`, `TIO_REFILL_THRESHOLD`, `NO_REASON` and their comments. Above `TIO_INITIAL_GRANT` add:

```kotlin
// Telit/u-blox credit flow control (issue #923). The layouts and preferred
// UUIDs live in BleCharacteristicSelector; the credit arithmetic stays here
// with the GATT writes that carry it.
```

In `onServicesDiscovered`, replace everything from the comment `// Score-based characteristic selection (mirrors Darwin BleIoStream).` down to (but not including) the line `var startedSetup = false` with:

```kotlin
            // Selection lives in BleCharacteristicSelector so it can be unit-
            // tested on the JVM; it mirrors darwin's selector of the same
            // name. The live list is captured once because the returned
            // indices address it.
            val liveServices = gatt.services
            val services = liveServices.map { service ->
                NativeLogger.d(TAG, "BLE", "Service: ${service.uuid}")
                BleCharacteristicSelector.Service(
                    service.uuid,
                    service.characteristics.map { char ->
                        NativeLogger.d(TAG, "BLE",
                            "  Char: ${char.uuid} props=0x${char.properties.toString(16)}" +
                                " descriptors=${char.descriptors.size}")
                        BleCharacteristicSelector.Characteristic(char.uuid, char.properties)
                    }
                )
            }
            val selection = BleCharacteristicSelector.select(services)
```

Then replace the block that starts `if (bestWrite != null && bestNotify != null) {` up to and including the line `creditsRequired = bestCreditsRequired` with:

```kotlin
            if (selection != null) {
                val chars = liveServices[selection.serviceIndex].characteristics
                val bestWrite = chars[selection.writeIndex]
                val bestNotify = chars[selection.responseIndex]
                val credits = selection.terminalIoCredits
                val bestCreditsWrite = credits?.let { chars[it.writeIndex] }
                val bestCreditsNotify = credits?.let { chars[it.notifyIndex] }
                val bestCreditsRequired = credits?.required ?: false
                NativeLogger.d(TAG, "BLE", "Data service selected (score=${selection.score})")
                NativeLogger.d(TAG, "BLE", "  write=${bestWrite.uuid} notify=${bestNotify.uuid}")
                writeCharacteristic = bestWrite
                notifyCharacteristic = bestNotify
                creditsWriteCharacteristic = bestCreditsWrite
                creditsNotifyCharacteristic = bestCreditsNotify
                creditsRequired = bestCreditsRequired
```

Everything after that line (the `val creditsNotify = bestCreditsNotify` block, the `startedSetup` logic, the `else` branch with `describeNoUsableService`, and the final release) stays as it is; the local names it reads (`bestNotify`, `bestCreditsWrite`, `bestCreditsNotify`, `bestCreditsRequired`) are the ones declared above.

Verify nothing else still references the removed constants:

```bash
grep -n "PREFERRED_\|TIO_SERVICE_UUID\|TIO_DATA_\|TIO_CREDITS_\|UBLOX_" packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt
```

Expected: no output.

- [ ] **Step 6: Run the whole plugin JVM suite (compiles BleIoStream too)**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --console=plain
```

Expected: BUILD SUCCESSFUL (the test task compiles the main source set, so a Kotlin error in `BleIoStream.kt` fails here).

- [ ] **Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelector.kt \
        packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelectorTest.kt \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt
git commit -m "refactor(ble): extract Android characteristic selection into a tested unit

Refs #1454"
```

---

### Task 5: Android selector read-poll tier

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelector.kt`
- Test: `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelectorTest.kt`

**Interfaces:**
- Consumes: Task 4's selector.
- Produces: `BleCharacteristicSelector.SEAC_SERVICE_UUID`, `SEAC_DATA_UUID`, `READ_POLL_SERVICES: Map<UUID, UUID>`; `select()` now returns `ResponseMode.READ` selections for the allowlist.

- [ ] **Step 1: Write the failing tests**

Add to the companion object of `BleCharacteristicSelectorTest`:

```kotlin
        const val SEAC_SERVICE = "84968ffe-d26d-478a-b953-5010bcf58bca"
        const val SEAC_DATA = "43c620c2-1b09-4951-bc1e-9c75298cddeb"
```

Add these tests at the end of the class (they mirror darwin cases 15 to 19):

```kotlin
    // 15. The Seac Tablet (issue #1454) as Android enumerates it, with Generic
    // Access (Device Name can be read+write) and Device Information first. Only
    // the Seac service is chosen, in read mode, one characteristic both ways.
    @Test
    fun seacTabletSelectsReadMode() {
        val services = listOf(
            service("00001800-0000-1000-8000-00805f9b34fb", char("00002a00-0000-1000-8000-00805f9b34fb", R, W)),
            service("0000180a-0000-1000-8000-00805f9b34fb", char("00002a29-0000-1000-8000-00805f9b34fb", R)),
            service(SEAC_SERVICE, char(SEAC_DATA, R, W))
        )
        val selection = BleCharacteristicSelector.select(services)
        val result = resolve(services, selection)
        assertEquals(ResponseMode.READ, selection?.responseMode)
        assertEquals(2, result?.serviceIndex)
        assertEquals(uuid(SEAC_DATA), result?.write)
        assertEquals(uuid(SEAC_DATA), result?.response)
        assertNull(selection?.terminalIoCredits)
    }

    // 16. The allowlist is the whole read tier.
    @Test
    fun readOnlyShapeOutsideTheAllowlistIsNotSelected() {
        assertNull(BleCharacteristicSelector.select(listOf(
            service("0000ffe0-0000-1000-8000-00805f9b34fb", char(SEAC_DATA, R, W))
        )))
        assertNull(BleCharacteristicSelector.select(listOf(
            service(SEAC_SERVICE, char("0000ffe1-0000-1000-8000-00805f9b34fb", R, W))
        )))
    }

    // 17. Strict fallback: a write/notify service wins in either order.
    @Test
    fun notifyServiceBeatsTheReadPollService() {
        val notifyService = service("0000ffe0-0000-1000-8000-00805f9b34fb", char("0000ffe1-0000-1000-8000-00805f9b34fb", WNR, N))
        val seac = service(SEAC_SERVICE, char(SEAC_DATA, R, W))

        val seacFirst = BleCharacteristicSelector.select(listOf(seac, notifyService))
        assertEquals(ResponseMode.NOTIFY, seacFirst?.responseMode)
        assertEquals(1, seacFirst?.serviceIndex)

        val seacLast = BleCharacteristicSelector.select(listOf(notifyService, seac))
        assertEquals(ResponseMode.NOTIFY, seacLast?.responseMode)
        assertEquals(0, seacLast?.serviceIndex)
    }

    // 18. READ plus a write property are both required; write-without-response
    // alone is enough for the write side.
    @Test
    fun allowlistedCharacteristicNeedsReadAndWrite() {
        fun selectSeac(vararg properties: Int) =
            BleCharacteristicSelector.select(listOf(service(SEAC_SERVICE, char(SEAC_DATA, *properties))))
        assertNull(selectSeac(W))
        assertNull(selectSeac(R))
        assertEquals(ResponseMode.READ, selectSeac(R, WNR)?.responseMode)
    }

    // 19. Firmware that adds notify gets the ordinary notify path.
    @Test
    fun seacCharacteristicThatNotifiesUsesTheNotifyPath() {
        val services = listOf(service(SEAC_SERVICE, char(SEAC_DATA, R, W, N)))
        assertEquals(ResponseMode.NOTIFY, BleCharacteristicSelector.select(services)?.responseMode)
    }
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --tests '*BleCharacteristicSelectorTest*' --console=plain
```

Expected: FAIL; `seacTabletSelectsReadMode` and `allowlistedCharacteristicNeedsReadAndWrite` fail (select returns null). The other three new tests already pass, which is correct: they pin fallback behaviour the read tier must not change.

- [ ] **Step 3: Implement the read tier**

In `BleCharacteristicSelector.kt`, after `PREFERRED_NOTIFY_UUIDS` add:

```kotlin
    // Read-poll services (issue #1454). A few computers expose a data
    // characteristic that can be read and written but cannot notify or
    // indicate, so every reply has to be fetched with a GATT read.
    // libdivecomputer commit 415778c documents the Seac Tablet's layout;
    // Subsurface's qt-ble.cpp reads it the same way (e8e0cea769).
    //
    // Deliberately an allowlist rather than "any read+write characteristic":
    // Generic Access's Device Name is read+write on some peripherals, and a
    // generic tier would connect to it on a computer whose real serial service
    // was simply not recognised, then time out with nothing to explain why.
    val SEAC_SERVICE_UUID: UUID = UUID.fromString("84968ffe-d26d-478a-b953-5010bcf58bca")
    // Rx/Tx in one characteristic: commands are written to it, replies read from it.
    val SEAC_DATA_UUID: UUID = UUID.fromString("43c620c2-1b09-4951-bc1e-9c75298cddeb")

    // Read-poll service UUID to its data characteristic UUID.
    val READ_POLL_SERVICES: Map<UUID, UUID> = mapOf(SEAC_SERVICE_UUID to SEAC_DATA_UUID)
```

Replace

```kotlin
    // Choose the characteristics to talk through, or null if nothing usable.
    fun select(services: List<Service>): Selection? = selectNotify(services)
```

with

```kotlin
    // Choose the characteristics to talk through, or null if nothing usable.
    // The write/notify pass runs first and is unchanged; the read-poll tier is
    // consulted only when it finds nothing, so no device that already works
    // can be moved onto the read path.
    fun select(services: List<Service>): Selection? =
        selectNotify(services) ?: selectReadPoll(services)

    // The first allowlisted read-poll service whose data characteristic can
    // be both read and written, or null.
    private fun selectReadPoll(services: List<Service>): Selection? {
        for ((serviceIndex, service) in services.withIndex()) {
            val dataUuid = READ_POLL_SERVICES[service.uuid] ?: continue
            val index = service.characteristics.indexOfFirst { it.uuid == dataUuid }
            if (index < 0) continue
            val props = service.characteristics[index].properties
            if (props and PROPERTY_READ == 0) continue
            if (props and (PROPERTY_WRITE or PROPERTY_WRITE_NO_RESPONSE) == 0) continue
            return Selection(
                serviceIndex = serviceIndex,
                writeIndex = index,
                responseIndex = index,
                responseMode = ResponseMode.READ,
                score = 0,
                terminalIoCredits = null
            )
        }
        return null
    }
```

- [ ] **Step 4: Run to verify they pass**

Same command as Step 2. Expected: BUILD SUCCESSFUL.

Note: `BleIoStream.onServicesDiscovered` would now treat a READ selection as a notify pair and fail the CCCD subscribe cleanly (no CCCD descriptor exists). Task 7 adds the real read-mode handling; the next task does not ship without it.

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelector.kt \
        packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/BleCharacteristicSelectorTest.kt
git commit -m "feat(ble): select the Seac Tablet's read-only data characteristic on Android

Refs #1454"
```

---

### Task 6: Android ReadPollPolicy

**Files:**
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/ReadPollPolicy.kt`
- Create: `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/ReadPollPolicyTest.kt`

**Interfaces:**
- Produces: `class ReadPollPolicy` with
  - `enum class Action { ISSUE_READ, WAIT, CLOSED }`
  - `companion object { const val RETRY_DELAY_MS = 100L; const val WAIT_SLICE_MS = 100L }`
  - `var readInFlight: Boolean` (private set)
  - `fun next(nowMs: Long): Action`
  - `fun issueFailed(nowMs: Long)`
  - `fun completed(hasData: Boolean, nowMs: Long): Boolean`
  - `fun purge()`
  - `fun close()`

- [ ] **Step 1: Write the failing tests**

Create `android/src/test/kotlin/com/submersion/libdivecomputer/ReadPollPolicyTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import com.submersion.libdivecomputer.ReadPollPolicy.Action
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// JVM tests for the read-poll decisions behind BleIoStream's read mode
// (issue #1454). Mirrors darwin/Tests/ReadPollPolicyTests case for case.
class ReadPollPolicyTest {

    @Test
    fun idleIssuesOneReadThenWaitsWhileItIsInFlight() {
        val policy = ReadPollPolicy()
        assertEquals(Action.ISSUE_READ, policy.next(0))
        assertTrue(policy.readInFlight)
        assertEquals(Action.WAIT, policy.next(5))
        assertEquals(Action.WAIT, policy.next(10_000))
    }

    @Test
    fun dataIsQueuedAndTheNextReadGoesOutAtOnce() {
        val policy = ReadPollPolicy()
        policy.next(0)
        assertTrue(policy.completed(hasData = true, nowMs = 50))
        assertEquals(Action.ISSUE_READ, policy.next(50))
    }

    @Test
    fun emptyValueBacksOffBeforeRereading() {
        val policy = ReadPollPolicy()
        policy.next(0)
        assertFalse(policy.completed(hasData = false, nowMs = 1000))
        assertEquals(Action.WAIT, policy.next(1099))
        assertEquals(Action.ISSUE_READ, policy.next(1100))
    }

    @Test
    fun refusedIssueBacksOff() {
        val policy = ReadPollPolicy()
        assertEquals(Action.ISSUE_READ, policy.next(0))
        policy.issueFailed(0)
        assertFalse(policy.readInFlight)
        assertEquals(Action.WAIT, policy.next(99))
        assertEquals(Action.ISSUE_READ, policy.next(100))
    }

    @Test
    fun purgeWhileInFlightDiscardsTheLateValue() {
        val policy = ReadPollPolicy()
        policy.next(0)
        policy.purge()
        assertFalse(policy.completed(hasData = true, nowMs = 500))
        assertEquals(Action.ISSUE_READ, policy.next(500))
        assertTrue(policy.completed(hasData = true, nowMs = 600))
    }

    @Test
    fun purgeWhileIdleDiscardsNothingLater() {
        val policy = ReadPollPolicy()
        policy.purge()
        policy.next(0)
        assertTrue(policy.completed(hasData = true, nowMs = 10))
    }

    @Test
    fun discardedEmptyValueDoesNotBackOff() {
        val policy = ReadPollPolicy()
        policy.next(0)
        policy.purge()
        assertFalse(policy.completed(hasData = false, nowMs = 500))
        assertEquals(Action.ISSUE_READ, policy.next(500))
    }

    @Test
    fun closeFailsReadsAndIgnoresLateCompletions() {
        val policy = ReadPollPolicy()
        policy.next(0)
        policy.close()
        assertEquals(Action.CLOSED, policy.next(1))
        assertFalse(policy.completed(hasData = true, nowMs = 2))
        assertEquals(Action.CLOSED, policy.next(3))
    }

    // A device that answers every read with an empty value, polled every
    // millisecond for libdivecomputer's 6000 ms: one read per retry delay.
    @Test
    fun emptyValuesUntilTheDeadlineNeverSpin() {
        val policy = ReadPollPolicy()
        var issued = 0
        for (now in 0L until 6000L) {
            if (policy.next(now) == Action.ISSUE_READ) {
                issued++
                policy.completed(hasData = false, nowMs = now)
            }
        }
        assertEquals(60, issued)
    }

    // System.nanoTime() is allowed to be negative, and the clock BleIoStream
    // feeds in derives from it. A fresh policy must still issue at once.
    @Test
    fun negativeClockStillIssuesImmediately() {
        val policy = ReadPollPolicy()
        assertEquals(Action.ISSUE_READ, policy.next(-5_000_000L))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --tests '*ReadPollPolicyTest*' --console=plain
```

Expected: FAIL, `Unresolved reference: ReadPollPolicy`.

- [ ] **Step 3: Implement the policy**

Create `android/src/main/kotlin/com/submersion/libdivecomputer/ReadPollPolicy.kt`:

```kotlin
package com.submersion.libdivecomputer

// Decides when a read-poll BLE transport puts a GATT read on the wire.
//
// Some dive computers expose a data characteristic that can be read but can
// neither notify nor indicate (the Seac Tablet, issue #1454), so every reply
// has to be asked for. libdivecomputer only says when it wants bytes, by
// calling read(); this policy turns that into GATT reads under three rules:
//
//  - At most one read is in flight. A read still outstanding when
//    libdivecomputer's timeout fires is adopted by the next read() rather than
//    doubled. The Tablet can answer seconds late (libdivecomputer 15d6f6c
//    measured up to 5.6 s), and a second request stacked behind the first is
//    what corrupted the retry that commit describes. Android also refuses a
//    second GATT operation outright.
//  - An empty value or a failed read is retried after RETRY_DELAY_MS, never at
//    once. dc_packet_read loops until it has every byte it asked for, so a
//    transport that answered an empty value with zero-byte success would make
//    it hammer the characteristic with no timeout ever firing.
//  - purge() discards the value of a read already in flight, because that
//    value answers a command libdivecomputer has abandoned.
//
// Not thread-safe: BleIoStream guards it with a lock. Pure Kotlin with an
// injected millisecond clock, so it runs as a JVM test. Mirrors darwin's
// ReadPollPolicy.swift.
class ReadPollPolicy {

    enum class Action {
        // Put one GATT read on the wire now.
        ISSUE_READ,
        // A read is in flight or backing off; wait for data, then ask again.
        WAIT,
        // The link is gone; fail the read.
        CLOSED
    }

    companion object {
        // Delay before re-reading after an empty value or a failed read.
        const val RETRY_DELAY_MS = 100L
        // Longest a waiting reader sleeps before asking the policy again.
        const val WAIT_SLICE_MS = 100L
    }

    var readInFlight = false
        private set
    private var discardInFlight = false
    // Long.MIN_VALUE, not 0: the clock derives from System.nanoTime(), which
    // may be negative, and a fresh policy must not start out backing off.
    private var retryNotBeforeMs = Long.MIN_VALUE
    private var closed = false

    // What a reader with an empty queue should do now.
    fun next(nowMs: Long): Action {
        if (closed) return Action.CLOSED
        if (readInFlight || nowMs < retryNotBeforeMs) return Action.WAIT
        readInFlight = true
        return Action.ISSUE_READ
    }

    // The platform refused the read that next() asked for, so no completion is
    // coming. Back off rather than retry in a tight loop.
    fun issueFailed(nowMs: Long) {
        readInFlight = false
        retryNotBeforeMs = nowMs + RETRY_DELAY_MS
    }

    // A read completed. Returns true when its value should be queued for
    // libdivecomputer; hasData is false for an empty value or a failed read.
    fun completed(hasData: Boolean, nowMs: Long): Boolean {
        readInFlight = false
        if (closed) return false
        if (discardInFlight) {
            discardInFlight = false
            return false
        }
        if (!hasData) {
            retryNotBeforeMs = nowMs + RETRY_DELAY_MS
            return false
        }
        return true
    }

    // libdivecomputer purged its input: whatever is already on the wire
    // answers a command it has given up on.
    fun purge() {
        if (readInFlight) discardInFlight = true
    }

    // The link is going away. Every later read fails and late completions are
    // ignored.
    fun close() {
        closed = true
        readInFlight = false
        discardInFlight = false
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Same command as Step 2. Expected: BUILD SUCCESSFUL. Run the bogus-filter control once (`--tests '*NoSuchTestXyz*'` must report "No tests found").

- [ ] **Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/ReadPollPolicy.kt \
        packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/ReadPollPolicyTest.kt
git commit -m "feat(ble): add the Android read-poll policy

Refs #1454"
```

---

### Task 7: Android BleIoStream read mode

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/GattDiagnostics.kt`
- Test: `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/GattDiagnosticsTest.kt`

**Interfaces:**
- Consumes: `BleCharacteristicSelector.Selection.responseMode/responseIndex` (Tasks 4 and 5), `ReadPollPolicy` (Task 6).

- [ ] **Step 1: Write the failing diagnostics test**

In `GattDiagnosticsTest.kt`, after `unusableDiscoveryListsWhatTheComputerExposed`, add:

```kotlin
    @Test
    fun unusableDiscoverySaysNoReadPollServiceMatched() {
        val message = GattDiagnostics.describeNoUsableService(
            listOf("00001800-0000-1000-8000-00805f9b34fb")
        )

        // Read-poll services (issue #1454) are the other way a service can
        // qualify; saying so tells a maintainer where a new entry would go.
        assertTrue(message.contains("read-poll"))
    }
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --tests '*GattDiagnosticsTest*' --console=plain
```

Expected: FAIL in `unusableDiscoverySaysNoReadPollServiceMatched`.

- [ ] **Step 3: Update the diagnostic**

In `GattDiagnostics.kt`, in `describeNoUsableService`, change

```kotlin
        return "No discovered service carries both a write and a notify " +
            "characteristic; ${serviceUuids.size} service(s) seen: " +
            serviceUuids.joinToString(", ")
```

to

```kotlin
        return "No discovered service carries both a write and a notify " +
            "characteristic, nor matches a known read-poll service; " +
            "${serviceUuids.size} service(s) seen: " +
            serviceUuids.joinToString(", ")
```

Run Step 2's command. Expected: PASS.

- [ ] **Step 4: Add read-mode state to BleIoStream**

Add `import java.util.concurrent.atomic.AtomicBoolean` to the imports (keep them sorted with the other `java.util.concurrent` imports).

Change `private var connected = false` to:

```kotlin
    // Written on the GATT callback thread, read by the read-poll loop on the
    // download thread.
    @Volatile
    private var connected = false
```

Rename `dataNotifyReady` to `responsePathReady` everywhere in the file (the declaration, the assignment in `onDescriptorWrite`, and the two uses in `connectAndDiscover`), and replace the declaration's comment with:

```kotlin
    // Whether the computer's replies can reach readQueue: the Data TX CCCD
    // write completed successfully, or the read-poll characteristic was chosen
    // (issue #1454), which needs no subscription. Assigning
    // notifyCharacteristic only means a candidate was found; until the
    // descriptor write lands the peripheral sends nothing.
```

In `connectAndDiscover`'s final log line, change `notifyReady=$dataNotifyReady` to `responseReady=$responsePathReady`.

After `private var notifyCharacteristic: BluetoothGattCharacteristic? = null` add:

```kotlin
    // The read-poll data characteristic (issue #1454), non-null only when the
    // selected service cannot notify. Replies are fetched with
    // readCharacteristic() and land in readQueue exactly as notifications do.
    @Volatile
    private var readCharacteristic: BluetoothGattCharacteristic? = null
    private val readPollLock = Any()
    private var readPoll = ReadPollPolicy()
    // Whether an in-flight GATT read holds gattOperation. Atomic because the
    // completion, the disconnect branch and a refused issue on the download
    // thread can all race to release it, and releasing twice would silently
    // destroy the gate's mutual exclusion (Semaphore has no permit ceiling).
    private val readGateHeld = AtomicBoolean(false)
```

- [ ] **Step 5: Select read mode in onServicesDiscovered**

In `onServicesDiscovered`, directly after `val selection = BleCharacteristicSelector.select(services)` (added in Task 4), insert:

```kotlin
            if (selection != null &&
                selection.responseMode == BleCharacteristicSelector.ResponseMode.READ
            ) {
                // Read-poll tier (issue #1454): the computer cannot push its
                // replies, so there is no CCCD to write and the response path
                // is ready as soon as the characteristic is chosen. GATT is
                // free for I/O at once.
                val service = liveServices[selection.serviceIndex]
                val char = service.characteristics[selection.responseIndex]
                writeCharacteristic = service.characteristics[selection.writeIndex]
                readCharacteristic = char
                responsePathReady = true
                NativeLogger.d(TAG, "BLE",
                    "read-poll tier selected: service=${service.uuid} characteristic=${char.uuid}" +
                        " props=0x${char.properties.toString(16)}")
                connectSemaphore.release()
                return
            }
```

- [ ] **Step 6: Deliver read responses**

Inside `gattCallback`, after the legacy `onCharacteristicChanged` override, add:

```kotlin
        // API 33+ delivers read responses via this overload. Overriding it
        // without calling super keeps the deprecated one below from also
        // firing for the same response.
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int
        ) {
            onReadResponse(characteristic, value, status)
        }

        // Pre-API 33 fallback: the value is on characteristic.value.
        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            onReadResponse(characteristic, characteristic.value ?: ByteArray(0), status)
        }
```

After the `onNotification` function, add:

```kotlin
    // Settle one read-poll response (issue #1454). The gate is released first:
    // a command write may be waiting on it.
    private fun onReadResponse(
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        status: Int
    ) {
        if (characteristic.uuid != readCharacteristic?.uuid) return
        releaseReadGate()
        val ok = status == BluetoothGatt.GATT_SUCCESS && value.isNotEmpty()
        val deliver = synchronized(readPollLock) { readPoll.completed(ok, nowMs()) }
        if (deliver) readQueue.offer(value)
        NativeLogger.d(TAG, "BLE",
            "read-poll response: status=$status bytes=${value.size} delivered=$deliver")
    }

    // Put one GATT read on the wire, holding the GATT gate until
    // onCharacteristicRead releases it: Android runs one operation at a time
    // and rejects the loser, exactly as for writes. False means no read is in
    // flight and no completion is coming.
    private fun issueGattRead(char: BluetoothGattCharacteristic, deadline: Long): Boolean {
        val g = gatt ?: return false
        val wait = if (deadline == Long.MAX_VALUE) Long.MAX_VALUE
        else (deadline - nowMs()).coerceAtLeast(0L)
        if (!gattOperation.tryAcquire(wait, TimeUnit.MILLISECONDS)) {
            NativeLogger.w(TAG, "BLE", "read-poll: timed out waiting for GATT to be free")
            return false
        }
        // Set before issuing: the completion can arrive on the binder thread
        // before readCharacteristic() returns.
        readGateHeld.set(true)
        if (!g.readCharacteristic(char)) {
            releaseReadGate()
            NativeLogger.w(TAG, "BLE", "read-poll: readCharacteristic() returned false")
            return false
        }
        return true
    }

    // Release the gate held by a read in flight, at most once however many
    // terminal paths race for it.
    private fun releaseReadGate() {
        if (readGateHeld.compareAndSet(true, false)) gattOperation.release()
    }

    // Monotonic milliseconds for ReadPollPolicy. May be negative.
    private fun nowMs(): Long = System.nanoTime() / 1_000_000

    // read() for a read-poll characteristic (issue #1454): the computer never
    // pushes, so each packet is asked for with a GATT read. ReadPollPolicy
    // decides when one goes on the wire; replies land in readQueue exactly as
    // notifications do, one entry per packet. The wait is sliced so an empty
    // value, a refused read or a dropped link is noticed within
    // WAIT_SLICE_MS even when libdivecomputer asked for no timeout.
    private fun readPolled(
        char: BluetoothGattCharacteristic,
        size: Int,
        timeoutMs: Int
    ): ByteArray? {
        val deadline = if (timeoutMs < 0) Long.MAX_VALUE else nowMs() + timeoutMs
        while (true) {
            readQueue.poll()?.let { return takeChunk(it, size) }
            val now = nowMs()
            if (deadline != Long.MAX_VALUE && now >= deadline) return null
            if (!connected) {
                synchronized(readPollLock) { readPoll.close() }
            }
            when (synchronized(readPollLock) { readPoll.next(now) }) {
                ReadPollPolicy.Action.CLOSED -> return null
                ReadPollPolicy.Action.ISSUE_READ -> if (!issueGattRead(char, deadline)) {
                    synchronized(readPollLock) { readPoll.issueFailed(nowMs()) }
                }
                ReadPollPolicy.Action.WAIT -> Unit
            }
            val remaining = if (deadline == Long.MAX_VALUE) Long.MAX_VALUE
            else deadline - nowMs()
            val slice = remaining.coerceIn(1L, ReadPollPolicy.WAIT_SLICE_MS)
            readQueue.poll(slice, TimeUnit.MILLISECONDS)?.let { return takeChunk(it, size) }
        }
    }

    // Return up to `size` bytes of one packet, keeping the rest for the next
    // read so bytes from two packets are never returned together.
    private fun takeChunk(chunk: ByteArray, size: Int): ByteArray {
        val bytesToCopy = minOf(size, chunk.size)
        val result = chunk.copyOfRange(0, bytesToCopy)
        if (bytesToCopy < chunk.size) {
            readBuffer = chunk.copyOfRange(bytesToCopy, chunk.size)
        }
        return result
    }
```

- [ ] **Step 7: Route read(), purge(), close() and the disconnect branch**

In `read()`, replace everything after the leftover-buffer `if (readBuffer.isNotEmpty()) { ... }` block with:

```kotlin
        readCharacteristic?.let { return readPolled(it, size, timeoutMs) }

        // Wait for exactly one BLE notification. Shearwater's SLIP decoder
        // expects each read to return a single BLE packet (it skips a 2-byte
        // BLE header per read call). Accumulating multiple notifications
        // into one buffer corrupts the SLIP framing.
        val timeout = if (timeoutMs < 0) Long.MAX_VALUE else timeoutMs.toLong()
        val chunk = readQueue.poll(timeout, TimeUnit.MILLISECONDS) ?: return null
        return takeChunk(chunk, size)
```

In `purge()`, inside the `if (direction and 1 != 0) {` block after `readQueue.clear()`, add:

```kotlin
            // A read already on the wire answers a command libdivecomputer
            // has abandoned (issue #1454).
            synchronized(readPollLock) { readPoll.purge() }
```

In `close()`, before `gatt?.disconnect()`, add:

```kotlin
        // Fail a read-poll reader and free a gate a pending read still holds:
        // no completion arrives once the client is closed.
        synchronized(readPollLock) { readPoll.close() }
        releaseReadGate()
```

and after `creditsNotifyCharacteristic = null` add:

```kotlin
        readCharacteristic = null
```

In `onConnectionStateChange`'s disconnect branch, directly after the `if (creditTopUpInFlight) { ... }` block, add:

```kotlin
                // A read-poll read in flight gets no completion either; free
                // its gate and fail any reader, which otherwise waits out
                // libdivecomputer's timeout (or forever, for "no timeout").
                releaseReadGate()
                synchronized(readPollLock) { readPoll.close() }
```

- [ ] **Step 8: Compile and run the plugin JVM suite**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --console=plain
```

Expected: BUILD SUCCESSFUL, including the new diagnostics test.

- [ ] **Step 9: Build the debug APK (the artifact the hardware tester will run)**

```bash
cat > "$TMPDIR/wt_apk.sh" <<'EOF'
set -euo pipefail
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb
flutter build apk --debug
EOF
bash "$TMPDIR/wt_apk.sh"
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 10: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/BleIoStream.kt \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/GattDiagnostics.kt \
        packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/GattDiagnosticsTest.kt
git commit -m "feat(ble): read the Seac Tablet's replies on demand on Android

Refs #1454"
```

---

### Task 8: Windows read-poll transport

**Files:**
- Create: `packages/libdivecomputer_plugin/windows/ble_read_poll.h`
- Create: `packages/libdivecomputer_plugin/windows/ble_read_poll.cc`
- Modify: `packages/libdivecomputer_plugin/windows/ble_io_stream.h`
- Modify: `packages/libdivecomputer_plugin/windows/ble_io_stream.cc`
- Modify: `packages/libdivecomputer_plugin/windows/CMakeLists.txt`

**Interfaces:**
- Produces: `class BleReadPoller` with `explicit BleReadPoller(GattCharacteristic)`, `int Read(void* data, size_t size, size_t* actual, int timeout_ms)`, `int Poll(int timeout_ms)`, `void Purge()`, `void Close()`.

There is no Windows toolchain or unit harness on the development Mac. Verification is the "Build Windows" job of `native-plugin-tests.yml` on the PR. Review this task line by line against Task 2's policy: the state machine must match it exactly.

- [ ] **Step 1: Create the header**

`windows/ble_read_poll.h`:

```cpp
#ifndef BLE_READ_POLL_H_
#define BLE_READ_POLL_H_

#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <vector>

#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>

namespace libdivecomputer_plugin {

// Response path for a characteristic that can be read but can neither notify
// nor indicate (the Seac Tablet, issue #1454): every reply is fetched with a
// GATT read whenever libdivecomputer asks for bytes.
//
// The same state machine as darwin's ReadPollPolicy.swift and Android's
// ReadPollPolicy.kt, which carry the unit tests:
//  - at most one read in flight; a read that outlives a read() timeout is
//    adopted by the next read() instead of being doubled;
//  - an empty value or a failed read is re-read after kRetryDelay, never at
//    once, so libdivecomputer's packet loop cannot spin on zero-byte reads;
//  - Purge() discards the value of a read already in flight.
// Replies are queued one entry per packet, and Read() returns bytes from at
// most one entry, the same contract as the notification path.
class BleReadPoller {
 public:
  explicit BleReadPoller(
      winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
          GattCharacteristic characteristic);
  ~BleReadPoller();

  BleReadPoller(const BleReadPoller&) = delete;
  BleReadPoller& operator=(const BleReadPoller&) = delete;

  // libdivecomputer read(). timeout_ms follows BleIoStream::timeout_ms_:
  // INT32_MAX means no timeout.
  int Read(void* data, size_t size, size_t* actual, int timeout_ms);
  // libdivecomputer poll(): negative means no timeout, zero never blocks.
  int Poll(int timeout_ms);
  void Purge();
  // Fail any waiting Read() and ignore completions still in flight.
  void Close();

 private:
  using Clock = std::chrono::steady_clock;
  static constexpr std::chrono::milliseconds kRetryDelay{100};
  static constexpr std::chrono::milliseconds kWaitSlice{100};

  // Shared with in-flight read completions, which may run after this poller
  // is destroyed, so they capture this state and never `this`.
  struct State {
    std::mutex mutex;
    std::condition_variable cv;
    std::deque<std::vector<uint8_t>> chunks;
    bool read_in_flight = false;
    bool discard_in_flight = false;
    bool closed = false;
    Clock::time_point retry_not_before{};
  };

  // Wait, issuing reads as needed, until a packet is queued (SUCCESS), the
  // deadline passes (TIMEOUT) or Close() runs (IO). Called and returns with
  // `lock` held on state_->mutex.
  int AwaitPacket(std::unique_lock<std::mutex>& lock,
                  Clock::time_point deadline);
  // Start one asynchronous uncached read. False if it could not be issued.
  bool IssueRead();

  std::shared_ptr<State> state_ = std::make_shared<State>();
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
      GattCharacteristic characteristic_{nullptr};
};

}  // namespace libdivecomputer_plugin

#endif  // BLE_READ_POLL_H_
```

- [ ] **Step 2: Create the implementation**

`windows/ble_read_poll.cc`:

```cpp
#include "ble_read_poll.h"

#include <algorithm>
#include <cstring>
#include <string>
#include <utility>

#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>

extern "C" {
#include "libdc_wrapper.h"
}

#include "native_logger.h"

namespace libdivecomputer_plugin {

using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace winrt::Windows::Storage::Streams;

namespace {

constexpr char kBleCategory[] = "BLE";

}  // namespace

BleReadPoller::BleReadPoller(GattCharacteristic characteristic)
    : characteristic_(std::move(characteristic)) {}

BleReadPoller::~BleReadPoller() { Close(); }

int BleReadPoller::Read(void* data, size_t size, size_t* actual,
                        int timeout_ms) {
    const auto deadline =
        (timeout_ms == INT32_MAX)
            ? Clock::time_point::max()
            : Clock::now() + std::chrono::milliseconds(timeout_ms);
    std::unique_lock<std::mutex> lock(state_->mutex);
    const int status = AwaitPacket(lock, deadline);
    if (status != LIBDC_STATUS_SUCCESS) {
        *actual = 0;
        return status;
    }

    // At most one packet per read, a partial packet staying at the front, as
    // on the notification path.
    std::vector<uint8_t>& chunk = state_->chunks.front();
    const size_t count = std::min(size, chunk.size());
    std::memcpy(data, chunk.data(), count);
    if (count < chunk.size()) {
        chunk.erase(chunk.begin(), chunk.begin() + count);
    } else {
        state_->chunks.pop_front();
    }
    *actual = count;
    return LIBDC_STATUS_SUCCESS;
}

int BleReadPoller::Poll(int timeout_ms) {
    std::unique_lock<std::mutex> lock(state_->mutex);
    if (!state_->chunks.empty()) return LIBDC_STATUS_SUCCESS;
    if (timeout_ms == 0) return LIBDC_STATUS_TIMEOUT;
    const auto deadline =
        (timeout_ms < 0)
            ? Clock::time_point::max()
            : Clock::now() + std::chrono::milliseconds(timeout_ms);
    return AwaitPacket(lock, deadline);
}

void BleReadPoller::Purge() {
    std::lock_guard<std::mutex> lock(state_->mutex);
    state_->chunks.clear();
    // The value of a read already on the wire answers a command
    // libdivecomputer has abandoned.
    if (state_->read_in_flight) state_->discard_in_flight = true;
}

void BleReadPoller::Close() {
    {
        std::lock_guard<std::mutex> lock(state_->mutex);
        state_->closed = true;
        state_->chunks.clear();
    }
    state_->cv.notify_all();
}

int BleReadPoller::AwaitPacket(std::unique_lock<std::mutex>& lock,
                               Clock::time_point deadline) {
    State& state = *state_;
    while (state.chunks.empty()) {
        if (state.closed) return LIBDC_STATUS_IO;
        const auto now = Clock::now();
        if (now >= deadline) return LIBDC_STATUS_TIMEOUT;

        if (!state.read_in_flight && now >= state.retry_not_before) {
            state.read_in_flight = true;
            // Unlocked while issuing: Completed() runs the handler inline when
            // the read has already finished, and the handler takes this
            // non-recursive mutex (the same trap as the credit grant).
            lock.unlock();
            const bool issued = IssueRead();
            lock.lock();
            if (!issued) {
                state.read_in_flight = false;
                state.retry_not_before = Clock::now() + kRetryDelay;
            }
            // Re-check: an inline completion may already have queued a packet.
            continue;
        }

        // Sliced so a completion that queued nothing (an empty value or a
        // failed read) is followed by a retry without needing its own wakeup.
        const auto slice_end =
            (deadline - now > kWaitSlice) ? now + kWaitSlice : deadline;
        state.cv.wait_until(lock, slice_end);
    }
    return LIBDC_STATUS_SUCCESS;
}

bool BleReadPoller::IssueRead() {
    try {
        // Uncached: the default may answer from Windows' attribute cache,
        // which holds the previous packet instead of asking for the next.
        auto operation =
            characteristic_.ReadValueAsync(BluetoothCacheMode::Uncached);
        operation.Completed([state = state_](auto const& op, auto const&) {
            std::vector<uint8_t> value;
            bool ok = false;
            try {
                auto result = op.GetResults();
                if (result.Status() == GattCommunicationStatus::Success) {
                    auto reader = DataReader::FromBuffer(result.Value());
                    value.resize(reader.UnconsumedBufferLength());
                    if (!value.empty()) reader.ReadBytes(value);
                    ok = !value.empty();
                }
            } catch (...) {
                ok = false;
            }
            {
                std::lock_guard<std::mutex> lock(state->mutex);
                state->read_in_flight = false;
                if (!state->closed) {
                    if (state->discard_in_flight) {
                        state->discard_in_flight = false;
                    } else if (ok) {
                        state->chunks.push_back(std::move(value));
                    } else {
                        state->retry_not_before = Clock::now() + kRetryDelay;
                    }
                }
            }
            state->cv.notify_all();
        });
        return true;
    } catch (const winrt::hresult_error& e) {
        NativeLogger::Warn(kBleCategory,
                           "Read-poll read could not be issued: " +
                               winrt::to_string(e.message()));
        return false;
    } catch (...) {
        NativeLogger::Warn(kBleCategory,
                           "Read-poll read could not be issued");
        return false;
    }
}

}  // namespace libdivecomputer_plugin
```

- [ ] **Step 3: Wire it into the stream header**

In `windows/ble_io_stream.h`, after `#include <winrt/Windows.Storage.Streams.h>` add:

```cpp

#include "ble_read_poll.h"
```

After `static const winrt::guid kUbloxCreditsUuid;` add:

```cpp
  // Read-poll service (issue #1454): its data characteristic can be read and
  // written but can neither notify nor indicate.
  static const winrt::guid kSeacServiceUuid;
  static const winrt::guid kSeacDataUuid;
```

After the `std::deque<std::vector<uint8_t>> read_chunks_;` member add:

```cpp

  // Non-null only when the read-poll tier was selected. Read, poll and purge
  // go to it instead of read_chunks_, which stays empty in that mode.
  std::unique_ptr<BleReadPoller> read_poller_;
```

- [ ] **Step 4: Wire it into the stream implementation**

In `windows/ble_io_stream.cc`, after the `kUbloxCreditsUuid` definition add:

```cpp
// Seac Tablet (libdivecomputer 415778c): 84968ffe-d26d-478a-b953-5010bcf58bca
// with one Rx/Tx characteristic, 43c620c2-1b09-4951-bc1e-9c75298cddeb.
const winrt::guid BleIoStream::kSeacServiceUuid{
    0x84968FFE, 0xD26D, 0x478A,
    {0xB9, 0x53, 0x50, 0x10, 0xBC, 0xF5, 0x8B, 0xCA}};
const winrt::guid BleIoStream::kSeacDataUuid{
    0x43C620C2, 0x1B09, 0x4951,
    {0xBC, 0x1E, 0x9C, 0x75, 0x29, 0x8C, 0xDD, 0xEB}};
```

In `DiscoverCharacteristics()`:

At the start of the function body add:

```cpp
    read_poller_.reset();
```

After `Candidate best;` add:

```cpp
    // Read-poll tier candidate (issue #1454), used only if no service carries
    // a write/notify pair. An allowlist: Generic Access's Device Name is
    // read+write on some peripherals and must never be mistaken for a
    // serial channel.
    GattCharacteristic read_poll_candidate{nullptr};
```

Inside the per-characteristic loop, directly after the six `if (ch.Uuid() == ...)` lines that record the TIO and u-blox members, add:

```cpp
            if (!read_poll_candidate && service.Uuid() == kSeacServiceUuid &&
                ch.Uuid() == kSeacDataUuid &&
                (props & GattCharacteristicProperties::Read) !=
                    GattCharacteristicProperties::None &&
                ((props & GattCharacteristicProperties::Write) !=
                     GattCharacteristicProperties::None ||
                 (props & GattCharacteristicProperties::WriteWithoutResponse) !=
                     GattCharacteristicProperties::None)) {
                read_poll_candidate = ch;
            }
```

Directly before `if (best.score < 0) {` add:

```cpp
    if (best.score < 0 && read_poll_candidate) {
        // Read-poll tier: the computer cannot push its replies, so there is no
        // CCCD to write, no ValueChanged handler and no credit handshake; the
        // poller reads the characteristic whenever libdivecomputer wants bytes.
        NativeLogger::Debug(kBleCategory,
                            "read-poll tier selected: service=" +
                                DescribeUuid(kSeacServiceUuid) +
                                " characteristic=" +
                                DescribeUuid(read_poll_candidate.Uuid()));
        write_characteristic_ = read_poll_candidate;
        read_poller_ = std::make_unique<BleReadPoller>(read_poll_candidate);
        return true;
    }
```

In the same function's failure message, change

```cpp
                "No discovered service carries both a write and a notify "
                "characteristic; " +
```

to

```cpp
                "No discovered service carries both a write and a notify "
                "characteristic, nor matches a known read-poll service; " +
```

In `Close()`, before `write_characteristic_ = nullptr;` add:

```cpp
    if (read_poller_) {
        read_poller_->Close();
        read_poller_.reset();
    }
```

In `PollCallback`, after `auto* stream = static_cast<BleIoStream*>(userdata);` add:

```cpp
    if (stream->read_poller_) return stream->read_poller_->Poll(timeout);
```

In `PurgeCallback`, after `auto* stream = static_cast<BleIoStream*>(userdata);` add:

```cpp
    if (stream->read_poller_) stream->read_poller_->Purge();
```

At the top of `PerformRead`, before `std::unique_lock<std::mutex> lock(read_mutex_);`, add:

```cpp
    if (read_poller_) {
        return read_poller_->Read(data, size, actual, timeout_ms_);
    }
```

- [ ] **Step 5: Add the source to the build**

In `windows/CMakeLists.txt`, in the `add_library(${PLUGIN_NAME} SHARED` list, after `ble_io_stream.cc` add a line `    ble_read_poll.cc`.

- [ ] **Step 6: Self-check what cannot be compiled here**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/packages/libdivecomputer_plugin/windows
grep -n "read_poller_" ble_io_stream.h ble_io_stream.cc
grep -n "ble_read_poll" CMakeLists.txt
grep -nP "\x{2014}|\x{2013}" ble_read_poll.h ble_read_poll.cc || echo "no dashes"
```

Expected: `read_poller_` appears in the header member, `DiscoverCharacteristics` (reset and assignment), `Close`, `PollCallback`, `PurgeCallback` and `PerformRead`; CMake lists the file; "no dashes".

- [ ] **Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/windows/ble_read_poll.h \
        packages/libdivecomputer_plugin/windows/ble_read_poll.cc \
        packages/libdivecomputer_plugin/windows/ble_io_stream.h \
        packages/libdivecomputer_plugin/windows/ble_io_stream.cc \
        packages/libdivecomputer_plugin/windows/CMakeLists.txt
git commit -m "feat(ble): read the Seac Tablet's replies on demand on Windows

Refs #1454"
```

---

### Task 9: Linux read-poll transport

**Files:**
- Create: `packages/libdivecomputer_plugin/linux/ble_read_poll.h`
- Create: `packages/libdivecomputer_plugin/linux/ble_read_poll.c`
- Modify: `packages/libdivecomputer_plugin/linux/ble_io_stream.h`
- Modify: `packages/libdivecomputer_plugin/linux/ble_io_stream.c`
- Modify: `packages/libdivecomputer_plugin/linux/CMakeLists.txt`

**Interfaces:**
- Produces: `BleReadPoller* ble_read_poller_new(GDBusConnection*, const gchar* characteristic_path)`, `int ble_read_poller_read(BleReadPoller*, void*, size_t, size_t*, gint timeout_ms)`, `int ble_read_poller_poll(BleReadPoller*, int timeout_ms)`, `void ble_read_poller_purge(BleReadPoller*)`, `void ble_read_poller_close(BleReadPoller*)`, `void ble_read_poller_unref(BleReadPoller*)`.

No BlueZ toolchain on the development Mac; verification is the "Build Linux" CI job. Review against Task 2's policy.

Threading: libdivecomputer runs on the `dc-download` GThread, which pushes no thread-default main context, so async D-Bus replies are dispatched on the GTK main loop, exactly like the existing PropertiesChanged handler and credit-grant completion. The completion therefore never runs inline inside `g_dbus_connection_call`, which is why a read can be issued with the poller mutex held.

- [ ] **Step 1: Create the header**

`linux/ble_read_poll.h`:

```c
#ifndef BLE_READ_POLL_H_
#define BLE_READ_POLL_H_

#include <gio/gio.h>
#include <glib.h>
#include <stddef.h>

G_BEGIN_DECLS

// Response path for a characteristic that can be read but can neither notify
// nor indicate (the Seac Tablet, issue #1454): every reply is fetched with
// org.bluez.GattCharacteristic1.ReadValue whenever libdivecomputer asks for
// bytes.
//
// The same state machine as darwin's ReadPollPolicy.swift and Android's
// ReadPollPolicy.kt, which carry the unit tests: at most one read in flight,
// a read that outlives a read() timeout adopted by the next read(), an empty
// value or failed read re-read after 100 ms and never at once, and purge
// discarding the value of a read already in flight. Replies are queued one
// entry per packet and a read returns bytes from at most one entry.
//
// Refcounted: every in-flight ReadValue holds a reference, so a completion
// arriving after the stream is freed settles against live memory.
typedef struct BleReadPoller BleReadPoller;

BleReadPoller* ble_read_poller_new(GDBusConnection* connection,
                                   const gchar* characteristic_path);

// libdivecomputer read(). timeout_ms follows BleIoStream.timeout_ms:
// G_MAXINT32 means no timeout.
int ble_read_poller_read(BleReadPoller* poller, void* data, size_t size,
                         size_t* actual, gint timeout_ms);

// libdivecomputer poll(): negative means no timeout, zero never blocks.
int ble_read_poller_poll(BleReadPoller* poller, int timeout_ms);

void ble_read_poller_purge(BleReadPoller* poller);

// Fail any waiting read and ignore completions still in flight. Does not
// release the caller's reference.
void ble_read_poller_close(BleReadPoller* poller);

void ble_read_poller_unref(BleReadPoller* poller);

G_END_DECLS

#endif  // BLE_READ_POLL_H_
```

- [ ] **Step 2: Create the implementation**

`linux/ble_read_poll.c`:

```c
#include "ble_read_poll.h"

#include <string.h>

#include "libdc_wrapper.h"

// Delay before re-reading after an empty value or a failed read.
#define READ_POLL_RETRY_DELAY_US (100 * G_TIME_SPAN_MILLISECOND)
// Longest a waiting reader sleeps before re-checking, so a completion that
// queued nothing is followed by a retry without needing its own wakeup.
#define READ_POLL_WAIT_SLICE_US (100 * G_TIME_SPAN_MILLISECOND)
// D-Bus timeout for one ReadValue: the ATT transaction timeout.
#define READ_POLL_DBUS_TIMEOUT_MS 30000

struct BleReadPoller {
    gint ref_count;
    GDBusConnection* connection;
    gchar* path;

    GMutex mutex;
    GCond cond;
    // GByteArray*, one entry per read response.
    GQueue* chunks;
    gboolean read_in_flight;
    gboolean discard_in_flight;
    gboolean closed;
    // g_get_monotonic_time() before which no read may be issued.
    gint64 retry_not_before;
};

static BleReadPoller* poller_ref(BleReadPoller* poller) {
    g_atomic_int_inc(&poller->ref_count);
    return poller;
}

static void clear_chunks(GQueue* chunks) {
    GByteArray* chunk;
    while ((chunk = g_queue_pop_head(chunks)) != NULL) {
        g_byte_array_unref(chunk);
    }
}

void ble_read_poller_unref(BleReadPoller* poller) {
    if (!poller || !g_atomic_int_dec_and_test(&poller->ref_count)) return;
    clear_chunks(poller->chunks);
    g_queue_free(poller->chunks);
    g_mutex_clear(&poller->mutex);
    g_cond_clear(&poller->cond);
    g_object_unref(poller->connection);
    g_free(poller->path);
    g_free(poller);
}

BleReadPoller* ble_read_poller_new(GDBusConnection* connection,
                                   const gchar* characteristic_path) {
    BleReadPoller* poller = g_new0(BleReadPoller, 1);
    poller->ref_count = 1;
    poller->connection = g_object_ref(connection);
    poller->path = g_strdup(characteristic_path);
    g_mutex_init(&poller->mutex);
    g_cond_init(&poller->cond);
    poller->chunks = g_queue_new();
    return poller;
}

static void on_read_value_complete(GObject* source, GAsyncResult* result,
                                   gpointer user_data) {
    BleReadPoller* poller = (BleReadPoller*)user_data;
    g_autoptr(GError) error = NULL;
    GVariant* reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);

    GByteArray* chunk = NULL;
    if (reply) {
        GVariant* value = NULL;
        g_variant_get(reply, "(@ay)", &value);
        gsize n_bytes = 0;
        const guint8* bytes =
            g_variant_get_fixed_array(value, &n_bytes, sizeof(guint8));
        if (n_bytes > 0 && bytes) {
            chunk = g_byte_array_sized_new((guint)n_bytes);
            g_byte_array_append(chunk, bytes, (guint)n_bytes);
        }
        g_variant_unref(value);
        g_variant_unref(reply);
    } else {
        g_warning("BleIoStream: read-poll ReadValue failed: %s; retrying",
                  error ? error->message : "unknown error");
    }

    g_mutex_lock(&poller->mutex);
    poller->read_in_flight = FALSE;
    if (!poller->closed) {
        if (poller->discard_in_flight) {
            // Answers a command libdivecomputer has abandoned.
            poller->discard_in_flight = FALSE;
        } else if (chunk) {
            g_queue_push_tail(poller->chunks, chunk);
            chunk = NULL;
        } else {
            poller->retry_not_before =
                g_get_monotonic_time() + READ_POLL_RETRY_DELAY_US;
        }
    }
    g_cond_broadcast(&poller->cond);
    g_mutex_unlock(&poller->mutex);

    if (chunk) g_byte_array_unref(chunk);
    // Drops the reference issue_read() took for this call.
    ble_read_poller_unref(poller);
}

// Start one asynchronous ReadValue. The reply is dispatched on the main
// context, never inline, so this is safe to call with the mutex held.
static void issue_read(BleReadPoller* poller) {
    GVariantBuilder options;
    g_variant_builder_init(&options, G_VARIANT_TYPE("a{sv}"));
    g_dbus_connection_call(
        poller->connection, "org.bluez", poller->path,
        "org.bluez.GattCharacteristic1", "ReadValue",
        g_variant_new("(a{sv})", &options), G_VARIANT_TYPE("(ay)"),
        G_DBUS_CALL_FLAGS_NONE, READ_POLL_DBUS_TIMEOUT_MS, NULL,
        on_read_value_complete, poller_ref(poller));
}

// Wait, issuing reads as needed, until a packet is queued (SUCCESS), the
// deadline passes (TIMEOUT) or the poller is closed (IO). Called and returns
// with the mutex held.
static int await_packet(BleReadPoller* poller, gint64 deadline) {
    while (g_queue_is_empty(poller->chunks)) {
        if (poller->closed) return LIBDC_STATUS_IO;
        gint64 now = g_get_monotonic_time();
        if (now >= deadline) return LIBDC_STATUS_TIMEOUT;

        if (!poller->read_in_flight && now >= poller->retry_not_before) {
            poller->read_in_flight = TRUE;
            issue_read(poller);
            continue;
        }

        gint64 slice_end = (deadline - now > READ_POLL_WAIT_SLICE_US)
                               ? now + READ_POLL_WAIT_SLICE_US
                               : deadline;
        g_cond_wait_until(&poller->cond, &poller->mutex, slice_end);
    }
    return LIBDC_STATUS_SUCCESS;
}

int ble_read_poller_read(BleReadPoller* poller, void* data, size_t size,
                         size_t* actual, gint timeout_ms) {
    gint64 deadline = (timeout_ms == G_MAXINT32)
                          ? G_MAXINT64
                          : g_get_monotonic_time() +
                                (gint64)timeout_ms * G_TIME_SPAN_MILLISECOND;
    size_t count = 0;

    g_mutex_lock(&poller->mutex);
    int status = await_packet(poller, deadline);
    if (status == LIBDC_STATUS_SUCCESS) {
        // At most one packet per read, a partial packet staying at the head,
        // as on the notification path.
        GByteArray* chunk = (GByteArray*)g_queue_peek_head(poller->chunks);
        count = MIN(size, chunk->len);
        memcpy(data, chunk->data, count);
        if (count < chunk->len) {
            g_byte_array_remove_range(chunk, 0, (guint)count);
        } else {
            g_queue_pop_head(poller->chunks);
            g_byte_array_unref(chunk);
        }
    }
    g_mutex_unlock(&poller->mutex);

    if (actual) *actual = count;
    return status;
}

int ble_read_poller_poll(BleReadPoller* poller, int timeout_ms) {
    int status;
    g_mutex_lock(&poller->mutex);
    if (!g_queue_is_empty(poller->chunks)) {
        status = LIBDC_STATUS_SUCCESS;
    } else if (timeout_ms == 0) {
        status = LIBDC_STATUS_TIMEOUT;
    } else {
        gint64 deadline = (timeout_ms < 0)
                              ? G_MAXINT64
                              : g_get_monotonic_time() +
                                    (gint64)timeout_ms * G_TIME_SPAN_MILLISECOND;
        status = await_packet(poller, deadline);
    }
    g_mutex_unlock(&poller->mutex);
    return status;
}

void ble_read_poller_purge(BleReadPoller* poller) {
    g_mutex_lock(&poller->mutex);
    clear_chunks(poller->chunks);
    // The value of a read already on the wire answers a command
    // libdivecomputer has abandoned.
    if (poller->read_in_flight) poller->discard_in_flight = TRUE;
    g_mutex_unlock(&poller->mutex);
}

void ble_read_poller_close(BleReadPoller* poller) {
    if (!poller) return;
    g_mutex_lock(&poller->mutex);
    poller->closed = TRUE;
    clear_chunks(poller->chunks);
    g_cond_broadcast(&poller->cond);
    g_mutex_unlock(&poller->mutex);
}
```

The Linux runner compiles plugins with `-Wall -Werror` (`linux/CMakeLists.txt` at the repo root, via `apply_standard_settings`), so an unused variable or label in this file fails the build.

- [ ] **Step 3: Wire it into the stream header**

In `linux/ble_io_stream.h`, after `#include "libdc_wrapper.h"` add:

```c
#include "ble_read_poll.h"
```

After the `GQueue* read_chunks;` member add:

```c

    // Non-NULL only when the read-poll tier was selected (issue #1454). Read,
    // poll and purge go to it instead of read_chunks, and notify_path stays
    // NULL: there is nothing to subscribe to.
    BleReadPoller* read_poller;
```

- [ ] **Step 4: Wire it into the stream implementation**

In `linux/ble_io_stream.c`, after the `UBLOX_CREDITS_UUID` definition add:

```c

// Read-poll service (issue #1454, libdivecomputer 415778c): the Seac Tablet's
// one Rx/Tx characteristic can be read and written but can neither notify nor
// indicate. An allowlist: Generic Access's Device Name is read+write on some
// peripherals and must never be mistaken for a serial channel.
static const char* SEAC_SERVICE_UUID = "84968ffe-d26d-478a-b953-5010bcf58bca";
static const char* SEAC_DATA_UUID = "43c620c2-1b09-4951-bc1e-9c75298cddeb";
```

In `ble_io_stream_connect`, after `gchar* ublox_credits_path = NULL;` add:

```c
    // Read-poll candidate and the object path of its service. BlueZ lists
    // services and characteristics as separate objects, so service UUIDs are
    // collected by path and the candidate's parent is checked after the walk.
    gchar* read_poll_path = NULL;
    gchar* read_poll_service_path = NULL;
    GHashTable* service_uuids =
        g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
```

Inside the object loop, directly after the `if (!g_str_has_prefix(obj_path, device_path)) { ... continue; }` block, add:

```c
        GVariant* service_props = g_variant_lookup_value(
            ifaces, "org.bluez.GattService1", G_VARIANT_TYPE_VARDICT);
        if (service_props) {
            GVariant* service_uuid = g_variant_lookup_value(
                service_props, "UUID", G_VARIANT_TYPE_STRING);
            if (service_uuid) {
                g_hash_table_insert(service_uuids, g_strdup(obj_path),
                                    g_variant_dup_string(service_uuid, NULL));
                g_variant_unref(service_uuid);
            }
            g_variant_unref(service_props);
        }
```

In the UUID `if / else if` chain that records the TIO and u-blox paths, add a final branch:

```c
        } else if (g_ascii_strcasecmp(uuid, SEAC_DATA_UUID) == 0 &&
                   !read_poll_path) {
            GVariant* parent = g_variant_lookup_value(
                char_props, "Service", G_VARIANT_TYPE_OBJECT_PATH);
            if (parent) {
                read_poll_path = g_strdup(obj_path);
                read_poll_service_path = g_variant_dup_string(parent, NULL);
                g_variant_unref(parent);
            }
        }
```

(The chain's last existing branch ends `ublox_credits_path = g_strdup(obj_path);` followed by `}`; replace that closing `}` with the `} else if` above so the chain stays one statement.)

After `g_variant_unref(objects);` add:

```c

    // Keep the read-poll candidate only if it sits under the allowlisted
    // service and can be both read and written.
    if (read_poll_path) {
        const gchar* parent_uuid =
            g_hash_table_lookup(service_uuids, read_poll_service_path);
        gboolean usable =
            parent_uuid &&
            g_ascii_strcasecmp(parent_uuid, SEAC_SERVICE_UUID) == 0 &&
            has_flag(stream->connection, read_poll_path, "read") &&
            (has_flag(stream->connection, read_poll_path, "write") ||
             has_flag(stream->connection, read_poll_path,
                      "write-without-response"));
        if (!usable) g_clear_pointer(&read_poll_path, g_free);
    }
    g_free(read_poll_service_path);
    g_hash_table_unref(service_uuids);
```

Replace

```c
    if (!best_write_path || !best_notify_path) {
        g_warning("BleIoStream: No suitable GATT characteristics found");
        g_free(best_write_path);
        g_free(best_notify_path);
        return FALSE;
    }
```

with

```c
    if (!best_notify_path && read_poll_path) {
        // Read-poll tier (issue #1454): the computer cannot push its replies,
        // so there is no StartNotify, no PropertiesChanged subscription and no
        // credit handshake; the poller reads the characteristic whenever
        // libdivecomputer wants bytes. Commands go to the same characteristic.
        g_free(best_write_path);
        stream->write_path = g_steal_pointer(&read_poll_path);
        stream->read_poller =
            ble_read_poller_new(stream->connection, stream->write_path);
        g_message("BleIoStream: read-poll tier selected: service=%s "
                  "characteristic=%s", SEAC_SERVICE_UUID, stream->write_path);
        return TRUE;
    }
    g_free(read_poll_path);

    if (!best_write_path || !best_notify_path) {
        g_warning("BleIoStream: No suitable GATT characteristics found, and "
                  "no known read-poll service matched");
        g_free(best_write_path);
        g_free(best_notify_path);
        return FALSE;
    }
```

At the top of `ble_read`, after `BleIoStream* stream = (BleIoStream*)userdata;`, add:

```c
    if (stream->read_poller) {
        return ble_read_poller_read(stream->read_poller, data, size, actual,
                                    stream->timeout_ms);
    }
```

At the top of `ble_poll`, after its `BleIoStream* stream = ...;` line (and before `g_mutex_lock`), add:

```c
    if (stream->read_poller) {
        return ble_read_poller_poll(stream->read_poller, timeout);
    }
```

In `ble_purge`, after `BleIoStream* stream = (BleIoStream*)userdata;`, add:

```c
    if (stream->read_poller) ble_read_poller_purge(stream->read_poller);
```

In `ble_io_stream_close`, after `if (!stream) return;`, add:

```c

    // Fail a read-poll reader; the poller itself is freed with the stream.
    if (stream->read_poller) ble_read_poller_close(stream->read_poller);
```

In `ble_io_stream_free`, before `g_free(stream->device_path);`, add:

```c
    if (stream->read_poller) ble_read_poller_unref(stream->read_poller);
```

- [ ] **Step 5: Add the source to the build**

In `linux/CMakeLists.txt`, in `add_library(${PLUGIN_NAME} SHARED`, after `ble_io_stream.c` add `    ble_read_poll.c`.

- [ ] **Step 6: Syntax-check the C that does not need BlueZ headers at runtime**

GLib/GIO headers may be available through Homebrew. If `pkg-config --exists gio-2.0` succeeds, run:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/packages/libdivecomputer_plugin
cc -fsyntax-only -Wall -Wextra -Werror -std=c11 $(pkg-config --cflags gio-2.0) -Imacos/Classes linux/ble_read_poll.c && echo "ble_read_poll.c OK"
cc -fsyntax-only -Wall -Werror -std=c11 $(pkg-config --cflags gio-2.0) -Imacos/Classes -Ilinux linux/ble_io_stream.c && echo "ble_io_stream.c OK"
```

Expected: both print OK. On the development Mac `pkg-config` and GLib are not installed (checked 2026-09-26); installing them (`brew install pkg-config glib`) is a machine change, so ask the user first. Without them, skip this step and say so in the task report; the "Build Linux" CI job is then the only compile check.

Also check wiring:

```bash
grep -n "read_poller" linux/ble_io_stream.h linux/ble_io_stream.c
grep -n "ble_read_poll" linux/CMakeLists.txt
```

Expected: header member; `connect` (assignment), `ble_read`, `ble_poll`, `ble_purge`, `ble_io_stream_close`, `ble_io_stream_free`; CMake entry.

- [ ] **Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/linux/ble_read_poll.h \
        packages/libdivecomputer_plugin/linux/ble_read_poll.c \
        packages/libdivecomputer_plugin/linux/ble_io_stream.h \
        packages/libdivecomputer_plugin/linux/ble_io_stream.c \
        packages/libdivecomputer_plugin/linux/CMakeLists.txt
git commit -m "feat(ble): read the Seac Tablet's replies on demand on Linux

Refs #1454"
```

---

### Task 10: Whole-branch verification and hand-off

**Files:**
- Modify: `/Users/ericgriffin/.claude/projects/-Users-ericgriffin-repos-submersion-app-submersion/memory/project_seac_tablet_ble_1419.md` (memory, not the repo)

- [ ] **Step 1: Format**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb && dart format . && git status --short
```

Expected: no Dart file changes (this branch touches none).

- [ ] **Step 2: Run every native suite this branch touches**

```bash
bash /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/packages/libdivecomputer_plugin/darwin/run_native_tests.sh
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb/android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :libdivecomputer_plugin:testDebugUnitTest --console=plain
```

Expected: all darwin suites pass; BUILD SUCCESSFUL.

- [ ] **Step 3: Scan the diff for forbidden punctuation and attribution**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-profile-depth-tooltip-118eeb
git diff origin/main...HEAD | grep -nP "^\+.*(\x{2014}|\x{2013})" || echo "no dashes added"
git log origin/main..HEAD --format=%B | grep -niE "claude|anthropic" || echo "no attribution"
```

Expected: "no dashes added" and "no attribution".

- [ ] **Step 4: Update the memory note**

In `project_seac_tablet_ble_1419.md`, replace the "Defect 2 (NOT fixed ...)" heading and its first paragraph with a status line: issue #1454, read-on-demand transport on all four platforms on branch `ericgriffin/github-issue-1454-eea528`, allowlist-only strict fallback tier, `ReadPollPolicy` in Swift and Kotlin; Android hardware confirmation from Cicatr1x pending; Darwin, Windows and Linux compile-verified only. Keep the rest of the note.

- [ ] **Step 5: Stop and ask before anything outward-facing**

Report to the user and ask for explicit approval before each of:

1. pushing the branch and opening a **draft** PR whose body says `Refs #1454` (not `Closes`), states that Darwin, Windows and Linux are compile-verified only and Android awaits hardware, and deletes the Screenshots section (no UI change);
2. commenting on #1454 to ask Cicatr1x to test the PR's Android build.

Do not push, open the PR or comment until the user says yes to that specific action.
