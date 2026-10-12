import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_grouping_providers.dart';
import 'package:submersion/features/dive_sites/presentation/utils/site_group_by_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Dive Sites sort sheet's "Group by" control (#1080, #3270). Choosing
/// closes the sheet, as choosing a sort field does.
///
/// A radio list rather than a segmented button: four options, two of them
/// "Country & ..." labels, would be too cramped in a segmented row (matches
/// the equipment sort sheet's type-order list for the same reason).
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
          // RadioGroup rather than per-tile groupValue/onChanged, which
          // Flutter deprecated after 3.32.
          RadioGroup<SiteGroupBy>(
            groupValue: ref.watch(siteGroupByProvider),
            onChanged: (value) {
              if (value == null) return;
              ref.read(siteGroupByProvider.notifier).state = value;
              Navigator.of(context).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in SiteGroupBy.values)
                  RadioListTile<SiteGroupBy>(
                    value: option,
                    title: Text(option.localizedName(l10n)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
