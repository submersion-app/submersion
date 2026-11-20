import 'dart:convert';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';

/// One photo's result as a JSON line, in the format of the Swift vision tool
/// (`vision_cli/main.swift` in submersion-app/species-pack), so the pack's
/// scorer reads the ONNX engine's results as it reads Core ML's.
String scoringLine(
  String path,
  PipelineResult result, {
  required bool withDetectorBoxes,
}) {
  final detections = result.analysis.detections;
  // JSON has no NaN or infinity; such an embedding is the model failing.
  if (detections.any((d) => d.embedding.any((v) => !v.isFinite))) {
    return scoringErrorLine(
      path,
      'the classifier returned a value that is not a number',
    );
  }
  return jsonEncode({
    'path': path,
    'width': result.analysis.imageWidth,
    'height': result.analysis.imageHeight,
    'detections': [
      for (var i = 0; i < detections.length; i++)
        {
          'x': detections[i].x,
          'y': detections[i].y,
          'w': detections[i].width,
          'h': detections[i].height,
          'score': detections[i].score,
          'pixelWidth': detections[i].pixelWidth,
          'pixelHeight': detections[i].pixelHeight,
          'embedding': [for (final v in detections[i].embedding) v],
          'embedMs': i < result.embedMs.length ? result.embedMs[i] : null,
        },
    ],
    'detectMs': result.detectMs,
    if (withDetectorBoxes) ...{
      'detectorBoxes': [
        for (final run in result.detectorBoxes) [for (final b in run) _box(b)],
      ],
      'mergedBoxes': [for (final b in result.mergedBoxes) _box(b)],
    },
  });
}

/// A photo that could not be scored.
String scoringErrorLine(String path, String message) =>
    jsonEncode({'path': path, 'error': message});

Map<String, Object> _box(PipelineBox b) => {
  'x': b.x,
  'y': b.y,
  'w': b.w,
  'h': b.h,
  'score': b.score,
};
