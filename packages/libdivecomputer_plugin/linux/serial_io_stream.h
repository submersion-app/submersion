#ifndef SERIAL_IO_STREAM_H_
#define SERIAL_IO_STREAM_H_

#include <glib.h>

#include "libdc_wrapper.h"

G_BEGIN_DECLS

// Wraps POSIX serial I/O and provides libdc_io_callbacks_t for libdivecomputer.
typedef struct {
    int fd;
    int timeout_ms;
} SerialIoStream;

// Create a new serial I/O stream.
SerialIoStream* serial_io_stream_new(void);

// Open a serial port (e.g., "/dev/ttyUSB0").
// Configures 9600 baud, 8N1, raw mode.
gboolean serial_io_stream_open(SerialIoStream* stream, const gchar* path);

// Build the libdc_io_callbacks_t struct pointing to this stream.
libdc_io_callbacks_t serial_io_stream_make_callbacks(SerialIoStream* stream);

// Close the port.
void serial_io_stream_close(SerialIoStream* stream);

// Free the stream and all resources.
void serial_io_stream_free(SerialIoStream* stream);

G_END_DECLS

#endif  // SERIAL_IO_STREAM_H_
