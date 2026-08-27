package com.submersion.libdivecomputer

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// JVM tests for the vendor-keyed proactive-bond policy behind the Android
// BLE download path (issue #910): Shearwater devices must not be bonded
// proactively because a Submersion-created bond blocks Shearwater Cloud
// until the user unpairs the computer.
class BondPolicyTest {

    @Test
    fun shearwaterIsExemptFromProactiveBonding() {
        assertFalse(BondPolicy.requiresProactiveBond("Shearwater"))
    }

    @Test
    fun shearwaterMatchIsCaseInsensitive() {
        assertFalse(BondPolicy.requiresProactiveBond("shearwater"))
        assertFalse(BondPolicy.requiresProactiveBond("SHEARWATER"))
    }

    @Test
    fun otherVendorsStillRequireProactiveBonding() {
        assertTrue(BondPolicy.requiresProactiveBond("Aqualung"))
        assertTrue(BondPolicy.requiresProactiveBond("Mares"))
        assertTrue(BondPolicy.requiresProactiveBond("Suunto"))
    }

    @Test
    fun unknownOrEmptyVendorDefaultsToBonding() {
        assertTrue(BondPolicy.requiresProactiveBond(""))
        assertTrue(BondPolicy.requiresProactiveBond("NoSuchVendor"))
    }

    // A tester saw eleven consecutive downloads end at "bond_failed" on a
    // connection that had already been established and had its services
    // discovered (issue #1029). No other backend (Apple, Linux, Windows)
    // bonds at all and the same computers download there, so a bond that
    // will not complete must not be allowed to end the download.
    @Test
    fun aFailedProactiveBondNeverAbortsTheDownload() {
        assertFalse(BondPolicy.bondFailureAbortsDownload("Aqualung"))
        assertFalse(BondPolicy.bondFailureAbortsDownload("Mares"))
        assertFalse(BondPolicy.bondFailureAbortsDownload("Suunto"))
        assertFalse(BondPolicy.bondFailureAbortsDownload("NoSuchVendor"))
        assertFalse(BondPolicy.bondFailureAbortsDownload(""))
    }

    // Vendors that never bond proactively cannot reach the failure path at
    // all, so the answer has to hold for them too.
    @Test
    fun exemptVendorsAlsoNeverAbortOnBondFailure() {
        assertFalse(BondPolicy.bondFailureAbortsDownload("Shearwater"))
    }
}
