import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Order-independent snapshot: each table's rows sorted by their JSON so an
/// array-order difference (id order in the streamed base vs. list order in
/// exportChangeset) is not a mismatch -- only data differences are.
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

Future<void> _seedRich() async {
  final serializer = SyncDataSerializer();
  final dives = DiveRepository();
  await dives.createDive(createTestDiveWithBottomTime(id: 'd1', diveNumber: 1));
  await dives.createDive(createTestDiveWithBottomTime(id: 'd2', diveNumber: 2));
  await serializer.upsertRecord('diveSites', {
    'id': 'site-1',
    'name': 'Test Site',
    'description': '',
    'notes': '',
    'isShared': false,
    'createdAt': 1000,
    'updatedAt': 1000,
  });
  // BLOB-bearing table (diveDataSources uses the base64 serializer).
  await serializer.upsertRecord('diveDataSources', {
    'id': 'ds-1',
    'diveId': 'd1',
    'isPrimary': true,
    'sourceFormat': 'shearwater',
    'importedAt': 1700000000000,
    'createdAt': 1700000000000,
    'rawFingerprint': Uint8List.fromList([0x01, 0x02, 0x03, 0xFE, 0xFF]),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // exportBaseToTempFile now defaults to path_provider's getTemporaryDirectory
  // (app-container temp, not /tmp -- issue #509). These calls do not inject a
  // tempDir, so mock the channel to a real writable dir.
  late Directory fakeAppTemp;
  setUpAll(() async {
    fakeAppTemp = await Directory.systemTemp.createTemp('parity_app_temp_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              call.method == 'getTemporaryDirectory' ? fakeAppTemp.path : null,
        );
  });
  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (fakeAppTemp.existsSync()) await fakeAppTemp.delete(recursive: true);
  });

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => tearDownTestDatabase());

  test('_baseTables lists exactly the SyncData entities in order', () {
    // A missing/extra/misordered entity would silently drop or misplace rows.
    expect(
      SyncDataSerializer.debugBaseTableKeys,
      const SyncData().toJson().keys.toList(),
    );
  });

  test(
    'streamed base equals exportChangeset(null) per table + valid checksum',
    () async {
      await _seedRich();
      final deletions = await SyncRepository().getAllDeletions();
      final expected = await SyncDataSerializer().exportChangeset(
        deviceId: 'peer',
        hlcWatermark: null,
        deletions: deletions,
      );

      final base = await SyncDataSerializer().exportBaseToTempFile(
        deviceId: 'peer',
        deletions: deletions,
        now: () => DateTime.fromMillisecondsSinceEpoch(123),
      );
      final decoded =
          jsonDecode(await File(base.path).readAsString())
              as Map<String, dynamic>;
      await File(base.path).delete();

      expect(decoded['version'], syncFormatVersion);
      expect(decoded['exportedAt'], 123);
      expect(base.exportedAt, 123);
      expect(
        _canonical(decoded['data'] as Map<String, dynamic>),
        _canonical(expected.data.toJson()),
      );
      expect(base.toHlc, expected.toHlc);
      // Internal checksum is valid over the streamed data bytes.
      final dataJson = jsonEncode(decoded['data']);
      expect(
        decoded['checksum'],
        sha256.convert(utf8.encode(dataJson)).toString(),
      );
    },
  );

  test('keyset paging across >1 page is complete', () async {
    final dives = DiveRepository();
    for (var i = 1; i <= 250; i++) {
      await dives.createDive(
        createTestDiveWithBottomTime(id: 'd$i', diveNumber: i),
      );
    }
    final expected = await SyncDataSerializer().exportChangeset(
      deviceId: 'peer',
      hlcWatermark: null,
      deletions: const [],
    );
    final base = await SyncDataSerializer().exportBaseToTempFile(
      deviceId: 'peer',
      deletions: const [],
      pageSize: 100, // forces 3 pages of dives
    );
    final decoded =
        jsonDecode(await File(base.path).readAsString())
            as Map<String, dynamic>;
    await File(base.path).delete();
    expect((decoded['data']['dives'] as List).length, 250);
    expect(
      _canonical(decoded['data'] as Map<String, dynamic>),
      _canonical(expected.data.toJson()),
    );
  });

  test('rowCount equals the total rows written to the base', () async {
    await _seedRich();
    final base = await SyncDataSerializer().exportBaseToTempFile(
      deviceId: 'peer',
      deletions: const [],
    );
    final decoded =
        jsonDecode(await File(base.path).readAsString())
            as Map<String, dynamic>;
    await File(base.path).delete();
    final total = (decoded['data'] as Map<String, dynamic>).values.fold<int>(
      0,
      (n, v) => n + (v as List).length,
    );
    expect(base.rowCount, total);
    expect(base.rowCount, greaterThan(0));
  });
}
