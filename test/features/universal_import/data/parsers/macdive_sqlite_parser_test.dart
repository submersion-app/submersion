import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  group('MacDiveSqliteParser', () {
    late Uint8List validBytes;

    setUpAll(() async {
      final path =
          '${Directory.systemTemp.path}/msp_${DateTime.now().microsecondsSinceEpoch}.sqlite';
      final file = buildSyntheticMacDiveDb(path);
      validBytes = Uint8List.fromList(await file.readAsBytes());
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
    });

    test('supportedFormats is macdiveSqlite', () {
      expect(MacDiveSqliteParser().supportedFormats, [
        ImportFormat.macdiveSqlite,
      ]);
    });

    test('parses synthetic MacDive SQLite end-to-end', () async {
      final payload = await MacDiveSqliteParser().parse(validBytes);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 3);
      expect(payload.entitiesOf(ImportEntityType.sites).length, 2);
      expect(
        payload.warnings.where(
          (w) => w.severity == ImportWarningSeverity.error,
        ),
        isEmpty,
      );
    });

    test('returns error payload on non-MacDive SQLite', () async {
      final tmp = File(
        '${Directory.systemTemp.path}/not_md_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      if (tmp.existsSync()) tmp.deleteSync();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync();
      });

      final db = sqlite3.sqlite3.open(tmp.path);
      db.execute('CREATE TABLE foo (id INTEGER PRIMARY KEY);');
      db.dispose();

      final otherBytes = Uint8List.fromList(await tmp.readAsBytes());
      final payload = await MacDiveSqliteParser().parse(otherBytes);
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
      expect(payload.warnings.first.severity, ImportWarningSeverity.error);
    });

    test('returns error payload on totally invalid bytes', () async {
      final garbage = Uint8List.fromList(const [0, 1, 2, 3, 4]);
      final payload = await MacDiveSqliteParser().parse(garbage);
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings.first.severity, ImportWarningSeverity.error);
    });
  });
}
