import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/divemate_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divemate_schema.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_id_list.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_profile_codec.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_reference_reader.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_row_values.dart';
import 'package:submersion/features/universal_import/data/services/sqlite_temp_copy.dart';

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
    return withTempSqliteCopy(
      bytes,
      prefix: _tempPrefix,
      body: probeCapabilities,
    );
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

  static const _tempPrefix = 'divinglog_import_';

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

  /// Columns only DiveMate writes (#3110). Read when present but never
  /// reported missing, since no Diving Log file has them.
  static const _diveMateLogbookColumns = [
    'DepthAvg',
    'TypeOfDive',
    'Status',
    'Water',
    'Rating',
    'VisHor',
    'UWCurrent',
    'Waves',
    'Weather',
    'Entry',
    'Boat',
    'Surfint',
  ];

  static const _diveMateTankColumns = [
    'Name',
    'Tanktype',
    'SupplyType',
    'DivePhase',
    'BreathingTime',
  ];

  /// Diving Log columns DiveMate never writes. Reporting them as missing
  /// from a DiveMate file would describe a loss that is not one: `Divetype`
  /// is carried by `TypeOfDive`, and the rest have no DiveMate counterpart.
  static const _notInDiveMate = {
    'Divetype',
    'City',
    'Visibility',
    'SupplyType',
    'CityID',
    'CountryID',
    'TripID',
    'Profile5',
    'He',
    'DblTank',
  };

  /// The `Status` DiveMate gives a dive the diver discarded.
  static const _discardedStatus = 2;

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
    return withTempSqliteCopy(
      bytes,
      prefix: _tempPrefix,
      body: (db) {
        final caps = probeCapabilities(db);
        if (!caps.hasTable('Logbook')) {
          throw const FormatException('No Logbook table');
        }

        // `Status` as a discard flag, `Profile3` as transmitter pressures and
        // the extra columns are DiveMate's meanings, so they are read only in
        // a DiveMate file. Another Diving Log flavour with columns of those
        // names keeps its dives and its cylinders.
        final isDiveMate = DiveMateSchema.matches(db, caps);
        List<String> reportable(List<String> missing) => isDiveMate
            ? missing.where((c) => !_notInDiveMate.contains(c)).toList()
            : missing;

        final notes = <String>[];
        final missing = reportable(
          caps.missingColumns('Logbook', _logbookColumns),
        );
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
          final missingTank = reportable(
            caps.missingColumns('Tank', _tankColumns),
          );
          if (missingTank.isNotEmpty) {
            notes.add('Tank is missing: ${missingTank.join(', ')}');
          }
        }
        // Both halves matter: the table can be present but keyless, and
        // treating that as "nothing was deleted" quietly reimports dives the
        // diver had removed.
        // DiveMate marks deleted dives with `Status`, not a tombstone table.
        if (isDiveMate) {
          // Nothing to report.
        } else if (!caps.hasTable('DeletedRecords')) {
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
        final tanksByLogId = _readTanks(db, caps, isDiveMate: isDiveMate);

        notes.addAll(
          DivingLogReferenceReader.schemaNotes(caps, isDiveMate: isDiveMate),
        );
        final references = DivingLogReferenceReader.read(
          db,
          caps,
          isDiveMate: isDiveMate,
        );

        final selectList = caps.selectList('Logbook', [
          ..._logbookColumns,
          ..._diveMateLogbookColumns,
        ]);
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
        var discarded = 0;
        for (final row in rows) {
          final uuid = rowString(row, 'UUID');
          if (uuid != null && tombstones.contains(uuid)) continue;
          final id = rowInt(row, 'ID');
          if (id == null) continue;
          if (isDiveMate && rowInt(row, 'Status') == _discardedStatus) {
            discarded++;
            continue;
          }

          final inline = _inlineTank(row);
          dives.add(
            DivingLogRawDive(
              id: id,
              uuid: uuid,
              number: rowInt(row, 'Number'),
              diveDate: rowString(row, 'Divedate'),
              entryTime: rowString(row, 'Entrytime'),
              country: rowString(row, 'Country'),
              city: rowString(row, 'City'),
              place: rowString(row, 'Place'),
              buddy: rowString(row, 'Buddy'),
              divemaster: rowString(row, 'Divemaster'),
              comments: rowString(row, 'Comments'),
              depthMeters: rowDouble(row, 'Depth'),
              avgDepthMeters: positiveOrNull(rowDouble(row, 'DepthAvg')),
              diveTimeMinutes: rowDouble(row, 'Divetime'),
              airTempCelsius: rowDouble(row, 'Airtemp'),
              waterTempCelsius: rowDouble(row, 'Watertemp'),
              weightKg: rowDouble(row, 'Weight'),
              divesuit: rowString(row, 'Divesuit'),
              computer: rowString(row, 'Computer'),
              visibilityCode: rowInt(row, 'Visibility'),
              supplyType: rowString(row, 'SupplyType'),
              buddyIds: parseDivingLogIdList(rowString(row, 'BuddyIDs')),
              equipmentIds: parseDivingLogIdList(rowString(row, 'UsedEquip')),
              diveTypeIds: _diveTypeIds(row),
              // 0 is how both programs write "none": a dive with PlaceID 0
              // has no site rather than a site the file forgot (#3110).
              placeId: _id(rowInt(row, 'PlaceID')),
              cityId: _id(rowInt(row, 'CityID')),
              countryId: _id(rowInt(row, 'CountryID')),
              shopId: _id(rowInt(row, 'ShopID')),
              tripId: _id(rowInt(row, 'TripID')),
              diveMate: isDiveMate ? _diveMateExtras(row) : null,
              tanks: tanksByLogId[id] ?? (inline == null ? const [] : [inline]),
              samples: DivingLogProfileCodec.decode(
                intervalSeconds: rowInt(row, 'ProfileInt') ?? 0,
                profile: rowString(row, 'Profile'),
                profile2: rowString(row, 'Profile2'),
                profile3: rowString(row, 'Profile3'),
                profile4: rowString(row, 'Profile4'),
                profile5: rowString(row, 'Profile5'),
                diveMateTransmitters: isDiveMate,
              ),
            ),
          );
        }

        return DivingLogLogbook(
          dives: dives,
          capabilities: caps,
          schemaNotes: notes,
          buddiesById: references.buddies,
          placesById: references.places,
          cityNamesById: references.cityNames,
          countryNamesById: references.countryNames,
          equipmentById: references.equipment,
          tripsById: references.trips,
          shopsById: references.shops,
          diveTypesById: references.diveTypes,
          certifications: references.certifications,
          speciesById: references.species,
          speciesIdsByLogId: references.speciesIdsByLogId,
          picturesByLogId: references.picturesByLogId,
          discardedDiveCount: discarded,
          isDiveMate: isDiveMate,
        );
      },
    );
  }

  /// A reference id, or null for the 0 (or negative) both programs write
  /// for "none".
  static int? _id(int? value) => value == null || value <= 0 ? null : value;

  static DiveMateDiveExtras _diveMateExtras(Row row) => DiveMateDiveExtras(
    water: rowInt(row, 'Water'),
    rating: rowInt(row, 'Rating'),
    visibility: rowString(row, 'VisHor'),
    current: rowString(row, 'UWCurrent'),
    waves: rowString(row, 'Waves'),
    weather: rowString(row, 'Weather'),
    entry: rowInt(row, 'Entry'),
    boat: rowString(row, 'Boat'),
    surfaceInterval: rowString(row, 'Surfint'),
  );

  /// Diving Log's `Divetype` id list, or DiveMate's single `TypeOfDive` id
  /// when the list is absent or blank.
  static List<int> _diveTypeIds(Row row) {
    final listed = parseDivingLogIdList(rowString(row, 'Divetype'));
    if (listed.isNotEmpty) return listed;
    final single = rowInt(row, 'TypeOfDive');
    return single == null || single <= 0 ? const [] : [single];
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
        if (rowString(r, 'UUID') case final String u) u,
    };
  }

  static Map<int, List<DivingLogRawTank>> _readTanks(
    Database db,
    DivingLogCapabilities caps, {
    required bool isDiveMate,
  }) {
    if (!caps.hasTable('Tank') || !caps.hasColumn('Tank', 'LogID')) {
      return const {};
    }
    final selectList = caps.selectList('Tank', [
      ..._tankColumns,
      if (isDiveMate) ..._diveMateTankColumns,
    ]);
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
      final logId = rowInt(row, 'LogID');
      if (logId == null) continue;
      out[logId] = [
        ...?out[logId],
        DivingLogRawTank(
          tankId: rowInt(row, 'TankID') ?? out[logId]?.length ?? 0,
          sizeLiters: rowDouble(row, 'TankSize'),
          startPressureBar: rowDouble(row, 'PresS'),
          endPressureBar: rowDouble(row, 'PresE'),
          workingPressureBar: rowDouble(row, 'PresW'),
          o2Percent: rowDouble(row, 'O2'),
          hePercent: rowDouble(row, 'He'),
          isDouble: (rowInt(row, 'DblTank') ?? 0) > 0,
          diveMate: isDiveMate
              ? DiveMateTankExtras(
                  name: rowString(row, 'Name'),
                  material: rowInt(row, 'Tanktype'),
                  supplyType: rowInt(row, 'SupplyType'),
                  divePhase: rowInt(row, 'DivePhase'),
                  breathingSeconds: rowInt(row, 'BreathingTime'),
                )
              : null,
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
    final size = rowDouble(row, 'TankSize');
    final start = rowDouble(row, 'PresS');
    final end = rowDouble(row, 'PresE');
    final o2 = rowDouble(row, 'O2');
    if (size == null && start == null && end == null && o2 == null) {
      return null;
    }
    return DivingLogRawTank(
      tankId: 0,
      sizeLiters: size,
      startPressureBar: start,
      endPressureBar: end,
      workingPressureBar: rowDouble(row, 'PresW'),
      o2Percent: o2,
      hePercent: rowDouble(row, 'He'),
      isDouble: (rowInt(row, 'DblTank') ?? 0) > 0,
    );
  }
}
