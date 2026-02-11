import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card displaying per-cylinder SAC (Surface Air Consumption) metrics.
///
/// Shows tank name, gas mix, SAC rate, pressure usage, and data quality indicator.
class CylinderSacCard extends StatelessWidget {
  /// The cylinder SAC data to display
  final CylinderSac cylinderSac;

  /// Unit formatter for converting values to user preferences
  final UnitFormatter units;

  /// Which SAC unit to display (L/min or bar/min)
  final SacUnit sacUnit;

  /// Whether this card is selected/highlighted
  final bool isSelected;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  const CylinderSacCard({
    super.key,
    required this.cylinderSac,
    required this.units,
    required this.sacUnit,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Semantics(
        button: onTap != null,
        label: listItemLabel(
          title: cylinderSac.displayLabel,
          subtitle: cylinderSac.gasMix.name,
          status: cylinderSac.hasValidSac ? 'SAC: ${_formatSacValue()}' : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Tank name + role badge
                Row(
                  children: [
                    // Tank icon
                    ExcludeSemantics(
                      child: Icon(
                        Icons.propane_tank,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tank name
                    Expanded(
                      child: Text(
                        cylinderSac.displayLabel,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(
                          colorScheme,
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cylinderSac.role.displayName,
                        style: textTheme.labelSmall?.copyWith(
                          color: _getRoleColor(colorScheme),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Gas mix
                Text(
                  cylinderSac.gasMix.name,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 12),

                // SAC rate (prominent display)
                if (cylinderSac.hasValidSac) ...[
                  Row(
                    children: [
                      Text(
                        _formatSacValue(),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      // Data quality indicator
                      _buildDataQualityBadge(context),
                    ],
                  ),
                ] else ...[
                  Text(
                    context.l10n.diveLog_cylinderSac_noSac,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Pressure usage
                if (cylinderSac.startPressure != null &&
                    cylinderSac.endPressure != null) ...[
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.trending_down,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatPressureRange(),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      // Usage duration
                      if (cylinderSac.usageDuration != null) ...[
                        ExcludeSemantics(
                          child: Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cylinderSac.durationFormatted,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Average depth during use
                if (cylinderSac.avgDepthDuringUse != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.straighten,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.diveLog_cylinderSac_avgDepth(
                          units.formatDepth(cylinderSac.avgDepthDuringUse!),
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
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

  /// Format SAC value based on unit setting
  String _formatSacValue() {
    if (sacUnit == SacUnit.litersPerMin && cylinderSac.sacVolume != null) {
      final value = units.convertVolume(cylinderSac.sacVolume!);
      return '${value.toStringAsFixed(1)} ${units.volumeSymbol}/min';
    } else if (cylinderSac.sacRate != null) {
      final value = units.convertPressure(cylinderSac.sacRate!);
      return '${value.toStringAsFixed(1)} ${units.pressureSymbol}/min';
    }
    return '--';
  }

  /// Format pressure range (start → end)
  String _formatPressureRange() {
    final start = units.convertPressure(cylinderSac.startPressure!.toDouble());
    final end = units.convertPressure(cylinderSac.endPressure!.toDouble());
    final used = start - end;
    return '${start.toInt()} → ${end.toInt()} (${used.toInt()} ${units.pressureSymbol})';
  }

  /// Build data quality badge (enhanced vs basic)
  Widget _buildDataQualityBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (cylinderSac.hasTimeSeriesData) {
      return Tooltip(
        message: context.l10n.diveLog_cylinderSac_tooltip_aiData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 12, color: Colors.green.shade700),
              const SizedBox(width: 2),
              Text(
                context.l10n.diveLog_cylinderSac_badge_ai,
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Tooltip(
        message: context.l10n.diveLog_cylinderSac_tooltip_basicData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            context.l10n.diveLog_cylinderSac_badge_basic,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
  }

  /// Get color for tank role badge
  Color _getRoleColor(ColorScheme colorScheme) {
    return switch (cylinderSac.role.name) {
      'backGas' => colorScheme.primary,
      'stage' => Colors.orange,
      'deco' => Colors.purple,
      'bailout' => Colors.red,
      'sidemountLeft' || 'sidemountRight' => colorScheme.secondary,
      'pony' => Colors.teal,
      'diluent' || 'oxygenSupply' => Colors.blue,
      _ => colorScheme.primary,
    };
  }
}

/// A list of cylinder SAC cards for multi-tank dives
class CylinderSacList extends StatelessWidget {
  /// List of cylinder SAC data
  final List<CylinderSac> cylinders;

  /// Unit formatter
  final UnitFormatter units;

  /// Which SAC unit to display
  final SacUnit sacUnit;

  /// Whether to show in a horizontal scroll view
  final bool horizontal;

  const CylinderSacList({
    super.key,
    required this.cylinders,
    required this.units,
    required this.sacUnit,
    this.horizontal = true,
  });

  @override
  Widget build(BuildContext context) {
    if (cylinders.isEmpty) {
      return const SizedBox.shrink();
    }

    if (horizontal) {
      return SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cylinders.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            return SizedBox(
              width: 200,
              child: CylinderSacCard(
                cylinderSac: cylinders[index],
                units: units,
                sacUnit: sacUnit,
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: cylinders.map((cylinder) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CylinderSacCard(
            cylinderSac: cylinder,
            units: units,
            sacUnit: sacUnit,
          ),
        );
      }).toList(),
    );
  }
}
