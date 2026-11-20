import 'dart:math' as math;
import 'dart:typed_data';

/// Reading the detectors' raw outputs into boxes, and merging two
/// detectors' boxes: ports of `detect`, `detectYolo`, `letterboxRect`,
/// `suppress`, `merge` and `overlap` in the Swift pipeline
/// (`packages/submersion_vision/darwin/Classes/VisionPipeline.swift`). The
/// pack's bars were measured on that pipeline's boxes, so these must agree
/// with it, and the merge with `boxes.py` in submersion-app/species-pack.
/// No Flutter import: the pipeline runs in a worker isolate.

/// IoU at or above which YOLO's own overlapping boxes are one animal.
const double yoloSuppressIoU = 0.7;

/// The grey YOLO models are trained with around a letterboxed image.
const int letterboxGrey = 114;

/// One box, normalised 0 to 1 against the image, with its score.
class PipelineBox {
  const PipelineBox(this.x, this.y, this.w, this.h, this.score);

  final double x;
  final double y;
  final double w;
  final double h;
  final double score;

  @override
  bool operator ==(Object other) =>
      other is PipelineBox &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h &&
      other.score == score;

  @override
  int get hashCode => Object.hash(x, y, w, h, score);

  @override
  String toString() => 'PipelineBox($x, $y, $w, $h, $score)';
}

/// A rectangle in pixels of a square canvas, origin top-left.
typedef PixelRect = ({double left, double top, double width, double height});

/// Where an image goes in a letterboxed square, as ultralytics places it:
/// scaled to fit and rounded to whole pixels, centred.
PixelRect letterboxRect(int width, int height, int size) {
  final r = math.min(size / width, size / height);
  final w = (width * r).roundToDouble();
  final h = (height * r).roundToDouble();
  return (
    left: ((size - w) / 2 - 0.1).roundToDouble(),
    top: ((size - h) / 2 - 0.1).roundToDouble(),
    width: w,
    height: h,
  );
}

/// RF-DETR's boxes: [boxes] holds each query's centre x, centre y, width
/// and height, normalised; [logits] each query's raw class scores. A query
/// scores the sigmoid of its best logit. Boxes at or over [scoreThreshold]
/// are clamped to the image, best first, at most [maxBoxes].
List<PipelineBox> readRfdetr({
  required Float32List boxes,
  required Float32List logits,
  required int queries,
  required int classes,
  required double scoreThreshold,
  required int maxBoxes,
}) {
  final threshold = _float32(scoreThreshold);
  final found = <PipelineBox>[];
  for (var q = 0; q < queries; q++) {
    var best = double.negativeInfinity;
    for (var c = 0; c < classes; c++) {
      best = math.max(best, logits[q * classes + c]);
    }
    final score = _float32(1 / (1 + math.exp(-best)));
    // Written so NaN, which no comparison passes, is dropped too.
    if (!(score >= threshold)) continue;
    final cx = boxes[q * 4], cy = boxes[q * 4 + 1];
    final w = boxes[q * 4 + 2], h = boxes[q * 4 + 3];
    final box = _clamped(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, score);
    if (box != null) found.add(box);
  }
  return _bestFirst(found).take(maxBoxes).toList();
}

/// YOLO's boxes: [output] is `[1, channels, anchors]`, channel-major: the
/// centre and size in letterbox pixels, then one already squashed score
/// per class. Boxes are taken out of [letterbox] into the image's 0 to 1,
/// then overlapping ones suppressed at [yoloSuppressIoU], at most
/// [maxBoxes].
List<PipelineBox> readYolo({
  required Float32List output,
  required int channels,
  required int anchors,
  required PixelRect letterbox,
  required int imageWidth,
  required int imageHeight,
  required double scoreThreshold,
  required int maxBoxes,
}) {
  final threshold = _float32(scoreThreshold);
  final sx = letterbox.width / imageWidth;
  final sy = letterbox.height / imageHeight;
  double toX(double px) => (px - letterbox.left) / sx / imageWidth;
  double toY(double py) => (py - letterbox.top) / sy / imageHeight;
  final found = <PipelineBox>[];
  for (var a = 0; a < anchors; a++) {
    var score = 0.0;
    for (var c = 4; c < channels; c++) {
      score = math.max(score, output[c * anchors + a]);
    }
    if (!(score >= threshold)) continue;
    final cx = output[a], cy = output[anchors + a];
    final w = output[2 * anchors + a], h = output[3 * anchors + a];
    final box = _clamped(
      toX(cx - w / 2),
      toY(cy - h / 2),
      toX(cx + w / 2),
      toY(cy + h / 2),
      score,
    );
    if (box != null) found.add(box);
  }
  return suppress(found, iou: yoloSuppressIoU, limit: maxBoxes);
}

/// The best boxes, dropping any that overlaps a better one by [iou] or
/// more, at most [limit].
List<PipelineBox> suppress(
  List<PipelineBox> boxes, {
  required double iou,
  required int limit,
}) {
  final kept = <PipelineBox>[];
  for (final box in _bestFirst(boxes)) {
    if (kept.length >= limit) break;
    if (!kept.any((k) => overlap(box, k) >= iou)) kept.add(box);
  }
  return kept;
}

/// Several detectors' boxes as one set, as the accuracy scorer merged them:
/// all boxes pooled in run order, best score first (equal scores keep pool
/// order), each dropped if it overlaps a kept box by [iou] or more, at most
/// [limit].
List<PipelineBox> mergeRuns(
  List<List<PipelineBox>> runs, {
  required double iou,
  required int limit,
}) {
  final kept = <PipelineBox>[];
  for (final box in _bestFirst([for (final run in runs) ...run])) {
    if (kept.length >= limit) break;
    if (kept.every((k) => overlap(box, k) < iou)) kept.add(box);
  }
  return kept;
}

/// Intersection over union, computed as `boxes.py` does, so a merge decided
/// at the threshold goes the same way.
double overlap(PipelineBox a, PipelineBox b) {
  final ix = math.max(0.0, math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x));
  final iy = math.max(0.0, math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y));
  final inter = ix * iy;
  final union = a.w * a.h + b.w * b.h - inter;
  return union > 0 ? inter / union : 0;
}

/// [boxes] best score first; equal scores keep their order, as Swift's
/// stable sort and Python's do.
List<PipelineBox> _bestFirst(List<PipelineBox> boxes) {
  final order = List.generate(boxes.length, (i) => i)
    ..sort((a, b) {
      final byScore = boxes[b].score.compareTo(boxes[a].score);
      return byScore != 0 ? byScore : a.compareTo(b);
    });
  return [for (final i in order) boxes[i]];
}

/// A box from its corners, clamped to 0..1; null when nothing is left.
PipelineBox? _clamped(
  double x0,
  double y0,
  double x1,
  double y1,
  double score,
) {
  final left = x0.clamp(0.0, 1.0), top = y0.clamp(0.0, 1.0);
  final right = x1.clamp(0.0, 1.0), bottom = y1.clamp(0.0, 1.0);
  if (right <= left || bottom <= top) return null;
  return PipelineBox(left, top, right - left, bottom - top, score);
}

final _narrow = Float32List(1);

/// [value] as a 32-bit float, as the Swift pipeline keeps scores.
double _float32(double value) => (_narrow..[0] = value)[0];
