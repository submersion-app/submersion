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

/// Inserts one dive, optionally tombstoned, optionally with Tank rows.
Uint8List buildDivingLogWithRows({
  bool tombstoneTheDive = false,
  bool withTankRows = false,
}) {
  final dir = Directory.systemTemp.createTempSync('dl_rows');
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

  group('DivingLogDbReader.readAll', () {
    test('reads a dive row with its scalar columns in source units', () async {
      final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
      expect(book.dives, hasLength(1));
      final d = book.dives.single;
      expect(d.id, 1);
      expect(d.uuid, 'uuid-1');
      expect(d.number, 42);
      expect(d.diveDate, '2024-06-01');
      expect(d.entryTime, '09:30');
      expect(d.country, 'Bonaire');
      expect(d.city, 'Kralendijk');
      expect(d.place, 'Salt Pier');
      expect(d.buddy, 'Alice, Bob');
      expect(d.divemaster, 'Carol');
      expect(d.comments, 'lovely dive');
      // Logbook.Depth is metres, not the profile's centimetres.
      expect(d.depthMeters, closeTo(18.5, 1e-9));
      expect(d.diveTimeMinutes, 47);
      expect(d.airTempCelsius, closeTo(29.0, 1e-9));
      expect(d.waterTempCelsius, closeTo(27.0, 1e-9));
      expect(d.weightKg, closeTo(5.0, 1e-9));
      expect(d.divesuit, '3mm shorty');
      expect(d.computer, 'Perdix');
      expect(d.visibilityCode, 1);
      expect(d.supplyType, 'Nitrox');
    });

    test('decodes the dive profile through the codec', () async {
      final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
      final samples = book.dives.single.samples;
      expect(samples, hasLength(1));
      expect(samples.single.depthMeters, closeTo(4.5, 1e-9));
      expect(samples.single.temperatureCelsius, closeTo(25.5, 1e-9));
    });

    test('excludes dives listed in DeletedRecords', () async {
      final book = await DivingLogDbReader.readAll(
        buildDivingLogWithRows(tombstoneTheDive: true),
      );
      expect(book.dives, isEmpty);
    });

    test('falls back to the Logbook cylinder when Tank has no rows', () async {
      final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
      final tanks = book.dives.single.tanks;
      expect(tanks, hasLength(1));
      expect(tanks.single.tankId, 0);
      expect(tanks.single.sizeLiters, closeTo(11.1, 1e-9));
      expect(tanks.single.startPressureBar, closeTo(210.0, 1e-9));
      expect(tanks.single.endPressureBar, closeTo(70.0, 1e-9));
      expect(tanks.single.workingPressureBar, closeTo(232.0, 1e-9));
      expect(tanks.single.o2Percent, closeTo(32.0, 1e-9));
      expect(tanks.single.isDouble, isFalse);
    });

    test(
      'prefers Tank rows over the Logbook cylinder, ordered by TankID',
      () async {
        final book = await DivingLogDbReader.readAll(
          buildDivingLogWithRows(withTankRows: true),
        );
        final tanks = book.dives.single.tanks;
        expect(tanks, hasLength(2));
        expect(tanks.map((t) => t.tankId), [0, 1]);
        expect(tanks[1].o2Percent, closeTo(50.0, 1e-9));
        expect(tanks[1].isDouble, isTrue);
      },
    );

    test(
      'records missing optional columns as notes rather than throwing',
      () async {
        final book = await DivingLogDbReader.readAll(
          buildDivingLogBytes(extraLogbookColumns: false),
        );
        expect(book.dives, isEmpty);
        expect(book.missingColumnNotes.join(' '), contains('Divemaster'));
      },
    );
  });
}
