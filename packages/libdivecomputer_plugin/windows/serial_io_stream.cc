#include "serial_io_stream.h"

#include <algorithm>
#include <cstring>
#include <string>

namespace libdivecomputer_plugin {

SerialIoStream::SerialIoStream() = default;

SerialIoStream::~SerialIoStream() { Close(); }

bool SerialIoStream::Open(const std::string& port_name) {
    // COM port paths above COM9 require the \\.\COMx prefix.
    std::string path = "\\\\.\\" + port_name;

    handle_ = CreateFileA(
        path.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr,
        OPEN_EXISTING, 0, nullptr);
    if (handle_ == INVALID_HANDLE_VALUE) return false;

    // Configure 9600 baud, 8N1.
    DCB dcb = {};
    dcb.DCBlength = sizeof(DCB);
    if (!GetCommState(handle_, &dcb)) {
        CloseHandle(handle_);
        handle_ = INVALID_HANDLE_VALUE;
        return false;
    }

    dcb.BaudRate = CBR_9600;
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;
    dcb.fBinary = TRUE;
    dcb.fParity = FALSE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDtrControl = DTR_CONTROL_ENABLE;
    dcb.fRtsControl = RTS_CONTROL_ENABLE;
    dcb.fOutX = FALSE;
    dcb.fInX = FALSE;

    if (!SetCommState(handle_, &dcb)) {
        CloseHandle(handle_);
        handle_ = INVALID_HANDLE_VALUE;
        return false;
    }

    // Set initial timeouts.
    COMMTIMEOUTS timeouts = {};
    timeouts.ReadIntervalTimeout = 0;
    timeouts.ReadTotalTimeoutMultiplier = 0;
    timeouts.ReadTotalTimeoutConstant = static_cast<DWORD>(timeout_ms_);
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = static_cast<DWORD>(timeout_ms_);

    SetCommTimeouts(handle_, &timeouts);
    return true;
}

void SerialIoStream::Close() {
    if (handle_ != INVALID_HANDLE_VALUE) {
        CloseHandle(handle_);
        handle_ = INVALID_HANDLE_VALUE;
    }
}

libdc_io_callbacks_t SerialIoStream::MakeCallbacks() {
    libdc_io_callbacks_t cbs = {};
    cbs.userdata = this;
    cbs.set_timeout = SetTimeoutCallback;
    cbs.read = ReadCallback;
    cbs.write = WriteCallback;
    cbs.close = CloseCallback;
    cbs.configure = ConfigureCallback;
    cbs.set_dtr = SetDtrCallback;
    cbs.set_rts = SetRtsCallback;
    cbs.ioctl = nullptr;
    cbs.poll = nullptr;
    cbs.purge = nullptr;
    cbs.sleep = nullptr;
    return cbs;
}

int SerialIoStream::SetTimeoutCallback(void* userdata, int timeout) {
    auto* stream = static_cast<SerialIoStream*>(userdata);
    stream->timeout_ms_ = (timeout < 0) ? 30000 : timeout;

    if (stream->handle_ != INVALID_HANDLE_VALUE) {
        COMMTIMEOUTS timeouts = {};
        timeouts.ReadIntervalTimeout = 0;
        timeouts.ReadTotalTimeoutMultiplier = 0;
        timeouts.ReadTotalTimeoutConstant =
            static_cast<DWORD>(stream->timeout_ms_);
        timeouts.WriteTotalTimeoutMultiplier = 0;
        timeouts.WriteTotalTimeoutConstant =
            static_cast<DWORD>(stream->timeout_ms_);
        SetCommTimeouts(stream->handle_, &timeouts);
    }

    return LIBDC_STATUS_SUCCESS;
}

int SerialIoStream::ReadCallback(void* userdata, void* data, size_t size,
                                  size_t* actual) {
    auto* stream = static_cast<SerialIoStream*>(userdata);
    size_t transferred = 0;
    int status = stream->PerformRead(data, size, &transferred);
    if (actual) *actual = transferred;
    return status;
}

int SerialIoStream::WriteCallback(void* userdata, const void* data,
                                   size_t size, size_t* actual) {
    auto* stream = static_cast<SerialIoStream*>(userdata);
    size_t transferred = 0;
    int status = stream->PerformWrite(data, size, &transferred);
    if (actual) *actual = transferred;
    return status;
}

int SerialIoStream::CloseCallback(void* userdata) {
    auto* stream = static_cast<SerialIoStream*>(userdata);
    stream->Close();
    return LIBDC_STATUS_SUCCESS;
}

int SerialIoStream::ConfigureCallback(void* userdata, unsigned int baudrate,
                                      unsigned int databits, unsigned int parity,
                                      unsigned int stopbits, unsigned int flowcontrol) {
    auto* stream = static_cast<SerialIoStream*>(userdata);
    if (stream->handle_ == INVALID_HANDLE_VALUE) return LIBDC_STATUS_IO;

    DCB dcb = {};
    dcb.DCBlength = sizeof(DCB);
    if (!GetCommState(stream->handle_, &dcb)) return LIBDC_STATUS_IO;

    dcb.BaudRate = baudrate;
    dcb.ByteSize = static_cast<BYTE>(databits);
    dcb.Parity = static_cast<BYTE>(parity);
    dcb.StopBits = static_cast<BYTE>(stopbits);
    // flowcontrol: 0=none, 1=software, 2=hardware (matches dc_flowcontrol_t)
    dcb.fOutxCtsFlow = (flowcontrol == 2) ? TRUE : FALSE;
    dcb.fRtsControl = (flowcontrol == 2) ? RTS_CONTROL_HANDSHAKE : RTS_CONTROL_ENABLE;
    dcb.fOutX = (flowcontrol == 1) ? TRUE : FALSE;
    dcb.fInX = (flowcontrol == 1) ? TRUE : FALSE;

    return SetCommState(stream->handle_, &dcb) ? LIBDC_STATUS_SUCCESS : LIBDC_STATUS_IO;
}

int SerialIoStream::SetDtrCallback(void* userdata, unsigned int value) {
    auto* stream = static_cast<SerialIoStream*>(userdata);
    if (stream->handle_ == INVALID_HANDLE_VALUE) return LIBDC_STATUS_IO;
    return EscapeCommFunction(stream->handle_, value ? SETDTR : CLRDTR)
           ? LIBDC_STATUS_SUCCESS : LIBDC_STATUS_IO;
}

int SerialIoStream::SetRtsCallback(void* userdata, unsigned int value) {
    auto* stream = static_cast<SerialIoStream*>(userdata);
    if (stream->handle_ == INVALID_HANDLE_VALUE) return LIBDC_STATUS_IO;
    return EscapeCommFunction(stream->handle_, value ? SETRTS : CLRRTS)
           ? LIBDC_STATUS_SUCCESS : LIBDC_STATUS_IO;
}

int SerialIoStream::PerformRead(void* data, size_t size, size_t* actual) {
    if (handle_ == INVALID_HANDLE_VALUE) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }

    DWORD bytes_read = 0;
    BOOL ok = ReadFile(handle_, data, static_cast<DWORD>(size),
                       &bytes_read, nullptr);
    if (!ok) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }

    *actual = static_cast<size_t>(bytes_read);
    if (bytes_read == 0) {
        return LIBDC_STATUS_TIMEOUT;
    }
    return LIBDC_STATUS_SUCCESS;
}

int SerialIoStream::PerformWrite(const void* data, size_t size,
                                  size_t* actual) {
    if (handle_ == INVALID_HANDLE_VALUE) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }

    DWORD bytes_written = 0;
    BOOL ok = WriteFile(handle_, data, static_cast<DWORD>(size),
                        &bytes_written, nullptr);
    if (!ok) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }

    *actual = static_cast<size_t>(bytes_written);
    return LIBDC_STATUS_SUCCESS;
}

}  // namespace libdivecomputer_plugin
