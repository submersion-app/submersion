# Diving Log / DiveLogDT SQLite Import, Phase 2, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the relational tables of a Diving Log / DiveLogDT logbook so equipment, trips, dive centers, real site and buddy records, dive types, certifications, marine life and photos all come across, closing #2187.

**Architecture:** Phase 1's reader, codec, mapper and parser are in main and unchanged in shape. This phase adds reference-table reads to `DivingLogDbReader`, a shared parser for the comma-separated id columns, and one mapper section per entity. Dives resolve references by id instead of by free text, with the text path kept only as a per-dive fallback.

**Tech Stack:** Dart, Flutter, `package:sqlite3` ^3.5.1, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-20-divinglog-sqlite-import-phase2-design.md`

## Global Constraints

- Issue link: the PR body must say `Closes #2187`. The "PR Issue Link" check blocks the merge otherwise, and the branch name must be linked too.
- Branch: `ericgriffin/github-issue-2187-phase2`, cut from `origin/main`. It has no upstream on purpose; push with `git push -u origin ericgriffin/github-issue-2187-phase2`.
- Run every command from this branch's own worktree, never the main checkout.
- No em-dash characters (U+2014) anywhere. No en-dash as sentence punctuation, no double hyphen or spaced hyphen as prose punctuation.
- No tool or vendor name, attribution line, co-author trailer or session link in any commit message, PR body, review reply, comment or file.
- No emojis in code, comments or documentation.
- Immutability: never mutate an object or list in place.
- File size: 200 to 400 lines typical, 800 maximum. `divinglog_dive_mapper.dart` is already about 320 lines, so this phase puts each new entity section in its own file rather than growing it past the limit.
- Run `dart format .` after completing any task, before committing.
- Every non-error `ImportWarning` MUST carry a `code`; the constructor asserts it. Use `ImportWarningCode.diagnostic` to record one without showing it.
- The database is metric. `Equipment.Weight` is kilograms (`0.45359237` is one pound). Do not convert.
- **Column and table lookups must go through `DivingLogCapabilities`, which matches case-insensitively.** The file spells columns its own way (`Tanksize`, not `TankSize`), and an exact-case miss silently drops data. Never index a row by a name you typed without resolving it first.
- **A zero in a packed or optional numeric field means "not recorded", not zero.** This cost phase 1 two rounds of review.
- Verify with real exit codes: `flutter test > /tmp/out.txt 2>&1; echo $?`. Piping through `tail` or `grep` reports the pipe's status, not the suite's.

## File Structure

| File | Responsibility |
| --- | --- |
| Modify `lib/features/universal_import/data/services/divinglog_raw_types.dart` | Add typed rows for the reference tables and the id-list columns. |
| Create `lib/features/universal_import/data/services/divinglog_id_list.dart` | Parse `"3,15,16"` into `List<int>`. Pure. |
| Modify `lib/features/universal_import/data/services/divinglog_db_reader.dart` | Read the reference tables and the Logbook id columns; diagnose each drifted table. |
| Create `lib/features/universal_import/data/services/divinglog_reference_mapper.dart` | Sites, buddies, trips, dive centers, dive types, certifications from the reference rows. |
| Create `lib/features/universal_import/data/services/divinglog_equipment_mapper.dart` | Equipment entities and per-dive `equipmentRefs`, typed via `typeFromName`. |
| Create `lib/features/universal_import/data/services/divinglog_sightings_mapper.dart` | `Fish` plus `FishRel` into `dive['sightings']`, and `Pictures` into media entries. |
| Modify `lib/features/universal_import/data/services/divinglog_dive_mapper.dart` | Call the new mappers; switch dive references from text to ids. |

Tests mirror each file under `test/features/universal_import/data/services/`.

---

### Task 1: The id-list parser

**Files:**
- Create: `lib/features/universal_import/data/services/divinglog_id_list.dart`
- Test: `test/features/universal_import/data/services/divinglog_id_list_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `List<int> parseDivingLogIdList(String? raw)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/services/divinglog_id_list_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_id_list.dart';

void main() {
  group('parseDivingLogIdList', () {
    test('reads a comma separated list', () {
      expect(parseDivingLogIdList('3,15,16'), [3, 15, 16]);
    });

    test('reads a single id', () {
      expect(parseDivingLogIdList('1'), [1]);
    });

    test('returns empty for null, empty and whitespace', () {
      expect(parseDivingLogIdList(null), isEmpty);
      expect(parseDivingLogIdList(''), isEmpty);
      expect(parseDivingLogIdList('   '), isEmpty);
    });

    test('tolerates spaces and trailing separators', () {
      expect(parseDivingLogIdList(' 8 , 9 ,'), [8, 9]);
    });

    test('drops entries that are not numbers', () {
      expect(parseDivingLogIdList('4,,x,5'), [4, 5]);
    });

    test('keeps order and does not deduplicate', () {
      expect(parseDivingLogIdList('5,1,5'), [5, 1, 5]);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_id_list_test.dart
```

Expected: FAIL, the library does not exist.

- [ ] **Step 3: Write the parser**

Create `lib/features/universal_import/data/services/divinglog_id_list.dart`:

```dart
/// Reads one of Diving Log's comma separated id columns.
///
/// `Logbook.BuddyIDs`, `Logbook.UsedEquip`, `Logbook.Divetype` and
/// `Trip.BuddyIDs` all hold ids this way, for example `3,15,16`. Order is
/// kept and duplicates are not removed, because the caller decides what a
/// repeat means. Entries that are not numbers are dropped rather than
/// failing the row: one unreadable id should not cost a dive its gear.
List<int> parseDivingLogIdList(String? raw) {
  if (raw == null) return const [];
  return [
    for (final part in raw.split(','))
      if (int.tryParse(part.trim()) case final int id) id,
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_id_list_test.dart
```

Expected: PASS, all six tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_id_list.dart test/features/universal_import/data/services/divinglog_id_list_test.dart
git commit -m "feat(import): parse Diving Log comma separated id columns

Refs #2187. BuddyIDs, UsedEquip and Divetype all hold ids this way, so
one reader serves them. An unreadable entry is dropped rather than
failing the row."
```

---

### Task 2: Reference row types

**Files:**
- Modify: `lib/features/universal_import/data/services/divinglog_raw_types.dart`
- Test: none of its own; Task 3 exercises these through the reader.

**Interfaces:**
- Consumes: nothing.
- Produces: `DivingLogRawBuddy`, `DivingLogRawPlace`, `DivingLogRawEquipment`, `DivingLogRawTrip`, `DivingLogRawShop`, `DivingLogRawDiveType`, `DivingLogRawCertification`, `DivingLogRawSpecies`, `DivingLogRawPicture`, and new fields on `DivingLogRawDive` and `DivingLogLogbook`.

- [ ] **Step 1: Append the reference row types**

Append to `lib/features/universal_import/data/services/divinglog_raw_types.dart`:

```dart
/// A row of the `Buddy` table. Units and spellings are the source's.
class DivingLogRawBuddy {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? comments;
  final String? url;

  const DivingLogRawBuddy({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.mobile,
    this.comments,
    this.url,
  });

  /// The display name, or null when the row has neither name part.
  String? get fullName {
    final parts = [
      firstName,
      lastName,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// A row of the `Place` table, the real dive site record.
class DivingLogRawPlace {
  final int id;
  final int? countryId;
  final String? place;
  final double? latitude;
  final double? longitude;
  final double? maxDepthMeters;
  final String? waterName;
  final String? difficulty;
  final String? comments;

  const DivingLogRawPlace({
    required this.id,
    this.countryId,
    this.place,
    this.latitude,
    this.longitude,
    this.maxDepthMeters,
    this.waterName,
    this.difficulty,
    this.comments,
  });
}

/// A row of the `Equipment` table. There is no type column: [object] is a
/// free-text name and the type has to be read from it.
class DivingLogRawEquipment {
  final int id;
  final String? object;
  final String? manufacturer;
  final String? serial;
  final DateTime? purchaseDate;
  final double? price;
  final double? weightKg;
  final bool inactive;
  final DateTime? o2ServiceDate;
  final String? comments;

  const DivingLogRawEquipment({
    required this.id,
    this.object,
    this.manufacturer,
    this.serial,
    this.purchaseDate,
    this.price,
    this.weightKg,
    this.inactive = false,
    this.o2ServiceDate,
    this.comments,
  });
}

/// A row of the `Trip` table.
class DivingLogRawTrip {
  final int id;
  final String? name;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? shopId;
  final String? comments;

  const DivingLogRawTrip({
    required this.id,
    this.name,
    this.startDate,
    this.endDate,
    this.shopId,
    this.comments,
  });
}

/// A row of the `Shop` table: a dive center, operator or hotel.
class DivingLogRawShop {
  final int id;
  final String? name;
  final String? shopType;
  final String? street;
  final String? city;
  final String? state;
  final String? zip;
  final String? country;
  final String? phone;
  final String? email;
  final String? url;
  final String? comments;

  const DivingLogRawShop({
    required this.id,
    this.name,
    this.shopType,
    this.street,
    this.city,
    this.state,
    this.zip,
    this.country,
    this.phone,
    this.email,
    this.url,
    this.comments,
  });
}

/// A row of the `Divetype` table.
class DivingLogRawDiveType {
  final int id;
  final String? name;
  final int? sortOrder;

  const DivingLogRawDiveType({required this.id, this.name, this.sortOrder});
}

/// A row of the `Brevets` table, the diver's certifications.
class DivingLogRawCertification {
  final int id;
  final String? name;
  final String? organisation;
  final DateTime? certDate;
  final String? number;
  final String? instructor;

  const DivingLogRawCertification({
    required this.id,
    this.name,
    this.organisation,
    this.certDate,
    this.number,
    this.instructor,
  });
}

/// A row of the `Fish` table, one species in the catalogue.
class DivingLogRawSpecies {
  final int id;
  final String? commonName;
  final String? scientificName;

  const DivingLogRawSpecies({
    required this.id,
    this.commonName,
    this.scientificName,
  });
}

/// A row of the `Pictures` table.
class DivingLogRawPicture {
  final int id;
  final int logId;
  final String? path;
  final String? description;

  const DivingLogRawPicture({
    required this.id,
    required this.logId,
    this.path,
    this.description,
  });
}
```

- [ ] **Step 2: Add the reference fields to the dive row**

In the same file, inside `DivingLogRawDive`, add these fields after `supplyType` and the matching constructor parameters after `this.supplyType,`:

```dart
  /// Ids from `Logbook`'s reference columns. Empty when the column is
  /// absent or blank.
  final List<int> buddyIds;
  final List<int> equipmentIds;
  final List<int> diveTypeIds;
  final int? placeId;
  final int? cityId;
  final int? countryId;
  final int? shopId;
  final int? tripId;
```

Constructor parameters:

```dart
    this.buddyIds = const [],
    this.equipmentIds = const [],
    this.diveTypeIds = const [],
    this.placeId,
    this.cityId,
    this.countryId,
    this.shopId,
    this.tripId,
```

- [ ] **Step 3: Add the reference collections to the logbook**

In the same file, inside `DivingLogLogbook`, add these fields after `capabilities` and the matching constructor parameters:

```dart
  final Map<int, DivingLogRawBuddy> buddiesById;
  final Map<int, DivingLogRawPlace> placesById;
  final Map<int, String> cityNamesById;
  final Map<int, String> countryNamesById;
  final Map<int, DivingLogRawEquipment> equipmentById;
  final Map<int, DivingLogRawTrip> tripsById;
  final Map<int, DivingLogRawShop> shopsById;
  final Map<int, DivingLogRawDiveType> diveTypesById;
  final List<DivingLogRawCertification> certifications;
  final Map<int, DivingLogRawSpecies> speciesById;

  /// Dive `Logbook.ID` to the species ids seen on it, from `FishRel`.
  final Map<int, List<int>> speciesIdsByLogId;

  /// Dive `Logbook.ID` to its `Pictures` rows.
  final Map<int, List<DivingLogRawPicture>> picturesByLogId;
```

Constructor parameters:

```dart
    this.buddiesById = const {},
    this.placesById = const {},
    this.cityNamesById = const {},
    this.countryNamesById = const {},
    this.equipmentById = const {},
    this.tripsById = const {},
    this.shopsById = const {},
    this.diveTypesById = const {},
    this.certifications = const [],
    this.speciesById = const {},
    this.speciesIdsByLogId = const {},
    this.picturesByLogId = const {},
```

- [ ] **Step 4: Verify it compiles**

```bash
flutter analyze lib/features/universal_import
```

Expected: `No issues found!`. Existing tests construct `DivingLogLogbook` with only `dives` and `capabilities`, which still works because every new field has a default.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_raw_types.dart
git commit -m "feat(import): typed rows for the Diving Log reference tables

Refs #2187. Adds Buddy, Place, Equipment, Trip, Shop, Divetype, Brevets,
Fish and Pictures rows, the id columns Logbook carries, and the lookup
maps the mapper resolves references through. Every new field defaults, so
existing callers are unaffected."
```

---

### Task 3: Read the reference tables

**Files:**
- Modify: `lib/features/universal_import/data/services/divinglog_db_reader.dart`
- Test: `test/features/universal_import/data/services/divinglog_db_reader_test.dart`

**Interfaces:**
- Consumes: `parseDivingLogIdList` from Task 1; every row type from Task 2; `DivingLogCapabilities.selectList`, `actualTable`, `actualColumn`, `missingColumns`, and the private `_str`, `_int`, `_double`, `_cell` helpers already in the reader.
- Produces: `DivingLogDbReader.readAll` returning a `DivingLogLogbook` with every reference map populated, plus a schema note per drifted reference table.

- [ ] **Step 1: Write the failing test**

Append this group to `test/features/universal_import/data/services/divinglog_db_reader_test.dart`, inside `main()`, and add the builder beside the existing ones at top level:

```dart
/// A logbook with every reference table populated and one dive wired to
/// all of them.
Uint8List buildReferenceLogbook() {
  final dir = Directory.systemTemp.createTempSync('dl_refs');
  final path = '${dir.path}/logbook.sql';
  final db = sqlite3.open(path);
  db.execute('''
CREATE TABLE Logbook (
  ID INTEGER PRIMARY KEY, UUID TEXT, Divedate TEXT, Entrytime TEXT,
  Buddy TEXT, BuddyIDs TEXT, UsedEquip TEXT, Divetype TEXT,
  PlaceID INTEGER, CityID INTEGER, CountryID INTEGER,
  ShopID INTEGER, TripID INTEGER, Depth REAL
)''');
  db.execute(
    "INSERT INTO Logbook VALUES (1, 'u1', '2024-06-01', '09:30', "
    "'Ignored Text', '1,2', '3,7', '5,6', 10, 20, 30, 40, 50, 18.5)",
  );
  db.execute('''
CREATE TABLE Buddy (
  ID INTEGER PRIMARY KEY, FirstName TEXT, LastName TEXT, Email TEXT,
  Phone TEXT, Mobile TEXT, Comments TEXT, URL TEXT
)''');
  db.execute(
    "INSERT INTO Buddy VALUES (1, 'Alice', 'Smith', 'a\@x.test', '123', "
    "NULL, 'good buddy', NULL)",
  );
  db.execute("INSERT INTO Buddy VALUES (2, 'Bob', NULL, NULL, NULL, NULL, NULL, NULL)");
  db.execute('''
CREATE TABLE Place (
  ID INTEGER PRIMARY KEY, CountryID INTEGER, Place TEXT, Lat REAL, Lon REAL,
  MaxDepth REAL, WaterName TEXT, Difficulty TEXT, Comments TEXT
)''');
  db.execute(
    "INSERT INTO Place VALUES (10, 30, 'Salt Pier', 12.13, -68.28, 24.0, "
    "'Caribbean', 'Easy', 'pier dive')",
  );
  db.execute('CREATE TABLE City (ID INTEGER PRIMARY KEY, CountryID INTEGER, City TEXT)');
  db.execute("INSERT INTO City VALUES (20, 30, 'Kralendijk')");
  db.execute('CREATE TABLE Country (ID INTEGER PRIMARY KEY, Country TEXT)');
  db.execute("INSERT INTO Country VALUES (30, 'Bonaire')");
  db.execute('''
CREATE TABLE Equipment (
  ID INTEGER PRIMARY KEY, Object TEXT, Manufacturer TEXT, Serial TEXT,
  DateP TEXT, Price REAL, Weight REAL, Inactive INTEGER, O2ServiceDate TEXT,
  Comments TEXT
)''');
  db.execute(
    "INSERT INTO Equipment VALUES (3, 'Go Sport Fins', 'ScubaPro', 'SN1', "
    "'2020-01-02', 99.0, 1.4968, 0, NULL, 'blue')",
  );
  db.execute(
    "INSERT INTO Equipment VALUES (7, 'Wet Suit (5mm full body)', "
    "'Henderson', NULL, NULL, NULL, NULL, 1, NULL, NULL)",
  );
  db.execute('''
CREATE TABLE Trip (
  ID INTEGER PRIMARY KEY, ShopID INTEGER, TripName TEXT, StartDate TEXT,
  EndDate TEXT, Comments TEXT
)''');
  db.execute(
    "INSERT INTO Trip VALUES (50, 40, 'Bonaire 2024', '2024-05-30', "
    "'2024-06-08', 'shore week')",
  );
  db.execute('''
CREATE TABLE Shop (
  ID INTEGER PRIMARY KEY, ShopName TEXT, ShopType TEXT, Street TEXT,
  City TEXT, State TEXT, Zip TEXT, Country TEXT, Phone TEXT, Email TEXT,
  URL TEXT, Comments TEXT
)''');
  db.execute(
    "INSERT INTO Shop VALUES (40, 'Dive Friends', 'Dive Center', 'Kaya', "
    "'Kralendijk', NULL, NULL, 'Bonaire', '555', 'd\@x.test', "
    "'https://x.test', 'friendly')",
  );
  db.execute('CREATE TABLE Divetype (ID INTEGER PRIMARY KEY, Typename TEXT, SortOrd INTEGER)');
  db.execute("INSERT INTO Divetype VALUES (5, 'Education', 5)");
  db.execute("INSERT INTO Divetype VALUES (6, 'Live Aboard', 6)");
  db.execute('''
CREATE TABLE Brevets (
  ID INTEGER PRIMARY KEY, Brevet TEXT, Org TEXT, CertDate TEXT,
  Number TEXT, Instructor TEXT
)''');
  db.execute(
    "INSERT INTO Brevets VALUES (1, 'Rescue Diver', 'PADI', '2023-09-08', "
    "'12345', 'Jane Doe')",
  );
  db.execute('''
CREATE TABLE Fish (
  ID INTEGER PRIMARY KEY, CommonName TEXT, ScientificName TEXT
)''');
  db.execute("INSERT INTO Fish VALUES (99, 'Giant Manta Ray', 'Mobula birostris')");
  db.execute('CREATE TABLE FishRel (ID INTEGER PRIMARY KEY, LogID INTEGER, FishID INTEGER)');
  db.execute('INSERT INTO FishRel VALUES (1, 1, 99)');
  db.execute('''
CREATE TABLE Pictures (
  ID INTEGER PRIMARY KEY, LogID INTEGER, Path TEXT, Description TEXT
)''');
  db.execute("INSERT INTO Pictures VALUES (1, 1, '/photos/dive1.jpg', 'manta')");
  db.close();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}
```

and the tests:

```dart
  group('reference tables', () {
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

    test('leaves the maps empty and notes the gap when tables are absent', () async {
      // The phase 1 fixture has Logbook and Tank only.
      final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
      expect(book.buddiesById, isEmpty);
      expect(book.equipmentById, isEmpty);
      final notes = book.schemaNotes.join(' ');
      expect(notes, contains('Buddy'));
      expect(notes, contains('Equipment'));
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_db_reader_test.dart
```

Expected: FAIL, `buddyIds` and the reference maps do not exist.

- [ ] **Step 3: Add the column lists and the reference reads**

In `divinglog_db_reader.dart`, add these constants beside `_tankColumns`:

```dart
  static const _buddyColumns = [
    'ID', 'FirstName', 'LastName', 'Email', 'Phone', 'Mobile', 'Comments',
    'URL',
  ];
  static const _placeColumns = [
    'ID', 'CountryID', 'Place', 'Lat', 'Lon', 'MaxDepth', 'WaterName',
    'Difficulty', 'Comments',
  ];
  static const _cityColumns = ['ID', 'City'];
  static const _countryColumns = ['ID', 'Country'];
  static const _equipmentColumns = [
    'ID', 'Object', 'Manufacturer', 'Serial', 'DateP', 'Price', 'Weight',
    'Inactive', 'O2ServiceDate', 'Comments',
  ];
  static const _tripColumns = [
    'ID', 'ShopID', 'TripName', 'StartDate', 'EndDate', 'Comments',
  ];
  static const _shopColumns = [
    'ID', 'ShopName', 'ShopType', 'Street', 'City', 'State', 'Zip',
    'Country', 'Phone', 'Email', 'URL', 'Comments',
  ];
  static const _diveTypeColumns = ['ID', 'Typename', 'SortOrd'];
  static const _certificationColumns = [
    'ID', 'Brevet', 'Org', 'CertDate', 'Number', 'Instructor',
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
```

Add these columns to `_logbookColumns`, after `'SupplyType',`:

```dart
    'BuddyIDs', 'UsedEquip', 'Divetype', 'PlaceID', 'CityID', 'CountryID',
    'ShopID', 'TripID',
```

Add the generic reader and a date helper:

```dart
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
```

- [ ] **Step 4: Wire the reads into readAll**

In `readAll`, immediately after the existing `final tanksByLogId = _readTanks(db, caps);` line, add:

```dart
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
        db, caps, 'Buddy', _buddyColumns, 'ID',
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
        db, caps, 'Place', _placeColumns, 'ID',
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
        db, caps, 'City', _cityColumns, 'ID', (r) => _str(r, 'City'),
      );
      final countries = _readReference(
        db, caps, 'Country', _countryColumns, 'ID', (r) => _str(r, 'Country'),
      );
      final equipment = _readReference(
        db, caps, 'Equipment', _equipmentColumns, 'ID',
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
        db, caps, 'Trip', _tripColumns, 'ID',
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
        db, caps, 'Shop', _shopColumns, 'ID',
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
        db, caps, 'Divetype', _diveTypeColumns, 'ID',
        (r) => DivingLogRawDiveType(
          id: _int(r, 'ID')!,
          name: _str(r, 'Typename'),
          sortOrder: _int(r, 'SortOrd'),
        ),
      );
      final certifications = _readReference(
        db, caps, 'Brevets', _certificationColumns, 'ID',
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
        db, caps, 'Fish', _speciesColumns, 'ID',
        (r) => DivingLogRawSpecies(
          id: _int(r, 'ID')!,
          commonName: _str(r, 'CommonName'),
          scientificName: _str(r, 'ScientificName'),
        ),
      );
      final speciesLinks = _readLinks(db, caps, _speciesLinkColumns);
      final pictures = _readPictures(db, caps);
```

`_readReference` returns `Map<int, String?>` for City and Country, so convert them where the logbook is built:

```dart
      Map<int, String> named(Map<int, String?> raw) => {
        for (final e in raw.entries)
          if (e.value case final String v) e.key: v,
      };
```

Then extend the returned `DivingLogLogbook`:

```dart
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
```

Add the two many-per-dive readers, which `_readReference` cannot serve because they are not keyed one row per id:

```dart
  /// `FishRel` rows grouped by dive. Many rows share a `LogID`, so this
  /// cannot go through [_readReference].
  static Map<int, List<int>> _readLinks(
    Database db,
    DivingLogCapabilities caps,
    List<String> columns,
  ) {
    if (!caps.hasTable('FishRel') ||
        !caps.hasColumn('FishRel', 'LogID') ||
        !caps.hasColumn('FishRel', 'FishID')) {
      return const {};
    }
    final selectList = caps.selectList('FishRel', columns);
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
```

- [ ] **Step 5: Populate the dive row's id fields**

In `readAll`, inside the per-row loop where `DivingLogRawDive` is constructed, add after `supplyType: _str(row, 'SupplyType'),`:

```dart
            buddyIds: parseDivingLogIdList(_str(row, 'BuddyIDs')),
            equipmentIds: parseDivingLogIdList(_str(row, 'UsedEquip')),
            diveTypeIds: parseDivingLogIdList(_str(row, 'Divetype')),
            placeId: _int(row, 'PlaceID'),
            cityId: _int(row, 'CityID'),
            countryId: _int(row, 'CountryID'),
            shopId: _int(row, 'ShopID'),
            tripId: _int(row, 'TripID'),
```

Add the import at the top of the file:

```dart
import 'package:submersion/features/universal_import/data/services/divinglog_id_list.dart';
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_db_reader_test.dart
```

Expected: PASS, every test including the eight new ones.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_db_reader.dart test/features/universal_import/data/services/divinglog_db_reader_test.dart
git commit -m "feat(import): read the Diving Log reference tables

Refs #2187. Buddy, Place, City, Country, Equipment, Trip, Shop, Divetype,
Brevets, Fish, FishRel and Pictures, plus the id columns Logbook carries.
Every read resolves the file's own spelling through the capability probe,
and a table that is absent or has lost its key is reported rather than
silently producing nothing."
```

---

### Task 4: Sites, buddies, trips, centers, types and certifications

**Files:**
- Create: `lib/features/universal_import/data/services/divinglog_reference_mapper.dart`
- Test: `test/features/universal_import/data/services/divinglog_reference_mapper_test.dart`

**Interfaces:**
- Consumes: the row types and lookup maps from Tasks 2 and 3.
- Produces: `DivingLogReferenceMapper.sites(DivingLogLogbook) -> Map<String, Map<String, dynamic>>` keyed by `uddfId`; `.buddies(...)`, `.trips(...)`, `.diveCenters(...)`, `.diveTypes(...)`, `.certifications(...)` with the same shape; and `DivingLogReferenceMapper.siteKeyFor(DivingLogLogbook, DivingLogRawDive) -> String?`.

The site key must be byte-identical to phase 1's so the two fold. Phase 1 builds `divinglog_site_` followed by country, city and place joined with `|` and lowercased, skipping nulls.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/services/divinglog_reference_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_reference_mapper.dart';

DivingLogLogbook logbook({
  Map<int, DivingLogRawBuddy> buddies = const {},
  Map<int, DivingLogRawPlace> places = const {},
  Map<int, String> cities = const {},
  Map<int, String> countries = const {},
  Map<int, DivingLogRawTrip> trips = const {},
  Map<int, DivingLogRawShop> shops = const {},
  Map<int, DivingLogRawDiveType> diveTypes = const {},
  List<DivingLogRawCertification> certifications = const [],
  List<DivingLogRawDive> dives = const [],
}) => DivingLogLogbook(
  dives: dives,
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
  buddiesById: buddies,
  placesById: places,
  cityNamesById: cities,
  countryNamesById: countries,
  tripsById: trips,
  shopsById: shops,
  diveTypesById: diveTypes,
  certifications: certifications,
);

void main() {
  group('sites', () {
    test('builds a site with coordinates from the Place row', () {
      final book = logbook(
        places: {
          10: const DivingLogRawPlace(
            id: 10,
            countryId: 30,
            place: 'Salt Pier',
            latitude: 12.13,
            longitude: -68.28,
            maxDepthMeters: 24.0,
          ),
        },
        countries: {30: 'Bonaire'},
        dives: [
          const DivingLogRawDive(id: 1, placeId: 10, cityId: 20, countryId: 30),
        ],
        cities: {20: 'Kralendijk'},
      );
      final sites = DivingLogReferenceMapper.sites(book);
      final site = sites.values.single;
      expect(site['name'], 'Salt Pier');
      expect(site['country'], 'Bonaire');
      expect(site['region'], 'Kralendijk');
      expect(site['latitude'], closeTo(12.13, 1e-9));
      expect(site['longitude'], closeTo(-68.28, 1e-9));
      expect(site['maxDepth'], closeTo(24.0, 1e-9));
    });

    test('keys the site exactly as phase 1 did, so the two fold', () {
      final book = logbook(
        places: {10: const DivingLogRawPlace(id: 10, place: 'Salt Pier')},
        cities: {20: 'Kralendijk'},
        countries: {30: 'Bonaire'},
        dives: [
          const DivingLogRawDive(id: 1, placeId: 10, cityId: 20, countryId: 30),
        ],
      );
      expect(
        DivingLogReferenceMapper.sites(book).keys.single,
        'divinglog_site_bonaire|kralendijk|salt pier',
      );
    });
  });

  group('buddies', () {
    test('joins the name parts and keeps contact details', () {
      final book = logbook(
        buddies: {
          1: const DivingLogRawBuddy(
            id: 1,
            firstName: 'Alice',
            lastName: 'Smith',
            email: 'a@x.test',
            phone: '123',
            comments: 'good buddy',
          ),
        },
      );
      final buddy = DivingLogReferenceMapper.buddies(book).values.single;
      expect(buddy['name'], 'Alice Smith');
      expect(buddy['uddfId'], 'Alice Smith');
      expect(buddy['email'], 'a@x.test');
      expect(buddy['phone'], '123');
      expect(buddy['notes'], 'good buddy');
    });

    test('skips a row with no name at all', () {
      final book = logbook(buddies: {1: const DivingLogRawBuddy(id: 1)});
      expect(DivingLogReferenceMapper.buddies(book), isEmpty);
    });
  });

  group('trips, centers, types, certifications', () {
    test('maps a trip with its dates', () {
      final book = logbook(
        trips: {
          50: DivingLogRawTrip(
            id: 50,
            name: 'Bonaire 2024',
            startDate: DateTime.utc(2024, 5, 30),
            endDate: DateTime.utc(2024, 6, 8),
            comments: 'shore week',
          ),
        },
      );
      final trip = DivingLogReferenceMapper.trips(book).values.single;
      expect(trip['name'], 'Bonaire 2024');
      expect(trip['startDate'], DateTime.utc(2024, 5, 30));
      expect(trip['endDate'], DateTime.utc(2024, 6, 8));
      expect(trip['notes'], 'shore week');
    });

    test('maps a shop to a dive center', () {
      final book = logbook(
        shops: {
          40: const DivingLogRawShop(
            id: 40,
            name: 'Dive Friends',
            shopType: 'Dive Center',
            city: 'Kralendijk',
            country: 'Bonaire',
            email: 'd@x.test',
            url: 'https://x.test',
          ),
        },
      );
      final center = DivingLogReferenceMapper.diveCenters(book).values.single;
      expect(center['name'], 'Dive Friends');
      expect(center['city'], 'Kralendijk');
      expect(center['country'], 'Bonaire');
      expect(center['email'], 'd@x.test');
      expect(center['website'], 'https://x.test');
    });

    test('maps dive types keyed by the shared slug', () {
      final book = logbook(
        diveTypes: {
          5: const DivingLogRawDiveType(id: 5, name: 'Live Aboard', sortOrder: 6),
        },
      );
      final types = DivingLogReferenceMapper.diveTypes(book);
      final slug = DiveTypeEntity.generateSlug('Live Aboard');
      // The importer matches dive types on this slug, and a dive references
      // it through `diveTypeIds`, so id, uddfId and the ref must all be it.
      expect(types.keys.single, slug);
      final type = types.values.single;
      expect(type['id'], slug);
      expect(type['uddfId'], slug);
      expect(type['name'], 'Live Aboard');
      expect(type['sortOrder'], 6);
      expect(type['isBuiltIn'], isFalse);
    });

    test('maps a certification with its agency and date', () {
      final book = logbook(
        certifications: [
          DivingLogRawCertification(
            id: 1,
            name: 'Rescue Diver',
            organisation: 'PADI',
            certDate: DateTime.utc(2023, 9, 8),
            number: '12345',
            instructor: 'Jane Doe',
          ),
        ],
      );
      final cert =
          DivingLogReferenceMapper.certifications(book).values.single;
      expect(cert['name'], 'Rescue Diver');
      expect(cert['agency'], 'PADI');
      expect(cert['issueDate'], DateTime.utc(2023, 9, 8));
      expect(cert['cardNumber'], '12345');
      expect(cert['instructorName'], 'Jane Doe');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_reference_mapper_test.dart
```

Expected: FAIL, the mapper does not exist.

- [ ] **Step 3: Write the mapper**

Create `lib/features/universal_import/data/services/divinglog_reference_mapper.dart`:

```dart
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Builds the payload entities that come from Diving Log's reference
/// tables, each keyed by the `uddfId` the dive maps reference.
class DivingLogReferenceMapper {
  const DivingLogReferenceMapper._();

  /// The site key for [dive], byte-identical to the one phase 1 built from
  /// the free-text columns.
  ///
  /// Phase 1 is already in main, so its key is the one to match: a
  /// re-import must fold onto the same site rather than creating a second.
  /// The parts are the country, city and place names in that order, joined
  /// with a pipe and lowercased, skipping any that are missing.
  static String? siteKeyFor(DivingLogLogbook book, DivingLogRawDive dive) {
    final parts = [
      dive.countryId == null ? null : book.countryNamesById[dive.countryId],
      dive.cityId == null ? null : book.cityNamesById[dive.cityId],
      dive.placeId == null ? null : book.placesById[dive.placeId]?.place,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return 'divinglog_site_${parts.join('|').toLowerCase()}';
  }

  /// Sites, built from the dives so a `Place` nobody dived is left out and
  /// the key matches what the dive will reference.
  static Map<String, Map<String, dynamic>> sites(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final dive in book.dives) {
      final key = siteKeyFor(book, dive);
      if (key == null || out.containsKey(key)) continue;
      final place = dive.placeId == null ? null : book.placesById[dive.placeId];
      final city = dive.cityId == null ? null : book.cityNamesById[dive.cityId];
      final country = dive.countryId == null
          ? null
          : book.countryNamesById[dive.countryId];
      final name = place?.place ?? city ?? country;
      if (name == null) continue;
      final map = <String, dynamic>{'uddfId': key, 'name': name};
      if (country != null) map['country'] = country;
      if (city != null) map['region'] = city;
      if (place?.latitude != null) map['latitude'] = place!.latitude;
      if (place?.longitude != null) map['longitude'] = place!.longitude;
      if (place?.maxDepthMeters != null) {
        map['maxDepth'] = place!.maxDepthMeters;
      }
      final notes = [
        if (place?.waterName != null) 'Water: ${place!.waterName}',
        if (place?.difficulty != null) 'Difficulty: ${place!.difficulty}',
        if (place?.comments != null) place!.comments!,
      ].join('\n');
      if (notes.isNotEmpty) map['description'] = notes;
      out[key] = map;
    }
    return out;
  }

  /// Buddies, keyed by their display name so the id maps resolve.
  static Map<String, Map<String, dynamic>> buddies(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final buddy in book.buddiesById.values) {
      final name = buddy.fullName;
      if (name == null) continue;
      final map = <String, dynamic>{'name': name, 'uddfId': name};
      if (buddy.email != null) map['email'] = buddy.email;
      final phone = buddy.phone ?? buddy.mobile;
      if (phone != null) map['phone'] = phone;
      if (buddy.comments != null) map['notes'] = buddy.comments;
      out[name] = map;
    }
    return out;
  }

  static Map<String, Map<String, dynamic>> trips(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final trip in book.tripsById.values) {
      final name = trip.name;
      if (name == null) continue;
      final key = 'divinglog_trip_${trip.id}';
      final map = <String, dynamic>{'name': name, 'uddfId': key};
      if (trip.startDate != null) map['startDate'] = trip.startDate;
      if (trip.endDate != null) map['endDate'] = trip.endDate;
      if (trip.comments != null) map['notes'] = trip.comments;
      out[key] = map;
    }
    return out;
  }

  static Map<String, Map<String, dynamic>> diveCenters(
    DivingLogLogbook book,
  ) {
    final out = <String, Map<String, dynamic>>{};
    for (final shop in book.shopsById.values) {
      final name = shop.name;
      if (name == null) continue;
      final key = 'divinglog_shop_${shop.id}';
      final map = <String, dynamic>{'name': name, 'uddfId': key};
      if (shop.street != null) map['street'] = shop.street;
      if (shop.city != null) map['city'] = shop.city;
      if (shop.state != null) map['stateProvince'] = shop.state;
      if (shop.zip != null) map['postalCode'] = shop.zip;
      if (shop.country != null) map['country'] = shop.country;
      if (shop.phone != null) map['phone'] = shop.phone;
      if (shop.email != null) map['email'] = shop.email;
      if (shop.url != null) map['website'] = shop.url;
      final notes = [
        if (shop.shopType != null) 'Type: ${shop.shopType}',
        if (shop.comments != null) shop.comments!,
      ].join('\n');
      if (notes.isNotEmpty) map['notes'] = notes;
      out[key] = map;
    }
    return out;
  }

  /// Dive types, keyed by the slug the importer matches on.
  ///
  /// MacDive already establishes the convention: the entity's `id` and
  /// `uddfId` are both `DiveTypeEntity.generateSlug(name)`, and a dive
  /// references them through `diveTypeIds` holding the same slugs. A name
  /// used as the key would reach nothing.
  static Map<String, Map<String, dynamic>> diveTypes(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final type in book.diveTypesById.values) {
      final name = type.name?.trim();
      if (name == null || name.isEmpty) continue;
      final slug = DiveTypeEntity.generateSlug(name);
      if (slug.isEmpty || out.containsKey(slug)) continue;
      out[slug] = <String, dynamic>{
        'id': slug,
        'name': name,
        'uddfId': slug,
        'isBuiltIn': false,
        if (type.sortOrder != null) 'sortOrder': type.sortOrder,
      };
    }
    return out;
  }

  /// The `diveTypeIds` for [dive]: slugs, matching [diveTypes].
  static List<String> diveTypeIdsFor(
    DivingLogLogbook book,
    DivingLogRawDive dive,
  ) {
    final out = <String>[];
    for (final id in dive.diveTypeIds) {
      final name = book.diveTypesById[id]?.name?.trim();
      if (name == null || name.isEmpty) continue;
      final slug = DiveTypeEntity.generateSlug(name);
      if (slug.isNotEmpty && !out.contains(slug)) out.add(slug);
    }
    return out;
  }

  static Map<String, Map<String, dynamic>> certifications(
    DivingLogLogbook book,
  ) {
    final out = <String, Map<String, dynamic>>{};
    for (final cert in book.certifications) {
      final name = cert.name;
      if (name == null) continue;
      final key = 'divinglog_cert_${cert.id}';
      final map = <String, dynamic>{
        'name': name,
        'uddfId': key,
        'level': name,
      };
      if (cert.organisation != null) map['agency'] = cert.organisation;
      if (cert.certDate != null) map['issueDate'] = cert.certDate;
      if (cert.number != null) map['cardNumber'] = cert.number;
      if (cert.instructor != null) map['instructorName'] = cert.instructor;
      out[key] = map;
    }
    return out;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_reference_mapper_test.dart
```

Expected: PASS, all eight tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_reference_mapper.dart test/features/universal_import/data/services/divinglog_reference_mapper_test.dart
git commit -m "feat(import): map the Diving Log reference tables to entities

Refs #2187. Sites now carry the coordinates the Place table holds, and
are keyed exactly as phase 1 keyed its text-derived sites so the two fold
instead of doubling. Buddies, trips, dive centers, dive types and
certifications come from their own tables."
```

---

### Task 5: Equipment

**Files:**
- Create: `lib/features/universal_import/data/services/divinglog_equipment_mapper.dart`
- Test: `test/features/universal_import/data/services/divinglog_equipment_mapper_test.dart`

**Interfaces:**
- Consumes: `DivingLogRawEquipment` from Task 2; `typeFromName` from `lib/features/equipment/domain/services/equipment_type_from_name.dart`, whose signature is `TypeFromName? typeFromName(String name)` with `TypeFromName = ({EquipmentType type, String? thickness})`.
- Produces: `DivingLogEquipmentMapper.entities(DivingLogLogbook) -> Map<String, Map<String, dynamic>>` keyed by `uddfId`, and `DivingLogEquipmentMapper.refsFor(DivingLogLogbook, DivingLogRawDive) -> List<String>`.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/services/divinglog_equipment_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_equipment_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

DivingLogLogbook logbook(
  Map<int, DivingLogRawEquipment> equipment, {
  List<DivingLogRawDive> dives = const [],
}) => DivingLogLogbook(
  dives: dives,
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
  equipmentById: equipment,
);

void main() {
  group('DivingLogEquipmentMapper', () {
    test('reads the type from the item name', () {
      final book = logbook({
        3: const DivingLogRawEquipment(
          id: 3,
          object: 'Go Sport Fins',
          manufacturer: 'ScubaPro',
          serial: 'SN1',
          weightKg: 1.4968,
        ),
      });
      final item = DivingLogEquipmentMapper.entities(book).values.single;
      expect(item['name'], 'Go Sport Fins');
      expect(item['brand'], 'ScubaPro');
      expect(item['serialNumber'], 'SN1');
      expect(item['weight'], closeTo(1.4968, 1e-9));
      expect(item['type'], 'fins');
    });

    test('falls back to other when the name says nothing', () {
      final book = logbook({
        1: const DivingLogRawEquipment(id: 1, object: 'Teric'),
      });
      expect(
        DivingLogEquipmentMapper.entities(book).values.single['type'],
        'other',
      );
    });

    test('marks an inactive item retired', () {
      final book = logbook({
        7: const DivingLogRawEquipment(
          id: 7,
          object: 'Wet Suit (5mm full body)',
          inactive: true,
        ),
      });
      final item = DivingLogEquipmentMapper.entities(book).values.single;
      expect(item['isRetired'], isTrue);
    });

    test('skips an item with no name', () {
      final book = logbook({1: const DivingLogRawEquipment(id: 1)});
      expect(DivingLogEquipmentMapper.entities(book), isEmpty);
    });

    test('resolves a dive UsedEquip list to refs, skipping unknown ids', () {
      final book = logbook(
        {
          3: const DivingLogRawEquipment(id: 3, object: 'Go Sport Fins'),
          7: const DivingLogRawEquipment(id: 7, object: 'Booties'),
        },
        dives: [
          const DivingLogRawDive(id: 1, equipmentIds: [3, 99, 7]),
        ],
      );
      expect(
        DivingLogEquipmentMapper.refsFor(book, book.dives.single),
        ['divinglog_gear_3', 'divinglog_gear_7'],
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_equipment_mapper_test.dart
```

Expected: FAIL, the mapper does not exist.

- [ ] **Step 3: Write the mapper**

Create `lib/features/universal_import/data/services/divinglog_equipment_mapper.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/services/equipment_type_from_name.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Maps Diving Log's `Equipment` table.
///
/// The table has no type column: `Object` is a free-text name like "Go Sport
/// Fins" or "Wet Suit (5mm full body)". [typeFromName] is the reader the
/// MacDive and CSV importers already use, so gear from any source is typed
/// the same way, and an item whose name says nothing lands on
/// [EquipmentType.other] where the Data Tools retype page can reach it.
class DivingLogEquipmentMapper {
  const DivingLogEquipmentMapper._();

  static String _uddfId(int id) => 'divinglog_gear_$id';

  static Map<String, Map<String, dynamic>> entities(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final item in book.equipmentById.values) {
      final name = item.object?.trim();
      if (name == null || name.isEmpty) continue;
      final key = _uddfId(item.id);
      final read = typeFromName(name);
      final map = <String, dynamic>{
        'name': name,
        'uddfId': key,
        'type': (read?.type ?? EquipmentType.other).name,
      };
      if (read?.thickness != null) map['thickness'] = read!.thickness;
      if (item.manufacturer != null) map['brand'] = item.manufacturer;
      if (item.serial != null) map['serialNumber'] = item.serial;
      if (item.weightKg != null) map['weight'] = item.weightKg;
      // The importer reads `purchasePrice`; `price` is silently dropped.
      if (item.price != null) map['purchasePrice'] = item.price;
      if (item.purchaseDate != null) map['purchaseDate'] = item.purchaseDate;
      if (item.inactive) map['isRetired'] = true;
      final notes = [
        if (item.o2ServiceDate != null)
          'O2 service: ${item.o2ServiceDate!.toIso8601String().substring(0, 10)}',
        if (item.comments != null) item.comments!,
      ].join('\n');
      if (notes.isNotEmpty) map['notes'] = notes;
      out[key] = map;
    }
    return out;
  }

  /// The `equipmentRefs` for [dive], in the order the source listed them.
  /// An id with no matching row is skipped rather than producing a ref the
  /// importer cannot resolve.
  static List<String> refsFor(DivingLogLogbook book, DivingLogRawDive dive) => [
    for (final id in dive.equipmentIds)
      if (book.equipmentById.containsKey(id)) _uddfId(id),
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_equipment_mapper_test.dart
```

Expected: PASS, all five tests. If the first test's expected type is not `fins`, read what `typeFromName('Go Sport Fins')` actually returns and use that value; the mapper is correct either way, the fixture is asserting the shared reader's behaviour.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_equipment_mapper.dart test/features/universal_import/data/services/divinglog_equipment_mapper_test.dart
git commit -m "feat(import): map Diving Log equipment and per-dive gear links

Refs #2187. The table has no type column, so the item name is read with
the same typeFromName the MacDive and CSV importers use and anything it
cannot read lands on other, where the retype page can reach it. UsedEquip
becomes equipmentRefs, skipping ids that match no row."
```

---

### Task 6: Marine life and photos

**Files:**
- Create: `lib/features/universal_import/data/services/divinglog_sightings_mapper.dart`
- Test: `test/features/universal_import/data/services/divinglog_sightings_mapper_test.dart`

**Interfaces:**
- Consumes: `DivingLogRawSpecies`, `DivingLogRawPicture` and the two per-dive maps from Tasks 2 and 3.
- Produces: `DivingLogSightingsMapper.sightingsFor(DivingLogLogbook, DivingLogRawDive) -> List<Map<String, dynamic>>` and `DivingLogSightingsMapper.mediaFor(DivingLogLogbook, DivingLogRawDive, int diveIndex) -> List<Map<String, dynamic>>`.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/services/divinglog_sightings_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_sightings_mapper.dart';

DivingLogLogbook logbook({
  Map<int, DivingLogRawSpecies> species = const {},
  Map<int, List<int>> links = const {},
  Map<int, List<DivingLogRawPicture>> pictures = const {},
}) => DivingLogLogbook(
  dives: const [DivingLogRawDive(id: 1)],
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
  speciesById: species,
  speciesIdsByLogId: links,
  picturesByLogId: pictures,
);

void main() {
  group('sightings', () {
    test('builds a speciesRef the importer can read back as a name', () {
      final book = logbook(
        species: {
          99: const DivingLogRawSpecies(
            id: 99,
            commonName: 'Giant Manta Ray',
            scientificName: 'Mobula birostris',
          ),
        },
        links: {
          1: [99],
        },
      );
      final sightings =
          DivingLogSightingsMapper.sightingsFor(book, book.dives.single);
      expect(sightings, hasLength(1));
      // UddfEntityImporter._speciesNameFromRef strips `species_`, splits on
      // underscores and title cases, so this round trips to the name.
      expect(sightings.single['speciesRef'], 'species_giant_manta_ray');
      expect(sightings.single['notes'], contains('Mobula birostris'));
    });

    test('skips a link whose species row is missing', () {
      final book = logbook(links: {
        1: [99],
      });
      expect(
        DivingLogSightingsMapper.sightingsFor(book, book.dives.single),
        isEmpty,
      );
    });

    test('skips a species with no common name', () {
      final book = logbook(
        species: {99: const DivingLogRawSpecies(id: 99)},
        links: {
          1: [99],
        },
      );
      expect(
        DivingLogSightingsMapper.sightingsFor(book, book.dives.single),
        isEmpty,
      );
    });

    test('returns nothing for a dive with no links', () {
      expect(
        DivingLogSightingsMapper.sightingsFor(logbook(), const DivingLogRawDive(id: 1)),
        isEmpty,
      );
    });
  });

  group('media', () {
    test('builds a media entry in the shared photo contract', () {
      final book = logbook(
        pictures: {
          1: [
            const DivingLogRawPicture(
              id: 1,
              logId: 1,
              path: '/photos/dive1.jpg',
              description: 'manta',
            ),
          ],
        },
      );
      final media =
          DivingLogSightingsMapper.mediaFor(book, book.dives.single, 4);
      expect(media, hasLength(1));
      expect(media.single['filename'], '/photos/dive1.jpg');
      expect(media.single['caption'], 'manta');
      expect(media.single['_diveIndex'], 4);
      expect(media.single['offsetSeconds'], isNull);
      expect(media.single['latitude'], isNull);
      expect(media.single['longitude'], isNull);
    });

    test('skips a picture row with no path', () {
      final book = logbook(
        pictures: {
          1: [const DivingLogRawPicture(id: 1, logId: 1)],
        },
      );
      expect(
        DivingLogSightingsMapper.mediaFor(book, book.dives.single, 0),
        isEmpty,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_sightings_mapper_test.dart
```

Expected: FAIL, the mapper does not exist.

- [ ] **Step 3: Write the mapper**

Create `lib/features/universal_import/data/services/divinglog_sightings_mapper.dart`:

```dart
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Maps Diving Log's `Fish` and `FishRel` tables into dive sightings, and
/// its `Pictures` table into media entries.
///
/// Neither needs a new `ImportEntityType`. `UddfEntityImporter` builds a
/// `MarineSighting` from each entry of `dive['sightings']`, and the photo
/// pipeline the Subsurface and MacDive parsers feed takes media entries
/// whose `filename` is the path exactly as the source recorded it, resolved
/// later against a folder the user picks in the wizard's Photos step.
class DivingLogSightingsMapper {
  const DivingLogSightingsMapper._();

  /// The importer recovers the display name by stripping `species_`,
  /// splitting on underscores and title casing, so the ref has to be the
  /// name in that shape and nothing else.
  static String speciesRef(String commonName) {
    final slug = commonName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'species_$slug';
  }

  static List<Map<String, dynamic>> sightingsFor(
    DivingLogLogbook book,
    DivingLogRawDive dive,
  ) {
    final ids = book.speciesIdsByLogId[dive.id];
    if (ids == null || ids.isEmpty) return const [];
    final out = <Map<String, dynamic>>[];
    for (final id in ids) {
      final species = book.speciesById[id];
      final common = species?.commonName?.trim();
      if (common == null || common.isEmpty) continue;
      out.add(<String, dynamic>{
        'speciesRef': speciesRef(common),
        'count': 1,
        // The sighting record holds only a name, so the scientific name has
        // nowhere else to go and would otherwise be dropped.
        'notes': species!.scientificName ?? '',
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> mediaFor(
    DivingLogLogbook book,
    DivingLogRawDive dive,
    int diveIndex,
  ) {
    final pictures = book.picturesByLogId[dive.id];
    if (pictures == null || pictures.isEmpty) return const [];
    return [
      for (final picture in pictures)
        if (picture.path case final String path when path.trim().isNotEmpty)
          <String, dynamic>{
            'filename': path,
            'caption': picture.description,
            '_diveIndex': diveIndex,
            'offsetSeconds': null,
            'latitude': null,
            'longitude': null,
          },
    ];
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_sightings_mapper_test.dart
```

Expected: PASS, all six tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_sightings_mapper.dart test/features/universal_import/data/services/divinglog_sightings_mapper_test.dart
git commit -m "feat(import): map Diving Log marine life and photos

Refs #2187. Sightings ride on the dive map, so no new entity type is
needed: the ref follows the species_ convention the entity importer reads
back into a display name, and the scientific name goes in the sighting
notes rather than being dropped. Photos use the media contract the
Subsurface and MacDive parsers already feed."
```

---

### Task 7: Wire the dive mapper to references

**Files:**
- Modify: `lib/features/universal_import/data/services/divinglog_dive_mapper.dart`
- Test: `test/features/universal_import/data/services/divinglog_dive_mapper_test.dart`

**Interfaces:**
- Consumes: every mapper from Tasks 4, 5 and 6.
- Produces: an `ImportPayload` carrying sites, buddies, equipment, trips, dive centers, dive types, certifications and media, with each dive referencing them by `uddfId`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/universal_import/data/services/divinglog_dive_mapper_test.dart`, inside `main()`:

```dart
  group('reference resolution', () {
    DivingLogLogbook wired() => DivingLogLogbook(
      dives: [
        const DivingLogRawDive(
          id: 1,
          diveDate: '2024-06-01',
          entryTime: '09:30',
          buddy: 'Ignored Text',
          buddyIds: [1],
          equipmentIds: [3],
          diveTypeIds: [5],
          placeId: 10,
          countryId: 30,
          shopId: 40,
          tripId: 50,
        ),
      ],
      capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
      buddiesById: {
        1: const DivingLogRawBuddy(id: 1, firstName: 'Alice', lastName: 'Smith'),
      },
      placesById: {
        10: const DivingLogRawPlace(
          id: 10,
          place: 'Salt Pier',
          latitude: 12.13,
          longitude: -68.28,
        ),
      },
      countryNamesById: {30: 'Bonaire'},
      equipmentById: {
        3: const DivingLogRawEquipment(id: 3, object: 'Go Sport Fins'),
      },
      tripsById: {50: const DivingLogRawTrip(id: 50, name: 'Bonaire 2024')},
      shopsById: {40: const DivingLogRawShop(id: 40, name: 'Dive Friends')},
      diveTypesById: {
        5: const DivingLogRawDiveType(id: 5, name: 'Education'),
      },
      certifications: [
        const DivingLogRawCertification(id: 1, name: 'Rescue Diver'),
      ],
      speciesById: {
        99: const DivingLogRawSpecies(id: 99, commonName: 'Giant Manta Ray'),
      },
      speciesIdsByLogId: {
        1: [99],
      },
      picturesByLogId: {
        1: [
          const DivingLogRawPicture(id: 1, logId: 1, path: '/p/1.jpg'),
        ],
      },
    );

    test('emits every reference entity', () {
      final payload = DivingLogDiveMapper.toPayload(wired());
      expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.buddies), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.equipment), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.trips), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.diveCenters), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.diveTypes), hasLength(1));
      expect(
        payload.entitiesOf(ImportEntityType.certifications),
        hasLength(1),
      );
      expect(payload.entitiesOf(ImportEntityType.media), hasLength(1));
    });

    test('a dive with BuddyIDs ignores its free text buddy column', () {
      final payload = DivingLogDiveMapper.toPayload(wired());
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['buddyRefs'], ['Alice Smith']);
      final names = payload
          .entitiesOf(ImportEntityType.buddies)
          .map((b) => b['name'])
          .toList();
      expect(names, ['Alice Smith']);
      expect(names, isNot(contains('Ignored Text')));
    });

    test('links the dive to its references by uddfId', () {
      final payload = DivingLogDiveMapper.toPayload(wired());
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['equipmentRefs'], ['divinglog_gear_3']);
      expect(d['tripRef'], 'divinglog_trip_50');
      expect(d['diveCenterRef'], 'divinglog_shop_40');
      expect(d['diveTypeIds'], [DiveTypeEntity.generateSlug('Education')]);
      expect(d['site']['uddfId'], 'divinglog_site_bonaire|salt pier');
      expect((d['sightings'] as List).single['speciesRef'],
          'species_giant_manta_ray');
    });

    test('reports ids that match no record, once per kind', () {
      final book = DivingLogLogbook(
        dives: [
          const DivingLogRawDive(
            id: 1,
            diveDate: '2024-06-01',
            buddyIds: [1, 99],
            equipmentIds: [42],
          ),
        ],
        capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
        buddiesById: {
          1: const DivingLogRawBuddy(id: 1, firstName: 'Alice'),
        },
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      final messages = payload.warnings.map((w) => w.message).join(' ');
      expect(messages, contains('1 buddy reference(s)'));
      expect(messages, contains('1 equipment reference(s)'));
    });

    test('still uses the text column when a dive has no BuddyIDs', () {
      final book = DivingLogLogbook(
        dives: [
          const DivingLogRawDive(
            id: 1,
            diveDate: '2024-06-01',
            buddy: 'Carol',
          ),
        ],
        capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      expect(
        payload.entitiesOf(ImportEntityType.dives).single['buddyRefs'],
        ['Carol'],
      );
    });
  });
```

Add these imports to the test file:

```dart
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
```

(already present) and nothing else.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_dive_mapper_test.dart
```

Expected: FAIL, the payload has no equipment, trips, centers, dive types, certifications or media.

- [ ] **Step 3: Wire the mappers in**

In `divinglog_dive_mapper.dart`, add the imports:

```dart
import 'package:submersion/features/universal_import/data/services/divinglog_equipment_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_reference_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_sightings_mapper.dart';
```

At the top of `toPayload`, after the existing local collections are declared, add:

```dart
    // Counts of ids that matched no row, by kind, reported once each.
    final unresolved = <String, int>{};
    final referenceSites = DivingLogReferenceMapper.sites(logbook);
    final referenceBuddies = DivingLogReferenceMapper.buddies(logbook);
    final equipment = DivingLogEquipmentMapper.entities(logbook);
    final trips = DivingLogReferenceMapper.trips(logbook);
    final diveCenters = DivingLogReferenceMapper.diveCenters(logbook);
    final referenceDiveTypes = DivingLogReferenceMapper.diveTypes(logbook);
    final certifications = DivingLogReferenceMapper.certifications(logbook);
    final media = <Map<String, dynamic>>[];
```

Inside the per-dive loop, replace the site block with one that prefers the reference key, and replace the buddy block so ids win. The site block becomes:

```dart
      final siteKey =
          DivingLogReferenceMapper.siteKeyFor(logbook, raw) ?? _siteKey(raw);
      if (siteKey != null) {
        if (!referenceSites.containsKey(siteKey)) {
          sitesByKey.putIfAbsent(siteKey, () {
            final site = <String, dynamic>{
              'uddfId': siteKey,
              'name': raw.place ?? raw.city ?? raw.country!,
            };
            if (raw.country != null) site['country'] = raw.country;
            if (raw.city != null) site['region'] = raw.city;
            return site;
          });
        }
        map['site'] = <String, dynamic>{'uddfId': siteKey};
      }
```

The buddy block becomes:

```dart
      // Ids win. A dive that names its buddies by id must not also emit the
      // free-text column, or the same person arrives twice under two
      // spellings and the dive links to only one of them.
      final idBuddyRefs = [
        for (final id in raw.buddyIds)
          if (logbook.buddiesById[id]?.fullName case final String name) name,
      ];
      final buddyRefs = idBuddyRefs.isNotEmpty
          ? idBuddyRefs
          : _refs(_names(raw.buddy), buddiesByName);
      final guideRefs = _refs(_names(raw.divemaster), buddiesByName);
      if (buddyRefs.isNotEmpty) map['buddyRefs'] = buddyRefs;
      if (guideRefs.isNotEmpty) map['diveGuideRefs'] = guideRefs;
```

Still inside the loop, after the tag block, add the remaining references:

```dart
      final gearRefs = DivingLogEquipmentMapper.refsFor(logbook, raw);
      if (gearRefs.isNotEmpty) map['equipmentRefs'] = gearRefs;

      if (raw.tripId != null &&
          trips.containsKey('divinglog_trip_${raw.tripId}')) {
        map['tripRef'] = 'divinglog_trip_${raw.tripId}';
      }
      if (raw.shopId != null &&
          diveCenters.containsKey('divinglog_shop_${raw.shopId}')) {
        map['diveCenterRef'] = 'divinglog_shop_${raw.shopId}';
      }
      final typeIds = DivingLogReferenceMapper.diveTypeIdsFor(logbook, raw);
      if (typeIds.isNotEmpty) map['diveTypeIds'] = typeIds;

      final sightings = DivingLogSightingsMapper.sightingsFor(logbook, raw);
      if (sightings.isNotEmpty) map['sightings'] = sightings;

      media.addAll(
        DivingLogSightingsMapper.mediaFor(logbook, raw, dives.length),
      );

      // An id pointing at a row the file does not contain is skipped above.
      // Counting it here turns a silent drop into one diagnostic per kind,
      // which the spec requires and which is how this importer's earlier
      // data losses went unnoticed.
      unresolved['buddy'] = (unresolved['buddy'] ?? 0) +
          raw.buddyIds.where((i) => !logbook.buddiesById.containsKey(i)).length;
      unresolved['equipment'] = (unresolved['equipment'] ?? 0) +
          raw.equipmentIds
              .where((i) => !logbook.equipmentById.containsKey(i))
              .length;
      unresolved['dive type'] = (unresolved['dive type'] ?? 0) +
          raw.diveTypeIds
              .where((i) => !logbook.diveTypesById.containsKey(i))
              .length;
```

`dives.length` is the index this dive will occupy, because the map is added to `dives` at the end of the loop body.

Finally, merge the reference entities into the payload. Replace the entity assembly block with:

```dart
    for (final entry in unresolved.entries) {
      if (entry.value == 0) continue;
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.diagnostic,
          message:
              '${entry.value} ${entry.key} reference(s) pointed at records '
              'the file does not contain and were skipped.',
          count: entry.value,
        ),
      );
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (dives.isNotEmpty) entities[ImportEntityType.dives] = dives;
    final allSites = {...sitesByKey, ...referenceSites};
    if (allSites.isNotEmpty) {
      entities[ImportEntityType.sites] = allSites.values.toList();
    }
    final allBuddies = {...buddiesByName.map((k, v) => MapEntry(v['name'] as String, v)), ...referenceBuddies};
    if (allBuddies.isNotEmpty) {
      entities[ImportEntityType.buddies] = allBuddies.values.toList();
    }
    if (tagsByName.isNotEmpty) {
      entities[ImportEntityType.tags] = tagsByName.values.toList();
    }
    if (equipment.isNotEmpty) {
      entities[ImportEntityType.equipment] = equipment.values.toList();
    }
    if (trips.isNotEmpty) {
      entities[ImportEntityType.trips] = trips.values.toList();
    }
    if (diveCenters.isNotEmpty) {
      entities[ImportEntityType.diveCenters] = diveCenters.values.toList();
    }
    if (referenceDiveTypes.isNotEmpty) {
      entities[ImportEntityType.diveTypes] = referenceDiveTypes.values.toList();
    }
    if (certifications.isNotEmpty) {
      entities[ImportEntityType.certifications] =
          certifications.values.toList();
    }
    if (media.isNotEmpty) entities[ImportEntityType.media] = media;
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_dive_mapper_test.dart
```

Expected: PASS, every test including the four new ones. The existing phase 1 tests must still pass: they use logbooks with no reference maps, so the text fallbacks still apply.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_dive_mapper.dart test/features/universal_import/data/services/divinglog_dive_mapper_test.dart
git commit -m "feat(import): resolve Diving Log dive references by id

Refs #2187. A dive now links to its site, buddies, gear, trip, center and
dive types by id, and carries its sightings and photos. Ids win over the
free-text columns: a dive naming its buddies by id no longer also emits
the text, which is what turned 16 people into 68 entries in phase 1. The
text path remains for dives that have no ids."
```

---

### Task 8: Whole-project verification and the real logbook

**Files:** none created.

**Interfaces:**
- Consumes: everything.
- Produces: a branch ready for a pull request.

- [ ] **Step 1: Format and analyze**

```bash
dart format .
flutter analyze > /tmp/dl2_analyze.txt 2>&1; echo "exit: $?"; tail -3 /tmp/dl2_analyze.txt
```

Expected: exit 0 and `No issues found!`. Infos are fatal in CI, so treat any output as a failure.

- [ ] **Step 2: Run the architecture guards**

These scan all of `lib/`, so an affected-directory run never includes them.

```bash
flutter test test/architecture > /tmp/dl2_arch.txt 2>&1; echo "exit: $?"; tail -1 /tmp/dl2_arch.txt
```

Expected: exit 0, `All tests passed!`.

- [ ] **Step 3: Check the real logbook**

The reference file is personal data and must not be committed. Write this probe, run it, record the numbers for the PR body, then delete it.

Create `test/features/universal_import/dl2_probe_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/divinglog_sqlite_parser.dart';

void main() {
  test('probe: phase 2 against the real logbook', () async {
    final path = '${Platform.environment['HOME']}/Desktop/petele-scuba-log.sql';
    final bytes = Uint8List.fromList(File(path).readAsBytesSync());
    final payload = await const DivingLogSqliteParser().parse(bytes);

    for (final t in payload.entities.keys) {
      // ignore: avoid_print
      print('ENTITY ${t.name}=${payload.entities[t]!.length}');
    }
    var withSite = 0, withGear = 0, withTrip = 0, withCenter = 0;
    var withSightings = 0, withCoords = 0;
    for (final d in payload.entitiesOf(ImportEntityType.dives)) {
      if (d.containsKey('site')) withSite++;
      if (d.containsKey('equipmentRefs')) withGear++;
      if (d.containsKey('tripRef')) withTrip++;
      if (d.containsKey('diveCenterRef')) withCenter++;
      if (d.containsKey('sightings')) withSightings++;
    }
    for (final s in payload.entitiesOf(ImportEntityType.sites)) {
      if (s.containsKey('latitude')) withCoords++;
    }
    // ignore: avoid_print
    print('DIVES site=$withSite gear=$withGear trip=$withTrip '
        'center=$withCenter sightings=$withSightings');
    // ignore: avoid_print
    print('SITES withCoordinates=$withCoords');

    // Phase 1 produced 68 buddies from a Buddy table of 16 people.
    expect(payload.entitiesOf(ImportEntityType.buddies), hasLength(16));
    expect(payload.entitiesOf(ImportEntityType.equipment), hasLength(31));
    expect(payload.entitiesOf(ImportEntityType.trips), hasLength(28));
    expect(payload.entitiesOf(ImportEntityType.diveCenters), hasLength(22));
    expect(payload.entitiesOf(ImportEntityType.certifications), hasLength(5));
    expect(payload.entitiesOf(ImportEntityType.diveTypes), hasLength(10));
  });
}
```

```bash
flutter test test/features/universal_import/dl2_probe_test.dart
```

Expected: PASS. If the buddy count is not 16, the id-wins rule is not taking effect and that must be fixed before shipping, because it is the defect this phase exists to repair. Then delete the probe:

```bash
rm test/features/universal_import/dl2_probe_test.dart
```

- [ ] **Step 4: Run the full suite once**

```bash
flutter test > /tmp/dl2_suite.txt 2>&1; echo "SUITE EXIT: $?"; grep -E "All tests passed|Some tests failed" /tmp/dl2_suite.txt | tail -1
```

Expected: exit 0 and `All tests passed!`. Run this once, and do not overlap it with another local test run.

- [ ] **Step 5: Commit any fixes**

```bash
dart format .
git add -u
git commit -m "chore(import): satisfy analyze and the architecture guards

Refs #2187."
```

Skip this step if steps 1 through 4 produced no changes.

- [ ] **Step 6: Push and open the pull request**

```bash
git push -u origin ericgriffin/github-issue-2187-phase2
```

Then open the PR with this body, which must contain `Closes #2187` outside any code block:

```
Closes #2187. Reported in discussion #2144.

Phase 2 of the Diving Log / DiveLogDT SQLite importer. Phase 1 (#2198)
brought across dives, profiles, tanks, weights, and the sites and buddies
it could read from the free text on each dive row. This phase reads the
relational tables and resolves dive references by id.

Equipment, trips, dive centers, dive types, certifications, marine life and
photos now import. Sites gain the coordinates the `Place` table holds.

It also repairs a phase 1 defect: splitting the free-text `Buddy` column
produced 68 buddies from a `Buddy` table of 16 people. A dive that names its
buddies by id now emits only those, and sites are keyed exactly as phase 1
keyed them so a re-import folds rather than doubling.

Verified against the reporter's 444-dive logbook, which is personal data and
is not committed: 16 buddies, 31 equipment items, 28 trips, 22 dive centers,
10 dive types, 5 certifications, and sites carrying coordinates.

Design: `docs/superpowers/specs/2026-09-20-divinglog-sqlite-import-phase2-design.md`
Plan: `docs/superpowers/plans/2026-09-20-divinglog-sqlite-import-phase2.md`
```

Do not add any attribution line, co-author trailer, tool name or session link
to the commit messages or the PR body.

---

## Notes for the executor

- The worktree is already initialized. If `flutter analyze` reports hundreds of errors about missing generated files, the worktree lost its codegen; re-initialize it rather than bypassing the pre-push hook.
- A sibling session may be running its own suite. Local runs are IO bound, so yours will be slow; never `pkill` a `flutter test` process, and never use bare `git stash`, since the stash stack is shared across worktrees.
- Nothing in this phase touches l10n, so no ARB files change.
