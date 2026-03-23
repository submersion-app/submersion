#include "serial_scanner.h"

#include <Windows.h>
#include <initguid.h>
#include <SetupAPI.h>
#include <devguid.h>

// ntddser.h provides GUID_DEVINTERFACE_COMPORT.  It also redefines
// SERIAL_LSRMST_* / SERIAL_IOC_* macros already pulled in through
// Windows.h, so suppress the C4005 (macro redefinition) warning.
#pragma warning(push)
#pragma warning(disable : 4005)
#include <ntddser.h>
#pragma warning(pop)

#include <cstdio>
#include <string>
#include <vector>

#pragma comment(lib, "SetupAPI.lib")

namespace libdivecomputer_plugin {

std::vector<std::string> EnumerateAvailableSerialPorts() {
    std::vector<std::string> ports;

    HDEVINFO dev_info = SetupDiGetClassDevs(
        &GUID_DEVINTERFACE_COMPORT, nullptr, nullptr,
        DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (dev_info == INVALID_HANDLE_VALUE) return ports;

    SP_DEVINFO_DATA dev_data = {};
    dev_data.cbSize = sizeof(SP_DEVINFO_DATA);

    for (DWORD i = 0; SetupDiEnumDeviceInfo(dev_info, i, &dev_data); i++) {
        // Only include USB-attached serial ports during auto-detect to avoid
        // probing unrelated devices (built-in COM ports, GPS modules, etc.).
        // If the hardware ID cannot be read, skip the port (fail-closed) to
        // avoid probing unknown devices.
        char hw_id[256] = {};
        if (!SetupDiGetDeviceRegistryPropertyA(
                dev_info, &dev_data, SPDRP_HARDWAREID, nullptr,
                reinterpret_cast<PBYTE>(hw_id), sizeof(hw_id), nullptr)) {
            continue;
        }
        // Hardware IDs for USB devices start with "USB\" or "FTDIBUS\".
        if (_strnicmp(hw_id, "USB\\", 4) != 0 &&
            _strnicmp(hw_id, "FTDIBUS\\", 8) != 0) {
            continue;
        }

        HKEY key = SetupDiOpenDevRegKey(
            dev_info, &dev_data, DICS_FLAG_GLOBAL, 0,
            DIREG_DEV, KEY_READ);
        if (key == INVALID_HANDLE_VALUE) continue;

        char port_name[32] = {};
        DWORD port_name_size = sizeof(port_name);
        DWORD type = 0;
        LONG result = RegQueryValueExA(
            key, "PortName", nullptr, &type,
            reinterpret_cast<LPBYTE>(port_name), &port_name_size);
        RegCloseKey(key);

        if (result == ERROR_SUCCESS) {
            ports.emplace_back(port_name);
        }
    }

    SetupDiDestroyDeviceInfoList(dev_info);
    return ports;
}

SerialScanner::SerialScanner() = default;

SerialScanner::~SerialScanner() { Stop(); }

void SerialScanner::SetOnDeviceDiscovered(DeviceCallback callback) {
    on_device_discovered_ = std::move(callback);
}

void SerialScanner::SetOnComplete(CompleteCallback callback) {
    on_complete_ = std::move(callback);
}

void SerialScanner::Start() {
    scan_thread_ = std::thread([this] {
        EnumerateSerialPorts();
        if (on_complete_) {
            on_complete_();
        }
    });
}

void SerialScanner::Stop() {
    if (scan_thread_.joinable()) {
        scan_thread_.join();
    }
}

void SerialScanner::EnumerateSerialPorts() {
    HDEVINFO dev_info = SetupDiGetClassDevs(
        &GUID_DEVINTERFACE_COMPORT, nullptr, nullptr,
        DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (dev_info == INVALID_HANDLE_VALUE) return;

    SP_DEVINFO_DATA dev_data = {};
    dev_data.cbSize = sizeof(SP_DEVINFO_DATA);

    for (DWORD i = 0; SetupDiEnumDeviceInfo(dev_info, i, &dev_data); i++) {
        // Get the friendly name.
        char friendly_name[256] = {};
        if (!SetupDiGetDeviceRegistryPropertyA(
                dev_info, &dev_data, SPDRP_FRIENDLYNAME, nullptr,
                reinterpret_cast<PBYTE>(friendly_name),
                sizeof(friendly_name), nullptr)) {
            continue;
        }

        // Get the port name from device parameters registry key.
        HKEY key = SetupDiOpenDevRegKey(
            dev_info, &dev_data, DICS_FLAG_GLOBAL, 0,
            DIREG_DEV, KEY_READ);
        if (key == INVALID_HANDLE_VALUE) continue;

        char port_name[32] = {};
        DWORD port_name_size = sizeof(port_name);
        DWORD type = 0;
        LONG result = RegQueryValueExA(
            key, "PortName", nullptr, &type,
            reinterpret_cast<LPBYTE>(port_name), &port_name_size);
        RegCloseKey(key);

        if (result != ERROR_SUCCESS) continue;

        // Match against libdivecomputer descriptors.
        libdc_descriptor_info_t info = {};
        int matched = libdc_descriptor_match(
            friendly_name, LIBDC_TRANSPORT_SERIAL, &info);

        if (!matched) {
            // Also try with just the port name.
            matched = libdc_descriptor_match(
                port_name, LIBDC_TRANSPORT_SERIAL, &info);
        }

        if (!matched) continue;

        std::string name_str(friendly_name);
        DiscoveredDevice device(
            std::string(info.vendor), std::string(info.product),
            static_cast<int64_t>(info.model), std::string(port_name),
            &name_str, TransportType::kSerial);

        if (on_device_discovered_) {
            on_device_discovered_(std::move(device));
        }
    }

    SetupDiDestroyDeviceInfoList(dev_info);
}

}  // namespace libdivecomputer_plugin
