#ifndef BLE_IO_STREAM_H_
#define BLE_IO_STREAM_H_

#include <gio/gio.h>
#include <glib.h>

#include "libdc_wrapper.h"

G_BEGIN_DECLS

// Bridges BlueZ D-Bus GATT communication to libdivecomputer's synchronous
// iostream interface using GMutex/GCond.
typedef struct {
    GDBusConnection* connection;
    gchar* device_path;    // e.g., /org/bluez/hci0/dev_XX_XX_XX_XX_XX_XX
    gchar* write_path;     // GATT characteristic object path for writes
    gchar* notify_path;    // GATT characteristic object path for notify
    guint properties_sub;  // PropertiesChanged signal subscription

    GMutex read_mutex;
    GCond read_cond;
    GByteArray* read_buffer;

    gint timeout_ms;
    gchar* device_name;
} BleIoStream;

// Create a new BLE I/O stream.
BleIoStream* ble_io_stream_new(void);

// Connect to a BlueZ device and discover GATT characteristics.
// |device_path| is the D-Bus object path (e.g.,
// /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF). Blocks until ready or failure.
gboolean ble_io_stream_connect(BleIoStream* stream,
                               const gchar* device_path);

// Build the libdc_io_callbacks_t struct pointing to this stream.
libdc_io_callbacks_t ble_io_stream_make_callbacks(BleIoStream* stream);

// Disconnect and clean up.
void ble_io_stream_close(BleIoStream* stream);

// Free the stream and all resources.
void ble_io_stream_free(BleIoStream* stream);

G_END_DECLS

#endif  // BLE_IO_STREAM_H_
