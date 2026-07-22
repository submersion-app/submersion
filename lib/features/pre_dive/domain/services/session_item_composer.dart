import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

/// Turns template items into session-item snapshots at session start.
/// Pure: callers load the equipment set and its gear items. Repository
/// assigns ids and sessionId afterwards.
class SessionItemComposer {
  const SessionItemComposer._();

  static List<PreDiveSessionItem> compose({
    required List<PreDiveChecklistTemplateItem> templateItems,
    EquipmentSet? equipmentSet,
    List<EquipmentItem> equipmentItems = const [],
    required DateTime now,
    // Localized note stamped on gear rows whose service is overdue. Passed in
    // from the UI call site so this domain service stays pure and free of
    // hard-coded English (the note is displayed verbatim in the runner).
    required String serviceOverdueNote,
    // Ids of gear whose service is overdue, derived from the clock engine by
    // the caller so this domain service stays pure (no legacy isServiceDue).
    Set<String> overdueEquipmentIds = const {},
  }) {
    final byId = {for (final g in equipmentItems) g.id: g};
    final sorted = [...templateItems]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final out = <PreDiveSessionItem>[];
    var order = 0;

    for (final t in sorted) {
      if (t.itemType == PreDiveItemType.equipmentSet && equipmentSet != null) {
        for (final gearId in equipmentSet.equipmentIds) {
          final gear = byId[gearId];
          if (gear == null) continue;
          final overdue = overdueEquipmentIds.contains(gear.id);
          out.add(
            PreDiveSessionItem(
              id: '',
              sessionId: '',
              section: t.section,
              title: gear.name,
              sortOrder: order++,
              itemType: PreDiveItemType.check,
              isRequired: t.isRequired,
              // Overdue service demands an explicit decision: the row
              // starts flagged and the diver may clear it to done.
              state: overdue
                  ? PreDiveItemState.flagged
                  : PreDiveItemState.pending,
              note: overdue ? serviceOverdueNote : '',
              completedAt: overdue ? now : null,
              equipmentId: gear.id,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
        continue;
      }
      // equipmentSet placeholder without a set degrades to a plain check
      // item so the checklist stays runnable.
      final effectiveType = t.itemType == PreDiveItemType.equipmentSet
          ? PreDiveItemType.check
          : t.itemType;
      out.add(
        PreDiveSessionItem(
          id: '',
          sessionId: '',
          section: t.section,
          title: t.title,
          notes: t.notes,
          sortOrder: order++,
          itemType: effectiveType,
          valueLabel: t.valueLabel,
          valueUnit: t.valueUnit,
          valueMin: t.valueMin,
          valueMax: t.valueMax,
          isRequired: t.isRequired,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return out;
  }
}
