import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveSearchActionKey = ValueKey('dive-search-action');

/// The Dives app bar's one search entry (#2773), shared by the phone,
/// desktop and table layouts. It replaces the old Search overlay and the
/// Filter icon; the badge is the Filter icon's old job.
class DiveSearchAction extends ConsumerWidget {
  const DiveSearchAction({super.key, this.iconSize});

  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(diveFilterProvider).hasActiveFilters;
    return IconButton(
      key: kDiveSearchActionKey,
      tooltip: context.l10n.diveLog_listPage_tooltip_searchDives,
      icon: Badge(
        isLabelVisible: filtered,
        child: Icon(Icons.search, size: iconSize),
      ),
      onPressed: () {
        final open = ref.read(diveSearchBarOpenProvider.notifier);
        // An idle open row closes; otherwise open it with the caret in it.
        if (ref.read(diveSearchBarVisibleProvider) && !filtered) {
          open.state = false;
          return;
        }
        open.state = true;
        ref.read(diveSearchFocusPendingProvider.notifier).state = true;
      },
    );
  }
}
