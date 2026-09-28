import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/site_wall_clock.dart';

const _bonaire = GeoPoint(12.15, -68.27); // America/Caracas, UTC-4, no DST

void main() {
  test('record times move to site wall clock; other fields are kept', () {
    final record = TideRecord(
      id: 'r1',
      diveId: 'd1',
      heightMeters: 0.3,
      tideState: TideState.rising,
      highTideTime: DateTime.utc(2026, 3, 28, 18, 20),
      highTideHeight: 0.4,
      lowTideTime: DateTime.utc(2026, 3, 28, 12, 20),
      lowTideHeight: 0.1,
      createdAt: DateTime.utc(2026, 3, 28),
    );
    final mapped = record.toSiteWallClock(_bonaire);
    expect(mapped.highTideTime, DateTime.utc(2026, 3, 28, 14, 20));
    expect(mapped.lowTideTime, DateTime.utc(2026, 3, 28, 8, 20));
    expect(mapped.heightMeters, 0.3);
    expect(mapped.id, 'r1');
  });

  test('missing record times stay missing', () {
    final record = TideRecord(
      id: 'r1',
      diveId: 'd1',
      heightMeters: 0.3,
      tideState: TideState.rising,
      createdAt: DateTime.utc(2026, 3, 28),
    );
    final mapped = record.toSiteWallClock(_bonaire);
    expect(mapped.highTideTime, isNull);
    expect(mapped.lowTideTime, isNull);
  });

  test('extremes and predictions map element-wise', () {
    final extremes = [
      TideExtreme(
        type: TideExtremeType.high,
        time: DateTime.utc(2026, 3, 28, 18),
        heightMeters: 0.4,
      ),
    ];
    final predictions = [
      TidePrediction(time: DateTime.utc(2026, 3, 28, 4), heightMeters: 0.2),
    ];
    expect(
      extremesAtSiteWallClock(extremes, _bonaire).single.time,
      DateTime.utc(2026, 3, 28, 14),
    );
    expect(
      predictionsAtSiteWallClock(predictions, _bonaire).single.time,
      DateTime.utc(2026, 3, 28),
    );
  });

  test('predictions stay in time order across a fall-back night', () {
    const monterey = GeoPoint(36.62, -121.90);
    // 08:00Z-10:00Z on 2026-11-01 runs 01:00 PDT, 01:00-01:59 PST again,
    // then 02:00 PST: the site clock repeats an hour.
    final predictions = [
      for (var minutes = 0; minutes <= 120; minutes += 10)
        TidePrediction(
          time: DateTime.utc(2026, 11, 1, 8).add(Duration(minutes: minutes)),
          heightMeters: minutes / 100,
        ),
    ];
    final mapped = predictionsAtSiteWallClock(predictions, monterey);
    for (var i = 1; i < mapped.length; i++) {
      expect(
        mapped[i].time.isAfter(mapped[i - 1].time),
        isTrue,
        reason: '${mapped[i - 1].time} then ${mapped[i].time}',
      );
    }
    expect(mapped.first.time, DateTime.utc(2026, 11, 1, 1));
    expect(mapped.last.time, DateTime.utc(2026, 11, 1, 2));
  });
}
