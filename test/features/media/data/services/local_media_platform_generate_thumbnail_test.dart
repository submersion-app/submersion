import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.submersion.app/local_media');
  final platform = LocalMediaPlatform();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns bytes from the channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'generateVideoThumbnail');
          expect(call.arguments['maxDimension'], 512);
          return Uint8List.fromList([1, 2, 3]);
        });

    final bytes = await platform.generateVideoThumbnail(
      path: '/tmp/v.mp4',
      maxDimension: 512,
    );
    expect(bytes, isNotNull);
    expect(bytes!.toList(), [1, 2, 3]);
  });

  test('returns null when the channel has no implementation', () async {
    // No mock handler installed -> MissingPluginException.
    final bytes = await platform.generateVideoThumbnail(
      path: '/tmp/v.mp4',
      maxDimension: 512,
    );
    expect(bytes, isNull);
  });

  test('returns null when the channel throws a PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'ERR');
        });
    final bytes = await platform.generateVideoThumbnail(
      path: '/tmp/v.mp4',
      maxDimension: 512,
    );
    expect(bytes, isNull);
  });
}
