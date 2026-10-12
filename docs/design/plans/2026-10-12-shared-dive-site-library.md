# Shared Dive-Site Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A club-controlled S3 or WebDAV folder holds a shared dive-site library that members connect to, read, edit field by field with attribution, push personal sites into, and govern with owner, editor and reader roles, independently of the personal sync.

**Architecture:** A new subsystem under `lib/core/services/shared_library/` (transport, codec, merge, clocks, local store) and `lib/features/shared_library/` (providers, pages, widgets) that shares only `CloudStorageProvider` and connected accounts with personal sync. Library sites are ordinary `dive_sites` rows carrying `shared_library_id`; per-field clocks and dirty flags live in `shared_site_state`. Personal sync gains three guards so library rows never cross it.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, the existing `Hlc` class, `FakeCloudStorageProvider` for tests, go_router, ARB l10n.

**Spec:** `docs/design/specs/2026-10-12-shared-dive-site-library-design.md`

## Global Constraints

- Schema rung is 285 as planned; it shipped as 289, because main released rungs 285 to 288 while this branch was open. The code, tests and spec use 289.
- Planned schema rung: 285; `AppDatabase.currentSchemaVersion` becomes 285, the rung is appended to `migrationVersions`, and every new table or column is also asserted in `beforeOpen` (the compatibility floor is NOT raised: new tables and a nullable column only).
- Tables live in `lib/core/database/tables/`, migration helpers in `lib/core/database/migrations/helpers/`, never in `database.dart` beyond the `tables:` list and the version constant.
- No em dashes anywhere, no emojis, no AI attribution in commits or the PR.
- Every user-visible string is an ARB key in `lib/l10n/arb/app_en.arb` and the ten other locales (ar, de, es, fr, he, hu, it, nl, pt, zh), inserted next to a key of the same feature group; run `flutter gen-l10n` after editing.
- Paths in tests use `p.join`; nothing global is left behind by a test (restore in `addTearDown`).
- Run `dart format .` and `flutter analyze` before every commit; run `test/architecture/` and `test/shared/` after adding files under `lib/`.
- Only S3 and WebDAV accounts may back a library (`AccountKind.s3`, `AccountKind.webdav`).
- `markRecordPending` is never called for a library site's personal-sync entity from the library code path (library rows are outside personal sync).

## Review Focus

1. A document whose `clocks` map lacks a field present in `fields` (an older writer): the field must merge as "oldest", so any local clock wins. Pinned in Task 4.
2. A `roles.json` that lists a member as both owner and editor, or lists an unknown id: owner wins, unknown ids are kept verbatim so a later join resolves them. Pinned in Task 11.
3. A library site hidden by the member, then edited remotely: the hide must survive the merge (hides are per profile, not part of the document). Pinned in Task 10.
4. A push of a site that another profile on the same device shared (`isShared` true with hides): hides are left in place and the row loses `isShared`. Pinned in Task 12.
5. The manifest disappears after a library was connected (club moved folders): sync must stop with a clear state and never delete local rows. Pinned in Task 11.

---

### Task 1: Schema rung 285

**Files:**
- Create: `lib/core/database/tables/shared_library_tables.dart`
- Create: `lib/core/database/migrations/helpers/shared_library_migrations.dart`
- Modify: `lib/core/database/tables/site_tables.dart:53` (add `sharedLibraryId` after `isShared`)
- Modify: `lib/core/database/database.dart` (`tables:` list near line 94 and 246, `currentSchemaVersion` line 265, `migrationVersions` after the `284,` entry near line 1224)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (append rung 285 after the v284 block)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart:72` (append the backstop call)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add the `part` line for the new helper, next to the other helpers)
- Test: `test/core/database/shared_library_schema_test.dart`

**Interfaces:**
- Produces Drift tables `SharedLibraries`, `SharedLibraryMembers`, `SharedLibraryMemberships`, `SharedSiteStates`, `SharedSiteSuggestions`, and `DiveSites.sharedLibraryId` (`shared_library_id`, nullable text). Row classes: `SharedLibraryRow`, `SharedLibraryMemberRow`, `SharedLibraryMembershipRow`, `SharedSiteStateRow`, `SharedSiteSuggestionRow`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/shared_library_schema_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('rung 285 creates the shared library tables', () async {
    final names = (await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(names, containsAll([
      'shared_libraries',
      'shared_library_members',
      'shared_library_memberships',
      'shared_site_states',
      'shared_site_suggestions',
    ]));
  });

  test('dive_sites carries shared_library_id', () async {
    final cols = (await db.customSelect("PRAGMA table_info('dive_sites')").get())
        .map((r) => r.read<String>('name'));
    expect(cols, contains('shared_library_id'));
  });

  test('the schema version is 285', () {
    expect(AppDatabase.currentSchemaVersion, 285);
    expect(AppDatabase.migrationVersions.last, 285);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/shared_library_schema_test.dart`
Expected: FAIL (tables missing, version 284).

- [ ] **Step 3: Add the tables**

```dart
// lib/core/database/tables/shared_library_tables.dart
import 'package:drift/drift.dart';

import 'diver_tables.dart';
import 'site_tables.dart';

/// A club library this device connected (issue #2567). Device-local: the
/// credentials live on the connected account, the role and member caches
/// are refreshed from the folder on every sync.
class SharedLibraries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get connectedAccountId => text()();
  TextColumn get prefix => text().withDefault(const Constant(''))();
  IntColumn get formatVersion => integer().withDefault(const Constant(1))();
  BoolColumn get readOnlyDetected =>
      boolean().withDefault(const Constant(false))();
  /// `{"owners": [...], "editors": [...]}` as last read from roles.json.
  TextColumn get rolesJson => text().withDefault(const Constant('{}'))();
  IntColumn get lastSyncAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Member cards as last listed from `members/` (issue #2567).
class SharedLibraryMembers extends Table {
  TextColumn get libraryId =>
      text().references(SharedLibraries, #id, onDelete: KeyAction.cascade)();
  TextColumn get memberId => text()();
  TextColumn get displayName => text()();
  IntColumn get joinedAt => integer()();

  @override
  Set<Column> get primaryKey => {libraryId, memberId};
}

/// A diver profile's membership of a library (issue #2567). Synced, so every
/// device of the profile is the same member; carries a location hint and
/// never credentials.
class SharedLibraryMemberships extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get libraryId => text()();
  TextColumn get memberId => text()();
  TextColumn get displayName => text()();
  TextColumn get libraryName => text()();
  /// `s3` or `webdav`.
  TextColumn get backendKind => text()();
  /// Bucket or host plus prefix, for the "connect on this device" prompt.
  TextColumn get locationHint => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per library site: the field clocks and this device's dirty flag
/// (issue #2567). Device-local. No FK to dive_sites: the row outlives a
/// deleted site so the tombstone can still be uploaded and a re-listed
/// tombstone is not downloaded again.
class SharedSiteStates extends Table {
  TextColumn get siteId => text()();
  TextColumn get libraryId => text()();
  /// `{field: {"hlc": "...", "memberId": "..."}}`.
  TextColumn get clocksJson => text().withDefault(const Constant('{}'))();
  /// `modifiedTime` of the document as last listed, ISO-8601 UTC.
  TextColumn get remoteModifiedTime => text().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  /// The document's tombstone flag as this device last knew it.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get lastEditorMemberId => text().nullable()();
  IntColumn get lastEditedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {siteId};
}

/// A proposed edit from a reader (issue #2567): outgoing until uploaded,
/// incoming on an owner's device until accepted or dismissed.
class SharedSiteSuggestions extends Table {
  TextColumn get id => text()();
  TextColumn get libraryId => text()();
  TextColumn get siteId => text()();
  TextColumn get memberId => text()();
  TextColumn get memberName => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  /// The changed fields only, in site-document field form.
  TextColumn get fieldsJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAt => integer()();
  /// `outgoing` or `incoming`.
  TextColumn get direction => text()();
  /// `pending`, `uploaded` or `withdrawn`.
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get remoteModifiedTime => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add to `site_tables.dart` directly after `isShared` (line 53):

```dart
  /// The club library this site belongs to (issue #2567); null for a
  /// personal site. Set rows never enter the personal sync.
  TextColumn get sharedLibraryId => text().nullable()();
```

In `database.dart`: import `tables/shared_library_tables.dart`, append the five tables to `tables: [...]`, set `currentSchemaVersion = 285`, append `285,` to `migrationVersions`.

- [ ] **Step 4: Add the migration helper, rung and backstop**

```dart
// lib/core/database/migrations/helpers/shared_library_migrations.dart
part of '../app_database_migrations.dart';

/// Shared dive-site library schema (issue #2567, v285): five tables and the
/// `dive_sites.shared_library_id` column. Idempotent, so it serves as the
/// rung and the beforeOpen backstop.
extension SharedLibraryMigrations on AppDatabase {
  Future<void> _assertSharedLibrarySchema() async {
    final m = Migrator(this);
    await m.createTable(sharedLibraries);
    await m.createTable(sharedLibraryMembers);
    await m.createTable(sharedLibraryMemberships);
    await m.createTable(sharedSiteStates);
    await m.createTable(sharedSiteSuggestions);
    final cols = await customSelect("PRAGMA table_info('dive_sites')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('shared_library_id')) {
      await customStatement(
        'ALTER TABLE dive_sites ADD COLUMN shared_library_id TEXT',
      );
    }
  }
}
```

Check how `createTable` behaves on an existing table in this repo: `_assertDiveComputerConnectionSchema` guards with a `sqlite_master` query first. Mirror that guard per table:

```dart
  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }
```

and wrap each `createTable` as `if (!await _tableExists('shared_libraries')) await m.createTable(sharedLibraries);` (and the four others). If a `_tableExists` helper already exists in the migrations extension, use it instead of adding one.

Rung, appended after the v284 block in `rungs_v231_onward.dart`:

```dart
    // v285: shared dive-site library tables and dive_sites.shared_library_id
    // (issue #2567). Idempotent; re-asserted in beforeOpen.
    if (from < 285) {
      await _assertSharedLibrarySchema();
    }
    if (from < 285) await reportProgress();
```

Backstop, appended at the end of `_tableBackstopsFromV217()`:

```dart
    // v285 backstop: shared library tables and column (parallel-branch
    // version-collision self-heal; idempotent).
    await _assertSharedLibrarySchema();
```

Add `part 'helpers/shared_library_migrations.dart';` to `app_database_migrations.dart` beside the other helper parts.

- [ ] **Step 5: Regenerate and run the test**

Run: `dart run build_runner build --delete-conflicting-outputs` (from a scratchpad script if the shell refuses the word), then `flutter test test/core/database/shared_library_schema_test.dart test/core/database`
Expected: PASS, and the existing migration tests still pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/tables/shared_library_tables.dart lib/core/database/tables/site_tables.dart lib/core/database/database.dart lib/core/database/migrations/helpers/shared_library_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/migrations/before_open_table_backstops.dart lib/core/database/migrations/app_database_migrations.dart test/core/database/shared_library_schema_test.dart
git commit -m "feat(shared-library): schema rung 285 for the shared site library"
```

---

### Task 2: Domain models and the DiveSite column

**Files:**
- Create: `lib/core/services/shared_library/shared_library_models.dart`
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart:65` (field, constructor, `copyWith`, `props`)
- Modify: `lib/features/dive_sites/data/mappers/dive_site_row_mapper.dart:47`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart:139-208` (`createSite` companion) and `:1388` (`_updateSiteRow`) so the column round-trips
- Test: `test/core/services/shared_library/shared_library_models_test.dart`

**Interfaces:**
- Produces:

```dart
enum SharedLibraryRole { reader, editor, owner }

class FieldClock { final Hlc hlc; final String memberId; }

class SharedLibraryRoles {
  final Set<String> owners; final Set<String> editors;
  SharedLibraryRole roleOf(String memberId);
  factory SharedLibraryRoles.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

class SharedLibraryMember { final String memberId; final String displayName; final DateTime joinedAt; }

class SharedLibrary {
  final String id; final String name; final String connectedAccountId;
  final String prefix; final int formatVersion; final bool readOnlyDetected;
  final SharedLibraryRoles roles; final DateTime? lastSyncAt; final String? lastError;
}

class SharedLibraryMembership {
  final String id; final String diverId; final String libraryId; final String memberId;
  final String displayName; final String libraryName; final String backendKind;
  final String locationHint;
}

/// Effective role: the roles file capped by what the credentials allowed.
SharedLibraryRole effectiveRole({required SharedLibraryRole listed, required bool readOnlyDetected});
```

- `DiveSite.sharedLibraryId` (`String?`), `bool get isLibrarySite => sharedLibraryId != null`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/shared_library/shared_library_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('SharedLibraryRoles', () {
    test('owner beats editor, unknown is reader, ids kept verbatim', () {
      final roles = SharedLibraryRoles.fromJson({
        'owners': ['a', 'ghost'],
        'editors': ['a', 'b'],
      });
      expect(roles.roleOf('a'), SharedLibraryRole.owner);
      expect(roles.roleOf('b'), SharedLibraryRole.editor);
      expect(roles.roleOf('c'), SharedLibraryRole.reader);
      expect(roles.toJson()['owners'], containsAll(['a', 'ghost']));
    });
    test('missing lists parse as empty', () {
      expect(SharedLibraryRoles.fromJson({}).roleOf('x'), SharedLibraryRole.reader);
    });
  });

  test('effectiveRole caps at reader when credentials were refused', () {
    expect(
      effectiveRole(listed: SharedLibraryRole.owner, readOnlyDetected: true),
      SharedLibraryRole.reader,
    );
    expect(
      effectiveRole(listed: SharedLibraryRole.editor, readOnlyDetected: false),
      SharedLibraryRole.editor,
    );
  });

  test('DiveSite.copyWith carries sharedLibraryId and can clear it', () {
    const site = DiveSite(id: 's', name: 'n');
    final lib = site.copyWith(sharedLibraryId: 'L');
    expect(lib.isLibrarySite, isTrue);
    expect(lib.copyWith(clearSharedLibraryId: true).sharedLibraryId, isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/shared_library/shared_library_models_test.dart`
Expected: FAIL (file and members missing).

- [ ] **Step 3: Implement**

```dart
// lib/core/services/shared_library/shared_library_models.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/sync/hlc.dart';

/// What a member may do in a club library (issue #2567).
enum SharedLibraryRole { reader, editor, owner }

/// The clock on one document field: when, and by which member.
class FieldClock extends Equatable {
  const FieldClock({required this.hlc, required this.memberId});
  final Hlc hlc;
  final String memberId;

  factory FieldClock.fromJson(Map<String, dynamic> json) => FieldClock(
        hlc: Hlc.parse(json['hlc'] as String),
        memberId: json['memberId'] as String,
      );
  Map<String, dynamic> toJson() => {'hlc': hlc.toString(), 'memberId': memberId};

  @override
  List<Object?> get props => [hlc, memberId];
}

/// `roles.json`: owners and editors by member id; everyone else reads.
class SharedLibraryRoles extends Equatable {
  const SharedLibraryRoles({this.owners = const {}, this.editors = const {}});
  final Set<String> owners;
  final Set<String> editors;

  static const empty = SharedLibraryRoles();

  factory SharedLibraryRoles.fromJson(Map<String, dynamic> json) =>
      SharedLibraryRoles(
        owners: _ids(json['owners']),
        editors: _ids(json['editors']),
      );

  static Set<String> _ids(Object? raw) =>
      raw is List ? raw.whereType<String>().toSet() : const {};

  Map<String, dynamic> toJson() => {
        'owners': owners.toList()..sort(),
        'editors': editors.toList()..sort(),
      };

  SharedLibraryRole roleOf(String memberId) {
    if (owners.contains(memberId)) return SharedLibraryRole.owner;
    if (editors.contains(memberId)) return SharedLibraryRole.editor;
    return SharedLibraryRole.reader;
  }

  SharedLibraryRoles withRole(String memberId, SharedLibraryRole role) =>
      SharedLibraryRoles(
        owners: role == SharedLibraryRole.owner
            ? {...owners, memberId}
            : {...owners}..remove(memberId),
        editors: role == SharedLibraryRole.editor
            ? {...editors, memberId}
            : {...editors}..remove(memberId),
      );

  @override
  List<Object?> get props => [owners, editors];
}

/// The role the UI honours: the listed role, capped at reader when the
/// storage refused a write.
SharedLibraryRole effectiveRole({
  required SharedLibraryRole listed,
  required bool readOnlyDetected,
}) => readOnlyDetected ? SharedLibraryRole.reader : listed;

class SharedLibraryMember extends Equatable {
  const SharedLibraryMember({
    required this.memberId,
    required this.displayName,
    required this.joinedAt,
  });
  final String memberId;
  final String displayName;
  final DateTime joinedAt;

  factory SharedLibraryMember.fromJson(String memberId, Map<String, dynamic> j) =>
      SharedLibraryMember(
        memberId: memberId,
        displayName: (j['displayName'] as String?) ?? '',
        joinedAt: DateTime.tryParse((j['joinedAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
  Map<String, dynamic> toJson({required String appVersion}) => {
        'displayName': displayName,
        'joinedAt': joinedAt.toUtc().toIso8601String(),
        'appVersion': appVersion,
      };

  @override
  List<Object?> get props => [memberId, displayName, joinedAt];
}

class SharedLibrary extends Equatable {
  const SharedLibrary({
    required this.id,
    required this.name,
    required this.connectedAccountId,
    required this.prefix,
    this.formatVersion = 1,
    this.readOnlyDetected = false,
    this.roles = SharedLibraryRoles.empty,
    this.lastSyncAt,
    this.lastError,
  });
  final String id;
  final String name;
  final String connectedAccountId;
  final String prefix;
  final int formatVersion;
  final bool readOnlyDetected;
  final SharedLibraryRoles roles;
  final DateTime? lastSyncAt;
  final String? lastError;

  SharedLibrary copyWith({
    String? name,
    bool? readOnlyDetected,
    SharedLibraryRoles? roles,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastError = false,
  }) => SharedLibrary(
        id: id,
        name: name ?? this.name,
        connectedAccountId: connectedAccountId,
        prefix: prefix,
        formatVersion: formatVersion,
        readOnlyDetected: readOnlyDetected ?? this.readOnlyDetected,
        roles: roles ?? this.roles,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
      );

  @override
  List<Object?> get props => [id, name, connectedAccountId, prefix,
        formatVersion, readOnlyDetected, roles, lastSyncAt, lastError];
}

class SharedLibraryMembership extends Equatable {
  const SharedLibraryMembership({
    required this.id,
    required this.diverId,
    required this.libraryId,
    required this.memberId,
    required this.displayName,
    required this.libraryName,
    required this.backendKind,
    this.locationHint = '',
  });
  final String id;
  final String diverId;
  final String libraryId;
  final String memberId;
  final String displayName;
  final String libraryName;
  final String backendKind;
  final String locationHint;

  @override
  List<Object?> get props => [id, diverId, libraryId, memberId, displayName,
        libraryName, backendKind, locationHint];
}

/// Manifest file name and folder names inside the club prefix.
abstract final class SharedLibraryLayout {
  static const manifestFile = 'submersion-shared-library.json';
  static const rolesFile = 'roles.json';
  static const membersDir = 'members';
  static const sitesDir = 'sites';
  static const suggestionsDir = 'suggestions';
  static const formatVersion = 1;

  static String memberFile(String memberId) => '$membersDir/$memberId.json';
  static String siteFile(String siteId) => '$sitesDir/$siteId.json';
  static String suggestionFile(String id) => '$suggestionsDir/$id.json';
}
```

`DiveSite`: add `final String? sharedLibraryId;`, constructor param `this.sharedLibraryId`, getter `bool get isLibrarySite => sharedLibraryId != null;`, `copyWith({String? sharedLibraryId, bool clearSharedLibraryId = false, ...})` resolving to `clearSharedLibraryId ? null : (sharedLibraryId ?? this.sharedLibraryId)`, and add it to `props`. Mapper: `sharedLibraryId: row.sharedLibraryId`. In `createSite` and `_updateSiteRow` companions add `sharedLibraryId: Value(site.sharedLibraryId)`. Do NOT add it to `_writeSiteUpdate`'s companion: library membership of a row changes only through Task 12's publisher.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/shared_library/shared_library_models_test.dart test/features/dive_sites/domain`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/shared_library/shared_library_models.dart lib/features/dive_sites/domain/entities/dive_site.dart lib/features/dive_sites/data/mappers/dive_site_row_mapper.dart lib/features/dive_sites/data/repositories/site_repository_impl.dart test/core/services/shared_library/shared_library_models_test.dart
git commit -m "feat(shared-library): domain models and the site library column"
```

---

### Task 3: Site document codec

**Files:**
- Create: `lib/core/services/shared_library/site_document.dart`
- Test: `test/core/services/shared_library/site_document_test.dart`

**Interfaces:**
- Produces:

```dart
class SiteDocument {
  final String id;
  final bool deleted;
  /// Field name to JSON value. Child lists are plain JSON lists.
  final Map<String, Object?> fields;
  final Map<String, FieldClock> clocks;
  /// Keys this build does not know, carried through unchanged.
  final Map<String, Object?> extra;
  factory SiteDocument.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  static Uint8List encode(SiteDocument doc);
  static SiteDocument decode(Uint8List bytes);
  /// Every field name a document may carry, in a stable order.
  static const List<String> fieldNames;
  static const String deletedField = 'deleted';
}
```

`fieldNames` = `name, description, latitude, longitude, minDepth, maxDepth, difficulty, waterType, bodyOfWater, city, island, country, region, rating, notes, hazards, accessNotes, mooringNumber, parkingInfo, altitude, entryMethod, exitMethod, siteTypes, tags, species, features`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/shared_library/site_document_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/sync/hlc.dart';

void main() {
  test('round-trips fields, clocks, deleted and unknown keys', () {
    final json = {
      'id': 's1',
      'formatVersion': 1,
      'deleted': false,
      'fields': {'name': 'Blue Hole', 'siteTypes': ['Reef'], 'future': 1},
      'clocks': {
        'name': {'hlc': Hlc(5, 0, 'm1').toString(), 'memberId': 'm1'},
      },
      'somethingNew': {'a': 1},
    };
    final doc = SiteDocument.fromJson(json);
    expect(doc.id, 's1');
    expect(doc.fields['name'], 'Blue Hole');
    expect(doc.clocks['name'], FieldClock(hlc: Hlc(5, 0, 'm1'), memberId: 'm1'));
    final back = doc.toJson();
    expect(back['somethingNew'], {'a': 1});
    expect((back['fields'] as Map)['future'], 1);
    expect(SiteDocument.decode(SiteDocument.encode(doc)).toJson(), back);
  });

  test('missing clocks and deleted parse as empty and false', () {
    final doc = SiteDocument.fromJson({'id': 'x', 'fields': {}});
    expect(doc.clocks, isEmpty);
    expect(doc.deleted, isFalse);
  });

  test('decode rejects a document without an id', () {
    expect(
      () => SiteDocument.decode(utf8.encode('{"fields":{}}')),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/shared_library/site_document_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/core/services/shared_library/site_document.dart
import 'dart:convert';
import 'dart:typed_data';

import 'shared_library_models.dart';

/// One site as stored in `sites/<id>.json` of a club library (issue #2567).
class SiteDocument {
  const SiteDocument({
    required this.id,
    this.deleted = false,
    this.fields = const {},
    this.clocks = const {},
    this.extra = const {},
  });

  final String id;
  final bool deleted;
  final Map<String, Object?> fields;
  final Map<String, FieldClock> clocks;
  final Map<String, Object?> extra;

  static const String deletedField = 'deleted';

  static const List<String> fieldNames = [
    'name', 'description', 'latitude', 'longitude', 'minDepth', 'maxDepth',
    'difficulty', 'waterType', 'bodyOfWater', 'city', 'island', 'country',
    'region', 'rating', 'notes', 'hazards', 'accessNotes', 'mooringNumber',
    'parkingInfo', 'altitude', 'entryMethod', 'exitMethod',
    'siteTypes', 'tags', 'species', 'features',
  ];

  static const _knownKeys = {'id', 'formatVersion', 'deleted', 'fields', 'clocks'};

  factory SiteDocument.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('site document without an id');
    }
    final rawClocks = json['clocks'];
    final clocks = <String, FieldClock>{};
    if (rawClocks is Map) {
      for (final e in rawClocks.entries) {
        final v = e.value;
        if (v is Map) {
          try {
            clocks[e.key as String] = FieldClock.fromJson(v.cast<String, dynamic>());
          } on FormatException {
            // An unreadable clock counts as absent: oldest on merge.
          }
        }
      }
    }
    final rawFields = json['fields'];
    return SiteDocument(
      id: id,
      deleted: json['deleted'] == true,
      fields: rawFields is Map ? Map<String, Object?>.from(rawFields) : const {},
      clocks: clocks,
      extra: {
        for (final e in json.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'formatVersion': SharedLibraryLayout.formatVersion,
        'deleted': deleted,
        'fields': fields,
        'clocks': {for (final e in clocks.entries) e.key: e.value.toJson()},
      };

  static Uint8List encode(SiteDocument doc) =>
      Uint8List.fromList(utf8.encode(jsonEncode(doc.toJson())));

  static SiteDocument decode(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('site document is not an object');
    }
    return SiteDocument.fromJson(decoded);
  }

  SiteDocument copyWith({
    bool? deleted,
    Map<String, Object?>? fields,
    Map<String, FieldClock>? clocks,
  }) => SiteDocument(
        id: id,
        deleted: deleted ?? this.deleted,
        fields: fields ?? this.fields,
        clocks: clocks ?? this.clocks,
        extra: extra,
      );
}
```

- [ ] **Step 4: Run the test, then commit**

Run: `flutter test test/core/services/shared_library/site_document_test.dart`
Expected: PASS.

```bash
git add lib/core/services/shared_library/site_document.dart test/core/services/shared_library/site_document_test.dart
git commit -m "feat(shared-library): site document codec"
```

---

### Task 4: Per-field merge and the member clock

**Files:**
- Create: `lib/core/services/shared_library/site_document_merge.dart`
- Create: `lib/core/services/shared_library/member_clock.dart`
- Test: `test/core/services/shared_library/site_document_merge_test.dart`
- Test: `test/core/services/shared_library/member_clock_test.dart`

**Interfaces:**
- Produces:

```dart
class SiteMergeOutcome {
  final SiteDocument merged;
  final Set<String> remoteWon;  // fields taken from remote (apply to the row)
  final Set<String> localWon;   // fields remote lacked or lost (re-upload)
  bool get needsUpload => localWon.isNotEmpty;
  bool get changesLocal => remoteWon.isNotEmpty;
}
SiteMergeOutcome mergeSiteDocuments({required SiteDocument local, required SiteDocument remote});

class MemberClock {
  MemberClock(String memberId, {int Function()? now});
  /// A fresh stamp for a local edit, monotonic across calls.
  Hlc next();
  /// Fold a remote clock in so later local stamps sort after it.
  void receive(Hlc remote);
}
```

The `deleted` flag is a field named `deleted` for merge purposes: `local.deleted` and `remote.deleted` compare by `clocks['deleted']`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/shared_library/site_document_merge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_merge.dart';
import 'package:submersion/core/services/sync/hlc.dart';

FieldClock c(int t, String m) => FieldClock(hlc: Hlc(t, 0, m), memberId: m);

void main() {
  test('each field goes to the newer clock; a tie keeps local', () {
    final local = SiteDocument(
      id: 's',
      fields: {'hazards': 'current', 'parkingInfo': 'lot A', 'notes': 'same'},
      clocks: {'hazards': c(10, 'a'), 'parkingInfo': c(2, 'a'), 'notes': c(5, 'a')},
    );
    final remote = SiteDocument(
      id: 's',
      fields: {'hazards': 'none', 'parkingInfo': 'lot B', 'notes': 'other'},
      clocks: {'hazards': c(3, 'b'), 'parkingInfo': c(9, 'b'), 'notes': c(5, 'b')},
    );
    final out = mergeSiteDocuments(local: local, remote: remote);
    expect(out.merged.fields['hazards'], 'current');
    expect(out.merged.fields['parkingInfo'], 'lot B');
    expect(out.merged.fields['notes'], 'other', reason: 'b > a breaks the tie by node id');
    expect(out.remoteWon, {'parkingInfo', 'notes'});
    expect(out.localWon, {'hazards'});
    expect(out.merged.clocks['parkingInfo'], c(9, 'b'));
  });

  test('a field without a clock is oldest', () {
    final local = SiteDocument(id: 's', fields: {'name': 'L'}, clocks: {'name': c(1, 'a')});
    final remote = SiteDocument(id: 's', fields: {'name': 'R'});
    final out = mergeSiteDocuments(local: local, remote: remote);
    expect(out.merged.fields['name'], 'L');
    expect(out.localWon, {'name'});
  });

  test('a field only remote has is taken; one only local has is kept', () {
    final local = SiteDocument(id: 's', fields: {'notes': 'n'}, clocks: {'notes': c(1, 'a')});
    final remote = SiteDocument(id: 's', fields: {'hazards': 'h'}, clocks: {'hazards': c(1, 'b')});
    final out = mergeSiteDocuments(local: local, remote: remote);
    expect(out.merged.fields, {'notes': 'n', 'hazards': 'h'});
    expect(out.remoteWon, {'hazards'});
    expect(out.localWon, {'notes'});
  });

  test('deleted merges by its own clock', () {
    final local = SiteDocument(id: 's', deleted: false, clocks: {'deleted': c(1, 'a')});
    final remote = SiteDocument(id: 's', deleted: true, clocks: {'deleted': c(2, 'b')});
    expect(mergeSiteDocuments(local: local, remote: remote).merged.deleted, isTrue);
    final undeleted = SiteDocument(id: 's', deleted: false, clocks: {'deleted': c(3, 'a')});
    expect(mergeSiteDocuments(local: undeleted, remote: remote).merged.deleted, isFalse);
  });

  test('identical documents need neither upload nor local change', () {
    final doc = SiteDocument(id: 's', fields: {'name': 'x'}, clocks: {'name': c(1, 'a')});
    final out = mergeSiteDocuments(local: doc, remote: doc);
    expect(out.needsUpload, isFalse);
    expect(out.changesLocal, isFalse);
  });

  test('converges: merge is commutative and idempotent over random edits', () {
    // Three members, each with a random clocked value per field.
    final docs = [
      for (var m = 0; m < 3; m++)
        SiteDocument(
          id: 's',
          fields: {for (final f in SiteDocument.fieldNames) f: '$m-$f'},
          clocks: {
            for (final f in SiteDocument.fieldNames)
              f: c((f.hashCode * (m + 1)) % 97, 'm$m'),
          },
        ),
    ];
    final ab = mergeSiteDocuments(local: docs[0], remote: docs[1]).merged;
    final abc = mergeSiteDocuments(local: ab, remote: docs[2]).merged;
    final cb = mergeSiteDocuments(local: docs[2], remote: docs[1]).merged;
    final cba = mergeSiteDocuments(local: cb, remote: docs[0]).merged;
    expect(abc.toJson(), cba.toJson());
    expect(mergeSiteDocuments(local: abc, remote: abc).merged.toJson(), abc.toJson());
  });
}
```

```dart
// test/core/services/shared_library/member_clock_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/member_clock.dart';
import 'package:submersion/core/services/sync/hlc.dart';

void main() {
  test('stamps carry the member id and never go backwards', () {
    var t = 100;
    final clock = MemberClock('m1', now: () => t);
    final a = clock.next();
    final b = clock.next();
    expect(a.nodeId, 'm1');
    expect(b.compareTo(a), greaterThan(0));
    t = 50; // wall clock stepped back
    expect(clock.next().compareTo(b), greaterThan(0));
  });

  test('receive pushes later stamps past a remote clock', () {
    final clock = MemberClock('m1', now: () => 10);
    clock.receive(Hlc(500, 3, 'm2'));
    expect(clock.next().compareTo(Hlc(500, 3, 'm2')), greaterThan(0));
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/shared_library/site_document_merge_test.dart test/core/services/shared_library/member_clock_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/core/services/shared_library/site_document_merge.dart
import 'shared_library_models.dart';
import 'site_document.dart';

/// Result of folding a remote document into the local one (issue #2567).
class SiteMergeOutcome {
  const SiteMergeOutcome({
    required this.merged,
    required this.remoteWon,
    required this.localWon,
  });
  final SiteDocument merged;
  final Set<String> remoteWon;
  final Set<String> localWon;
  bool get needsUpload => localWon.isNotEmpty;
  bool get changesLocal => remoteWon.isNotEmpty;
}

/// Per-field last-writer-wins. The greater clock wins; a tie keeps local;
/// a missing clock is oldest. The merged document carries the winning
/// value and clock of every field either side has.
SiteMergeOutcome mergeSiteDocuments({
  required SiteDocument local,
  required SiteDocument remote,
}) {
  final fields = <String, Object?>{};
  final clocks = <String, FieldClock>{};
  final remoteWon = <String>{};
  final localWon = <String>{};
  final names = {...local.fields.keys, ...remote.fields.keys};

  for (final name in names) {
    final inLocal = local.fields.containsKey(name);
    final inRemote = remote.fields.containsKey(name);
    final lc = local.clocks[name];
    final rc = remote.clocks[name];
    final takeRemote = inRemote && (!inLocal || _newer(rc, lc));
    if (takeRemote) {
      fields[name] = remote.fields[name];
      if (rc != null) clocks[name] = rc;
      if (!inLocal || local.fields[name] != remote.fields[name] || lc != rc) {
        remoteWon.add(name);
      }
    } else {
      fields[name] = local.fields[name];
      if (lc != null) clocks[name] = lc;
      if (!inRemote || remote.fields[name] != local.fields[name] || lc != rc) {
        localWon.add(name);
      }
    }
  }

  final ld = local.clocks[SiteDocument.deletedField];
  final rd = remote.clocks[SiteDocument.deletedField];
  bool deleted;
  if (_newer(rd, ld)) {
    deleted = remote.deleted;
    if (rd != null) clocks[SiteDocument.deletedField] = rd;
    if (local.deleted != remote.deleted || ld != rd) {
      remoteWon.add(SiteDocument.deletedField);
    }
  } else {
    deleted = local.deleted;
    if (ld != null) clocks[SiteDocument.deletedField] = ld;
    if (local.deleted != remote.deleted || ld != rd) {
      localWon.add(SiteDocument.deletedField);
    }
  }

  return SiteMergeOutcome(
    merged: SiteDocument(
      id: local.id,
      deleted: deleted,
      fields: fields,
      clocks: clocks,
      extra: {...remote.extra, ...local.extra},
    ),
    remoteWon: remoteWon,
    localWon: localWon,
  );
}

/// True when [a] sorts strictly after [b]; a null clock is oldest.
bool _newer(FieldClock? a, FieldClock? b) {
  if (a == null) return false;
  if (b == null) return true;
  return a.hlc.compareTo(b.hlc) > 0;
}
```

```dart
// lib/core/services/shared_library/member_clock.dart
import 'package:submersion/core/services/sync/hlc.dart';

/// A hybrid logical clock for one member of a club library (issue #2567).
/// Unlike [SyncClock] it is not a singleton: one per library sync, seeded
/// from the newest clock the device already holds.
class MemberClock {
  MemberClock(this.memberId, {int Function()? now, Hlc? seed})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _current = seed ?? Hlc(0, 0, memberId);

  final String memberId;
  final int Function() _now;
  Hlc _current;

  Hlc next() {
    _current = Hlc(_current.physicalTime, _current.counter, memberId)
        .increment(_now());
    return _current;
  }

  void receive(Hlc remote) {
    if (remote.compareTo(_current) > 0) {
      _current = Hlc(remote.physicalTime, remote.counter, memberId);
    }
  }
}
```

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/shared_library/`
Expected: PASS.

```bash
git add lib/core/services/shared_library/site_document_merge.dart lib/core/services/shared_library/member_clock.dart test/core/services/shared_library/site_document_merge_test.dart test/core/services/shared_library/member_clock_test.dart
git commit -m "feat(shared-library): per-field merge and member clock"
```

---

### Task 5: Local store

**Files:**
- Create: `lib/core/services/shared_library/shared_library_store.dart`
- Test: `test/core/services/shared_library/shared_library_store_test.dart`

**Interfaces:**
- Produces `class SharedLibraryStore` over `DatabaseService.instance.database`:

```dart
Future<void> upsertLibrary(SharedLibrary lib);
Future<SharedLibrary?> getLibrary(String id);
Future<List<SharedLibrary>> getLibraries();
Future<void> deleteLibrary(String id);              // cascades members
Future<void> setLibraryStatus(String id, {DateTime? lastSyncAt, String? lastError, bool clearError = false, bool? readOnlyDetected, SharedLibraryRoles? roles, String? name});
Future<void> replaceMembers(String libraryId, List<SharedLibraryMember> members);
Future<List<SharedLibraryMember>> getMembers(String libraryId);
Future<Map<String, String>> memberNames(String libraryId);  // memberId -> displayName
Future<void> upsertMembership(SharedLibraryMembership m);   // stamps hlc via SyncRepository.markRecordPending('sharedLibraryMemberships')
Future<List<SharedLibraryMembership>> membershipsForDiver(String diverId);
Future<SharedLibraryMembership?> membership({required String diverId, required String libraryId});
Future<void> deleteMembership(String id);                   // logs a tombstone
Future<String> memberIdForDiver(String diverId);            // existing membership's id, else a new uuid
Future<SharedSiteState?> getSiteState(String siteId);
Future<List<SharedSiteState>> dirtySites(String libraryId);
Future<Map<String, SharedSiteState>> siteStates(String libraryId);
Future<void> putSiteState(SharedSiteState s);
Future<void> deleteSiteState(String siteId);
Future<void> putSuggestion(SharedSiteSuggestion s);
Future<List<SharedSiteSuggestion>> suggestions(String libraryId, {String? direction, String? status, String? siteId});
Future<void> deleteSuggestion(String id);
Stream<void> watchLibraries();   // tableUpdates on shared_libraries + members + memberships
Stream<void> watchSuggestions();
```

with two small value classes in the same file:

```dart
class SharedSiteState { siteId, libraryId, Map<String, FieldClock> clocks, String? remoteModifiedTime, bool dirty, bool deleted, String? lastEditorMemberId, int? lastEditedAtMs; copyWith(...) }
class SharedSiteSuggestion { id, libraryId, siteId, memberId, memberName, note, Map<String, Object?> fields, DateTime createdAt, String direction, String status, String? remoteModifiedTime; copyWith(...) }
```

`clocks` are stored as `clocksJson` through `FieldClock.toJson` / `fromJson`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/shared_library/shared_library_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SharedLibraryStore store;
  setUp(() async {
    await setUpTestDatabase();
    store = SharedLibraryStore();
    await DiverRepository().createDiver(const Diver(id: 'd1', name: 'Ann'));
  });
  tearDown(tearDownTestDatabase);

  test('library round trip, status update and cascade delete', () async {
    await store.upsertLibrary(const SharedLibrary(
      id: 'L', name: 'Club', connectedAccountId: 'acc', prefix: 'club/'));
    await store.replaceMembers('L', [
      SharedLibraryMember(memberId: 'm1', displayName: 'Ann', joinedAt: DateTime.utc(2026)),
    ]);
    await store.setLibraryStatus('L', lastError: 'boom',
        roles: const SharedLibraryRoles(owners: {'m1'}));
    final lib = (await store.getLibrary('L'))!;
    expect(lib.lastError, 'boom');
    expect(lib.roles.roleOf('m1'), SharedLibraryRole.owner);
    expect(await store.memberNames('L'), {'m1': 'Ann'});
    await store.deleteLibrary('L');
    expect(await store.getMembers('L'), isEmpty);
  });

  test('memberIdForDiver is stable across libraries', () async {
    final first = await store.memberIdForDiver('d1');
    await store.upsertMembership(SharedLibraryMembership(
      id: 'ms1', diverId: 'd1', libraryId: 'L', memberId: first,
      displayName: 'Ann', libraryName: 'Club', backendKind: 's3'));
    expect(await store.memberIdForDiver('d1'), first);
    final rows = await store.membershipsForDiver('d1');
    expect(rows.single.memberId, first);
  });

  test('upsertMembership stamps an hlc for personal sync', () async {
    await store.upsertMembership(const SharedLibraryMembership(
      id: 'ms1', diverId: 'd1', libraryId: 'L', memberId: 'm',
      displayName: 'Ann', libraryName: 'Club', backendKind: 's3'));
    final hlc = (await DatabaseService.instance.database
            .customSelect("SELECT hlc FROM shared_library_memberships WHERE id = 'ms1'")
            .getSingle())
        .read<String?>('hlc');
    expect(hlc, isNotNull, reason: 'registered in hlcTargets (Task 7)');
  });

  test('site state keeps clocks and the dirty flag', () async {
    final clock = FieldClock(hlc: Hlc(1, 0, 'm'), memberId: 'm');
    await store.putSiteState(SharedSiteState(
      siteId: 's', libraryId: 'L', clocks: {'name': clock}, dirty: true));
    final s = (await store.getSiteState('s'))!;
    expect(s.clocks['name'], clock);
    expect((await store.dirtySites('L')).map((e) => e.siteId), ['s']);
  });

  test('suggestions filter by direction and status', () async {
    await store.putSuggestion(SharedSiteSuggestion(
      id: 'g1', libraryId: 'L', siteId: 's', memberId: 'm', memberName: 'Ann',
      fields: const {'notes': 'x'}, createdAt: DateTime.utc(2026),
      direction: 'outgoing', status: 'pending'));
    expect(await store.suggestions('L', direction: 'outgoing', status: 'pending'), hasLength(1));
    expect(await store.suggestions('L', direction: 'incoming'), isEmpty);
  });
}
```

The hlc test passes only after Task 7 registers the entity; mark it `skip: 'Task 7'` until then and remove the skip in Task 7. Also add to the site-state test: `await store.putSiteState(s.copyWith(deleted: true)); expect((await store.getSiteState('s'))!.deleted, isTrue);`.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/shared_library/shared_library_store_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the store**

Write `SharedLibraryStore` with Drift queries over the Task 1 tables. Key points:

```dart
class SharedLibraryStore {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _sync = SyncRepository();
  final _uuid = const Uuid();

  Future<void> upsertLibrary(SharedLibrary lib) => _db
      .into(_db.sharedLibraries)
      .insertOnConflictUpdate(SharedLibrariesCompanion.insert(
        id: lib.id, name: lib.name, connectedAccountId: lib.connectedAccountId,
        prefix: Value(lib.prefix), formatVersion: Value(lib.formatVersion),
        readOnlyDetected: Value(lib.readOnlyDetected),
        rolesJson: Value(jsonEncode(lib.roles.toJson())),
        lastSyncAt: Value(lib.lastSyncAt?.millisecondsSinceEpoch),
        lastError: Value(lib.lastError),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

  Future<void> upsertMembership(SharedLibraryMembership m) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _db.into(_db.sharedLibraryMemberships).insertOnConflictUpdate(
        SharedLibraryMembershipsCompanion.insert(
          id: m.id, diverId: m.diverId, libraryId: m.libraryId,
          memberId: m.memberId, displayName: m.displayName,
          libraryName: m.libraryName, backendKind: m.backendKind,
          locationHint: Value(m.locationHint), createdAt: now, updatedAt: now,
        ),
      );
      await _sync.markRecordPending(
        entityType: 'sharedLibraryMemberships', recordId: m.id, localUpdatedAt: now,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<void> deleteMembership(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.sharedLibraryMemberships)..where((t) => t.id.equals(id))).go();
      await _sync.logDeletions(entityType: 'sharedLibraryMemberships', recordIds: [id]);
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<String> memberIdForDiver(String diverId) async {
    final row = await (_db.select(_db.sharedLibraryMemberships)
          ..where((t) => t.diverId.equals(diverId))
          ..limit(1))
        .getSingleOrNull();
    return row?.memberId ?? _uuid.v4();
  }
}
```

`createdAt` on upsertLibrary must be preserved on update: read the existing row first and reuse its `createdAt`. Implement the remaining methods as plain selects, `insertOnConflictUpdate`, and deletes; `watchLibraries` is `_db.tableUpdates(TableUpdateQuery.onAllTables([_db.sharedLibraries, _db.sharedLibraryMembers, _db.sharedLibraryMemberships]))`.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/shared_library/shared_library_store_test.dart`
Expected: PASS (one skipped until Task 7).

```bash
git add lib/core/services/shared_library/shared_library_store.dart test/core/services/shared_library/shared_library_store_test.dart
git commit -m "feat(shared-library): local store for libraries, members, state and suggestions"
```

---

### Task 6: Site document bridge (row to document and back)

**Files:**
- Create: `lib/core/services/shared_library/site_document_bridge.dart`
- Test: `test/core/services/shared_library/site_document_bridge_test.dart`

**Interfaces:**
- Consumes: `SiteDocument` (Task 3), `SharedSiteState` (Task 5), `SiteRepository.getSiteById`, `SiteClassificationRepository.getTypesForSite/getTagsForSite/replaceTypes/replaceTags`, `SpeciesRepository.getExpectedSpeciesForSite/addExpectedSpecies/removeExpectedSpecies/createSpecies/getSpeciesById`, `SiteFeatureRepository.getFeaturesForSite`, `SiteTypeRepository.getAllSiteTypes/createSiteType`, `TagRepository.getAllTags/createTag`.
- Produces:

```dart
class SiteDocumentBridge {
  /// The document for a local library site, from its row, children and
  /// the clocks in [state]. `deleted` is false; Task 12 sets it on delete.
  Future<SiteDocument> build(String siteId, SharedSiteState state);
  /// Writes the winning fields of [doc] into the row and children. Creates
  /// the row (diverId null, isShared false, sharedLibraryId = [libraryId])
  /// when it does not exist. [fields] limits the write to those names;
  /// null writes every field in the document. Vocabulary is resolved against
  /// [vocabularyDiverId]. Never calls markRecordPending('diveSites').
  Future<void> apply(SiteDocument doc, {required String libraryId, required String vocabularyDiverId, Set<String>? fields});
  /// The document-form value of one field read from the current row.
  static Object? fieldValue(DiveSite site, String field);
}
```

Field encodings: enums by `.name` (`difficulty`, `waterType`, `entryMethod`, `exitMethod`), `latitude` and `longitude` as doubles from `site.location`, `siteTypes` and `tags` as `List<String>` names, `species` as `List<{name, scientificName}>`, `features` as `List<{id, type, name, latitude, longitude, bearingDeg, depthMeters, notes}>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/shared_library/site_document_bridge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_bridge.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SiteDocumentBridge bridge;
  setUp(() async {
    await setUpTestDatabase();
    bridge = SiteDocumentBridge();
    await DiverRepository().createDiver(const Diver(id: 'd1', name: 'Ann'));
  });
  tearDown(tearDownTestDatabase);

  test('apply creates a library row with children resolved by name', () async {
    final doc = SiteDocument(
      id: 's1',
      fields: {
        'name': 'Blue Hole', 'latitude': 1.5, 'longitude': 2.5, 'maxDepth': 30.0,
        'hazards': 'current', 'entryMethod': 'shore',
        'siteTypes': ['Reef'], 'tags': ['Club'],
        'species': [{'name': 'Grouper', 'scientificName': 'Epinephelus'}],
        'features': [{'id': 'f1', 'type': 'mooring', 'name': 'M1',
          'latitude': 1.0, 'longitude': 2.0, 'bearingDeg': null, 'depthMeters': 5.0, 'notes': ''}],
      },
      clocks: {for (final f in SiteDocument.fieldNames)
        f: FieldClock(hlc: Hlc(1, 0, 'm'), memberId: 'm')},
    );
    await bridge.apply(doc, libraryId: 'L', vocabularyDiverId: 'd1');
    final site = (await SiteRepository().getSiteById('s1'))!;
    expect(site.sharedLibraryId, 'L');
    expect(site.diverId, isNull);
    expect(site.isShared, isFalse);
    expect(site.hazards, 'current');
    expect(site.location?.latitude, 1.5);
    expect((await SiteClassificationRepository().getTypesForSite('s1')).map((t) => t.name), ['Reef']);
    expect((await SiteClassificationRepository().getTagsForSite('s1')).map((t) => t.name), ['Club']);
    expect((await SiteFeatureRepository().getFeaturesForSite('s1')).single.id, 'f1');
    final tag = (await TagRepository().getAllTags(diverId: 'd1')).single;
    expect(tag.diverId, 'd1', reason: 'vocabulary belongs to the subscribing diver');
  });

  test('apply with a field subset leaves other columns alone', () async {
    await SiteRepository().createSite(const DiveSite(id: 's2', name: 'Old', notes: 'keep', sharedLibraryId: 'L'));
    final doc = SiteDocument(id: 's2', fields: {'name': 'New', 'notes': 'drop'});
    await bridge.apply(doc, libraryId: 'L', vocabularyDiverId: 'd1', fields: {'name'});
    final site = (await SiteRepository().getSiteById('s2'))!;
    expect(site.name, 'New');
    expect(site.notes, 'keep');
  });

  test('build reads the row, children and clocks', () async {
    await SiteRepository().createSite(const DiveSite(id: 's3', name: 'S', hazards: 'h', sharedLibraryId: 'L'));
    final state = SharedSiteState(siteId: 's3', libraryId: 'L',
      clocks: {'name': FieldClock(hlc: Hlc(2, 0, 'm'), memberId: 'm')});
    final doc = await bridge.build('s3', state);
    expect(doc.id, 's3');
    expect(doc.fields['name'], 'S');
    expect(doc.fields['hazards'], 'h');
    expect(doc.fields['siteTypes'], isEmpty);
    expect(doc.clocks['name']?.memberId, 'm');
    expect(doc.deleted, isFalse);
  });

  test('apply does not mark the site pending for personal sync', () async {
    final doc = SiteDocument(id: 's4', fields: {'name': 'N'});
    await bridge.apply(doc, libraryId: 'L', vocabularyDiverId: 'd1');
    final pending = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM sync_records WHERE id = 'diveSites_s4'")
        .get();
    expect(pending, isEmpty);
  });
}
```

Check `createSite`'s actual signature at `site_repository_impl.dart:139` before writing the test; if it returns the created entity or needs a `diverId`, adjust the calls.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/shared_library/site_document_bridge_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Outline of `apply`:

```dart
Future<void> apply(SiteDocument doc, {required String libraryId,
    required String vocabularyDiverId, Set<String>? fields}) async {
  final names = fields ?? doc.fields.keys.toSet();
  final now = DateTime.now().millisecondsSinceEpoch;
  final f = doc.fields;
  await _db.transaction(() async {
    final exists = await (_db.select(_db.diveSites)..where((t) => t.id.equals(doc.id))).getSingleOrNull();
    var companion = DiveSitesCompanion(
      id: Value(doc.id),
      sharedLibraryId: Value(libraryId),
      diverId: const Value(null),
      isShared: const Value(false),
      updatedAt: Value(now),
    );
    if (exists == null) {
      companion = companion.copyWith(name: Value((f['name'] as String?) ?? ''), createdAt: Value(now));
    }
    Value<T> pick<T>(String field, T Function(Object?) conv) =>
        names.contains(field) && f.containsKey(field) ? Value(conv(f[field])) : const Value.absent();
    companion = companion.copyWith(
      name: names.contains('name') ? Value((f['name'] as String?) ?? '') : companion.name,
      description: pick('description', (v) => (v as String?) ?? ''),
      latitude: pick('latitude', (v) => (v as num?)?.toDouble()),
      longitude: pick('longitude', (v) => (v as num?)?.toDouble()),
      minDepth: pick('minDepth', (v) => (v as num?)?.toDouble()),
      maxDepth: pick('maxDepth', (v) => (v as num?)?.toDouble()),
      difficulty: pick('difficulty', (v) => v as String?),
      waterType: pick('waterType', (v) => v as String?),
      bodyOfWater: pick('bodyOfWater', (v) => v as String?),
      city: pick('city', (v) => v as String?),
      island: pick('island', (v) => v as String?),
      country: pick('country', (v) => v as String?),
      region: pick('region', (v) => v as String?),
      rating: pick('rating', (v) => (v as num?)?.toDouble()),
      notes: pick('notes', (v) => (v as String?) ?? ''),
      hazards: pick('hazards', (v) => v as String?),
      accessNotes: pick('accessNotes', (v) => v as String?),
      mooringNumber: pick('mooringNumber', (v) => v as String?),
      parkingInfo: pick('parkingInfo', (v) => v as String?),
      altitude: pick('altitude', (v) => (v as num?)?.toDouble()),
      entryMethod: pick('entryMethod', (v) => v as String?),
      exitMethod: pick('exitMethod', (v) => v as String?),
    );
    await _db.into(_db.diveSites).insertOnConflictUpdate(companion);
    if (names.contains('siteTypes')) await _applyTypes(doc.id, _strings(f['siteTypes']), vocabularyDiverId);
    if (names.contains('tags')) await _applyTags(doc.id, _strings(f['tags']), vocabularyDiverId);
    if (names.contains('species')) await _applySpecies(doc.id, f['species']);
    if (names.contains('features')) await _applyFeatures(doc.id, f['features'], now);
  });
}
```

Check whether `DiveSitesCompanion.copyWith` exists in the generated code (Drift generates it for companions); if not, build the companion in one constructor call with ternaries. `_applyTypes`: load `SiteTypeRepository().getAllSiteTypes(diverId: vocabularyDiverId)` (built-ins plus the diver's), match by `name.trim().toLowerCase()`, create missing with `createSiteType(SiteTypeEntity(id: '', diverId: vocabularyDiverId, name: n, isBuiltIn: false, sortOrder: 0, createdAt: now, updatedAt: now))`, then `SiteClassificationRepository().replaceTypes(siteId, ids, notify: false)`. `_applyTags` the same through `TagRepository().getAllTags(diverId:)` and `createTag(Tag(id: uuid, diverId: vocabularyDiverId, name: n, createdAt: ..., updatedAt: ..., scopes: {TagScope.sites}))`, then `replaceTags`. `_applySpecies`: current = `getExpectedSpeciesForSite`, match incoming by scientific name (case-insensitive) then common name against `getAllSpecies()`; create missing with `createSpecies(commonName: n, scientificName: s, category: SpeciesCategory.other)`; `addExpectedSpecies` for new, `removeExpectedSpecies` for ones no longer listed. `_applyFeatures`: upsert each by id straight into `_db.siteFeatures` (`SiteFeaturesCompanion` with `type`, `name`, `latitude`, `longitude`, `bearingDeg`, `depthMeters`, `notes`, `createdAt`, `updatedAt`), delete rows for the site whose id is not in the list. `replaceTypes`/`replaceTags` call `markRecordPending` on the junctions; that is harmless because Task 9's export guard drops children of library sites.

`build` reads `getSiteById`, the three child repositories, maps every `fieldNames` entry via `fieldValue`, and copies `state.clocks`.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/shared_library/site_document_bridge_test.dart`
Expected: PASS.

```bash
git add lib/core/services/shared_library/site_document_bridge.dart test/core/services/shared_library/site_document_bridge_test.dart
git commit -m "feat(shared-library): bridge between site rows and documents"
```

---

### Task 7: Register memberships in personal sync

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncData field near line 371, constructor 489, toJson 606, fromJson 738, `_baseTables` 1326, export call 2623, fetchRecord 3275, fetchRecords 3740, upsertRecord 5082, upsertRecords 6515, the `plain(...)` switch 7059, table switch 7520, deleteRecord 8098, and a new `_exportSharedLibraryMemberships` next to `_exportDiveComputerConnections` 9297)
- Modify: `lib/core/services/sync/sync_service.dart` (mergeOrder after the `diveComputerConnections` entry near line 1535, `entityHasUpdatedAt` map near 2644, `parentRefs` near 2808)
- Modify: `lib/core/data/repositories/sync_repository.dart:197` (`hlcTargets`)
- Modify: `test/core/services/shared_library/shared_library_store_test.dart` (remove the skip)
- Test: `test/core/services/sync/shared_library_membership_sync_test.dart`

**Interfaces:**
- Produces entity type `'sharedLibraryMemberships'` on the personal wire, `hasUpdatedAt: true`, parent ref `(field: 'diverId', parent: 'divers', nullable: false)`, `hlcTargets['sharedLibraryMemberships'] = (table: 'shared_library_memberships', pk: 'id')`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/shared_library_membership_sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

void main() {
  test('a membership reaches a second device of the same profile', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await DiverRepository().createDiver(const Diver(id: 'd1', name: 'Ann'));
    await SharedLibraryStore().upsertMembership(const SharedLibraryMembership(
      id: 'ms1', diverId: 'd1', libraryId: 'L', memberId: 'm1',
      displayName: 'Ann', libraryName: 'Club', backendKind: 's3',
      locationHint: 'bucket/club'));
    var svc = SyncService(syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(), cloudProvider: cloud);
    expect((await svc.performSync()).status, SyncResultStatus.success);
    await tearDownTestDatabase();

    await setUpTestDatabase();
    svc = SyncService(syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(), cloudProvider: cloud);
    expect((await svc.performSync()).status, SyncResultStatus.success);
    final rows = await SharedLibraryStore().membershipsForDiver('d1');
    expect(rows.single.locationHint, 'bucket/club');
    await tearDownTestDatabase();
  });
}
```

Confirm the import path of `FakeCloudStorageProvider` from `changeset_sync_convergence_test.dart` and copy it.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/shared_library_membership_sync_test.dart`
Expected: FAIL (the entity is unknown, nothing arrives).

- [ ] **Step 3: Register the entity**

Follow the `diveComputerConnections` lines listed above one by one, with `sharedLibraryMemberships` / `_db.sharedLibraryMemberships` / `SharedLibraryMembershipRow`. Export:

```dart
  Future<List<Map<String, dynamic>>> _exportSharedLibraryMemberships(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.sharedLibraryMemberships);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

mergeOrder entry, after the diver settings entries so the diver exists:

```dart
          // v285: a profile's club-library memberships (issue #2567).
          (
            type: 'sharedLibraryMemberships',
            records: data.sharedLibraryMemberships,
            hasUpdatedAt: true,
          ),
```

`entityHasUpdatedAt`: `'sharedLibraryMemberships': true,`. `parentRefs`: `'sharedLibraryMemberships': [(field: 'diverId', parent: 'divers', nullable: false)],`. `hlcTargets`: `'sharedLibraryMemberships': (table: 'shared_library_memberships', pk: 'id'),`. There is a parity test that asserts `entityHasUpdatedAt` covers exactly the SyncData entities (sync_service.dart:2589); run `test/core/services/sync` to find every registry it checks and add the entity there too.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/sync/shared_library_membership_sync_test.dart test/core/services/shared_library/shared_library_store_test.dart test/core/services/sync`
Expected: PASS, including the previously skipped hlc test.

```bash
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart lib/core/data/repositories/sync_repository.dart test/core/services/sync/shared_library_membership_sync_test.dart test/core/services/shared_library/shared_library_store_test.dart
git commit -m "feat(shared-library): sync club memberships across a profile's devices"
```

---

### Task 8: Stamp library edits in the site write path

**Files:**
- Create: `lib/core/services/shared_library/library_edit_stamper.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart:235-320` (`_writeSiteUpdate`), `:342` (`updateSiteAltitude`), `:350` (`updateSiteCoordinates`), `:370` (`applyLocationDetails`)
- Modify: `lib/features/dive_sites/data/repositories/site_classification_repository.dart:165,195,215,245` (`replaceTypes`, `addTypes`, `replaceTags`, `addTags`)
- Modify: `lib/features/dive_sites/data/repositories/site_feature_repository.dart:26,115,134`
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart:790,830`
- Test: `test/core/services/shared_library/library_edit_stamper_test.dart`

**Interfaces:**
- Produces:

```dart
class LibraryEditStamper {
  LibraryEditStamper({SharedLibraryStore? store, MemberClock Function(String memberId)? clockFor});
  /// No-op for a personal site. For a library site: stamps [fields] with a
  /// fresh clock under the current member and sets dirty. [memberId] comes
  /// from the active diver's membership of the site's library; with no
  /// membership on this device the edit is stamped under 'unknown'.
  Future<void> stamp(String siteId, Set<String> fields);
  /// Which document fields a row write changes, by comparing [before] and [after].
  static Set<String> changedFields(DiveSite before, DiveSite after);
}
```

The current member id is read through `SharedLibraryStore.membership(diverId:, libraryId:)` with `diverId` from `DiverRepository().getCurrentDiverId()` (check `lib/features/divers/data/repositories/diver_repository.dart` for the accessor the repositories already use for the active profile; `site_repository_impl.dart` passes `actingDiverId` from the providers instead, so `stamp` takes an optional `actingDiverId` and the repositories pass what they have).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/shared_library/library_edit_stamper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(const Diver(id: 'd1', name: 'Ann'));
    await SharedLibraryStore().upsertMembership(const SharedLibraryMembership(
      id: 'ms', diverId: 'd1', libraryId: 'L', memberId: 'm1',
      displayName: 'Ann', libraryName: 'Club', backendKind: 's3'));
    await SiteRepository().createSite(const DiveSite(id: 's', name: 'S', sharedLibraryId: 'L'));
  });
  tearDown(tearDownTestDatabase);

  test('changedFields names only the fields that differ', () {
    const a = DiveSite(id: 's', name: 'S', hazards: 'x');
    expect(LibraryEditStamper.changedFields(a, a.copyWith(hazards: 'y', notes: 'n')),
        {'hazards', 'notes'});
  });

  test('updateSite on a library site stamps the changed fields and dirties the state', () async {
    final site = (await SiteRepository().getSiteById('s'))!;
    await SiteRepository().updateSite(site.copyWith(hazards: 'current'), actingDiverId: 'd1');
    final state = (await SharedLibraryStore().getSiteState('s'))!;
    expect(state.dirty, isTrue);
    expect(state.clocks.keys, ['hazards']);
    expect(state.clocks['hazards']!.memberId, 'm1');
    expect(state.lastEditorMemberId, 'm1');
  });

  test('a personal site is never stamped', () async {
    await SiteRepository().createSite(const DiveSite(id: 'p', name: 'P'));
    final site = (await SiteRepository().getSiteById('p'))!;
    await SiteRepository().updateSite(site.copyWith(notes: 'n'), actingDiverId: 'd1');
    expect(await SharedLibraryStore().getSiteState('p'), isNull);
  });

  test('a later stamp of the same field replaces the clock', () async {
    final stamper = LibraryEditStamper();
    await stamper.stamp('s', {'name'}, actingDiverId: 'd1');
    final first = (await SharedLibraryStore().getSiteState('s'))!.clocks['name']!;
    await stamper.stamp('s', {'name'}, actingDiverId: 'd1');
    final second = (await SharedLibraryStore().getSiteState('s'))!.clocks['name']!;
    expect(second.hlc.compareTo(first.hlc), greaterThan(0));
  });
}
```

Check `updateSite`'s named parameters at `site_repository_impl.dart:209` (it takes the entity plus `classification` and `actingDiverId`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/shared_library/library_edit_stamper_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/core/services/shared_library/library_edit_stamper.dart
class LibraryEditStamper {
  LibraryEditStamper({SharedLibraryStore? store}) : _store = store ?? SharedLibraryStore();
  final SharedLibraryStore _store;
  AppDatabase get _db => DatabaseService.instance.database;

  static const _unknownMember = 'unknown';

  Future<void> stamp(String siteId, Set<String> fields, {String? actingDiverId}) async {
    if (fields.isEmpty) return;
    final row = await (_db.select(_db.diveSites)..where((t) => t.id.equals(siteId))).getSingleOrNull();
    final libraryId = row?.sharedLibraryId;
    if (libraryId == null) return;
    final membership = actingDiverId == null
        ? null
        : await _store.membership(diverId: actingDiverId, libraryId: libraryId);
    final memberId = membership?.memberId ?? _unknownMember;
    final existing = await _store.getSiteState(siteId) ??
        SharedSiteState(siteId: siteId, libraryId: libraryId);
    final clock = MemberClock(memberId);
    for (final c in existing.clocks.values) {
      clock.receive(c.hlc);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final clocks = Map<String, FieldClock>.from(existing.clocks);
    for (final f in fields) {
      clocks[f] = FieldClock(hlc: clock.next(), memberId: memberId);
    }
    await _store.putSiteState(existing.copyWith(
      clocks: clocks, dirty: true, lastEditorMemberId: memberId, lastEditedAtMs: now));
  }

  static Set<String> changedFields(DiveSite before, DiveSite after) => {
        for (final f in SiteDocument.fieldNames)
          if (_scalar(f) && SiteDocumentBridge.fieldValue(before, f) != SiteDocumentBridge.fieldValue(after, f)) f,
      };

  static bool _scalar(String f) => !const {'siteTypes', 'tags', 'species', 'features'}.contains(f);
}
```

`MemberClock.receive` must accept a clock from another member (it rewrites the node id to its own; that is already how Task 4 wrote it). Wire-up:

- `_writeSiteUpdate`: before the transaction, `final before = await getSiteById(site.id);` and after the transaction `if (before != null && before.isLibrarySite) await _stamper.stamp(site.id, LibraryEditStamper.changedFields(before, site), actingDiverId: actingDiverId);`. When `classification != null`, also stamp `{'siteTypes'}` or `{'tags'}` for the lists that changed (compare the id lists via `getTypeIdsBySite`/`getTagIdsBySite` before and after, or simply stamp both when `classification` is non-null and the site is a library site; prefer the comparison).
- `updateSiteAltitude` stamps `{'altitude'}`, `updateSiteCoordinates` stamps `{'latitude', 'longitude'}`, `applyLocationDetails` stamps the location fields it filled (it returns whether anything changed; stamp `{'country','region','city','island','bodyOfWater'}` filtered to the ones it wrote).
- `SiteClassificationRepository.replaceTypes/addTypes` stamp `{'siteTypes'}`, `replaceTags/addTags` stamp `{'tags'}`; each has a `notify` flag already, so the stamp happens when `notify` is true (the bridge passes `notify: false`).
- `SiteFeatureRepository.addFeature/updateFeature/deleteFeature` stamp `{'features'}` through `_markPendingAndBumpSite`'s caller, skipped when the write came from the bridge (add a `bool fromLibrary = false` parameter the bridge sets; the bridge writes features directly anyway, so this is only a guard).
- `SpeciesRepository.addExpectedSpecies/removeExpectedSpecies` stamp `{'species'}` the same way.

Each repository holds `final LibraryEditStamper _libraryStamper = LibraryEditStamper();`. `actingDiverId` is not available in the child repositories; there `stamp` is called without it, and the stamper falls back to the active diver: add to `LibraryEditStamper` a `Future<String?> Function()? activeDiverId` constructor hook defaulting to reading `DiverRepository().getCurrentDiverId()` (look up the real accessor name in `diver_repository.dart`; the settings pages read the active profile id from a `SharedPreferences` key through that repository).

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/shared_library/library_edit_stamper_test.dart test/features/dive_sites`
Expected: PASS.

```bash
git add lib/core/services/shared_library/library_edit_stamper.dart lib/features/dive_sites/data/repositories lib/features/marine_life/data/repositories/species_repository.dart test/core/services/shared_library/library_edit_stamper_test.dart
git commit -m "feat(shared-library): stamp field clocks on library site edits"
```

---

### Task 9: Personal-sync guards for library rows

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart:8390` (`_exportDiveSites`), `:8688` (`_exportSiteFeatures`), `:9525` (`_exportSiteSiteTypes`), `:9547` (`_exportSiteTags`), `:9730` (`_exportSiteSpecies`), and the base export of these tables (`exportBaseToTempFile`, `_baseTables` near 917: add a `where` hook or post-filter for the five tables)
- Modify: `lib/core/services/sync/sync_service.dart:3127` (`_mergeEntity`: drop incoming rows whose local site is a library row) and `:2397` (`_applyRemoteDeletions`: skip a `diveSites` tombstone for a library row)
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart:579` (`_deleteSiteRows`: no tombstone for library rows)
- Test: `test/core/services/sync/shared_library_row_guard_test.dart`

**Interfaces:**
- Produces `SyncDataSerializer.librarySiteIds()` (`Future<Set<String>>`, ids of `dive_sites` rows with `shared_library_id IS NOT NULL`) used by the merge and deletion guards, and `_deleteSiteRows(..., logTombstones: bool)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/shared_library_row_guard_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

SyncService _svc(FakeCloudStorageProvider cloud) => SyncService(
    syncRepository: SyncRepository(), serializer: SyncDataSerializer(), cloudProvider: cloud);

void main() {
  test('a library site is never exported', () async {
    final cloud = FakeCloudStorageProvider();
    await setUpTestDatabase();
    await SiteRepository().createSite(const DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: 'L'));
    await SiteRepository().createSite(const DiveSite(id: 'mine', name: 'Mine'));
    expect((await _svc(cloud).performSync()).status, SyncResultStatus.success);
    await tearDownTestDatabase();

    await setUpTestDatabase();
    expect((await _svc(cloud).performSync()).status, SyncResultStatus.success);
    expect(await SiteRepository().getSiteById('mine'), isNotNull);
    expect(await SiteRepository().getSiteById('lib'), isNull);
    await tearDownTestDatabase();
  });

  test('a peer\'s stale personal copy never overwrites or deletes a library row', () async {
    final cloud = FakeCloudStorageProvider();
    // Device A publishes a personal site, then deletes it.
    await setUpTestDatabase();
    await SiteRepository().createSite(const DiveSite(id: 'x', name: 'Stale', notes: 'old'));
    expect((await _svc(cloud).performSync()).status, SyncResultStatus.success);
    await tearDownTestDatabase();

    // Device B holds the same id as a library row.
    await setUpTestDatabase();
    await SiteRepository().createSite(const DiveSite(id: 'x', name: 'Club', notes: 'new', sharedLibraryId: 'L'));
    expect((await _svc(cloud).performSync()).status, SyncResultStatus.success);
    var site = (await SiteRepository().getSiteById('x'))!;
    expect(site.notes, 'new');
    expect(site.sharedLibraryId, 'L');
    await tearDownTestDatabase();

    // Device A deletes; B must keep the row.
    await setUpTestDatabase();
    expect((await _svc(cloud).performSync()).status, SyncResultStatus.success);
    await SiteRepository().deleteSite('x');
    expect((await _svc(cloud).performSync()).status, SyncResultStatus.success);
    await tearDownTestDatabase();

    await setUpTestDatabase();
    await SiteRepository().createSite(const DiveSite(id: 'x', name: 'Club', notes: 'new', sharedLibraryId: 'L'));
    expect((await _svc(cloud).performSync()).status, SyncResultStatus.success);
    site = (await SiteRepository().getSiteById('x'))!;
    expect(site.sharedLibraryId, 'L');
    await tearDownTestDatabase();
  });

  test('deleting a library row logs no tombstone', () async {
    await setUpTestDatabase();
    await SiteRepository().createSite(const DiveSite(id: 'lib', name: 'Club', sharedLibraryId: 'L'));
    await SiteRepository().deleteSite('lib');
    final rows = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM deletion_log WHERE entity_type = 'diveSites' AND record_id = 'lib'")
        .get();
    expect(rows, isEmpty);
    await tearDownTestDatabase();
  });
}
```

The third device in the second test re-uses device A's identity through the fake cloud's manifest; since `setUpTestDatabase` gives a fresh device id each time, the sequence above produces three distinct devices. That is fine: the point is that the tombstone for `x` and the stale row both arrive at a device holding `x` as a library row. Check the deletion_log column names in `lib/core/database/tables/sync_tables.dart:76` (`entity_type`, `record_id`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/shared_library_row_guard_test.dart`
Expected: FAIL (the library row is exported and overwritten).

- [ ] **Step 3: Implement the guards**

Export: add `..where((t) => t.sharedLibraryId.isNull())` to `_exportDiveSites`, and to the parent lookup in each child export (`modifiedSites` query gains the same where; the full-export branch joins through `dive_sites` to exclude children of library rows, for example

```dart
    final librarySiteIds = await librarySiteIds();
    final rows = await _db.select(_db.siteSiteTypes).get();
    return rows.where((r) => !librarySiteIds.contains(r.siteId)).map((r) => r.toJson()).toList();
```

). `_exportSiteFeatures` filters on its own `hlc` and must also drop rows whose `siteId` is a library site. The pending-children union (`_withPendingChildren`) must drop the same ids. Base export: find how `_baseTables` streams rows (`exportBaseToTempFile` near 1492) and add an optional `excludeWhere` per entry, set for `diveSites` (`shared_library_id IS NULL`) and the four children (`site_id NOT IN (SELECT id FROM dive_sites WHERE shared_library_id IS NOT NULL)`).

```dart
  /// Ids of sites that belong to a club library (issue #2567): outside the
  /// personal sync in both directions.
  Future<Set<String>> librarySiteIds() async {
    final rows = await (_db.selectOnly(_db.diveSites)
          ..addColumns([_db.diveSites.id])
          ..where(_db.diveSites.sharedLibraryId.isNotNull()))
        .get();
    return rows.map((r) => r.read(_db.diveSites.id)!).toSet();
  }
```

Merge: at the top of `_mergeEntity`, when `entityType` is `diveSites` or one of `siteSiteTypes`, `siteTags`, `siteSpecies`, `siteFeatures`, `siteHides`, compute `final guarded = await _serializer.librarySiteIds();` once per call and filter `records` to those whose `id` (sites) or `siteId` (children) is not in it. Deletions: in `_applyRemoteDeletions`, after the `pendingByEntity` check, `if (entityType == 'diveSites' && librarySiteIds.contains(recordId)) continue;` with `librarySiteIds` fetched once before the loop.

Repository: `_deleteSiteRows` gains `bool logTombstones = true`. `deleteSite` gains `bool? logTombstones` (null, the default, means "log unless the row is a library row", decided by reading the row first) and passes it down; `bulkDeleteSites` splits the ids into library and personal rows and calls `_deleteSiteRows` twice, the library half with `logTombstones: false`. Task 12's detach path calls `deleteSite(id, logTombstones: false)` explicitly.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/sync/shared_library_row_guard_test.dart test/core/services/sync test/features/dive_sites`
Expected: PASS.

```bash
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart lib/features/dive_sites/data/repositories/site_repository_impl.dart test/core/services/sync/shared_library_row_guard_test.dart
git commit -m "feat(shared-library): keep library sites out of the personal sync"
```

---

### Task 10: Visibility, policy and membership providers

**Files:**
- Modify: `lib/core/data/visibility/visibility_filter.dart:37-53` (`applyToDiveSites`) and `:121-142` (`sqlFragment`, site kind)
- Modify: `lib/core/data/visibility/shared_item_policy.dart` (library branch)
- Modify: `lib/features/query/data/name_index_loader.dart:152` (site names)
- Create: `lib/features/shared_library/presentation/providers/shared_library_providers.dart`
- Test: `test/core/data/visibility/library_site_visibility_test.dart`
- Test: `test/core/data/visibility/shared_item_policy_library_test.dart`

**Interfaces:**
- Produces in `shared_item_policy.dart`:

```dart
/// Role-gated actions on a library site (issue #2567).
bool canEditLibrarySite(SharedLibraryRole role) => role != SharedLibraryRole.reader;
bool canDeleteLibrarySite(SharedLibraryRole role) => role != SharedLibraryRole.reader;
bool canManageLibrary(SharedLibraryRole role) => role == SharedLibraryRole.owner;
bool canSuggestOnLibrarySite(SharedLibraryRole role) => role == SharedLibraryRole.reader;
```

and `canDestroySharedItem` gains `bool isLibrarySite = false` returning false for library rows (library rows route through the role functions instead). Providers:

```dart
final sharedLibraryStoreProvider = Provider<SharedLibraryStore>((ref) => SharedLibraryStore());
final sharedLibrariesProvider = StreamProvider<List<SharedLibrary>>(...);   // watchLibraries, then getLibraries
final currentMembershipsProvider = FutureProvider<List<SharedLibraryMembership>>(...); // for validatedCurrentDiverIdProvider
final libraryRoleProvider = FutureProvider.family<SharedLibraryRole, String>((ref, libraryId) ...); // effectiveRole of current member, reader when not connected
final libraryConnectedHereProvider = FutureProvider.family<bool, String>(...);  // store.getLibrary(id) != null
final libraryMemberNamesProvider = FutureProvider.family<Map<String, String>, String>(...);
final siteLibraryStateProvider = FutureProvider.family<SharedSiteState?, String>(...);
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/data/visibility/library_site_visibility_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(const Diver(id: 'member', name: 'Ann'));
    await DiverRepository().createDiver(const Diver(id: 'other', name: 'Bob'));
    await SharedLibraryStore().upsertMembership(const SharedLibraryMembership(
      id: 'ms', diverId: 'member', libraryId: 'L', memberId: 'm',
      displayName: 'Ann', libraryName: 'Club', backendKind: 's3'));
    await SiteRepository().createSite(const DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: 'L'));
  });
  tearDown(tearDownTestDatabase);

  test('a library site is visible to a member profile only', () async {
    expect((await SiteRepository().getAllSites(diverId: 'member')).map((s) => s.id), contains('lib'));
    expect((await SiteRepository().getAllSites(diverId: 'other')).map((s) => s.id), isNot(contains('lib')));
  });

  test('search honours the same rule', () async {
    expect(await SiteRepository().searchSites('Club', diverId: 'other'), isEmpty);
    expect(await SiteRepository().searchSites('Club', diverId: 'member'), hasLength(1));
  });

  test('a hide removes a library site for that profile and survives a remote edit', () async {
    await ProfileHidesRepository().hide(SharedItemKind.site, 'lib', diverId: 'member');
    expect((await SiteRepository().getAllSites(diverId: 'member')).map((s) => s.id), isNot(contains('lib')));
    final site = (await SiteRepository().getSiteById('lib'))!;
    await SiteRepository().updateSite(site.copyWith(notes: 'edited remotely'));
    expect((await SiteRepository().getAllSites(diverId: 'member')).map((s) => s.id), isNot(contains('lib')));
  });
}
```

Check `ProfileHidesRepository`'s hide method name and parameters at `profile_hides_repository.dart:64` and `searchSites`'s signature at `site_repository_impl.dart:1204`.

```dart
// test/core/data/visibility/shared_item_policy_library_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

void main() {
  test('a library row is never destroyable through the profile rule', () {
    expect(canDestroySharedItem(ownerId: null, activeDiverId: 'd', isLibrarySite: true), isFalse);
    expect(canDestroySharedItem(ownerId: null, activeDiverId: 'd'), isTrue);
  });
  test('roles gate edit, delete, manage and suggest', () {
    expect(canEditLibrarySite(SharedLibraryRole.reader), isFalse);
    expect(canEditLibrarySite(SharedLibraryRole.editor), isTrue);
    expect(canDeleteLibrarySite(SharedLibraryRole.editor), isTrue);
    expect(canManageLibrary(SharedLibraryRole.editor), isFalse);
    expect(canManageLibrary(SharedLibraryRole.owner), isTrue);
    expect(canSuggestOnLibrarySite(SharedLibraryRole.reader), isTrue);
    expect(canSuggestOnLibrarySite(SharedLibraryRole.owner), isFalse);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/data/visibility/library_site_visibility_test.dart test/core/data/visibility/shared_item_policy_library_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`applyToDiveSites`:

```dart
    query.where(
      (t) =>
          (t.diverId.equals(diverId) |
              t.isShared.equals(true) |
              t.sharedLibraryId.isInQuery(
                db.selectOnly(db.sharedLibraryMemberships)
                  ..addColumns([db.sharedLibraryMemberships.libraryId])
                  ..where(db.sharedLibraryMemberships.diverId.equals(diverId)),
              )) &
          t.id.isNotInQuery(
            db.selectOnly(hides)
              ..addColumns([hides.siteId])
              ..where(hides.diverId.equals(diverId)),
          ),
    );
```

`sqlFragment` for `SharedItemKind.site` adds `' OR $tableAlias.shared_library_id IN (SELECT library_id FROM shared_library_memberships WHERE diver_id = ?)'` inside the owner-or-shared parentheses, with a third `Variable.withString(diverId)`; keep the trip branch unchanged. Add a `static String ownerOrSharedOrLibrarySql(String alias, String viewer)` used by the site branch, and in `name_index_loader.dart` near line 152 use the same clause for site names (read lines 140-160 first to see which tables that loop covers). `shared_item_policy.dart` gains the `isLibrarySite` parameter and the four role functions. Every caller of `canDestroySharedItem` for sites (`site_detail_page.dart:411` via `canDestroySharedItemOnceKnown`, `site_list_content.dart:497`, `splitForBulkDelete`) passes `isLibrarySite: site.isLibrarySite`; `splitForBulkDelete` gains `bool Function(T) isLibraryOf` and leaves library rows out of both lists.

Providers file as listed under Interfaces, reading `validatedCurrentDiverIdProvider` from `lib/features/divers/presentation/providers/diver_providers.dart:290`.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/data/visibility test/features/dive_sites test/features/query`
Expected: PASS.

```bash
git add lib/core/data/visibility lib/features/query/data/name_index_loader.dart lib/features/shared_library/presentation/providers/shared_library_providers.dart lib/features/dive_sites/presentation test/core/data/visibility
git commit -m "feat(shared-library): library sites visible to members, role policy"
```

---

### Task 11: Transport and the library sync

**Files:**
- Create: `lib/core/services/shared_library/shared_library_transport.dart`
- Create: `lib/core/services/shared_library/shared_library_service.dart`
- Modify: `test/helpers/fake_cloud_storage_provider.dart` (add `CloudStorageException? uploadException;` thrown instead of the fixed message when set)
- Test: `test/core/services/shared_library/shared_library_transport_test.dart`
- Test: `test/core/services/shared_library/shared_library_service_test.dart`

**Interfaces:**
- Consumes: `CloudStorageProvider` (`createFolder(name, {parentFolderId})`, `uploadFile`, `downloadFile`, `listFiles({folderId, namePattern})`, `getFileInfo`, `deleteFile`, `getOrCreateSyncFolder`), Tasks 3 to 6 and 8.
- Produces:

```dart
/// File operations on one club library folder. File names carry a kind
/// prefix (site-, member-, suggestion-) as well as living in their own
/// subfolder, so a backend that flattens folders (the test fake, some
/// S3-compatible stores) still lists each kind apart.
class SharedLibraryTransport {
  SharedLibraryTransport(CloudStorageProvider provider, {required String prefix});
  static String siteFileName(String siteId) => 'site-$siteId.json';
  static String memberFileName(String memberId) => 'member-$memberId.json';
  static String suggestionFileName(String id) => 'suggestion-$id.json';
  Future<Map<String, dynamic>?> readManifest();            // null when absent
  Future<void> writeManifest(Map<String, dynamic> manifest);
  Future<SharedLibraryRoles> readRoles();                   // empty when absent
  Future<void> writeRoles(SharedLibraryRoles roles);
  Future<List<SharedLibraryMember>> listMembers();          // downloads every card
  Future<void> writeMember(SharedLibraryMember m, {required String appVersion});
  Future<void> deleteMember(String memberId);
  Future<List<CloudFileInfo>> listSites();                  // name = site-<id>.json
  Future<SiteDocument> readSite(String fileId);
  Future<DateTime> writeSite(SiteDocument doc);             // returns modifiedTime after upload (getFileInfo)
  Future<List<CloudFileInfo>> listSuggestions();
  Future<Map<String, dynamic>> readSuggestion(String fileId);
  Future<void> writeSuggestion(String id, Map<String, dynamic> json);
  Future<void> deleteSuggestion(String id);
  static String siteIdOf(CloudFileInfo f);                  // strips prefix and .json
  static bool isPermissionError(Object e);                  // 401/403/Forbidden/AccessDenied in message or cause
}

enum SharedLibrarySyncStatus { success, readOnly, notALibrary, needsNewerApp, notConnected, failed }
class SharedLibrarySyncResult { final SharedLibrarySyncStatus status; final int pulled; final int pushed; final String? error; }

class SharedLibraryService {
  SharedLibraryService({
    required SharedLibraryStore store,
    required Future<SharedLibraryTransport> Function(SharedLibrary library) transportFor,
    SiteDocumentBridge? bridge,
    SiteDetacher? detacher,          // Task 12; null means "remove the row" on tombstones
    String appVersion = 'test',
    int Function()? now,
  });
  /// One library, for the profile [diverId]. Never runs twice at once for
  /// the same library (an internal per-library Completer gate).
  Future<SharedLibrarySyncResult> sync(String libraryId, {required String diverId});
}
```

The prefix the transport receives is the club prefix relative to the account's sync folder; the transport resolves `root = createFolder(prefix, parentFolderId: await getOrCreateSyncFolder())` once (S3 returns the key prefix, WebDAV ensures the collection), then `members`, `sites` and `suggestions` the same way under root. All reads and writes pass those folder ids. An empty prefix uses the sync folder itself as root.

- [ ] **Step 1: Write the failing transport test**

```dart
// test/core/services/shared_library/shared_library_transport_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryTransport t;
  setUp(() {
    cloud = FakeCloudStorageProvider();
    t = SharedLibraryTransport(cloud, prefix: 'club');
  });

  test('manifest and roles round trip; absent reads as null and empty', () async {
    expect(await t.readManifest(), isNull);
    expect(await t.readRoles(), SharedLibraryRoles.empty);
    await t.writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 1});
    await t.writeRoles(const SharedLibraryRoles(owners: {'m1'}));
    expect((await t.readManifest())!['name'], 'Club');
    expect((await t.readRoles()).roleOf('m1'), SharedLibraryRole.owner);
  });

  test('sites, members and suggestions are listed apart', () async {
    await t.writeSite(const SiteDocument(id: 's1', fields: {'name': 'A'}));
    await t.writeMember(SharedLibraryMember(memberId: 'm1', displayName: 'Ann', joinedAt: DateTime.utc(2026)), appVersion: '1');
    await t.writeSuggestion('g1', {'siteId': 's1'});
    expect((await t.listSites()).map(SharedLibraryTransport.siteIdOf), ['s1']);
    expect((await t.listMembers()).single.displayName, 'Ann');
    expect(await t.listSuggestions(), hasLength(1));
    expect((await t.readSite((await t.listSites()).single.id)).fields['name'], 'A');
  });

  test('isPermissionError recognises 403 and AccessDenied', () {
    expect(SharedLibraryTransport.isPermissionError(const CloudStorageException('Upload failed', cause: 'HTTP 403')), isTrue);
    expect(SharedLibraryTransport.isPermissionError(const CloudStorageException('AccessDenied')), isTrue);
    expect(SharedLibraryTransport.isPermissionError(const CloudStorageException('timeout')), isFalse);
  });
}
```

Check `CloudStorageException`'s constructor at `cloud_storage_provider.dart:32-40` for the `cause` parameter name.

- [ ] **Step 2: Write the failing service test**

```dart
// test/core/services/shared_library/shared_library_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

const _lib = SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'acc', prefix: 'club');

/// A fresh device for [member] joined to the shared fake [cloud].
Future<SharedLibraryService> device(FakeCloudStorageProvider cloud, String member) async {
  await setUpTestDatabase();
  await DiverRepository().createDiver(Diver(id: 'd-$member', name: member));
  final store = SharedLibraryStore();
  await store.upsertLibrary(_lib);
  await store.upsertMembership(SharedLibraryMembership(
    id: 'ms-$member', diverId: 'd-$member', libraryId: 'L', memberId: member,
    displayName: member, libraryName: 'Club', backendKind: 's3'));
  return SharedLibraryService(
    store: store,
    transportFor: (lib) async => SharedLibraryTransport(cloud, prefix: lib.prefix),
  );
}

Future<void> seedLibrary(FakeCloudStorageProvider cloud, {Set<String> owners = const {'a'}}) async {
  final t = SharedLibraryTransport(cloud, prefix: 'club');
  await t.writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 1});
  await t.writeRoles(SharedLibraryRoles(owners: owners));
}

void main() {
  tearDown(() async {
    try { await tearDownTestDatabase(); } catch (_) {}
  });

  test('a pushed site reaches another member with its clocks', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    var svc = await device(cloud, 'a');
    await SiteRepository().createSite(const DiveSite(id: 's1', name: 'Blue', hazards: 'current', sharedLibraryId: 'L'));
    await SharedLibraryStore().putSiteState(SharedSiteState(siteId: 's1', libraryId: 'L', dirty: true));
    final ra = await svc.sync('L', diverId: 'd-a');
    expect(ra.status, SharedLibrarySyncStatus.success);
    expect(ra.pushed, 1);
    expect((await SharedLibraryStore().getSiteState('s1'))!.dirty, isFalse);
    await tearDownTestDatabase();

    svc = await device(cloud, 'b');
    final rb = await svc.sync('L', diverId: 'd-b');
    expect(rb.pulled, 1);
    final site = (await SiteRepository().getSiteById('s1'))!;
    expect(site.hazards, 'current');
    expect(site.sharedLibraryId, 'L');
    expect((await SharedLibraryStore().getSiteState('s1'))!.clocks['hazards']!.memberId, 'a');
    expect((await SharedLibraryStore().memberNames('L')).keys, containsAll(['a', 'b']));
  });

  test('two members editing different fields converge', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    var svc = await device(cloud, 'a');
    await SiteRepository().createSite(const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'));
    await SharedLibraryStore().putSiteState(SharedSiteState(siteId: 's1', libraryId: 'L', dirty: true));
    await svc.sync('L', diverId: 'd-a');
    await tearDownTestDatabase();

    svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    var site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(site.copyWith(parkingInfo: 'lot B'), actingDiverId: 'd-b');
    await svc.sync('L', diverId: 'd-b');
    await tearDownTestDatabase();

    svc = await device(cloud, 'a');
    await svc.sync('L', diverId: 'd-a');
    site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(site.copyWith(hazards: 'current'), actingDiverId: 'd-a');
    await svc.sync('L', diverId: 'd-a');
    site = (await SiteRepository().getSiteById('s1'))!;
    expect(site.parkingInfo, 'lot B');
    expect(site.hazards, 'current');
    final doc = await SharedLibraryTransport(cloud, prefix: 'club').readSite('site-s1.json');
    expect(doc.fields['parkingInfo'], 'lot B');
    expect(doc.clocks['hazards']!.memberId, 'a');
  });

  test('an overwritten upload is re-merged and re-uploaded next sync', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a', 'b'});
    var svc = await device(cloud, 'a');
    await SiteRepository().createSite(const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'));
    await SharedLibraryStore().putSiteState(SharedSiteState(siteId: 's1', libraryId: 'L', dirty: true));
    await svc.sync('L', diverId: 'd-a');
    var site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(site.copyWith(hazards: 'A says'), actingDiverId: 'd-a');
    // B overwrites the document before A uploads (simulated by writing straight to the cloud).
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    final remote = await t.readSite('site-s1.json');
    await t.writeSite(remote.copyWith(
      fields: {...remote.fields, 'notes': 'B says'},
      clocks: {...remote.clocks, 'notes': FieldClock(hlc: Hlc(DateTime.now().millisecondsSinceEpoch + 1000, 0, 'b'), memberId: 'b')},
    ));
    await svc.sync('L', diverId: 'd-a');
    site = (await SiteRepository().getSiteById('s1'))!;
    expect(site.hazards, 'A says');
    expect(site.notes, 'B says');
    final doc = await t.readSite('site-s1.json');
    expect(doc.fields['hazards'], 'A says');
    expect(doc.fields['notes'], 'B says');
  });

  test('a refused upload marks the library read-only and keeps the site dirty', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final svc = await device(cloud, 'a');
    await SiteRepository().createSite(const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'));
    await SharedLibraryStore().putSiteState(SharedSiteState(siteId: 's1', libraryId: 'L', dirty: true));
    cloud.failUploads = true;
    cloud.uploadException = const CloudStorageException('Forbidden', cause: 'HTTP 403');
    final r = await svc.sync('L', diverId: 'd-a');
    expect(r.status, SharedLibrarySyncStatus.readOnly);
    expect((await SharedLibraryStore().getLibrary('L'))!.readOnlyDetected, isTrue);
    expect((await SharedLibraryStore().getSiteState('s1'))!.dirty, isTrue);
  });

  test('a missing manifest stops the sync and keeps local rows', () async {
    final cloud = FakeCloudStorageProvider();
    final svc = await device(cloud, 'a');
    await SiteRepository().createSite(const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'));
    final r = await svc.sync('L', diverId: 'd-a');
    expect(r.status, SharedLibrarySyncStatus.notALibrary);
    expect(await SiteRepository().getSiteById('s1'), isNotNull);
    expect((await SharedLibraryStore().getLibrary('L'))!.lastError, isNotNull);
  });

  test('a newer format version stops the sync', () async {
    final cloud = FakeCloudStorageProvider();
    await SharedLibraryTransport(cloud, prefix: 'club').writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 2});
    final svc = await device(cloud, 'a');
    expect((await svc.sync('L', diverId: 'd-a')).status, SharedLibrarySyncStatus.needsNewerApp);
  });

  test('roles and members are cached; ghost ids survive', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a', 'ghost'});
    final svc = await device(cloud, 'a');
    await svc.sync('L', diverId: 'd-a');
    final lib = (await SharedLibraryStore().getLibrary('L'))!;
    expect(lib.roles.owners, containsAll(['a', 'ghost']));
  });

  test('a remote tombstone removes an unlinked local row and keeps its state', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    await t.writeSite(SiteDocument(id: 's1', fields: {'name': 'Gone'},
      clocks: {'name': FieldClock(hlc: Hlc(1, 0, 'a'), memberId: 'a')}));
    final svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    expect(await SiteRepository().getSiteById('s1'), isNotNull);
    await t.writeSite(SiteDocument(id: 's1', deleted: true,
      clocks: {'deleted': FieldClock(hlc: Hlc(2, 0, 'a'), memberId: 'a')}));
    await svc.sync('L', diverId: 'd-b');
    expect(await SiteRepository().getSiteById('s1'), isNull);
    expect((await SharedLibraryStore().getSiteState('s1'))!.deleted, isTrue);
  });
}
```

Add `import 'package:submersion/core/services/sync/hlc.dart';` and `site_document.dart` imports where used. The fake's `uploadFile` needs the new `uploadException` field: `if (failUploads) throw uploadException ?? const CloudStorageException('upload failed (test)');`.

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/core/services/shared_library/shared_library_transport_test.dart test/core/services/shared_library/shared_library_service_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement the transport**

```dart
class SharedLibraryTransport {
  SharedLibraryTransport(this._provider, {required String prefix}) : _prefix = prefix.trim();
  final CloudStorageProvider _provider;
  final String _prefix;
  String? _root, _members, _sites, _suggestions;

  Future<String> _rootId() async => _root ??= _prefix.isEmpty
      ? await _provider.getOrCreateSyncFolder()
      : await _provider.createFolder(_prefix, parentFolderId: await _provider.getOrCreateSyncFolder());
  Future<String> _membersId() async => _members ??= await _provider.createFolder(SharedLibraryLayout.membersDir, parentFolderId: await _rootId());
  // _sitesId, _suggestionsId likewise.

  Future<Map<String, dynamic>?> readManifest() async {
    final f = await _find(await _rootId(), SharedLibraryLayout.manifestFile);
    if (f == null) return null;
    final decoded = jsonDecode(utf8.decode(await _provider.downloadFile(f.id)));
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<CloudFileInfo?> _find(String folderId, String name) async {
    final files = await _provider.listFiles(folderId: folderId, namePattern: name);
    for (final f in files) {
      if (f.name == name || f.name.endsWith('/$name')) return f;
    }
    return null;
  }

  Future<List<CloudFileInfo>> listSites() async =>
      (await _provider.listFiles(folderId: await _sitesId(), namePattern: 'site-'))
          .where((f) => f.name.endsWith('.json')).toList();

  Future<DateTime> writeSite(SiteDocument doc) async {
    final name = siteFileName(doc.id);
    final result = await _provider.uploadFile(SiteDocument.encode(doc), name, folderId: await _sitesId());
    final info = await _provider.getFileInfo(result.fileId);
    return info?.modifiedTime ?? result.uploadTime;
  }

  static String siteIdOf(CloudFileInfo f) {
    final base = f.name.split('/').last;
    return base.substring('site-'.length, base.length - '.json'.length);
  }

  static bool isPermissionError(Object e) {
    final text = e is CloudStorageException ? '${e.message} ${e.cause ?? ''}' : e.toString();
    return RegExp(r'\b(401|403)\b|Forbidden|AccessDenied|Unauthorized', caseSensitive: false).hasMatch(text);
  }
}
```

Write the members, roles and suggestions methods the same way (`member-` and `suggestion-` prefixes, `roles.json` and the manifest at root). Every method lets `CloudStorageException` propagate; the service decides.

- [ ] **Step 5: Implement the service**

```dart
class SharedLibraryService {
  final _gates = <String, Future<void>>{};

  Future<SharedLibrarySyncResult> sync(String libraryId, {required String diverId}) async {
    final previous = _gates[libraryId] ?? Future.value();
    final completer = Completer<void>();
    _gates[libraryId] = previous.then((_) => completer.future);
    await previous;
    try {
      return await _syncOnce(libraryId, diverId: diverId);
    } finally {
      completer.complete();
    }
  }

  Future<SharedLibrarySyncResult> _syncOnce(String libraryId, {required String diverId}) async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) return const SharedLibrarySyncResult(status: SharedLibrarySyncStatus.notConnected);
    final membership = await _store.membership(diverId: diverId, libraryId: libraryId);
    try {
      final t = await _transportFor(library);
      // 1. manifest
      final manifest = await t.readManifest();
      if (manifest == null) return _fail(libraryId, SharedLibrarySyncStatus.notALibrary, 'No library at this location');
      final version = (manifest['formatVersion'] as num?)?.toInt() ?? 1;
      if (version > SharedLibraryLayout.formatVersion) return _fail(libraryId, SharedLibrarySyncStatus.needsNewerApp, 'Library format $version needs a newer app');
      // 2. roles and members
      final roles = await t.readRoles();
      final members = await t.listMembers();
      await _store.setLibraryStatus(libraryId, roles: roles, name: manifest['name'] as String?);
      await _store.replaceMembers(libraryId, members);
      var readOnly = library.readOnlyDetected;
      if (membership != null) {
        final mine = members.where((m) => m.memberId == membership.memberId).firstOrNull;
        if (mine == null || mine.displayName != membership.displayName) {
          readOnly = await _tryWrite(libraryId, readOnly, () => t.writeMember(
            SharedLibraryMember(memberId: membership.memberId, displayName: membership.displayName, joinedAt: mine?.joinedAt ?? DateTime.now().toUtc()),
            appVersion: _appVersion));
        }
      }
      // 3. pull
      final states = await _store.siteStates(libraryId);
      var pulled = 0;
      final clock = MemberClock(membership?.memberId ?? 'unknown');
      for (final f in await t.listSites()) {
        final siteId = SharedLibraryTransport.siteIdOf(f);
        final state = states[siteId];
        if (state != null && state.remoteModifiedTime == f.modifiedTime.toUtc().toIso8601String()) continue;
        final SiteDocument remote;
        try {
          remote = await t.readSite(f.id);
        } on FormatException catch (e) {
          _log.warning('Skipping unreadable site document ${f.name}: $e');
          continue;
        }
        pulled += await _mergeRemote(library, remote, f, state, diverId: diverId, clock: clock) ? 1 : 0;
      }
      // 4. push
      var pushed = 0;
      for (final state in await _store.dirtySites(libraryId)) {
        if (readOnly) break;
        final doc = await _documentFor(state);
        try {
          final modified = await t.writeSite(doc);
          await _store.putSiteState(state.copyWith(dirty: false, remoteModifiedTime: modified.toUtc().toIso8601String()));
          pushed++;
        } catch (e) {
          if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
          readOnly = true;
        }
      }
      // 5. suggestions (Task 13 adds the owner inbox; the upload lives here)
      await _uploadSuggestions(t, libraryId, readOnlyForSites: readOnly);
      await _pullSuggestions(t, libraryId, roles: roles, membership: membership);
      // 6. status
      await _store.setLibraryStatus(libraryId, lastSyncAt: DateTime.now(), clearError: true, readOnlyDetected: readOnly);
      return SharedLibrarySyncResult(status: readOnly ? SharedLibrarySyncStatus.readOnly : SharedLibrarySyncStatus.success, pulled: pulled, pushed: pushed);
    } catch (e, st) {
      _log.error('Library $libraryId sync failed', error: e, stackTrace: st);
      return _fail(libraryId, SharedLibrarySyncStatus.failed, e is CloudStorageException ? e.displayMessage : e.toString());
    }
  }
```

`_mergeRemote`: local document = `state == null ? SiteDocument(id) : await _bridge.build(siteId, state)` (when the local row is missing but a state exists, treat local as `SiteDocument(id: siteId, deleted: state.deleted, clocks: state.clocks)`); `outcome = mergeSiteDocuments(local:, remote:)`; fold every remote clock into `clock.receive`. If `outcome.merged.deleted`: hand the site to `_detacher` (Task 12) or delete the row through `SiteRepository().deleteSite(siteId)` guarded by Task 9's no-tombstone path; store the state with `deleted: true`, `dirty: outcome.needsUpload`, the clocks and `remoteModifiedTime`. Otherwise `await _bridge.apply(outcome.merged, libraryId: library.id, vocabularyDiverId: diverId, fields: outcome.remoteWon)`, then store the state with the merged clocks, `dirty: state?.dirty == true || outcome.needsUpload`, `remoteModifiedTime: f.modifiedTime...`, `lastEditorMemberId` and `lastEditedAtMs` from the newest clock. Returns `outcome.changesLocal`. `_documentFor(state)`: `state.deleted ? SiteDocument(id: state.siteId, deleted: true, clocks: state.clocks) : await _bridge.build(state.siteId, state)`. `_fail` records `lastError` through `setLibraryStatus` and returns the result. `_uploadSuggestions`: for each `suggestions(libraryId, direction: 'outgoing', status: 'pending')` call `t.writeSuggestion(id, json)` and set `status: 'uploaded'`; a permission error here is reported as failed (readers are allowed to write suggestions by policy). `_pullSuggestions`: only when `roles.roleOf(membership.memberId) == owner`: list remote suggestions, download ids not yet stored as incoming, store them; delete local incoming rows whose file is gone.

Suggestion JSON: `{id, siteId, memberId, memberName, note, fields, createdAt}`.

- [ ] **Step 6: Run the tests, then commit**

Run: `flutter test test/core/services/shared_library/`
Expected: PASS.

```bash
git add lib/core/services/shared_library/shared_library_transport.dart lib/core/services/shared_library/shared_library_service.dart test/helpers/fake_cloud_storage_provider.dart test/core/services/shared_library/shared_library_transport_test.dart test/core/services/shared_library/shared_library_service_test.dart
git commit -m "feat(shared-library): club folder transport and the library sync"
```

---

### Task 12: Connect, create, join, leave, push and detach

**Files:**
- Create: `lib/core/services/shared_library/shared_library_membership_service.dart`
- Create: `lib/core/services/shared_library/shared_site_publisher.dart`
- Create: `lib/core/services/shared_library/site_detacher.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (expose `relinkSiteReferences(from, to)` built from `_relinkDives`, `_relinkPlans`, `_relinkMedia`, `_relinkSiteFeatures`, `SiteClassificationRepository.relinkForMerge`, `_mergeExpectedSpecies`, and `hasLinks(siteId)` from `countLinksToSites`)
- Test: `test/core/services/shared_library/shared_library_membership_service_test.dart`
- Test: `test/core/services/shared_library/shared_site_publisher_test.dart`
- Test: `test/core/services/shared_library/site_detacher_test.dart`

**Interfaces:**

```dart
class LibraryProbe { final bool exists; final String? id; final String? name; final int formatVersion; }

class SharedLibraryMembershipService {
  SharedLibraryMembershipService({required SharedLibraryStore store, required Future<SharedLibraryTransport> Function({required ConnectedAccount account, required String prefix}) transportFor, String appVersion = 'test'});
  Future<LibraryProbe> probe({required ConnectedAccount account, required String prefix});
  /// Writes manifest, roles (creator owner), member card; stores library and membership.
  Future<SharedLibrary> create({required ConnectedAccount account, required String prefix, required String name, required String diverId, required String displayName});
  /// Reads the manifest, writes the member card, stores library and membership.
  Future<SharedLibrary> join({required ConnectedAccount account, required String prefix, required String diverId, required String displayName});
  /// Deletes the member card when allowed, the membership row, and detaches
  /// or removes every library site; removes the library row when no other
  /// profile on this device holds a membership.
  Future<void> leave({required String libraryId, required String diverId});
  Future<void> rename({required String libraryId, required String diverId, required String displayName});
  /// Owners only: rewrites roles.json and the cache. Refuses to demote the last owner.
  Future<void> setRole({required String libraryId, required String memberId, required SharedLibraryRole role});
}

class SharedSitePublisher {
  SharedSitePublisher({SharedLibraryStore? store, SiteDocumentBridge? bridge});
  /// Converts a personal site in place: sharedLibraryId set, diverId and
  /// isShared cleared, every field clocked under the member, dirty.
  Future<void> push({required String siteId, required String libraryId, required String diverId});
  /// Editors and owners: stamps deleted=true, detaches or removes locally.
  Future<void> deleteFromLibrary({required String siteId, required String diverId});
  Future<void> undelete({required String siteId, required String diverId});
}

class SiteDetacher {
  /// A library site leaving this device: linked rows survive as a personal
  /// site under a new id (dives, plans, media, features, species, types,
  /// tags relinked), unlinked ones are removed with no tombstone. Returns
  /// the new personal id or null.
  Future<String?> detachOrRemove({required String siteId, required String ownerDiverId});
}
```

The membership `locationHint` is `'${account.label}: $prefix'`; `backendKind` is `account.kind.name`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/shared_library/site_detacher_test.dart
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(const Diver(id: 'd1', name: 'Ann'));
    await SiteRepository().createSite(const DiveSite(id: 'lib', name: 'Club', sharedLibraryId: 'L'));
    await SharedLibraryStore().putSiteState(SharedSiteState(siteId: 'lib', libraryId: 'L'));
  });
  tearDown(tearDownTestDatabase);

  test('a site with a dive survives as a personal site under a new id', () async {
    await DiveRepository().createDive(createTestDiveWithBottomTime(id: 'dv', diveNumber: 1).copyWith(siteId: 'lib'));
    final newId = await SiteDetacher().detachOrRemove(siteId: 'lib', ownerDiverId: 'd1');
    expect(newId, isNotNull);
    expect(await SiteRepository().getSiteById('lib'), isNull);
    final kept = (await SiteRepository().getSiteById(newId!))!;
    expect(kept.sharedLibraryId, isNull);
    expect(kept.diverId, 'd1');
    expect(kept.name, 'Club');
    final dive = (await DiveRepository().getDiveById('dv'))!;
    expect(dive.siteId, newId);
    expect(await SharedLibraryStore().getSiteState('lib'), isNull);
  });

  test('an unlinked site is removed without a tombstone', () async {
    expect(await SiteDetacher().detachOrRemove(siteId: 'lib', ownerDiverId: 'd1'), isNull);
    expect(await SiteRepository().getSiteById('lib'), isNull);
    final rows = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM deletion_log WHERE entity_type = 'diveSites' AND record_id = 'lib'").get();
    expect(rows, isEmpty);
  });
}
```

Use the dive fixture helper the convergence test imports (`createTestDiveWithBottomTime`; find its file under `test/helpers/`) and check how a dive's site is set on the `Dive` entity (`site` or `siteId`).

```dart
// test/core/services/shared_library/shared_site_publisher_test.dart
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(const Diver(id: 'd1', name: 'Ann'));
    await SharedLibraryStore().upsertLibrary(const SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'acc', prefix: 'club'));
    await SharedLibraryStore().upsertMembership(const SharedLibraryMembership(
      id: 'ms', diverId: 'd1', libraryId: 'L', memberId: 'm1', displayName: 'Ann', libraryName: 'Club', backendKind: 's3'));
  });
  tearDown(tearDownTestDatabase);

  test('push converts in place and clocks every field', () async {
    await SiteRepository().createSite(const DiveSite(id: 'p', diverId: 'd1', name: 'Mine', isShared: true, hazards: 'h'));
    await ProfileHidesRepository().hide(SharedItemKind.site, 'p', diverId: 'd1');
    await SharedSitePublisher().push(siteId: 'p', libraryId: 'L', diverId: 'd1');
    final site = (await SiteRepository().getSiteById('p'))!;
    expect(site.sharedLibraryId, 'L');
    expect(site.diverId, isNull);
    expect(site.isShared, isFalse);
    final state = (await SharedLibraryStore().getSiteState('p'))!;
    expect(state.dirty, isTrue);
    expect(state.clocks.keys, containsAll(SiteDocument.fieldNames));
    expect(state.clocks['name']!.memberId, 'm1');
    final hides = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM site_hides WHERE site_id = 'p'").get();
    expect(hides, hasLength(1), reason: 'hides are left in place');
  });

  test('deleteFromLibrary stamps the tombstone and removes the unlinked row', () async {
    await SiteRepository().createSite(const DiveSite(id: 'lib', name: 'Club', sharedLibraryId: 'L'));
    await SharedLibraryStore().putSiteState(SharedSiteState(siteId: 'lib', libraryId: 'L'));
    await SharedSitePublisher().deleteFromLibrary(siteId: 'lib', diverId: 'd1');
    final state = (await SharedLibraryStore().getSiteState('lib'))!;
    expect(state.deleted, isTrue);
    expect(state.dirty, isTrue);
    expect(state.clocks['deleted']!.memberId, 'm1');
    expect(await SiteRepository().getSiteById('lib'), isNull);
  });
}
```

```dart
// test/core/services/shared_library/shared_library_membership_service_test.dart
void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryMembershipService service;
  final account = ConnectedAccount(id: 'acc', kind: AccountKind.s3, label: 'Club bucket', createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026));
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(const Diver(id: 'd1', name: 'Ann'));
    cloud = FakeCloudStorageProvider();
    service = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async => SharedLibraryTransport(cloud, prefix: prefix),
    );
  });
  tearDown(tearDownTestDatabase);

  test('probe, create, then a second profile joins', () async {
    expect((await service.probe(account: account, prefix: 'club')).exists, isFalse);
    final lib = await service.create(account: account, prefix: 'club', name: 'Club', diverId: 'd1', displayName: 'Ann');
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    expect((await t.readManifest())!['name'], 'Club');
    final me = (await SharedLibraryStore().membership(diverId: 'd1', libraryId: lib.id))!;
    expect((await t.readRoles()).roleOf(me.memberId), SharedLibraryRole.owner);
    expect((await t.listMembers()).single.displayName, 'Ann');
    expect((await service.probe(account: account, prefix: 'club')).name, 'Club');

    await DiverRepository().createDiver(const Diver(id: 'd2', name: 'Bob'));
    await service.join(account: account, prefix: 'club', diverId: 'd2', displayName: 'Bob');
    expect(await t.listMembers(), hasLength(2));
    expect(await SharedLibraryStore().getLibraries(), hasLength(1));
  });

  test('setRole refuses to demote the last owner', () async {
    final lib = await service.create(account: account, prefix: 'club', name: 'Club', diverId: 'd1', displayName: 'Ann');
    final me = (await SharedLibraryStore().membership(diverId: 'd1', libraryId: lib.id))!;
    expect(() => service.setRole(libraryId: lib.id, memberId: me.memberId, role: SharedLibraryRole.editor), throwsStateError);
  });

  test('leave removes the membership, detaches linked sites, drops the library when unused', () async {
    final lib = await service.create(account: account, prefix: 'club', name: 'Club', diverId: 'd1', displayName: 'Ann');
    await SiteRepository().createSite(DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: lib.id));
    await SharedLibraryStore().putSiteState(SharedSiteState(siteId: 'lib', libraryId: lib.id));
    await service.leave(libraryId: lib.id, diverId: 'd1');
    expect(await SharedLibraryStore().membership(diverId: 'd1', libraryId: lib.id), isNull);
    expect(await SharedLibraryStore().getLibrary(lib.id), isNull);
    expect(await SiteRepository().getSiteById('lib'), isNull);
  });
}
```

Check `ConnectedAccount`'s constructor at `connected_account.dart:6-12`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/shared_library/`
Expected: FAIL for the three new files.

- [ ] **Step 3: Implement**

`SiteDetacher.detachOrRemove`:

```dart
  Future<String?> detachOrRemove({required String siteId, required String ownerDiverId}) async {
    final repo = SiteRepository();
    final site = await repo.getSiteById(siteId);
    if (site == null) { await _store.deleteSiteState(siteId); return null; }
    if (!await repo.hasLinks(siteId)) {
      await repo.deleteSite(siteId, logTombstones: false);   // Task 9's flag, threaded through deleteSite
      await _store.deleteSiteState(siteId);
      return null;
    }
    final newId = const Uuid().v4();
    await _db.transaction(() async {
      await repo.createSite(site.copyWith(id: newId, diverId: ownerDiverId, isShared: false, clearSharedLibraryId: true));
      await repo.relinkSiteReferences(from: siteId, to: newId);
      await repo.deleteSite(siteId, logTombstones: false, cascadeMedia: false);
      await _store.deleteSiteState(siteId);
    });
    SyncEventBus.notifyLocalChange();
    return newId;
  }
```

`relinkSiteReferences` in the site repository wraps the private relink helpers used by `mergeSites` (lines 911-914 and `_mergeExpectedSpecies`, plus `SiteClassificationRepository.relinkForMerge`) for a single `from`. `createSite` must accept a caller-supplied id (check line 139; if it always mints one, add an optional `id` parameter). `hasLinks` is `(await countLinksToSites(_db, [siteId]))` having any dives or plans.

`SharedSitePublisher.push`: membership lookup (throw `StateError` when the diver has none); update the row (`sharedLibraryId`, `diverId: null`, `isShared: false`, `updatedAt`); build clocks for every `SiteDocument.fieldNames` entry under a `MemberClock(memberId)`; `putSiteState(dirty: true, lastEditor..)`; `SyncEventBus.notifyLocalChange()`. `deleteFromLibrary`: stamp `deleted` with a fresh clock (fold the existing clocks in first), `putSiteState(deleted: true, dirty: true)`, then `SiteDetacher().detachOrRemove(siteId:, ownerDiverId: diverId)` must NOT delete the state row in this path: give `detachOrRemove` a `bool keepState = false` parameter and pass true here. `undelete`: requires the state row, stamps `deleted: false`, dirty; the row is recreated on the next pull from the library's document (fields are not kept locally after a delete), so `undelete` is only offered while the document still exists remotely (Task 18 shows it on the History sheet of a detached copy only when the state row exists and `deleted` is true; keep the scope small: `undelete` re-pulls by clearing `remoteModifiedTime`).

`SharedLibraryMembershipService.create`: `libraryId = uuid`, transport for (account, prefix), `writeManifest({'id', 'name', 'formatVersion': 1, 'createdBy': memberId, 'createdAt': iso})`, `writeRoles(owners: {memberId})`, `writeMember`, `store.upsertLibrary`, `store.upsertMembership(id: uuid, memberId: await store.memberIdForDiver(diverId), ...)`. `join`: `probe` first (throw `StateError('not a library')` when absent, `needsNewerApp` when the version is higher), then member card, library row (`readOnlyDetected` false), membership. `leave`: detach every site with `sharedLibraryId == libraryId` through `SiteDetacher` (ownerDiverId = diverId), delete the membership (tombstoned for personal sync), `try { await t.deleteMember(memberId); } catch (_) {}` (a reader may lack delete rights; the card going stale is harmless), and drop the library row plus members when `(await store.getLibraries())` no longer has a membership for it from any diver (`membershipsForLibrary(libraryId)` on the store; add it). `setRole`: read the cached roles, refuse when removing the only owner, `writeRoles`, `setLibraryStatus(roles:)`.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/shared_library/ test/features/dive_sites`
Expected: PASS.

```bash
git add lib/core/services/shared_library lib/features/dive_sites/data/repositories/site_repository_impl.dart test/core/services/shared_library
git commit -m "feat(shared-library): connect, join, leave, push and detach"
```

---

### Task 13: Suggestions

**Files:**
- Create: `lib/core/services/shared_library/suggestion_service.dart`
- Test: `test/core/services/shared_library/suggestion_service_test.dart`

**Interfaces:**

```dart
class SuggestionService {
  SuggestionService({SharedLibraryStore? store, SiteDocumentBridge? bridge, Future<SharedLibraryTransport> Function(SharedLibrary)? transportFor});
  /// A reader's proposal: the fields of [proposed] that differ from the
  /// stored site, plus the note. Returns null when nothing changed.
  Future<SharedSiteSuggestion?> propose({required DiveSite proposed, required String diverId, String note = ''});
  Future<void> withdraw(String suggestionId);                       // outgoing, pending only
  /// Owner: applies the fields with clocks under the suggester, dirties
  /// the site, deletes the remote file and the local row.
  Future<void> accept(String suggestionId, {required String diverId});
  Future<void> dismiss(String suggestionId);                        // deletes remote file and local row
  /// For the review sheet: field name to (before, after).
  Future<Map<String, (Object?, Object?)>> diff(SharedSiteSuggestion s);
}
```

- [ ] **Step 1: Write the failing test**

```dart
void main() {
  late FakeCloudStorageProvider cloud;
  late SuggestionService service;
  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    await DiverRepository().createDiver(const Diver(id: 'reader', name: 'Ray'));
    await DiverRepository().createDiver(const Diver(id: 'owner', name: 'Olga'));
    final store = SharedLibraryStore();
    await store.upsertLibrary(const SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'acc', prefix: 'club',
        roles: SharedLibraryRoles(owners: {'o'})));
    await store.upsertMembership(const SharedLibraryMembership(id: 'm-r', diverId: 'reader', libraryId: 'L', memberId: 'r', displayName: 'Ray', libraryName: 'Club', backendKind: 's3'));
    await store.upsertMembership(const SharedLibraryMembership(id: 'm-o', diverId: 'owner', libraryId: 'L', memberId: 'o', displayName: 'Olga', libraryName: 'Club', backendKind: 's3'));
    await SiteRepository().createSite(const DiveSite(id: 's', name: 'S', hazards: 'old', sharedLibraryId: 'L'));
    await store.putSiteState(SharedSiteState(siteId: 's', libraryId: 'L'));
    service = SuggestionService(transportFor: (lib) async => SharedLibraryTransport(cloud, prefix: lib.prefix));
  });
  tearDown(tearDownTestDatabase);

  test('propose stores only the changed fields and leaves the site alone', () async {
    final site = (await SiteRepository().getSiteById('s'))!;
    final s = await service.propose(proposed: site.copyWith(hazards: 'new', notes: 'n'), diverId: 'reader', note: 'please');
    expect(s!.fields, {'hazards': 'new', 'notes': 'n'});
    expect(s.direction, 'outgoing');
    expect((await SiteRepository().getSiteById('s'))!.hazards, 'old');
    expect(await service.propose(proposed: site, diverId: 'reader'), isNull);
  });

  test('accept applies with the suggester as editor and removes the file', () async {
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    await t.writeSuggestion('g1', {'id': 'g1', 'siteId': 's', 'memberId': 'r', 'memberName': 'Ray', 'note': '', 'fields': {'hazards': 'new'}, 'createdAt': '2026-10-12T00:00:00Z'});
    await SharedLibraryStore().putSuggestion(SharedSiteSuggestion(id: 'g1', libraryId: 'L', siteId: 's', memberId: 'r', memberName: 'Ray',
        fields: const {'hazards': 'new'}, createdAt: DateTime.utc(2026), direction: 'incoming', status: 'pending'));
    final d = await service.diff((await SharedLibraryStore().suggestions('L')).single);
    expect(d['hazards'], ('old', 'new'));
    await service.accept('g1', diverId: 'owner');
    expect((await SiteRepository().getSiteById('s'))!.hazards, 'new');
    final state = (await SharedLibraryStore().getSiteState('s'))!;
    expect(state.clocks['hazards']!.memberId, 'r');
    expect(state.dirty, isTrue);
    expect(await t.listSuggestions(), isEmpty);
    expect(await SharedLibraryStore().suggestions('L'), isEmpty);
  });

  test('dismiss drops the file and the row; a vanished file is tolerated', () async {
    await SharedLibraryStore().putSuggestion(SharedSiteSuggestion(id: 'g2', libraryId: 'L', siteId: 's', memberId: 'r', memberName: 'Ray',
        fields: const {'notes': 'x'}, createdAt: DateTime.utc(2026), direction: 'incoming', status: 'pending'));
    await service.dismiss('g2');
    expect(await SharedLibraryStore().suggestions('L'), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/shared_library/suggestion_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`propose`: load the stored site, `changed = LibraryEditStamper.changedFields(stored, proposed)` plus list fields when the page passed new classification (take an optional `Map<String, Object?> childFields` for `siteTypes`, `tags`, `species`, `features` the edit page computes); null when empty; store `SharedSiteSuggestion(id: uuid, libraryId: stored.sharedLibraryId!, siteId:, memberId:, memberName:, note:, fields: {for f in changed: f: SiteDocumentBridge.fieldValue(proposed, f)}, direction: 'outgoing', status: 'pending')`; `SyncEventBus.notifyLocalChange()`. `accept`: load the row, `bridge.apply(SiteDocument(id: siteId, fields: s.fields), libraryId:, vocabularyDiverId: diverId, fields: s.fields.keys.toSet())`, then stamp each field through `LibraryEditStamper` but under the suggester: add `stamp(..., {String? asMemberId})` to Task 8's stamper; delete remotely (`try { await t.deleteSuggestion(id); } on CloudStorageException catch (e) { if (!_isNotFound(e)) rethrow; }`) and locally. `dismiss` is the delete half. `diff` maps each field to `(SiteDocumentBridge.fieldValue(stored, f), s.fields[f])`, with list fields read through the bridge's `build`.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/shared_library/`
Expected: PASS.

```bash
git add lib/core/services/shared_library/suggestion_service.dart lib/core/services/shared_library/library_edit_stamper.dart test/core/services/shared_library/suggestion_service_test.dart
git commit -m "feat(shared-library): reader suggestions and owner review"
```

---

### Task 14: Notifier, coordinator and triggers

**Files:**
- Create: `lib/core/services/sync/sync_coordinator.dart`
- Create: `lib/features/shared_library/presentation/providers/shared_library_sync_notifier.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart:1370-1395` (`performSync` loop wraps `_runSyncOnce` in `SyncCoordinator.run`)
- Modify: `lib/app.dart:249-271` (`_maybeSyncOnLaunch`, `_maybeSyncOnResume` also call the library notifier)
- Modify: `lib/features/shared_library/presentation/providers/shared_library_providers.dart` (add `sharedLibrarySyncProvider`, `sharedLibraryServiceProvider`, `sharedLibraryMembershipServiceProvider`, `suggestionServiceProvider`, `sharedLibraryTransportFactoryProvider`)
- Test: `test/core/services/sync/sync_coordinator_test.dart`
- Test: `test/features/shared_library/presentation/providers/shared_library_sync_notifier_test.dart`

**Interfaces:**

```dart
/// Serialises every sync that merges into the database (issue #2567): the
/// personal changeset sync and each club library sync wait for one another.
abstract final class SyncCoordinator {
  static Future<T> run<T>(Future<T> Function() body);
  static bool get busy;
  @visibleForTesting static void reset();
}

class SharedLibrarySyncState { final bool syncing; final Map<String, SharedLibrarySyncResult> lastResults; final String? syncingLibraryId; }

class SharedLibrarySyncNotifier extends Notifier<SharedLibrarySyncState> {   // or StateNotifier, matching SyncNotifier's base
  /// Every library the active profile is a member of and that is connected here.
  Future<void> syncAll({bool auto = false});
  Future<SharedLibrarySyncResult> syncOne(String libraryId);
}
final sharedLibrarySyncProvider = NotifierProvider<SharedLibrarySyncNotifier, SharedLibrarySyncState>(...);
```

The transport factory provider builds `SharedLibraryTransport(adapter.syncProvider(account), prefix:)` with `ref.read(accountProviderRegistryProvider).adapterFor(account.kind)` and the account from `ref.read(connectedAccountsRepositoryProvider).getById(library.connectedAccountId)`; a missing account yields `SharedLibrarySyncStatus.notConnected` (the service's `transportFor` throws a `StateError` the service maps).

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/sync/sync_coordinator_test.dart
void main() {
  tearDown(SyncCoordinator.reset);
  test('bodies run one at a time in order', () async {
    final log = <String>[];
    final first = SyncCoordinator.run(() async { log.add('a-start'); await Future.delayed(const Duration(milliseconds: 20)); log.add('a-end'); });
    final second = SyncCoordinator.run(() async { log.add('b'); });
    expect(SyncCoordinator.busy, isTrue);
    await Future.wait([first, second]);
    expect(log, ['a-start', 'a-end', 'b']);
    expect(SyncCoordinator.busy, isFalse);
  });
  test('a throwing body releases the gate', () async {
    await expectLater(SyncCoordinator.run(() async => throw StateError('x')), throwsStateError);
    expect(await SyncCoordinator.run(() async => 1), 1);
  });
}
```

```dart
// test/features/shared_library/presentation/providers/shared_library_sync_notifier_test.dart
void main() {
  test('syncAll syncs each connected library of the active profile and records results', () async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await DiverRepository().createDiver(const Diver(id: 'd1', name: 'Ann'));
    final store = SharedLibraryStore();
    await store.upsertLibrary(const SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'acc', prefix: 'club'));
    await store.upsertMembership(const SharedLibraryMembership(id: 'ms', diverId: 'd1', libraryId: 'L', memberId: 'm', displayName: 'Ann', libraryName: 'Club', backendKind: 's3'));
    final cloud = FakeCloudStorageProvider();
    await SharedLibraryTransport(cloud, prefix: 'club').writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 1});
    final container = ProviderContainer(overrides: [
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      sharedLibraryTransportFactoryProvider.overrideWithValue((lib) async => SharedLibraryTransport(cloud, prefix: lib.prefix)),
    ]);
    addTearDown(container.dispose);
    await container.read(sharedLibrarySyncProvider.notifier).syncAll();
    final state = container.read(sharedLibrarySyncProvider);
    expect(state.lastResults['L']!.status, SharedLibrarySyncStatus.success);
    expect(state.syncing, isFalse);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/sync/sync_coordinator_test.dart test/features/shared_library`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/core/services/sync/sync_coordinator.dart
abstract final class SyncCoordinator {
  static Future<void> _tail = Future.value();
  static int _depth = 0;
  static bool get busy => _depth > 0;

  static Future<T> run<T>(Future<T> Function() body) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) async {
      _depth++;
      try {
        return await body();
      } finally {
        _depth--;
        done.complete();
      }
    });
  }

  @visibleForTesting
  static void reset() { _tail = Future.value(); _depth = 0; }
}
```

In `SyncNotifier.performSync`, replace `final succeeded = await _runSyncOnce(auto: runAuto);` with `final succeeded = await SyncCoordinator.run(() => _runSyncOnce(auto: runAuto));`. The library notifier: `syncAll` reads `validatedCurrentDiverIdProvider`, `store.membershipsForDiver`, filters to libraries present in `store.getLibraries()`, and for each runs `SyncCoordinator.run(() => service.sync(id, diverId:))`, updating state before and after; it listens to `SyncEventBus.changes` with a 5-second debounce and runs `syncAll(auto: true)` only when `store.dirtySites` for any library or pending outgoing suggestions are non-empty and `syncBehaviorProvider.autoSyncEnabled`; a sync requested while one runs is queued once, as `SyncNotifier` does. Register the `test/architecture/test_global_state_restored_test.dart` restore helper for `SyncCoordinator.reset` as `docs/developer/testing.md` prescribes for process-wide state. In `app.dart`, after the personal sync call in both launch and resume paths: `ref.read(sharedLibrarySyncProvider.notifier).syncAll(auto: true);`.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/core/services/sync/sync_coordinator_test.dart test/features/shared_library test/features/settings/presentation/providers test/architecture`
Expected: PASS.

```bash
git add lib/core/services/sync/sync_coordinator.dart lib/features/shared_library/presentation/providers lib/features/settings/presentation/providers/sync_providers.dart lib/app.dart test/core/services/sync/sync_coordinator_test.dart test/features/shared_library
git commit -m "feat(shared-library): library sync notifier, coordinator and triggers"
```

---

### Task 15: Localised strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (new `sharedLibrary_*` group, inserted after the `settings_cloudSync_*` keys near line 12870) and the ten other ARBs (same anchor, translated)
- Test: the generated-l10n staleness check in the pre-push hook; `flutter gen-l10n` must leave `git status` clean of generated drift

**Interfaces:** every later task uses these keys through `context.l10n.<key>`.

| Key | English |
| --- | --- |
| `sharedLibrary_settings_title` | Club libraries |
| `sharedLibrary_settings_subtitle` | Shared dive-site catalogues |
| `sharedLibrary_list_empty` | No club library connected yet. |
| `sharedLibrary_connect_action` | Connect a library |
| `sharedLibrary_connect_account_label` | Storage account |
| `sharedLibrary_connect_prefix_label` | Folder (prefix) |
| `sharedLibrary_connect_prefix_help` | The folder inside the account where the club keeps its library. |
| `sharedLibrary_connect_probe_action` | Check |
| `sharedLibrary_connect_join_action` | Join {name} |
| `sharedLibrary_connect_create_action` | Create library |
| `sharedLibrary_connect_create_name_label` | Library name |
| `sharedLibrary_connect_displayName_label` | Your name in this library |
| `sharedLibrary_connect_notALibrary` | No library here yet. |
| `sharedLibrary_connect_needsNewerApp` | This library needs a newer version of Submersion. |
| `sharedLibrary_connect_onlyS3Webdav` | Club libraries work with S3 and WebDAV accounts. |
| `sharedLibrary_role_reader` | Reader |
| `sharedLibrary_role_editor` | Editor |
| `sharedLibrary_role_owner` | Owner |
| `sharedLibrary_library_members` | Members |
| `sharedLibrary_library_memberCount` | {count, plural, =1{1 member} other{{count} members}} |
| `sharedLibrary_library_syncNow` | Sync now |
| `sharedLibrary_library_lastSync` | Last sync {when} |
| `sharedLibrary_library_neverSynced` | Not synced yet |
| `sharedLibrary_library_readOnlyBanner` | Your credentials allow reading only. You can suggest changes; a referent applies them. |
| `sharedLibrary_library_errorBanner` | Last sync failed: {error} |
| `sharedLibrary_library_addMySites` | Add my sites |
| `sharedLibrary_library_suggestions` | Suggestions |
| `sharedLibrary_library_leave` | Leave library |
| `sharedLibrary_library_leaveConfirm_title` | Leave {name}? |
| `sharedLibrary_library_leaveConfirm_body` | Club sites your dives use stay as personal copies. Other club sites are removed from this device. |
| `sharedLibrary_library_rename_label` | Display name |
| `sharedLibrary_members_setRole` | Change role |
| `sharedLibrary_members_lastOwner` | The last owner cannot be demoted. |
| `sharedLibrary_site_badgeTooltip` | In {name} |
| `sharedLibrary_site_lastEdited` | Last edited by {name}, {when} |
| `sharedLibrary_site_history` | Edit history |
| `sharedLibrary_site_addToLibrary` | Add to club library |
| `sharedLibrary_site_chooseLibrary` | Choose a library |
| `sharedLibrary_site_added` | Added to {name} |
| `sharedLibrary_site_notConnectedHere` | This site is in {name}, which is not connected on this device. |
| `sharedLibrary_site_connectHere` | Connect on this device |
| `sharedLibrary_site_deleteFromLibrary_title` | Delete from the club library? |
| `sharedLibrary_site_deleteFromLibrary_body` | Members whose dives use this site keep a personal copy. |
| `sharedLibrary_site_readerCannotDelete` | Only editors and owners delete club sites. |
| `sharedLibrary_suggest_title` | Suggest changes |
| `sharedLibrary_suggest_note_label` | Note for the referents |
| `sharedLibrary_suggest_send` | Send |
| `sharedLibrary_suggest_sent` | Suggestion sent |
| `sharedLibrary_suggest_nothingChanged` | Nothing changed. |
| `sharedLibrary_suggest_pending` | {count, plural, =1{1 suggestion pending} other{{count} suggestions pending}} |
| `sharedLibrary_suggest_withdraw` | Withdraw |
| `sharedLibrary_inbox_title` | Suggestions |
| `sharedLibrary_inbox_empty` | No suggestions waiting. |
| `sharedLibrary_inbox_from` | From {name}, {when} |
| `sharedLibrary_inbox_accept` | Accept |
| `sharedLibrary_inbox_dismiss` | Dismiss |
| `sharedLibrary_inbox_siteDeleted` | This site has been deleted from the library. |
| `sharedLibrary_inbox_before` | Before |
| `sharedLibrary_inbox_after` | After |
| `sharedLibrary_filter_library` | Library |
| `sharedLibrary_filter_personal` | Personal sites |
| `sharedLibrary_groupBy_library` | Library |
| `sharedLibrary_groupBy_personalGroup` | Personal |
| `sharedLibrary_bulk_addToLibrary` | Add to club library |

Plural keys need `@` metadata with `placeholders`; placeholder keys for `{name}`, `{when}`, `{error}` need their `@` entries with `"type": "String"`.

- [ ] **Step 1: Add the English keys**

Insert the block after `settings_cloudSync_entry_subtitle` in `app_en.arb`, each key followed by its `@key` metadata where it has placeholders. Keep the file's existing formatting (two-space indent, trailing commas as the file has them).

- [ ] **Step 2: Add the ten translations**

Same anchor in each locale file, translated (ar, de, es, fr, he, hu, it, nl, pt, zh). Plural forms follow each locale's CLDR categories as the neighbouring plural keys in that file do (`=1{...}` is the `one` category, not the digit).

- [ ] **Step 3: Generate and verify**

Run: `flutter gen-l10n && flutter analyze lib/l10n && git status --short lib/l10n`
Expected: no analyzer errors; only the ARB files and the generated `app_localizations*.dart` changed. Then run `python3.14 scripts/check_arb_consistency.py` if the repo has one (`ls scripts | grep -i arb`), else skip.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n
git commit -m "feat(shared-library): localised strings"
```

---

### Task 16: Settings pages: library list, library page, connect flow, members, inbox

**Files:**
- Create: `lib/features/shared_library/presentation/pages/shared_libraries_page.dart`
- Create: `lib/features/shared_library/presentation/pages/shared_library_page.dart`
- Create: `lib/features/shared_library/presentation/pages/connect_shared_library_page.dart`
- Create: `lib/features/shared_library/presentation/pages/shared_library_members_page.dart`
- Create: `lib/features/shared_library/presentation/pages/suggestion_inbox_page.dart`
- Create: `lib/features/shared_library/presentation/widgets/library_role_chip.dart`
- Create: `lib/features/shared_library/presentation/widgets/suggestion_review_sheet.dart`
- Modify: `lib/core/router/app_router.dart` (after the `cloud-sync` route near line 1478: `club-libraries`, `club-libraries/connect`, `club-libraries/:libraryId`, `club-libraries/:libraryId/members`, `club-libraries/:libraryId/suggestions`)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart:2758-2767` (a `ListTile` after Cloud Sync: icon `Icons.groups_outlined`, title `sharedLibrary_settings_title`, subtitle `sharedLibrary_settings_subtitle`, `context.push('/settings/club-libraries')`)
- Test: `test/features/shared_library/presentation/pages/shared_libraries_page_test.dart`
- Test: `test/features/shared_library/presentation/pages/shared_library_page_test.dart`
- Test: `test/features/shared_library/presentation/pages/connect_shared_library_page_test.dart`
- Test: `test/features/shared_library/presentation/pages/suggestion_inbox_page_test.dart`

**Interfaces:**
- Consumes the Task 10 and 14 providers, `SharedLibraryMembershipService` (Task 12), `SuggestionService` (Task 13), `connectedAccountsRepositoryProvider` and the add-account flows in `connected_accounts_page.dart` (reuse by pushing `/settings/connected-accounts` with a "come back" result, or by invoking the same dialogs; read that page first and reuse its `_addAccount` entry points as a shared function if they are private).
- Produces routes `/settings/club-libraries...` and the pages above.

- [ ] **Step 1: Write the failing page tests**

```dart
// test/features/shared_library/presentation/pages/shared_libraries_page_test.dart
void main() {
  testWidgets('empty state offers Connect a library', (tester) async {
    await tester.pumpWidget(testApp(
      overrides: [
        sharedLibrariesProvider.overrideWith((ref) => Stream.value(const <SharedLibrary>[])),
        currentMembershipsProvider.overrideWith((ref) async => const []),
      ],
      child: const SharedLibrariesPage(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No club library connected yet.'), findsOneWidget);
    expect(find.text('Connect a library'), findsOneWidget);
  });

  testWidgets('a connected library shows name, role and member count', (tester) async {
    await tester.pumpWidget(testApp(
      overrides: [
        sharedLibrariesProvider.overrideWith((ref) => Stream.value(const [
          SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'a', prefix: 'club',
              roles: SharedLibraryRoles(owners: {'m'})),
        ])),
        currentMembershipsProvider.overrideWith((ref) async => const [
          SharedLibraryMembership(id: 'ms', diverId: 'd', libraryId: 'L', memberId: 'm',
              displayName: 'Ann', libraryName: 'Club', backendKind: 's3'),
        ]),
        libraryMemberNamesProvider('L').overrideWith((ref) async => {'m': 'Ann', 'x': 'Bob'}),
      ],
      child: const SharedLibrariesPage(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Club'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
  });
}
```

```dart
// test/features/shared_library/presentation/pages/shared_library_page_test.dart
void main() {
  Widget page(SharedLibraryRole role, {bool readOnly = false, String? error}) => testApp(
    overrides: [
      sharedLibrariesProvider.overrideWith((ref) => Stream.value([
        SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'a', prefix: 'club',
            readOnlyDetected: readOnly, lastError: error,
            roles: SharedLibraryRoles(
              owners: role == SharedLibraryRole.owner ? {'m'} : {},
              editors: role == SharedLibraryRole.editor ? {'m'} : {})),
      ])),
      currentMembershipsProvider.overrideWith((ref) async => const [
        SharedLibraryMembership(id: 'ms', diverId: 'd', libraryId: 'L', memberId: 'm',
            displayName: 'Ann', libraryName: 'Club', backendKind: 's3')]),
      libraryRoleProvider('L').overrideWith((ref) async => effectiveRole(listed: role, readOnlyDetected: readOnly)),
      libraryMemberNamesProvider('L').overrideWith((ref) async => {'m': 'Ann'}),
      pendingIncomingSuggestionCountProvider('L').overrideWith((ref) async => 2),
    ],
    child: const SharedLibraryPage(libraryId: 'L'),
  );

  testWidgets('an owner sees Members, Suggestions with a badge, Add my sites, Leave', (tester) async {
    await tester.pumpWidget(page(SharedLibraryRole.owner));
    await tester.pumpAndSettle();
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Add my sites'), findsOneWidget);
    expect(find.text('Leave library'), findsOneWidget);
  });

  testWidgets('a reader sees neither Add my sites nor Suggestions', (tester) async {
    await tester.pumpWidget(page(SharedLibraryRole.reader));
    await tester.pumpAndSettle();
    expect(find.text('Add my sites'), findsNothing);
    expect(find.text('Suggestions'), findsNothing);
  });

  testWidgets('read-only and error banners', (tester) async {
    await tester.pumpWidget(page(SharedLibraryRole.editor, readOnly: true, error: 'boom'));
    await tester.pumpAndSettle();
    expect(find.textContaining('allow reading only'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });
}
```

```dart
// test/features/shared_library/presentation/pages/connect_shared_library_page_test.dart
void main() {
  testWidgets('a non-S3/WebDAV account list shows the hint; probe routes to Join or Create', (tester) async {
    final accounts = [ConnectedAccount(id: 'a', kind: AccountKind.s3, label: 'Bucket', createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026))];
    final probes = <String, LibraryProbe>{'club': const LibraryProbe(exists: true, id: 'L', name: 'Club', formatVersion: 1)};
    await tester.pumpWidget(testApp(
      overrides: [
        eligibleLibraryAccountsProvider.overrideWith((ref) async => accounts),
        sharedLibraryMembershipServiceProvider.overrideWithValue(_FakeMembershipService(probes)),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
        currentDiverProvider.overrideWith((ref) async => const Diver(id: 'd', name: 'Ann')),
      ],
      child: const ConnectSharedLibraryPage(),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library-prefix')), 'club');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Join Club'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('library-prefix')), 'other');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('No library here yet.'), findsOneWidget);
    expect(find.text('Create library'), findsOneWidget);
  });
}
```

`_FakeMembershipService` extends `SharedLibraryMembershipService` with `probe` answering from the map (give the real class a `@visibleForTesting` no-arg-ish constructor, or make the page depend on an abstract `probe/create/join` interface). `eligibleLibraryAccountsProvider` is a new `FutureProvider<List<ConnectedAccount>>` in Task 10's providers file: `getAll()` filtered to `s3` and `webdav`.

```dart
// test/features/shared_library/presentation/pages/suggestion_inbox_page_test.dart
void main() {
  testWidgets('lists suggestions grouped by site and opens the review sheet', (tester) async {
    await tester.pumpWidget(testApp(
      overrides: [
        incomingSuggestionsProvider('L').overrideWith((ref) async => [
          SharedSiteSuggestion(id: 'g', libraryId: 'L', siteId: 's', memberId: 'r', memberName: 'Ray',
              note: 'please', fields: const {'hazards': 'new'}, createdAt: DateTime.utc(2026, 10, 1),
              direction: 'incoming', status: 'pending'),
        ]),
        siteByIdProvider('s').overrideWith((ref) async => const DiveSite(id: 's', name: 'Blue', hazards: 'old', sharedLibraryId: 'L')),
        suggestionDiffProvider('g').overrideWith((ref) async => {'hazards': ('old', 'new')}),
      ],
      child: const SuggestionInboxPage(libraryId: 'L'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Blue'), findsOneWidget);
    expect(find.textContaining('From Ray'), findsOneWidget);
    await tester.tap(find.textContaining('From Ray'));
    await tester.pumpAndSettle();
    expect(find.text('old'), findsOneWidget);
    expect(find.text('new'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });
}
```

Check the existing site-by-id provider's name in `site_providers.dart` (it is `siteByIdProvider` or `siteDetailProvider`; use the real one).

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/shared_library/presentation/pages`
Expected: FAIL (pages missing).

- [ ] **Step 3: Build the pages**

First add to `shared_library_providers.dart` the providers these pages and tests name: `eligibleLibraryAccountsProvider` (`FutureProvider<List<ConnectedAccount>>`, `getAll()` filtered to `AccountKind.s3` and `AccountKind.webdav`), `libraryMembersProvider` (`FutureProvider.family<List<SharedLibraryMember>, String>` over `store.getMembers`), `pendingIncomingSuggestionCountProvider` (`FutureProvider.family<int, String>`), `incomingSuggestionsProvider` (`FutureProvider.family<List<SharedSiteSuggestion>, String>`, direction incoming, status pending, refreshed by `store.watchSuggestions()`), `outgoingSuggestionsForSiteProvider` (`FutureProvider.family<List<SharedSiteSuggestion>, String>` by site id, for Task 18), and `suggestionDiffProvider` (`FutureProvider.family<Map<String, (Object?, Object?)>, String>` by suggestion id through `SuggestionService.diff`).

`SharedLibrariesPage`: `Scaffold` + `AppBar(title: sharedLibrary_settings_title)`, body from `sharedLibrariesProvider` joined with `currentMembershipsProvider` (only libraries the active profile belongs to; others show greyed with "not a member on this profile" is out of scope, so simply filter), each a `ListTile(leading: Icon(Icons.groups_outlined), title: name, subtitle: "<role> · <n members> · <last sync>", trailing: chevron, onTap: push('/settings/club-libraries/$id'))`; empty state text plus a `FilledButton.icon` "Connect a library" (also in the app bar as `IconButton(Icons.add)`), pushing `/settings/club-libraries/connect`.

`SharedLibraryPage(libraryId)`: banners (`MaterialBanner`-style `Card`s) for `readOnlyDetected` and `lastError`; a status card with "Last sync" and a `FilledButton.tonal` "Sync now" calling `ref.read(sharedLibrarySyncProvider.notifier).syncOne(libraryId)`; a `ListTile` "Display name" editing via `showDialog` with a `TextField`, saving through `membershipService.rename`; role chip; `ListTile` "Members" (count) pushing the members page; owners: `ListTile` "Suggestions" with a `Badge` count from `pendingIncomingSuggestionCountProvider(libraryId)` (new provider in the providers file: `store.suggestions(libraryId, direction: 'incoming', status: 'pending').length`), pushing the inbox; editors and owners: `ListTile` "Add my sites" pushing `/sites?select=1&library=$libraryId` is heavier than needed, so open the Sites list in selection mode is out: instead show a `showModalBottomSheet` listing the profile's personal sites with checkboxes and an "Add" button calling `SharedSitePublisher.push` for each; `ListTile` "Leave library" (destructive) with the confirm dialog, calling `membershipService.leave` then `context.pop()`.

`ConnectSharedLibraryPage`: a `DropdownButtonFormField<ConnectedAccount>` over `eligibleLibraryAccountsProvider` (empty: the `sharedLibrary_connect_onlyS3Webdav` hint and a button to `/settings/connected-accounts`); a `TextFormField(key: Key('library-prefix'))`; a "Check" button calling `probe`; the result area: existing library shows its name and "Join <name>" (plus the display-name field prefilled from `currentDiverProvider`'s name); absent shows "No library here yet.", a name field, and "Create library"; `needsNewerApp` shows that text. Join/create call the service then `syncOne` and pop to the library page.

`SharedLibraryMembersPage(libraryId)`: list of `SharedLibraryMember` from `libraryMembersProvider(libraryId)` with the role chip; owners get a trailing `PopupMenuButton<SharedLibraryRole>` "Change role" calling `setRole`, showing `sharedLibrary_members_lastOwner` in a `SnackBar` on `StateError`.

`SuggestionInboxPage(libraryId)`: `incomingSuggestionsProvider(libraryId)` grouped by `siteId` with the site name as a section header; each row `From <name>, <date>` plus the note; tapping opens `SuggestionReviewSheet` (a `DraggableScrollableSheet`) that renders `suggestionDiffProvider(id)` as a two-column table (field label, before, after) with Accept and Dismiss buttons calling the service and popping; a suggestion whose site is gone shows `sharedLibrary_inbox_siteDeleted` and only Dismiss.

Router: nested under the existing settings routes, pages built with `state.pathParameters['libraryId']!`.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/features/shared_library test/features/settings/presentation/pages/settings_page_test.dart` (if that test exists) and `flutter analyze`
Expected: PASS.

```bash
git add lib/features/shared_library lib/core/router/app_router.dart lib/features/settings/presentation/pages/settings_page.dart test/features/shared_library
git commit -m "feat(shared-library): club library settings pages"
```

---

### Task 17: Sites list, map, filter, group-by and bulk action

**Files:**
- Create: `lib/features/shared_library/presentation/widgets/library_site_badge.dart`
- Create: `lib/features/shared_library/presentation/widgets/library_picker_dialog.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_tile.dart` (badge beside the name near line 215), `compact_site_list_tile.dart`, `dense_site_list_tile.dart` (same)
- Modify: `lib/features/dive_sites/presentation/widgets/site_map_content.dart` (marker icon variant for library sites)
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart:50-180` (`SiteFilterState.libraryId`, `'personal'` sentinel, `toQuery` clause, `copyWith`, equality, `hasActiveFilters`)
- Modify: `lib/features/dive_sites/query/site_query_entity.dart` (a `QueryField(key: 'library', column: 'shared_library_id')` text field; `personal` compiles to `IS NULL`)
- Modify: `lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart` (a "Library" chip row: Personal sites plus each connected library)
- Modify: `lib/features/dive_sites/domain/utils/site_grouping.dart` (`SiteGroupBy.library`, `siteLibraryKey`), `site_group_by_selector.dart`, `site_list_content.dart:672-760` (group headers resolve library names through `sharedLibrariesProvider`; personal group label `sharedLibrary_groupBy_personalGroup`)
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart:1260` (a `BulkAction(id: 'addToLibrary', icon: Icons.groups_outlined, label: sharedLibrary_bulk_addToLibrary, minCount: 1, isEnabled: only personal sites checked and role allows, onInvoke: _addToLibrary)`)
- Test: `test/features/shared_library/presentation/widgets/library_site_badge_test.dart`
- Test: `test/features/dive_sites/presentation/providers/site_filter_library_test.dart`
- Test: `test/features/dive_sites/domain/utils/site_grouping_library_test.dart`

**Interfaces:**

```dart
/// A small group glyph with the library name as tooltip; nothing for a personal site.
class LibrarySiteBadge extends ConsumerWidget { const LibrarySiteBadge({required this.site, this.size = 16}); }
/// Picks one of the connected libraries the active profile may push to; returns its id or null.
Future<String?> showLibraryPickerDialog(BuildContext context, WidgetRef ref);
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/shared_library/presentation/widgets/library_site_badge_test.dart
void main() {
  testWidgets('shows the library name as tooltip for a library site and nothing otherwise', (tester) async {
    await tester.pumpWidget(testApp(
      overrides: [sharedLibrariesProvider.overrideWith((ref) => Stream.value(const [
        SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'a', prefix: 'p')]))],
      child: const Column(children: [
        LibrarySiteBadge(site: DiveSite(id: '1', name: 'a', sharedLibraryId: 'L')),
        LibrarySiteBadge(site: DiveSite(id: '2', name: 'b')),
      ]),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    expect(find.byTooltip('In Club'), findsOneWidget);
  });
}
```

```dart
// test/features/dive_sites/presentation/providers/site_filter_library_test.dart
void main() {
  test('libraryId compiles to shared_library_id, personal to IS NULL', () {
    final lib = compileSiteFilter(const SiteFilterState(libraryId: 'L'));
    expect(lib.sql, contains('shared_library_id'));
    expect(lib.variables.map((v) => v.value), contains('L'));
    final personal = compileSiteFilter(const SiteFilterState(libraryId: SiteFilterState.personalLibrary));
    expect(personal.sql.toUpperCase(), contains('SHARED_LIBRARY_ID IS NULL'));
    expect(const SiteFilterState(libraryId: 'L').hasActiveFilters, isTrue);
  });
}
```

Check `CompiledQuery`'s member names (`sql`, `variables`) in `lib/features/query/`.

```dart
// test/features/dive_sites/domain/utils/site_grouping_library_test.dart
void main() {
  test('siteLibraryKey groups by library id with the no-group key for personal sites', () {
    expect(siteLibraryKey(const DiveSite(id: '1', name: 'a', sharedLibraryId: 'L')), 'L');
    expect(siteLibraryKey(const DiveSite(id: '2', name: 'b')), noGroupKey);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/shared_library/presentation/widgets test/features/dive_sites/presentation/providers/site_filter_library_test.dart test/features/dive_sites/domain/utils`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// library_site_badge.dart
class LibrarySiteBadge extends ConsumerWidget {
  const LibrarySiteBadge({super.key, required this.site, this.size = 16});
  final DiveSite site;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = site.sharedLibraryId;
    if (id == null) return const SizedBox.shrink();
    final name = ref.watch(sharedLibrariesProvider).valueOrNull
            ?.where((l) => l.id == id).map((l) => l.name).firstOrNull ?? '';
    return Tooltip(
      message: context.l10n.sharedLibrary_site_badgeTooltip(name),
      child: Icon(Icons.groups_outlined, size: size, color: Theme.of(context).colorScheme.primary),
    );
  }
}
```

Place it in a `Row` with the name `Text` in each tile (the name becomes `Expanded`). Map markers: in `site_map_content.dart`, where the marker icon is chosen, use `Icons.groups` for library sites (same colour). Filter: `SiteFilterState` gains `final String? libraryId;` with `static const personalLibrary = 'personal';`; `toQuery` adds a condition on the `library` field (`equals` for an id, `isNull` for the sentinel; check which operators `QueryField` supports for text fields and whether an "is empty" operator exists, else add a `nullable: true` text field with an `isNull` operator following `coordinates`' pattern at `site_query_entity.dart:115`). Filter sheet: a `Wrap` of `ChoiceChip`s (Personal sites, each library) bound to `libraryId`. Grouping: `SiteGroupBy.library`, `siteLibraryKey(site) => site.sharedLibraryId ?? noGroupKey`, header label from the libraries provider, `noGroupKey` labelled "Personal". Bulk action `_addToLibrary(ids)`: `showLibraryPickerDialog`, then `SharedSitePublisher().push` per id with the active diver id, then a `SnackBar` with `sharedLibrary_site_added`. `isEnabled` returns false when any checked site is a library site or when no connected library has a role above reader for the active profile (read `libraryRoleProvider` for each library once).

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/features/dive_sites test/features/shared_library` and `flutter analyze`
Expected: PASS.

```bash
git add lib/features/shared_library/presentation/widgets lib/features/dive_sites test/features/dive_sites test/features/shared_library
git commit -m "feat(shared-library): library badges, filter, grouping and bulk add"
```

---

### Task 18: Site detail: attribution, history, role-gated actions

**Files:**
- Create: `lib/features/shared_library/presentation/widgets/site_attribution_line.dart`
- Create: `lib/features/shared_library/presentation/widgets/site_edit_history_sheet.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_detail_header.dart:26-120` (library name chip plus `SiteAttributionLine` under the name for a library site)
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart:255-270` (edit button becomes "Suggest changes" for readers, hidden on an unconnected device), `:400-440` (`canDestroy` false for library rows; new menu entries), `:500-540` (menu: Delete from library for editors and owners, Edit history, Add to club library for personal sites, Connect on this device when `libraryConnectedHereProvider` is false), `:580-600` (delete dialog text for library sites)
- Test: `test/features/shared_library/presentation/widgets/site_attribution_line_test.dart`
- Test: `test/features/dive_sites/presentation/pages/site_detail_library_actions_test.dart`

**Interfaces:**

```dart
class SiteAttributionLine extends ConsumerWidget { const SiteAttributionLine({required this.site}); }  // "Last edited by Ann, 12 Oct 2026" from siteLibraryStateProvider + libraryMemberNamesProvider
Future<void> showSiteEditHistorySheet(BuildContext context, {required DiveSite site});          // per-field editor and time
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/shared_library/presentation/widgets/site_attribution_line_test.dart
void main() {
  testWidgets('renders the newest clock with the member name', (tester) async {
    final state = SharedSiteState(siteId: 's', libraryId: 'L', clocks: {
      'name': FieldClock(hlc: Hlc(DateTime.utc(2026, 10, 1).millisecondsSinceEpoch, 0, 'a'), memberId: 'a'),
      'hazards': FieldClock(hlc: Hlc(DateTime.utc(2026, 10, 12).millisecondsSinceEpoch, 0, 'b'), memberId: 'b'),
    });
    await tester.pumpWidget(testApp(
      overrides: [
        siteLibraryStateProvider('s').overrideWith((ref) async => state),
        libraryMemberNamesProvider('L').overrideWith((ref) async => {'a': 'Ann', 'b': 'Bob'}),
      ],
      child: const SiteAttributionLine(site: DiveSite(id: 's', name: 'S', sharedLibraryId: 'L')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Last edited by Bob'), findsOneWidget);
  });

  testWidgets('falls back to a short member id when the card is missing', (tester) async {
    final state = SharedSiteState(siteId: 's', libraryId: 'L', clocks: {
      'name': FieldClock(hlc: Hlc(1, 0, 'abcdef123456'), memberId: 'abcdef123456')});
    await tester.pumpWidget(testApp(
      overrides: [
        siteLibraryStateProvider('s').overrideWith((ref) async => state),
        libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
      ],
      child: const SiteAttributionLine(site: DiveSite(id: 's', name: 'S', sharedLibraryId: 'L')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('abcdef12'), findsOneWidget);
  });
}
```

```dart
// test/features/dive_sites/presentation/pages/site_detail_library_actions_test.dart
// Pump SiteDetailPage for a library site under each role and assert:
//  reader: 'Suggest changes' present, no Edit tooltip, delete menu entry absent
//  editor: Edit tooltip present, 'Delete from the club library?' dialog title on delete
//  unconnected device (libraryConnectedHereProvider false): 'Connect on this device' present, no Edit
//  personal site: 'Add to club library' in the properties menu when a library with editor role is connected
```

Write the four `testWidgets` cases using the overrides pattern `site_detail_page_test.dart` already uses (read it for the site and diver provider overrides it needs), plus `libraryRoleProvider('L')`, `libraryConnectedHereProvider('L')`, `sharedLibrariesProvider`, `currentMembershipsProvider`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/shared_library/presentation/widgets/site_attribution_line_test.dart test/features/dive_sites/presentation/pages/site_detail_library_actions_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`SiteAttributionLine`: watch the state and names; newest = `state.clocks.entries.reduce` by `hlc.compareTo`; name = `names[memberId] ?? memberId.substring(0, min(8, length))`; date = `DateTime.fromMillisecondsSinceEpoch(hlc.physicalTime)` formatted with the app's date formatter (`formatDateTime` with `l10n:` per the l10n index). Header: when `site.isLibrarySite`, a `Chip` with the library name and the attribution line under the title. Detail page: compute `role = ref.watch(libraryRoleProvider(libraryId))`, `connected = ref.watch(libraryConnectedHereProvider(libraryId))`; edit `IconButton` shown when `!isLibrarySite || (connected && canEditLibrarySite(role))`; a `TextButton.icon(Icons.rate_review_outlined, "Suggest changes")` when `connected && canSuggestOnLibrarySite(role)`, pushing `/sites/$siteId/edit?suggest=1`; menu entries as listed; delete for library sites calls `SharedSitePublisher().deleteFromLibrary` after the library-specific dialog; "Add to club library" uses `showLibraryPickerDialog` then `push`; "Connect on this device" pushes `/settings/club-libraries/connect` with the prefix prefilled from the membership's `locationHint` (`extra:`).

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/features/dive_sites/presentation/pages test/features/shared_library` and `flutter analyze`
Expected: PASS.

```bash
git add lib/features/shared_library/presentation/widgets lib/features/dive_sites/presentation test/features/dive_sites/presentation/pages/site_detail_library_actions_test.dart test/features/shared_library
git commit -m "feat(shared-library): site detail attribution, history and role actions"
```

---

### Task 19: Site edit page suggestion mode

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart:56-100` (constructor `bool suggest = false`), `:1010-1030` (hide the Share toggle for library sites), `:1790-1910` (`_saveSite` branches to `SuggestionService.propose` in suggest mode; note field; Send label)
- Modify: `lib/core/router/app_router.dart` (site edit route reads `state.uri.queryParameters['suggest'] == '1'`)
- Test: `test/features/dive_sites/presentation/pages/site_edit_suggest_mode_test.dart`

**Interfaces:** `SiteEditPage(siteId:, suggest: true)`.

- [ ] **Step 1: Write the failing test**

```dart
void main() {
  testWidgets('suggest mode shows the note field and Send, and never writes the site', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await DiverRepository().createDiver(const Diver(id: 'd', name: 'Ray'));
    final store = SharedLibraryStore();
    await store.upsertLibrary(const SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'a', prefix: 'p'));
    await store.upsertMembership(const SharedLibraryMembership(id: 'ms', diverId: 'd', libraryId: 'L', memberId: 'r', displayName: 'Ray', libraryName: 'Club', backendKind: 's3'));
    await SiteRepository().createSite(const DiveSite(id: 's', name: 'Blue', hazards: 'old', sharedLibraryId: 'L'));
    await tester.pumpWidget(testApp(
      overrides: [validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd')],
      child: const SiteEditPage(siteId: 's', suggest: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Suggest changes'), findsOneWidget);
    expect(find.text('Note for the referents'), findsOneWidget);
    expect(find.text('Share with all profiles'), findsNothing);   // use the real share-toggle label from app_en.arb
    await tester.enterText(find.byKey(const Key('site-hazards')), 'new');   // find the real field key or label used by access_safety_section.dart
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect((await SiteRepository().getSiteById('s'))!.hazards, 'old');
    expect(await store.suggestions('L', direction: 'outgoing'), hasLength(1));
  });
}
```

Read `site_edit_page_test.dart` for how the page is pumped (it may need `GoRouter` and more overrides) and adopt the same scaffolding.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_suggest_mode_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Constructor field `final bool suggest;`. App bar title `sharedLibrary_suggest_title` in suggest mode; a `TextFormField` for the note (controller `_suggestionNote`) appended after the last section; the save button label `sharedLibrary_suggest_send`. In `_saveSite`, when `widget.suggest`: build the `DiveSite` exactly as the normal path does (the `copyWith` at line 1902 area), then `final s = await SuggestionService().propose(proposed: site, diverId: actingDiverId, note: _suggestionNote.text, childFields: {...types/tags if changed})`; null shows `sharedLibrary_suggest_nothingChanged`, else `sharedLibrary_suggest_sent`, then pop. The Share toggle (`_isShared` row near line 1015) is wrapped in `if (!(_originalSite?.isLibrarySite ?? false))`. Readers never reach the normal save because Task 18 routes them here, but guard anyway: in normal mode, if the site is a library site and the role is reader, treat as suggest mode.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/features/dive_sites/presentation/pages` and `flutter analyze`
Expected: PASS.

```bash
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart lib/core/router/app_router.dart test/features/dive_sites/presentation/pages/site_edit_suggest_mode_test.dart
git commit -m "feat(shared-library): suggestion mode on the site edit page"
```

---

### Task 20: Dive detail and site picker badges

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_hero_header.dart:148,314` (badge after the site name)
- Modify: `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_site_tile.dart:46` (badge after the title)
- Test: `test/features/dive_sites/presentation/widgets/site_picker_site_tile_library_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
void main() {
  testWidgets('picker tile shows the library badge for a library site', (tester) async {
    await tester.pumpWidget(testApp(
      overrides: [sharedLibrariesProvider.overrideWith((ref) => Stream.value(const [
        SharedLibrary(id: 'L', name: 'Club', connectedAccountId: 'a', prefix: 'p')]))],
      child: SitePickerSiteTile(site: const DiveSite(id: 's', name: 'Blue', sharedLibraryId: 'L'), onTap: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
  });
}
```

Match `SitePickerSiteTile`'s real constructor (read lines 1-45).

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Implement**

Wrap the name `Text` in a `Row` with `LibrarySiteBadge(site: site)` in both widgets; the hero header passes `dive.site` when non-null.

- [ ] **Step 4: Run the tests, then commit**

Run: `flutter test test/features/dive_sites/presentation/widgets test/features/dive_log/presentation/widgets` and `flutter analyze`
Expected: PASS.

```bash
git add lib/features/dive_log/presentation/widgets/dive_hero_header.dart lib/features/dive_sites/presentation/widgets/site_picker/site_picker_site_tile.dart test/features/dive_sites/presentation/widgets/site_picker_site_tile_library_test.dart
git commit -m "feat(shared-library): library badge on dive detail and the site picker"
```

---

### Task 21: Whole-branch checks

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes from format, analyzer clean.

- [ ] **Step 2: Architecture and adoption guards**

Run: `flutter test test/architecture test/shared`
Expected: PASS. A failure names a new file that breaks a repo-wide rule (file size, import grouping, raw date pickers, global state restore); fix it in place.

- [ ] **Step 3: Affected suites**

Run: `flutter test test/core/database test/core/services/sync test/core/services/shared_library test/core/data test/features/dive_sites test/features/shared_library test/features/settings test/features/dive_log/presentation/widgets test/features/query`
Expected: PASS.

- [ ] **Step 4: Line counts**

Run: `wc -l lib/core/services/shared_library/*.dart lib/features/shared_library/presentation/**/*.dart | sort -n | tail -5`
Expected: every file under 800 lines; split any that is not (the service into `shared_library_service.dart` plus `shared_library_pull.dart`/`shared_library_push.dart` extensions).

- [ ] **Step 5: Commit any fixes**

```bash
git add -A lib test
git commit -m "fix(shared-library): whole-branch format, analyze and guard fixes"
```

(Only if something changed; otherwise no commit.)
