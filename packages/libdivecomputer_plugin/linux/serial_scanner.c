#include "serial_scanner.h"

#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

SerialScanner* serial_scanner_new(void) {
    return g_new0(SerialScanner, 1);
}

void serial_scanner_set_callbacks(SerialScanner* scanner,
                                  SerialDeviceCallback on_device,
                                  SerialScanCompleteCallback on_complete,
                                  gpointer user_data) {
    scanner->on_device_discovered = on_device;
    scanner->on_complete = on_complete;
    scanner->user_data = user_data;
}

// Check if a filename matches serial device patterns.
static gboolean is_serial_device(const char* name) {
    return g_str_has_prefix(name, "ttyUSB") ||
           g_str_has_prefix(name, "ttyACM") ||
           g_str_has_prefix(name, "ttyS");
}

// Read the product/manufacturer string from sysfs for a given tty device.
// Returns a newly-allocated string or NULL.
static gchar* read_sysfs_attr(const char* tty_name, const char* attr) {
    g_autofree gchar* path = g_strdup_printf(
        "/sys/class/tty/%s/device/%s", tty_name, attr);

    gchar* contents = NULL;
    if (!g_file_get_contents(path, &contents, NULL, NULL)) {
        return NULL;
    }
    // Strip trailing newline.
    g_strstrip(contents);
    return contents;
}

static gpointer scan_thread_func(gpointer data) {
    SerialScanner* scanner = (SerialScanner*)data;

    DIR* dir = opendir("/dev");
    if (!dir) {
        if (scanner->on_complete) {
            scanner->on_complete(scanner->user_data);
        }
        return NULL;
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (!is_serial_device(entry->d_name)) continue;

        g_autofree gchar* dev_path =
            g_strdup_printf("/dev/%s", entry->d_name);

        // Check if the device actually exists and is a character device.
        struct stat st;
        if (stat(dev_path, &st) != 0 || !S_ISCHR(st.st_mode)) continue;

        // Try to get a friendly name from sysfs.
        g_autofree gchar* product = read_sysfs_attr(entry->d_name, "product");
        g_autofree gchar* manufacturer =
            read_sysfs_attr(entry->d_name, "manufacturer");

        // Build a display name from available info.
        g_autofree gchar* display_name = NULL;
        if (manufacturer && product) {
            display_name = g_strdup_printf("%s %s", manufacturer, product);
        } else if (product) {
            display_name = g_strdup(product);
        } else {
            display_name = g_strdup(entry->d_name);
        }

        // Match against libdivecomputer descriptors.
        libdc_descriptor_info_t info = {0};
        int matched = libdc_descriptor_match(
            display_name, LIBDC_TRANSPORT_SERIAL, &info);

        if (!matched) {
            // Also try with just the device name.
            matched = libdc_descriptor_match(
                entry->d_name, LIBDC_TRANSPORT_SERIAL, &info);
        }

        if (!matched) continue;

        if (scanner->on_device_discovered) {
            g_autofree gchar* friendly_name =
                g_strdup_printf("%s %s", info.vendor, info.product);

            LibdivecomputerPluginDiscoveredDevice* device =
                libdivecomputer_plugin_discovered_device_new(
                    info.vendor, info.product, (int64_t)info.model,
                    dev_path, friendly_name,
                    LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_SERIAL);

            scanner->on_device_discovered(device, scanner->user_data);
            g_object_unref(device);
        }
    }

    closedir(dir);

    if (scanner->on_complete) {
        scanner->on_complete(scanner->user_data);
    }

    return NULL;
}

void serial_scanner_start(SerialScanner* scanner) {
    scanner->scan_thread = g_thread_new("serial-scan", scan_thread_func,
                                        scanner);
}

void serial_scanner_stop(SerialScanner* scanner) {
    if (scanner->scan_thread) {
        g_thread_join(scanner->scan_thread);
        scanner->scan_thread = NULL;
    }
}

void serial_scanner_free(SerialScanner* scanner) {
    if (!scanner) return;
    serial_scanner_stop(scanner);
    g_free(scanner);
}

gchar** serial_enumerate_ports(void) {
    GPtrArray* ports = g_ptr_array_new();

    DIR* dir = opendir("/dev");
    if (dir) {
        struct dirent* entry;
        while ((entry = readdir(dir)) != NULL) {
            // Only probe USB-to-serial adapters (ttyUSB*, ttyACM*) during
            // auto-detect. Motherboard serial ports (ttyS*) are excluded to
            // avoid sending handshake bytes to unrelated devices.
            if (!g_str_has_prefix(entry->d_name, "ttyUSB") &&
                !g_str_has_prefix(entry->d_name, "ttyACM")) {
                continue;
            }

            g_autofree gchar* dev_path =
                g_strdup_printf("/dev/%s", entry->d_name);

            struct stat st;
            if (stat(dev_path, &st) == 0 && S_ISCHR(st.st_mode)) {
                g_ptr_array_add(ports, g_strdup(dev_path));
            }
        }
        closedir(dir);
    }

    g_ptr_array_add(ports, NULL);
    return (gchar**)g_ptr_array_free(ports, FALSE);
}
