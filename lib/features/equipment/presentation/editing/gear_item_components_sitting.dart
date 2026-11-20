import 'package:flutter/foundation.dart' show listEquals;

import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

const String _componentsRepoKey = 'equipment.components.repo';
const String _divesRepoKey = 'equipment.components.dives';
const String _answersKey = 'equipment.components.answers';
const String _touchedKey = 'equipment.components.touchedDives';

/// The gear item's parts as its sitting has them (issue #4527, phase 3):
/// added, replaced, removed, given a role or reordered, written at Save
/// with the dives the change reaches.
final gearItemComponentsList =
    SittingList<EquipmentItem, EquipmentComponent>.withSession(
      key: 'equipment.components',
      cardId: GearItemCardId.components.name,
      read: (item) => _repository(null).getComponents(item.id),
      writeIn: (session, loaded, current) =>
          writeGearItemComponents(session, loaded, current),
    );

EquipmentComponentRepository _repository(EditSession<EquipmentItem>? session) =>
    session?.recall<EquipmentComponentRepository>(_componentsRepoKey) ??
    EquipmentComponentRepository();

/// Keeps the repositories the held write uses, read as the sitting starts,
/// and reads the parts.
void holdGearItemComponents(
  EditSession<EquipmentItem> session,
  ProviderRead read,
) {
  session.remember(
    _componentsRepoKey,
    read(equipmentComponentRepositoryProvider),
  );
  session.remember(_divesRepoKey, read(diveRepositoryProvider));
  gearItemComponentsList.load(session);
}

/// Records how the diver answered "Update past dives?" for the change to
/// the part [componentEquipmentId], asked when the change was made. The
/// last answer for a part is the one Save uses.
void rememberPartAnswer(
  EditSession<EquipmentItem> session,
  String componentEquipmentId,
  AssemblyHistoryChoice answer,
) {
  session.remember(_answersKey, {
    ..._answers(session),
    componentEquipmentId: answer,
  });
}

Map<String, AssemblyHistoryChoice> _answers(
  EditSession<EquipmentItem> session,
) =>
    session.recall<Map<String, AssemblyHistoryChoice>>(_answersKey) ?? const {};

/// The dive rewrites the sitting's parts make: each part's net change
/// against [loaded] (added, removed, or swapped on a kept row, oldest to
/// newest), under the last answer given for it. A part added and removed in
/// the sitting, or removed and added back, changes no dive.
({List<GearHistoryRewrite> alsoPast, List<GearHistoryRewrite> futureOnly})
gearAssemblyRewrites(
  List<EquipmentComponent> loaded,
  List<EquipmentComponent> current,
  Map<String, AssemblyHistoryChoice> answers,
) {
  final before = {for (final c in loaded) c.id: c.componentEquipmentId};
  final after = {for (final c in current) c.id: c.componentEquipmentId};
  final removed = <String>{
    for (final MapEntry(key: row, value: part) in before.entries)
      if (!after.containsKey(row)) part,
  };
  final added = <String>{
    for (final MapEntry(key: row, value: part) in after.entries)
      if (!before.containsKey(row)) part,
  };
  // A part taken out and put back in the sitting is where it was.
  final back = removed.intersection(added);
  final rewrites = <(String, GearHistoryRewrite)>[
    for (final part in removed.difference(back)) (part, GearPartRemoved(part)),
    for (final MapEntry(key: row, value: part) in after.entries)
      if (before[row] case final old? when old != part)
        (part, GearPartReplaced(oldPartId: old, newPartId: part)),
    for (final part in added.difference(back)) (part, GearPartAdded(part)),
  ];
  bool alsoPast(String part) => answers[part] == AssemblyHistoryChoice.alsoPast;
  return (
    alsoPast: [
      for (final (part, rewrite) in rewrites)
        if (alsoPast(part)) rewrite,
    ],
    futureOnly: [
      for (final (part, rewrite) in rewrites)
        if (!alsoPast(part)) rewrite,
    ],
  );
}

/// Writes the parts at Save: removals, new rows under the ids the sitting
/// gave them, swapped parts, roles, then the order, then the dives the change
/// reaches (planned always, logged as the diver answered). A part the
/// database refuses as a cycle fails the whole Save.
Future<Object?> writeGearItemComponents(
  EditSession<EquipmentItem> session,
  List<EquipmentComponent> loaded,
  List<EquipmentComponent> current,
) async {
  final repository = _repository(session);
  final assemblyId = session.stored.id;
  final before = {for (final c in loaded) c.id: c};
  final kept = {for (final c in current) c.id};
  try {
    // Removals first: a part taken off one row and put on another, or
    // removed and added back, must find its old row gone, or the add would
    // find that row and keep it and the swap would break the unique pair.
    for (final old in loaded) {
      if (!kept.contains(old.id)) await repository.removeComponent(old.id);
    }
    for (final row in current) {
      final old = before[row.id];
      if (old == null) {
        await repository.addComponent(
          parentId: assemblyId,
          componentId: row.componentEquipmentId,
          role: row.role,
          id: row.id,
        );
        continue;
      }
      if (old.componentEquipmentId != row.componentEquipmentId) {
        await repository.replaceComponent(row.id, row.componentEquipmentId);
      }
      if (old.role != row.role) await repository.updateRole(row.id, row.role);
    }
  } on EquipmentComponentCycleException {
    throw RecordSittingRefusal((l) => l.equipment_components_cycleError);
  }
  // New rows are appended, so the order needs writing only when it is not
  // the stored order with them at the end.
  final appended = [
    for (final c in loaded)
      if (kept.contains(c.id)) c.id,
    for (final c in current)
      if (!before.containsKey(c.id)) c.id,
  ];
  final order = [for (final c in current) c.id];
  if (!listEquals(order, appended)) {
    await repository.reorder(assemblyId, order);
  }

  final rewrites = gearAssemblyRewrites(loaded, current, _answers(session));
  final dives =
      session.recall<DiveRepository>(_divesRepoKey) ?? DiveRepository();
  final touched = <String>{
    ...await dives.rewriteAssemblyOnDives(
      assemblyId,
      rewrites.alsoPast,
      alsoLogged: true,
      notify: false,
    ),
    ...await dives.rewriteAssemblyOnDives(
      assemblyId,
      rewrites.futureOnly,
      alsoLogged: false,
      notify: false,
    ),
  };
  session.remember(_touchedKey, touched);
  return null;
}

/// What the saved parts still have to do outside the transaction: rescan the
/// dives they rewrote, as a rewrite outside a sitting does.
List<Future<void> Function()> componentsAfterCommit(
  EditSession<EquipmentItem> session,
) {
  final touched = session.recall<Set<String>>(_touchedKey) ?? const {};
  if (touched.isEmpty) return const [];
  return [() async => scheduleQualityScan(touched)];
}
