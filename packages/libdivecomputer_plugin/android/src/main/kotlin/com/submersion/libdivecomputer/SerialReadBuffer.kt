package com.submersion.libdivecomputer

// Reassembles libdivecomputer's exact-length serial reads from raw USB bulk
// chunk reads, restoring the tty byte-stream semantics its serial drivers
// were written against.
//
// Raw USB bulk endpoints are packet-based: asking the kernel for fewer bytes
// than the arriving packet contains fails the transfer with EOVERFLOW and
// DISCARDS the packet, and usb-serial-for-android surfaces that as an
// immediate 0-byte read -- indistinguishable from a silent device. That is
// how the Mares Puck Pro handshake failed in issue #318: libdivecomputer
// reads the 1-byte ACK header first, the device's whole response arrived in
// one 64-byte bulk packet, and every retry threw the response away.
//
// Two invariants fix that:
//  1. Only hand USB buffers sized to a whole number of bulk packets
//     (minChunkSize = the endpoint's max packet size). "At least one packet"
//     is not enough: a request ending mid-packet still babbles when the
//     response runs one packet past it (issue #318, Puck Pro version block).
//  2. Keep whatever a chunk returns beyond the requested size buffered for
//     subsequent reads, since the next protocol bytes ride in the same packet.
//
// Pure Kotlin (no Android imports): the clock, the chunk reader, and tracing
// are injected so the deadline and buffering logic is testable on the JVM.
class SerialReadBuffer(
    minChunkSize: Int,
    private val nowNanos: () -> Long = System::nanoTime,
    private val trace: (String) -> Unit = {},
) {
    private val minChunkSize = minChunkSize.coerceAtLeast(1)

    // Surplus bytes from an earlier chunk, in arrival order.
    private var pending = ByteArray(0)

    // Returns exactly `size` bytes, or null on timeout (the JNI bridge maps
    // null to LIBDC_STATUS_TIMEOUT and libdivecomputer retries). Timeout
    // semantics follow libdivecomputer's serial contract: negative = block
    // until data, zero = non-blocking single poll, positive = total deadline
    // across however many chunk reads it takes.
    //
    // readChunk(dest, timeoutMs) performs one USB bulk read into dest and
    // returns the byte count (0 = nothing this slice); usb-serial-for-android
    // treats timeout 0 as "block until data". I/O errors propagate as
    // exceptions.
    fun read(
        size: Int,
        timeoutMs: Int,
        readChunk: (ByteArray, Int) -> Int,
    ): ByteArray? {
        if (size <= 0) return ByteArray(0)
        val result = ByteArray(size)
        var received = 0

        // Serve buffered surplus from earlier chunks first.
        if (pending.isNotEmpty()) {
            val n = minOf(pending.size, size)
            System.arraycopy(pending, 0, result, 0, n)
            pending = pending.copyOfRange(n, pending.size)
            received = n
        }

        val deadlineNanos =
            if (timeoutMs > 0) nowNanos() + timeoutMs.toLong() * 1_000_000L else 0L

        while (received < size) {
            val sliceTimeout: Int = when {
                timeoutMs < 0 -> 0 // block until data arrives
                timeoutMs == 0 -> 1 // non-blocking; smallest real slice
                else -> {
                    val remainingNanos = deadlineNanos - nowNanos()
                    if (remainingNanos <= 0) break
                    ((remainingNanos + 999_999L) / 1_000_000L).toInt().coerceAtLeast(1)
                }
            }
            // Request a whole number of bulk packets (invariant 1): a request
            // ending mid-packet babbles (EOVERFLOW) when the response runs
            // past it, and the kernel discards the transfer. Overshoot lands
            // in `pending`.
            val packets = (size - received + minChunkSize - 1) / minChunkSize
            val chunk = ByteArray(packets * minChunkSize)
            trace("usb read req=${chunk.size} sliceTimeout=$sliceTimeout received=$received")
            val n = readChunk(chunk, sliceTimeout)
            trace("usb read <- $n")
            if (n <= 0) {
                // Nothing this slice. A zero-length transfer must not fake a
                // timeout while the deadline (or a blocking read) still
                // stands; only the non-blocking mode gives up here.
                if (timeoutMs == 0) break
                continue
            }
            val take = minOf(n, size - received)
            System.arraycopy(chunk, 0, result, received, take)
            received += take
            if (n > take) {
                // Only the chunk that completes the read can overshoot, and
                // pending was drained before the loop, so plain assignment.
                pending = chunk.copyOfRange(take, n)
            }
        }

        trace("read exit received=$received/$size buffered=${pending.size}")
        return if (received == size) result else null
    }

    // Drops buffered surplus. Call when libdivecomputer purges the input
    // direction, so stale bytes cannot leak into the next packet exchange.
    fun clear() {
        pending = ByteArray(0)
    }
}
