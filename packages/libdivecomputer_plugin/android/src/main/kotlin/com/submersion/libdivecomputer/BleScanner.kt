package com.submersion.libdivecomputer

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context

// Transport bitmask values matching libdc_wrapper.h.
private const val LIBDC_TRANSPORT_BLE = 1 shl 5

// Scans for BLE dive computers using Android's BluetoothLeScanner
// and matches discovered devices against libdivecomputer's descriptor database.
// Bluetooth permissions are requested at the Dart layer before these methods are called.
@SuppressLint("MissingPermission")
class BleScanner(private val context: Context) {
    private var scanCallback: ScanCallback? = null
    private val seenAddresses = mutableSetOf<String>()
    private val loggedUnmatched = mutableSetOf<String>()

    var onDeviceDiscovered: ((DiscoveredDevice) -> Unit)? = null
    var onComplete: (() -> Unit)? = null

    fun start() {
        seenAddresses.clear()
        loggedUnmatched.clear()
        val bluetoothManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager ?: return
        val adapter = bluetoothManager.adapter ?: return
        val scanner = adapter.bluetoothLeScanner ?: return

        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val address = result.device.address ?: return
                if (seenAddresses.contains(address)) return

                val name = result.scanRecord?.deviceName
                    ?: result.device.name
                    ?: return

                val info = DescriptorInfo()
                val matched = LibdcWrapper.nativeDescriptorMatch(
                    name, LIBDC_TRANSPORT_BLE, info
                )
                if (!matched) {
                    // onScanResult redelivers every advertisement packet, so
                    // log each unmatched device only once per scan session.
                    if (loggedUnmatched.add(address)) {
                        NativeLogger.d(
                            "BleScanner", "BLE",
                            "Unmatched device $address ($name)"
                        )
                    }
                    return
                }

                seenAddresses.add(address)
                NativeLogger.d(
                    "BleScanner", "BLE",
                    "Matched device $address ($name) -> " +
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
                onComplete?.invoke()
            }
        }

        scanCallback = callback
        scanner.startScan(callback)
    }

    fun stop() {
        val bluetoothManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager ?: return
        val scanner = bluetoothManager.adapter?.bluetoothLeScanner ?: return

        scanCallback?.let { scanner.stopScan(it) }
        scanCallback = null
        onComplete?.invoke()
    }
}
