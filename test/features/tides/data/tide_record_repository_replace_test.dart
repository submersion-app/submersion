import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A dive has at most one tide record, however many writers record it at
/// once: after a save in a sitting moves the dive's site, the save's own
/// follow-up and the tide card's heal both record it (issue #4527).
void main() {
  late AppDatabase db;
  const diveId = 'd1';

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: diveId, diveNumber: 1),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<int> rows() async => (await (db.select(
    db.tideRecords,
  )..where((t) => t.diveId.equals(diveId))).get()).length;

  test('two records made at once leave one', () async {
    final tides = TideRecordRepository();
    const status = TideStatus(state: TideState.rising, currentHeight: 0.4);

    await Future.wait([
      tides.createFromStatus(diveId: diveId, status: status),
      tides.createFromStatus(diveId: diveId, status: status),
    ]);

    expect(await rows(), 1);
  });

  test('two made at once over a stored one leave one', () async {
    final tides = TideRecordRepository();
    const status = TideStatus(state: TideState.falling, currentHeight: 0.2);
    await tides.createFromStatus(diveId: diveId, status: status);

    await Future.wait([
      tides.createFromStatus(diveId: diveId, status: status),
      tides.createFromStatus(diveId: diveId, status: status),
    ]);

    expect(await rows(), 1);
  });
}
