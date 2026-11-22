import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';

/// EXIF orientation 6: the stored image is shown turned a quarter turn
/// clockwise, as a phone held upright stores its photos.
const exifRotatedClockwise = 6;

/// A copy of the JPEG [jpeg] that says it is to be shown with EXIF
/// [orientation]: any EXIF block it had is dropped and a minimal one, with
/// only the orientation, is written after the JFIF header. The image data is
/// not touched, so the decoder turning it is all that changes.
Uint8List withExifOrientation(Uint8List jpeg, int orientation) {
  if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
    throw ArgumentError('not a JPEG');
  }
  final kept = BytesBuilder(copy: false);
  var insertAt = -1;
  var at = 2;
  while (at + 4 <= jpeg.length) {
    if (jpeg[at] != 0xFF) throw ArgumentError('a broken JPEG segment at $at');
    final marker = jpeg[at + 1];
    if (marker == 0xFF) {
      at++; // Fill byte.
      continue;
    }
    // Start of scan: the image data runs from here to the end, unchanged.
    if (marker == 0xDA) break;
    final length = (jpeg[at + 2] << 8) | jpeg[at + 3];
    final segment = Uint8List.sublistView(jpeg, at, at + 2 + length);
    final isExif =
        marker == 0xE1 &&
        length >= 8 &&
        String.fromCharCodes(segment.sublist(4, 8)) == 'Exif';
    if (!isExif) {
      kept.add(segment);
      // After the JFIF header when there is one, else first.
      if (marker == 0xE0 && insertAt < 0) insertAt = kept.length;
    }
    at += 2 + length;
  }
  final headers = kept.takeBytes();
  final split = insertAt < 0 ? 0 : insertAt;
  return Uint8List.fromList([
    0xFF, 0xD8, //
    ...headers.sublist(0, split),
    ..._exifOrientationSegment(orientation),
    ...headers.sublist(split),
    ...jpeg.sublist(at),
  ]);
}

/// An APP1 segment holding a big-endian TIFF header and one IFD with a
/// single entry: Orientation (0x0112), a SHORT.
List<int> _exifOrientationSegment(int orientation) {
  const tiff = [
    0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // MM, 42, IFD at 8
    0x00, 0x01, // One entry.
    0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, // Orientation, SHORT, 1
  ];
  final payload = [
    ...'Exif'.codeUnits, 0x00, 0x00, //
    ...tiff,
    0x00, orientation, 0x00, 0x00, // The value, left-justified.
    0x00, 0x00, 0x00, 0x00, // No next IFD.
  ];
  final length = payload.length + 2;
  return [0xFF, 0xE1, length >> 8, length & 0xFF, ...payload];
}

/// Where [box], normalised against an image, lands once that image is
/// turned a quarter turn clockwise: a point (u, v) moves to (1 - v, u).
IdentificationBox turnedClockwise(IdentificationBox box) => IdentificationBox(
  x: 1 - box.y - box.height,
  y: box.x,
  width: box.height,
  height: box.width,
);

IdentificationBox boxOf(VisionDetection d) =>
    IdentificationBox(x: d.x, y: d.y, width: d.width, height: d.height);

/// How closely the closest of [candidates] matches [box]: its overlap, and
/// the largest distance between matching edges, both normalised.
({double iou, double edge}) closestMatch(
  IdentificationBox box,
  List<IdentificationBox> candidates,
) {
  var bestIou = 0.0;
  var bestEdge = double.infinity;
  for (final c in candidates) {
    final iou = box.iou(c);
    if (iou <= bestIou) continue;
    bestIou = iou;
    bestEdge = [
      (box.x - c.x).abs(),
      (box.y - c.y).abs(),
      (box.x + box.width - c.x - c.width).abs(),
      (box.y + box.height - c.y - c.height).abs(),
    ].reduce(math.max);
  }
  return (iou: bestIou, edge: bestEdge);
}

String describeBox(IdentificationBox b) =>
    '(${_f(b.x)}, ${_f(b.y)}, ${_f(b.width)} x ${_f(b.height)})';

/// [analysis]'s detections in a line each.
List<String> describeAnalysis(VisionAnalysis analysis) => [
  '${analysis.imageWidth} x ${analysis.imageHeight}, '
      '${analysis.detections.length} detections',
  for (final d in analysis.detections)
    '  score ${_f(d.score)} box ${describeBox(boxOf(d))} '
        '${d.pixelWidth} x ${d.pixelHeight} px, '
        'embedding ${d.embedding.length}, crop ${d.cropJpeg.length} bytes',
];

String _f(double v) => v.toStringAsFixed(3);

/// A JPEG that shows exactly as [jpeg] does but is stored the other way
/// round, as a phone held upright stores its photos: the pixels turned a
/// quarter turn anticlockwise, saved at full quality, with EXIF
/// orientation 6 to turn them back. Analysed, it must give [jpeg]'s own
/// image size and boxes; were the orientation ignored, the image would come
/// out taller than wide, with the boxes elsewhere.
Uint8List storedTurnedJpeg(Uint8List jpeg) {
  final image = img.decodeJpg(jpeg) ?? (throw ArgumentError('not a JPEG'));
  final turned = img.copyRotate(image, angle: 270);
  return withExifOrientation(
    img.encodeJpg(turned, quality: 100),
    exifRotatedClockwise,
  );
}

/// A detection this sure is expected to come back from the same pixels.
const confidentScore = 0.5;

/// How closely a box must come back from the same pixels stored the other
/// way round: only the JPEG's rounding differs.
const sameBoxMinIou = 0.9;
const sameBoxMaxEdge = 0.02;
