#include "usbhid_enumerator.h"

#include <stdio.h>
#include <string.h>

#define SYSFS_HIDRAW_DIR "/sys/class/hidraw"

static void usb_hid_device_free(gpointer data) {
    UsbHidDevice* device = (UsbHidDevice*)data;
    if (device == NULL) return;
    g_free(device->path);
    g_free(device->name);
    g_free(device);
}

gchar* usb_hid_device_display_name(const UsbHidDevice* device) {
    if (device == NULL) return g_strdup("");
    if (device->name != NULL && device->name[0] != '\0') {
        return g_strdup(device->name);
    }
    return g_strdup_printf("HID 0x%04X:0x%04X", device->vendor_id,
                           device->product_id);
}

// Reads the identifiers out of a hidraw node's uevent file.
//
// The kernel writes one HID_ID line per device, "bus:vendor:product" with each
// field zero-padded hexadecimal, and an optional HID_NAME line. Parsing that is
// what lets enumeration run without opening the device: HIDIOCGRAWINFO would
// need a file descriptor, and a distribution without dive-computer udev rules
// does not grant one.
static gboolean read_uevent(const gchar* node, unsigned short* vendor_id,
                            unsigned short* product_id, gchar** name) {
    g_autofree gchar* uevent_path =
        g_build_filename(SYSFS_HIDRAW_DIR, node, "device", "uevent", NULL);
    g_autofree gchar* contents = NULL;
    if (!g_file_get_contents(uevent_path, &contents, NULL, NULL)) {
        return FALSE;
    }

    gboolean found_ids = FALSE;
    g_auto(GStrv) lines = g_strsplit(contents, "\n", -1);
    for (int i = 0; lines[i] != NULL; i++) {
        if (g_str_has_prefix(lines[i], "HID_ID=")) {
            // The bus id leads HID_ID and nothing here wants it, so %*x
            // parses and discards it. That makes sscanf report two
            // assignments rather than three.
            unsigned int vendor = 0, product = 0;
            if (sscanf(lines[i] + strlen("HID_ID="), "%*x:%x:%x", &vendor,
                       &product) == 2) {
                *vendor_id = (unsigned short)(vendor & 0xFFFF);
                *product_id = (unsigned short)(product & 0xFFFF);
                found_ids = TRUE;
            }
        } else if (g_str_has_prefix(lines[i], "HID_NAME=")) {
            g_free(*name);
            *name = g_strdup(lines[i] + strlen("HID_NAME="));
        }
    }
    return found_ids;
}

GPtrArray* usb_hid_enumerate_matching(UsbHidMatchFn is_match,
                                      gpointer user_data) {
    GPtrArray* devices = g_ptr_array_new_with_free_func(usb_hid_device_free);
    if (is_match == NULL) return devices;

    GDir* dir = g_dir_open(SYSFS_HIDRAW_DIR, 0, NULL);
    if (dir == NULL) return devices;

    const gchar* node = NULL;
    while ((node = g_dir_read_name(dir)) != NULL) {
        if (!g_str_has_prefix(node, "hidraw")) continue;

        unsigned short vendor_id = 0;
        unsigned short product_id = 0;
        gchar* name = NULL;
        if (!read_uevent(node, &vendor_id, &product_id, &name)) {
            g_free(name);
            continue;
        }
        if (!is_match(vendor_id, product_id, user_data)) {
            g_free(name);
            continue;
        }

        UsbHidDevice* device = g_new0(UsbHidDevice, 1);
        device->vendor_id = vendor_id;
        device->product_id = product_id;
        device->path = g_build_filename("/dev", node, NULL);
        device->name = name;
        g_ptr_array_add(devices, device);
    }

    g_dir_close(dir);
    return devices;
}
