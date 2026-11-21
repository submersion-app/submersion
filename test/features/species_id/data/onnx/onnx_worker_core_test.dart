import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/features/species_id/data/engines/onnx/device_crash_guard.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker_core.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// A model that finds one fish (a detector) or embeds to three values (the
/// classifier); fails when [failing] says so.
class FakeModel implements LoadedModel {
  FakeModel(this.path, this._device, this.failing);

  final String path;
  final OrtDevice _device;
  final bool Function() failing;
  bool closed = false;

  @override
  String get device => _device.name;

  @override
  List<ModelOutput> run(Float32List input, List<int> shape) {
    if (failing()) throw const OrtException('the GPU driver stopped');
    if (path.contains('classifier')) {
      return [
        ModelOutput([1, 3], Float32List.fromList([1, 2, 3])),
      ];
    }
    final logit = math.log(0.9 / 0.1);
    return [
      ModelOutput([1, 1, 4], Float32List.fromList([0.5, 0.5, 0.5, 0.5])),
      ModelOutput([1, 1, 1], Float32List.fromList([logit])),
    ];
  }

  @override
  void close() => closed = true;
}

const _models = VisionModels(
  detectors: [
    VisionDetector(
      path: 'detector/model.onnx',
      format: DetectorFormat.rfdetr,
      inputSize: 8,
      mean: [0, 0, 0],
      std: [1, 1, 1],
      scoreThreshold: 0.3,
      maxBoxes: 8,
    ),
  ],
  classifierPath: 'classifier/model.onnx',
  mergeIoU: 0.5,
  maxBoxes: 8,
  cropPadding: 0.1,
  classifierInputSize: 4,
  classifierMean: [0.5, 0.5, 0.5],
  classifierStd: [0.25, 0.25, 0.25],
  embeddingSize: 3,
  cropThumbnailSize: 16,
);

void main() {
  final image = RgbaImage(40, 20, Uint8List(40 * 20 * 4));
  const devices = [OrtDevice.hardware, OrtDevice.directMl, OrtDevice.cpu];

  late List<FakeModel> opened;
  late Set<OrtDevice> refuseToOpen;
  late Set<OrtDevice> failToRun;

  OnnxWorkerCore core() => OnnxWorkerCore(
    devices: devices,
    open: (path, device) {
      if (refuseToOpen.contains(device)) {
        throw OrtException('$device cannot open $path');
      }
      final model = FakeModel(path, device, () => failToRun.contains(device));
      opened.add(model);
      return model;
    },
  );

  setUp(() {
    opened = [];
    refuseToOpen = {};
    failToRun = {};
  });

  test('opens on the first device that takes the models', () {
    final c = core()..load(_models);
    expect(c.device, OrtDevice.hardware);
    expect(c.analyze(image).analysis.detections, hasLength(1));
  });

  test('a session failing on the GPU opens on DirectML', () {
    refuseToOpen = {OrtDevice.hardware};
    final c = core()..load(_models);
    expect(c.device, OrtDevice.directMl);
  });

  test('a run failing on the GPU moves to DirectML', () {
    failToRun = {OrtDevice.hardware};
    final c = core()..load(_models);

    final result = c.analyze(image);

    expect(result.analysis.detections, hasLength(1));
    expect(c.device, OrtDevice.directMl);
    expect(
      opened.where((m) => m.device == 'hardware').every((m) => m.closed),
      isTrue,
    );
  });

  test('says where the models run, before and after a fallback, for the '
      'debug log', () {
    final c = core();
    expect(c.deviceDescription, isNull);

    c.load(_models);
    expect(c.deviceDescription, 'hardware');

    failToRun = {OrtDevice.hardware};
    c.analyze(image);
    expect(c.deviceDescription, 'directMl');
  });

  test('every model open is noted while it runs, a fallback during a run '
      'included, and the note is gone once it returns', () {
    // The note survives only if the app ends mid-open: DeviceCrashGuard then
    // skips the device it names at the next start.
    final dir = Directory.systemTemp.createTempSync('opening_note');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'onnx_opening');
    final noted = <String>[];
    failToRun = {OrtDevice.hardware};
    final c = OnnxWorkerCore(
      devices: devices,
      open: noteOpens((modelPath, device) {
        noted.add(File(path).readAsStringSync());
        final model = FakeModel(
          modelPath,
          device,
          () => failToRun.contains(device),
        );
        opened.add(model);
        return model;
      }, OpeningNote(path)),
    );

    c.load(_models);
    c.analyze(image);

    expect(noted.toSet(), {'hardware', 'directMl'});
    expect(File(path).existsSync(), isFalse);
  });

  test('the first run after each open is watched while it runs, a '
      'fallback included, and later runs are not', () {
    final watched = <String>[];
    failToRun = {OrtDevice.hardware};
    final c = OnnxWorkerCore(
      devices: devices,
      open: (path, device) {
        final model = FakeModel(path, device, () => failToRun.contains(device));
        opened.add(model);
        return model;
      },
      firstRuns: _Watcher(watched),
    );

    c.load(_models);
    c.analyze(image);
    c.analyze(image);

    expect(watched, [
      'starting hardware',
      'finished',
      'starting directMl',
      'finished',
    ]);
  });

  test('failing on DirectML too lands on the processor', () {
    failToRun = {OrtDevice.hardware, OrtDevice.directMl};
    final c = core()..load(_models);

    c.analyze(image);

    expect(c.device, OrtDevice.cpu);
  });

  test('failing everywhere is an inference failure, with nothing open', () {
    failToRun = devices.toSet();
    final c = core()..load(_models);

    expect(
      () => c.analyze(image),
      throwsA(
        isA<VisionEngineException>().having(
          (e) => e.code,
          'code',
          'inference_failed',
        ),
      ),
    );
    expect(opened.every((m) => m.closed), isTrue);
    expect(c.device, isNull);
  });

  test('no device opening the models is an inference failure', () {
    refuseToOpen = devices.toSet();
    expect(() => core().load(_models), throwsA(isA<VisionEngineException>()));
  });

  test('the same models load once; unload closes them all', () {
    final c = core()
      ..load(_models)
      ..load(_models);
    expect(opened, hasLength(2));

    c.unload();

    expect(opened.every((m) => m.closed), isTrue);
    expect(
      () => c.analyze(image),
      throwsA(
        isA<VisionEngineException>().having(
          (e) => e.code,
          'code',
          VisionEngineException.notLoaded,
        ),
      ),
    );
  });
}

class _Watcher implements FirstRunWatcher {
  _Watcher(this.calls);

  final List<String> calls;

  @override
  void starting(OrtDevice device) => calls.add('starting ${device.name}');

  @override
  void finished() => calls.add('finished');
}
