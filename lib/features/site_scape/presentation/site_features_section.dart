import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_glyph.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_marker_layer.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// The site's diver-placed annotations, listed for review and editing.
/// Placement itself happens on the map, so [onAddFeature] hands control
/// back to the host (which opens the fullscreen map armed to place). Null
/// for a site this profile may not change (a shared library site it only
/// reads): the list is then shown without add or edit.
class SiteFeaturesSection extends ConsumerWidget {
  final String siteId;
  final VoidCallback? onAddFeature;

  /// The features to show in place of those stored: a sitting's, once the
  /// diver has changed them (issue #4527).
  final List<SiteFeature>? features;

  const SiteFeaturesSection({
    super.key,
    required this.siteId,
    required this.onAddFeature,
    this.features,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final features =
        this.features ??
        ref.watch(siteFeaturesProvider(siteId)).valueOrNull ??
        const <SiteFeature>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The pencil, while the page is unlocked (issue #4527).
            RecordCardHeader(
              title: l10n.siteFeature_sectionTitle,
              leading: Icon(
                Icons.place_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            SiteFeatureRows(
              features: features,
              onTap: onAddFeature == null
                  ? null
                  : (f) => editSiteFeature(context, ref, f),
            ),
            if (onAddFeature != null)
              SiteFeatureAddButton(onPressed: onAddFeature!),
          ],
        ),
      ),
    );
  }
}

/// One row per feature, its depth in the diver's unit; [onTap] opens one.
class SiteFeatureRows extends ConsumerWidget {
  const SiteFeatureRows({super.key, required this.features, this.onTap});

  final List<SiteFeature> features;
  final ValueChanged<SiteFeature>? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;

    String depthText(double meters) {
      final v = meters / unitInMeters;
      final text = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      return '$text ${depthUnit.symbol}';
    }

    final tap = onTap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            onTap: tap == null ? null : () => tap(f),
          ),
      ],
    );
  }
}

/// "Add feature": opens the map armed to place one.
class SiteFeatureAddButton extends StatelessWidget {
  const SiteFeatureAddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      key: const ValueKey('siteFeatureAddButton'),
      icon: const Icon(Icons.add_location_alt_outlined),
      label: Text(context.l10n.siteFeature_addAction),
      onPressed: onPressed,
    ),
  );
}
