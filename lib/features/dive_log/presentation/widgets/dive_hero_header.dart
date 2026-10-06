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

/// A dive's hero header: map backdrop, number badge, name and site, entry and
/// exit times, rating/mode/type badges, and the depth, runtime, bottom-time
/// and water-temperature stat row.
///
/// Shared by DiveDetailPage and the CNS/OTU readout. The detail page passes
/// its per-source stat values, its data-quality chip ([belowTitle]) and a
/// site link ([onSiteTap]); the readout passes none of them and gets a purely
/// decorative header for the dive its load is projected from.
class DiveHeroHeader extends ConsumerWidget {
  final Dive dive;
  final UnitFormatter units;

  /// Max depth to show in place of the dive's own (a viewed source's).
  final double? maxDepth;

  /// Water temperature to show in place of the dive's own.
  final double? waterTemp;

  /// Runtime text in place of [formatRuntime] of the dive.
  final String? runtimeText;

  /// Bottom-time text in place of [formatBottomTime] of the dive.
  final String? bottomTimeText;

  /// Shown under the dive's name, above the site lines.
  final Widget? belowTitle;

  /// Opens the dive's site. When set and the header has a map, the whole
  /// card is a button; when null the map is purely decorative.
  final VoidCallback? onSiteTap;

  const DiveHeroHeader({
    required this.dive,
    required this.units,
    this.maxDepth,
    this.waterTemp,
    this.runtimeText,
    this.bottomTimeText,
    this.belowTitle,
    this.onSiteTap,
    super.key,
  });

  /// The dive's stored runtime, else its entry/exit span.
  static String formatRuntime(Dive dive) {
    if (dive.runtime != null) {
      return '${dive.runtime!.inMinutes} min';
    }
    // Calculate from entry/exit times if available
    if (dive.entryTime != null && dive.exitTime != null) {
      final calculated = dive.exitTime!.difference(dive.entryTime!);
      return '${calculated.inMinutes} min';
    }
    return '--';
  }

  /// The dive's stored bottom time.
  static String formatBottomTime(Dive dive) =>
      formatBottomTimeSeconds(dive.bottomTime?.inSeconds);

  /// Bottom time from a seconds count, '--' when unknown.
  static String formatBottomTimeSeconds(int? seconds) =>
      seconds != null ? '${seconds ~/ 60} min' : '--';

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
    // A type absent from diveTypesById (not yet loaded, or deleted out from
    // under a still-referencing dive) stays shown -- unknown is not the same
    // as explicitly hidden.
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
              // Scales with the header's own width instead of a flat cap, so
              // a wide detail pane can spell out more type badges before
              // collapsing to "+N" while a narrow one still reserves enough
              // room for the site name/dates column on the left.
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
                            // Pin the pre-scale size (CircleAvatar's implicit
                            // titleMedium default) so FittedBox scales from a
                            // theme-independent baseline.
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
                        ?belowTitle,
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
                          '${context.l10n.diveLog_detail_label_entry} ${units.formatDateTimeBullet(dive.effectiveEntryTime)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (dive.exitTime != null)
                          Text(
                            '${context.l10n.diveLog_detail_label_exit} ${units.formatDateTimeBullet(dive.exitTime!)}',
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
                              // Same ink-centering fix as DiveModeBadge: without
                              // it this number's default line leading isn't
                              // split evenly around its own glyph, so it
                              // doesn't sit on the same visual line as the star
                              // icon next to it.
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
                        // Capped rather than left unbounded: Row hands a
                        // non-flex child unbounded width, which would let a
                        // long run of type badges grow without limit instead of
                        // wrapping under the rating/mode row. The cap itself
                        // scales with the header's width (see badgeMaxWidth)
                        // rather than a flat constant.
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
                units.formatDepth(maxDepth ?? dive.maxDepth),
                context.l10n.diveLog_detail_stat_maxDepth,
              ),
              _statItem(
                context,
                Icons.timelapse,
                runtimeText ?? formatRuntime(dive),
                context.l10n.diveLog_detail_stat_runtime,
              ),
              _statItem(
                context,
                Icons.timer,
                bottomTimeText ?? formatBottomTime(dive),
                context.l10n.diveLog_detail_stat_bottomTime,
              ),
              _statItem(
                context,
                Icons.thermostat,
                units.formatTemperature(waterTemp ?? dive.waterTemp),
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

    final mapped = Stack(
      children: [
        // Map background (decorative, non-interactive), faded into the
        // card toward the bottom.
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
        // Content
        content,
      ],
    );

    final onTap = onSiteTap;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? mapped
          : Semantics(
              button: true,
              label:
                  '${context.l10n.diveLog_detail_viewSite} '
                  '${dive.site?.name ?? ''}',
              child: InkWell(onTap: onTap, child: mapped),
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
}
