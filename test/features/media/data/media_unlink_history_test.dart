import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// The media library's Unlink and the Gear tab's Remove are one labelled
/// entry in History each, and never touch a source file (issue #4527, media
/// library plan 1).
void main() {
  late AppDatabase db;
  late Directory files;
  late MediaRepository media;
  late MediaUnlinkService service;
  final changeLog = ChangeLogRepository();
  final epoch = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    files = Directory.systemTemp.createTempSync('unlink_history_');
    media = MediaRepository();
    service = MediaUnlinkService(
      repository: media,
      deleteMedia: (ids) => MediaRepository().deleteMultipleMedia(ids),
      gearPhotos: GearPhotoRepository(),
    );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
  });
  tearDown(() async {
    files.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  /// A media row whose source is a real file, so a test can see it stays.
  Future<String> addMedia(
    String id, {
    String? diveId,
    String? equipmentId,
  }) async {
    final path = p.join(files.path, '$id.jpg');
    File(path).writeAsBytesSync(const [1, 2, 3]);
    await media.createMedia(
      MediaItem(
        id: id,
        diveId: diveId,
        equipmentId: equipmentId,
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: path,
        localPath: path,
        takenAt: DateTime.utc(2026, 6, 1),
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
      ),
    );
    return path;
  }

  /// Setup's rows are not what is under test.
  Future<void> clearLog() async {
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  }

  Future<List<String?>> operationLabels() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.read<String?>('label')];
  }

  test('unlinking from the library is one entry in History', () async {
    final a = await addMedia('m1', diveId: 'd1');
    final b = await addMedia('m2');
    await clearLog();

    await service.unlinkFromLibrary(['m1', 'm2']);

    expect(await operationLabels(), [ChangeLogLabels.unlinkMedia]);
    expect(await media.getMediaById('m1'), isNull);
    expect(await media.getMediaById('m2'), isNull);
    expect(File(a).existsSync(), isTrue);
    expect(File(b).existsSync(), isTrue);
  });

  test('unlinking one item is still one labelled entry', () async {
    await addMedia('m1', diveId: 'd1');
    await clearLog();

    await service.unlinkFromLibrary(['m1']);

    expect(await operationLabels(), [ChangeLogLabels.unlinkMedia]);
  });

  /// Whether the History entry [label] is closed, read as the worker would
  /// start: the drain must not run inside the entry.
  Future<bool> entryClosed(String label) async {
    final row = await db
        .customSelect(
          'SELECT closed FROM change_log_operations WHERE label = ?',
          variables: [Variable.withString(label)],
        )
        .getSingleOrNull();
    return row?.read<bool>('closed') ?? false;
  }

  /// [service] with the delete split from the media store's drain, as the
  /// app wires it, recording whether the drain ran inside a History entry.
  MediaUnlinkService draining(List<String> events) => MediaUnlinkService(
    repository: media,
    deleteMedia: (ids) async => events.add('draining delete'),
    deleteMediaUndrained: (ids) async {
      events.add('delete');
      await MediaRepository().deleteMultipleMedia(ids);
    },
    deleteMediaHeld: (ids) async {
      events.add('held delete');
      await MediaRepository().deleteMultipleMedia(ids);
    },
    drainDeletes: () async {
      events.add(
        ChangeLogScope.currentOperationId == null
            ? 'drain outside the entry'
            : 'drain inside the entry',
      );
    },
    gearPhotos: GearPhotoRepository(),
  );

  test('the media store drains after the Unlink entry closes', () async {
    await addMedia('m1', diveId: 'd1');
    await clearLog();
    final events = <String>[];

    await draining(events).unlinkFromLibrary(['m1']);

    expect(events, ['delete', 'drain outside the entry']);
    expect(await entryClosed(ChangeLogLabels.unlinkMedia), isTrue);
    expect(await operationLabels(), [ChangeLogLabels.unlinkMedia]);
  });

  // The drain takes the whole upload queue; the diver must not wait for it
  // (code review on PR #4948).
  test('Unlink and Remove do not wait for the media store to drain', () async {
    await addMedia('m1', diveId: 'd1');
    final regId = (await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    )).id;
    await addMedia('g1', equipmentId: regId);
    final neverDrains = Completer<void>();
    final service = MediaUnlinkService(
      repository: media,
      deleteMedia: (ids) => MediaRepository().deleteMultipleMedia(ids),
      deleteMediaUndrained: (ids) => MediaRepository().deleteMultipleMedia(ids),
      drainDeletes: () => neverDrains.future,
      gearPhotos: GearPhotoRepository(),
    );

    await service.unlinkFromLibrary(['m1']).timeout(const Duration(seconds: 5));
    await service.removeGearPhotos(['g1']).timeout(const Duration(seconds: 5));

    expect(await media.getMediaById('m1'), isNull);
    expect(await media.getMediaById('g1'), isNull);
  });

  test('a drain that throws at once does not fail the unlink', () async {
    await addMedia('m1', diveId: 'd1');
    final service = MediaUnlinkService(
      repository: media,
      deleteMedia: (ids) => MediaRepository().deleteMultipleMedia(ids),
      drainDeletes: () => throw StateError('the provider has gone'),
    );

    await service.unlinkFromLibrary(['m1']);

    expect(await media.getMediaById('m1'), isNull);
  });

  test('unlinking a gear cover from the library clears the cover', () async {
    final regId = (await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    )).id;
    await addMedia('g1', equipmentId: regId);
    await GearPhotoRepository().setCover(regId, 'g1');
    await clearLog();

    await service.unlinkFromLibrary(['g1']);

    final item = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals(regId))).getSingle();
    expect(item.coverMediaId, isNull);
    expect(await operationLabels(), [ChangeLogLabels.unlinkMedia]);
  });

  test('unlinking nothing writes no entry', () async {
    await clearLog();

    await service.unlinkFromLibrary(const []);

    expect(await operationLabels(), isEmpty);
  });

  group('the Gear tab', () {
    late String regId;

    setUp(() async {
      regId = (await EquipmentRepository().createEquipment(
        const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
      )).id;
    });

    test('removing gear photos is one entry in History', () async {
      // A dive still holds the first, so it stays with its gear link
      // cleared; nothing holds the second, so it goes.
      final kept = await addMedia('g1', diveId: 'd1', equipmentId: regId);
      final gone = await addMedia('g2', equipmentId: regId);
      await GearPhotoRepository().setCover(regId, 'g2');
      await clearLog();

      final outcome = await service.removeGearPhotos(['g1', 'g2']);

      expect(await operationLabels(), [ChangeLogLabels.removeGearPhotos]);
      expect(outcome.keptLinked, 1);
      expect(outcome.deleted, 1);
      expect((await media.getMediaById('g1'))!.equipmentId, isNull);
      expect(await media.getMediaById('g2'), isNull);
      final cover = await (db.select(
        db.equipment,
      )..where((t) => t.id.equals(regId))).getSingle();
      expect(cover.coverMediaId, isNull);
      expect(File(kept).existsSync(), isTrue);
      expect(File(gone).existsSync(), isTrue);
    });

    test('the media store drains after the Remove entry closes', () async {
      await addMedia('g1', equipmentId: regId);
      await clearLog();
      final events = <String>[];

      await draining(events).removeGearPhotos(['g1']);

      // Held inside the transaction: a final delete's purge waits for a
      // running analysis, which writes outside it (code review on #4948).
      expect(events, ['held delete', 'drain outside the entry']);
      expect(await entryClosed(ChangeLogLabels.removeGearPhotos), isTrue);
    });

    test('a Remove that fails partway changes nothing', () async {
      // The kept row's link is cleared before the delete runs, so without
      // one transaction a failed delete would leave it half removed.
      await addMedia('g1', diveId: 'd1', equipmentId: regId);
      await addMedia('g2', equipmentId: regId);
      await GearPhotoRepository().setCover(regId, 'g2');
      final failing = MediaUnlinkService(
        repository: media,
        deleteMedia: (_) async => throw StateError('disk full'),
        deleteMediaUndrained: (_) async => throw StateError('disk full'),
        deleteMediaHeld: (_) async => throw StateError('disk full'),
        drainDeletes: () async {},
        gearPhotos: GearPhotoRepository(),
      );

      await expectLater(
        failing.removeGearPhotos(['g1', 'g2']),
        throwsStateError,
      );

      expect((await media.getMediaById('g1'))!.equipmentId, regId);
      expect(await media.getMediaById('g2'), isNotNull);
      final item = await (db.select(
        db.equipment,
      )..where((t) => t.id.equals(regId))).getSingle();
      expect(item.coverMediaId, 'g2');
    });

    test('the other unlink paths keep their History', () async {
      await addMedia('g1', equipmentId: regId);
      await clearLog();

      await service.unlinkFromEquipment(['g1']);

      expect(
        await operationLabels(),
        isNot(contains(ChangeLogLabels.removeGearPhotos)),
      );
    });
  });
}
