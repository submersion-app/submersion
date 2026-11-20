import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// A worker that records its calls and holds each analysis until [release].
class FakeWorker implements OnnxWorkerHandle {
  final calls = <String>[];
  VisionModels? loaded;
  int running = 0;
  int mostAtOnce = 0;
  Completer<void>? gate;

  static const analysis = VisionAnalysis(
    imageWidth: 3,
    imageHeight: 2,
    detections: [],
  );

  @override
  Future<void> load(VisionModels models) async {
    calls.add('load');
    loaded = models;
  }

  @override
  Future<PipelineResult> analyze(RgbaImage image) async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWorker worker;
  late List<Uint8List> decoded;

  OnnxVisionEngine engine() => OnnxVisionEngine(
    worker: () async => worker,
    decode: (bytes) async {
      decoded.add(bytes);
      return RgbaImage(3, 2, Uint8List(3 * 2 * 4));
    },
  );

  setUp(() {
    worker = FakeWorker();
    decoded = [];
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
}
