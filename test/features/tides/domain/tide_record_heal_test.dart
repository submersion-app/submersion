import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/tide_record_heal.dart';

TideRecord _record({
  double height = 1.0,
  TideState state = TideState.rising,
  DateTime? highTime,
  DateTime? lowTime,
}) {
  return TideRecord(
    id: 'r1',
    diveId: 'd1',
    heightMeters: height,
    tideState: state,
    highTideTime: highTime,
    lowTideTime: lowTime,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  final high = DateTime.utc(2026, 6, 15, 14, 0);
  final low = DateTime.utc(2026, 6, 15, 8, 0);

  test('identical records need no heal', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(highTime: high, lowTime: low),
        fresh: _record(highTime: high, lowTime: low),
      ),
      false,
    );
  });

  test('small differences inside thresholds need no heal', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(height: 1.0, highTime: high),
        fresh: _record(
          height: 1.04,
          highTime: high.add(const Duration(minutes: 9)),
        ),
      ),
      false,
    );
  });

  test('height difference above 0.05 m heals', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(height: 1.0),
        fresh: _record(height: 1.06),
      ),
      true,
    );
  });

  test('state difference heals', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(state: TideState.rising),
        fresh: _record(state: TideState.falling),
      ),
      true,
    );
  });

  test('extreme time difference above 10 minutes heals', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(highTime: high),
        fresh: _record(highTime: high.add(const Duration(minutes: 11))),
      ),
      true,
    );
  });

  test('null versus non-null extreme heals', () {
    expect(
      tideRecordNeedsHeal(
        stored: _record(highTime: null),
        fresh: _record(highTime: high),
      ),
      true,
    );
  });
}
