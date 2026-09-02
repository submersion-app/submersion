#ifndef USBHID_ENUMERATOR_H_
#define USBHID_ENUMERATOR_H_

#include <glib.h>

G_BEGIN_DECLS

// A USB HID device present on the machine.
typedef struct {
    unsigned short vendor_id;
    unsigned short product_id;
    // Path of the hidraw node, which is what open(2) takes.
    gchar* path;
    // The HID name reported by the kernel, empty when it reports none.
    gchar* name;
} UsbHidDevice;

// What to show in logs and probe messages: the device's own name when it has
// one, its identifiers otherwise. Caller frees.
gchar* usb_hid_device_display_name(const UsbHidDevice* device);

// Answers whether a vendor/product id pair belongs to the selected model.
typedef gboolean (*UsbHidMatchFn)(unsigned short vendor_id,
                                  unsigned short product_id,
                                  gpointer user_data);

// Lists attached HID devices that `is_match` accepts.
//
// There is no allowlist here. Which HID device belongs to which dive computer
// is libdivecomputer's knowledge, held in the vendor and product id tables
// inside dc_filter_uwatec and dc_filter_suunto and reachable through
// libdc_usbhid_match. The caller passes that question in as `is_match`.
//
// Identifiers are read from sysfs rather than from the device, so listing
// works without permission to open a hidraw node. A distribution that has not
// installed dive-computer udev rules then fails at open time, with a message
// that says so, instead of silently finding nothing.
//
// Returns a GPtrArray of UsbHidDevice with a free function set; g_ptr_array_unref
// releases everything.
GPtrArray* usb_hid_enumerate_matching(UsbHidMatchFn is_match,
                                      gpointer user_data);

G_END_DECLS

#endif  // USBHID_ENUMERATOR_H_
