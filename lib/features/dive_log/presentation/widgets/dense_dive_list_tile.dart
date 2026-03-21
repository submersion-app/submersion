import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Single-row flat tile for the dive list (maximum density).
///
/// Row: dive number | site name | abbreviated date | depth | duration | chevron
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

  // Card coloring
  final double? colorValue;
  final double? minValueInList;
  final double? maxValueInList;
  final Color? gradientStartColor;
  final Color? gradientEndColor;

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
    this.colorValue,
    this.minValueInList,
    this.maxValueInList,
    this.gradientStartColor,
    this.gradientEndColor,
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
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : attributeColor;

    final effectiveBackground = rowColor ?? colorScheme.surface;
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    final accentColor = useLightText
        ? Colors.cyan.shade200
        : Colors.teal.shade800;

    return Semantics(
      button: true,
      label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  SizedBox(
                    width: 36,
                    child: Text(
                      '#$diveNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: accentColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Site name (expanded)
                Expanded(
                  child: Text(
                    siteName ?? context.l10n.diveLog_listPage_unknownSite,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Abbreviated date
                Text(
                  _formatShortDate(dateTime),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                ),
                const SizedBox(width: 12),
                // Depth (fixed width for column alignment)
                SizedBox(
                  width: 56,
                  child: Text(
                    units.formatDepth(maxDepth),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: maxDepth != null
                          ? accentColor
                          : secondaryTextColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                // Duration (fixed width for column alignment)
                SizedBox(
                  width: 50,
                  child: Text(
                    duration != null ? '${duration!.inMinutes} min' : '--',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: duration != null
                          ? accentColor
                          : secondaryTextColor,
                    ),
                    textAlign: TextAlign.right,
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
