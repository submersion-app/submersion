# Buddy/Instructor Integration Implementation Plan (#395)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Buddies can hold professional credentials (instructor/divemaster/dive guide with number + agency); certifications gain a structured `instructorId` link with snapshot semantics; certification, course, and dive-buddy UIs pick instructors from buddies instead of retyping.

**Architecture:** New `buddy_roles` table (schema v94, HLC-synced, own-id PK) + nullable `certifications.instructor_id` FK mirroring the existing `courses.instructorId` pattern. A shared `InstructorPickerField` widget serves both certification and course edit pages. Link + snapshot: picking a buddy copies name/number into the existing text fields, which stay editable.

**Tech Stack:** Flutter 3.x, Drift ORM (codegen via build_runner), Riverpod, per-row HLC sync.

**Spec:** `docs/superpowers/specs/2026-07-02-buddy-instructor-integration-design.md`

## Global Constraints

- Working directory is the worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-395-buddy-instructor` — run every command there. NEVER cd to the main checkout.
- Branch: `worktree-issue-395-buddy-instructor`. Verify with `git branch --show-current` before every commit.
- After changing any drift table: `dart run build_runner build --delete-conflicting-outputs` (regenerates `database.g.dart`).
- All user-visible strings go through l10n (`context.l10n.<key>`); new keys must be added to `lib/l10n/arb/app_en.arb` AND all 10 other locales (ar, de, es, fr, he, hu, it, nl, pt, zh), then regenerate with `flutter gen-l10n`.
- No emojis anywhere. Immutability always. `dart format .` (whole repo) before every commit.
- Run tests as specific files, never broad directories (Bash timeout risk).
- Commit messages: conventional style (`feat:`, `test:`, `refactor:`); NO Co-Authored-By lines.
- The drift row class for the new table MUST be named `BuddyRoleRow` (via `@DataClassName`) — the default name `BuddyRole` collides with the existing `BuddyRole` enum in `lib/core/constants/enums.dart`.

---

### Task 1: Schema v94 — buddy_roles table + certifications.instructor_id

**Files:**
- Modify: `lib/core/database/database.dart` (table class near line 985, `@DriftDatabase` tables list near line 1700, `currentSchemaVersion` line 1710, `migrationVersions` line 1806, `_hlcTables` line 1842, migration block near line 4320)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets` map, lines 29-54)
- Test: `test/core/database/migration_v94_buddy_roles_test.dart`

**Interfaces:**
- Produces: drift table `BuddyRoles` with row class `BuddyRoleRow`, companion `BuddyRolesCompanion`, accessor `_db.buddyRoles`; `certifications.instructor_id TEXT` nullable column (drift getter `instructorId`); schema version 94.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/migration_v94_buddy_roles_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh v94 schema has buddy_roles table and '
      'certifications.instructor_id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // buddy_roles exists with the expected columns.
    final roleCols = await db
        .customSelect("PRAGMA table_info('buddy_roles')")
        .get();
    final roleColNames = roleCols.map((c) => c.read<String>('name')).toSet();
    expect(
      roleColNames,
      containsAll([
        'id',
        'buddy_id',
        'role',
        'credential_number',
        'agency',
        'notes',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );

    // certifications gained instructor_id.
    final certCols = await db
        .customSelect("PRAGMA table_info('certifications')")
        .get();
    final certColNames = certCols.map((c) => c.read<String>('name')).toSet();
    expect(certColNames, contains('instructor_id'));
  });

  test('v94 migration adds instructor_id to a v93 certifications table '
      'and is idempotent', () async {
    // Simulate the guarded ALTER against a pre-v94 table shape.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('''
      CREATE TABLE certs_v93 (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        instructor_name TEXT
      )
    ''');
    Future<bool> hasColumn() async {
      final cols = await db
          .customSelect("PRAGMA table_info('certs_v93')")
          .get();
      return cols.any((c) => c.read<String>('name') == 'instructor_id');
    }

    // The same guard logic the migration uses: check, then ALTER.
    for (var i = 0; i < 2; i++) {
      if (!await hasColumn()) {
        await db.customStatement(
          'ALTER TABLE certs_v93 ADD COLUMN instructor_id TEXT '
          'REFERENCES buddies (id) ON DELETE SET NULL',
        );
      }
    }
    expect(await hasColumn(), isTrue);
  });

  test('schema version is 94 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, 94);
    expect(AppDatabase.migrationVersions, contains(94));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v94_buddy_roles_test.dart`
Expected: FAIL (buddy_roles table missing; version still 93)

- [ ] **Step 3: Add the drift table class**

In `lib/core/database/database.dart`, insert directly after the `DiveBuddies` class (after line 985):

```dart
/// Professional credentials held by a buddy (instructor, divemaster,
/// dive guide). One row per (buddy, role); the repository enforces that
/// logical uniqueness. Issue #395.
@DataClassName('BuddyRoleRow')
class BuddyRoles extends Table {
  TextColumn get id => text()();
  TextColumn get buddyId =>
      text().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // BuddyRole enum name
  TextColumn get credentialNumber => text().nullable()();
  TextColumn get agency => text().nullable()(); // CertificationAgency enum name
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: Add the certifications column**

In the `Certifications` table class, after the `instructorNumber` getter (line 998):

```dart
  // Structured instructor link (issue #395). The text fields above remain
  // the historical snapshot and survive buddy deletion.
  TextColumn get instructorId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.setNull)();
```

- [ ] **Step 5: Register the table, bump version, add migration**

1. Add `BuddyRoles,` to the `@DriftDatabase(tables: [...])` list (near line 1700, alongside `Buddies`).
2. Change `static const int currentSchemaVersion = 93;` to `94`.
3. Append `94,` to `migrationVersions` (after `93,` on line 1806).
4. Add `'buddy_roles',` to `_hlcTables` (after `'buddies',` line 1819).
5. In `onUpgrade`, after the `if (from < 93) await reportProgress();` line (line 4320), insert:

```dart
        if (from < 94) {
          // Buddy professional credentials + structured instructor link on
          // certifications (issue #395). PRAGMA-guarded so a healthy database
          // no-ops and an interrupted upgrade does not fail on a duplicate
          // ALTER. createTable is IF NOT EXISTS.
          final certCols = await customSelect(
            "PRAGMA table_info('certifications')",
          ).get();
          if (certCols.isNotEmpty) {
            final existing = certCols
                .map((c) => c.read<String>('name'))
                .toSet();
            if (!existing.contains('instructor_id')) {
              await customStatement(
                'ALTER TABLE certifications ADD COLUMN instructor_id TEXT '
                'REFERENCES buddies (id) ON DELETE SET NULL',
              );
            }
          }
          await m.createTable(buddyRoles);
        }
        if (from < 94) await reportProgress();
```

- [ ] **Step 6: Register HLC stamping**

In `lib/core/data/repositories/sync_repository.dart`, add to `_hlcTargets` after the `'buddies'` entry (line 32):

```dart
    'buddyRoles': (table: 'buddy_roles', pk: 'id'),
```

- [ ] **Step 7: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `database.g.dart` gains `BuddyRoleRow`, `BuddyRolesCompanion`, `$BuddyRolesTable`.

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/core/database/migration_v94_buddy_roles_test.dart`
Expected: PASS (3 tests)

Also run the neighboring migration tests to catch regressions:
`flutter test test/core/database/migration_v93_dive_types_seed_test.dart test/core/database/new_tables_drift_access_test.dart`
Expected: PASS. Note: `sync_parent_refs_completeness_test.dart` will now FAIL until Task 4 — that is expected; do not fix it here.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(db): add buddy_roles table and certifications.instructor_id (v94) (#395)"
```

---

### Task 2: BuddyRoleCredential entity + repository role CRUD + providers

**Files:**
- Create: `lib/features/buddies/domain/entities/buddy_role_credential.dart`
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart`
- Modify: `lib/features/buddies/presentation/providers/buddy_providers.dart`
- Test: `test/features/buddies/data/repositories/buddy_role_repository_test.dart`

**Interfaces:**
- Consumes: `_db.buddyRoles`, `BuddyRolesCompanion`, `BuddyRoleRow` (Task 1).
- Produces:
  - `class BuddyRoleCredential { String id; String buddyId; BuddyRole role; String? credentialNumber; CertificationAgency? agency; String notes; DateTime createdAt; DateTime updatedAt; }` with `copyWith`, `displayLabel`, Equatable props.
  - `const kProfessionalBuddyRoles = [BuddyRole.instructor, BuddyRole.diveMaster, BuddyRole.diveGuide];`
  - `BuddyRepository.getRolesForBuddy(String buddyId) -> Future<List<BuddyRoleCredential>>`
  - `BuddyRepository.getAllRoles() -> Future<Map<String, List<BuddyRoleCredential>>>` (keyed by buddyId)
  - `BuddyRepository.setRolesForBuddy(String buddyId, List<BuddyRoleCredential> roles) -> Future<void>` (replace semantics, dedupes by role, preserves row ids for kept roles)
  - `BuddyRepository.watchBuddyRolesChanges() -> Stream<void>`
  - Providers: `buddyRolesProvider` (family by buddyId), `allBuddyRolesProvider` (map).

- [ ] **Step 1: Write the entity**

Create `lib/features/buddies/domain/entities/buddy_role_credential.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Roles that represent professional credentials a buddy can hold.
const kProfessionalBuddyRoles = [
  BuddyRole.instructor,
  BuddyRole.diveMaster,
  BuddyRole.diveGuide,
];

/// A professional credential held by a buddy (issue #395).
class BuddyRoleCredential extends Equatable {
  final String id;
  final String buddyId;
  final BuddyRole role;
  final String? credentialNumber;
  final CertificationAgency? agency;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BuddyRoleCredential({
    required this.id,
    required this.buddyId,
    required this.role,
    this.credentialNumber,
    this.agency,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display string like "Instructor - PADI #12345".
  String get displayLabel {
    final parts = <String>[
      if (agency != null) agency!.displayName,
      if (credentialNumber != null && credentialNumber!.isNotEmpty)
        '#$credentialNumber',
    ];
    if (parts.isEmpty) return role.displayName;
    return '${role.displayName} - ${parts.join(' ')}';
  }

  BuddyRoleCredential copyWith({
    String? id,
    String? buddyId,
    BuddyRole? role,
    String? credentialNumber,
    CertificationAgency? agency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BuddyRoleCredential(
      id: id ?? this.id,
      buddyId: buddyId ?? this.buddyId,
      role: role ?? this.role,
      credentialNumber: credentialNumber ?? this.credentialNumber,
      agency: agency ?? this.agency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    buddyId,
    role,
    credentialNumber,
    agency,
    notes,
    createdAt,
    updatedAt,
  ];
}
```

- [ ] **Step 2: Write the failing repository test**

Create `test/features/buddies/data/repositories/buddy_role_repository_test.dart`. Mirror the setup of the existing `test/features/buddies/data/repositories/buddy_repository_test.dart` (same `DatabaseService` test wiring — copy its `setUp`/`tearDown` exactly), and IMPORTANTLY enable foreign keys in setup: `await db.customStatement('PRAGMA foreign_keys = ON');` (FK-OFF suites have masked ordering bugs before). Test cases:

```dart
// Test bodies (adapt the shared setUp from buddy_repository_test.dart):

test('setRolesForBuddy inserts and getRolesForBuddy reads back', () async {
  final buddy = await repository.createBuddy(_buddy('Alice'));
  final now = DateTime.now();
  await repository.setRolesForBuddy(buddy.id, [
    BuddyRoleCredential(
      id: '',
      buddyId: buddy.id,
      role: BuddyRole.instructor,
      credentialNumber: '12345',
      agency: CertificationAgency.padi,
      createdAt: now,
      updatedAt: now,
    ),
  ]);
  final roles = await repository.getRolesForBuddy(buddy.id);
  expect(roles, hasLength(1));
  expect(roles.single.role, BuddyRole.instructor);
  expect(roles.single.credentialNumber, '12345');
  expect(roles.single.agency, CertificationAgency.padi);
});

test('setRolesForBuddy dedupes by role (last wins)', () async {
  // Pass two instructor entries; expect a single row with the second number.
});

test('setRolesForBuddy preserves the row id of a kept role', () async {
  // Set instructor role; read id; set again with changed number;
  // expect the same row id and the new number.
});

test('setRolesForBuddy removes roles omitted from the new list', () async {
  // Set [instructor, diveMaster]; then set [instructor]; expect 1 row.
});

test('deleting a buddy cascades its buddy_roles rows (FK ON)', () async {
  // Create buddy + role; deleteBuddy; SELECT count from buddy_roles == 0.
});

test('getAllRoles returns a buddyId-keyed map', () async {
  // Two buddies, one credentialed; expect map has entry only for that one.
});
```

Write each stub above as a full test (create buddy via `repository.createBuddy`, use a small `_buddy(String name)` helper returning a `domain.Buddy` with empty id and `DateTime.now()` timestamps).

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_role_repository_test.dart`
Expected: FAIL — `getRolesForBuddy`/`setRolesForBuddy` not defined.

- [ ] **Step 4: Implement repository methods**

In `lib/features/buddies/data/repositories/buddy_repository.dart`, add the import:

```dart
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
```

Add these methods to `BuddyRepository` (after `watchBuddiesChanges`, line 27):

```dart
  /// Emits whenever the `buddy_roles` table changes.
  Stream<void> watchBuddyRolesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.buddyRoles));

  /// Professional credentials for one buddy.
  Future<List<BuddyRoleCredential>> getRolesForBuddy(String buddyId) async {
    final rows =
        await (_db.select(_db.buddyRoles)
              ..where((t) => t.buddyId.equals(buddyId))
              ..orderBy([(t) => OrderingTerm.asc(t.role)]))
            .get();
    return rows.map(_mapRowToRoleCredential).toList();
  }

  /// All credentials keyed by buddy id, for pickers annotating many buddies.
  Future<Map<String, List<BuddyRoleCredential>>> getAllRoles() async {
    final rows = await _db.select(_db.buddyRoles).get();
    final map = <String, List<BuddyRoleCredential>>{};
    for (final row in rows) {
      map.putIfAbsent(row.buddyId, () => []).add(_mapRowToRoleCredential(row));
    }
    return map;
  }

  /// Replace the credential set for [buddyId]. Dedupes by role (last entry
  /// wins) and preserves the existing row id for roles that stay, so sync
  /// peers see an update rather than delete+insert.
  Future<void> setRolesForBuddy(
    String buddyId,
    List<BuddyRoleCredential> roles,
  ) async {
    final byRole = <BuddyRole, BuddyRoleCredential>{};
    for (final role in roles) {
      byRole[role.role] = role;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(
      _db.buddyRoles,
    )..where((t) => t.buddyId.equals(buddyId))).get();
    final existingByRole = {for (final row in existing) row.role: row};

    // Delete roles no longer present.
    for (final row in existing) {
      if (!byRole.keys.any((r) => r.name == row.role)) {
        await (_db.delete(
          _db.buddyRoles,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'buddyRoles',
          recordId: row.id,
        );
      }
    }

    // Upsert kept/new roles.
    for (final credential in byRole.values) {
      final existingRow = existingByRole[credential.role.name];
      if (existingRow != null) {
        await (_db.update(
          _db.buddyRoles,
        )..where((t) => t.id.equals(existingRow.id))).write(
          BuddyRolesCompanion(
            credentialNumber: Value(credential.credentialNumber),
            agency: Value(credential.agency?.name),
            notes: Value(credential.notes),
            updatedAt: Value(now),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'buddyRoles',
          recordId: existingRow.id,
          localUpdatedAt: now,
        );
      } else {
        final id = credential.id.isEmpty ? _uuid.v4() : credential.id;
        await _db
            .into(_db.buddyRoles)
            .insert(
              BuddyRolesCompanion(
                id: Value(id),
                buddyId: Value(buddyId),
                role: Value(credential.role.name),
                credentialNumber: Value(credential.credentialNumber),
                agency: Value(credential.agency?.name),
                notes: Value(credential.notes),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'buddyRoles',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    }
    SyncEventBus.notifyLocalChange();
  }

  BuddyRoleCredential _mapRowToRoleCredential(BuddyRoleRow row) {
    return BuddyRoleCredential(
      id: row.id,
      buddyId: row.buddyId,
      role: BuddyRole.values.firstWhere(
        (r) => r.name == row.role,
        orElse: () => BuddyRole.buddy,
      ),
      credentialNumber: row.credentialNumber,
      agency: _parseCertificationAgency(row.agency),
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
```

- [ ] **Step 5: Add providers**

In `lib/features/buddies/presentation/providers/buddy_providers.dart`, add the import for `buddy_role_credential.dart`, then after `buddiesForDiveProvider` (line 143):

```dart
/// Professional credentials for one buddy. Self-invalidates on any
/// buddy_roles table change (local edit or sync apply).
final buddyRolesProvider =
    FutureProvider.family<List<BuddyRoleCredential>, String>((
      ref,
      buddyId,
    ) async {
      final repository = ref.watch(buddyRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchBuddyRolesChanges());
      return repository.getRolesForBuddy(buddyId);
    });

/// All credentials keyed by buddy id, for pickers annotating many buddies.
final allBuddyRolesProvider =
    FutureProvider<Map<String, List<BuddyRoleCredential>>>((ref) async {
      final repository = ref.watch(buddyRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchBuddyRolesChanges());
      return repository.getAllRoles();
    });
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/buddies/data/repositories/buddy_role_repository_test.dart test/features/buddies/data`
Expected: PASS (new tests + no regression in existing buddy repo tests)

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(buddies): BuddyRoleCredential entity, role CRUD, providers (#395)"
```

---

### Task 3: certifications.instructorId through entity and repository

**Files:**
- Modify: `lib/features/certifications/domain/entities/certification.dart`
- Modify: `lib/features/certifications/data/repositories/certification_repository.dart`
- Test: extend `test/features/certifications/data/repositories/certification_repository_test.dart`

**Interfaces:**
- Consumes: `certifications.instructor_id` column (Task 1).
- Produces: `Certification.instructorId` (`String?`), persisted by create/update, read by all read paths.

- [ ] **Step 1: Write the failing test**

Add to the existing `certification_repository_test.dart` group:

```dart
test('persists and reads back instructorId', () async {
  final created = await repository.createCertification(
    Certification.empty().copyWith(name: 'Rescue Diver')
        .copyWith(instructorId: 'buddy-1'),
  );
  final loaded = await repository.getCertificationById(created.id);
  expect(loaded!.instructorId, 'buddy-1');

  await repository.updateCertification(loaded.copyWith(name: 'Rescue'));
  final reloaded = await repository.getCertificationById(created.id);
  expect(reloaded!.instructorId, 'buddy-1'); // survives update
});
```

Note: if the test database enforces FKs, insert a buddy row with id `buddy-1` first (check how the existing tests seed data; follow suit).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/certifications/data/repositories/certification_repository_test.dart`
Expected: FAIL — `instructorId` not defined.

- [ ] **Step 3: Extend the entity**

In `certification.dart`:
1. Add field after `instructorNumber` (line 18): `final String? instructorId;`
2. Add `this.instructorId,` to the constructor.
3. Add `String? instructorId,` parameter and `instructorId: instructorId ?? this.instructorId,` to `copyWith`.
4. In `clearPhotos`, pass through: `instructorId: instructorId,`.
5. Add `instructorId,` to `props`.

- [ ] **Step 4: Extend the repository**

In `certification_repository.dart`:
1. `_mapRowToCertification` (line 340): add `instructorId: row.instructorId,`.
2. Both raw `customSelect` mappers (`searchCertifications` line 93, `getExpiringCertifications` line 258, `getExpiredCertifications` line 303): add `instructorId: row.data['instructor_id'] as String?,` next to the other instructor fields.
3. `createCertification` companion (line 130): add `instructorId: Value(cert.instructorId),`.
4. `updateCertification` companion (line 177): add `instructorId: Value(cert.instructorId),`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/certifications/data/repositories/certification_repository_test.dart`
Expected: PASS

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(certifications): instructorId link on entity and repository (#395)"
```

---

### Task 4: Sync registration for buddyRoles

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (all sites below)
- Modify: `lib/core/services/sync/sync_service.dart` (`parentRefs`, line 1467)
- Test: `test/core/services/sync/sync_buddy_roles_test.dart`

**Interfaces:**
- Consumes: `_db.buddyRoles`, `BuddyRoleRow` (Task 1).
- Produces: `buddyRoles` fully registered in export/import/delete/localIds paths; `parentRefs['buddyRoles']`; `parentRefs['certifications']` gains the instructorId ref.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/sync/sync_buddy_roles_test.dart`, modeled exactly on `test/core/services/sync/sync_dive_dive_types_test.dart` (the v92 junction's sync test — same setup/harness). Cover:
- Export: insert a buddy + buddy_roles row (with hlc), run the serializer export, assert the payload's `buddyRoles` list contains the row.
- Import (round trip): serialize, wipe the table, apply, assert the row is restored with all columns (`role`, `credential_number`, `agency`).
- Incremental: a buddy_roles row with hlc greater than the cursor is exported; one below is not.

- [ ] **Step 2: Run tests to verify current state**

Run: `flutter test test/core/services/sync/sync_buddy_roles_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart`
Expected: both FAIL (unregistered entity; parentRefs incomplete — the completeness test has been failing since Task 1 added the FK).

- [ ] **Step 3: Register in sync_data_serializer.dart — data container**

Four edits in the `SyncData` class, each placed directly after the corresponding `buddies`/`diveBuddies` line:
1. Field (after line 226): `final List<Map<String, dynamic>> buddyRoles;`
2. Constructor (after line 268): `this.buddyRoles = const [],`
3. `toJson` (after line 311): `'buddyRoles': buddyRoles,`
4. `fromJson` (after line 355): `buddyRoles: _parseList(json['buddyRoles']),`

- [ ] **Step 4: Register the table descriptor and export**

1. `_baseTables` (line 531): insert after the `buddies` entry and BEFORE `diveBuddies` (parent-before-child apply order):
   `(key: 'buddyRoles', table: _db.buddyRoles, blob: false, full: null),`
2. The `exportChanges` construction site (line 876 area): after the `buddies:` argument add:
   ```dart
   buddyRoles: await _safeExport(
     'buddyRoles',
     () => _exportBuddyRoles(hlcSince),
   ),
   ```
3. Add the exporter next to `_exportBuddies` (line 2690) — buddy_roles carries its own hlc, so use the simple filter pattern:
   ```dart
   Future<List<Map<String, dynamic>>> _exportBuddyRoles(
     String? hlcSince,
   ) async {
     final query = _db.select(_db.buddyRoles);
     if (hlcSince != null) {
       query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
     }
     final rows = await query.get();
     return rows.map((r) => r.toJson()).toList();
   }
   ```

- [ ] **Step 5: Register the five switch cases**

Add a `case 'buddyRoles':` clause directly after each existing `case 'buddies':` clause (NOT after `diveBuddies`, to keep parent/child grouping readable), in these five switches:
1. fetchRecord (line 1155):
   ```dart
   case 'buddyRoles':
     final row = await (_db.select(
       _db.buddyRoles,
     )..where((t) => t.id.equals(recordId))).getSingleOrNull();
     return row?.toJson();
   ```
2. single upsert (line 1510):
   ```dart
   case 'buddyRoles':
     await _db
         .into(_db.buddyRoles)
         .insertOnConflictUpdate(BuddyRoleRow.fromJson(data));
     return;
   ```
3. batch upsert (line 1795):
   ```dart
   case 'buddyRoles':
     await _db.batch(
       (b) => b.insertAllOnConflictUpdate(
         _db.buddyRoles,
         records.map((r) => BuddyRoleRow.fromJson(r)).toList(),
       ),
     );
     return;
   ```
4. localIds (line 2150 area): `case 'buddyRoles': return plain(_db.buddyRoles, _db.buddyRoles.id);`
5. table lookup (line 2265 area): `case 'buddyRoles': return _db.buddyRoles;`
6. delete (line 2372 area):
   ```dart
   case 'buddyRoles':
     await (_db.delete(
       _db.buddyRoles,
     )..where((t) => t.id.equals(recordId))).go();
     return;
   ```

Then search the file for any remaining exhaustive handling: run `grep -n "case 'buddies':" lib/core/services/sync/sync_data_serializer.dart` and confirm every match now has a `buddyRoles` sibling. Also check `sync_service.dart` and `lib/core/services/sync/` for other per-entity switches over these keys (`grep -rn "'diveBuddies'" lib/core/services/sync/ lib/core/data/`) and mirror each.

- [ ] **Step 6: parentRefs**

In `sync_service.dart` `parentRefs` map (line 1467):
1. Add after the `'diveBuddies'` entry:
   ```dart
   'buddyRoles': [(field: 'buddyId', parent: 'buddies', nullable: false)],
   ```
2. Extend the `'certifications'` entry (line 1523) to:
   ```dart
   'certifications': [
     (field: 'courseId', parent: 'courses', nullable: true),
     (field: 'instructorId', parent: 'buddies', nullable: true),
   ],
   ```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/sync_buddy_roles_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_serializer_round_trip_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_round_trip_test.dart`
Expected: PASS. If a coverage/parity test fails listing a missing entity key, it names the exact site you missed — add the `buddyRoles` case there.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(sync): register buddyRoles entity and certification instructor FK (#395)"
```

---

### Task 5: Buddy merge moves credentials and re-points certifications

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_merge_repository.dart`
- Test: extend the existing buddy merge tests (find with `grep -rln "mergeBuddies" test/features/buddies/`)

**Interfaces:**
- Consumes: `_db.buddyRoles`, `BuddyRolesCompanion`, `CertificationsCompanion`, `logDeletion`/`markRecordPending` entity keys `'buddyRoles'`, `'certifications'`.
- Produces: `BuddyMergeSnapshot` gains `deletedBuddyRoles` (`List<BuddyRoleSnapshot>`) and `repointedCertifications` (`List<CertificationInstructorSnapshot>`), both defaulting to `const []` so existing constructions compile.

- [ ] **Step 1: Write the failing tests**

In the existing merge test file, add:

```dart
test('merge relinks duplicate buddy credentials to the survivor', () async {
  // survivor has no instructor role; duplicate has one.
  // After merge: buddy_roles row exists with buddy_id == survivor,
  // same credential number, same row id (relinked, not recreated).
});

test('merge drops a duplicate credential when the survivor already has '
    'that role, keeping the survivor row', () async {
  // Both have instructor roles; after merge exactly one instructor row,
  // buddy_id == survivor, survivor's credential number kept.
});

test('merge re-points certifications.instructorId to the survivor', () async {
  // Certification with instructorId == duplicate id; after merge it
  // equals the survivor id.
});

test('undoMerge restores duplicate credentials and certification links',
    () async {
  // Run the three scenarios above, undo, assert original rows/links back.
});
```

Write these as complete tests using the file's existing helpers for creating buddies/dives; create certifications through `CertificationRepository`.

- [ ] **Step 2: Run tests to verify they fail**

Run the merge test file. Expected: FAIL (credentials cascade-deleted, certs not re-pointed).

- [ ] **Step 3: Extend snapshots**

In `buddy_merge_repository.dart`, after `DiveBuddySnapshot` (line 26):

```dart
/// Snapshot of a buddy_roles row for undo.
class BuddyRoleSnapshot {
  final String id;
  final String buddyId;
  final String role;
  final String? credentialNumber;
  final String? agency;
  final String notes;
  final int createdAt;
  final int updatedAt;

  const BuddyRoleSnapshot({
    required this.id,
    required this.buddyId,
    required this.role,
    this.credentialNumber,
    this.agency,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Snapshot of a certification's instructor link for undo.
class CertificationInstructorSnapshot {
  final String certificationId;
  final String instructorId;

  const CertificationInstructorSnapshot({
    required this.certificationId,
    required this.instructorId,
  });
}
```

Extend `BuddyMergeSnapshot` with two new final fields, constructor params defaulting to `const []`:

```dart
  final List<BuddyRoleSnapshot> deletedBuddyRoles;
  final List<CertificationInstructorSnapshot> repointedCertifications;
```

Also add them to the `show` re-export list in `buddy_repository.dart` (line 15).

- [ ] **Step 4: Implement merge handling**

Inside the `mergeBuddies` transaction (line 182), BEFORE the "Delete duplicate buddy rows" loop (line 288), insert:

```dart
        // Move professional credentials (issue #395). Relink when the
        // survivor lacks the role; drop the duplicate's row when the
        // survivor already holds it. Snapshot everything for undo.
        final survivorRoleRows = await (_db.select(
          _db.buddyRoles,
        )..where((t) => t.buddyId.equals(survivorId))).get();
        final survivorRoles = survivorRoleRows.map((r) => r.role).toSet();
        for (final duplicateId in duplicateIds) {
          final dupRoleRows = await (_db.select(
            _db.buddyRoles,
          )..where((t) => t.buddyId.equals(duplicateId))).get();
          for (final row in dupRoleRows) {
            deletedBuddyRoles.add(
              BuddyRoleSnapshot(
                id: row.id,
                buddyId: row.buddyId,
                role: row.role,
                credentialNumber: row.credentialNumber,
                agency: row.agency,
                notes: row.notes,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
              ),
            );
            if (survivorRoles.contains(row.role)) {
              await (_db.delete(
                _db.buddyRoles,
              )..where((t) => t.id.equals(row.id))).go();
              await _syncRepository.logDeletion(
                entityType: 'buddyRoles',
                recordId: row.id,
              );
            } else {
              await (_db.update(_db.buddyRoles)
                    ..where((t) => t.id.equals(row.id)))
                  .write(BuddyRolesCompanion(buddyId: Value(survivorId)));
              await _syncRepository.markRecordPending(
                entityType: 'buddyRoles',
                recordId: row.id,
                localUpdatedAt: now,
              );
              survivorRoles.add(row.role);
            }
          }
        }

        // Re-point certification instructor links (issue #395).
        final linkedCerts = await (_db.select(
          _db.certifications,
        )..where((t) => t.instructorId.isIn(duplicateIds))).get();
        for (final cert in linkedCerts) {
          repointedCertifications.add(
            CertificationInstructorSnapshot(
              certificationId: cert.id,
              instructorId: cert.instructorId!,
            ),
          );
          await (_db.update(_db.certifications)
                ..where((t) => t.id.equals(cert.id)))
              .write(CertificationsCompanion(
                instructorId: Value(survivorId),
              ));
          await _syncRepository.markRecordPending(
            entityType: 'certifications',
            recordId: cert.id,
            localUpdatedAt: now,
          );
        }
```

Declare `final deletedBuddyRoles = <BuddyRoleSnapshot>[];` and `final repointedCertifications = <CertificationInstructorSnapshot>[];` beside the other snapshot lists (line 176), and pass both into the returned `BuddyMergeSnapshot`.

- [ ] **Step 5: Implement undo handling**

In `undoMerge`, inside the transaction after step 4 (line 422), add:

```dart
        // 5. Restore duplicate credentials. Relinked rows still exist
        // (buddyId updated), truly-deleted rows do not - insertOrReplace
        // handles both.
        for (final entry in snapshot.deletedBuddyRoles) {
          await _db
              .into(_db.buddyRoles)
              .insert(
                BuddyRolesCompanion(
                  id: Value(entry.id),
                  buddyId: Value(entry.buddyId),
                  role: Value(entry.role),
                  credentialNumber: Value(entry.credentialNumber),
                  agency: Value(entry.agency),
                  notes: Value(entry.notes),
                  createdAt: Value(entry.createdAt),
                  updatedAt: Value(entry.updatedAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
          await _syncRepository.markRecordPending(
            entityType: 'buddyRoles',
            recordId: entry.id,
            localUpdatedAt: now,
          );
        }

        // 6. Restore certification instructor links.
        for (final entry in snapshot.repointedCertifications) {
          await (_db.update(_db.certifications)
                ..where((t) => t.id.equals(entry.certificationId)))
              .write(CertificationsCompanion(
                instructorId: Value(entry.instructorId),
              ));
          await _syncRepository.markRecordPending(
            entityType: 'certifications',
            recordId: entry.certificationId,
            localUpdatedAt: now,
          );
        }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: the merge test file plus `flutter test test/features/buddies/data`
Expected: PASS

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(buddies): merge moves credentials and re-points certification links (#395)"
```

---

### Task 6: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` plus `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

**Interfaces:**
- Produces: l10n getters used by Tasks 7-11.

- [ ] **Step 1: Add English keys**

Add to `app_en.arb`, near the existing `buddies_` keys (keep the file's alphabetical/grouped ordering):

```json
"buddies_section_professionalRoles": "Professional Roles",
"buddies_roles_addRole": "Add role",
"buddies_roles_role": "Role",
"buddies_roles_agency": "Agency",
"buddies_roles_credentialNumber": "Credential number",
"buddies_roles_removeTooltip": "Remove role",
"buddies_roles_emptyHint": "Add instructor or divemaster credentials to reuse them when logging certifications and courses.",
"buddies_instructorPicker_label": "Instructor from buddies",
"buddies_instructorPicker_none": "None (manual entry)",
"buddies_detail_section_professionalRoles": "Professional Roles"
```

If the file carries `@key` description entries for neighboring keys, add matching ones.

- [ ] **Step 2: Translate into the 10 other locales**

Add the same keys with translated values to each of the 10 ARB files. Translate naturally per locale (e.g. de: "Berufliche Rollen", "Rolle hinzufügen", ...; fr: "Rôles professionnels", ...). Keep placeholders none (these are plain strings).

- [ ] **Step 3: Regenerate and verify**

Run: `flutter gen-l10n && flutter analyze lib/l10n`
Expected: generation succeeds, no missing-translation warnings for the new keys, analyze clean.

- [ ] **Step 4: Commit**

```bash
dart format .
git add -A
git commit -m "feat(l10n): strings for buddy professional roles and instructor picker (#395)"
```

---

### Task 7: Buddy edit page — Professional Roles section

**Files:**
- Create: `lib/features/buddies/presentation/widgets/buddy_roles_editor.dart`
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart`
- Test: `test/features/buddies/presentation/widgets/buddy_roles_editor_test.dart`

**Interfaces:**
- Consumes: `BuddyRoleCredential`, `kProfessionalBuddyRoles` (Task 2), l10n keys (Task 6).
- Produces: `BuddyRolesEditor({required List<BuddyRoleCredential> roles, required ValueChanged<List<BuddyRoleCredential>> onChanged})` — a stateless controlled widget rendering the draft credential list.

- [ ] **Step 1: Write the failing widget test**

Create `buddy_roles_editor_test.dart` (mirror the harness of an existing test under `test/features/buddies/presentation/widgets/` for MaterialApp + l10n delegates setup):

```dart
// Cases:
// 1. Renders one row per credential with role name and number visible.
// 2. Tapping "Add role" invokes onChanged with a new instructor entry
//    (first professional role not yet used).
// 3. "Add role" is absent when all professional roles are used.
// 4. Editing the credential-number field invokes onChanged with the
//    updated credential.
// 5. Tapping the remove icon invokes onChanged without that credential.
```

Write all five as full `testWidgets` bodies pumping `BuddyRolesEditor` inside the standard localized MaterialApp scaffold.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_roles_editor_test.dart`
Expected: FAIL — widget does not exist.

- [ ] **Step 3: Implement the widget**

Create `buddy_roles_editor.dart`. Controlled component; parent owns the list. Structure:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';

/// Editable list of professional credentials for the buddy edit form.
/// Controlled: the parent owns the list and receives every change via
/// [onChanged]; nothing is persisted here.
class BuddyRolesEditor extends StatelessWidget {
  final List<BuddyRoleCredential> roles;
  final ValueChanged<List<BuddyRoleCredential>> onChanged;

  const BuddyRolesEditor({
    super.key,
    required this.roles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final usedRoles = roles.map((r) => r.role).toSet();
    final availableRoles = kProfessionalBuddyRoles
        .where((r) => !usedRoles.contains(r))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (roles.isEmpty)
          Text(
            context.l10n.buddies_roles_emptyHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        for (final credential in roles) ...[
          _RoleEntry(
            key: ValueKey(credential.role),
            credential: credential,
            usedRoles: usedRoles,
            onChanged: (updated) => onChanged([
              for (final r in roles)
                if (r.role == credential.role) updated else r,
            ]),
            onRemoved: () => onChanged([
              for (final r in roles)
                if (r.role != credential.role) r,
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (availableRoles.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final now = DateTime.now();
                onChanged([
                  ...roles,
                  BuddyRoleCredential(
                    id: '',
                    buddyId: roles.isNotEmpty ? roles.first.buddyId : '',
                    role: availableRoles.first,
                    createdAt: now,
                    updatedAt: now,
                  ),
                ]);
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.buddies_roles_addRole),
            ),
          ),
      ],
    );
  }
}
```

`_RoleEntry` is a private StatefulWidget in the same file rendering: a `DropdownButtonFormField<BuddyRole>` over `kProfessionalBuddyRoles` (entries already used by OTHER credentials disabled/omitted; current value always present), a `DropdownButtonFormField<CertificationAgency?>` (nullable, with a "not specified" null item, mirroring the agency dropdown pattern in `buddy_edit_page.dart:484-509`), a `TextFormField` for the credential number (own `TextEditingController` initialized from the credential, disposed properly, `onChanged` propagating `credential.copyWith(credentialNumber: ...)`), and an `IconButton(icon: Icon(Icons.delete_outline), tooltip: context.l10n.buddies_roles_removeTooltip, onPressed: onRemoved)`. Keep the file under 400 lines.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_roles_editor_test.dart`
Expected: PASS

- [ ] **Step 5: Wire into buddy_edit_page.dart**

1. State: add `List<BuddyRoleCredential> _roles = [];` to `_BuddyEditPageState`.
2. `_loadBuddy` (line 112): after loading the buddy, also `_roles = await ref.read(buddyRepositoryProvider).getRolesForBuddy(widget.buddyId!);` (inside the try, before setState; assign in setState).
3. Form body (`_buildFormBody`): after the certification agency dropdown block (after line 540) and before the Notes header, insert a section:
   ```dart
            const SizedBox(height: 24),
            Text(
              context.l10n.buddies_section_professionalRoles,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            BuddyRolesEditor(
              roles: _roles,
              onChanged: (roles) {
                setState(() {
                  _roles = roles;
                  _hasChanges = true;
                });
              },
            ),
   ```
4. `_saveBuddy` (line 721): after the buddy is saved (both branches produce `savedBuddy`), persist roles:
   ```dart
      await ref
          .read(buddyRepositoryProvider)
          .setRolesForBuddy(savedBuddy.id, _roles);
   ```
   Place it before the `if (mounted)` navigation block. In the merge branch, call it with `savedId` (the survivor) only if `_roles` is non-empty.
5. Imports: `buddy_role_credential.dart`, `buddy_roles_editor.dart`.

- [ ] **Step 6: Verify the page still builds and tests pass**

Run: `flutter analyze lib/features/buddies && flutter test test/features/buddies/presentation`
Expected: analyze clean; existing page tests still PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(buddies): professional roles editor on buddy edit page (#395)"
```

---

### Task 8: Buddy detail page — roles card

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- Test: `test/features/buddies/presentation/pages/buddy_detail_roles_test.dart`

**Interfaces:**
- Consumes: `buddyRolesProvider` (Task 2), l10n key `buddies_detail_section_professionalRoles`.

- [ ] **Step 1: Write the failing widget test**

Create `buddy_detail_roles_test.dart` mirroring the harness of the existing buddy detail page tests (provider overrides): override `buddyRolesProvider(buddyId)` with a credential list and assert:
1. With one instructor credential (PADI, 12345): the section title "Professional Roles" and the text `Instructor - PADI #12345` are visible.
2. With an empty list: the section title is absent.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/presentation/pages/buddy_detail_roles_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the card**

In `buddy_detail_page.dart`, locate the existing info-card column (read the file; it follows the same `Card > Padding > Column` + section title pattern as `certification_detail_page.dart:549-580`). Add a consumer of `ref.watch(buddyRolesProvider(buddy.id))` and, when `value` (use `AsyncValue.value`, not `valueOrNull` via `when(loading:)` — avoids the reload flicker) is non-null and non-empty, render after the certification info card:

```dart
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.buddies_detail_section_professionalRoles,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final credential in roles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.workspace_premium),
                title: Text(credential.displayLabel),
              ),
          ],
        ),
      ),
    ),
```

Match the page's actual row/section building blocks — if it has a private `_InfoRow`-style helper, use that instead of raw ListTile.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/buddies/presentation/pages/buddy_detail_roles_test.dart`
Expected: PASS

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(buddies): show professional roles on buddy detail page (#395)"
```

---

### Task 9: InstructorPickerField + certification edit/detail integration

**Files:**
- Create: `lib/features/buddies/presentation/widgets/instructor_picker_field.dart`
- Modify: `lib/features/certifications/presentation/pages/certification_edit_page.dart`
- Modify: `lib/features/certifications/presentation/pages/certification_detail_page.dart`
- Test: `test/features/buddies/presentation/widgets/instructor_picker_field_test.dart`
- Test: `test/features/certifications/presentation/pages/certification_edit_instructor_test.dart`

**Interfaces:**
- Consumes: `allBuddiesProvider`, `allBuddyRolesProvider`, `BuddyRoleCredential`, l10n keys.
- Produces:
  ```dart
  class InstructorPickerField extends ConsumerWidget {
    final String? instructorId;
    final void Function(Buddy? buddy, BuddyRoleCredential? credential)
        onSelected;
    const InstructorPickerField({
      super.key,
      required this.instructorId,
      required this.onSelected,
    });
  }
  ```
  Selecting "None" calls `onSelected(null, null)`.

- [ ] **Step 1: Write the failing picker widget test**

Create `instructor_picker_field_test.dart` (ProviderScope with `allBuddiesProvider` and `allBuddyRolesProvider` overridden to fixed data):
1. Instructor-credentialed buddies are listed before non-credentialed ones and show their credential label.
2. Selecting a credentialed buddy fires `onSelected` with the buddy and its instructor credential.
3. Selecting a non-credentialed buddy fires `onSelected(buddy, null)`.
4. Selecting the None item fires `onSelected(null, null)`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/presentation/widgets/instructor_picker_field_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the widget**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';

/// Dropdown for picking a certification/course instructor from the buddy
/// list. Buddies holding an instructor credential are grouped first and
/// annotated with it; any buddy remains selectable (autofills name only).
class InstructorPickerField extends ConsumerWidget {
  final String? instructorId;
  final void Function(Buddy? buddy, BuddyRoleCredential? credential)
  onSelected;

  const InstructorPickerField({
    super.key,
    required this.instructorId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(allBuddiesProvider);
    final rolesAsync = ref.watch(allBuddyRolesProvider);
    final buddies = buddiesAsync.value ?? const <Buddy>[];
    final rolesByBuddy =
        rolesAsync.value ?? const <String, List<BuddyRoleCredential>>{};
    if (buddies.isEmpty) return const SizedBox.shrink();

    BuddyRoleCredential? instructorCredential(String buddyId) {
      final credentials = rolesByBuddy[buddyId];
      if (credentials == null) return null;
      for (final c in credentials) {
        if (c.role == BuddyRole.instructor) return c;
      }
      return null;
    }

    final credentialed = buddies
        .where((b) => instructorCredential(b.id) != null)
        .toList();
    final others = buddies
        .where((b) => instructorCredential(b.id) == null)
        .toList();
    final ordered = [...credentialed, ...others];
    // Guard against a stale instructorId (buddy deleted / not yet synced).
    final validValue = ordered.any((b) => b.id == instructorId)
        ? instructorId
        : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey(validValue),
      initialValue: validValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.buddies_instructorPicker_label,
        prefixIcon: const Icon(Icons.people),
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(context.l10n.buddies_instructorPicker_none),
        ),
        ...ordered.map((buddy) {
          final credential = instructorCredential(buddy.id);
          final label = credential == null
              ? buddy.name
              : '${buddy.name} (${credential.displayLabel})';
          return DropdownMenuItem(
            value: buddy.id,
            child: Text(label, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (value) {
        if (value == null) {
          onSelected(null, null);
          return;
        }
        final buddy = ordered.firstWhere((b) => b.id == value);
        onSelected(buddy, instructorCredential(buddy.id));
      },
    );
  }
}
```

- [ ] **Step 4: Run picker test to verify it passes**

Run: `flutter test test/features/buddies/presentation/widgets/instructor_picker_field_test.dart`
Expected: PASS

- [ ] **Step 5: Write the failing certification edit test**

Create `certification_edit_instructor_test.dart` (mirror the existing cert edit page test harness under `test/features/certifications/presentation/pages/`; override `allBuddiesProvider`/`allBuddyRolesProvider` and the repository providers):
1. Picking a credentialed buddy fills the instructor name and number fields.
2. After picking, editing the name text does not clear the selection.
3. Selecting None keeps the text fields' contents.
4. Saving passes `instructorId` through (assert on the repository fake / notifier call).
5. Loading an existing cert with `instructorId` pre-selects the dropdown.

- [ ] **Step 6: Integrate into certification_edit_page.dart**

1. State: `String? _instructorId;`
2. `_loadCertification` (line 78): `_instructorId = cert.instructorId;` inside setState.
3. Instructor section (lines 434-471): between the section header and the instructor-name `TextFormField`, insert:
   ```dart
                  InstructorPickerField(
                    instructorId: _instructorId,
                    onSelected: (buddy, credential) {
                      setState(() {
                        _instructorId = buddy?.id;
                        _hasChanges = true;
                        if (buddy != null) {
                          _instructorNameController.text = buddy.name;
                          if (credential?.credentialNumber != null &&
                              credential!.credentialNumber!.isNotEmpty) {
                            _instructorNumberController.text =
                                credential.credentialNumber!;
                          }
                        }
                        // Clearing to None keeps the text fields untouched.
                      });
                    },
                  ),
                  const SizedBox(height: 16),
   ```
   Use `buddy.name` (not `displayName` — displayName appends the cert level, which is not the instructor's printed name).
4. `_saveCertification` (line 753): add `instructorId: _instructorId,` to the `Certification` constructor.
5. Imports: `instructor_picker_field.dart`.

- [ ] **Step 7: Make the detail page instructor tappable**

In `certification_detail_page.dart` `_buildInstructorSection` (line 549): the section is inside a widget with access to `ref` (check the class; if it is a plain method on a ConsumerWidget, thread `WidgetRef ref` through like `_buildCourseSection` does at line 582). When `certification.instructorId != null`, resolve `ref.watch(buddyByIdProvider(certification.instructorId!))`; when the buddy resolves non-null, wrap the name `_InfoRow` in an `InkWell` that navigates: `context.push('/buddies/${certification.instructorId}')` and append a `chevron_right`-style affordance consistent with the page's other tappable rows (see the course ListTile at line 612 for the established pattern — prefer converting the name row to a `ListTile` with `contentPadding: EdgeInsets.zero` and `onTap` when linked). When the buddy is null (deleted or not yet synced), keep the existing plain `_InfoRow` — text-only fallback.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/certifications/presentation test/features/buddies/presentation/widgets/instructor_picker_field_test.dart`
Expected: PASS (new + existing).

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(certifications): instructor picker with snapshot autofill and linked detail row (#395)"
```

---

### Task 10: Course edit page — shared picker + number autofill

**Files:**
- Modify: `lib/features/courses/presentation/pages/course_edit_page.dart` (lines 214-262)
- Test: `test/features/courses/presentation/pages/course_edit_instructor_test.dart` (create; or extend the existing course edit test file if one exists — check `ls test/features/courses/presentation/pages/`)

**Interfaces:**
- Consumes: `InstructorPickerField` (Task 9).

- [ ] **Step 1: Write the failing test**

Test cases (same harness as the cert edit test in Task 9):
1. Picking a credentialed buddy fills instructor name AND number.
2. The dropdown lists non-credentialed buddies too (regression vs the old `certificationLevel != null` filter: a buddy with no cert level at all must appear).
3. Saving persists `instructorId` (already-existing behavior — keep passing).

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL on case 1 (number not filled) and case 2 (buddy filtered out).

- [ ] **Step 3: Replace the inline dropdown**

Replace the whole `buddiesAsync.when(...)` block at `course_edit_page.dart:215-262` with:

```dart
          InstructorPickerField(
            instructorId: _instructorId,
            onSelected: (buddy, credential) {
              setState(() {
                _instructorId = buddy?.id;
                if (buddy != null) {
                  _instructorNameController.text = buddy.name;
                  if (credential?.credentialNumber != null &&
                      credential!.credentialNumber!.isNotEmpty) {
                    _instructorNumberController.text =
                        credential.credentialNumber!;
                  }
                }
              });
            },
          ),
          const SizedBox(height: 16),
```

Remove the now-unused `buddiesAsync` watch if nothing else in the page uses it (check first — `grep -n buddiesAsync lib/features/courses/presentation/pages/course_edit_page.dart`). Note the old code set the name to `buddy.displayName`; the new code uses `buddy.name` intentionally (printed name, not name + cert level). Add the `instructor_picker_field.dart` import.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/courses`
Expected: PASS (new + all existing course tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(courses): use shared instructor picker with credential autofill (#395)"
```

---

### Task 11: Dive BuddyPicker — credential subtitle + instructor-first role sheet

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_picker.dart`
- Test: `test/features/buddies/presentation/widgets/buddy_picker_roles_test.dart` (create; extend the existing buddy_picker test harness if present)

**Interfaces:**
- Consumes: `allBuddyRolesProvider` (Task 2).

- [ ] **Step 1: Write the failing test**

Test cases (override `allBuddiesProvider` + `allBuddyRolesProvider`):
1. In the selection sheet list, a credentialed buddy's tile shows `Instructor - PADI #12345` as (part of) the subtitle.
2. Tapping a credentialed buddy opens the role sheet with Instructor as the FIRST option; tapping a plain buddy shows the default order (Buddy first).

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Implement**

In `_BuddySelectionSheetState`:
1. In `build` (line 249), also watch: `final rolesByBuddy = ref.watch(allBuddyRolesProvider).value ?? const <String, List<BuddyRoleCredential>>{};` and pass it to `_buildBuddyListView` and `_showRoleSelectorForBuddy` (add parameters).
2. Tile subtitle (line 450): replace with a combined line —
   ```dart
          subtitle: () {
            final credentials = rolesByBuddy[buddy.id] ?? const [];
            final parts = <String>[
              if (buddy.certificationLevel != null)
                buddy.certificationLevel!.displayName,
              ...credentials.map((c) => c.displayLabel),
            ];
            return parts.isEmpty ? null : Text(parts.join(' | '));
          }(),
   ```
3. `_showRoleSelectorForBuddy` (line 500): compute an ordered role list before building the sheet —
   ```dart
    final credentials = rolesByBuddy[buddy.id] ?? const <BuddyRoleCredential>[];
    final credentialRoles = credentials.map((c) => c.role).toSet();
    final orderedRoles = [
      ...BuddyRole.values.where(credentialRoles.contains),
      ...BuddyRole.values.where((r) => !credentialRoles.contains(r)),
    ];
   ```
   and map over `orderedRoles` instead of `BuddyRole.values` (line 515). For roles in `credentialRoles`, use `leading: const Icon(Icons.workspace_premium)` instead of `Icons.person` so the credentialed suggestion is visually marked.
4. Import `buddy_role_credential.dart`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/buddies/presentation/widgets`
Expected: PASS (new + existing picker tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dives): surface buddy credentials in dive buddy picker (#395)"
```

---

### Task 12: Whole-project verification

**Files:** none (verification only)

- [ ] **Step 1: Format check**

Run: `dart format .`
Expected: `0 changed` (if files changed, commit the formatting).

- [ ] **Step 2: Whole-project analyze**

Run: `flutter analyze`
Expected: `No issues found!` — run the FULL project analyze, never a piped/filtered variant. Fix anything reported (common stragglers: test mocks needing regeneration — `dart run build_runner build --delete-conflicting-outputs` — and unused imports).

- [ ] **Step 3: Run the affected test suites (as explicit file lists)**

```bash
flutter test test/core/database/migration_v94_buddy_roles_test.dart \
  test/features/buddies/data test/features/certifications/data
flutter test test/core/services/sync/sync_buddy_roles_test.dart \
  test/core/services/sync/sync_parent_refs_completeness_test.dart \
  test/core/services/sync/sync_round_trip_test.dart \
  test/core/services/sync/sync_serializer_round_trip_test.dart
flutter test test/features/buddies/presentation
flutter test test/features/certifications/presentation test/features/courses
```
Expected: all PASS.

- [ ] **Step 4: Commit any remaining fixes**

```bash
git add -A
git commit -m "test: verification fixes for buddy/instructor integration (#395)"
```

(Skip the commit if the tree is clean.)

---

## Post-plan notes for the finishing session

- Push with `--no-verify` (the worktree pre-push hook runs against the main tree and reports false failures).
- PR title suggestion: `feat: buddy professional roles and instructor picker for certifications/courses (#395)`; body should reference the spec and note the v94 migration.
- Do NOT delete or modify `docs/superpowers/specs/2026-07-02-buddy-instructor-integration-design.md`.
