import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/list_entry_count.dart';
import 'package:submersion/shared/models/subtitle_text.dart';

/// The equipment list's entry count (#2669). Null until the list loads.
///
/// The total is the default view, not every item: with no filter the list
/// hides retired gear, so "3 of 40 items" counts against the 40 it shows
/// unfiltered rather than a number that includes gear it never lists.
final equipmentListCountProvider = Provider<ListEntryCount?>((ref) {
  return listEntryCount(
    shown: ref.watch(filteredEquipmentProvider),
    isFiltered: ref.watch(effectiveEquipmentFilterProvider).hasActiveFilters,
    total: () => narrowByIds(
      ref.watch(allEquipmentProvider),
      ref.watch(
        queryFilteredEquipmentIdsProvider((
          filter: const EquipmentFilterState(),
          diverId: ref.watch(validatedCurrentDiverIdProvider).value,
        )),
      ),
      (e) => e.id,
    ),
  );
});

/// The subtitle under the equipment list's title: "40 items", or
/// "3 of 40 items" while a filter is active.
SubtitleText? equipmentListCountLabel(BuildContext context, WidgetRef ref) =>
    ref
        .watch(equipmentListCountProvider)
        ?.subtitle(
          all: context.l10n.equipment_list_count,
          filtered: context.l10n.equipment_list_countFiltered,
          compactFiltered: context.l10n.common_listCount_shownOfTotal,
        );
