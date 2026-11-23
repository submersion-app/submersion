import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/held_references.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_record_overlay.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Issue #4954: the sync apply's foreign key repair clears a link (or deletes
/// a NOT NULL child) whose parent is not on this device yet. When that parent
/// arrives from another peer, the change is undone, and until then this
/// device exports a held link as the value it held, so its next edit of the
/// row cannot clear the link on every other device.
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
    // performSync configures the process-wide clock for this test's device.
    SyncClock.instance.reset();
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

  Future<String?> setting(String key) async =>
      (await db
              .customSelect(
                'SELECT value FROM settings WHERE key = ?',
                variables: [Variable.withString(key)],
              )
              .getSingleOrNull())
          ?.read<String?>('value');

  Future<HeldReferences> held() async => HeldReferences.decode(
    links: await setting(heldLinksSettingsKey),
    orphans: await setting(heldOrphansSettingsKey),
  );

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

    test('goes out in this device\'s export as the value it held', () async {
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));

      expect((await item('item'))!['section_id'], isNull);
      expect((await exportedItem('item'))['sectionId'], 'gear');

      await apply(() => insertSection('gear'));

      expect((await exportedItem('item'))['sectionId'], 'gear');
    });

    test('goes out in a streamed base as the value it held', () async {
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));

      final base = await serializer.exportBaseToTempFile(
        deviceId: here,
        deletions: const [],
      );
      addTearDown(() async {
        final file = File(base.path);
        if (file.existsSync()) await file.delete();
      });
      final json =
          jsonDecode(await File(base.path).readAsString())
              as Map<String, dynamic>;
      final items =
          ((json['data'] as Map<String, dynamic>)['tripChecklistItems'] as List)
              .cast<Map<String, dynamic>>();

      final row = items.singleWhere((r) => r['id'] == 'item');
      expect(row['sectionId'], 'gear');
      expect(row['title'], 'Mask');
    });

    test('still comes back after a local edit of the row', () async {
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));
      await db.customStatement(
        "UPDATE trip_checklist_items SET is_done = 1, hlc = ? WHERE id = 'item'",
        [localClock],
      );

      final edited = await exportedItem('item');
      expect(edited['sectionId'], 'gear');
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
      expect((await exportedItem('item'))['sectionId'], isNull);
    });

    test('a hold this build can no longer read is let go, and the apply '
        'still commits', () async {
      // A link held under a column a later schema renamed.
      const stale = HeldLink(
        table: 'trip_checklist_items',
        key: {'id': 'item'},
        column: 'retired_section_id',
        parent: HeldParent(
          table: 'trip_checklist_sections',
          column: 'id',
          value: 'gear',
        ),
      );
      await insertItem('item', hlc: phoneClock);
      await db.customStatement(
        'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, 0)',
        [
          heldLinksSettingsKey,
          HeldReferences(links: {stale.id: stale}).encodeLinks(),
        ],
      );

      expect((await exportedItem('item'))['title'], 'Mask');
      await apply(() => insertSection('gear'));

      expect((await held()).isEmpty, isTrue);
    });
  });

  test('a deletion of another kind of row with the same id does not count '
      'as the parent\'s', () async {
    await db.customStatement(
      'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) '
      "VALUES ('tomb', 'dives', 'gear', 0)",
    );

    await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));
    expect((await held()).links, hasLength(1));

    await apply(() => insertSection('gear'));
    expect((await item('item'))!['section_id'], 'gear');
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

    test('put back by a single conflict write, it is repaired before the '
        'commit when it names another missing parent', () async {
      await insertSection('soon-gone');
      await apply(
        () => insertItem(
          'late-item',
          checklistId: 'late-list',
          sectionId: 'soon-gone',
          hlc: phoneClock,
        ),
      );
      expect((await held()).orphans, hasLength(1));
      // The section goes before the checklist arrives, with no tombstone.
      await db.customStatement(
        "DELETE FROM trip_checklist_sections WHERE id = 'soon-gone'",
      );

      await serializer.applyInDeferredFkTransaction(() async {
        await db.customStatement(
          'INSERT INTO trip_checklists (id, trip_id, name, created_at, '
          "updated_at) VALUES ('late-list', 'trip', 'Spares', 0, 0)",
        );
        await serializer.repairAfterRowWrite('tripChecklists');
      });

      final restored = (await item('late-item'))!;
      expect(restored['section_id'], isNull);
      expect((await held()).links, hasLength(1));
    });

    test(
      'with a composite key is not put back once a peer deleted it',
      () async {
        await db.customStatement(
          'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
          "VALUES ('dive', 0, 0, 0)",
        );
        await apply(
          () => db.customStatement(
            'INSERT INTO dive_equipment (dive_id, equipment_id) '
            "VALUES ('dive', 'late-reg')",
          ),
        );
        expect((await held()).orphans, hasLength(1));

        final recordId = syncRecordId('diveEquipment', {
          'diveId': 'dive',
          'equipmentId': 'late-reg',
        });
        await db.customStatement(
          'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) '
          "VALUES ('tomb', 'diveEquipment', ?, 0)",
          [recordId],
        );
        await apply(
          () => db.customStatement(
            'INSERT INTO equipment (id, name, type, created_at, updated_at) '
            "VALUES ('late-reg', 'Reg', 'regulator', 0, 0)",
          ),
        );

        final links = await db
            .customSelect("SELECT 1 FROM dive_equipment WHERE dive_id = 'dive'")
            .get();
        expect(links, isEmpty);
        expect((await held()).isEmpty, isTrue);
      },
    );

    test('stays held, with nothing half put back, when a row no longer '
        'fits', () async {
      await apply(
        () => db.customStatement(
          'INSERT INTO trip_checklist_sections (id, checklist_id, title, '
          "created_at, updated_at) VALUES ('late-gear', 'late-list', "
          "'Dive gear', 0, 0)",
        ),
      );
      await apply(
        () => db.customStatement(
          'INSERT INTO trip_checklists (id, trip_id, name, created_at, '
          "updated_at) VALUES ('late-list', 'late-trip', 'Spares', 0, 0)",
        ),
      );
      // Something else now holds the section's title.
      await db.customStatement(
        'CREATE UNIQUE INDEX test_section_title '
        'ON trip_checklist_sections (title)',
      );
      await insertSection('taken');
      await db.customStatement(
        "UPDATE trip_checklist_sections SET title = 'Dive gear' "
        "WHERE id = 'taken'",
      );

      await apply(
        () => db.customStatement(
          'INSERT INTO trips (id, name, start_date, end_date, created_at, '
          "updated_at) VALUES ('late-trip', 'Roatan', 0, 0, 0, 0)",
        ),
      );

      Future<bool> sectionBack() async =>
          (await db
              .customSelect(
                "SELECT 1 FROM trip_checklist_sections WHERE id = 'late-gear'",
              )
              .getSingleOrNull()) !=
          null;
      expect(await sectionBack(), isFalse);
      expect((await held()).orphans.keys, hasLength(1));

      await db.customStatement(
        "DELETE FROM trip_checklist_sections "
        "WHERE id = 'taken'",
      );
      await apply(() async {});

      expect(await sectionBack(), isTrue);
      expect((await held()).isEmpty, isTrue);
    });

    test('is let go when the library is replaced, so the replacement does '
        'not get it back', () async {
      // The wire rows of a checklist this device does not have yet.
      await db.customStatement(
        'INSERT INTO trip_checklists (id, trip_id, name, created_at, '
        "updated_at) VALUES ('late-list', 'trip', 'Spares', 0, 0)",
      );
      final trip = await serializer.fetchRecord('trips', 'trip');
      final list = await serializer.fetchRecord('tripChecklists', 'list');
      final lateList = await serializer.fetchRecord(
        'tripChecklists',
        'late-list',
      );
      await db.customStatement(
        "DELETE FROM trip_checklists WHERE id = 'late-list'",
      );
      await apply(
        () => db.customStatement(
          'INSERT INTO trip_checklist_sections (id, checklist_id, title, '
          "created_at, updated_at) VALUES ('late-gear', 'late-list', "
          "'Dive gear', 0, 0)",
        ),
      );
      expect((await held()).orphans, hasLength(1));

      // The replacement library has the checklist but not the section.
      final replacement = SyncData(
        trips: [trip!],
        tripChecklists: [list!, lateList!],
      );
      await SyncService(
        syncRepository: SyncRepository(),
        serializer: serializer,
        cloudProvider: FakeCloudStorageProvider(),
      ).debugAdoptInMemory([
        SyncPayload(
          version: syncFormatVersion,
          exportedAt: 9000,
          deviceId: 'replacer',
          checksum: sha256
              .convert(utf8.encode(jsonEncode(replacement.toJson())))
              .toString(),
          data: replacement,
          deletions: const {},
        ),
      ]);

      expect(
        await db
            .customSelect(
              "SELECT 1 FROM trip_checklist_sections WHERE id = 'late-gear'",
            )
            .getSingleOrNull(),
        isNull,
      );
      expect((await held()).isEmpty, isTrue);
    });

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

  group('through a real pull from peers', () {
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

    test('a newer copy that leaves the column out keeps it held until the '
        'section arrives', () async {
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
      await db.customStatement('DELETE FROM trip_checklist_items');
      await db.customStatement('DELETE FROM trip_checklist_sections');

      // The iPad, on a build that does not know the column, ticked the item:
      // its copy is newer and leaves sectionId out.
      final ipadItem = {
        for (final e in phoneItem!.entries)
          if (e.key != 'sectionId') e.key: e.value,
        'isDone': true,
        'hlc': const Hlc(2000, 0, 'ipad').toString(),
      };
      await seedPeer('peer-1-phone', SyncData(tripChecklistItems: [phoneItem]));
      await seedPeer('peer-2-ipad', SyncData(tripChecklistItems: [ipadItem]));
      await seedPeer(
        'peer-3-watch',
        SyncData(
          tripChecklistSections: [
            {...section!, 'hlc': const Hlc(900, 0, 'watch').toString()},
          ],
        ),
      );

      final result = await sync();
      expect(result.status, isNot(SyncResultStatus.error));

      final synced = (await item('item'))!;
      expect(synced['is_done'], 1, reason: 'the newer copy applies');
      expect(synced['section_id'], 'gear', reason: 'and the link comes back');
    });

    test('an edit made here reaches a device that has never had the item '
        'with its section, whatever order it pulls in', () async {
      // Here: the phone's item lands without its section, then the diver
      // ticks it.
      await insertSection('gear');
      await insertItem('item', sectionId: 'gear', hlc: phoneClock);
      final phoneItem = await serializer.fetchRecord(
        'tripChecklistItems',
        'item',
      );
      await db.customStatement('DELETE FROM trip_checklist_items');
      await db.customStatement('DELETE FROM trip_checklist_sections');
      await apply(() => insertItem('item', sectionId: 'gear', hlc: phoneClock));
      await db.customStatement(
        "UPDATE trip_checklist_items SET is_done = 1, hlc = ? WHERE id = 'item'",
        [localClock],
      );
      final ticked = await exportedItem('item');

      // A watch with the section but no item pulls this device's newer copy
      // before the phone's older one.
      DatabaseService.instance.resetForTesting();
      db = await setUpTestDatabase();
      serializer = SyncDataSerializer();
      await db.customStatement(
        'INSERT INTO sync_metadata (id, device_id, created_at, updated_at) '
        "VALUES ('global', 'watch', 0, 0)",
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

      await seedPeer('peer-1-$here', SyncData(tripChecklistItems: [ticked]));
      await seedPeer(
        'peer-2-phone',
        SyncData(tripChecklistItems: [phoneItem!]),
      );
      final result = await sync();
      expect(result.status, isNot(SyncResultStatus.error));

      final onWatch = (await item('item'))!;
      expect(onWatch['is_done'], 1);
      expect(onWatch['section_id'], 'gear');
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
      expect(ownSettings, isNot(contains(heldLinksSettingsKey)));

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
