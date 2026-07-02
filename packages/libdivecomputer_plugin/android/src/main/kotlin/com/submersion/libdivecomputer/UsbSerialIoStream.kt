package com.submersion.libdivecomputer

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort
import java.io.IOException
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

// Bridges libdivecomputer's synchronous serial I/O to a USB-to-serial adapter
// via the vendored usb-serial-for-android library.
//
// Unlike BLE, USB serial read/write are already synchronous blocking calls, so
// no semaphore/queue bridge is needed. The one asynchronous step is the USB
// permission dialog, handled with a BroadcastReceiver + Semaphore (mirroring
// BleIoStream.ensureBonded).
//
// libdivecomputer drives I/O on its own download thread; the line-control
// methods (configure/setDtr/setRts) return 0 on success, non-zero on failure.
class UsbSerialIoStream(
    private val context: Context,
    private val driver: UsbSerialDriver,
) : SerialIoHandler {

    companion object {
        private const val TAG = "UsbSerialIoStream"
        private const val ACTION_USB_PERMISSION =
            "com.submersion.libdivecomputer.USB_PERMISSION"
        private const val PERMISSION_TIMEOUT_SECONDS = 30L
    }

    private var connection: UsbDeviceConnection? = null
    private var port: UsbSerialPort? = null

    // Requests USB permission (if needed) and opens the first port on the
    // device. Blocks up to PERMISSION_TIMEOUT_SECONDS for the user's response.
    // Returns true on success. Safe to call on a background thread.
    fun open(): Boolean {
        val usbManager =
            context.getSystemService(Context.USB_SERVICE) as? UsbManager ?: return false
        val device = driver.device
        NativeTrace.d("open begin ${device.deviceName}")

        if (!usbManager.hasPermission(device)) {
            NativeTrace.d("open requesting USB permission")
            if (!requestPermission(usbManager, device)) {
                NativeTrace.w("open USB permission not granted")
                NativeLogger.w(TAG, "SER", "USB permission not granted for ${device.deviceName}")
                return false
            }
        }

        val conn = usbManager.openDevice(device)
        if (conn == null) {
            NativeLogger.e(TAG, "SER", "openDevice returned null for ${device.deviceName}")
            return false
        }
        connection = conn

        val ports = driver.ports
        if (ports.isEmpty()) {
            NativeLogger.e(TAG, "SER", "driver exposes no serial ports")
            conn.close()
            connection = null
            return false
        }

        // Most adapters expose a single port, but multi-interface chips expose
        // several; try each until one opens so a non-functional first interface
        // doesn't block the download.
        for ((index, candidate) in ports.withIndex()) {
            try {
                NativeTrace.d("opening port[$index]")
                candidate.open(conn)
                port = candidate
                NativeTrace.d("opened port[$index]")
                NativeLogger.i(TAG, "SER", "Opened USB serial port[$index] for ${device.deviceName}")
                return true
            } catch (e: IOException) {
                NativeTrace.w("port[$index] open failed: ${e.message}")
                NativeLogger.w(TAG, "SER", "port[$index] open failed: ${e.message}")
            }
        }

        NativeLogger.e(TAG, "SER", "no openable serial port on ${device.deviceName}")
        conn.close()
        connection = null
        return false
    }

    private fun requestPermission(usbManager: UsbManager, device: UsbDevice): Boolean {
        val semaphore = Semaphore(0)
        var granted = false
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != ACTION_USB_PERMISSION) return
                val broadcastDevice: UsbDevice? =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                // Ignore a response for a different device (defends against an
                // unrelated/overlapping USB permission broadcast). A null device
                // extra is treated as ours to avoid deadlocking the request.
                if (broadcastDevice != null &&
                    broadcastDevice.deviceName != device.deviceName
                ) {
                    return
                }
                granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                semaphore.release()
            }
        }

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }

        try {
            // FLAG_MUTABLE so the system can attach the device + grant extras.
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            val intent = Intent(ACTION_USB_PERMISSION).setPackage(context.packageName)
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            usbManager.requestPermission(device, pendingIntent)

            if (!semaphore.tryAcquire(PERMISSION_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                NativeLogger.w(TAG, "SER", "USB permission request timed out")
                return false
            }
            return granted
        } finally {
            context.unregisterReceiver(receiver)
        }
    }

    // --- SerialIoHandler ---

    override fun read(size: Int, timeoutMs: Int): ByteArray? {
        val p = port ?: return null
        if (size <= 0) return ByteArray(0)

        NativeTrace.d("read enter size=$size timeoutMs=$timeoutMs")
        // libdivecomputer's read contract (see serial_posix.c dc_serial_read) is
        // "return exactly `size` bytes or time out" -- every driver relies on it.
        // A single UsbSerialPort.read() returns only the first ~64-byte USB bulk
        // chunk, so a larger device response (e.g. the Mares Puck Pro 140-byte
        // version block) came back truncated, desynced libdivecomputer's framing
        // and failed every probe with rc=-8. Accumulate across chunks, re-reading
        // on the remaining timeout, until the whole packet arrives (#334).
        val result = ByteArray(size)
        var received = 0
        // Bound the TOTAL wait for a finite (positive) libdivecomputer timeout.
        val deadlineNanos =
            if (timeoutMs > 0) System.nanoTime() + timeoutMs.toLong() * 1_000_000L else 0L

        while (received < size) {
            val sliceTimeout: Int = when {
                timeoutMs < 0 -> 0   // libdc infinite; usb-serial blocks on 0
                timeoutMs == 0 -> 1  // libdc non-blocking; smallest real slice
                else -> {
                    val remainingNanos = deadlineNanos - System.nanoTime()
                    if (remainingNanos <= 0) break
                    ((remainingNanos + 999_999L) / 1_000_000L).toInt().coerceAtLeast(1)
                }
            }
            val tmp = ByteArray(size - received)
            // Written BEFORE the USB read: if the read crashes the process
            // natively (no exception and no "<- n" follows), this is the last
            // line on disk, naming the slice size + timeout that triggered it.
            NativeTrace.d(
                "usb read req=${tmp.size} sliceTimeout=$sliceTimeout received=$received"
            )
            val n = try {
                p.read(tmp, sliceTimeout)
            } catch (e: IOException) {
                // A real I/O error (device unplugged, USB permission revoked) --
                // not a timeout, which returns 0 rather than throwing. Propagate
                // so the JNI bridge reports LIBDC_STATUS_IO and the driver fails
                // fast instead of retrying a dead port.
                NativeTrace.e("usb read IOException: ${e.message}")
                NativeLogger.e(TAG, "SER", "read failed: ${e.message}")
                throw e
            } catch (e: Throwable) {
                // e.g. FtdiSerialPort throws IllegalArgumentException for a
                // buffer <= 2 bytes (the 1-byte header/trailer reads).
                NativeTrace.e("usb read ${e.javaClass.simpleName}: ${e.message}")
                throw e
            }
            NativeTrace.d("usb read <- $n")
            if (n <= 0) break // timeout / nothing available this slice
            System.arraycopy(tmp, 0, result, received, n)
            received += n
        }

        // Exactly `size` -> success. A short read returns null so the JNI bridge
        // reports LIBDC_STATUS_TIMEOUT and libdivecomputer retries, rather than
        // accepting a truncated packet as a successful read.
        NativeTrace.d("read exit received=$received/$size")
        return if (received == size) result else null
    }

    override fun write(data: ByteArray, timeoutMs: Int): Int {
        val p = port ?: return -1
        val timeout = if (timeoutMs < 0) 0 else timeoutMs
        NativeTrace.d("usb write req=${data.size} timeout=$timeout")
        return try {
            p.write(data, timeout)
            NativeTrace.d("usb write <- ok")
            data.size
        } catch (e: IOException) {
            NativeTrace.e("usb write IOException: ${e.message}")
            NativeLogger.e(TAG, "SER", "write failed: ${e.message}")
            -1
        }
    }

    override fun purge(direction: Int) {
        val p = port ?: return
        NativeTrace.d("purge direction=$direction")
        // libdivecomputer direction bits: 1 = input, 2 = output.
        val purgeRead = direction and 1 != 0
        val purgeWrite = direction and 2 != 0
        try {
            p.purgeHwBuffers(purgeWrite, purgeRead)
        } catch (e: Exception) {
            // Best-effort: not all drivers support hardware purge.
            NativeLogger.d(TAG, "SER", "purge unsupported: ${e.message}")
        }
    }

    override fun close() {
        NativeTrace.d("close")
        try {
            port?.close()
        } catch (e: Exception) {
            NativeLogger.d(TAG, "SER", "port.close: ${e.message}")
        }
        port = null
        try {
            connection?.close()
        } catch (e: Exception) {
            NativeLogger.d(TAG, "SER", "connection.close: ${e.message}")
        }
        connection = null
    }

    override fun configure(
        baudRate: Int,
        dataBits: Int,
        parity: Int,
        stopBits: Int,
        flowControl: Int
    ): Int {
        val p = port ?: return -1
        NativeTrace.d(
            "configure baud=$baudRate dataBits=$dataBits parity=$parity " +
                "stopBits=$stopBits flow=$flowControl"
        )
        val db = when (dataBits) {
            5 -> UsbSerialPort.DATABITS_5
            6 -> UsbSerialPort.DATABITS_6
            7 -> UsbSerialPort.DATABITS_7
            else -> UsbSerialPort.DATABITS_8
        }
        // libdivecomputer parity 0=none, 1=odd, 2=even maps 1:1 to UsbSerialPort.
        val par = when (parity) {
            1 -> UsbSerialPort.PARITY_ODD
            2 -> UsbSerialPort.PARITY_EVEN
            else -> UsbSerialPort.PARITY_NONE
        }
        // libdivecomputer stopbits 0=one, 1=onepointfive, 2=two.
        val sb = when (stopBits) {
            1 -> UsbSerialPort.STOPBITS_1_5
            2 -> UsbSerialPort.STOPBITS_2
            else -> UsbSerialPort.STOPBITS_1
        }
        return try {
            p.setParameters(baudRate, db, sb, par)
            // Dive computers use no flow control; usb-serial has no portable
            // hardware/software flow-control setter, so nothing more is applied.
            NativeTrace.d("configure <- ok")
            0
        } catch (e: IOException) {
            NativeTrace.e("configure IOException: ${e.message}")
            NativeLogger.e(TAG, "SER", "configure failed: ${e.message}")
            -1
        }
    }

    override fun setDtr(value: Int): Int {
        val p = port ?: return -1
        NativeTrace.d("setDtr=$value")
        return try {
            p.setDTR(value != 0)
            0
        } catch (e: IOException) {
            NativeTrace.e("setDtr IOException: ${e.message}")
            NativeLogger.e(TAG, "SER", "setDtr failed: ${e.message}")
            -1
        }
    }

    override fun setRts(value: Int): Int {
        val p = port ?: return -1
        NativeTrace.d("setRts=$value")
        return try {
            p.setRTS(value != 0)
            0
        } catch (e: IOException) {
            NativeTrace.e("setRts IOException: ${e.message}")
            NativeLogger.e(TAG, "SER", "setRts failed: ${e.message}")
            -1
        }
    }
}
