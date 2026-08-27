#include "ftdi_usb_darwin.h"

#include <TargetConditionals.h>

#if TARGET_OS_OSX

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdlib.h>
#include <string.h>

struct ftdi_usb_handle {
    IOUSBDeviceInterface300 **device;
    IOUSBInterfaceInterface300 **interface;
    UInt8 pipe_in;
    UInt8 pipe_out;
    UInt16 max_packet_size;
};

// IOKit class names a USB device may be registered under. Both are tried, for
// the same reason UsbFtdiDeviceEnumerator queries both: the modern stack uses
// IOUSBHostDevice, the legacy name is kept working for compatibility, and
// which one answers on a given macOS release is not worth guessing.
static const char *const kUsbDeviceClassNames[] = {
    "IOUSBHostDevice",
    "IOUSBDevice",
};
static const size_t kUsbDeviceClassNameCount =
    sizeof(kUsbDeviceClassNames) / sizeof(kUsbDeviceClassNames[0]);

// Resolves the io_service_t for the USB device at `location_id`.
// Returns 0 when no such device is present. The caller owns the reference.
static io_service_t find_device(uint32_t location_id) {
    for (size_t i = 0; i < kUsbDeviceClassNameCount; i++) {
        CFMutableDictionaryRef matching = IOServiceMatching(kUsbDeviceClassNames[i]);
        if (matching == NULL) {
            continue;
        }

        io_iterator_t iterator = 0;
        if (IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
                != KERN_SUCCESS) {
            continue;
        }

        io_service_t found = 0;
        io_service_t service;
        while ((service = IOIteratorNext(iterator)) != 0) {
            CFTypeRef value = IORegistryEntryCreateCFProperty(
                service, CFSTR("locationID"), kCFAllocatorDefault, 0);
            uint32_t candidate = 0;
            if (value != NULL) {
                if (CFGetTypeID(value) == CFNumberGetTypeID()) {
                    CFNumberGetValue((CFNumberRef)value, kCFNumberSInt32Type, &candidate);
                }
                CFRelease(value);
            }
            if (candidate == location_id) {
                found = service;
                break;
            }
            IOObjectRelease(service);
        }

        IOObjectRelease(iterator);
        if (found != 0) {
            return found;
        }
    }
    return 0;
}

// Opens the device's first interface and resolves its bulk pipes.
static IOReturn open_interface(ftdi_usb_handle_t *handle) {
    IOUSBFindInterfaceRequest request;
    request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting = kIOUSBFindInterfaceDontCare;

    io_iterator_t iterator = 0;
    IOReturn rc = (*handle->device)->CreateInterfaceIterator(
        handle->device, &request, &iterator);
    if (rc != kIOReturnSuccess) {
        return rc;
    }

    io_service_t usb_interface = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (usb_interface == 0) {
        return kIOReturnNoDevice;
    }

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    rc = IOCreatePlugInInterfaceForService(
        usb_interface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID,
        &plugin, &score);
    IOObjectRelease(usb_interface);
    if (rc != kIOReturnSuccess || plugin == NULL) {
        return rc == kIOReturnSuccess ? kIOReturnNoResources : rc;
    }

    HRESULT hr = (*plugin)->QueryInterface(
        plugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID300),
        (LPVOID *)&handle->interface);
    (*plugin)->Release(plugin);
    if (hr != S_OK || handle->interface == NULL) {
        return kIOReturnNoResources;
    }

    // Claims the interface exclusively. This is the call the App Sandbox gates
    // behind com.apple.security.device.usb; without that entitlement it fails
    // rather than returning bad data, so the error is worth surfacing verbatim.
    rc = (*handle->interface)->USBInterfaceOpen(handle->interface);
    if (rc != kIOReturnSuccess) {
        return rc;
    }

    UInt8 endpoint_count = 0;
    rc = (*handle->interface)->GetNumEndpoints(handle->interface, &endpoint_count);
    if (rc != kIOReturnSuccess) {
        return rc;
    }

    // Pipe 0 is the default control pipe, so data endpoints start at 1.
    for (UInt8 pipe = 1; pipe <= endpoint_count; pipe++) {
        UInt8 direction = 0;
        UInt8 number = 0;
        UInt8 transfer_type = 0;
        UInt16 packet_size = 0;
        UInt8 interval = 0;
        rc = (*handle->interface)->GetPipeProperties(
            handle->interface, pipe, &direction, &number, &transfer_type,
            &packet_size, &interval);
        if (rc != kIOReturnSuccess || transfer_type != kUSBBulk) {
            continue;
        }
        if (direction == kUSBIn && handle->pipe_in == 0) {
            handle->pipe_in = pipe;
            handle->max_packet_size = packet_size;
        } else if (direction == kUSBOut && handle->pipe_out == 0) {
            handle->pipe_out = pipe;
        }
    }

    if (handle->pipe_in == 0 || handle->pipe_out == 0) {
        return kIOReturnNotFound;
    }
    return kIOReturnSuccess;
}

int ftdi_usb_open(uint32_t location_id, ftdi_usb_handle_t **out_handle) {
    if (out_handle == NULL) {
        return kIOReturnBadArgument;
    }
    *out_handle = NULL;

    io_service_t service = find_device(location_id);
    if (service == 0) {
        return kIOReturnNoDevice;
    }

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    IOReturn rc = IOCreatePlugInInterfaceForService(
        service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin,
        &score);
    IOObjectRelease(service);
    if (rc != kIOReturnSuccess || plugin == NULL) {
        return rc == kIOReturnSuccess ? kIOReturnNoResources : rc;
    }

    ftdi_usb_handle_t *handle = calloc(1, sizeof(*handle));
    if (handle == NULL) {
        (*plugin)->Release(plugin);
        return kIOReturnNoMemory;
    }

    HRESULT hr = (*plugin)->QueryInterface(
        plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID300),
        (LPVOID *)&handle->device);
    (*plugin)->Release(plugin);
    if (hr != S_OK || handle->device == NULL) {
        free(handle);
        return kIOReturnNoResources;
    }

    rc = (*handle->device)->USBDeviceOpen(handle->device);
    if (rc != kIOReturnSuccess) {
        (*handle->device)->Release(handle->device);
        free(handle);
        return rc;
    }

    // An unclaimed device may still be unconfigured, because macOS sets the
    // configuration when a driver matches and no driver matched this one.
    UInt8 configuration = 0;
    if ((*handle->device)->GetConfiguration(handle->device, &configuration)
            == kIOReturnSuccess
        && configuration == 0) {
        IOUSBConfigurationDescriptorPtr descriptor = NULL;
        if ((*handle->device)->GetConfigurationDescriptorPtr(
                handle->device, 0, &descriptor) == kIOReturnSuccess
            && descriptor != NULL) {
            (*handle->device)->SetConfiguration(
                handle->device, descriptor->bConfigurationValue);
        }
    }

    rc = open_interface(handle);
    if (rc != kIOReturnSuccess) {
        ftdi_usb_close(handle);
        return rc;
    }

    *out_handle = handle;
    return kIOReturnSuccess;
}

int ftdi_usb_control(ftdi_usb_handle_t *handle, uint8_t request_type,
                     uint8_t request, uint16_t value, uint16_t index,
                     uint32_t timeout_ms) {
    if (handle == NULL || handle->device == NULL) {
        return kIOReturnNotOpen;
    }

    IOUSBDevRequestTO req;
    memset(&req, 0, sizeof(req));
    req.bmRequestType = request_type;
    req.bRequest = request;
    req.wValue = value;
    req.wIndex = index;
    req.wLength = 0;
    req.pData = NULL;
    req.noDataTimeout = timeout_ms;
    req.completionTimeout = timeout_ms;

    return (*handle->device)->DeviceRequestTO(handle->device, &req);
}

int ftdi_usb_bulk_read(ftdi_usb_handle_t *handle, void *buffer, size_t size,
                       size_t *actual, uint32_t timeout_ms) {
    if (actual != NULL) {
        *actual = 0;
    }
    if (handle == NULL || handle->interface == NULL) {
        return kIOReturnNotOpen;
    }
    if (size == 0) {
        return kIOReturnSuccess;
    }

    UInt32 transferred = (UInt32)size;
    IOReturn rc = (*handle->interface)->ReadPipeTO(
        handle->interface, handle->pipe_in, buffer, &transferred, timeout_ms,
        timeout_ms);
    // A timeout still reports whatever arrived before it expired.
    if (rc == kIOReturnSuccess || rc == kIOReturnTimeout) {
        if (actual != NULL) {
            *actual = (size_t)transferred;
        }
    }
    return rc;
}

int ftdi_usb_bulk_write(ftdi_usb_handle_t *handle, const void *buffer,
                        size_t size, size_t *actual, uint32_t timeout_ms) {
    if (actual != NULL) {
        *actual = 0;
    }
    if (handle == NULL || handle->interface == NULL) {
        return kIOReturnNotOpen;
    }
    if (size == 0) {
        return kIOReturnSuccess;
    }

    IOReturn rc = (*handle->interface)->WritePipeTO(
        handle->interface, handle->pipe_out, (void *)buffer, (UInt32)size,
        timeout_ms, timeout_ms);
    if (rc == kIOReturnSuccess && actual != NULL) {
        *actual = size;
    }
    return rc;
}

size_t ftdi_usb_max_packet_size(const ftdi_usb_handle_t *handle) {
    return handle == NULL ? 0 : (size_t)handle->max_packet_size;
}

int ftdi_usb_status_is_timeout(int status) {
    return status == kIOReturnTimeout ? 1 : 0;
}

void ftdi_usb_close(ftdi_usb_handle_t *handle) {
    if (handle == NULL) {
        return;
    }
    if (handle->interface != NULL) {
        (*handle->interface)->USBInterfaceClose(handle->interface);
        (*handle->interface)->Release(handle->interface);
    }
    if (handle->device != NULL) {
        (*handle->device)->USBDeviceClose(handle->device);
        (*handle->device)->Release(handle->device);
    }
    free(handle);
}

#else  // TARGET_OS_OSX

// iOS and every other Apple platform have no USB host support. The stubs keep
// the symbols resolvable so callers need no conditional compilation.

#include <IOKit/IOReturn.h>

int ftdi_usb_open(uint32_t location_id, ftdi_usb_handle_t **out_handle) {
    (void)location_id;
    if (out_handle != NULL) {
        *out_handle = NULL;
    }
    return kIOReturnUnsupported;
}

int ftdi_usb_control(ftdi_usb_handle_t *handle, uint8_t request_type,
                     uint8_t request, uint16_t value, uint16_t index,
                     uint32_t timeout_ms) {
    (void)handle;
    (void)request_type;
    (void)request;
    (void)value;
    (void)index;
    (void)timeout_ms;
    return kIOReturnUnsupported;
}

int ftdi_usb_bulk_read(ftdi_usb_handle_t *handle, void *buffer, size_t size,
                       size_t *actual, uint32_t timeout_ms) {
    (void)handle;
    (void)buffer;
    (void)size;
    (void)timeout_ms;
    if (actual != NULL) {
        *actual = 0;
    }
    return kIOReturnUnsupported;
}

int ftdi_usb_bulk_write(ftdi_usb_handle_t *handle, const void *buffer,
                        size_t size, size_t *actual, uint32_t timeout_ms) {
    (void)handle;
    (void)buffer;
    (void)size;
    (void)timeout_ms;
    if (actual != NULL) {
        *actual = 0;
    }
    return kIOReturnUnsupported;
}

size_t ftdi_usb_max_packet_size(const ftdi_usb_handle_t *handle) {
    (void)handle;
    return 0;
}

int ftdi_usb_status_is_timeout(int status) {
    (void)status;
    return 0;
}

void ftdi_usb_close(ftdi_usb_handle_t *handle) {
    (void)handle;
}

#endif  // TARGET_OS_OSX
