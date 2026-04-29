import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Creates a minimal MacDive-shaped SQLite database at [path] and returns
/// the [File]. Populates:
///
/// - 3 dives (dive-uuid-1, dive-uuid-2, dive-uuid-3)
/// - 2 sites: "Test Reef" (salt, Mexico) and "Freshwater Springs" (fresh, USA)
/// - 2 buddies: Alice, Bob
/// - 2 tags: Reef, Photography
/// - 1 gear item: Hydros Pro (Scubapro BCD)
/// - 2 gas mixes: EAN32, EAN80
/// - 2 tanks: AL80, Steel 72
/// - 3 tank-and-gas rows (dive 1: AL80+EAN32; dive 2: AL80+EAN32;
///   dive 3: Steel 72 + EAN80)
/// - Junctions: dive 1 ↔ Alice,Bob; dive 2 ↔ Bob; dive 3 ↔ (no buddies).
///   Dive 1 ↔ Reef+Photography; Dive 2 ↔ Reef. Dive 1 ↔ gear-uuid-1.
/// - `ZMETADATA.ZIDENTIFIER = 'SystemOfUnits'` → `ZALL = 'Metric'`.
///
/// BLOB columns (`ZRAWDATA`, `ZSAMPLES`, `ZTIMEZONE`) are left NULL —
/// tests for bplist decoding use the real-sample fixtures committed in
/// `bplist_samples/`.
///
/// If a file already exists at [path] it is deleted first. Schema
/// mirrors the subset of MacDive's real schema that tasks 8-10 actually
/// query — it is NOT complete (e.g. full Core Data Z_METADATA /
/// Z_PRIMARYKEY / Z_MODELCACHE tables are omitted since the reader
/// doesn't query them).
File buildSyntheticMacDiveDb(String path) {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  final db = sqlite3.open(path);
  try {
    _createSchema(db);
    _insertFixtureRows(db);
  } finally {
    db.dispose();
  }
  return f;
}

void _createSchema(Database db) {
  db.execute('''
    CREATE TABLE ZDIVE (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZDIVENUMBER INTEGER, ZREPETITIVEDIVENUMBER INTEGER,
      ZRELATIONSHIPDIVESITE INTEGER, ZRELATIONSHIPCERTIFICATION INTEGER,
      ZMAXDEPTH FLOAT, ZAVERAGEDEPTH FLOAT,
      ZTEMPHIGH FLOAT, ZTEMPLOW FLOAT, ZAIRTEMP FLOAT,
      ZCNS FLOAT, ZSURFACEINTERVAL FLOAT, ZSAMPLEINTERVAL FLOAT,
      ZTOTALDURATION FLOAT, ZRATING FLOAT,
      ZSETPOINTHIGH FLOAT, ZSETPOINTLOW FLOAT,
      ZRAWDATE TIMESTAMP, ZUUID VARCHAR, ZIDENTIFIER VARCHAR,
      ZNOTES VARCHAR, ZWEATHER VARCHAR, ZSURFACECONDITIONS VARCHAR,
      ZCURRENT VARCHAR, ZENTRYTYPE VARCHAR, ZDIVEMASTER VARCHAR,
      ZDIVEOPERATOR VARCHAR, ZBOATNAME VARCHAR, ZBOATCAPTAIN VARCHAR,
      ZPERSONALMODE VARCHAR, ZALTITUDEMODE VARCHAR, ZSIGNATURE VARCHAR,
      ZVISIBILITY VARCHAR, ZWEIGHT VARCHAR,
      ZDECOMODEL VARCHAR, ZGASMODEL VARCHAR,
      ZCOMPUTER VARCHAR, ZCOMPUTERSERIAL VARCHAR,
      ZRAWDATA BLOB, ZSAMPLES BLOB, ZTIMEZONE BLOB
    )
  ''');
  db.execute('''
    CREATE TABLE ZDIVESITE (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZCOUNTRY VARCHAR, ZLOCATION VARCHAR,
      ZBODYOFWATER VARCHAR, ZWATERTYPE VARCHAR, ZDIFFICULTY VARCHAR,
      ZFLAG VARCHAR, ZNOTES VARCHAR, ZUUID VARCHAR,
      ZGPSLAT FLOAT, ZGPSLON FLOAT, ZALTITUDE FLOAT
    )
  ''');
  db.execute('''
    CREATE TABLE ZBUDDY (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE Z_1RELATIONSHIPDIVE (
      Z_1RELATIONSHIPBUDDIES INTEGER, Z_5RELATIONSHIPDIVE INTEGER
    )
  ''');
  db.execute('''
    CREATE TABLE ZTAG (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZUUID VARCHAR, ZIMAGE VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE Z_5RELATIONSHIPTAGS (
      Z_5RELATIONSHIPDIVES INTEGER, Z_17RELATIONSHIPTAGS INTEGER
    )
  ''');
  db.execute('''
    CREATE TABLE ZGEARITEM (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZMANUFACTURER VARCHAR, ZMODEL VARCHAR, ZSERIAL VARCHAR,
      ZTYPE VARCHAR, ZWEIGHT FLOAT, ZPRICE FLOAT,
      ZDATEPURCHASE TIMESTAMP, ZDATENEXTSERVICE TIMESTAMP,
      ZNOTES VARCHAR, ZURL VARCHAR, ZWARRANTY VARCHAR, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE Z_5RELATIONSHIPGEARITEMS (
      Z_5RELATIONSHIPGEARTODIVES INTEGER, Z_14RELATIONSHIPGEARITEMS INTEGER
    )
  ''');
  db.execute('''
    CREATE TABLE ZGAS (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZOXYGEN FLOAT, ZHELIUM FLOAT,
      ZMAXPPO2 FLOAT, ZMINPPO2 FLOAT, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE ZTANK (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZSIZE FLOAT, ZWORKINGPRESSURE FLOAT,
      ZTYPE VARCHAR, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE ZTANKANDGAS (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZRELATIONSHIPDIVE INTEGER, ZRELATIONSHIPTANK INTEGER, ZRELATIONSHIPGAS INTEGER,
      ZAIRSTART FLOAT, ZAIREND FLOAT, ZDURATION FLOAT,
      ZISDOUBLE INTEGER, ZORDER INTEGER, ZSUPPLYTYPE VARCHAR, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE ZCRITTER (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZSPECIES VARCHAR, ZSIZE FLOAT,
      ZNOTES VARCHAR, ZIMAGE VARCHAR, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE Z_3RELATIONSHIPCRITTERTODIVE (
      Z_3RELATIONSHIPDIVETOCRITTER INTEGER,
      Z_5RELATIONSHIPCRITTERTODIVE INTEGER
    )
  ''');
  db.execute('''
    CREATE TABLE ZCERTIFICATION (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZRELATIONSHIPDIVER INTEGER,
      ZNAME VARCHAR, ZAGENCY VARCHAR,
      ZATTAINED TIMESTAMP, ZEXPIRY TIMESTAMP,
      ZINSTRUCTORNAME VARCHAR, ZINSTRUCTORNUMBER VARCHAR,
      ZCARDFRONT VARCHAR, ZCARDBACK VARCHAR, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE ZSERVICERECORD (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZRELATIONSHIPGEARITEM INTEGER,
      ZSERVICEDATE TIMESTAMP, ZSERVICEDBY VARCHAR, ZNOTES VARCHAR, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE ZEVENT (
      Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZRELATIONSHIPEVENTTODIVE INTEGER,
      ZTYPE INTEGER, ZTIME FLOAT, ZDETAIL VARCHAR, ZUUID VARCHAR
    )
  ''');
  db.execute('''
    CREATE TABLE ZMETADATA (
      Z_PK INTEGER PRIMARY KEY,
      ZIDENTIFIER VARCHAR, ZALL VARCHAR
    )
  ''');
}

void _insertFixtureRows(Database db) {
  // ---- sites ----
  db.execute('''
    INSERT INTO ZDIVESITE (Z_PK, ZNAME, ZCOUNTRY, ZLOCATION,
                           ZWATERTYPE, ZGPSLAT, ZGPSLON, ZUUID)
    VALUES
      (1, 'Test Reef', 'Mexico', 'Baja California', 'saltwater',
        24.12345, -110.54321, 'site-uuid-1'),
      (2, 'Freshwater Springs', 'USA', 'Florida', 'freshwater',
        0.0, 0.0, 'site-uuid-2')
  ''');

  // ---- buddies ----
  db.execute('''
    INSERT INTO ZBUDDY (Z_PK, ZNAME, ZUUID) VALUES
      (1, 'Alice', 'buddy-uuid-1'),
      (2, 'Bob',   'buddy-uuid-2')
  ''');

  // ---- tags ----
  db.execute('''
    INSERT INTO ZTAG (Z_PK, ZNAME, ZUUID) VALUES
      (1, 'Reef',        'tag-uuid-1'),
      (2, 'Photography', 'tag-uuid-2')
  ''');

  // ---- gas mixes ----
  db.execute('''
    INSERT INTO ZGAS (Z_PK, ZNAME, ZOXYGEN, ZHELIUM, ZUUID) VALUES
      (1, 'EAN32', 0.32, 0, 'gas-uuid-1'),
      (2, 'EAN80', 0.80, 0, 'gas-uuid-2')
  ''');

  // ---- tanks ----
  db.execute('''
    INSERT INTO ZTANK (Z_PK, ZNAME, ZSIZE, ZWORKINGPRESSURE, ZUUID) VALUES
      (1, 'AL80',     77.4, 3000, 'tank-uuid-1'),
      (2, 'Steel 72', 72,   2400, 'tank-uuid-2')
  ''');

  // ---- gear ----
  db.execute('''
    INSERT INTO ZGEARITEM (Z_PK, ZNAME, ZMANUFACTURER, ZMODEL, ZTYPE, ZUUID)
    VALUES (1, 'Hydros Pro', 'Scubapro', 'Hydros Pro', 'BCD', 'gear-uuid-1')
  ''');

  // ---- dives ----
  // Core Data NSDate = seconds since 2001-01-01 UTC.
  // 2024-06-01 09:00:00 UTC = 738936000 seconds.
  const baseNsDate = 738936000.0;
  db.execute(
    '''
    INSERT INTO ZDIVE (
      Z_PK, ZDIVENUMBER, ZRELATIONSHIPDIVESITE,
      ZMAXDEPTH, ZTEMPHIGH, ZTEMPLOW, ZTOTALDURATION,
      ZRAWDATE, ZUUID, ZIDENTIFIER,
      ZNOTES, ZWEATHER, ZDIVEOPERATOR, ZBOATNAME
    ) VALUES
      (1, 42, 1, 25.4, 26.5, 20.0, 2400, ?, 'dive-uuid-1',
       '20240601090000-ABC', 'Nice reef', 'Sunny',
       'Test Operator', 'MV Test'),
      (2, 43, 1, 18.0, 25.0, 19.0, 1800, ?, 'dive-uuid-2',
       '20240601100000-ABC', NULL, 'Sunny',
       'Test Operator', 'MV Test'),
      (3, 44, 2, 12.0, 24.0, 22.0, 2100, ?, 'dive-uuid-3',
       '20240602090000-ABC', 'Springs', NULL, NULL, NULL)
  ''',
    [baseNsDate, baseNsDate + 3600, baseNsDate + 86400],
  );

  // ---- dive-buddy junctions ----
  // Dive 1: Alice + Bob. Dive 2: Bob only. Dive 3: no buddies.
  db.execute('''
    INSERT INTO Z_1RELATIONSHIPDIVE
    (Z_1RELATIONSHIPBUDDIES, Z_5RELATIONSHIPDIVE)
    VALUES (1, 1), (2, 1), (2, 2)
  ''');

  // ---- dive-tag junctions ----
  db.execute('''
    INSERT INTO Z_5RELATIONSHIPTAGS
    (Z_5RELATIONSHIPDIVES, Z_17RELATIONSHIPTAGS)
    VALUES (1, 1), (1, 2), (2, 1)
  ''');

  // ---- dive-gear junctions ----
  db.execute('''
    INSERT INTO Z_5RELATIONSHIPGEARITEMS
    (Z_5RELATIONSHIPGEARTODIVES, Z_14RELATIONSHIPGEARITEMS)
    VALUES (1, 1)
  ''');

  // ---- tank + gas linkage ----
  db.execute('''
    INSERT INTO ZTANKANDGAS (
      Z_PK, ZRELATIONSHIPDIVE, ZRELATIONSHIPTANK, ZRELATIONSHIPGAS,
      ZAIRSTART, ZAIREND, ZORDER, ZSUPPLYTYPE, ZUUID
    ) VALUES
      (1, 1, 1, 1, 3000, 1000, 0, 'Open Circuit', 'tankandgas-uuid-1'),
      (2, 2, 1, 1, 3000,  900, 0, 'Open Circuit', 'tankandgas-uuid-2'),
      (3, 3, 2, 2, 2400,  500, 0, 'Open Circuit', 'tankandgas-uuid-3')
  ''');

  // ---- units preference ----
  db.execute('''
    INSERT INTO ZMETADATA (Z_PK, ZIDENTIFIER, ZALL)
    VALUES (1, 'SystemOfUnits', 'Metric')
  ''');
}
