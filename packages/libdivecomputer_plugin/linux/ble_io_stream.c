#include "ble_io_stream.h"

#include <stdio.h>
#include <string.h>

// Known GATT UUIDs for dive computer communication (same as macOS/Windows).
static const char* PREFERRED_SERVICE_UUID =
    "cb3c4555-d670-4670-bc20-b61dbc851e9a";
static const char* PREFERRED_WRITE_UUID =
    "6606ab42-89d5-4a00-a8ce-4eb5e1414ee0";
static const char* PREFERRED_NOTIFY_UUID =
    "a60b8e5c-b267-44d7-9764-837caf96489e";

static const guint32 BLE_IOCTL_TYPE = 'b';
static const guint32 BLE_IOCTL_GET_NAME = 0;
static const guint32 DIRECTION_INPUT = 1;

BleIoStream* ble_io_stream_new(void) {
    BleIoStream* stream = g_new0(BleIoStream, 1);
    g_mutex_init(&stream->read_mutex);
    g_cond_init(&stream->read_cond);
    stream->read_buffer = g_byte_array_new();
    stream->timeout_ms = 10000;
    return stream;
}

// Get a string property from a BlueZ D-Bus object.
static gchar* get_string_property(GDBusConnection* conn,
                                  const gchar* path,
                                  const gchar* interface,
                                  const gchar* property) {
    g_autoptr(GError) error = NULL;
    GVariant* result = g_dbus_connection_call_sync(
        conn, "org.bluez", path,
        "org.freedesktop.DBus.Properties", "Get",
        g_variant_new("(ss)", interface, property),
        G_VARIANT_TYPE("(v)"),
        G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
    if (!result) return NULL;

    GVariant* value = NULL;
    g_variant_get(result, "(v)", &value);
    g_variant_unref(result);

    const gchar* str = g_variant_get_string(value, NULL);
    gchar* ret = g_strdup(str);
    g_variant_unref(value);
    return ret;
}

// Check if a characteristic has a specific flag (e.g., "write", "notify").
static gboolean has_flag(GDBusConnection* conn, const gchar* char_path,
                         const gchar* flag) {
    g_autoptr(GError) error = NULL;
    GVariant* result = g_dbus_connection_call_sync(
        conn, "org.bluez", char_path,
        "org.freedesktop.DBus.Properties", "Get",
        g_variant_new("(ss)", "org.bluez.GattCharacteristic1", "Flags"),
        G_VARIANT_TYPE("(v)"),
        G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
    if (!result) return FALSE;

    GVariant* value = NULL;
    g_variant_get(result, "(v)", &value);
    g_variant_unref(result);

    gboolean found = FALSE;
    GVariantIter iter;
    g_variant_iter_init(&iter, value);
    const gchar* f;
    while (g_variant_iter_next(&iter, "&s", &f)) {
        if (g_strcmp0(f, flag) == 0) {
            found = TRUE;
            break;
        }
    }
    g_variant_unref(value);
    return found;
}

// PropertiesChanged signal handler for GATT notifications.
static void on_properties_changed(GDBusConnection* connection,
                                  const gchar* sender_name,
                                  const gchar* object_path,
                                  const gchar* interface_name,
                                  const gchar* signal_name,
                                  GVariant* parameters,
                                  gpointer user_data) {
    BleIoStream* stream = (BleIoStream*)user_data;
    (void)connection;
    (void)sender_name;
    (void)signal_name;

    // Only handle our notify characteristic.
    if (g_strcmp0(object_path, stream->notify_path) != 0) return;

    // PropertiesChanged: (STRING interface, DICT changed_props, ARRAY
    // invalidated)
    const gchar* iface = NULL;
    GVariant* changed = NULL;
    g_variant_get(parameters, "(&s@a{sv}@as)", &iface, &changed, NULL);

    if (g_strcmp0(iface, "org.bluez.GattCharacteristic1") != 0) {
        g_variant_unref(changed);
        return;
    }

    GVariant* value_var = g_variant_lookup_value(
        changed, "Value", G_VARIANT_TYPE_BYTESTRING);
    if (!value_var) {
        // Try array of bytes type.
        value_var = g_variant_lookup_value(
            changed, "Value", G_VARIANT_TYPE("ay"));
    }
    g_variant_unref(changed);
    if (!value_var) return;

    gsize n_bytes = 0;
    const guint8* bytes = g_variant_get_fixed_array(
        value_var, &n_bytes, sizeof(guint8));

    if (n_bytes > 0 && bytes) {
        g_mutex_lock(&stream->read_mutex);
        g_byte_array_append(stream->read_buffer, bytes, (guint)n_bytes);
        g_cond_signal(&stream->read_cond);
        g_mutex_unlock(&stream->read_mutex);
    }

    g_variant_unref(value_var);
}

gboolean ble_io_stream_connect(BleIoStream* stream,
                               const gchar* device_path) {
    g_autoptr(GError) error = NULL;

    stream->connection = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &error);
    if (!stream->connection) {
        g_warning("BleIoStream: Failed to connect to system bus: %s",
                  error->message);
        return FALSE;
    }

    stream->device_path = g_strdup(device_path);

    // Connect the device.
    g_dbus_connection_call_sync(
        stream->connection, "org.bluez", device_path,
        "org.bluez.Device1", "Connect",
        NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 30000, NULL, &error);
    if (error) {
        g_warning("BleIoStream: Connect failed: %s", error->message);
        return FALSE;
    }

    // Get the device name.
    stream->device_name = get_string_property(
        stream->connection, device_path, "org.bluez.Device1", "Name");

    // Discover GATT characteristics by enumerating child objects.
    // BlueZ exposes them as /org/bluez/hci0/dev_.../serviceXXXX/charXXXX.
    GVariant* managed = g_dbus_connection_call_sync(
        stream->connection, "org.bluez", "/",
        "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
        NULL, G_VARIANT_TYPE("(a{oa{sa{sv}}})"),
        G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
    if (!managed) {
        g_warning("BleIoStream: GetManagedObjects failed: %s",
                  error->message);
        return FALSE;
    }

    GVariant* objects = NULL;
    g_variant_get(managed, "(@a{oa{sa{sv}}})", &objects);
    g_variant_unref(managed);

    int best_write_score = -1;
    int best_notify_score = -1;
    gchar* best_write_path = NULL;
    gchar* best_notify_path = NULL;

    GVariantIter obj_iter;
    g_variant_iter_init(&obj_iter, objects);
    const gchar* obj_path;
    GVariant* ifaces;

    while (g_variant_iter_next(&obj_iter, "{&o@a{sa{sv}}}", &obj_path,
                               &ifaces)) {
        // Only look at characteristics under our device path.
        if (!g_str_has_prefix(obj_path, device_path)) {
            g_variant_unref(ifaces);
            continue;
        }

        GVariant* char_props = g_variant_lookup_value(
            ifaces, "org.bluez.GattCharacteristic1",
            G_VARIANT_TYPE_VARDICT);
        if (!char_props) {
            g_variant_unref(ifaces);
            continue;
        }

        // Get the UUID.
        GVariant* uuid_var = g_variant_lookup_value(
            char_props, "UUID", G_VARIANT_TYPE_STRING);
        if (!uuid_var) {
            g_variant_unref(char_props);
            g_variant_unref(ifaces);
            continue;
        }
        const gchar* uuid = g_variant_get_string(uuid_var, NULL);

        // Score as write candidate.
        gboolean can_write = has_flag(stream->connection, obj_path, "write");
        gboolean can_write_no_rsp =
            has_flag(stream->connection, obj_path, "write-without-response");
        if (can_write || can_write_no_rsp) {
            int ws = 0;
            if (can_write_no_rsp) ws += 4;
            if (can_write) ws += 2;
            if (g_ascii_strcasecmp(uuid, PREFERRED_WRITE_UUID) == 0) {
                ws += 1000;
            }
            if (ws > best_write_score) {
                g_free(best_write_path);
                best_write_path = g_strdup(obj_path);
                best_write_score = ws;
            }
        }

        // Score as notify candidate.
        gboolean can_notify = has_flag(stream->connection, obj_path, "notify");
        gboolean can_indicate =
            has_flag(stream->connection, obj_path, "indicate");
        if (can_notify || can_indicate) {
            int ns = 0;
            if (can_notify) ns += 4;
            if (can_indicate) ns += 2;
            if (g_ascii_strcasecmp(uuid, PREFERRED_NOTIFY_UUID) == 0) {
                ns += 1000;
            }
            if (ns > best_notify_score) {
                g_free(best_notify_path);
                best_notify_path = g_strdup(obj_path);
                best_notify_score = ns;
            }
        }

        g_variant_unref(uuid_var);
        g_variant_unref(char_props);
        g_variant_unref(ifaces);
    }
    g_variant_unref(objects);

    if (!best_write_path || !best_notify_path) {
        g_warning("BleIoStream: No suitable GATT characteristics found");
        g_free(best_write_path);
        g_free(best_notify_path);
        return FALSE;
    }

    stream->write_path = best_write_path;
    stream->notify_path = best_notify_path;

    // Subscribe to PropertiesChanged on the notify characteristic.
    stream->properties_sub = g_dbus_connection_signal_subscribe(
        stream->connection, "org.bluez",
        "org.freedesktop.DBus.Properties", "PropertiesChanged",
        stream->notify_path, NULL,
        G_DBUS_SIGNAL_FLAGS_NONE,
        on_properties_changed, stream, NULL);

    // Enable notifications via StartNotify.
    g_clear_error(&error);
    g_dbus_connection_call_sync(
        stream->connection, "org.bluez", stream->notify_path,
        "org.bluez.GattCharacteristic1", "StartNotify",
        NULL, NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
    if (error) {
        g_warning("BleIoStream: StartNotify failed: %s", error->message);
        return FALSE;
    }

    return TRUE;
}

// -- C callback implementations --

static int ble_set_timeout(void* userdata, int timeout) {
    BleIoStream* stream = (BleIoStream*)userdata;
    stream->timeout_ms = (timeout < 0) ? G_MAXINT32 : MAX(timeout, 3000);
    return LIBDC_STATUS_SUCCESS;
}

static int ble_read(void* userdata, void* data, size_t size,
                    size_t* actual) {
    BleIoStream* stream = (BleIoStream*)userdata;

    g_mutex_lock(&stream->read_mutex);

    gint64 deadline = (stream->timeout_ms == G_MAXINT32)
                          ? G_MAXINT64
                          : g_get_monotonic_time() +
                                (gint64)stream->timeout_ms * 1000;

    while (stream->read_buffer->len == 0) {
        if (stream->timeout_ms == G_MAXINT32) {
            g_cond_wait(&stream->read_cond, &stream->read_mutex);
        } else {
            if (!g_cond_wait_until(&stream->read_cond,
                                   &stream->read_mutex, deadline)) {
                g_mutex_unlock(&stream->read_mutex);
                if (actual) *actual = 0;
                return LIBDC_STATUS_TIMEOUT;
            }
        }
    }

    size_t bytes_to_read = MIN(size, stream->read_buffer->len);
    memcpy(data, stream->read_buffer->data, bytes_to_read);
    g_byte_array_remove_range(stream->read_buffer, 0,
                              (guint)bytes_to_read);
    g_mutex_unlock(&stream->read_mutex);

    if (actual) *actual = bytes_to_read;
    return LIBDC_STATUS_SUCCESS;
}

static int ble_write(void* userdata, const void* data, size_t size,
                     size_t* actual) {
    BleIoStream* stream = (BleIoStream*)userdata;

    // Build byte array variant for WriteValue.
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("ay"));
    const guint8* bytes = (const guint8*)data;
    for (size_t i = 0; i < size; i++) {
        g_variant_builder_add(&builder, "y", bytes[i]);
    }

    // Options dict (empty for default write behavior).
    GVariantBuilder opts;
    g_variant_builder_init(&opts, G_VARIANT_TYPE("a{sv}"));

    g_autoptr(GError) error = NULL;
    g_dbus_connection_call_sync(
        stream->connection, "org.bluez", stream->write_path,
        "org.bluez.GattCharacteristic1", "WriteValue",
        g_variant_new("(@aya{sv})",
                      g_variant_builder_end(&builder),
                      &opts),
        NULL, G_DBUS_CALL_FLAGS_NONE,
        stream->timeout_ms, NULL, &error);

    if (error) {
        g_warning("BleIoStream: WriteValue failed: %s", error->message);
        if (actual) *actual = 0;
        return LIBDC_STATUS_IO;
    }

    if (actual) *actual = size;
    return LIBDC_STATUS_SUCCESS;
}

static int ble_close(void* userdata) {
    BleIoStream* stream = (BleIoStream*)userdata;
    ble_io_stream_close(stream);
    return LIBDC_STATUS_SUCCESS;
}

static int ble_ioctl(void* userdata, unsigned int request,
                     void* data, size_t size) {
    BleIoStream* stream = (BleIoStream*)userdata;
    guint32 ioctl_type = (request >> 8) & 0xFF;
    guint32 ioctl_number = request & 0xFF;

    if (ioctl_type == BLE_IOCTL_TYPE &&
        ioctl_number == BLE_IOCTL_GET_NAME) {
        if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;
        if (!stream->device_name || stream->device_name[0] == '\0') {
            return LIBDC_STATUS_UNSUPPORTED;
        }

        size_t name_len = strlen(stream->device_name) + 1;
        size_t copy_len = MIN(name_len, size);
        memcpy(data, stream->device_name, copy_len);
        ((char*)data)[copy_len - 1] = '\0';
        return LIBDC_STATUS_SUCCESS;
    }

    return LIBDC_STATUS_UNSUPPORTED;
}

static int ble_poll(void* userdata, int timeout) {
    BleIoStream* stream = (BleIoStream*)userdata;
    g_mutex_lock(&stream->read_mutex);

    if (stream->read_buffer->len > 0) {
        g_mutex_unlock(&stream->read_mutex);
        return LIBDC_STATUS_SUCCESS;
    }

    if (timeout == 0) {
        g_mutex_unlock(&stream->read_mutex);
        return LIBDC_STATUS_TIMEOUT;
    }

    gboolean signaled;
    if (timeout < 0) {
        g_cond_wait(&stream->read_cond, &stream->read_mutex);
        signaled = TRUE;
    } else {
        gint64 deadline =
            g_get_monotonic_time() + (gint64)timeout * 1000;
        signaled = g_cond_wait_until(
            &stream->read_cond, &stream->read_mutex, deadline);
    }

    g_mutex_unlock(&stream->read_mutex);
    return signaled ? LIBDC_STATUS_SUCCESS : LIBDC_STATUS_TIMEOUT;
}

static int ble_purge(void* userdata, unsigned int direction) {
    if ((direction & DIRECTION_INPUT) == 0) return LIBDC_STATUS_SUCCESS;
    BleIoStream* stream = (BleIoStream*)userdata;
    g_mutex_lock(&stream->read_mutex);
    g_byte_array_set_size(stream->read_buffer, 0);
    g_mutex_unlock(&stream->read_mutex);
    return LIBDC_STATUS_SUCCESS;
}

libdc_io_callbacks_t ble_io_stream_make_callbacks(BleIoStream* stream) {
    libdc_io_callbacks_t cbs = {0};
    cbs.userdata = stream;
    cbs.set_timeout = ble_set_timeout;
    cbs.read = ble_read;
    cbs.write = ble_write;
    cbs.close = ble_close;
    cbs.ioctl = ble_ioctl;
    cbs.poll = ble_poll;
    cbs.purge = ble_purge;
    cbs.sleep = NULL;
    return cbs;
}

void ble_io_stream_close(BleIoStream* stream) {
    if (!stream) return;

    // Stop notifications.
    if (stream->connection && stream->notify_path) {
        g_dbus_connection_call_sync(
            stream->connection, "org.bluez", stream->notify_path,
            "org.bluez.GattCharacteristic1", "StopNotify",
            NULL, NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, NULL);
    }

    if (stream->connection && stream->properties_sub > 0) {
        g_dbus_connection_signal_unsubscribe(
            stream->connection, stream->properties_sub);
        stream->properties_sub = 0;
    }

    // Disconnect the device.
    if (stream->connection && stream->device_path) {
        g_dbus_connection_call_sync(
            stream->connection, "org.bluez", stream->device_path,
            "org.bluez.Device1", "Disconnect",
            NULL, NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, NULL);
    }
}

void ble_io_stream_free(BleIoStream* stream) {
    if (!stream) return;

    ble_io_stream_close(stream);

    g_mutex_clear(&stream->read_mutex);
    g_cond_clear(&stream->read_cond);
    if (stream->read_buffer) g_byte_array_unref(stream->read_buffer);
    g_free(stream->device_path);
    g_free(stream->write_path);
    g_free(stream->notify_path);
    g_free(stream->device_name);
    if (stream->connection) g_object_unref(stream->connection);
    g_free(stream);
}
