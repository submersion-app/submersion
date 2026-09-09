import 'package:uuid/uuid.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

/// Turns template items into session-item snapshots at session start.
/// Pure: callers load the equipment set and its gear items. The repository
/// assigns sessionId afterwards.
///
/// Item ids are minted here rather than by the repository, because a
/// `cellLinearity` item's sourceItemId has to name a sibling this same call
/// is building (issue #986). `startSession` honours any non-blank id it is
/// handed, so nothing else had to change.
///
/// Every composed item starts [PreDiveItemState.pending], even when its
/// linked gear has overdue service: that decision belongs to the diver, made
/// explicitly during the run, not preset here before the checklist is even
/// opened. Overdue maintenance is instead surfaced as a purely informative,
/// live-computed warning in the runner UI (see `SessionItemTile`), decoupled
/// from the resolved/done state.
class SessionItemComposer {
  const SessionItemComposer._();

  static const _uuid = Uuid();

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

    // Pass one: mint a session id for every template item up front, so a
    // cellLinearity item can point at its source whether that source sorts
    // before or after it.
    //
    // Every item gets an entry, including equipmentSet placeholders. Those
    // usually fan out to their own rows and leave the entry unused, but a
    // placeholder with no set degrades to a single check row below and does
    // consume it. Minting an id that goes unused is free; assuming which
    // branch claims it is not.
    final sessionIdByTemplateId = <String, String>{
      for (final t in sorted) t.id: _uuid.v4(),
    };
    final templateItemById = {for (final t in sorted) t.id: t};

    final out = <PreDiveSessionItem>[];
    var order = 0;

    for (final t in sorted) {
      if (t.itemType == PreDiveItemType.equipment) {
        final equipmentId = equipmentByTemplateItemId[t.id] ?? t.equipmentId;
        final gear = equipmentId == null ? null : byId[equipmentId];
        out.add(
          PreDiveSessionItem(
            id: sessionIdByTemplateId[t.id]!,
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
              id: _uuid.v4(),
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
      var effectiveType = t.itemType == PreDiveItemType.equipmentSet
          ? PreDiveItemType.check
          : t.itemType;

      // A usable source is one that actually records a number, so the id
      // resolving is not enough: retyping the air item from value to check
      // leaves the link pointing at a row that can never carry a reading.
      // Anything but a value item is treated exactly like a missing source.
      final sourceTemplateItem = t.sourceItemId == null
          ? null
          : templateItemById[t.sourceItemId];
      final sourceSessionId =
          sourceTemplateItem?.itemType == PreDiveItemType.value
          ? sessionIdByTemplateId[t.sourceItemId]
          : null;

      // A cellLinearity item whose source is missing or unusable degrades to
      // a plain value item rather than a check: the diver is standing there
      // with a meter, so the oxygen reading is still worth recording even
      // though the ratio cannot be computed.
      final degraded =
          effectiveType == PreDiveItemType.cellLinearity &&
          sourceSessionId == null;
      if (degraded) effectiveType = PreDiveItemType.value;

      out.add(
        PreDiveSessionItem(
          id: sessionIdByTemplateId[t.id]!,
          sessionId: '',
          section: t.section,
          title: t.title,
          notes: t.notes,
          sortOrder: order++,
          itemType: effectiveType,
          valueLabel: t.valueLabel,
          valueUnit: t.valueUnit,
          // Thresholds are a percentage on a cellLinearity item but
          // millivolts on a value item, so a degraded item must shed them.
          // Carrying a 95% floor onto a millivolt reading would light the
          // out-of-range warning on every healthy cell.
          valueMin: degraded ? null : t.valueMin,
          valueMax: degraded ? null : t.valueMax,
          isRequired: t.isRequired,
          sourceItemId: sourceSessionId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return out;
  }
}
