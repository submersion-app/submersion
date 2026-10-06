# Buddy Multiple Certifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give buddies multiple certifications (matching the self-diver's rich certification model) by generalizing certification ownership, while keeping compact buddy displays working via a derived "primary" certification.

**Architecture:** Generalize the existing `certifications` table so a row is owned by *either* a diver (`diverId`) *or* a buddy (`buddyId`, new). The `Buddy` entity keeps its scalar `certificationLevel`/`certificationAgency` fields, but they become *derived transient* values the repository fills at hydration from the buddy's certification rows (the highest-by-ladder "primary"). The two inline `buddies` columns are removed via an expand/contract migration pair. The buddy edit page stages a certification list in memory and commits it transactionally on Save (mirroring the existing roles pattern).

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod, go_router. Codegen via `dart run build_runner build --delete-conflicting-outputs`. Sync is HLC-based; `certifications` is already a registered sync entity.

## Global Constraints

- **Schema versions (assign at implementation time):** `currentSchemaVersion` on this base (`origin/main` @ `8eea4586036`) is **106**. This plan uses **v107 (expand)** and **v108 (contract)**. Before committing, re-check `AppDatabase.currentSchemaVersion` against the latest merged `main`: the connected-accounts (v107/v108) and media-linking (v107) programs claim these numbers on *unmerged* branches. If either merges first, renumber this plan's two versions to the next two free integers and update `migrationVersions`, the `if (from < N)` blocks, and the test names/asserts accordingly.
- **Deterministic migration ids:** the v107 data copy MUST derive each migrated cert id from the buddy id (`'buddycert-<buddyId>'`), never a random UUID — the migration runs independently per device, and a random id duplicates the cert under sync.
- **Owner invariant:** every `certifications` row has exactly one of `{diverId, buddyId}` non-null. Enforced in `CertificationRepository.createCertification`.
- **Deletion tombstones:** buddy deletion must route child certs through `deleteCertification` (which writes a `deletion_log` tombstone) — FK `ON DELETE CASCADE` does NOT tombstone, and un-tombstoned deletes resurrect on sync.
- **No commits unless asked:** the user handles all `git add`/`git commit`. Each task below ends with a "Commit" step written as the message to use — but do NOT run it unless the user has authorized commits for this plan (e.g. by choosing subagent-driven execution). Otherwise stop after tests pass and report.
- **Formatting/lints:** run `dart format .` (whole project) and `flutter analyze` (whole project, never piped through `tail`) before any commit.
- **l10n:** new strings go into `lib/l10n/arb/app_en.arb` (template) AND all 10 non-en locales (`ar de es fr he hu it nl pt zh`), then regenerate with `flutter gen-l10n`.
- **Widget-test traps (this repo):** set `themeAnimationDuration: Duration.zero` on the test `MaterialApp`; wrap post-`pump` Drift awaits in `tester.runAsync`; `ensureVisible` before tapping form fields; form-section labels may be uppercased.
- **Worktree:** all work happens in `.claude/worktrees/issue-553-buddy-certs` (branch `worktree-issue-553-buddy-certs`). After any change to `database.dart` or an entity with codegen, run `dart run build_runner build --delete-conflicting-outputs`.

**Type/name reference (fixed across tasks):**
- `Certification.buddyId` → `String?`
- `certifications.buddy_id` → `TextColumn get buddyId => text().nullable().references(Buddies, #id, onDelete: KeyAction.cascade)()`
- `CertificationRepository.getCertificationsByBuddy(String buddyId) → Future<List<domain.Certification>>`
- `CertificationRepository.getCertificationsForBuddies(List<String> buddyIds) → Future<Map<String, List<domain.Certification>>>`
- `CertificationRepository.replaceBuddyCertifications(String buddyId, List<domain.Certification> desired) → Future<void>`
- `primaryCertification(List<Certification> certs) → Certification?` (top-level, `lib/features/certifications/domain/certification_primary.dart`)
- `buddyCertificationsProvider` → `FutureProvider.family<List<Certification>, String>`
- `CertificationEditPage({..., Certification? initialCertification, void Function(Certification result)? onStaged})`

---

### Task 1: Add `buddyId` to the `Certification` entity

**Files:**
- Modify: `lib/features/certifications/domain/entities/certification.dart`
- Test: `test/features/certifications/domain/certification_entity_test.dart`

**Interfaces:**
- Produces: `Certification.buddyId` (`String?`), threaded through the constructor, `copyWith`, `clearPhotos`, `Certification.empty()`, and `props`.

- [ ] **Step 1: Write the failing test**

Create `test/features/certifications/domain/certification_entity_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

void main() {
  Certification base() => Certification(
        id: 'c1',
        name: 'Nitrox',
        agency: CertificationAgency.padi,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  test('buddyId defaults to null and round-trips through copyWith', () {
    expect(base().buddyId, isNull);
    final owned = base().copyWith(buddyId: 'b1');
    expect(owned.buddyId, 'b1');
    // buddyId participates in equality
    expect(owned == base(), isFalse);
    expect(owned == base().copyWith(buddyId: 'b1'), isTrue);
  });

  test('clearPhotos preserves buddyId', () {
    final owned = base().copyWith(buddyId: 'b1');
    expect(owned.clearPhotos(clearFront: true).buddyId, 'b1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/certifications/domain/certification_entity_test.dart`
Expected: FAIL — `copyWith` has no `buddyId` parameter (compile error).

- [ ] **Step 3: Add the field**

In `lib/features/certifications/domain/entities/certification.dart`:
- Add field after `diverId` (line 10): `final String? buddyId;`
- Add constructor param after `this.diverId,` (line 27): `this.buddyId,`
- Add `copyWith` param after `String? diverId,` (line 83): `String? buddyId,`
- In the `copyWith` body after `diverId: diverId ?? this.diverId,` (line 99): `buddyId: buddyId ?? this.buddyId,`
- In `clearPhotos` after `diverId: diverId,` (line 121): `buddyId: buddyId,`
- In `Certification.empty()` — no change needed (buddyId stays null).
- In `props` after `diverId,` (line 154): `buddyId,`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/certifications/domain/certification_entity_test.dart`
Expected: PASS

- [ ] **Step 5: Commit** (only if authorized — see Global Constraints)

```bash
git add lib/features/certifications/domain/entities/certification.dart test/features/certifications/domain/certification_entity_test.dart
git commit -m "feat(certifications): add nullable buddyId owner to Certification entity"
```

---

### Task 2: Schema EXPAND (v107) — add `certifications.buddy_id`, copy inline buddy certs, owner-aware cert repo

**Files:**
- Modify: `lib/core/database/database.dart` (Certifications table, `currentSchemaVersion`, `migrationVersions`, `onUpgrade`, `beforeOpen`, two new helper methods, add enums import)
- Modify: `lib/features/certifications/data/repositories/certification_repository.dart` (`createCertification`, `_mapRowToCertification`)
- Test: `test/core/database/migration_v107_buddy_cert_owner_test.dart`
- Test: `test/features/certifications/data/repositories/certification_repository_buddy_owner_test.dart`

**Interfaces:**
- Produces: `certifications.buddy_id` column; `Certification.buddyId` persisted on create and hydrated on read; a buddy's pre-existing inline cert copied into a `certifications` row with deterministic id `'buddycert-<buddyId>'`.
- Consumes: `Certification.buddyId` (Task 1).

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v107_buddy_cert_owner_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v107 buddies + certifications shape (buddies still carry the
/// inline cert columns; certifications has no buddy_id).
NativeDatabase _dbAt106({
  required String buddyId,
  String? level,
  String? agency,
}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 106');
      rawDb.execute('''
        CREATE TABLE buddies (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          email TEXT,
          phone TEXT,
          certification_level TEXT,
          certification_agency TEXT,
          photo_path TEXT,
          notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      rawDb.execute('''
        CREATE TABLE certifications (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          agency TEXT NOT NULL,
          level TEXT,
          card_number TEXT,
          issue_date INTEGER,
          expiry_date INTEGER,
          instructor_name TEXT,
          instructor_number TEXT,
          instructor_id TEXT,
          photo_front_path TEXT,
          photo_back_path TEXT,
          photo_front BLOB,
          photo_back BLOB,
          course_id TEXT,
          notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      rawDb.execute(
        "INSERT INTO buddies (id, name, certification_level, "
        "certification_agency, created_at, updated_at) "
        "VALUES ('$buddyId', 'Sarah', "
        "${level == null ? 'NULL' : "'$level'"}, "
        "${agency == null ? 'NULL' : "'$agency'"}, 0, 0)",
      );
    },
  );
}

void main() {
  test('v107 adds buddy_id and copies a buddy inline cert into a '
      'deterministic-id certifications row', () async {
    final db = AppDatabase(
      _dbAt106(buddyId: 'b1', level: 'cmas2StarDiver', agency: 'cmas'),
    );
    addTearDown(() => db.close());

    final cols =
        await db.customSelect("PRAGMA table_info('certifications')").get();
    expect(cols.map((c) => c.read<String>('name')), contains('buddy_id'));

    final certs = await db.customSelect('SELECT * FROM certifications').get();
    expect(certs, hasLength(1));
    expect(certs.first.data['id'], 'buddycert-b1');
    expect(certs.first.data['buddy_id'], 'b1');
    expect(certs.first.data['diver_id'], isNull);
    expect(certs.first.data['level'], 'cmas2StarDiver');
    expect(certs.first.data['agency'], 'cmas');
  });

  test('v107 defaults agency to "other" when the buddy had a level but no '
      'agency', () async {
    final db = AppDatabase(_dbAt106(buddyId: 'b2', level: 'openWater'));
    addTearDown(() => db.close());
    final cert = await db
        .customSelect("SELECT * FROM certifications WHERE buddy_id = 'b2'")
        .getSingle();
    expect(cert.data['agency'], 'other');
  });

  test('v107 data copy is idempotent (upsert on deterministic id)', () async {
    final db = AppDatabase(
      _dbAt106(buddyId: 'b1', level: 'openWater', agency: 'padi'),
    );
    addTearDown(() => db.close());
    // Force a second beforeOpen pass by re-reading; the copy must not create
    // a duplicate row.
    await db.customSelect('SELECT 1').get();
    final certs = await db
        .customSelect("SELECT * FROM certifications WHERE buddy_id = 'b1'")
        .get();
    expect(certs, hasLength(1));
  });

  test('version ladder includes 107', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(107));
    expect(AppDatabase.migrationVersions, contains(107));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v107_buddy_cert_owner_test.dart`
Expected: FAIL — `currentSchemaVersion` is 106; no `buddy_id` column; no copy.

- [ ] **Step 3: Add the `buddyId` column to the Certifications table class**

In `lib/core/database/database.dart`, inside `class Certifications` (after the `instructorId` getter, ~line 1373), add:
```dart
  // Owner when this certification belongs to a buddy instead of the diver
  // (issue #553). Exactly one of {diverId, buddyId} is set. Cascade so a
  // buddy delete removes their certs (deletion tombstones are written
  // explicitly in the repository — cascade alone does not tombstone).
  TextColumn get buddyId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.cascade)();
```

Then register the sync FK edge. In `lib/core/services/sync/sync_service.dart`, in the `parentRefs` map, change the `certifications` entry (~line 1687) to add the buddy owner edge:
```dart
    'certifications': [
      (field: 'courseId', parent: 'courses', nullable: true),
      (field: 'instructorId', parent: 'buddies', nullable: true),
      (field: 'buddyId', parent: 'buddies', nullable: true),
    ],
```
This is REQUIRED: `sync_parent_refs_completeness_test.dart` asserts `parentRefs` against the live schema and FAILS for any new FK to a deletable parent (`buddies`) until the edge is added. It also lets `_mergeEntity` clear a dangling `buddyId` (nullable) instead of aborting a whole sync on a deferred-FK COMMIT.

- [ ] **Step 4: Bump the schema version and ladder**

In `lib/core/database/database.dart`:
- Line 2162: `static const int currentSchemaVersion = 107;` (this task only adds the v107 expand block; Task 6 bumps to 108 when it adds the v108 contract block — never set the version ahead of the migration blocks that exist).
- In `migrationVersions` (ends at 106, ~line 2270), append: `107,`.

- [ ] **Step 5: Add the enums import (if absent)**

At the top of `lib/core/database/database.dart`, ensure this import exists (needed by the display-name helper in Step 7):
```dart
import 'package:submersion/core/constants/enums.dart';
```

- [ ] **Step 6: Add the v107 onUpgrade block**

In `onUpgrade`, after the `if (from < 106) await reportProgress();` line (~5283), add:
```dart
        if (from < 107) {
          // issue #553: certifications can belong to a buddy. Add the owner
          // column, then copy each buddy's inline cert into a certifications
          // row (deterministic id so per-device migration converges).
          await _assertCertificationBuddyOwnerColumn();
          await _migrateBuddyInlineCertifications();
        }
        if (from < 107) await reportProgress();
```

- [ ] **Step 7: Add the two migration helpers + display-name helper**

In `lib/core/database/database.dart`, near the other private helpers (e.g. after `_assertConnectorSuggestionColumns`, ~line 2298), add:
```dart
  /// Idempotent DDL for the issue #553 buddy-owner column on certifications.
  /// Called from the v107 onUpgrade block and the beforeOpen backstop.
  Future<void> _assertCertificationBuddyOwnerColumn() async {
    final cols =
        await customSelect("PRAGMA table_info('certifications')").get();
    if (cols.isEmpty) return;
    final has = cols.any((c) => c.read<String>('name') == 'buddy_id');
    if (!has) {
      await customStatement(
        'ALTER TABLE certifications ADD COLUMN buddy_id TEXT '
        'REFERENCES buddies (id) ON DELETE CASCADE',
      );
    }
  }

  /// Copy each buddy's inline certification (certification_level /
  /// certification_agency) into a certifications row owned by that buddy.
  /// Idempotent via a deterministic id ('buddycert-<buddyId>') + upsert, so it
  /// is safe to run under the beforeOpen backstop and converges across devices
  /// that each ran the migration independently. No-op once the inline columns
  /// are dropped (v108).
  Future<void> _migrateBuddyInlineCertifications() async {
    final buddyCols = await customSelect("PRAGMA table_info('buddies')").get();
    final names = buddyCols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('certification_level') &&
        !names.contains('certification_agency')) {
      return;
    }
    final rows = await customSelect(
      'SELECT id, certification_level, certification_agency FROM buddies '
      'WHERE certification_level IS NOT NULL '
      'OR certification_agency IS NOT NULL',
    ).get();
    for (final r in rows) {
      final buddyId = r.read<String>('id');
      final level = r.read<String?>('certification_level');
      final agency = r.read<String?>('certification_agency') ?? 'other';
      final certId = 'buddycert-$buddyId';
      final name = _displayNameForMigratedCert(level, agency);
      final now = DateTime.now().millisecondsSinceEpoch;
      await customStatement(
        'INSERT INTO certifications '
        '(id, buddy_id, diver_id, name, agency, level, notes, '
        'created_at, updated_at) '
        "VALUES (?, ?, NULL, ?, ?, ?, '', ?, ?) "
        'ON CONFLICT(id) DO UPDATE SET buddy_id = excluded.buddy_id',
        [certId, buddyId, name, agency, level, now, now],
      );
    }
  }

  /// Human-readable name for a migrated buddy cert: the level's display name
  /// when present, else the agency's.
  String _displayNameForMigratedCert(String? level, String agency) {
    if (level != null) {
      return CertificationLevel.values
          .firstWhere((e) => e.name == level,
              orElse: () => CertificationLevel.other)
          .displayName;
    }
    return CertificationAgency.values
        .firstWhere((e) => e.name == agency,
            orElse: () => CertificationAgency.other)
        .displayName;
  }
```

- [ ] **Step 8: Add the beforeOpen backstop**

In `beforeOpen` (after the existing v99 `instructor_id` backstop block, ~line 5331), add:
```dart
        // v107 backstop (issue #553): re-assert the certifications.buddy_id
        // column and the buddy inline-cert copy. Both are idempotent, so a
        // parallel-branch schema-version collision cannot strand a database
        // without them.
        await _assertCertificationBuddyOwnerColumn();
        await _migrateBuddyInlineCertifications();
```

- [ ] **Step 9: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes, `wrote N outputs`. `CertificationsCompanion` now has a `buddyId` field.

- [ ] **Step 10: Run the migration test**

Run: `flutter test test/core/database/migration_v107_buddy_cert_owner_test.dart`
Expected: PASS (all four tests).

- [ ] **Step 11: Write the failing cert-repo owner test**

Create `test/features/certifications/data/repositories/certification_repository_buddy_owner_test.dart`. Follow the DB-test setup used across `test/features/certifications/data/` (construct `AppDatabase(NativeDatabase.memory())` and inject via `DatabaseService`; mirror a sibling repo test's `setUp`). Core assertions:
```dart
  test('createCertification persists buddyId and hydrates it back', () async {
    final repo = CertificationRepository();
    final saved = await repo.createCertification(
      Certification(
        id: '',
        buddyId: 'b1',
        name: 'Nitrox',
        agency: CertificationAgency.padi,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final read = await repo.getCertificationById(saved.id);
    expect(read!.buddyId, 'b1');
    expect(read.diverId, isNull);
  });

  test('createCertification rejects a row with neither owner', () async {
    final repo = CertificationRepository();
    expect(
      () => repo.createCertification(
        Certification(
          id: '',
          name: 'X',
          agency: CertificationAgency.padi,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
      throwsArgumentError,
    );
  });
```

- [ ] **Step 12: Wire buddyId into the cert repository**

In `lib/features/certifications/data/repositories/certification_repository.dart`:
- In `createCertification`, at the top of the `try` (after `final id = ...`), add the invariant:
```dart
      if ((cert.diverId == null) == (cert.buddyId == null)) {
        throw ArgumentError(
          'Certification must have exactly one owner (diverId XOR buddyId)',
        );
      }
```
- In the insert companion (after `diverId: Value(cert.diverId),`, line 133), add: `buddyId: Value(cert.buddyId),`
- In `_mapRowToCertification` (after `diverId: row.diverId,`, line 349), add: `buddyId: row.buddyId,`

- [ ] **Step 13: Run tests to verify they pass**

Run: `flutter test test/features/certifications/data/repositories/certification_repository_buddy_owner_test.dart`
Expected: PASS

- [ ] **Step 14: Commit** (if authorized)

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/core/services/sync/sync_service.dart lib/features/certifications/data/repositories/certification_repository.dart test/core/database/migration_v107_buddy_cert_owner_test.dart test/features/certifications/data/repositories/certification_repository_buddy_owner_test.dart
git commit -m "feat(certifications): add buddy owner column + v107 expand migration (issue #553)"
```

---

### Task 3: `primaryCertification` derivation (highest by ladder)

**Files:**
- Create: `lib/features/certifications/domain/certification_primary.dart`
- Test: `test/features/certifications/domain/certification_primary_test.dart`

**Interfaces:**
- Produces: `Certification? primaryCertification(List<Certification> certs)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/certifications/domain/certification_primary_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/certification_primary.dart';

Certification cert(
  String id, {
  CertificationAgency agency = CertificationAgency.cmas,
  CertificationLevel? level,
  DateTime? issue,
  DateTime? updated,
}) =>
    Certification(
      id: id,
      buddyId: 'b1',
      name: id,
      agency: agency,
      level: level,
      issueDate: issue,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: updated ?? DateTime(2024, 1, 1),
    );

void main() {
  test('empty list -> null', () {
    expect(primaryCertification(const []), isNull);
  });

  test('higher ladder position wins', () {
    final result = primaryCertification([
      cert('a', level: CertificationLevel.cmas1StarDiver),
      cert('b', level: CertificationLevel.cmas3StarDiver),
      cert('c', level: CertificationLevel.cmas2StarDiver),
    ]);
    expect(result!.id, 'b');
  });

  test('a specialty (off-ladder) ranks below any ladder cert', () {
    final result = primaryCertification([
      cert('spec', agency: CertificationAgency.padi,
          level: CertificationLevel.nitrox),
      cert('ladder', agency: CertificationAgency.padi,
          level: CertificationLevel.openWater),
    ]);
    expect(result!.id, 'ladder');
  });

  test('all specialties / no ladder level -> still returns one (not null)', () {
    final result = primaryCertification([
      cert('n', agency: CertificationAgency.padi,
          level: CertificationLevel.nitrox, issue: DateTime(2020)),
      cert('w', agency: CertificationAgency.padi,
          level: CertificationLevel.wreck, issue: DateTime(2022)),
    ]);
    // tie on rank (-1); newer issue date wins
    expect(result!.id, 'w');
  });

  test('rank tie broken by issueDate then updatedAt', () {
    final result = primaryCertification([
      cert('old', level: CertificationLevel.cmas2StarDiver,
          issue: DateTime(2019)),
      cert('new', level: CertificationLevel.cmas2StarDiver,
          issue: DateTime(2023)),
    ]);
    expect(result!.id, 'new');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/certifications/domain/certification_primary_test.dart`
Expected: FAIL — file/function does not exist.

- [ ] **Step 3: Implement the function**

Create `lib/features/certifications/domain/certification_primary.dart`:
```dart
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// The "primary" certification for a set — the highest by the agency ladder.
///
/// Rank = the level's index in `CertificationLevelCatalog.ladderFor(agency)`;
/// a null level, or a specialty not on that agency's ladder, ranks -1 (below
/// any core-ladder cert). Ties break by latest issue date, then most recently
/// updated. Returns null only for an empty list.
///
/// Cross-agency note: ladder indices are compared directly (best effort) when
/// certs come from different agencies — see the #553 design's non-goals.
Certification? primaryCertification(List<Certification> certs) {
  if (certs.isEmpty) return null;

  int rank(Certification c) {
    final level = c.level;
    if (level == null) return -1;
    return CertificationLevelCatalog.ladderFor(c.agency).indexOf(level);
  }

  final sorted = [...certs]..sort((a, b) {
      final byRank = rank(b).compareTo(rank(a));
      if (byRank != 0) return byRank;
      final ai = a.issueDate;
      final bi = b.issueDate;
      if (ai != null && bi != null && ai != bi) return bi.compareTo(ai);
      if (ai != null && bi == null) return -1;
      if (ai == null && bi != null) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  return sorted.first;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/certifications/domain/certification_primary_test.dart`
Expected: PASS

- [ ] **Step 5: Commit** (if authorized)

```bash
git add lib/features/certifications/domain/certification_primary.dart test/features/certifications/domain/certification_primary_test.dart
git commit -m "feat(certifications): primary-cert derivation (highest by ladder)"
```

---

### Task 4: Buddy-scoped cert repository methods + provider

**Files:**
- Modify: `lib/features/certifications/data/repositories/certification_repository.dart`
- Modify: `lib/features/certifications/presentation/providers/certification_providers.dart`
- Test: `test/features/certifications/data/repositories/certification_repository_buddy_owner_test.dart` (extend)

**Interfaces:**
- Produces:
  - `getCertificationsByBuddy(String buddyId) → Future<List<domain.Certification>>`
  - `getCertificationsForBuddies(List<String> buddyIds) → Future<Map<String, List<domain.Certification>>>`
  - `replaceBuddyCertifications(String buddyId, List<domain.Certification> desired) → Future<void>`
  - `buddyCertificationsProvider` (`FutureProvider.family<List<Certification>, String>`)
- Consumes: `getCertificationById`, `createCertification`, `updateCertification`, `deleteCertification` (Task 2).

- [ ] **Step 1: Write failing tests** (append to the Task 2 owner test file)
```dart
  test('getCertificationsByBuddy returns only that buddy\'s certs', () async {
    final repo = CertificationRepository();
    await repo.createCertification(_buddyCert('b1', 'Nitrox'));
    await repo.createCertification(_buddyCert('b1', 'Deep'));
    await repo.createCertification(_buddyCert('b2', 'Wreck'));
    final b1 = await repo.getCertificationsByBuddy('b1');
    expect(b1.map((c) => c.name), unorderedEquals(['Nitrox', 'Deep']));
  });

  test('replaceBuddyCertifications inserts, updates, and tombstones', () async {
    final repo = CertificationRepository();
    final keep = await repo.createCertification(_buddyCert('b1', 'Nitrox'));
    final drop = await repo.createCertification(_buddyCert('b1', 'Old'));
    await repo.replaceBuddyCertifications('b1', [
      keep.copyWith(name: 'Nitrox (EANx)'), // update
      _buddyCert('b1', 'New'),              // insert (id empty)
      // 'drop' omitted -> delete+tombstone
    ]);
    final now = await repo.getCertificationsByBuddy('b1');
    expect(now.map((c) => c.name), unorderedEquals(['Nitrox (EANx)', 'New']));
    expect(now.any((c) => c.id == drop.id), isFalse);
  });
```
Add a helper `_buddyCert` in the test file:
```dart
Certification _buddyCert(String buddyId, String name) => Certification(
      id: '', buddyId: buddyId, name: name,
      agency: CertificationAgency.padi,
      createdAt: DateTime.now(), updatedAt: DateTime.now());
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/certifications/data/repositories/certification_repository_buddy_owner_test.dart`
Expected: FAIL — methods do not exist.

- [ ] **Step 3: Implement the repository methods**

In `certification_repository.dart`, add:
```dart
  /// All certifications owned by a buddy (newest issue date first).
  Future<List<domain.Certification>> getCertificationsByBuddy(
    String buddyId,
  ) async {
    final query = _db.select(_db.certifications)
      ..where((t) => t.buddyId.equals(buddyId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.issueDate),
        (t) => OrderingTerm.asc(t.name),
      ]);
    final rows = await query.get();
    return rows.map(_mapRowToCertification).toList();
  }

  /// Certifications for many buddies at once, grouped by buddyId. O(1) query.
  Future<Map<String, List<domain.Certification>>> getCertificationsForBuddies(
    List<String> buddyIds,
  ) async {
    if (buddyIds.isEmpty) return {};
    final query = _db.select(_db.certifications)
      ..where((t) => t.buddyId.isIn(buddyIds));
    final rows = await query.get();
    final out = <String, List<domain.Certification>>{};
    for (final row in rows) {
      final cert = _mapRowToCertification(row);
      (out[cert.buddyId!] ??= []).add(cert);
    }
    return out;
  }

  /// Replace a buddy's certification set with [desired]: insert new (empty id),
  /// update existing, and delete+tombstone any existing rows not in [desired].
  /// Used by the buddy edit form's commit-on-save (issue #553).
  Future<void> replaceBuddyCertifications(
    String buddyId,
    List<domain.Certification> desired,
  ) async {
    final existing = await getCertificationsByBuddy(buddyId);
    final existingIds = {for (final c in existing) c.id};
    final keptIds = <String>{};
    for (final cert in desired) {
      final owned = cert.copyWith(buddyId: buddyId);
      if (owned.id.isEmpty || !existingIds.contains(owned.id)) {
        final created = await createCertification(owned);
        keptIds.add(created.id);
      } else {
        await updateCertification(owned);
        keptIds.add(owned.id);
      }
    }
    for (final c in existing) {
      if (!keptIds.contains(c.id)) {
        await deleteCertification(c.id);
      }
    }
  }
```

- [ ] **Step 4: Add the provider**

In `certification_providers.dart`, add:
```dart
/// Certifications owned by a specific buddy. Self-invalidates on any
/// certifications-table change (including sync).
final buddyCertificationsProvider =
    FutureProvider.family<List<Certification>, String>((ref, buddyId) async {
  final repository = ref.watch(certificationRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchCertificationsChanges());
  return repository.getCertificationsByBuddy(buddyId);
});
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/certifications/data/repositories/certification_repository_buddy_owner_test.dart`
Expected: PASS

- [ ] **Step 6: Commit** (if authorized)

```bash
git add lib/features/certifications/data/repositories/certification_repository.dart lib/features/certifications/presentation/providers/certification_providers.dart test/features/certifications/data/repositories/certification_repository_buddy_owner_test.dart
git commit -m "feat(certifications): buddy-scoped cert reads, replace-set, and provider"
```

---

### Task 5: Buddy hydration derives the primary cert; stop writing inline columns

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (6-of-6 buddy construction sites + create/update + new `_certRepo` field + `_withPrimaryCerts` helper; remove now-unused parse helpers)
- Modify: `lib/features/buddies/data/repositories/buddy_merge_repository.dart` (`_mapRowToBuddy`, `createBuddy`/`_updateBuddyRow`/undo re-insert stop writing columns)
- Test: `test/features/buddies/data/repositories/buddy_repository_cert_hydration_test.dart`

**Interfaces:**
- Consumes: `CertificationRepository.getCertificationsForBuddies` (Task 4), `primaryCertification` (Task 3).
- Behavior: `Buddy.certificationLevel`/`certificationAgency` are now the derived primary; buddy writes no longer touch the inline columns.

> NOTE: the inline columns still physically exist here (dropped in Task 6). This task stops *reading* and *writing* them; the Drift getters remain until Task 6.

- [ ] **Step 1: Write the failing test**
```dart
  // setUp inserts buddy rows 'b1' and 'bNoCerts' (follow the sibling
  // test/features/buddies/data/ harness for AppDatabase + DatabaseService).
  Certification cmasCert(String buddyId, String levelName) => Certification(
        id: '',
        buddyId: buddyId,
        name: levelName,
        agency: CertificationAgency.cmas,
        level: CertificationLevel.values.byName(levelName),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  test('getBuddyById derives primary cert (highest by ladder) from certs',
      () async {
    final certRepo = CertificationRepository();
    await certRepo.createCertification(cmasCert('b1', 'cmas1StarDiver'));
    await certRepo.createCertification(cmasCert('b1', 'cmas3StarDiver'));
    final buddy = await BuddyRepository().getBuddyById('b1');
    expect(buddy!.certificationAgency, CertificationAgency.cmas);
    expect(buddy.certificationLevel, CertificationLevel.cmas3StarDiver);
  });

  test('getAllBuddies batch-derives primary for each buddy', () async {
    await CertificationRepository()
        .createCertification(cmasCert('b1', 'cmas2StarDiver'));
    final buddies = await BuddyRepository().getAllBuddies();
    expect(buddies.firstWhere((b) => b.id == 'b1').certificationLevel,
        CertificationLevel.cmas2StarDiver);
    expect(buddies.firstWhere((b) => b.id == 'bNoCerts').certificationLevel,
        isNull);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/buddies/data/repositories/buddy_repository_cert_hydration_test.dart`
Expected: FAIL — hydration still reads the (now-empty-post-cutover) inline columns / returns null.

- [ ] **Step 3: Add cert-repo field + `_withPrimaryCerts` helper**

In `buddy_repository.dart`, add the import `import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';` and `import 'package:submersion/features/certifications/domain/certification_primary.dart';`, then a field near line 45:
```dart
  final CertificationRepository _certRepo = CertificationRepository();
```
Add the helper:
```dart
  /// Fill each buddy's derived primary certification (highest by ladder) from
  /// the certifications table. O(1) queries (batched). Buddies with no certs
  /// keep null level/agency.
  Future<List<domain.Buddy>> _withPrimaryCerts(
    List<domain.Buddy> buddies,
  ) async {
    if (buddies.isEmpty) return buddies;
    final certsByBuddy = await _certRepo.getCertificationsForBuddies(
      buddies.map((b) => b.id).toList(),
    );
    return [
      for (final b in buddies)
        b.copyWith(
          certificationLevel:
              primaryCertification(certsByBuddy[b.id] ?? const [])?.level,
          certificationAgency:
              primaryCertification(certsByBuddy[b.id] ?? const [])?.agency,
        ),
    ];
  }
```

- [ ] **Step 4: Cut over the 6 buddy construction sites**

In each of the following, set `certificationLevel: null, certificationAgency: null` in the `domain.Buddy(...)` construction (they will be filled by `_withPrimaryCerts`), and route the result through the helper:

1. `_mapRowToBuddy` (line 810): set both cert fields to `null` (remove the `_parseCertification*(row.certification*)` calls).
2. `getAllBuddies` (line 88): `return _withPrimaryCerts(rows.map(_mapRowToBuddy).toList());`
3. `getBuddyById` (line 101): `final b = row != null ? _mapRowToBuddy(row) : null; return b == null ? null : (await _withPrimaryCerts([b])).first;`
4. `searchBuddies` (line 135-157): set both cert fields to `null` in the inline `domain.Buddy(...)`, then `final buddies = results.map(...).toList(); return _withPrimaryCerts(buddies);`
5. `findOrCreateByName` (found branch, line 228-247): set both to `null`; before returning the found buddy: `return (await _withPrimaryCerts([found])).first;` (the freshly created buddy has no certs — leave null).
6. `getBuddiesForDive` (line 349-368): set both to `null`; after building `List<BuddyWithRole>`, batch-fill:
```dart
    final filled = await _withPrimaryCerts(list.map((w) => w.buddy).toList());
    final byId = {for (final b in filled) b.id: b};
    return [
      for (final w in list)
        domain.BuddyWithRole(buddy: byId[w.buddy.id]!, role: w.role),
    ];
```
7. `getAllBuddiesWithDiveCount` (line 657-677): set both to `null`; batch-fill the inner buddies the same way, rebuilding `BuddyWithDiveCount(buddy: byId[..]!, diveCount: ..)`.

- [ ] **Step 5: Stop writing the inline columns on create/update**

- `createBuddy` (lines 176-177): delete the `certificationLevel:`/`certificationAgency:` companion lines.
- `updateBuddy` (lines 285-286): delete the same two lines.
- In `buddy_merge_repository.dart`: delete the two column lines in the `undoMerge` re-insert (493-494) and `_updateBuddyRow` (627-628); in that file's `_mapRowToBuddy` (115-129) set both cert fields to `null`.

- [ ] **Step 6: Remove now-dead parse helpers**

`_parseCertificationLevel`/`_parseCertificationAgency` in `buddy_repository.dart` (826-840) and `buddy_merge_repository.dart` (131-145) are now unused → delete them (analyzer will flag as unused otherwise).

- [ ] **Step 7: Run tests + analyze**

Run: `flutter test test/features/buddies/data/repositories/buddy_repository_cert_hydration_test.dart`
Expected: PASS
Run: `flutter analyze` — expect no new "unused" warnings.

- [ ] **Step 8: Commit** (if authorized)

```bash
git add lib/features/buddies/data/repositories/buddy_repository.dart lib/features/buddies/data/repositories/buddy_merge_repository.dart test/features/buddies/data/repositories/buddy_repository_cert_hydration_test.dart
git commit -m "refactor(buddies): derive primary cert at hydration; stop writing inline cert columns (issue #553)"
```

---

### Task 6: Schema CONTRACT (v108) — drop the inline buddy columns

**Files:**
- Modify: `lib/core/database/database.dart` (Buddies table class, v108 onUpgrade block, beforeOpen backstop)
- Test: `test/core/database/migration_v108_drop_buddy_cert_columns_test.dart`

**Interfaces:**
- Behavior: `buddies.certification_level` / `certification_agency` no longer exist; the `Buddy` Drift row class and `BuddiesCompanion` lose those fields. (The domain `Buddy` entity keeps its derived fields — unchanged.)

> Prereq: Task 5 must be complete (nothing reads/writes the columns) or codegen will break compilation.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/migration_v108_drop_buddy_cert_columns_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v108 drops the inline buddy certification columns but preserves the '
      'migrated cert row', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 107');
        // buddies still has the inline columns at v107.
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            email TEXT, phone TEXT, certification_level TEXT,
            certification_agency TEXT, photo_path TEXT,
            notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, buddy_id TEXT,
            name TEXT NOT NULL, agency TEXT NOT NULL, level TEXT,
            card_number TEXT, issue_date INTEGER, expiry_date INTEGER,
            instructor_name TEXT, instructor_number TEXT, instructor_id TEXT,
            photo_front_path TEXT, photo_back_path TEXT, photo_front BLOB,
            photo_back BLOB, course_id TEXT, notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO buddies (id, name, created_at, updated_at) "
          "VALUES ('b1', 'Sarah', 0, 0)",
        );
        rawDb.execute(
          "INSERT INTO certifications (id, buddy_id, name, agency, level, "
          "created_at, updated_at) VALUES ('buddycert-b1', 'b1', '2 Star', "
          "'cmas', 'cmas2StarDiver', 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final buddyCols =
        await db.customSelect("PRAGMA table_info('buddies')").get();
    final names = buddyCols.map((c) => c.read<String>('name')).toSet();
    expect(names, isNot(contains('certification_level')));
    expect(names, isNot(contains('certification_agency')));

    // The migrated cert row survives.
    final cert = await db
        .customSelect("SELECT * FROM certifications WHERE buddy_id = 'b1'")
        .getSingle();
    expect(cert.data['level'], 'cmas2StarDiver');
  });

  test('version ladder includes 108', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(108));
    expect(AppDatabase.migrationVersions, contains(108));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/migration_v108_drop_buddy_cert_columns_test.dart`
Expected: FAIL — columns still present (no v108 block).

- [ ] **Step 3: Remove the two column getters from the Buddies table class**

In `lib/core/database/database.dart`, delete lines 1306-1307:
```dart
  TextColumn get certificationLevel => text().nullable()();
  TextColumn get certificationAgency => text().nullable()();
```

- [ ] **Step 4: Bump the version, then add the v108 onUpgrade block**

First bump the ladder: set `currentSchemaVersion = 108` (line 2162) and append `108,` to `migrationVersions`. Then, after `if (from < 107) await reportProgress();`, add:
```dart
        if (from < 108) {
          // issue #553 contract: inline buddy cert columns are now redundant
          // (data lives in certifications rows since v107). SQLite >= 3.35
          // supports DROP COLUMN; guard so a fresh v108 database no-ops.
          final cols = await customSelect("PRAGMA table_info('buddies')").get();
          final names = cols.map((c) => c.read<String>('name')).toSet();
          if (names.contains('certification_level')) {
            await customStatement(
              'ALTER TABLE buddies DROP COLUMN certification_level',
            );
          }
          if (names.contains('certification_agency')) {
            await customStatement(
              'ALTER TABLE buddies DROP COLUMN certification_agency',
            );
          }
        }
        if (from < 108) await reportProgress();
```

- [ ] **Step 5: Regenerate + run**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test test/core/database/migration_v108_drop_buddy_cert_columns_test.dart`
Expected: PASS. Also run `flutter analyze` (the dropped companion fields must have no remaining references — Task 5 removed them all).

- [ ] **Step 6: Commit** (if authorized)

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v108_drop_buddy_cert_columns_test.dart
git commit -m "feat(certifications): v108 contract migration drops inline buddy cert columns (issue #553)"
```

---

### Task 7: Buddy deletion tombstones child certs

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (`deleteBuddy`)
- Modify: `lib/features/buddies/data/repositories/buddy_merge_repository.dart` (`bulkDeleteBuddies`)
- Test: `test/features/buddies/data/repositories/buddy_deletion_tombstone_test.dart`

**Interfaces:**
- Consumes: `CertificationRepository.getCertificationsByBuddy` + `deleteCertification` (Tasks 2/4).

- [ ] **Step 1: Write the failing test**
```dart
  // setUp inserts buddy row 'b1'.
  test('deleteBuddy tombstones the buddy\'s certifications', () async {
    final certRepo = CertificationRepository();
    final c = await certRepo.createCertification(Certification(
      id: '', buddyId: 'b1', name: 'Nitrox',
      agency: CertificationAgency.padi,
      createdAt: DateTime.now(), updatedAt: DateTime.now()));
    await BuddyRepository().deleteBuddy('b1');

    // cert row gone
    expect(await certRepo.getCertificationById(c.id), isNull);
    // deletion_log has a tombstone for it
    final db = DatabaseService.instance.database;
    final tomb = await db.customSelect(
      "SELECT * FROM deletion_log WHERE entity_type = 'certifications' "
      "AND record_id = ?",
      variables: [Variable.withString(c.id)],
    ).get();
    expect(tomb, hasLength(1));
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/buddies/data/repositories/buddy_deletion_tombstone_test.dart`
Expected: FAIL — no cert tombstone (only the buddy is tombstoned today).

- [ ] **Step 3: Tombstone certs before deleting the buddy**

In `buddy_repository.dart` `deleteBuddy` (310-326), before the `_db.delete(_db.buddies)` line:
```dart
      // issue #553: tombstone the buddy's certs explicitly — FK cascade would
      // delete the rows but never writes a deletion_log entry, so they would
      // resurrect on the next sync.
      for (final cert in await _certRepo.getCertificationsByBuddy(id)) {
        await _certRepo.deleteCertification(cert.id);
      }
```

In `buddy_merge_repository.dart` `bulkDeleteBuddies` (599-618), before the `_db.delete(_db.buddies)` line, add a `CertificationRepository` field to the class (mirror `buddy_repository`) and:
```dart
      for (final id in ids) {
        for (final cert in await _certRepo.getCertificationsByBuddy(id)) {
          await _certRepo.deleteCertification(cert.id);
        }
      }
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/buddies/data/repositories/buddy_deletion_tombstone_test.dart`
Expected: PASS

- [ ] **Step 5: Commit** (if authorized)

```bash
git add lib/features/buddies/data/repositories/buddy_repository.dart lib/features/buddies/data/repositories/buddy_merge_repository.dart test/features/buddies/data/repositories/buddy_deletion_tombstone_test.dart
git commit -m "fix(buddies): tombstone child certs on buddy delete to prevent sync resurrection (issue #553)"
```

---

### Task 8: Buddy merge — survivor inherits the union of certs

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_merge_repository.dart` (`mergeBuddies`, `undoMerge`, add an owner-snapshot type)
- Test: `test/features/buddies/data/repositories/buddy_merge_cert_test.dart`

**Interfaces:**
- Behavior: merging duplicates onto a survivor reassigns every duplicate-owned cert's `buddyId` to the survivor (union); `undoMerge` restores the original `buddyId`.

- [ ] **Step 1: Write the failing test**
```dart
  // setUp inserts buddy rows 'survivor' and 'dup'; `survivorBuddy` is the
  // domain.Buddy for 'survivor'.
  test('merge reassigns duplicate-owned certs to the survivor (union)',
      () async {
    final certRepo = CertificationRepository();
    Certification cert(String buddyId, String name) => Certification(
        id: '', buddyId: buddyId, name: name,
        agency: CertificationAgency.padi,
        createdAt: DateTime.now(), updatedAt: DateTime.now());
    await certRepo.createCertification(cert('survivor', 'OW'));
    final dupCert = await certRepo.createCertification(cert('dup', 'Nitrox'));

    await BuddyMergeRepository()
        .mergeBuddies(survivorBuddy, ['survivor', 'dup']);

    final survivorCerts = await certRepo.getCertificationsByBuddy('survivor');
    expect(survivorCerts.map((c) => c.name),
        unorderedEquals(['OW', 'Nitrox']));
    // reassigned, not duplicated
    expect((await certRepo.getCertificationById(dupCert.id))!.buddyId,
        'survivor');
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_cert_test.dart`
Expected: FAIL — dup's cert is deleted with the dup buddy (cascade) instead of reassigned.

- [ ] **Step 3: Add an owner snapshot type + reassign in `mergeBuddies`**

In `buddy_merge_repository.dart`, near `CertificationInstructorSnapshot`, add:
```dart
class CertificationOwnerSnapshot {
  final String certificationId;
  final String previousBuddyId;
  const CertificationOwnerSnapshot({
    required this.certificationId,
    required this.previousBuddyId,
  });
}
```
In `mergeBuddies`, alongside the existing instructor re-point block (379-403) and BEFORE the duplicates are deleted, reassign owner:
```dart
        // issue #553: survivor inherits the union of certs. Reassign owner
        // (buddyId) from duplicates to survivor so a subsequent duplicate
        // delete does not cascade them away.
        final ownedCerts = await (_db.select(_db.certifications)
              ..where((t) => t.buddyId.isIn(duplicateIds)))
            .get();
        for (final cert in ownedCerts) {
          repointedOwnerCerts.add(CertificationOwnerSnapshot(
            certificationId: cert.id,
            previousBuddyId: cert.buddyId!,
          ));
          await (_db.update(_db.certifications)
                ..where((t) => t.id.equals(cert.id)))
              .write(CertificationsCompanion(
            buddyId: Value(survivorId),
            updatedAt: Value(now),
          ));
          await _syncRepository.markRecordPending(
            entityType: 'certifications',
            recordId: cert.id,
            localUpdatedAt: now,
          );
        }
```
Add `final repointedOwnerCerts = <CertificationOwnerSnapshot>[];` near `repointedCertifications` and thread it into the merge snapshot returned for undo (mirror how `repointedCertifications` is stored).

- [ ] **Step 4: Restore in `undoMerge`**

In `undoMerge`, where instructor links are restored, restore owners:
```dart
        for (final snap in snapshot.repointedOwnerCerts) {
          await (_db.update(_db.certifications)
                ..where((t) => t.id.equals(snap.certificationId)))
              .write(CertificationsCompanion(
            buddyId: Value(snap.previousBuddyId),
            updatedAt: Value(now),
          ));
          await _syncRepository.markRecordPending(
            entityType: 'certifications',
            recordId: snap.certificationId,
            localUpdatedAt: now,
          );
        }
```
(Note: `undoMerge` re-creates the deleted duplicate buddies first — that already happens at 482-506 — so the FK target exists before restoring `buddyId`.)

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_cert_test.dart`
Expected: PASS

- [ ] **Step 6: Commit** (if authorized)

```bash
git add lib/features/buddies/data/repositories/buddy_merge_repository.dart test/features/buddies/data/repositories/buddy_merge_cert_test.dart
git commit -m "feat(buddies): merge unions certs onto survivor with undo (issue #553)"
```

---

### Task 9: Certification editor — staging mode

**Files:**
- Modify: `lib/features/certifications/presentation/pages/certification_edit_page.dart`
- Test: `test/features/certifications/presentation/pages/certification_edit_page_staging_test.dart`

**Interfaces:**
- Produces: `CertificationEditPage({..., Certification? initialCertification, void Function(Certification result)? onStaged})`. When `onStaged != null`, Save builds the `Certification` and calls `onStaged(cert)` WITHOUT persisting (no diver-id lookup, no notifier); prefill comes from `initialCertification` instead of a repo load.

- [ ] **Step 1: Write the failing widget test**

Assert that, given `onStaged`, tapping Save returns the built cert via the callback and does not hit the repository. Use `MaterialApp(themeAnimationDuration: Duration.zero, ...)`; `ensureVisible` the Save button before tapping.
```dart
  testWidgets('staging mode returns a Certification without persisting',
      (tester) async {
    Certification? staged;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CertificationEditPage(
        embedded: true,
        initialCertification: Certification(
          id: 'staged-1', buddyId: 'b1', name: 'Nitrox',
          agency: CertificationAgency.padi,
          createdAt: DateTime(2024), updatedAt: DateTime(2024)),
        onStaged: (c) => staged = c,
      ),
    )));
    await tester.pumpAndSettle();
    // tap Save (embedded header FilledButton)
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(staged, isNotNull);
    expect(staged!.name, 'Nitrox');
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/certifications/presentation/pages/certification_edit_page_staging_test.dart`
Expected: FAIL — no `initialCertification`/`onStaged` params.

- [ ] **Step 3: Add the params + prefill + staged save**

- Add fields to the widget (after `certificationId`, line 19):
```dart
  final Certification? initialCertification;
  final void Function(Certification result)? onStaged;
```
and constructor params `this.initialCertification,` and `this.onStaged,`.
- Add `bool get _isStaging => widget.onStaged != null;` on the state.
- In `initState`, prefill from `initialCertification` when present:
```dart
    if (widget.initialCertification != null) {
      _prefillFrom(widget.initialCertification!);
    } else if (isEditing) {
      _loadCertification();
    }
```
Add `_prefillFrom(Certification cert)` that copies the same fields `_loadCertification` sets (name/cardNumber/instructor/notes controllers + `_agency`,`_level`,`_issueDate`,`_expiryDate`,`_photoFront`,`_photoBack`,`_instructorId`, and `_originalCertification = cert`).
- In `_saveCertification`, branch at the top:
```dart
    if (_isStaging) {
      final now = DateTime.now();
      final cert = Certification(
        id: widget.initialCertification?.id ?? '',
        buddyId: widget.initialCertification?.buddyId,
        diverId: widget.initialCertification?.diverId,
        name: _nameController.text.trim(),
        agency: _agency,
        level: _level,
        cardNumber: _cardNumberController.text.trim().isEmpty
            ? null : _cardNumberController.text.trim(),
        issueDate: _issueDate,
        expiryDate: _expiryDate,
        instructorName: _instructorNameController.text.trim().isEmpty
            ? null : _instructorNameController.text.trim(),
        instructorNumber: _instructorNumberController.text.trim().isEmpty
            ? null : _instructorNumberController.text.trim(),
        instructorId: _instructorId,
        photoFront: _photoFront,
        photoBack: _photoBack,
        notes: _notesController.text.trim(),
        createdAt: widget.initialCertification?.createdAt ?? now,
        updatedAt: now,
      );
      widget.onStaged!(cert);
      if (widget.embedded) {
        widget.onSaved?.call(cert.id);
      } else {
        context.pop();
      }
      return;
    }
```
(The existing persist path is untouched for the self-diver flow.)

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/certifications/presentation/pages/certification_edit_page_staging_test.dart`
Expected: PASS

- [ ] **Step 5: Commit** (if authorized)

```bash
git add lib/features/certifications/presentation/pages/certification_edit_page.dart test/features/certifications/presentation/pages/certification_edit_page_staging_test.dart
git commit -m "feat(certifications): editor staging mode (return without persisting) for buddy flow (issue #553)"
```

---

### Task 10: Buddy edit page — Certifications section (stage + commit on Save)

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart`
- Modify: `lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart` (remove cert cycling)
- Test: `test/features/buddies/presentation/pages/buddy_edit_page_cert_test.dart`

**Interfaces:**
- Consumes: `buddyCertificationsProvider`/`certificationRepositoryProvider.getCertificationsByBuddy` (load), `replaceBuddyCertifications` (commit), `CertificationEditPage(onStaged:, initialCertification:)` (Task 9).

- [ ] **Step 1: Write the failing widget test**

Assert: opening an existing buddy shows its certs as rows; "Add certification" opens the editor; after adding + Save, `replaceBuddyCertifications` is called with the staged list. (Mirror the buddy-edit widget-test setup already in `test/features/buddies/presentation/`; `themeAnimationDuration: Duration.zero`; `ensureVisible` before taps.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/buddies/presentation/pages/buddy_edit_page_cert_test.dart`
Expected: FAIL — no Certifications section / staging.

- [ ] **Step 3: Replace the two dropdowns with a staged list**

- Remove the state fields `_certLevel`/`_certAgency` (63-64); add `List<Certification> _certifications = [];`.
- In `initState` merge branch (97-98) and `_loadBuddy` (139-140): remove `_certLevel`/`_certAgency` assignment. In `_loadBuddy`, after loading the buddy, load certs:
```dart
        final certs = await ref
            .read(certificationRepositoryProvider)
            .getCertificationsByBuddy(widget.buddyId!);
```
and set `_certifications = certs;` inside the `setState`.
- Replace the entire cert section (454-601) with:
```dart
            Text(
              context.l10n.buddies_section_certifications,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final (i, cert) in _certifications.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.card_membership),
                title: Text(cert.level?.displayName ?? cert.name),
                subtitle: Text(cert.agency.displayName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editStagedCert(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        _certifications = [..._certifications]..removeAt(i);
                        _hasChanges = true;
                      }),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(context.l10n.buddies_action_addCertification),
                onPressed: _addStagedCert,
              ),
            ),
            const SizedBox(height: 24),
```
- Add the two handlers (open the editor in a dialog/route in staging mode):
```dart
  Future<void> _addStagedCert() async {
    await _openCertEditor(null);
  }

  Future<void> _editStagedCert(int index) async {
    await _openCertEditor(index);
  }

  Future<void> _openCertEditor(int? index) async {
    final existing = index == null ? null : _certifications[index];
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 480,
          child: CertificationEditPage(
            embedded: true,
            initialCertification: existing ??
                Certification.empty().copyWith(buddyId: widget.buddyId),
            onStaged: (result) {
              setState(() {
                final next = [..._certifications];
                if (index == null) {
                  next.add(result);
                } else {
                  next[index] = result;
                }
                _certifications = next;
                _hasChanges = true;
              });
            },
            onSaved: (_) => Navigator.of(ctx).pop(),
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }
```
- Update imports: add `certification.dart`, `certification_edit_page.dart`, `certification_providers.dart`; remove `certification_levels.dart` if no longer used.

- [ ] **Step 4: Commit staged certs on Save**

In `_saveBuddy` (798-908):
- Remove `certificationLevel: _certLevel, certificationAgency: _certAgency,` from the `Buddy(...)` construction (820-821).
- After the buddy is persisted (both `isEditing` and new branches produce `savedBuddy`), and after `setRolesForBuddy`, add (non-merge branch only):
```dart
      await ref
          .read(certificationRepositoryProvider)
          .replaceBuddyCertifications(savedBuddy.id, _certifications);
```
- Merge branch: do NOT commit `_certifications` (the merge repo unions certs onto the survivor — Task 8). Leave the cert section out of the merge save path.

- [ ] **Step 5: Remove cert cycling from the merge controller**

In `buddy_merge_form_controller.dart`, remove `certAgencyCandidates`/`certLevelCandidates`/`cycleCertAgency`/`cycleCertLevel` and the `(certLevel, certAgency)` return from `initialize` (return the remaining record fields or `void`). Update `initState`'s merge branch in `buddy_edit_page.dart` accordingly (it no longer destructures `certLevel`/`certAgency`). In merge mode, hide the Certifications section (wrap it in `if (!widget.isMerging) ...[ ... ]`).

- [ ] **Step 6: l10n keys**

Add to `lib/l10n/arb/app_en.arb` (and all 10 locales in Task 13; add English now so it compiles):
```json
  "buddies_section_certifications": "Certifications",
  "buddies_action_addCertification": "Add certification",
```
Run `flutter gen-l10n`.

- [ ] **Step 7: Run + analyze + format**

Run: `flutter test test/features/buddies/presentation/pages/buddy_edit_page_cert_test.dart`
Expected: PASS. Then `flutter analyze`, `dart format .`.

- [ ] **Step 8: Commit** (if authorized)

```bash
git add lib/features/buddies/presentation/pages/buddy_edit_page.dart lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart lib/l10n/arb/app_en.arb lib/l10n/generated test/features/buddies/presentation/pages/buddy_edit_page_cert_test.dart
git commit -m "feat(buddies): multi-cert editor on buddy edit page, staged + committed on save (issue #553)"
```

---

### Task 11: Buddy detail page — certification list

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- Test: `test/features/buddies/presentation/pages/buddy_detail_page_cert_test.dart`

**Interfaces:**
- Consumes: `buddyCertificationsProvider` (Task 4).

- [ ] **Step 1: Write the failing widget test**

Assert the section renders one row per cert (agency + name) and an empty state when the buddy has none.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/buddies/presentation/pages/buddy_detail_page_cert_test.dart`
Expected: FAIL.

- [ ] **Step 3: Convert `_buildCertificationSection` to a cert list**

`_BuddyDetailContent` is a `ConsumerWidget`, so pass `ref` to the section and watch the provider. Replace `_buildCertificationSection(context)` (464-496) and its call site (137-140):
```dart
          // Certifications (issue #553)
          _buildCertificationSection(context, ref),
          const SizedBox(height: 24),
```
```dart
  Widget _buildCertificationSection(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(buddyCertificationsProvider(buddy.id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.buddies_section_certifications,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            certsAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (certs) => certs.isEmpty
                  ? Text(context.l10n.buddies_certifications_empty,
                      style: Theme.of(context).textTheme.bodyMedium)
                  : Column(
                      children: [
                        for (final cert in certs)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.card_membership),
                            title: Text(cert.level?.displayName ?? cert.name),
                            subtitle: Text(cert.agency.displayName),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
```
(The embedded header subtitle at 257-263 keeps using `buddy.certificationLevel` — the derived primary — unchanged.)

- [ ] **Step 4: l10n key**

Add to `app_en.arb`: `"buddies_certifications_empty": "No certifications",` and `flutter gen-l10n`.

- [ ] **Step 5: Run + pass**

Run: `flutter test test/features/buddies/presentation/pages/buddy_detail_page_cert_test.dart`
Expected: PASS

- [ ] **Step 6: Commit** (if authorized)

```bash
git add lib/features/buddies/presentation/pages/buddy_detail_page.dart lib/l10n/arb/app_en.arb lib/l10n/generated test/features/buddies/presentation/pages/buddy_detail_page_cert_test.dart
git commit -m "feat(buddies): buddy detail shows full certification list (issue #553)"
```

---

### Task 12: UDDF export/import of multiple buddy certifications

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (~185-215)
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (~393-409)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (~533-550, buddy build)
- Test: `test/core/services/export/uddf/uddf_buddy_certifications_test.dart`

**Interfaces:**
- Behavior: export emits one `<certification>` element per buddy cert (from the certs table, not the removed inline fields); import creates buddy-owned `Certifications` rows.

- [ ] **Step 1: Write the failing round-trip test**

Export a buddy with two certs → parse back → two buddy-owned certs.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/export/uddf/uddf_buddy_certifications_test.dart`
Expected: FAIL — export still reads `buddy.certificationLevel`/`Agency` (now the single derived primary), and import writes only inline fields.

- [ ] **Step 3: Export the buddy's cert rows**

In `uddf_full_export_service.dart`, replace the `if (buddy.certificationLevel != null || buddy.certificationAgency != null) { ... }` block (194-213) with an iteration over the buddy's certs (load via `CertificationRepository.getCertificationsByBuddy(buddy.id)`; the export service already has DB access — pass the list in where the buddy loop is built). Emit one element per cert:
```dart
                      for (final cert in certsByBuddy[buddy.id] ?? const []) {
                        builder.element('certification', nest: () {
                          if (cert.level != null) {
                            builder.element('level', nest: cert.level!.name);
                          }
                          builder.element('agency', nest: cert.agency.name);
                          if (cert.cardNumber != null) {
                            builder.element('cardNumber',
                                nest: cert.cardNumber!);
                          }
                        });
                      }
```
Load `certsByBuddy` once before the buddy loop via `getCertificationsForBuddies(buddyIds)`.

- [ ] **Step 4: Parse multiple certs on import**

In `uddf_import_parsers.dart`, change `findElements('certification').firstOrNull` (393) to iterate ALL `<certification>` elements and collect a `List<Map<String,dynamic>>` under `buddy['certifications']` (each map with `level`/`agency`/`cardNumber`).

In `uddf_entity_importer.dart`, after building + inserting the `Buddy` (533-550) — and dropping the now-removed `certificationLevel`/`certificationAgency` args from the `Buddy(...)` constructor — create buddy-owned certs:
```dart
      for (final certMap in (buddyData['certifications'] as List? ?? const [])) {
        await certRepository.createCertification(Certification(
          id: '',
          buddyId: newId,
          name: _certName(certMap),
          agency: _parseEnum(certMap['agency'], CertificationAgency.values)
              ?? CertificationAgency.other,
          level: _parseEnum(certMap['level'], CertificationLevel.values),
          cardNumber: certMap['cardNumber'] as String?,
          createdAt: now, updatedAt: now,
        ));
      }
```

- [ ] **Step 5: Run + pass**

Run: `flutter test test/core/services/export/uddf/uddf_buddy_certifications_test.dart`
Expected: PASS

- [ ] **Step 6: Commit** (if authorized)

```bash
git add lib/core/services/export/uddf/uddf_full_export_service.dart lib/core/services/export/uddf/uddf_import_parsers.dart lib/features/dive_import/data/services/uddf_entity_importer.dart test/core/services/export/uddf/uddf_buddy_certifications_test.dart
git commit -m "feat(uddf): export/import multiple buddy certifications (issue #553)"
```

---

### Task 13: Localize new strings into all locales + full verification

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- (Regenerated) `lib/l10n/generated/*`

- [ ] **Step 1: Add the three new keys to each non-en locale**

Add `buddies_section_certifications`, `buddies_action_addCertification`, `buddies_certifications_empty` to all 10 locale ARBs with translated values (match casing/format of neighboring keys; keys stay in alphabetical order within their section).

- [ ] **Step 2: Regenerate**

Run: `flutter gen-l10n`
Expected: no "untranslated message" warnings for the three keys.

- [ ] **Step 3: Full verification**

Run: `dart format .`
Run: `flutter analyze` (whole project — expect "No issues found!")
Run the feature's test files together:
`flutter test test/features/certifications test/features/buddies/data test/features/buddies/presentation/pages/buddy_edit_page_cert_test.dart test/features/buddies/presentation/pages/buddy_detail_page_cert_test.dart test/core/database/migration_v107_buddy_cert_owner_test.dart test/core/database/migration_v108_drop_buddy_cert_columns_test.dart test/core/services/export/uddf/uddf_buddy_certifications_test.dart`
Expected: all PASS.

- [ ] **Step 4: Commit** (if authorized)

```bash
git add lib/l10n/arb lib/l10n/generated
git commit -m "i18n(buddies): localize certification section strings (issue #553)"
```

---

## Post-implementation

- **Manual smoke (macOS):** create a buddy → add 2-3 certs (a CMAS star level + specialties) → verify the buddy chip/list column shows the star level (primary), the detail page lists all certs, edit/remove works, and a two-buddy merge unions certs onto the survivor.
- **Two-device sync verify** (when hardware available): buddy-owned cert round-trips; deleting a buddy on device A does not resurrect its certs after device B syncs.
- **Update `docs/FEATURE_ROADMAP.md`** if it tracks this item.
