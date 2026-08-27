import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ICloudNativeService.queryNativeAvailability', () {
    const channel = MethodChannel('app.submersion/icloud_container');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('invokes getICloudAvailability and maps the native status', () async {
      String? requested;
      messenger.setMockMethodCallHandler(channel, (call) async {
        requested = call.method;
        return 'signedOut';
      });

      final result = await ICloudNativeService.queryNativeAvailability();

      expect(requested, 'getICloudAvailability');
      expect(result, ICloudAvailability.signedOut);
    });

    test('returns unknown when the channel throws', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'BOOM'),
      );

      expect(
        await ICloudNativeService.queryNativeAvailability(),
        ICloudAvailability.unknown,
      );
    });

    test(
      'getAvailability resolves to a value on the current platform',
      () async {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => 'available',
        );
        // Non-Apple hosts return unsupported via the platform guard; Apple hosts
        // delegate to the channel. Either path resolves without throwing.
        expect(
          await ICloudNativeService.getAvailability(),
          isA<ICloudAvailability>(),
        );
      },
    );
  });

  group('ICloudNativeService.availabilityFromStatus', () {
    test('maps "available"', () {
      expect(
        ICloudNativeService.availabilityFromStatus('available'),
        ICloudAvailability.available,
      );
    });

    test('maps "signedOut"', () {
      expect(
        ICloudNativeService.availabilityFromStatus('signedOut'),
        ICloudAvailability.signedOut,
      );
    });

    test('maps "unsupported"', () {
      expect(
        ICloudNativeService.availabilityFromStatus('unsupported'),
        ICloudAvailability.unsupported,
      );
    });

    test('maps an unrecognized string to unknown', () {
      expect(
        ICloudNativeService.availabilityFromStatus('wat'),
        ICloudAvailability.unknown,
      );
    });

    test('maps null to unknown', () {
      expect(
        ICloudNativeService.availabilityFromStatus(null),
        ICloudAvailability.unknown,
      );
    });
  });
}
