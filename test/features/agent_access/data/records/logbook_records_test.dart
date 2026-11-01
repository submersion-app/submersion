import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide CsvPreset;
import 'package:submersion/features/connections/data/repositories/connection_map_repository.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_weight_entry_repository.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_point_codec.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/safety/data/repositories/emergency_chamber_repository.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/repositories/csv_preset_repository.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    for (final (id, owner) in [
      ('a', kDiverA),
      ('b', kDiverB),
      ('none', null),
    ]) {
      await db
          .into(db.incidents)
          .insert(
            IncidentsCompanion.insert(
              id: 'inc-$id',
              occurredAt: t,
              category: 'equipment',
              severity: 'minor',
              narrative: 'Free flow',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.emergencyChambers)
          .insert(
            EmergencyChambersCompanion.insert(
              id: 'chamber-$id',
              name: 'Chamber',
              country: 'Belize',
              phone: '+501',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.savedQueries)
          .insert(
            SavedQueriesCompanion.insert(
              id: 'q-$id',
              subject: 'dives',
              name: 'Deep',
              queryJson: '{"version":1}',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.preDiveSessions)
          .insert(
            PreDiveSessionsCompanion.insert(
              id: 'pre-$id',
              templateName: 'Boat',
              startedAt: t,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.preDiveSessionItems)
          .insert(
            PreDiveSessionItemsCompanion.insert(
              id: 'pre-item-$id',
              sessionId: 'pre-$id',
              title: 'Tank',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final (id, owner) in [('a', kDiverA), ('b', kDiverB)]) {
      await db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              id: 'doc-$id',
              diverId: owner,
              type: 'insurance',
              createdAt: t,
              updatedAt: t,
              title: const Value('Policy'),
              referenceNumber: const Value('REF-1'),
              emergencyPhone: const Value('+1 800'),
            ),
          );
      await db
          .into(db.documentPages)
          .insert(
            DocumentPagesCompanion.insert(
              id: 'page-$id',
              documentId: 'doc-$id',
              pageIndex: 0,
              fileName: 'p.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 3,
              bytes: Uint8List.fromList([1, 2, 3]),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'pc-$id',
              name: 'Teric',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              bluetoothAddress: const Value('AA:BB'),
              lastDiveFingerprint: const Value('fp'),
            ),
          );
      await db
          .into(db.diverWeightEntries)
          .insert(
            DiverWeightEntriesCompanion.insert(
              id: 'kg-$id',
              diverId: owner,
              measuredAt: t,
              weightKg: 80,
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.navTracks)
          .insert(
            NavTracksCompanion.insert(
              id: 'nav-$id',
              source: 'seacraft_enc',
              startTime: t,
              endTime: t + 1000,
              pointCount: 0,
              points: encodeNavTrackPoints(const []),
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              maxDepth: const Value(20),
            ),
          );
    }
    await db
        .into(db.gpsTracks)
        .insert(
          GpsTracksCompanion.insert(
            id: 'gps',
            startTime: t,
            createdAt: t,
            updatedAt: t,
            name: const Value('Boat day'),
          ),
        );
    await db
        .into(db.divePlans)
        .insert(
          DivePlansCompanion.insert(
            id: 'plan',
            name: 'Reef plan',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> listed(String entity) async =>
      (await h.list(entity)).toSet();

  group('documents', () {
    test('a document lists page metadata and no bytes', () async {
      final doc = (await h.one('documents', 'doc-a', include: ['pages']))!;
      expect(doc['reference_number'], 'REF-1');
      expect(doc['emergency_phone'], '+1 800');
      final page = (doc['pages'] as List).cast<Map>().single;
      expect(page['file_name'], 'p.pdf');
      expect(page['size_bytes'], 3);
      expect(page.keys, isNot(contains('bytes')));
    });

    test('another profile\'s document is missing', () async {
      expect(await h.one('documents', 'doc-b'), isNull);
    });

    test('scope matches getAllForDiver', () async {
      final expected = {
        for (final x in await DocumentRepository().getAllForDiver(kDiverA))
          x.document.id,
      };
      expect(await listed('documents'), expected);
    });
  });

  group('dive computers', () {
    test(
      'a dive computer leaves out its Bluetooth address and fingerprint',
      () async {
        final doc = (await h.one('dive_computers', 'pc-a'))!;
        expect(doc['name'], 'Teric');
        expect(doc.keys, isNot(contains('bluetooth_address')));
        expect(doc.keys, isNot(contains('last_dive_fingerprint')));
      },
    );

    test('scope matches getAllComputers', () async {
      final expected = {
        for (final x in await DiveComputerRepository().getAllComputers(
          diverId: kDiverA,
        ))
          x.id,
      };
      expect(await listed('dive_computers'), expected);
    });
  });

  group('plans', () {
    test('a plan carries tanks and segments', () async {
      final doc = (await h.one('dive_plans', 'plan'))!;
      expect(doc['name'], 'Reef plan');
      expect(doc['tanks'], isEmpty);
      expect(doc['segments'], isEmpty);
      expect(doc['linked_dive_id'], isNull);
    });

    test(
      'ownerless plans read for every profile, as the app lists them',
      () async {
        expect(await h.one('dive_plans', 'plan', diverId: kDiverB), isNotNull);
        expect(await listed('dive_plans'), {'plan'});
      },
    );
  });

  group('rules', () {
    test('a rule carries its query and actions as JSON', () async {
      final id = await RuleRepository().create(
        diverId: kDiverA,
        subject: RuleSubject.dives,
        name: 'Tag deep',
        triggers: const {},
        condition: null,
        actions: const [],
      );
      final doc = (await h.one('rules', id))!;
      expect(doc['name'], 'Tag deep');
      expect(doc['subject'], 'dives');
      expect((doc['actions'] as Map)['actions'], isEmpty);
      expect(await h.one('rules', id, diverId: kDiverB), isNull);
    });
  });

  group('saved_queries', () {
    test('saved queries decode their JSON', () async {
      expect((await h.one('saved_queries', 'q-a'))!['query'], {'version': 1});
    });

    test(
      'stored JSON this build cannot parse stays readable as text',
      () async {
        await (db.update(db.savedQueries)..where((q) => q.id.equals('q-a')))
            .write(const SavedQueriesCompanion(queryJson: Value('not json')));
        expect((await h.one('saved_queries', 'q-a'))!['query'], 'not json');
      },
    );

    test('scope matches getAll', () async {
      final expected = {
        for (final x in await SavedQueryRepository().getAll(diverId: kDiverA))
          x.id,
      };
      expect(await listed('saved_queries'), expected);
    });
  });

  group('tracks', () {
    test('a track document reports points without a blob', () async {
      final doc = (await h.one('nav_tracks', 'nav-a'))!;
      expect(doc['point_count'], 0);
      expect(doc['max_depth_m'], 20.0);
      expect(doc.keys, isNot(contains('points')));
      expect(doc['start_time'], endsWith('Z'));
    });

    test('nav track points are paged and carry a wall clock', () async {
      await (db.update(db.navTracks)..where((n) => n.id.equals('nav-a'))).write(
        NavTracksCompanion(
          pointCount: const Value(2),
          points: Value(
            encodeNavTrackPoints(const [
              NavTrackPoint(timestamp: 0, north: 1, east: 2, depth: 3),
              NavTrackPoint(timestamp: 60, north: 4, east: 5, depth: 6),
            ]),
          ),
        ),
      );
      final doc = (await h.one(
        'nav_tracks',
        'nav-a',
        include: ['points'],
        profileLimit: 1,
      ))!;
      final points = doc['points'] as Map;
      expect(points['total'], 2);
      expect(points['limit'], 1);
      final sample = (points['samples'] as List).cast<Map>().single;
      expect(sample['sample_time'], '1970-01-01T00:00:00.000Z');
      expect(sample['north_m'], 1.0);
      expect(sample.keys, isNot(contains('time_s')));
    });

    test('GPS tracks read for every profile', () async {
      final doc = (await h.one(
        'gps_tracks',
        'gps',
        diverId: kDiverB,
        include: ['points'],
      ))!;
      expect(doc['name'], 'Boat day');
      expect((doc['points'] as Map)['total'], 0);
    });

    test('nav tracks stop at the profile', () async {
      expect(await h.one('nav_tracks', 'nav-b'), isNull);
    });

    test('scope matches getAll for nav tracks', () async {
      final expected = {
        for (final x in await NavTrackRepository().getAll(diverId: kDiverA))
          x.id,
      };
      expect(await listed('nav_tracks'), expected);
    });
  });

  group('logged records', () {
    test('incidents read for owner and ownerless', () async {
      final expected = {
        for (final x in await IncidentRepository().getIncidents(
          diverId: kDiverA,
        ))
          x.id,
      };
      expect(await listed('incidents'), expected);
      expect(expected, {'inc-a', 'inc-none'});
    });

    test('an incident keeps its wall clock', () async {
      final doc = (await h.one('incidents', 'inc-a'))!;
      expect(doc['occurred_time'], endsWith('Z'));
      expect(doc['narrative'], 'Free flow');
    });

    test('an emergency chamber reads', () async {
      final expected = {
        for (final x in await EmergencyChamberRepository().getUserChambers(
          diverId: kDiverA,
        ))
          x.id,
      };
      expect(await listed('emergency_chambers'), expected);
      expect(
        (await h.one('emergency_chambers', 'chamber-a'))!['phone'],
        '+501',
      );
    });

    test('pre-dive session items arrive as a block', () async {
      final doc = (await h.one(
        'pre_dive_sessions',
        'pre-a',
        include: ['items'],
      ))!;
      final items = doc['items'] as Map;
      expect((items['items'] as List).cast<Map>().single['title'], 'Tank');
      expect(items['sections'], isEmpty);
    });

    test('scope matches getAllSessions', () async {
      final expected = {
        for (final x in await PreDiveSessionRepository().getAllSessions(
          diverId: kDiverA,
        ))
          x.id,
      };
      expect(await listed('pre_dive_sessions'), expected);
    });

    test('scope matches getEntriesForDiver', () async {
      final expected = {
        for (final x in await DiverWeightEntryRepository().getEntriesForDiver(
          kDiverA,
        ))
          x.id,
      };
      expect(await listed('weight_entries'), expected);
      expect((await h.one('weight_entries', 'kg-a'))!['weight_kg'], 80.0);
    });
  });

  group('stored views', () {
    test('a smart album decodes its filter for every profile', () async {
      final album = await MediaSmartAlbumRepository().create(
        name: 'Reefs',
        filter: const MediaLibraryFilter(),
      );
      final doc = (await h.one('smart_albums', album.id, diverId: kDiverB))!;
      expect(doc['name'], 'Reefs');
      expect(doc['filter'], isA<Map>());
    });

    test('a connection map decodes its spec for its owner', () async {
      final map = await ConnectionMapRepository().create(
        diverId: kDiverA,
        name: 'Mine',
        spec: MapSpec.of(const {}, const {}),
      );
      expect(await listed('connection_maps'), {
        for (final x in await ConnectionMapRepository().getAll(kDiverA)) x.id,
      });
      final doc = (await h.one('connection_maps', map.id))!;
      expect(doc['spec'], isA<Map>());
      expect(await h.one('connection_maps', map.id, diverId: kDiverB), isNull);
    });

    test('a CSV preset reads for every profile', () async {
      await CsvPresetRepository().savePreset(
        const CsvPreset(id: 'csv', name: 'My CSV'),
      );
      final doc = (await h.one('csv_presets', 'csv', diverId: kDiverB))!;
      expect(doc['name'], 'My CSV');
      expect(doc['preset'], isA<Map>());
    });
  });
}
