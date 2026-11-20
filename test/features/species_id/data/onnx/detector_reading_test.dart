import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';

void main() {
  void expectBox(PipelineBox box, List<double> want, {double tol = 1e-6}) {
    expect(box.x, closeTo(want[0], tol), reason: 'x of $box');
    expect(box.y, closeTo(want[1], tol), reason: 'y of $box');
    expect(box.w, closeTo(want[2], tol), reason: 'w of $box');
    expect(box.h, closeTo(want[3], tol), reason: 'h of $box');
    expect(box.score, closeTo(want[4], tol), reason: 'score of $box');
  }

  double logit(double p) => math.log(p / (1 - p));

  group('letterboxRect', () {
    test('places a landscape image as ultralytics does', () {
      final r = letterboxRect(1920, 1080, 640);
      expect(r.left, 0);
      expect(r.top, 140);
      expect(r.width, 640);
      expect(r.height, 360);
    });

    test('places a portrait image as ultralytics does', () {
      final r = letterboxRect(1080, 1920, 640);
      expect(r.left, 140);
      expect(r.top, 0);
      expect(r.width, 360);
      expect(r.height, 640);
    });
  });

  group('readRfdetr', () {
    // Each query: centre x, centre y, width, height (normalised), then its
    // probability, given to the reader as a logit.
    List<PipelineBox> read(
      List<(List<double>, List<double>)> queries, {
      double threshold = 0.3,
      int maxBoxes = 8,
    }) {
      final classes = queries.first.$2.length;
      return readRfdetr(
        boxes: Float32List.fromList([for (final q in queries) ...q.$1]),
        logits: Float32List.fromList([
          for (final q in queries) ...q.$2.map(logit),
        ]),
        queries: queries.length,
        classes: classes,
        scoreThreshold: threshold,
        maxBoxes: maxBoxes,
      );
    }

    test(
      'keeps boxes over the threshold, best first, clamped to the image',
      () {
        final boxes = read([
          ([0.5, 0.5, 0.2, 0.2], [0.5]),
          ([0.5, 0.5, 0.4, 0.4], [0.2]),
          ([0.95, 0.5, 0.2, 0.2], [0.9]),
        ]);
        expect(boxes, hasLength(2));
        expectBox(boxes[0], [0.85, 0.4, 0.15, 0.2, 0.9]);
        expectBox(boxes[1], [0.4, 0.4, 0.2, 0.2, 0.5]);
      },
    );

    test('drops a box with no area once clamped', () {
      expect(
        read([
          ([1.2, 0.5, 0.2, 0.2], [0.9]),
        ]),
        isEmpty,
      );
    });

    test('a query scored NaN is no box', () {
      expect(
        read([
          ([0.5, 0.5, 0.2, 0.2], [double.nan]),
        ]),
        isEmpty,
      );
    });

    test('scores a query by its best class', () {
      final boxes = read([
        ([0.5, 0.5, 0.2, 0.2], [0.1, 0.8]),
      ]);
      expectBox(boxes.single, [0.4, 0.4, 0.2, 0.2, 0.8]);
    });

    test('keeps at most maxBoxes', () {
      final boxes = read([
        ([0.2, 0.2, 0.1, 0.1], [0.6]),
        ([0.7, 0.7, 0.1, 0.1], [0.9]),
      ], maxBoxes: 1);
      expectBox(boxes.single, [0.65, 0.65, 0.1, 0.1, 0.9]);
    });

    test('scores are 32-bit, as the Swift pipeline keeps them', () {
      final box = read([
        ([0.5, 0.5, 0.2, 0.2], [0.9]),
      ]).single;
      final narrowed = (Float32List(1)..[0] = box.score)[0];
      expect(box.score, narrowed);
    });
  });

  group('readYolo', () {
    const imageWidth = 1920, imageHeight = 1080, size = 640;
    final rect = letterboxRect(imageWidth, imageHeight, size);
    final sx = rect.width / imageWidth, sy = rect.height / imageHeight;

    // A box normalised to the image, as the model would report it: centre
    // and size in letterbox pixels.
    List<double> inLetterbox(List<double> b) {
      final x = b[0] * imageWidth, y = b[1] * imageHeight;
      final w = b[2] * imageWidth, h = b[3] * imageHeight;
      return [
        (x + w / 2) * sx + rect.left,
        (y + h / 2) * sy + rect.top,
        w * sx,
        h * sy,
      ];
    }

    List<PipelineBox> read(List<(List<double>, double)> anchors) {
      const channels = 5;
      final n = anchors.length;
      final out = Float32List(channels * n);
      for (var a = 0; a < n; a++) {
        final v = [...inLetterbox(anchors[a].$1), anchors[a].$2];
        for (var c = 0; c < channels; c++) {
          out[c * n + a] = v[c];
        }
      }
      return readYolo(
        output: out,
        channels: channels,
        anchors: n,
        letterbox: rect,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        scoreThreshold: 0.25,
        maxBoxes: 8,
      );
    }

    test('an anchor scored NaN is no box', () {
      expect(
        read([
          ([0.4, 0.4, 0.2, 0.2], double.nan),
        ]),
        isEmpty,
      );
    });

    test('takes a box out of the letterbox into the image', () {
      final boxes = read([
        ([0.25, 0.25, 0.1, 0.2], 0.8),
      ]);
      expectBox(boxes.single, [0.25, 0.25, 0.1, 0.2, 0.8], tol: 1e-5);
    });

    test('drops scores under the threshold and suppresses overlaps', () {
      final boxes = read([
        ([0.25, 0.25, 0.1, 0.2], 0.8),
        ([0.251, 0.25, 0.1, 0.2], 0.7),
        ([0.6, 0.6, 0.1, 0.1], 0.1),
        ([0.7, 0.1, 0.1, 0.1], 0.5),
      ]);
      expect(boxes, hasLength(2));
      expectBox(boxes[0], [0.25, 0.25, 0.1, 0.2, 0.8], tol: 1e-5);
      expectBox(boxes[1], [0.7, 0.1, 0.1, 0.1, 0.5], tol: 1e-5);
    });
  });

  group('suppress', () {
    test('keeps the best of boxes overlapping at the threshold or more', () {
      const a = PipelineBox(0.0, 0.0, 0.5, 0.5, 0.6);
      const b = PipelineBox(0.0, 0.0, 0.5, 0.5, 0.9);
      const c = PipelineBox(0.6, 0.6, 0.2, 0.2, 0.3);
      expect(suppress([a, b, c], iou: yoloSuppressIoU, limit: 8), [b, c]);
      expect(suppress([a, b, c], iou: yoloSuppressIoU, limit: 1), [b]);
    });
  });

  group('overlap', () {
    test('of identical boxes is 1', () {
      const a = PipelineBox(0.1, 0.1, 0.2, 0.2, 1);
      expect(overlap(a, a), closeTo(1, 1e-12));
    });

    test('of disjoint boxes is 0', () {
      expect(
        overlap(
          const PipelineBox(0, 0, 0.1, 0.1, 1),
          const PipelineBox(0.5, 0.5, 0.1, 0.1, 1),
        ),
        0,
      );
    });

    test('of two empty boxes is 0', () {
      const empty = PipelineBox(0.3, 0.3, 0, 0, 1);
      expect(overlap(empty, empty), 0);
    });
  });
}
