import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_grouping_providers.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_group_by_display.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/list_arrangement_writes.dart';

/// The certification sort sheet's "Group by" control (#3359), a direct port
/// of the Dive Sites list's [SiteGroupBySelector]. Choosing closes the
/// sheet, as choosing a sort field does.
class CertificationGroupBySelector extends ConsumerWidget {
  const CertificationGroupBySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.certifications_list_groupBy,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          RadioGroup<CertificationGroupBy>(
            groupValue: ref.watch(certificationGroupByProvider),
            onChanged: (value) {
              if (value == null) return;
              ref
                  .read(settingsProvider.notifier)
                  .setCertificationGroupBy(value);
              Navigator.of(context).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in CertificationGroupBy.values)
                  RadioListTile<CertificationGroupBy>(
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
