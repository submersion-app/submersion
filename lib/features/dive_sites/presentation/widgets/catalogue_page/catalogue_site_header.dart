import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_nearby.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/not_verified_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The top of a built-in site's page: its name, where it is, and a line
/// saying what kind of record this is and that it is not one of the
/// diver's own sites.
///
/// When one of the diver's unlinked sites sits on the record, a line names
/// it and opens it: that is the site the map shows in the record's place.
class CatalogueSiteHeader extends ConsumerWidget {
  const CatalogueSiteHeader({super.key, required this.site, this.here});

  final CatalogueSite site;

  /// The diver's site at this position, if there is one.
  final NearbyOwnSite? here;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final place = catalogueLocationLine(site);
    final yours = here;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(site.name, style: theme.textTheme.headlineSmall),
        if (place.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(place, style: muted),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${catalogueKindLabel(site, l10n)}'
                ' · ${l10n.diveSites_builtInPage_notYours}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (site.isResearched) const NotVerifiedLabel(),
            ],
          ),
        ),
        if (yours != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              key: const ValueKey('catalogueYourSiteHere'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/sites/${yours.site.id}'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.diveSites_builtInPage_yourSiteHere(
                          ref
                              .watch(unitFormatterProvider)
                              .formatGeoDistance(yours.meters),
                          yours.site.name,
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
