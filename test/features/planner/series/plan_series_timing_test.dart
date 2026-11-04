import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart';

import 'series_fixtures.dart';

const _config = PlanEngineConfig();

/// 09:00 on the dive day, as the dive log stores it: clock digits as UTC.
final _nine = DateTime.utc(2026, 10, 27, 9);

/// Dive A, then Dive B after [interval].
PlanSeries _twoDives({
  DateTime? start,
  Duration interval = const Duration(hours: 1),
}) {
  var series = PlanSeries.single(
    seriesDiveState().copyWith(startDateTime: start),
  );
  series = appendDive(series, newId: idSequence());
  final b = series.dives[1];
  return updateDiveState(
    series,
    1,
    b.state.copyWith(surfaceInterval: interval),
    pinTypedPressures: false,
  );
}

/// When [result]'s dive ends, as clock digits.
DateTime _end(SeriesDiveResult result) => asWallClockUtc(
  fromWallClockUtc(
    result.state.startDateTime!,
  ).add(Duration(seconds: result.outcome.runtimeSeconds)),
);

SeriesFollow _follow(DateTime endInstant) => SeriesFollow(
  loggedDives: [
    SeriesLoggedDive(
      id: 'logged',
      start: asWallClockUtc(endInstant.subtract(const Duration(minutes: 45))),
      end: asWallClockUtc(endInstant),
      endInstant: endInstant,
    ),
  ],
);

void main() {
  group('start times through a series', () {
    test('a later dive starts at the previous end plus its interval', () {
      final results = computeSeries(
        _twoDives(start: _nine).dives,
        config: _config,
      );

      expect(results[0].state.startDateTime, _nine);
      expect(
        results[1].state.startDateTime,
        _end(results[0]).add(const Duration(hours: 1)),
      );
    });

    test('with no start anywhere, later dives have none either', () {
      final results = computeSeries(_twoDives().dives, config: _config);

      expect(results[0].state.startDateTime, isNull);
      expect(results[1].state.startDateTime, isNull);
      expect(results[1].state.surfaceInterval, const Duration(hours: 1));
    });

    test('a start copied from Dive A is not kept once A has none', () {
      var series = _twoDives(start: _nine);
      series = updateDiveState(
        series,
        0,
        series.dives[0].state.copyWith(clearStartDateTime: true),
        pinTypedPressures: false,
      );
      final results = computeSeries(series.dives, config: _config);

      expect(results[1].state.startDateTime, isNull);
    });

    test('a later dive given a start takes its interval from it', () {
      var series = _twoDives(start: _nine);
      final aEnd = _end(computeSeries(series.dives, config: _config)[0]);
      final bStart = aEnd.add(const Duration(hours: 2, minutes: 30));
      series = setDiveStart(series, 1, bStart);

      final results = computeSeries(series.dives, config: _config);

      expect(results[1].state.startDateTime, bStart);
      expect(
        results[1].state.surfaceInterval,
        const Duration(hours: 2, minutes: 30),
      );
    });

    test('a fixed start keeps its time when an earlier dive gets longer', () {
      var series = _twoDives(start: _nine);
      final aEnd = _end(computeSeries(series.dives, config: _config)[0]);
      final bStart = aEnd.add(const Duration(hours: 2));
      series = setDiveStart(series, 1, bStart);
      final a = series.dives[0].state;
      series = updateDiveState(
        series,
        0,
        a.copyWith(
          segments: [
            a.segments[0],
            a.segments[1].copyWith(durationSeconds: 35 * 60),
          ],
        ),
        pinTypedPressures: false,
      );

      final results = computeSeries(series.dives, config: _config);

      expect(results[1].state.startDateTime, bStart);
      expect(
        results[1].state.surfaceInterval,
        lessThan(const Duration(hours: 2)),
      );
    });

    test('a start before the previous dive ends computes from no interval', () {
      var series = _twoDives(start: _nine);
      series = setDiveStart(series, 1, _nine.add(const Duration(minutes: 5)));

      final results = computeSeries(series.dives, config: _config);

      expect(results[1].state.surfaceInterval, Duration.zero);
    });

    test('a start has no effect until there is a previous end to measure '
        'from', () {
      var series = _twoDives();
      series = setDiveStart(series, 1, _nine);

      final results = computeSeries(series.dives, config: _config);

      expect(results[1].state.surfaceInterval, const Duration(hours: 1));
      expect(results[1].state.startDateTime, isNull);
    });

    test('the interval sets the OTU window, not the stored interval', () {
      // B fixed 30 hours after A: A's OTU is out of the daily window even
      // though B's own interval still reads 1:00.
      var series = _twoDives(start: _nine);
      final aEnd = _end(computeSeries(series.dives, config: _config)[0]);
      series = setDiveStart(series, 1, aEnd.add(const Duration(hours: 30)));

      final results = computeSeries(series.dives, config: _config);

      expect(results[1].state.initialOtu, 0);
    });
  });

  group('start times after a followed dive', () {
    final endInstant = DateTime(2026, 10, 27, 8);

    test('Dive A starts at the followed end plus its interval', () {
      final series = _twoDives().copyWith(follow: _follow(endInstant));
      final first = series.dives[0];
      final withInterval = updateDiveState(
        series,
        0,
        first.state.copyWith(surfaceInterval: const Duration(minutes: 90)),
        pinTypedPressures: false,
      );

      final results = computeSeries(
        withInterval.dives,
        config: _config,
        follow: withInterval.follow,
      );

      expect(
        results[0].state.startDateTime,
        asWallClockUtc(endInstant.add(const Duration(minutes: 90))),
      );
    });

    test('a start given to Dive A sets its interval', () {
      var series = _twoDives().copyWith(follow: _follow(endInstant));
      series = setDiveStart(
        series,
        0,
        asWallClockUtc(endInstant.add(const Duration(hours: 3))),
      );

      final results = computeSeries(
        series.dives,
        config: _config,
        follow: series.follow,
      );

      expect(results[0].state.surfaceInterval, const Duration(hours: 3));
    });
  });

  group('setDiveStart and anchorInterval', () {
    test('a start fixes it; clearing it lets the interval lead again', () {
      var series = _twoDives(start: _nine);
      series = setDiveStart(series, 1, _nine.add(const Duration(hours: 4)));
      expect(series.dives[1].fixedStart, isTrue);
      expect(
        series.dives[1].state.startDateTime,
        _nine.add(const Duration(hours: 4)),
      );

      series = setDiveStart(series, 1, null);
      expect(series.dives[1].fixedStart, isFalse);
      expect(series.dives[1].state.startDateTime, isNull);
    });

    test('anchorInterval lets the interval lead', () {
      var series = _twoDives(start: _nine);
      series = setDiveStart(series, 1, _nine.add(const Duration(hours: 4)));
      series = anchorInterval(series, 1);

      expect(series.dives[1].fixedStart, isFalse);
    });

    test('a new dive is led by its interval', () {
      var series = _twoDives(start: _nine);
      series = setDiveStart(series, 1, _nine.add(const Duration(hours: 4)));
      series = appendDive(series, newId: idSequence('c'));

      expect(series.dives[2].fixedStart, isFalse);
    });
  });
}
