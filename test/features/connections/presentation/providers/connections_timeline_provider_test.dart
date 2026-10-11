import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_timeline_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/mock_providers.dart';

final DayRange _span = (
  start: DateTime(2019, 1, 1),
  end: DateTime(2022, 12, 31),
);

/// Lets a test move the span, as a synced dive would.
final _spanState = StateProvider<DayRange?>((ref) => _span);

/// Stands in for the page's graph: reloads on every filter change and takes
/// a second, like a large log.
final _graph = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(connectionsFilterProvider);
  await Future<void>.delayed(const Duration(seconds: 1));
  return 1;
});

/// Riverpod refreshes dependent providers on a zero-length timer, not a
/// microtask, so fake time has to step past it.
void flush(FakeAsync async) => async.elapse(Duration.zero);

/// The sweep's ticker is the only periodic timer the timeline starts.
Iterable<FakeTimer> sweepTimers(FakeAsync async) =>
    async.pendingTimers.where((t) => t.isPeriodic);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Override> base;
  setUp(() async {
    base = await getBaseOverrides();
  });

  ProviderContainer container({DayRange? span}) {
    final c = ProviderContainer(
      overrides: [
        ...base,
        if (span != null) _spanState.overrideWith((ref) => span),
        connectionsDateSpanProvider.overrideWith(
          (ref) async => ref.watch(_spanState),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(connectionsTimelineProvider, (_, _) {});
    c.listen(connectionsDateSpanProvider, (_, _) {});
    c.listen(connectionsTimelineRangeProvider, (_, _) {});
    return c;
  }

  DiveFilterState filter(ProviderContainer c) =>
      c.read(connectionsFilterProvider);
  TimelineState timeline(ProviderContainer c) =>
      c.read(connectionsTimelineProvider);
  ConnectionsTimelineNotifier notifier(ProviderContainer c) =>
      c.read(connectionsTimelineProvider.notifier);
  void settle(ConnectionsTimelineNotifier n) => n
    ..loadStarted()
    ..loadSettled(failed: false);

  test('from the full span, play starts the end at the start day', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      notifier(c).play();
      expect(timeline(c).playing, isTrue);
      expect(timeline(c).pending, (
        start: DateTime(2019, 1, 1),
        end: DateTime(2019, 1, 1),
      ));
      expect(filter(c).startDate, isNull, reason: 'the span start is open');
      expect(filter(c).endDate, DateTime(2019, 1, 1));
      notifier(c).pause();
    });
  });

  test('the sweep crosses the whole span in 20 s, the map following', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final n = notifier(c)..play();
      async.elapse(const Duration(seconds: 10));
      expect(timeline(c).pending!.end, DateTime(2020, 12, 31));
      expect(
        filter(c).endDate,
        DateTime(2019, 1, 1),
        reason: 'the first load has not settled',
      );
      settle(n);
      expect(filter(c).endDate, DateTime(2020, 12, 31));
      async.elapse(const Duration(seconds: 10));
      expect(timeline(c).playing, isFalse);
      expect(timeline(c).pending!.end, DateTime(2022, 12, 31));
      settle(n);
      expect(filter(c).startDate, isNull, reason: 'the whole span');
      expect(filter(c).endDate, isNull);
      settle(n);
      expect(timeline(c), TimelineState.idle);
      expect(sweepTimers(async), isEmpty);
    });
  });

  test('moves during one load make one write, of the latest range', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final writes = <DiveFilterState>[];
      c.listen(connectionsFilterProvider, (_, next) => writes.add(next));
      final n = notifier(c)..dragStart();
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)));
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 2)));
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 3)));
      expect(writes.length, 1);
      expect(
        c.read(connectionsTimelineRangeProvider)!.end,
        DateTime(2020, 6, 3),
        reason: 'the thumbs run ahead of the map',
      );
      settle(n);
      expect(writes.length, 2);
      expect(writes.last.endDate, DateTime(2020, 6, 3));
      n.dragEnd((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 3)));
      settle(n);
      expect(writes.length, 2, reason: 'already on the map');
      expect(timeline(c), TimelineState.idle);
    });
  });

  test('a settle from before the write is not counted', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final n = notifier(c)..dragStart();
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)));
      n.loadSettled(failed: false);
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 7, 1)));
      expect(filter(c).endDate, DateTime(2020, 6, 1));
      settle(n);
      expect(filter(c).endDate, DateTime(2020, 7, 1));
    });
  });

  test('a load reported during the filter write still counts', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final n = notifier(c);
      // A graph that rebuilds synchronously reports its load inside the
      // filter write itself.
      c.listen(connectionsFilterProvider, (_, _) => settle(n));
      n
        ..dragStart()
        ..dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)))
        ..dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 7, 1)));
      expect(filter(c).endDate, DateTime(2020, 7, 1));
    });
  });

  test('dragging to the whole span clears the dates', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: DateTime(2020),
        endDate: DateTime(2021),
      );
      notifier(c)
        ..dragStart()
        ..dragEnd(_span);
      expect(filter(c).startDate, isNull);
      expect(filter(c).endDate, isNull);
    });
  });

  test('from a range that ends early, play continues from its end', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 6, 30),
      );
      final n = notifier(c)..play();
      expect(timeline(c).pending, (
        start: DateTime(2020, 1, 1),
        end: DateTime(2020, 6, 30),
      ));
      async.elapse(ConnectionsTimelineNotifier.sweep);
      settle(n);
      expect(filter(c).startDate, DateTime(2020, 1, 1));
      expect(filter(c).endDate, isNull, reason: 'the span end is open');
    });
  });

  test('an outside filter change stops play and is never overwritten', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final n = notifier(c)..play();
      final mine = DiveFilterState(endDate: DateTime(2021, 6, 1));
      c.read(connectionsFilterProvider.notifier).state = mine;
      flush(async);
      expect(timeline(c), TimelineState.idle);
      settle(n);
      async.elapse(const Duration(seconds: 5));
      expect(filter(c), mine);
      expect(sweepTimers(async), isEmpty);
    });
  });

  test('a view change, a failed load and pause each stop play', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final n = notifier(c)..play();
      c
          .read(connectionsViewProvider.notifier)
          .update((v) => v.withMode(ConnectionsMode.around));
      flush(async);
      expect(timeline(c).playing, isFalse);

      n.play();
      expect(timeline(c).playing, isTrue);
      n.loadSettled(failed: true);
      expect(timeline(c), TimelineState.idle);

      n
        ..play()
        ..pause();
      expect(timeline(c).playing, isFalse);
      expect(sweepTimers(async), isEmpty);
    });
  });

  test('colouring the map does not stop play', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final n = notifier(c)..play();
      c
          .read(connectionsViewProvider.notifier)
          .update((v) => v.withHighlight(HighlightMode.groups));
      flush(async);
      expect(timeline(c).playing, isTrue);
      n.pause();
    });
  });

  test('disposing the provider cancels the sweep', () {
    fakeAsync((async) {
      final c = ProviderContainer(
        overrides: [
          ...base,
          connectionsDateSpanProvider.overrideWith((ref) async => _span),
        ],
      );
      addTearDown(c.dispose);
      final keep = c.listen(connectionsTimelineProvider, (_, _) {});
      c.listen(connectionsDateSpanProvider, (_, _) {});
      flush(async);
      c.read(connectionsTimelineProvider.notifier).play();
      final written = c.read(connectionsFilterProvider);
      keep.close();
      flush(async);
      async.elapse(const Duration(seconds: 3));
      expect(c.read(connectionsFilterProvider), written);
      expect(sweepTimers(async), isEmpty);
    });
  });

  test('the range follows the filter when idle, clamped for display only', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      expect(c.read(connectionsTimelineRangeProvider), _span);
      final outside = DiveFilterState(
        startDate: DateTime(2010),
        endDate: DateTime(2021, 4, 5),
      );
      c.read(connectionsFilterProvider.notifier).state = outside;
      expect(c.read(connectionsTimelineRangeProvider), (
        start: DateTime(2019, 1, 1),
        end: DateTime(2021, 4, 5),
      ));
      expect(filter(c), outside, reason: 'not rewritten until a drag');
    });
  });

  test('a single-day log has no range and does not play', () {
    fakeAsync((async) {
      final day = DateTime(2022, 5, 5);
      final c = container(span: (start: day, end: day));
      flush(async);
      expect(c.read(connectionsTimelineRangeProvider), isNull);
      notifier(c).play();
      expect(timeline(c), TimelineState.idle);
      expect(filter(c).endDate, isNull);
      expect(sweepTimers(async), isEmpty);
    });
  });

  // Review focus 1.
  test('a span that shrinks keeps the pending range inside it', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      notifier(c)
        ..dragStart()
        ..dragTo((start: DateTime(2022, 6, 1), end: DateTime(2022, 12, 31)));
      c.read(_spanState.notifier).state = (
        start: DateTime(2019, 1, 1),
        end: DateTime(2022, 6, 30),
      );
      flush(async);
      expect(c.read(connectionsTimelineRangeProvider), (
        start: DateTime(2022, 6, 1),
        end: DateTime(2022, 6, 30),
      ));
    });
  });

  // Review focus 2.
  test('pause then play resumes from where the sweep stopped', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final n = notifier(c)..play();
      async.elapse(const Duration(seconds: 10));
      n.pause();
      final paused = timeline(c).pending!.end;
      expect(paused, DateTime(2020, 12, 31));
      n.play();
      expect(timeline(c).pending!.end, paused);
      expect(timeline(c).pending!.start, DateTime(2019, 1, 1));
      n.pause();
    });
  });

  // Review focus 3.
  test('grabbing a thumb and letting go without moving writes nothing', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final writes = <DiveFilterState>[];
      c.listen(connectionsFilterProvider, (_, next) => writes.add(next));
      notifier(c)
        ..dragStart()
        ..dragEnd(_span);
      expect(writes, isEmpty);
      expect(timeline(c), TimelineState.idle);
    });
  });

  // Review focus 5.
  test('play with both thumbs on the last day does nothing', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final last = DateTime(2022, 12, 31);
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: last,
        endDate: last,
      );
      notifier(c).play();
      expect(timeline(c), TimelineState.idle);
      expect(sweepTimers(async), isEmpty);
    });
  });

  /// Wires [_graph] to the notifier the way ConnectionsPage does: the
  /// listener reports changes, and each build reports whether it is loading.
  void wireGraph(ProviderContainer c) {
    final n = notifier(c);
    c.listen<AsyncValue<int>>(_graph, (_, next) {
      if (next.isLoading) {
        n.loadStarted();
      } else {
        n.loadSettled(failed: next.hasError);
      }
    });
    n.syncLoading(c.read(_graph).isLoading);
  }

  test('a write during an unrelated reload still reaches the map', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      wireGraph(c);
      async.elapse(const Duration(seconds: 1));
      // A reload the timeline did not cause, for instance a view change.
      c.invalidate(_graph);
      async.elapse(const Duration(milliseconds: 500));
      final n = notifier(c)..dragStart();
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)));
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 7, 1)));
      n.dragEnd((start: DateTime(2020, 3, 1), end: DateTime(2020, 7, 1)));
      async.elapse(const Duration(seconds: 3));
      expect(filter(c).endDate, DateTime(2020, 7, 1));
      expect(timeline(c), TimelineState.idle);
    });
  });

  test('a drag during the first load still reaches the map', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      wireGraph(c);
      final n = notifier(c)..dragStart();
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)));
      n.dragEnd((start: DateTime(2020, 3, 1), end: DateTime(2020, 7, 1)));
      async.elapse(const Duration(seconds: 3));
      expect(filter(c).endDate, DateTime(2020, 7, 1));
      expect(timeline(c), TimelineState.idle);
    });
  });

  test('moving a thumb by a screen reader during play stops the sweep', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      final n = notifier(c)..play();
      async.elapse(const Duration(seconds: 1));
      // Semantic increase and decrease call onChanged with no onChangeStart.
      final DayRange moved = (
        start: DateTime(2019, 1, 1),
        end: DateTime(2021, 5, 5),
      );
      n.dragTo(moved);
      async.elapse(const Duration(seconds: 2));
      expect(timeline(c).playing, isFalse);
      expect(timeline(c).pending, moved);
      expect(sweepTimers(async), isEmpty);
    });
  });

  test('a span change during play stops the sweep', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      notifier(c).play();
      async.elapse(const Duration(seconds: 1));
      // A synced dive moves the last day on.
      c.read(_spanState.notifier).state = (
        start: DateTime(2019, 1, 1),
        end: DateTime(2023, 3, 1),
      );
      flush(async);
      expect(timeline(c).playing, isFalse);
      expect(sweepTimers(async), isEmpty);
    });
  });

  test('a span that collapses mid-drag drops the drag', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      notifier(c)
        ..dragStart()
        ..dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)));
      final day = DateTime(2022, 5, 5);
      c.read(_spanState.notifier).state = (start: day, end: day);
      flush(async);
      expect(timeline(c), TimelineState.idle);
    });
  });

  test('a span reload stops the sweep before the new span arrives', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      notifier(c).play();
      async.elapse(const Duration(seconds: 1));
      // A diver switch reloads the span; the old one is still the value
      // while it loads, and must not keep being swept.
      c.invalidate(connectionsDateSpanProvider);
      flush(async);
      expect(timeline(c).playing, isFalse);
      expect(sweepTimers(async), isEmpty);
    });
  });

  test('play started during a span reload stops when a new span lands', () {
    fakeAsync((async) {
      final c = container();
      flush(async);
      // The reload is under way; the old span is still the value.
      c.read(_spanState.notifier).state = (
        start: DateTime(2019, 1, 1),
        end: DateTime(2023, 3, 1),
      );
      notifier(c).play();
      expect(timeline(c).playing, isTrue);
      flush(async);
      expect(timeline(c).playing, isFalse);
      expect(sweepTimers(async), isEmpty);
    });
  });

  test('timeline states with the same range and play flag are equal', () {
    final DayRange range = (start: DateTime(2020), end: DateTime(2021));
    expect(
      TimelineState(pending: range, playing: true),
      TimelineState(pending: range, playing: true),
    );
    expect(
      TimelineState(pending: range, playing: true).hashCode,
      TimelineState(pending: range, playing: true).hashCode,
    );
    expect(TimelineState(pending: range), isNot(TimelineState.idle));
  });
}
