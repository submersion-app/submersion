import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_gates.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/dive_tide_window.dart';
import 'package:submersion/features/tides/domain/services/site_wall_clock.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/tide_state_display.dart';
import 'package:submersion/features/tides/presentation/widgets/dive_tide_chart.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_extremes_list.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_stat_tiles.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';

/// The tide conditions section for a dive.
///
/// Shows tide data from:
/// 1. Stored TideRecord (if saved when dive was logged)
/// 2. Calculated from tide model (if dive site has coordinates and tide data)
///
/// The card charts the predicted tide across the day around the dive (12
/// hours either side of the entry), then gives the tide at the entry as
/// three readings and lists every high and low in that day (issue #4567).
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
    final tide = _tideCard(context, ref);
    if (tide == null) return const SizedBox.shrink();
    // Faded while the dive is unlocked: it is worked out, not logged.
    final card = RecordCardFade<Dive>(
      reason: RecordCardFadeReason.calculated,
      child: tide,
    );
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
    // The site's zone is resolved once (a polygon lookup) and every time
    // on the card goes through this converter.
    final toSite = siteClockConverter(request.location);

    // The stored record, lazily self-healed against a fresh computation.
    final tideRecordAsync = ref.watch(healedTideRecordProvider(request));

    return tideRecordAsync.when<Widget?>(
      data: (tideRecord) {
        if (tideRecord != null) {
          return _buildTideCard(
            context,
            ref,
            tideRecord.atWallClock(toSite),
            request: request,
            toSite: toSite,
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
          calculated.atWallClock(toSite),
          request: request,
          toSite: toSite,
          isCalculated: true,
        );
      },
      loading: () => null,
      error: (_, _) => null,
    );
  }

  /// Build the tide card with data. [record] carries times already mapped
  /// to the dive site's wall clock.
  Widget _buildTideCard(
    BuildContext context,
    WidgetRef ref,
    TideRecord record, {
    required ({String diveId, GeoPoint location, DateTime entryTime}) request,
    required DateTime Function(DateTime instant) toSite,
    bool isCalculated = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = ref.watch(unitFormatterProvider);
    final entryTime = request.entryTime;

    // Get collapsed state from provider
    final isExpanded = ref.watch(tideSectionExpandedProvider);

    // The day of tide around the dive. Watched only while the card is open:
    // a collapsed card shows none of it.
    final windowAsync = isExpanded
        ? ref.watch(diveTideWindowProvider(request))
        : const AsyncValue<DiveTideWindow?>.loading();
    final window = windowAsync.value;
    final hasWindow = window != null && window.predictions.length >= 2;

    // Build collapsed subtitle with tide state and height
    final collapsedSubtitle =
        '${record.tideState.localizedName(context.l10n)} • ${units.formatDepth(record.heightMeters)}';

    // The header names the dive's date; the chart's own axis carries the
    // times, and names the neighbouring day where the window crosses into
    // it. The entry time is site wall clock, so it is formatted verbatim.
    final dateLabel = DateFormat(
      UnitFormatter.weekdayMonthDayPattern(units.settings.dateFormat),
    ).format(entryTime);

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
      // The date is secondary to the card itself: in a half-width column it
      // trims rather than wrapping the header.
      trailing: isExpanded
          ? Text(
              dateLabel,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            const SizedBox(height: 4),
            if (hasWindow)
              DiveTideChart(
                window: window,
                units: units,
                displayTime: toSite,
                diveDuration: dive.effectiveRuntime,
              )
            else if (windowAsync.isLoading)
              // Hold the chart's place while the day is computed.
              SizedBox(height: DiveTideChart.heightOf(context))
            else
              // No day of predictions to plot: the single cycle the record
              // itself describes.
              TideCycleGraph(
                record: record,
                referenceTime: entryTime,
                timeFormat: units.settings.timeFormat,
                depthUnit: units.settings.depthUnit,
              ),
            const SizedBox(height: 12),
            TideStatTiles(record: record, units: units),
            const SizedBox(height: 8),
            TideExtremesList(
              extremes: hasWindow
                  ? extremesAtWallClock(window.extremes, toSite)
                  : _recordExtremes(record),
              units: units,
              day: entryTime,
            ),
          ],
        ),
      ),
    );
  }

  /// The one high and one low a record names, in time order: what the list
  /// shows until, or instead of, the day of predictions.
  List<TideExtreme> _recordExtremes(TideRecord record) {
    final highTime = record.highTideTime;
    final highHeight = record.highTideHeight;
    final lowTime = record.lowTideTime;
    final lowHeight = record.lowTideHeight;
    return [
      if (highTime != null && highHeight != null)
        TideExtreme(
          type: TideExtremeType.high,
          time: highTime,
          heightMeters: highHeight,
        ),
      if (lowTime != null && lowHeight != null)
        TideExtreme(
          type: TideExtremeType.low,
          time: lowTime,
          heightMeters: lowHeight,
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }
}
