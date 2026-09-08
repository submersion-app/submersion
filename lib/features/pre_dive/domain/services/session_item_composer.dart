import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

/// Turns template items into session-item snapshots at session start.
/// Pure: callers load the equipment set and its gear items. Repository
/// assigns ids and sessionId afterwards.
///
/// Every composed item starts [PreDiveItemState.pending], even when its
/// linked gear has overdue service: that decision belongs to the diver, made
/// explicitly during the run, not preset here before the checklist is even
/// opened. Overdue maintenance is instead surfaced as a purely informative,
/// live-computed warning in the runner UI (see `SessionItemTile`), decoupled
/// from the resolved/done state.
class SessionItemComposer {
  const SessionItemComposer._();

  static List<PreDiveSessionItem> compose({
    required List<PreDiveChecklistTemplateItem> templateItems,
    EquipmentSet? equipmentSet,
    List<EquipmentItem> equipmentItems = const [],
    // Per-item equipment choice for 'equipment'-typed items, keyed by
    // template item id. Falls back to the item's own remembered
    // [PreDiveChecklistTemplateItem.equipmentId] when absent, so a session
    // still resolves the device on a plain re-run with no fresh picker
    // interaction.
    Map<String, String> equipmentByTemplateItemId = const {},
    required DateTime now,
  }) {
    final byId = {for (final g in equipmentItems) g.id: g};
    final sorted = [...templateItems]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final out = <PreDiveSessionItem>[];
    var order = 0;

    for (final t in sorted) {
      if (t.itemType == PreDiveItemType.equipment) {
        final equipmentId = equipmentByTemplateItemId[t.id] ?? t.equipmentId;
        final gear = equipmentId == null ? null : byId[equipmentId];
        out.add(
          PreDiveSessionItem(
            id: '',
            sessionId: '',
            section: t.section,
            title: t.title,
            notes: t.notes,
            sortOrder: order++,
            itemType: PreDiveItemType.check,
            isRequired: t.isRequired,
            equipmentId: gear?.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
        continue;
      }
      if (t.itemType == PreDiveItemType.equipmentSet && equipmentSet != null) {
        for (final gearId in equipmentSet.equipmentIds) {
          final gear = byId[gearId];
          if (gear == null) continue;
          out.add(
            PreDiveSessionItem(
              id: '',
              sessionId: '',
              section: t.section,
              title: gear.name,
              sortOrder: order++,
              itemType: PreDiveItemType.check,
              isRequired: t.isRequired,
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
