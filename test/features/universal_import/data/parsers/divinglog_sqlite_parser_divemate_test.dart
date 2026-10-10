import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/divinglog_sqlite_parser.dart';

/// A logbook shaped like a DiveMate `.ddb` export (#3110).
///
/// DiveMate writes Diving Log's SQLite schema, so the file is detected and
/// read as a Diving Log logbook, but it has drifted from it: gear is named
/// in `Equipment.Name` with `Object` as the model, a site keeps its country
/// as text, a dive has one `TypeOfDive` id, an average depth, a `Status`
/// that marks discarded dives, and tank transmitter pressures in `Profile3`.
Uint8List buildDiveMateDdb() {
  final dir = Directory.systemTemp.createTempSync('divemate_ddb');
  final path = p.join(dir.path, 'divemate.ddb');
  final db = sqlite3.open(path);
  db.execute('''
CREATE TABLE Logbook (
  ID INTEGER, DiverID INTEGER, PlaceID INTEGER, ShopID INTEGER,
  TypeOfDive INTEGER, BuddyIDs TEXT, UsedEquip TEXT, Number INTEGER,
  Divedate TEXT, Entrytime TEXT, UTCoffset INTEGER, Divetime REAL,
  Surfint TEXT, Depth REAL, DepthAvg REAL, Airtemp REAL, Watertemp REAL,
  Weight REAL, Computer TEXT, Divesuit TEXT, Divemaster TEXT,
  Comments TEXT, UUID TEXT, ProfileInt INTEGER, Profile TEXT,
  Profile2 TEXT, Profile3 TEXT, Profile4 TEXT, Buddy TEXT, Status INTEGER
)''');
  db.execute('''
CREATE TABLE Place (
  ID INTEGER, Place TEXT, Country TEXT, Region TEXT, WaterName TEXT,
  Lat TEXT, Lon TEXT, MaxDepth REAL, Rating INTEGER, Water INTEGER,
  Comments TEXT, UUID TEXT
)''');
  db.execute('''
CREATE TABLE Buddy (
  ID INTEGER, FirstName TEXT, LastName TEXT, Email TEXT, UUID TEXT
)''');
  db.execute('''
CREATE TABLE Equipment (
  ID INTEGER, Name TEXT, Object TEXT, Category TEXT, Manufacturer TEXT,
  Serial TEXT, Inactive INTEGER, Weight REAL, Comments TEXT, UUID TEXT,
  Info TEXT, TypeID INTEGER
)''');
  db.execute('''
CREATE TABLE Divetype (ID INTEGER, Typename TEXT, SortOrd INTEGER)''');
  db.execute('''
CREATE TABLE Tank (
  ID INTEGER, LogID INTEGER, TankID INTEGER, Name TEXT, SortOrd INTEGER,
  Tanksize REAL, PresS REAL, PresE REAL, O2 REAL, He REAL, PresW REAL
)''');

  db.execute('''
INSERT INTO Place VALUES (
  7, 'Attersee Ost', 'Österreich', 'Oberösterreich', 'Attersee',
  '47°51''0.00"N', '13°33''0.00"E', 40, 0, 2, NULL, 'site-uuid'
)''');
  db.execute(
    "INSERT INTO Buddy VALUES (4, 'Sam', 'Buddy', NULL, 'buddy-uuid')",
  );
  db.execute('''
INSERT INTO Equipment VALUES (
  9, 'Fins', 'Jet Fin', 'Fins', 'Scubapro', NULL, 0, NULL, NULL,
  'fins-uuid', NULL, 4
)''');
  db.execute('''
INSERT INTO Equipment VALUES (
  10, 'Basic set', NULL, '---SET', NULL, NULL, 0, NULL, NULL,
  'set-uuid', '9', 9
)''');
  db.execute("INSERT INTO Divetype VALUES (5, 'Deep', 1)");

  // Two samples 30 s apart. Profile2 carries the pressure of the cylinder
  // in use (zero on the second sample, meaning not recorded); Profile3
  // carries both transmitters, tank 1 then tank 2, in tenths of a bar.
  db.execute('''
INSERT INTO Logbook VALUES (
  11, 1, 7, NULL, 5, '4', '10', 42, '2026-07-26', '14:29:00', 120, 48.5,
  '01:30', 31.2, 16.4, 26, 22, 6.5, 'Perdix', '5 mm', NULL, 'great dive',
  'dive-uuid', 30, '000000000000012300000000',
  '2202000000020000001000',
  '1995200000000019001450000000',
  NULL, 'Sam, Toni', 1
)''');
  // Discarded in DiveMate, so it is not part of the logbook.
  db.execute('''
INSERT INTO Logbook VALUES (
  12, 1, 7, NULL, NULL, NULL, NULL, 43, '2026-07-27', '09:00:00', 120,
  30, NULL, 10, 8, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  'discarded-uuid', NULL, NULL, NULL, NULL, NULL, NULL, 2
)''');
  db.execute('''
INSERT INTO Tank VALUES (
  1, 11, 1, 'Left', 1, 11.1, 200, 60, 32, 0, 232
)''');
  db.execute('''
INSERT INTO Tank VALUES (
  2, 11, 2, 'Right', 2, 11.1, 200, 140, 32, 0, 232
)''');
  db.close();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}

void main() {
  late ImportPayload payload;
  late Map<String, dynamic> dive;

  setUpAll(() async {
    payload = await const DivingLogSqliteParser().parse(buildDiveMateDdb());
    dive = payload
        .entitiesOf(ImportEntityType.dives)
        .firstWhere((d) => d['diveNumber'] == 42);
  });

  test('a dive DiveMate marked discarded is skipped and reported', () {
    expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
    expect(dive['diveNumber'], 42);
    // A diagnostic, not divesSkipped: that code means a dive that could not
    // be read and lands in the import's missing-dives card, while this one
    // was left out on purpose by the diver.
    final discarded = payload.warnings.where(
      (w) => w.message.contains('discarded'),
    );
    expect(discarded, hasLength(1));
    expect(discarded.single.code, ImportWarningCode.diagnostic);
    expect(discarded.single.count, 1);
    expect(
      payload.warnings.where((w) => w.code == ImportWarningCode.divesSkipped),
      isEmpty,
    );
  });

  test('average depth comes from DepthAvg', () {
    expect(dive['avgDepth'], 16.4);
  });

  test('the dive type comes from TypeOfDive', () {
    expect(dive['diveTypeIds'], ['deep']);
  });

  test('a site keeps the country and region its Place row names', () {
    final site = payload.entitiesOf(ImportEntityType.sites).single;
    expect(site['name'], 'Attersee Ost');
    expect(site['country'], 'Österreich');
    expect(site['region'], 'Oberösterreich');
    expect(site['latitude'], closeTo(47.85, 1e-9));
    expect(site['longitude'], closeTo(13.55, 1e-9));
  });

  group('equipment', () {
    test('an item is named from Name, with Object as its model', () {
      final gear = payload.entitiesOf(ImportEntityType.equipment);
      expect(gear, hasLength(1), reason: 'a set is not itself gear');
      expect(gear.single['name'], 'Fins');
      expect(gear.single['model'], 'Jet Fin');
      expect(gear.single['brand'], 'Scubapro');
      expect(gear.single['type'], 'fins');
    });

    test('a dive that used a set references the set members', () {
      expect(dive['equipmentRefs'], ['divinglog_gear_9']);
      final unresolved = payload.warnings.where(
        (w) => w.message.contains('equipment reference'),
      );
      expect(unresolved, isEmpty);
    });
  });

  group('tank pressure samples', () {
    List<Map<String, dynamic>> pressuresAt(int index) {
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      return profile[index]['allTankPressures'] as List<Map<String, dynamic>>;
    }

    test('each transmitter pressure lands on its own cylinder', () {
      expect(pressuresAt(0), [
        {'pressure': 199.5, 'tankIndex': 0},
        {'pressure': 200.0, 'tankIndex': 1},
      ]);
      expect(pressuresAt(1), [
        {'pressure': 190.0, 'tankIndex': 0},
        {'pressure': 145.0, 'tankIndex': 1},
      ]);
    });
  });

  group('buddies', () {
    test('a free-text name beside a linked buddy is kept', () {
      expect(dive['buddyRefs'], ['Sam Buddy', 'Toni']);
      final names = payload
          .entitiesOf(ImportEntityType.buddies)
          .map((b) => b['name'])
          .toSet();
      expect(names, {'Sam Buddy', 'Toni'});
    });
  });

  test('a Status column outside a DiveMate file drops no dive', () async {
    final dir = Directory.systemTemp.createTempSync('divinglog_status');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'logbook.sql');
    final db = sqlite3.open(path);
    db.execute(
      'CREATE TABLE Logbook (ID INTEGER, Number INTEGER, Divedate TEXT, '
      'Status INTEGER)',
    );
    db.execute("INSERT INTO Logbook VALUES (1, 7, '2024-06-01', 2)");
    db.close();
    final other = await const DivingLogSqliteParser().parse(
      File(path).readAsBytesSync(),
    );
    expect(other.entitiesOf(ImportEntityType.dives), hasLength(1));
  });

  test('a logbook whose every dive was discarded says so', () async {
    final dir = Directory.systemTemp.createTempSync('divemate_all_discarded');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'divemate.ddb');
    final db = sqlite3.open(path);
    db.execute(
      'CREATE TABLE Logbook (ID INTEGER, Number INTEGER, Divedate TEXT, '
      'TypeOfDive INTEGER, Status INTEGER)',
    );
    db.execute("INSERT INTO Logbook VALUES (1, 7, '2024-06-01', NULL, 2)");
    db.close();
    final empty = await const DivingLogSqliteParser().parse(
      File(path).readAsBytesSync(),
    );
    expect(empty.entitiesOf(ImportEntityType.dives), isEmpty);
    expect(
      empty.warnings.map((w) => w.message),
      contains(contains('discarded')),
    );
  });

  test('DiveMate-only columns are not reported missing for Diving Log', () {
    // The reverse case: these columns are DiveMate's, so a note naming them
    // would be noise on every Diving Log import.
    final notes = payload.warnings.map((w) => w.message).join('\n');
    expect(notes, isNot(contains('DepthAvg')));
    expect(notes, isNot(contains('TypeOfDive')));
    expect(notes, isNot(contains('Status')));
  });
}
