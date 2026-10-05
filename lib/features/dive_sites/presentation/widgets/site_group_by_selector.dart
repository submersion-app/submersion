import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_grouping_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Dive Sites sort sheet's "Group by" control (#1080). Choosing closes
/// the sheet, as choosing a sort field does.
class SiteGroupBySelector extends ConsumerWidget {
  const SiteGroupBySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.diveSites_list_groupBy,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<SiteGroupBy>(
            segments: [
              ButtonSegment(
                value: SiteGroupBy.none,
                label: Text(l10n.diveSites_list_groupBy_none),
              ),
              ButtonSegment(
                value: SiteGroupBy.location,
                icon: const Icon(Icons.public),
                label: Text(l10n.diveSites_list_groupBy_location),
              ),
            ],
            selected: {ref.watch(siteGroupByProvider)},
            showSelectedIcon: false,
            onSelectionChanged: (selected) {
              ref.read(siteGroupByProvider.notifier).state = selected.first;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
