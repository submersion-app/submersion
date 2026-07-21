import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('submersion_transcoder/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
  });

  test('isAvailable returns the channel result', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'isAvailable');
      return true;
    });
    expect(await ChannelTranscodeEngine().isAvailable(), isTrue);
  });

  test('isAvailable is false when the plugin is missing', () async {
    // No handler registered -> MissingPluginException.
    expect(await ChannelTranscodeEngine().isAvailable(), isFalse);
  });

  test('probe decodes the channel map', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'probe');
      expect((call.arguments as Map)['path'], '/x.mov');
      return {
        'width': 1920,
        'height': 1080,
        'durationMs': 5000,
        'overallBitrateKbps': 9000,
      };
    });
    final probe = (await ChannelTranscodeEngine().probe(File('/x.mov')))!;
    expect(probe.height, 1080);
    expect(probe.overallBitrateKbps, 9000);
  });

  test('probe returns null when the channel returns null', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => null);
    expect(await ChannelTranscodeEngine().probe(File('/x.mov')), isNull);
  });

  test('transcode forwards target args and completes on success', () async {
    Map<Object?, Object?>? seen;
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'transcode') {
        seen = call.arguments as Map<Object?, Object?>;
        return null;
      }
      return null;
    });
    await ChannelTranscodeEngine().transcode(
      source: File('/in.mov'),
      output: File('/out.mp4'),
      target: const TranscodeTarget(
        maxHeight: 720,
        videoBitrateKbps: 4000,
        audioBitrateKbps: 128,
      ),
    );
    expect(seen!['maxHeight'], 720);
    expect(seen!['videoBitrateKbps'], 4000);
    expect(seen!['output'], '/out.mp4');
    expect(seen!['progressId'], isA<String>());
  });

  test('a PlatformException becomes a TranscodeException', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'transcode_failed', message: 'boom');
    });
    await expectLater(
      ChannelTranscodeEngine().transcode(
        source: File('/in.mov'),
        output: File('/out.mp4'),
        target: const TranscodeTarget(
          maxHeight: 720,
          videoBitrateKbps: 4000,
          audioBitrateKbps: 128,
        ),
      ),
      throwsA(isA<TranscodeException>()),
    );
  });
}
