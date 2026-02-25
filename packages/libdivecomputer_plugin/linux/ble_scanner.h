#ifndef BLE_SCANNER_H_
#define BLE_SCANNER_H_

#include <gio/gio.h>
#include <glib.h>

#include "dive_computer_api.g.h"
#include "libdc_wrapper.h"

G_BEGIN_DECLS

// Callback types for BLE scan events.
typedef void (*BleDeviceCallback)(
    LibdivecomputerPluginDiscoveredDevice* device, gpointer user_data);
typedef void (*BleScanCompleteCallback)(gpointer user_data);

// Context for the BLE scanner.
typedef struct {
    GDBusConnection* connection;
    guint interfaces_added_sub;
    gchar* adapter_path;
    GHashTable* seen_addresses;  // set of seen BLE address strings

    BleDeviceCallback on_device_discovered;
    BleScanCompleteCallback on_complete;
    gpointer user_data;
} BleScanner;

// Create a new BLE scanner.
BleScanner* ble_scanner_new(void);

// Set callbacks for device discovery events.
void ble_scanner_set_callbacks(BleScanner* scanner,
                               BleDeviceCallback on_device,
                               BleScanCompleteCallback on_complete,
                               gpointer user_data);

// Start BLE scanning. Returns TRUE on success.
gboolean ble_scanner_start(BleScanner* scanner);

// Stop BLE scanning.
void ble_scanner_stop(BleScanner* scanner);

// Free the scanner and all resources.
void ble_scanner_free(BleScanner* scanner);

G_END_DECLS

#endif  // BLE_SCANNER_H_
