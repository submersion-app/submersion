import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/site_wall_clock.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/tide_state_display.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';

/// The tide conditions section for a dive.
///
/// Shows tide data from:
/// 1. Stored TideRecord (if saved when dive was logged)
/// 2. Calculated from tide model (if dive site has coordinates and tide data)
///
/// Collapses to nothing when no tide data is available, so the section takes
/// up zero space; [topGap] is placed above the card only then. Beside Surface
/// GPS the pair owns the spacing and [topGap] is null, which leaves the bare
/// card.
class DiveTideSection extends ConsumerWidget {
  const DiveTideSection({super.key, required this.dive, this.topGap});

  final Dive dive;
  final double? topGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = _tideCard(context, ref);
    if (card == null) return const SizedBox.shrink();
    final gap = topGap;
    if (gap == null) return card;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: gap),
        card,
      ],
    );
  }

  /// The tide card without its leading section gap, or null when the dive has
  /// no tide data to show. [watchHasTide] answers the same question for the
  /// section list, which is what lets a pair form around this card.
  Widget? _tideCard(BuildContext context, WidgetRef ref) {
    final request = diveTideRequest(dive);
    if (request == null) return null;
    final siteLocation = request.location;
    final entryTime = request.entryTime;

    // The stored record, lazily self-healed against a fresh computation.
    final tideRecordAsync = ref.watch(healedTideRecordProvider(request));

    return tideRecordAsync.when<Widget?>(
      data: (tideRecord) {
        if (tideRecord != null) {
          return _buildTideCard(
            context,
            ref,
            tideRecord.toSiteWallClock(siteLocation),
            entryTime: entryTime,
          );
        }

        // Nothing stored: the model's answer, computed off the UI thread.
        final calculated = ref
            .watch(calculatedTideRecordProvider(request))
            .value;
        if (calculated == null) return null;
        return _buildTideCard(
          context,
          ref,
          calculated.toSiteWallClock(siteLocation),
          isCalculated: true,
          entryTime: entryTime,
        );
      },
      loading: () => null,
      error: (_, _) => null,
    );
  }

  /// Build the tide card with data.
  Widget _buildTideCard(
    BuildContext context,
    WidgetRef ref,
    TideRecord record, {
    bool isCalculated = false,
    DateTime? entryTime,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = ref.watch(unitFormatterProvider);

    // Get collapsed state from provider
    final isExpanded = ref.watch(tideSectionExpandedProvider);

    // Get icon and color based on tide state
    IconData stateIcon;
    Color stateColor;
    switch (record.tideState) {
      case TideState.rising:
        stateIcon = Icons.trending_up;
        stateColor = Colors.blue;
        break;
      case TideState.falling:
        stateIcon = Icons.trending_down;
        stateColor = Colors.orange;
        break;
      case TideState.slackHigh:
        stateIcon = Icons.horizontal_rule;
        stateColor = Colors.green;
        break;
      case TideState.slackLow:
        stateIcon = Icons.horizontal_rule;
        stateColor = Colors.amber;
        break;
    }

    // Build collapsed subtitle with tide state and height
    final collapsedSubtitle =
        '${record.tideState.localizedName(context.l10n)} • ${DepthUnit.meters.convert(record.heightMeters, units.settings.depthUnit).toStringAsFixed(1)}${units.settings.depthUnit.symbol}';

    // Compute cycle time range for the header
    final (cycleStart, cycleEnd) = _calculateCycleTimes(
      record.highTideTime,
      record.lowTideTime,
    );
    final dateRef = entryTime ?? record.highTideTime ?? record.lowTideTime;
    final dateStr = dateRef != null
        ? DateFormat(
            UnitFormatter.weekdayMonthDayPattern(units.settings.dateFormat),
          ).format(dateRef)
        : '';
    // The record's times arrive already mapped to the dive site's wall
    // clock (wall-clock-as-UTC), so format them verbatim.
    final timeRangeStr = cycleStart != null && cycleEnd != null
        ? () {
            final timeFmt = DateFormat(units.settings.timeFormat.pattern);
            final startStr = timeFmt.format(cycleStart);
            final endStr = timeFmt.format(cycleEnd);
            final spansNewDay =
                cycleStart.year != cycleEnd.year ||
                cycleStart.month != cycleEnd.month ||
                cycleStart.day != cycleEnd.day;
            if (spansNewDay) {
              final endDateStr = DateFormat(
                UnitFormatter.monthDayPattern(units.settings.dateFormat),
              ).format(cycleEnd);
              return '$startStr - $endStr ($endDateStr)';
            }
            return '$startStr - $endStr';
          }()
        : '';
    final dateTimeLabel = [
      dateStr,
      timeRangeStr,
    ].where((s) => s.isNotEmpty).join(' | ');

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_tide,
      icon: Icons.waves,
      collapsedSubtitle: collapsedSubtitle,
      collapsedTrailing: isCalculated
          ? Tooltip(
              message: context.l10n.diveLog_detail_tideCalculated,
              child: Icon(
                Icons.calculate_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      // The cycle range is secondary to the card itself: in a half-width
      // column it trims rather than wrapping the header onto three lines.
      trailing: isExpanded && dateTimeLabel.isNotEmpty
          ? Text(
              dateTimeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      isExpanded: isExpanded,
      onToggle: (expanded) {
        ref.read(collapsibleSectionProvider.notifier).setTideExpanded(expanded);
      },
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              // Tide cycle visualization
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TideCycleGraph(
                  record: record,
                  referenceTime: entryTime,
                  timeFormat: units.settings.timeFormat,
                  depthUnit: units.settings.depthUnit,
                  height: 80,
                ),
              ),
              // Current state, its icon in the label column so the value
              // lines up with the rows below.
              DetailRow.text(
                icon: stateIcon,
                iconColor: stateColor,
                iconGap: 8,
                label: context.l10n.diveLog_detail_label_state,
                value: record.tideState.localizedName(context.l10n),
                valueStyle: theme.textTheme.bodyMedium,
              ),
              DiveDetailRow(
                label: context.l10n.diveLog_detail_label_height,
                value:
                    '${DepthUnit.meters.convert(record.heightMeters, units.settings.depthUnit).toStringAsFixed(2)}${units.settings.depthUnit.symbol}',
              ),
              if (record.rateOfChange != null)
                DiveDetailRow(
                  label: context.l10n.diveLog_detail_label_rateOfChange,
                  value: units.formatTideRate(record.rateOfChange),
                ),
              if (record.highTideTime != null && record.highTideHeight != null)
                DiveDetailRow(
                  label: context.l10n.diveLog_detail_label_highTide,
                  value:
                      '${DepthUnit.meters.convert(record.highTideHeight!, units.settings.depthUnit).toStringAsFixed(2)}${units.settings.depthUnit.symbol} at ${_formatTime(record.highTideTime!, units.settings.timeFormat)}',
                ),
              if (record.lowTideTime != null && record.lowTideHeight != null)
                DiveDetailRow(
                  label: context.l10n.diveLog_detail_label_lowTide,
                  value:
                      '${DepthUnit.meters.convert(record.lowTideHeight!, units.settings.depthUnit).toStringAsFixed(2)}${units.settings.depthUnit.symbol} at ${_formatTime(record.lowTideTime!, units.settings.timeFormat)}',
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calculate the start and end times for the tide cycle (low -> high -> low).
  (DateTime?, DateTime?) _calculateCycleTimes(
    DateTime? highTideTime,
    DateTime? lowTideTime,
  ) {
    if (highTideTime == null || lowTideTime == null) {
      return (null, null);
    }

    final halfCycle = highTideTime.difference(lowTideTime).abs();

    if (lowTideTime.isBefore(highTideTime)) {
      return (lowTideTime, highTideTime.add(halfCycle));
    } else {
      return (highTideTime.subtract(halfCycle), lowTideTime);
    }
  }

  /// Format a DateTime as a time string using the given time format.
  String _formatTime(DateTime time, TimeFormat timeFormat) {
    return DateFormat(timeFormat.pattern).format(time);
  }
}
