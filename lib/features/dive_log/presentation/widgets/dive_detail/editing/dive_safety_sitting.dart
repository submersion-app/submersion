import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The held change of the Safety review card: findings dismissed and
/// restored in the sitting.
const String safetyDismissalsKey = 'safetyDismissals';

const String _noteKey = 'safetyDismissals.held';
const String _repoKey = 'safetyDismissals.repo';

/// Each finding the diver touched in the sitting: whether it was dismissed
/// when first touched, and whether it is now.
typedef _Touched = Map<String, ({bool stored, bool now})>;

/// Keeps the repository the held write uses, read as the sitting starts so
/// the write needs no provider when it runs.
void holdSafetyDismissals(EditSession<Dive> session, ProviderRead read) {
  session.remember(_repoKey, read(safetyFindingsRepositoryProvider));
}

_Touched _touched(EditSession<Dive> session) =>
    session.recall<_Touched>(_noteKey) ?? const {};

/// Whether each finding the sitting changed is dismissed, by id.
Map<String, bool> sittingDismissals(EditSession<Dive> session) => {
  for (final MapEntry(key: id, value: t) in _touched(session).entries)
    if (t.stored != t.now) id: t.now,
};

/// Dismisses or restores [finding] in the sitting. Back to how it was, it
/// is no change; with none left, the held change is released.
void setFindingDismissed(
  EditSession<Dive> session,
  SafetyFinding finding, {
  required bool dismissed,
}) => setAllFindingsDismissed(session, [finding], dismissed: dismissed);

/// [setFindingDismissed] for each of [findings] at once.
void setAllFindingsDismissed(
  EditSession<Dive> session,
  List<SafetyFinding> findings, {
  required bool dismissed,
}) {
  if (session.isDisposed || session.isFrozen) return;
  final touched = {..._touched(session)};
  for (final finding in findings) {
    final stored = touched[finding.id]?.stored ?? finding.isDismissed;
    touched[finding.id] = (stored: stored, now: dismissed);
  }
  session.remember(_noteKey, touched);
  if (sittingDismissals(session).isEmpty) {
    session.releaseWrite(safetyDismissalsKey);
    return;
  }
  final repository = session.recall<SafetyFindingsRepository>(_repoKey);
  if (repository == null) return;
  session.holdChange(
    safetyDismissalsKey,
    cardId: DiveDetailSectionId.safetyReview.name,
    write: () => _write(session, repository),
  );
}

/// Writes each changed dismissal at Save, for findings that still exist: a
/// review recomputed during the sitting keeps the ids of the findings that
/// still fire, and drops the rest.
Future<void> _write(
  EditSession<Dive> session,
  SafetyFindingsRepository repository,
) async {
  final changed = sittingDismissals(session);
  if (changed.isEmpty) return;
  final review = await repository.getReview(session.stored.id);
  final present = {for (final f in review?.findings ?? const []) f.id};
  final now = DateTime.now();
  for (final MapEntry(key: id, value: dismissed) in changed.entries) {
    if (!present.contains(id)) continue;
    await repository.setDismissed(
      findingId: id,
      dismissed: dismissed,
      now: now,
    );
  }
}

/// [review] with the sitting's dismissals laid over it, for the card that
/// shows them during a sitting.
SafetyReview reviewInSitting(EditSession<Dive> session, SafetyReview review) {
  final changed = sittingDismissals(session);
  if (changed.isEmpty) return review;
  final now = DateTime.now();
  return SafetyReview(
    diveId: review.diveId,
    engineVersion: review.engineVersion,
    reviewedAt: review.reviewedAt,
    inputsHash: review.inputsHash,
    findings: [
      for (final f in review.findings)
        switch (changed[f.id]) {
          true => f.isDismissed ? f : f.copyWith(dismissedAt: now),
          false => f.copyWith(clearDismissedAt: true),
          null => f,
        },
    ],
  );
}
