import 'dart:async';
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
    expect(await DarwinAvfEngine().isAvailable(), isTrue);
  });

  test('isAvailable is false when the plugin is missing', () async {
    // No handler registered -> MissingPluginException.
    expect(await DarwinAvfEngine().isAvailable(), isFalse);
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
    final probe = (await DarwinAvfEngine().probe(File('/x.mov')))!;
    expect(probe.height, 1080);
    expect(probe.overallBitrateKbps, 9000);
  });

  test('probe returns null when the channel returns null', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => null);
    expect(await DarwinAvfEngine().probe(File('/x.mov')), isNull);
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
    await DarwinAvfEngine().transcode(
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

  test('progressIds are unique across engine instances', () async {
    final ids = <String>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'transcode') {
        ids.add((call.arguments as Map)['progressId'] as String);
      }
      return null;
    });
    const target = TranscodeTarget(
      maxHeight: 720,
      videoBitrateKbps: 4000,
      audioBitrateKbps: 128,
    );
    // Two separate engine instances: an instance-local counter would emit 'p0'
    // for both and collide on the shared progress channel.
    await DarwinAvfEngine().transcode(
      source: File('/a.mov'),
      output: File('/a.mp4'),
      target: target,
    );
    await DarwinAvfEngine().transcode(
      source: File('/b.mov'),
      output: File('/b.mp4'),
      target: target,
    );
    expect(ids.length, 2);
    expect(ids[0], isNot(ids[1]));
  });

  test('progress routes by progressId, clamps, and stops after done', () async {
    const progressChannel = MethodChannel('submersion_transcoder/progress');
    // Swallow the EventChannel listen/cancel calls.
    messenger.setMockMethodCallHandler(progressChannel, (_) async => null);
    addTearDown(
      () => messenger.setMockMethodCallHandler(progressChannel, null),
    );

    Future<void> emit(Map<String, dynamic> data) async {
      await messenger.handlePlatformMessage(
        progressChannel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(data),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero); // let the broadcast deliver
    }

    final reported = <double>[];
    final methodDone = Completer<void>();
    String? progressId;
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'transcode') {
        progressId = (call.arguments as Map)['progressId'] as String;
        await methodDone.future; // keep transcode pending while we emit
      }
      return null;
    });

    final future = DarwinAvfEngine().transcode(
      source: File('/in.mov'),
      output: File('/out.mp4'),
      target: const TranscodeTarget(
        maxHeight: 720,
        videoBitrateKbps: 4000,
        audioBitrateKbps: 128,
      ),
      onProgress: reported.add,
    );
    while (progressId == null) {
      await Future<void>.delayed(Duration.zero);
    }

    await emit({'progressId': 'someone-else', 'fraction': 0.5}); // wrong id
    await emit({'progressId': progressId, 'fraction': 0.5}); // -> 0.5
    await emit({'progressId': progressId, 'fraction': 1.5}); // clamp -> 1.0
    await emit({'progressId': progressId, 'fraction': -0.3}); // clamp -> 0.0
    expect(reported, [0.5, 1.0, 0.0]);

    methodDone.complete();
    await future; // transcode completes -> subscription cancelled in finally

    await emit({'progressId': progressId, 'fraction': 0.8}); // after cancel
    expect(reported, [0.5, 1.0, 0.0], reason: 'no callbacks after completion');
  });

  test('a PlatformException becomes a TranscodeException', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'transcode_failed', message: 'boom');
    });
    await expectLater(
      DarwinAvfEngine().transcode(
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

  test('a null-message PlatformException falls back to details', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(
        code: 'transcode_failed',
        message: null,
        details: 'writer failed: disk full',
      );
    });
    try {
      await DarwinAvfEngine().transcode(
        source: File('/in.mov'),
        output: File('/out.mp4'),
        target: const TranscodeTarget(
          maxHeight: 720,
          videoBitrateKbps: 4000,
          audioBitrateKbps: 128,
        ),
      );
      fail('expected a TranscodeException');
    } on TranscodeException catch (e) {
      expect(e.message, contains('writer failed: disk full'));
      expect(e.message, isNot(contains('null')));
    }
  });

  test('progress listen is shared across engine instances', () async {
    const progressChannel = MethodChannel('submersion_transcoder/progress');
    var listens = 0;
    messenger.setMockMethodCallHandler(progressChannel, (call) async {
      if (call.method == 'listen') listens++;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(progressChannel, null),
    );

    // Keep both transcodes pending so their progress subscriptions overlap.
    final gate = Completer<void>();
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'transcode') await gate.future;
      return null;
    });

    const target = TranscodeTarget(
      maxHeight: 720,
      videoBitrateKbps: 4000,
      audioBitrateKbps: 128,
    );
    final a = DarwinAvfEngine().transcode(
      source: File('/a.mov'),
      output: File('/a.mp4'),
      target: target,
      onProgress: (_) {},
    );
    final b = DarwinAvfEngine().transcode(
      source: File('/b.mov'),
      output: File('/b.mp4'),
      target: target,
      onProgress: (_) {},
    );

    // Let both subscriptions propagate to the platform side.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    // Two separate engine instances on the default channel share one broadcast
    // stream, so the native side sees exactly one onListen. A per-instance
    // stream would trigger a second onListen and overwrite the Swift plugin's
    // single progressSink, starving the first transcode's progress.
    expect(listens, 1);

    gate.complete();
    await Future.wait([a, b]);
  });
}
