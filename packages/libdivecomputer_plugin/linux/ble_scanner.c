#include "ble_scanner.h"

#include <stdio.h>
#include <string.h>

BleScanner* ble_scanner_new(void) {
    BleScanner* scanner = g_new0(BleScanner, 1);
    scanner->seen_addresses = g_hash_table_new_full(
        g_str_hash, g_str_equal, g_free, NULL);
    return scanner;
}

void ble_scanner_set_callbacks(BleScanner* scanner,
                               BleDeviceCallback on_device,
                               BleScanCompleteCallback on_complete,
                               gpointer user_data) {
    scanner->on_device_discovered = on_device;
    scanner->on_complete = on_complete;
    scanner->user_data = user_data;
}

// Pelagic BLE names: two letters + serial digits (e.g., FH025918).
// Returns the two-byte model code, or 0 if not a match.
static guint32 parse_pelagic_model_code(const char* name) {
    size_t len = strlen(name);
    if (len < 8) return 0;
    if (!g_ascii_isalpha(name[0]) || !g_ascii_isalpha(name[1])) return 0;

    int digits = 0;
    for (size_t i = 2; i < len; i++) {
        if (g_ascii_isdigit(name[i])) {
            digits++;
        } else if (name[i] == ' ' || name[i] == '-' || name[i] == '_') {
            continue;
        } else {
            return 0;
        }
    }
    if (digits < 6) return 0;

    guint32 c0 = (guint32)g_ascii_toupper(name[0]);
    guint32 c1 = (guint32)g_ascii_toupper(name[1]);
    return (c0 << 8) | c1;
}

static void on_interfaces_added(GDBusConnection* connection,
                                const gchar* sender_name,
                                const gchar* object_path,
                                const gchar* interface_name,
                                const gchar* signal_name,
                                GVariant* parameters,
                                gpointer user_data) {
    BleScanner* scanner = (BleScanner*)user_data;
    (void)connection;
    (void)sender_name;
    (void)interface_name;
    (void)signal_name;

    // InterfacesAdded signal: (OBJPATH, DICT<STRING,DICT<STRING,VARIANT>>)
    GVariant* ifaces_and_properties = NULL;
    const gchar* obj_path = NULL;
    g_variant_get(parameters, "(&o@a{sa{sv}})", &obj_path,
                  &ifaces_and_properties);

    // Check if it contains org.bluez.Device1.
    GVariant* device_props = g_variant_lookup_value(
        ifaces_and_properties, "org.bluez.Device1",
        G_VARIANT_TYPE_VARDICT);
    if (!device_props) {
        g_variant_unref(ifaces_and_properties);
        return;
    }

    // Get the device address.
    GVariant* addr_var = g_variant_lookup_value(
        device_props, "Address", G_VARIANT_TYPE_STRING);
    if (!addr_var) {
        g_variant_unref(device_props);
        g_variant_unref(ifaces_and_properties);
        return;
    }
    const gchar* address = g_variant_get_string(addr_var, NULL);

    // Skip already-seen devices.
    if (g_hash_table_contains(scanner->seen_addresses, address)) {
        g_variant_unref(addr_var);
        g_variant_unref(device_props);
        g_variant_unref(ifaces_and_properties);
        return;
    }

    // Get the device name.
    GVariant* name_var = g_variant_lookup_value(
        device_props, "Name", G_VARIANT_TYPE_STRING);
    if (!name_var) {
        g_variant_unref(addr_var);
        g_variant_unref(device_props);
        g_variant_unref(ifaces_and_properties);
        return;
    }
    const gchar* name = g_variant_get_string(name_var, NULL);

    // Match against libdivecomputer descriptors.
    libdc_descriptor_info_t info = {0};
    int matched = 0;

    guint32 model_code = parse_pelagic_model_code(name);
    if (model_code != 0) {
        matched = libdc_descriptor_lookup_model(
            LIBDC_TRANSPORT_BLE, model_code, &info);
    }
    if (!matched) {
        matched = libdc_descriptor_match(
            name, LIBDC_TRANSPORT_BLE, &info);
    }

    if (matched && scanner->on_device_discovered) {
        g_hash_table_add(scanner->seen_addresses, g_strdup(address));

        LibdivecomputerPluginDiscoveredDevice* device =
            libdivecomputer_plugin_discovered_device_new(
                info.vendor, info.product, (int64_t)info.model,
                address, name,
                LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_BLE);

        scanner->on_device_discovered(device, scanner->user_data);
        g_object_unref(device);
    }

    g_variant_unref(name_var);
    g_variant_unref(addr_var);
    g_variant_unref(device_props);
    g_variant_unref(ifaces_and_properties);
}

gboolean ble_scanner_start(BleScanner* scanner) {
    g_autoptr(GError) error = NULL;

    scanner->connection = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &error);
    if (!scanner->connection) {
        g_warning("BleScanner: Failed to connect to system bus: %s",
                  error->message);
        return FALSE;
    }

    // Find the default Bluetooth adapter (/org/bluez/hci0).
    scanner->adapter_path = g_strdup("/org/bluez/hci0");

    // Subscribe to InterfacesAdded signals.
    scanner->interfaces_added_sub = g_dbus_connection_signal_subscribe(
        scanner->connection,
        "org.bluez",
        "org.freedesktop.DBus.ObjectManager",
        "InterfacesAdded",
        NULL,  // object path (match all)
        NULL,  // arg0 (no filter)
        G_DBUS_SIGNAL_FLAGS_NONE,
        on_interfaces_added,
        scanner,
        NULL);

    // Set discovery filter to LE only.
    GVariantBuilder filter_builder;
    g_variant_builder_init(&filter_builder, G_VARIANT_TYPE_VARDICT);
    g_variant_builder_add(&filter_builder, "{sv}", "Transport",
                          g_variant_new_string("le"));

    g_dbus_connection_call_sync(
        scanner->connection,
        "org.bluez",
        scanner->adapter_path,
        "org.bluez.Adapter1",
        "SetDiscoveryFilter",
        g_variant_new("(a{sv})", &filter_builder),
        NULL,
        G_DBUS_CALL_FLAGS_NONE,
        -1, NULL, &error);
    if (error) {
        g_warning("BleScanner: SetDiscoveryFilter failed: %s",
                  error->message);
        // Non-fatal — continue with unfiltered discovery.
        g_clear_error(&error);
    }

    // Start discovery.
    g_dbus_connection_call_sync(
        scanner->connection,
        "org.bluez",
        scanner->adapter_path,
        "org.bluez.Adapter1",
        "StartDiscovery",
        NULL,
        NULL,
        G_DBUS_CALL_FLAGS_NONE,
        -1, NULL, &error);
    if (error) {
        g_warning("BleScanner: StartDiscovery failed: %s",
                  error->message);
        return FALSE;
    }

    return TRUE;
}

void ble_scanner_stop(BleScanner* scanner) {
    if (!scanner->connection) return;

    // Stop discovery (ignore errors if already stopped).
    g_dbus_connection_call_sync(
        scanner->connection,
        "org.bluez",
        scanner->adapter_path,
        "org.bluez.Adapter1",
        "StopDiscovery",
        NULL,
        NULL,
        G_DBUS_CALL_FLAGS_NONE,
        -1, NULL, NULL);

    if (scanner->interfaces_added_sub > 0) {
        g_dbus_connection_signal_unsubscribe(
            scanner->connection, scanner->interfaces_added_sub);
        scanner->interfaces_added_sub = 0;
    }

    if (scanner->on_complete) {
        scanner->on_complete(scanner->user_data);
    }
}

void ble_scanner_free(BleScanner* scanner) {
    if (!scanner) return;

    if (scanner->connection && scanner->interfaces_added_sub > 0) {
        g_dbus_connection_signal_unsubscribe(
            scanner->connection, scanner->interfaces_added_sub);
    }
    g_free(scanner->adapter_path);
    if (scanner->seen_addresses) {
        g_hash_table_unref(scanner->seen_addresses);
    }
    if (scanner->connection) {
        g_object_unref(scanner->connection);
    }
    g_free(scanner);
}
