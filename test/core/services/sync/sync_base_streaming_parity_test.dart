import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Proves the streaming base apply (_applyRemoteBaseFile) produces a
/// byte-for-byte identical database to the in-memory apply (_applyRemotePayload)
/// for the same payload. This is the safety net for issue #358: it guarantees
/// that bounding memory did not change merge behavior across a representative
/// subset of tables -- a parent, clockless children, a junction, a BLOB column,
/// updatedAt tables, and the deletions pass. (A separate structural test in
/// this file asserts entityHasUpdatedAt lists every SyncData entity; this parity
/// test does not seed all of them.)

/// Order-independent snapshot of a SyncData JSON map: each table's rows are
/// sorted by their JSON so a difference in cross-table insertion order between
/// the two apply paths does not register as a mismatch (only data differences
/// do).
String _canonical(Map<String, dynamic> dataJson) {
  final out = <String, dynamic>{};
  for (final key in dataJson.keys.toList()..sort()) {
    final list = (dataJson[key] as List).cast<Map<String, dynamic>>();
    final sorted = [...list]
      ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    out[key] = sorted;
  }
  return jsonEncode(out);
}

Future<String> _exportCanonical() async {
  final export = await SyncDataSerializer().exportData(
    deviceId: 'snapshot',
    deletions: const [],
  );
  return _canonical(export.data.toJson());
}

/// Seeds a library spanning parent, clockless-child, junction, BLOB-bearing,
/// and updatedAt-bearing tables, plus a tombstone, so parity covers every
/// merge path.
Future<void> _seedRichLibrary() async {
  final serializer = SyncDataSerializer();
  final dives = DiveRepository();

  await dives.createDive(createTestDiveWithBottomTime(id: 'd1', diveNumber: 1));
  await dives.createDive(createTestDiveWithBottomTime(id: 'd2', diveNumber: 2));

  await serializer.upsertRecord('divers', {
    'id': 'diver-1',
    'name': 'Test Diver',
    'medicalNotes': '',
    'notes': '',
    'isDefault': false,
    'createdAt': 1000,
    'updatedAt': 1000,
  });
  await serializer.upsertRecord('diveSites', {
    'id': 'site-1',
    'name': 'Test Site',
    'description': '',
    'notes': '',
    'isShared': false,
    'createdAt': 1000,
    'updatedAt': 1000,
  });
  await serializer.upsertRecord('species', {
    'id': 'species-1',
    'commonName': 'Test Fish',
    'category': 'fish',
    'isBuiltIn': false,
  });
  await serializer.upsertRecord('siteSpecies', {
    'id': 'ss-1',
    'siteId': 'site-1',
    'speciesId': 'species-1',
    'notes': 'seen on the wall',
    'createdAt': 1000,
  });
  await serializer.upsertRecord('diveCustomFields', {
    'id': 'cf-1',
    'diveId': 'd1',
    'fieldKey': 'visibility_m',
    'fieldValue': '20',
    'sortOrder': 0,
    'createdAt': 1000,
  });
  await serializer.upsertRecord('csvPresets', {
    'id': 'csv-1',
    'name': 'Suunto CSV',
    'presetJson': '{"columns":["date","depth"]}',
    'createdAt': 1000,
    'updatedAt': 1000,
  });
  await serializer.upsertRecord('viewConfigs', {
    'id': 'vc-1',
    'diverId': 'diver-1',
    'viewMode': 'table',
    'configJson': '{"columns":["date","depth"]}',
    'updatedAt': 1000,
  });
  await serializer.upsertRecord('fieldPresets', {
    'id': 'fp-1',
    'diverId': 'diver-1',
    'viewMode': 'table',
    'name': 'Tech Layout',
    'configJson': '{"fields":["max_depth","cns"]}',
    'isBuiltIn': false,
    'createdAt': 1000,
  });
  // BLOB-bearing row: exercises the base64 BLOB path through streaming.
  await serializer.upsertRecord('diveDataSources', {
    'id': 'ds-1',
    'diveId': 'd1',
    'isPrimary': true,
    'sourceFormat': 'shearwater',
    'importedAt': 1700000000000,
    'createdAt': 1700000000000,
    'rawFingerprint': Uint8List.fromList([0x01, 0x02, 0x03, 0xFE, 0xFF]),
  });

  // Safety review marker + finding: covers the in-memory mergeOrder entries
  // for both tables (a type missing from mergeOrder is dropped by the
  // in-memory apply and would make the byte-for-byte comparison fail).
  await serializer.upsertRecord('diveSafetyReviews', {
    'diveId': 'd1',
    'engineVersion': 1,
    'reviewedAt': 1700000000000,
  });
  await serializer.upsertRecord('diveSafetyFindings', {
    'id': 'sf-1',
    'diveId': 'd1',
    'ruleId': 'rapidAscent',
    'severity': 'caution',
    'startTimestamp': 100,
    'endTimestamp': 140,
    'value': 14.2,
    'engineVersion': 1,
    'createdAt': 1700000000000,
  });

  // A tombstone so the deletions pass is exercised (best-effort: deleteDive
  // logs a deletion if the repository does so).
  await dives.createDive(
    createTestDiveWithBottomTime(id: 'd3-doomed', diveNumber: 3),
  );
  await dives.deleteDive('d3-doomed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => tearDownTestDatabase());

  test('entityHasUpdatedAt covers exactly the SyncData entities', () {
    // The streaming apply only applies tables present in entityHasUpdatedAt, so
    // a SyncData entity missing from the map would be silently dropped on base
    // import. This locks the map to the entity set.
    expect(
      SyncService.entityHasUpdatedAt.keys.toSet(),
      const SyncData().toJson().keys.toSet(),
    );
  });

  test('streaming base apply matches in-memory apply byte-for-byte', () async {
    await _seedRichLibrary();
    final payload = await SyncDataSerializer().exportData(
      deviceId: 'peer',
      deletions: await SyncRepository().getAllDeletions(),
    );

    // Phase 1: in-memory apply into a fresh DB.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final counts1 = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    ).debugApplyPayload(payload);
    final dump1 = await _exportCanonical();

    // Phase 2: streaming file apply into another fresh DB.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final tmpDir = await Directory.systemTemp.createTemp('parity');
    final tmp = File('${tmpDir.path}/base.json');
    await tmp.writeAsBytes(
      utf8.encode(SyncDataSerializer().serializePayload(payload)),
    );
    final counts2 = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    ).debugApplyBaseFile(tmp.path);
    final dump2 = await _exportCanonical();
    await tmpDir.delete(recursive: true);

    expect(dump2, dump1, reason: 'streaming DB must equal in-memory DB');
    expect(counts2.recordsApplied, counts1.recordsApplied);
    expect(counts2.conflictsFound, counts1.conflictsFound);
    expect(counts2.recordsFailed, counts1.recordsFailed);
    expect(counts2.recordsFailed, 0, reason: 'no rows should fail to apply');
  });

  test(
    'batch boundary (>500 rows of one table) does not change the result',
    () async {
      final dives = DiveRepository();
      for (var i = 1; i <= 600; i++) {
        await dives.createDive(
          createTestDiveWithBottomTime(id: 'd$i', diveNumber: i),
        );
      }
      final payload = await SyncDataSerializer().exportData(
        deviceId: 'peer',
        deletions: await SyncRepository().getAllDeletions(),
      );

      await tearDownTestDatabase();
      await setUpTestDatabase();
      await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
      ).debugApplyPayload(payload);
      final dumpA = await _exportCanonical();

      await tearDownTestDatabase();
      await setUpTestDatabase();
      final tmpDir = await Directory.systemTemp.createTemp('parity_big');
      final tmp = File('${tmpDir.path}/base.json');
      await tmp.writeAsBytes(
        utf8.encode(SyncDataSerializer().serializePayload(payload)),
      );
      await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
      ).debugApplyBaseFile(tmp.path);
      final dumpB = await _exportCanonical();
      await tmpDir.delete(recursive: true);

      expect(dumpB, dumpA);
    },
  );

  test(
    'a worker-spawn failure falls back to inline and still applies',
    () async {
      await _seedRichLibrary();
      final payload = await SyncDataSerializer().exportData(
        deviceId: 'peer',
        deletions: await SyncRepository().getAllDeletions(),
      );

      // In-memory baseline.
      await tearDownTestDatabase();
      await setUpTestDatabase();
      await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
      ).debugApplyPayload(payload);
      final dumpInMemory = await _exportCanonical();

      // Worker spawn forced to fail -> must fall back to the inline file apply.
      await tearDownTestDatabase();
      await setUpTestDatabase();
      final tmpDir = await Directory.systemTemp.createTemp('parity_fallback');
      final tmp = File('${tmpDir.path}/base.json');
      await tmp.writeAsBytes(
        utf8.encode(SyncDataSerializer().serializePayload(payload)),
      );
      final svc = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
      )..baseParseClientSpawn = (_) async => throw StateError('forced failure');
      final counts = await svc.debugApplyBaseFile(tmp.path);
      final dumpFallback = await _exportCanonical();
      await tmpDir.delete(recursive: true);

      expect(dumpFallback, dumpInMemory, reason: 'inline fallback must match');
      expect(counts.recordsFailed, 0);
    },
  );
}
