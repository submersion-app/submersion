package com.submersion.libdivecomputer

// Builds the debug-log messages for BLE advertisements that the scanner
// declines to surface, and rate-limits them to one line per distinct
// sighting (issue #123).
//
// Android redelivers an advertisement packet every scan interval, so the
// raw callback fires many times per second per device. Without the
// bookkeeping here, logging every skipped device would flood the log file
// and rotate away the very lines a bug report needs. Without logging them
// at all -- the previous behaviour -- an unsupported dive computer left no
// trace whatsoever, and the owner of a Suunto Ocean could not produce the
// advertised name that adding a descriptor requires.
//
// Framework-free so it can run as a JVM unit test; the Android scan-result
// types are not constructible outside an instrumented test.
class BleScanDiagnostics {

    // Keyed by address *and* name: a peripheral that omits its local name
    // from the initial advertisement and supplies it in the scan response
    // must log a second time, once the name is known.
    private val loggedSightings = mutableSetOf<String>()

    /** Clears per-session state so a new scan logs every device again. */
    fun reset() {
        loggedSightings.clear()
    }

    /**
     * Message for a device whose advertised [name] matched no descriptor,
     * or null if this sighting was already logged during this scan.
     */
    fun describeUnmatched(address: String, name: String, rssi: Int): String? {
        if (!loggedSightings.add("$address|$name")) return null
        return "Unmatched device $address ($name) rssi=$rssi"
    }

    /**
     * Message for a device that advertised no readable name, or null if
     * this sighting was already logged during this scan.
     *
     * These cannot be matched at all: libdivecomputer identifies BLE dive
     * computers by name prefix, so a nameless advertisement is unusable
     * even when it comes from a supported model.
     */
    fun describeUnnamed(address: String, rssi: Int): String? {
        if (!loggedSightings.add("$address|")) return null
        return "Unnamed device $address rssi=$rssi (no advertised name; cannot match descriptor)"
    }

    /**
     * Message for an advertisement that carried no device address, or null
     * if one was already reported during this scan.
     *
     * There is no per-device key to deduplicate these on, so they are
     * collapsed to a single line per scan rather than left unthrottled.
     */
    fun describeAddressless(): String? {
        if (!loggedSightings.add(ADDRESSLESS_KEY)) return null
        return "Skipped advertisement with no device address"
    }

    companion object {
        // Not a valid "address|name" key, so it cannot collide with a device.
        private const val ADDRESSLESS_KEY = "<addressless>"

        /**
         * The usable advertised name for a scan result, or null if the device
         * supplied none.
         *
         * A zero-length Complete Local Name AD field surfaces as `""` rather
         * than being omitted, and the cached [android.bluetooth.BluetoothDevice]
         * name can be empty too. Both must count as absent: an empty string
         * would be matched against the descriptor table as an empty prefix,
         * logged as a nameless `(...)`, and -- because the dedupe key is
         * `address|name` -- would collide with the key used for devices that
         * advertised no name at all.
         */
        fun resolveName(scanRecordName: String?, deviceName: String?): String? =
            scanRecordName?.takeIf { it.isNotEmpty() }
                ?: deviceName?.takeIf { it.isNotEmpty() }

        // Mirrors android.bluetooth.le.ScanCallback. Duplicated rather than
        // referenced so this class stays free of Android imports.
        const val SCAN_FAILED_ALREADY_STARTED = 1
        const val SCAN_FAILED_APPLICATION_REGISTRATION_FAILED = 2
        const val SCAN_FAILED_INTERNAL_ERROR = 3
        const val SCAN_FAILED_FEATURE_UNSUPPORTED = 4
        const val SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES = 5
        const val SCAN_FAILED_SCANNING_TOO_FREQUENTLY = 6

        /** Human-readable reason for a ScanCallback.onScanFailed code. */
        fun describeScanFailure(errorCode: Int): String = when (errorCode) {
            SCAN_FAILED_ALREADY_STARTED ->
                "scan already started"
            SCAN_FAILED_APPLICATION_REGISTRATION_FAILED ->
                "app could not be registered with the Bluetooth stack"
            SCAN_FAILED_INTERNAL_ERROR ->
                "internal Bluetooth stack error"
            SCAN_FAILED_FEATURE_UNSUPPORTED ->
                "BLE scanning unsupported on this device"
            SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES ->
                "out of Bluetooth hardware resources"
            SCAN_FAILED_SCANNING_TOO_FREQUENTLY ->
                "scanning started too frequently; Android is throttling scans"
            else ->
                "unknown scan failure (code $errorCode)"
        }
    }
}
