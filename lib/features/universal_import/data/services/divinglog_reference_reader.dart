import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_row_values.dart';

/// Everything read from Diving Log's reference tables, ready to be handed
/// to a [DivingLogLogbook].
class DivingLogReferences {
  final Map<int, DivingLogRawBuddy> buddies;
  final Map<int, DivingLogRawPlace> places;
  final Map<int, String> cityNames;
  final Map<int, String> countryNames;
  final Map<int, DivingLogRawEquipment> equipment;
  final Map<int, DivingLogRawTrip> trips;
  final Map<int, DivingLogRawShop> shops;
  final Map<int, DivingLogRawDiveType> diveTypes;
  final List<DivingLogRawCertification> certifications;
  final Map<int, DivingLogRawSpecies> species;
  final Map<int, List<int>> speciesIdsByLogId;
  final Map<int, List<DivingLogRawPicture>> picturesByLogId;

  const DivingLogReferences({
    this.buddies = const {},
    this.places = const {},
    this.cityNames = const {},
    this.countryNames = const {},
    this.equipment = const {},
    this.trips = const {},
    this.shops = const {},
    this.diveTypes = const {},
    this.certifications = const [],
    this.species = const {},
    this.speciesIdsByLogId = const {},
    this.picturesByLogId = const {},
  });
}

/// Reads Diving Log's reference tables: the people, places, gear, trips,
/// shops, dive types, certifications, species and photos that the dive
/// rows point at by id.
///
/// Split out of `DivingLogDbReader` so neither file carries the whole
/// schema. The reader there owns the dive rows and the cylinders; this one
/// owns everything a dive references.
class DivingLogReferenceReader {
  const DivingLogReferenceReader._();

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

  /// The column groups a table needs before its rows can produce anything.
  ///
  /// Each entry is a set of alternatives: the table is usable when it has
  /// at least one of them. A `Buddy` row with neither name part yields no
  /// entity, so a table carrying only `ID` and `Email` loses the whole
  /// buddy list, and reporting nothing because the key is present would
  /// hide that. Listed separately from [_tables] because a missing key is a
  /// different loss from a missing payload column.
  static const _payloadColumns = <String, List<String>>{
    'Buddy': ['FirstName', 'LastName'],
    'Place': ['Place'],
    'City': ['City'],
    'Country': ['Country'],
    'Equipment': ['Object'],
    'Trip': ['TripName'],
    'Shop': ['ShopName'],
    'Divetype': ['Typename'],
    'Brevets': ['Brevet'],
    'Fish': ['CommonName'],
    'Pictures': ['Path'],
  };

  /// The reference tables, with the columns each one cannot be read
  /// without. A table that is absent, or present without one of these, is
  /// reported and skipped. `FishRel` needs both halves of its join: with
  /// `LogID` alone every marine-life link is dropped, so listing only that
  /// would lose them without a word.
  static const _tables = <String, List<String>>{
    'Buddy': ['ID'],
    'Place': ['ID'],
    'City': ['ID'],
    'Country': ['ID'],
    'Equipment': ['ID'],
    'Trip': ['ID'],
    'Shop': ['ID'],
    'Divetype': ['ID'],
    'Brevets': ['ID'],
    'Fish': ['ID'],
    'FishRel': ['LogID', 'FishID'],
    'Pictures': ['LogID'],
  };

  /// One schema note per reference table this file cannot use, naming what
  /// the diver loses. A table that is present but keyless is a different
  /// message from one that is absent, because "no Buddy table" would be
  /// factually wrong for a table that exists.
  static List<String> schemaNotes(DivingLogCapabilities caps) {
    final notes = <String>[];
    for (final entry in _tables.entries) {
      if (!caps.hasTable(entry.key)) {
        notes.add('No ${entry.key} table, so its records were not imported.');
        continue;
      }
      final missing = [
        for (final column in entry.value)
          if (!caps.hasColumn(entry.key, column)) column,
      ];
      if (missing.isNotEmpty) {
        notes.add(
          'The ${entry.key} table has no ${missing.join(' or ')} column, so '
          'its records could not be matched and were not imported.',
        );
        continue;
      }
      // The key is there, so the rows can be read; whether they can become
      // anything is a separate question.
      final payload = _payloadColumns[entry.key];
      if (payload == null) continue;
      if (payload.any((column) => caps.hasColumn(entry.key, column))) continue;
      notes.add(
        'The ${entry.key} table has no ${payload.join(' or ')} column, so its '
        'records carried nothing to import.',
      );
    }
    return notes;
  }

  static DivingLogReferences read(Database db, DivingLogCapabilities caps) {
    final cities = _read(
      db,
      caps,
      'City',
      _cityColumns,
      'ID',
      (r) => rowString(r, 'City'),
    );
    final countries = _read(
      db,
      caps,
      'Country',
      _countryColumns,
      'ID',
      (r) => rowString(r, 'Country'),
    );
    return DivingLogReferences(
      buddies: _read(
        db,
        caps,
        'Buddy',
        _buddyColumns,
        'ID',
        (r) => DivingLogRawBuddy(
          id: rowInt(r, 'ID')!,
          firstName: rowString(r, 'FirstName'),
          lastName: rowString(r, 'LastName'),
          email: rowString(r, 'Email'),
          phone: rowString(r, 'Phone'),
          mobile: rowString(r, 'Mobile'),
          comments: rowString(r, 'Comments'),
          url: rowString(r, 'URL'),
        ),
      ),
      places: _read(
        db,
        caps,
        'Place',
        _placeColumns,
        'ID',
        (r) => DivingLogRawPlace(
          id: rowInt(r, 'ID')!,
          countryId: rowInt(r, 'CountryID'),
          place: rowString(r, 'Place'),
          // Stored as degrees, minutes and seconds text in the real
          // export, not as a decimal, so this cannot be rowDouble.
          latitude: rowCoordinate(r, 'Lat'),
          longitude: rowCoordinate(r, 'Lon'),
          maxDepthMeters: rowDouble(r, 'MaxDepth'),
          waterName: rowString(r, 'WaterName'),
          difficulty: rowString(r, 'Difficulty'),
          comments: rowString(r, 'Comments'),
        ),
      ),
      cityNames: _named(cities),
      countryNames: _named(countries),
      equipment: _read(
        db,
        caps,
        'Equipment',
        _equipmentColumns,
        'ID',
        (r) => DivingLogRawEquipment(
          id: rowInt(r, 'ID')!,
          object: rowString(r, 'Object'),
          manufacturer: rowString(r, 'Manufacturer'),
          serial: rowString(r, 'Serial'),
          purchaseDate: rowDate(r, 'DateP'),
          price: rowDouble(r, 'Price'),
          weightKg: rowDouble(r, 'Weight'),
          inactive: (rowInt(r, 'Inactive') ?? 0) > 0,
          o2ServiceDate: rowDate(r, 'O2ServiceDate'),
          comments: rowString(r, 'Comments'),
        ),
      ),
      trips: _read(
        db,
        caps,
        'Trip',
        _tripColumns,
        'ID',
        (r) => DivingLogRawTrip(
          id: rowInt(r, 'ID')!,
          name: rowString(r, 'TripName'),
          startDate: rowDate(r, 'StartDate'),
          endDate: rowDate(r, 'EndDate'),
          shopId: rowInt(r, 'ShopID'),
          comments: rowString(r, 'Comments'),
        ),
      ),
      shops: _read(
        db,
        caps,
        'Shop',
        _shopColumns,
        'ID',
        (r) => DivingLogRawShop(
          id: rowInt(r, 'ID')!,
          name: rowString(r, 'ShopName'),
          shopType: rowString(r, 'ShopType'),
          street: rowString(r, 'Street'),
          city: rowString(r, 'City'),
          state: rowString(r, 'State'),
          zip: rowString(r, 'Zip'),
          country: rowString(r, 'Country'),
          phone: rowString(r, 'Phone'),
          email: rowString(r, 'Email'),
          url: rowString(r, 'URL'),
          comments: rowString(r, 'Comments'),
        ),
      ),
      diveTypes: _read(
        db,
        caps,
        'Divetype',
        _diveTypeColumns,
        'ID',
        (r) => DivingLogRawDiveType(
          id: rowInt(r, 'ID')!,
          name: rowString(r, 'Typename'),
          sortOrder: rowInt(r, 'SortOrd'),
        ),
      ),
      certifications: _read(
        db,
        caps,
        'Brevets',
        _certificationColumns,
        'ID',
        (r) => DivingLogRawCertification(
          id: rowInt(r, 'ID')!,
          name: rowString(r, 'Brevet'),
          organisation: rowString(r, 'Org'),
          certDate: rowDate(r, 'CertDate'),
          number: rowString(r, 'Number'),
          instructor: rowString(r, 'Instructor'),
        ),
      ).values.toList(),
      species: _read(
        db,
        caps,
        'Fish',
        _speciesColumns,
        'ID',
        (r) => DivingLogRawSpecies(
          id: rowInt(r, 'ID')!,
          commonName: rowString(r, 'CommonName'),
          scientificName: rowString(r, 'ScientificName'),
        ),
      ),
      speciesIdsByLogId: _readSpeciesLinks(db, caps),
      picturesByLogId: _readPictures(db, caps),
    );
  }

  static Map<int, String> _named(Map<int, String?> raw) => {
    for (final e in raw.entries)
      if (e.value case final String v) e.key: v,
  };

  /// Runs one reference table through [build], keyed by [keyColumn].
  ///
  /// Returns an empty map when the table is missing or has lost its key
  /// column; [schemaNotes] has already reported that, so this does not
  /// throw. Every read goes through `selectList`, which resolves the file's
  /// own spelling of each column.
  static Map<int, T> _read<T>(
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
      final key = rowInt(row, keyColumn);
      if (key == null) continue;
      out[key] = build(row);
    }
    return out;
  }

  /// `FishRel` rows grouped by dive. Many rows share a `LogID`, so this
  /// cannot go through [_read].
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
      final logId = rowInt(row, 'LogID');
      final fishId = rowInt(row, 'FishID');
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
      final logId = rowInt(row, 'LogID');
      if (logId == null) continue;
      out[logId] = [
        ...?out[logId],
        DivingLogRawPicture(
          id: rowInt(row, 'ID') ?? 0,
          logId: logId,
          path: rowString(row, 'Path'),
          description: rowString(row, 'Description'),
        ),
      ];
    }
    return out;
  }
}
