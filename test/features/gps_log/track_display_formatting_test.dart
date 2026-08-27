import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

GpsTrackPoint _p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: 20.0, longitude: -87.0);

/// 08:00-12:00 with a fix every hour.
GpsTrack _track({int? trimStart, int? trimEnd, bool hydrated = true}) {
  final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
  final points = [for (var h = 0; h <= 4; h++) _p(startMs ~/ 1000 + h * 3600)];
  return GpsTrack(
    id: 't',
    startTime: startMs,
    endTime: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    pointCount: points.length,
    points: hydrated ? points : const [],
    trimStartTime: trimStart,
    trimEndTime: trimEnd,
  );
}

void main() {
  group('effectivePointCount', () {
    test('is the stored count when there is no trim', () {
      expect(_track().effectivePointCount, 5);
      expect(_track(hydrated: false).effectivePointCount, 5);
    });

    test('counts only the fixes inside the trim window', () {
      final track = _track(
        trimStart: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
      );
      expect(track.effectivePointCount, 3);
    });

    test('is null when trimmed but the row carries no points', () {
      // List rows are hydrated without points on purpose. Returning the
      // stored count here would print the untrimmed number beside a trimmed
      // duration, contradicting the detail page.
      final track = _track(
        trimStart: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
        hydrated: false,
      );
      expect(track.effectivePointCount, isNull);
    });

    test('an empty track reports zero rather than unknown', () {
      const track = GpsTrack(id: 't', startTime: 0, trimStartTime: 1);
      expect(track.effectivePointCount, 0);
    });
  });

  group('geo distance formatting', () {
    UnitFormatter formatter(DepthUnit unit) =>
        UnitFormatter(AppSettings(depthUnit: unit));

    test('a boat crossing reads in km, not thousands of metres', () {
      // formatDistance, the depth-unit formatter, rendered this as "74000 m".
      expect(formatter(DepthUnit.meters).formatGeoDistance(74000), '74 km');
    });

    test('a short hop stays in metres', () {
      expect(formatter(DepthUnit.meters).formatGeoDistance(420), '420 m');
    });

    test('imported divers get miles', () {
      expect(formatter(DepthUnit.feet).formatGeoDistance(74000), '46 mi');
    });
  });

  group('formatTimeWithSeconds', () {
    UnitFormatter formatter(TimeFormat f) =>
        UnitFormatter(AppSettings(timeFormat: f));

    final time = DateTime.utc(2026, 5, 22, 14, 30, 7);

    test('honours the 24-hour preference', () {
      expect(
        formatter(TimeFormat.twentyFourHour).formatTimeWithSeconds(time),
        '14:30:07',
      );
    });

    test('honours the 12-hour preference rather than forcing a 24h clock', () {
      // DateFormat.Hms() ignored the preference entirely.
      expect(
        formatter(TimeFormat.twelveHour).formatTimeWithSeconds(time),
        startsWith('2:30:07'),
      );
    });
  });
}
