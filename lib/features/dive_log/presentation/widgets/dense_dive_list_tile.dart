import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Single-row flat tile for the dive list (maximum density).
///
/// Row: dive number | slot1 | slot2 | slot3 | slot4 | chevron
class DenseDiveListTile extends ConsumerWidget {
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
  final DiveField slot1Field;
  final DiveField slot2Field;
  final DiveField slot3Field;
  final DiveField slot4Field;

  const DenseDiveListTile({
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
    this.slot1Field = DiveField.siteName,
    this.slot2Field = DiveField.dateTime,
    this.slot3Field = DiveField.maxDepth,
    this.slot4Field = DiveField.bottomTime,
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

  /// Abbreviated date: "Mar 15" for current year, "Mar 15 '24" for other years.
  String _formatShortDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year) {
      return DateFormat('MMM d').format(dt);
    }
    return DateFormat("MMM d ''yy").format(dt);
  }

  /// Returns the display string for an expanded text slot (slot1 / slot2).
  String _buildTextSlotValue(
    DiveField field,
    DiveField defaultField,
    UnitFormatter units,
    BuildContext context,
  ) {
    if (summary != null && field != defaultField) {
      final value = field.extractFromSummary(summary!);
      return field.formatValue(value, units);
    }
    if (field == DiveField.siteName) {
      return siteName ?? context.l10n.diveLog_listPage_unknownSite;
    }
    if (field == DiveField.dateTime) {
      return _formatShortDate(dateTime);
    }
    final value = summary != null ? field.extractFromSummary(summary!) : null;
    return field.formatValue(value, units);
  }

  /// Returns the display string for a numeric stat slot (slot3 / slot4).
  String _buildStatSlotValue(
    DiveField field,
    DiveField defaultField,
    UnitFormatter units,
  ) {
    if (summary != null && field != defaultField) {
      final value = field.extractFromSummary(summary!);
      return field.formatValue(value, units);
    }
    if (field == DiveField.maxDepth) {
      return units.formatDepth(maxDepth);
    }
    if (field == DiveField.bottomTime) {
      return duration != null ? '${duration!.inMinutes} min' : '--';
    }
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

    // Row coloring
    final colorAttribute = ref.watch(cardColorAttributeProvider);
    final showCardColors = colorAttribute != CardColorAttribute.none;
    final attributeColor = showCardColors
        ? _getAttributeBackgroundColor()
        : null;
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : isHighlighted
        ? colorScheme.primaryContainer.withValues(alpha: 0.15)
        : attributeColor;

    final effectiveBackground = rowColor ?? colorScheme.surface;
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    final accentColor = useLightText
        ? Colors.cyan.shade200
        : Colors.teal.shade800;

    // Resolve slot text values
    final slot1Text = _buildTextSlotValue(
      slot1Field,
      DiveField.siteName,
      units,
      context,
    );
    final slot2Text = _buildTextSlotValue(
      slot2Field,
      DiveField.dateTime,
      units,
      context,
    );
    final slot3Text = _buildStatSlotValue(
      slot3Field,
      DiveField.maxDepth,
      units,
    );
    final slot4Text = _buildStatSlotValue(
      slot4Field,
      DiveField.bottomTime,
      units,
    );

    // Determine if stat values are present
    final slot3HasValue = summary != null
        ? slot3Field.extractFromSummary(summary!) != null
        : (slot3Field == DiveField.maxDepth
              ? maxDepth != null
              : duration != null);
    final slot4HasValue = summary != null
        ? slot4Field.extractFromSummary(summary!) != null
        : (slot4Field == DiveField.bottomTime
              ? duration != null
              : maxDepth != null);

    final statStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: accentColor,
    );
    final statStyleDim = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: secondaryTextColor,
    );

    return Semantics(
      button: true,
      label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            left: isHighlighted
                ? BorderSide(color: colorScheme.primary, width: 3)
                : BorderSide.none,
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
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
                // Slot 1 (expanded)
                Expanded(
                  child: Text(
                    slot1Text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Slot 2 (abbreviated date or configured field)
                Text(
                  slot2Text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                ),
                const SizedBox(width: 12),
                // Slot 3 (fixed width, stat with icon fallback)
                SizedBox(
                  width: 56,
                  child: _buildStatSlot(
                    slot3Field,
                    slot3Text,
                    slot3HasValue ? statStyle! : statStyleDim!,
                    slot3HasValue ? accentColor : secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 8),
                // Slot 4 (fixed width, stat with icon fallback)
                SizedBox(
                  width: 50,
                  child: _buildStatSlot(
                    slot4Field,
                    slot4Text,
                    slot4HasValue ? statStyle! : statStyleDim!,
                    slot4HasValue ? accentColor : secondaryTextColor,
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: secondaryTextColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
