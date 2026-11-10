import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_log/data/services/draft_conditions_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';
import 'package:submersion/features/tides/data/services/dive_tide_recorder.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';

class _CapturingRepository extends TideRecordRepository {
  String? diveId;
  TideStatus? status;
  String? id;

  @override
  Future<TideRecord> createFromStatus({
    required String diveId,
    required TideStatus status,
    String? id,
  }) async {
    this.diveId = diveId;
    this.status = status;
    this.id = id;
    return TideRecord.fromStatus(
      id: id ?? 'r1',
      diveId: diveId,
      status: status,
    );
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
      waterType: WaterType.salt,
    );

    expect(repository.diveId, 'd1');
    expect(
      repository.status,
      calculator.getStatus(DateTime.utc(2026, 3, 28, 14)),
    );
  });

  test('a record id given is the one kept, so two devices converge on one '
      'row (issue #637)', () async {
    final repository = _CapturingRepository();

    await recordDiveTide(
      repository: repository,
      calculator: TideCalculator(
        constituents: {
          'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
        },
      ),
      diveId: 'd1',
      entryWallClock: DateTime.utc(2026, 3, 28, 10),
      location: const GeoPoint(12.15, -68.27),
      waterType: WaterType.salt,
      id: draftTideRecordId('d1'),
    );

    expect(repository.id, draftTideRecordId('d1'));
    expect(draftTideRecordId('d1'), isNot(draftTideRecordId('d2')));
  });

  test('a dive marked freshwater records no tide', () async {
    final repository = _CapturingRepository();

    final record = await recordDiveTide(
      repository: repository,
      calculator: TideCalculator(
        constituents: {
          'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
        },
      ),
      diveId: 'd1',
      entryWallClock: DateTime.utc(2026, 3, 28, 10),
      location: const GeoPoint(12.15, -68.27),
      waterType: WaterType.fresh,
    );

    expect(record, isNull);
    expect(repository.diveId, isNull);
  });
}
