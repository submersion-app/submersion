import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/year_play_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Override> base;
  setUp(() async {
    base = await getBaseOverrides();
  });

  ProviderContainer container({
    ({int first, int last}) span = (first: 2019, last: 2022),
  }) {
    final c = ProviderContainer(
      overrides: [
        ...base,
        connectionsYearSpanProvider.overrideWith((ref) async => span),
      ],
    );
    addTearDown(c.dispose);
    c.listen(yearPlayProvider, (_, _) {});
    c.listen(connectionsYearSpanProvider, (_, _) {});
    return c;
  }

  DiveFilterState filter(ProviderContainer c) =>
      c.read(connectionsFilterProvider);

  test('from the full span, play restarts at the first year', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      c.read(yearPlayProvider.notifier).play();
      expect(c.read(yearPlayProvider), 2019);
      expect(filter(c).endDate, DateTime(2019, 12, 31));
      expect(filter(c).startDate, isNull);
      c.read(yearPlayProvider.notifier).pause();
    });
  });

  test('a beat waits for both the delay and the load', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      async.elapse(YearPlayNotifier.beat);
      expect(c.read(yearPlayProvider), 2019, reason: 'load not settled');
      n
        ..loadStarted()
        ..loadSettled(failed: false);
      expect(c.read(yearPlayProvider), 2020);

      n
        ..loadStarted()
        ..loadSettled(failed: false);
      async.elapse(const Duration(milliseconds: 600));
      expect(c.read(yearPlayProvider), 2020, reason: 'beat not elapsed');
      async.elapse(const Duration(milliseconds: 600));
      expect(c.read(yearPlayProvider), 2021);
      n.pause();
    });
  });

  test('reaching the last year stops and clears the whole span', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      for (var i = 0; i < 3; i++) {
        n
          ..loadStarted()
          ..loadSettled(failed: false);
        async.elapse(YearPlayNotifier.beat);
      }
      expect(c.read(yearPlayProvider), isNull);
      expect(filter(c).startDate, isNull);
      expect(filter(c).endDate, isNull);
    });
  });

  test('a later start year is kept, and the end stays at the last year', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 12, 31),
      );
      final n = c.read(yearPlayProvider.notifier)..play();
      expect(c.read(yearPlayProvider), 2021, reason: 'continues past 2020');
      expect(filter(c).startDate, DateTime(2020, 1, 1));
      n
        ..loadStarted()
        ..loadSettled(failed: false);
      async.elapse(YearPlayNotifier.beat);
      expect(c.read(yearPlayProvider), isNull);
      expect(filter(c).startDate, DateTime(2020, 1, 1));
      expect(filter(c).endDate, DateTime(2022, 12, 31));
    });
  });

  test('an outside filter change stops play and is never overwritten', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      final mine = DiveFilterState(endDate: DateTime(2021, 6, 1));
      c.read(connectionsFilterProvider.notifier).state = mine;
      async.flushMicrotasks();
      expect(c.read(yearPlayProvider), isNull);
      n
        ..loadStarted()
        ..loadSettled(failed: false);
      async.elapse(YearPlayNotifier.beat * 3);
      expect(filter(c), mine);
    });
  });

  test('a view change, a failed load and pause each stop play', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      c
          .read(connectionsViewProvider.notifier)
          .update((v) => v.withMode(ConnectionsMode.around));
      async.flushMicrotasks();
      expect(c.read(yearPlayProvider), isNull);

      n.play();
      expect(c.read(yearPlayProvider), isNotNull);
      n.loadSettled(failed: true);
      expect(c.read(yearPlayProvider), isNull);

      n.play();
      n.pause();
      expect(c.read(yearPlayProvider), isNull);
      final before = filter(c);
      async.elapse(YearPlayNotifier.beat * 2);
      expect(c.read(yearPlayProvider), isNull);
      expect(filter(c), before);
    });
  });

  test('a one-year log does not play', () {
    fakeAsync((async) {
      final c = container(span: (first: 2022, last: 2022));
      async.flushMicrotasks();
      c.read(yearPlayProvider.notifier).play();
      expect(c.read(yearPlayProvider), isNull);
      expect(filter(c).endDate, isNull);
    });
  });
  test('changing how the map is colored does not stop play', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      c
          .read(connectionsViewProvider.notifier)
          .update((v) => v.withHighlight(HighlightMode.groups));
      async.flushMicrotasks();
      expect(c.read(yearPlayProvider), 2019);
      n
        ..loadStarted()
        ..loadSettled(failed: false);
      async.elapse(YearPlayNotifier.beat);
      expect(c.read(yearPlayProvider), 2020);
      n.pause();
    });
  });

  test('disposing the provider cancels the pending beat', () {
    fakeAsync((async) {
      final c = ProviderContainer(
        overrides: [
          ...base,
          connectionsYearSpanProvider.overrideWith(
            (ref) async => (first: 2019, last: 2022),
          ),
        ],
      );
      addTearDown(c.dispose);
      final keep = c.listen(yearPlayProvider, (_, _) {});
      c.listen(connectionsYearSpanProvider, (_, _) {});
      async.flushMicrotasks();
      c.read(yearPlayProvider.notifier)
        ..play()
        ..loadStarted()
        ..loadSettled(failed: false);
      final written = c.read(connectionsFilterProvider);
      keep.close();
      async.flushMicrotasks();
      async.elapse(YearPlayNotifier.beat * 3);
      expect(c.read(connectionsFilterProvider), written);
      expect(async.pendingTimers, isEmpty);
    });
  });
  test('a start date inside the first year survives the end of play', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final start = DateTime(2019, 6, 15);
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: start,
      );
      final n = c.read(yearPlayProvider.notifier)..play();
      for (var i = 0; i < 3; i++) {
        n
          ..loadStarted()
          ..loadSettled(failed: false);
        async.elapse(YearPlayNotifier.beat);
      }
      expect(c.read(yearPlayProvider), isNull);
      expect(filter(c).startDate, start);
      expect(filter(c).endDate, DateTime(2022, 12, 31));
    });
  });
  test('a load that finished before play wrote its year is not counted', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      // A load already in flight for the old filter settles before the
      // graph has started loading the year play just wrote.
      n.loadSettled(failed: false);
      async.elapse(YearPlayNotifier.beat);
      expect(c.read(yearPlayProvider), 2019, reason: 'waits for its own load');
      n
        ..loadStarted()
        ..loadSettled(failed: false);
      expect(c.read(yearPlayProvider), 2020);
      n.pause();
    });
  });
  test('a load reported during the filter write still counts', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier);
      // A graph that rebuilds synchronously reports its load inside the
      // filter write itself.
      c.listen(connectionsFilterProvider, (_, _) {
        n
          ..loadStarted()
          ..loadSettled(failed: false);
      });
      n.play();
      async.elapse(YearPlayNotifier.beat);
      expect(c.read(yearPlayProvider), 2020);
      n.pause();
    });
  });
}
