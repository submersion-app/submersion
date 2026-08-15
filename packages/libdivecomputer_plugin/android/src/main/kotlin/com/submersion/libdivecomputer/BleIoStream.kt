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
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

// Client Characteristic Configuration Descriptor UUID for enabling notifications.
private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

// Telit/Stollmann Terminal I/O (TIO), service 0xFEFB.
//
// Heinrichs Weikamp computers built on the Telit (formerly Stollmann)
// BlueMod+SR module -- the OSTC 2/3/4/Sport/cR/Plus family -- expose their
// serial bridge behind this service with credit-based flow control (Telit
// "TIO Implementation Guide" r04). The module carries no UART data until the
// client subscribes to UART Credits TX and grants initial credits on UART
// Credits RX, and it spends one credit per notification, so the balance must
// also be topped up while a transfer runs. Without the handshake the first
// command write fails and libdivecomputer reports "Failed to send the
// command" (issue #923, OSTC4).
//
// Subsurface implements the same handshake in core/qt-ble.cpp across the two
// Heinrichs Weikamp module families, and both are handled here: Telit (0xFEFB,
// four characteristics, credits mandatory) and the u-blox serial service
// (...d701, two characteristics, credits optional -- the OSTC nano downloads
// today with no handshake at all, #280/#394, so a rejected grant there falls
// back to running without flow control instead of failing a working device).
// Mirrors darwin's BleCharacteristicSelector + TerminalIoCreditPolicy.
private val TIO_SERVICE_UUID = UUID.fromString("0000fefb-0000-1000-8000-00805f9b34fb")
private val TIO_DATA_RX_UUID = UUID.fromString("00000001-0000-1000-8000-008025000000")
private val TIO_DATA_TX_UUID = UUID.fromString("00000002-0000-1000-8000-008025000000")
private val TIO_CREDITS_RX_UUID = UUID.fromString("00000003-0000-1000-8000-008025000000")
private val TIO_CREDITS_TX_UUID = UUID.fromString("00000004-0000-1000-8000-008025000000")

// u-blox serial service: one characteristic carries data in both directions
// and one carries credits in both directions.
private val UBLOX_SERVICE_UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d701")
private val UBLOX_DATA_UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d703")
private val UBLOX_CREDITS_UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d704")

// Opening credit grant. 0xFF is reserved by the TIO protocol, so 254 is the
// largest value that means "credits" rather than a control code.
private const val TIO_INITIAL_GRANT = 254
// Balance at or below which the client tops the module back up.
private const val TIO_REFILL_THRESHOLD = 32

// Sentinel for "the bond-state broadcast carried no reason extra". Every
// real UNBOND_REASON_* value is positive, so a negative cannot collide.
private const val NO_REASON = -1

// Preferred UUIDs for characteristic selection scoring (matching Darwin BleIoStream).
// These ensure devices like Aqualung/Oceanic select the correct write and notify
// characteristics when the service has multiple write-capable chars.
private val PREFERRED_SERVICE_UUIDS = setOf(
    UUID.fromString("cb3c4555-d670-4670-bc20-b61dbc851e9a"),
    // Biased so the serial bridge always beats the Stollmann vendor service
    // the same devices also advertise, which can tie on raw score.
    TIO_SERVICE_UUID,
    UBLOX_SERVICE_UUID
)
private val PREFERRED_WRITE_UUIDS = setOf(
    UUID.fromString("6606ab42-89d5-4a00-a8ce-4eb5e1414ee0"),
    // Telit UART Data RX. Raw scoring already prefers it over UART Credits RX,
    // but commands written to the credits characteristic would be silently
    // swallowed, so the pair is pinned rather than left to the heuristic.
    TIO_DATA_RX_UUID,
    // u-blox FIFO, pinned over the credits characteristic for the same reason.
    UBLOX_DATA_UUID,
    // Halcyon Symbios: the app writes commands to the device's Rx endpoint
    // (00000101). Both Symbios characteristics advertise read+write+indicate and
    // tie on raw score, so a preferred UUID is required to tell them apart. The
    // Tx/Rx names are device-centric: Subsurface's qt-ble.cpp writes commands to
    // 00000101 ("Rx") and reads replies from 00000201 ("Tx"). PR #356 mapped
    // these backwards and the device never answered (issue #288).
    UUID.fromString("00000101-8c3b-4f2c-a59e-8c08224f3253")
)
private val PREFERRED_NOTIFY_UUIDS = setOf(
    UUID.fromString("a60b8e5c-b267-44d7-9764-837caf96489e"),
    // Telit UART Data TX (see PREFERRED_WRITE_UUIDS).
    TIO_DATA_TX_UUID,
    // u-blox FIFO carries data in both directions, so it is the notify
    // candidate as well as the write one.
    UBLOX_DATA_UUID,
    // Halcyon Symbios: the device transmits replies on its Tx endpoint
    // (00000201) via indications; the app writes commands on 00000101 (see
    // PREFERRED_WRITE_UUIDS and issue #288).
    UUID.fromString("00000201-8c3b-4f2c-a59e-8c08224f3253")
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

    // Which step of the connection handshake is in flight. Telit Terminal I/O
    // devices subscribe to UART Credits TX, then UART Data TX, then grant
    // initial credits; everything else only does the DATA_NOTIFY step. Android
    // permits one GATT operation at a time, so these must be chained through
    // their completion callbacks rather than issued together.
    private enum class SetupStep { NONE, CREDITS_NOTIFY, DATA_NOTIFY, INITIAL_CREDITS }

    private var gatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    private var notifyCharacteristic: BluetoothGattCharacteristic? = null
    // UART Credits RX/TX, non-null only on Telit Terminal I/O devices.
    private var creditsWriteCharacteristic: BluetoothGattCharacteristic? = null
    private var creditsNotifyCharacteristic: BluetoothGattCharacteristic? = null
    private var credits = 0
    // Whether a failed opening grant is fatal (Telit) or falls back to running
    // without flow control (u-blox, where it is optional).
    private var creditsRequired = false
    // Set while a mid-transfer top-up holds the GATT gate. Only touched on the
    // GATT callback thread.
    private var creditTopUpInFlight = false
    // Set once the opening grant is confirmed; top-ups stay suppressed until
    // then so they cannot race the setup write.
    private var creditsOpen = false
    // GATT status of the most recent command write, so writeLocked() can fail
    // a write the peripheral rejected instead of reporting it as sent.
    private var lastWriteStatus = BluetoothGatt.GATT_SUCCESS
    private var setupStep = SetupStep.NONE

    private val readQueue = LinkedBlockingQueue<ByteArray>()
    private val writeSemaphore = Semaphore(0)
    // One permit, held from the moment a GATT write is issued until its
    // completion callback arrives. Android's BluetoothGatt carries a single
    // busy flag and rejects writeCharacteristic() while any operation is
    // pending, so command writes and credit top-ups must not overlap.
    // Acquired with a timeout on the download thread; only ever tryAcquire()d
    // on the callback thread, which must stay free to deliver the completion
    // that releases it.
    private val gattOperation = Semaphore(1)
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

    // Why the most recent ensureBonded() call did not produce a bond, or
    // null if it succeeded or was never attempted. Exposed so the download
    // path can name the reason in the line it logs when it carries on
    // unbonded, instead of leaving a bare "bond failed" in the user's log.
    @Volatile
    var lastBondFailure: String? = null
        private set

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(
            gatt: BluetoothGatt, status: Int, newState: Int
        ) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connected = true
                // Request a high-priority (low-interval) connection so the dive
                // computer's serial->BLE bridge can drain its buffer fast enough
                // during bulk logbook/profile dumps. Some devices (e.g. the
                // Heinrichs Weikamp OSTC nano, #280) stream the whole logbook
                // back-to-back with no flow control and overflow -> drop
                // notifications when the connection interval is too slow.
                // Best-effort: the peripheral or controller may ignore it.
                val priorityRequested =
                    gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
                NativeLogger.d(TAG, "BLE",
                    "requestConnectionPriority(HIGH) -> $priorityRequested")
                // Request a larger MTU before discovering services.
                // Android defaults to 23 bytes (20 payload); CoreBluetooth
                // negotiates automatically but Android requires an explicit call.
                gatt.requestMtu(512)
            } else {
                connected = false
                lastDisconnectStatus = status
                // A credit top-up that was accepted before the link dropped
                // never gets its completion callback, so its permit would be
                // held for the life of this object. Every later command write
                // would then wait on the gate instead of failing fast -- and
                // libdivecomputer passes a negative timeout for "no timeout",
                // which write() maps to Long.MAX_VALUE, so the wait would be
                // indefinite rather than merely slow. Clear the flag before
                // releasing so a late callback cannot release it a second
                // time; Semaphore has no permit ceiling, and an over-release
                // would silently destroy the mutual exclusion the gate exists
                // for. Both callbacks arrive on the same GATT callback thread,
                // so this check and the one in onCharacteristicWrite cannot
                // interleave.
                if (creditTopUpInFlight) {
                    creditTopUpInFlight = false
                    gattOperation.release()
                }
                // A command write in flight gets no completion callback once
                // the link is down either. libdivecomputer's negative "no
                // timeout" maps to Long.MAX_VALUE, so its wait would never
                // end; wake it with a failure status so it returns -1. A
                // permit left unconsumed here is harmless because every write
                // drains the semaphore before issuing.
                lastWriteStatus = BluetoothGatt.GATT_FAILURE
                writeSemaphore.release()
                NativeLogger.d(TAG, "BLE", "onConnectionStateChange: disconnected status=$status")
                connectSemaphore.release()
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            NativeLogger.d(TAG, "BLE", "onMtuChanged: mtu=$mtu status=$status")
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
            var bestCreditsWrite: BluetoothGattCharacteristic? = null
            var bestCreditsNotify: BluetoothGattCharacteristic? = null
            var bestCreditsRequired = false

            for (service in gatt.services) {
                NativeLogger.d(TAG, "BLE", "Service: ${service.uuid}")
                var serviceWrite: BluetoothGattCharacteristic? = null
                var serviceWriteScore = -1
                var serviceNotify: BluetoothGattCharacteristic? = null
                var serviceNotifyScore = -1

                for (char in service.characteristics) {
                    val props = char.properties
                    NativeLogger.d(TAG, "BLE", "  Char: ${char.uuid} props=0x${props.toString(16)} descriptors=${char.descriptors.size}")

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
                        // Only run the handshake on a complete known layout, so
                        // every other device keeps today's plain write/notify
                        // path. Telit needs all four UART characteristics;
                        // u-blox needs its data and credits pair.
                        val tioCreditsRx = service.getCharacteristic(TIO_CREDITS_RX_UUID)
                        val tioCreditsTx = service.getCharacteristic(TIO_CREDITS_TX_UUID)
                        val ubloxCredits = service.getCharacteristic(UBLOX_CREDITS_UUID)
                        if (tioCreditsRx != null && tioCreditsTx != null &&
                            service.getCharacteristic(TIO_DATA_RX_UUID) != null &&
                            service.getCharacteristic(TIO_DATA_TX_UUID) != null
                        ) {
                            bestCreditsWrite = tioCreditsRx
                            bestCreditsNotify = tioCreditsTx
                            bestCreditsRequired = true
                        } else if (ubloxCredits != null &&
                            service.getCharacteristic(UBLOX_DATA_UUID) != null
                        ) {
                            bestCreditsWrite = ubloxCredits
                            bestCreditsNotify = ubloxCredits
                            bestCreditsRequired = false
                        } else {
                            bestCreditsWrite = null
                            bestCreditsNotify = null
                            bestCreditsRequired = false
                        }
                    }
                }
            }

            var startedSetup = false
            if (bestWrite != null && bestNotify != null) {
                NativeLogger.d(TAG, "BLE", "Data service selected (score=$bestServiceScore)")
                NativeLogger.d(TAG, "BLE", "  write=${bestWrite.uuid} notify=${bestNotify.uuid}")
                writeCharacteristic = bestWrite
                notifyCharacteristic = bestNotify
                creditsWriteCharacteristic = bestCreditsWrite
                creditsNotifyCharacteristic = bestCreditsNotify
                creditsRequired = bestCreditsRequired

                // Terminal I/O subscribes to Credits TX before Data TX (Telit
                // TIO Implementation Guide r04 sections 6.4 and 6.2, and the
                // same order in Subsurface's qt-ble.cpp). The payload is never
                // consumed, but the module keeps the UART bridge closed until
                // the subscription exists.
                val creditsNotify = bestCreditsNotify
                startedSetup = if (creditsNotify != null) {
                    NativeLogger.d(TAG, "BLE",
                        "  Credit flow control detected" +
                            " (${if (bestCreditsRequired) "Telit, required" else "u-blox, optional"}):" +
                            " creditsRx=${bestCreditsWrite?.uuid} creditsTx=${creditsNotify.uuid}")
                    subscribeToNotifications(gatt, creditsNotify, SetupStep.CREDITS_NOTIFY)
                } else {
                    subscribeToNotifications(gatt, bestNotify, SetupStep.DATA_NOTIFY)
                }
            }

            // If a setup operation was started, wait for its completion
            // callback before signalling ready. Otherwise the download may
            // call writeCharacteristic while the descriptor write is still in
            // flight, which silently fails.
            if (!startedSetup) {
                connectSemaphore.release()
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            NativeLogger.d(TAG, "BLE", "onDescriptorWrite: ${descriptor.uuid} status=$status")
            val completed = setupStep
            setupStep = SetupStep.NONE
            val ok = status == BluetoothGatt.GATT_SUCCESS

            // Credits TX is live; Data TX comes next, and the initial credit
            // grant after that.
            if (completed == SetupStep.CREDITS_NOTIFY && (ok || !creditsRequired)) {
                if (!ok) abandonCreditFlowControl("credits subscription failed status=$status")
                val notify = notifyCharacteristic
                if (notify != null &&
                    subscribeToNotifications(gatt, notify, SetupStep.DATA_NOTIFY)
                ) {
                    return
                }
            } else if (completed == SetupStep.DATA_NOTIFY && ok) {
                if (creditsWriteCharacteristic == null) {
                    // No credit flow control on this device, or already
                    // abandoned: GATT is free for I/O.
                } else if (grantInitialCredits(gatt)) {
                    return
                } else if (!creditsRequired) {
                    abandonCreditFlowControl("initial credit write rejected")
                }
            }

            // Nothing further in flight; GATT is free for I/O.
            connectSemaphore.release()
        }

        // API 33+ delivers notification data via this 3-parameter overload.
        // The old 2-parameter version is never called on API 33+ devices.
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            NativeLogger.d(TAG, "BLE", "onCharacteristicChanged(API33+): ${value.size} bytes")
            onNotification(characteristic, value)
        }

        // Pre-API 33 fallback: notification data is on characteristic.value.
        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val value = characteristic.value ?: return
            NativeLogger.d(TAG, "BLE", "onCharacteristicChanged(legacy): ${value.size} bytes")
            onNotification(characteristic, value)
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            // Credit grants share this callback with command writes but not
            // their semaphore: releasing writeSemaphore here would free a
            // command write that is still in flight and desynchronise the
            // protocol.
            if (characteristic.uuid == creditsWriteCharacteristic?.uuid) {
                // A mid-transfer top-up owns the GATT gate; release it before
                // anything else can want it. Tracked by its own flag rather
                // than inferred from setupStep, so the permit can never be
                // released for a write that did not take one.
                if (creditTopUpInFlight) {
                    creditTopUpInFlight = false
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        // Only now is the module known to hold the grant.
                        credits += TIO_INITIAL_GRANT - TIO_REFILL_THRESHOLD
                        NativeLogger.d(TAG, "BLE",
                            "Terminal I/O: credits acknowledged (balance=$credits)")
                    } else {
                        // Leave the balance uncredited so the next packet
                        // retries rather than stalling on credits the module
                        // never received.
                        NativeLogger.w(TAG, "BLE",
                            "Terminal I/O: credit grant not acknowledged" +
                                " status=$status; will retry")
                    }
                    gattOperation.release()
                    return
                }
                if (setupStep == SetupStep.INITIAL_CREDITS) {
                    setupStep = SetupStep.NONE
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        credits = TIO_INITIAL_GRANT
                        creditsOpen = true
                        NativeLogger.d(TAG, "BLE",
                            "Terminal I/O: bridge open (credits=$credits)")
                    } else if (creditsRequired) {
                        NativeLogger.e(TAG, "BLE",
                            "Terminal I/O: initial credit grant failed status=$status")
                    } else {
                        abandonCreditFlowControl(
                            "initial credit grant failed status=$status")
                    }
                    connectSemaphore.release()
                }
                return
            }
            // Only the selected command characteristic drives writeSemaphore.
            // Matching positively rather than "anything that is not credits"
            // matters once the u-blox fallback has cleared the credit
            // characteristics: a late completion for an abandoned credit
            // grant would otherwise fall through and wake a command write
            // that is still in flight.
            if (characteristic.uuid != writeCharacteristic?.uuid) return
            lastWriteStatus = status
            writeSemaphore.release()
        }
    }

    // Route one notification, ignoring anything that is not the selected data
    // characteristic. UART Credits TX carries no application data; injecting
    // its indications into the read queue would corrupt the protocol stream.
    private fun onNotification(
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray
    ) {
        val notify = notifyCharacteristic
        if (notify != null && characteristic.uuid != notify.uuid) return
        readQueue.offer(value)
        replenishCredits()
    }

    // Give up on credit flow control and run the connection without it.
    //
    // Only reachable for u-blox, whose serial service treats flow control as
    // optional and already works with no handshake at all (#280, #394). A
    // Telit bridge carries nothing without credits, so its failures are fatal
    // and never come here.
    private fun abandonCreditFlowControl(reason: String) {
        NativeLogger.w(TAG, "BLE",
            "Terminal I/O: $reason; continuing without credit flow control")
        // Stop the local stack forwarding credit indications we would only
        // discard. This is a local call with no GATT operation behind it, so
        // it cannot collide with the setup chain or the write gate. The CCCD
        // disable that would also stop the module transmitting is deliberately
        // not chained here: it would need another setup step on a path that
        // only runs when a u-blox module rejects the grant, and the callbacks
        // are already filtered out by onNotification.
        creditsNotifyCharacteristic?.let { gatt?.setCharacteristicNotification(it, false) }
        creditsWriteCharacteristic = null
        creditsNotifyCharacteristic = null
    }

    // Subscribe to a characteristic and record which setup step is now in
    // flight. Returns true if the descriptor write was accepted.
    private fun subscribeToNotifications(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        step: SetupStep
    ): Boolean {
        gatt.setCharacteristicNotification(characteristic, true)
        val descriptor = characteristic.getDescriptor(CCCD_UUID)
        NativeLogger.d(TAG, "BLE", "  CCCD descriptor: ${descriptor?.uuid ?: "NULL"}")
        if (descriptor == null) return false

        // Use ENABLE_INDICATION_VALUE for INDICATE-only chars (which is what
        // UART Credits TX is), ENABLE_NOTIFICATION_VALUE otherwise.
        descriptor.value = if (
            characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY == 0 &&
            characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
        ) {
            BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        } else {
            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        }
        setupStep = step
        val started = gatt.writeDescriptor(descriptor)
        NativeLogger.d(TAG, "BLE", "  writeDescriptor returned: $started")
        if (!started) setupStep = SetupStep.NONE
        return started
    }

    // Write the opening credit grant to UART Credits RX. Returns true if the
    // write was accepted, in which case onCharacteristicWrite finishes setup.
    private fun grantInitialCredits(gatt: BluetoothGatt): Boolean {
        val creditsChar = creditsWriteCharacteristic ?: return false
        NativeLogger.d(TAG, "BLE",
            "Terminal I/O: granting $TIO_INITIAL_GRANT initial credits")
        creditsChar.value = byteArrayOf(TIO_INITIAL_GRANT.toByte())
        creditsChar.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        setupStep = SetupStep.INITIAL_CREDITS
        val started = gatt.writeCharacteristic(creditsChar)
        if (!started) {
            setupStep = SetupStep.NONE
            NativeLogger.e(TAG, "BLE", "Terminal I/O: initial credit write rejected")
        }
        return started
    }

    // Account for one received packet and top the module back up when its
    // balance runs low, so a multi-thousand-notification logbook dump does not
    // stall once the opening grant is spent.
    private fun replenishCredits() {
        val creditsChar = creditsWriteCharacteristic ?: return
        val g = gatt ?: return

        // Nothing until the opening grant has been confirmed. Notifications go
        // live before that write is issued -- the u-blox service streams with
        // no credits at all -- and a refill requested in that window would put
        // a second credit write on the wire alongside the opening one. Their
        // completions are indistinguishable here, so the setup step and the
        // top-up would be mis-attributed to each other.
        if (!creditsOpen) return

        if (credits > 0) credits--
        if (credits > TIO_REFILL_THRESHOLD) return

        // Never preempt a command write. Android permits one GATT operation in
        // flight and rejects the loser, and a rejected command write fails the
        // whole download, so credit maintenance always yields. tryAcquire and
        // never a blocking acquire: this runs on the GATT callback thread,
        // which must stay free to deliver the completion that frees the gate.
        // Skipping is cheap -- there are TIO_REFILL_THRESHOLD packets of slack
        // and the next one retries.
        if (!gattOperation.tryAcquire()) return

        val grant = TIO_INITIAL_GRANT - TIO_REFILL_THRESHOLD
        creditsChar.value = byteArrayOf(grant.toByte())
        creditsChar.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        // Commit the grant only when the request was accepted; otherwise the
        // balance must stay as it is so the next packet asks again.
        if (g.writeCharacteristic(creditsChar)) {
            // Do NOT count the grant yet. writeCharacteristic() reporting true
            // only means Android accepted the request; the write can still
            // fail at the ATT layer, and counting credits the module never
            // received leaves the balance permanently above the refill
            // threshold -- the module falls silent, no packets arrive to
            // decrement it, and the transfer stalls for good. The balance may
            // run understated in the meantime, which only costs an early
            // refill.
            creditTopUpInFlight = true
            NativeLogger.d(TAG, "BLE",
                "Terminal I/O: requesting $grant more credits (balance=$credits)")
        } else {
            // No completion callback is coming, so release the gate here.
            gattOperation.release()
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
            NativeLogger.e(TAG, "BLE", "connectAndDiscover: semaphore timeout")
            return false
        }
        // A Terminal I/O module keeps its UART bridge closed until credits are
        // granted, so a failed handshake means the first command write would
        // fail rather than the download merely being slow (issue #923).
        val terminalIoReady = creditsWriteCharacteristic == null || credits > 0
        val ok = connected && writeCharacteristic != null && terminalIoReady
        NativeLogger.d(TAG, "BLE", "connectAndDiscover: connected=$connected writeChar=${writeCharacteristic?.uuid} credits=$credits result=$ok")
        return ok
    }

    // Ensure the device is bonded before starting I/O. Called AFTER
    // connectAndDiscover() so there is an active GATT connection.
    // If the device is already bonded, returns immediately.
    // Otherwise calls createBond() and blocks until the user accepts
    // the pairing dialog (or timeout). Needs an active connection
    // because many BLE peripherals ignore pairing requests without one.
    fun ensureBonded(): Boolean {
        lastBondFailure = null
        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            NativeLogger.d(TAG, "BLE", "ensureBonded: already bonded")
            return true
        }

        NativeLogger.d(TAG, "BLE", "ensureBonded: initiating bonding for ${device.address}")
        val bondSemaphore = Semaphore(0)
        // Android reports why a bond ended in the broadcast, not in the
        // device state that survives it, so the reason has to be captured
        // here. The broadcast arrives on the main thread while this method
        // blocks on the download thread, so the handoff must be atomic;
        // NO_REASON marks "the stack sent none".
        val unbondReason = AtomicInteger(NO_REASON)
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
                // Absent on some stacks; NO_REASON cannot collide with a
                // real UNBOND_REASON_* value, all of which are positive.
                val reason = intent.getIntExtra(BondDiagnostics.EXTRA_REASON, NO_REASON)
                if (reason != NO_REASON) unbondReason.set(reason)
                NativeLogger.d(
                    TAG, "BLE",
                    "ensureBonded: bond state changed to " +
                        BondDiagnostics.describeBondState(state)
                )
                if (state == BluetoothDevice.BOND_BONDED ||
                    state == BluetoothDevice.BOND_NONE
                ) {
                    bondSemaphore.release()
                }
            }
        }

        // NOT_EXPORTED: ACTION_BOND_STATE_CHANGED is only ever delivered by
        // the platform, so nothing is lost by refusing broadcasts from other
        // apps -- and it matches how UsbSerialIoStream registers its own
        // receiver.
        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }

        try {
            // createBond() also returns false when a bond is already under
            // way, which is what a user retrying a failed download every
            // second produces. Failing instantly there would abandon a bond
            // that is still running and could yet succeed, so wait for the
            // in-flight attempt instead of starting a competing one.
            if (!device.createBond() &&
                !BondDiagnostics.bondAlreadyInProgress(device.bondState)
            ) {
                lastBondFailure = BondDiagnostics.describeRefusedRequest(device.bondState)
                NativeLogger.w(TAG, "BLE", "ensureBonded: $lastBondFailure")
                return false
            }
            // 30s timeout: user needs time to interact with pairing dialog.
            if (!bondSemaphore.tryAcquire(30, TimeUnit.SECONDS)) {
                lastBondFailure =
                    "pairing did not finish within 30s (device is " +
                        "${BondDiagnostics.describeBondState(device.bondState)})"
                NativeLogger.w(TAG, "BLE", "ensureBonded: $lastBondFailure")
                return false
            }
            val bondState = device.bondState
            if (bondState == BluetoothDevice.BOND_BONDED) {
                NativeLogger.d(TAG, "BLE", "ensureBonded: bonded")
                return true
            }
            // The branch that fires when a computer refuses to pair. It
            // previously reported only "result=false" at DEBUG, which left
            // a refused pairing indistinguishable from a cancelled one in
            // every bug report that reached this point (issue #1029).
            lastBondFailure = BondDiagnostics.describeFailedAttempt(
                bondState,
                unbondReason.get().takeIf { it != NO_REASON }
            )
            NativeLogger.w(TAG, "BLE", "ensureBonded: $lastBondFailure")
            return false
        } catch (e: Exception) {
            lastBondFailure =
                BondDiagnostics.describeThrownFailure(e.javaClass.simpleName, e.message)
            NativeLogger.e(TAG, "BLE", "ensureBonded: $lastBondFailure")
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
            NativeLogger.d(TAG, "BLE", "removeBond: not bonded, nothing to remove")
            return true
        }

        NativeLogger.d(TAG, "BLE", "removeBond: removing bond for ${device.address}")
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
                NativeLogger.d(TAG, "BLE", "removeBond: bond state changed to $state")
                if (state == BluetoothDevice.BOND_NONE) {
                    bondSemaphore.release()
                }
            }
        }

        // NOT_EXPORTED for the same reason as in ensureBonded above.
        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }

        try {
            val method = device.javaClass.getMethod("removeBond")
            val result = method.invoke(device) as Boolean
            if (!result) {
                NativeLogger.e(TAG, "BLE", "removeBond: removeBond() returned false")
                return false
            }
            if (!bondSemaphore.tryAcquire(5, TimeUnit.SECONDS)) {
                NativeLogger.e(TAG, "BLE", "removeBond: timeout waiting for bond removal")
                return false
            }
            val removed = device.bondState == BluetoothDevice.BOND_NONE
            NativeLogger.d(TAG, "BLE", "removeBond: result=$removed")
            return removed
        } catch (e: Exception) {
            NativeLogger.e(TAG, "BLE", "removeBond: failed: ${e.message}")
            return false
        } finally {
            context.unregisterReceiver(receiver)
        }
    }

    // BleIoHandler implementation - called from native code via JNI.

    override fun read(size: Int, timeoutMs: Int): ByteArray? {
        NativeLogger.d(TAG, "BLE", "read: size=$size timeout=$timeoutMs")

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
            NativeLogger.e(TAG, "BLE", "write: writeCharacteristic is null")
            return -1
        }
        val g = gatt ?: run {
            NativeLogger.e(TAG, "BLE", "write: gatt is null")
            return -1
        }

        NativeLogger.d(TAG, "BLE", "write: ${data.size} bytes, timeout=$timeoutMs")

        // Claim the GATT gate for the whole request/completion cycle so a
        // credit top-up cannot be in flight when this write is issued. Android
        // rejects writeCharacteristic() outright while another operation is
        // pending, and a rejected command write fails the download with no
        // retry -- unlike a rejected credit write, which simply waits for the
        // next packet. Blocking here is safe: this is the libdivecomputer
        // download thread, not the callback thread that releases the gate.
        val timeout = if (timeoutMs < 0) Long.MAX_VALUE else timeoutMs.toLong()
        if (!gattOperation.tryAcquire(timeout, TimeUnit.MILLISECONDS)) {
            NativeLogger.e(TAG, "BLE", "write: timed out waiting for GATT to be free")
            return -1
        }
        try {
            return writeLocked(char, g, data, timeout)
        } finally {
            gattOperation.release()
        }
    }

    private fun writeLocked(
        char: BluetoothGattCharacteristic,
        g: BluetoothGatt,
        data: ByteArray,
        timeout: Long
    ): Int {
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

        // Discard any permit left behind by an earlier write that timed out
        // before its completion callback arrived. Without this, that stale
        // permit satisfies this write's wait immediately: write() would report
        // success while the write was still in flight, and the finally block
        // would hand back the GATT gate, letting the next command write be
        // issued on top of an operation Android still considers pending --
        // which it then rejects, failing the download. darwin drains the same
        // semaphore for the same reason before a with-response write.
        writeSemaphore.drainPermits()
        lastWriteStatus = BluetoothGatt.GATT_SUCCESS

        if (!g.writeCharacteristic(char)) {
            NativeLogger.e(TAG, "BLE", "write: writeCharacteristic() returned false")
            return -1
        }

        // Always wait for onCharacteristicWrite before returning.
        // Android BLE only allows one GATT operation at a time;
        // without this wait, a subsequent write would fail because
        // the previous one is still in flight.
        if (!writeSemaphore.tryAcquire(timeout, TimeUnit.MILLISECONDS)) return -1

        // A write the peripheral rejected must be reported as a failure.
        // Returning data.size regardless would tell libdivecomputer the
        // command went out, leaving it waiting for a reply that can never
        // come. darwin already fails the write on lastWriteError.
        if (lastWriteStatus != BluetoothGatt.GATT_SUCCESS) {
            NativeLogger.e(TAG, "BLE", "write: failed status=$lastWriteStatus")
            return -1
        }

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
        creditsWriteCharacteristic = null
        creditsNotifyCharacteristic = null
        credits = 0
        creditsRequired = false
        creditsOpen = false
        creditTopUpInFlight = false
        setupStep = SetupStep.NONE
    }

    override fun onPinCodeRequired(address: String): String {
        val deviceAddress = device.address
        NativeLogger.d(TAG, "BLE", "PIN code requested for $deviceAddress")
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
            NativeLogger.w(TAG, "BLE", "PIN entry timed out")
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
