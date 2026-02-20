package com.submersion.libdivecomputer

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context

// Transport bitmask values matching libdc_wrapper.h.
private const val LIBDC_TRANSPORT_BLE = 1 shl 5

// Scans for BLE dive computers using Android's BluetoothLeScanner
// and matches discovered devices against libdivecomputer's descriptor database.
class BleScanner(private val context: Context) {
    private var scanCallback: ScanCallback? = null
    private val seenAddresses = mutableSetOf<String>()

    var onDeviceDiscovered: ((DiscoveredDevice) -> Unit)? = null
    var onComplete: (() -> Unit)? = null

    fun start() {
        seenAddresses.clear()
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
                if (!matched) return

                seenAddresses.add(address)

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
