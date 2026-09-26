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
