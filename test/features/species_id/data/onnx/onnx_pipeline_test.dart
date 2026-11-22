import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/colour_profile.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import 'icc_test_profiles.dart';

/// A model that records what it was given and answers with [answer].
class FakeRunner implements ModelRunner {
  FakeRunner(this.answer);

  final List<ModelOutput> Function(Float32List input) answer;
  final shapes = <List<int>>[];
  final inputs = <Float32List>[];

  @override
  List<ModelOutput> run(Float32List input, List<int> shape) {
    shapes.add(shape);
    inputs.add(input);
    return answer(input);
  }
}

double _logit(double p) => math.log(p / (1 - p));

/// An RF-DETR model that finds [boxes]: centre x, centre y, width, height,
/// probability. Its logits come first, so the reader must find the boxes by
/// their shape.
FakeRunner rfdetr(List<List<double>> boxes) => FakeRunner(
  (_) => [
    ModelOutput([
      1,
      boxes.length,
      1,
    ], Float32List.fromList([for (final b in boxes) _logit(b[4])])),
    ModelOutput([
      1,
      boxes.length,
      4,
    ], Float32List.fromList([for (final b in boxes) ...b.take(4)])),
  ],
);

FakeRunner classifier(List<double> embedding) => FakeRunner(
  (_) => [
    ModelOutput([1, embedding.length], Float32List.fromList(embedding)),
  ],
);

VisionDetector detector(DetectorFormat format) => VisionDetector(
  path: 'detector',
  format: format,
  inputSize: 8,
  mean: const [0, 0, 0],
  std: const [1, 1, 1],
  scoreThreshold: 0.3,
  maxBoxes: 8,
);

VisionModels models({
  int detectors = 1,
  DetectorFormat format = DetectorFormat.rfdetr,
}) => VisionModels(
  detectors: [for (var i = 0; i < detectors; i++) detector(format)],
  classifierPath: 'classifier',
  mergeIoU: 0.5,
  maxBoxes: 8,
  cropPadding: 0.1,
  classifierInputSize: 4,
  classifierMean: const [0.5, 0.5, 0.5],
  classifierStd: const [0.25, 0.25, 0.25],
  embeddingSize: 3,
  cropThumbnailSize: 16,
);

RgbaImage uniform(int width, int height, List<int> rgb) => RgbaImage(
  width,
  height,
  Uint8List.fromList([
    for (var i = 0; i < width * height; i++) ...[rgb[0], rgb[1], rgb[2], 255],
  ]),
);

void main() {
  final image = uniform(40, 20, [10, 20, 30]);

  test('runs the detector on a square tensor and reads its boxes', () {
    final det = rfdetr([
      [0.5, 0.5, 0.5, 0.5, 0.9],
      [0.2, 0.2, 0.2, 0.2, 0.1],
    ]);
    final cls = classifier([1, 2, 3]);
    final pipeline = OnnxPipeline(
      models: models(),
      detectors: [det],
      classifier: cls,
    );

    final result = pipeline.analyze(image);

    expect(det.shapes.single, [1, 3, 8, 8]);
    expect(det.inputs.single, hasLength(3 * 8 * 8));
    expect(result.analysis.imageWidth, 40);
    expect(result.analysis.imageHeight, 20);
    final d = result.analysis.detections.single;
    expect(d.x, closeTo(0.25, 1e-6));
    expect(d.y, closeTo(0.25, 1e-6));
    expect(d.width, closeTo(0.5, 1e-6));
    expect(d.height, closeTo(0.5, 1e-6));
    expect(d.score, closeTo(0.9, 1e-6));
    expect(result.embedMs, hasLength(1));
  });

  test('a detection carries its unpadded pixel size, crop and embedding', () {
    final cls = classifier([1, 2, 3]);
    final pipeline = OnnxPipeline(
      models: models(),
      detectors: [
        rfdetr([
          [0.5, 0.5, 0.5, 0.5, 0.9],
        ]),
      ],
      classifier: cls,
    );

    final d = pipeline.analyze(image).analysis.detections.single;

    expect(cls.shapes.single, [1, 3, 4, 4]);
    expect(d.pixelWidth, 20);
    expect(d.pixelHeight, 10);
    expect(d.embedding, Float32List.fromList([1, 2, 3]));
    expect(d.cropJpeg.sublist(0, 2), [0xFF, 0xD8]);
  });

  test('two detectors are merged, and each one\'s boxes are kept', () {
    final pipeline = OnnxPipeline(
      models: models(detectors: 2),
      detectors: [
        rfdetr([
          [0.5, 0.5, 0.5, 0.5, 0.6],
        ]),
        rfdetr([
          [0.51, 0.5, 0.5, 0.5, 0.9],
          [0.1, 0.1, 0.1, 0.1, 0.5],
        ]),
      ],
      classifier: classifier([1, 2, 3]),
    );

    final result = pipeline.analyze(image);

    expect(result.detectorBoxes, hasLength(2));
    expect(
      result.mergedBoxes,
      mergeRuns(result.detectorBoxes, iou: 0.5, limit: 8),
    );
    expect(result.mergedBoxes, hasLength(2));
    expect(result.analysis.detections.first.score, closeTo(0.9, 1e-6));
  });

  test('a box too small to crop is left out of the detections', () {
    // 0.4 pixels wide, inside one pixel of a 40 pixel image, so even
    // taken out to whole pixels it is under 2.
    final pipeline = OnnxPipeline(
      models: models(),
      detectors: [
        rfdetr([
          [0.4825, 0.5, 0.01, 0.5, 0.9],
        ]),
      ],
      classifier: classifier([1, 2, 3]),
    );

    final result = pipeline.analyze(image);

    expect(result.mergedBoxes, hasLength(1));
    expect(result.analysis.detections, isEmpty);
  });

  test('an embedding of the wrong length fails as inference_failed', () {
    final pipeline = OnnxPipeline(
      models: models(),
      detectors: [
        rfdetr([
          [0.5, 0.5, 0.5, 0.5, 0.9],
        ]),
      ],
      classifier: classifier([1, 2]),
    );

    expect(
      () => pipeline.analyze(image),
      throwsA(
        isA<VisionEngineException>().having(
          (e) => e.code,
          'code',
          'inference_failed',
        ),
      ),
    );
  });

  test('a YOLO detector gets a letterboxed tensor, grey outside the image', () {
    final det = FakeRunner(
      (_) => [
        ModelOutput([1, 5, 0], Float32List(0)),
      ],
    );
    final pipeline = OnnxPipeline(
      models: models(format: DetectorFormat.yolo),
      detectors: [det],
      classifier: classifier([1, 2, 3]),
    );

    pipeline.analyze(image);

    // A 40 by 20 image letterboxed into 8 pixels fills rows 2 to 5.
    final red = det.inputs.single;
    expect(red[0], closeTo(114 / 255, 1e-3));
    expect(red[4 * 8], closeTo(10 / 255, 0.02));
  });

  test('a video moment is cropped and embedded as a photo box is', () {
    final pipeline = OnnxPipeline(
      models: models(),
      detectors: [rfdetr(const [])],
      classifier: classifier([4, 5, 6]),
    );

    final crop = pipeline.cropAndEmbed(
      image,
      const IdentificationBox(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
    )!;

    expect(crop.pixelWidth, 20);
    expect(crop.pixelHeight, 10);
    expect(crop.embedding, Float32List.fromList([4, 5, 6]));
    expect(crop.cropJpeg.sublist(0, 2), [0xFF, 0xD8]);
  });

  test('detectFrame returns the merged boxes of a frame', () {
    final pipeline = OnnxPipeline(
      models: models(),
      detectors: [
        rfdetr([
          [0.5, 0.5, 0.5, 0.5, 0.9],
        ]),
      ],
      classifier: classifier([1, 2, 3]),
    );

    final boxes = pipeline.detectFrame(image);

    expect(boxes.single.score, closeTo(0.9, 1e-6));
  });

  test('converts a photo with a colour profile to sRGB before anything '
      'sees it', () {
    final p3 = uniform(40, 20, [200, 100, 50]);
    final photo = RgbaImage(
      40,
      20,
      p3.bytes,
      colour: srgbConversionOf(jpegWith(displayP3Profile())),
    );
    final det = rfdetr([
      [0.5, 0.5, 0.5, 0.5, 0.9],
    ]);
    final pipeline = OnnxPipeline(
      models: models(),
      detectors: [det],
      classifier: classifier([1, 2, 3]),
    );

    pipeline.analyze(photo);

    // The detector's mean is 0 and its std 1: its input is v / 255.
    final plane = 8 * 8, input = det.inputs.single;
    for (final (c, want) in [(0, 215), (1, 93), (2, 31)]) {
      expect(input[c * plane] * 255, closeTo(want, 1.01), reason: 'channel $c');
    }
  });
}
