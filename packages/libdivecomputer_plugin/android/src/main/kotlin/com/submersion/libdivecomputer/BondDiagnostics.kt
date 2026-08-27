package com.submersion.libdivecomputer

// Explains why an Android BLE pairing attempt did not produce a bond.
//
// A tester reported eleven consecutive downloads failing with
// "bond_failed / Failed to pair with device" and a debug log that carried
// no other BLE line to go with them (issue #1029). The branch which
// actually fires -- the bond ending on BOND_NONE rather than timing out --
// reported only "ensureBonded: result=false" at DEBUG, recording neither
// the state the bond ended in nor the reason Android supplied alongside it.
// A pairing that the peripheral refused was therefore indistinguishable
// from one the user dismissed, from one that never started.
//
// Framework-free so it can run as a JVM unit test; the Android bond
// constants are duplicated here rather than referenced, as
// BleScanDiagnostics does for the scan-failure codes.
object BondDiagnostics {

    // Mirrors android.bluetooth.BluetoothDevice bond states.
    const val BOND_NONE = 10
    const val BOND_BONDING = 11
    const val BOND_BONDED = 12

    // Mirrors the android.bluetooth.BluetoothDevice UNBOND_REASON_* values
    // delivered in the ACTION_BOND_STATE_CHANGED reason extra. The extra and
    // its constants are hidden API, so they are duplicated rather than
    // referenced; the values are stable across releases.
    const val UNBOND_REASON_AUTH_FAILED = 1
    const val UNBOND_REASON_AUTH_REJECTED = 2
    const val UNBOND_REASON_AUTH_CANCELED = 3
    const val UNBOND_REASON_REMOTE_DEVICE_DOWN = 4
    const val UNBOND_REASON_DISCOVERY_IN_PROGRESS = 5
    const val UNBOND_REASON_AUTH_TIMEOUT = 6
    const val UNBOND_REASON_REPEATED_ATTEMPTS = 7
    const val UNBOND_REASON_REMOTE_AUTH_CANCELED = 8
    const val UNBOND_REASON_REMOVED = 9

    // BluetoothDevice.EXTRA_REASON is hidden API; the string it resolves to
    // is public and stable, and reading the extra by name avoids reflection.
    const val EXTRA_REASON = "android.bluetooth.device.extra.REASON"

    /** Human-readable name for a BluetoothDevice bond state. */
    fun describeBondState(state: Int): String = when (state) {
        BOND_NONE -> "not bonded"
        BOND_BONDING -> "bonding in progress"
        BOND_BONDED -> "bonded"
        else -> "unknown bond state ($state)"
    }

    /** Human-readable reason for an ACTION_BOND_STATE_CHANGED reason extra. */
    fun describeUnbondReason(reason: Int): String = when (reason) {
        UNBOND_REASON_AUTH_FAILED ->
            "authentication failed"
        UNBOND_REASON_AUTH_REJECTED ->
            "the computer rejected the pairing request"
        UNBOND_REASON_AUTH_CANCELED ->
            "pairing was cancelled on this phone"
        UNBOND_REASON_REMOTE_DEVICE_DOWN ->
            "the computer stopped responding"
        UNBOND_REASON_DISCOVERY_IN_PROGRESS ->
            "a Bluetooth discovery was running"
        UNBOND_REASON_AUTH_TIMEOUT ->
            "pairing timed out"
        UNBOND_REASON_REPEATED_ATTEMPTS ->
            "too many pairing attempts in a row; Android is throttling them"
        UNBOND_REASON_REMOTE_AUTH_CANCELED ->
            "the computer cancelled pairing"
        UNBOND_REASON_REMOVED ->
            "the bond was removed"
        else ->
            "unknown pairing failure (reason $reason)"
    }

    /**
     * True when a `false` from createBond() means a bond is already under
     * way rather than that the request was refused.
     *
     * Android returns false from createBond() while a bond is in progress.
     * A user tapping retry every second therefore produces a cascade:
     * attempt N leaves the device in BOND_BONDING, and every attempt after
     * it fails instantly without ever waiting for the bond still running.
     */
    fun bondAlreadyInProgress(bondState: Int): Boolean = bondState == BOND_BONDING

    /**
     * Message for a bond attempt that ran and did not end bonded, naming
     * both the state it settled in and Android's reason where one was
     * supplied. Some stacks omit the reason extra, so [unbondReason] is
     * optional and its absence must not surface as "null".
     */
    fun describeFailedAttempt(bondState: Int, unbondReason: Int?): String {
        val state = describeBondState(bondState)
        return if (unbondReason == null) {
            "pairing did not complete (ended $state; no reason reported)"
        } else {
            "pairing did not complete (ended $state: ${describeUnbondReason(unbondReason)})"
        }
    }

    /**
     * Message for a bond the Bluetooth stack declined to even start, which
     * createBond() reports as a bare `false` with no broadcast to follow.
     */
    fun describeRefusedRequest(bondState: Int): String =
        "createBond() was refused by the Bluetooth stack " +
            "(device is ${describeBondState(bondState)})"

    /**
     * Message for a pairing attempt that threw. [message] is
     * Throwable.message, which is nullable often enough (SecurityException
     * from a revoked permission, NullPointerException) that interpolating
     * it directly would leave "null" in the log.
     */
    fun describeThrownFailure(exceptionName: String, message: String?): String {
        val detail = message?.takeIf { it.isNotBlank() }
        return if (detail == null) {
            "pairing threw $exceptionName (no message)"
        } else {
            "pairing threw $exceptionName: $detail"
        }
    }
}
