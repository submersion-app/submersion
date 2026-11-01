import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/query_roots.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

/// Rows that exist only as a relation on a parent: they arrive as a block.
const _linkTables = {
  'course_requirement_dives',
  'dive_buddies',
  'dive_buddy_roles',
  'dive_courses',
  'dive_dive_types',
  'dive_diver_roles',
  'dive_equipment',
  'dive_tags',
  'document_tags',
  'equipment_tags',
  'media_people',
  'media_species',
  'media_tags',
  'site_shares',
  'site_site_types',
  'site_species',
  'site_tags',
  'trip_equipment',
  'trip_shares',
};

/// Rows a parent's document carries inside it.
const _foldedTables = {
  'checklist_template_items',
  'checklist_template_sections',
  'cylinder_config_items',
  'dive_data_sources',
  'dive_plan_equipment',
  'dive_plan_mission_legs',
  'dive_plan_mission_members',
  'dive_plan_missions',
  'dive_plan_segments',
  'dive_plan_tanks',
  'document_pages',
  'equipment_attributes',
  'equipment_set_geofences',
  'equipment_set_items',
  'pre_dive_checklist_template_items',
  'pre_dive_checklist_template_sections',
  'pre_dive_session_items',
  'pre_dive_session_sections',
  'weight_preset_entries',
};

/// Tracked tables an agent has no reason to read, each for a stated reason.
const _unexposedTables = {
  // A host's own connection details, device-local by design.
  'dive_computer_connections',
  // A history the app writes; a diver does not edit it.
  'equipment_ownership_events',
  // Layout presets for the app's own lists.
  'field_presets',
  // Bookkeeping for files already imported.
  'imported_files',
  // Which insights a diver dismissed: screen state.
  'insight_observation_dismissals',
  // Personal notes on a shared library site, keyed by a device-synced id.
  'library_site_notes',
  // Connection configuration, beside the credentials.
  'media_stores',
  'media_subscriptions',
  // The device key-value store.
  'settings',
  // What a profile hid from itself; visibility already honours it.
  'site_hides',
  'trip_hides',
};

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
  });
  tearDown(tearDownTestDatabase);

  test('every tracked table is covered, linked, folded or unexposed', () {
    final covered = {for (final e in h.catalog.all) e.table};
    final decided = {
      ...covered,
      ..._linkTables,
      ..._foldedTables,
      ..._unexposedTables,
    };
    final undecided = [
      for (final e in changeLogTables.entries)
        if (e.value == ChangeLogClass.tracked && !decided.contains(e.key))
          e.key,
    ];
    expect(undecided, isEmpty);
  });

  test('no table is claimed twice', () {
    final lists = [
      {for (final e in h.catalog.all) e.table},
      _linkTables,
      _foldedTables,
      _unexposedTables,
    ];
    for (var i = 0; i < lists.length; i++) {
      for (var j = i + 1; j < lists.length; j++) {
        expect(lists[i].intersection(lists[j]), isEmpty);
      }
    }
  });

  test('every entity name is unique', () {
    final names = [for (final e in h.catalog.all) e.name];
    expect(names.toSet(), hasLength(names.length));
  });

  test('every query root is an entity', () {
    final names = {for (final e in h.catalog.all) e.name};
    for (final root in kQueryRoots) {
      expect(names, contains(root.name));
    }
  });

  test('every entity\'s table exists', () async {
    final tables = {
      for (final r
          in await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table'",
              )
              .get())
        r.read<String>('name'),
    };
    for (final entry in h.catalog.all) {
      expect(tables, contains(entry.table), reason: entry.name);
    }
  });

  test('every entity\'s parent column exists on its table', () async {
    for (final entry in h.catalog.all) {
      final column = entry.parentColumn;
      if (column == null) continue;
      final columns = await db
          .customSelect("SELECT name FROM pragma_table_info('${entry.table}')")
          .get();
      expect(
        columns.map((c) => c.read<String>('name')),
        contains(column),
        reason: entry.name,
      );
    }
  });

  test('every entity\'s rule and order are valid SQL', () async {
    final reader = RecordReader(db);
    for (final entry in h.catalog.all) {
      await reader.visibleIds(entry, const ['nothing'], kDiverA);
      await reader.page(entry, kDiverA, limit: 1, offset: 0);
    }
  });

  test('every entity is exercised by a family test', () {
    final directory = Directory(
      p.join('test', 'features', 'agent_access', 'data', 'records'),
    );
    final text = [
      for (final f in directory.listSync().whereType<File>())
        if (f.path.endsWith('_records_test.dart')) f.readAsStringSync(),
    ].join();
    for (final entry in h.catalog.all) {
      expect(text, contains("'${entry.name}'"), reason: entry.name);
    }
  });

  test('a repeat read writes nothing', () async {
    final ticks = <Object>[];
    final sub = db.tableUpdates().listen(ticks.add);
    final reader = RecordReader(db);
    for (final entry in h.catalog.all) {
      await reader.page(entry, kDiverA, limit: 1, offset: 0);
      await entry.read(const [
        'nothing',
      ], RecordLoad(include: entry.blocks, diverId: kDiverA));
    }
    await pumpEventQueue();
    await sub.cancel();
    expect(ticks, isEmpty);
  });

  test('no document in the catalogue carries bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    await (db.update(db.divers)..where((d) => d.id.equals(kDiverA))).write(
      DiversCompanion(photo: Value(bytes)),
    );
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'bud',
            name: 'Bud',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            photo: Value(bytes),
          ),
        );
    await db
        .into(db.certifications)
        .insert(
          CertificationsCompanion.insert(
            id: 'cert',
            name: 'OW',
            agency: 'padi',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            photoFront: Value(bytes),
            photoBack: Value(bytes),
          ),
        );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'sig',
            filePath: 'sig.png',
            takenAt: const Value(t),
            createdAt: t,
            updatedAt: t,
            imageData: Value(bytes),
          ),
        );
    await db
        .into(db.documents)
        .insert(
          DocumentsCompanion.insert(
            id: 'doc',
            diverId: kDiverA,
            type: 'insurance',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.documentPages)
        .insert(
          DocumentPagesCompanion.insert(
            id: 'page',
            documentId: 'doc',
            pageIndex: 0,
            fileName: 'p.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 3,
            bytes: bytes,
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final (entity, id) in [
      ('divers', kDiverA),
      ('buddies', 'bud'),
      ('certifications', 'cert'),
      ('media', 'sig'),
      ('documents', 'doc'),
    ]) {
      final entry = h.catalog.named(entity);
      // The harness walks every value for bytes.
      expect(
        await h.one(entity, id, include: entry.blocks.toList()),
        isNotNull,
        reason: entity,
      );
    }
  });
}
