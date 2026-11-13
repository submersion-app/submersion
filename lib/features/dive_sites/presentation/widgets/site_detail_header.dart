import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_rating_stars.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/country_flag.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/site_attribution_line.dart';

/// The site's name and what classifies it, directly under the map card at
/// the top of Site Details.
///
/// Pinned like the Dive Center header it is modelled on: it is not one of
/// the diver's configurable cards, so a site always opens on its name no
/// matter how the cards below are arranged. Everything here also lives in a
/// card further down (rating, difficulty, site types), so each line is a
/// summary and is simply left out when the site has no value for it.
class SiteDetailHeader extends ConsumerWidget {
  const SiteDetailHeader({super.key, required this.site});

  final DiveSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // A built-in type is stored under its English name, so it reads through
    // the l10n lookup rather than the stored one.
    final types =
        ref.watch(siteTypesForSiteProvider(site.id)).value ?? const [];
    final labels = <String>[
      for (final type in types) type.localizedName(l10n),
      if (site.difficulty != null) site.difficulty!.localizedName(l10n),
      if (site.waterType != null) site.waterType!.localizedName(l10n),
    ];

    final rating = site.rating;
    final location = site.locationString;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.scuba_diving,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site.name, style: theme.textTheme.headlineSmall),
                    if (site.isLibrarySite) ...[
                      const SizedBox(height: 4),
                      _LibraryLine(site: site),
                    ],
                    if (rating != null && rating > 0) ...[
                      const SizedBox(height: 4),
                      _Rating(rating: rating),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 16),
            // The flag takes the pin's place; the pin returns when there is
            // no flag (issue #4426).
            LocationWithFlag(
              country: site.country,
              countryCode: site.countryCode,
              flagHeight: 14,
              gap: 8,
              fallbackLeading: Icon(
                Icons.location_on_outlined,
                size: 20,
                color: colorScheme.outline,
              ),
              text: Text(location, style: theme.textTheme.bodyLarge),
            ),
          ],
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Every other block on this page is a Card, which is itself a
            // Material; the header is not one, so it carries the Material a
            // Chip needs rather than relying on the Scaffold hosting it.
            Material(
              type: MaterialType.transparency,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in labels)
                    Chip(
                      label: Text(label),
                      backgroundColor: colorScheme.secondaryContainer,
                      labelStyle: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (site.catalogueId != null)
            _CatalogueLine(catalogueId: site.catalogueId!),
        ],
      ),
    );
  }
}

/// Where a site adopted from the built-in catalogue came from: the source
/// to credit, and the site's website when the catalogue holds one.
///
/// Read through the site's link, not stored on the site, so it follows the
/// catalogue. Nothing shows for a record a later catalogue dropped.
class _CatalogueLine extends ConsumerWidget {
  const _CatalogueLine({required this.catalogueId});

  final String catalogueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(catalogueSiteProvider(catalogueId)).value;
    if (record == null) return const SizedBox.shrink();
    final source = ref.watch(catalogueSourceProvider(record.source)).value;
    if (source == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    final website = catalogueWebsiteUri(record.website);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            l10n.diveSites_catalogue_credit(source.credit),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (website != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () =>
                  launchUrl(website, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(l10n.diveCenters_label_website),
            ),
        ],
      ),
    );
  }
}

/// Five stars and the value, the way the Dive Center header shows a rating.
///
/// Wrapped rather than a plain row: the stars are fixed-size icons while the
/// value grows with the diver's text scale, so on a narrow pane the value
/// drops below the stars instead of overflowing.
class _Rating extends StatelessWidget {
  const _Rating({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SiteRatingStars(rating: rating, size: 20, color: Colors.amber.shade700),
        Text(
          rating.toStringAsFixed(1),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// The shared site library a site belongs to and who last edited it (issue
/// #2567).
class _LibraryLine extends ConsumerWidget {
  const _LibraryLine({required this.site});

  final DiveSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraries = ref.watch(sharedLibrariesProvider).value;
    var name = '';
    for (final l in libraries ?? const []) {
      if (l.id == site.sharedLibraryId) name = l.name;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: const Icon(Icons.groups_outlined, size: 18),
          label: Text(name),
          visualDensity: VisualDensity.compact,
        ),
        SiteAttributionLine(site: site),
      ],
    );
  }
}
