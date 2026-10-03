import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Within filters / All dives (#2773): All dives keeps the filter axes but
/// runs only the typed search, so any dive can be found while filtered.
class DiveSearchScopeToggle extends ConsumerWidget {
  const DiveSearchScopeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(diveFilterProvider);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SegmentedButton<bool>(
        key: const ValueKey('dive-search-scope'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: false,
            label: Text(l10n.diveLog_search_scopeWithin),
          ),
          ButtonSegment(value: true, label: Text(l10n.diveLog_search_scopeAll)),
        ],
        selected: {filter.axesSuspended},
        onSelectionChanged: (s) {
          final notifier = ref.read(diveFilterProvider.notifier);
          notifier.state = notifier.state.copyWith(axesSuspended: s.first);
        },
      ),
    );
  }
}
