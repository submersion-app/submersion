import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/colour_profile.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import 'icc_test_profiles.dart';

/// The worker isolate, the ONNX Runtime bindings and the pipeline together,
/// through real ONNX Runtime and two constant-output models
/// (`tool/species_id/make_fake_onnx_models.py`). On Linux the build hook's
/// library is loaded, so it never skips there (CI runs it); elsewhere it
/// needs `SUBMERSION_ORT_LIBRARY`.
void main() {
  final libraryPath = Platform.environment['SUBMERSION_ORT_LIBRARY'];
  final skip = !Platform.isLinux && libraryPath == null
      ? 'no ONNX Runtime library on this machine'
      : null;
  String fixture(String name) => p.absolute(
    p.join('test', 'features', 'species_id', 'data', 'onnx', 'fixtures', name),
  );

  final models = VisionModels(
    detectors: [
      VisionDetector(
        path: fixture('fake_detector.onnx'),
        format: DetectorFormat.rfdetr,
        inputSize: 8,
        mean: const [0, 0, 0],
        std: const [1, 1, 1],
        scoreThreshold: 0.3,
        maxBoxes: 8,
      ),
    ],
    classifierPath: fixture('fake_classifier.onnx'),
    mergeIoU: 0.5,
    maxBoxes: 8,
    cropPadding: 0.1,
    classifierInputSize: 4,
    classifierMean: const [0.5, 0.5, 0.5],
    classifierStd: const [0.25, 0.25, 0.25],
    embeddingSize: 3,
    cropThumbnailSize: 16,
  );
  final image = RgbaImage(40, 20, Uint8List(40 * 20 * 4));

  test('runs the pipeline through real ONNX Runtime in its isolate', () async {
    final worker = await OnnxWorker.spawn(
      ortLibraryPath: Platform.isLinux ? null : libraryPath,
    );
    addTearDown(worker.close);
    await worker.load(models);

    final result = await worker.analyze(image);

    final fish = result.analysis.detections.single;
    expect(fish.x, closeTo(0.25, 1e-6));
    expect(fish.width, closeTo(0.5, 1e-6));
    expect(fish.score, closeTo(0.9, 1e-6));
    expect(fish.embedding, Float32List.fromList([1, 2, 3]));
    expect(fish.cropJpeg.sublist(0, 2), [0xFF, 0xD8]);

    expect((await worker.detect(image)).single.score, closeTo(0.9, 1e-6));
    final crop = await worker.cropAndEmbed(
      image,
      const IdentificationBox(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
    );
    expect(crop!.embedding, Float32List.fromList([1, 2, 3]));

    await worker.unload();
    await expectLater(
      worker.analyze(image),
      throwsA(
        isA<VisionEngineException>().having(
          (e) => e.code,
          'code',
          VisionEngineException.notLoaded,
        ),
      ),
    );
  }, skip: skip);

  test(
    'converts a photo with a colour profile to sRGB in its isolate',
    () async {
      final worker = await OnnxWorker.spawn(
        ortLibraryPath: Platform.isLinux ? null : libraryPath,
      );
      addTearDown(worker.close);
      await worker.load(models);
      final photo = RgbaImage(
        40,
        20,
        Uint8List.fromList([
          for (var i = 0; i < 40 * 20; i++) ...[200, 100, 50, 255],
        ]),
        colour: srgbConversionOf(jpegWith(displayP3Profile())),
      );

      final result = await worker.analyze(photo);

      // The crop the worker cut is in sRGB: Display P3's (200, 100, 50).
      final crop = img.decodeJpg(result.analysis.detections.single.cropJpeg)!;
      final centre = crop.getPixel(crop.width ~/ 2, crop.height ~/ 2);
      expect(centre.r, closeTo(215, 3));
      expect(centre.g, closeTo(93, 3));
      expect(centre.b, closeTo(31, 3));
    },
    skip: skip,
  );

  test('a worker that dies while starting fails instead of hanging', () async {
    // No device makes the worker's core throw outside the guarded open,
    // so the isolate dies before it answers.
    await expectLater(
      OnnxWorker.spawn(
        ortLibraryPath: Platform.isLinux ? null : libraryPath,
        devices: const [],
      ).timeout(const Duration(seconds: 20)),
      throwsA(isA<VisionEngineException>()),
    );
  }, skip: skip);

  test('a model that is not there fails to load', () async {
    final worker = await OnnxWorker.spawn(
      ortLibraryPath: Platform.isLinux ? null : libraryPath,
    );
    addTearDown(worker.close);

    await expectLater(
      worker.load(models.copyWith(classifierPath: fixture('missing.onnx'))),
      throwsA(isA<VisionEngineException>()),
    );
  }, skip: skip);
}
