import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/widgets/duplicate_badge.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card displaying a dive entry for selection in the import wizard.
///
/// Shows dive date, depth, duration, and site name with a selection
/// checkbox and optional duplicate match badge with confidence score.
/// When a probable duplicate is detected, shows an expandable
/// [DiveComparisonCard] with profile overlay, field comparison, and
/// resolution action buttons.
class ImportDiveCard extends StatefulWidget {
  const ImportDiveCard({
    super.key,
    required this.diveData,
    required this.index,
    required this.isSelected,
    required this.onToggle,
    this.matchResult,
    this.resolution,
    this.onResolutionChanged,
  });

  final Map<String, dynamic> diveData;
  final int index;
  final bool isSelected;
  final VoidCallback onToggle;
  final DiveMatchResult? matchResult;
  final DiveDuplicateResolution? resolution;
  final ValueChanged<DiveDuplicateResolution>? onResolutionChanged;

  @override
  State<ImportDiveCard> createState() => _ImportDiveCardState();
}

class _ImportDiveCardState extends State<ImportDiveCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateTime = widget.diveData['dateTime'] as DateTime?;
    final maxDepth = widget.diveData['maxDepth'] as double?;
    final duration = widget.diveData['duration'] as Duration?;
    final runtime = widget.diveData['runtime'] as Duration?;
    final siteName = widget.diveData['siteName'] as String?;
    final diveNumber = widget.diveData['diveNumber'] as int?;

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

    final hasMatch =
        widget.matchResult != null && widget.matchResult!.score >= 0.5;

    return Card(
      elevation: widget.isSelected ? 2 : 0,
      color: widget.isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Column(
        children: [
          Semantics(
            button: true,
            label: context.l10n.universalImport_semantics_toggleSelection(
              title,
            ),
            child: InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                _buildMetrics(
                                  theme,
                                  depthStr,
                                  durationStr,
                                  siteName,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.matchResult != null) ...[
                          const SizedBox(width: 8),
                          DuplicateBadge(
                            isProbable: widget.matchResult!.score >= 0.7,
                            label: context.l10n
                                .universalImport_label_percentMatch(
                                  (widget.matchResult!.score * 100)
                                      .toStringAsFixed(0),
                                ),
                          ),
                        ],
                      ],
                    ),
                    // Expand/collapse toggle for match comparison
                    if (hasMatch)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          icon: Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                          ),
                          label: Text(
                            _isExpanded ? 'Hide comparison' : 'Compare dives',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Expandable comparison card
          if (hasMatch && _isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: DiveComparisonCard(
                embedded: true,
                incoming: IncomingDiveData.fromImportMap(widget.diveData),
                existingDiveId: widget.matchResult!.diveId,
                matchScore: widget.matchResult!.score,
                incomingLabel: 'Imported',
                onSkip: () => widget.onResolutionChanged?.call(
                  DiveDuplicateResolution.skip,
                ),
                onImportAsNew: () => widget.onResolutionChanged?.call(
                  DiveDuplicateResolution.importAsNew,
                ),
                onConsolidate: () => widget.onResolutionChanged?.call(
                  DiveDuplicateResolution.consolidate,
                ),
              ),
            ),
        ],
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
          color: widget.isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
        color: widget.isSelected ? colorScheme.primary : Colors.transparent,
      ),
      child: widget.isSelected
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
