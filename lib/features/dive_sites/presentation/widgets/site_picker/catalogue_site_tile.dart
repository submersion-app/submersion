import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One built-in catalogue site in the site picker.
///
/// Tapping the row adopts the site; the trailing button opens its details
/// first, for a diver who wants to check before picking.
class CatalogueSiteTile extends ConsumerWidget {
  const CatalogueSiteTile({
    super.key,
    required this.site,
    required this.distanceText,
    required this.onTap,
    required this.onDetails,
  });

  final CatalogueSite site;

  /// How far the site is from the dive or the device, already formatted;
  /// null when the area was inferred and a distance would mean little.
  final String? distanceText;

  /// Null while an adoption is under way, which disables the row.
  final VoidCallback? onTap;

  /// Null while an adoption is under way, for the same reason.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final summary = catalogueSiteSummary(
      site,
      ref.watch(unitFormatterProvider),
      context.l10n,
    );

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.travel_explore, color: colorScheme.onSurfaceVariant),
      ),
      title: Text(site.name),
      subtitle: summary.isEmpty && distanceText == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.isNotEmpty) Text(summary),
                if (distanceText != null)
                  Text(
                    distanceText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
      // A fixed-width control: a text button or chip here would squeeze
      // the title (the ListTile.trailing guard).
      trailing: IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: context.l10n.diveSites_picker_builtIn_details,
        onPressed: onDetails,
      ),
      onTap: onTap,
    );
  }
}
