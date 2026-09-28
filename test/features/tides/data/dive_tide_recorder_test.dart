import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';
import 'package:submersion/features/tides/data/services/dive_tide_recorder.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';

class _CapturingRepository extends TideRecordRepository {
  String? diveId;
  TideStatus? status;

  @override
  Future<TideRecord> createFromStatus({
    required String diveId,
    required TideStatus status,
  }) async {
    this.diveId = diveId;
    this.status = status;
    return TideRecord.fromStatus(id: 'r1', diveId: diveId, status: status);
  }
}

void main() {
  test('a saved dive records the tide at its real entry instant', () async {
    final calculator = TideCalculator(
      constituents: {
        'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
      },
    );
    final repository = _CapturingRepository();

    await recordDiveTide(
      repository: repository,
      calculator: calculator,
      diveId: 'd1',
      // Wall clock at Bonaire (UTC-4, no DST): 10:00 local is 14:00Z.
      entryWallClock: DateTime.utc(2026, 3, 28, 10),
      location: const GeoPoint(12.15, -68.27),
    );

    expect(repository.diveId, 'd1');
    expect(
      repository.status,
      calculator.getStatus(DateTime.utc(2026, 3, 28, 14)),
    );
  });
}
