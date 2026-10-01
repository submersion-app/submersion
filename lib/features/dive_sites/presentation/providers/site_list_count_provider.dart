import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/list_entry_count.dart';
import 'package:submersion/shared/models/subtitle_text.dart';

/// The sites list's entry count (#2669): what the list shows against
/// what it holds with no filter. Null until the list loads.
final siteListCountProvider = Provider<ListEntryCount?>(
  (ref) => listEntryCount(
    shown: ref.watch(sortedSitesWithCountsProvider),
    isFiltered: ref.watch(siteFilterProvider).hasActiveFilters,
    total: () => ref.watch(sitesWithCountsProvider),
  ),
);

/// The subtitle under the sites list's title: "12 sites", or
/// "3 of 12 sites" while a filter is active.
SubtitleText? siteListCountLabel(BuildContext context, WidgetRef ref) => ref
    .watch(siteListCountProvider)
    ?.subtitle(
      all: context.l10n.diveSites_list_count,
      filtered: context.l10n.diveSites_list_countFiltered,
      compactFiltered: context.l10n.common_listCount_shownOfTotal,
    );
