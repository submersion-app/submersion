import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_mobile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.submersion.app/photo_metadata');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getAssetMetadata maps native metadata result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getAssetMetadata');
          expect(call.arguments, {'assetId': 'asset-1'});
          return {
            'dateTimeOriginal': '2024:04:15 11:49:11',
            'latitude': '14.5',
            'longitude': 120,
            'width': 4032,
            'height': '3024',
            'durationSeconds': 0.9,
            'mimeType': 'image/jpeg',
          };
        });

    final metadata = await PhotoPickerServiceMobile().getAssetMetadata(
      'asset-1',
    );

    expect(metadata, isNotNull);
    expect(metadata!.takenAt, DateTime.utc(2024, 4, 15, 11, 49, 11));
    expect(metadata.latitude, 14.5);
    expect(metadata.longitude, 120);
    expect(metadata.width, 4032);
    expect(metadata.height, 3024);
    expect(metadata.durationSeconds, 1);
    expect(metadata.mimeType, 'image/jpeg');
  });

  test(
    'getAssetMetadata returns null when native handler is unavailable',
    () async {
      final metadata = await PhotoPickerServiceMobile().getAssetMetadata(
        'asset-1',
      );

      expect(metadata, isNull);
    },
  );

  test('getAssetMetadata returns null on platform exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'PERMISSION_DENIED');
        });

    final metadata = await PhotoPickerServiceMobile().getAssetMetadata(
      'asset-1',
    );

    expect(metadata, isNull);
  });
}
