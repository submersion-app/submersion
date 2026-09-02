#include "usbhid_enumerator.h"

#include <Windows.h>
#include <SetupAPI.h>

extern "C" {
#include <hidsdi.h>
}

#include <cstdio>
#include <string>
#include <vector>

#pragma comment(lib, "SetupAPI.lib")
#pragma comment(lib, "hid.lib")

namespace libdivecomputer_plugin {
namespace {

// The HID product string is UTF-16 and only reaches a log line, so a lossy
// narrowing is fine. An empty result is indistinguishable from "no name",
// which is the same thing as far as the caller is concerned.
std::string NarrowString(const wchar_t* wide) {
    if (wide == nullptr || wide[0] == L'\0') return {};
    int needed = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr,
                                     nullptr);
    if (needed <= 1) return {};

    // `needed` counts the terminator, because cchWideChar is -1, so the string
    // holds one character fewer and the conversion writes one byte more. That
    // last byte lands on the terminator slot, not past the buffer: C++17 gives
    // data() the range [0, size()], and writing charT() to data()[size()] is
    // exactly what the standard permits there.
    std::string narrow(static_cast<size_t>(needed) - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide, -1, narrow.data(), needed, nullptr,
                        nullptr);
    return narrow;
}

std::string FormatIds(unsigned short vendor_id, unsigned short product_id) {
    char buffer[32] = {};
    // Widened explicitly: %X takes an unsigned int, and the build treats the
    // format-mismatch warning as an error.
    snprintf(buffer, sizeof(buffer), "0x%04X:0x%04X",
             static_cast<unsigned int>(vendor_id),
             static_cast<unsigned int>(product_id));
    return buffer;
}

}  // namespace

std::string UsbHidDevice::DisplayName() const {
    if (!product_name.empty()) return product_name;
    return "HID " + FormatIds(vendor_id, product_id);
}

std::vector<UsbHidDevice> EnumerateMatchingUsbHidDevices(
    const std::function<bool(unsigned short, unsigned short)>& is_match,
    const std::function<void(const std::string&)>& log) {
    std::vector<UsbHidDevice> devices;
    int considered = 0;

    GUID hid_guid = {};
    HidD_GetHidGuid(&hid_guid);

    HDEVINFO dev_info = SetupDiGetClassDevs(
        &hid_guid, nullptr, nullptr, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (dev_info == INVALID_HANDLE_VALUE) {
        if (log) log("SetupDiGetClassDevs(HID) failed");
        return devices;
    }

    SP_DEVICE_INTERFACE_DATA interface_data = {};
    interface_data.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);

    for (DWORD i = 0; SetupDiEnumDeviceInterfaces(dev_info, nullptr, &hid_guid,
                                                  i, &interface_data);
         i++) {
        DWORD required = 0;
        SetupDiGetDeviceInterfaceDetailW(dev_info, &interface_data, nullptr, 0,
                                         &required, nullptr);
        if (required == 0) continue;

        std::vector<BYTE> buffer(required);
        auto* detail =
            reinterpret_cast<PSP_DEVICE_INTERFACE_DETAIL_DATA_W>(buffer.data());
        detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);
        if (!SetupDiGetDeviceInterfaceDetailW(dev_info, &interface_data, detail,
                                              required, nullptr, nullptr)) {
            continue;
        }

        // Opened without GENERIC_READ or GENERIC_WRITE on purpose. Windows
        // hands out a HID handle with no access rights to anybody, while a
        // read/write handle to a device another process has already claimed
        // is refused. Attributes and strings are readable either way, so the
        // enumeration must not be the thing that fails.
        HANDLE handle = CreateFileW(detail->DevicePath, 0,
                                    FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                                    OPEN_EXISTING, 0, nullptr);
        if (handle == INVALID_HANDLE_VALUE) continue;

        HIDD_ATTRIBUTES attributes = {};
        attributes.Size = sizeof(HIDD_ATTRIBUTES);
        if (!HidD_GetAttributes(handle, &attributes)) {
            CloseHandle(handle);
            continue;
        }

        wchar_t product[256] = {};
        HidD_GetProductString(handle, product,
                              static_cast<ULONG>(sizeof(product)));
        CloseHandle(handle);

        considered++;
        const std::string product_name = NarrowString(product);
        const std::string id_text =
            FormatIds(attributes.VendorID, attributes.ProductID);

        if (!is_match(attributes.VendorID, attributes.ProductID)) {
            if (log) {
                log("HID " + id_text + " '" + product_name +
                    "' is not this dive computer");
            }
            continue;
        }

        if (log) {
            log("HID " + id_text + " '" + product_name +
                "' matched the selected model");
        }
        UsbHidDevice device;
        device.vendor_id = attributes.VendorID;
        device.product_id = attributes.ProductID;
        device.path = detail->DevicePath;
        device.product_name = product_name;
        devices.push_back(std::move(device));
    }

    SetupDiDestroyDeviceInfoList(dev_info);

    // Always emitted, so a log with no per-device lines still says whether
    // that means "no HID devices at all" or "the walk itself failed".
    if (log) {
        log("HID enumeration considered " + std::to_string(considered) +
            " device(s), matched " + std::to_string(devices.size()));
    }
    return devices;
}

}  // namespace libdivecomputer_plugin
