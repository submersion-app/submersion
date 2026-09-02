package com.submersion.libdivecomputer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// JVM tests for the GATT connect/discovery diagnostics (issue #957).
//
// A Shearwater Petrel 2 owner reported "Failed to connect to device" and
// sent a debug log whose entire account of the failure was
// "connectAndDiscover: connected=true writeChar=null credits=0
// result=false". Every path that can leave writeChar null returned without
// logging anything: a refused service discovery returned early, and a
// discovery that found no usable service simply fell through. These tests
// pin the messages that tell those cases apart in a bug report.
class GattDiagnosticsTest {

    @Test
    fun dualModeDeviceTypeIsNamed() {
        val described = GattDiagnostics.describeDeviceType(
            GattDiagnostics.DEVICE_TYPE_DUAL
        )

        assertTrue(described.contains("dual"))
        assertTrue(described.contains("LE"))
    }

    @Test
    fun everyDeviceTypeIsDescribed() {
        assertEquals("Bluetooth Classic only", GattDiagnostics.describeDeviceType(
            GattDiagnostics.DEVICE_TYPE_CLASSIC
        ))
        assertEquals("LE only", GattDiagnostics.describeDeviceType(
            GattDiagnostics.DEVICE_TYPE_LE
        ))
        assertTrue(
            GattDiagnostics.describeDeviceType(
                GattDiagnostics.DEVICE_TYPE_UNKNOWN
            ).contains("unknown")
        )
    }

    @Test
    fun unrecognizedDeviceTypeStillReportsItsValue() {
        assertTrue(GattDiagnostics.describeDeviceType(42).contains("42"))
    }

    @Test
    fun commonAttStatusesAreExplained() {
        assertTrue(GattDiagnostics.describeAttStatus(0).contains("success"))
        assertTrue(
            GattDiagnostics.describeAttStatus(
                GattDiagnostics.ATT_INSUFFICIENT_AUTHENTICATION
            ).contains("pairing")
        )
        assertEquals(
            "generic GATT error; usually the computer refused the operation " +
                "or the link was not usable for it",
            GattDiagnostics.describeAttStatus(GattDiagnostics.GATT_ERROR)
        )
    }

    @Test
    fun statusEightReadsAsAuthorizationOnAnAttCallback() {
        // ATT 0x08 is insufficient authorization, a bond problem. The HCI
        // connection space also defines 8, as a connection timeout, and
        // describing an onServicesDiscovered status with that table sent the
        // reporter after range and battery for what pairing again fixes.
        val message = GattDiagnostics.describeAttStatus(
            GattDiagnostics.ATT_INSUFFICIENT_AUTHORIZATION
        )

        assertTrue(message.contains("authorization"))
        assertFalse(message.contains("out of range"))
        assertFalse(message.contains("timed out"))
    }

    @Test
    fun statusEightStillReadsAsATimeoutOnAConnectionCallback() {
        val message = GattDiagnostics.describeConnectionStatus(
            GattDiagnostics.CONN_TIMEOUT
        )

        assertTrue(message.contains("timed out"))
        assertFalse(message.contains("authorization"))
    }

    @Test
    fun theTwoStatusSpacesDisagreeAboutEightOnPurpose() {
        // Pins the collision itself: if either table is ever folded back
        // into the other, one of these call sites starts lying.
        assertFalse(
            GattDiagnostics.describeAttStatus(8) ==
                GattDiagnostics.describeConnectionStatus(8)
        )
    }

    @Test
    fun everyKnownAttStatusHasItsOwnDescription() {
        // The sibling suites (BondDiagnosticsTest, BleScanDiagnosticsTest)
        // both carry this assertion; without it a copy-paste that gives two
        // codes the same text reads as a working table.
        val known = listOf(
            GattDiagnostics.GATT_SUCCESS,
            GattDiagnostics.ATT_INVALID_HANDLE,
            GattDiagnostics.ATT_READ_NOT_PERMITTED,
            GattDiagnostics.ATT_WRITE_NOT_PERMITTED,
            GattDiagnostics.ATT_INSUFFICIENT_AUTHENTICATION,
            GattDiagnostics.ATT_REQUEST_NOT_SUPPORTED,
            GattDiagnostics.ATT_INVALID_OFFSET,
            GattDiagnostics.ATT_INSUFFICIENT_AUTHORIZATION,
            GattDiagnostics.ATT_ATTRIBUTE_NOT_FOUND,
            GattDiagnostics.ATT_INSUFFICIENT_KEY_SIZE,
            GattDiagnostics.ATT_INVALID_ATTRIBUTE_LENGTH,
            GattDiagnostics.ATT_INSUFFICIENT_ENCRYPTION,
            GattDiagnostics.GATT_INTERNAL_ERROR,
            GattDiagnostics.GATT_ERROR,
            GattDiagnostics.GATT_CONN_CANCEL,
            GattDiagnostics.GATT_FAILURE
        )
        val descriptions = known.map { GattDiagnostics.describeAttStatus(it) }

        assertEquals(known.size, descriptions.toSet().size)
        assertTrue(descriptions.none { it.contains("unknown") })
    }

    @Test
    fun everyKnownConnectionStatusHasItsOwnDescription() {
        val known = listOf(
            GattDiagnostics.GATT_SUCCESS,
            GattDiagnostics.CONN_TIMEOUT,
            GattDiagnostics.CONN_TERMINATE_PEER_USER,
            GattDiagnostics.CONN_TERMINATE_LOCAL_HOST,
            GattDiagnostics.CONN_LMP_TIMEOUT,
            GattDiagnostics.CONN_FAIL_ESTABLISH,
            GattDiagnostics.CONN_AUTH_FAILURE,
            GattDiagnostics.CONN_TIMEOUT_HCI,
            GattDiagnostics.GATT_INTERNAL_ERROR,
            GattDiagnostics.GATT_ERROR,
            GattDiagnostics.GATT_CONN_CANCEL,
            GattDiagnostics.GATT_FAILURE
        )
        val descriptions =
            known.map { GattDiagnostics.describeConnectionStatus(it) }

        assertEquals(known.size, descriptions.toSet().size)
        assertTrue(descriptions.none { it.contains("unknown") })
    }

    @Test
    fun theStatusThisRepoKeepsCitingIsNotUnknown() {
        // 147 appears three times in DiveComputerHostApiImpl's own comments
        // as the stale-bond failure, and used to render as "unknown".
        assertFalse(
            GattDiagnostics.describeConnectionStatus(147).contains("unknown")
        )
    }

    @Test
    fun unknownStatusReportsItsValueAndItsSpace() {
        assertTrue(GattDiagnostics.describeAttStatus(200).contains("200"))
        assertTrue(GattDiagnostics.describeAttStatus(200).contains("ATT"))
        assertTrue(
            GattDiagnostics.describeConnectionStatus(200).contains("200")
        )
        assertTrue(
            GattDiagnostics.describeConnectionStatus(200).contains("connection")
        )
    }

    @Test
    fun discoveryFailureNamesTheStatusAndTheDeviceType() {
        val message = GattDiagnostics.describeDiscoveryFailure(
            GattDiagnostics.GATT_ERROR,
            GattDiagnostics.DEVICE_TYPE_LE
        )

        assertTrue(message.contains("133"))
        assertTrue(message.contains("LE only"))
    }

    @Test
    fun discoveryFailureOnADualModeDeviceNamesTheTransportTrap() {
        val message = GattDiagnostics.describeDiscoveryFailure(
            GattDiagnostics.GATT_ERROR,
            GattDiagnostics.DEVICE_TYPE_DUAL
        )

        // The dual-mode radio is the whole diagnosis of #957: under
        // TRANSPORT_AUTO Android connects such a device over Bluetooth
        // Classic, and GATT discovery then finds nothing.
        assertTrue(message.contains("Classic"))
        assertTrue(message.contains("TRANSPORT_AUTO"))
    }

    @Test
    fun theDualModeAddendumIsALeadRatherThanAVerdict() {
        val message = GattDiagnostics.describeDiscoveryFailure(
            GattDiagnostics.GATT_ERROR,
            GattDiagnostics.DEVICE_TYPE_DUAL
        )

        // Since this build demands TRANSPORT_LE, the transport is not the
        // explanation on a current log, and a dual-mode radio fails
        // discovery for the same ordinary reasons any other radio does.
        // The line must send the reader to the connect line rather than
        // deciding the diagnosis for them.
        assertTrue(message.contains("connect line"))
        assertTrue(message.contains("before assuming"))
    }

    @Test
    fun onlyADualModeRadioEarnsTheTransportAddendum() {
        // Testing DEVICE_TYPE_LE alone under-constrains the guard: an
        // implementation written `if (type == DEVICE_TYPE_LE) return base`
        // would pass. Every non-dual type has to be checked, and the
        // addendum is identified by its own words rather than by "Classic",
        // which the CLASSIC base string legitimately contains.
        val nonDual = listOf(
            GattDiagnostics.DEVICE_TYPE_UNKNOWN,
            GattDiagnostics.DEVICE_TYPE_CLASSIC,
            GattDiagnostics.DEVICE_TYPE_LE,
            42
        )
        for (type in nonDual) {
            val message = GattDiagnostics.describeDiscoveryFailure(
                GattDiagnostics.GATT_ERROR,
                type
            )
            assertFalse(
                "type $type must not earn the addendum",
                message.contains("TRANSPORT_AUTO")
            )
        }
        assertTrue(
            GattDiagnostics.describeDiscoveryFailure(
                GattDiagnostics.GATT_ERROR,
                GattDiagnostics.DEVICE_TYPE_DUAL
            ).contains("TRANSPORT_AUTO")
        )
    }

    @Test
    fun theTransportLabelFollowsWhatTheConnectActuallyRequested() {
        assertEquals("LE", GattDiagnostics.describeTransport(true))

        // A log that claims LE on a connect that ran under TRANSPORT_AUTO
        // would misreport the one fact this instrumentation exists to
        // establish, so the fallback must never read as LE.
        val fallback = GattDiagnostics.describeTransport(false)
        assertFalse(fallback == "LE")
        assertTrue(fallback.contains("AUTO"))
    }

    @Test
    fun emptyDiscoveryIsDistinguishedFromAnUnusableOne() {
        val empty = GattDiagnostics.describeNoUsableService(emptyList())

        assertTrue(empty.contains("no services"))
    }

    @Test
    fun unusableDiscoveryListsWhatTheComputerExposed() {
        val message = GattDiagnostics.describeNoUsableService(
            listOf(
                "00001800-0000-1000-8000-00805f9b34fb",
                "0000fefb-0000-1000-8000-00805f9b34fb"
            )
        )

        // "2" alone passed only because neither fixture UUID contains that
        // digit; assert the count as it is actually rendered.
        assertTrue(message.contains("2 service(s)"))
        assertTrue(message.contains("00001800-0000-1000-8000-00805f9b34fb"))
        assertTrue(message.contains("0000fefb-0000-1000-8000-00805f9b34fb"))
    }

    @Test
    fun aRefusedDataSubscriptionNamesTheAttReasonForIt() {
        // onDescriptorWrite is an ATT callback, so status 8 here is an
        // authorization failure, not the connection timeout the same number
        // means on onConnectionStateChange. Sending a reporter after range
        // and battery for a bond problem is the misdiagnosis this suite
        // exists to prevent.
        val message = GattDiagnostics.describeDataSubscriptionFailure(
            GattDiagnostics.ATT_INSUFFICIENT_AUTHORIZATION
        )

        assertTrue(message.contains("status=8"))
        assertTrue(message.contains("authorization"))
        assertFalse(message.contains("out of range"))
    }

    @Test
    fun aRefusedCreditsSubscriptionNamesTheBridgeItLeavesShut() {
        // A Telit module answers nothing at all without this subscription,
        // so the message has to say why the link is dead rather than just
        // that a descriptor write failed (#923).
        val message = GattDiagnostics.describeCreditsSubscriptionFailure(
            GattDiagnostics.ATT_INSUFFICIENT_AUTHENTICATION
        )

        assertTrue(message.contains("Credits TX"))
        assertTrue(message.contains("bridge"))
        assertTrue(message.contains("status=5"))
        assertTrue(message.contains("pairing"))
    }

    @Test
    fun theTwoSubscriptionFailuresAreNotInterchangeable() {
        // They are logged from adjacent branches of one callback. An
        // implementation that routed both through a single message would
        // leave a log that cannot say which subscription died, which is the
        // difference between a Terminal I/O handshake problem and a data
        // characteristic the computer refuses to push.
        val status = GattDiagnostics.GATT_ERROR
        val data = GattDiagnostics.describeDataSubscriptionFailure(status)
        val credits = GattDiagnostics.describeCreditsSubscriptionFailure(status)

        assertFalse(data == credits)
        assertTrue(data.contains("Data TX"))
        assertFalse(data.contains("Credits TX"))
    }

    @Test
    fun aSubscribeThatNeverStartedClaimsNoStatusItCouldNotHave() {
        // Nothing reached the computer on this path, so there is no ATT
        // status to name. A message that rendered one anyway would invent a
        // verdict the peripheral never gave.
        assertFalse(GattDiagnostics.SUBSCRIPTION_NOT_STARTED.contains("status="))
        assertFalse(
            GattDiagnostics.SUBSCRIPTION_NOT_STARTED ==
                GattDiagnostics.describeDataSubscriptionFailure(
                    GattDiagnostics.GATT_SUCCESS
                )
        )
    }
}
