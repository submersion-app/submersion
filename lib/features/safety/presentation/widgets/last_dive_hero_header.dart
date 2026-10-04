import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/header_map_backdrop.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/ink_centered_text_style.dart';

/// Visual twin of DiveDetailPage's hero header (map backdrop, number badge,
/// rating/mode/type badges, the depth/runtime/bottom-time/water-temp stat
/// row), scoped to the one dive a CNS/OTU readout is projected from.
///
/// Not a reuse of that header: it is a private method wired to
/// DiveDetailPage's own navigation, favorite toggle and data-quality chip,
/// none of which apply on a safety readout that isn't browsing the dive
/// itself. This rebuilds just the look from the same building-block widgets
/// (HeaderMapBackdrop, DiveLocationsMap, DiveModeBadge, DiveTypeBadgeRow).
/// Unlike the original, the map is purely decorative here -- it does not
/// link through to the dive site.
class LastDiveHeroHeader extends ConsumerWidget {
  final Dive dive;
  final UnitFormatter units;

  const LastDiveHeroHeader({
    required this.dive,
    required this.units,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryLoc = dive.entryLocation;
    final exitLoc = dive.exitLocation;
    final siteLoc = dive.site?.location;
    final hasGps = entryLoc != null || exitLoc != null;
    final hasLocation = siteLoc != null || hasGps;
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    final diveTypesById = {
      for (final t
          in ref.watch(diveTypesProvider).value ?? const <DiveTypeEntity>[])
        t.id: t,
    };
    final visibleHeaderTypeIds = dive.diveTypeIds
        .where((id) => diveTypesById[id]?.showInDetailHeader ?? true)
        .toList();

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final badgeMaxWidth = (headerConstraints.maxWidth * 0.35).clamp(
                120.0,
                280.0,
              );
              return Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '#${dive.diveNumber ?? '-'}',
                          maxLines: 1,
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dive.effectiveName ??
                              dive.site?.name ??
                              context.l10n.diveLog_listPage_unknownSite,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (dive.effectiveName != null && dive.site != null)
                          Text(
                            dive.site!.name,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        if (dive.site?.locationString.isNotEmpty == true)
                          Text(
                            dive.site!.locationString,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        Text(
                          '${context.l10n.diveLog_detail_label_entry} '
                          '${units.formatDateTimeBullet(dive.effectiveEntryTime)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (dive.exitTime != null)
                          Text(
                            '${context.l10n.diveLog_detail_label_exit} '
                            '${units.formatDateTimeBullet(dive.exitTime!)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (dive.rating != null) ...[
                            ExcludeSemantics(
                              child: Icon(
                                Icons.star,
                                color: Colors.amber.shade600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${dive.rating}',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.inkCentered,
                              textHeightBehavior: inkCenteredTextHeightBehavior,
                            ),
                            const SizedBox(width: 8),
                          ],
                          DiveModeBadge(mode: dive.diveMode),
                        ],
                      ),
                      if (visibleHeaderTypeIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: badgeMaxWidth),
                          child: DiveTypeBadgeRow(
                            labels: [
                              for (final typeId in visibleHeaderTypeIds)
                                diveTypeShortLabel(
                                  context.l10n,
                                  typeId,
                                  typesById: diveTypesById,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                context,
                Icons.arrow_downward,
                units.formatDepth(dive.maxDepth),
                context.l10n.diveLog_detail_stat_maxDepth,
              ),
              _statItem(
                context,
                Icons.timelapse,
                _formatRuntime(dive),
                context.l10n.diveLog_detail_stat_runtime,
              ),
              _statItem(
                context,
                Icons.timer,
                _formatBottomTime(dive),
                context.l10n.diveLog_detail_stat_bottomTime,
              ),
              _statItem(
                context,
                Icons.thermostat,
                units.formatTemperature(dive.waterTemp),
                context.l10n.diveLog_detail_stat_waterTemp,
              ),
            ],
          ),
        ],
      ),
    );

    if (!hasLocation) {
      return Card(clipBehavior: Clip.antiAlias, child: content);
    }

    final LatLng mapCenter = entryLoc != null
        ? LatLng(entryLoc.latitude, entryLoc.longitude)
        : exitLoc != null
        ? LatLng(exitLoc.latitude, exitLoc.longitude)
        : LatLng(siteLoc!.latitude, siteLoc.longitude);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: HeaderMapBackdrop(
              fadeColor: cardColor,
              child: DiveLocationsMap(
                entry: entryLoc,
                exit: exitLoc,
                site: hasGps ? null : siteLoc,
                interactive: false,
                initialCenter: mapCenter,
                initialZoom: 12.0,
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _statItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        ExcludeSemantics(
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Mirrors DiveDetailPage's no-active-source fallback: the dive's own
  /// runtime, else the entry/exit span.
  String _formatRuntime(Dive dive) {
    if (dive.runtime != null) return '${dive.runtime!.inMinutes} min';
    if (dive.entryTime != null && dive.exitTime != null) {
      return '${dive.exitTime!.difference(dive.entryTime!).inMinutes} min';
    }
    return '--';
  }

  /// Mirrors DiveDetailPage's no-active-source fallback: the dive's own
  /// stored bottom time (not recomputed from profile samples -- there is no
  /// per-source toggle on this page).
  String _formatBottomTime(Dive dive) {
    final seconds = dive.bottomTime?.inSeconds;
    return seconds != null ? '${seconds ~/ 60} min' : '--';
  }
}
