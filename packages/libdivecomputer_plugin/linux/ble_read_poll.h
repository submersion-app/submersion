#ifndef BLE_READ_POLL_H_
#define BLE_READ_POLL_H_

#include <gio/gio.h>
#include <glib.h>
#include <stddef.h>

G_BEGIN_DECLS

// Response path for a characteristic that can be read but can neither notify
// nor indicate (the Seac Tablet, issue #1454): every reply is fetched with
// org.bluez.GattCharacteristic1.ReadValue whenever libdivecomputer asks for
// bytes.
//
// The same state machine as darwin's ReadPollPolicy.swift and Android's
// ReadPollPolicy.kt, which carry the unit tests: at most one read in flight,
// a read that outlives a read() timeout adopted by the next read(), an empty
// value or failed read re-read after 100 ms and never at once, and purge
// discarding the value of a read already in flight. Replies are queued one
// entry per packet and a read returns bytes from at most one entry.
//
// Refcounted: every in-flight ReadValue holds a reference, so a completion
// arriving after the stream is freed settles against live memory.
typedef struct BleReadPoller BleReadPoller;

BleReadPoller* ble_read_poller_new(GDBusConnection* connection,
                                   const gchar* characteristic_path);

// libdivecomputer read(). timeout_ms follows BleIoStream.timeout_ms:
// G_MAXINT32 means no timeout.
int ble_read_poller_read(BleReadPoller* poller, void* data, size_t size,
                         size_t* actual, gint timeout_ms);

// libdivecomputer poll(): negative means no timeout, zero never blocks.
int ble_read_poller_poll(BleReadPoller* poller, int timeout_ms);

void ble_read_poller_purge(BleReadPoller* poller);

// Fail any waiting read and ignore completions still in flight. Does not
// release the caller's reference.
void ble_read_poller_close(BleReadPoller* poller);

void ble_read_poller_unref(BleReadPoller* poller);

G_END_DECLS

#endif  // BLE_READ_POLL_H_
