import Foundation

/// A libdivecomputer byte pipe backed by an FTDI chip driven over raw USB.
///
/// Serves dive-computer cables that no operating system driver claims, so no
/// serial device node exists for `SerialIoStream` to open (issue #732).
/// libdivecomputer is unaware of the difference: this fills the same
/// `libdc_io_callbacks_t` table, and the session is still opened with
/// `LIBDC_TRANSPORT_SERIAL`.
///
/// The caller must keep the stream alive while the callbacks are in use; the
/// userdata pointer is unretained, matching `SerialIoStream`.
class FtdiUsbIoStream {
    private var handle: OpaquePointer?
    private var accumulator: FtdiReadAccumulator?
    private var packetSize = 64
    private var timeoutMs: Int32 = 10000

    deinit {
        close()
    }

    /// Opens `device` and puts the chip into a known state. Returns nil on
    /// success, or a human-readable reason the open failed.
    func open(device: UsbFtdiDevice) -> String? {
        var opened: OpaquePointer?
        let rc = ftdi_usb_open(device.locationId, &opened)
        guard rc == 0, let opened else {
            return "IOKit refused the USB device (IOReturn 0x\(String(format: "%08X", rc)))"
        }
        handle = opened

        let reported = ftdi_usb_max_packet_size(opened)
        // Fall back to the full-speed bulk maximum if the descriptor is
        // unreadable; a zero packet size would make every read a no-op.
        packetSize = reported > 0 ? Int(reported) : 64
        accumulator = FtdiReadAccumulator(packetSize: packetSize)

        // Reset the UART so the chip does not start mid-frame from whatever a
        // previous session left behind.
        if let failure = sendControl(.reset, value: 0) {
            close()
            return "Failed to reset the FTDI cable: \(failure)"
        }
        if let failure = sendControl(
            .setLatencyTimer, value: FtdiProtocol.defaultLatencyTimerMs
        ) {
            // Not fatal: the chip works at its 16 ms default, just slower.
            NativeLogger.w(
                "FtdiUsb", category: "USB",
                "Could not set the latency timer: \(failure)")
        }

        NativeLogger.i(
            "FtdiUsb", category: "USB",
            "Opened \(device.displayName) at location "
                + "0x\(String(format: "%08X", device.locationId)), "
                // NativeLogger takes an escaping autoclosure, so a property
                // reference here needs an explicit self.
                + "packet size \(self.packetSize)")
        return nil
    }

    func close() {
        if let handle {
            ftdi_usb_close(handle)
        }
        handle = nil
        accumulator = nil
    }

    /// Returns the callback table libdivecomputer drives this stream through.
    ///
    /// Every serial line-control slot is filled. The bridge in
    /// `libdc_download.c` silently no-ops a NULL slot, and the Oceanic Atom2
    /// driver pulses RTS with DTR held high before it will talk at all
    /// (`oceanic_atom2.c`), so a missing slot would look like a dead cable
    /// rather than a bug. This is the shape of issue #334.
    func makeCallbacks() -> libdc_io_callbacks_t {
        var callbacks = libdc_io_callbacks_t()
        callbacks.userdata = Unmanaged.passUnretained(self).toOpaque()
        callbacks.set_timeout = { userdata, timeout in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!)
                .takeUnretainedValue()
            stream.timeoutMs = Int32(timeout)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.read = { userdata, data, size, actual in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!)
                .takeUnretainedValue()
            return stream.performRead(data!, size: size, actual: actual!)
        }
        callbacks.write = { userdata, data, size, actual in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!)
                .takeUnretainedValue()
            return stream.performWrite(data!, size: size, actual: actual!)
        }
        callbacks.close = { userdata in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!)
                .takeUnretainedValue()
            stream.close()
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.purge = { userdata, direction in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!)
                .takeUnretainedValue()
            return stream.performPurge(direction)
        }
        callbacks.sleep = { _, milliseconds in
            Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.configure = { userdata, baudrate, databits, parity, stopbits, flowcontrol in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!)
                .takeUnretainedValue()
            return stream.performConfigure(
                baudRate: baudrate, dataBits: databits, parity: parity,
                stopBits: stopbits, flowControl: flowcontrol)
        }
        callbacks.set_dtr = { userdata, value in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!)
                .takeUnretainedValue()
            return stream.performSetModemLine(
                FtdiProtocol.modemControlValue(dtr: value != 0))
        }
        callbacks.set_rts = { userdata, value in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!)
                .takeUnretainedValue()
            return stream.performSetModemLine(
                FtdiProtocol.modemControlValue(rts: value != 0))
        }
        // poll and ioctl are left NULL, as they are in the Windows backend.
        return callbacks
    }

    /// Sends a vendor control request. Returns nil on success or a description
    /// of the IOKit failure.
    private func sendControl(
        _ request: FtdiProtocol.Request, value: UInt16,
        index: UInt16 = FtdiProtocol.portIndex
    ) -> String? {
        guard let handle else { return "the cable is not open" }
        let rc = ftdi_usb_control(
            handle, FtdiProtocol.requestTypeOut, request.rawValue, value, index,
            UInt32(max(timeoutMs, 0)))
        return rc == 0 ? nil : "IOReturn 0x\(String(format: "%08X", rc))"
    }

    private func performSetModemLine(_ value: UInt16) -> Int32 {
        if let failure = sendControl(.setModemControl, value: value) {
            NativeLogger.e(
                "FtdiUsb", category: "USB",
                "Failed to set the modem control lines: \(failure)")
            return Int32(LIBDC_STATUS_IO)
        }
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performRead(
        _ buffer: UnsafeMutableRawPointer, size: Int,
        actual: UnsafeMutablePointer<Int>
    ) -> Int32 {
        guard let handle, let accumulator else {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }

        let packetSize = self.packetSize
        let outcome = accumulator.read(
            into: buffer, size: size, timeoutMs: timeoutMs
        ) { remainingMs in
            var packet = [UInt8](repeating: 0, count: packetSize)
            var transferred = 0
            let rc = packet.withUnsafeMutableBytes { raw in
                ftdi_usb_bulk_read(
                    handle, raw.baseAddress, packetSize, &transferred,
                    UInt32(max(remainingMs, 0)))
            }
            // A timeout is the pipe having nothing to say right now, which is
            // normal between device replies. Anything else is a real transport
            // failure and must not be retried as if it were merely slow.
            if rc != 0 && ftdi_usb_status_is_timeout(rc) == 0 {
                return .failure
            }
            return transferred > 0 ? .packet(Array(packet[0..<transferred])) : .idle
        }

        actual.pointee = outcome.bytesRead
        switch outcome.status {
        case .success: return Int32(LIBDC_STATUS_SUCCESS)
        case .timeout: return Int32(LIBDC_STATUS_TIMEOUT)
        case .io: return Int32(LIBDC_STATUS_IO)
        }
    }

    private func performWrite(
        _ buffer: UnsafeRawPointer, size: Int,
        actual: UnsafeMutablePointer<Int>
    ) -> Int32 {
        guard let handle else {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }

        var transferred = 0
        let rc = ftdi_usb_bulk_write(
            handle, buffer, size, &transferred, UInt32(max(timeoutMs, 0)))
        actual.pointee = transferred
        return rc == 0 ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_IO)
    }

    private func performPurge(_ direction: UInt32) -> Int32 {
        guard handle != nil else { return Int32(LIBDC_STATUS_IO) }

        // Drop bytes already pulled off the pipe as well as the chip's own
        // buffers. Purging only the chip would leave pre-purge payload sitting
        // in the accumulator, to surface in the next read.
        if direction & 0x01 != 0 {
            accumulator?.discardPending()
        }
        for value in FtdiProtocol.resetValues(forDirection: direction) {
            if let failure = sendControl(.reset, value: value) {
                NativeLogger.w("FtdiUsb", category: "USB", "Purge failed: \(failure)")
                return Int32(LIBDC_STATUS_IO)
            }
        }
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performConfigure(
        baudRate: UInt32, dataBits: UInt32, parity: UInt32,
        stopBits: UInt32, flowControl: UInt32
    ) -> Int32 {
        guard handle != nil else { return Int32(LIBDC_STATUS_IO) }

        guard let divisor = FtdiProtocol.baudDivisor(baudRate),
            let parityCode = FtdiProtocol.parity(fromLibdc: parity),
            let stopBitsCode = FtdiProtocol.stopBits(fromLibdc: stopBits),
            let flowControlCode = FtdiProtocol.flowControl(fromLibdc: flowControl),
            let dataWord = FtdiProtocol.dataWord(
                dataBits: dataBits, parity: parityCode, stopBits: stopBitsCode)
        else {
            NativeLogger.e(
                "FtdiUsb", category: "USB",
                "Unsupported line settings: \(baudRate) baud, \(dataBits) data bits, "
                    + "parity \(parity), stop bits \(stopBits), flow control \(flowControl)")
            return Int32(LIBDC_STATUS_INVALIDARGS)
        }

        // SET_BAUD_RATE is the one request that does not put the port number in
        // wIndex: on single-port parts the field carries the divisor's high
        // bits instead (libftdi's ftdi_convert_baudrate, and ftdi_sio.c's
        // change_speed, which only ORs in an interface number for the
        // multi-port FT2232 family). Passing portIndex here would corrupt the
        // divisor.
        if let failure = sendControl(
            .setBaudRate, value: divisor.value, index: divisor.index
        ) {
            NativeLogger.e(
                "FtdiUsb", category: "USB", "Failed to set baud rate: \(failure)")
            return Int32(LIBDC_STATUS_IO)
        }
        if let failure = sendControl(.setData, value: dataWord) {
            NativeLogger.e(
                "FtdiUsb", category: "USB", "Failed to set line format: \(failure)")
            return Int32(LIBDC_STATUS_IO)
        }
        if let failure = sendControl(
            .setFlowControl, value: 0,
            index: flowControlCode.rawValue | FtdiProtocol.portIndex
        ) {
            NativeLogger.e(
                "FtdiUsb", category: "USB", "Failed to set flow control: \(failure)")
            return Int32(LIBDC_STATUS_IO)
        }

        NativeLogger.i(
            "FtdiUsb", category: "USB",
            "Configured \(baudRate) baud, \(dataBits) data bits, parity \(parity), "
                + "stop bits \(stopBits)")
        return Int32(LIBDC_STATUS_SUCCESS)
    }
}
