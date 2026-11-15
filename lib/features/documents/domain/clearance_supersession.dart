import 'package:submersion/features/documents/domain/entities/document.dart';

/// The medical clearances in [documents] that a later clearance of the same
/// diver supersedes (issue #4541): every dated clearance but the one that
/// expires last. A diver keeps older certificates as an archive, and only
/// the current one should warn as it runs out, the same clearance the diver
/// profile shows (DocumentRepository.latestClearanceExpiryByDiver).
///
/// A tie on expiry keeps the later issued, then the later created, then
/// the higher id, so exactly one clearance per diver stays current.
/// Undated clearances never remind, so they take no part.
Set<String> supersededClearanceIds(Iterable<Document> documents) {
  final current = <String, Document>{};
  final dated = [
    for (final d in documents)
      if (d.type == DocumentType.medicalClearance && d.expiryDate != null) d,
  ];
  for (final d in dated) {
    final best = current[d.diverId];
    if (best == null || _isLater(d, best)) current[d.diverId] = d;
  }
  return {
    for (final d in dated)
      if (current[d.diverId]!.id != d.id) d.id,
  };
}

/// [documents] without the clearances [supersededClearanceIds] names, in
/// their order.
List<Document> withoutSupersededClearances(List<Document> documents) {
  final superseded = supersededClearanceIds(documents);
  if (superseded.isEmpty) return documents;
  return [
    for (final d in documents)
      if (!superseded.contains(d.id)) d,
  ];
}

bool _isLater(Document a, Document b) {
  final byExpiry = a.expiryDate!.compareTo(b.expiryDate!);
  if (byExpiry != 0) return byExpiry > 0;
  final byIssue = _compareNullable(a.issueDate, b.issueDate);
  if (byIssue != 0) return byIssue > 0;
  final byCreated = a.createdAt.compareTo(b.createdAt);
  if (byCreated != 0) return byCreated > 0;
  return a.id.compareTo(b.id) > 0;
}

/// A missing date sorts before any date.
int _compareNullable(DateTime? a, DateTime? b) => switch ((a, b)) {
  (null, null) => 0,
  (null, _) => -1,
  (_, null) => 1,
  (final x?, final y?) => x.compareTo(y),
};
