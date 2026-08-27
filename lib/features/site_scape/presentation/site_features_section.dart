import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_glyph.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_marker_layer.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The site's diver-placed annotations, listed for review and editing.
/// Placement itself happens on the map, so [onAddFeature] hands control
/// back to the host (which opens the fullscreen map armed to place).
class SiteFeaturesSection extends ConsumerWidget {
  final String siteId;
  final VoidCallback onAddFeature;

  const SiteFeaturesSection({
    super.key,
    required this.siteId,
    required this.onAddFeature,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final features = ref.watch(siteFeaturesProvider(siteId)).valueOrNull ?? [];
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;

    String depthText(double meters) {
      final v = meters / unitInMeters;
      final text = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      return '$text ${depthUnit.symbol}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.siteFeature_sectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final f in features)
              ListTile(
                key: ValueKey('siteFeatureRow-${f.id}'),
                contentPadding: EdgeInsets.zero,
                leading: SiteFeatureGlyph(typeName: f.typeName, size: 16),
                title: Text(
                  f.name.isNotEmpty
                      ? f.name
                      : siteFeatureTypeLabel(l10n, f.typeName),
                ),
                subtitle: Text(
                  [
                    siteFeatureTypeLabel(l10n, f.typeName),
                    if (f.depthMeters != null) depthText(f.depthMeters!),
                  ].join(' • '),
                ),
                onTap: () => editSiteFeature(context, ref, f),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('siteFeatureAddButton'),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(l10n.siteFeature_addAction),
                onPressed: onAddFeature,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
