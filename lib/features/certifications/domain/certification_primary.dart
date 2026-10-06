import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// The "primary" certification for a set — the highest by the agency ladder.
///
/// Rank = [CertificationCatalog.rankOf]: the level's index in the agency's
/// built-in ladder, with the agency's custom progression rungs ranked after
/// it (issue #690). A null level, a specialty or an unknown id ranks -1
/// (below any ladder cert). [catalog] defaults to built-ins only. Ties
/// break by latest issue date, then most recently updated. Returns null only
/// for an empty list.
///
/// Cross-agency note: ladder indices are compared directly (best effort) when
/// certs come from different agencies — see the #553 design's non-goals.
Certification? primaryCertification(
  List<Certification> certs, {
  CertificationCatalog? catalog,
}) {
  if (certs.isEmpty) return null;
  final c = catalog ?? CertificationCatalog.builtInOnly;

  int rank(Certification cert) => c.rankOf(cert.agency, cert.level);

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
