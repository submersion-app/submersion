import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Built-in dive types are reference data: seeded identically on every device,
/// and rejected by [DiveTypeRepository.deleteDiveType]. Nothing may remove
/// them.
///
/// A replace-adopt clears every synced table and refills from the cloud, but
/// `_exportDiveTypes` deliberately omits built-ins from the payload -- so the
/// refill cannot restore what the clear removed. Since the seed only runs in
/// `onCreate` and the one-shot `from < 93` migration, a device past v93 that
/// loses its built-ins never gets them back: the dive-type picker and
/// Settings > Manage > Dive Types both go permanently empty, and the surviving
/// `dive_dive_types` rows dangle against a missing catalog.
///
/// The adopt parity test cannot catch this: it compares both adopt paths via
/// `exportData()`, which excludes built-ins by definition.
SyncService _svc() => SyncService(
  syncRepository: SyncRepository(),
  serializer: SyncDataSerializer(),
);

Future<List<String>> _builtInIds() async {
  final db = DatabaseService.instance.database;
  final rows = await (db.select(
    db.diveTypes,
  )..where((t) => t.isBuiltIn.equals(true))).get();
  return rows.map((r) => r.id).toList()..sort();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => tearDownTestDatabase());

  test('adopt preserves built-in dive types', () async {
    // The cloud library is published by a peer whose export, like every
    // export, carries only custom dive types.
    final base = await SyncDataSerializer().exportData(
      deviceId: 'peer',
      deletions: const [],
    );
    expect(
      base.data.diveTypes,
      isEmpty,
      reason: 'exports never carry built-in dive types',
    );

    final seeded = await _builtInIds();
    expect(seeded, hasLength(15), reason: 'onCreate seeds the built-ins');

    final tmpDir = await Directory.systemTemp.createTemp('adopt_builtin');
    final tmp = File('${tmpDir.path}/base.json');
    await tmp.writeAsBytes(
      utf8.encode(SyncDataSerializer().serializePayload(base)),
    );
    await _svc().debugAdoptStreaming([tmp.path], [base.exportedAt], const []);
    await tmpDir.delete(recursive: true);

    expect(
      await _builtInIds(),
      seeded,
      reason: 'adopt must not delete rows its refill cannot restore',
    );
  });

  test(
    'reopening a database with no built-in dive types re-seeds them',
    () async {
      // Databases already stranded with an empty catalog -- by an adopt predating
      // the guard above, or by restoring a library copied from such a device --
      // are past v93, so no migration will ever repair them. beforeOpen must.
      final dir = await Directory.systemTemp.createTemp('reseed_backstop');
      final file = File('${dir.path}/submersion.db');

      var db = AppDatabase(NativeDatabase(file));
      await db.customStatement('DELETE FROM dive_types');
      final emptied = await db
          .customSelect('SELECT count(*) AS c FROM dive_types')
          .getSingle();
      expect(emptied.read<int>('c'), 0);
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final restored = await (db.select(
        db.diveTypes,
      )..where((t) => t.isBuiltIn.equals(true))).get();
      await db.close();
      await dir.delete(recursive: true);

      expect(
        restored,
        hasLength(15),
        reason: 'beforeOpen re-seeds the built-ins',
      );
      expect(
        restored.map((r) => r.id),
        contains('wreck'),
        reason: 'stable slug ids are what dive_dive_types references',
      );
    },
  );
}
