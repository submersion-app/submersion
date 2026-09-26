#include "ble_read_poll.h"

#include <string.h>

#include "libdc_wrapper.h"

// Delay before re-reading after an empty value or a failed read.
#define READ_POLL_RETRY_DELAY_US (100 * G_TIME_SPAN_MILLISECOND)
// Longest a waiting reader sleeps before re-checking, so a completion that
// queued nothing is followed by a retry without needing its own wakeup.
#define READ_POLL_WAIT_SLICE_US (100 * G_TIME_SPAN_MILLISECOND)
// D-Bus timeout for one ReadValue: the ATT transaction timeout.
#define READ_POLL_DBUS_TIMEOUT_MS 30000

struct BleReadPoller {
    gint ref_count;
    GDBusConnection* connection;
    gchar* path;

    GMutex mutex;
    GCond cond;
    // GByteArray*, one entry per read response.
    GQueue* chunks;
    gboolean read_in_flight;
    gboolean discard_in_flight;
    gboolean closed;
    // g_get_monotonic_time() before which no read may be issued.
    gint64 retry_not_before;
};

static BleReadPoller* poller_ref(BleReadPoller* poller) {
    g_atomic_int_inc(&poller->ref_count);
    return poller;
}

static void clear_chunks(GQueue* chunks) {
    GByteArray* chunk;
    while ((chunk = g_queue_pop_head(chunks)) != NULL) {
        g_byte_array_unref(chunk);
    }
}

void ble_read_poller_unref(BleReadPoller* poller) {
    if (!poller || !g_atomic_int_dec_and_test(&poller->ref_count)) return;
    clear_chunks(poller->chunks);
    g_queue_free(poller->chunks);
    g_mutex_clear(&poller->mutex);
    g_cond_clear(&poller->cond);
    g_object_unref(poller->connection);
    g_free(poller->path);
    g_free(poller);
}

BleReadPoller* ble_read_poller_new(GDBusConnection* connection,
                                   const gchar* characteristic_path) {
    BleReadPoller* poller = g_new0(BleReadPoller, 1);
    poller->ref_count = 1;
    poller->connection = g_object_ref(connection);
    poller->path = g_strdup(characteristic_path);
    g_mutex_init(&poller->mutex);
    g_cond_init(&poller->cond);
    poller->chunks = g_queue_new();
    return poller;
}

static void on_read_value_complete(GObject* source, GAsyncResult* result,
                                   gpointer user_data) {
    BleReadPoller* poller = (BleReadPoller*)user_data;
    g_autoptr(GError) error = NULL;
    GVariant* reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);

    GByteArray* chunk = NULL;
    if (reply) {
        GVariant* value = NULL;
        g_variant_get(reply, "(@ay)", &value);
        gsize n_bytes = 0;
        const guint8* bytes =
            g_variant_get_fixed_array(value, &n_bytes, sizeof(guint8));
        if (n_bytes > 0 && bytes) {
            chunk = g_byte_array_sized_new((guint)n_bytes);
            g_byte_array_append(chunk, bytes, (guint)n_bytes);
        }
        g_variant_unref(value);
        g_variant_unref(reply);
    } else {
        g_warning("BleIoStream: read-poll ReadValue failed: %s; retrying",
                  error ? error->message : "unknown error");
    }

    g_mutex_lock(&poller->mutex);
    poller->read_in_flight = FALSE;
    if (!poller->closed) {
        if (poller->discard_in_flight) {
            // Answers a command libdivecomputer has abandoned.
            poller->discard_in_flight = FALSE;
        } else if (chunk) {
            g_queue_push_tail(poller->chunks, chunk);
            chunk = NULL;
        } else {
            poller->retry_not_before =
                g_get_monotonic_time() + READ_POLL_RETRY_DELAY_US;
        }
    }
    g_cond_broadcast(&poller->cond);
    g_mutex_unlock(&poller->mutex);

    if (chunk) g_byte_array_unref(chunk);
    // Drops the reference issue_read() took for this call.
    ble_read_poller_unref(poller);
}

// Start one asynchronous ReadValue. The reply is dispatched on the main
// context, never inline, so this is safe to call with the mutex held.
static void issue_read(BleReadPoller* poller) {
    GVariantBuilder options;
    g_variant_builder_init(&options, G_VARIANT_TYPE("a{sv}"));
    g_dbus_connection_call(
        poller->connection, "org.bluez", poller->path,
        "org.bluez.GattCharacteristic1", "ReadValue",
        g_variant_new("(a{sv})", &options), G_VARIANT_TYPE("(ay)"),
        G_DBUS_CALL_FLAGS_NONE, READ_POLL_DBUS_TIMEOUT_MS, NULL,
        on_read_value_complete, poller_ref(poller));
}

// Wait, issuing reads as needed, until a packet is queued (SUCCESS), the
// deadline passes (TIMEOUT) or the poller is closed (IO). Called and returns
// with the mutex held.
static int await_packet(BleReadPoller* poller, gint64 deadline) {
    while (g_queue_is_empty(poller->chunks)) {
        if (poller->closed) return LIBDC_STATUS_IO;
        gint64 now = g_get_monotonic_time();
        if (now >= deadline) return LIBDC_STATUS_TIMEOUT;

        if (!poller->read_in_flight && now >= poller->retry_not_before) {
            poller->read_in_flight = TRUE;
            issue_read(poller);
            continue;
        }

        gint64 slice_end = (deadline - now > READ_POLL_WAIT_SLICE_US)
                               ? now + READ_POLL_WAIT_SLICE_US
                               : deadline;
        g_cond_wait_until(&poller->cond, &poller->mutex, slice_end);
    }
    return LIBDC_STATUS_SUCCESS;
}

int ble_read_poller_read(BleReadPoller* poller, void* data, size_t size,
                         size_t* actual, gint timeout_ms) {
    gint64 deadline = (timeout_ms == G_MAXINT32)
                          ? G_MAXINT64
                          : g_get_monotonic_time() +
                                (gint64)timeout_ms * G_TIME_SPAN_MILLISECOND;
    size_t count = 0;

    g_mutex_lock(&poller->mutex);
    int status = await_packet(poller, deadline);
    if (status == LIBDC_STATUS_SUCCESS) {
        // At most one packet per read, a partial packet staying at the head,
        // as on the notification path.
        GByteArray* chunk = (GByteArray*)g_queue_peek_head(poller->chunks);
        count = MIN(size, chunk->len);
        memcpy(data, chunk->data, count);
        if (count < chunk->len) {
            g_byte_array_remove_range(chunk, 0, (guint)count);
        } else {
            g_queue_pop_head(poller->chunks);
            g_byte_array_unref(chunk);
        }
    }
    g_mutex_unlock(&poller->mutex);

    if (actual) *actual = count;
    return status;
}

int ble_read_poller_poll(BleReadPoller* poller, int timeout_ms) {
    int status;
    g_mutex_lock(&poller->mutex);
    if (!g_queue_is_empty(poller->chunks)) {
        status = LIBDC_STATUS_SUCCESS;
    } else if (timeout_ms == 0) {
        status = LIBDC_STATUS_TIMEOUT;
    } else {
        gint64 deadline = (timeout_ms < 0)
                              ? G_MAXINT64
                              : g_get_monotonic_time() +
                                    (gint64)timeout_ms * G_TIME_SPAN_MILLISECOND;
        status = await_packet(poller, deadline);
    }
    g_mutex_unlock(&poller->mutex);
    return status;
}

void ble_read_poller_purge(BleReadPoller* poller) {
    g_mutex_lock(&poller->mutex);
    clear_chunks(poller->chunks);
    // The value of a read already on the wire answers a command
    // libdivecomputer has abandoned.
    if (poller->read_in_flight) poller->discard_in_flight = TRUE;
    g_mutex_unlock(&poller->mutex);
}

void ble_read_poller_close(BleReadPoller* poller) {
    if (!poller) return;
    g_mutex_lock(&poller->mutex);
    poller->closed = TRUE;
    clear_chunks(poller->chunks);
    g_cond_broadcast(&poller->cond);
    g_mutex_unlock(&poller->mutex);
}
