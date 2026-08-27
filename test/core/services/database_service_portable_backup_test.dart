import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';

void main() {
  // These tests drive backup() against a service with databaseKeyHex set and
  // a fake exporter; no real cipher needed on the host.
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('portable_backup');
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    await tmp.delete(recursive: true);
  });

  test(
    'backup of an encrypted db exports plaintext via the exporter',
    () async {
      final src = '${tmp.path}/submersion.db';
      File(
        src,
      ).writeAsBytesSync(List<int>.generate(4096, (i) => (i * 37 + 11) % 256));
      final calls = <String?>[];
      DatabaseService.instance
        ..databaseKeyHex = 'aa'
        ..debugExporterOverride =
            ({
              required String sourcePath,
              required String targetPath,
              String? sourceKeyHex,
              String? targetKeyHex,
            }) async {
              calls.add(targetKeyHex);
              File(targetPath).writeAsStringSync('PLAINTEXT-EXPORT');
            }
        ..setCurrentPathForTesting(src);

      final dest = '${tmp.path}/out/backup.db';
      await DatabaseService.instance.backup(dest);
      expect(calls, [null]); // targetKeyHex null = plaintext export
      expect(File(dest).readAsStringSync(), 'PLAINTEXT-EXPORT');
      expect(File('$dest.export-staging').existsSync(), false);
    },
  );

  test(
    'backup of a plaintext db never reaches the sqlcipher exporter',
    () async {
      // Not a real database, so the SQL-level export cannot run and the
      // degraded byte-copy fallback produces the artifact. Either way the
      // encrypted branch must stay untouched -- that is what is asserted here.
      final src = '${tmp.path}/submersion.db';
      File(src).writeAsBytesSync([
        ...'SQLite format 3'.codeUnits,
        0,
        ...List.filled(100, 7),
      ]);
      var exporterCalled = false;
      DatabaseService.instance
        ..databaseKeyHex = null
        ..debugExporterOverride =
            ({
              required String sourcePath,
              required String targetPath,
              String? sourceKeyHex,
              String? targetKeyHex,
            }) async {
              exporterCalled = true;
            }
        ..setCurrentPathForTesting(src);

      final dest = '${tmp.path}/out/backup.db';
      await DatabaseService.instance.backup(dest);
      expect(exporterCalled, false);
      expect(File(dest).existsSync(), true);
    },
  );
}
