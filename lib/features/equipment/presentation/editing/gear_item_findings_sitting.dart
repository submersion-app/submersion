import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The held change of the Condition findings card (issue #4527, phase 3):
/// findings dismissed and restored in the sitting, written at Save into the
/// item's History entry, as a dive's safety findings are.
const String gearFindingDismissalsKey = 'equipment.findingDismissals';

const String _noteKey = 'equipment.findingDismissals.held';
const String _repoKey = 'equipment.findingDismissals.repo';

/// Each finding the diver touched in the sitting: whether it was dismissed
/// when first touched, and whether it is now.
typedef _Touched = Map<String, ({bool stored, bool now})>;

/// Keeps the repository the held write uses, read as the sitting starts so
/// the write needs no provider when it runs.
void holdFindingDismissals(
  EditSession<EquipmentItem> session,
  ProviderRead read,
) {
  session.remember(_repoKey, read(equipmentFindingsRepositoryProvider));
}

_Touched _touched(EditSession<EquipmentItem> session) =>
    session.recall<_Touched>(_noteKey) ?? const {};

/// Whether each finding the sitting changed is dismissed, by id.
Map<String, bool> sittingFindingDismissals(
  EditSession<EquipmentItem> session,
) => {
  for (final MapEntry(key: id, value: t) in _touched(session).entries)
    if (t.stored != t.now) id: t.now,
};

/// Dismisses or restores [finding] in the sitting. Back to how it was, it
/// is no change; with none left, the held change is released.
void setFindingDismissedInSitting(
  EditSession<EquipmentItem> session,
  EquipmentFinding finding, {
  required bool dismissed,
}) {
  if (session.isDisposed || session.isFrozen) return;
  final touched = {..._touched(session)};
  final stored = touched[finding.id]?.stored ?? finding.dismissedAt != null;
  touched[finding.id] = (stored: stored, now: dismissed);
  session.remember(_noteKey, touched);
  if (sittingFindingDismissals(session).isEmpty) {
    session.releaseWrite(gearFindingDismissalsKey);
    return;
  }
  final repository = session.recall<EquipmentFindingsRepository>(_repoKey);
  if (repository == null) return;
  session.holdChange(
    gearFindingDismissalsKey,
    cardId: GearItemCardId.conditionFindings.name,
    write: () => _write(session, repository),
  );
}

/// Writes each changed dismissal at Save. A finding a recompute deleted
/// during the sitting is skipped: the repository writes nothing for a row
/// that has gone.
Future<void> _write(
  EditSession<EquipmentItem> session,
  EquipmentFindingsRepository repository,
) async {
  final now = DateTime.now();
  for (final MapEntry(key: id, value: dismissed) in sittingFindingDismissals(
    session,
  ).entries) {
    await repository.setDismissed(
      findingId: id,
      dismissed: dismissed,
      now: now,
    );
  }
}

/// [stored] with the sitting's dismissals laid over it, for the card that
/// shows them during a sitting.
List<EquipmentFinding> findingsInSitting(
  EditSession<EquipmentItem> session,
  List<EquipmentFinding> stored,
) {
  final changed = sittingFindingDismissals(session);
  if (changed.isEmpty) return stored;
  final now = DateTime.now();
  return [
    for (final f in stored)
      switch (changed[f.id]) {
        true => f.dismissedAt != null ? f : f.copyWith(dismissedAt: now),
        false => f.copyWith(clearDismissedAt: true),
        null => f,
      },
  ];
}
