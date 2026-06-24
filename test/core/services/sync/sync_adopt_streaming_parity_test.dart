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

/// Proves the streaming replace-adopt (`_adoptApplyStreaming`, driven by
/// [SyncService.debugAdoptStreaming]) produces a byte-for-byte identical
/// database to the in-memory reference adopt ([SyncService.debugAdoptInMemory])
/// for the same inputs. This is the safety net for the #358 follow-up: it
/// guarantees that bounding adopt memory did not change replace semantics --
/// latest-export-wins union, deletion of local rows absent from the restored
/// library, and a BLOB column streamed through the base file.

/// Order-independent snapshot of a SyncData JSON map.
String _canonical(Map<String, dynamic> dataJson) {
  final out = <String, dynamic>{};
  for (final key in dataJson.keys.toList()..sort()) {
    final list = (dataJson[key] as List).cast<Map<String, dynamic>>();
    out[key] = [...list]
      ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  }
  return jsonEncode(out);
}

Future<String> _dump() async {
  final export = await SyncDataSerializer().exportData(
    deviceId: 'snapshot',
    deletions: const [],
  );
  return _canonical(export.data.toJson());
}

SyncService _svc() => SyncService(
  syncRepository: SyncRepository(),
  serializer: SyncDataSerializer(),
);

/// Deterministic exportedAt so ordering between the two paths is identical
/// (Dart's List.sort is not stable, so equal exportedAt would be ambiguous).
SyncPayload _withExportedAt(SyncPayload p, int at) =>
    SyncPayload.fromJson({...p.toJson(), 'exportedAt': at});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => tearDownTestDatabase());

  test('streaming adopt equals in-memory adopt, byte-for-byte', () async {
    // ---- Build the cloud library as two payloads (base older, changeset
    // newer) so latest-export-wins is exercised, including a BLOB row. ----
    final dives = DiveRepository();
    await dives.createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await dives.createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    final ser = SyncDataSerializer();
    await ser.upsertRecord('diveSites', _site('site-1', 'Old', 1000));
    await ser.upsertRecord('diveDataSources', {
      'id': 'ds-1',
      'diveId': 'd1',
      'isPrimary': true,
      'sourceFormat': 'shearwater',
      'importedAt': 1700000000000,
      'createdAt': 1700000000000,
      'rawFingerprint': Uint8List.fromList([0x01, 0x02, 0x03, 0xFE, 0xFF]),
    });
    final base = _withExportedAt(
      await ser.exportData(deviceId: 'peer', deletions: const []),
      1000,
    );

    // Newer changeset: rename site-1, add site-2.
    await ser.upsertRecord('diveSites', _site('site-1', 'NEW NAME', 2000));
    await ser.upsertRecord('diveSites', _site('site-2', 'Second', 2000));
    final changeset = _withExportedAt(
      await ser.exportData(deviceId: 'peer', deletions: const []),
      2000,
    );

    // Seed a DIFFERENT local library each run: 'd1' overlaps (must become the
    // cloud version) and 'd-stale' is absent from the cloud (must be deleted).
    Future<void> seedLocal() async {
      final d = DiveRepository();
      await d.createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 99),
      );
      await d.createDive(
        createTestDiveWithBottomTime(id: 'd-stale', diveNumber: 7),
      );
    }

    // ---- Phase A: in-memory reference (payloads passed unsorted on purpose).
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await seedLocal();
    await _svc().debugAdoptInMemory([changeset, base]);
    final reference = await _dump();

    // ---- Phase B: streaming. Base -> temp file; changeset stays in memory.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await seedLocal();
    final tmpDir = await Directory.systemTemp.createTemp('adopt_parity');
    final tmp = File('${tmpDir.path}/base.json');
    await tmp.writeAsBytes(
      utf8.encode(SyncDataSerializer().serializePayload(base)),
    );
    await _svc().debugAdoptStreaming([tmp.path], [base.exportedAt], [
      changeset,
    ]);
    final streamed = await _dump();
    await tmpDir.delete(recursive: true);

    expect(streamed, reference, reason: 'streaming adopt must equal in-memory');

    // Spot-checks: latest-wins applied, stale row gone.
    final decoded = jsonDecode(streamed) as Map<String, dynamic>;
    final siteNames = [
      for (final s in (decoded['diveSites'] as List)) (s as Map)['name'],
    ];
    expect(siteNames, containsAll(<String>['NEW NAME', 'Second']));
    expect(siteNames, isNot(contains('Old')));
    final diveIds = [
      for (final d in (decoded['dives'] as List)) (d as Map)['id'],
    ];
    expect(diveIds, containsAll(<String>['d1', 'd2']));
    expect(diveIds, isNot(contains('d-stale')));
  });

  test('batch boundary (>500 rows of one table) preserves parity', () async {
    final dives = DiveRepository();
    for (var i = 1; i <= 600; i++) {
      await dives.createDive(
        createTestDiveWithBottomTime(id: 'd$i', diveNumber: i),
      );
    }
    final base = _withExportedAt(
      await SyncDataSerializer().exportData(
        deviceId: 'peer',
        deletions: const [],
      ),
      1000,
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    await _svc().debugAdoptInMemory([base]);
    final reference = await _dump();

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final tmpDir = await Directory.systemTemp.createTemp('adopt_parity_big');
    final tmp = File('${tmpDir.path}/base.json');
    await tmp.writeAsBytes(
      utf8.encode(SyncDataSerializer().serializePayload(base)),
    );
    await _svc().debugAdoptStreaming([tmp.path], [base.exportedAt], const []);
    final streamed = await _dump();
    await tmpDir.delete(recursive: true);

    expect(streamed, reference);
  });
}

Map<String, dynamic> _site(String id, String name, int updatedAt) => {
  'id': id,
  'name': name,
  'description': '',
  'notes': '',
  'isShared': false,
  'createdAt': 1000,
  'updatedAt': updatedAt,
};
