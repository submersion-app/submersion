import 'package:flutter/material.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/altitude_group_label.dart';
import 'package:submersion/features/dive_log/presentation/info/altitude_info.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// Informational note shown when the site records a meaningful altitude
/// but the dive itself has none, so deco replay ran at sea-level pressure.
class DiveAltitudeMismatchNote extends StatelessWidget {
  const DiveAltitudeMismatchNote({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Unlocked, the note sits in the Altitude card's frame and opens it.
    // Locked, it reads only (issue #4527).
    final open = RecordCardFrameScope.maybeOf(context)?.onOpen;
    return Card(
      child: ListTile(
        leading: Icon(Icons.terrain, color: colorScheme.onSurfaceVariant),
        title: Text(context.l10n.diveLog_detail_altitudeMismatch_title),
        subtitle: Text(context.l10n.diveLog_detail_altitudeMismatch_subtitle),
        trailing: open == null
            ? null
            : const Icon(Icons.edit_outlined, size: 18),
        onTap: open,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordCardHeader(
              leading: Icon(
                Icons.terrain,
                size: 20,
                color: colorScheme.primary,
              ),
              title: context.l10n.diveLog_detail_section_altitudeDive,
              trailing: HeaderInfoButton(
                title: context.l10n.diveLog_detail_section_altitudeDive,
                content: (context) =>
                    altitudeInfo(context.l10n, infoUnits(context)),
              ),
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
              AltitudeGroupBanner(group: altitudeGroup),
            ],
          ],
        ),
      ),
    );
  }
}

/// The coloured banner naming an altitude group and its range, shared by
/// the Altitude card and its editor. Draws nothing at sea level.
class AltitudeGroupBanner extends ConsumerWidget {
  const AltitudeGroupBanner({super.key, required this.group});

  final AltitudeGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (group == AltitudeGroup.seaLevel) return const SizedBox.shrink();

    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground, icon) = switch (group.warningLevel) {
      AltitudeWarningLevel.none => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        Icons.check_circle_outline,
      ),
      AltitudeWarningLevel.info => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.info_outline,
      ),
      AltitudeWarningLevel.caution => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.warning_amber,
      ),
      AltitudeWarningLevel.warning => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.warning,
      ),
      AltitudeWarningLevel.severe => (
        scheme.error,
        scheme.onError,
        Icons.dangerous,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.localizedName(context.l10n),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
                Text(
                  group.localizedRange(context.l10n, units),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
