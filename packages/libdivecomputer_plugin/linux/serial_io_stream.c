#include "serial_io_stream.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

SerialIoStream* serial_io_stream_new(void) {
    SerialIoStream* stream = g_new0(SerialIoStream, 1);
    stream->fd = -1;
    stream->timeout_ms = 10000;
    return stream;
}

gboolean serial_io_stream_open(SerialIoStream* stream, const gchar* path) {
    stream->fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (stream->fd < 0) {
        g_warning("SerialIoStream: Failed to open %s: %s", path,
                  strerror(errno));
        return FALSE;
    }

    // Configure 9600 baud, 8N1, raw mode.
    struct termios options;
    tcgetattr(stream->fd, &options);
    cfsetispeed(&options, B9600);
    cfsetospeed(&options, B9600);
    options.c_cflag |= (CS8 | CLOCAL | CREAD);
    options.c_cflag &= ~(PARENB | CSTOPB | CRTSCTS);
    options.c_iflag = 0;
    options.c_oflag = 0;
    options.c_lflag = 0;
    options.c_cc[VMIN] = 0;
    options.c_cc[VTIME] = 0;
    tcsetattr(stream->fd, TCSANOW, &options);

    // Switch back to blocking mode.
    int flags = fcntl(stream->fd, F_GETFL);
    fcntl(stream->fd, F_SETFL, flags & ~O_NONBLOCK);

    return TRUE;
}

void serial_io_stream_close(SerialIoStream* stream) {
    if (stream->fd >= 0) {
        close(stream->fd);
        stream->fd = -1;
    }
}

// --- libdc_io_callbacks_t implementations ---

static int serial_set_timeout(void* userdata, int timeout) {
    SerialIoStream* stream = (SerialIoStream*)userdata;
    stream->timeout_ms = timeout;
    return LIBDC_STATUS_SUCCESS;
}

static int serial_read(void* userdata, void* data, size_t size,
                       size_t* actual) {
    SerialIoStream* stream = (SerialIoStream*)userdata;
    if (stream->fd < 0) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }

    // Use poll() for timeout support.
    struct pollfd pfd = {
        .fd = stream->fd,
        .events = POLLIN,
        .revents = 0,
    };
    int ready = poll(&pfd, 1, stream->timeout_ms);
    if (ready < 0) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }
    if (ready == 0) {
        *actual = 0;
        return LIBDC_STATUS_TIMEOUT;
    }

    ssize_t n = read(stream->fd, data, size);
    if (n < 0) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }
    *actual = (size_t)n;
    return LIBDC_STATUS_SUCCESS;
}

static int serial_write(void* userdata, const void* data, size_t size,
                        size_t* actual) {
    SerialIoStream* stream = (SerialIoStream*)userdata;
    if (stream->fd < 0) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }

    ssize_t n = write(stream->fd, data, size);
    if (n < 0) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }
    *actual = (size_t)n;
    return LIBDC_STATUS_SUCCESS;
}

static int serial_close(void* userdata) {
    SerialIoStream* stream = (SerialIoStream*)userdata;
    serial_io_stream_close(stream);
    return LIBDC_STATUS_SUCCESS;
}

static int serial_purge(void* userdata, int direction) {
    SerialIoStream* stream = (SerialIoStream*)userdata;
    if (stream->fd < 0) return LIBDC_STATUS_IO;

    int queue;
    if (direction == 1) {
        queue = TCIFLUSH;
    } else if (direction == 2) {
        queue = TCOFLUSH;
    } else {
        queue = TCIOFLUSH;
    }
    tcflush(stream->fd, queue);
    return LIBDC_STATUS_SUCCESS;
}

static int serial_sleep(void* userdata, int milliseconds) {
    (void)userdata;
    g_usleep((gulong)milliseconds * 1000);
    return LIBDC_STATUS_SUCCESS;
}

libdc_io_callbacks_t serial_io_stream_make_callbacks(SerialIoStream* stream) {
    libdc_io_callbacks_t callbacks = {0};
    callbacks.userdata = stream;
    callbacks.set_timeout = serial_set_timeout;
    callbacks.read = serial_read;
    callbacks.write = serial_write;
    callbacks.close = serial_close;
    callbacks.purge = serial_purge;
    callbacks.sleep = serial_sleep;
    return callbacks;
}

void serial_io_stream_free(SerialIoStream* stream) {
    if (!stream) return;
    serial_io_stream_close(stream);
    g_free(stream);
}
