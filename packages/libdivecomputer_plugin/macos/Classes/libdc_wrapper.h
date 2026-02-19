// Thin C wrapper around libdivecomputer functions.
// Keeps libdivecomputer headers as an implementation detail, not part
// of the plugin framework's public interface.

#ifndef LIBDC_WRAPPER_H
#define LIBDC_WRAPPER_H

#include <stdint.h>

// Get the libdivecomputer version string.
// Returns a statically allocated string (do not free).
const char *libdc_get_version(void);

// Transport type bitmask values matching dc_transport_t.
#define LIBDC_TRANSPORT_SERIAL    (1 << 0)
#define LIBDC_TRANSPORT_USB       (1 << 1)
#define LIBDC_TRANSPORT_USBHID    (1 << 2)
#define LIBDC_TRANSPORT_IRDA      (1 << 3)
#define LIBDC_TRANSPORT_BLUETOOTH (1 << 4)
#define LIBDC_TRANSPORT_BLE       (1 << 5)

// Descriptor info returned by the iterator.
typedef struct {
    const char *vendor;
    const char *product;
    unsigned int model;
    unsigned int transports;  // bitmask of LIBDC_TRANSPORT_* values
} libdc_descriptor_info_t;

// Opaque iterator handle.
typedef struct libdc_descriptor_iterator libdc_descriptor_iterator_t;

// Create a descriptor iterator. Returns NULL on failure.
// Caller must free with libdc_descriptor_iterator_free().
libdc_descriptor_iterator_t *libdc_descriptor_iterator_new(void);

// Get the next descriptor. Returns 0 on success, 1 when done, -1 on error.
// The returned info pointers are valid until the next call to _next or _free.
int libdc_descriptor_iterator_next(libdc_descriptor_iterator_t *iter,
                                   libdc_descriptor_info_t *info);

// Free the iterator.
void libdc_descriptor_iterator_free(libdc_descriptor_iterator_t *iter);

#endif
