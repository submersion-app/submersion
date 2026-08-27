import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart'
    as domain;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_glyph.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Read-only readout of what the diver recorded for [feature]: what it is,
/// how deep, which way it runs, and any notes.
///
/// Tapping a feature is a "show me this" gesture, not a "change this" one,
/// so both the 2D map and the 3D terrain open this rather than the editor.
/// Surfaces that can edit pass [onEdit]; it closes the sheet first, so the
/// editor opens over the map instead of stacking on top of this sheet. 3D
/// omits it, keeping placement and editing a 2D-map concern.
Future<void> showSiteFeatureInfoSheet(
  BuildContext context,
  WidgetRef ref,
  domain.SiteFeature feature, {
  VoidCallback? onEdit,
}) {
  final l10n = context.l10n;
  final depthUnit = ref.read(settingsProvider).depthUnit;
  final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          key: const ValueKey('siteFeatureInfoSheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SiteFeatureGlyph(typeName: feature.typeName, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature.name.isNotEmpty
                        ? feature.name
                        : siteFeatureTypeLabel(l10n, feature.typeName),
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    key: const ValueKey('siteFeatureInfoEditButton'),
                    icon: const Icon(Icons.edit),
                    tooltip: l10n.common_action_edit,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onEdit();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(siteFeatureTypeLabel(l10n, feature.typeName)),
            if (feature.depthMeters != null)
              Text(
                '${l10n.siteFeature_field_depth}: '
                '${(feature.depthMeters! / unitInMeters).toStringAsFixed(1)} '
                '${depthUnit.symbol}',
              ),
            if (feature.bearingDeg != null)
              Text(
                '${l10n.siteFeature_field_bearing}: '
                '${feature.bearingDeg!.round()}',
              ),
            if (feature.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(feature.notes),
            ],
          ],
        ),
      ),
    ),
  );
}
