import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/change_log/data/services/change_log_settler.dart';

import '../../../helpers/test_database.dart';
import '../../database/change_log/change_log_support.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    SyncClock.instance.reset();
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await insertDiver(db, 'diver');
    await insertDive(db, 'dive', diverId: 'diver', notes: 'Calm');
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  SyncService service() =>
      SyncService(syncRepository: SyncRepository(), serializer: serializer);

  /// [notes] on the local dive as a peer would publish it, with a newer
  /// clock, or the row unchanged when [notes] is null.
  Future<SyncPayload> peerPayload({String? notes}) async {
    final dive = (await serializer.fetchRecord('dives', 'dive'))!;
    final later = DateTime.now().millisecondsSinceEpoch + 60000;
    final data = SyncData(
      dives: [
        {
          ...dive,
          'notes': ?notes,
          'updatedAt': later,
          'hlc': Hlc(later, 0, 'peer-dev').toString(),
        },
      ],
    );
    return SyncPayload(
      version: syncFormatVersion,
      exportedAt: 9000,
      deviceId: 'peer-dev',
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: const {},
    );
  }

  test('a changeset holds the long lease through its transaction', () async {
    await probeLease(db);

    await service().debugApplyPayload(await peerPayload(notes: 'Rough'));

    expect(await probedLease(db), greaterThan(kChangeLogLease));
  });

  Future<String> baseFile(SyncPayload payload) async {
    final dir = await Directory.systemTemp.createTemp('change_log_sync');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));
    return file.path;
  }

  Future<List<ChangeLogOperationRow>> settledOperations() async {
    await ChangeLogSettler(db).settle();
    return db.select(db.changeLogOperations).get();
  }

  test("a pulled edit logs under sync with the peer's device id", () async {
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await service().debugApplyPayload(
      await peerPayload(notes: 'From the peer'),
      lastSync: DateTime(2020),
    );

    final operation = (await settledOperations()).single;
    expect(operation.source, ChangeLogSource.sync.name);
    expect(operation.deviceId, 'peer-dev');
    final fields = await logFields(
      db,
      (await logEvents(db)).single['id']! as int,
    );
    expect(fields['notes'], ('Calm', 'From the peer'));
  });

  test('a pull that changes nothing leaves no operation', () async {
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await service().debugApplyPayload(
      await peerPayload(),
      lastSync: DateTime(2020),
    );

    expect(await settledOperations(), isEmpty);
  });

  group('a base file', () {
    test('first adoption logs one summary and no rows', () async {
      final path = await baseFile(await peerPayload(notes: 'Adopted'));
      await db.customStatement("DELETE FROM dives WHERE id = 'dive'");
      await ChangeLogSettler(db).settle();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');

      await service().debugApplyBaseFile(path);

      expect(await logEvents(db), isEmpty);
      final operation = (await settledOperations()).single;
      expect(operation.label, ChangeLogLabels.libraryAdopted);
      expect(operation.summaryCount, greaterThan(0));
    });

    test('a device with its own library logs a first base as sync', () async {
      final path = await baseFile(await peerPayload(notes: 'Merged'));
      await ChangeLogSettler(db).settle();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');

      await service().debugApplyBaseFile(path);

      final operation = (await settledOperations()).single;
      expect(operation.source, ChangeLogSource.sync.name);
      expect(operation.summaryCount, isNull);
    });

    test('a lapped base logs its real differences as sync', () async {
      final path = await baseFile(await peerPayload(notes: 'Lapped'));
      await ChangeLogSettler(db).settle();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');

      await service().debugApplyBaseFile(
        path,
        lastSync: DateTime(2020),
        peerDeviceId: 'peer-dev',
      );

      final operation = (await settledOperations()).single;
      expect(operation.source, ChangeLogSource.sync.name);
      expect(operation.deviceId, 'peer-dev');
      final event = (await logEvents(db)).single;
      expect((await logFields(db, event['id']! as int))['notes'], (
        'Calm',
        'Lapped',
      ));
    });

    test('a lapped base that changes nothing logs nothing', () async {
      final path = await baseFile(await peerPayload());
      await ChangeLogSettler(db).settle();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');

      await service().debugApplyBaseFile(path, lastSync: DateTime(2020));

      expect(await settledOperations(), isEmpty);
    });
  });
}
