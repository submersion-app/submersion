package com.submersion.libdivecomputer

import java.nio.ByteBuffer

/**
 * Encodes/decodes a ParsedDive to a byte[] using the plugin's OWN Pigeon codec
 * (via the public DiveComputerHostApi.codec), so a dive can cross the AIDL
 * boundary from :dc back to the main process without hand-duplicating the
 * 28-field, nested ParsedDive schema. The codec (StandardMessageCodec) already
 * knows how to write/read ParsedDive and its nested ProfileSample/TankInfo/
 * GasMix/DiveEvent types (type byte 136 and friends). See issue #318.
 */
object DiveMarshaling {
    fun encode(dive: ParsedDive): ByteArray {
        // StandardMessageCodec.encodeMessage returns a buffer positioned at the
        // end of the written data; flip to expose [0, size) for reading out.
        val buffer = DiveComputerHostApi.codec.encodeMessage(dive)
            ?: return ByteArray(0)
        buffer.flip()
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        return bytes
    }

    fun decode(bytes: ByteArray): ParsedDive {
        val value = DiveComputerHostApi.codec.decodeMessage(ByteBuffer.wrap(bytes))
        // Validate rather than blind-cast: an empty/corrupt/incompatible IPC
        // payload must fail with a clear, catchable exception (the caller on the
        // main process converts it to an error rather than crashing).
        return value as? ParsedDive
            ?: throw IllegalArgumentException(
                "IPC payload did not decode to a ParsedDive " +
                    "(got ${value?.javaClass?.simpleName ?: "null"})")
    }
}
