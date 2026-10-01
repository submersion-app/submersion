import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/services/site_wall_clock.dart';
import 'package:submersion/features/tides/domain/services/tide_status_for_dive.dart';

/// NOAA prints "2026-03-08 03:31"; the digits are site wall-clock.
DateTime _wallClock(String noaaLocal) {
  final parsed = DateTime.parse(noaaLocal.replaceFirst(' ', 'T'));
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
  );
}

({
  TideCalculator calculator,
  GeoPoint location,
  List<Map<String, dynamic>> extremes,
})
_load(String station) {
  final fixture =
      json.decode(
            File(
              p.join(
                'test',
                'core',
                'tide',
                'fixtures',
                'noaa_local_$station.json',
              ),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final constituents = <String, TideConstituent>{
    for (final entry
        in (fixture['constituents'] as Map<String, dynamic>).entries)
      entry.key: TideConstituent(
        name: entry.key,
        amplitude: ((entry.value as Map)['amplitude'] as num).toDouble(),
        phase: ((entry.value as Map)['phase'] as num).toDouble(),
      ),
  };
  return (
    calculator: TideCalculator(
      constituents: constituents,
      z0: (fixture['z0MetersAboveMllw'] as num).toDouble(),
    ),
    location: GeoPoint(
      (fixture['latitude'] as num).toDouble(),
      (fixture['longitude'] as num).toDouble(),
    ),
    extremes: (fixture['expectedLocalExtremes'] as List)
        .cast<Map<String, dynamic>>(),
  );
}

/// Minutes from [expected] to the nearest same-type extreme in [status],
/// after mapping it with [toDisplay].
double _errorMinutes(
  TideStatus status,
  TideExtremeType type,
  DateTime expected,
  DateTime Function(DateTime) toDisplay,
) {
  final candidates = [status.previousExtreme, status.nextExtreme]
      .whereType<TideExtreme>()
      .where((e) => e.type == type)
      .map((e) => toDisplay(e.time).difference(expected).inSeconds.abs() / 60);
  return candidates.isEmpty ? double.infinity : candidates.reduce(math.min);
}

void main() {
  for (final station in ['9414290', '9755371']) {
    test('NOAA $station local-time extremes round-trip through site time', () {
      final data = _load(station);
      final toSite = siteClockConverter(data.location);
      expect(data.extremes, isNotEmpty);
      for (final e in data.extremes) {
        final expected = _wallClock(e['localTime'] as String);
        final type = e['type'] == 'H'
            ? TideExtremeType.high
            : TideExtremeType.low;
        // Synchronous here: tideStatusForDive is getStatusAsync at this
        // instant, and 35 isolate spawns would only slow the test.
        final status = data.calculator.getStatus(
          diveEntryInstant(
            expected.subtract(const Duration(hours: 1)),
            data.location,
          ),
        );
        final error = _errorMinutes(status, type, expected, toSite);
        expect(
          error,
          lessThanOrEqualTo(20),
          reason: '$station ${e['type']} at ${e['localTime']}',
        );
      }
    });
  }

  test('the old path (wall clock fed in as an instant) misses by hours', () {
    final data = _load('9755371');
    final errors = <double>[];
    for (final e in data.extremes) {
      final expected = _wallClock(e['localTime'] as String);
      final type = e['type'] == 'H'
          ? TideExtremeType.high
          : TideExtremeType.low;
      final status = data.calculator.getStatus(
        expected.subtract(const Duration(hours: 1)),
      );
      errors.add(_errorMinutes(status, type, expected, (t) => t));
    }
    errors.sort();
    expect(errors[errors.length ~/ 2], greaterThanOrEqualTo(60));
  });

  test('diveEntryInstant reads the site clock', () {
    expect(
      diveEntryInstant(
        DateTime.utc(2026, 3, 28, 10),
        const GeoPoint(12.15, -68.27),
      ),
      DateTime.utc(2026, 3, 28, 14),
    );
  });

  test('tideStatusForDive evaluates the dive\'s real entry instant', () async {
    final data = _load('9755371');
    final entry = DateTime.utc(2026, 7, 14, 10);
    final status = await tideStatusForDive(
      calculator: data.calculator,
      entryWallClock: entry,
      location: data.location,
    );
    // San Juan is UTC-4 with no DST: 10:00 local is 14:00Z.
    expect(status, data.calculator.getStatus(DateTime.utc(2026, 7, 14, 14)));
  });
}
