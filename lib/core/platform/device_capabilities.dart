/// What this device can do. See [DeviceCapabilities].
library;

import 'package:submersion/core/platform/device_capabilities_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/device_capabilities_web.dart'
    as platform;
import 'package:submersion/core/platform/device_capabilities_model.dart';
import 'package:submersion/core/providers/provider.dart';

export 'package:submersion/core/platform/device_capabilities_model.dart';

/// The running device's capabilities: the operating system's on a native
/// build, the browser table on the web.
DeviceCapabilities currentDeviceCapabilities() =>
    platform.currentDeviceCapabilities();

/// The capabilities every screen consults before it offers a feature.
/// Tests override it with [DeviceCapabilities.web] or a native value.
final deviceCapabilitiesProvider = Provider<DeviceCapabilities>(
  (ref) => currentDeviceCapabilities(),
);
