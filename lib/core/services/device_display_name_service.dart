import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the host platform knows about this device's identity. Every field is
/// nullable: platforms answer with whatever they have, and the composition in
/// [DeviceDisplayNameService.resolve] degrades through them.
@immutable
class NativeDeviceIdentity {
  const NativeDeviceIdentity({this.name, this.manufacturer, this.model});

  /// The name the OWNER gave this device (Android's Settings > About phone >
  /// Device name, iOS's device name). Null when the platform has none.
  final String? name;

  /// Vendor, as the platform reports it. Android returns it lower-cased
  /// ('samsung', 'google'), which is why [DeviceDisplayNameService] title-cases
  /// it before showing it to anyone.
  final String? manufacturer;

  /// Marketing or hardware model ('Pixel 8 Pro', 'SM-S921B', 'iPhone').
  final String? model;

  static NativeDeviceIdentity fromChannel(Map<Object?, Object?> map) =>
      NativeDeviceIdentity(
        name: map['name'] as String?,
        manufacturer: map['manufacturer'] as String?,
        model: map['model'] as String?,
      );
}

/// Asks the host platform who it is. Returns null when this platform has no
/// native handler, which is the desktop case: there, the hostname IS the
/// device name a user recognises.
typedef NativeDeviceIdentityReader = Future<NativeDeviceIdentity?> Function();

/// The name this device is known by across the fleet: sync manifests, library
/// epoch markers, and library-moved markers all stamp it, and peers render it
/// in banners and on the "Devices on this backend" page.
///
/// Desktop hostnames are already the name a user recognises, but mobile
/// hostnames are not: Android reports 'localhost' for every device on earth
/// (issue #1194), which is worse than no name at all, so it was discarded and
/// the UI fell back to a hex device id. Mobile therefore asks the platform
/// directly, through a native handler, and only falls back to the hostname.
class DeviceDisplayNameService {
  const DeviceDisplayNameService({
    NativeDeviceIdentityReader? readNativeIdentity,
    String Function()? readHostname,
  }) : _readNativeIdentity = readNativeIdentity,
       _readHostname = readHostname;

  static const _channel = MethodChannel('app.submersion/device_name');

  /// Names that identify nothing. Android reports 'localhost' as its hostname
  /// and 'unknown' as the model on some emulators and ROMs; every peer
  /// displaying the same name is worse than falling back to the device id,
  /// which is at least unique.
  static const _uselessNames = {'localhost', 'unknown', 'android'};

  final NativeDeviceIdentityReader? _readNativeIdentity;
  final String Function()? _readHostname;

  /// Normalises a raw name, returning null when it identifies nothing.
  static String? sanitizeDeviceName(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (_uselessNames.contains(trimmed.toLowerCase())) return null;
    return trimmed;
  }

  /// This device's display name, or null when nothing on this platform
  /// identifies it. Callers fall back to a short device id.
  ///
  /// Never throws: a device without a name still has to sync.
  Future<String?> resolve() async {
    final native = await _resolveNative();
    if (native != null) return native;
    try {
      return sanitizeDeviceName((_readHostname ?? _hostname)());
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveNative() async {
    NativeDeviceIdentity? identity;
    try {
      identity = await (_readNativeIdentity ?? _readFromChannel)();
    } catch (_) {
      // A missing handler (desktop, or a platform build without one) is the
      // expected case, not an error.
      identity = null;
    }
    if (identity == null) return null;
    return sanitizeDeviceName(identity.name) ?? _composeModelName(identity);
  }

  /// "samsung" + "SM-S921B" -> "Samsung SM-S921B", and "Google" + "Pixel 8 Pro"
  /// -> "Google Pixel 8 Pro", but "Xiaomi" + "Xiaomi 14" -> "Xiaomi 14": a
  /// model that already carries its vendor must not be prefixed with it again.
  static String? _composeModelName(NativeDeviceIdentity identity) {
    final model = sanitizeDeviceName(identity.model);
    final manufacturer = sanitizeDeviceName(identity.manufacturer);
    if (model == null) {
      return manufacturer == null ? null : _titleCase(manufacturer);
    }
    if (manufacturer == null) return model;
    if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
      return model;
    }
    return '${_titleCase(manufacturer)} $model';
  }

  /// Vendors report themselves lower-cased ('samsung'); a name shown next to
  /// "Erics-MacBook-Pro" should not be the odd one out.
  static String _titleCase(String value) => value
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  static Future<NativeDeviceIdentity?> _readFromChannel() async {
    // Only the platforms that ship a handler are asked; everywhere else the
    // hostname is already the right answer and a channel call would just be a
    // MissingPluginException to swallow.
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'getDeviceIdentity',
    );
    return map == null ? null : NativeDeviceIdentity.fromChannel(map);
  }

  static String _hostname() => Platform.localHostname;
}
