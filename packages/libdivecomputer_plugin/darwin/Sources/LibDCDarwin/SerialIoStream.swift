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
}
