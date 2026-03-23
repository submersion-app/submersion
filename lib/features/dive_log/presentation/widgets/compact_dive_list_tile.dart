import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Two-line compact card tile for the dive list.
///
/// Line 1: dive number | site name | date/time | chevron
/// Line 2: (indented) depth icon + value | duration icon + value
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

  // Card coloring
  final double? colorValue;
  final double? minValueInList;
  final double? maxValueInList;
  final Color? gradientStartColor;
  final Color? gradientEndColor;

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
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : attributeColor;

    final effectiveBackground =
        cardColor ?? colorScheme.surfaceContainerHighest;
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    final accentColor = useLightText
        ? Colors.cyan.shade200
        : Colors.teal.shade800;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: cardColor,
      child: Semantics(
        button: true,
        label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: dive number, site name, date, chevron
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
                        siteName ?? context.l10n.diveLog_listPage_unknownSite,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      units.formatDateTime(dateTime, l10n: context.l10n),
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
                // Line 2: depth and duration
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 44),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.arrow_downward,
                          size: 13,
                          color: maxDepth != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        units.formatDepth(maxDepth),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: maxDepth != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: duration != null
                              ? accentColor
                              : secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        duration != null ? '${duration!.inMinutes} min' : '--',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: duration != null
                              ? accentColor
                              : secondaryTextColor,
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
    );
  }
}
