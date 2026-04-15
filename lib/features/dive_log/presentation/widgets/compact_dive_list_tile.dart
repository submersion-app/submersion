import 'package:flutter/material.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Two-line compact card tile for the dive list.
///
/// Line 1: dive number badge | title slot | date slot | chevron
/// Line 2: (indented) stat1 slot | stat2 slot
class CompactDiveListTile extends ConsumerWidget {
  final String diveId;
  final int diveNumber;
  final DateTime dateTime;
  final String? siteName;
  final double? maxDepth;
  final Duration? duration;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onDoubleTap;

  // Card coloring
  final double? colorValue;
  final double? minValueInList;
  final double? maxValueInList;
  final Color? gradientStartColor;
  final Color? gradientEndColor;

  // Optional full summary for configurable slot rendering
  final DiveSummary? summary;

  // Configurable slots
  final DiveField titleField;
  final DiveField dateField;
  final DiveField stat1Field;
  final DiveField stat2Field;

  const CompactDiveListTile({
    super.key,
    required this.diveId,
    required this.diveNumber,
    required this.dateTime,
    this.siteName,
    this.maxDepth,
    this.duration,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onDoubleTap,
    this.colorValue,
    this.minValueInList,
    this.maxValueInList,
    this.gradientStartColor,
    this.gradientEndColor,
    this.summary,
    this.titleField = DiveField.siteName,
    this.dateField = DiveField.dateTime,
    this.stat1Field = DiveField.maxDepth,
    this.stat2Field = DiveField.bottomTime,
  });

  Color? _getAttributeBackgroundColor() {
    return normalizeAndLerp(
      value: colorValue,
      min: minValueInList,
      max: maxValueInList,
      startColor: gradientStartColor ?? const Color(0xFF4DD0E1),
      endColor: gradientEndColor ?? const Color(0xFF0D1B2A),
    );
  }

  bool _shouldUseLightText(Color backgroundColor) {
    return backgroundColor.computeLuminance() < 0.5;
  }

  /// Returns the display string for the title slot.
  String _buildTitleText(UnitFormatter units, BuildContext context) {
    if (summary != null && titleField != DiveField.siteName) {
      final value = titleField.extractFromSummary(summary!);
      return titleField.formatValue(value, units);
    }
    return siteName ?? context.l10n.diveLog_listPage_unknownSite;
  }

  /// Returns the display string for the date slot.
  String _buildDateText(UnitFormatter units) {
    if (summary != null && dateField != DiveField.dateTime) {
      final value = dateField.extractFromSummary(summary!);
      return dateField.formatValue(value, units);
    }
    return units.formatDateTime(dateTime, l10n: null);
  }

  /// Returns the display string for a stat slot.
  String _buildStatText(
    DiveField field,
    DiveField defaultField,
    UnitFormatter units,
  ) {
    if (summary != null && field != defaultField) {
      final value = field.extractFromSummary(summary!);
      return field.formatValue(value, units);
    }
    // Use legacy parameters for default fields
    if (field == DiveField.maxDepth) {
      return units.formatDepth(maxDepth);
    }
    if (field == DiveField.bottomTime) {
      return duration != null ? '${duration!.inMinutes} min' : '--';
    }
    // Fallback for any other field value
    final value = summary != null ? field.extractFromSummary(summary!) : null;
    return field.formatValue(value, units);
  }

  /// Builds the icon+value or label:value widget for a stat slot.
  Widget _buildStatSlot(
    DiveField field,
    String formatted,
    TextStyle style,
    Color iconColor,
  ) {
    final icon = field.icon;
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              formatted,
              style: style,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    }
    return Text(
      '${field.shortLabel}: $formatted',
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Card coloring
    final colorAttribute = ref.watch(cardColorAttributeProvider);
    final showCardColors = colorAttribute != CardColorAttribute.none;
    final attributeColor = showCardColors
        ? _getAttributeBackgroundColor()
        : null;
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : isHighlighted
        ? colorScheme.primaryContainer.withValues(alpha: 0.15)
        : attributeColor;

    final effectiveBackground =
        cardColor ?? colorScheme.surfaceContainerHighest;
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    final accentColor = useLightText
        ? Colors.cyan.shade200
        : Colors.teal.shade800;

    // Resolve slot text values
    final titleText = _buildTitleText(units, context);
    final dateText = _buildDateText(units);
    final stat1Text = _buildStatText(stat1Field, DiveField.maxDepth, units);
    final stat2Text = _buildStatText(stat2Field, DiveField.bottomTime, units);

    final statStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: accentColor,
    );
    final statStyleDim = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: secondaryTextColor,
    );

    // Determine if stat values are present (non-null raw values)
    final stat1HasValue = summary != null
        ? stat1Field.extractFromSummary(summary!) != null
        : (stat1Field == DiveField.maxDepth
              ? maxDepth != null
              : duration != null);
    final stat2HasValue = summary != null
        ? stat2Field.extractFromSummary(summary!) != null
        : (stat2Field == DiveField.bottomTime
              ? duration != null
              : maxDepth != null);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: isHighlighted
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 3),
              ),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: cardColor,
        child: Semantics(
          button: true,
          label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
          child: InkWell(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: dive number, title slot, date slot, chevron
                  Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Visibility(
                              visible: isSelectionMode,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) => onTap?.call(),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            if (!isSelectionMode)
                              Text(
                                '#$diveNumber',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: accentColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titleText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.chevron_right,
                          color: secondaryTextColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  // Line 2: stat1 and stat2 slots
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 44),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: _buildStatSlot(
                            stat1Field,
                            stat1Text,
                            stat1HasValue ? statStyle! : statStyleDim!,
                            stat1HasValue ? accentColor : secondaryTextColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        ExcludeSemantics(
                          child: _buildStatSlot(
                            stat2Field,
                            stat2Text,
                            stat2HasValue ? statStyle! : statStyleDim!,
                            stat2HasValue ? accentColor : secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
