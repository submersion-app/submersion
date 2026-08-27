import Foundation

// Standalone test runner for TerminalIoCreditPolicy (no XCTest: the
// LibDCDarwin package cannot build under SwiftPM because it depends on Flutter
// modules only present in the CocoaPods build). Run via run_native_tests.sh.

var failures = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message) (main.swift:\(line))")
        failures += 1
    }
}

/// Feed `count` packets through the policy, committing every refill the way a
/// transport whose writes all succeed would. Returns the grants requested.
func drain(_ policy: inout TerminalIoCreditPolicy, packets count: Int) -> [UInt8] {
    var grants: [UInt8] = []
    for _ in 0..<count {
        if let grant = policy.packetReceived() {
            grants.append(grant)
            policy.grantAccepted(grant)
        }
    }
    return grants
}

// 1. The opening grant is 254, not 255: 0xFF is a reserved TIO control value.
do {
    expect(TerminalIoCreditPolicy.initialGrant == 254,
           "initial grant is 254 (0xFF is reserved by the TIO protocol)")
}

// 2. A fresh policy has no credits until the opening grant is committed. This
// is what keeps the transport from believing the bridge is open before the
// initial write to UART Credits RX has actually gone out.
do {
    var policy = TerminalIoCreditPolicy()
    expect(policy.credits == 0, "fresh policy starts at zero credits")
    policy.opened(with: TerminalIoCreditPolicy.initialGrant)
    expect(policy.credits == 254, "opening grant credits the balance")
}

// 3. Packets below the threshold cost a credit but ask for nothing.
do {
    var policy = TerminalIoCreditPolicy()
    policy.opened(with: TerminalIoCreditPolicy.initialGrant)
    let grants = drain(&policy, packets: 100)
    expect(grants.isEmpty, "no refill requested while the balance is healthy")
    expect(policy.credits == 154, "each packet spends exactly one credit")
}

// 4. The refill fires at the threshold and restores the full balance, so a
// long transfer never runs the module dry. 254 - 32 = 222 credits are granted
// when 32 remain.
do {
    var policy = TerminalIoCreditPolicy()
    policy.opened(with: TerminalIoCreditPolicy.initialGrant)
    let grants = drain(&policy, packets: 222)
    expect(grants == [222], "one refill of 222 requested on reaching the threshold")
    expect(policy.credits == 254, "refill restores the full balance")
}

// 5. Regression for the real failure mode: an OSTC logbook dump is thousands
// of notifications. A one-shot grant would stall after 254; the policy must
// keep topping up and never let the balance reach zero.
do {
    var policy = TerminalIoCreditPolicy()
    policy.opened(with: TerminalIoCreditPolicy.initialGrant)
    var minimumSeen = Int.max
    var refills = 0
    for _ in 0..<5000 {
        if let grant = policy.packetReceived() {
            refills += 1
            policy.grantAccepted(grant)
        }
        minimumSeen = min(minimumSeen, policy.credits)
    }
    expect(refills > 20, "long transfer refills repeatedly (got \(refills))")
    expect(minimumSeen > 0, "balance never reaches zero (low-water \(minimumSeen))")
}

// 6. A refill that never reached the module must not be counted, and once the
// caller reports the failure the next packet asks again. Android reports
// success from writeCharacteristic() and can still fail the write at the ATT
// layer afterwards, so "accepted" is not "received".
do {
    var policy = TerminalIoCreditPolicy()
    policy.opened(with: TerminalIoCreditPolicy.initialGrant)
    _ = drain(&policy, packets: 221)
    let first = policy.packetReceived()  // reaches the threshold
    expect(first == 222, "refill requested at the threshold")
    expect(policy.credits == 32, "an unconfirmed refill is not counted")
    policy.grantFailed()
    let second = policy.packetReceived()
    expect(second == 222, "after a reported failure the next packet asks again")
    policy.grantAccepted(second ?? 0)
    expect(policy.credits == 253, "the confirmed retry credits the balance")
}

// 7. Regression for the stall this whole policy exists to avoid. If a failed
// grant were counted as delivered, the balance would sit far above the
// threshold while the module's real balance ran out; the module would fall
// silent, no further packets would arrive to decrement the balance, and no
// refill would ever be issued again. The balance must stay at or below the
// module's real one so a refill is always eventually triggered.
do {
    var policy = TerminalIoCreditPolicy()
    policy.opened(with: TerminalIoCreditPolicy.initialGrant)
    _ = drain(&policy, packets: 222)  // one confirmed refill, balance back to 254
    var moduleBalance = 254

    // Every subsequent refill fails to reach the module.
    for _ in 0..<254 {
        moduleBalance -= 1
        if let grant = policy.packetReceived() {
            _ = grant  // the write is issued but never reaches the module
            policy.grantFailed()
        }
        expect(policy.credits <= moduleBalance,
               "balance never exceeds the module's real credits")
        if moduleBalance <= 0 { break }
    }
    expect(policy.packetReceived() != nil,
           "a refill is still being requested rather than silently stalling")
}

// 8. Only one grant is outstanding at a time: a second packet arriving before
// the first grant is confirmed must not request another, or the module would
// be handed credits twice and the balance would overshoot.
do {
    var policy = TerminalIoCreditPolicy()
    policy.opened(with: TerminalIoCreditPolicy.initialGrant)
    _ = drain(&policy, packets: 221)
    expect(policy.packetReceived() == 222, "first refill requested")
    expect(policy.packetReceived() == nil, "no second refill while one is outstanding")
    expect(policy.packetReceived() == nil, "still suppressed on the next packet")
    policy.grantAccepted(TerminalIoCreditPolicy.refillAmount)
    expect(policy.credits == 252, "only the one confirmed grant is counted")
}

// 9. Nothing is requested before the opening grant is confirmed. Notifications
// are already live by the time that grant is written -- the u-blox service in
// particular streams with no credits at all -- so packets can arrive during
// the window. A refill requested there would put a second credit write on the
// wire alongside the opening one; their completions are indistinguishable to
// the transport, so it would mis-attribute them and count both grants.
do {
    var policy = TerminalIoCreditPolicy()
    let grants = (0..<10).map { _ in policy.packetReceived() }
    expect(grants.allSatisfy { $0 == nil },
           "no refill is requested before the opening grant is confirmed")
    expect(policy.credits == 0, "balance floors at zero rather than going negative")
    expect(!policy.grantInFlight, "no grant is left marked outstanding")

    // Once opened, accounting proceeds normally despite those early packets.
    policy.opened(with: TerminalIoCreditPolicy.initialGrant)
    expect(policy.credits == 254, "opening grant credits the balance as usual")
    expect(policy.packetReceived() == nil, "and refills resume their normal schedule")
}

if failures == 0 {
    print("All TerminalIoCreditPolicy tests passed.")
    exit(0)
} else {
    print("\(failures) TerminalIoCreditPolicy test(s) FAILED.")
    exit(1)
}
