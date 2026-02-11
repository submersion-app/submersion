import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/universal_import/presentation/widgets/duplicate_badge.dart';

/// Card displaying a dive entry for selection in the import wizard.
///
/// Shows dive date, depth, duration, and site name with a selection
/// checkbox and optional duplicate match badge with confidence score.
class ImportDiveCard extends StatelessWidget {
  const ImportDiveCard({
    super.key,
    required this.diveData,
    required this.index,
    required this.isSelected,
    required this.onToggle,
    this.matchResult,
  });

  final Map<String, dynamic> diveData;
  final int index;
  final bool isSelected;
  final VoidCallback onToggle;
  final DiveMatchResult? matchResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateTime = diveData['dateTime'] as DateTime?;
    final maxDepth = diveData['maxDepth'] as double?;
    final duration = diveData['duration'] as Duration?;
    final runtime = diveData['runtime'] as Duration?;
    final siteName = diveData['siteName'] as String?;
    final diveNumber = diveData['diveNumber'] as int?;

    final dateStr = dateTime != null
        ? DateFormat('MMM d, y - HH:mm').format(dateTime)
        : context.l10n.universalImport_label_unknownDate;

    final depthStr = maxDepth != null ? '${maxDepth.toStringAsFixed(1)}m' : '';
    final durationMin = (runtime ?? duration)?.inMinutes;
    final durationStr = durationMin != null ? '${durationMin}min' : '';

    final title = diveNumber != null
        ? context.l10n.universalImport_label_diveNumber(diveNumber)
        : dateStr;
    final subtitle = diveNumber != null
        ? dateStr
        : [
            depthStr,
            durationStr,
            siteName ?? '',
          ].where((s) => s.isNotEmpty).join(' / ');

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Semantics(
        button: true,
        label: context.l10n.universalImport_semantics_toggleSelection(title),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildCheckbox(colorScheme),
                const SizedBox(width: 12),
                Icon(
                  Icons.scuba_diving,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (diveNumber != null) ...[
                        const SizedBox(height: 2),
                        _buildMetrics(theme, depthStr, durationStr, siteName),
                      ],
                    ],
                  ),
                ),
                if (matchResult != null) ...[
                  const SizedBox(width: 8),
                  DuplicateBadge(
                    isProbable: matchResult!.score >= 0.7,
                    label: context.l10n.universalImport_label_percentMatch(
                      (matchResult!.score * 100).toStringAsFixed(0),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(ColorScheme colorScheme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
        color: isSelected ? colorScheme.primary : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }

  Widget _buildMetrics(
    ThemeData theme,
    String depthStr,
    String durationStr,
    String? siteName,
  ) {
    final parts = [
      depthStr,
      durationStr,
      siteName ?? '',
    ].where((s) => s.isNotEmpty).join(' / ');

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
