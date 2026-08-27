import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// The "primary" certification for a set — the highest by the agency ladder.
///
/// Rank = the level's index in `CertificationLevelCatalog.ladderFor(agency)`;
/// a null level, or a specialty not on that agency's ladder, ranks -1 (below
/// any core-ladder cert). Ties break by latest issue date, then most recently
/// updated. Returns null only for an empty list.
///
/// Cross-agency note: ladder indices are compared directly (best effort) when
/// certs come from different agencies — see the #553 design's non-goals.
Certification? primaryCertification(List<Certification> certs) {
  if (certs.isEmpty) return null;

  int rank(Certification c) {
    final level = c.level;
    if (level == null) return -1;
    return CertificationLevelCatalog.ladderFor(c.agency).indexOf(level);
  }

  final sorted = [...certs]
    ..sort((a, b) {
      final byRank = rank(b).compareTo(rank(a));
      if (byRank != 0) return byRank;
      final ai = a.issueDate;
      final bi = b.issueDate;
      if (ai != null && bi != null && ai != bi) return bi.compareTo(ai);
      if (ai != null && bi == null) return -1;
      if (ai == null && bi != null) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  return sorted.first;
}
