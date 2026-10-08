import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Design spec 2026-09-10-underwater-nav-track-design.md, "Sync, backup,
/// reset": "Verify how a peer on an older build treats an unknown entity
/// type from a newer peer before shipping; unknown types should be
/// skipped, not fail the sync."
///
/// This build cannot literally receive a *future* entity it has never
/// heard of, so the regression is simulated with a made-up entity name
/// standing in for whatever a newer peer adds after this build ships.
/// Three layers already provide the guarantee, all exercised here:
///
/// 1. [SyncData.fromJson] only reads the keys its typed fields declare, so
///    an unrecognized top-level key on the wire is silently dropped rather
///    than causing a parse failure.
/// 2. [SyncDataSerializer.upsertRecord] and [SyncDataSerializer.deleteRecord]
///    (the single-record paths the incremental merge and conflict
///    resolution use) fall through their switch with no default case for
///    an unrecognized entityType, so they return without throwing.
/// 3. The streaming replace-adopt path only ever calls the batch
///    upsertRecords/deleteAllRecords for entities present in
///    [SyncService.entityHasUpdatedAt] (via `_baseApplyEntityFlags`), so an
///    unrecognized entity from a newer peer's base export is filtered out
///    before it ever reaches those methods.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  const futureEntity = 'seacraftEnc4RouteFromAFutureBuild';

  test('SyncData.fromJson ignores an entity type this build does not know', () {
    final data = SyncData.fromJson({
      futureEntity: [
        {'id': 'x'},
      ],
      'gpsTracks': [
        {
          'id': 'g1',
          'startTime': 1,
          'endTime': 2,
          'tzOffsetMinutes': 0,
          'pointCount': 0,
          'createdAt': 1,
          'updatedAt': 1,
        },
      ],
    });

    expect(data.gpsTracks, hasLength(1));
    expect(data.toJson().containsKey(futureEntity), isFalse);
  });

  test('entityHasUpdatedAt (the base-adopt entity allowlist) has no entry for '
      'an unrecognized entity, so the streaming adopt loop skips it', () {
    expect(SyncService.entityHasUpdatedAt.containsKey(futureEntity), isFalse);
  });

  test('upsertRecord does not throw on an unrecognized entity type', () async {
    final serializer = SyncDataSerializer();
    await expectLater(
      serializer.upsertRecord(futureEntity, {'id': 'x'}),
      completes,
    );
  });

  test('deleteRecord does not throw on an unrecognized entity type', () async {
    final serializer = SyncDataSerializer();
    await expectLater(serializer.deleteRecord(futureEntity, 'x'), completes);
  });
}
