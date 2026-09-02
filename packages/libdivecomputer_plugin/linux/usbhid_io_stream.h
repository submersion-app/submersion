#ifndef USBHID_IO_STREAM_H_
#define USBHID_IO_STREAM_H_

#include <glib.h>

#include "libdc_wrapper.h"
#include "usbhid_enumerator.h"

G_BEGIN_DECLS

// USB HID byte pipe for libdivecomputer, backed by a hidraw node.
//
// This is the transport the Scubapro G2 family and the Suunto EON Steel family
// speak over a USB cable (issue #1271). libdivecomputer already knows the HID
// framing: passing LIBDC_TRANSPORT_USBHID to dc_custom_open makes uwatec_smart.c
// and suunto_eonsteel.c size their packets as HID reports, so all this owes
// them is one report per read and one report per write.
typedef struct {
    int fd;
    int timeout_ms;
} UsbHidIoStream;

// Create a new USB HID stream.
UsbHidIoStream* usbhid_io_stream_new(void);

// Open the device's hidraw node. Returns NULL on success, or a newly allocated
// reason the open was refused. The reason is returned rather than collapsed to
// a boolean because permission is the usual cause on Linux: hidraw nodes are
// root-only until a udev rule says otherwise, and a user who is told that can
// fix it.
gchar* usbhid_io_stream_open(UsbHidIoStream* stream, const UsbHidDevice* device);

// Build the libdc_io_callbacks_t struct pointing to this stream.
libdc_io_callbacks_t usbhid_io_stream_make_callbacks(UsbHidIoStream* stream);

// Close the node.
void usbhid_io_stream_close(UsbHidIoStream* stream);

// Free the stream and all resources.
void usbhid_io_stream_free(UsbHidIoStream* stream);

G_END_DECLS

#endif  // USBHID_IO_STREAM_H_
