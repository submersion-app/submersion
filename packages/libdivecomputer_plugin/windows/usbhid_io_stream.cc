#include "usbhid_io_stream.h"

// hidsdi.h declares HidD_*, hidpi.h declares HidP_GetCaps and HIDP_CAPS. The
// Windows SDK does not pull the second in through the first, so both are named.
extern "C" {
#include <hidsdi.h>
#include <hidpi.h>
}

#include <algorithm>
#include <cstring>

#pragma comment(lib, "hid.lib")

namespace libdivecomputer_plugin {
namespace {

// Report length used when the device publishes none. 64 bytes is the read size
// every HID dive computer driver in libdivecomputer asks for
// (PACKETSIZE_USBHID_RX, uwatec_smart.c:36), plus the report id byte Windows
// puts in front of every transfer.
constexpr size_t kFallbackReportLength = 65;

}  // namespace

UsbHidIoStream::UsbHidIoStream() = default;

UsbHidIoStream::~UsbHidIoStream() { Close(); }

std::string UsbHidIoStream::Open(const UsbHidDevice& device) {
    handle_ = CreateFileW(device.path.c_str(), GENERIC_READ | GENERIC_WRITE,
                          FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                          OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
    if (handle_ == INVALID_HANDLE_VALUE) {
        const DWORD error = GetLastError();
        if (error == ERROR_ACCESS_DENIED) {
            return "access denied, another application may be using it";
        }
        return "CreateFile failed (error " + std::to_string(error) + ")";
    }

    // Report lengths come from the device so hardware with reports wider than
    // the Uwatec family's 64 bytes is not truncated.
    input_report_length_ = kFallbackReportLength;
    output_report_length_ = kFallbackReportLength;
    PHIDP_PREPARSED_DATA preparsed = nullptr;
    if (HidD_GetPreparsedData(handle_, &preparsed)) {
        HIDP_CAPS caps = {};
        if (HidP_GetCaps(preparsed, &caps) == HIDP_STATUS_SUCCESS) {
            if (caps.InputReportByteLength > 0) {
                input_report_length_ = caps.InputReportByteLength;
            }
            if (caps.OutputReportByteLength > 0) {
                output_report_length_ = caps.OutputReportByteLength;
            }
        }
        HidD_FreePreparsedData(preparsed);
    }
    read_buffer_.assign(input_report_length_, 0);
    write_buffer_.assign(output_report_length_, 0);

    read_event_ = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    if (read_event_ == nullptr) {
        Close();
        return "CreateEvent failed (error " + std::to_string(GetLastError()) +
               ")";
    }
    read_overlapped_ = {};
    read_overlapped_.hEvent = read_event_;
    return {};
}

void UsbHidIoStream::Close() {
    if (handle_ != INVALID_HANDLE_VALUE) {
        if (read_pending_) {
            CancelIoEx(handle_, &read_overlapped_);
            // The overlapped structure and its buffer live in this object, so
            // the wait is not optional: returning while the driver may still
            // write into them would corrupt whatever reuses the memory.
            DWORD transferred = 0;
            GetOverlappedResult(handle_, &read_overlapped_, &transferred, TRUE);
            read_pending_ = false;
        }
        CloseHandle(handle_);
        handle_ = INVALID_HANDLE_VALUE;
    }
    if (read_event_ != nullptr) {
        CloseHandle(read_event_);
        read_event_ = nullptr;
    }
}

libdc_io_callbacks_t UsbHidIoStream::MakeCallbacks() {
    // configure, set_dtr and set_rts are deliberately left null. They are
    // serial line control and have no meaning for a report pipe;
    // libdivecomputer's own USB HID vtable leaves the equivalent slots null
    // (usbhid.c:150-160), and the bridge in libdc_download.c treats an unset
    // slot as a no-op.
    libdc_io_callbacks_t callbacks = {};
    callbacks.userdata = this;
    callbacks.set_timeout = SetTimeoutCallback;
    callbacks.read = ReadCallback;
    callbacks.write = WriteCallback;
    callbacks.close = CloseCallback;
    callbacks.sleep = SleepCallback;
    return callbacks;
}

int UsbHidIoStream::SetTimeoutCallback(void* userdata, int timeout) {
    static_cast<UsbHidIoStream*>(userdata)->timeout_ms_ = timeout;
    return LIBDC_STATUS_SUCCESS;
}

int UsbHidIoStream::ReadCallback(void* userdata, void* data, size_t size,
                                 size_t* actual) {
    return static_cast<UsbHidIoStream*>(userdata)->PerformRead(data, size,
                                                               actual);
}

int UsbHidIoStream::WriteCallback(void* userdata, const void* data, size_t size,
                                  size_t* actual) {
    return static_cast<UsbHidIoStream*>(userdata)->PerformWrite(data, size,
                                                                actual);
}

int UsbHidIoStream::CloseCallback(void* userdata) {
    static_cast<UsbHidIoStream*>(userdata)->Close();
    return LIBDC_STATUS_SUCCESS;
}

int UsbHidIoStream::SleepCallback(void*, unsigned int milliseconds) {
    Sleep(milliseconds);
    return LIBDC_STATUS_SUCCESS;
}

// Returns at most one input report.
//
// A timeout is success with zero bytes, not an error. That is what
// libdivecomputer's own USB HID read does (usbhid.c:728-742, where a hidapi
// timeout returns zero and DC_STATUS_SUCCESS), and the drivers above rely on
// it: uwatec_smart_usbhid_receive raises the protocol error itself when a
// packet comes back short.
int UsbHidIoStream::PerformRead(void* data, size_t size, size_t* actual) {
    if (actual != nullptr) *actual = 0;
    if (handle_ == INVALID_HANDLE_VALUE) return LIBDC_STATUS_IO;

    if (!read_pending_) {
        ResetEvent(read_event_);
        DWORD read_now = 0;
        if (!ReadFile(handle_, read_buffer_.data(),
                      static_cast<DWORD>(read_buffer_.size()), &read_now,
                      &read_overlapped_)) {
            if (GetLastError() != ERROR_IO_PENDING) {
                CancelIoEx(handle_, &read_overlapped_);
                return LIBDC_STATUS_IO;
            }
        }
        read_pending_ = true;
    }

    const DWORD wait = WaitForSingleObject(
        read_event_, timeout_ms_ < 0 ? INFINITE
                                     : static_cast<DWORD>(timeout_ms_));
    if (wait == WAIT_TIMEOUT) {
        // Left pending on purpose: see read_pending_ in the header.
        return LIBDC_STATUS_SUCCESS;
    }
    if (wait != WAIT_OBJECT_0) return LIBDC_STATUS_IO;

    DWORD transferred = 0;
    const BOOL ok =
        GetOverlappedResult(handle_, &read_overlapped_, &transferred, FALSE);
    read_pending_ = false;
    if (!ok) return LIBDC_STATUS_IO;
    if (transferred == 0) return LIBDC_STATUS_SUCCESS;

    // Windows puts a report id byte in front of every input report, including
    // for devices that do not use numbered reports, where it is always zero.
    // macOS and Linux hand back the report without it, and libdivecomputer's
    // drivers expect the macOS and Linux shape, so the zero byte is dropped
    // here. hidapi's Windows backend does the same, for the same reason.
    const unsigned char* source = read_buffer_.data();
    size_t available = transferred;
    if (available > 0 && source[0] == 0) {
        source++;
        available--;
    }

    const size_t copied = (std::min)(size, available);
    std::memcpy(data, source, copied);
    if (actual != nullptr) *actual = copied;
    return LIBDC_STATUS_SUCCESS;
}

// Sends one output report.
//
// The buffer's first byte is the HID report id, which is exactly what Windows
// wants at the front of a WriteFile, so unlike the macOS backend nothing is
// stripped here.
//
// Windows wants exactly OutputReportByteLength bytes. A shorter report is
// padded, as hidapi's Windows backend does. A longer one cannot be padded down
// and the driver would reject it, so it is refused here rather than handed to
// WriteFile: the write fails either way, and INVALIDARGS says the caller asked
// for something impossible while an I/O error would suggest the cable. hidapi
// passes the oversized buffer through instead; no driver sends one, so the
// difference is only in which failure a future one would see.
int UsbHidIoStream::PerformWrite(const void* data, size_t size,
                                 size_t* actual) {
    if (actual != nullptr) *actual = 0;
    if (handle_ == INVALID_HANDLE_VALUE) return LIBDC_STATUS_IO;
    if (size == 0) return LIBDC_STATUS_SUCCESS;

    if (size > output_report_length_) {
        return LIBDC_STATUS_INVALIDARGS;
    }

    const unsigned char* source = static_cast<const unsigned char*>(data);
    const unsigned char* buffer = source;
    size_t length = size;
    if (size < output_report_length_) {
        std::memcpy(write_buffer_.data(), source, size);
        std::memset(write_buffer_.data() + size, 0,
                    output_report_length_ - size);
        buffer = write_buffer_.data();
        length = output_report_length_;
    }

    HANDLE write_event = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    if (write_event == nullptr) return LIBDC_STATUS_IO;
    OVERLAPPED overlapped = {};
    overlapped.hEvent = write_event;

    int status = LIBDC_STATUS_SUCCESS;
    DWORD written = 0;
    if (!WriteFile(handle_, buffer, static_cast<DWORD>(length), &written,
                   &overlapped)) {
        if (GetLastError() != ERROR_IO_PENDING) {
            status = LIBDC_STATUS_IO;
        } else {
            const DWORD wait = WaitForSingleObject(
                write_event,
                timeout_ms_ < 0 ? INFINITE : static_cast<DWORD>(timeout_ms_));

            // Classified the same way PerformRead classifies its wait. Folding
            // everything that is not WAIT_OBJECT_0 into a timeout would report
            // WAIT_FAILED, which means the wait itself broke, as though the
            // dive computer had simply been slow.
            if (wait != WAIT_OBJECT_0) {
                // CancelIoEx, not CancelIo: CancelIo cancels every operation
                // the calling thread has outstanding on this handle, and reads
                // and writes both come from libdivecomputer's one download
                // thread. Cancelling broadly would take the read that
                // PerformRead deliberately leaves pending, and the next read
                // would then fail with ERROR_OPERATION_ABORTED for no reason.
                CancelIoEx(handle_, &overlapped);
                GetOverlappedResult(handle_, &overlapped, &written, TRUE);
                status = wait == WAIT_TIMEOUT ? LIBDC_STATUS_TIMEOUT
                                              : LIBDC_STATUS_IO;
            } else if (!GetOverlappedResult(handle_, &overlapped, &written,
                                            FALSE)) {
                status = LIBDC_STATUS_IO;
            }
        }
    }
    CloseHandle(write_event);

    if (status != LIBDC_STATUS_SUCCESS) return status;

    // A HID report reaches the device whole or not at all, so a short write is
    // a failure rather than a partial success. Reporting it upward as success
    // would leave the device holding half a command and desynchronise every
    // exchange after it.
    if (written != static_cast<DWORD>(length)) return LIBDC_STATUS_IO;

    // The caller counts the bytes it handed over, not the padding, exactly as
    // libdivecomputer's own write does (usbhid.c:776-778).
    if (actual != nullptr) *actual = size;
    return LIBDC_STATUS_SUCCESS;
}

}  // namespace libdivecomputer_plugin
