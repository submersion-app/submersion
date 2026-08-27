package com.submersion.libdivecomputer

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context

// Transport bitmask values matching libdc_wrapper.h.
private const val LIBDC_TRANSPORT_BLE = 1 shl 5

private const val TAG = "BleScanner"

// Scans for BLE dive computers using Android's BluetoothLeScanner
// and matches discovered devices against libdivecomputer's descriptor database.
// Bluetooth permissions are requested at the Dart layer before these methods are called.
//
// Every path that declines to surface a device logs why (issue #123). An
// unsupported model is indistinguishable from a dead scan otherwise, which
// is what stalled the Suunto Ocean report: the owner was asked for the
// "Unmatched device" line twice and could not produce it, because the
// branches ahead of it all returned silently.
@SuppressLint("MissingPermission")
class BleScanner(private val context: Context) {
    private var scanCallback: ScanCallback? = null
    private val seenAddresses = mutableSetOf<String>()
    private val diagnostics = BleScanDiagnostics()

    var onDeviceDiscovered: ((DiscoveredDevice) -> Unit)? = null
    var onComplete: (() -> Unit)? = null

    fun start() {
        seenAddresses.clear()
        diagnostics.reset()

        val bluetoothManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        if (bluetoothManager == null) {
            NativeLogger.e(TAG, "BLE", "Scan aborted: no Bluetooth service on this device")
            onComplete?.invoke()
            return
        }

        val adapter = bluetoothManager.adapter
        if (adapter == null) {
            NativeLogger.e(TAG, "BLE", "Scan aborted: device has no Bluetooth adapter")
            onComplete?.invoke()
            return
        }

        // A disabled adapter yields a null scanner, which previously looked
        // identical to a scan that simply found nothing.
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            val state = if (adapter.state == BluetoothAdapter.STATE_OFF) {
                "Bluetooth is turned off"
            } else {
                "adapter state=${adapter.state}"
            }
            NativeLogger.e(TAG, "BLE", "Scan aborted: no BLE scanner ($state)")
            onComplete?.invoke()
            return
        }

        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val address = result.device.address
                if (address == null) {
                    diagnostics.describeAddressless()?.let {
                        NativeLogger.d(TAG, "BLE", it)
                    }
                    return
                }
                if (seenAddresses.contains(address)) return

                val rssi = result.rssi

                // Peripherals may advertise without a local name and only
                // supply one in the scan response, so an absent name here is
                // not necessarily permanent -- later packets are re-evaluated.
                val name = BleScanDiagnostics.resolveName(
                    result.scanRecord?.deviceName,
                    result.device.name
                )
                if (name == null) {
                    diagnostics.describeUnnamed(address, rssi)?.let {
                        NativeLogger.d(TAG, "BLE", it)
                    }
                    return
                }

                val info = DescriptorInfo()
                val matched = LibdcWrapper.nativeDescriptorMatch(
                    name, LIBDC_TRANSPORT_BLE, info
                )
                if (!matched) {
                    diagnostics.describeUnmatched(address, name, rssi)?.let {
                        NativeLogger.d(TAG, "BLE", it)
                    }
                    return
                }

                seenAddresses.add(address)
                NativeLogger.i(
                    TAG, "BLE",
                    "Matched device $address ($name) rssi=$rssi -> " +
                        "${info.vendor} ${info.product} (${info.model})"
                )

                val device = DiscoveredDevice(
                    vendor = info.vendor,
                    product = info.product,
                    model = info.model.toLong(),
                    address = address,
                    name = name,
                    transport = TransportType.BLE
                )
                onDeviceDiscovered?.invoke(device)
            }

            override fun onScanFailed(errorCode: Int) {
                NativeLogger.e(
                    TAG, "BLE",
                    "Scan failed: ${BleScanDiagnostics.describeScanFailure(errorCode)}"
                )
                onComplete?.invoke()
            }
        }

        scanCallback = callback

        // The no-argument startScan overload uses SCAN_MODE_LOW_POWER, whose
        // low duty cycle can take tens of seconds to notice a peripheral --
        // or miss it for the length of a scan. This scan is short-lived,
        // foreground, and user-initiated, which is exactly what LOW_LATENCY
        // is for; vendor apps scan the same way.
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        NativeLogger.i(TAG, "BLE", "Starting BLE scan (mode=low latency)")
        try {
            scanner.startScan(null, settings, callback)
        } catch (e: Exception) {
            // The adapter can be switched off between the null check above and
            // this call, and revoked permissions surface here too. Nothing is
            // registered when this throws, so drop the callback rather than
            // leave it for the next start() to overwrite. The exception still
            // propagates: DiveComputerHostApiImpl turns it into the error the
            // user sees.
            scanCallback = null
            NativeLogger.e(
                TAG, "BLE",
                "Scan could not be started: ${e.javaClass.simpleName}: ${e.message}"
            )
            onComplete?.invoke()
            throw e
        }
    }

    // Always releases the callback and signals completion, including when the
    // system scanner has become unreachable -- Bluetooth switched off during a
    // scan makes bluetoothLeScanner null. Returning early there would strand
    // scanCallback, and the next start() would overwrite it while the old
    // registration was still outstanding.
    fun stop() {
        val callback = scanCallback
        scanCallback = null

        val scanner = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)
            ?.adapter
            ?.bluetoothLeScanner

        if (callback != null) {
            if (scanner != null) {
                // stopScan throws in some adapter state transitions. Letting it
                // escape would skip onComplete below and, because the Dart
                // stopScan() clears isScanning only after awaiting this call,
                // strand the wizard on "scanning" -- the failure this change
                // exists to remove. Report it and finish the teardown.
                try {
                    scanner.stopScan(callback)
                    NativeLogger.i(
                        TAG, "BLE",
                        "Stopped BLE scan; ${seenAddresses.size} supported device(s) found"
                    )
                } catch (e: Exception) {
                    NativeLogger.w(
                        TAG, "BLE",
                        "Stopping the BLE scan failed: " +
                            "${e.javaClass.simpleName}: ${e.message}"
                    )
                }
            } else {
                NativeLogger.w(
                    TAG, "BLE",
                    "Stopped BLE scan without unregistering: Bluetooth became unavailable"
                )
            }
        }

        onComplete?.invoke()
    }
}
