import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/divinglog_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';

/// Inserts one dive, optionally tombstoned, optionally with Tank rows.
/// Deliberately duplicated from the reader test rather than shared: each
/// test file stands alone.
Uint8List buildDivingLogWithRows({
  bool tombstoneTheDive = false,
  bool withTankRows = false,
}) {
  final dir = Directory.systemTemp.createTempSync('dl_parser');
  final path = '${dir.path}/logbook.sql';
  final db = sqlite3.open(path);
  db.execute('''
CREATE TABLE Logbook (
  ID INTEGER PRIMARY KEY, UUID TEXT, Number INTEGER,
  Divedate TEXT, Entrytime TEXT,
  Country TEXT, City TEXT, Place TEXT,
  Buddy TEXT, Divemaster TEXT, Comments TEXT,
  Depth REAL, Divetime INTEGER,
  Airtemp REAL, Watertemp REAL, Weight REAL,
  Divesuit TEXT, Computer TEXT, Visibility INTEGER, SupplyType TEXT,
  ProfileInt INTEGER, Profile TEXT, Profile2 TEXT,
  Profile3 TEXT, Profile4 TEXT, Profile5 TEXT,
  TankSize REAL, PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER
)''');
  db.execute('CREATE TABLE DeletedRecords (UUID TEXT)');
  db.execute('''
CREATE TABLE Tank (
  LogID INTEGER, TankID INTEGER, TankSize REAL,
  PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER
)''');
  db.execute('''
INSERT INTO Logbook VALUES (
  1, 'uuid-1', 42, '2024-06-01', '09:30',
  'Bonaire', 'Kralendijk', 'Salt Pier',
  'Alice, Bob', 'Carol', 'lovely dive',
  18.5, 47, 29.0, 27.0, 5.0,
  '3mm shorty', 'Perdix', 1, 'Nitrox',
  20, '004500000000', '25518051099', NULL, NULL, NULL,
  11.1, 210.0, 70.0, 232.0, 32.0, 0.0, 0
)''');
  if (tombstoneTheDive) {
    db.execute("INSERT INTO DeletedRecords VALUES ('uuid-1')");
  }
  if (withTankRows) {
    db.execute(
      'INSERT INTO Tank VALUES (1, 0, 11.1, 210.0, 70.0, 232.0, 32.0, 0.0, 0)',
    );
    db.execute(
      'INSERT INTO Tank VALUES (1, 1, 7.0, 200.0, 180.0, 232.0, 50.0, 0.0, 1)',
    );
  }
  db.close();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}

void main() {
  group('DivingLogSqliteParser', () {
    test('parses a Diving Log file into dives and sites', () async {
      final payload = await const DivingLogSqliteParser().parse(
        buildDivingLogWithRows(),
      );
      expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));
      expect(payload.metadata['source'], 'divinglog_sqlite');
    });

    test('reports a non-SQLite file as an error with no entities', () async {
      final bytes = Uint8List.fromList('not a database'.codeUnits);
      final payload = await const DivingLogSqliteParser().parse(bytes);
      expect(payload.entities, isEmpty);
      expect(
        payload.warnings.any((w) => w.severity == ImportWarningSeverity.error),
        isTrue,
      );
    });

    test('reports an empty file as an error', () async {
      final payload = await const DivingLogSqliteParser().parse(Uint8List(0));
      expect(payload.entities, isEmpty);
      expect(
        payload.warnings.any((w) => w.severity == ImportWarningSeverity.error),
        isTrue,
      );
    });

    test('declares the format it handles', () {
      expect(const DivingLogSqliteParser().supportedFormats, [
        ImportFormat.divingLogSqlite,
      ]);
    });

    test(
      'reports a Logbook table that shares only the name as an error',
      () async {
        final dir = Directory.systemTemp.createTempSync('dl_parser_odd');
        final path = '${dir.path}/logbook.sql';
        final db = sqlite3.open(path);
        db.execute('CREATE TABLE Logbook (Foo TEXT)');
        db.close();
        final bytes = Uint8List.fromList(File(path).readAsBytesSync());
        dir.deleteSync(recursive: true);

        final payload = await const DivingLogSqliteParser().parse(bytes);
        expect(payload.entities, isEmpty);
        expect(
          payload.warnings.any(
            (w) =>
                w.severity == ImportWarningSeverity.error &&
                w.message.contains('Failed to read Diving Log logbook'),
          ),
          isTrue,
        );
      },
    );

    test('keeps the schema notes when no dive could be read', () async {
      final dir = Directory.systemTemp.createTempSync('dl_parser_noid');
      final path = '${dir.path}/logbook.sql';
      final db = sqlite3.open(path);
      // No ID column, so every row is skipped and the note is the only
      // thing that explains the empty result.
      db.execute('CREATE TABLE Logbook (Divedate TEXT, Depth REAL)');
      db.execute("INSERT INTO Logbook VALUES ('2024-06-01', 18.5)");
      db.close();
      final bytes = Uint8List.fromList(File(path).readAsBytesSync());
      dir.deleteSync(recursive: true);

      final payload = await const DivingLogSqliteParser().parse(bytes);
      expect(payload.entities, isEmpty);
      expect(
        payload.warnings.any((w) => w.message.contains('Logbook is missing')),
        isTrue,
      );
    });

    test('is registered for its format', () {
      expect(
        parserForFormat(ImportFormat.divingLogSqlite),
        isA<DivingLogSqliteParser>(),
      );
    });

    test('the format is marked supported', () {
      expect(ImportFormat.divingLogSqlite.isSupported, isTrue);
      expect(ImportFormat.divingLogSqlite.displayName, 'Diving Log');
    });

    test('Diving Log has export instructions naming the logbook', () {
      final text = SourceApp.divingLog.exportInstructions;
      expect(text, isNotNull);
      expect(text!.toLowerCase(), contains('logbook'));
    });
  });
}
