package com.submersion.libdivecomputer

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

// Client Characteristic Configuration Descriptor UUID for enabling notifications.
private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

// Preferred UUIDs for characteristic selection scoring (matching Darwin BleIoStream).
// These ensure devices like Aqualung/Oceanic select the correct write and notify
// characteristics when the service has multiple write-capable chars.
private val PREFERRED_SERVICE_UUIDS = setOf(
    UUID.fromString("cb3c4555-d670-4670-bc20-b61dbc851e9a")
)
private val PREFERRED_WRITE_UUIDS = setOf(
    UUID.fromString("6606ab42-89d5-4a00-a8ce-4eb5e1414ee0")
)
private val PREFERRED_NOTIFY_UUIDS = setOf(
    UUID.fromString("a60b8e5c-b267-44d7-9764-837caf96489e")
)

// Bridges Android BLE GATT communication to libdivecomputer's synchronous
// I/O interface using semaphores.
//
// libdivecomputer calls read/write synchronously on a background thread.
// This class translates those calls to async BluetoothGatt operations,
// blocking with semaphores until the BLE operation completes.
// Bluetooth permissions are requested at the Dart layer before these methods are called.
@SuppressLint("MissingPermission")
class BleIoStream(
    private val context: Context,
    private val device: BluetoothDevice
) : BleIoHandler {

    companion object {
        private const val TAG = "BleIoStream"
    }

    private var gatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null

    private val readQueue = LinkedBlockingQueue<ByteArray>()
    private val writeSemaphore = Semaphore(0)
    private val connectSemaphore = Semaphore(0)
    private var connected = false
    private var readBuffer = ByteArray(0)

    private val pinSemaphore = Semaphore(0)
    private var pendingPinCode: String? = null

    /// Callback invoked when PIN is needed. Set by HostApiImpl.
    var onPinRequired: ((String) -> Unit)? = null

    // GATT status from the most recent disconnect. Exposed so that callers
    // can detect stale bond keys (status 5 = GATT_INSUFFICIENT_AUTHENTICATION).
    var lastDisconnectStatus = 0
        private set

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(
            gatt: BluetoothGatt, status: Int, newState: Int
        ) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connected = true
                // Request a larger MTU before discovering services.
                // Android defaults to 23 bytes (20 payload); CoreBluetooth
                // negotiates automatically but Android requires an explicit call.
                gatt.requestMtu(512)
            } else {
                connected = false
                lastDisconnectStatus = status
                Log.d(TAG, "onConnectionStateChange: disconnected status=$status")
                connectSemaphore.release()
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            Log.d(TAG, "onMtuChanged: mtu=$mtu status=$status")
            // MTU negotiation complete; now discover services.
            gatt.discoverServices()
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                connectSemaphore.release()
                return
            }

            // Score-based characteristic selection (mirrors Darwin BleIoStream).
            // Write and notify/indicate chars are scored independently so that
            // devices with separate write and notify characteristics (e.g.
            // Aqualung i300C) select the correct pair rather than picking a
            // single combined characteristic for both.
            var bestServiceScore = -1
            var bestWrite: BluetoothGattCharacteristic? = null
            var bestNotify: BluetoothGattCharacteristic? = null

            for (service in gatt.services) {
                Log.d(TAG, "Service: ${service.uuid}")
                var serviceWrite: BluetoothGattCharacteristic? = null
                var serviceWriteScore = -1
                var serviceNotify: BluetoothGattCharacteristic? = null
                var serviceNotifyScore = -1

                for (char in service.characteristics) {
                    val props = char.properties
                    Log.d(TAG, "  Char: ${char.uuid} props=0x${props.toString(16)} descriptors=${char.descriptors.size}")

                    // Score write candidates.
                    if (props and BluetoothGattCharacteristic.PROPERTY_WRITE != 0 ||
                        props and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
                    ) {
                        var ws = 0
                        if (props and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) ws += 4
                        if (props and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) ws += 2
                        if (PREFERRED_WRITE_UUIDS.contains(char.uuid)) ws += 1000
                        if (ws > serviceWriteScore) {
                            serviceWrite = char
                            serviceWriteScore = ws
                        }
                    }

                    // Score notify/indicate candidates.
                    if (props and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0 ||
                        props and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
                    ) {
                        var ns = 0
                        if (props and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) ns += 4
                        if (props and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) ns += 2
                        if (PREFERRED_NOTIFY_UUIDS.contains(char.uuid)) ns += 1000
                        if (ns > serviceNotifyScore) {
                            serviceNotify = char
                            serviceNotifyScore = ns
                        }
                    }
                }

                if (serviceWrite != null && serviceNotify != null) {
                    var score = serviceWriteScore + serviceNotifyScore
                    if (PREFERRED_SERVICE_UUIDS.contains(service.uuid)) score += 1000
                    if (score > bestServiceScore) {
                        bestServiceScore = score
                        bestWrite = serviceWrite
                        bestNotify = serviceNotify
                    }
                }
            }

            var startedDescriptorWrite = false
            if (bestWrite != null && bestNotify != null) {
                Log.d(TAG, "Data service selected (score=$bestServiceScore)")
                Log.d(TAG, "  write=${bestWrite.uuid} notify=${bestNotify.uuid}")
                writeCharacteristic = bestWrite
                gatt.setCharacteristicNotification(bestNotify, true)
                val descriptor = bestNotify.getDescriptor(CCCD_UUID)
                Log.d(TAG, "  CCCD descriptor: ${descriptor?.uuid ?: "NULL"}")
                if (descriptor != null) {
                    // Use ENABLE_INDICATION_VALUE for INDICATE-only chars,
                    // ENABLE_NOTIFICATION_VALUE otherwise.
                    descriptor.value = if (
                        bestNotify.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY == 0 &&
                        bestNotify.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
                    ) {
                        BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                    } else {
                        BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    }
                    startedDescriptorWrite = gatt.writeDescriptor(descriptor)
                    Log.d(TAG, "  writeDescriptor returned: $startedDescriptorWrite")
                }
            }

            // If a CCCD descriptor write was started, wait for
            // onDescriptorWrite before signalling ready. Otherwise
            // the download may call writeCharacteristic while the
            // descriptor write is still in flight, which silently fails.
            if (!startedDescriptorWrite) {
                connectSemaphore.release()
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            Log.d(TAG, "onDescriptorWrite: ${descriptor.uuid} status=$status")
            // CCCD write completed; notification subscription is active
            // on the remote device and GATT is free for I/O.
            connectSemaphore.release()
        }

        // API 33+ delivers notification data via this 3-parameter overload.
        // The old 2-parameter version is never called on API 33+ devices.
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            Log.d(TAG, "onCharacteristicChanged(API33+): ${value.size} bytes")
            readQueue.offer(value)
        }

        // Pre-API 33 fallback: notification data is on characteristic.value.
        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val value = characteristic.value ?: return
            Log.d(TAG, "onCharacteristicChanged(legacy): ${value.size} bytes")
            readQueue.offer(value)
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            writeSemaphore.release()
        }
    }

    // Connect to the BLE device and discover services.
    // Blocks until ready or timeout. Returns true on success.
    //
    // Does NOT pre-bond. If the device requires encryption, the Android
    // BLE stack will handle pairing transparently during the first
    // encrypted GATT operation (Just Works or PIN dialog). Pre-bonding
    // with createBond() doesn't work reliably for many BLE peripherals
    // because they won't respond to pairing requests without an active
    // GATT connection.
    fun connectAndDiscover(): Boolean {
        gatt = device.connectGatt(context, false, gattCallback)
        if (!connectSemaphore.tryAcquire(15, TimeUnit.SECONDS)) {
            Log.e(TAG, "connectAndDiscover: semaphore timeout")
            return false
        }
        val ok = connected && writeCharacteristic != null
        Log.d(TAG, "connectAndDiscover: connected=$connected writeChar=${writeCharacteristic?.uuid} result=$ok")
        return ok
    }

    // Ensure the device is bonded before starting I/O. Called AFTER
    // connectAndDiscover() so there is an active GATT connection.
    // If the device is already bonded, returns immediately.
    // Otherwise calls createBond() and blocks until the user accepts
    // the pairing dialog (or timeout). Needs an active connection
    // because many BLE peripherals ignore pairing requests without one.
    fun ensureBonded(): Boolean {
        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            Log.d(TAG, "ensureBonded: already bonded")
            return true
        }

        Log.d(TAG, "ensureBonded: initiating bonding for ${device.address}")
        val bondSemaphore = Semaphore(0)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
                val bondDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(
                        BluetoothDevice.EXTRA_DEVICE,
                        BluetoothDevice::class.java
                    )
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (bondDevice?.address != device.address) return

                val state = intent.getIntExtra(
                    BluetoothDevice.EXTRA_BOND_STATE,
                    BluetoothDevice.BOND_NONE
                )
                Log.d(TAG, "ensureBonded: bond state changed to $state")
                if (state == BluetoothDevice.BOND_BONDED ||
                    state == BluetoothDevice.BOND_NONE
                ) {
                    bondSemaphore.release()
                }
            }
        }

        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }

        try {
            if (!device.createBond()) {
                Log.e(TAG, "ensureBonded: createBond() returned false")
                return false
            }
            // 30s timeout: user needs time to interact with pairing dialog.
            if (!bondSemaphore.tryAcquire(30, TimeUnit.SECONDS)) {
                Log.e(TAG, "ensureBonded: timeout waiting for bonding")
                return false
            }
            val bonded = device.bondState == BluetoothDevice.BOND_BONDED
            Log.d(TAG, "ensureBonded: result=$bonded")
            return bonded
        } catch (e: Exception) {
            Log.e(TAG, "ensureBonded: failed", e)
            return false
        } finally {
            context.unregisterReceiver(receiver)
        }
    }

    // Remove an existing bond. Used when bond keys are stale: the device
    // reports BOND_BONDED but connections fail with GATT status 5.
    // Uses reflection because BluetoothDevice.removeBond() is hidden API.
    fun removeBond(): Boolean {
        if (device.bondState != BluetoothDevice.BOND_BONDED) {
            Log.d(TAG, "removeBond: not bonded, nothing to remove")
            return true
        }

        Log.d(TAG, "removeBond: removing bond for ${device.address}")
        val bondSemaphore = Semaphore(0)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
                val bondDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(
                        BluetoothDevice.EXTRA_DEVICE,
                        BluetoothDevice::class.java
                    )
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (bondDevice?.address != device.address) return

                val state = intent.getIntExtra(
                    BluetoothDevice.EXTRA_BOND_STATE,
                    BluetoothDevice.BOND_NONE
                )
                Log.d(TAG, "removeBond: bond state changed to $state")
                if (state == BluetoothDevice.BOND_NONE) {
                    bondSemaphore.release()
                }
            }
        }

        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }

        try {
            val method = device.javaClass.getMethod("removeBond")
            val result = method.invoke(device) as Boolean
            if (!result) {
                Log.e(TAG, "removeBond: removeBond() returned false")
                return false
            }
            if (!bondSemaphore.tryAcquire(5, TimeUnit.SECONDS)) {
                Log.e(TAG, "removeBond: timeout waiting for bond removal")
                return false
            }
            val removed = device.bondState == BluetoothDevice.BOND_NONE
            Log.d(TAG, "removeBond: result=$removed")
            return removed
        } catch (e: Exception) {
            Log.e(TAG, "removeBond: failed", e)
            return false
        } finally {
            context.unregisterReceiver(receiver)
        }
    }

    // BleIoHandler implementation - called from native code via JNI.

    override fun read(size: Int, timeoutMs: Int): ByteArray? {
        Log.d(TAG, "read: size=$size timeout=$timeoutMs")

        // Return leftover data from a previous notification first.
        if (readBuffer.isNotEmpty()) {
            val bytesToCopy = minOf(size, readBuffer.size)
            val result = readBuffer.copyOfRange(0, bytesToCopy)
            readBuffer = readBuffer.copyOfRange(bytesToCopy, readBuffer.size)
            return result
        }

        // Wait for exactly one BLE notification. Shearwater's SLIP decoder
        // expects each read to return a single BLE packet (it skips a 2-byte
        // BLE header per read call). Accumulating multiple notifications
        // into one buffer corrupts the SLIP framing.
        val timeout = if (timeoutMs < 0) Long.MAX_VALUE else timeoutMs.toLong()
        val chunk = readQueue.poll(timeout, TimeUnit.MILLISECONDS) ?: return null

        val bytesToCopy = minOf(size, chunk.size)
        val result = chunk.copyOfRange(0, bytesToCopy)
        if (bytesToCopy < chunk.size) {
            readBuffer = chunk.copyOfRange(bytesToCopy, chunk.size)
        }
        return result
    }

    override fun write(data: ByteArray, timeoutMs: Int): Int {
        val char = writeCharacteristic ?: run {
            Log.e(TAG, "write: writeCharacteristic is null")
            return -1
        }
        val g = gatt ?: run {
            Log.e(TAG, "write: gatt is null")
            return -1
        }

        Log.d(TAG, "write: ${data.size} bytes, timeout=$timeoutMs")
        char.value = data
        // Use WRITE_NO_RESPONSE when supported. Many BLE dive computers
        // (including Shearwater) only process WRITE_NO_RESPONSE at the
        // firmware level; WRITE (with response) is ACK'd by the BLE stack
        // but the device firmware silently ignores the payload.
        char.writeType = if (char.properties and
            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
        ) {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }

        if (!g.writeCharacteristic(char)) {
            Log.e(TAG, "write: writeCharacteristic() returned false")
            return -1
        }

        // Always wait for onCharacteristicWrite before returning.
        // Android BLE only allows one GATT operation at a time;
        // without this wait, a subsequent write would fail because
        // the previous one is still in flight.
        val timeout = if (timeoutMs < 0) Long.MAX_VALUE else timeoutMs.toLong()
        if (!writeSemaphore.tryAcquire(timeout, TimeUnit.MILLISECONDS)) return -1

        return data.size
    }

    override fun purge(direction: Int) {
        // Direction 1 = input (read buffer). Clear any stale data
        // so the next protocol exchange starts clean.
        if (direction and 1 != 0) {
            readBuffer = ByteArray(0)
            readQueue.clear()
        }
    }

    override fun close() {
        gatt?.disconnect()
        gatt?.close()
        gatt = null
    }

    override fun onPinCodeRequired(address: String): String {
        val deviceAddress = device.address
        Log.d(TAG, "PIN code requested for $deviceAddress")
        pendingPinCode = null

        // Dispatch callback to main thread BEFORE blocking.
        val callback = onPinRequired
        if (callback != null) {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                callback(deviceAddress)
            }
        }

        // Block until submitPinCode() is called (60s timeout).
        val acquired = pinSemaphore.tryAcquire(60, TimeUnit.SECONDS)
        if (!acquired) {
            Log.w(TAG, "PIN entry timed out")
            return ""
        }

        return pendingPinCode ?: ""
    }

    fun submitPinCode(pin: String) {
        pendingPinCode = pin
        pinSemaphore.release()
    }

    override fun getAccessCode(address: String): ByteArray? {
        val deviceAddress = device.address
        val prefs = context.getSharedPreferences("ble_access_codes", Context.MODE_PRIVATE)
        val key = "ble_access_code_$deviceAddress"
        val encoded = prefs.getString(key, null) ?: return null
        return android.util.Base64.decode(encoded, android.util.Base64.NO_WRAP)
    }

    override fun setAccessCode(address: String, code: ByteArray) {
        val deviceAddress = device.address
        val prefs = context.getSharedPreferences("ble_access_codes", Context.MODE_PRIVATE)
        val key = "ble_access_code_$deviceAddress"
        val encoded = android.util.Base64.encodeToString(code, android.util.Base64.NO_WRAP)
        prefs.edit().putString(key, encoded).apply()
    }
}
