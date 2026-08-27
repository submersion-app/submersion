import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_track_extractor.dart';

/// A RecordMessage carrying an optional position and a timestamp in Unix ms.
RecordMessage _record(double? lat, double? lon, DateTime when) {
  final r = RecordMessage();
  r.timestamp = when.millisecondsSinceEpoch;
  if (lat != null) r.positionLat = lat;
  if (lon != null) r.positionLong = lon;
  return r;
}

void main() {
  test('returns null when no record carries a position', () {
    final records = [_record(null, null, DateTime.utc(2026, 5, 22, 13))];
    expect(extractFitTrack(records), isNull);
  });

  test('collects every positioned record', () {
    final records = [
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13)),
      _record(20.51, -87.26, DateTime.utc(2026, 5, 22, 13, 1)),
      _record(20.52, -87.27, DateTime.utc(2026, 5, 22, 13, 2)),
    ];
    expect(extractFitTrack(records)!.fixes.length, 3);
  });

  test('skips records with no position but keeps the rest', () {
    final records = [
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13)),
      _record(null, null, DateTime.utc(2026, 5, 22, 13, 1)),
      _record(20.52, -87.27, DateTime.utc(2026, 5, 22, 13, 2)),
    ];
    expect(extractFitTrack(records)!.fixes.length, 2);
  });

  test('keeps positions in degrees without re-scaling', () {
    // fit_tool already applies the semicircle scale. Applying it again would
    // collapse every coordinate toward zero.
    final records = [
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13)),
      _record(20.51, -87.26, DateTime.utc(2026, 5, 22, 13, 1)),
    ];
    final fixes = extractFitTrack(records)!.fixes;
    expect(fixes.first.lat, closeTo(20.50, 1e-6));
    expect(fixes.first.lon, closeTo(-87.25, 1e-6));
  });

  test('returns null for a single positioned record (nothing to draw)', () {
    final records = [_record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13))];
    expect(extractFitTrack(records), isNull);
  });

  test('orders fixes by timestamp', () {
    final records = [
      _record(20.52, -87.27, DateTime.utc(2026, 5, 22, 13, 2)),
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13)),
    ];
    final fixes = extractFitTrack(records)!.fixes;
    expect(fixes.first.utc.minute, 0);
  });

  test('drops an out-of-range coordinate without losing the track', () {
    final records = [
      _record(200.0, -87.25, DateTime.utc(2026, 5, 22, 13)),
      _record(20.51, -87.26, DateTime.utc(2026, 5, 22, 13, 1)),
      _record(20.52, -87.27, DateTime.utc(2026, 5, 22, 13, 2)),
    ];
    expect(extractFitTrack(records)!.fixes.length, 2);
  });

  test('parses timestamps as real UTC', () {
    final records = [
      _record(20.50, -87.25, DateTime.utc(2026, 5, 22, 13)),
      _record(20.51, -87.26, DateTime.utc(2026, 5, 22, 13, 1)),
    ];
    final first = extractFitTrack(records)!.fixes.first;
    expect(first.utc.isUtc, isTrue);
    expect(first.utc, DateTime.utc(2026, 5, 22, 13));
  });
}
