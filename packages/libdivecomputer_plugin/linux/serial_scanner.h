#ifndef SERIAL_SCANNER_H_
#define SERIAL_SCANNER_H_

#include <glib.h>

#include "dive_computer_api.g.h"
#include "libdc_wrapper.h"

G_BEGIN_DECLS

// Callback types for serial scan events.
typedef void (*SerialDeviceCallback)(
    LibdivecomputerPluginDiscoveredDevice* device, gpointer user_data);
typedef void (*SerialScanCompleteCallback)(gpointer user_data);

// Context for the serial scanner.
typedef struct {
    GThread* scan_thread;
    SerialDeviceCallback on_device_discovered;
    SerialScanCompleteCallback on_complete;
    gpointer user_data;
} SerialScanner;

// Create a new serial scanner.
SerialScanner* serial_scanner_new(void);

// Set callbacks for device discovery events.
void serial_scanner_set_callbacks(SerialScanner* scanner,
                                  SerialDeviceCallback on_device,
                                  SerialScanCompleteCallback on_complete,
                                  gpointer user_data);

// Start serial port enumeration. Spawns a background thread.
void serial_scanner_start(SerialScanner* scanner);

// Wait for the scan to complete.
void serial_scanner_stop(SerialScanner* scanner);

// Free the scanner and all resources.
void serial_scanner_free(SerialScanner* scanner);

// Returns a NULL-terminated array of available serial port paths
// (e.g., "/dev/ttyUSB0"). Free with g_strfreev().
gchar** serial_enumerate_ports(void);

G_END_DECLS

#endif  // SERIAL_SCANNER_H_
