import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_card_stat_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/unfilled_dive_chip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_inset.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/widgets/record_list_chevron.dart';

/// The most of line 1's text room the date slot may take, once the number
/// and the badges have theirs. The title takes the rest, so a short date
/// leaves no gap before the mode badge.
const double _dateMaxWidthFraction = 0.5;

/// Two-line compact card tile for the dive list.
///
/// Line 1: dive number badge | title slot | date slot | mode badge
/// Line 2: (indented) stat1 slot | stat2 slot | type badges
/// A chevron centred on both lines follows them at the card's end.
class CompactDiveListTile extends ConsumerWidget {
  final String diveId;
  final int diveNumber;

  /// The dive is planned and therefore unnumbered (issue #2002). Callers
  /// that pass a [summary] may leave this false: the summary's own flag is
  /// honoured too.
  final bool isPlanned;
  final DateTime dateTime;
  final String? siteName;
  final double? maxDepth;
  final Duration? duration;
  final VoidCallback? onTap;
  final bool isSelectionMode;

  /// In the current bulk selection. Renders as a fill tint plus the leading
  /// checkbox. Independent of [isHighlighted]: a row can be both.
  final bool isChecked;

  /// Currently open in the detail pane. Renders as a leading edge stripe.
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

  /// The full dive, when the list loaded one because a slot names a field
  /// [DiveSummary] does not carry (boat, buddy, visibility and the like).
  /// Slots read it in preference to [summary], as the detailed card does.
  final Dive? fullDive;

  // Configurable slots
  final DiveField titleField;
  final DiveField dateField;
  final DiveField stat1Field;
  final DiveField stat2Field;

  /// Resolves a dive-type slug to its localized label (issue #643).
  ///
  /// Built once per list by [watchDiveTypeLabelResolver] and threaded down, so
  /// the tile neither watches `diveTypesProvider` nor rebuilds a lookup map per
  /// row. When omitted, a Dive Type slot falls back to the English slug
  /// capitalization, matching the locale-independent export path.
  final DiveTypeLabelResolver? diveTypeLabelResolver;

  /// Resolves a dive-type slug to its short-form abbreviation, for the badge
  /// row on the stat line (mirrors the dive detail header's type badges).
  /// When omitted, badges fall back to the slug's capitalization.
  final DiveTypeLabelResolver? diveTypeShortLabelResolver;

  /// Whether a dive-type slug's badge should appear in the badge row
  /// (issue #1269 follow-up). When omitted, every type is shown.
  final DiveTypeListVisibilityPredicate? diveTypeListVisibilityPredicate;

  const CompactDiveListTile({
    super.key,
    required this.diveId,
    required this.diveNumber,
    this.isPlanned = false,
    required this.dateTime,
    this.siteName,
    this.maxDepth,
    this.duration,
    this.onTap,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.isHighlighted = false,
    this.onDoubleTap,
    this.colorValue,
    this.minValueInList,
    this.maxValueInList,
    this.gradientStartColor,
    this.gradientEndColor,
    this.summary,
    this.fullDive,
    this.titleField = DiveField.siteName,
    this.dateField = DiveField.dateTime,
    this.stat1Field = DiveField.maxDepth,
    this.stat2Field = DiveField.runtime,
    this.diveTypeLabelResolver,
    this.diveTypeShortLabelResolver,
    this.diveTypeListVisibilityPredicate,
  });

  /// Whether the configurable slots have a source to read from.
  bool get _hasSlotData => fullDive != null || summary != null;

  /// Whether [field] is a duration field that the [duration] parameter fills
  /// when there is no source to read: the runtime (the default) or bottom
  /// time.
  static bool _isDurationField(DiveField field) =>
      field == DiveField.runtime || field == DiveField.bottomTime;

  /// Whether a stat slot showing [field] has a value. With no source to
  /// read, only the depth and duration parameters can fill a slot.
  bool _statHasValue(DiveField field, UnitFormatter units) {
    if (_hasSlotData) return _extract(field, units) != null;
    if (field == DiveField.maxDepth) return maxDepth != null;
    if (_isDurationField(field)) return duration != null;
    return false;
  }

  /// The raw value of [field] from [fullDive] when there is one, else from
  /// [summary]; null when neither is set. RMV follows the diver's gas model.
  dynamic _extract(DiveField field, UnitFormatter units) {
    if (fullDive case final dive?) {
      return field.extractFromDive(
        dive,
        gasModel: units.settings.gasModel,
        diveTypeLabel: diveTypeLabelResolver,
      );
    }
    return summary == null
        ? null
        : field.extractFromSummary(
            summary!,
            diveTypeLabel: diveTypeLabelResolver,
          );
  }

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
    if (_hasSlotData && titleField != DiveField.siteName) {
      final value = _extract(titleField, units);
      return titleField.formatValue(value, units);
    }
    return siteName ?? context.l10n.diveLog_listPage_unknownSite;
  }

  /// Returns the display string for the date slot.
  String _buildDateText(UnitFormatter units) {
    if (_hasSlotData && dateField != DiveField.dateTime) {
      final value = _extract(dateField, units);
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
    if (_hasSlotData && field != defaultField) {
      final value = _extract(field, units);
      return field.formatValue(value, units);
    }
    // Use legacy parameters for default fields
    if (field == DiveField.maxDepth) {
      return units.formatDepth(maxDepth);
    }
    // [duration] is either of runtime and bottom time, so with a source to
    // read, the slot reads its own field (issue #3304).
    if (_isDurationField(field) && !_hasSlotData) {
      return field.formatValue(duration, units);
    }
    // Fallback for any other field value
    final value = _extract(field, units);
    return field.formatValue(value, units);
  }

  static const double _statIconSize = 13;
  static const double _statIconGap = 4;
  static const double _statGap = 14;
  static const double _badgeGap = 8;

  /// The text a stat slot shows: the value beside its icon, or the field's
  /// short label and the value when the field has no icon.
  String _statSlotText(BuildContext context, DiveField field, String value) =>
      field.icon != null
      ? value
      : '${field.localizedShortLabel(context.l10n)}: $value';

  /// The width a stat slot takes at its natural size.
  double _naturalStatWidth(
    BuildContext context,
    DiveField field,
    String value,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: _statSlotText(context, field, value), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // Rounded up so a slot measured to fit is never ellipsized by a
    // sub-pixel difference from the Text's own layout.
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return field.icon == null ? width : _statIconSize + _statIconGap + width;
  }

  /// Builds the icon+value or label:value widget for a stat slot, [width]
  /// wide. A slot narrower than its icon and gap drops the icon.
  Widget _buildStatSlot(
    BuildContext context,
    DiveField field,
    String formatted,
    TextStyle style,
    Color iconColor,
    double width,
  ) {
    final text = Text(
      _statSlotText(context, field, formatted),
      style: style,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      maxLines: 1,
    );
    final icon = field.icon;
    return SizedBox(
      width: width,
      child: icon == null || width < _statIconSize + _statIconGap
          ? text
          : Row(
              children: [
                Icon(icon, size: _statIconSize, color: iconColor),
                const SizedBox(width: _statIconGap),
                Flexible(child: text),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A dive awaiting its computer data, a plan (issue #2002) or a draft
    // (issue #637), has no number, and the list passes its position as a
    // fallback, so the badge and the screen-reader label leave the number
    // out.
    final unfilledState = unfilledDiveStateOf(
      isPlanned: isPlanned || summary?.isPlanned == true,
      isDraft: summary?.isDraft == true,
      isOpenDraft: summary?.isOpenDraft == true,
    );
    // The chip follows the summary alone, as the planned chip did.
    final chipState = unfilledDiveStateOf(
      isPlanned: summary?.isPlanned == true,
      isDraft: summary?.isDraft == true,
      isOpenDraft: summary?.isOpenDraft == true,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final units = ref.watch(unitFormatterProvider);
    // Read here rather than in line 1's LayoutBuilder, whose builder runs
    // during layout, not this widget's build.
    final showSafetyBadge =
        (summary?.safetyFindingCount ?? 0) > 0 &&
        ref.watch(safetyReviewEnabledProvider);

    // Card coloring
    final colorAttribute = ref.watch(cardColorAttributeProvider);
    final showCardColors = colorAttribute != CardColorAttribute.none;
    final attributeColor = showCardColors
        ? _getAttributeBackgroundColor()
        : null;
    // The active row carries a fill tint: checked in the bulk selection, or --
    // outside selection mode -- open in the detail pane. Inside selection mode
    // the fill belongs to the checked channel alone, so a highlighted but
    // unchecked row stays plain instead of reading as selected.
    final showsSelectionFill = isChecked || (isHighlighted && !isSelectionMode);
    final cardColor = showsSelectionFill
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : attributeColor;

    final effectiveBackground =
        cardColor ?? colorScheme.surfaceContainerHighest;
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    final accentColor = useLightText
        ? Colors.cyan.shade200
        : Colors.teal.shade800;

    // Resolve slot text values. The dive-type resolver arrives as a parameter
    // so a Dive Type slot honors the active locale (issue #643) and keeps a
    // custom type's own name, without this tile subscribing to the type list.
    final titleText = _buildTitleText(units, context);
    final dateText = _buildDateText(units);
    final stat1Text = _buildStatText(stat1Field, DiveField.maxDepth, units);
    final stat2Text = _buildStatText(stat2Field, DiveField.runtime, units);

    final statStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: accentColor,
    );
    final statStyleDim = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: secondaryTextColor,
    );

    // Determine if stat values are present (non-null raw values)
    final stat1HasValue = _statHasValue(stat1Field, units);
    final stat2HasValue = _statHasValue(stat2Field, units);

    final diveTypeLabels = [
      for (final id in summary?.diveTypeIds ?? const <String>[])
        if (diveTypeListVisibilityPredicate?.call(id) ?? true)
          (diveTypeShortLabelResolver ?? Dive.diveTypeDisplayName)(id),
    ];

    // The highlight is the fill above, not an edge stripe; the key only marks
    // the row for tests. It sits below the InkWell, never on the root: a tap
    // highlights the dive in the same frame its ink splash starts, and a
    // changed key rebuilds its whole subtree, splash and all (issue #3474).
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        margin: EdgeInsets.zero,
        color: cardColor,
        child: Semantics(
          button: true,
          label: diveTileSemanticsLabel(
            context,
            unfilledState,
            diveNumber,
            siteName,
          ),
          child: InkWell(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              key: isHighlighted ? const ValueKey('dive_row_highlight') : null,
              padding: const EdgeInsets.all(kRecordCardCompactPadding),
              // The chevron takes a column of its own at the card's end, so
              // the mode badge on line 1 and the type badges on line 2 end at
              // one edge (#4639).
              child: RecordListChevronRow(
                chevronSize: RecordListChevron.compactSize,
                chevronColor: secondaryTextColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: dive number, title slot, date slot, mode badge
                    Row(
                      children: [
                        SelectionLeading(
                          isSelectionMode: isSelectionMode,
                          isChecked: isChecked,
                          onChanged: (_) => onTap?.call(),
                          child: SizedBox(
                            width: 36,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: unfilledState != null
                                    ? Icon(
                                        unfilledDiveIcon(unfilledState),
                                        size: 14,
                                        color: accentColor,
                                      )
                                    : Text(
                                        '#$diveNumber',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: accentColor,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // The title and the date share what the badges
                        // leave. The date is capped at a share of that room
                        // rather than Flexible: a loose Flexible beside the
                        // Expanded title was allotted half the free width
                        // whatever the date needed, and the unused part sat
                        // after the mode badge on a wide pane (#4639).
                        // Measuring the room left, not the whole line, keeps
                        // a crowded line from overflowing.
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, room) => Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    titleText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (showSafetyBadge) ...[
                                  const SizedBox(width: 6),
                                  SafetyFindingBadge(
                                    count: summary!.safetyFindingCount,
                                    color: secondaryTextColor,
                                  ),
                                ],
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    // Less the gap before it, so the date
                                    // and its gap never take more than the
                                    // share together.
                                    maxWidth:
                                        math.max(0.0, room.maxWidth - 8) *
                                        _dateMaxWidthFraction,
                                  ),
                                  child: Text(
                                    dateText,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: secondaryTextColor),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (chipState != null) ...[
                          const SizedBox(width: 6),
                          UnfilledDiveChip(state: chipState),
                        ],
                        const SizedBox(width: 6),
                        DiveModeBadge(
                          mode: summary?.diveMode ?? DiveMode.oc,
                          dense: true,
                        ),
                      ],
                    ),
                    // Line 2: stat1 and stat2 slots, then the type badges.
                    // The badges' "+N" width is reserved first and the stats
                    // ellipsize only when what is left cannot hold them, as
                    // on the detailed card, so a narrow card (the chevron
                    // has its own column since #4639) never overflows.
                    SelectionInset(
                      isSelectionMode: isSelectionMode,
                      start: 44,
                      child: LayoutBuilder(
                        builder: (context, line2) {
                          final style1 = stat1HasValue
                              ? statStyle!
                              : statStyleDim!;
                          final style2 = stat2HasValue
                              ? statStyle!
                              : statStyleDim!;
                          final naturals = [
                            _naturalStatWidth(
                              context,
                              stat1Field,
                              stat1Text,
                              style1,
                            ),
                            _naturalStatWidth(
                              context,
                              stat2Field,
                              stat2Text,
                              style2,
                            ),
                          ];
                          final badgeReserve = diveTypeLabels.isEmpty
                              ? 0.0
                              : _badgeGap +
                                    DiveTypeBadgeRow.minWidthOf(
                                      context,
                                      diveTypeLabels,
                                      dense: true,
                                    );
                          final widths = line2.maxWidth.isFinite
                              ? DiveCardStatRow.fairShareWidths(
                                  naturals,
                                  line2.maxWidth - _statGap - badgeReserve,
                                )
                              : naturals;
                          return Row(
                            children: [
                              ExcludeSemantics(
                                child: _buildStatSlot(
                                  context,
                                  stat1Field,
                                  stat1Text,
                                  style1,
                                  stat1HasValue
                                      ? accentColor
                                      : secondaryTextColor,
                                  widths[0],
                                ),
                              ),
                              const SizedBox(width: _statGap),
                              ExcludeSemantics(
                                child: _buildStatSlot(
                                  context,
                                  stat2Field,
                                  stat2Text,
                                  style2,
                                  stat2HasValue
                                      ? accentColor
                                      : secondaryTextColor,
                                  widths[1],
                                ),
                              ),
                              if (diveTypeLabels.isNotEmpty) ...[
                                const SizedBox(width: _badgeGap),
                                Expanded(
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: DiveTypeBadgeRow(
                                      labels: diveTypeLabels,
                                      dense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
