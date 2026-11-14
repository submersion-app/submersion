import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One built-in catalogue site among the import page's search results: its
/// name, place and tags, and the button that adopts it. Tapping the card
/// opens the record's details.
class CatalogueImportSiteCard extends StatelessWidget {
  final CatalogueSite site;
  final bool isImported;
  final UnitFormatter units;
  final VoidCallback onImport;

  const CatalogueImportSiteCard({
    super.key,
    required this.site,
    required this.isImported,
    required this.units,
    required this.onImport,
  });

  /// What the catalogue says the site is: its types by name, then the
  /// source's other tags.
  List<String> _tags(BuildContext context) => [
    ...catalogueTypeNames(site, context.l10n),
    ...site.features,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: context.l10n.diveSites_import_semantics_viewDetails(site.name),
        child: InkWell(
          onTap: () => _showDetails(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.scuba_diving,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Site info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _locationText(context),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Import button
                    if (isImported)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.diveSites_import_badge_imported,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      FilledButton.tonal(
                        onPressed: onImport,
                        child: Text(
                          context.l10n.diveSites_import_button_import,
                        ),
                      ),
                  ],
                ),

                // Features
                if (_tags(context).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _tags(context).take(4).map((feature) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          feature,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Depth and coordinates
                if (site.maxDepth != null || site.hasCoordinates) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (site.maxDepth != null) ...[
                        Icon(
                          Icons.arrow_downward,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          units.formatDepth(site.maxDepth, decimals: 0),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (site.hasCoordinates) ...[
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.diveSites_import_label_gps,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Where the site is, as the picker and the details card say it (island
  /// and locality included), or that it is not known.
  String _locationText(BuildContext context) {
    final line = catalogueLocationLine(site);
    return line.isNotEmpty
        ? line
        : context.l10n.diveCenters_label_locationUnknown;
  }

  /// The record's details, in the sheet the picker and the map use, so a
  /// diver sees its hazards, entry, depth range and website before
  /// importing it.
  void _showDetails(BuildContext context) {
    final l10n = context.l10n;
    unawaited(
      showCatalogueSiteDetails(
        context,
        site: site,
        actionLabel: isImported
            ? l10n.diveSites_import_detail_alreadyImported
            : l10n.diveSites_import_detail_importToMySites,
        onAction: isImported ? null : () async => onImport(),
      ),
    );
  }
}
