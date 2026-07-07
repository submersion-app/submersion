import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Fuzzy-match an OCR-extracted site name against existing sites.
/// Returns the best match at/above [threshold], else null — the caller
/// then routes the raw name to the notes appendix instead.
DiveSite? resolveSiteByName(
  String extractedName,
  List<DiveSite> candidates, {
  double threshold = 0.75,
}) {
  final query = normalize(extractedName);
  if (query.isEmpty) return null;
  DiveSite? best;
  var bestScore = 0.0;
  for (final site in candidates) {
    final score = diceCoefficient(query, normalize(site.name));
    if (score > bestScore) {
      bestScore = score;
      best = site;
    }
  }
  return bestScore >= threshold ? best : null;
}
