import Foundation

// Standalone tests for the USB HID report framing used by the Scubapro G2 and
// Suunto EON Steel download path (issue #1271).
//
// libdivecomputer hands the transport a buffer whose first byte is the HID
// report id, a convention its own usbhid.c implements and every driver above
// it assumes. IOHIDDeviceSetReport takes that id as a separate argument, so
// the buffer has to be split before it can be sent.
//
// The rules asserted here come from two external sources, never from our
// implementation, so a wrong split cannot make its own test pass:
//
//   - libdivecomputer src/usbhid.c:745-775, the libusb branch: "Skip a report
//     id of zero", and the write is still reported as having consumed the
//     skipped byte.
//   - hidapi's macOS backend (mac/hid.c, set_report): a report id of zero
//     sends data+1 with length-1; a numbered report sends the whole buffer,
//     id byte included, because Apple requires the id to lead the report data
//     for numbered reports.
//
// Assertions use precondition() (not assert(), which the optimizer can elide)
// so a failure aborts the run even if these are ever built with -O.

func expect(_ condition: Bool, _ message: String) {
    precondition(condition, message)
}

// The Uwatec Smart driver always writes report id zero: uwatec_smart.c:287
// sets buf[0] = 0 and writes PACKETSIZE_USBHID_TX + 1 = 33 bytes. The 32-byte
// output report is what actually reaches the device.
func testZeroReportIdIsStripped() {
    var buffer = [UInt8](repeating: 0, count: 33)
    buffer[0] = 0
    buffer[1] = 2  // length byte
    buffer[2] = 0x1b  // command
    buffer[32] = 0xff  // last byte of the report must survive

    guard let report = UsbHidReportFraming.outgoingReport(from: buffer) else {
        preconditionFailure("a 33-byte buffer must produce a report")
    }
    expect(report.reportId == 0, "report id must be the first byte")
    expect(report.payload.count == 32, "the id byte must not be sent")
    expect(report.payload[0] == 2, "payload must start after the id")
    expect(report.payload[1] == 0x1b, "payload must keep the command byte")
    expect(report.payload[31] == 0xff, "payload must keep the last byte")
    print("PASS: testZeroReportIdIsStripped")
}

// A numbered report keeps its id byte in the payload, because Apple requires
// the id to lead the report data for numbered reports.
//
// This is the Suunto EON Steel family, not a hypothetical: suunto_eonsteel.c
// builds a 64-byte packet whose first byte is the report type 0x3f
// (suunto_eonsteel.c:242), writes the whole buffer, and checks buf[0] == 0x3f
// on the way back (suunto_eonsteel.c:156). Stripping that byte would fail
// every packet in both directions.
func testNumberedReportKeepsItsIdByte() {
    var buffer = [UInt8](repeating: 0, count: 64)
    buffer[0] = 0x3f  // report type, EON Steel
    buffer[1] = 12    // payload length
    buffer[63] = 0xcc

    guard let report = UsbHidReportFraming.outgoingReport(from: buffer) else {
        preconditionFailure("a 64-byte buffer must produce a report")
    }
    expect(report.reportId == 0x3f, "report id must be the first byte")
    expect(report.payload.count == 64, "a numbered report keeps its id byte")
    expect(report.payload == buffer, "a numbered report is sent verbatim")
    print("PASS: testNumberedReportKeepsItsIdByte")
}

// libdivecomputer short-circuits a zero-length write before it reaches the
// transport (usbhid.c:752), but the callback is reachable from any driver, and
// buffer[0] on an empty buffer is a read out of bounds.
func testEmptyBufferProducesNoReport() {
    expect(UsbHidReportFraming.outgoingReport(from: []) == nil,
           "an empty buffer has no report id to read")
    print("PASS: testEmptyBufferProducesNoReport")
}

// A one-byte buffer is a bare report id with nothing to send. It must produce
// an empty payload rather than nil: the write still succeeded as far as the
// caller is concerned, and reporting failure would abort a download.
func testBareReportIdProducesEmptyPayload() {
    guard let report = UsbHidReportFraming.outgoingReport(from: [0]) else {
        preconditionFailure("a bare report id is still a report")
    }
    expect(report.reportId == 0, "report id must be the first byte")
    expect(report.payload.isEmpty, "nothing follows a bare report id")
    print("PASS: testBareReportIdProducesEmptyPayload")
}

// Report sizes come from the device so a computer with a wider input report
// than the Uwatec family's 64 bytes is not silently truncated. Devices that
// publish nothing usable fall back to the caller's size.
func testReportSizePrefersTheDeviceMaximum() {
    expect(UsbHidReportFraming.reportSize(deviceMaximum: 64, fallback: 64) == 64,
           "a device maximum equal to the fallback is used as is")
    expect(UsbHidReportFraming.reportSize(deviceMaximum: 512, fallback: 64) == 512,
           "a wider device maximum must win")
    expect(UsbHidReportFraming.reportSize(deviceMaximum: nil, fallback: 64) == 64,
           "a device that publishes nothing falls back")
    expect(UsbHidReportFraming.reportSize(deviceMaximum: 0, fallback: 64) == 64,
           "a zero maximum is not a usable size")
    expect(UsbHidReportFraming.reportSize(deviceMaximum: -1, fallback: 64) == 64,
           "a negative maximum is not a usable size")
    // A narrower device report never shrinks the buffer below what the caller
    // asked for. The buffer is where one report lands, so over-allocating is
    // free while under-allocating would truncate a read.
    expect(UsbHidReportFraming.reportSize(deviceMaximum: 32, fallback: 64) == 64,
           "a narrower device maximum must not shrink the buffer")
    print("PASS: testReportSizePrefersTheDeviceMaximum")
}

testZeroReportIdIsStripped()
testNumberedReportKeepsItsIdByte()
testEmptyBufferProducesNoReport()
testBareReportIdProducesEmptyPayload()
testReportSizePrefersTheDeviceMaximum()
print("All USB HID report framing tests passed")
