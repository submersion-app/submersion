#include "ble_io_stream.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <sstream>

#include "native_logger.h"

namespace libdivecomputer_plugin {

using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Storage::Streams;

namespace {

// Log category shared with the Android and darwin transports, so a Windows
// bug report reads the same way as the ones this code was modelled on.
constexpr char kBleCategory[] = "BLE";

// Colon-free upper-case hex, the one form a Windows address takes anywhere
// else in this plugin: ble_scanner.cc formats the same uint64 as "%012llX",
// that string is DiscoveredDevice::address(), it is the access-code storage
// key, it is what dive_computer_host_api_impl.cc parses back with strtoull,
// and it is what the Dart log prints. A colon-separated form here would mean
// the connect and error lines could not be matched to the device that
// produced them, and bluetoothAddressesMatch (discovery_providers.dart) only
// upper-cases before comparing, so it would not bridge the two spellings.
// HRESULT code plus message. The message alone is localized and often
// generic ("The object has been closed"), while the code is what a bug
// report can be searched on and what names an access or authentication
// failure precisely.
std::string DescribeHresult(const winrt::hresult_error& e) {
    char code[16];
    std::snprintf(code, sizeof(code), "0x%08X",
                  static_cast<unsigned int>(static_cast<int32_t>(e.code())));
    return std::string(code) + " " + winrt::to_string(e.message());
}

std::string FormatAddress(uint64_t address) {
    char buffer[13];
    std::snprintf(buffer, sizeof(buffer), "%012llX",
                  static_cast<unsigned long long>(address));
    return std::string(buffer);
}

// Formatted by hand rather than through winrt::to_hstring so the output
// matches the lowercase 8-4-4-4-12 form Android's UUID.toString() logs, and
// so no cppwinrt overload has to exist for it.
std::string DescribeUuid(const winrt::guid& uuid) {
    char buffer[37];
    std::snprintf(buffer, sizeof(buffer),
                  "%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                  static_cast<unsigned>(uuid.Data1),
                  static_cast<unsigned>(uuid.Data2),
                  static_cast<unsigned>(uuid.Data3),
                  static_cast<unsigned>(uuid.Data4[0]),
                  static_cast<unsigned>(uuid.Data4[1]),
                  static_cast<unsigned>(uuid.Data4[2]),
                  static_cast<unsigned>(uuid.Data4[3]),
                  static_cast<unsigned>(uuid.Data4[4]),
                  static_cast<unsigned>(uuid.Data4[5]),
                  static_cast<unsigned>(uuid.Data4[6]),
                  static_cast<unsigned>(uuid.Data4[7]));
    return std::string(buffer);
}

// GattCommunicationStatus says which half of a failed GATT call to look at:
// Unreachable is the link, AccessDenied is Windows' own pairing state, and
// ProtocolError is the computer answering with an ATT error.
std::string DescribeGattStatus(GattCommunicationStatus status) {
    switch (status) {
        case GattCommunicationStatus::Success:
            return "success";
        case GattCommunicationStatus::Unreachable:
            return "unreachable; the computer is out of range, switched its "
                   "radio off, or dropped the link";
        case GattCommunicationStatus::ProtocolError:
            return "protocol error; the computer refused the request";
        case GattCommunicationStatus::AccessDenied:
            return "access denied; Windows will not talk to this computer "
                   "without pairing it first";
        default:
            return "unknown status (" +
                   std::to_string(static_cast<int>(status)) + ")";
    }
}

}  // namespace

// Same UUIDs as the macOS/iOS BleIoStream.
const winrt::guid BleIoStream::kPreferredServiceUuid{
    0xCB3C4555, 0xD670, 0x4670,
    {0xBC, 0x20, 0xB6, 0x1D, 0xBC, 0x85, 0x1E, 0x9A}};
const winrt::guid BleIoStream::kPreferredWriteUuid{
    0x6606AB42, 0x89D5, 0x4A00,
    {0xA8, 0xCE, 0x4E, 0xB5, 0xE1, 0x41, 0x4E, 0xE0}};
const winrt::guid BleIoStream::kPreferredNotifyUuid{
    0xA60B8E5C, 0xB267, 0x44D7,
    {0x97, 0x64, 0x83, 0x7C, 0xAF, 0x96, 0x48, 0x9E}};
// Halcyon Symbios device-centric Tx/Rx endpoints. The app WRITES commands to
// the device's Rx (00000101) and READS replies (indications) from its Tx
// (00000201) -- matching Subsurface's qt-ble.cpp. Both chars advertise
// read+write+indicate and tie on raw score, so these biases pick the pair.
// PR #356 biased them backwards (wrote to Tx) and the device never answered
// (issue #288).
const winrt::guid BleIoStream::kHalcyonSymbiosTxUuid{
    0x00000201, 0x8C3B, 0x4F2C,
    {0xA5, 0x9E, 0x8C, 0x08, 0x22, 0x4F, 0x32, 0x53}};
const winrt::guid BleIoStream::kHalcyonSymbiosRxUuid{
    0x00000101, 0x8C3B, 0x4F2C,
    {0xA5, 0x9E, 0x8C, 0x08, 0x22, 0x4F, 0x32, 0x53}};

// Telit/Stollmann Terminal I/O (TIO), service 0xFEFB.
//
// Heinrichs Weikamp computers built on the Telit (formerly Stollmann)
// BlueMod+SR module -- the OSTC 2/3/4/Sport/cR/Plus family -- expose their
// serial bridge behind this service with credit-based flow control (Telit
// "TIO Implementation Guide" r04). The module carries no UART data until the
// client subscribes to UART Credits TX and grants initial credits on UART
// Credits RX, and it spends one credit per notification, so the balance must
// also be topped up while a transfer runs. Without the handshake the very
// first command write fails and libdivecomputer reports "Failed to send the
// command" (issue #923, OSTC4).
//
// Subsurface implements the same handshake in core/qt-ble.cpp across the two
// Heinrichs Weikamp module families, and both are handled here: Telit (0xFEFB,
// four characteristics, credits mandatory) and the u-blox serial service
// (...d701, two characteristics, credits optional -- the OSTC nano downloads
// today with no handshake at all, #280/#394, so a rejected grant there falls
// back to running without flow control instead of failing a working device).
// Mirrors darwin's BleCharacteristicSelector + TerminalIoCreditPolicy.
const winrt::guid BleIoStream::kTerminalIoServiceUuid{
    0x0000FEFB, 0x0000, 0x1000,
    {0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB}};
const winrt::guid BleIoStream::kTerminalIoDataRxUuid{
    0x00000001, 0x0000, 0x1000,
    {0x80, 0x00, 0x00, 0x80, 0x25, 0x00, 0x00, 0x00}};
const winrt::guid BleIoStream::kTerminalIoDataTxUuid{
    0x00000002, 0x0000, 0x1000,
    {0x80, 0x00, 0x00, 0x80, 0x25, 0x00, 0x00, 0x00}};
const winrt::guid BleIoStream::kTerminalIoCreditsRxUuid{
    0x00000003, 0x0000, 0x1000,
    {0x80, 0x00, 0x00, 0x80, 0x25, 0x00, 0x00, 0x00}};
const winrt::guid BleIoStream::kTerminalIoCreditsTxUuid{
    0x00000004, 0x0000, 0x1000,
    {0x80, 0x00, 0x00, 0x80, 0x25, 0x00, 0x00, 0x00}};

// u-blox serial service: one characteristic carries data in both directions
// and one carries credits in both directions.
const winrt::guid BleIoStream::kUbloxServiceUuid{
    0x2456E1B9, 0x26E2, 0x8F83,
    {0xE7, 0x44, 0xF3, 0x4F, 0x01, 0xE9, 0xD7, 0x01}};
const winrt::guid BleIoStream::kUbloxDataUuid{
    0x2456E1B9, 0x26E2, 0x8F83,
    {0xE7, 0x44, 0xF3, 0x4F, 0x01, 0xE9, 0xD7, 0x03}};
const winrt::guid BleIoStream::kUbloxCreditsUuid{
    0x2456E1B9, 0x26E2, 0x8F83,
    {0xE7, 0x44, 0xF3, 0x4F, 0x01, 0xE9, 0xD7, 0x04}};

static constexpr uint32_t kBleIoctlType = 'b';
static constexpr uint32_t kBleIoctlGetName = 0;
static constexpr uint32_t kBleIoctlGetPinCode = 1;
static constexpr uint32_t kBleIoctlAccessCode = 2;
static constexpr uint32_t kDirectionInput = 1;

BleIoStream::BleIoStream() = default;

BleIoStream::~BleIoStream() { Close(); }

bool BleIoStream::ConnectAndDiscover(uint64_t bluetooth_address) {
    const std::string address = FormatAddress(bluetooth_address);
    NativeLogger::Debug(kBleCategory, "Connecting to " + address);
    try {
        device_ = BluetoothLEDevice::FromBluetoothAddressAsync(
                      bluetooth_address)
                      .get();
        if (!device_) {
            // Phrased as a lead rather than a verdict, for the same reason
            // the Android twin was (GattDiagnostics.describeDiscoveryFailure):
            // naming one cause as fact sends the reporter down it. Windows
            // resolves the address against its own device database, so a
            // dual-mode computer known only as a Classic device is one
            // explanation, but the single-argument FromBluetoothAddressAsync
            // resolves against a public address type and so also misses a
            // random-static advertiser (#1232), and a stored address the
            // stack has not seen advertise recently fails here too
            // (discovery_providers.dart).
            NativeLogger::Error(kBleCategory,
                                "No Bluetooth LE device for " + address +
                                    "; Windows resolved no LE record for this "
                                    "address. Known causes: a dual-mode "
                                    "computer Windows knows only as a "
                                    "Bluetooth Classic device, an address "
                                    "the stack has not seen advertise "
                                    "recently, or a random-static advertising "
                                    "address. Re-running a scan before the "
                                    "connect distinguishes the second");
            return false;
        }

        device_name_ = winrt::to_string(device_.Name());

        // Request a throughput-optimized (low-interval) connection so a dive
        // computer's serial->BLE bridge can drain its buffer during bulk
        // logbook/profile dumps without overflowing and dropping
        // notifications (issue #280, OSTC nano). Best-effort: hold the request
        // for the connection's lifetime; ignore failures on Windows < 2004 or
        // unsupported controllers.
        try {
            preferred_connection_request_ =
                device_.RequestPreferredConnectionParameters(
                    BluetoothLEPreferredConnectionParameters::
                        ThroughputOptimized());
        } catch (...) {
        }

        return DiscoverCharacteristics();
    // DiscoverCharacteristics runs inside this try and does not catch its
    // own .get() throws, so these handlers see discovery failures too.
    // Saying "connect" would tell the reader the link never came up when it
    // may have come up and died during discovery, which is exactly the
    // distinction #957 was about.
    } catch (const winrt::hresult_error& e) {
        NativeLogger::Error(kBleCategory,
                            "Connect or service discovery for " + address +
                                " threw: " + DescribeHresult(e));
        return false;
    } catch (...) {
        NativeLogger::Error(kBleCategory,
                            "Connect or service discovery for " + address +
                                " threw an unknown error");
        return false;
    }
}

bool BleIoStream::DiscoverCharacteristics() {
    auto services_result =
        device_.GetGattServicesAsync(BluetoothCacheMode::Uncached).get();
    if (services_result.Status() != GattCommunicationStatus::Success) {
        NativeLogger::Error(kBleCategory,
                            "Service discovery failed: " +
                                DescribeGattStatus(services_result.Status()));
        return false;
    }

    // The UUIDs a computer actually exposed are what a new descriptor gets
    // written from, and their absence is the whole diagnosis when none of
    // them can carry a serial session (issue #957).
    std::vector<std::string> discovered_service_uuids;

    struct Candidate {
        int score = -1;
        GattCharacteristic write{nullptr};
        GattCharacteristic notify{nullptr};
        GattCharacteristic credits_write{nullptr};
        GattCharacteristic credits_notify{nullptr};
        bool credits_required = false;
    };
    Candidate best;

    for (auto const& service : services_result.Services()) {
        auto chars_result =
            service.GetCharacteristicsAsync(BluetoothCacheMode::Uncached)
                .get();
        if (chars_result.Status() != GattCommunicationStatus::Success) {
            NativeLogger::Warn(kBleCategory,
                               "Service " + DescribeUuid(service.Uuid()) +
                                   " listed no characteristics: " +
                                   DescribeGattStatus(chars_result.Status()));
            continue;
        }
        // Counted only now. Pushing before the gate made the terminal "no
        // usable service; N service(s) seen" line assert a fact about
        // characteristics that were never enumerated: on an unpaired machine
        // every service returns AccessDenied, and the summary would send a
        // maintainer into UUID archaeology when the adjacent WARN lines
        // already say the machine simply needs pairing.
        discovered_service_uuids.push_back(DescribeUuid(service.Uuid()));

        GattCharacteristic best_write{nullptr};
        int best_write_score = -1;
        GattCharacteristic best_notify{nullptr};
        int best_notify_score = -1;
        // Terminal I/O members of this service, if it is a TIO service.
        GattCharacteristic tio_data_rx{nullptr};
        GattCharacteristic tio_data_tx{nullptr};
        GattCharacteristic tio_credits_rx{nullptr};
        GattCharacteristic tio_credits_tx{nullptr};
        GattCharacteristic ublox_data{nullptr};
        GattCharacteristic ublox_credits{nullptr};

        for (auto const& ch : chars_result.Characteristics()) {
            auto props = ch.CharacteristicProperties();

            if (ch.Uuid() == kTerminalIoDataRxUuid) tio_data_rx = ch;
            if (ch.Uuid() == kTerminalIoDataTxUuid) tio_data_tx = ch;
            if (ch.Uuid() == kTerminalIoCreditsRxUuid) tio_credits_rx = ch;
            if (ch.Uuid() == kTerminalIoCreditsTxUuid) tio_credits_tx = ch;
            if (ch.Uuid() == kUbloxDataUuid) ublox_data = ch;
            if (ch.Uuid() == kUbloxCreditsUuid) ublox_credits = ch;

            // Evaluate as write candidate.
            if ((props & GattCharacteristicProperties::Write) !=
                    GattCharacteristicProperties::None ||
                (props &
                 GattCharacteristicProperties::WriteWithoutResponse) !=
                    GattCharacteristicProperties::None) {
                int ws = 0;
                if ((props &
                     GattCharacteristicProperties::WriteWithoutResponse) !=
                    GattCharacteristicProperties::None) {
                    ws += 4;
                }
                if ((props & GattCharacteristicProperties::Write) !=
                    GattCharacteristicProperties::None) {
                    ws += 2;
                }
                if (ch.Uuid() == kPreferredWriteUuid ||
                    ch.Uuid() == kHalcyonSymbiosRxUuid ||
                    ch.Uuid() == kTerminalIoDataRxUuid ||
                    ch.Uuid() == kUbloxDataUuid) {
                    ws += 1000;
                }
                if (ws > best_write_score) {
                    best_write = ch;
                    best_write_score = ws;
                }
            }

            // Evaluate as notify candidate.
            if ((props & GattCharacteristicProperties::Notify) !=
                    GattCharacteristicProperties::None ||
                (props & GattCharacteristicProperties::Indicate) !=
                    GattCharacteristicProperties::None) {
                int ns = 0;
                if ((props & GattCharacteristicProperties::Notify) !=
                    GattCharacteristicProperties::None) {
                    ns += 4;
                }
                if ((props & GattCharacteristicProperties::Indicate) !=
                    GattCharacteristicProperties::None) {
                    ns += 2;
                }
                if (ch.Uuid() == kPreferredNotifyUuid ||
                    ch.Uuid() == kHalcyonSymbiosTxUuid ||
                    ch.Uuid() == kTerminalIoDataTxUuid ||
                    ch.Uuid() == kUbloxDataUuid) {
                    ns += 1000;
                }
                if (ns > best_notify_score) {
                    best_notify = ch;
                    best_notify_score = ns;
                }
            }
        }

        if (!best_write || !best_notify) continue;

        int service_score = best_write_score + best_notify_score;
        if (service.Uuid() == kPreferredServiceUuid ||
            service.Uuid() == kTerminalIoServiceUuid ||
            service.Uuid() == kUbloxServiceUuid) {
            service_score += 1000;
        }

        // Only run the handshake on a complete known layout, so every other
        // device keeps today's plain write/notify behaviour. Telit needs all
        // four UART characteristics; u-blox needs its data and credits pair.
        GattCharacteristic credits_write{nullptr};
        GattCharacteristic credits_notify{nullptr};
        bool credits_required = false;
        if (tio_data_rx && tio_data_tx && tio_credits_rx && tio_credits_tx) {
            credits_write = tio_credits_rx;
            credits_notify = tio_credits_tx;
            credits_required = true;
        } else if (ublox_data && ublox_credits) {
            credits_write = ublox_credits;
            credits_notify = ublox_credits;
        }

        if (service_score > best.score) {
            best = {service_score, best_write, best_notify, credits_write,
                    credits_notify, credits_required};
        }
    }

    if (best.score < 0) {
        if (discovered_service_uuids.empty()) {
            NativeLogger::Error(kBleCategory,
                                "Service discovery succeeded but the computer "
                                "reported no services at all");
        } else {
            std::ostringstream seen;
            for (size_t i = 0; i < discovered_service_uuids.size(); i++) {
                if (i > 0) seen << ", ";
                seen << discovered_service_uuids[i];
            }
            NativeLogger::Error(
                kBleCategory,
                "No discovered service carries both a write and a notify "
                "characteristic; " +
                    std::to_string(discovered_service_uuids.size()) +
                    " service(s) seen: " + seen.str());
        }
        return false;
    }

    NativeLogger::Debug(kBleCategory,
                        "Data service selected: write=" +
                            DescribeUuid(best.write.Uuid()) +
                            " notify=" + DescribeUuid(best.notify.Uuid()));

    write_characteristic_ = best.write;
    notify_characteristic_ = best.notify;
    credits_write_characteristic_ = best.credits_write;
    credits_notify_characteristic_ = best.credits_notify;
    credits_required_ = best.credits_required;

    // Terminal I/O subscribes to UART Credits TX before UART Data TX (Telit
    // TIO Implementation Guide r04 sections 6.4 and 6.2, and the same order in
    // Subsurface's qt-ble.cpp). The payload is not consumed, but the module
    // keeps the UART bridge closed until the subscription exists.
    if (credits_notify_characteristic_) {
        // Telit's UART Credits TX indicates; the u-blox credits characteristic
        // notifies. Pick from the advertised properties rather than assuming.
        auto credits_cccd_value =
            ((credits_notify_characteristic_.CharacteristicProperties() &
              GattCharacteristicProperties::Notify) !=
             GattCharacteristicProperties::None)
                ? GattClientCharacteristicConfigurationDescriptorValue::Notify
                : GattClientCharacteristicConfigurationDescriptorValue::
                      Indicate;

        // .get() throws if the link drops mid-setup. The outer try in
        // ConnectAndDiscover would catch it, but that fails the whole
        // connection -- which is wrong for u-blox, whose fallback exists
        // precisely so an optional handshake cannot break a working device.
        // Treat a throw exactly like a non-Success status instead.
        auto credits_cccd_result = GattCommunicationStatus::Unreachable;
        // Kept separate from the status. Unreachable is only a convenient
        // non-Success value to take the failure branch with, and running it
        // through DescribeGattStatus would report "out of range, switched
        // its radio off, or dropped the link" for what may be an
        // authentication or access error whose HRESULT names the real cause.
        // On a Telit module this is terminal, so it is the last line in the
        // log and has to be true.
        std::string credits_cccd_threw;
        try {
            credits_cccd_result =
                credits_notify_characteristic_
                    .WriteClientCharacteristicConfigurationDescriptorAsync(
                        credits_cccd_value)
                    .get();
        } catch (const winrt::hresult_error& e) {
            credits_cccd_result = GattCommunicationStatus::Unreachable;
            credits_cccd_threw = DescribeHresult(e);
        } catch (...) {
            credits_cccd_result = GattCommunicationStatus::Unreachable;
            credits_cccd_threw = "unknown error";
        }
        if (credits_cccd_result != GattCommunicationStatus::Success) {
            NativeLogger::Warn(kBleCategory,
                               "Terminal I/O credit subscription failed: " +
                                   (credits_cccd_threw.empty()
                                        ? DescribeGattStatus(
                                              credits_cccd_result)
                                        : "threw: " + credits_cccd_threw));
            if (credits_required_) return false;
            // u-blox flow control is optional; fall back to running without it
            // rather than failing a device that works today.
            credits_notify_characteristic_ = nullptr;
            credits_write_characteristic_ = nullptr;
        } else {
            credits_notify_token_ = credits_notify_characteristic_.ValueChanged(
                {this, &BleIoStream::OnCharacteristicValueChanged});
        }
    }

    // Enable notifications.
    auto cccd_value =
        ((notify_characteristic_.CharacteristicProperties() &
          GattCharacteristicProperties::Notify) !=
         GattCharacteristicProperties::None)
            ? GattClientCharacteristicConfigurationDescriptorValue::Notify
            : GattClientCharacteristicConfigurationDescriptorValue::
                  Indicate;

    auto cccd_result =
        notify_characteristic_
            .WriteClientCharacteristicConfigurationDescriptorAsync(
                cccd_value)
            .get();
    if (cccd_result != GattCommunicationStatus::Success) {
        NativeLogger::Error(kBleCategory,
                            "Could not subscribe to notifications on " +
                                DescribeUuid(notify_characteristic_.Uuid()) +
                                ": " + DescribeGattStatus(cccd_result));
        return false;
    }

    // Publish the handle before subscribing, so the first callback already
    // has something to match against.
    notify_attribute_handle_.store(notify_characteristic_.AttributeHandle(),
                                   std::memory_order_release);
    notify_token_ = notify_characteristic_.ValueChanged(
        {this, &BleIoStream::OnCharacteristicValueChanged});

    return GrantInitialCredits();
}

bool BleIoStream::GrantInitialCredits() {
    if (!credits_write_characteristic_) return true;

    bool granted = false;
    try {
        auto writer = DataWriter();
        writer.WriteByte(kTerminalIoInitialGrant);
        auto result =
            credits_write_characteristic_
                .WriteValueWithResultAsync(writer.DetachBuffer(),
                                           GattWriteOption::WriteWithResponse)
                .get();
        granted = result.Status() == GattCommunicationStatus::Success;
    } catch (...) {
        granted = false;
    }

    if (!granted) {
        NativeLogger::Warn(kBleCategory,
                           "Terminal I/O initial credit grant was refused");
        // A Telit bridge carries nothing without credits, so the connection is
        // dead. u-blox flow control is optional and the service already works
        // with no handshake at all, so fall back to that instead.
        if (credits_required_) return false;
        ReleaseCreditCharacteristics();
        return true;
    }

    {
        std::lock_guard<std::mutex> lock(credits_->mutex);
        credits_->credits = kTerminalIoInitialGrant;
        credits_->open = true;
    }
    return true;
}

void BleIoStream::ReleaseCreditCharacteristics() {
    // Unsubscribe rather than merely ignoring the credit indications, so the
    // module stops transmitting on a channel we have given up on and its
    // airtime goes to the data stream instead.
    if (credits_notify_characteristic_) {
        credits_notify_characteristic_.ValueChanged(credits_notify_token_);
        try {
            credits_notify_characteristic_
                .WriteClientCharacteristicConfigurationDescriptorAsync(
                    GattClientCharacteristicConfigurationDescriptorValue::None)
                .get();
        } catch (...) {
        }
        credits_notify_characteristic_ = nullptr;
    }
    std::lock_guard<std::mutex> lock(credits_->mutex);
    credits_write_characteristic_ = nullptr;
    credits_->credits = 0;
    credits_->grant_in_flight = false;
    credits_->open = false;
}

void BleIoStream::ReplenishCredits() {
    auto credits = credits_;
    const uint8_t grant = static_cast<uint8_t>(kTerminalIoInitialGrant -
                                               kTerminalIoRefillThreshold);
    GattCharacteristic characteristic{nullptr};

    {
        std::lock_guard<std::mutex> lock(credits->mutex);
        if (!credits_write_characteristic_) return;
        if (!credits->open) return;
        if (credits->credits > 0) credits->credits--;
        if (credits->grant_in_flight) return;
        if (credits->credits > kTerminalIoRefillThreshold) return;
        credits->grant_in_flight = true;
        characteristic = credits_write_characteristic_;
    }
    // The lock is released before the write is issued: Completed() runs the
    // handler inline when the operation has already finished, and the handler
    // takes this same non-recursive mutex.

    try {
        auto writer = DataWriter();
        writer.WriteByte(grant);
        // Fire-and-forget: this runs on the notification thread, and blocking
        // it on the write result would stall notification delivery during a
        // bulk logbook dump.
        auto operation = characteristic.WriteValueWithResultAsync(
            writer.DetachBuffer(), GattWriteOption::WriteWithResponse);
        // The balance is credited only once the module acknowledges the
        // grant. Counting it now would overstate the balance whenever a write
        // failed, and an overstated balance stalls the transfer for good: the
        // module falls silent, no notifications arrive to decrement it, and no
        // refill is ever issued again.
        //
        // The handler captures the shared balance rather than `this`, so it
        // stays safe if the async operation outlives this stream.
        operation.Completed([credits, grant](auto const& op, auto const&) {
            bool acknowledged = false;
            try {
                acknowledged =
                    op.GetResults().Status() == GattCommunicationStatus::Success;
            } catch (...) {
                acknowledged = false;
            }
            std::lock_guard<std::mutex> lock(credits->mutex);
            credits->grant_in_flight = false;
            if (acknowledged) credits->credits += grant;
        });
    } catch (...) {
        // Nothing was queued, so no completion is coming; leave the balance
        // alone and let the next notification retry. There are
        // kTerminalIoRefillThreshold packets of slack to recover within.
        std::lock_guard<std::mutex> lock(credits->mutex);
        credits->grant_in_flight = false;
    }
}

void BleIoStream::OnCharacteristicValueChanged(
    GattCharacteristic const& sender,
    GattValueChangedEventArgs const& args) {
    // UART Credits TX shares this handler with UART Data TX but carries no
    // application data: injecting its indications into the read queue would
    // corrupt the protocol stream.
    //
    // Compared against a cached handle rather than notify_characteristic_.
    // Revoking the ValueChanged token does not wait for handlers already
    // running, so this can be executing while Close() clears that member on
    // the download thread; reading the WinRT object here would be a data race.
    // Close() zeroes the handle first, and zero rejects everything, so a late
    // callback is dropped rather than mis-routed.
    const uint16_t expected_handle =
        notify_attribute_handle_.load(std::memory_order_acquire);
    if (expected_handle == 0 || sender.AttributeHandle() != expected_handle) {
        return;
    }

    auto reader = DataReader::FromBuffer(args.CharacteristicValue());
    uint32_t length = reader.UnconsumedBufferLength();
    if (length == 0) return;

    std::vector<uint8_t> data(length);
    reader.ReadBytes(data);

    {
        std::lock_guard<std::mutex> lock(read_mutex_);
        read_chunks_.push_back(std::move(data));
    }
    read_cv_.notify_one();

    // Each packet the module sends costs it one credit; top it back up before
    // the balance runs out or the transfer stalls part-way through.
    ReplenishCredits();
}

libdc_io_callbacks_t BleIoStream::MakeCallbacks() {
    libdc_io_callbacks_t cbs = {};
    cbs.userdata = this;
    cbs.set_timeout = SetTimeoutCallback;
    cbs.read = ReadCallback;
    cbs.write = WriteCallback;
    cbs.close = CloseCallback;
    cbs.ioctl = IoctlCallback;
    cbs.poll = PollCallback;
    cbs.purge = PurgeCallback;
    cbs.sleep = nullptr;
    return cbs;
}

void BleIoStream::Close() {
    ReleaseCreditCharacteristics();
    credits_required_ = false;
    // Retire the handle before touching the characteristic, so any handler
    // already running stops accepting data before the object it would
    // otherwise have read is torn down.
    notify_attribute_handle_.store(0, std::memory_order_release);
    if (notify_characteristic_) {
        notify_characteristic_.ValueChanged(notify_token_);
        try {
            notify_characteristic_
                .WriteClientCharacteristicConfigurationDescriptorAsync(
                    GattClientCharacteristicConfigurationDescriptorValue::
                        None)
                .get();
        } catch (...) {
        }
        notify_characteristic_ = nullptr;
    }
    write_characteristic_ = nullptr;
    // Release the throughput-optimized connection request (reverts to the
    // controller's default interval) before tearing down the device.
    preferred_connection_request_ = nullptr;
    if (device_) {
        device_.Close();
        device_ = nullptr;
    }
}

void BleIoStream::SubmitPinCode(const std::string& pin) {
    std::lock_guard<std::mutex> lock(pin_mutex_);
    pending_pin_ = pin;
    pin_ready_ = true;
    pin_cv_.notify_one();
}

void BleIoStream::SetDeviceAddress(const std::string& address) {
    device_address_ = address;
}

void BleIoStream::SetOnPinCodeRequired(
    std::function<void(const std::string&)> callback) {
    on_pin_code_required_ = std::move(callback);
}

static std::wstring AccessCodeKey(const std::string& address) {
    std::wstring key = L"ble_access_code_";
    for (char c : address) key += static_cast<wchar_t>(c);
    return key;
}

std::vector<uint8_t> BleIoStream::LoadAccessCode() {
    try {
        auto settings = winrt::Windows::Storage::ApplicationData::Current()
            .LocalSettings();
        auto key = AccessCodeKey(device_address_);
        auto value = settings.Values().TryLookup(winrt::hstring(key));
        if (!value) return {};
        auto str = winrt::unbox_value<winrt::hstring>(value);
        // Stored as hex string.
        std::vector<uint8_t> result;
        std::string hex(winrt::to_string(str));
        for (size_t i = 0; i + 1 < hex.size(); i += 2) {
            result.push_back(
                static_cast<uint8_t>(std::stoi(hex.substr(i, 2), nullptr, 16)));
        }
        return result;
    } catch (...) {
        return {};
    }
}

void BleIoStream::SaveAccessCode(const uint8_t* data, size_t size) {
    try {
        auto settings = winrt::Windows::Storage::ApplicationData::Current()
            .LocalSettings();
        auto key = AccessCodeKey(device_address_);
        // Store as hex string.
        std::string hex;
        char buf[3];
        for (size_t i = 0; i < size; i++) {
            std::snprintf(buf, sizeof(buf), "%02x", data[i]);
            hex += buf;
        }
        settings.Values().Insert(
            winrt::hstring(key), winrt::box_value(winrt::to_hstring(hex)));
    } catch (...) {
        // Best effort.
    }
}

// -- C callback implementations --

int BleIoStream::SetTimeoutCallback(void* userdata, int timeout) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    stream->timeout_ms_ =
        (timeout < 0) ? INT32_MAX : std::max(timeout, 3000);
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::ReadCallback(void* userdata, void* data, size_t size,
                               size_t* actual) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    size_t transferred = 0;
    int status = stream->PerformRead(data, size, &transferred);
    if (actual) {
        *actual = transferred;
    }
    return status;
}

int BleIoStream::WriteCallback(void* userdata, const void* data,
                                size_t size, size_t* actual) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    size_t transferred = 0;
    int status = stream->PerformWrite(data, size, &transferred);
    if (actual) {
        *actual = transferred;
    }
    return status;
}

int BleIoStream::CloseCallback(void* userdata) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    stream->Close();
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::IoctlCallback(void* userdata, unsigned int request,
                                 void* data, size_t size) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    uint32_t ioctl_type = (request >> 8) & 0xFF;
    uint32_t ioctl_number = request & 0xFF;

    if (ioctl_type == kBleIoctlType && ioctl_number == kBleIoctlGetName) {
        if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;
        if (stream->device_name_.empty()) return LIBDC_STATUS_UNSUPPORTED;

        size_t copy_len =
            std::min(stream->device_name_.size() + 1, size);
        std::memcpy(data, stream->device_name_.c_str(), copy_len);
        static_cast<char*>(data)[copy_len - 1] = '\0';
        return LIBDC_STATUS_SUCCESS;
    }

    if (ioctl_type == kBleIoctlType && ioctl_number == kBleIoctlGetPinCode) {
        if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;

        // Reset state.
        {
            std::lock_guard<std::mutex> lock(stream->pin_mutex_);
            stream->pending_pin_.clear();
            stream->pin_ready_ = false;
        }

        // Dispatch callback (must reach main thread).
        if (stream->on_pin_code_required_) {
            stream->on_pin_code_required_(stream->device_address_);
        }

        // Block until SubmitPinCode is called (60s timeout).
        {
            std::unique_lock<std::mutex> lock(stream->pin_mutex_);
            if (!stream->pin_cv_.wait_for(lock, std::chrono::seconds(60),
                    [stream] { return stream->pin_ready_; })) {
                return LIBDC_STATUS_TIMEOUT;
            }
        }

        if (stream->pending_pin_.empty()) {
            return LIBDC_STATUS_CANCELLED;
        }

        size_t copy_len = std::min(stream->pending_pin_.size() + 1, size);
        std::memcpy(data, stream->pending_pin_.c_str(), copy_len);
        static_cast<char*>(data)[copy_len - 1] = '\0';
        return LIBDC_STATUS_SUCCESS;
    }

    if (ioctl_type == kBleIoctlType && ioctl_number == kBleIoctlAccessCode) {
        if (!data || size == 0) return LIBDC_STATUS_INVALIDARGS;
        uint32_t direction = (request >> 30) & 0x3;

        if (direction == 1) {
            // GET access code.
            auto stored = stream->LoadAccessCode();
            if (stored.empty()) return LIBDC_STATUS_UNSUPPORTED;
            size_t copy_len = std::min(stored.size(), size);
            std::memcpy(data, stored.data(), copy_len);
            return LIBDC_STATUS_SUCCESS;
        }
        if (direction == 2) {
            // SET access code.
            stream->SaveAccessCode(static_cast<const uint8_t*>(data), size);
            return LIBDC_STATUS_SUCCESS;
        }
    }

    return LIBDC_STATUS_UNSUPPORTED;
}

int BleIoStream::PollCallback(void* userdata, int timeout) {
    auto* stream = static_cast<BleIoStream*>(userdata);
    std::unique_lock<std::mutex> lock(stream->read_mutex_);
    if (!stream->read_chunks_.empty()) return LIBDC_STATUS_SUCCESS;
    if (timeout == 0) return LIBDC_STATUS_TIMEOUT;

    if (timeout < 0) {
        stream->read_cv_.wait(
            lock, [stream] { return !stream->read_chunks_.empty(); });
    } else {
        if (!stream->read_cv_.wait_for(
                lock, std::chrono::milliseconds(timeout),
                [stream] { return !stream->read_chunks_.empty(); })) {
            return LIBDC_STATUS_TIMEOUT;
        }
    }
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::PurgeCallback(void* userdata, unsigned int direction) {
    if ((direction & kDirectionInput) == 0) return LIBDC_STATUS_SUCCESS;
    auto* stream = static_cast<BleIoStream*>(userdata);
    std::lock_guard<std::mutex> lock(stream->read_mutex_);
    stream->read_chunks_.clear();
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::PerformRead(void* data, size_t size, size_t* actual) {
    std::unique_lock<std::mutex> lock(read_mutex_);

    auto deadline = (timeout_ms_ == INT32_MAX)
                        ? std::chrono::steady_clock::time_point::max()
                        : std::chrono::steady_clock::now() +
                              std::chrono::milliseconds(timeout_ms_);

    while (read_chunks_.empty()) {
        if (timeout_ms_ == INT32_MAX) {
            read_cv_.wait(
                lock, [this] { return !read_chunks_.empty(); });
        } else {
            if (!read_cv_.wait_until(
                    lock, deadline,
                    [this] { return !read_chunks_.empty(); })) {
                *actual = 0;
                return LIBDC_STATUS_TIMEOUT;
            }
        }
    }

    // Return bytes from at most one notification per read: the packet
    // parsers size each read from the packet header and would silently
    // drop a second packet coalesced into the same read (lost FLAG_LAST
    // ack -> spurious timeout). A partially consumed notification stays
    // at the front of the queue.
    std::vector<uint8_t>& chunk = read_chunks_.front();
    size_t bytes_to_read = std::min(size, chunk.size());
    std::memcpy(data, chunk.data(), bytes_to_read);
    if (bytes_to_read < chunk.size()) {
        chunk.erase(chunk.begin(), chunk.begin() + bytes_to_read);
    } else {
        read_chunks_.pop_front();
    }
    *actual = bytes_to_read;
    return LIBDC_STATUS_SUCCESS;
}

int BleIoStream::PerformWrite(const void* data, size_t size,
                               size_t* actual) {
    if (!write_characteristic_) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }

    try {
        auto writer = DataWriter();
        writer.WriteBytes(winrt::array_view<const uint8_t>(
            static_cast<const uint8_t*>(data), static_cast<uint32_t>(size)));

        auto props = write_characteristic_.CharacteristicProperties();
        bool has_write_with_response =
            (props & GattCharacteristicProperties::Write) !=
            GattCharacteristicProperties::None;

        GattWriteOption write_option =
            has_write_with_response
                ? GattWriteOption::WriteWithResponse
                : GattWriteOption::WriteWithoutResponse;

        auto result =
            write_characteristic_
                .WriteValueWithResultAsync(writer.DetachBuffer(),
                                           write_option)
                .get();
        if (result.Status() != GattCommunicationStatus::Success) {
            *actual = 0;
            return LIBDC_STATUS_IO;
        }

        *actual = size;
        return LIBDC_STATUS_SUCCESS;
    } catch (...) {
        *actual = 0;
        return LIBDC_STATUS_IO;
    }
}

}  // namespace libdivecomputer_plugin
