import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// A synthetic DiveMate `.ddb` logbook (#3110), returned as file bytes.
///
/// The tables and columns are DiveMate 5.0's, taken from a real export; the
/// rows are invented, so no diver's data is committed. DiveMate writes Diving
/// Log 5's schema and has drifted from it, which is what these rows exercise:
///
/// - Dive 11 (#42): Attersee, everything filled in. Fresh water, rating 4,
///   German visibility, current, waves and weather text, shore entry, a boat,
///   a surface interval, two sidemount cylinders (aluminium F1, steel F2)
///   with transmitter pressures in `Profile3`, linked buddy Sam beside the
///   free-text name Toni, and an equipment set in `UsedEquip`.
/// - Dive 12 (#43): `Status` 2, discarded in DiveMate.
/// - Dive 13 (#44): no site (`PlaceID` 0), boat entry, visibility in metres,
///   an unknown surface interval (`0:0-1`), a bottom cylinder plus a deco
///   cylinder.
/// - Dive 14 (#300): the same dive as 13 imported twice in DiveMate, with a
///   different number, a slightly different profile and a linked buddy.
///
/// [withDbInfo] false drops the `DBInfo` table, and [withTypeOfDive] false
/// drops the `TypeOfDive` column, so detection's fallbacks can be tested.
Uint8List buildDiveMateDdb({
  bool withDbInfo = true,
  bool withTypeOfDive = true,
}) {
  final dir = Directory.systemTemp.createTempSync('divemate_ddb');
  try {
    final path = p.join(dir.path, 'DiveMate.ddb');
    final db = sqlite3.open(path);
    try {
      _create(db, withDbInfo: withDbInfo, withTypeOfDive: withTypeOfDive);
      _insert(db, withTypeOfDive: withTypeOfDive);
    } finally {
      db.close();
    }
    return File(path).readAsBytesSync();
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void _create(
  Database db, {
  required bool withDbInfo,
  required bool withTypeOfDive,
}) {
  if (withDbInfo) {
    db.execute(
      'CREATE TABLE DBInfo (PrgName TEXT, DBVersion TEXT, UUID TEXT, '
      'Updated TEXT)',
    );
  }
  db.execute('''
CREATE TABLE Logbook (
  ID INTEGER, Number INTEGER, Divedate TEXT, Entrytime TEXT, Country TEXT,
  Place TEXT, PlaceID INTEGER, Divetime REAL, Surfint TEXT, Comments TEXT,
  Depth REAL, PresS REAL, PresE REAL, Weight REAL, Airtemp REAL,
  Watertemp REAL, O2 REAL, MaxPPO2 REAL, ProfileInt INTEGER, Profile TEXT,
  Rating INTEGER, Computer TEXT, Water INTEGER, VisHor TEXT, UWCurrent TEXT,
  Entry INTEGER, Divesuit TEXT, Deco INTEGER, Buddy TEXT, BuddyIDs TEXT,
  UUID TEXT, Updated TEXT, DiverID INTEGER, Profile2 TEXT, UTCoffset INTEGER,
  Tanksize REAL, DepthAvg REAL, Waves TEXT, Tanktype INTEGER, Boat TEXT,
  Weather TEXT, Status INTEGER, Divetype TEXT, PresW REAL, Divemaster TEXT,
  UsedEquip TEXT, Profile3 TEXT, ShopID INTEGER, Profile4 TEXT
  ${withTypeOfDive ? ', TypeOfDive INTEGER' : ''}
)''');
  db.execute('''
CREATE TABLE Place (
  ID INTEGER, Country TEXT, Place TEXT, Lat TEXT, Lon TEXT, UUID TEXT,
  Rating INTEGER, Water INTEGER, MaxDepth REAL, Comments TEXT, Altitude TEXT,
  WaterName TEXT, Region TEXT, Difficulty TEXT
)''');
  db.execute('''
CREATE TABLE Buddy (
  ID INTEGER, FirstName TEXT, LastName TEXT, Email TEXT, Comments TEXT,
  UUID TEXT
)''');
  db.execute('''
CREATE TABLE Equipment (
  ID INTEGER, Object TEXT, Manufacturer TEXT, Serial TEXT, Price REAL,
  Comments TEXT, Inactive INTEGER, Weight REAL, UUID TEXT, Category TEXT,
  Name TEXT, Info TEXT, TypeID INTEGER, Val1 REAL, Val2 REAL, Val3 INTEGER
)''');
  db.execute(
    'CREATE TABLE Divetype (ID INTEGER, Typename TEXT, SortOrd INTEGER, '
    'UUID TEXT)',
  );
  db.execute('''
CREATE TABLE Tank (
  ID INTEGER, LogID INTEGER, TankID INTEGER, SortOrd INTEGER,
  Tanktype INTEGER, Tanksize REAL, PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, SupplyType INTEGER, UUID TEXT, Name TEXT,
  DivePhase INTEGER, BreathingTime INTEGER
)''');
}

void _insert(Database db, {required bool withTypeOfDive}) {
  if (db
      .select("SELECT 1 FROM sqlite_master WHERE name = 'DBInfo'")
      .isNotEmpty) {
    db.execute(
      "INSERT INTO DBInfo VALUES ('DiveMate', '5.0.0', 'db-uuid', NULL)",
    );
  }
  db.execute('''
INSERT INTO Place VALUES (
  7, 'Österreich', 'Attersee Ost', '47°51''0.00"N', '13°33''0.00"E',
  'site-uuid', 0, 2, 40, NULL, NULL, 'Attersee', 'Oberösterreich', NULL
)''');
  // DiveMate's placeholder for "no coordinates".
  db.execute('''
INSERT INTO Place VALUES (
  8, 'Ägypten', 'Abu Dabab', '189°60''0.00"N', '170°00''0.00"W',
  'site-2-uuid', 0, 1, 18, NULL, NULL, NULL, NULL, NULL
)''');
  db.execute(
    "INSERT INTO Buddy VALUES (4, 'Sam', 'Buddy', NULL, NULL, 'buddy-uuid')",
  );
  final gear = <String>[
    // ID, Object, Manufacturer, Serial, Price, Comments, Inactive, Weight,
    // UUID, Category, Name, Info, TypeID, Val1, Val2, Val3
    "9, 'Jet Fin', 'Scubapro', NULL, 0, NULL, 0, 0, 'g9', 'Flossen', "
        "'Fins', NULL, 0, 0, 0, 0",
    "10, NULL, NULL, NULL, 0, NULL, 0, 0, 'g10', '---SET', "
        "'Basic set', '9,13', 9, 0, 0, 0",
    "12, 'Peregrine', 'Shearwater', NULL, 0, NULL, 0, 0, 'g12', "
        "'Tauchcomputer', 'Shearwater Peregrine', 'F3:61:FE', 17, 0, 0, 0",
    "13, NULL, NULL, NULL, 0, NULL, 0, 0, 'g13', 'Flaschen', '15er Alu', "
        "NULL, 11, 15, 0, 1",
    "14, NULL, NULL, NULL, 0, NULL, 0, 0, 'g14', 'Flaschen', '12er Stahl', "
        "NULL, 11, 12, 0, 2",
    "16, NULL, NULL, NULL, 0, NULL, 0, 4, 'g16', 'Blei', '4kg Blei', NULL, "
        '12, 0, 0, 0',
    "20, NULL, NULL, NULL, 0, NULL, 0, 0, 'g20', 'Anzug', 'Trocki', NULL, "
        '0, 0, 0, 0',
    "27, NULL, 'xDeep', NULL, 0, NULL, 0, 0, 'g27', 'Wing', 'Ghost', NULL, "
        '0, 0, 0, 0',
  ];
  for (final row in gear) {
    db.execute('INSERT INTO Equipment VALUES ($row)');
  }
  db.execute("INSERT INTO Divetype VALUES (5, 'Tieftauchgang', 5, 't5')");

  final typeOfDive = withTypeOfDive;
  void dive(String values, {int? type}) {
    db.execute(
      'INSERT INTO Logbook VALUES ($values${typeOfDive ? ', ${type ?? 'NULL'}' : ''})',
    );
  }

  // Columns, in order: ID, Number, Divedate, Entrytime, Country, Place,
  // PlaceID, Divetime, Surfint, Comments, Depth, PresS, PresE, Weight,
  // Airtemp, Watertemp, O2, MaxPPO2, ProfileInt, Profile, Rating, Computer,
  // Water, VisHor, UWCurrent, Entry, Divesuit, Deco, Buddy, BuddyIDs, UUID,
  // Updated, DiverID, Profile2, UTCoffset, Tanksize, DepthAvg, Waves,
  // Tanktype, Boat, Weather, Status, Divetype, PresW, Divemaster, UsedEquip,
  // Profile3, ShopID, Profile4.
  dive(
    "11, 42, '2026-07-26', '14:29:00', 'Österreich', 'Attersee Ost', 7, "
    "48.5, '2:41', 'great dive', 31.2, 200, 60, 6.5, 26, 16.4, 32, 0.9, 30, "
    "'000000000000012300000000', 4, 'Shearwater Peregrine', 2, 'gut', "
    "'leichte Strömung', 1, NULL, 0, 'Sam, Toni', '4', 'dive-11', NULL, 2, "
    "'2202000000020000001000', 0, 11.1, 16.4, 'Wellen', 1, 'MS Seeblick', "
    "'klar', 1, NULL, 232, NULL, '10', "
    "'1995200000000019001450000000', NULL, NULL",
    type: 5,
  );
  dive(
    "12, 43, '2026-07-27', '09:00:00', NULL, NULL, 7, 30, NULL, NULL, 10, "
    'NULL, NULL, NULL, NULL, 8, NULL, NULL, NULL, NULL, 0, NULL, 0, NULL, '
    "NULL, 0, NULL, 0, NULL, NULL, 'dive-12', NULL, 2, NULL, 0, NULL, NULL, "
    'NULL, 0, NULL, NULL, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL',
  );
  dive(
    "13, 44, '2026-08-01', '10:15:00', NULL, NULL, 0, 41, '0:0-1', NULL, "
    "18.4, 210, 70, 8, 30, 27, 30, 1.0, 10, '000000000000018400000000', 3, "
    "'Shearwater Peregrine', 1, '15 m', 'keine Strömung', 2, NULL, 0, NULL, "
    "NULL, 'dive-13', NULL, 2, NULL, 0, 12, 12.1, NULL, 2, NULL, NULL, 0, "
    'NULL, 232, NULL, NULL, NULL, NULL, NULL',
    type: 0,
  );
  dive(
    "14, 300, '2026-08-01', '10:15:00', NULL, NULL, 0, 41, '0:00', NULL, "
    "18.4, 210, 70, 8, 30, 27, 30, 1.0, 10, '000000000000018300000000', 3, "
    "'Shearwater Peregrine', 1, NULL, NULL, 0, NULL, 0, NULL, '4', "
    "'dive-14', NULL, 2, NULL, 0, 12, 12.1, NULL, 2, NULL, NULL, NULL, NULL, "
    '232, NULL, NULL, NULL, NULL, NULL',
  );

  final tanks = <String>[
    // ID, LogID, TankID, SortOrd, Tanktype, Tanksize, PresS, PresE, PresW,
    // O2, He, SupplyType, UUID, Name, DivePhase, BreathingTime
    "1, 11, 1, 1, 1, 11.1, 200, 60, 207, 32, 0, 4, 't1', '80cuft Alu', 0, "
        '2900',
    "2, 11, 2, 2, 2, 12, 200, 140, 232, 32, 0, 4, 't2', '12er Faber', 0, "
        '2900',
    "3, 13, 1, 1, 2, 12, 210, 70, 232, 30, 0, 1, 't3', '12er Stahl', 0, "
        'NULL',
    "4, 13, 2, 2, 1, 5.6, 200, 150, 207, 100, 0, 0, 't4', '40cft 100%', 3, "
        'NULL',
    "5, 14, 1, 1, 2, 12, 210, 70, 232, 30, 0, 1, 't5', '12er Stahl', 0, "
        'NULL',
  ];
  for (final row in tanks) {
    db.execute('INSERT INTO Tank VALUES ($row)');
  }
}
