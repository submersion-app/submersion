import Flutter
import UIKit

/// Tells Dart what this device is called, so peers can be named on the
/// "Devices on this backend" page instead of shown as a hex id (issue #1194).
///
/// Methods (channel: app.submersion/device_name):
///   - getDeviceIdentity() -> Dictionary
///       name         UIDevice.name
///       manufacturer "Apple"
///       model        UIDevice.model ("iPhone", "iPad")
///
/// Note iOS 16 stopped handing out the owner's chosen device name to apps
/// without a special entitlement: `UIDevice.name` returns the model there
/// ("iPhone"), so two same-model devices report the same name. The devices
/// page disambiguates duplicates with the short device id; a model name plus
/// an id still reads better than an id alone.
///
/// Composition and fallback live Dart-side in DeviceDisplayNameService, where
/// they are unit-testable; this handler only reports raw facts.
class DeviceNameHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "app.submersion/device_name",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDeviceIdentity":
            let device = UIDevice.current
            result([
                "name": device.name,
                "manufacturer": "Apple",
                "model": device.model,
            ])
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
