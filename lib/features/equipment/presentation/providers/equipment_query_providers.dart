import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';

/// The ids the equipment filter selects (#2365). A query naming
/// `serviceDue` waits for the service cache to mirror the engine first.
/// Keyed on the filter's value and the active diver (the owner scope, and
/// whose dives shared gear's counts read).
final queryFilteredEquipmentIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, ({EquipmentFilterState filter, String? diverId})>(
      (ref, key) => watchQueryIds(
        ref,
        compileEquipmentFilter(key.filter, diverId: key.diverId),
        scope: key.filter.ownerScope(key.diverId),
      ),
    );

/// [items] narrowed to [ids], by [narrowByIds]'s rules.
AsyncValue<List<EquipmentItem>> _narrow(
  AsyncValue<List<EquipmentItem>> items,
  AsyncValue<Set<String>> ids,
) => narrowByIds(items, ids, (e) => e.id);

/// The equipment list: every visible item (in `getAllEquipment` order,
/// type then name) narrowed to the compiled query's ids. Replaces the
/// active / by-status / service-due provider switch and apply().
final filteredEquipmentProvider = Provider<AsyncValue<List<EquipmentItem>>>((
  ref,
) {
  final filter = ref.watch(effectiveEquipmentFilterProvider);
  final diverId = ref.watch(validatedCurrentDiverIdProvider).value;
  return _narrow(
    ref.watch(allEquipmentProvider),
    ref.watch(
      queryFilteredEquipmentIdsProvider((filter: filter, diverId: diverId)),
    ),
  );
});

/// Whether the tag selection is what emptied the list (issue #1942): the
/// filter selects nothing, but the same filter without its tags selects
/// something.
final equipmentTagsEmptiedProvider = Provider<bool>((ref) {
  final filter = ref.watch(effectiveEquipmentFilterProvider);
  if (filter.tagIds.isEmpty) return false;
  final withTags = ref.watch(filteredEquipmentProvider).value;
  if (withTags == null || withTags.isNotEmpty) return false;
  final diverId = ref.watch(validatedCurrentDiverIdProvider).value;
  final without = _narrow(
    ref.watch(allEquipmentProvider),
    ref.watch(
      queryFilteredEquipmentIdsProvider((
        filter: filter.copyWith(clearTagIds: true),
        diverId: diverId,
      )),
    ),
  ).value;
  return without != null && without.isNotEmpty;
});

/// Whether the status view alone (the base list before category, attribute,
/// tag, owner and advanced narrowing) holds anything, so the empty state can
/// tell "no gear of this category" from "nothing in this view at all".
final equipmentStatusViewHasItemsProvider = Provider<bool>((ref) {
  final filter = ref.watch(effectiveEquipmentFilterProvider);
  final diverId = ref.watch(validatedCurrentDiverIdProvider).value;
  final base = EquipmentFilterState(
    status: filter.status,
    serviceDue: filter.serviceDue,
  );
  final items = _narrow(
    ref.watch(allEquipmentProvider),
    ref.watch(
      queryFilteredEquipmentIdsProvider((filter: base, diverId: diverId)),
    ),
  ).value;
  return items != null && items.isNotEmpty;
});
