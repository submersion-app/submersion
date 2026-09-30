import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/list_entry_count.dart';
import 'package:submersion/shared/models/subtitle_text.dart';

/// The trips list's entry count (#2669): what the list shows against
/// what it holds with no filter. Null until the list loads.
final tripListCountProvider = Provider<ListEntryCount?>(
  (ref) => listEntryCount(
    shown: ref.watch(sortedFilteredTripsProvider),
    isFiltered: ref.watch(tripFilterProvider).hasActiveFilters,
    total: () => ref.watch(tripListNotifierProvider),
  ),
);

/// The subtitle under the trips list's title: "12 trips", or
/// "3 of 12 trips" while a filter is active.
SubtitleText? tripListCountLabel(BuildContext context, WidgetRef ref) => ref
    .watch(tripListCountProvider)
    ?.subtitle(
      all: context.l10n.trips_list_count,
      filtered: context.l10n.trips_list_countFiltered,
      compactFiltered: context.l10n.common_listCount_shownOfTotal,
    );
