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

    // How a command write on a read-poll characteristic is reported to
    // libdivecomputer once its completion is in.
    enum class WriteOutcome {
        // The computer accepted it.
        SENT,
        // The computer answered with an error on a live link; report it sent.
        SENT_DESPITE_REJECTION,
        // The link dropped under it; fail it.
        FAILED
    }

    companion object {
        // Delay before re-reading after an empty value or a failed read.
        const val RETRY_DELAY_MS = 100L
        // Longest a waiting reader sleeps before asking the policy again.
        const val WAIT_SLICE_MS = 100L

        // A rejected write counts as sent while the link is up. The Seac
        // Tablet accepts its 1-byte wake-up write but answers every 7-byte
        // command with ATT 0x0D (invalid attribute value length), and
        // Subsurface, the only client known to download it over BLE, never
        // looks at a write's status (qt-ble.cpp BLEObject::write). Failing the
        // write ends the download before the reply is read; reporting it sent
        // lets the read decide, and a command that really was dropped times
        // out there and is retried by libdivecomputer. A write lost to a
        // dropped link can never be answered, so it still fails.
        fun writeOutcome(accepted: Boolean, linkUp: Boolean): WriteOutcome = when {
            accepted -> WriteOutcome.SENT
            linkUp -> WriteOutcome.SENT_DESPITE_REJECTION
            else -> WriteOutcome.FAILED
        }
    }

    var readInFlight = false
        private set
    private var discardInFlight = false
    // Long.MIN_VALUE, not 0: the clock derives from System.nanoTime(), which
    // may be negative, and a fresh policy must not start out backing off.
    private var retryNotBeforeMs = Long.MIN_VALUE
    // Readable so BleIoStream can refuse to publish GATT-gate ownership once
    // the stream is closing.
    var isClosed = false
        private set

    // What a reader with an empty queue should do now.
    fun next(nowMs: Long): Action {
        if (isClosed) return Action.CLOSED
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
        if (isClosed) return false
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
        isClosed = true
        readInFlight = false
        discardInFlight = false
    }
}
