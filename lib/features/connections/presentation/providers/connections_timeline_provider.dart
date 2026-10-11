import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// What the timeline shows ahead of the map.
@immutable
class TimelineState {
  const TimelineState({this.pending, this.playing = false});

  static const idle = TimelineState();

  /// The days on screen while a drag or the sweep is ahead of the filter.
  /// Null when idle: the slider then shows the filter's own range.
  final DayRange? pending;

  /// Whether the play sweep is running.
  final bool playing;

  @override
  bool operator ==(Object other) =>
      other is TimelineState &&
      other.pending == pending &&
      other.playing == playing;

  @override
  int get hashCode => Object.hash(pending, playing);
}

/// Drives the connections date range from the timeline slider and its play
/// sweep.
///
/// The range on screen ([TimelineState.pending]) runs ahead of the filter:
/// a drag or the sweep moves it every frame, and it is written into the
/// filter only once the page has reported the previous write's graph
/// loaded, latest value wins. A drag across hundreds of days on a large log
/// therefore causes a few reloads, never a queue of them. Any filter change
/// it did not make itself stops it, so it never overwrites what the diver
/// just chose; so does any view change other than the highlight mode.
class ConnectionsTimelineNotifier extends Notifier<TimelineState> {
  /// How long the sweep takes to cross the whole span.
  static const Duration sweep = Duration(seconds: 20);
  static const Duration tick = Duration(milliseconds: 16);

  Timer? _ticker;
  bool _dragging = false;

  /// True from a write until the graph load it caused has settled.
  bool _inFlight = false;

  /// True once a graph load has started since the last write; a load that
  /// settles before then was for the old filter.
  bool _started = false;

  /// Whether the graph is loading, as the page last reported it.
  bool _loading = false;

  /// The last filter written here, to tell its own writes from the diver's.
  DiveFilterState? _written;

  DateTime _spanStart = DateTime(0);
  DateTime _sweepStart = DateTime(0);
  int _from = 0;
  int _total = 0;

  /// The day the sweep last put on screen, so a tick within it does nothing.
  int _day = 0;

  @override
  TimelineState build() {
    ref.onDispose(_cancel);
    ref.listen<DiveFilterState>(connectionsFilterProvider, (_, next) {
      if (next != _written && (state.playing || state.pending != null)) {
        _reset();
      }
    });
    // The sweep runs over the span it started with, and a drag over a slider
    // that may have gone: a new span (a synced dive, another diver) ends both.
    // While the span reloads the old one is still its value, so the sweep
    // stops as soon as a reload starts rather than sweep stale dates.
    ref.listen<AsyncValue<DayRange?>>(connectionsDateSpanProvider, (
      prev,
      next,
    ) {
      if (next.isLoading) {
        if (state.playing) pause();
        return;
      }
      if (prev?.value == next.value) return;
      if (_span() == null) {
        if (state != TimelineState.idle || _inFlight) _reset();
      } else if (state.playing) {
        pause();
      }
    });
    // Colouring the map is not a change of what it shows: play carries on.
    ref.listen<ConnectionsViewState>(connectionsViewProvider, (prev, next) {
      if (state.playing &&
          prev != null &&
          prev.copyWith(highlight: next.highlight) != next) {
        pause();
      }
    });
    return TimelineState.idle;
  }

  /// Sweeps the end of the range to the log's last day. From the last day
  /// already, the end first jumps back to the start; the start never moves.
  void play() {
    final span = _span();
    if (span == null) return;
    final shown = _shown(span);
    final total = dayIndex(span.start, span.end);
    var from = dayIndex(span.start, shown.end);
    if (from >= total) from = dayIndex(span.start, shown.start);
    if (from >= total) return;
    _cancel();
    _dragging = false;
    _spanStart = span.start;
    _sweepStart = shown.start;
    _from = from;
    _total = total;
    _day = from;
    state = TimelineState(
      pending: (start: shown.start, end: dayAt(span.start, from)),
      playing: true,
    );
    _ticker = Timer.periodic(tick, _onTick);
    _commit();
  }

  /// Stops the sweep where it is; the range on screen still reaches the map.
  void pause() {
    _cancel();
    if (state.playing) state = TimelineState(pending: state.pending);
    _commit();
  }

  /// A thumb was grabbed: the sweep stops and the drag owns the range.
  void dragStart() {
    final span = _span();
    if (span == null) return;
    _cancel();
    _dragging = true;
    state = TimelineState(pending: _shown(span));
  }

  /// Any move of a thumb, including a screen reader's adjustment, which
  /// arrives with no [dragStart], stops the sweep.
  void dragTo(DayRange range) {
    final span = _span();
    if (span == null) return;
    _cancel();
    state = TimelineState(pending: clampDays(range, span));
    _commit();
  }

  /// The thumb was let go at [range], which always reaches the map.
  void dragEnd(DayRange range) {
    _dragging = false;
    dragTo(range);
  }

  /// The page reports, from each build, whether the graph is loading. Its
  /// listener never hears about an initial load (the first one, or a new
  /// node budget), and a write during one restarts it without a word.
  void syncLoading(bool loading) {
    _loading = loading;
    if (loading && _inFlight) _started = true;
  }

  /// The page reports each load of the graph that starts.
  void loadStarted() {
    _loading = true;
    if (_inFlight) _started = true;
  }

  /// The page reports each settled load of the graph. A failed load stops
  /// everything; the page shows the reload error.
  void loadSettled({required bool failed}) {
    _loading = false;
    if (failed) {
      if (state.playing || state.pending != null || _inFlight) _reset();
      return;
    }
    if (!_inFlight || !_started) return;
    _inFlight = false;
    _commit();
  }

  /// The log's span, or null when there is nothing to move through.
  DayRange? _span() {
    final span = ref.read(connectionsDateSpanProvider).value;
    return span == null || !span.start.isBefore(span.end) ? null : span;
  }

  DayRange _shown(DayRange span) {
    final pending = state.pending;
    return pending == null
        ? filteredDays(ref.read(connectionsFilterProvider), span)
        : clampDays(pending, span);
  }

  /// Writes the range on screen into the filter, unless a write is still
  /// loading. Once the map shows it and nothing is moving, goes idle.
  void _commit() {
    final pending = state.pending;
    if (pending == null || _inFlight) return;
    final span = _span();
    if (span == null) {
      _reset();
      return;
    }
    final filter = ref.read(connectionsFilterProvider);
    final next = filterWithDays(filter, pending, span);
    if (next == filter) {
      if (!state.playing && !_dragging) state = TimelineState.idle;
      return;
    }
    // Set before the write: a graph that reloads synchronously reports its
    // load during it, and that report must find the write in flight.
    _written = next;
    _inFlight = true;
    // A load already running restarts with the new filter, and only its
    // settle will be reported.
    _started = _loading;
    ref.read(connectionsFilterProvider.notifier).state = next;
  }

  void _onTick(Timer timer) {
    // timer.tick counts every period passed, so a late frame catches up
    // rather than slowing the sweep.
    final elapsed = timer.tick * tick.inMicroseconds;
    final day = math.min(
      _total,
      _from + elapsed * _total ~/ sweep.inMicroseconds,
    );
    if (day == _day) return;
    _day = day;
    final done = day >= _total;
    if (done) _cancel();
    state = TimelineState(
      pending: (start: _sweepStart, end: dayAt(_spanStart, day)),
      playing: !done,
    );
    _commit();
  }

  void _reset() {
    _cancel();
    _dragging = false;
    _inFlight = false;
    _started = false;
    state = TimelineState.idle;
  }

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
  }
}

final connectionsTimelineProvider =
    NotifierProvider.autoDispose<ConnectionsTimelineNotifier, TimelineState>(
      ConnectionsTimelineNotifier.new,
    );

/// The days the timeline slider shows: the range ahead of the map while a
/// drag or the sweep runs, else the filter's own, held inside the log's
/// span. Null when the log spans fewer than two days.
final connectionsTimelineRangeProvider = Provider.autoDispose<DayRange?>((ref) {
  final span = ref.watch(connectionsDateSpanProvider).value;
  if (span == null || !span.start.isBefore(span.end)) return null;
  final pending = ref.watch(
    connectionsTimelineProvider.select((s) => s.pending),
  );
  if (pending != null) return clampDays(pending, span);
  return filteredDays(ref.watch(connectionsFilterProvider), span);
});
