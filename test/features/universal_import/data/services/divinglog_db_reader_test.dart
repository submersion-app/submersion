import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_db_reader.dart';

/// Builds a Diving Log shaped database on disk and returns its bytes.
/// `extraLogbookColumns` false drops the optional columns so the
/// degradation path can be exercised.
Uint8List buildDivingLogBytes({
  bool withTankTable = true,
  bool extraLogbookColumns = true,
}) {
  final dir = Directory.systemTemp.createTempSync('dl_test');
  final path = '${dir.path}/logbook.sql';
  final db = sqlite3.open(path);
  final optional = extraLogbookColumns
      ? ', Divemaster TEXT, Visibility INTEGER, SupplyType TEXT, '
            'Divesuit TEXT, Computer TEXT'
      : '';
  db.execute('''
CREATE TABLE Logbook (
  ID INTEGER PRIMARY KEY, UUID TEXT, Number INTEGER,
  Divedate TEXT, Entrytime TEXT,
  Country TEXT, City TEXT, Place TEXT,
  Buddy TEXT, Comments TEXT,
  Depth REAL, Divetime INTEGER,
  Airtemp REAL, Watertemp REAL, Weight REAL,
  ProfileInt INTEGER, Profile TEXT, Profile2 TEXT,
  Profile3 TEXT, Profile4 TEXT, Profile5 TEXT,
  TankSize REAL, PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER$optional
)''');
  db.execute('CREATE TABLE DeletedRecords (UUID TEXT)');
  if (withTankTable) {
    db.execute('''
CREATE TABLE Tank (
  LogID INTEGER, TankID INTEGER, TankSize REAL,
  PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER
)''');
  }
  db.close();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}

void main() {
  group('DivingLogDbReader.matchesTables', () {
    test('accepts a Diving Log table set', () {
      expect(
        DivingLogDbReader.matchesTables({'Logbook', 'DeletedRecords', 'Tank'}),
        isTrue,
      );
    });

    test('accepts a logbook without the optional Tank table', () {
      expect(DivingLogDbReader.matchesTables({'Logbook'}), isTrue);
    });

    test('rejects a MacDive table set', () {
      expect(
        DivingLogDbReader.matchesTables({
          'ZDIVE',
          'ZDIVESITE',
          'ZGAS',
          'ZTANKANDGAS',
        }),
        isFalse,
      );
    });

    test('rejects a Shearwater table set', () {
      expect(
        DivingLogDbReader.matchesTables({'dive_details', 'log_data'}),
        isFalse,
      );
    });
  });

  group('DivingLogDbReader.isDivingLogDb', () {
    test('accepts a Diving Log shaped file', () async {
      expect(
        await DivingLogDbReader.isDivingLogDb(buildDivingLogBytes()),
        isTrue,
      );
    });

    test('returns false for non-SQLite bytes without throwing', () async {
      final bytes = Uint8List.fromList('not a database'.codeUnits);
      expect(await DivingLogDbReader.isDivingLogDb(bytes), isFalse);
    });
  });

  group('capabilities', () {
    test('reports the Tank table missing when it is absent', () async {
      final caps = await DivingLogDbReader.readCapabilities(
        buildDivingLogBytes(withTankTable: false),
      );
      expect(caps.hasTable('Logbook'), isTrue);
      expect(caps.hasTable('Tank'), isFalse);
    });

    test(
      'reports optional Logbook columns missing when they are absent',
      () async {
        final caps = await DivingLogDbReader.readCapabilities(
          buildDivingLogBytes(extraLogbookColumns: false),
        );
        expect(caps.hasColumn('Logbook', 'Depth'), isTrue);
        expect(caps.hasColumn('Logbook', 'Divemaster'), isFalse);
      },
    );
  });
}
