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
