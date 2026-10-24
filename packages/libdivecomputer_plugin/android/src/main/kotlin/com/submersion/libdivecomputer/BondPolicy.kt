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
// The Pelagic i330R family (Apeks DSX, Aqualung i330R and i330R Console)
// authenticates inside its own protocol instead: libdivecomputer asks the
// computer for access, the computer shows a six-digit code, and the user
// types it into Submersion's PIN dialog (DC_IOCTL_BLE_GET_PINCODE).
// createBond() raised Android's system pairing dialog asking for a
// four-digit PIN the computer never shows, and held the download for up
// to 30 seconds before libdivecomputer could ask for access at all
// (issue #3546). Exempted by product, not vendor: the Aqualung computers
// in the Oceanic Atom2 family keep the bond.
//
// Skipping the proactive bond cannot strand a download: if a device does
// demand encryption mid-session, the Android stack pairs transparently
// during the first encrypted GATT operation (see
// BleIoStream.connectAndDiscover).
object BondPolicy {
    private val vendorsWithoutProactiveBond = setOf("shearwater")

    // (vendor, product) pairs, lowercased, as libdivecomputer's
    // descriptor.c spells them for DC_FAMILY_PELAGIC_I330R. BondPolicyTest
    // reads descriptor.c and fails if a product joins or leaves that family.
    internal val productsWithoutProactiveBond = setOf(
        "apeks" to "dsx",
        "aqualung" to "i330r",
        "aqualung" to "i330r console",
    )

    // vendor and product are the libdivecomputer descriptor strings
    // (DiscoveredDevice.vendor / .product), e.g. "Shearwater" for Petrel,
    // Perdix, Teric, Nerd, Peregrine, and Tern models, or "Apeks" / "DSX".
    fun requiresProactiveBond(vendor: String, product: String): Boolean {
        val v = vendor.trim().lowercase()
        val p = product.trim().lowercase()
        return v !in vendorsWithoutProactiveBond &&
            (v to p) !in productsWithoutProactiveBond
    }

    // The download path's entry point. It reads the descriptor product,
    // never the advertised BLE name (DiscoveredDevice.name), which carries
    // a serial suffix and would match no exemption.
    fun requiresProactiveBond(device: DiscoveredDevice): Boolean =
        requiresProactiveBond(device.vendor, device.product)

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
