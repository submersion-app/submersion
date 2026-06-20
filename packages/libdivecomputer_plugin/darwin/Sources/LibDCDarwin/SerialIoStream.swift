import Foundation

/// Wraps POSIX serial I/O and provides libdc_io_callbacks_t for libdivecomputer.
///
/// Uses standard POSIX APIs (open, read, write, select, tcsetattr, tcflush)
/// which are available on both macOS and iOS, though serial device files
/// only exist on macOS. The caller must keep this SerialIoStream alive
/// while the callbacks are in use.
class SerialIoStream {
    private var fileDescriptor: Int32 = -1
    private var timeoutMs: Int32 = 10000

    deinit {
        close()
    }

    func open(path: String, baudRate: speed_t = 9600) -> Bool {
        fileDescriptor = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor >= 0 else { return false }

        // Configure serial port.
        var options = termios()
        tcgetattr(fileDescriptor, &options)
        cfsetispeed(&options, baudRate)
        cfsetospeed(&options, baudRate)
        options.c_cflag |= UInt(CS8 | CLOCAL | CREAD)
        options.c_iflag = 0
        options.c_oflag = 0
        options.c_lflag = 0
        tcsetattr(fileDescriptor, TCSANOW, &options)

        // Switch back to blocking mode.
        let flags = fcntl(fileDescriptor, F_GETFL)
        _ = fcntl(fileDescriptor, F_SETFL, flags & ~O_NONBLOCK)

        return true
    }

    func close() {
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    /// Returns libdc_io_callbacks_t filled with function pointers to this stream.
    /// The caller must keep this SerialIoStream alive while the callbacks are in use.
    func makeCallbacks() -> libdc_io_callbacks_t {
        var callbacks = libdc_io_callbacks_t()
        callbacks.userdata = Unmanaged.passUnretained(self).toOpaque()
        callbacks.set_timeout = { userdata, timeout in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            stream.timeoutMs = Int32(timeout)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.read = { userdata, data, size, actual in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performRead(data!, size: size, actual: actual!)
        }
        callbacks.write = { userdata, data, size, actual in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performWrite(data!, size: size, actual: actual!)
        }
        callbacks.close = { userdata in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            stream.close()
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.purge = { userdata, direction in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performPurge(direction)
        }
        callbacks.sleep = { _, milliseconds in
            Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        // Serial line-control callbacks. Without these the bridge in
        // libdc_download.c treats configure/DTR/RTS as no-ops, leaving the port
        // at its open() default (9600 8N1). Devices like the Mares Puck Pro
        // (ICONHD family) require 115200 8E1 with DTR/RTS deasserted, so they
        // never respond unless these are honored.
        callbacks.configure = { userdata, baudrate, databits, parity, stopbits, flowcontrol in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performConfigure(
                baudRate: baudrate, dataBits: databits, parity: parity,
                stopBits: stopbits, flowControl: flowcontrol)
        }
        callbacks.set_dtr = { userdata, value in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performSetModemLine(TIOCM_DTR, value: value)
        }
        callbacks.set_rts = { userdata, value in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performSetModemLine(TIOCM_RTS, value: value)
        }
        return callbacks
    }

    private func performRead(
        _ buffer: UnsafeMutableRawPointer, size: Int,
        actual: UnsafeMutablePointer<Int>
    ) -> Int32 {
        guard fileDescriptor >= 0 else {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }

        // Use poll() for timeout support (simpler than select() in Swift).
        var pfd = pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0)
        let ready = poll(&pfd, 1, timeoutMs)
        if ready < 0 {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }
        if ready == 0 {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_TIMEOUT)
        }

        let n = Darwin.read(fileDescriptor, buffer, size)
        if n < 0 {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }
        actual.pointee = n
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performWrite(
        _ buffer: UnsafeRawPointer, size: Int,
        actual: UnsafeMutablePointer<Int>
    ) -> Int32 {
        guard fileDescriptor >= 0 else {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }

        let n = Darwin.write(fileDescriptor, buffer, size)
        if n < 0 {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }
        actual.pointee = n
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performPurge(_ direction: UInt32) -> Int32 {
        guard fileDescriptor >= 0 else { return Int32(LIBDC_STATUS_IO) }
        // Flush input and/or output buffers.
        let queue: Int32
        if direction == 1 {
            queue = TCIFLUSH
        } else if direction == 2 {
            queue = TCOFLUSH
        } else {
            queue = TCIOFLUSH
        }
        tcflush(fileDescriptor, queue)
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    /// Applies the serial line settings libdivecomputer requests for a device.
    ///
    /// Mirrors the Linux backend (serial_io_stream.c serial_configure). On
    /// Darwin, speed_t constants equal their numeric baud values, so an
    /// arbitrary baud rate can be set directly without a Bxxxx lookup table.
    /// parity: 0=none, 1=odd, 2=even. stopbits: 2=two, else one.
    /// flowcontrol: 0=none, 1=software (XON/XOFF), 2=hardware (RTS/CTS).
    private func performConfigure(
        baudRate: UInt32, dataBits: UInt32, parity: UInt32,
        stopBits: UInt32, flowControl: UInt32
    ) -> Int32 {
        guard fileDescriptor >= 0 else { return Int32(LIBDC_STATUS_IO) }

        var options = termios()
        if tcgetattr(fileDescriptor, &options) != 0 { return Int32(LIBDC_STATUS_IO) }

        let speed = speed_t(baudRate)
        cfsetispeed(&options, speed)
        cfsetospeed(&options, speed)

        // Data bits.
        options.c_cflag &= ~UInt(CSIZE)
        switch dataBits {
        case 5: options.c_cflag |= UInt(CS5)
        case 6: options.c_cflag |= UInt(CS6)
        case 7: options.c_cflag |= UInt(CS7)
        default: options.c_cflag |= UInt(CS8)
        }

        // Parity.
        if parity == 0 {
            options.c_cflag &= ~UInt(PARENB)
        } else {
            options.c_cflag |= UInt(PARENB)
            if parity == 1 {
                options.c_cflag |= UInt(PARODD)
            } else {
                options.c_cflag &= ~UInt(PARODD)
            }
        }

        // Stop bits.
        if stopBits == 2 {
            options.c_cflag |= UInt(CSTOPB)
        } else {
            options.c_cflag &= ~UInt(CSTOPB)
        }

        // Flow control.
        if flowControl == 2 {
            options.c_cflag |= UInt(CRTSCTS)
            options.c_iflag &= ~UInt(IXON | IXOFF)
        } else if flowControl == 1 {
            options.c_cflag &= ~UInt(CRTSCTS)
            options.c_iflag |= UInt(IXON | IXOFF)
        } else {
            options.c_cflag &= ~UInt(CRTSCTS)
            options.c_iflag &= ~UInt(IXON | IXOFF)
        }

        return tcsetattr(fileDescriptor, TCSANOW, &options) == 0
            ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_IO)
    }

    /// Asserts or clears a modem-control line (DTR or RTS) via TIOCMGET/TIOCMSET.
    /// `bit` is TIOCM_DTR or TIOCM_RTS; `value` non-zero asserts the line.
    private func performSetModemLine(_ bit: Int32, value: UInt32) -> Int32 {
        guard fileDescriptor >= 0 else { return Int32(LIBDC_STATUS_IO) }

        var flags: Int32 = 0
        if ioctl(fileDescriptor, UInt(TIOCMGET), &flags) != 0 {
            return Int32(LIBDC_STATUS_IO)
        }
        if value != 0 {
            flags |= bit
        } else {
            flags &= ~bit
        }
        return ioctl(fileDescriptor, UInt(TIOCMSET), &flags) == 0
            ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_IO)
    }
}
