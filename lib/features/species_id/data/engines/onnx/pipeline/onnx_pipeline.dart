import 'dart:typed_data';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// One output of a model: its shape and its values.
class ModelOutput {
  const ModelOutput(this.shape, this.data);

  final List<int> shape;
  final Float32List data;
}

/// A loaded model: runs one float32 input and returns every output in
/// order. ONNX Runtime in the app; a fake in tests.
abstract interface class ModelRunner {
  List<ModelOutput> run(Float32List input, List<int> shape);
}

/// What [OnnxPipeline.analyze] found, with what the accuracy scorer reads
/// besides: each detector's own boxes, the merged boxes, and timings.
class PipelineResult {
  const PipelineResult({
    required this.analysis,
    required this.detectorBoxes,
    required this.mergedBoxes,
    required this.detectMs,
    required this.embedMs,
  });

  final VisionAnalysis analysis;
  final List<List<PipelineBox>> detectorBoxes;
  final List<PipelineBox> mergedBoxes;
  final double detectMs;

  /// One entry per detection, in order.
  final List<double> embedMs;
}

/// Finds the animals in an image, crops and embeds each one: the Swift
/// pipeline's `analyze`, `detectBoxes` and `cropAndEmbed`, run over any
/// [ModelRunner]s. Not safe to use from two isolates at once.
class OnnxPipeline {
  OnnxPipeline({
    required this.models,
    required List<ModelRunner> detectors,
    required ModelRunner classifier,
  }) : _detectors = detectors,
       _classifier = classifier {
    if (detectors.length != models.detectors.length) {
      throw ArgumentError.value(
        detectors,
        'detectors',
        'one runner for each of the ${models.detectors.length} detectors',
      );
    }
  }

  final VisionModels models;
  final List<ModelRunner> _detectors;
  final ModelRunner _classifier;

  /// Detects, crops and embeds, in sRGB ([inSrgb]: a photo's own colour
  /// profile applied first). A box too small to crop is left out.
  PipelineResult analyze(RgbaImage photo) {
    final image = inSrgb(photo);
    final detectWatch = Stopwatch()..start();
    final runs = _detectEach(image);
    final boxes = _combined(runs);
    final detectMs = detectWatch.elapsedMicroseconds / 1000;
    final detections = <VisionDetection>[];
    final embedMs = <double>[];
    for (final box in boxes) {
      final watch = Stopwatch()..start();
      final crop = _cropAndEmbed(image, box.x, box.y, box.w, box.h);
      if (crop == null) continue;
      embedMs.add(watch.elapsedMicroseconds / 1000);
      detections.add(
        VisionDetection(
          x: box.x,
          y: box.y,
          width: box.w,
          height: box.h,
          score: box.score,
          pixelWidth: crop.pixelWidth,
          pixelHeight: crop.pixelHeight,
          cropJpeg: crop.cropJpeg,
          embedding: crop.embedding,
        ),
      );
    }
    return PipelineResult(
      analysis: VisionAnalysis(
        imageWidth: image.width,
        imageHeight: image.height,
        detections: detections,
      ),
      detectorBoxes: runs,
      mergedBoxes: boxes,
      detectMs: detectMs,
      embedMs: embedMs,
    );
  }

  /// The detectors over a video frame, merged when there are two.
  List<PipelineBox> detectFrame(RgbaImage frame) =>
      _combined(_detectEach(frame));

  /// [box] of a video frame [image] cropped and embedded; null when too
  /// small to crop. A small box takes more of its surroundings than a
  /// photo's box does ([VisionModels.momentPadding], issue #4882).
  VisionMomentCrop? cropAndEmbed(RgbaImage image, IdentificationBox box) =>
      _cropAndEmbed(
        image,
        box.x,
        box.y,
        box.width,
        box.height,
        padding: models.momentPadding(
          boxWidth: box.width * image.width,
          boxHeight: box.height * image.height,
        ),
      );

  List<List<PipelineBox>> _detectEach(RgbaImage image) {
    final inputs = _detectorInputs(image);
    return [
      for (var i = 0; i < _detectors.length; i++)
        _detect(image, inputs[i], models.detectors[i], _detectors[i]),
    ];
  }

  /// Every detector's input drawn before any model runs, from one drawer:
  /// the square and the letterbox share most of their resampling, and the
  /// shared work is let go before inference.
  List<RgbaImage> _detectorInputs(RgbaImage image) {
    final drawer = CanvasDrawer(image);
    return [
      for (final detector in models.detectors)
        detector.format == DetectorFormat.yolo
            ? drawer.draw(
                letterboxRect(image.width, image.height, detector.inputSize),
                canvas: detector.inputSize,
                fill: const [
                  letterboxGrey / 255,
                  letterboxGrey / 255,
                  letterboxGrey / 255,
                ],
              )
            // Resized straight to the square input, no letterbox, as the
            // detector was trained.
            : drawer.draw((
                left: 0,
                top: 0,
                width: detector.inputSize.toDouble(),
                height: detector.inputSize.toDouble(),
              ), canvas: detector.inputSize),
    ];
  }

  /// One detector's boxes as they are; two detectors' merged.
  List<PipelineBox> _combined(List<List<PipelineBox>> runs) => runs.length == 1
      ? runs.single
      : mergeRuns(runs, iou: models.mergeIoU, limit: models.maxBoxes);

  List<PipelineBox> _detect(
    RgbaImage image,
    RgbaImage square,
    VisionDetector detector,
    ModelRunner runner,
  ) {
    final size = detector.inputSize;
    final shape = [1, 3, size, size];
    if (detector.format == DetectorFormat.yolo) {
      final rect = letterboxRect(image.width, image.height, size);
      final outputs = runner.run(_tensor(square, detector), shape);
      final output = outputs.where((o) => o.shape.length == 3).firstOrNull;
      if (output == null) {
        throw const VisionEngineException(
          'inference_failed',
          'detector output not found',
        );
      }
      final channels = output.shape[1], anchors = output.shape[2];
      if (channels < 5 || output.data.length < channels * anchors) {
        throw const VisionEngineException(
          'inference_failed',
          'detector output has an unexpected shape',
        );
      }
      return readYolo(
        output: output.data,
        channels: channels,
        anchors: anchors,
        letterbox: rect,
        imageWidth: image.width,
        imageHeight: image.height,
        scoreThreshold: detector.scoreThreshold,
        maxBoxes: detector.maxBoxes,
      );
    }
    final outputs = runner.run(_tensor(square, detector), shape);
    ModelOutput? boxes, scores;
    for (final output in outputs) {
      if (output.shape.length != 3) continue;
      if (output.shape[2] == 4) {
        boxes = output;
      } else {
        scores = output;
      }
    }
    if (boxes == null || scores == null) {
      throw const VisionEngineException(
        'inference_failed',
        'detector outputs not found',
      );
    }
    final queries = boxes.shape[1], classes = scores.shape[2];
    // A model whose two outputs disagree would read past the end.
    if (classes <= 0 ||
        scores.shape[1] != queries ||
        boxes.data.length < queries * 4 ||
        scores.data.length < queries * classes) {
      throw const VisionEngineException(
        'inference_failed',
        'detector outputs do not match',
      );
    }
    return readRfdetr(
      boxes: boxes.data,
      logits: scores.data,
      queries: queries,
      classes: classes,
      scoreThreshold: detector.scoreThreshold,
      maxBoxes: detector.maxBoxes,
    );
  }

  Float32List _tensor(RgbaImage square, VisionDetector detector) =>
      toTensor(square, mean: detector.mean, std: detector.std);

  VisionMomentCrop? _cropAndEmbed(
    RgbaImage image,
    double x,
    double y,
    double w,
    double h, {
    double? padding,
  }) {
    final rect = paddedCrop(
      imageWidth: image.width,
      imageHeight: image.height,
      x: x,
      y: y,
      w: w,
      h: h,
      padding: padding ?? models.cropPadding,
    );
    if (rect == null) return null;
    final crop = cropOf(image, rect);
    return VisionMomentCrop(
      pixelWidth: (w * image.width).round(),
      pixelHeight: (h * image.height).round(),
      cropJpeg: jpegOf(fittedWithin(crop, models.cropThumbnailSize)),
      embedding: _embed(crop),
    );
  }

  Float32List _embed(RgbaImage crop) {
    final size = models.classifierInputSize;
    final rect = fitRect(crop.width, crop.height, size, models.cropFit);
    final square = drawInto(
      crop,
      rect,
      canvas: size,
      fill: models.classifierMean,
    );
    final input = toTensor(
      square,
      mean: models.classifierMean,
      std: models.classifierStd,
    );
    final outputs = _classifier.run(input, [1, 3, size, size]);
    if (outputs.isEmpty) {
      throw const VisionEngineException(
        'inference_failed',
        'classifier output not found',
      );
    }
    final values = outputs.first.data;
    if (values.length != models.embeddingSize) {
      throw VisionEngineException(
        'inference_failed',
        'embedding has ${values.length} values, '
            'expected ${models.embeddingSize}',
      );
    }
    return Float32List.fromList(values);
  }
}
