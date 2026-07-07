import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/label_definitions.dart';

class LabelMatch {
  final LogField field;
  final OcrTextBlock block;

  const LabelMatch(this.field, this.block);
}

/// Find all label blocks. Stop-list guards run first so that
/// "Certification No." can never become a dive-number label.
List<LabelMatch> findLabels(List<OcrTextBlock> blocks) {
  final matches = <LabelMatch>[];
  for (final block in blocks) {
    final text = block.text.trim();
    if (labelStopList.any((re) => re.hasMatch(text))) continue;
    for (final def in labelDefinitions) {
      if (def.pattern.hasMatch(text)) {
        matches.add(LabelMatch(def.field, block));
        break; // first (most specific, list-ordered) definition wins
      }
    }
  }
  return matches;
}

/// Bind the value block for [label]: nearest non-label block right-of,
/// below, or above, within a threshold scaled to the label's text height.
OcrTextBlock? bindValue(
  LabelMatch label,
  List<OcrTextBlock> blocks, {
  required Set<OcrTextBlock> labelBlocks,
}) {
  final l = label.block;
  final h = l.height;
  OcrTextBlock? best;
  var bestScore = double.infinity;

  for (final candidate in blocks) {
    if (identical(candidate, l) || labelBlocks.contains(candidate)) continue;
    if (candidate.text.trim().isEmpty) continue;

    final dx = candidate.center.dx - l.center.dx;
    final dy = candidate.center.dy - l.center.dy;
    // Right-of uses the edge gap, not center distance: a wide value block
    // ("Pinnacle, Sodwana Bay") starts right next to the label even though
    // its center is far away.
    final gap = candidate.boundingBox.left - l.boundingBox.right;

    // Short-range left-of: some templates write the value immediately
    // before the label ("24 Air" on temperature scales).
    final leftGap = l.boundingBox.left - candidate.boundingBox.right;

    double score;
    if (gap > -h && gap < 12 * h && dy.abs() < 1.5 * h) {
      score = gap.abs(); // right-of: strongly preferred
    } else if (leftGap > -h && leftGap < 3 * h && dy.abs() < 1.5 * h) {
      score = h + leftGap.abs(); // left-of: close range only
    } else if (dy > 0 && dy < 3 * h && dx.abs() < 6 * h) {
      score = 2 * h + dy + dx.abs(); // below
    } else if (dy < 0 && dy > -3 * h && dx.abs() < 6 * h) {
      score = 3 * h - dy + dx.abs(); // above (PADI Z-diagram)
    } else {
      continue;
    }

    if (score < bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}
