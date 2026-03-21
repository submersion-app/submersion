import 'package:flutter/material.dart';

import 'package:submersion/core/domain/models/dive_comparison_result.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/overlaid_profile_chart.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Shared comparison card for dive duplicate resolution.
///
/// Used by both the dive computer download flow ([SummaryStepWidget]) and the
/// file import flow ([ImportDiveCard]).  Fetches the existing dive and profile
/// from Riverpod providers and renders the hybrid comparison layout.
class DiveComparisonCard extends ConsumerWidget {
  final IncomingDiveData incoming;
  final String existingDiveId;
  final double matchScore;
  final String existingLabel;
  final String incomingLabel;
  final VoidCallback? onSkip;
  final VoidCallback? onImportAsNew;
  final VoidCallback? onConsolidate;

  const DiveComparisonCard({
    super.key,
    required this.incoming,
    required this.existingDiveId,
    required this.matchScore,
    this.existingLabel = 'Existing',
    this.incomingLabel = 'Downloaded',
    this.onSkip,
    this.onImportAsNew,
    this.onConsolidate,
  });

  Color _badgeColor(ColorScheme colorScheme) {
    if (matchScore >= 0.9) return colorScheme.primary;
    if (matchScore >= 0.7) return Colors.amber.shade700;
    return colorScheme.error;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final existingAsync = ref.watch(diveProvider(existingDiveId));
    final profileAsync = ref.watch(diveProfileProvider(existingDiveId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: existingAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Error loading dive data'),
        ),
        data: (existingDive) {
          if (existingDive == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Existing dive not found'),
            );
          }

          final comparison = compareForConsolidation(existingDive, incoming);
          final existingProfile = profileAsync.valueOrNull ?? [];
          final diveNum = existingDive.diveNumber;
          final effectiveExistingLabel = diveNum != null
              ? '$existingLabel (#$diveNum)'
              : existingLabel;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Match Header
              _buildMatchHeader(
                context,
                comparison,
                effectiveExistingLabel,
                units,
              ),

              // 2. Overlaid Profiles
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: OverlaidProfileChart(
                  existingProfile: existingProfile,
                  incomingProfile: incoming.profile,
                  existingLabel: _computerLabel(
                    existingDive.diveComputerModel,
                    existingDive.diveComputerSerial,
                  ),
                  incomingLabel: _computerLabel(
                    incoming.computerModel,
                    incoming.computerSerial,
                  ),
                  height: 80,
                ),
              ),

              // 3. Same Fields Summary
              if (comparison.sameFields.isNotEmpty)
                _buildSameSummary(context, comparison, units),

              // 4. Differences Table
              _buildDiffTable(
                context,
                comparison,
                effectiveExistingLabel,
                units,
              ),

              // 5. Action Buttons
              _buildActionButtons(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchHeader(
    BuildContext context,
    DiveComparisonResult comparison,
    String label,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percent = (matchScore * 100).toStringAsFixed(0);

    // Gather shared data to display once.
    final sharedParts = <String>[];
    for (final f in comparison.sameFields) {
      if (f.name == 'date/time' || f.name == 'max depth') {
        sharedParts.add(_formatFieldValue(f.type, f.rawValue, units));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _badgeColor(colorScheme),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$percent%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sharedParts.isNotEmpty
                  ? sharedParts.join(' \u00b7 ')
                  : 'Potential match',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSameSummary(
    BuildContext context,
    DiveComparisonResult comparison,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fieldNames = comparison.sameFields.map((f) => f.name).toList();
    final summary = fieldNames.join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.check, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Same: $summary',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffTable(
    BuildContext context,
    DiveComparisonResult comparison,
    String existingLabel,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIFFERENCES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          // Column headers
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text('', style: theme.textTheme.labelSmall),
              ),
              Expanded(
                child: Text(
                  existingLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  incomingLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 4),
          // Diff rows
          ...comparison.diffFields.map(
            (field) => _buildDiffRow(context, field, units),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffRow(
    BuildContext context,
    DiffField field,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Format values using UnitFormatter for unit-aware display.
    final existingStr =
        field.existingText ??
        (field.existingRaw != null
            ? _formatFieldValue(field.type, field.existingRaw, units)
            : null);
    final incomingStr =
        field.incomingText ??
        (field.incomingRaw != null
            ? _formatFieldValue(field.type, field.incomingRaw, units)
            : null);

    String formatValue(String? value) => value ?? 'not recorded';
    final hasExisting = existingStr != null;
    final hasIncoming = incomingStr != null;
    final isChanged = hasExisting && hasIncoming && field.name != 'computer';

    // Format incoming value with delta.
    String incomingDisplay = formatValue(incomingStr);
    if (field.delta != null && field.delta != 0) {
      final sign = field.delta! > 0 ? '+' : '';
      if (field.type == ComparisonFieldType.duration) {
        final deltaSec = field.delta!.round();
        final deltaMin = deltaSec ~/ 60;
        final remSec = deltaSec.abs() % 60;
        final deltaStr = deltaMin != 0
            ? '$sign${deltaMin}m${remSec > 0 ? ' ${remSec}s' : ''}'
            : '$sign${deltaSec}s';
        incomingDisplay = '$incomingStr ($deltaStr)';
      } else {
        incomingDisplay =
            '$incomingStr ($sign${field.delta!.toStringAsFixed(1)})';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              field.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              formatValue(existingStr),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              incomingDisplay,
              style: theme.textTheme.bodySmall?.copyWith(
                color: !hasIncoming
                    ? colorScheme.onSurfaceVariant
                    : (isChanged ? Colors.amber.shade700 : null),
                fontStyle: !hasIncoming ? FontStyle.italic : null,
                fontWeight: isChanged ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ActionButton(
            label: 'Skip',
            subtitle: 'Discard this download',
            onPressed: onSkip,
            style: _ActionButtonStyle.text,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: 'Import as New',
            subtitle: 'Save as separate dive',
            onPressed: onImportAsNew,
            style: _ActionButtonStyle.outlined,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: 'Consolidate',
            subtitle: 'Add as 2nd computer reading',
            onPressed: onConsolidate,
            style: _ActionButtonStyle.filledTonal,
          ),
        ],
      ),
    );
  }

  /// Format a raw field value using UnitFormatter for unit-aware display.
  static String _formatFieldValue(
    ComparisonFieldType type,
    double? rawValue,
    UnitFormatter units,
  ) {
    if (rawValue == null) return '--';
    switch (type) {
      case ComparisonFieldType.depth:
        return units.formatDepth(rawValue);
      case ComparisonFieldType.temperature:
        return units.formatTemperature(rawValue);
      case ComparisonFieldType.duration:
        return '${(rawValue / 60).round()} min';
      case ComparisonFieldType.dateTime:
      case ComparisonFieldType.text:
        return rawValue.toString();
    }
  }

  String _computerLabel(String? model, String? serial) {
    final parts = <String>[];
    if (model != null) parts.add(model);
    if (serial != null) {
      final truncated = serial.length > 6
          ? '...${serial.substring(serial.length - 6)}'
          : serial;
      parts.add(truncated);
    }
    return parts.isEmpty ? 'Unknown' : parts.join(' \u00b7 ');
  }
}

enum _ActionButtonStyle { text, outlined, filledTonal }

class _ActionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback? onPressed;
  final _ActionButtonStyle style;

  const _ActionButton({
    required this.label,
    required this.subtitle,
    this.onPressed,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );

    switch (style) {
      case _ActionButtonStyle.text:
        return TextButton(onPressed: onPressed, child: child);
      case _ActionButtonStyle.outlined:
        return OutlinedButton(onPressed: onPressed, child: child);
      case _ActionButtonStyle.filledTonal:
        return FilledButton.tonal(onPressed: onPressed, child: child);
    }
  }
}
