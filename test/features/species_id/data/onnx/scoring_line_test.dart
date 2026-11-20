import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/scoring_line.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';

/// The scorer in submersion-app/species-pack reads these lines as it reads
/// `vision_cli/main.swift`'s, so the fields must be the same.
void main() {
  PipelineResult result({List<double> embedding = const [0.5, -0.25]}) =>
      PipelineResult(
        analysis: VisionAnalysis(
          imageWidth: 400,
          imageHeight: 300,
          detections: [
            VisionDetection(
              x: 0.1,
              y: 0.2,
              width: 0.3,
              height: 0.4,
              score: 0.9,
              pixelWidth: 120,
              pixelHeight: 120,
              cropJpeg: Uint8List(3),
              embedding: Float32List.fromList(embedding),
            ),
          ],
        ),
        detectorBoxes: const [
          [PipelineBox(0.1, 0.2, 0.3, 0.4, 0.9)],
          [PipelineBox(0.5, 0.5, 0.1, 0.1, 0.4)],
        ],
        mergedBoxes: const [PipelineBox(0.1, 0.2, 0.3, 0.4, 0.9)],
        detectMs: 12.5,
        embedMs: const [3.25],
      );

  test('a photo is the vision tool\'s line', () {
    final line =
        jsonDecode(
              scoringLine('/set/a.jpg', result(), withDetectorBoxes: false),
            )
            as Map<String, Object?>;

    expect(line.keys, ['path', 'width', 'height', 'detections', 'detectMs']);
    expect(line['path'], '/set/a.jpg');
    expect((line['width'], line['height']), (400, 300));
    expect(line['detectMs'], 12.5);
    final d = (line['detections']! as List).single as Map<String, Object?>;
    expect(d.keys, [
      'x',
      'y',
      'w',
      'h',
      'score',
      'pixelWidth',
      'pixelHeight',
      'embedding',
      'embedMs',
    ]);
    expect((d['x'], d['y'], d['w'], d['h']), (0.1, 0.2, 0.3, 0.4));
    expect(d['embedding'], [0.5, -0.25]);
    expect(d['embedMs'], 3.25);
  });

  test('each detector\'s boxes and the merge come when asked', () {
    final line =
        jsonDecode(scoringLine('/set/a.jpg', result(), withDetectorBoxes: true))
            as Map<String, Object?>;

    final perDetector = line['detectorBoxes']! as List;
    expect(perDetector, hasLength(2));
    expect((perDetector[1] as List).single, {
      'x': 0.5,
      'y': 0.5,
      'w': 0.1,
      'h': 0.1,
      'score': 0.4,
    });
    expect((line['mergedBoxes']! as List).single, containsPair('score', 0.9));
  });

  test('an embedding that is not a number is an error line', () {
    final line =
        jsonDecode(
              scoringLine(
                '/set/a.jpg',
                result(embedding: [double.nan, 1]),
                withDetectorBoxes: false,
              ),
            )
            as Map<String, Object?>;

    expect(line, {
      'path': '/set/a.jpg',
      'error': 'the classifier returned a value that is not a number',
    });
  });

  test('a failure is an error line', () {
    expect(jsonDecode(scoringErrorLine('/set/b.jpg', 'unreadable')), {
      'path': '/set/b.jpg',
      'error': 'unreadable',
    });
  });
}
