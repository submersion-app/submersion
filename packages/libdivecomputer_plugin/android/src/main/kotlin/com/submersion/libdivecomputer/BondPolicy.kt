package com.submersion.libdivecomputer

// Decides whether the Android BLE download path should proactively bond
// (BluetoothDevice.createBond) with a dive computer before starting I/O.
//
// Most vendors keep the proactive bond: devices using encrypted BLE
// services (e.g. Aqualung i300C on the Pelagic service) have to pair
// eventually, and bonding up front puts the system pairing dialog in
// front of the user before the transfer starts rather than part-way
// through it. Shearwater's protocol uses no encrypted characteristics --
// Shearwater Cloud connects without pairing -- and a bond created by
// Submersion blocks Shearwater Cloud from connecting until the user
// unpairs the computer in Android Bluetooth settings (issue #910).
//
// Skipping the proactive bond cannot strand a download: if a device does
// demand encryption mid-session, the Android stack pairs transparently
// during the first encrypted GATT operation (see
// BleIoStream.connectAndDiscover).
object BondPolicy {
    private val vendorsWithoutProactiveBond = setOf("shearwater")

    // vendor is the libdivecomputer descriptor vendor string
    // (DiscoveredDevice.vendor), e.g. "Shearwater" for Petrel, Perdix,
    // Teric, Nerd, Peregrine, and Tern models.
    fun requiresProactiveBond(vendor: String): Boolean =
        vendor.trim().lowercase() !in vendorsWithoutProactiveBond

    // Whether a proactive bond that did not complete should end the
    // download. It never should, for any vendor.
    //
    // The bond attempt runs only after connectAndDiscover() has succeeded,
    // so a failure here throws away a link that is already connected and
    // whose services and write characteristic have already been resolved.
    // Nothing in libdivecomputer's BLE protocols needs a bond: the Apple,
    // Linux, and Windows backends never pair at all and download the same
    // computers, and a peripheral that does demand encryption gets it
    // anyway -- the Android stack pairs transparently during the first
    // encrypted GATT operation, which is the same reasoning that makes
    // skipping the bond safe for Shearwater above.
    //
    // Treating the bond as a hard prerequisite instead cost a tester every
    // download attempt on a connection that had already been established
    // (issue #1029).
    //
    // Parameterised by vendor so that hardware evidence for a specific
    // vendor can reintroduce a hard requirement without reopening the
    // question for every other computer.
    @Suppress("UNUSED_PARAMETER")
    fun bondFailureAbortsDownload(vendor: String): Boolean = false
}
