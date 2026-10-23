package com.submersion.libdivecomputer

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// JVM tests for the proactive-bond policy behind the Android BLE download
// path. Shearwater devices must not be bonded proactively because a
// Submersion-created bond blocks Shearwater Cloud until the user unpairs
// the computer (issue #910). The Pelagic i330R family (Apeks DSX, Aqualung
// i330R) must not be bonded because the system pairing dialog asks for a
// PIN the computer never displays (issue #3546).
class BondPolicyTest {

    @Test
    fun shearwaterIsExemptFromProactiveBonding() {
        assertFalse(BondPolicy.requiresProactiveBond("Shearwater", "Perdix 2"))
    }

    @Test
    fun shearwaterMatchIsCaseInsensitive() {
        assertFalse(BondPolicy.requiresProactiveBond("shearwater", "Teric"))
        assertFalse(BondPolicy.requiresProactiveBond("SHEARWATER", "Teric"))
    }

    // The i330R family authenticates in its own protocol: libdivecomputer
    // asks the computer for access, the computer shows a six-digit code, and
    // the user types it into Submersion's own dialog. createBond() instead
    // raises Android's system pairing dialog asking for a four-digit PIN
    // that the computer never shows, and holds the download for up to 30
    // seconds before libdivecomputer can ask for access, which is what
    // makes the computer show its real code (issue #3546).
    @Test
    fun pelagicI330rFamilyIsExemptFromProactiveBonding() {
        assertFalse(BondPolicy.requiresProactiveBond("Apeks", "DSX"))
        assertFalse(BondPolicy.requiresProactiveBond("Aqualung", "i330R"))
        assertFalse(BondPolicy.requiresProactiveBond("Aqualung", "i330R Console"))
    }

    @Test
    fun pelagicI330rMatchIgnoresCaseAndSurroundingWhitespace() {
        assertFalse(BondPolicy.requiresProactiveBond("APEKS", " dsx "))
        assertFalse(BondPolicy.requiresProactiveBond(" aqualung", "I330R"))
    }

    // Only those three products are exempt. Aqualung's Oceanic Atom2 family
    // computers on the same Pelagic BLE service (i300C, i770R, i550C) keep
    // the proactive bond.
    @Test
    fun otherPelagicProductsStillRequireProactiveBonding() {
        assertTrue(BondPolicy.requiresProactiveBond("Aqualung", "i300C"))
        assertTrue(BondPolicy.requiresProactiveBond("Aqualung", "i770R"))
        assertTrue(BondPolicy.requiresProactiveBond("Aqualung", "i550C"))
    }

    // An exempt product name under the wrong vendor is not the same device.
    @Test
    fun exemptProductNameUnderAnotherVendorStillBonds() {
        assertTrue(BondPolicy.requiresProactiveBond("Mares", "DSX"))
        assertTrue(BondPolicy.requiresProactiveBond("Apeks", "i330R"))
    }

    @Test
    fun otherVendorsStillRequireProactiveBonding() {
        assertTrue(BondPolicy.requiresProactiveBond("Aqualung", "i300C"))
        assertTrue(BondPolicy.requiresProactiveBond("Mares", "Genius"))
        assertTrue(BondPolicy.requiresProactiveBond("Suunto", "EON Steel"))
    }

    @Test
    fun unknownOrEmptyVendorDefaultsToBonding() {
        assertTrue(BondPolicy.requiresProactiveBond("", ""))
        assertTrue(BondPolicy.requiresProactiveBond("NoSuchVendor", "DSX"))
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
        assertFalse(BondPolicy.bondFailureAbortsDownload("Apeks"))
    }
}
