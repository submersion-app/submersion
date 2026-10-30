import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/list_entry_count.dart';
import 'package:submersion/shared/models/subtitle_text.dart';

/// The dive list's entry count, read from the loaded page state rather than
/// the live filter: a filter change reaches [diveFilterProvider] before the
/// reload it queues, so pairing the two would briefly show the new filter
/// against the old count. Null until the first page loads.
final diveListCountProvider = Provider<ListEntryCount?>((ref) {
  final state = ref.watch(paginatedDiveListProvider).valueOrNull;
  if (state == null) return null;
  final unfiltered = state.unfilteredTotalCount;
  return unfiltered == null
      ? ListEntryCount.unfiltered(state.totalCount)
      : ListEntryCount.filtered(shown: state.totalCount, total: unfiltered);
});

/// The table view's counts, for one diver under one filter, in SQL (#3815).
///
/// Keyed on both, so a change of either lands on a fresh instance that starts
/// loading and hides the count, while a write to a table the filter reads
/// keeps the value until the new one arrives. The tick is the one
/// [orderedDiveIdsProvider] follows: the dives plus the filter's own tables.
final _diveTableCountsProvider = FutureProvider.autoDispose
    .family<ListEntryCount, ({String? diverId, DiveFilterState filter})>((
      ref,
      key,
    ) async {
      final repository = ref.watch(diveRepositoryProvider);
      final (:diverId, :filter) = key;
      final touched = diveFilterTablesTouched(filter);
      await awaitServiceStatusIfRead(ref, touched);
      final extra = touched.difference({'dives'});
      ref.invalidateSelfWhen(
        extra.isEmpty
            ? repository.watchDivesChanges()
            : repository.watchTables({'dives', ...extra}),
      );
      final shown = repository.getDiveCount(diverId: diverId, filter: filter);
      if (!filter.hasActiveFilters) {
        return ListEntryCount.unfiltered(await shown);
      }
      final total = repository.getDiveCount(diverId: diverId);
      return ListEntryCount.filtered(shown: await shown, total: await total);
    });

/// The table view's entry count. Null until its first count arrives.
final diveTableCountProvider = Provider<ListEntryCount?>(
  (ref) => ref
      .watch(
        _diveTableCountsProvider((
          diverId: ref.watch(currentDiverIdProvider),
          filter: ref.watch(diveFilterProvider),
        )),
      )
      .valueOrNull,
);

/// The subtitle under the dive list's title for [count]: "812 dives", or
/// "34 of 812 dives" while a filter is active. Shared by the list and table
/// views, which count from different providers.
SubtitleText? diveCountSubtitle(BuildContext context, ListEntryCount? count) =>
    count?.subtitle(
      all: context.l10n.diveLog_listPage_count,
      filtered: context.l10n.diveLog_listPage_countFiltered,
      compactFiltered: context.l10n.common_listCount_shownOfTotal,
    );
