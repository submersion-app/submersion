import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/divinglog_id_list.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_profile_codec.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Reads a Diving Log 5.0 / DiveLogDT SQLite logbook.
///
/// Mirrors the `MacDiveDbReader` pattern: writes the input bytes to a temp
/// file, opens read-only, queries, and deletes the temp file on exit. Safe
/// for concurrent calls (each invocation uses a unique microsecond-suffixed
/// temp path).
///
/// Unlike the MacDive reader this probes the schema before querying.
/// DiveLogDT on macOS and iOS and Diving Log on Windows share a format but
/// have drifted, so a hard-coded column list would throw on a file we have
/// never seen. See the design doc for the reasoning.
class DivingLogDbReader {
  /// `Logbook` alone identifies the format. `Tank` and `DeletedRecords` are
  /// optional: an old or trimmed logbook may have neither, and requiring
  /// them would reject files we can read perfectly well.
  static const _requiredTables = ['Logbook'];

  /// Synchronous companion to [isDivingLogDb] for callers that have already
  /// probed the SQLite table set, matching `MacDiveDbReader.matchesTables`.
  ///
  /// Guards against claiming another flavour's file: MacDive and Shearwater
  /// are checked first at the call site, but a Core Data export could in
  /// principle carry a `Logbook` table, so those markers are excluded here
  /// too.
  static bool matchesTables(Set<String> tables) {
    final lower = tables.map((t) => t.toLowerCase()).toSet();
    const foreignMarkers = ['zdive', 'dive_details'];
    if (foreignMarkers.any(lower.contains)) return false;
    return _requiredTables.every((t) => lower.contains(t.toLowerCase()));
  }

  /// True when [bytes] is a SQLite database shaped like a Diving Log
  /// logbook. Returns false (does not throw) for non-SQLite input.
  static Future<bool> isDivingLogDb(Uint8List bytes) async {
    try {
      final caps = await readCapabilities(bytes);
      return matchesTables(caps.tables);
    } catch (_) {
      return false;
    }
  }

  /// Opens [bytes] and reports which tables and columns exist.
  static Future<DivingLogCapabilities> readCapabilities(Uint8List bytes) async {
    return _withDb(bytes, probeCapabilities);
  }

  /// Probes an already-open [db]. Split out so reads that already hold a
  /// handle do not reopen the file.
  static DivingLogCapabilities probeCapabilities(Database db) {
    final tableRows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final tables = tableRows.map<String>((r) => r['name'] as String).toSet();

    final columns = <String, Set<String>>{};
    for (final table in tables) {
      try {
        final info = db.select(
          'PRAGMA table_info(${quoteSqlIdentifier(table)})',
        );
        columns[table] = info.map<String>((r) => r['name'] as String).toSet();
      } catch (_) {
        columns[table] = const <String>{};
      }
    }
    return DivingLogCapabilities(tables: tables, columns: columns);
  }

  /// Writes [bytes] into a private temp directory, opens it read-only, runs
  /// [body], and always removes the directory.
  ///
  /// The directory comes from `createTempSync`, which the OS guarantees to
  /// be unique. A timestamp-derived name does not: two calls landing in the
  /// same microsecond would share a path, and each would delete the file the
  /// other was still reading.
  static Future<T> _withDb<T>(
    Uint8List bytes,
    T Function(Database db) body,
  ) async {
    final tmpDir = Directory.systemTemp.createTempSync('divinglog_import_');
    try {
      final tmpFile = File('${tmpDir.path}/logbook.sqlite');
      await tmpFile.writeAsBytes(bytes);
      final db = sqlite3.open(tmpFile.path, mode: OpenMode.readOnly);
      try {
        return body(db);
      } finally {
        db.close();
      }
    } finally {
      _deleteTempDir(tmpDir);
    }
  }

  /// Every `Logbook` column phase 1 wants. Any the file lacks is dropped
  /// from the SELECT and read as null.
  static const _logbookColumns = [
    'ID',
    'UUID',
    'Number',
    'Divedate',
    'Entrytime',
    'Country',
    'City',
    'Place',
    'Buddy',
    'Divemaster',
    'Comments',
    'Depth',
    'Divetime',
    'Airtemp',
    'Watertemp',
    'Weight',
    'Divesuit',
    'Computer',
    'Visibility',
    'SupplyType',
    'BuddyIDs',
    'UsedEquip',
    'Divetype',
    'PlaceID',
    'CityID',
    'CountryID',
    'ShopID',
    'TripID',
    'ProfileInt',
    'Profile',
    'Profile2',
    'Profile3',
    'Profile4',
    'Profile5',
    'TankSize',
    'PresS',
    'PresE',
    'PresW',
    'O2',
    'He',
    'DblTank',
  ];

  static const _buddyColumns = [
    'ID',
    'FirstName',
    'LastName',
    'Email',
    'Phone',
    'Mobile',
    'Comments',
    'URL',
  ];
  static const _placeColumns = [
    'ID',
    'CountryID',
    'Place',
    'Lat',
    'Lon',
    'MaxDepth',
    'WaterName',
    'Difficulty',
    'Comments',
  ];
  static const _cityColumns = ['ID', 'City'];
  static const _countryColumns = ['ID', 'Country'];
  static const _equipmentColumns = [
    'ID',
    'Object',
    'Manufacturer',
    'Serial',
    'DateP',
    'Price',
    'Weight',
    'Inactive',
    'O2ServiceDate',
    'Comments',
  ];
  static const _tripColumns = [
    'ID',
    'ShopID',
    'TripName',
    'StartDate',
    'EndDate',
    'Comments',
  ];
  static const _shopColumns = [
    'ID',
    'ShopName',
    'ShopType',
    'Street',
    'City',
    'State',
    'Zip',
    'Country',
    'Phone',
    'Email',
    'URL',
    'Comments',
  ];
  static const _diveTypeColumns = ['ID', 'Typename', 'SortOrd'];
  static const _certificationColumns = [
    'ID',
    'Brevet',
    'Org',
    'CertDate',
    'Number',
    'Instructor',
  ];
  static const _speciesColumns = ['ID', 'CommonName', 'ScientificName'];
  static const _speciesLinkColumns = ['LogID', 'FishID'];
  static const _pictureColumns = ['ID', 'LogID', 'Path', 'Description'];

  /// The reference tables, with the column each one is keyed by. A table
  /// that is absent, or present without its key, is reported and skipped.
  static const _referenceTables = <String, String>{
    'Buddy': 'ID',
    'Place': 'ID',
    'City': 'ID',
    'Country': 'ID',
    'Equipment': 'ID',
    'Trip': 'ID',
    'Shop': 'ID',
    'Divetype': 'ID',
    'Brevets': 'ID',
    'Fish': 'ID',
    'FishRel': 'LogID',
    'Pictures': 'LogID',
  };

  static const _tankColumns = [
    'LogID',
    'TankID',
    'TankSize',
    'PresS',
    'PresE',
    'PresW',
    'O2',
    'He',
    'DblTank',
  ];

  /// Reads every dive, its cylinders and its decoded profile.
  ///
  /// Throws [FormatException] when there is no `Logbook` table, which the
  /// parser turns into a fatal import warning. Everything else degrades.
  static Future<DivingLogLogbook> readAll(Uint8List bytes) async {
    return _withDb(bytes, (db) {
      final caps = probeCapabilities(db);
      if (!caps.hasTable('Logbook')) {
        throw const FormatException('No Logbook table');
      }

      final notes = <String>[];
      final missing = caps.missingColumns('Logbook', _logbookColumns);
      if (missing.isNotEmpty) {
        notes.add('Logbook is missing: ${missing.join(', ')}');
      }
      // An absent optional table is not harmless: without Tank a
      // multi-cylinder dive silently keeps only the Logbook cylinder, and
      // without DeletedRecords tombstoned dives come back. Say so.
      if (!caps.hasTable('Tank')) {
        notes.add(
          'No Tank table, so dives with several cylinders kept only the one '
          'recorded on the dive row.',
        );
      } else if (!caps.hasColumn('Tank', 'LogID')) {
        // Without the join key the table cannot be attached to any dive, so
        // it is read as if absent. Saying only "no Tank table" would be
        // wrong, and saying nothing loses every extra cylinder silently.
        notes.add(
          'The Tank table has no LogID column, so its cylinders could not be '
          'matched to dives and only the cylinder on each dive row was kept.',
        );
      } else {
        final missingTank = caps.missingColumns('Tank', _tankColumns);
        if (missingTank.isNotEmpty) {
          notes.add('Tank is missing: ${missingTank.join(', ')}');
        }
      }
      // Both halves matter: the table can be present but keyless, and
      // treating that as "nothing was deleted" quietly reimports dives the
      // diver had removed.
      if (!caps.hasTable('DeletedRecords')) {
        notes.add(
          'No DeletedRecords table, so dives the logbook had marked deleted '
          'could not be excluded.',
        );
      } else if (!caps.hasColumn('DeletedRecords', 'UUID')) {
        notes.add(
          'The DeletedRecords table has no UUID column, so dives the logbook '
          'had marked deleted could not be excluded.',
        );
      }

      final tombstones = _readTombstones(db, caps);
      final tanksByLogId = _readTanks(db, caps);

      for (final entry in _referenceTables.entries) {
        if (!caps.hasTable(entry.key)) {
          notes.add('No ${entry.key} table, so its records were not imported.');
        } else if (!caps.hasColumn(entry.key, entry.value)) {
          notes.add(
            'The ${entry.key} table has no ${entry.value} column, so its '
            'records could not be matched and were not imported.',
          );
        }
      }

      final buddies = _readReference(
        db,
        caps,
        'Buddy',
        _buddyColumns,
        'ID',
        (r) => DivingLogRawBuddy(
          id: _int(r, 'ID')!,
          firstName: _str(r, 'FirstName'),
          lastName: _str(r, 'LastName'),
          email: _str(r, 'Email'),
          phone: _str(r, 'Phone'),
          mobile: _str(r, 'Mobile'),
          comments: _str(r, 'Comments'),
          url: _str(r, 'URL'),
        ),
      );
      final places = _readReference(
        db,
        caps,
        'Place',
        _placeColumns,
        'ID',
        (r) => DivingLogRawPlace(
          id: _int(r, 'ID')!,
          countryId: _int(r, 'CountryID'),
          place: _str(r, 'Place'),
          latitude: _double(r, 'Lat'),
          longitude: _double(r, 'Lon'),
          maxDepthMeters: _double(r, 'MaxDepth'),
          waterName: _str(r, 'WaterName'),
          difficulty: _str(r, 'Difficulty'),
          comments: _str(r, 'Comments'),
        ),
      );
      final cities = _readReference(
        db,
        caps,
        'City',
        _cityColumns,
        'ID',
        (r) => _str(r, 'City'),
      );
      final countries = _readReference(
        db,
        caps,
        'Country',
        _countryColumns,
        'ID',
        (r) => _str(r, 'Country'),
      );
      final equipment = _readReference(
        db,
        caps,
        'Equipment',
        _equipmentColumns,
        'ID',
        (r) => DivingLogRawEquipment(
          id: _int(r, 'ID')!,
          object: _str(r, 'Object'),
          manufacturer: _str(r, 'Manufacturer'),
          serial: _str(r, 'Serial'),
          purchaseDate: _date(r, 'DateP'),
          price: _double(r, 'Price'),
          weightKg: _double(r, 'Weight'),
          inactive: (_int(r, 'Inactive') ?? 0) > 0,
          o2ServiceDate: _date(r, 'O2ServiceDate'),
          comments: _str(r, 'Comments'),
        ),
      );
      final trips = _readReference(
        db,
        caps,
        'Trip',
        _tripColumns,
        'ID',
        (r) => DivingLogRawTrip(
          id: _int(r, 'ID')!,
          name: _str(r, 'TripName'),
          startDate: _date(r, 'StartDate'),
          endDate: _date(r, 'EndDate'),
          shopId: _int(r, 'ShopID'),
          comments: _str(r, 'Comments'),
        ),
      );
      final shops = _readReference(
        db,
        caps,
        'Shop',
        _shopColumns,
        'ID',
        (r) => DivingLogRawShop(
          id: _int(r, 'ID')!,
          name: _str(r, 'ShopName'),
          shopType: _str(r, 'ShopType'),
          street: _str(r, 'Street'),
          city: _str(r, 'City'),
          state: _str(r, 'State'),
          zip: _str(r, 'Zip'),
          country: _str(r, 'Country'),
          phone: _str(r, 'Phone'),
          email: _str(r, 'Email'),
          url: _str(r, 'URL'),
          comments: _str(r, 'Comments'),
        ),
      );
      final diveTypes = _readReference(
        db,
        caps,
        'Divetype',
        _diveTypeColumns,
        'ID',
        (r) => DivingLogRawDiveType(
          id: _int(r, 'ID')!,
          name: _str(r, 'Typename'),
          sortOrder: _int(r, 'SortOrd'),
        ),
      );
      final certifications = _readReference(
        db,
        caps,
        'Brevets',
        _certificationColumns,
        'ID',
        (r) => DivingLogRawCertification(
          id: _int(r, 'ID')!,
          name: _str(r, 'Brevet'),
          organisation: _str(r, 'Org'),
          certDate: _date(r, 'CertDate'),
          number: _str(r, 'Number'),
          instructor: _str(r, 'Instructor'),
        ),
      );
      final species = _readReference(
        db,
        caps,
        'Fish',
        _speciesColumns,
        'ID',
        (r) => DivingLogRawSpecies(
          id: _int(r, 'ID')!,
          commonName: _str(r, 'CommonName'),
          scientificName: _str(r, 'ScientificName'),
        ),
      );
      final speciesLinks = _readSpeciesLinks(db, caps);
      final pictures = _readPictures(db, caps);

      Map<int, String> named(Map<int, String?> raw) => {
        for (final e in raw.entries)
          if (e.value case final String v) e.key: v,
      };
      final selectList = caps.selectList('Logbook', _logbookColumns);
      if (selectList.isEmpty) {
        // Another product's table can share the name. Saying so beats
        // emitting `SELECT  FROM Logbook` and surfacing a SQL syntax error
        // to a diver who only wanted to import their dives.
        throw const FormatException(
          'Logbook table has none of the expected columns',
        );
      }
      final table = caps.actualTable('Logbook')!;
      final rows = db.select(
        'SELECT $selectList FROM ${quoteSqlIdentifier(table)}',
      );

      final dives = <DivingLogRawDive>[];
      for (final row in rows) {
        final uuid = _str(row, 'UUID');
        if (uuid != null && tombstones.contains(uuid)) continue;
        final id = _int(row, 'ID');
        if (id == null) continue;

        final inline = _inlineTank(row);
        dives.add(
          DivingLogRawDive(
            id: id,
            uuid: uuid,
            number: _int(row, 'Number'),
            diveDate: _str(row, 'Divedate'),
            entryTime: _str(row, 'Entrytime'),
            country: _str(row, 'Country'),
            city: _str(row, 'City'),
            place: _str(row, 'Place'),
            buddy: _str(row, 'Buddy'),
            divemaster: _str(row, 'Divemaster'),
            comments: _str(row, 'Comments'),
            depthMeters: _double(row, 'Depth'),
            diveTimeMinutes: _double(row, 'Divetime'),
            airTempCelsius: _double(row, 'Airtemp'),
            waterTempCelsius: _double(row, 'Watertemp'),
            weightKg: _double(row, 'Weight'),
            divesuit: _str(row, 'Divesuit'),
            computer: _str(row, 'Computer'),
            visibilityCode: _int(row, 'Visibility'),
            supplyType: _str(row, 'SupplyType'),
            buddyIds: parseDivingLogIdList(_str(row, 'BuddyIDs')),
            equipmentIds: parseDivingLogIdList(_str(row, 'UsedEquip')),
            diveTypeIds: parseDivingLogIdList(_str(row, 'Divetype')),
            placeId: _int(row, 'PlaceID'),
            cityId: _int(row, 'CityID'),
            countryId: _int(row, 'CountryID'),
            shopId: _int(row, 'ShopID'),
            tripId: _int(row, 'TripID'),
            tanks: tanksByLogId[id] ?? (inline == null ? const [] : [inline]),
            samples: DivingLogProfileCodec.decode(
              intervalSeconds: _int(row, 'ProfileInt') ?? 0,
              profile: _str(row, 'Profile'),
              profile2: _str(row, 'Profile2'),
              profile3: _str(row, 'Profile3'),
              profile4: _str(row, 'Profile4'),
              profile5: _str(row, 'Profile5'),
            ),
          ),
        );
      }

      return DivingLogLogbook(
        dives: dives,
        capabilities: caps,
        schemaNotes: notes,
        buddiesById: buddies,
        placesById: places,
        cityNamesById: named(cities),
        countryNamesById: named(countries),
        equipmentById: equipment,
        tripsById: trips,
        shopsById: shops,
        diveTypesById: diveTypes,
        certifications: certifications.values.toList(),
        speciesById: species,
        speciesIdsByLogId: speciesLinks,
        picturesByLogId: pictures,
      );
    });
  }

  static Set<String> _readTombstones(Database db, DivingLogCapabilities caps) {
    if (!caps.hasTable('DeletedRecords') ||
        !caps.hasColumn('DeletedRecords', 'UUID')) {
      return const {};
    }
    final table = caps.actualTable('DeletedRecords')!;
    final column = caps.actualColumn('DeletedRecords', 'UUID')!;
    final rows = db.select(
      'SELECT ${quoteSqlIdentifier(column)} AS "UUID" '
      'FROM ${quoteSqlIdentifier(table)}',
    );
    return {
      for (final r in rows)
        if (_str(r, 'UUID') case final String u) u,
    };
  }

  static Map<int, List<DivingLogRawTank>> _readTanks(
    Database db,
    DivingLogCapabilities caps,
  ) {
    if (!caps.hasTable('Tank') || !caps.hasColumn('Tank', 'LogID')) {
      return const {};
    }
    final selectList = caps.selectList('Tank', _tankColumns);
    final table = caps.actualTable('Tank')!;
    final tankId = caps.actualColumn('Tank', 'TankID');
    final order = tankId == null
        ? ''
        : ' ORDER BY ${quoteSqlIdentifier(tankId)}';
    final rows = db.select(
      'SELECT $selectList FROM ${quoteSqlIdentifier(table)}$order',
    );

    final out = <int, List<DivingLogRawTank>>{};
    for (final row in rows) {
      final logId = _int(row, 'LogID');
      if (logId == null) continue;
      out[logId] = [
        ...?out[logId],
        DivingLogRawTank(
          tankId: _int(row, 'TankID') ?? out[logId]?.length ?? 0,
          sizeLiters: _double(row, 'TankSize'),
          startPressureBar: _double(row, 'PresS'),
          endPressureBar: _double(row, 'PresE'),
          workingPressureBar: _double(row, 'PresW'),
          o2Percent: _double(row, 'O2'),
          hePercent: _double(row, 'He'),
          isDouble: (_int(row, 'DblTank') ?? 0) > 0,
        ),
      ];
    }
    return out;
  }

  /// The cylinder carried on the `Logbook` row itself, used when the `Tank`
  /// table is absent or holds no row for this dive. Null when the row has
  /// no cylinder data at all, so a dive without gas does not gain an empty
  /// tank.
  static DivingLogRawTank? _inlineTank(Row row) {
    final size = _double(row, 'TankSize');
    final start = _double(row, 'PresS');
    final end = _double(row, 'PresE');
    final o2 = _double(row, 'O2');
    if (size == null && start == null && end == null && o2 == null) {
      return null;
    }
    return DivingLogRawTank(
      tankId: 0,
      sizeLiters: size,
      startPressureBar: start,
      endPressureBar: end,
      workingPressureBar: _double(row, 'PresW'),
      o2Percent: o2,
      hePercent: _double(row, 'He'),
      isDouble: (_int(row, 'DblTank') ?? 0) > 0,
    );
  }

  /// Reads a column that the SELECT may not have included at all, so a
  /// missing column and a null value are the same thing to callers.

  /// Runs one reference table through [build], keyed by [keyOf].
  ///
  /// Returns an empty map when the table is missing or has lost its key
  /// column; the caller has already recorded a note for that, so this does
  /// not throw. Every read goes through `selectList`, which resolves the
  /// file's own spelling of each column.
  static Map<int, T> _readReference<T>(
    Database db,
    DivingLogCapabilities caps,
    String table,
    List<String> columns,
    String keyColumn,
    T Function(Row row) build,
  ) {
    if (!caps.hasTable(table) || !caps.hasColumn(table, keyColumn)) {
      return const {};
    }
    final selectList = caps.selectList(table, columns);
    if (selectList.isEmpty) return const {};
    final actual = caps.actualTable(table)!;
    final rows = db.select(
      'SELECT $selectList FROM ${quoteSqlIdentifier(actual)}',
    );
    final out = <int, T>{};
    for (final row in rows) {
      final key = _int(row, keyColumn);
      if (key == null) continue;
      out[key] = build(row);
    }
    return out;
  }

  /// `FishRel` rows grouped by dive. Many rows share a `LogID`, so this
  /// cannot go through [_readReference].
  static Map<int, List<int>> _readSpeciesLinks(
    Database db,
    DivingLogCapabilities caps,
  ) {
    if (!caps.hasTable('FishRel') ||
        !caps.hasColumn('FishRel', 'LogID') ||
        !caps.hasColumn('FishRel', 'FishID')) {
      return const {};
    }
    final selectList = caps.selectList('FishRel', _speciesLinkColumns);
    final actual = caps.actualTable('FishRel')!;
    final rows = db.select(
      'SELECT $selectList FROM ${quoteSqlIdentifier(actual)}',
    );
    final out = <int, List<int>>{};
    for (final row in rows) {
      final logId = _int(row, 'LogID');
      final fishId = _int(row, 'FishID');
      if (logId == null || fishId == null) continue;
      out[logId] = [...?out[logId], fishId];
    }
    return out;
  }

  /// `Pictures` rows grouped by dive.
  static Map<int, List<DivingLogRawPicture>> _readPictures(
    Database db,
    DivingLogCapabilities caps,
  ) {
    if (!caps.hasTable('Pictures') || !caps.hasColumn('Pictures', 'LogID')) {
      return const {};
    }
    final selectList = caps.selectList('Pictures', _pictureColumns);
    final actual = caps.actualTable('Pictures')!;
    final rows = db.select(
      'SELECT $selectList FROM ${quoteSqlIdentifier(actual)}',
    );
    final out = <int, List<DivingLogRawPicture>>{};
    for (final row in rows) {
      final logId = _int(row, 'LogID');
      if (logId == null) continue;
      out[logId] = [
        ...?out[logId],
        DivingLogRawPicture(
          id: _int(row, 'ID') ?? 0,
          logId: logId,
          path: _str(row, 'Path'),
          description: _str(row, 'Description'),
        ),
      ];
    }
    return out;
  }

  /// Reads a `YYYY-MM-DD` date column as a wall clock, per the house
  /// convention that stored dive times carry no zone.
  static DateTime? _date(Row row, String column) {
    final raw = _str(row, column);
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return null;
    final year = int.tryParse(digits.substring(0, 4));
    final month = int.tryParse(digits.substring(4, 6));
    final day = int.tryParse(digits.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static Object? _cell(Row row, String column) {
    try {
      return row[column];
    } catch (_) {
      return null;
    }
  }

  static String? _str(Row row, String column) {
    final v = _cell(row, column);
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(Row row, String column) {
    final v = _cell(row, column);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return v == null ? null : int.tryParse(v.toString().trim());
  }

  static double? _double(Row row, String column) {
    final v = _cell(row, column);
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return v == null ? null : double.tryParse(v.toString().trim());
  }

  static void _deleteTempDir(Directory d) {
    try {
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
