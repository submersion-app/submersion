import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  group('MacDiveSqliteParser', () {
    late Uint8List validBytes;

    setUpAll(() async {
      final dir = Directory.systemTemp.createTempSync('msp_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = buildSyntheticMacDiveDb(p.join(dir.path, 'msp.sqlite'));
      validBytes = Uint8List.fromList(await file.readAsBytes());
    });

    test('supportedFormats is macdiveSqlite', () {
      expect(const MacDiveSqliteParser().supportedFormats, [
        ImportFormat.macdiveSqlite,
      ]);
    });

    test('parses synthetic MacDive SQLite end-to-end', () async {
      final payload = await const MacDiveSqliteParser().parse(validBytes);
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
      final dir = Directory.systemTemp.createTempSync('not_md_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final tmp = File(p.join(dir.path, 'not_md.sqlite'));

      final db = sqlite3.sqlite3.open(tmp.path);
      db.execute('CREATE TABLE foo (id INTEGER PRIMARY KEY);');
      db.close();

      final otherBytes = Uint8List.fromList(await tmp.readAsBytes());
      final payload = await const MacDiveSqliteParser().parse(otherBytes);
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
      expect(payload.warnings.first.severity, ImportWarningSeverity.error);
    });

    test('fails a library with no dives with an error', () async {
      // Nothing is imported, so the file fails and this message becomes the
      // reason shown for it.
      final dir = Directory.systemTemp.createTempSync('msp_empty_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final path = p.join(dir.path, 'msp_empty.sqlite');
      final file = buildSyntheticMacDiveDb(path);
      final db = sqlite3.sqlite3.open(path);
      db.execute('DELETE FROM ZDIVE;');
      db.close();

      final payload = await const MacDiveSqliteParser().parse(
        Uint8List.fromList(await file.readAsBytes()),
      );

      expect(payload.isEmpty, isTrue);
      expect(payload.warnings.single.severity, ImportWarningSeverity.error);
      expect(payload.warnings.single.message, contains('no dives'));
    });

    test('returns error payload on totally invalid bytes', () async {
      final garbage = Uint8List.fromList(const [0, 1, 2, 3, 4]);
      final payload = await const MacDiveSqliteParser().parse(garbage);
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings.first.severity, ImportWarningSeverity.error);
    });

    test(
      'gear entities carry a stable uddfId matching the gear UUID',
      () async {
        final payload = await const MacDiveSqliteParser().parse(validBytes);
        final equipment = payload.entitiesOf(ImportEntityType.equipment);
        expect(equipment, hasLength(2));
        final gear = equipment.firstWhere((g) => g['name'] == 'Hydros Pro');
        expect(gear['name'], 'Hydros Pro');
        expect(gear['uddfId'], 'gear-uuid-1');
        expect(gear['sourceUuid'], 'gear-uuid-1');
      },
    );

    test(
      'dives emit equipmentRefs pointing at gear uddfIds, enabling linking',
      () async {
        final payload = await const MacDiveSqliteParser().parse(validBytes);
        final dives = payload.entitiesOf(ImportEntityType.dives);
        // Dive 1 in the synthetic fixture has the only dive↔gear junction.
        final withGear = dives.where(
          (d) => (d['equipmentRefs'] as List?)?.isNotEmpty ?? false,
        );
        expect(withGear, hasLength(1));
        final refs = withGear.single['equipmentRefs'] as List;
        expect(refs, ['gear-uuid-1']);
      },
    );
  });
}
