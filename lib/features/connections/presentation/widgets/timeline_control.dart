import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_timeline_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Play or pause the sweep of the range's end to the last dive day.
class TimelinePlayButton extends ConsumerWidget {
  const TimelinePlayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playing = ref.watch(
      connectionsTimelineProvider.select((s) => s.playing),
    );
    final span = ref.watch(connectionsDateSpanProvider).value;
    // With both thumbs on the last day there is nothing left to sweep.
    final canPlay = ref.watch(
      connectionsTimelineRangeProvider.select(
        (r) => r != null && span != null && r.start.isBefore(span.end),
      ),
    );
    final notifier = ref.read(connectionsTimelineProvider.notifier);
    return IconButton(
      key: const ValueKey('timeline-play-button'),
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      tooltip: playing
          ? l10n.connections_yearPlay_pause
          : l10n.connections_timeline_play,
      onPressed: playing
          ? notifier.pause
          : canPlay
          ? notifier.play
          : null,
    );
  }
}

/// Both ends of the date range, by whole day from the log's first dive day
/// to its last. No divisions: thousands of tick marks would smear into a
/// bar, so values are rounded to days here instead.
class TimelineRangeSlider extends ConsumerWidget {
  const TimelineRangeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final span = ref.watch(connectionsDateSpanProvider).value;
    final range = ref.watch(connectionsTimelineRangeProvider);
    if (span == null || range == null) return const SizedBox.shrink();
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notifier = ref.read(connectionsTimelineProvider.notifier);
    DayRange days(RangeValues v) => (
      start: dayAt(span.start, v.start.round()),
      end: dayAt(span.start, v.end.round()),
    );
    return RangeSlider(
      key: const ValueKey('timeline-slider'),
      min: 0,
      max: dayIndex(span.start, span.end).toDouble(),
      values: RangeValues(
        dayIndex(span.start, range.start).toDouble(),
        dayIndex(span.start, range.end).toDouble(),
      ),
      semanticFormatterCallback: (v) =>
          units.formatDate(dayAt(span.start, v.round())),
      onChangeStart: (_) => notifier.dragStart(),
      onChanged: (v) => notifier.dragTo(days(v)),
      onChangeEnd: (v) => notifier.dragEnd(days(v)),
    );
  }
}

/// The range in the diver's date format above Play and the slider. Shared
/// by the bar over the canvas and the panel's Filter tab, so the two always
/// show the same thumbs. Hidden when the log spans fewer than two days.
class TimelineControl extends ConsumerWidget {
  const TimelineControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(connectionsTimelineRangeProvider);
    if (range == null) return const SizedBox.shrink();
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 12, top: 8),
          child: Text(
            context.l10n.connections_timeline_range(
              units.formatDate(range.start),
              units.formatDate(range.end),
            ),
            key: const ValueKey('timeline-label'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const Row(
          children: [
            TimelinePlayButton(),
            Expanded(child: TimelineRangeSlider()),
          ],
        ),
      ],
    );
  }
}

/// [TimelineControl] in a card over the canvas: as wide as the canvas on a
/// phone, at most [maxWidth] and at the start edge on a wide screen. Place
/// it with a Positioned spanning the canvas width; the space beside a capped
/// card lets taps through to the canvas.
class ConnectionsTimelineBar extends ConsumerWidget {
  const ConnectionsTimelineBar({super.key});

  static const double maxWidth = 560;

  /// Room the canvas keeps clear at its bottom edge for the bar: the gap,
  /// the label line at the reader's text size, and the slider row.
  static double reserveOf(BuildContext context) =>
      84 + MediaQuery.textScalerOf(context).scale(20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(connectionsTimelineRangeProvider) == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: const Card(
          key: ValueKey('connections-timeline-bar'),
          margin: EdgeInsets.zero,
          child: TimelineControl(),
        ),
      ),
    );
  }
}
