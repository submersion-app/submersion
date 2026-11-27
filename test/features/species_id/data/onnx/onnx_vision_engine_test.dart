import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/data/engines/onnx/device_memory.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../../../../helpers/global_test_defaults.dart';

/// A worker that records its calls and holds each analysis until [release].
class FakeWorker implements OnnxWorkerHandle {
  final calls = <String>[];
  VisionModels? loaded;
  int running = 0;
  int mostAtOnce = 0;
  Completer<void>? gate;

  /// Answers every call as a worker whose isolate has stopped.
  bool stopped = false;

  void _alive() {
    if (stopped) {
      throw const VisionEngineException(OnnxWorker.stoppedCode, 'stopped');
    }
  }

  static const analysis = VisionAnalysis(
    imageWidth: 3,
    imageHeight: 2,
    detections: [],
  );

  @override
  Future<String?> load(VisionModels models) async {
    _alive();
    calls.add('load');
    loaded = models;
    return 'cpu';
  }

  @override
  Future<PipelineResult> analyze(RgbaImage image) async {
    _alive();
    if (loaded == null) {
      throw const VisionEngineException(VisionEngineException.notLoaded);
    }
    calls.add('analyze ${image.width}x${image.height}');
    running++;
    mostAtOnce = running > mostAtOnce ? running : mostAtOnce;
    await gate?.future;
    running--;
    return const PipelineResult(
      analysis: analysis,
      detectorBoxes: [[]],
      mergedBoxes: [],
      detectMs: 0,
      embedMs: [],
    );
  }

  @override
  Future<List<PipelineBox>> detect(RgbaImage frame) async => const [];

  @override
  Future<VisionMomentCrop?> cropAndEmbed(
    RgbaImage frame,
    IdentificationBox box,
  ) async => null;

  @override
  Future<void> unload() async {
    calls.add('unload');
    loaded = null;
  }

  @override
  Future<void> close() async => calls.add('close');
}

class FakeDeviceMemory implements DeviceMemory {
  FakeDeviceMemory(this.total);

  final int? total;

  @override
  Future<int?> totalBytes() async => total;

  @override
  Future<VisionMemory> reading() async =>
      const VisionMemory(footprintBytes: 42, footprintPeakBytes: 43);
}

const _models = VisionModels(
  detectors: [
    VisionDetector(
      path: 'detector/model.onnx',
      format: DetectorFormat.rfdetr,
      inputSize: 640,
      mean: [0.485, 0.456, 0.406],
      std: [0.229, 0.224, 0.225],
      scoreThreshold: 0.3,
      maxBoxes: 8,
    ),
  ],
  classifierPath: 'classifier/model.onnx',
  mergeIoU: 0.5,
  maxBoxes: 8,
  cropPadding: 0.1,
  classifierInputSize: 224,
  classifierMean: [0.48, 0.45, 0.4],
  classifierStd: [0.26, 0.26, 0.27],
  embeddingSize: 768,
  cropThumbnailSize: 320,
);

/// [engine], removed from the binding's observers when the test ends: an
/// engine that loads models observes memory pressure, and one left behind
/// would hear the next test file's events in CI's shared isolate.
OnnxVisionEngine _tracked(OnnxVisionEngine engine) {
  addTearDown(() => WidgetsBinding.instance.removeObserver(engine));
  return engine;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWorker worker;
  late List<Uint8List> decoded;

  OnnxVisionEngine engine() => _tracked(
    OnnxVisionEngine(
      worker: () async => worker,
      decode: (bytes) async {
        decoded.add(bytes);
        return RgbaImage(3, 2, Uint8List(3 * 2 * 4));
      },
    ),
  );

  setUp(() {
    worker = FakeWorker();
    decoded = [];
  });

  test(
    'a worker that failed to start is started again on the next call',
    () async {
      var spawns = 0;
      final e = _tracked(
        OnnxVisionEngine(
          worker: () async {
            spawns++;
            if (spawns == 1) {
              throw const VisionEngineException(
                'unsupported',
                'no runtime yet',
              );
            }
            return worker;
          },
          decode: (bytes) async => RgbaImage(3, 2, Uint8List(3 * 2 * 4)),
        ),
      );

      await expectLater(e.load(_models), throwsA(isA<VisionEngineException>()));
      await e.load(_models);

      expect(spawns, 2);
      expect(worker.calls, ['load']);
    },
  );

  test(
    'a worker that stopped is replaced and the models loaded again',
    () async {
      final first = FakeWorker(), second = FakeWorker();
      final workers = [first, second];
      final e = _tracked(
        OnnxVisionEngine(
          worker: () async => workers.removeAt(0),
          decode: (bytes) async => RgbaImage(3, 2, Uint8List(3 * 2 * 4)),
        ),
      );
      await e.load(_models);
      first.stopped = true;

      await expectLater(
        e.analyze(bytes: Uint8List(1)),
        throwsA(
          isA<VisionEngineException>().having(
            (x) => x.code,
            'code',
            VisionEngineException.notLoaded,
          ),
        ),
      );
      await e.load(_models);

      expect(second.calls, ['load']);
      expect(first.calls.last, 'close', reason: 'the stopped worker is closed');
      expect((await e.analyze(bytes: Uint8List(1))).imageWidth, 3);
    },
  );

  test('a worker that lost its models is loaded again', () async {
    // A run that failed on the worker's last device closes its models.
    final e = engine();
    await e.load(_models);
    worker.loaded = null;

    await expectLater(
      e.analyze(bytes: Uint8List(1)),
      throwsA(
        isA<VisionEngineException>().having(
          (x) => x.code,
          'code',
          VisionEngineException.notLoaded,
        ),
      ),
    );
    await e.load(_models);

    expect(worker.calls.where((c) => c == 'load'), hasLength(2));
    expect((await e.analyze(bytes: Uint8List(1))).imageWidth, 3);
  });

  test('ONNX Runtime leaves two cores for playback and scrolling', () {
    expect(onnxThreadsFor(8), 6);
    expect(onnxThreadsFor(4), 2);
    expect(onnxThreadsFor(2), 1);
    expect(onnxThreadsFor(1), 1);
  });

  test('a photo that cannot be read fails as decode_failed', () async {
    final e = engine();
    await e.load(_models);

    await expectLater(
      e.analyze(path: p.join(Directory.systemTemp.path, 'no-such-photo.jpg')),
      throwsA(
        isA<VisionEngineException>().having(
          (x) => x.code,
          'code',
          'decode_failed',
        ),
      ),
    );
  });

  test('is the onnx engine', () {
    expect(engine().engineName, VisionEngine.onnxEngine);
    expect(VisionEngine.onnxEngine, 'onnx');
  });

  test('analyses bytes', () async {
    final e = engine();
    await e.load(_models);

    final result = await e.analyze(bytes: Uint8List.fromList([1, 2, 3]));

    expect(result, FakeWorker.analysis);
    expect(decoded.single, [1, 2, 3]);
    expect(worker.calls, ['load', 'analyze 3x2']);
  });

  test('analyses a file', () async {
    final dir = await Directory.systemTemp.createTemp('onnx_engine');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'photo.jpg'))
      ..writeAsBytesSync([9, 8, 7]);
    final e = engine();
    await e.load(_models);

    await e.analyze(path: file.path);

    expect(decoded.single, [9, 8, 7]);
  });

  test('takes exactly one of path and bytes', () async {
    final e = engine();
    expect(() => e.analyze(), throwsArgumentError);
    expect(
      () => e.analyze(path: 'a', bytes: Uint8List(1)),
      throwsArgumentError,
    );
  });

  test('calls are served one at a time', () async {
    final e = engine();
    await e.load(_models);
    worker.gate = Completer<void>();

    final first = e.analyze(bytes: Uint8List(1));
    final second = e.analyze(bytes: Uint8List(2));
    await pumpEventQueue();
    worker.gate!.complete();
    await Future.wait([first, second]);

    expect(worker.mostAtOnce, 1);
    expect(worker.calls.where((c) => c.startsWith('analyze')), hasLength(2));
  });

  test('loading the same models twice loads once', () async {
    final e = engine();
    await e.load(_models);
    await e.load(_models);

    expect(worker.calls.where((c) => c == 'load'), hasLength(1));
  });

  test('after unload, analyse fails as not_loaded', () async {
    final e = engine();
    await e.load(_models);
    await e.unload();

    await expectLater(
      e.analyze(bytes: Uint8List(1)),
      throwsA(
        isA<VisionEngineException>().having(
          (x) => x.code,
          'code',
          VisionEngineException.notLoaded,
        ),
      ),
    );
  });

  test('memory pressure unloads the models', () async {
    final e = engine();
    await e.load(_models);

    e.didHaveMemoryPressure();
    await pumpEventQueue();

    expect(worker.calls, contains('unload'));
    await expectLater(
      e.analyze(bytes: Uint8List(1)),
      throwsA(isA<VisionEngineException>()),
    );
  });

  test('excludeFromBackup touches nothing', () async {
    await engine().excludeFromBackup('/nowhere/at/all');
    expect(worker.calls, isEmpty);
  });

  group('availability', () {
    OnnxVisionEngine on(
      TargetPlatform platform, {
      int? total = androidMinimumMemoryBytes,
      bool ignoreFloor = false,
      bool is64Bit = true,
      bool libraryLoads = true,
      bool onnxPlatforms = true,
    }) => _tracked(
      OnnxVisionEngine(
        platform: platform,
        worker: () async => worker,
        deviceMemory: FakeDeviceMemory(total),
        ignoreFloor: ignoreFloor,
        is64Bit: is64Bit,
        libraryLoads: () async => libraryLoads,
        onnxPlatforms: onnxPlatforms,
      ),
    );

    test('a build with MARINE_LIFE_ID_ONNX=false reports the engine as not '
        'running here, so nothing offers it', () async {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(
          await on(platform, onnxPlatforms: false).availability(),
          VisionAvailability.unsupportedPlatform,
          reason: '$platform',
        );
      }
    });

    test('an engine with no library check of its own follows the test '
        'override, whatever the host ships', () async {
      addTearDown(applyGlobalTestDefaults);
      OnnxVisionEngine unchecked() => _tracked(
        OnnxVisionEngine(
          platform: TargetPlatform.android,
          worker: () async => worker,
          deviceMemory: FakeDeviceMemory(androidMinimumMemoryBytes),
        ),
      );

      OnnxVisionEngine.debugLibraryLoadsOverride = true;
      expect(await unchecked().availability(), VisionAvailability.available);

      OnnxVisionEngine.debugLibraryLoadsOverride = false;
      expect(
        await unchecked().availability(),
        VisionAvailability.unsupportedPlatform,
      );
    });

    test('is available at exactly the floor', () async {
      expect(
        await on(TargetPlatform.android).availability(),
        VisionAvailability.available,
      );
      expect(
        await on(
          TargetPlatform.windows,
          total: pcMinimumMemoryBytes,
        ).availability(),
        VisionAvailability.available,
      );
    });

    test('a device one byte under the floor is not eligible', () async {
      expect(
        await on(
          TargetPlatform.android,
          total: androidMinimumMemoryBytes - 1,
        ).availability(),
        VisionAvailability.deviceNotEligible,
      );
      expect(
        await on(
          TargetPlatform.linux,
          total: pcMinimumMemoryBytes - 1,
        ).availability(),
        VisionAvailability.deviceNotEligible,
      );
    });

    test('the measurement build lifts the floor', () async {
      expect(
        await on(
          TargetPlatform.android,
          total: 4 * 1024 * 1024 * 1024,
          ignoreFloor: true,
        ).availability(),
        VisionAvailability.available,
      );
    });

    test('an unknown memory size is not eligible', () async {
      expect(
        await on(TargetPlatform.android, total: null).availability(),
        VisionAvailability.deviceNotEligible,
      );
    });

    test('a 32-bit Android device is not eligible', () async {
      expect(
        await on(TargetPlatform.android, is64Bit: false).availability(),
        VisionAvailability.deviceNotEligible,
      );
    });

    test('a 32-bit Android device, which ships no library, is not '
        'eligible rather than unsupported', () async {
      expect(
        await on(
          TargetPlatform.android,
          is64Bit: false,
          libraryLoads: false,
        ).availability(),
        VisionAvailability.deviceNotEligible,
      );
    });

    test('no library is an unsupported platform', () async {
      expect(
        await on(TargetPlatform.linux, libraryLoads: false).availability(),
        VisionAvailability.unsupportedPlatform,
      );
    });

    test('Core ML platforms are not this engine\'s', () async {
      expect(
        await on(TargetPlatform.iOS).availability(),
        VisionAvailability.unsupportedPlatform,
      );
    });

    test('memory reads the device', () async {
      final reading = await on(TargetPlatform.linux).memory();
      expect(reading.footprintBytes, 42);
      expect(reading.footprintPeakBytes, 43);
    });
  });
}
