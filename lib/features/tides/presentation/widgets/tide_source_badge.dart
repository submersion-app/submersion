import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact provenance line for the tide section: which data tier is
/// backing the predictions, tappable for datum and caveat details.
class TideSourceBadge extends ConsumerWidget {
  final GeoPoint location;

  const TideSourceBadge({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceAsync = ref.watch(tideDataSourceProvider(location));
    final TideDataSource? source = sourceAsync.value;
    if (source == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final String label;
    final IconData icon;
    switch (source.kind) {
      case TideDataSourceKind.noaaStation:
        label = context.l10n.tides_source_noaaStation(
          source.stationName ?? source.stationId ?? '',
          units.formatGeoDistance((source.distanceKm ?? 0) * 1000),
        );
        icon = Icons.verified_outlined;
      case TideDataSourceKind.fesModel:
        label = context.l10n.tides_source_modelEstimate;
        icon = Icons.public;
    }

    return InkWell(
      onTap: () => _showDetails(context, source),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, TideDataSource source) {
    final isStation = source.kind == TideDataSourceKind.noaaStation;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.tides_source_sheetTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (isStation) ...[
                  Text(source.stationName ?? source.stationId ?? ''),
                  const SizedBox(height: 8),
                  Text(
                    source.mllwDatum
                        ? context.l10n.tides_source_datumMllw
                        : context.l10n.tides_source_datumMsl,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(context.l10n.tides_source_modelCaveat),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.tides_source_datumMsl,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
