import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';

/// Reads a MacDive Core Data SQLite export into a [MacDiveRawLogbook].
///
/// Mirrors the [ShearwaterDbReader] pattern: writes the input bytes to a
/// temp file, opens read-only, runs per-table queries, builds the typed
/// row graph, and deletes the temp file on exit. Safe for concurrent
/// calls (each invocation uses a unique microsecond-suffixed temp path).
class MacDiveDbReader {
  /// Four tables uniquely identify a MacDive-shaped SQLite. All four
  /// must exist for [isMacDiveDb] to succeed. Picking these four rather
  /// than just `ZDIVE` rules out other Core Data exports that might
  /// have a `ZDIVE` table coincidentally.
  static const _requiredTables = ['ZDIVE', 'ZDIVESITE', 'ZGAS', 'ZTANKANDGAS'];

  /// Synchronous companion to [isMacDiveDb] for callers that have
  /// already probed the SQLite table set (e.g. the format detector
  /// runs every DB-flavor check against one probe to avoid doubling
  /// temp-file I/O).
  static bool matchesTables(Set<String> tables) =>
      _requiredTables.every(tables.contains);

  /// True when [bytes] is a SQLite database containing every table in
  /// [_requiredTables]. Returns false (doesn't throw) for non-SQLite
  /// inputs or unrelated schemas.
  static Future<bool> isMacDiveDb(Uint8List bytes) async {
    final tmpPath = _tmpPath();
    final tmpFile = File(tmpPath);
    try {
      await tmpFile.writeAsBytes(bytes);
      final db = sqlite3.open(tmpPath, mode: OpenMode.readOnly);
      try {
        final rows = db.select(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        final tables = rows.map<String>((r) => r['name'] as String).toSet();
        return _requiredTables.every(tables.contains);
      } finally {
        db.dispose();
      }
    } catch (_) {
      return false;
    } finally {
      _deleteTempFile(tmpFile);
    }
  }

  /// Reads every MacDive table relevant to the import pipeline and
  /// returns a fully populated [MacDiveRawLogbook]. The four tables in
  /// [_requiredTables] are validated up-front (a [FormatException] is
  /// thrown if any are missing) so subsequent reads on them can rely
  /// on direct `db.select` without per-call guards. For every other
  /// table (e.g. `ZCRITTER`, `ZBUDDY`, `ZGEARITEM`), a missing or
  /// unpopulated table produces an empty collection rather than an
  /// error — some MacDive schema versions omit tables the user has
  /// never touched.
  static Future<MacDiveRawLogbook> readAll(Uint8List bytes) async {
    final tmpPath = _tmpPath();
    final tmpFile = File(tmpPath);
    try {
      await tmpFile.writeAsBytes(bytes);
      final db = sqlite3.open(tmpPath, mode: OpenMode.readOnly);
      try {
        _validateRequiredTables(db);
        final unitsPreference = _readUnitsPreference(db);
        final sites = _readSites(db);
        final buddies = _readBuddies(db);
        final tags = _readTags(db);
        final gear = _readGear(db);
        final tanks = _readTanks(db);
        final gases = _readGases(db);
        final critters = _readCritters(db);
        final certifications = _readCertifications(db);
        final serviceRecords = _readServiceRecords(db);
        final events = _readEvents(db);
        final tankAndGases = _readTankAndGases(db);
        final dives = _readDives(db);

        final diveToBuddyPks = _readJunction(
          db,
          table: 'Z_1RELATIONSHIPDIVE',
          dividingColumn: 'Z_5RELATIONSHIPDIVE',
          relatedColumn: 'Z_1RELATIONSHIPBUDDIES',
        );
        final diveToTagPks = _readJunction(
          db,
          table: 'Z_5RELATIONSHIPTAGS',
          dividingColumn: 'Z_5RELATIONSHIPDIVES',
          relatedColumn: 'Z_17RELATIONSHIPTAGS',
        );
        final diveToGearPks = _readJunction(
          db,
          table: 'Z_5RELATIONSHIPGEARITEMS',
          dividingColumn: 'Z_5RELATIONSHIPGEARTODIVES',
          relatedColumn: 'Z_14RELATIONSHIPGEARITEMS',
        );
        final diveToCritterPks = _readJunction(
          db,
          table: 'Z_3RELATIONSHIPCRITTERTODIVE',
          dividingColumn: 'Z_3RELATIONSHIPDIVETOCRITTER',
          relatedColumn: 'Z_5RELATIONSHIPCRITTERTODIVE',
        );

        return MacDiveRawLogbook(
          dives: dives,
          sitesByPk: {for (final s in sites) s.pk: s},
          buddiesByPk: {for (final b in buddies) b.pk: b},
          tagsByPk: {for (final t in tags) t.pk: t},
          gearByPk: {for (final g in gear) g.pk: g},
          tanksByPk: {for (final t in tanks) t.pk: t},
          gasesByPk: {for (final g in gases) g.pk: g},
          tankAndGases: tankAndGases,
          crittersByPk: {for (final c in critters) c.pk: c},
          certifications: certifications,
          serviceRecords: serviceRecords,
          events: events,
          diveToBuddyPks: diveToBuddyPks,
          diveToTagPks: diveToTagPks,
          diveToGearPks: diveToGearPks,
          diveToCritterPks: diveToCritterPks,
          unitsPreference: unitsPreference,
        );
      } finally {
        db.dispose();
      }
    } finally {
      _deleteTempFile(tmpFile);
    }
  }

  // ---- per-table readers ----

  static String? _readUnitsPreference(Database db) {
    try {
      final rows = db.select(
        "SELECT ZALL FROM ZMETADATA WHERE ZIDENTIFIER = 'SystemOfUnits'",
      );
      if (rows.isEmpty) return null;
      return _str(rows.first['ZALL']);
    } catch (_) {
      return null;
    }
  }

  static List<MacDiveRawSite> _readSites(Database db) {
    return db.select('SELECT * FROM ZDIVESITE').map((r) {
      return MacDiveRawSite(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        name: _str(r['ZNAME']),
        country: _str(r['ZCOUNTRY']),
        location: _str(r['ZLOCATION']),
        bodyOfWater: _str(r['ZBODYOFWATER']),
        waterType: _str(r['ZWATERTYPE']),
        difficulty: _str(r['ZDIFFICULTY']),
        flag: _str(r['ZFLAG']),
        latitude: _double(r['ZGPSLAT']),
        longitude: _double(r['ZGPSLON']),
        altitude: _double(r['ZALTITUDE']),
        notes: _str(r['ZNOTES']),
      );
    }).toList();
  }

  static List<MacDiveRawBuddy> _readBuddies(Database db) {
    return _selectOrEmpty<MacDiveRawBuddy>(
      db,
      'SELECT Z_PK, ZUUID, ZNAME FROM ZBUDDY',
      (r) => MacDiveRawBuddy(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        name: _str(r['ZNAME']),
      ),
    );
  }

  static List<MacDiveRawTag> _readTags(Database db) {
    return _selectOrEmpty<MacDiveRawTag>(
      db,
      'SELECT Z_PK, ZUUID, ZNAME FROM ZTAG',
      (r) => MacDiveRawTag(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        name: _str(r['ZNAME']),
      ),
    );
  }

  static List<MacDiveRawGear> _readGear(Database db) {
    return _selectOrEmpty<MacDiveRawGear>(
      db,
      'SELECT * FROM ZGEARITEM',
      (r) => MacDiveRawGear(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        name: _str(r['ZNAME']),
        manufacturer: _str(r['ZMANUFACTURER']),
        model: _str(r['ZMODEL']),
        serial: _str(r['ZSERIAL']),
        type: _str(r['ZTYPE']),
        weight: _double(r['ZWEIGHT']),
        price: _double(r['ZPRICE']),
        datePurchase: _nsDateFromSeconds(_double(r['ZDATEPURCHASE'])),
        dateNextService: _nsDateFromSeconds(_double(r['ZDATENEXTSERVICE'])),
        notes: _str(r['ZNOTES']),
        url: _str(r['ZURL']),
        warranty: _str(r['ZWARRANTY']),
      ),
    );
  }

  static List<MacDiveRawTank> _readTanks(Database db) {
    return _selectOrEmpty<MacDiveRawTank>(
      db,
      'SELECT * FROM ZTANK',
      (r) => MacDiveRawTank(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        name: _str(r['ZNAME']),
        size: _double(r['ZSIZE']),
        workingPressure: _double(r['ZWORKINGPRESSURE']),
        type: _str(r['ZTYPE']),
      ),
    );
  }

  static List<MacDiveRawGas> _readGases(Database db) {
    return db.select('SELECT * FROM ZGAS').map((r) {
      return MacDiveRawGas(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        name: _str(r['ZNAME']),
        oxygen: _double(r['ZOXYGEN']),
        helium: _double(r['ZHELIUM']),
        maxPpO2: _double(r['ZMAXPPO2']),
        minPpO2: _double(r['ZMINPPO2']),
      );
    }).toList();
  }

  static List<MacDiveRawTankAndGas> _readTankAndGases(Database db) {
    return db
        .select('SELECT * FROM ZTANKANDGAS')
        .where((r) {
          // Skip rows with missing foreign keys (incomplete tank/gas references).
          return (r['ZRELATIONSHIPDIVE'] as int?) != null &&
              (r['ZRELATIONSHIPTANK'] as int?) != null &&
              (r['ZRELATIONSHIPGAS'] as int?) != null;
        })
        .map((r) {
          return MacDiveRawTankAndGas(
            diveFk: r['ZRELATIONSHIPDIVE'] as int,
            tankFk: r['ZRELATIONSHIPTANK'] as int,
            gasFk: r['ZRELATIONSHIPGAS'] as int,
            airStart: _double(r['ZAIRSTART']),
            airEnd: _double(r['ZAIREND']),
            duration: _double(r['ZDURATION']),
            isDouble: (r['ZISDOUBLE'] as int? ?? 0) != 0,
            order: (r['ZORDER'] as int?) ?? 0,
            supplyType: _str(r['ZSUPPLYTYPE']),
          );
        })
        .toList();
  }

  static List<MacDiveRawCritter> _readCritters(Database db) {
    return _selectOrEmpty<MacDiveRawCritter>(
      db,
      'SELECT * FROM ZCRITTER',
      (r) => MacDiveRawCritter(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        name: _str(r['ZNAME']),
        species: _str(r['ZSPECIES']),
        size: _double(r['ZSIZE']),
        notes: _str(r['ZNOTES']),
        imagePath: _str(r['ZIMAGE']),
      ),
    );
  }

  static List<MacDiveRawCertification> _readCertifications(Database db) {
    return _selectOrEmpty<MacDiveRawCertification>(
      db,
      'SELECT * FROM ZCERTIFICATION',
      (r) => MacDiveRawCertification(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        name: _str(r['ZNAME']),
        agency: _str(r['ZAGENCY']),
        attained: _nsDateFromSeconds(_double(r['ZATTAINED'])),
        expiry: _nsDateFromSeconds(_double(r['ZEXPIRY'])),
        instructorName: _str(r['ZINSTRUCTORNAME']),
        instructorNumber: _str(r['ZINSTRUCTORNUMBER']),
        cardFrontPath: _str(r['ZCARDFRONT']),
        cardBackPath: _str(r['ZCARDBACK']),
      ),
    );
  }

  static List<MacDiveRawServiceRecord> _readServiceRecords(Database db) {
    return _selectOrEmpty<MacDiveRawServiceRecord>(
      db,
      'SELECT * FROM ZSERVICERECORD',
      (r) => MacDiveRawServiceRecord(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        gearFk: r['ZRELATIONSHIPGEARITEM'] as int,
        serviceDate: _nsDateFromSeconds(_double(r['ZSERVICEDATE'])),
        servicedBy: _str(r['ZSERVICEDBY']),
        notes: _str(r['ZNOTES']),
      ),
    );
  }

  static List<MacDiveRawEvent> _readEvents(Database db) {
    return _selectOrEmpty<MacDiveRawEvent>(
      db,
      'SELECT * FROM ZEVENT',
      (r) => MacDiveRawEvent(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        diveFk: r['ZRELATIONSHIPEVENTTODIVE'] as int?,
        type: r['ZTYPE'] as int?,
        time: _double(r['ZTIME']),
        detail: _str(r['ZDETAIL']),
      ),
    );
  }

  static List<MacDiveRawDive> _readDives(Database db) {
    return db.select('SELECT * FROM ZDIVE').map((r) {
      return MacDiveRawDive(
        pk: r['Z_PK'] as int,
        uuid: _str(r['ZUUID']) ?? '',
        identifier: _str(r['ZIDENTIFIER']),
        rawDate: _nsDateFromSeconds(_double(r['ZRAWDATE'])),
        timezoneBplist: _bytes(r['ZTIMEZONE']),
        maxDepth: _double(r['ZMAXDEPTH']),
        averageDepth: _double(r['ZAVERAGEDEPTH']),
        diveNumber: r['ZDIVENUMBER'] as int?,
        repetitiveDiveNumber: r['ZREPETITIVEDIVENUMBER'] as int?,
        rating: _double(r['ZRATING']),
        airTemp: _double(r['ZAIRTEMP']),
        tempHigh: _double(r['ZTEMPHIGH']),
        tempLow: _double(r['ZTEMPLOW']),
        cns: _double(r['ZCNS']),
        surfaceInterval: _double(r['ZSURFACEINTERVAL']),
        sampleInterval: _double(r['ZSAMPLEINTERVAL']),
        totalDuration: _double(r['ZTOTALDURATION']),
        setpointHigh: _double(r['ZSETPOINTHIGH']),
        setpointLow: _double(r['ZSETPOINTLOW']),
        decoModel: _str(r['ZDECOMODEL']),
        gasModel: _str(r['ZGASMODEL']),
        computer: _str(r['ZCOMPUTER']),
        computerSerial: _str(r['ZCOMPUTERSERIAL']),
        notes: _str(r['ZNOTES']),
        weather: _str(r['ZWEATHER']),
        surfaceConditions: _str(r['ZSURFACECONDITIONS']),
        current: _str(r['ZCURRENT']),
        entryType: _str(r['ZENTRYTYPE']),
        diveMaster: _str(r['ZDIVEMASTER']),
        diveOperator: _str(r['ZDIVEOPERATOR']),
        boatName: _str(r['ZBOATNAME']),
        boatCaptain: _str(r['ZBOATCAPTAIN']),
        personalMode: _str(r['ZPERSONALMODE']),
        altitudeMode: _str(r['ZALTITUDEMODE']),
        signature: _str(r['ZSIGNATURE']),
        visibility: _str(r['ZVISIBILITY']),
        weight: _str(r['ZWEIGHT']),
        diveSiteFk: r['ZRELATIONSHIPDIVESITE'] as int?,
        certificationFk: r['ZRELATIONSHIPCERTIFICATION'] as int?,
        samplesBlob: _bytes(r['ZSAMPLES']),
        rawDataBlob: _bytes(r['ZRAWDATA']),
      );
    }).toList();
  }

  /// Reads a junction table, returning a map of LHS PK -> list of RHS PKs.
  /// Absent tables (or query errors) return an empty map - the caller
  /// treats absence and emptiness identically.
  static Map<int, List<int>> _readJunction(
    Database db, {
    required String table,
    required String dividingColumn,
    required String relatedColumn,
  }) {
    final out = <int, List<int>>{};
    try {
      final rows = db.select(
        'SELECT $dividingColumn, $relatedColumn FROM $table',
      );
      for (final r in rows) {
        final left = r[dividingColumn] as int;
        final right = r[relatedColumn] as int;
        out.putIfAbsent(left, () => <int>[]).add(right);
      }
    } catch (_) {
      // Table absent or unreadable - fall through with empty map.
    }
    return out;
  }

  static List<T> _selectOrEmpty<T>(
    Database db,
    String query,
    T Function(Row r) map,
  ) {
    try {
      return db.select(query).map(map).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Confirms every table in [_requiredTables] exists in [db]. Called
  /// at the top of [readAll] so the readers below can count on these
  /// tables being present, and so that a missing-table failure surfaces
  /// as a clear error instead of a confusing "no such table" from a
  /// later query.
  static void _validateRequiredTables(Database db) {
    final rows = db.select("SELECT name FROM sqlite_master WHERE type='table'");
    final tables = rows.map<String>((r) => r['name'] as String).toSet();
    final missing = _requiredTables
        .where((t) => !tables.contains(t))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw FormatException(
        'MacDive SQLite is missing required tables: ${missing.join(', ')}',
      );
    }
  }

  // ---- utilities ----

  static String _tmpPath() =>
      '${Directory.systemTemp.path}/macdive_import_${DateTime.now().microsecondsSinceEpoch}.sqlite';

  static void _deleteTempFile(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  static String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Core Data NSDate epoch = 2001-01-01 00:00:00 UTC. Converts a
  /// seconds-since-reference double into a UTC [DateTime] with
  /// microsecond precision.
  static DateTime? _nsDateFromSeconds(double? seconds) {
    if (seconds == null) return null;
    return DateTime.utc(
      2001,
    ).add(Duration(microseconds: (seconds * 1e6).round()));
  }

  static Uint8List? _bytes(dynamic value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }
}
