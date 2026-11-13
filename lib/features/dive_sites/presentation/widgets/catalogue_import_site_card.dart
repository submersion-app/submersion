import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One built-in catalogue site among the import page's search results: its
/// name, place and tags, a details sheet, and the button that adopts it.
class CatalogueImportSiteCard extends StatelessWidget {
  final CatalogueSite site;
  final bool isImported;
  final UnitFormatter units;

  /// Who to credit for the record, or null while that is unknown.
  final String? sourceCredit;
  final VoidCallback onImport;

  const CatalogueImportSiteCard({
    super.key,
    required this.site,
    required this.isImported,
    required this.units,
    required this.sourceCredit,
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
                            _buildLocationText(),
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

  String _buildLocationText() {
    final parts = <String>[];
    if (site.region != null && site.region!.isNotEmpty) {
      parts.add(site.region!);
    }
    if (site.country != null && site.country!.isNotEmpty) {
      parts.add(site.country!);
    }
    return parts.isNotEmpty ? parts.join(', ') : 'Location unknown';
  }

  void _showDetails(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    site.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildLocationText(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (site.description != null &&
                      site.description!.isNotEmpty) ...[
                    Text(site.description!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                  ],

                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (site.maxDepth != null)
                        Chip(
                          avatar: const Icon(Icons.arrow_downward, size: 18),
                          label: Text(
                            context.l10n.diveSites_import_detail_maxDepth(
                              units.formatDepth(site.maxDepth!, decimals: 0),
                            ),
                          ),
                        ),
                      if (site.hasCoordinates)
                        Chip(
                          avatar: const Icon(Icons.location_on, size: 18),
                          label: Text(
                            units.formatCoordinates(
                              site.location!.latitude,
                              site.location!.longitude,
                            ),
                          ),
                        ),
                      ..._tags(context).map((f) => Chip(label: Text(f))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Source
                  if (sourceCredit != null) ...[
                    Text(
                      context.l10n.diveSites_import_detail_source(
                        sourceCredit!,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Import button
                  if (!isImported)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onImport();
                        },
                        icon: const Icon(Icons.download),
                        label: Text(
                          context.l10n.diveSites_import_detail_importToMySites,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              context
                                  .l10n
                                  .diveSites_import_detail_alreadyImported,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
