import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/altitude_group_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Informational note shown when the site records a meaningful altitude
/// but the dive itself has none, so deco replay ran at sea-level pressure.
class DiveAltitudeMismatchNote extends StatelessWidget {
  const DiveAltitudeMismatchNote({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.terrain, color: colorScheme.onSurfaceVariant),
        title: Text(context.l10n.diveLog_detail_altitudeMismatch_title),
        subtitle: Text(context.l10n.diveLog_detail_altitudeMismatch_subtitle),
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: () => context.push('/dives/${dive.id}/edit'),
      ),
    );
  }
}

/// The Altitude card, for a dive logged above sea level.
class DiveAltitudeSection extends ConsumerWidget {
  const DiveAltitudeSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dive.altitude == null || dive.altitude! <= 0) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final units = ref.watch(unitFormatterProvider);

    final altitudeGroup = AltitudeGroup.fromAltitude(dive.altitude);
    final pressure =
        dive.surfacePressure ??
        AltitudeCalculator.calculateBarometricPressure(dive.altitude!);

    Color getGroupColor(AltitudeWarningLevel level) {
      switch (level) {
        case AltitudeWarningLevel.none:
          return colorScheme.surfaceContainerHighest;
        case AltitudeWarningLevel.info:
          return colorScheme.primaryContainer;
        case AltitudeWarningLevel.caution:
          return colorScheme.tertiaryContainer;
        case AltitudeWarningLevel.warning:
          return colorScheme.errorContainer;
        case AltitudeWarningLevel.severe:
          return colorScheme.error;
      }
    }

    Color getGroupForeground(AltitudeWarningLevel level) {
      switch (level) {
        case AltitudeWarningLevel.none:
          return colorScheme.onSurface;
        case AltitudeWarningLevel.info:
          return colorScheme.onPrimaryContainer;
        case AltitudeWarningLevel.caution:
          return colorScheme.onTertiaryContainer;
        case AltitudeWarningLevel.warning:
          return colorScheme.onErrorContainer;
        case AltitudeWarningLevel.severe:
          return colorScheme.onError;
      }
    }

    IconData getGroupIcon(AltitudeWarningLevel level) {
      switch (level) {
        case AltitudeWarningLevel.none:
          return Icons.check_circle_outline;
        case AltitudeWarningLevel.info:
          return Icons.info_outline;
        case AltitudeWarningLevel.caution:
          return Icons.warning_amber;
        case AltitudeWarningLevel.warning:
          return Icons.warning;
        case AltitudeWarningLevel.severe:
          return Icons.dangerous;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terrain, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveLog_detail_section_altitudeDive,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        context.l10n.diveLog_detail_label_elevation,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        units.formatAltitude(dive.altitude),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        context.l10n.diveLog_detail_label_surfacePressure,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        units.formatSurfacePressure(pressure),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (altitudeGroup != AltitudeGroup.seaLevel) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: getGroupColor(altitudeGroup.warningLevel),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      getGroupIcon(altitudeGroup.warningLevel),
                      size: 24,
                      color: getGroupForeground(altitudeGroup.warningLevel),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            altitudeGroup.localizedName(context.l10n),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: getGroupForeground(
                                    altitudeGroup.warningLevel,
                                  ),
                                ),
                          ),
                          Text(
                            altitudeGroup.rangeDescription,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: getGroupForeground(
                                    altitudeGroup.warningLevel,
                                  ).withValues(alpha: 0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
