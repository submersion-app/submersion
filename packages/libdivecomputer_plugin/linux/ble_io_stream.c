#include "ble_io_stream.h"

#include <stdio.h>
#include <string.h>

// Known GATT UUIDs for dive computer communication (same as macOS/Windows).
// PREFERRED_SERVICE_UUID is unused on Linux (BlueZ enumerates all
// characteristics under the device path rather than filtering by service),
// but kept for cross-platform reference.
static const char* PREFERRED_WRITE_UUID =
    "6606ab42-89d5-4a00-a8ce-4eb5e1414ee0";
static const char* PREFERRED_NOTIFY_UUID =
    "a60b8e5c-b267-44d7-9764-837caf96489e";
// Halcyon Symbios device-centric Tx/Rx endpoints. The app WRITES commands to
// the device's Rx (00000101) and READS replies (indications) from its Tx
// (00000201) -- matching Subsurface's qt-ble.cpp. Both chars advertise
// read+write+indicate and tie on raw score, so these biases pick the pair.
// PR #356 biased them backwards (wrote to Tx) and the device never answered
// (issue #288).
static const char* HALCYON_SYMBIOS_TX_UUID =
    "00000201-8c3b-4f2c-a59e-8c08224f3253";
static const char* HALCYON_SYMBIOS_RX_UUID =
    "00000101-8c3b-4f2c-a59e-8c08224f3253";

static const guint32 BLE_IOCTL_TYPE = 'b';
static const guint32 BLE_IOCTL_GET_NAME = 0;
static const guint32 BLE_IOCTL_GET_PINCODE_NR = 1;
static const guint32 BLE_IOCTL_ACCESSCODE_NR = 2;
static const guint32 DIRECTION_INPUT = 1;

BleIoStream* ble_io_stream_new(void) {
    BleIoStream* stream = g_new0(BleIoStream, 1);
    g_mutex_init(&stream->read_mutex);
    g_cond_init(&stream->read_cond);
    stream->read_chunks = g_queue_new();
    stream->timeout_ms = 10000;
    g_mutex_init(&stream->pin_mutex);
    g_cond_init(&stream->pin_cond);
    stream->pending_pin = NULL;
    stream->pin_ready = FALSE;
    stream->device_address = NULL;
    stream->on_pin_code_required = NULL;
    stream->pin_callback_data = NULL;
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
        GByteArray* chunk = g_byte_array_sized_new((guint)n_bytes);
        g_byte_array_append(chunk, bytes, (guint)n_bytes);
        g_mutex_lock(&stream->read_mutex);
        g_queue_push_tail(stream->read_chunks, chunk);
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

    // Note: BlueZ exposes no simple per-connection priority/interval API on
    // org.bluez.Device1 (unlike Android's requestConnectionPriority or
    // Windows' preferred connection parameters), so high-rate dumps (e.g. the
    // OSTC nano logbook, #280) rely on the device pacing itself plus the
    // hw_ostc3 read fix; transient notification loss is covered by a retry.

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
            if (g_ascii_strcasecmp(uuid, PREFERRED_WRITE_UUID) == 0 ||
                g_ascii_strcasecmp(uuid, HALCYON_SYMBIOS_RX_UUID) == 0) {
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
            if (g_ascii_strcasecmp(uuid, PREFERRED_NOTIFY_UUID) == 0 ||
                g_ascii_strcasecmp(uuid, HALCYON_SYMBIOS_TX_UUID) == 0) {
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

    while (g_queue_is_empty(stream->read_chunks)) {
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

    // Return bytes from at most one notification per read: the packet
    // parsers size each read from the packet header and would silently
    // drop a second packet coalesced into the same read (lost FLAG_LAST
    // ack -> spurious timeout). A partially consumed notification stays
    // at the head of the queue.
    GByteArray* chunk = (GByteArray*)g_queue_peek_head(stream->read_chunks);
    size_t bytes_to_read = MIN(size, chunk->len);
    memcpy(data, chunk->data, bytes_to_read);
    if (bytes_to_read < chunk->len) {
        g_byte_array_remove_range(chunk, 0, (guint)bytes_to_read);
    } else {
        g_queue_pop_head(stream->read_chunks);
        g_byte_array_unref(chunk);
    }
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

static gchar* get_access_code_path(void) {
    return g_build_filename(
        g_get_user_config_dir(), "submersion", "ble_access_codes.ini", NULL);
}

static GBytes* load_access_code(const gchar* address) {
    g_autofree gchar* path = get_access_code_path();
    g_autoptr(GKeyFile) kf = g_key_file_new();

    if (!g_key_file_load_from_file(kf, path, G_KEY_FILE_NONE, NULL)) {
        return NULL;
    }

    gchar* key = g_strdup_printf("ble_access_code_%s", address);
    g_autofree gchar* hex = g_key_file_get_string(kf, "access_codes", key, NULL);
    g_free(key);

    if (hex == NULL) return NULL;

    // Decode hex string to bytes.
    gsize hex_len = strlen(hex);
    if (hex_len == 0 || hex_len % 2 != 0) return NULL;
    gsize byte_len = hex_len / 2;
    guint8* bytes = g_malloc(byte_len);
    for (gsize i = 0; i < byte_len; i++) {
        char buf[3] = { hex[i*2], hex[i*2+1], '\0' };
        bytes[i] = (guint8)g_ascii_strtoull(buf, NULL, 16);
    }
    return g_bytes_new_take(bytes, byte_len);
}

static void save_access_code(const gchar* address,
                              const void* data, gsize size) {
    g_autofree gchar* path = get_access_code_path();
    g_autofree gchar* dir = g_path_get_dirname(path);
    g_mkdir_with_parents(dir, 0700);

    g_autoptr(GKeyFile) kf = g_key_file_new();
    g_key_file_load_from_file(kf, path, G_KEY_FILE_NONE, NULL);

    // Encode bytes as hex string.
    GString* hex = g_string_sized_new(size * 2);
    const guint8* bytes = (const guint8*)data;
    for (gsize i = 0; i < size; i++) {
        g_string_append_printf(hex, "%02x", bytes[i]);
    }

    gchar* key = g_strdup_printf("ble_access_code_%s", address);
    g_key_file_set_string(kf, "access_codes", key, hex->str);
    g_free(key);
    g_string_free(hex, TRUE);

    g_key_file_save_to_file(kf, path, NULL);
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

    if (ioctl_type == BLE_IOCTL_TYPE && ioctl_number == BLE_IOCTL_GET_PINCODE_NR) {
        if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;

        g_mutex_lock(&stream->pin_mutex);
        g_free(stream->pending_pin);
        stream->pending_pin = NULL;
        stream->pin_ready = FALSE;
        g_mutex_unlock(&stream->pin_mutex);

        // Dispatch callback.
        if (stream->on_pin_code_required) {
            stream->on_pin_code_required(
                stream->device_address, stream->pin_callback_data);
        }

        // Block until submitPinCode is called (60s timeout).
        g_mutex_lock(&stream->pin_mutex);
        gint64 end_time = g_get_monotonic_time() + 60 * G_TIME_SPAN_SECOND;
        while (!stream->pin_ready) {
            if (!g_cond_wait_until(&stream->pin_cond, &stream->pin_mutex,
                                    end_time)) {
                g_mutex_unlock(&stream->pin_mutex);
                return LIBDC_STATUS_TIMEOUT;
            }
        }

        if (stream->pending_pin == NULL || stream->pending_pin[0] == '\0') {
            g_mutex_unlock(&stream->pin_mutex);
            return LIBDC_STATUS_CANCELLED;
        }

        size_t pin_len = strlen(stream->pending_pin) + 1;
        size_t copy_len = MIN(pin_len, size);
        memcpy(data, stream->pending_pin, copy_len);
        ((char*)data)[copy_len - 1] = '\0';
        g_mutex_unlock(&stream->pin_mutex);
        return LIBDC_STATUS_SUCCESS;
    }

    if (ioctl_type == BLE_IOCTL_TYPE && ioctl_number == BLE_IOCTL_ACCESSCODE_NR) {
        if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;
        guint32 direction = (request >> 30) & 0x3;

        if (direction == 1) {
            // GET access code.
            GBytes* stored = load_access_code(stream->device_address);
            if (stored == NULL) return LIBDC_STATUS_UNSUPPORTED;
            gsize stored_size;
            const void* stored_data = g_bytes_get_data(stored, &stored_size);
            size_t copy_len = MIN(stored_size, size);
            memcpy(data, stored_data, copy_len);
            g_bytes_unref(stored);
            return LIBDC_STATUS_SUCCESS;
        }
        if (direction == 2) {
            // SET access code.
            save_access_code(stream->device_address, data, size);
            return LIBDC_STATUS_SUCCESS;
        }
    }

    return LIBDC_STATUS_UNSUPPORTED;
}

static int ble_poll(void* userdata, int timeout) {
    BleIoStream* stream = (BleIoStream*)userdata;
    g_mutex_lock(&stream->read_mutex);

    if (!g_queue_is_empty(stream->read_chunks)) {
        g_mutex_unlock(&stream->read_mutex);
        return LIBDC_STATUS_SUCCESS;
    }

    if (timeout == 0) {
        g_mutex_unlock(&stream->read_mutex);
        return LIBDC_STATUS_TIMEOUT;
    }

    // GCond waits can wake spuriously; re-check the predicate in a loop.
    gboolean signaled = TRUE;
    if (timeout < 0) {
        while (g_queue_is_empty(stream->read_chunks)) {
            g_cond_wait(&stream->read_cond, &stream->read_mutex);
        }
    } else {
        gint64 deadline =
            g_get_monotonic_time() + (gint64)timeout * 1000;
        while (g_queue_is_empty(stream->read_chunks)) {
            if (!g_cond_wait_until(&stream->read_cond,
                                   &stream->read_mutex, deadline)) {
                signaled = FALSE;
                break;
            }
        }
    }

    g_mutex_unlock(&stream->read_mutex);
    return signaled ? LIBDC_STATUS_SUCCESS : LIBDC_STATUS_TIMEOUT;
}

static int ble_purge(void* userdata, unsigned int direction) {
    if ((direction & DIRECTION_INPUT) == 0) return LIBDC_STATUS_SUCCESS;
    BleIoStream* stream = (BleIoStream*)userdata;
    g_mutex_lock(&stream->read_mutex);
    GByteArray* chunk;
    while ((chunk = g_queue_pop_head(stream->read_chunks)) != NULL) {
        g_byte_array_unref(chunk);
    }
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
    if (stream->read_chunks) {
        GByteArray* chunk;
        while ((chunk = g_queue_pop_head(stream->read_chunks)) != NULL) {
            g_byte_array_unref(chunk);
        }
        g_queue_free(stream->read_chunks);
    }
    g_free(stream->device_path);
    g_free(stream->write_path);
    g_free(stream->notify_path);
    g_free(stream->device_name);
    g_mutex_clear(&stream->pin_mutex);
    g_cond_clear(&stream->pin_cond);
    g_free(stream->pending_pin);
    g_free(stream->device_address);
    if (stream->connection) g_object_unref(stream->connection);
    g_free(stream);
}

void ble_io_stream_submit_pin(BleIoStream* stream, const gchar* pin) {
    g_mutex_lock(&stream->pin_mutex);
    g_free(stream->pending_pin);
    stream->pending_pin = g_strdup(pin);
    stream->pin_ready = TRUE;
    g_cond_signal(&stream->pin_cond);
    g_mutex_unlock(&stream->pin_mutex);
}

void ble_io_stream_set_device_address(BleIoStream* stream,
                                       const gchar* address) {
    g_free(stream->device_address);
    stream->device_address = g_strdup(address);
}

void ble_io_stream_set_pin_callback(
    BleIoStream* stream,
    void (*callback)(const gchar* address, gpointer user_data),
    gpointer user_data) {
    stream->on_pin_code_required = callback;
    stream->pin_callback_data = user_data;
}
