import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

import '../../../helpers/test_database.dart';

/// A base's high-water mark must count media fact clocks as well as row
/// clocks (media sync program spec 5.1). A base whose newest change is a
/// fact write would otherwise leave the watermark below that clock, and the
/// first incremental after it would re-publish the row for nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory fakeAppTemp;
  setUpAll(() async {
    fakeAppTemp = await Directory.systemTemp.createTemp('fact_watermark_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              call.method == 'getTemporaryDirectory' ? fakeAppTemp.path : null,
        );
  });

  tearDownAll(() async {
    if (fakeAppTemp.existsSync()) await fakeAppTemp.delete(recursive: true);
  });

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 0, 0)",
    );
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 0,
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('a fact clock lifts the base watermark', () async {
    await SyncRepository().markFactsPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 1,
      group: SyncFactGroups.mediaUpload,
    );
    final row = (await SyncDataSerializer().fetchRecord('media', 'm1'))!;
    final rowClock = row['hlc'] as String;
    final factClock = row['uploadFactsHlc'] as String;
    expect(factClock.compareTo(rowClock), greaterThan(0));

    final base = await SyncDataSerializer().exportBaseToTempFile(
      deviceId: 'me',
      deletions: const [],
    );
    addTearDown(() async {
      final f = File(base.path);
      if (f.existsSync()) await f.delete();
    });
    final json =
        jsonDecode(await File(base.path).readAsString())
            as Map<String, dynamic>;

    expect(
      json['toHlc'],
      factClock,
      reason: 'else the next incremental re-publishes the row for nothing',
    );
  });
}
