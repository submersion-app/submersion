import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/core/theme/foreground_on.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/calendar_day_matrix.dart';
import 'package:submersion/features/insights/presentation/formatters/distribution_labels.dart';
import 'package:submersion/features/insights/presentation/insights_place_dives.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fill of a calendar cell holding [count] dives when the busiest date holds
/// [maxCount]. Zero is a neutral surface, never the primary hue, so a date
/// with no dives reads apart from a date with one; counts deepen from a
/// light primary tint to [ColorScheme.primary] at the busiest date. Opaque,
/// so it reads the same on any card surface.
Color calendarCellFill(ColorScheme scheme, int count, int maxCount) {
  if (count <= 0 || maxCount <= 0) {
    // A whisper of the text colour on the surface: empty dates recede, so
    // even a one-dive tint reads as covered.
    return Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      scheme.surface,
    );
  }
  if (count >= maxCount) return scheme.primary;
  return Color.lerp(scheme.surface, scheme.primary, _share(count, maxCount))!;
}

/// Text colour for a cell filled by [calendarCellFill], chosen by measured
/// contrast so the 11 px count reads at 4.5:1 or better on every theme: a
/// mid-range tint sits too near the middle for a fixed onPrimary switch.
/// Empty dates keep the muted variant colour while it still reads.
Color calendarCellText(ColorScheme scheme, int count, int maxCount) =>
    _textOn(scheme, count, maxCount, calendarCellFill(scheme, count, maxCount));

/// [calendarCellText] for a [fill] already worked out, so a cell computes
/// its fill once.
Color _textOn(ColorScheme scheme, int count, int maxCount, Color fill) {
  if (count <= 0 || maxCount <= 0) {
    return contrastRatio(scheme.onSurfaceVariant, fill) >= 4.5
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
  }
  return blackOrWhiteOn(fill);
}

double _share(int count, int maxCount) => 0.3 + 0.7 * (count / maxCount);

/// Dives on each calendar date across all years, as a 12 x 31 grid with
/// month and day-of-month totals (issue #3127). A cell opens the dives
/// logged on that date under the Insights filter.
class CalendarDayMatrixCard extends ConsumerWidget {
  const CalendarDayMatrixCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final matrixAsync = ref.watch(divesByCalendarDayProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    return StatSectionCard(
      title: l10n.insights_timePatterns_calendarDays_title,
      subtitle: l10n.insights_timePatterns_calendarDays_subtitle,
      child: matrixAsync.when(
        data: (matrix) => matrix.isEmpty
            ? StatEmptyState(
                icon: Icons.calendar_month,
                message: l10n.insights_timePatterns_calendarDays_empty,
              )
            : _CalendarDayMatrixBody(
                matrix: matrix,
                formatDate: units.formatMonthDay,
                onOpen: (month, day) => openInsightsDives(
                  context,
                  ref,
                  calendarDayDivesFilter(
                    ref.read(insightsFilterProvider),
                    month: month,
                    day: day,
                  ),
                ),
              ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.insights_timePatterns_calendarDays_error,
        ),
      ),
    );
  }
}

class _CalendarDayMatrixBody extends StatefulWidget {
  const _CalendarDayMatrixBody({
    required this.matrix,
    required this.formatDate,
    required this.onOpen,
  });

  final CalendarDayMatrix matrix;

  /// A cell's date in the diver's month-and-day order.
  final String Function(DateTime date) formatDate;
  final void Function(int month, int day) onOpen;

  @override
  State<_CalendarDayMatrixBody> createState() => _CalendarDayMatrixBodyState();
}

class _CalendarDayMatrixBodyState extends State<_CalendarDayMatrixBody> {
  static const double _monthColumnWidth = 44;

  /// Shared by the scrollbar and the grid, so the thumb tracks the days.
  final _days = ScrollController();

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matrix = widget.matrix;
    final l10n = context.l10n;
    final separator = l10n.insights_timePatterns_calendarDays_listSeparator;
    final months = insightsMonthLabels(l10n);
    final percent = NumberFormat.decimalPercentPattern(
      locale: l10n.localeName,
      decimalDigits: 1,
    );
    final secondary = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.insights_timePatterns_calendarDays_coverage(
                matrix.coveredDays,
                CalendarDayMatrix.calendarDays,
                percent.format(matrix.coverage),
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              l10n.insights_timePatterns_calendarDays_busiestMonth(
                matrix.busiestMonths.map((m) => months[m - 1]).join(separator),
              ),
              style: secondary,
            ),
            Text(
              l10n.insights_timePatterns_calendarDays_busiestDay(
                matrix.busiestDays.join(separator),
              ),
              style: secondary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // 31 day columns plus a total column 1.5 cells wide: the whole
            // year fits a wide card, and a phone scrolls the days sideways
            // under the pinned month names.
            final cell = ((constraints.maxWidth - _monthColumnWidth) / 32.5)
                .clamp(28.0, 40.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthColumn(
                  months: months,
                  width: _monthColumnWidth,
                  cell: cell,
                ),
                Expanded(
                  // A visible thumb, and drag by mouse as well as touch: on
                  // desktop the master pane is narrower than the year, and
                  // Material draws no horizontal scrollbar by default.
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                    child: Scrollbar(
                      controller: _days,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _days,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _Grid(
                          matrix: matrix,
                          months: months,
                          cell: cell,
                          formatDate: widget.formatDate,
                          onOpen: widget.onOpen,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The pinned row labels: a blank over the day header, the month names,
/// and the totals row's sigma.
class _MonthColumn extends StatelessWidget {
  const _MonthColumn({
    required this.months,
    required this.width,
    required this.cell,
  });

  final List<String> months;
  final double width;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    Widget label(String text) => SizedBox(
      width: width,
      height: cell,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: style),
          ),
        ),
      ),
    );

    return ExcludeSemantics(
      child: Column(
        children: [
          SizedBox(height: cell),
          for (final m in months) label(m),
          label('Σ'),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.matrix,
    required this.months,
    required this.cell,
    required this.formatDate,
    required this.onOpen,
  });

  final CalendarDayMatrix matrix;
  final List<String> months;
  final double cell;
  final String Function(DateTime date) formatDate;
  final void Function(int month, int day) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalWidth = cell * 1.5;
    final busiestMonths = matrix.busiestMonths.toSet();
    final busiestDays = matrix.busiestDays.toSet();

    Widget header(String text, double width) => SizedBox(
      width: width,
      height: cell,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );

    Widget total(
      int value,
      String label, {
      required double width,
      bool busiest = false,
    }) => _TotalCell(
      value: value,
      width: width,
      height: cell,
      busiest: busiest,
      semanticsLabel: l10n.insights_timePatterns_calendarDays_totalSemantics(
        label,
        value,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (var d = 1; d <= 31; d++) header('$d', cell),
              header('Σ', totalWidth),
            ],
          ),
        ),
        for (var m = 1; m <= 12; m++)
          Row(
            children: [
              for (var d = 1; d <= 31; d++)
                _DayCell(
                  count: matrix.count(m, d),
                  maxCount: matrix.maxCount,
                  size: cell,
                  semanticsLabel: CalendarDayMatrix.isValidDate(m, d)
                      ? l10n.insights_timePatterns_calendarDays_cellSemantics(
                          formatDate(DateTime(2024, m, d)),
                          matrix.count(m, d)!,
                        )
                      : null,
                  onTap: () => onOpen(m, d),
                ),
              total(
                matrix.monthTotals[m - 1],
                months[m - 1],
                width: totalWidth,
                busiest: busiestMonths.contains(m),
              ),
            ],
          ),
        Row(
          children: [
            for (var d = 1; d <= 31; d++)
              total(
                matrix.dayTotals[d - 1],
                l10n.insights_timePatterns_calendarDays_dayLabel(d),
                width: cell,
                busiest: busiestDays.contains(d),
              ),
            total(
              matrix.total,
              l10n.insights_timePatterns_calendarDays_total,
              width: totalWidth,
            ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.count,
    required this.maxCount,
    required this.size,
    required this.semanticsLabel,
    required this.onTap,
  });

  /// Null for a date that does not exist (30 February).
  final int? count;
  final int maxCount;
  final double size;
  final String? semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    final count = this.count;

    if (count == null) {
      return ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text('×', style: style?.copyWith(color: scheme.outline)),
          ),
        ),
      );
    }

    final fill = calendarCellFill(scheme, count, maxCount);
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Semantics(
          label: semanticsLabel,
          button: true,
          excludeSemantics: true,
          // Excluding the children drops the InkWell's own tap action, so
          // the node carries it for screen readers.
          onTap: onTap,
          child: Material(
            color: fill,
            borderRadius: BorderRadius.circular(3),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(3),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$count',
                      style: style?.copyWith(
                        color: _textOn(scheme, count, maxCount, fill),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({
    required this.value,
    required this.width,
    required this.height,
    required this.busiest,
    required this.semanticsLabel,
  });

  final int value;
  final double width;
  final double height;
  final bool busiest;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      // The margin sits inside the box, so totals line up with the cells.
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: DecoratedBox(
            decoration: busiest
                ? BoxDecoration(
                    border: Border.all(color: scheme.tertiary, width: 2),
                    borderRadius: BorderRadius.circular(3),
                  )
                : const BoxDecoration(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$value',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
