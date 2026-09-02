package com.submersion.libdivecomputer

// Explains why a GATT connection produced no usable serial characteristics.
//
// A Shearwater Petrel 2 owner reported "Failed to connect to device" and
// sent a debug log whose whole account of the failure was
// "connectAndDiscover: connected=true writeChar=null credits=0
// result=false" (issue #957). The link was up and the MTU had been
// negotiated, so the failure was somewhere in service discovery -- but
// every branch that leaves writeCharacteristic null returned silently:
// a discovery the stack refused returned early on its status, and a
// discovery that produced no service with both a write and a notify
// characteristic simply fell through. The two are different bugs with
// different fixes and the log could not tell them apart.
//
// Framework-free so it can run as a JVM unit test; the Android GATT
// constants are duplicated here rather than referenced, as BondDiagnostics
// does for the bond states and BleScanDiagnostics for the scan failures.
object GattDiagnostics {

    // Mirrors android.bluetooth.BluetoothDevice device types.
    const val DEVICE_TYPE_UNKNOWN = 0
    const val DEVICE_TYPE_CLASSIC = 1
    const val DEVICE_TYPE_LE = 2
    const val DEVICE_TYPE_DUAL = 3

    // A BluetoothGattCallback status is read in one of two disjoint number
    // spaces, and they collide. An operation callback (onServicesDiscovered,
    // onDescriptorWrite, onCharacteristicRead/Write) carries an ATT protocol
    // error; onConnectionStateChange carries an HCI connection error passed
    // through unchanged. Both define 8: ATT 0x08 is insufficient
    // authorization, HCI 0x08 is connection timeout. Describing one with the
    // other's table does not degrade to a vague answer, it produces a
    // confident wrong one, so the two tables are kept apart and each
    // describer names the space it reads.

    // ATT protocol errors (Bluetooth core spec vol 3 part F 3.4.1.1, mirrored
    // in stack/include/gatt_api.h). GATT_SUCCESS and a handful of these are
    // public API on android.bluetooth.BluetoothGatt; the rest are stable.
    const val GATT_SUCCESS = 0
    const val ATT_INVALID_HANDLE = 1
    const val ATT_READ_NOT_PERMITTED = 2
    const val ATT_WRITE_NOT_PERMITTED = 3
    const val ATT_INSUFFICIENT_AUTHENTICATION = 5
    const val ATT_REQUEST_NOT_SUPPORTED = 6
    const val ATT_INVALID_OFFSET = 7
    const val ATT_INSUFFICIENT_AUTHORIZATION = 8
    const val ATT_ATTRIBUTE_NOT_FOUND = 10
    const val ATT_INSUFFICIENT_KEY_SIZE = 12
    const val ATT_INVALID_ATTRIBUTE_LENGTH = 13
    const val ATT_INSUFFICIENT_ENCRYPTION = 15

    // HCI connection errors, as delivered to onConnectionStateChange.
    const val CONN_TIMEOUT = 8
    const val CONN_TERMINATE_PEER_USER = 19
    const val CONN_TERMINATE_LOCAL_HOST = 22
    const val CONN_LMP_TIMEOUT = 34
    const val CONN_FAIL_ESTABLISH = 62
    const val CONN_AUTH_FAILURE = 137
    const val CONN_TIMEOUT_HCI = 147

    // Reported in both spaces.
    const val GATT_INTERNAL_ERROR = 129
    const val GATT_ERROR = 133
    const val GATT_CONN_CANCEL = 256
    const val GATT_FAILURE = 257

    /**
     * Human-readable name for a BluetoothDevice.getType() value.
     *
     * The distinction matters: a dual-mode radio is reached over Bluetooth
     * Classic by default, and a computer that serves its serial bridge only
     * over LE then answers service discovery with nothing.
     */
    fun describeDeviceType(type: Int): String = when (type) {
        DEVICE_TYPE_CLASSIC -> "Bluetooth Classic only"
        DEVICE_TYPE_LE -> "LE only"
        DEVICE_TYPE_DUAL -> "dual-mode (Bluetooth Classic + LE)"
        DEVICE_TYPE_UNKNOWN -> "unknown to the Bluetooth stack"
        else -> "unrecognized device type ($type)"
    }

    /**
     * Names the transport a connect actually ran on.
     *
     * Written from the same flag that picks the connectGatt overload so the
     * two cannot drift: a line that claimed LE while the call fell back to
     * TRANSPORT_AUTO would misreport the one fact this instrumentation
     * exists to establish.
     */
    fun describeTransport(leRequested: Boolean): String =
        if (leRequested) "LE" else "AUTO (LE cannot be demanded below API 23)"

    /**
     * Reason for a status delivered by an ATT operation callback, such as
     * [android.bluetooth.BluetoothGattCallback.onServicesDiscovered].
     *
     * Do not use for onConnectionStateChange: see [describeConnectionStatus]
     * and the note on the constants above for the codes that collide.
     */
    fun describeAttStatus(status: Int): String = when (status) {
        GATT_SUCCESS ->
            "success"
        ATT_INVALID_HANDLE ->
            "the computer rejected the handle as invalid"
        ATT_READ_NOT_PERMITTED ->
            "the computer does not permit reading that attribute"
        ATT_WRITE_NOT_PERMITTED ->
            "the computer does not permit writing that attribute"
        ATT_INSUFFICIENT_AUTHENTICATION ->
            "insufficient authentication; the stored pairing keys are stale " +
                "or the computer demanded encryption"
        ATT_REQUEST_NOT_SUPPORTED ->
            "the computer does not support that request"
        ATT_INVALID_OFFSET ->
            "the computer rejected the offset as invalid"
        ATT_INSUFFICIENT_AUTHORIZATION ->
            "insufficient authorization; usually a bond problem, so removing " +
                "the pairing on both sides and pairing again is the first " +
                "thing to try"
        ATT_ATTRIBUTE_NOT_FOUND ->
            "the computer reported no such attribute"
        ATT_INSUFFICIENT_KEY_SIZE ->
            "the negotiated encryption key is too short for that attribute"
        ATT_INVALID_ATTRIBUTE_LENGTH ->
            "the computer rejected the attribute length"
        ATT_INSUFFICIENT_ENCRYPTION ->
            "the attribute needs an encrypted link and this one is not"
        GATT_INTERNAL_ERROR ->
            "internal Bluetooth stack error"
        GATT_ERROR ->
            "generic GATT error; usually the computer refused the operation " +
                "or the link was not usable for it"
        GATT_CONN_CANCEL ->
            "the connection attempt was cancelled"
        GATT_FAILURE ->
            "the operation failed"
        else ->
            "unknown ATT status ($status)"
    }

    /**
     * Reason for a status delivered by
     * [android.bluetooth.BluetoothGattCallback.onConnectionStateChange],
     * which reads in the HCI connection space rather than the ATT one.
     */
    fun describeConnectionStatus(status: Int): String = when (status) {
        GATT_SUCCESS ->
            "success"
        CONN_TIMEOUT ->
            "the connection timed out; the computer moved out of range or " +
                "switched its radio off"
        CONN_TERMINATE_PEER_USER ->
            "the computer closed the connection"
        CONN_TERMINATE_LOCAL_HOST ->
            "this phone closed the connection"
        CONN_LMP_TIMEOUT ->
            "the computer stopped answering the radio link"
        CONN_FAIL_ESTABLISH ->
            "the connection could not be established"
        CONN_AUTH_FAILURE ->
            "authentication failed; the pairing keys are stale on one side"
        CONN_TIMEOUT_HCI ->
            "the connection could not be established before the radio gave up"
        GATT_INTERNAL_ERROR ->
            "internal Bluetooth stack error"
        GATT_ERROR ->
            "generic GATT error; on a connect this is usually a stale bond " +
                "or a computer that is not advertising"
        GATT_CONN_CANCEL ->
            "the connection attempt was cancelled"
        GATT_FAILURE ->
            "the operation failed"
        else ->
            "unknown connection status ($status)"
    }

    /**
     * Message for a service discovery the stack refused, naming the radio
     * the computer was reached on.
     *
     * A dual-mode computer earns an extra clause naming the trap behind
     * #957: under TRANSPORT_AUTO Android connects such a radio over
     * Bluetooth Classic, where a GATT server that exists only on the LE
     * radio is invisible.
     *
     * Phrased as a lead to check rather than a verdict. This build already
     * demands TRANSPORT_LE, so on a current log the transport is not the
     * explanation, and a dual-mode radio fails discovery for the same
     * ordinary reasons any other radio does: an unstable link, an ATT
     * error, a computer that dropped out of upload mode. Pointing the
     * reader at the connect line keeps the addendum useful without
     * pre-deciding the diagnosis for them.
     */
    fun describeDiscoveryFailure(status: Int, deviceType: Int): String {
        val base = "Service discovery failed: status=$status " +
            "(${describeAttStatus(status)}); the computer's radio is " +
            describeDeviceType(deviceType)
        if (deviceType != DEVICE_TYPE_DUAL) return base
        return "$base. Dual-mode is a known trap: under TRANSPORT_AUTO " +
            "Android connects such a radio over Bluetooth Classic, where " +
            "an LE-only GATT server is invisible. Check the transport on " +
            "the connect line above before assuming that is the cause " +
            "here; an unstable link or an ATT error fails discovery too"
    }

    /**
     * Message for a subscription whose CCCD write was never issued: the
     * characteristic carries no CCCD, or the local stack refused to queue
     * the write. Nothing reached the computer, so there is no ATT status to
     * report and none is claimed.
     *
     * Shared by both sites that start a subscription, the first one in
     * onServicesDiscovered and the Data TX one that a credit-flow device
     * starts from onDescriptorWrite instead.
     */
    const val SUBSCRIPTION_NOT_STARTED =
        "Notification subscription could not be started; the connection " +
            "cannot carry a serial session"

    /**
     * Message for a Data TX CCCD write the computer accepted and then
     * completed with a failure status.
     *
     * This is the other half of [SUBSCRIPTION_NOT_STARTED] and has to read
     * differently: there the write never left this phone, while here the
     * computer answered and refused, so the ATT status is its own account
     * of why. Either way the peripheral sends nothing and every
     * libdivecomputer read blocks to timeout.
     */
    fun describeDataSubscriptionFailure(status: Int): String =
        "Data TX notification subscription failed: status=$status " +
            "(${describeAttStatus(status)}); the computer will send nothing, " +
            "so the connection cannot carry a serial session"

    /**
     * The Terminal I/O twin of [describeDataSubscriptionFailure], for the
     * Credits TX subscription that is written first.
     *
     * Only reached on a module that requires credit flow control, which
     * keeps its UART bridge closed until the subscription exists (#923):
     * that failure is terminal rather than something to run without. A
     * u-blox module, where flow control is optional, never comes here; it
     * abandons credits and carries on, which is a warning, not an error.
     */
    fun describeCreditsSubscriptionFailure(status: Int): String =
        "Terminal I/O: Credits TX subscription failed: status=$status " +
            "(${describeAttStatus(status)}); the module keeps its UART " +
            "bridge closed without it, so no command can reach the computer"

    /**
     * Message for a discovery that completed but exposed no service
     * carrying both a write and a notify/indicate characteristic, which is
     * the pair the serial bridge needs.
     *
     * An empty list is reported in its own words: no services at all means
     * the connection was not really usable, while a populated list that
     * still yields no pair means the computer is exposing something this
     * build does not know how to drive, and the UUIDs are what a new
     * descriptor would be written from.
     */
    fun describeNoUsableService(serviceUuids: List<String>): String {
        if (serviceUuids.isEmpty()) {
            return "Service discovery succeeded but the computer reported " +
                "no services at all"
        }
        return "No discovered service carries both a write and a notify " +
            "characteristic; ${serviceUuids.size} service(s) seen: " +
            serviceUuids.joinToString(", ")
    }
}
