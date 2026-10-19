import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Issue #3520: the native frame grabber behind the channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('submersion_transcoder/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  final times = [Duration.zero, const Duration(milliseconds: 2500)];

  test('sends path, times in ms and size; maps the frames', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'extractFrames');
      final args = call.arguments as Map;
      expect(args['path'], '/v/dive.mov');
      expect(args['timesMs'], [0, 2500]);
      expect(args['maxDimension'], 160);
      return [
        Uint8List.fromList([1, 2]),
        null,
      ];
    });
    final frames = await ChannelTranscodeEngine().extractFrames(
      source: File('/v/dive.mov'),
      times: times,
    );
    expect(frames, [
      Uint8List.fromList([1, 2]),
      null,
    ]);
  });

  test('exact asks for the very frame, not a nearby keyframe', () async {
    Object? sent;
    messenger.setMockMethodCallHandler(methods, (call) async {
      sent = (call.arguments as Map)['exact'];
      return [null, null];
    });
    await ChannelTranscodeEngine().extractFrames(
      source: File('/v/dive.mov'),
      times: times,
      exact: true,
    );
    expect(sent, isTrue);
  });

  test('a missing plugin gives a null per time', () async {
    expect(
      await ChannelTranscodeEngine().extractFrames(
        source: File('/v/dive.mov'),
        times: times,
      ),
      [null, null],
    );
  });

  test('a platform error gives a null per time', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'decode');
    });
    expect(
      await ChannelTranscodeEngine().extractFrames(
        source: File('/v/dive.mov'),
        times: times,
      ),
      [null, null],
    );
  });

  test('a short or malformed reply is padded with nulls', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => ['nope']);
    expect(
      await ChannelTranscodeEngine().extractFrames(
        source: File('/v/dive.mov'),
        times: times,
      ),
      [null, null],
    );
  });
}
