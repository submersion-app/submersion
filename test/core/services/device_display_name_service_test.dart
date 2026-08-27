import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/device_display_name_service.dart';

/// Builds a service whose platform answers are fixed, so the composition and
/// fallback order can be exercised without a device.
DeviceDisplayNameService _service({
  NativeDeviceIdentity? native,
  Object? nativeThrows,
  String hostname = 'localhost',
}) => DeviceDisplayNameService(
  readNativeIdentity: () async {
    if (nativeThrows != null) throw nativeThrows;
    return native;
  },
  readHostname: () => hostname,
);

/// The shape the Android and iOS handlers put on the channel.
abstract final class _ChannelFixture {
  static const Map<Object?, Object?> full = {
    'name': "Eric's Pixel",
    'manufacturer': 'Google',
    'model': 'Pixel 8 Pro',
  };
}

void main() {
  group('sanitizeDeviceName', () {
    test('keeps a real hostname', () {
      expect(
        DeviceDisplayNameService.sanitizeDeviceName('Erics-MacBook-Pro'),
        'Erics-MacBook-Pro',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        DeviceDisplayNameService.sanitizeDeviceName('  Erics-iPhone  '),
        'Erics-iPhone',
      );
    });

    test('treats null, empty and whitespace as absent', () {
      expect(DeviceDisplayNameService.sanitizeDeviceName(null), isNull);
      expect(DeviceDisplayNameService.sanitizeDeviceName(''), isNull);
      expect(DeviceDisplayNameService.sanitizeDeviceName('   '), isNull);
    });

    test('treats localhost as absent regardless of case', () {
      // Android commonly reports 'localhost'; every device claiming the same
      // name is worse than falling back to the device id.
      expect(DeviceDisplayNameService.sanitizeDeviceName('localhost'), isNull);
      expect(DeviceDisplayNameService.sanitizeDeviceName('LocalHost'), isNull);
      expect(
        DeviceDisplayNameService.sanitizeDeviceName(' localhost '),
        isNull,
      );
    });

    test('treats placeholder model strings as absent', () {
      expect(DeviceDisplayNameService.sanitizeDeviceName('unknown'), isNull);
      expect(DeviceDisplayNameService.sanitizeDeviceName('Android'), isNull);
    });
  });

  group('NativeDeviceIdentity.fromChannel', () {
    test('reads the three fields the native handlers report', () {
      const identity = _ChannelFixture.full;
      final parsed = NativeDeviceIdentity.fromChannel(identity);
      expect(parsed.name, "Eric's Pixel");
      expect(parsed.manufacturer, 'Google');
      expect(parsed.model, 'Pixel 8 Pro');
    });

    test('tolerates a handler that reports nothing', () {
      // A future platform, or a handler that could not read a field: every
      // field is nullable by contract.
      final parsed = NativeDeviceIdentity.fromChannel(const {});
      expect(parsed.name, isNull);
      expect(parsed.manufacturer, isNull);
      expect(parsed.model, isNull);
    });
  });

  group('resolve', () {
    test('prefers the name the owner gave the device', () async {
      final name = await _service(
        native: const NativeDeviceIdentity(
          name: "Eric's Pixel",
          manufacturer: 'Google',
          model: 'Pixel 8 Pro',
        ),
      ).resolve();
      expect(name, "Eric's Pixel");
    });

    test('falls back to the model when no owner name is set', () async {
      final name = await _service(
        native: const NativeDeviceIdentity(
          manufacturer: 'samsung',
          model: 'SM-S921B',
        ),
      ).resolve();
      // Vendors report themselves lower-cased; title-case it.
      expect(name, 'Samsung SM-S921B');
    });

    test('names a vendor whose model does not carry it', () async {
      final name = await _service(
        native: const NativeDeviceIdentity(
          manufacturer: 'Google',
          model: 'Pixel 8 Pro',
        ),
      ).resolve();
      expect(name, 'Google Pixel 8 Pro');
    });

    test('does not repeat a vendor the model already carries', () async {
      final name = await _service(
        native: const NativeDeviceIdentity(
          manufacturer: 'Xiaomi',
          model: 'Xiaomi 14',
        ),
      ).resolve();
      expect(name, 'Xiaomi 14');
    });

    test(
      'ignores a useless owner name and composes the model instead',
      () async {
        final name = await _service(
          native: const NativeDeviceIdentity(
            name: 'unknown',
            manufacturer: 'motorola',
            model: 'edge 50',
          ),
        ).resolve();
        expect(name, 'Motorola edge 50');
      },
    );

    test('names the vendor alone when the model says nothing', () async {
      // A ROM that reports 'unknown' as its model still knows who built it.
      final name = await _service(
        native: const NativeDeviceIdentity(
          manufacturer: 'oneplus',
          model: 'unknown',
        ),
      ).resolve();
      // Title-casing only lifts the first letter of each word, so a vendor
      // whose own spelling is camel-cased comes back as 'Oneplus'. That is a
      // fallback for a device that told us nothing better; do not build a
      // vendor spelling table for it.
      expect(name, 'Oneplus');
    });

    test('uses the hostname when the platform has no native handler', () async {
      // The desktop path: no handler, and the hostname IS the device name.
      final name = await _service(
        native: null,
        hostname: 'Erics-MacBook-Pro',
      ).resolve();
      expect(name, 'Erics-MacBook-Pro');
    });

    test('uses the hostname when the native call fails', () async {
      final name = await _service(
        nativeThrows: Exception('MissingPluginException'),
        hostname: 'ERIC-PC',
      ).resolve();
      expect(name, 'ERIC-PC');
    });

    test('is null when neither source identifies the device', () async {
      // Pre-fix Android: hostname 'localhost', nothing native. Callers fall
      // back to the short device id, which is at least unique.
      expect(await _service(native: null).resolve(), isNull);
    });

    test(
      'is null rather than throwing when the hostname lookup fails',
      () async {
        final service = DeviceDisplayNameService(
          readNativeIdentity: () async => null,
          readHostname: () => throw Exception('no hostname'),
        );
        expect(await service.resolve(), isNull);
      },
    );
  });
}
