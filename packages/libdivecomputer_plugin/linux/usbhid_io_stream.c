#include "usbhid_io_stream.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <string.h>
#include <unistd.h>

UsbHidIoStream* usbhid_io_stream_new(void) {
    UsbHidIoStream* stream = g_new0(UsbHidIoStream, 1);
    stream->fd = -1;
    stream->timeout_ms = 10000;
    return stream;
}

gchar* usbhid_io_stream_open(UsbHidIoStream* stream,
                             const UsbHidDevice* device) {
    if (device == NULL || device->path == NULL) {
        return g_strdup("no device path");
    }

    stream->fd = open(device->path, O_RDWR);
    if (stream->fd < 0) {
        const int saved_errno = errno;
        if (saved_errno == EACCES) {
            // The usual Linux cause, and the one the user can act on: hidraw
            // nodes belong to root until a udev rule hands them over.
            return g_strdup_printf(
                "permission denied on %s. A udev rule granting access to "
                "hidraw devices is needed to download over USB.",
                device->path);
        }
        return g_strdup_printf("failed to open %s: %s", device->path,
                               strerror(saved_errno));
    }
    return NULL;
}

void usbhid_io_stream_close(UsbHidIoStream* stream) {
    if (stream->fd >= 0) {
        close(stream->fd);
        stream->fd = -1;
    }
}

// --- libdc_io_callbacks_t implementations ---

static int usbhid_set_timeout(void* userdata, int timeout) {
    UsbHidIoStream* stream = (UsbHidIoStream*)userdata;
    stream->timeout_ms = timeout;
    return LIBDC_STATUS_SUCCESS;
}

// Returns at most one input report.
//
// A timeout is success with zero bytes, not an error. That is what
// libdivecomputer's own USB HID read does (usbhid.c:728-742, where a hidapi
// timeout returns zero and DC_STATUS_SUCCESS), and the drivers above rely on
// it: uwatec_smart_usbhid_receive raises the protocol error itself when a
// packet comes back short.
//
// Nothing is stripped from the front. A hidraw read returns the report id byte
// only for a device that uses numbered reports, and no dive computer here
// does, which is the same shape libdivecomputer's drivers expect. Windows is
// the platform that prepends a zero byte and has to drop it again.
static int usbhid_read(void* userdata, void* data, size_t size,
                       size_t* actual) {
    UsbHidIoStream* stream = (UsbHidIoStream*)userdata;
    if (actual != NULL) *actual = 0;
    if (stream->fd < 0) return LIBDC_STATUS_IO;

    struct pollfd pfd;
    pfd.fd = stream->fd;
    pfd.events = POLLIN;
    pfd.revents = 0;

    // A signal must not end the wait. Returning success with zero bytes here
    // would be read as a timeout by uwatec_smart_usbhid_receive, which treats
    // a packet shorter than one byte as a protocol error and aborts the
    // download. libdivecomputer's own serial poll retries on EINTR for the
    // same reason (serial_posix.c:673-689).
    int ready = 0;
    do {
        ready = poll(&pfd, 1, stream->timeout_ms);
    } while (ready < 0 && errno == EINTR);

    if (ready < 0) return LIBDC_STATUS_IO;
    if (ready == 0) return LIBDC_STATUS_SUCCESS;

    ssize_t got = 0;
    do {
        got = read(stream->fd, data, size);
    } while (got < 0 && errno == EINTR);

    if (got < 0) {
        // EAGAIN after poll said readable means the report was consumed
        // elsewhere; nothing arrived, which is the timeout shape.
        if (errno == EAGAIN) return LIBDC_STATUS_SUCCESS;
        return LIBDC_STATUS_IO;
    }
    if (actual != NULL) *actual = (size_t)got;
    return LIBDC_STATUS_SUCCESS;
}

// Sends one output report.
//
// The buffer's first byte is the HID report id, which is exactly what hidraw
// wants at the front of a write, so unlike the macOS backend nothing is
// stripped here.
static int usbhid_write(void* userdata, const void* data, size_t size,
                        size_t* actual) {
    UsbHidIoStream* stream = (UsbHidIoStream*)userdata;
    if (actual != NULL) *actual = 0;
    if (stream->fd < 0) return LIBDC_STATUS_IO;
    if (size == 0) return LIBDC_STATUS_SUCCESS;

    const unsigned char* buffer = (const unsigned char*)data;
    ssize_t sent = 0;
    do {
        sent = write(stream->fd, buffer, size);
    } while (sent < 0 && errno == EINTR);

    if (sent < 0) return LIBDC_STATUS_IO;

    // One write(2) per report, and a short one is a failure rather than
    // something to resume. A hidraw write is a whole report: continuing from
    // the middle would send the tail as a second, malformed report, and the
    // device would answer the wrong question. libdivecomputer's own hidapi
    // path is a single hid_write for the same reason, and the Windows backend
    // here rejects a short write rather than retrying it.
    if ((size_t)sent != size) return LIBDC_STATUS_IO;

    if (actual != NULL) *actual = (size_t)sent;
    return LIBDC_STATUS_SUCCESS;
}

static int usbhid_poll(void* userdata, int timeout) {
    UsbHidIoStream* stream = (UsbHidIoStream*)userdata;
    if (stream->fd < 0) return LIBDC_STATUS_IO;

    struct pollfd pfd;
    pfd.fd = stream->fd;
    pfd.events = POLLIN;
    pfd.revents = 0;

    // Retried on EINTR, as in usbhid_read above and in libdivecomputer's own
    // serial poll: a signal arriving mid-wait is not an I/O failure.
    int ready = 0;
    do {
        ready = poll(&pfd, 1, timeout);
    } while (ready < 0 && errno == EINTR);

    if (ready < 0) return LIBDC_STATUS_IO;
    return ready == 0 ? LIBDC_STATUS_TIMEOUT : LIBDC_STATUS_SUCCESS;
}

static int usbhid_sleep(void* userdata, unsigned int milliseconds) {
    (void)userdata;
    g_usleep((gulong)milliseconds * 1000);
    return LIBDC_STATUS_SUCCESS;
}

static int usbhid_close(void* userdata) {
    usbhid_io_stream_close((UsbHidIoStream*)userdata);
    return LIBDC_STATUS_SUCCESS;
}

libdc_io_callbacks_t usbhid_io_stream_make_callbacks(UsbHidIoStream* stream) {
    // configure, set_dtr and set_rts are deliberately left null. They are
    // serial line control and have no meaning for a report pipe;
    // libdivecomputer's own USB HID vtable leaves the equivalent slots null
    // (usbhid.c:150-160), and the bridge in libdc_download.c treats an unset
    // slot as a no-op.
    libdc_io_callbacks_t callbacks;
    memset(&callbacks, 0, sizeof(callbacks));
    callbacks.userdata = stream;
    callbacks.set_timeout = usbhid_set_timeout;
    callbacks.read = usbhid_read;
    callbacks.write = usbhid_write;
    callbacks.poll = usbhid_poll;
    callbacks.sleep = usbhid_sleep;
    callbacks.close = usbhid_close;
    return callbacks;
}

void usbhid_io_stream_free(UsbHidIoStream* stream) {
    if (stream == NULL) return;
    usbhid_io_stream_close(stream);
    g_free(stream);
}
