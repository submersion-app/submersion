import 'package:submersion/features/documents/domain/entities/document.dart';

/// Whose medical clearance a document is: the diver's own, or the buddy's
/// it is filed under (an instructor's student, say). A holder's clearances
/// supersede only one another, so a buddy's renewal never silences the
/// diver's own clearance, nor another buddy's.
typedef ClearanceHolder = ({String diverId, String? buddyId});

ClearanceHolder clearanceHolder(Document d) => (
  diverId: d.diverId,
  buddyId: d.owner.kind == DocumentOwnerKind.buddy ? d.owner.id : null,
);

/// Each holder's current medical clearance in [documents] (issue #4541):
/// the latest by expiry, else issue date, the key the list sorts
/// clearances by (#4508). An undated renewal issued after the last expiry
/// is current, and reminds of nothing, having no expiry.
///
/// A tie keeps the later issued, then the later created, then the higher
/// id, so exactly one clearance per holder is current. A clearance with
/// neither date takes no part.
Map<ClearanceHolder, Document> currentClearances(Iterable<Document> documents) {
  final current = <ClearanceHolder, Document>{};
  for (final d in documents) {
    if (!_ranked(d)) continue;
    final holder = clearanceHolder(d);
    final best = current[holder];
    if (best == null || _isLater(d, best)) current[holder] = d;
  }
  return current;
}

/// The medical clearances in [documents] that a later clearance of the
/// same holder supersedes: every ranked one but [currentClearances]'. A
/// diver keeps older certificates as an archive, and only the current one
/// should warn as it runs out, the same clearance the diver profile shows
/// (DocumentRepository.latestClearanceExpiryByDiver).
Set<String> supersededClearanceIds(Iterable<Document> documents) {
  final ranked = [
    for (final d in documents)
      if (_ranked(d)) d,
  ];
  final current = currentClearances(ranked);
  return {
    for (final d in ranked)
      if (current[clearanceHolder(d)]!.id != d.id) d.id,
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

bool _ranked(Document d) =>
    d.type == DocumentType.medicalClearance && _recency(d) != null;

/// The ranking key: the expiry, else the issue date.
DateTime? _recency(Document d) => d.expiryDate ?? d.issueDate;

bool _isLater(Document a, Document b) {
  final byRecency = _recency(a)!.compareTo(_recency(b)!);
  if (byRecency != 0) return byRecency > 0;
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
