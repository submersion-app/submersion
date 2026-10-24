import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:path/path.dart' as p;

import 'color_timeline_test.dart' show gains20, identity20;
import 'mp4_recording_info_test.dart'
    show box, identityMatrix, movie, mvhd, rotate90Matrix, trak, xyz;

/// Issue #3521: the colour-corrected encode over the transcoder channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('submersion_transcoder/methods');
  const progressChannel = MethodChannel('submersion_transcoder/progress');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final timeline = ColorTimeline([
    ColorTimelineKey(timeMs: 1000, matrix: gains20(1.2, 1, 0.8)),
    ColorTimelineKey(timeMs: 0, matrix: identity20),
  ]);

  setUp(() {
    // Swallow the EventChannel listen/cancel calls.
    messenger.setMockMethodCallHandler(progressChannel, (_) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(progressChannel, null);
  });

  Future<void> emit(Map<String, dynamic> data) async {
    await messenger.handlePlatformMessage(
      progressChannel.name,
      const StandardMethodCodec().encodeSuccessEnvelope(data),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> encode({
    ColorEncodeCancel? cancel,
    void Function(double)? onProgress,
  }) => ChannelTranscodeEngine().encodeWithColor(
    source: File('/in.mov'),
    output: File('/out.mp4'),
    timeline: timeline,
    cancel: cancel,
    onProgress: onProgress,
  );

  test(
    'encodeWithColor sends source, output, timeline and a progressId',
    () async {
      Map<Object?, Object?>? args;
      messenger.setMockMethodCallHandler(methods, (call) async {
        expect(call.method, 'encodeWithColor');
        args = call.arguments as Map<Object?, Object?>;
        return null;
      });
      await encode();
      expect(args!['source'], '/in.mov');
      expect(args!['output'], '/out.mp4');
      expect(args!['timeline'], timeline.toChannel());
      expect(args!['progressId'], isA<String>());
    },
  );

  test(
    'progress events with its progressId reach onProgress, clamped',
    () async {
      final reported = <double>[];
      final done = Completer<void>();
      String? progressId;
      messenger.setMockMethodCallHandler(methods, (call) async {
        progressId = (call.arguments as Map)['progressId'] as String;
        await done.future;
        return null;
      });
      final future = encode(onProgress: reported.add);
      while (progressId == null) {
        await Future<void>.delayed(Duration.zero);
      }
      await emit({'progressId': 'other', 'fraction': 0.3});
      await emit({'progressId': progressId, 'fraction': 0.4});
      await emit({'progressId': progressId, 'fraction': 1.7});
      expect(reported, [0.4, 1.0]);
      done.complete();
      await future;
    },
  );

  test('progress is polled from an engine that keeps it (Windows)', () async {
    final reported = <double>[];
    final done = Completer<void>();
    final polled = <double>[0.25, 0.25, 0.6];
    messenger.setMockMethodCallHandler(methods, (call) async {
      switch (call.method) {
        case 'encodeWithColor':
          await done.future;
          return null;
        case 'colorEncodeProgress':
          expect((call.arguments as Map)['progressId'], isA<String>());
          if (polled.isEmpty) {
            if (!done.isCompleted) done.complete();
            return 0.6;
          }
          return polled.removeAt(0);
      }
      return null;
    });
    await ChannelTranscodeEngine(
      progressPollInterval: const Duration(milliseconds: 5),
    ).encodeWithColor(
      source: File('/in.mov'),
      output: File('/out.mp4'),
      timeline: timeline,
      onProgress: reported.add,
    );
    // Finished between polls: the end is reported once the encode returns.
    expect(reported, [0.25, 0.6, 1.0]);
  });

  test('an engine without polled progress is asked only once', () async {
    var polls = 0;
    final done = Completer<void>();
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'colorEncodeProgress') {
        polls++;
        throw MissingPluginException();
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      done.complete();
      return null;
    });
    await ChannelTranscodeEngine(
      progressPollInterval: const Duration(milliseconds: 5),
    ).encodeWithColor(
      source: File('/in.mov'),
      output: File('/out.mp4'),
      timeline: timeline,
      onProgress: (_) {},
    );
    expect(polls, 1);
  });

  test('cancel sends cancelEncode with the same progressId', () async {
    final done = Completer<void>();
    String? encodeId;
    String? cancelId;
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'encodeWithColor') {
        encodeId = (call.arguments as Map)['progressId'] as String;
        await done.future;
        throw PlatformException(code: 'cancelled');
      }
      if (call.method == 'cancelEncode') {
        cancelId = (call.arguments as Map)['progressId'] as String;
        done.complete();
      }
      return null;
    });
    final cancel = ColorEncodeCancel();
    final future = encode(cancel: cancel);
    while (encodeId == null) {
      await Future<void>.delayed(Duration.zero);
    }
    cancel.cancel();
    await expectLater(future, throwsA(isA<TranscodeCancelledException>()));
    expect(cancelId, encodeId);
    expect(cancel.isCancelled, isTrue);
  });

  test('a cancel during the source read never starts the encode', () async {
    var called = false;
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'encodeWithColor') called = true;
      return null;
    });
    final cancel = ColorEncodeCancel();
    // The source does not exist, so the read fails fast; the cancel lands
    // while it is in flight, before the encode is asked for.
    final future = ChannelTranscodeEngine().encodeWithColor(
      source: File('/in.mov'),
      output: File('/out.mp4'),
      timeline: timeline,
      cancel: cancel,
    );
    cancel.cancel();
    await expectLater(future, throwsA(isA<TranscodeCancelledException>()));
    expect(called, isFalse);
  });

  test('a cancel requested before the call never starts the encode', () async {
    var called = false;
    messenger.setMockMethodCallHandler(methods, (call) async {
      called = true;
      return null;
    });
    final cancel = ColorEncodeCancel()..cancel();
    await expectLater(
      encode(cancel: cancel),
      throwsA(isA<TranscodeCancelledException>()),
    );
    expect(called, isFalse);
  });

  test('error code cancelled throws TranscodeCancelledException', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (_) async => throw PlatformException(code: 'cancelled'),
    );
    await expectLater(encode(), throwsA(isA<TranscodeCancelledException>()));
  });

  test('error code unsupported throws TranscodeUnsupportedException', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (_) async =>
          throw PlatformException(code: 'unsupported', message: '8K H.264'),
    );
    await expectLater(
      encode(),
      throwsA(
        isA<TranscodeUnsupportedException>().having(
          (e) => e.message,
          'message',
          contains('8K H.264'),
        ),
      ),
    );
  });

  test('other PlatformException throws TranscodeException', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (_) async => throw PlatformException(code: 'transcode_failed'),
    );
    await expectLater(
      encode(),
      throwsA(
        isA<TranscodeException>().having(
          (e) => e,
          'not unsupported',
          isNot(isA<TranscodeUnsupportedException>()),
        ),
      ),
    );
  });

  test('missing plugin throws TranscodeException', () async {
    await expectLater(encode(), throwsA(isA<TranscodeException>()));
  });

  group('recording date and place', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('enc_meta'));
    tearDown(() => dir.delete(recursive: true));

    test(
      'the source location is sent and its date stamped on the copy',
      () async {
        final recorded = DateTime.utc(2026, 5, 1, 10);
        final source = File(p.join(dir.path, 'in.mp4'))
          ..writeAsBytesSync(
            movie([mvhd(recorded), box('udta', xyz('+20.5000-087.0000/'))]),
          );
        final output = File(p.join(dir.path, 'out.mp4'));
        Object? location;
        messenger.setMockMethodCallHandler(methods, (call) async {
          location = (call.arguments as Map)['location'];
          // The native encoder stamps the copy with the moment it was made.
          output.writeAsBytesSync(movie([mvhd(DateTime.utc(2030))]));
          return null;
        });
        await ChannelTranscodeEngine().encodeWithColor(
          source: source,
          output: output,
          timeline: timeline,
        );
        expect(location, '+20.5000-087.0000/');
        expect((await readMp4RecordingInfo(output)).created, recorded);
      },
    );

    test('a copy written without a location gets the source one', () async {
      final source = File(p.join(dir.path, 'in.mp4'))
        ..writeAsBytesSync(
          movie([
            mvhd(DateTime.utc(2026)),
            box('udta', xyz('+1.0000+002.0000/')),
          ]),
        );
      final output = File(p.join(dir.path, 'out.mp4'));
      messenger.setMockMethodCallHandler(methods, (call) async {
        // An encoder that writes no location (Media Foundation).
        output.writeAsBytesSync(
          movie([mvhd(DateTime.utc(2030))], moovLast: true),
        );
        return null;
      });
      await ChannelTranscodeEngine().encodeWithColor(
        source: source,
        output: output,
        timeline: timeline,
      );
      expect(
        (await readMp4RecordingInfo(output)).location,
        '+01.0000+002.0000+000.000/',
      );
    });

    test('a copy that lost the rotation gets the source one', () async {
      final source = File(p.join(dir.path, 'in.mp4'))
        ..writeAsBytesSync(
          movie([mvhd(DateTime.utc(2026)), trak(rotate90Matrix)]),
        );
      final output = File(p.join(dir.path, 'out.mp4'));
      messenger.setMockMethodCallHandler(methods, (call) async {
        output.writeAsBytesSync(
          movie([mvhd(DateTime.utc(2030)), trak(identityMatrix)]),
        );
        return null;
      });
      await ChannelTranscodeEngine().encodeWithColor(
        source: source,
        output: output,
        timeline: timeline,
      );
      expect(await readMp4VideoMatrix(output), rotate90Matrix);
    });

    test('a source with no date leaves the copy as written', () async {
      final source = File(p.join(dir.path, 'in.mp4'))
        ..writeAsBytesSync([1, 2, 3]);
      final output = File(p.join(dir.path, 'out.mp4'));
      final made = DateTime.utc(2030);
      Map<Object?, Object?>? args;
      messenger.setMockMethodCallHandler(methods, (call) async {
        args = call.arguments as Map<Object?, Object?>;
        output.writeAsBytesSync(movie([mvhd(made)]));
        return null;
      });
      await ChannelTranscodeEngine().encodeWithColor(
        source: source,
        output: output,
        timeline: timeline,
      );
      expect(args!['location'], isNull);
      expect((await readMp4RecordingInfo(output)).created, made);
    });
  });

  test('colorEncoderForThisPlatform is null on Linux only', () {
    final encoder = colorEncoderForThisPlatform();
    if (Platform.isLinux) {
      expect(encoder, isNull);
    } else {
      expect(encoder, isA<ChannelTranscodeEngine>());
    }
  });
}
