package com.submersion.libdivecomputer

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.content.Context
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

// Client Characteristic Configuration Descriptor UUID for enabling notifications.
private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

// Bridges Android BLE GATT communication to libdivecomputer's synchronous
// I/O interface using semaphores.
//
// libdivecomputer calls read/write synchronously on a background thread.
// This class translates those calls to async BluetoothGatt operations,
// blocking with semaphores until the BLE operation completes.
class BleIoStream(
    private val context: Context,
    private val device: BluetoothDevice
) : BleIoHandler {

    private var gatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null

    private val readQueue = LinkedBlockingQueue<ByteArray>()
    private val writeSemaphore = Semaphore(0)
    private val connectSemaphore = Semaphore(0)
    private var connected = false
    private var readBuffer = ByteArray(0)

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(
            gatt: BluetoothGatt, status: Int, newState: Int
        ) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connected = true
                gatt.discoverServices()
            } else {
                connected = false
                connectSemaphore.release()
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                // Find write and notify characteristics.
                for (service in gatt.services) {
                    for (char in service.characteristics) {
                        val props = char.properties
                        if (props and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0 ||
                            props and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
                        ) {
                            gatt.setCharacteristicNotification(char, true)
                            val descriptor = char.getDescriptor(CCCD_UUID)
                            if (descriptor != null) {
                                descriptor.value =
                                    BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                gatt.writeDescriptor(descriptor)
                            }
                        }
                        if (props and BluetoothGattCharacteristic.PROPERTY_WRITE != 0 ||
                            props and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
                        ) {
                            writeCharacteristic = char
                        }
                    }
                }
            }
            connectSemaphore.release()
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val value = characteristic.value ?: return
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
    fun connectAndDiscover(): Boolean {
        gatt = device.connectGatt(context, false, gattCallback)
        if (!connectSemaphore.tryAcquire(15, TimeUnit.SECONDS)) return false
        return connected && writeCharacteristic != null
    }

    // BleIoHandler implementation - called from native code via JNI.

    override fun read(size: Int, timeoutMs: Int): ByteArray? {
        val result = ByteArray(size)
        var totalRead = 0

        while (totalRead < size) {
            // First consume any leftover data in the buffer.
            if (readBuffer.isNotEmpty()) {
                val bytesToCopy = minOf(size - totalRead, readBuffer.size)
                System.arraycopy(readBuffer, 0, result, totalRead, bytesToCopy)
                readBuffer = readBuffer.copyOfRange(bytesToCopy, readBuffer.size)
                totalRead += bytesToCopy
                continue
            }

            // Wait for new data from BLE notifications.
            val timeout = if (timeoutMs < 0) Long.MAX_VALUE else timeoutMs.toLong()
            val chunk = readQueue.poll(timeout, TimeUnit.MILLISECONDS) ?: return if (totalRead > 0) {
                result.copyOfRange(0, totalRead)
            } else {
                null
            }

            // Copy as much as needed, buffer the rest.
            val bytesToCopy = minOf(size - totalRead, chunk.size)
            System.arraycopy(chunk, 0, result, totalRead, bytesToCopy)
            totalRead += bytesToCopy
            if (bytesToCopy < chunk.size) {
                readBuffer = chunk.copyOfRange(bytesToCopy, chunk.size)
            }
        }

        return result
    }

    override fun write(data: ByteArray, timeoutMs: Int): Int {
        val char = writeCharacteristic ?: return -1
        val g = gatt ?: return -1

        char.value = data
        char.writeType = if (char.properties and
            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
        ) {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }

        g.writeCharacteristic(char)

        if (char.writeType == BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) {
            val timeout = if (timeoutMs < 0) Long.MAX_VALUE else timeoutMs.toLong()
            if (!writeSemaphore.tryAcquire(timeout, TimeUnit.MILLISECONDS)) return -1
        }

        return data.size
    }

    override fun close() {
        gatt?.disconnect()
        gatt?.close()
        gatt = null
    }
}
