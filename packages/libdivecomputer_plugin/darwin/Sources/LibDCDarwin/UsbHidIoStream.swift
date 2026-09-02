import Foundation
#if os(macOS)
import IOKit
import IOKit.hid
#endif

/// USB HID byte pipe for libdivecomputer, backed by IOKit's HID family.
///
/// This is the transport the Scubapro G2 family and the Suunto EON Steel
/// family speak over a USB cable (issue #1271). Both are driven by
/// libdivecomputer code that already knows the HID framing: passing
/// `LIBDC_TRANSPORT_USBHID` to `dc_custom_open` makes `uwatec_smart.c` and
/// `suunto_eonsteel.c` size their packets as HID reports, so all this class
/// owes them is one report per read and one report per write.
///
/// Input reports arrive on a dedicated run loop and queue into a
/// `PacketReadBuffer`, which is the same structure the BLE transport uses and
/// for the same reason: it preserves packet boundaries, so a read never
/// returns bytes from two reports. Coalescing them would corrupt the length
/// byte that leads every Uwatec reply (`uwatec_smart.c:377`).
///
/// The caller must keep this object alive while the callbacks are in use: the
/// callback table's userdata pointer is unretained.
final class UsbHidIoStream {
    /// Report size used when the device publishes none. 64 bytes is the read
    /// size every HID dive computer driver in libdivecomputer asks for
    /// (`PACKETSIZE_USBHID_RX`, `uwatec_smart.c:36`).
    private static let fallbackReportSize = 64

    private var timeoutMs: Int32 = 10000
    private let buffer = PacketReadBuffer()

    #if os(macOS)
    private var device: IOHIDDevice?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private var reportBufferLength = 0

    /// The thread whose run loop delivers input report callbacks, and that run
    /// loop. Both are nil until `open` succeeds.
    private var readThread: Thread?
    private var readRunLoop: CFRunLoop?
    /// Signalled once the read thread has scheduled the device and is running.
    private let readLoopReady = DispatchSemaphore(value: 0)
    /// Signalled once the read thread has unscheduled the device and returned.
    /// `close` waits on it before freeing the report buffer, which IOKit is
    /// still writing into until the device is unscheduled.
    private let readLoopFinished = DispatchSemaphore(value: 0)
    /// Set by `stopReadLoop`, read by the read thread between run loop passes.
    ///
    /// CFRunLoopStop alone is not enough to end the loop, because it only
    /// records the request when the loop is already running: it sets
    /// `_stopped` on `rl->_currentMode` and does nothing when there is no
    /// current mode. A stop that lands between the thread signalling readiness
    /// and entering CFRunLoopRun would be dropped, and the loop would then run
    /// for the lifetime of the process, leaking the thread and the report
    /// buffer. A flag the thread re-reads each pass cannot be missed whichever
    /// order the two threads happen to run in.
    private let stopLock = NSLock()
    private var readLoopStopRequested = false

    deinit {
        close()
    }

    /// Opens the device. Returns nil on success, or the reason it was refused.
    ///
    /// The failure is returned rather than collapsed to a Bool so the probe can
    /// tell the user which of the plausible causes applies: a computer that has
    /// been unplugged since it was listed reads differently from one another
    /// process has seized.
    func open(device hidDevice: UsbHidDevice) -> String? {
        guard let ref = UsbHidDeviceEnumerator.makeHidDevice(for: hidDevice) else {
            return "the device is no longer attached"
        }

        let result = IOHIDDeviceOpen(ref, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            return "IOHIDDeviceOpen failed (0x\(String(result, radix: 16)))"
        }

        device = ref
        reportBufferLength = UsbHidReportFraming.reportSize(
            deviceMaximum: hidDevice.maxInputReportSize,
            fallback: Self.fallbackReportSize)
        reportBuffer = UnsafeMutablePointer<UInt8>.allocate(
            capacity: reportBufferLength)
        reportBuffer?.initialize(repeating: 0, count: reportBufferLength)

        startReadLoop()
        return nil
    }

    func close() {
        stopReadLoop()

        if let ref = device {
            IOHIDDeviceClose(ref, IOOptionBits(kIOHIDOptionsTypeNone))
            device = nil
        }
        if let allocated = reportBuffer {
            allocated.deinitialize(count: reportBufferLength)
            allocated.deallocate()
            reportBuffer = nil
            reportBufferLength = 0
        }
        buffer.purge()
    }

    // MARK: - Read loop

    /// Input reports are delivered by a run loop source, so the device needs a
    /// run loop that is actually running. libdivecomputer's download thread is
    /// blocked inside a read for most of a transfer and cannot serve one, and
    /// the main run loop belongs to Flutter, so this owns a thread whose only
    /// job is to pump callbacks for the life of the download.
    private func startReadLoop() {
        guard let ref = device, let reports = reportBuffer else { return }
        let length = reportBufferLength

        stopLock.lock()
        readLoopStopRequested = false
        stopLock.unlock()

        let thread = Thread { [weak self] in
            guard let self else { return }
            let loop: CFRunLoop = CFRunLoopGetCurrent()
            self.readRunLoop = loop

            // The callback's separate reportID argument is deliberately
            // ignored, and the report buffer passed through untouched.
            //
            // That matters for the Suunto EON Steel, which uses a numbered
            // report: suunto_eonsteel.c:156 rejects any reply whose first byte
            // is not 0x3f, so the id byte has to survive. IOKit puts it at the
            // front of the report buffer for a numbered device, and omits it
            // for an unnumbered one, which is exactly the shape hidraw
            // delivers on Linux and what libdivecomputer's drivers assume.
            //
            // hidapi's macOS backend does the same thing, discarding report_id
            // and copying the buffer verbatim, and Subsurface downloads an EON
            // Steel over USB on macOS through it. Reading the id byte out of
            // the argument and prepending it here would double it.
            IOHIDDeviceRegisterInputReportCallback(
                ref, reports, length,
                { context, result, _, _, _, report, reportLength in
                    guard let context, result == kIOReturnSuccess, reportLength > 0
                    else { return }
                    let stream = Unmanaged<UsbHidIoStream>
                        .fromOpaque(context).takeUnretainedValue()
                    stream.buffer.append(Data(bytes: report, count: reportLength))
                },
                Unmanaged.passUnretained(self).toOpaque())
            IOHIDDeviceScheduleWithRunLoop(
                ref, loop, CFRunLoopMode.defaultMode.rawValue)

            // A run loop with no input source returns from CFRunLoopRun
            // immediately. A port that is never signalled is the conventional
            // way to hold one open, and it is also what CFRunLoopStop needs in
            // order to have a loop left to stop.
            RunLoop.current.add(NSMachPort(), forMode: .default)

            self.readLoopReady.signal()

            // Bounded passes rather than one open-ended CFRunLoopRun, so the
            // stop flag is re-read regularly. CFRunLoopStop still makes the
            // exit immediate in the ordinary case; this only removes the
            // dependency on the stop arriving while the loop is running.
            while !self.isReadLoopStopRequested {
                CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.25, false)
            }

            // Unregistering before unscheduling means IOKit is finished with
            // the report buffer by the time close() frees it.
            IOHIDDeviceRegisterInputReportCallback(ref, reports, length, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(
                ref, loop, CFRunLoopMode.defaultMode.rawValue)
            self.readLoopFinished.signal()
        }
        thread.name = "app.submersion.usbhid"
        thread.start()
        readThread = thread

        // Waiting for the loop to be running before the first write means a
        // reply cannot arrive before the callback is registered. The timeout is
        // a guard against a thread that never starts, not an expected path.
        _ = readLoopReady.wait(timeout: .now() + .seconds(5))
    }

    private var isReadLoopStopRequested: Bool {
        stopLock.lock()
        defer { stopLock.unlock() }
        return readLoopStopRequested
    }

    private func stopReadLoop() {
        // Raised before the run loop is touched, so a stop that arrives before
        // the loop starts is still seen on its first pass.
        stopLock.lock()
        readLoopStopRequested = true
        stopLock.unlock()

        guard let loop = readRunLoop else {
            readThread = nil
            return
        }
        readRunLoop = nil
        // CFRunLoopStop wakes the loop itself when one is running, so no
        // separate CFRunLoopWakeUp is needed here.
        CFRunLoopStop(loop)
        // Bounded so a wedged run loop cannot hang the download thread. Losing
        // the race leaks the report buffer, which is the safe way to lose it:
        // freeing memory IOKit may still write to would corrupt the heap.
        if readLoopFinished.wait(timeout: .now() + .seconds(5)) == .timedOut {
            reportBuffer = nil
            reportBufferLength = 0
        }
        readThread = nil
    }

    // MARK: - Callbacks

    /// Returns `libdc_io_callbacks_t` filled with function pointers to this
    /// stream. The caller must keep this object alive while they are in use.
    ///
    /// `configure`, `set_dtr` and `set_rts` are deliberately left unset. They
    /// are serial line control and have no meaning for a report pipe;
    /// libdivecomputer's own USB HID vtable leaves the equivalent slots null
    /// (`usbhid.c:150-160`), and the bridge in `libdc_download.c` treats an
    /// unset slot as a no-op.
    func makeCallbacks() -> libdc_io_callbacks_t {
        var callbacks = libdc_io_callbacks_t()
        callbacks.userdata = Unmanaged.passUnretained(self).toOpaque()
        callbacks.set_timeout = { userdata, timeout in
            let stream = Unmanaged<UsbHidIoStream>
                .fromOpaque(userdata!).takeUnretainedValue()
            stream.timeoutMs = Int32(timeout)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.read = { userdata, data, size, actual in
            let stream = Unmanaged<UsbHidIoStream>
                .fromOpaque(userdata!).takeUnretainedValue()
            return stream.performRead(data!, size: size, actual: actual!)
        }
        callbacks.write = { userdata, data, size, actual in
            let stream = Unmanaged<UsbHidIoStream>
                .fromOpaque(userdata!).takeUnretainedValue()
            return stream.performWrite(data!, size: size, actual: actual!)
        }
        callbacks.poll = { userdata, timeout in
            let stream = Unmanaged<UsbHidIoStream>
                .fromOpaque(userdata!).takeUnretainedValue()
            return stream.performPoll(timeout)
        }
        callbacks.purge = { userdata, _ in
            let stream = Unmanaged<UsbHidIoStream>
                .fromOpaque(userdata!).takeUnretainedValue()
            stream.buffer.purge()
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.sleep = { _, milliseconds in
            Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.close = { userdata in
            let stream = Unmanaged<UsbHidIoStream>
                .fromOpaque(userdata!).takeUnretainedValue()
            stream.close()
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        return callbacks
    }

    /// Returns at most one input report.
    ///
    /// A timeout is success with zero bytes, not an error. That is what
    /// libdivecomputer's own USB HID read does (`usbhid.c:728-742`, where a
    /// hidapi timeout returns zero and `DC_STATUS_SUCCESS`), and the drivers
    /// above rely on it: `uwatec_smart_usbhid_receive` raises the protocol
    /// error itself when a packet comes back short.
    private func performRead(
        _ dest: UnsafeMutableRawPointer, size: Int,
        actual: UnsafeMutablePointer<Int>
    ) -> Int32 {
        guard device != nil else {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }
        let count = buffer.read(
            into: dest, maxBytes: size, deadline: Self.deadline(for: timeoutMs))
        actual.pointee = count ?? 0
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    /// Sends one output report.
    ///
    /// The buffer's first byte is the HID report id, which IOKit takes as a
    /// separate argument; `UsbHidReportFraming` does that split. The whole
    /// buffer counts as written even when the id byte was dropped, matching
    /// `usbhid.c:776-778`, because the caller counts the bytes it handed over,
    /// not the bytes that went on the wire.
    private func performWrite(
        _ data: UnsafeRawPointer, size: Int,
        actual: UnsafeMutablePointer<Int>
    ) -> Int32 {
        actual.pointee = 0
        guard let ref = device else { return Int32(LIBDC_STATUS_IO) }

        // Nothing to send is a success, not an error. libdivecomputer's own
        // USB HID write short-circuits it that way (`usbhid.c:750-752`), and so
        // do the Windows and Linux backends here, so failing it would make
        // macOS the only one of the four that aborts a download over it.
        if size == 0 { return Int32(LIBDC_STATUS_SUCCESS) }

        let bytes = Array(UnsafeRawBufferPointer(start: data, count: size))
        guard let report = UsbHidReportFraming.outgoingReport(from: bytes) else {
            // Unreachable while size > 0, since a non-empty buffer always has a
            // report id. Kept so a future caller cannot reach IOKit with a
            // buffer this has not framed.
            return Int32(LIBDC_STATUS_INVALIDARGS)
        }

        let result = report.payload.withUnsafeBufferPointer { payload -> IOReturn in
            guard let base = payload.baseAddress else { return kIOReturnSuccess }
            return IOHIDDeviceSetReport(
                ref, kIOHIDReportTypeOutput, CFIndex(report.reportId),
                base, payload.count)
        }
        guard result == kIOReturnSuccess else {
            return Int32(LIBDC_STATUS_IO)
        }

        actual.pointee = size
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performPoll(_ timeout: Int32) -> Int32 {
        return buffer.poll(deadline: Self.deadline(for: timeout))
            ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_TIMEOUT)
    }

    /// Turns a libdivecomputer timeout into an absolute deadline.
    ///
    /// Negative means block indefinitely, zero means do not block at all, and
    /// positive bounds the wait. That is libdivecomputer's own contract, set by
    /// `dc_serial_poll` (serial_posix.c:677-686), which passes a null timeval
    /// to select for a negative timeout and a zeroed one for zero.
    ///
    /// Worth a named helper rather than the arithmetic inline: adding a
    /// negative interval to `now()` yields a deadline already in the past, so
    /// the infinite case silently becomes the most impatient one. The Windows
    /// backend spells this out with INFINITE and the Linux backend gets it from
    /// poll(2), so macOS was the only one of the three that had it wrong.
    private static func deadline(for timeoutMs: Int32) -> DispatchTime {
        timeoutMs < 0 ? .distantFuture : .now() + .milliseconds(Int(timeoutMs))
    }
    #else
    // iOS has no USB host role. The type stays declared so the shared host API
    // compiles, but nothing can ever open it.
    func open(device hidDevice: UsbHidDevice) -> String? {
        "USB HID is not available on this platform"
    }

    func close() {}

    func makeCallbacks() -> libdc_io_callbacks_t {
        libdc_io_callbacks_t()
    }
    #endif
}
