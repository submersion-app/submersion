import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/shared/models/list_entry_count.dart';

/// The dive list's entry count, read from the loaded page state rather than
/// the live filter: a filter change reaches [diveFilterProvider] before the
/// reload it queues, so pairing the two would briefly show the new filter
/// against the old count. Null until the first page loads.
final diveListCountProvider = Provider<ListEntryCount?>((ref) {
  final state = ref.watch(paginatedDiveListProvider).value;
  if (state == null) return null;
  final unfiltered = state.unfilteredTotalCount;
  return unfiltered == null
      ? ListEntryCount.unfiltered(state.totalCount)
      : ListEntryCount.filtered(shown: state.totalCount, total: unfiltered);
});

/// The table view's entry count. Table mode loads every dive and its filtered
/// subset in full, so both lengths are already in hand.
final diveTableCountProvider = Provider<ListEntryCount?>(
  (ref) => listEntryCount(
    shown: ref.watch(filteredDivesProvider),
    isFiltered: ref.watch(diveFilterProvider).hasActiveFilters,
    total: () => ref.watch(diveListNotifierProvider),
  ),
);
