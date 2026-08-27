#ifndef FTDI_USB_DARWIN_H
#define FTDI_USB_DARWIN_H

#include <stddef.h>
#include <stdint.h>

// Raw USB access to an FTDI USB-to-serial bridge that no operating system
// driver has claimed.
//
// The Aeris/Oceanic dive-computer cable is an FTDI chip carrying a custom USB
// product ID. Apple's AppleUSBFTDI driver does not match it, so macOS creates
// no /dev/cu.* node and the serial transport has nothing to open (issue #732).
// Nothing having claimed the device is also what lets this code claim it.
//
// This layer knows nothing about FTDI. It moves bytes and control requests;
// the wire protocol lives in FtdiProtocol.swift, where it can be unit-tested.
//
// Deliberately free of IOKit types and headers so the declarations are safe in
// the iOS umbrella header. On platforms without USB host support every
// function is a stub returning an unsupported status.
//
// All functions return an IOReturn value: 0 (kIOReturnSuccess) means success.

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ftdi_usb_handle ftdi_usb_handle_t;

// Opens the USB device at `location_id`, claims its first interface and
// resolves the bulk IN and OUT pipes. On success stores a handle the caller
// must release with ftdi_usb_close.
int ftdi_usb_open(uint32_t location_id, ftdi_usb_handle_t **out_handle);

// Sends a vendor control request with no data stage.
int ftdi_usb_control(ftdi_usb_handle_t *handle, uint8_t request_type,
                     uint8_t request, uint16_t value, uint16_t index,
                     uint32_t timeout_ms);

// Reads from the bulk IN pipe. `size` should be a whole number of maximum-size
// packets; a partial-packet request risks an overflow on the host controller.
// Returns a timeout status with *actual set to 0 when nothing arrives.
int ftdi_usb_bulk_read(ftdi_usb_handle_t *handle, void *buffer, size_t size,
                       size_t *actual, uint32_t timeout_ms);

// Writes to the bulk OUT pipe.
int ftdi_usb_bulk_write(ftdi_usb_handle_t *handle, const void *buffer,
                        size_t size, size_t *actual, uint32_t timeout_ms);

// Maximum packet size of the bulk IN endpoint, from its descriptor. Returns 0
// for a null handle.
size_t ftdi_usb_max_packet_size(const ftdi_usb_handle_t *handle);

// True when `status` reports that nothing arrived before the deadline, as
// opposed to a real transport failure. The distinction matters upstream:
// libdivecomputer retries a timeout but treats an I/O error as fatal.
int ftdi_usb_status_is_timeout(int status);

// Closes the interface and device and frees the handle. Safe on NULL.
void ftdi_usb_close(ftdi_usb_handle_t *handle);

#ifdef __cplusplus
}
#endif

#endif  // FTDI_USB_DARWIN_H
