import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/held_references.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Issue #4954: the sync apply's foreign key repair clears a link (or deletes
/// a NOT NULL child) whose parent is not on this device yet. When that parent
/// arrives from another peer, the change is undone, and until then this
/// device's exports leave a cleared column out, so its next edit of the row
/// cannot clear the link on every other device.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  const here = 'mac';
  final phoneClock = const Hlc(1000, 0, 'phone').toString();
  final laterPhoneClock = const Hlc(5000, 0, 'phone').toString();
  final localClock = const Hlc(6000, 0, here).toString();

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement(
      'INSERT INTO sync_metadata (id, device_id, created_at, updated_at) '
      "VALUES ('global', ?, 0, 0)",
      [here],
    );
    await db.customStatement(
      'INSERT INTO trips (id, name, start_date, end_date, created_at, '
      "updated_at) VALUES ('trip', 'Bonaire', 0, 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO trip_checklists (id, trip_id, name, created_at, '
      "updated_at) VALUES ('list', 'trip', 'Packing', 0, 0)",
    );
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  /// One peer's apply: [body] writes its rows, then the repair runs, in one
  /// deferred-FK transaction, as every sync apply path does.
  Future<void> apply(Future<void> Function() body) =>
      serializer.applyInDeferredFkTransaction(() async {
        await body();
        await serializer.repairDanglingForeignKeys();
      });

  Future<void> insertSection(String id, {String checklistId = 'list'}) =>
      db.customStatement(
        'INSERT INTO trip_checklist_sections (id, checklist_id, title, '
        "created_at, updated_at) VALUES (?, ?, 'Dive gear', 0, 0)",
        [id, checklistId],
      );

  Future<void> insertItem(
    String id, {
    String? sectionId,
    String checklistId = 'list',
    String? hlc,
  }) => db.customStatement(
    'INSERT INTO trip_checklist_items (id, checklist_id, title, section_id, '
    "created_at, updated_at, hlc) VALUES (?, ?, 'Mask', ?, 0, 0, ?)",
    [id, checklistId, sectionId, hlc],
  );

  Future<Map<String, Object?>?> item(String id) async =>
      (await db
              .customSelect(
                'SELECT section_id, hlc, is_done FROM trip_checklist_items '
                'WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingleOrNull())
          ?.data;

  Future<int> pendingCount() async =>
      (await db
              .customSelect(
                "SELECT COUNT(*) AS n FROM sync_records WHERE sync_status = 'pending'",
              )
              .getSingle())
          .read<int>('n');

  Future<HeldReferences> held() async {
    final row = await db
        .customSelect(
          'SELECT value FROM settings WHERE key = ?',
          variables: [Variable.withString(heldReferencesSettingsKey)],
        )
        .getSingleOrNull();
    return HeldReferences.decode(row?.read<String?>('value'));
  }

  Future<Map<String, dynamic>> exportedItem(String id) async {
    final payload = await serializer.exportData(
      deviceId: here,
      deletions: const [],
    );
    return payload.data.tripChecklistItems.singleWhere((r) => r['id'] == id);
  }

  group('a nullable link to a parent that has not arrived', () {
    test('comes back when the parent arrives, with the row clock untouched '
        'and nothing marked pending', () async {
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));

      expect((await item('item'))!['section_id'], isNull);
      expect((await held()).links, hasLength(1));

      await apply(() => insertSection('gear'));

      final restored = (await item('item'))!;
      expect(restored['section_id'], 'gear');
      expect(restored['hlc'], phoneClock);
      expect(await pendingCount(), 0);
      expect((await held()).isEmpty, isTrue);
    });

    test('is left out of this device\'s export while it is held', () async {
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));

      expect((await exportedItem('item')).containsKey('sectionId'), isFalse);

      await apply(() => insertSection('gear'));

      expect((await exportedItem('item'))['sectionId'], 'gear');
    });

    test('still comes back after a local edit of the row', () async {
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));
      await db.customStatement(
        "UPDATE trip_checklist_items SET is_done = 1, hlc = ? WHERE id = 'item'",
        [localClock],
      );

      final edited = await exportedItem('item');
      expect(edited.containsKey('sectionId'), isFalse);
      expect(edited['isDone'], isTrue);

      await apply(() => insertSection('gear'));

      expect((await item('item'))!['section_id'], 'gear');
    });

    test('is let go when a newer peer copy clears the column', () async {
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));
      await apply(() async {
        await serializer.noteIncomingRows('tripChecklistItems', [
          {'id': 'item', 'sectionId': null, 'hlc': laterPhoneClock},
        ]);
        await db.customStatement(
          "UPDATE trip_checklist_items SET hlc = ? WHERE id = 'item'",
          [laterPhoneClock],
        );
      });

      expect((await held()).isEmpty, isTrue);

      await apply(() => insertSection('gear'));

      expect((await item('item'))!['section_id'], isNull);
    });

    test('stays held when a newer peer copy leaves the column out', () async {
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));
      await apply(() async {
        await serializer.noteIncomingRows('tripChecklistItems', [
          {'id': 'item', 'isDone': true, 'hlc': laterPhoneClock},
        ]);
        await db.customStatement(
          "UPDATE trip_checklist_items SET is_done = 1, hlc = ? "
          "WHERE id = 'item'",
          [laterPhoneClock],
        );
      });

      expect((await held()).links, hasLength(1));

      await apply(() => insertSection('gear'));

      expect((await item('item'))!['section_id'], 'gear');
    });

    test('is let go when a local write sets the column', () async {
      await insertSection('other');
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));
      await db.customStatement(
        "UPDATE trip_checklist_items SET section_id = 'other', hlc = ? "
        "WHERE id = 'item'",
        [localClock],
      );

      expect((await exportedItem('item'))['sectionId'], 'other');

      await apply(() => insertSection('gear'));

      expect((await item('item'))!['section_id'], 'other');
      expect((await held()).isEmpty, isTrue);
    });

    test('is not held when the parent was deleted', () async {
      await db.customStatement(
        'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) '
        "VALUES ('tomb', 'tripChecklistSections', 'gear', 0)",
      );

      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));

      expect((await item('item'))!['section_id'], isNull);
      expect((await held()).isEmpty, isTrue);
      expect((await exportedItem('item')).containsKey('sectionId'), isTrue);
    });
  });

  group('a NOT NULL child of a parent that has not arrived', () {
    test(
      'comes back with everything beneath it when the parent arrives',
      () async {
        // A checklist made on another device, with a section and an item in
        // it, lands before its trip does.
        await apply(() async {
          await db.customStatement(
            'INSERT INTO trip_checklist_sections (id, checklist_id, title, '
            'created_at, updated_at, hlc) '
            "VALUES ('late-gear', 'late-list', 'Dive gear', 0, 0, ?)",
            [phoneClock],
          );
          await insertItem(
            'late-item',
            checklistId: 'late-list',
            sectionId: 'late-gear',
            hlc: phoneClock,
          );
          await db.customStatement(
            'INSERT INTO trip_checklists (id, trip_id, name, created_at, '
            "updated_at, hlc) VALUES ('late-list', 'late-trip', 'Spares', "
            '0, 0, ?)',
            [phoneClock],
          );
        });

        expect(await item('late-item'), isNull);
        expect((await held()).orphans, isNotEmpty);

        await apply(
          () => db.customStatement(
            'INSERT INTO trips (id, name, start_date, end_date, created_at, '
            "updated_at) VALUES ('late-trip', 'Roatan', 0, 0, 0, 0)",
          ),
        );

        final list = await db
            .customSelect(
              "SELECT name, hlc FROM trip_checklists WHERE id = 'late-list'",
            )
            .getSingleOrNull();
        expect(list?.data, {'name': 'Spares', 'hlc': phoneClock});
        expect(
          await db
              .customSelect(
                "SELECT 1 FROM trip_checklist_sections WHERE id = 'late-gear'",
              )
              .getSingleOrNull(),
          isNotNull,
        );
        final restoredItem = (await item('late-item'))!;
        expect(restoredItem['section_id'], 'late-gear');
        expect(restoredItem['hlc'], phoneClock);
        expect(await pendingCount(), 0);
        expect((await held()).isEmpty, isTrue);
      },
    );

    test('is not put back over a copy that arrived since', () async {
      await apply(
        () => db.customStatement(
          'INSERT INTO trip_checklist_sections (id, checklist_id, title, '
          "created_at, updated_at) VALUES ('late-gear', 'late-list', 'Old', "
          '0, 0)',
        ),
      );
      await apply(() async {
        await db.customStatement(
          'INSERT INTO trip_checklists (id, trip_id, name, created_at, '
          "updated_at) VALUES ('late-list', 'trip', 'Spares', 0, 0)",
        );
        await db.customStatement(
          'INSERT INTO trip_checklist_sections (id, checklist_id, title, '
          "created_at, updated_at) VALUES ('late-gear', 'late-list', 'New', "
          '0, 0)',
        );
      });

      final title = await db
          .customSelect(
            "SELECT title FROM trip_checklist_sections WHERE id = 'late-gear'",
          )
          .getSingle();
      expect(title.read<String>('title'), 'New');
      expect((await held()).isEmpty, isTrue);
    });
  });

  group('through a real pull from two peers', () {
    late FakeCloudStorageProvider cloud;

    setUp(() => cloud = FakeCloudStorageProvider());

    Future<void> seedPeer(String peerId, SyncData data) =>
        seedPeerBaseFromPayload(
          cloud,
          peerId,
          SyncPayload(
            version: syncFormatVersion,
            exportedAt: 9000,
            deviceId: peerId,
            checksum: sha256
                .convert(utf8.encode(jsonEncode(data.toJson())))
                .toString(),
            data: data,
            deletions: const {},
          ),
        );

    Future<SyncResult> sync() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();

    test('an item from the phone keeps the section that comes from the iPad '
        'in the same sync', () async {
      // The wire rows, read from rows written here and then removed.
      await insertSection('gear');
      await insertItem('item', sectionId: 'gear', hlc: phoneClock);
      final section = await serializer.fetchRecord(
        'tripChecklistSections',
        'gear',
      );
      final phoneItem = await serializer.fetchRecord(
        'tripChecklistItems',
        'item',
      );
      await db.customStatement("DELETE FROM trip_checklist_items");
      await db.customStatement("DELETE FROM trip_checklist_sections");

      // Seeded in listing order: the phone's payload applies first.
      await seedPeer(
        'peer-1-phone',
        SyncData(tripChecklistItems: [phoneItem!]),
      );
      await seedPeer(
        'peer-2-ipad',
        SyncData(
          tripChecklistSections: [
            {...section!, 'hlc': const Hlc(900, 0, 'ipad').toString()},
          ],
        ),
      );

      final result = await sync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect((await item('item'))!['section_id'], 'gear');
      expect((await held()).isEmpty, isTrue);
    });

    test('an edit made here before the section arrives leaves the section '
        'in place on a device that has it', () async {
      // Here: the phone's item lands without its section, then the diver
      // ticks it.
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));
      await db.customStatement(
        "UPDATE trip_checklist_items SET is_done = 1, hlc = ? WHERE id = 'item'",
        [localClock],
      );
      final ticked = await exportedItem('item');
      final ownSettings = (await serializer.exportData(
        deviceId: here,
        deletions: const [],
      )).data.settings.map((s) => s['key']);
      expect(ownSettings, isNot(contains(heldReferencesSettingsKey)));

      // The phone, which has the item in its section, applies that edit.
      DatabaseService.instance.resetForTesting();
      db = await setUpTestDatabase();
      serializer = SyncDataSerializer();
      await db.customStatement(
        'INSERT INTO sync_metadata (id, device_id, created_at, updated_at) '
        "VALUES ('global', 'phone', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO trips (id, name, start_date, end_date, created_at, '
        "updated_at) VALUES ('trip', 'Bonaire', 0, 0, 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO trip_checklists (id, trip_id, name, created_at, '
        "updated_at) VALUES ('list', 'trip', 'Packing', 0, 0)",
      );
      await insertSection('gear');
      await insertItem('item', sectionId: 'gear', hlc: phoneClock);

      await seedPeer(here, SyncData(tripChecklistItems: [ticked]));
      final result = await sync();
      expect(result.status, isNot(SyncResultStatus.error));

      final onPhone = (await item('item'))!;
      expect(onPhone['is_done'], 1, reason: 'the edit applies');
      expect(onPhone['section_id'], 'gear', reason: 'the link stays');
    });
  });
}
