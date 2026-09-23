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

/// A logbook spelled the way the real DiveLogDT export spells it:
/// `Tanksize`, not `TankSize`, and a fractional `Divetime`.
Uint8List buildRealSpellingLogbook() {
  final dir = Directory.systemTemp.createTempSync('dl_case');
  final path = '${dir.path}/logbook.sql';
  final db = sqlite3.open(path);
  db.execute('''
CREATE TABLE Logbook (
  ID INTEGER PRIMARY KEY, UUID TEXT, Number INTEGER,
  Divedate TEXT, Entrytime TEXT, Divetime REAL, Depth REAL,
  Tanksize REAL, PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER
)''');
  db.execute(
    "INSERT INTO Logbook VALUES (1, 'u1', 1, '2024-06-01', '09:30', "
    '80.733333, 18.5, 11.1, 210.0, 70.0, 232.0, 32.0, 0.0, 0)',
  );
  db.close();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}

/// A table that shares the `Logbook` name but none of its columns, and a
/// logbook whose numbers are stored as TEXT (SQLite is dynamically typed,
/// so a column declared REAL can still hold a string).
Uint8List buildOddLogbook({required bool unrecognisable}) {
  final dir = Directory.systemTemp.createTempSync('dl_odd');
  final path = '${dir.path}/logbook.sql';
  final db = sqlite3.open(path);
  if (unrecognisable) {
    db.execute('CREATE TABLE Logbook (Foo TEXT, Bar INTEGER)');
    db.execute("INSERT INTO Logbook VALUES ('x', 1)");
  } else {
    db.execute(
      'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Number TEXT, '
      'Divedate TEXT, Entrytime TEXT, Divetime TEXT, Depth TEXT, '
      'Weight TEXT)',
    );
    db.execute(
      "INSERT INTO Logbook VALUES (1, '42', '2024-06-01', '09:30', "
      "'47.5', '18.5', '5.5')",
    );
  }
  db.close();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}

/// A logbook with every reference table populated and one dive wired to
/// all of them.
Uint8List buildReferenceLogbook() {
  final dir = Directory.systemTemp.createTempSync('dl_refs');
  final path = '${dir.path}/logbook.sql';
  final db = sqlite3.open(path);
  db.execute("""
CREATE TABLE Logbook (
  ID INTEGER PRIMARY KEY, UUID TEXT, Divedate TEXT, Entrytime TEXT,
  Buddy TEXT, BuddyIDs TEXT, UsedEquip TEXT, Divetype TEXT,
  PlaceID INTEGER, CityID INTEGER, CountryID INTEGER,
  ShopID INTEGER, TripID INTEGER, Depth REAL
)""");
  db.execute(
    "INSERT INTO Logbook VALUES (1, 'u1', '2024-06-01', '09:30', "
    "'Ignored Text', '1,2', '3,7', '5,6', 10, 20, 30, 40, 50, 18.5)",
  );
  db.execute("""
CREATE TABLE Buddy (
  ID INTEGER PRIMARY KEY, FirstName TEXT, LastName TEXT, Email TEXT,
  Phone TEXT, Mobile TEXT, Comments TEXT, URL TEXT
)""");
  db.execute(
    "INSERT INTO Buddy VALUES (1, 'Alice', 'Smith', 'a@x.test', '123', "
    "NULL, 'good buddy', NULL)",
  );
  db.execute(
    "INSERT INTO Buddy VALUES (2, 'Bob', NULL, NULL, NULL, NULL, NULL, NULL)",
  );
  db.execute("""
CREATE TABLE Place (
  ID INTEGER PRIMARY KEY, CountryID INTEGER, Place TEXT, Lat REAL, Lon REAL,
  MaxDepth REAL, WaterName TEXT, Difficulty TEXT, Comments TEXT
)""");
  db.execute(
    "INSERT INTO Place VALUES (10, 30, 'Salt Pier', 12.13, -68.28, 24.0, "
    "'Caribbean', 'Easy', 'pier dive')",
  );
  db.execute(
    'CREATE TABLE City (ID INTEGER PRIMARY KEY, CountryID INTEGER, City TEXT)',
  );
  db.execute("INSERT INTO City VALUES (20, 30, 'Kralendijk')");
  db.execute('CREATE TABLE Country (ID INTEGER PRIMARY KEY, Country TEXT)');
  db.execute("INSERT INTO Country VALUES (30, 'Bonaire')");
  db.execute("""
CREATE TABLE Equipment (
  ID INTEGER PRIMARY KEY, Object TEXT, Manufacturer TEXT, Serial TEXT,
  DateP TEXT, Price REAL, Weight REAL, Inactive INTEGER, O2ServiceDate TEXT,
  Comments TEXT
)""");
  db.execute(
    "INSERT INTO Equipment VALUES (3, 'Go Sport Fins', 'ScubaPro', 'SN1', "
    "'2020-01-02', 99.0, 1.4968, 0, NULL, 'blue')",
  );
  db.execute(
    "INSERT INTO Equipment VALUES (7, 'Wet Suit (5mm full body)', "
    "'Henderson', NULL, NULL, NULL, NULL, 1, NULL, NULL)",
  );
  db.execute("""
CREATE TABLE Trip (
  ID INTEGER PRIMARY KEY, ShopID INTEGER, TripName TEXT, StartDate TEXT,
  EndDate TEXT, Comments TEXT
)""");
  db.execute(
    "INSERT INTO Trip VALUES (50, 40, 'Bonaire 2024', '2024-05-30', "
    "'2024-06-08', 'shore week')",
  );
  db.execute("""
CREATE TABLE Shop (
  ID INTEGER PRIMARY KEY, ShopName TEXT, ShopType TEXT, Street TEXT,
  City TEXT, State TEXT, Zip TEXT, Country TEXT, Phone TEXT, Email TEXT,
  URL TEXT, Comments TEXT
)""");
  db.execute(
    "INSERT INTO Shop VALUES (40, 'Dive Friends', 'Dive Center', 'Kaya', "
    "'Kralendijk', NULL, NULL, 'Bonaire', '555', 'd@x.test', "
    "'https://x.test', 'friendly')",
  );
  db.execute(
    'CREATE TABLE Divetype '
    '(ID INTEGER PRIMARY KEY, Typename TEXT, SortOrd INTEGER)',
  );
  db.execute("INSERT INTO Divetype VALUES (5, 'Education', 5)");
  db.execute("INSERT INTO Divetype VALUES (6, 'Live Aboard', 6)");
  db.execute("""
CREATE TABLE Brevets (
  ID INTEGER PRIMARY KEY, Brevet TEXT, Org TEXT, CertDate TEXT,
  Number TEXT, Instructor TEXT
)""");
  db.execute(
    "INSERT INTO Brevets VALUES (1, 'Rescue Diver', 'PADI', '2023-09-08', "
    "'12345', 'Jane Doe')",
  );
  db.execute(
    'CREATE TABLE Fish '
    '(ID INTEGER PRIMARY KEY, CommonName TEXT, ScientificName TEXT)',
  );
  db.execute(
    "INSERT INTO Fish VALUES (99, 'Giant Manta Ray', 'Mobula birostris')",
  );
  db.execute(
    'CREATE TABLE FishRel '
    '(ID INTEGER PRIMARY KEY, LogID INTEGER, FishID INTEGER)',
  );
  db.execute('INSERT INTO FishRel VALUES (1, 1, 99)');
  db.execute("""
CREATE TABLE Pictures (
  ID INTEGER PRIMARY KEY, LogID INTEGER, Path TEXT, Description TEXT
)""");
  db.execute(
    "INSERT INTO Pictures VALUES (1, 1, '/photos/dive1.jpg', 'manta')",
  );
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
        expect(book.schemaNotes.join(' '), contains('Divemaster'));
      },
    );
  });

  group('real-world spelling and precision', () {
    test('matches a column whose case differs from ours', () async {
      // The real export writes `Tanksize`; dropping it silently cost every
      // dive its cylinder volume, and with it SAC and gas consumption.
      final book = await DivingLogDbReader.readAll(buildRealSpellingLogbook());
      final tank = book.dives.single.tanks.single;
      expect(tank.sizeLiters, closeTo(11.1, 1e-9));
      // The fixture legitimately lacks many columns, but the differently
      // cased one must not be among those reported missing.
      expect(book.schemaNotes.join(' '), isNot(contains('TankSize')));
    });

    test('diagnoses an absent optional table', () async {
      // A missing Tank table costs multi-cylinder rows and a missing
      // DeletedRecords table lets tombstoned dives back in, so neither
      // may pass silently.
      final book = await DivingLogDbReader.readAll(
        buildDivingLogBytes(withTankTable: false),
      );
      expect(book.schemaNotes.join(' '), contains('Tank'));
    });

    test('diagnoses a DeletedRecords table that has no UUID column', () async {
      final dir = Directory.systemTemp.createTempSync('dl_keyless');
      final path = '${dir.path}/logbook.sql';
      final db = sqlite3.open(path);
      db.execute(
        'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Divedate TEXT)',
      );
      db.execute('CREATE TABLE DeletedRecords (Something TEXT)');
      db.close();
      final bytes = File(path).readAsBytesSync();
      dir.deleteSync(recursive: true);

      final book = await DivingLogDbReader.readAll(bytes);
      expect(
        book.schemaNotes.join(' '),
        contains('DeletedRecords table has no UUID column'),
      );
    });

    test('diagnoses a Tank table with no LogID column', () async {
      final dir = Directory.systemTemp.createTempSync('dl_tank_nokey');
      final path = '${dir.path}/logbook.sql';
      final db = sqlite3.open(path);
      db.execute(
        'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Divedate TEXT)',
      );
      db.execute('CREATE TABLE Tank (TankID INTEGER, Tanksize REAL)');
      db.close();
      final bytes = File(path).readAsBytesSync();
      dir.deleteSync(recursive: true);

      final book = await DivingLogDbReader.readAll(bytes);
      expect(
        book.schemaNotes.join(' '),
        contains('Tank table has no LogID column'),
      );
    });

    test('diagnoses Tank columns the file has dropped', () async {
      final dir = Directory.systemTemp.createTempSync('dl_tank_thin');
      final path = '${dir.path}/logbook.sql';
      final db = sqlite3.open(path);
      db.execute(
        'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Divedate TEXT)',
      );
      db.execute('CREATE TABLE Tank (LogID INTEGER, TankID INTEGER)');
      db.close();
      final bytes = File(path).readAsBytesSync();
      dir.deleteSync(recursive: true);

      final book = await DivingLogDbReader.readAll(bytes);
      expect(book.schemaNotes.join(' '), contains('Tank is missing'));
      expect(book.schemaNotes.join(' '), contains('TankSize'));
    });

    test('does not diagnose a table the file has', () async {
      final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
      expect(book.schemaNotes.join(' '), isNot(contains('Tank table')));
    });

    test('survives a table name containing a quote', () async {
      final dir = Directory.systemTemp.createTempSync('dl_quote');
      final path = '${dir.path}/logbook.sql';
      final db = sqlite3.open(path);
      db.execute(
        'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Divedate TEXT)',
      );
      db.execute('INSERT INTO Logbook VALUES (1, \'2024-06-01\')');
      // A hostile neighbour table must not break the schema probe.
      // Creating a table literally named od"d needs the quote doubled,
      // which is exactly the escaping the reader has to perform too.
      db.execute('CREATE TABLE "od""d" (x TEXT)');
      db.close();
      final bytes = File(path).readAsBytesSync();
      dir.deleteSync(recursive: true);

      final book = await DivingLogDbReader.readAll(bytes);
      expect(book.dives, hasLength(1));
      expect(book.capabilities.hasColumn('od"d', 'x'), isTrue);
    });

    test('matches a table whose case differs from ours', () {
      expect(DivingLogDbReader.matchesTables({'logbook'}), isTrue);
      expect(DivingLogDbReader.matchesTables({'LOGBOOK'}), isTrue);
    });

    test('keeps the fractional part of Divetime', () async {
      // 393 of 444 dives in the real file have a non-integer Divetime.
      final book = await DivingLogDbReader.readAll(buildRealSpellingLogbook());
      expect(book.dives.single.diveTimeMinutes, closeTo(80.733333, 1e-6));
    });
  });

  group('hostile and loosely typed files', () {
    test('rejects a Logbook table that shares only the name', () async {
      expect(
        () => DivingLogDbReader.readAll(buildOddLogbook(unrecognisable: true)),
        throwsA(isA<FormatException>()),
      );
    });

    test('reads numbers stored as TEXT', () async {
      // SQLite is dynamically typed, so a REAL column can hold a string.
      final book = await DivingLogDbReader.readAll(
        buildOddLogbook(unrecognisable: false),
      );
      final d = book.dives.single;
      expect(d.number, 42);
      expect(d.diveTimeMinutes, closeTo(47.5, 1e-9));
      expect(d.depthMeters, closeTo(18.5, 1e-9));
      expect(d.weightKg, closeTo(5.5, 1e-9));
    });
  });

  group('reference tables', () {
    test('diagnoses a reference table that has lost its key column', () async {
      // The same shape as the keyless DeletedRecords and Tank cases: the
      // table is present, so "no Buddy table" would be wrong, but without
      // its id nothing in it can be matched to a dive.
      final dir = Directory.systemTemp.createTempSync('dl_keyless_ref');
      final path = '${dir.path}/logbook.sql';
      final db = sqlite3.open(path);
      db.execute(
        'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Divedate TEXT)',
      );
      db.execute('CREATE TABLE Buddy (FirstName TEXT, LastName TEXT)');
      db.close();
      final bytes = File(path).readAsBytesSync();
      dir.deleteSync(recursive: true);

      final book = await DivingLogDbReader.readAll(bytes);
      expect(book.buddiesById, isEmpty);
      expect(
        book.schemaNotes.join(' '),
        contains('Buddy table has no ID column'),
      );
    });

    test('diagnoses a FishRel table missing its second join column', () async {
      // FishRel needs both LogID and FishID. Requiring only LogID let a
      // drifted table drop every marine-life link with no diagnostic.
      final dir = Directory.systemTemp.createTempSync('dl_fishrel');
      final path = '${dir.path}/logbook.sql';
      final db = sqlite3.open(path);
      db.execute(
        'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Divedate TEXT)',
      );
      db.execute(
        'CREATE TABLE FishRel (ID INTEGER PRIMARY KEY, LogID INTEGER)',
      );
      db.close();
      final bytes = File(path).readAsBytesSync();
      dir.deleteSync(recursive: true);

      final book = await DivingLogDbReader.readAll(bytes);
      expect(book.speciesIdsByLogId, isEmpty);
      expect(book.schemaNotes.join(' '), contains('FishRel'));
      expect(book.schemaNotes.join(' '), contains('FishID'));
    });

    test(
      'diagnoses a reference table with no usable payload columns',
      () async {
        // A Buddy table with an ID and no name parts yields rows the mapper
        // discards, so the diver loses their buddy list with nothing said.
        final dir = Directory.systemTemp.createTempSync('dl_no_names');
        final path = '${dir.path}/logbook.sql';
        final db = sqlite3.open(path);
        db.execute(
          'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Divedate TEXT)',
        );
        db.execute('CREATE TABLE Buddy (ID INTEGER PRIMARY KEY, Email TEXT)');
        db.close();
        final bytes = File(path).readAsBytesSync();
        dir.deleteSync(recursive: true);

        final book = await DivingLogDbReader.readAll(bytes);
        final notes = book.schemaNotes.join(' ');
        expect(notes, contains('Buddy'));
        expect(notes, contains('FirstName'));
      },
    );

    test('reads the id columns off the dive row', () async {
      final book = await DivingLogDbReader.readAll(buildReferenceLogbook());
      final d = book.dives.single;
      expect(d.buddyIds, [1, 2]);
      expect(d.equipmentIds, [3, 7]);
      expect(d.diveTypeIds, [5, 6]);
      expect(d.placeId, 10);
      expect(d.cityId, 20);
      expect(d.countryId, 30);
      expect(d.shopId, 40);
      expect(d.tripId, 50);
    });

    test('reads buddies with a joined display name', () async {
      final book = await DivingLogDbReader.readAll(buildReferenceLogbook());
      expect(book.buddiesById[1]!.fullName, 'Alice Smith');
      expect(book.buddiesById[1]!.email, 'a@x.test');
      expect(book.buddiesById[2]!.fullName, 'Bob');
    });

    test('reads coordinates stored as degrees minutes seconds', () async {
      final dir = Directory.systemTemp.createTempSync('dl_dms');
      final path = '${dir.path}/logbook.sql';
      final db = sqlite3.open(path);
      db.execute(
        'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Divedate TEXT)',
      );
      db.execute(
        'CREATE TABLE Place (ID INTEGER PRIMARY KEY, Place TEXT, Lat TEXT, '
        'Lon TEXT)',
      );
      // The real export writes this form, not a decimal.
      db.execute(
        'INSERT INTO Place VALUES '
        '(1, \'Arch Cave\', \'19°38\'\'27.80"N\', \'156°0\'\'31.98"W\')',
      );
      db.close();
      final bytes = File(path).readAsBytesSync();
      dir.deleteSync(recursive: true);

      final book = await DivingLogDbReader.readAll(bytes);
      final place = book.placesById[1]!;
      expect(place.latitude, closeTo(19 + 38 / 60 + 27.80 / 3600, 1e-9));
      expect(place.longitude, closeTo(-(156 + 0 / 60 + 31.98 / 3600), 1e-9));
    });

    test('reads places with coordinates', () async {
      final book = await DivingLogDbReader.readAll(buildReferenceLogbook());
      final place = book.placesById[10]!;
      expect(place.place, 'Salt Pier');
      expect(place.latitude, closeTo(12.13, 1e-9));
      expect(place.longitude, closeTo(-68.28, 1e-9));
      expect(place.maxDepthMeters, closeTo(24.0, 1e-9));
      expect(book.cityNamesById[20], 'Kralendijk');
      expect(book.countryNamesById[30], 'Bonaire');
    });

    test('reads equipment including the retired flag and weight', () async {
      final book = await DivingLogDbReader.readAll(buildReferenceLogbook());
      expect(book.equipmentById[3]!.object, 'Go Sport Fins');
      expect(book.equipmentById[3]!.weightKg, closeTo(1.4968, 1e-9));
      expect(book.equipmentById[3]!.inactive, isFalse);
      expect(book.equipmentById[7]!.inactive, isTrue);
    });

    test('reads trips, shops, dive types and certifications', () async {
      final book = await DivingLogDbReader.readAll(buildReferenceLogbook());
      expect(book.tripsById[50]!.name, 'Bonaire 2024');
      expect(book.tripsById[50]!.shopId, 40);
      expect(book.shopsById[40]!.name, 'Dive Friends');
      expect(book.shopsById[40]!.shopType, 'Dive Center');
      expect(book.diveTypesById[5]!.name, 'Education');
      expect(book.certifications.single.name, 'Rescue Diver');
      expect(book.certifications.single.organisation, 'PADI');
    });

    test('reads species and their dive links', () async {
      final book = await DivingLogDbReader.readAll(buildReferenceLogbook());
      expect(book.speciesById[99]!.commonName, 'Giant Manta Ray');
      expect(book.speciesById[99]!.scientificName, 'Mobula birostris');
      expect(book.speciesIdsByLogId[1], [99]);
    });

    test('reads pictures keyed by dive', () async {
      final book = await DivingLogDbReader.readAll(buildReferenceLogbook());
      expect(book.picturesByLogId[1]!.single.path, '/photos/dive1.jpg');
      expect(book.picturesByLogId[1]!.single.description, 'manta');
    });

    test(
      'leaves the maps empty and notes the gap when tables are absent',
      () async {
        // The phase 1 fixture has Logbook and Tank only.
        final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
        expect(book.buddiesById, isEmpty);
        expect(book.equipmentById, isEmpty);
        final notes = book.schemaNotes.join(' ');
        expect(notes, contains('Buddy'));
        expect(notes, contains('Equipment'));
      },
    );
  });
}
