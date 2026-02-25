#include "serial_scanner.h"

#include <Windows.h>
#include <SetupAPI.h>
#include <devguid.h>
#include <initguid.h>
#include <ntddser.h>

#include <cstdio>
#include <string>
#include <vector>

#pragma comment(lib, "SetupAPI.lib")

namespace libdivecomputer_plugin {

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
