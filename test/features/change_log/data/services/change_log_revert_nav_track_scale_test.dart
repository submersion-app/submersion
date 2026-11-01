import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Undoing a track's first scale save writes the logged old value through a
/// raw UPDATE, past the repository. The column is NOT NULL, so that value is
/// 1, a real value that reaches other devices, not a null that an upsert
/// would leave out (issue #3823).
void main() {
  late AppDatabase db;
  late NavTrackRepository tracks;
  final repository = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    tracks = NavTrackRepository();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  test('undoing a first scale save writes 1 and queues it for sync', () async {
    final id = await tracks.insertImportedRoute(
      points: const [
        NavTrackPoint(timestamp: 1700000000, north: 0, east: 0, depth: 2),
        NavTrackPoint(timestamp: 1700000010, north: 10, east: 5, depth: 5),
      ],
      source: NavTrackSource.suuntoRoute,
      sourceRef: 'suunto:test',
    );
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await SyncRepository().clearPendingRecords();

    await tracks.updateCorrection(
      id,
      const NavTrackCorrection(scaleFactor: 1.38),
    );
    await repository.settleAll();
    final event = (await logEvents(db)).last['id']! as int;

    final service = ChangeLogRevertService();
    await service.execute(await service.planField(event, 'scale_factor'));

    final row = await db
        .customSelect(
          'SELECT scale_factor FROM nav_tracks WHERE id = ?1',
          variables: [Variable(id)],
        )
        .getSingle();
    expect(row.read<double>('scale_factor'), 1.0);
    expect((await tracks.getById(id))!.scaleFactor, 1.0);
    expect({
      for (final r in await SyncRepository().getPendingRecords())
        '${r.entityType}:${r.recordId}',
    }, contains('navTracks:$id'));
  });
}
