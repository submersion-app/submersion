package com.submersion.libdivecomputer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// JVM tests for the bond diagnostics used by BleIoStream.ensureBonded().
//
// A tester reported eleven consecutive "bond_failed / Failed to pair with
// device" download failures whose debug log contained no other BLE line
// (issue #1029), because the branch that actually fired logged at DEBUG
// and recorded neither the bond state it ended on nor the reason Android
// supplied. These tests pin the text that makes the next report
// diagnosable.
class BondDiagnosticsTest {

    @Test
    fun rejectedPairingIsDescribedInWords() {
        val description = BondDiagnostics.describeUnbondReason(
            BondDiagnostics.UNBOND_REASON_AUTH_REJECTED
        )

        assertTrue(description.contains("reject"))
    }

    @Test
    fun eachKnownReasonHasItsOwnDescription() {
        val known = listOf(
            BondDiagnostics.UNBOND_REASON_AUTH_FAILED,
            BondDiagnostics.UNBOND_REASON_AUTH_REJECTED,
            BondDiagnostics.UNBOND_REASON_AUTH_CANCELED,
            BondDiagnostics.UNBOND_REASON_REMOTE_DEVICE_DOWN,
            BondDiagnostics.UNBOND_REASON_DISCOVERY_IN_PROGRESS,
            BondDiagnostics.UNBOND_REASON_AUTH_TIMEOUT,
            BondDiagnostics.UNBOND_REASON_REPEATED_ATTEMPTS,
            BondDiagnostics.UNBOND_REASON_REMOTE_AUTH_CANCELED,
            BondDiagnostics.UNBOND_REASON_REMOVED
        )

        val descriptions = known.map { BondDiagnostics.describeUnbondReason(it) }

        assertEquals(known.size, descriptions.toSet().size)
    }

    @Test
    fun unrecognizedReasonCodeIsStillReportedNumerically() {
        val description = BondDiagnostics.describeUnbondReason(42)

        assertTrue(description.contains("42"))
    }

    @Test
    fun bondStatesAreDescribedInWords() {
        assertTrue(
            BondDiagnostics.describeBondState(BondDiagnostics.BOND_NONE)
                .contains("not bonded")
        )
        assertTrue(
            BondDiagnostics.describeBondState(BondDiagnostics.BOND_BONDING)
                .contains("in progress")
        )
        assertTrue(
            BondDiagnostics.describeBondState(BondDiagnostics.BOND_BONDED)
                .contains("bonded")
        )
    }

    // createBond() returns false when a bond is already under way, which is
    // exactly what a user tapping retry every second produces: attempt N
    // leaves the device in BOND_BONDING and attempt N+1 fails instantly
    // without waiting for the bond that is still running.
    @Test
    fun aBondAlreadyUnderWayIsDistinguishedFromARefusedRequest() {
        assertTrue(BondDiagnostics.bondAlreadyInProgress(BondDiagnostics.BOND_BONDING))
        assertFalse(BondDiagnostics.bondAlreadyInProgress(BondDiagnostics.BOND_NONE))
        assertFalse(BondDiagnostics.bondAlreadyInProgress(BondDiagnostics.BOND_BONDED))
    }

    @Test
    fun failedAttemptNamesBothTheEndStateAndTheReason() {
        val description = BondDiagnostics.describeFailedAttempt(
            BondDiagnostics.BOND_NONE,
            BondDiagnostics.UNBOND_REASON_AUTH_REJECTED
        )

        assertTrue(description.contains("not bonded"))
        assertTrue(description.contains("reject"))
    }

    // Android omits the reason extra on some stacks; the state alone must
    // still produce a usable line rather than the string "null".
    @Test
    fun failedAttemptWithoutAReasonStillDescribesTheEndState() {
        val description = BondDiagnostics.describeFailedAttempt(
            BondDiagnostics.BOND_NONE,
            null
        )

        assertTrue(description.contains("not bonded"))
        assertFalse(description.contains("null"))
    }

    @Test
    fun aThrownPairingFailureNamesTheExceptionAndItsMessage() {
        val description = BondDiagnostics.describeThrownFailure(
            "SecurityException",
            "BLUETOOTH_CONNECT permission denied"
        )

        assertTrue(description.contains("SecurityException"))
        assertTrue(description.contains("BLUETOOTH_CONNECT permission denied"))
    }

    // Throwable.message is nullable, and interpolating it produced log text
    // ending in ": null" -- the same defect already avoided for the absent
    // reason extra.
    @Test
    fun aThrownPairingFailureWithoutAMessageDoesNotLogTheWordNull() {
        val description = BondDiagnostics.describeThrownFailure(
            "NullPointerException",
            null
        )

        assertTrue(description.contains("NullPointerException"))
        assertFalse(description.contains("null"))
    }

    @Test
    fun aBondRequestTheStackRefusedToStartIsDescribed() {
        val description = BondDiagnostics.describeRefusedRequest(BondDiagnostics.BOND_NONE)

        assertTrue(description.contains("createBond"))
        assertTrue(description.contains("not bonded"))
    }
}
