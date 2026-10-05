import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Grows the map one year at a time by moving the connections filter's end
/// date. The state is the year on screen while playing, null when idle.
///
/// A beat moves to the next year only once [beat] has passed and the page
/// has reported the year's graph loaded ([loadSettled]), so a slow log never
/// piles up steps. Any filter change it did not make itself, and any view
/// change other than the highlight mode, stops play, so it never overwrites
/// what the diver just chose.
class YearPlayNotifier extends Notifier<int?> {
  static const Duration beat = Duration(milliseconds: 1200);

  Timer? _timer;
  bool _beatDone = false;
  bool _loaded = false;

  /// True once a graph load has started since play last wrote the filter;
  /// a load that settles before then was for the old filter.
  bool _started = false;

  /// The last filter play wrote, to tell its own writes from the diver's.
  DiveFilterState? _written;
  int _first = 0;
  int _last = 0;

  @override
  int? build() {
    ref.onDispose(_cancel);
    ref.listen<DiveFilterState>(connectionsFilterProvider, (_, next) {
      if (state != null && next != _written) stop();
    });
    // Colouring the map is not a change of what it shows: play carries on.
    ref.listen<ConnectionsViewState>(connectionsViewProvider, (prev, next) {
      if (state != null &&
          prev != null &&
          prev.copyWith(highlight: next.highlight) != next) {
        stop();
      }
    });
    return null;
  }

  /// Starts from the lower year when the range already reaches the last
  /// year, otherwise continues past the current upper year.
  void play() {
    final span = ref.read(connectionsYearSpanProvider).value;
    if (span == null || span.first >= span.last) return;
    final filter = ref.read(connectionsFilterProvider);
    final (:lower, :upper) = filteredYears(filter, span);
    _first = span.first;
    _last = span.last;
    _show(upper >= span.last ? lower : upper + 1);
  }

  /// Stops where it is; the slider keeps the range on screen.
  void pause() => stop();

  void stop() {
    _cancel();
    state = null;
  }

  /// The page reports each load of the graph that starts.
  void loadStarted() {
    if (state != null) _started = true;
  }

  /// The page reports each settled load of the graph. A failed load stops
  /// play; the page shows the reload error.
  void loadSettled({required bool failed}) {
    if (state == null) return;
    if (failed) {
      stop();
      return;
    }
    if (!_started) return;
    _loaded = true;
    _advance();
  }

  void _show(int year) {
    final filter = ref.read(connectionsFilterProvider);
    final atEnd = year >= _last;
    // The whole span is no filter at all, as the year slider has it; a start
    // date the diver chose inside the first year is theirs and stays.
    final start = filter.startDate;
    final wholeSpan =
        atEnd && (start == null || !start.isAfter(DateTime(_first)));
    final next = wholeSpan
        ? filter.copyWith(clearStartDate: true, clearEndDate: true)
        : filter.copyWith(endDate: DateTime(year, 12, 31));
    _cancel();
    state = atEnd ? null : year;
    _written = next;
    // Reset before the write: a graph that reloads synchronously reports
    // its load during it, and that report must not be wiped afterwards.
    _beatDone = false;
    _loaded = false;
    _started = false;
    ref.read(connectionsFilterProvider.notifier).state = next;
    if (atEnd) return;
    _timer = Timer(beat, () {
      _beatDone = true;
      _advance();
    });
  }

  void _advance() {
    final year = state;
    if (year == null || !_beatDone || !_loaded) return;
    _show(year + 1);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

final yearPlayProvider = NotifierProvider.autoDispose<YearPlayNotifier, int?>(
  YearPlayNotifier.new,
);

/// The years the connections filter covers within the log's [span]: no
/// start or end date means the span's own first or last year. The year
/// slider, the play pill and play itself all read the range this way.
({int lower, int upper}) filteredYears(
  DiveFilterState filter,
  ({int first, int last}) span,
) => (
  lower: (filter.startDate?.year ?? span.first).clamp(span.first, span.last),
  upper: (filter.endDate?.year ?? span.last).clamp(span.first, span.last),
);
