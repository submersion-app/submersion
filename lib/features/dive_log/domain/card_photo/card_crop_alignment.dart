import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';
import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';

/// The vertical alignment (-1 top .. 1 bottom) for drawing a photo of
/// [imageAspect] (width / height) to cover a card of [cardAspect].
///
/// Covering a wide card keeps a horizontal strip of the photo; this decides
/// where that strip sits, in priority order:
///
/// 1. [focusBoxes] (tagged people, normalised 0..1): the strip centres on
///    the box around all of them, or keeps their top when they are taller
///    than the strip.
/// 2. [rowScores] (one interest score per image row, top to bottom): the
///    strip with the highest total, pulled gently toward the middle, when it
///    clearly beats the centred strip.
/// 3. Otherwise centred.
///
/// A photo at least as wide as the card loses nothing vertically and is
/// centred.
double cardCropAlignmentY({
  required double imageAspect,
  required double cardAspect,
  List<FocusBox> focusBoxes = const [],
  List<double>? rowScores,
}) {
  if (imageAspect <= 0 || cardAspect <= 0) return 0;
  if (imageAspect >= cardAspect) return 0;
  // The share of the photo's height the card shows, and how far the strip
  // can move.
  final strip = imageAspect / cardAspect;
  final slack = 1 - strip;
  if (slack <= 1e-9) return 0;

  if (focusBoxes.isNotEmpty) {
    return _alignForBoxes(focusBoxes, strip, slack);
  }
  if (rowScores != null) {
    return _alignForRows(rowScores, strip);
  }
  return 0;
}

double _alignForBoxes(List<FocusBox> boxes, double strip, double slack) {
  var top = double.infinity;
  var bottom = double.negativeInfinity;
  for (final b in boxes) {
    top = math.min(top, b.top);
    bottom = math.max(bottom, b.bottom);
  }
  final span = bottom - top;
  final stripTop = span <= strip ? (top + bottom) / 2 - strip / 2 : top;
  final clamped = stripTop.clamp(0.0, slack);
  return 2 * clamped / slack - 1;
}

double _alignForRows(List<double> rows, double strip) {
  final n = rows.length;
  if (n < 2) return 0;
  final k = (strip * n).round().clamp(1, n);
  final positions = n - k;
  if (positions <= 0) return 0;

  final prefix = List<double>.filled(n + 1, 0);
  for (var i = 0; i < n; i++) {
    prefix[i + 1] = prefix[i] + rows[i];
  }
  double windowAt(int i) => prefix[i + k] - prefix[i];

  final centre = (positions / 2).round();
  final centreScore = windowAt(centre);

  var best = centre;
  var bestWeighted = centreScore;
  for (var i = 0; i <= positions; i++) {
    final p = i / positions;
    final weight = 1 - CardPhotoTuning.centrePull * (2 * p - 1).abs();
    final weighted = windowAt(i) * weight;
    if (weighted > bestWeighted) {
      best = i;
      bestWeighted = weighted;
    }
  }

  if (bestWeighted <= 0) return 0;
  if (bestWeighted <= centreScore * (1 + CardPhotoTuning.minGainOverCentre)) {
    return 0;
  }
  return 2 * best / positions - 1;
}
