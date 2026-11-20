import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/frame_reader.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('submersion_vision/frames');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const reader = ChannelFrameReader();

  test('opens a video, passing a content URI through unchanged', () async {
    answer(
      (_) => {'handle': 7, 'width': 1080, 'height': 1920, 'durationMs': 30000},
    );

    final video = await reader.open('content://media/external/video/12');

    expect(calls.single.method, 'open');
    expect(calls.single.arguments, {
      'path': 'content://media/external/video/12',
    });
    expect(video.handle, 7);
    expect((video.width, video.height, video.durationMs), (1080, 1920, 30000));
  });

  test('reads the next frame at or after a time', () async {
    answer(
      (_) => {
        'ms': 266,
        'width': 2,
        'height': 1,
        'rgba': Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 255]),
      },
    );

    final frame = await reader.next(7, atOrAfterMs: 250, maxSide: 960);

    expect(calls.single.method, 'next');
    expect(calls.single.arguments, {
      'handle': 7,
      'atOrAfterMs': 250,
      'maxSide': 960,
    });
    expect(frame!.ms, 266);
    expect((frame.image.width, frame.image.height), (2, 1));
    expect(frame.image.bytes, [1, 2, 3, 255, 4, 5, 6, 255]);
  });

  test('the end of the video is no frame', () async {
    answer((_) => null);
    expect(await reader.next(7, atOrAfterMs: 0, maxSide: 960), isNull);
  });

  test('reads one exact frame', () async {
    answer(
      (_) => {
        'width': 1,
        'height': 1,
        'rgba': Uint8List.fromList([9, 9, 9, 255]),
      },
    );

    final image = await reader.frameAt(7, 1500, maxSide: 4096);

    expect(calls.single.method, 'frameAt');
    expect(calls.single.arguments, {'handle': 7, 'ms': 1500, 'maxSide': 4096});
    expect(image!.bytes, [9, 9, 9, 255]);
  });

  test('closes a video', () async {
    answer((_) => null);
    await reader.close(7);
    expect(calls.single.method, 'close');
    expect(calls.single.arguments, {'handle': 7});
  });

  test('reads the device state', () async {
    answer(
      (_) => {
        'thermalSevere': true,
        'lowMemory': false,
        'availableBytes': 2147483648,
      },
    );

    final state = await reader.deviceState();

    expect(calls.single.method, 'deviceState');
    expect(state.thermalSevere, isTrue);
    expect(state.lowMemory, isFalse);
    expect(state.availableBytes, 2147483648);
  });

  test(
    'a frame whose pixels do not fill its size is a decode failure',
    () async {
      final decodeFailed = throwsA(
        isA<VisionEngineException>().having(
          (e) => e.code,
          'code',
          'decode_failed',
        ),
      );
      answer(
        (call) => {'ms': 0, 'width': 2, 'height': 1, 'rgba': Uint8List(4)},
      );
      await expectLater(
        reader.next(1, atOrAfterMs: 0, maxSide: 960),
        decodeFailed,
      );
      answer((call) => {'width': 2, 'height': 1});
      await expectLater(reader.frameAt(1, 0, maxSide: 4096), decodeFailed);
    },
  );

  test('a platform failure becomes an engine failure with its code', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'decode_failed', message: 'no video track');
    });

    await expectLater(
      reader.open('/videos/a.mp4'),
      throwsA(
        isA<VisionEngineException>()
            .having((e) => e.code, 'code', 'decode_failed')
            .having((e) => e.message, 'message', 'no video track'),
      ),
    );
  });

  test('no frame reader on this platform is unsupported', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      reader.open('/videos/a.mp4'),
      throwsA(
        isA<VisionEngineException>().having(
          (e) => e.code,
          'code',
          'unsupported',
        ),
      ),
    );
  });
}
