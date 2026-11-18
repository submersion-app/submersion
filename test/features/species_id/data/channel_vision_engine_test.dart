import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/channel_vision_engine.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../domain/manifest_fixture.dart';

const _models = VisionModels(
  detectors: [
    VisionDetector(
      path: '/packs/1/detector.mlpackage',
      format: DetectorFormat.rfdetr,
      inputSize: 640,
      mean: [0.485, 0.456, 0.406],
      std: [0.229, 0.224, 0.225],
      scoreThreshold: 0.3,
      maxBoxes: 8,
    ),
  ],
  classifierPath: '/packs/1/classifier.mlpackage',
  mergeIoU: 0.5,
  maxBoxes: 8,
  cropPadding: 0.1,
  classifierInputSize: 224,
  classifierMean: [0.48, 0.45, 0.4],
  classifierStd: [0.26, 0.26, 0.27],
  embeddingSize: 3,
  cropThumbnailSize: 320,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('submersion_vision');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  ChannelVisionEngine engine([
    TargetPlatform platform = TargetPlatform.macOS,
  ]) => ChannelVisionEngine(platform: platform);

  test('maps each availability string', () async {
    for (final value in VisionAvailability.values) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'availability');
        return value.name;
      });
      expect(await engine().availability(), value);
    }
  });

  test('a platform without a Core ML engine never asks the channel', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return 'available';
    });
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        await engine(platform).availability(),
        VisionAvailability.unsupportedPlatform,
      );
      expect(engine(platform).engineName, isNull);
    }
    expect(called, isFalse);
    expect(engine(TargetPlatform.iOS).engineName, VisionEngine.coreMlEngine);
  });

  test('a missing plugin is an unsupported platform, not an error', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw MissingPluginException(),
    );
    expect(
      await engine().availability(),
      VisionAvailability.unsupportedPlatform,
    );
  });

  test('load sends every model setting', () async {
    Map<Object?, Object?>? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'load');
      sent = call.arguments as Map<Object?, Object?>;
      return null;
    });
    await engine().load(_models);
    expect(sent, {
      'detectors': [
        {
          'path': '/packs/1/detector.mlpackage',
          'format': 'rfdetr',
          'inputSize': 640,
          'mean': [0.485, 0.456, 0.406],
          'std': [0.229, 0.224, 0.225],
          'scoreThreshold': 0.3,
          'maxBoxes': 8,
        },
      ],
      'mergeIoU': 0.5,
      'maxBoxes': 8,
      'cropPadding': 0.1,
      'classifierPath': '/packs/1/classifier.mlpackage',
      'classifierInputSize': 224,
      'classifierMean': [0.48, 0.45, 0.4],
      'classifierStd': [0.26, 0.26, 0.27],
      'embeddingSize': 3,
      'cropThumbnailSize': 320,
      'cropFit': 'padSquare',
    });
  });

  test('load sends both detectors of a pair pack, in order', () async {
    Map<Object?, Object?>? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call.arguments as Map<Object?, Object?>;
      return null;
    });
    final manifest = SpeciesPackManifest.parse(manifestV2Json());
    await engine().load(
      VisionModels.fromManifest(
        manifest,
        detectorPaths: const [
          '/p/detector/d.mlmodelc',
          '/p/detector-megalodon/m.mlmodelc',
        ],
        classifierPath: '/p/classifier/c.mlmodelc',
      ),
    );
    final detectors = (sent!['detectors']! as List)
        .cast<Map<Object?, Object?>>();
    expect(detectors.map((d) => d['path']), [
      '/p/detector/d.mlmodelc',
      '/p/detector-megalodon/m.mlmodelc',
    ]);
    expect(detectors.map((d) => d['format']), ['rfdetr', 'yolo']);
    expect(detectors.map((d) => d['scoreThreshold']), [0.3, 0.25]);
    expect(detectors.last['mean'], [0.0, 0.0, 0.0]);
    expect(sent!['mergeIoU'], 0.5);
    expect(sent!['maxBoxes'], 8);
    expect(sent!['cropPadding'], 0.10);
  });

  test('a detector path for each detector is required', () {
    final manifest = SpeciesPackManifest.parse(manifestV2Json());
    expect(
      () => VisionModels.fromManifest(
        manifest,
        detectorPaths: const ['/p/detector/d.mlmodelc'],
        classifierPath: '/p/classifier/c.mlmodelc',
      ),
      throwsArgumentError,
    );
  });

  test('load sends the crop fitting the pack asks for', () async {
    Map<Object?, Object?>? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call.arguments as Map<Object?, Object?>;
      return null;
    });
    await engine().load(_models.copyWith(cropFit: CropFit.centreCrop));
    expect(sent!['cropFit'], 'centreCrop');
  });

  test('analyze decodes the native reply into typed detections', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'analyze');
      expect(call.arguments, {'path': '/photos/a.jpeg'});
      return {
        'imageWidth': 4000,
        'imageHeight': 3000,
        'detections': [
          {
            'x': 0.1,
            'y': 0.2,
            'width': 0.3,
            'height': 0.25,
            'score': 0.9,
            'pixelWidth': 1200,
            'pixelHeight': 750,
            'crop': Uint8List.fromList([1, 2, 3]),
            'embedding': Float32List.fromList([1, 0, 0]),
          },
          {
            'x': 0.5,
            'y': 0.5,
            'width': 0.1,
            'height': 0.1,
            'score': 0.4,
            'pixelWidth': 400,
            'pixelHeight': 300,
            'crop': Uint8List.fromList([4]),
            'embedding': Float32List.fromList([0, 1, 0]),
          },
        ],
      };
    });

    final result = await engine().analyze(path: '/photos/a.jpeg');

    expect(result.imageWidth, 4000);
    expect(result.imageHeight, 3000);
    expect(result.detections, hasLength(2));
    final first = result.detections.first;
    expect(first.x, 0.1);
    expect(first.height, 0.25);
    expect(first.score, 0.9);
    expect(first.pixelWidth, 1200);
    expect(first.cropJpeg, [1, 2, 3]);
    expect(first.embedding, [1.0, 0.0, 0.0]);
  });

  test('analyze sends bytes when given bytes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments, {
        'bytes': Uint8List.fromList([9, 9]),
      });
      return {'imageWidth': 1, 'imageHeight': 1, 'detections': <Object?>[]};
    });
    final result = await engine().analyze(bytes: Uint8List.fromList([9, 9]));
    expect(result.detections, isEmpty);
  });

  test('analyze needs exactly one of a path and bytes', () {
    expect(() => engine().analyze(), throwsArgumentError);
    expect(
      () => engine().analyze(path: 'a', bytes: Uint8List(1)),
      throwsArgumentError,
    );
  });

  test('a native failure becomes a VisionEngineException', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          throw PlatformException(code: 'decode_failed', message: 'bad jpeg'),
    );
    await expectLater(
      engine().analyze(path: 'x'),
      throwsA(
        isA<VisionEngineException>().having(
          (e) => e.code,
          'code',
          'decode_failed',
        ),
      ),
    );
  });

  test('excludeFromBackup and unload reach the channel', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await engine().excludeFromBackup('/support/species_id/pack');
    await engine().unload();
    expect(calls.map((c) => c.method), ['excludeFromBackup', 'unload']);
    expect(calls.first.arguments, {'path': '/support/species_id/pack'});
  });

  test('models are built from a manifest', () {
    final manifest = SpeciesPackManifest.parse(manifestJson());
    final models = VisionModels.fromManifest(
      manifest,
      detectorPaths: const ['d'],
      classifierPath: 'c',
    );
    expect(models.detectors.single.inputSize, 640);
    expect(models.detectors.single.format, DetectorFormat.rfdetr);
    expect(models.detectors.single.scoreThreshold, 0.3);
    expect(models.detectors.single.maxBoxes, 8);
    expect(models.maxBoxes, 8);
    expect(models.cropPadding, 0.10);
    expect(models.classifierInputSize, 224);
    expect(models.embeddingSize, 768);
    expect(models.cropThumbnailSize, 320);
    expect(models.classifierMean, manifest.classifier.mean);
  });

  group('video (issue #4675)', () {
    test('detectVideo sends the range and decodes the frames', () async {
      late MethodCall sent;
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent = call;
        return {
          'width': 1080,
          'height': 1920,
          'durationMs': 25000,
          'frames': [
            {
              'ms': 0,
              'boxes': [
                {'x': 0.1, 'y': 0.2, 'width': 0.3, 'height': 0.4, 'score': 0.9},
              ],
            },
            {'ms': 250, 'boxes': <Object?>[]},
          ],
        };
      });
      final video = await engine().detectVideo(
        path: '/v.mp4',
        startMs: 10000,
        endMs: 20000,
        sampleIntervalMs: 250,
      );
      expect(sent.method, 'detectVideo');
      expect(sent.arguments, {
        'path': '/v.mp4',
        'startMs': 10000,
        'endMs': 20000,
        'sampleIntervalMs': 250,
      });
      expect(video.width, 1080);
      expect(video.height, 1920);
      expect(video.durationMs, 25000);
      expect(video.frames.map((f) => f.ms), [0, 250]);
      expect(
        video.frames.first.boxes.single,
        const DetectedBox(
          box: IdentificationBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
          score: 0.9,
        ),
      );
    });

    test('embedMoments sends each moment and keeps a gap where a frame '
        'failed', () async {
      late MethodCall sent;
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent = call;
        return [
          {
            'pixelWidth': 80,
            'pixelHeight': 60,
            'crop': Uint8List.fromList([0xFF, 0xD8]),
            'embedding': Float32List.fromList([1, 0, 0]),
          },
          null,
        ];
      });
      final crops = await engine().embedMoments(
        path: '/v.mp4',
        moments: const [
          VisionMoment(
            ms: 500,
            box: IdentificationBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
          ),
          VisionMoment(
            ms: 900,
            box: IdentificationBox(x: 0.5, y: 0.5, width: 0.1, height: 0.1),
          ),
        ],
      );
      expect(sent.method, 'embedMoments');
      expect(sent.arguments, {
        'path': '/v.mp4',
        'moments': [
          {'ms': 500, 'x': 0.1, 'y': 0.2, 'width': 0.3, 'height': 0.4},
          {'ms': 900, 'x': 0.5, 'y': 0.5, 'width': 0.1, 'height': 0.1},
        ],
      });
      expect(crops, hasLength(2));
      expect(crops.first!.pixelWidth, 80);
      expect(crops.first!.embedding, [1, 0, 0]);
      expect(crops.last, isNull);
    });

    test('an app in the background is reported as such', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'not_foreground'),
      );
      expect(
        engine().detectVideo(
          path: '/v.mp4',
          startMs: 0,
          endMs: 10000,
          sampleIntervalMs: 250,
        ),
        throwsA(
          isA<VisionEngineException>().having(
            (e) => e.code,
            'code',
            VisionEngineException.notForeground,
          ),
        ),
      );
    });

    test('a missing plugin is unsupported', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(
        engine().embedMoments(path: '/v.mp4', moments: const []),
        throwsA(
          isA<VisionEngineException>().having(
            (e) => e.code,
            'code',
            'unsupported',
          ),
        ),
      );
    });
  });

  group('memory', () {
    const mib = 1048576;

    test('memory decodes every field the plugin reports', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'memory');
        return <String, Object?>{
          'footprint': 600 * mib,
          'footprintPeak': 845 * mib,
          'available': 2412 * mib,
          'neuralCounted': 0,
          'neuralNotCounted': 717 * mib,
          'neuralNotCountedPeak': 717 * mib,
        };
      });
      expect(
        await engine().memory(),
        const VisionMemory(
          footprintBytes: 600 * mib,
          footprintPeakBytes: 845 * mib,
          availableBytes: 2412 * mib,
          neuralCountedBytes: 0,
          neuralNotCountedBytes: 717 * mib,
          neuralNotCountedPeakBytes: 717 * mib,
        ),
      );
    });

    test('memory leaves out what the platform does not report', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => <String, Object?>{'footprint': mib},
      );
      final reading = await engine().memory();
      expect(reading.footprintBytes, mib);
      expect(reading.footprintPeakBytes, isNull);
      expect(reading.availableBytes, isNull);
      expect(reading.neuralCountedBytes, isNull);
      expect(reading.neuralNotCountedBytes, isNull);
      expect(reading.neuralNotCountedPeakBytes, isNull);
    });

    test('memory with an empty reply is an engine failure', () async {
      // What the plugin answers when task_info fails.
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => <String, Object?>{},
      );
      expect(
        engine().memory(),
        throwsA(
          isA<VisionEngineException>().having(
            (e) => e.code,
            'code',
            'no_reading',
          ),
        ),
      );
    });

    test('memory with no reply is an engine failure', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(
        engine().memory(),
        throwsA(
          isA<VisionEngineException>().having(
            (e) => e.code,
            'code',
            'no_reading',
          ),
        ),
      );
    });
  });
}
