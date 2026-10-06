# Diver and Buddy Profile Photos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give divers and buddies a profile photo stored as a size-bounded JPEG blob in the database, so it syncs across devices without growing the database without limit.

**Architecture:** A nullable `BlobColumn photo` is added to the `divers` and `buddies` Drift tables, mirroring the existing `certifications.photoFront` blob. All resizing happens in Dart on the write path through a new shared codec, because `image_picker`'s size arguments are silently ignored on desktop. A pan-and-zoom crop dialog returns a rectangle in source-image pixels, which the codec crops, downscales to 512x512, and JPEG-encodes. One shared `ProfileAvatar` widget replaces 13 duplicated `CircleAvatar` sites.

**Tech Stack:** Flutter, Drift (SQLite/SQLCipher), Riverpod, `image: ^4.3.0`, `image_picker: ^1.1.2`, `flutter_contacts: ^2.0.2`, GoRouter.

**Spec:** `docs/superpowers/specs/2026-08-29-diver-buddy-profile-photos-design.md`

## Global Constraints

- **Worktree:** all work happens in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-photos` on branch `worktree-profile-photos`. Use absolute paths; the shell's working directory can reset to the main checkout between commands.
- **No em-dashes** (U+2014) in any output: code, comments, docs, commit messages, ARB strings. En-dashes (U+2013) used as prose punctuation, double hyphens, and spaced hyphens are equally forbidden. Use commas, colons, semicolons, parentheses, or two sentences. Hyphens inside compound words and CLI flags are fine.
- **No emojis** in code, comments, or documentation.
- **Stored avatar format:** 512x512 square JPEG, quality 85.
- **Stored certification card format:** 2000px longest edge, quality 85, aspect ratio preserved.
- **Schema:** claim rung **181**. Re-verify against `origin/main` before Task 1. PR #1374 already landed and took 180, which is why this is 181. `minimumCompatibleSchemaVersion` stays **170** and must not be changed.
- **Line numbers are advisory, the quoted code is authoritative.** They were re-derived after rebasing onto `origin/main` at v180. If a number does not match, locate the quoted snippet by text and proceed.
- **Analyze must be run as** `flutter analyze --fatal-infos` (CI fails on info-level diagnostics).
- **Format must be run as** `dart format .` before committing; CI runs `dart format --set-exit-if-changed .`.
- **Never pipe `flutter test` through `grep`.** The pipeline returns grep's exit status, so a failing suite reads as success.
- **ARB parity:** `test/l10n/arb_parity_test.dart` requires all 10 non-English locales to define exactly the English key set. Any string change lands in all 11 files in the same commit.
- **Generated files split two ways.** `*.g.dart` is gitignored (`.gitignore:9`), so Drift and mockito output is never committed and a fresh worktree must run `build_runner` before anything compiles. But `lib/l10n/arb/app_localizations*.dart` comes from `flutter gen-l10n`, does not match that pattern, and IS tracked, so l10n regeneration must be committed.
- **Immutability:** never mutate objects or arrays; all domain entities have `copyWith`.
- **Commit only what the task names.** Never `git add -A` or `git add -u` in this repo: sibling worktrees share the checkout and a broad add can commit another session's work or restage a stale submodule.

---

## File Structure

**Created:**

| Path | Responsibility |
| --- | --- |
| `lib/core/services/images/profile_photo_codec.dart` | Bytes-in/bytes-out decode, orientation-bake, crop, resize, JPEG-encode on an isolate |
| `lib/shared/widgets/profile_photo/profile_photo_crop_geometry.dart` | Pure viewport-to-source-pixel rectangle math |
| `lib/shared/widgets/profile_photo/profile_photo_crop_dialog.dart` | Full-screen pan/zoom crop surface |
| `lib/shared/widgets/profile_photo/profile_photo_source_sheet.dart` | Source chooser (camera, library, contacts, remove) |
| `lib/shared/widgets/profile_photo/profile_photo_picker.dart` | Orchestrates source sheet, byte acquisition, crop dialog, encode |
| `lib/shared/widgets/profile_photo/profile_avatar.dart` | Shared avatar display with initials fallback |
| `lib/shared/utils/contact_import_support.dart` | Shared iOS/Android platform guard |

**Modified:** `lib/core/database/database.dart`, `lib/features/divers/domain/entities/diver.dart`, `lib/features/buddies/domain/entities/buddy.dart`, both repositories, `buddy_merge_repository.dart`, `sync_data_serializer.dart`, the 13 avatar call sites, `buddy_list_content.dart`, `certification_edit_page.dart`, `entity_table_view.dart`, `app_router.dart`, and all 11 ARB files.

---

## Task 1: Schema column and v181 migration

**Files:**
- Modify: `lib/core/database/database.dart` (table classes, helper, ladder, `migrationVersions`, `currentSchemaVersion`, `beforeOpen`)
- Test: `test/core/database/migration_v181_profile_photo_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `divers.photo` and `buddies.photo` as `BlobColumn` (`Uint8List?`), generated Drift row fields `Diver.photo` and `Buddy.photo`, and `AppDatabase.currentSchemaVersion == 181`.

- [ ] **Step 1: Confirm rung 181 is still free**

Run:
```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-photos
git fetch origin main
git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "
```
Expected: `currentSchemaVersion = 180`. If it reports 181 or higher, use the next free integer above it everywhere this task says 181, and say so in the commit message.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v181_profile_photo_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v181 shape: divers and buddies without the photo column,
/// stamped at v180 so the upgrade to 181 runs.
NativeDatabase _dbAt180() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 180');
      rawDb.execute('''
        CREATE TABLE divers (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute('''
        CREATE TABLE buddies (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute("INSERT INTO divers (id) VALUES ('d1')");
      rawDb.execute("INSERT INTO buddies (id) VALUES ('b1')");
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

void main() {
  test('v181 adds a nullable photo column to divers and buddies', () async {
    final db = AppDatabase(_dbAt180());
    addTearDown(() => db.close());

    expect(await _columns(db, 'divers'), contains('photo'));
    expect(await _columns(db, 'buddies'), contains('photo'));

    // Pre-existing rows survive and default to no photo.
    final diver = await db
        .customSelect("SELECT photo FROM divers WHERE id = 'd1'")
        .getSingle();
    expect(diver.data['photo'], isNull);
  });

  test('fresh databases get the photo column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _columns(db, 'divers'), contains('photo'));
    expect(await _columns(db, 'buddies'), contains('photo'));
  });

  test('the helper no-ops when the tables are absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 180'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v181 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(181));
    expect(AppDatabase.migrationVersions, contains(181));
  });

  test('the sync compatibility floor is unchanged', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 170);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v181_profile_photo_test.dart`
Expected: FAIL. The `photo` column is missing and `migrationVersions` does not contain 181.

- [ ] **Step 4: Add the Drift columns**

In `lib/core/database/database.dart`, in `class Divers extends Table` (around line 20), replace the `photoPath` line with these two lines:

```dart
  /// Deprecated, superseded by [photo]. Never written for divers; kept so a
  /// database that predates v181 still maps.
  TextColumn get photoPath => text().nullable()();

  /// Profile photo: a 512x512 square JPEG produced by
  /// `lib/core/services/images/profile_photo_codec.dart`. Stored on the row so
  /// it syncs with the diver rather than depending on a device-local path.
  BlobColumn get photo => blob().nullable()();
```

In `class Buddies extends Table` (around line 1983), make the identical change, with "buddy" in place of "diver" in the second comment.

- [ ] **Step 5: Add the idempotent DDL helper**

In `lib/core/database/database.dart`, directly after `_assertBuddyFavoriteColumn` (around line 5569), add:

```dart
  /// Idempotent DDL for the v181 divers.photo and buddies.photo columns.
  /// Holds a 512x512 square JPEG, so it is nullable with no default. Self-
  /// guards on each table existing, which is what makes it safe to call from
  /// both the ladder and beforeOpen.
  Future<void> _assertProfilePhotoColumns() async {
    for (final table in const ['divers', 'buddies']) {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('photo')) {
        await customStatement('ALTER TABLE $table ADD COLUMN photo BLOB');
      }
    }
  }
```

- [ ] **Step 6: Add the ladder rung**

In `lib/core/database/database.dart`, immediately after the `if (from < 180) await reportProgress();` line (around line 9265), add:

```dart
        // v181: divers.photo and buddies.photo, the profile photo blobs.
        if (from < 181) {
          await _assertProfilePhotoColumns();
        }
        if (from < 181) await reportProgress();
```

- [ ] **Step 7: Append to migrationVersions**

In `lib/core/database/database.dart`, change the tail of `migrationVersions` (around line 3717) from `    180,\n  ];` to:

```dart
    180,
    // v181: divers.photo and buddies.photo, the profile photo blobs. Claimed
    // against origin/main at 180. A rung at or below the shipped version
    // merges with no conflict marker and its onUpgrade step then never runs,
    // so re-verify this number if this branch sits open while main advances.
    181,
  ];
```

- [ ] **Step 8: Bump currentSchemaVersion**

In `lib/core/database/database.dart` line 3329, change `static const int currentSchemaVersion = 180;` to `static const int currentSchemaVersion = 181;`. Do **not** touch `minimumCompatibleSchemaVersion`.

- [ ] **Step 9: Add the beforeOpen backstop**

In `lib/core/database/database.dart`, in the `beforeOpen` block after the `_assertSiteSuggestionDismissedAtColumn()` backstop call (around line 9472), add:

```dart
        // v181 backstop: re-assert divers.photo and buddies.photo. A database
        // that arrives by restore or sync-adopt never runs onUpgrade, and
        // every read of a diver or buddy row would throw without the column.
        await _assertProfilePhotoColumns();
```

- [ ] **Step 10: Regenerate Drift code**

Run:
```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-photos
dart run build_runner build --delete-conflicting-outputs
```
Expected: succeeds. `lib/core/database/database.g.dart` now has `photo` on the divers and buddies table and data classes.

Do NOT try to commit `database.g.dart`. `.gitignore:9` is a blanket `*.g.dart`, so every Drift and mockito output is untracked and each worktree regenerates its own. `git add` on it fails with "paths are ignored".

- [ ] **Step 11: Run the test to verify it passes**

Run: `flutter test test/core/database/migration_v181_profile_photo_test.dart`
Expected: PASS, all five tests.

- [ ] **Step 12: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/database/database.dart test/core/database/migration_v181_profile_photo_test.dart
git commit -m "feat(db): add profile photo blob columns to divers and buddies (v181)"
```

---

## Task 2: Domain entities

**Files:**
- Modify: `lib/features/divers/domain/entities/diver.dart`
- Modify: `lib/features/buddies/domain/entities/buddy.dart`
- Test: `test/features/divers/domain/diver_copywith_clear_test.dart` (modify)
- Test: `test/features/buddies/domain/buddy_photo_test.dart` (create)

**Interfaces:**
- Consumes: nothing from Task 1 at compile time.
- Produces: `Diver.photo` (`Uint8List?`, clearable via `copyWith(photo: null)`), `Buddy.photo` (`Uint8List?`), and `Buddy clearPhoto()`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/buddies/domain/buddy_photo_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

Buddy _buddy({Uint8List? photo}) => Buddy(
  id: 'b1',
  name: 'Jane Doe',
  photo: photo,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  test('photo defaults to null', () {
    expect(_buddy().photo, isNull);
  });

  test('copyWith carries the photo through', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(_buddy().copyWith(photo: bytes).photo, bytes);
  });

  test('clearPhoto removes the photo and keeps every other field', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final withPhoto = _buddy(photo: bytes);
    final cleared = withPhoto.clearPhoto();

    expect(cleared.photo, isNull);
    expect(cleared.id, withPhoto.id);
    expect(cleared.name, withPhoto.name);
    expect(cleared.createdAt, withPhoto.createdAt);
    expect(cleared.updatedAt, withPhoto.updatedAt);
  });

  test('photo participates in equality', () {
    final a = _buddy(photo: Uint8List.fromList([1]));
    final b = _buddy(photo: Uint8List.fromList([1]));
    expect(a, isNot(equals(b)),
        reason: 'Uint8List equality is by identity, so two distinct byte '
            'lists make distinct buddies; this documents the behaviour so a '
            'future change to props is deliberate');
    expect(a, equals(a));
  });
}
```

In `test/features/divers/domain/diver_copywith_clear_test.dart`, add this test inside the existing `main()`:

```dart
  test('copyWith clears the photo when passed null', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final d = Diver(
      id: 'd1',
      name: 'Jane',
      photo: bytes,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    expect(d.photo, bytes);
    expect(d.copyWith(photo: null).photo, isNull);
    expect(d.copyWith().photo, bytes);
  });
```

Add `import 'dart:typed_data';` to that file if it is not already imported.

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
flutter test test/features/buddies/domain/buddy_photo_test.dart test/features/divers/domain/diver_copywith_clear_test.dart
```
Expected: FAIL, "No named parameter with the name 'photo'".

- [ ] **Step 3: Add photo to Diver**

In `lib/features/divers/domain/entities/diver.dart`:

Add `import 'dart:typed_data';` at the top if absent.

After the `final String? photoPath;` field declaration (line 69), add:

```dart
  /// Profile photo: a 512x512 square JPEG. Supersedes [photoPath].
  final Uint8List? photo;
```

In the constructor, after `this.photoPath,`, add `this.photo,`.

In `copyWith`'s parameter list, after `Object? photoPath = _unset,`, add:

```dart
    Object? photo = _unset,
```

In the returned `Diver(...)`, after the `photoPath:` line, add:

```dart
      photo: _resolve<Uint8List?>(photo, this.photo, 'photo'),
```

In `props`, after `photoPath,`, add `photo,`.

- [ ] **Step 4: Add photo and clearPhoto to Buddy**

In `lib/features/buddies/domain/entities/buddy.dart`:

Add `import 'dart:typed_data';` at the top.

After `final String? photoPath;` (line 15), add:

```dart
  /// Profile photo: a 512x512 square JPEG. Supersedes [photoPath].
  final Uint8List? photo;
```

In the constructor, after `this.photoPath,`, add `this.photo,`.

In `copyWith`'s parameter list, after `String? photoPath,`, add `Uint8List? photo,`. In the returned `Buddy(...)`, after the `photoPath:` line, add `photo: photo ?? this.photo,`.

Then add this method directly after `copyWith`:

```dart
  /// Create a copy with the profile photo explicitly removed.
  ///
  /// [copyWith] uses the plain `??` idiom, so `copyWith(photo: null)` keeps
  /// the current value rather than clearing it. This mirrors
  /// `Certification.clearPhotos`, which solves the same problem for the
  /// certification card blobs.
  Buddy clearPhoto() {
    return Buddy(
      id: id,
      diverId: diverId,
      name: name,
      email: email,
      phone: phone,
      certificationLevel: certificationLevel,
      certificationAgency: certificationAgency,
      photoPath: photoPath,
      photo: null,
      notes: notes,
      isFavorite: isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
```

In `props`, after `photoPath,`, add `photo,`.

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
flutter test test/features/buddies/domain/buddy_photo_test.dart test/features/divers/domain/diver_copywith_clear_test.dart
```
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/divers/domain/entities/diver.dart lib/features/buddies/domain/entities/buddy.dart test/features/buddies/domain/buddy_photo_test.dart test/features/divers/domain/diver_copywith_clear_test.dart
git commit -m "feat(entities): carry a profile photo on Diver and Buddy"
```

---

## Task 3: Repository wiring

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (every `photoPath` site: lines 152, 182, 244, 292, 385, 447, 838, 1117)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (every `photoPath` site: lines 144, 208, 676)
- Modify: `lib/features/buddies/data/repositories/buddy_merge_repository.dart` (lines 115, 446, 594)
- Modify: `lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart` (line 81)
- Test: `test/features/buddies/data/buddy_photo_persistence_test.dart` (create)

**Interfaces:**
- Consumes: `Buddy.photo`, `Diver.photo` from Task 2; `buddies.photo`, `divers.photo` columns from Task 1.
- Produces: photos that survive a create, read, update, and clear round-trip.

- [ ] **Step 1: Write the failing test**

Create `test/features/buddies/data/buddy_photo_persistence_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

import '../../../helpers/test_database.dart';

Buddy _buddy({Uint8List? photo}) => Buddy(
  id: 'b-photo-1',
  name: 'Jane Doe',
  photo: photo,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  test('a photo survives create and read', () async {
    final repo = BuddyRepository();
    final bytes = Uint8List.fromList(List.generate(64, (i) => i));

    await repo.createBuddy(_buddy(photo: bytes));
    final read = await repo.getBuddyById('b-photo-1');

    expect(read, isNotNull);
    expect(read!.photo, bytes);
  });

  test('updating to a new photo replaces the stored bytes', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(_buddy(photo: Uint8List.fromList([1, 2, 3])));

    final replacement = Uint8List.fromList([9, 9, 9, 9]);
    await repo.updateBuddy(_buddy(photo: replacement));
    final read = await repo.getBuddyById('b-photo-1');

    expect(read!.photo, replacement);
  });

  test('updating with a null photo clears the stored bytes', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(_buddy(photo: Uint8List.fromList([1, 2, 3])));

    await repo.updateBuddy(_buddy().clearPhoto());
    final read = await repo.getBuddyById('b-photo-1');

    expect(read!.photo, isNull);
  });

  test('a buddy with no photo reads back null, not empty bytes', () async {
    final repo = BuddyRepository();
    await repo.createBuddy(_buddy());
    final read = await repo.getBuddyById('b-photo-1');

    expect(read!.photo, isNull);
  });
}
```

If `getBuddyById` is not the accessor name in this repository, open `buddy_repository.dart` and use the single-buddy read method it actually defines. Do not add a new one.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/buddies/data/buddy_photo_persistence_test.dart`
Expected: FAIL. The photo reads back null after create, because the mapper and companion drop it.

- [ ] **Step 3: Wire the buddy repository**

In `lib/features/buddies/data/repositories/buddy_repository.dart`:

In `_mapRowToBuddy` (line 1106, the `photoPath: row.photoPath,` at line 1117), add `photo: row.photo,` directly after it.

In the inline row-to-`Buddy` construction feeding `_withPrimaryCerts` (lines 140-162), which reads columns via `row.data[...]`, after the `photoPath:` entry add:

```dart
        photo: row.data['photo'] as Uint8List?,
```

In `createBuddy`'s `BuddiesCompanion` (method at line 167, the `photoPath:` line at 182), after `photoPath: Value(buddy.photoPath),` add `photo: Value(buddy.photo),`.

In `updateBuddy`'s `BuddiesCompanion` (method at line 279, the `photoPath:` line at 292), make the identical addition.

There are four further `photoPath` sites in this file, and every one of them needs a `photo` sibling or the photo silently vanishes on that path:

- **Lines 244, 385, 838** are row mappers reading `row.data['photo_path'] as String?`. Add `photo: row.data['photo'] as Uint8List?,` directly after each.
- **Line 447** is an entity-to-entity copy reading `photoPath: b.photoPath,`. Add `photo: b.photo,` after it.

Use `grep -n "photoPath" lib/features/buddies/data/repositories/buddy_repository.dart` and confirm you end with exactly eight `photo` siblings, one per `photoPath`.

Add `import 'dart:typed_data';` if the file does not already import it.

- [ ] **Step 4: Wire the diver repository**

In `lib/features/divers/data/repositories/diver_repository.dart`:

In `_mapRowToDiver` (method at line 670, the `photoPath: row.photoPath,` at line 676), add `photo: row.photo,` directly after it.

In `createDiver`'s `DiversCompanion` (method at line 130, companion at 139, the `photoPath:` line at 144), after `photoPath: Value(diver.photoPath),` add `photo: Value(diver.photo),`.

In `updateDiver`'s `DiversCompanion` (method at line 198, companion at 204, the `photoPath:` line at 208), make the identical addition.

Leave the `DiversCompanion` at line 558 alone: it writes only `isDefault` and `updatedAt`.

Add `import 'dart:typed_data';` if absent.

- [ ] **Step 5: Wire the merge paths**

In `lib/features/buddies/data/repositories/buddy_merge_repository.dart`, at each of lines 115, 446, and 594, add a `photo` line beside the existing `photoPath` line, in the same style as its neighbour (`photo: row.photo,` for a mapper, `photo: Value(buddy.photo),` for a companion).

In `lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart`, line 81 selects a winning `photoPath` with `(buddy) => buddy.photoPath`. Add an equivalent selector for `photo` immediately after it, following the surrounding code's shape exactly.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/buddies/data/buddy_photo_persistence_test.dart`
Expected: PASS, all four tests.

- [ ] **Step 7: Run the surrounding suites for regressions**

Run:
```bash
flutter test test/features/buddies test/features/divers
```
Expected: PASS. If `buddy_list_tile_test.dart` fails, leave it: Task 11 rewrites it. Note the failure and move on only if it is that one file.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/buddies/data lib/features/divers/data lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart test/features/buddies/data/buddy_photo_persistence_test.dart
git commit -m "feat(repos): persist diver and buddy profile photos"
```

---

## Task 4: Sync serialization

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (12 sites: lines 654, 718, 1555, 1650, 1971, 2026, 2444, 2549, 2951, 3115, 4535, 4803)
- Test: `test/core/services/sync/sync_blob_base64_test.dart` (modify)

**Interfaces:**
- Consumes: `divers.photo`, `buddies.photo` from Task 1.
- Produces: diver and buddy photos encoded as base64 strings on the sync wire.

- [ ] **Step 1: Write the failing test**

In `test/core/services/sync/sync_blob_base64_test.dart`, add these tests inside the existing `group('Sync BLOB base64 encoding', ...)`:

```dart
    test('a buddy photo is exported as a base64 string', () async {
      final serializer = SyncDataSerializer();
      final photo = Uint8List.fromList(List.generate(256, (i) => i % 256));

      await serializer.upsertRecord('buddies', {
        'id': 'buddy-b64-1',
        'name': 'Jane Doe',
        'notes': '',
        'isFavorite': false,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'photo': photo,
      });

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();

      final payload = await cloudBasePayload(cloud, deviceId);
      final row = payload!.data.buddies.firstWhere(
        (r) => r['id'] == 'buddy-b64-1',
      );

      expect(
        row['photo'],
        isA<String>(),
        reason: 'a buddy photo must serialize as base64, not a byte array',
      );
      expect(row['photo'], base64Encode(photo));
    });

    test('a diver photo round-trips through fetchRecord', () async {
      final serializer = SyncDataSerializer();
      final photo = Uint8List.fromList(List.generate(128, (i) => 255 - i % 256));

      await serializer.upsertRecord('divers', {
        'id': 'diver-b64-1',
        'name': 'Jane Doe',
        'medicalNotes': '',
        'notes': '',
        'isDefault': false,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'photo': photo,
      });

      final restored = await serializer.fetchRecord('divers', 'diver-b64-1');
      expect(restored, isNotNull);
      final blob = restored!['photo'];
      final bytes = blob is String
          ? base64Decode(blob)
          : Uint8List.fromList((blob as List).cast<int>());
      expect(bytes, photo);
    });

    test('a legacy array-encoded buddy photo still imports', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('buddies', {
        'id': 'buddy-legacy-1',
        'name': 'Jane Doe',
        'notes': '',
        'isFavorite': false,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'photo': [0x01, 0x02, 0x03],
      });

      final restored = await serializer.fetchRecord('buddies', 'buddy-legacy-1');
      final blob = restored!['photo'];
      final bytes = blob is String
          ? base64Decode(blob)
          : Uint8List.fromList((blob as List).cast<int>());
      expect(bytes, [0x01, 0x02, 0x03]);
    });

    test('a null buddy photo exports as null', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('buddies', {
        'id': 'buddy-nullphoto',
        'name': 'Jane Doe',
        'notes': '',
        'isFavorite': false,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'photo': null,
      });

      final deviceId = await SyncRepository().getDeviceId();
      await buildService().performSync();
      final payload = await cloudBasePayload(cloud, deviceId);
      final row = payload!.data.buddies.firstWhere(
        (r) => r['id'] == 'buddy-nullphoto',
      );
      expect(row['photo'], isNull);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/sync_blob_base64_test.dart`
Expected: FAIL. `row['photo']` is a `List<int>`, not a `String`.

- [ ] **Step 3: Flip the base table flags**

In `lib/core/services/sync/sync_data_serializer.dart`:

Line 654, change to:
```dart
    (key: 'divers', table: _db.divers, blob: true, full: null),
```

Line 718, change to:
```dart
    (key: 'buddies', table: _db.buddies, blob: true, full: null),
```

- [ ] **Step 4: Update the delta exporters**

In `_exportDivers` (line 4535), change the final line to:

```dart
    // Divers carry the profile photo BLOB; base64-encode it.
    return rows.map((r) => r.toJson(serializer: _syncBlobSerializer)).toList();
```

In `_exportBuddies` (line 4803), make the identical change with "Buddies" in the comment.

- [ ] **Step 5: Update fetchRecord**

At line 1555 (`case 'divers':`) and line 1650 (`case 'buddies':`), change `return row?.toJson();` to:

```dart
        return row?.toJson(serializer: _syncBlobSerializer);
```

- [ ] **Step 6: Update fetchRecords (the batch fetch)**

At line 1971 (`case 'divers':`) and line 2026 (`case 'buddies':`), change the map comprehension to:

```dart
        return {
          for (final r in rows) r.id: r.toJson(serializer: _syncBlobSerializer),
        };
```

- [ ] **Step 7: Update upsertRecord**

At line 2444, change the divers case body to:

```dart
        await _db
            .into(_db.divers)
            .insertOnConflictUpdate(
              Diver.fromJson(
                data,
                serializer: _syncBlobSerializer,
              ).toCompanion(false),
            );
        return;
```

At line 2549, make the identical change for `buddies`, using `Buddy.fromJson` and `_db.buddies`.

- [ ] **Step 8: Update upsertRecords (the batch upsert)**

At line 2951, change the divers case body to:

```dart
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.divers,
            records
                .map(
                  (r) => Diver.fromJson(
                    r,
                    serializer: _syncBlobSerializer,
                  ).toCompanion(false),
                )
                .toList(),
          ),
        );
        return;
```

At line 3115, make the identical change for `buddies`.

- [ ] **Step 9: Run the test to verify it passes**

Run: `flutter test test/core/services/sync/sync_blob_base64_test.dart`
Expected: PASS.

- [ ] **Step 10: Run the sync suite for regressions**

Run: `flutter test test/core/services/sync`
Expected: PASS.

- [ ] **Step 11: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/sync_blob_base64_test.dart
git commit -m "feat(sync): base64-encode diver and buddy profile photos"
```

---

## Task 5: The image codec

**Files:**
- Create: `lib/core/services/images/profile_photo_codec.dart`
- Test: `test/core/services/images/profile_photo_codec_test.dart` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `class ImageEncodeSpec { final int maxDimension; final int jpegQuality; final bool square; static const avatar; static const certificationCard; }`
  - `class ImageEncodeRequest` with `.fromBytes({required Uint8List bytes, required ImageEncodeSpec spec, Rect? cropRect, String? declaredName, int maxSourcePixels})`
  - `enum ImageEncodeOutcome { encoded, undecodable, tooLarge }`
  - `class ImageEncodeResult { final ImageEncodeOutcome outcome; final Uint8List? bytes; final int sizeBytes; final String? error; }`
  - `Future<ImageEncodeResult> encodeStoredImage(ImageEncodeRequest request)`
  - `@visibleForTesting ImageEncodeResult runImageEncodeRequest(ImageEncodeRequest request)`

- [ ] **Step 1: Write the failing test**

Create `test/core/services/images/profile_photo_codec_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/services/images/profile_photo_codec.dart';

/// A solid-colour JPEG of the given size, for feeding the codec.
Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 60, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

img.Image _decode(Uint8List bytes) => img.decodeImage(bytes)!;

void main() {
  test('a landscape source becomes a 512x512 square', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(1600, 900),
        spec: ImageEncodeSpec.avatar,
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.encoded);
    final out = _decode(result.bytes!);
    expect(out.width, 512);
    expect(out.height, 512);
  });

  test('a portrait source becomes a 512x512 square', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(900, 1600),
        spec: ImageEncodeSpec.avatar,
      ),
    );

    final out = _decode(result.bytes!);
    expect(out.width, 512);
    expect(out.height, 512);
  });

  test('a source smaller than the ceiling is not upscaled', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(200, 200),
        spec: ImageEncodeSpec.avatar,
      ),
    );

    final out = _decode(result.bytes!);
    expect(out.width, 200);
    expect(out.height, 200);
  });

  test('an explicit crop rect selects that region', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(1000, 1000),
        spec: ImageEncodeSpec.avatar,
        cropRect: const Rect.fromLTWH(100, 100, 400, 400),
      ),
    );

    final out = _decode(result.bytes!);
    expect(out.width, 400, reason: '400px crop is under the 512 ceiling');
    expect(out.height, 400);
  });

  test('the certification spec preserves aspect ratio', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(4000, 2000),
        spec: ImageEncodeSpec.certificationCard,
      ),
    );

    final out = _decode(result.bytes!);
    expect(out.width, 2000);
    expect(out.height, 1000);
  });

  test('undecodable bytes report undecodable, not a throw', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: Uint8List.fromList([0, 1, 2, 3, 4]),
        spec: ImageEncodeSpec.avatar,
        declaredName: 'broken.jpg',
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.undecodable);
    expect(result.bytes, isNull);
  });

  test('a source above maxSourcePixels reports tooLarge', () {
    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: _jpeg(1000, 1000),
        spec: ImageEncodeSpec.avatar,
        maxSourcePixels: 500 * 500,
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.tooLarge);
    expect(result.bytes, isNull);
  });

  test('EXIF orientation 6 is baked before cropping', () {
    // Orientation 6 means "rotate 90 degrees clockwise to display upright".
    // Build a 200x100 image whose LEFT half is red, then declare orientation
    // 6. Displayed upright it is 100x200 with red on TOP, so a crop of the
    // top half must come back red.
    final source = img.Image(width: 200, height: 100);
    img.fill(source, color: img.ColorRgb8(0, 0, 255));
    img.fillRect(source,
        x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(255, 0, 0));
    source.exif.imageIfd.orientation = 6;
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 95));

    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: bytes,
        spec: ImageEncodeSpec.avatar,
        declaredName: 'rotated.jpg',
        cropRect: const Rect.fromLTWH(0, 0, 100, 100),
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.encoded);
    final out = _decode(result.bytes!);
    final pixel = out.getPixel(50, 50);
    expect(pixel.r, greaterThan(pixel.b),
        reason: 'orientation must be baked before the crop is applied, or '
            'the crop selects the wrong region');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/images/profile_photo_codec_test.dart`
Expected: FAIL, "Target of URI doesn't exist: profile_photo_codec.dart".

- [ ] **Step 3: Write the codec**

Create `lib/core/services/images/profile_photo_codec.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// How a stored image blob is bounded.
///
/// Sizing is enforced HERE, in Dart, and never through `ImagePicker`'s
/// `maxWidth` / `maxHeight` / `imageQuality`: those arguments are silently
/// ignored by image_picker_macos, image_picker_windows and image_picker_linux,
/// so a desktop pick would enter the database at full size and ride into every
/// sync changeset as base64.
@immutable
class ImageEncodeSpec {
  const ImageEncodeSpec({
    required this.maxDimension,
    required this.jpegQuality,
    required this.square,
  });

  /// Longest edge of the output, in pixels. A source already within this is
  /// never upscaled.
  final int maxDimension;

  final int jpegQuality;

  /// When true the output is cropped to a square before resizing, so every
  /// avatar render site can assume a 1:1 aspect and never letterbox.
  final bool square;

  /// Profile photo for a diver or buddy: 512x512, roughly 50-80 KB. The
  /// largest avatar in the app draws at radius 50, so 300 physical pixels at
  /// 3x; 512 is deliberate headroom for a future enlarged view, since the
  /// source is discarded at pick time.
  static const avatar =
      ImageEncodeSpec(maxDimension: 512, jpegQuality: 85, square: true);

  /// Certification card face. Card text must stay readable, so the ceiling is
  /// higher and the source aspect ratio is preserved.
  static const certificationCard =
      ImageEncodeSpec(maxDimension: 2000, jpegQuality: 85, square: false);
}

/// One encode job, sendable to an isolate.
@immutable
class ImageEncodeRequest {
  const ImageEncodeRequest.fromBytes({
    required this.bytes,
    required this.spec,
    this.cropRect,
    this.declaredName,
    this.maxSourcePixels = _defaultMaxSourcePixels,
  });

  /// 80 megapixels. Decoding is what allocates, and nothing caps a desktop
  /// pick, so a source beyond this is refused rather than risking an isolate
  /// out-of-memory that would surface as an unexplained failure.
  static const int _defaultMaxSourcePixels = 80 * 1000 * 1000;

  final Uint8List bytes;
  final ImageEncodeSpec spec;

  /// Region of the DECODED, orientation-corrected source to keep, in source
  /// pixels. Null means the largest centered square when [ImageEncodeSpec
  /// .square] is set, or the whole image otherwise.
  final Rect? cropRect;

  /// Filename whose extension picks the decoder. package:image's generic
  /// probe tries every format and the permissive ones accept arbitrary bytes,
  /// so pass this whenever the source name is known.
  final String? declaredName;

  final int maxSourcePixels;
}

/// What [encodeStoredImage] did.
enum ImageEncodeOutcome {
  /// A JPEG was produced and is in [ImageEncodeResult.bytes].
  encoded,

  /// package:image could not decode the source.
  undecodable,

  /// The decoded source exceeded [ImageEncodeRequest.maxSourcePixels].
  tooLarge,
}

@immutable
class ImageEncodeResult {
  const ImageEncodeResult(
    this.outcome, {
    this.bytes,
    this.sizeBytes = 0,
    this.error,
  });

  final ImageEncodeOutcome outcome;

  /// The encoded JPEG, non-null only for [ImageEncodeOutcome.encoded].
  final Uint8List? bytes;

  final int sizeBytes;

  /// Why the source could not be decoded, carried as a String rather than
  /// letting the exception cross the isolate boundary and lose the outcome
  /// the caller switches on.
  final String? error;
}

/// Runs [request] on a background isolate.
Future<ImageEncodeResult> encodeStoredImage(ImageEncodeRequest request) =>
    compute(runImageEncodeRequest, request);

/// The isolate body. Top-level and public so a test can exercise the work
/// itself without paying for an isolate spawn per case.
@visibleForTesting
ImageEncodeResult runImageEncodeRequest(ImageEncodeRequest request) {
  final name = request.declaredName;
  final img.Image? decoded;
  try {
    decoded = name != null && name.contains('.')
        ? img.decodeNamedImage(name, request.bytes)
        : img.decodeImage(request.bytes);
  } on Exception catch (e) {
    return ImageEncodeResult(
      ImageEncodeOutcome.undecodable,
      error: e.toString(),
    );
  }
  if (decoded == null) {
    return const ImageEncodeResult(ImageEncodeOutcome.undecodable);
  }

  if (decoded.width * decoded.height > request.maxSourcePixels) {
    return const ImageEncodeResult(ImageEncodeOutcome.tooLarge);
  }

  // Orientation MUST be resolved before any geometry is applied. The JPEG
  // decoder does no orientation handling, so a portrait phone photo arrives
  // as a sideways buffer carrying exif.orientation = 6. Cropping first would
  // apply a rectangle chosen in the upright preview to a rotated buffer and
  // select the wrong region.
  final upright = img.bakeOrientation(decoded);

  final cropped = _crop(upright, request);

  final longest =
      cropped.width > cropped.height ? cropped.width : cropped.height;
  final resized = longest > request.spec.maxDimension
      ? img.copyResize(
          cropped,
          // Width or height only: passing both resizes to exact bounds and
          // distorts the aspect ratio.
          width: cropped.width >= cropped.height
              ? request.spec.maxDimension
              : null,
          height:
              cropped.height > cropped.width ? request.spec.maxDimension : null,
        )
      : cropped;

  // Re-encoding drops EXIF, so GPS embedded in a gallery or contact photo
  // cannot ride into a blob that syncs to every device and cloud provider.
  final jpeg = Uint8List.fromList(
    img.encodeJpg(resized, quality: request.spec.jpegQuality),
  );
  return ImageEncodeResult(
    ImageEncodeOutcome.encoded,
    bytes: jpeg,
    sizeBytes: jpeg.length,
  );
}

img.Image _crop(img.Image source, ImageEncodeRequest request) {
  final rect = request.cropRect;
  if (rect != null) {
    final x = rect.left.round().clamp(0, source.width - 1);
    final y = rect.top.round().clamp(0, source.height - 1);
    final w = rect.width.round().clamp(1, source.width - x);
    final h = rect.height.round().clamp(1, source.height - y);
    return img.copyCrop(source, x: x, y: y, width: w, height: h);
  }

  if (!request.spec.square) return source;

  final side =
      source.width < source.height ? source.width : source.height;
  return img.copyCrop(
    source,
    x: (source.width - side) ~/ 2,
    y: (source.height - side) ~/ 2,
    width: side,
    height: side,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/images/profile_photo_codec_test.dart`
Expected: PASS, all eight tests. If the orientation test fails, the `bakeOrientation` call is in the wrong position relative to `_crop`.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/core/services/images/profile_photo_codec.dart test/core/services/images/profile_photo_codec_test.dart
git commit -m "feat(images): add a bounded profile photo codec"
```

---

## Task 6: Crop geometry

**Files:**
- Create: `lib/shared/widgets/profile_photo/profile_photo_crop_geometry.dart`
- Test: `test/shared/widgets/profile_photo/profile_photo_crop_geometry_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `Rect cropRectInSourcePixels({required Matrix4 transform, required Size viewport, required Size childSize, required Size sourceSize})`.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/profile_photo/profile_photo_crop_geometry_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_crop_geometry.dart';

void main() {
  test('identity transform over a square child selects the whole source', () {
    final rect = cropRectInSourcePixels(
      transform: Matrix4.identity(),
      viewport: const Size(300, 300),
      childSize: const Size(300, 300),
      sourceSize: const Size(1200, 1200),
    );

    expect(rect.left, closeTo(0, 0.01));
    expect(rect.top, closeTo(0, 0.01));
    expect(rect.width, closeTo(1200, 0.01));
    expect(rect.height, closeTo(1200, 0.01));
  });

  test('a 2x zoom selects the centre quarter when centred', () {
    // InteractiveViewer scales about the origin, so a 2x zoom with the
    // viewport centred means translating back by half the viewport.
    final transform = Matrix4.identity()
      ..translate(-150.0, -150.0)
      ..scale(2.0, 2.0);

    final rect = cropRectInSourcePixels(
      transform: transform,
      viewport: const Size(300, 300),
      childSize: const Size(300, 300),
      sourceSize: const Size(1200, 1200),
    );

    expect(rect.width, closeTo(600, 0.01));
    expect(rect.height, closeTo(600, 0.01));
  });

  test('the result is independent of device pixel ratio', () {
    // The same gesture expressed at two viewport sizes must select the same
    // region of the SOURCE, which is what makes the stored image identical
    // on a 1x and a 3x screen.
    final small = cropRectInSourcePixels(
      transform: Matrix4.identity(),
      viewport: const Size(200, 200),
      childSize: const Size(200, 200),
      sourceSize: const Size(1000, 1000),
    );
    final large = cropRectInSourcePixels(
      transform: Matrix4.identity(),
      viewport: const Size(600, 600),
      childSize: const Size(600, 600),
      sourceSize: const Size(1000, 1000),
    );

    expect(small.width, closeTo(large.width, 0.01));
    expect(small.height, closeTo(large.height, 0.01));
  });

  test('a pan beyond the image is clamped into bounds', () {
    final transform = Matrix4.identity()..translate(500.0, 500.0);

    final rect = cropRectInSourcePixels(
      transform: transform,
      viewport: const Size(300, 300),
      childSize: const Size(300, 300),
      sourceSize: const Size(1200, 1200),
    );

    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(1200));
    expect(rect.bottom, lessThanOrEqualTo(1200));
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/widgets/profile_photo/profile_photo_crop_geometry_test.dart`
Expected: FAIL, URI does not exist.

- [ ] **Step 3: Write the geometry**

Create `lib/shared/widgets/profile_photo/profile_photo_crop_geometry.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Maps the square crop viewport back into source-image pixel coordinates.
///
/// The crop is computed as GEOMETRY rather than by rasterizing the widget
/// through a `RepaintBoundary`. Rasterizing would bake in the device pixel
/// ratio, cap the output at whatever the viewport happened to render, and be
/// almost untestable. A rectangle is a pure value: the same gesture yields
/// the same stored image on a 1x desktop window and a 3x phone, and this
/// function unit-tests with no widget tree at all.
///
/// [transform] is `TransformationController.value` from the InteractiveViewer.
/// [viewport] is the square crop window in logical pixels, [childSize] is the
/// image as laid out inside the viewer, and [sourceSize] is the decoded image's
/// pixel dimensions.
Rect cropRectInSourcePixels({
  required Matrix4 transform,
  required Size viewport,
  required Size childSize,
  required Size sourceSize,
}) {
  // Undo the viewer's transform to find which part of the child the viewport
  // is showing.
  final inverse = Matrix4.inverted(transform);
  final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
  final bottomRight = MatrixUtils.transformPoint(
    inverse,
    Offset(viewport.width, viewport.height),
  );

  // Child (logical) pixels to source pixels.
  final scaleX = sourceSize.width / childSize.width;
  final scaleY = sourceSize.height / childSize.height;

  final rawLeft = topLeft.dx * scaleX;
  final rawTop = topLeft.dy * scaleY;
  final rawRight = bottomRight.dx * scaleX;
  final rawBottom = bottomRight.dy * scaleY;

  // Clamp into the image. minScale is set to the cover scale at the call
  // site, so a gap is not normally representable; this is a guard, not
  // routine control flow.
  final left = rawLeft.clamp(0.0, sourceSize.width);
  final top = rawTop.clamp(0.0, sourceSize.height);
  final right = rawRight.clamp(0.0, sourceSize.width);
  final bottom = rawBottom.clamp(0.0, sourceSize.height);

  // Never hand back a degenerate rect: the codec would crop to nothing.
  final width = (right - left).clamp(1.0, sourceSize.width);
  final height = (bottom - top).clamp(1.0, sourceSize.height);

  return Rect.fromLTWH(
    left.clamp(0.0, sourceSize.width - width),
    top.clamp(0.0, sourceSize.height - height),
    width,
    height,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/shared/widgets/profile_photo/profile_photo_crop_geometry_test.dart`
Expected: PASS, all four tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/shared/widgets/profile_photo/profile_photo_crop_geometry.dart test/shared/widgets/profile_photo/profile_photo_crop_geometry_test.dart
git commit -m "feat(profile-photo): add pure crop geometry"
```

---

## Task 7: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and all 10 other locale ARB files in `lib/l10n/arb/`
- Test: `test/l10n/arb_parity_test.dart` (existing, must stay green)

**Interfaces:**
- Consumes: nothing.
- Produces: `context.l10n.profilePhoto_*` getters used by Tasks 8, 9, 12, 13, 14.

- [ ] **Step 1: Add the English keys**

Append these to `lib/l10n/arb/app_en.arb`, immediately before the closing `}`. Remember to add a comma to the previous last entry.

```json
  "profilePhoto_sheet_title": "Profile Photo",
  "profilePhoto_source_camera": "Take Photo",
  "profilePhoto_source_library": "Choose from Library",
  "profilePhoto_source_file": "Choose File",
  "profilePhoto_source_contacts": "Choose from Contacts",
  "profilePhoto_action_remove": "Remove Photo",
  "profilePhoto_crop_title": "Adjust Photo",
  "profilePhoto_crop_hint": "Drag to reposition, pinch to zoom",
  "profilePhoto_error_tooLarge": "That image is too large to use. Try a smaller one.",
  "profilePhoto_error_undecodable": "That file could not be read as an image.",
  "profilePhoto_error_contactNoPhoto": "That contact does not have a photo."
```

Reuse the existing `common_action_cancel`, `common_action_save`, and `common_action_remove` rather than adding new ones.

- [ ] **Step 2: Add the same keys to all 10 other locales**

Add the identical 11 keys to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, and `app_zh.arb`, translated into each language. Do not leave English values in place: the parity test checks presence, but leaving English text in a translated file ships an untranslated string.

Suggested German, as a shape reference:

```json
  "profilePhoto_sheet_title": "Profilfoto",
  "profilePhoto_source_camera": "Foto aufnehmen",
  "profilePhoto_source_library": "Aus Mediathek wählen",
  "profilePhoto_source_file": "Datei wählen",
  "profilePhoto_source_contacts": "Aus Kontakten wählen",
  "profilePhoto_action_remove": "Foto entfernen",
  "profilePhoto_crop_title": "Foto anpassen",
  "profilePhoto_crop_hint": "Ziehen zum Verschieben, zwei Finger zum Zoomen",
  "profilePhoto_error_tooLarge": "Dieses Bild ist zu groß. Bitte ein kleineres wählen.",
  "profilePhoto_error_undecodable": "Diese Datei konnte nicht als Bild gelesen werden.",
  "profilePhoto_error_contactNoPhoto": "Dieser Kontakt hat kein Foto."
```

- [ ] **Step 3: Regenerate localizations**

Run:
```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-photos
flutter gen-l10n
```
Expected: succeeds, `lib/l10n/arb/app_localizations*.dart` are regenerated.

- [ ] **Step 4: Run the parity test to verify it passes**

Run: `flutter test test/l10n/arb_parity_test.dart`
Expected: PASS. A failure naming "N missing" against every locale means English has keys the others do not.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/l10n/arb
git commit -m "feat(l10n): add profile photo strings in all locales"
```

---

## Task 8: The crop dialog

**Files:**
- Create: `lib/shared/widgets/profile_photo/profile_photo_crop_dialog.dart`
- Test: `test/shared/widgets/profile_photo/profile_photo_crop_dialog_test.dart` (create)

**Interfaces:**
- Consumes: `cropRectInSourcePixels` (Task 6), `encodeStoredImage` / `ImageEncodeSpec` / `ImageEncodeOutcome` (Task 5), `profilePhoto_crop_*` strings (Task 7).
- Produces: `Future<Uint8List?> showProfilePhotoCropDialog({required BuildContext context, required Uint8List sourceBytes, String? declaredName})`, returning encoded bytes or null on cancel.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/profile_photo/profile_photo_crop_dialog_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/shared/widgets/profile_photo/profile_photo_crop_dialog.dart';

import '../../../helpers/test_app.dart';

Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 60, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  testWidgets('cancel returns null', (tester) async {
    Uint8List? result;
    var called = false;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showProfilePhotoCropDialog(
                context: context,
                sourceBytes: _jpeg(800, 600),
                declaredName: 'pick.jpg',
              );
              called = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Adjust Photo'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    // Pump manually: the dialog runs a progress state, so pumpAndSettle can
    // time out on an animating spinner.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(called, isTrue);
    expect(result, isNull);
  });

  testWidgets('save returns encoded square bytes', (tester) async {
    Uint8List? result;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showProfilePhotoCropDialog(
                context: context,
                sourceBytes: _jpeg(800, 600),
                declaredName: 'pick.jpg',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(result, isNotNull);
    final out = img.decodeImage(result!)!;
    expect(out.width, out.height, reason: 'the stored photo must be square');
    expect(out.width, lessThanOrEqualTo(512));
  });

  testWidgets('the dialog shows the repositioning hint', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showProfilePhotoCropDialog(
              context: context,
              sourceBytes: _jpeg(400, 400),
              declaredName: 'pick.jpg',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Drag to reposition, pinch to zoom'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/widgets/profile_photo/profile_photo_crop_dialog_test.dart`
Expected: FAIL, URI does not exist.

- [ ] **Step 3: Write the dialog**

Create `lib/shared/widgets/profile_photo/profile_photo_crop_dialog.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_crop_geometry.dart';

/// Shows the pan and zoom crop surface and returns the encoded 512x512 JPEG,
/// or null if the user cancelled.
///
/// A full-screen dialog rather than a bottom sheet: a crop wants maximum area,
/// and `showModalBottomSheet(isScrollControlled: true)` removes the height
/// ceiling entirely, which puts a drag handle inside Android's notification
/// shade zone (issue #1188). Popping happens from inside this builder's own
/// context, which addresses the root navigator that `showDialog` already
/// defaults to, so this is not the pattern that blanked master-detail in
/// PR #1312.
Future<Uint8List?> showProfilePhotoCropDialog({
  required BuildContext context,
  required Uint8List sourceBytes,
  String? declaredName,
}) {
  return showDialog<Uint8List?>(
    context: context,
    builder: (dialogContext) => _ProfilePhotoCropDialog(
      sourceBytes: sourceBytes,
      declaredName: declaredName,
    ),
  );
}

class _ProfilePhotoCropDialog extends StatefulWidget {
  const _ProfilePhotoCropDialog({
    required this.sourceBytes,
    this.declaredName,
  });

  final Uint8List sourceBytes;
  final String? declaredName;

  @override
  State<_ProfilePhotoCropDialog> createState() =>
      _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<_ProfilePhotoCropDialog> {
  final TransformationController _controller = TransformationController();
  ui.Image? _decoded;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.sourceBytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _decoded = frame.image);
  }

  @override
  void dispose() {
    _controller.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  Future<void> _save(Size viewport, Size childSize, Size sourceSize) async {
    setState(() => _busy = true);
    final rect = cropRectInSourcePixels(
      transform: _controller.value,
      viewport: viewport,
      childSize: childSize,
      sourceSize: sourceSize,
    );
    final result = await encodeStoredImage(
      ImageEncodeRequest.fromBytes(
        bytes: widget.sourceBytes,
        spec: ImageEncodeSpec.avatar,
        cropRect: rect,
        declaredName: widget.declaredName,
      ),
    );
    if (!mounted) return;
    if (result.outcome != ImageEncodeOutcome.encoded) {
      setState(() => _busy = false);
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.outcome == ImageEncodeOutcome.tooLarge
                ? l10n.profilePhoto_error_tooLarge
                : l10n.profilePhoto_error_undecodable,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(result.bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final decoded = _decoded;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profilePhoto_crop_title),
          leading: TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.common_action_cancel),
          ),
          leadingWidth: 96,
        ),
        body: decoded == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth < constraints.maxHeight
                      ? constraints.maxWidth
                      : constraints.maxHeight;
                  final viewport = Size(side, side);
                  final sourceSize = Size(
                    decoded.width.toDouble(),
                    decoded.height.toDouble(),
                  );
                  // Lay the child out at cover scale so the square viewport is
                  // always fully covered; minScale 1.0 then makes a gap
                  // unrepresentable rather than something to validate against.
                  final coverScale = decoded.width < decoded.height
                      ? side / decoded.width
                      : side / decoded.height;
                  final childSize = Size(
                    decoded.width * coverScale,
                    decoded.height * coverScale,
                  );

                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: ClipOval(
                              child: InteractiveViewer(
                                transformationController: _controller,
                                minScale: 1,
                                maxScale: 5,
                                constrained: false,
                                child: SizedBox(
                                  width: childSize.width,
                                  height: childSize.height,
                                  child: Image.memory(
                                    widget.sourceBytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.profilePhoto_crop_hint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _save(viewport, childSize, sourceSize),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.common_action_save),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/shared/widgets/profile_photo/profile_photo_crop_dialog_test.dart`
Expected: PASS, all three tests. If a test hangs, add another `await tester.pump(const Duration(milliseconds: 500));` rather than switching to `pumpAndSettle`.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/shared/widgets/profile_photo/profile_photo_crop_dialog.dart test/shared/widgets/profile_photo/profile_photo_crop_dialog_test.dart
git commit -m "feat(profile-photo): add the pan and zoom crop dialog"
```

---

## Task 9: Source sheet and picker orchestration

**Files:**
- Create: `lib/shared/utils/contact_import_support.dart`
- Create: `lib/shared/widgets/profile_photo/profile_photo_source_sheet.dart`
- Create: `lib/shared/widgets/profile_photo/profile_photo_picker.dart`
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart` (line 80, remove the private getter)
- Test: `test/shared/widgets/profile_photo/profile_photo_source_sheet_test.dart` (create)

**Interfaces:**
- Consumes: `showProfilePhotoCropDialog` (Task 8), `profilePhoto_*` strings (Task 7).
- Produces:
  - `bool get isContactImportSupported` in `lib/shared/utils/contact_import_support.dart`
  - `enum ProfilePhotoSource { camera, library, contacts, remove }`
  - `Future<ProfilePhotoSource?> showProfilePhotoSourceSheet({required BuildContext context, required bool hasPhoto, required bool allowContacts})`
  - `class ProfilePhotoResult { const ProfilePhotoResult({Uint8List? bytes, bool removed = false}); final Uint8List? bytes; final bool removed; }`
  - `Future<ProfilePhotoResult?> pickProfilePhoto({required BuildContext context, required bool hasPhoto, required bool allowContacts, Future<Uint8List?> Function(BuildContext context)? contactPhotoLoader})`. The `contactPhotoLoader` is left null by Task 9 and supplied by Task 14, which is what keeps this shared widget free of a `flutter_contacts` dependency.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/profile_photo/profile_photo_source_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_source_sheet.dart';

import '../../../helpers/test_app.dart';

Future<void> _open(
  WidgetTester tester, {
  required bool hasPhoto,
  required bool allowContacts,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showProfilePhotoSourceSheet(
            context: context,
            hasPhoto: hasPhoto,
            allowContacts: allowContacts,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('hides Remove Photo when there is no photo', (tester) async {
    await _open(tester, hasPhoto: false, allowContacts: false);
    expect(find.text('Remove Photo'), findsNothing);
  });

  testWidgets('shows Remove Photo when a photo exists', (tester) async {
    await _open(tester, hasPhoto: true, allowContacts: false);
    expect(find.text('Remove Photo'), findsOneWidget);
  });

  testWidgets('hides Choose from Contacts when not allowed', (tester) async {
    await _open(tester, hasPhoto: false, allowContacts: false);
    expect(find.text('Choose from Contacts'), findsNothing);
  });

  testWidgets('shows Choose from Contacts when allowed', (tester) async {
    await _open(tester, hasPhoto: false, allowContacts: true);
    expect(find.text('Choose from Contacts'), findsOneWidget);
  });

  testWidgets('always offers a library option', (tester) async {
    await _open(tester, hasPhoto: false, allowContacts: false);
    expect(
      find.text('Choose from Library').evaluate().isNotEmpty ||
          find.text('Choose File').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/widgets/profile_photo/profile_photo_source_sheet_test.dart`
Expected: FAIL, URI does not exist.

- [ ] **Step 3: Extract the platform guard**

Create `lib/shared/utils/contact_import_support.dart`:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Whether the device address book can be reached at all.
///
/// flutter_contacts ships iOS and Android implementations only. Lifted out of
/// `buddy_list_content.dart` so the buddy import flow and the profile photo
/// source sheet cannot drift apart on which platforms they offer contacts on.
bool get isContactImportSupported {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isAndroid;
}
```

In `lib/features/buddies/presentation/widgets/buddy_list_content.dart`, delete the private `_isContactImportSupported` getter at lines 80-83 (it has one use, at line 331), add the import for the new file, and replace the single use at line 331 with `isContactImportSupported`.

- [ ] **Step 4: Write the source sheet**

Create `lib/shared/widgets/profile_photo/profile_photo_source_sheet.dart`:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where a profile photo comes from.
enum ProfilePhotoSource { camera, library, contacts, remove }

/// Asks the user where the profile photo should come from.
///
/// Returns null if the sheet was dismissed without a choice.
Future<ProfilePhotoSource?> showProfilePhotoSourceSheet({
  required BuildContext context,
  required bool hasPhoto,
  required bool allowContacts,
}) {
  final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  return showModalBottomSheet<ProfilePhotoSource>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.profilePhoto_sheet_title,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            if (isMobile)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.profilePhoto_source_camera),
                onTap: () =>
                    Navigator.pop(sheetContext, ProfilePhotoSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                isMobile
                    ? l10n.profilePhoto_source_library
                    : l10n.profilePhoto_source_file,
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, ProfilePhotoSource.library),
            ),
            if (allowContacts)
              ListTile(
                leading: const Icon(Icons.contacts),
                title: Text(l10n.profilePhoto_source_contacts),
                onTap: () =>
                    Navigator.pop(sheetContext, ProfilePhotoSource.contacts),
              ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.profilePhoto_action_remove),
                onTap: () =>
                    Navigator.pop(sheetContext, ProfilePhotoSource.remove),
              ),
          ],
        ),
      );
    },
  );
}
```

- [ ] **Step 5: Write the orchestrator**

Create `lib/shared/widgets/profile_photo/profile_photo_picker.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_crop_dialog.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_source_sheet.dart';

/// Outcome of running the profile photo flow.
///
/// [removed] distinguishes "the user asked to delete the photo" from "the user
/// cancelled", which a bare `Uint8List?` cannot express.
@immutable
class ProfilePhotoResult {
  const ProfilePhotoResult({this.bytes, this.removed = false});

  final Uint8List? bytes;
  final bool removed;
}

/// Runs the whole flow: source sheet, byte acquisition, crop dialog, encode.
///
/// Returns null if the user cancelled at any point. Size bounding happens in
/// the crop dialog's encode step, never through ImagePicker's maxWidth /
/// maxHeight / imageQuality, which desktop silently ignores.
Future<ProfilePhotoResult?> pickProfilePhoto({
  required BuildContext context,
  required bool hasPhoto,
  required bool allowContacts,
  Future<Uint8List?> Function(BuildContext context)? contactPhotoLoader,
}) async {
  final source = await showProfilePhotoSourceSheet(
    context: context,
    hasPhoto: hasPhoto,
    allowContacts: allowContacts,
  );
  if (source == null || !context.mounted) return null;

  if (source == ProfilePhotoSource.remove) {
    return const ProfilePhotoResult(removed: true);
  }

  Uint8List? raw;
  String? declaredName;

  if (source == ProfilePhotoSource.contacts) {
    raw = await contactPhotoLoader?.call(context);
    declaredName = 'contact.jpg';
    if (raw == null) return null;
  } else {
    final picked = await ImagePicker().pickImage(
      source: source == ProfilePhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (picked == null) return null;
    raw = await File(picked.path).readAsBytes();
    declaredName = picked.name;
  }

  if (!context.mounted) return null;

  final encoded = await showProfilePhotoCropDialog(
    context: context,
    sourceBytes: raw,
    declaredName: declaredName,
  );
  if (encoded == null) return null;
  return ProfilePhotoResult(bytes: encoded);
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/shared/widgets/profile_photo/profile_photo_source_sheet_test.dart`
Expected: PASS, all five tests.

- [ ] **Step 7: Verify the extracted guard did not break the buddy list**

Run: `flutter test test/features/buddies`
Expected: PASS except possibly `buddy_list_tile_test.dart`, which Task 11 rewrites.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/shared/utils/contact_import_support.dart lib/shared/widgets/profile_photo lib/features/buddies/presentation/widgets/buddy_list_content.dart test/shared/widgets/profile_photo/profile_photo_source_sheet_test.dart
git commit -m "feat(profile-photo): add the source sheet and picker orchestration"
```

---

## Task 10: The ProfileAvatar widget

**Files:**
- Create: `lib/shared/widgets/profile_photo/profile_avatar.dart`
- Test: `test/shared/widgets/profile_photo/profile_avatar_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `class ProfileAvatar extends StatelessWidget` with `const ProfileAvatar({Key? key, required Uint8List? photo, required String initials, double radius = 20, Color? backgroundColor, Color? foregroundColor, Color? ringColor, TextStyle? textStyle})`. Note `photo` is `required` but nullable, so no call site can forget to pass it, and `textStyle` exists because two sites (buddy detail and buddy edit) render initials at 36pt.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/profile_photo/profile_avatar_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../helpers/test_app.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

void main() {
  testWidgets('falls back to initials when there is no photo', (tester) async {
    await tester.pumpWidget(
      testApp(child: const ProfileAvatar(photo: null, initials: 'JD')),
    );
    await tester.pump();

    expect(find.text('JD'), findsOneWidget);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
  });

  testWidgets('renders the photo and hides initials when present',
      (tester) async {
    await tester.pumpWidget(
      testApp(child: ProfileAvatar(photo: _jpeg(), initials: 'JD')),
    );
    await tester.pump();

    expect(find.text('JD'), findsNothing);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNotNull);
  });

  testWidgets('decodes through ResizeImage, not a bare MemoryImage',
      (tester) async {
    await tester.pumpWidget(
      testApp(child: ProfileAvatar(photo: _jpeg(), initials: 'JD', radius: 20)),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      avatar.backgroundImage,
      isA<ResizeImage>(),
      reason: 'a bare MemoryImage decodes at intrinsic size, so a list of '
          'avatars would hold megabytes of bitmaps each',
    );
  });

  testWidgets('draws a ring when ringColor is given', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const ProfileAvatar(
          photo: null,
          initials: 'JD',
          ringColor: Color(0xFF00FF00),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Container), findsWidgets);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/widgets/profile_photo/profile_avatar_test.dart`
Expected: FAIL, URI does not exist.

- [ ] **Step 3: Write the widget**

Create `lib/shared/widgets/profile_photo/profile_avatar.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// One avatar for divers and buddies: the stored photo when there is one,
/// their initials otherwise.
///
/// Replaces 13 hand-rolled CircleAvatar sites that each re-implemented the
/// initials fallback, two of which had drifted into disagreeing about how a
/// photo is even loaded.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photo,
    required this.initials,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.ringColor,
    this.textStyle,
  });

  /// The stored 512x512 square JPEG, or null to show [initials].
  ///
  /// Pass the SAME Uint8List instance the repository handed you. MemoryImage
  /// equality is identity-based on the byte list and that is what keys
  /// Flutter's image cache, so a defensive copy would mint a fresh cache key
  /// every rebuild and re-decode every avatar on every frame.
  final Uint8List? photo;

  final String initials;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Draws a coloured ring around the avatar (the buddy list uses this for
  /// the usual-role indicator).
  final Color? ringColor;

  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = photo;

    // Decode at the size actually drawn. Flutter decodes to the image's
    // INTRINSIC size, so a bare MemoryImage on a 512x512 JPEG holds about 1 MB
    // of bitmap for a 40 logical pixel tile; a list of 200 buddies would hold
    // roughly 200 MB.
    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final target = (radius * 2 * devicePixelRatio).round().clamp(1, 512);

    final avatar = CircleAvatar(
      radius: ringColor == null ? radius : radius - 2,
      backgroundColor: backgroundColor ?? theme.colorScheme.primaryContainer,
      foregroundColor:
          foregroundColor ?? theme.colorScheme.onPrimaryContainer,
      backgroundImage: bytes == null
          ? null
          : ResizeImage(
              MemoryImage(bytes),
              width: target,
              height: target,
            ),
      child: bytes == null
          ? Text(
              initials,
              style: textStyle ??
                  TextStyle(
                    color: foregroundColor ??
                        theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            )
          : null,
    );

    if (ringColor == null) return avatar;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: 2),
      ),
      child: avatar,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/shared/widgets/profile_photo/profile_avatar_test.dart`
Expected: PASS, all four tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/shared/widgets/profile_photo/profile_avatar.dart test/shared/widgets/profile_photo/profile_avatar_test.dart
git commit -m "feat(profile-photo): add the shared ProfileAvatar widget"
```

---

## Task 11: Roll ProfileAvatar out to existing sites

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_summary_widget.dart` (line 177)
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_tile.dart` (lines 293-321)
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart` (lines 232, 413)
- Modify: `lib/features/buddies/presentation/widgets/buddy_picker.dart` (lines 201, 264, 615)
- Modify: `lib/features/divers/presentation/widgets/diver_switcher_sheet.dart` (line 55)
- Modify: `lib/features/divers/presentation/widgets/diver_summary_widget.dart` (lines 195, 281)
- Modify: `lib/features/settings/presentation/pages/diver_profile_hub_page.dart` (line 130)
- Test: `test/features/buddies/presentation/widgets/buddy_list_tile_test.dart` (rewrite the photo test)

**Interfaces:**
- Consumes: `ProfileAvatar` (Task 10), `Buddy.photo` / `Diver.photo` (Task 2).
- Produces: no new API. Every avatar site now renders the stored photo.

- [ ] **Step 1: Rewrite the failing photo test**

In `test/features/buddies/presentation/widgets/buddy_list_tile_test.dart`:

Change the `_buddy` helper's `String? photoPath` parameter to `Uint8List? photo` and pass `photo: photo` to the `Buddy(...)` constructor instead of `photoPath: photoPath`. Add `import 'dart:typed_data';` and `import 'package:image/image.dart' as img;`, and remove `import 'dart:io';` if nothing else in the file uses it.

Replace the whole `'loads an existing photo file and falls back to initials'` test with:

```dart
  testWidgets('renders the stored photo and falls back to initials', (
    tester,
  ) async {
    final image = img.Image(width: 64, height: 64);
    img.fill(image, color: img.ColorRgb8(10, 20, 30));
    final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 80));

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(buddy: _buddy(photo: bytes), diveCount: 1),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<ResizeImage>());
    expect(find.text('JD'), findsNothing);

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(buddy: _buddy(), diveCount: 1),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('JD'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_list_tile_test.dart`
Expected: FAIL. `backgroundImage` is a `FileImage` built from `photoPath`, not a `ResizeImage`.

- [ ] **Step 3: Replace the buddy list tile avatar**

In `lib/features/buddies/presentation/widgets/buddy_list_tile.dart`, replace the whole `build` body of the avatar widget (lines 292-321, starting at `final path = buddy.photoPath;`) with:

```dart
  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      photo: buddy.photo,
      initials: buddy.initials,
      radius: 20,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      ringColor: ringColor,
    );
  }
```

Add `import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';` and remove the now-unused `dart:io` import.

- [ ] **Step 4: Replace the buddy detail page avatars**

In `lib/features/buddies/presentation/pages/buddy_detail_page.dart`:

At line 413, replace the whole `CircleAvatar(...)` (including its `backgroundImage: buddy.photoPath != null ? AssetImage(buddy.photoPath!) : null` and its `child:` ternary) with:

```dart
          ProfileAvatar(
            photo: buddy.photo,
            initials: buddy.initials,
            radius: 50,
            textStyle: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
```

At line 232, replace that `CircleAvatar` with an equivalent `ProfileAvatar`, keeping whatever `radius` and colours it already passes and adding `photo: buddy.photo, initials: buddy.initials`.

Add the `ProfileAvatar` import.

- [ ] **Step 5: Replace the remaining nine sites**

For each of these, replace the `CircleAvatar(...)` with `ProfileAvatar(...)`, keeping the existing `radius`, `backgroundColor`, and `foregroundColor` arguments, replacing `child: Text(x.initials)` with `initials: x.initials`, and adding `photo: x.photo`:

- `lib/features/buddies/presentation/widgets/buddy_summary_widget.dart:177`
- `lib/features/buddies/presentation/widgets/buddy_picker.dart:201`, `:264`, `:615`
- `lib/features/divers/presentation/widgets/diver_switcher_sheet.dart:55`
- `lib/features/divers/presentation/widgets/diver_summary_widget.dart:195`, `:281`
- `lib/features/settings/presentation/pages/diver_profile_hub_page.dart:130`

Add the `ProfileAvatar` import to each file. Leave `buddy_edit_page.dart` alone: Task 12 rewrites it.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_list_tile_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the buddy, diver, and settings suites**

Run:
```bash
flutter test test/features/buddies test/features/divers test/features/settings
```
Expected: PASS. Fix any test that asserted on the old `CircleAvatar` internals by asserting on `ProfileAvatar` instead.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/buddies lib/features/divers lib/features/settings test/features/buddies
git commit -m "refactor(avatars): render diver and buddy photos through ProfileAvatar"
```

---

## Task 12: Edit page entry points

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart` (lines 305-355, 701)
- Modify: `lib/features/settings/presentation/pages/diver_profile_hub_page.dart` (the active diver card)
- Modify: all 11 ARB files (remove `buddies_label_photoComingSoon`)
- Test: `test/features/buddies/presentation/pages/buddy_edit_photo_test.dart` (create)

**Interfaces:**
- Consumes: `pickProfilePhoto` (Task 9), `ProfileAvatar` (Task 10), `Buddy.photo` (Task 2).
- Produces: `BuddyEditPage` gains an `initialPhoto` field on its form state, consumed by Task 14.

- [ ] **Step 1: Write the failing test**

Create `test/features/buddies/presentation/pages/buddy_edit_photo_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('the edit page shows a tappable ProfileAvatar, not a stub', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        child: const BuddyEditPage(),
      ),
    );
    await tester.pump();

    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(find.textContaining('coming'), findsNothing);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/buddies/presentation/pages/buddy_edit_photo_test.dart`
Expected: FAIL. The page renders a `CircleAvatar` stub and the "coming soon" text.

- [ ] **Step 3: Add photo state to the edit page**

In `lib/features/buddies/presentation/pages/buddy_edit_page.dart`, add a field beside the other form state:

```dart
  Uint8List? _photo;
```

Add `import 'dart:typed_data';`. Wherever the page seeds form state from `_originalBuddy` (the same place it currently reads `photoPath`), add `_photo = _originalBuddy?.photo;`. If the widget accepts prefill parameters, add `this.initialPhoto` to its constructor and seed `_photo = widget.initialPhoto ?? _originalBuddy?.photo;`.

- [ ] **Step 4: Replace the stub with a real control**

Replace the whole `Center(child: Stack(...))` photo placeholder block (lines 306-343) plus the `photoComingSoon` `Center(child: Text(...))` that follows it with:

```dart
            Center(
              child: GestureDetector(
                onTap: () async {
                  final result = await pickProfilePhoto(
                    context: context,
                    hasPhoto: _photo != null,
                    allowContacts: isContactImportSupported,
                  );
                  if (result == null || !mounted) return;
                  setState(() {
                    _photo = result.removed ? null : result.bytes;
                    _hasChanges = true;
                  });
                },
                child: Stack(
                  children: [
                    ProfileAvatar(
                      photo: _photo,
                      initials: _nameController.text.isNotEmpty
                          ? _getInitials(_nameController.text)
                          : '?',
                      radius: 50,
                      textStyle: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: ExcludeSemantics(
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
```

Add these imports:
```dart
import 'package:submersion/shared/utils/contact_import_support.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_picker.dart';
```

At line 701, where the saved `Buddy` is constructed, add `photo: _photo,` beside the existing `photoPath:` line.

- [ ] **Step 5: Make the diver profile hub card tappable**

In `lib/features/settings/presentation/pages/diver_profile_hub_page.dart`, wrap the `ProfileAvatar` in `_buildActiveDiverCard` in a `GestureDetector` whose `onTap` runs `pickProfilePhoto(context: context, hasPhoto: diver.photo != null, allowContacts: false)` and, on a non-null result, calls the diver repository's update with `diver.copyWith(photo: result.removed ? null : result.bytes)`. Use whichever provider or notifier the surrounding page already uses to persist a diver edit; do not add a new one.

Note `allowContacts: false`: contacts hold buddies, not the logged-in diver.

- [ ] **Step 6: Remove the dead string from all 11 locales**

Delete the `"buddies_label_photoComingSoon": ...` line from `app_en.arb` and from all 10 other locale files.

Run: `flutter gen-l10n`

- [ ] **Step 7: Run the tests to verify they pass**

Run:
```bash
flutter test test/features/buddies/presentation/pages/buddy_edit_photo_test.dart test/l10n/arb_parity_test.dart
```
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/buddies/presentation/pages/buddy_edit_page.dart lib/features/settings/presentation/pages/diver_profile_hub_page.dart lib/l10n/arb test/features/buddies/presentation/pages/buddy_edit_photo_test.dart
git commit -m "feat(profile-photo): set diver and buddy photos from the edit screens"
```

---

## Task 13: Table view leading avatars

**Files:**
- Modify: `lib/shared/widgets/entity_table/entity_table_view.dart`
- Modify: the buddy and diver table hosts (found in Step 3)
- Test: `test/shared/widgets/entity_table/entity_table_leading_test.dart` (create)

**Interfaces:**
- Consumes: `ProfileAvatar` (Task 10).
- Produces: `EntityTableView` gains `final Widget Function(T entity)? leadingBuilder`, defaulting to null so every existing table is unchanged.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/entity_table/entity_table_leading_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/app_settings.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

import '../../../helpers/test_app.dart';

BuddyWithDiveCount _entry() => BuddyWithDiveCount(
  buddy: Buddy(
    id: 'b1',
    name: 'Jane Doe',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  diveCount: 3,
);

Widget _table({Widget Function(BuddyWithDiveCount entity)? leadingBuilder}) {
  return EntityTableView<BuddyWithDiveCount, BuddyField>(
    entities: [_entry()],
    idExtractor: (e) => e.buddy.id,
    adapter: BuddyFieldAdapter.instance,
    config: EntityTableViewConfig<BuddyField>(
      columns: [EntityTableColumnConfig(field: BuddyField.buddyName)],
    ),
    units: const UnitFormatter(AppSettings()),
    onSortFieldChanged: (_) {},
    onResizeColumn: (_, __) {},
    onEntityTap: (_) {},
    leadingBuilder: leadingBuilder,
  );
}

void main() {
  testWidgets('renders no leading widget when leadingBuilder is null', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(child: _table()));
    await tester.pump();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byKey(const ValueKey('lead')), findsNothing);
  });

  testWidgets('renders one leading widget per row when given a builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: _table(
          leadingBuilder: (_) =>
              const Icon(Icons.person, key: ValueKey('lead')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byKey(const ValueKey('lead')), findsOneWidget);
  });
}
```

If `AppSettings` lives at a different path, find it with `grep -rn "class AppSettings" lib/` and correct the import. Do not construct a settings object any other way.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/widgets/entity_table/entity_table_leading_test.dart`
Expected: FAIL, "No named parameter with the name 'leadingBuilder'".

- [ ] **Step 3: Add the hook**

In `lib/shared/widgets/entity_table/entity_table_view.dart`:

Add to the widget's fields and constructor:

```dart
  /// Optional widget rendered at the start of each row, before the first
  /// column. Null for every table that does not opt in, so existing tables
  /// are unchanged. Used for profile photos, which are not a sortable text
  /// value and therefore do not belong in the field enum.
  final Widget Function(T entity)? leadingBuilder;
```

In `_buildCell` or the row builder that composes cells (around line 214), prepend the leading widget to the row's children when `widget.leadingBuilder != null`, with an 8 logical pixel gap after it.

- [ ] **Step 4: Wire the buddy and diver tables**

Find the table hosts:

```bash
grep -rn "EntityTableView" lib/features/buddies lib/features/divers
```

For each, pass:

```dart
        leadingBuilder: (entry) => ProfileAvatar(
          photo: entry.buddy.photo,
          initials: entry.buddy.initials,
          radius: 14,
        ),
```

adjusting `entry.buddy` to whatever the entity type actually is. Add the `ProfileAvatar` import.

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```bash
flutter test test/shared/widgets/entity_table test/features/buddies test/features/divers
```
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/shared/widgets/entity_table lib/features/buddies lib/features/divers test/shared/widgets/entity_table
git commit -m "feat(tables): show profile photos in buddy and diver table rows"
```

---

## Task 14: Contact photos and the master-detail fix

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart` (`_importFromContacts` at 330, `FlutterContacts.get` at 365, master-detail branch at 386)
- Modify: `lib/core/router/app_router.dart` (the `newBuddy` route builder, around line 599, `initialName:` at 609)
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart` (constructor)
- Test: `test/features/buddies/presentation/widgets/buddy_contact_import_test.dart` (create)

**Interfaces:**
- Consumes: `encodeStoredImage` / `ImageEncodeSpec.avatar` (Task 5), `BuddyEditPage.initialPhoto` (Task 12).
- Produces: contact photos reaching the new-buddy form; no new public API.

- [ ] **Step 1: Write the failing test**

Create `test/features/buddies/presentation/widgets/buddy_contact_import_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets(
    'the new-buddy route carries name, email, phone and photo through extra',
    (tester) async {
      late GoRouter router;
      router = GoRouter(
        initialLocation: '/buddies',
        routes: [
          GoRoute(
            path: '/buddies',
            builder: (context, state) => ElevatedButton(
              onPressed: () => context.push(
                '/buddies/new',
                extra: {
                  'name': 'Jane Doe',
                  'email': 'jane@example.com',
                  'phone': '+1 555 0100',
                  'photo': null,
                },
              ),
              child: const Text('import'),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return BuddyEditPage(
                    initialName: extra?['name'] as String?,
                    initialEmail: extra?['email'] as String?,
                    initialPhone: extra?['phone'] as String?,
                  );
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        testAppRouter(router: router, locale: const Locale('en')),
      );
      await tester.pump();

      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();

      expect(find.text('Jane Doe'), findsOneWidget);
    },
  );
}
```

This test is a guard on the route contract. The master-detail branch removal is verified by Step 4's code reading, because `_importFromContacts` needs a live address book and cannot be driven from a widget test.

- [ ] **Step 2: Run the test to verify it fails or passes**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_contact_import_test.dart`
Expected: FAIL if `BuddyEditPage` does not yet accept `initialName`; PASS if Task 12 already added it. If it passes, that is fine: it is a regression guard, and the real change is Steps 3 and 4.

- [ ] **Step 3: Fetch the contact photo**

In `lib/features/buddies/presentation/widgets/buddy_list_content.dart`, replace the `FlutterContacts.get(contactId)` call (line 365) with:

```dart
      final fullContact = await FlutterContacts.get(
        contactId,
        properties: {
          ContactProperty.name,
          ContactProperty.email,
          ContactProperty.phone,
          ContactProperty.photoFullRes,
          ContactProperty.photoThumbnail,
        },
      );
```

After the existing `name`, `email`, and `phone` extraction, add:

```dart
      // Full resolution first: the thumbnail is only 96x96 or 150x150, which
      // is a fallback, not a preference. Centered automatically with no crop
      // dialog, because the user is mid-import and did not ask to frame a
      // photo; they can adjust it afterwards from the edit page.
      final rawPhoto =
          fullContact.photo?.fullSize ?? fullContact.photo?.thumbnail;
      Uint8List? photo;
      if (rawPhoto != null) {
        final encoded = await encodeStoredImage(
          ImageEncodeRequest.fromBytes(
            bytes: rawPhoto,
            spec: ImageEncodeSpec.avatar,
            declaredName: 'contact.jpg',
          ),
        );
        if (encoded.outcome == ImageEncodeOutcome.encoded) {
          photo = encoded.bytes;
        }
      }
```

Add `import 'dart:typed_data';` and `import 'package:submersion/core/services/images/profile_photo_codec.dart';`.

- [ ] **Step 4: Delete the master-detail branch**

Replace the whole `if (ResponsiveBreakpoints.isMasterDetail(context)) { ... } else { ... }` block inside `_importFromContacts` (starts line 386) with the code below. Note there is a SECOND `isMasterDetail` at line 888 that belongs to a different flow: leave it alone.

```dart
      if (context.mounted) {
        // One push for every layout. `/buddies/new` declares
        // parentNavigatorKey: rootNavigatorKey so it renders in the
        // foreground rather than under the shell, which is why the old
        // master-detail special case was not just buggy (it carried no data,
        // so an iPad in landscape landed on a blank form) but unnecessary.
        context.push(
          '/buddies/new',
          extra: {
            'name': name,
            'email': email,
            'phone': phone,
            'photo': photo,
          },
        );
      }
```

Remove the now-unused `ResponsiveBreakpoints` and `GoRouterState` imports if nothing else in the file uses them.

- [ ] **Step 5: Carry the photo through the route**

In `lib/core/router/app_router.dart`, in the `newBuddy` route builder (the `initialName:` line at 609), add:

```dart
                    initialPhoto: extra?['photo'] as Uint8List?,
```

Add `import 'dart:typed_data';`.

In `lib/features/buddies/presentation/pages/buddy_edit_page.dart`, add `final Uint8List? initialPhoto;` and `this.initialPhoto,` to the constructor if Task 12 did not already.

- [ ] **Step 6: Wire the contacts source in the picker**

In `lib/features/buddies/presentation/pages/buddy_edit_page.dart`, pass a `contactPhotoLoader` to the `pickProfilePhoto` call added in Task 12. The loader opens the same permission check and native picker, requests only the two photo properties, and returns the raw bytes:

```dart
                    contactPhotoLoader: (context) async {
                      if (!await FlutterContacts.permissions
                          .has(PermissionType.read)) {
                        await FlutterContacts.permissions
                            .request(PermissionType.read);
                        if (!await FlutterContacts.permissions
                            .has(PermissionType.read)) {
                          return null;
                        }
                      }
                      final id =
                          (await FlutterContacts.native.showPicker())?.trim();
                      if (id == null || id.isEmpty) return null;
                      final contact = await FlutterContacts.get(
                        id,
                        properties: {
                          ContactProperty.photoFullRes,
                          ContactProperty.photoThumbnail,
                        },
                      );
                      final bytes = contact?.photo?.fullSize ??
                          contact?.photo?.thumbnail;
                      if (bytes == null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.profilePhoto_error_contactNoPhoto,
                            ),
                          ),
                        );
                      }
                      return bytes;
                    },
```

- [ ] **Step 7: Run the tests to verify they pass**

Run:
```bash
flutter test test/features/buddies
```
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/buddies lib/core/router/app_router.dart test/features/buddies/presentation/widgets/buddy_contact_import_test.dart
git commit -m "feat(buddies): import contact photos and fix master-detail data loss"
```

---

## Task 15: Certification photo reroute

**Files:**
- Modify: `lib/features/certifications/presentation/pages/certification_edit_page.dart` (`_pickPhoto` at 175, `pickImage` block at 201-212)
- Test: `test/features/certifications/certification_photo_bound_test.dart` (create)

**Interfaces:**
- Consumes: `encodeStoredImage` / `ImageEncodeSpec.certificationCard` (Task 5).
- Produces: certification card photos bounded at 2000px on every platform.

- [ ] **Step 1: Write the failing test**

Create `test/features/certifications/certification_photo_bound_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/services/images/profile_photo_codec.dart';

/// Guards the contract certification photos rely on: the cap is enforced in
/// Dart, not by ImagePicker's maxWidth / maxHeight / imageQuality, which
/// image_picker_macos, image_picker_windows and image_picker_linux silently
/// ignore.
void main() {
  test('an oversized card photo is bounded to 2000px on any platform', () {
    final source = img.Image(width: 6000, height: 4000);
    img.fill(source, color: img.ColorRgb8(200, 200, 200));
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 90));

    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: bytes,
        spec: ImageEncodeSpec.certificationCard,
        declaredName: 'card.jpg',
      ),
    );

    expect(result.outcome, ImageEncodeOutcome.encoded);
    final out = img.decodeImage(result.bytes!)!;
    expect(out.width, 2000);
    expect(out.height, 1333, reason: 'aspect ratio must be preserved');
  });

  test('a card photo is not cropped to a square', () {
    final source = img.Image(width: 1000, height: 600);
    img.fill(source, color: img.ColorRgb8(200, 200, 200));
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 90));

    final result = runImageEncodeRequest(
      ImageEncodeRequest.fromBytes(
        bytes: bytes,
        spec: ImageEncodeSpec.certificationCard,
        declaredName: 'card.jpg',
      ),
    );

    final out = img.decodeImage(result.bytes!)!;
    expect(out.width, 1000);
    expect(out.height, 600);
  });
}
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `flutter test test/features/certifications/certification_photo_bound_test.dart`
Expected: PASS. This test guards the codec spec, which Task 5 already built. If `expect(out.height, 1333)` fails by one pixel, adjust the expectation to the value `copyResize` actually produces and note it in the test.

- [ ] **Step 3: Reroute the picker**

In `lib/features/certifications/presentation/pages/certification_edit_page.dart`, replace the `pickImage` call and the byte read inside `_pickPhoto` (lines 201-212, from `final picked = await _imagePicker.pickImage(` through `return await file.readAsBytes();`) with:

```dart
      // No maxWidth / maxHeight / imageQuality here: image_picker_macos,
      // image_picker_windows and image_picker_linux silently ignore them, so
      // a desktop pick entered the database at full size and rode into every
      // sync changeset as base64. The cap is enforced below instead.
      final picked = await _imagePicker.pickImage(source: source);

      if (picked == null) return null;

      final raw = await File(picked.path).readAsBytes();
      final encoded = await encodeStoredImage(
        ImageEncodeRequest.fromBytes(
          bytes: raw,
          spec: ImageEncodeSpec.certificationCard,
          declaredName: picked.name,
        ),
      );
      if (encoded.outcome != ImageEncodeOutcome.encoded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                encoded.outcome == ImageEncodeOutcome.tooLarge
                    ? context.l10n.profilePhoto_error_tooLarge
                    : context.l10n.profilePhoto_error_undecodable,
              ),
            ),
          );
        }
        return null;
      }
      return encoded.bytes;
```

Add `import 'package:submersion/core/services/images/profile_photo_codec.dart';`.

- [ ] **Step 4: Run the certification suite**

Run: `flutter test test/features/certifications`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze --fatal-infos
git add lib/features/certifications test/features/certifications/certification_photo_bound_test.dart
git commit -m "fix(certifications): bound card photo size on desktop"
```

---

## Task 16: Full verification

**Files:** none modified unless a failure requires it.

- [ ] **Step 1: Regenerate everything**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-photos
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

- [ ] **Step 2: Format and analyze the whole project**

```bash
dart format .
flutter analyze --fatal-infos
```
Expected: no issues. Analyze the WHOLE project, not just changed files: CI does, and info-level diagnostics are fatal.

- [ ] **Step 3: Run the full suite once**

Run: `flutter test`
Expected: PASS. Do not pipe through `grep`: the pipeline returns grep's exit status and a failing suite would read as success.

If a test fails that is listed in the repo's known-flaky index, rerun that one file alone before treating it as real. Do not run overlapping test processes: a concurrent run makes a passing test look like a lone failure.

- [ ] **Step 4: Confirm the schema rung is still uncontested**

```bash
git fetch origin main
git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "
```
Expected: still 180. If main has advanced to 181 or beyond, renumber this branch's rung above it in `database.dart` (the ladder `if (from < N)`, the `migrationVersions` entry, `currentSchemaVersion`) and in `migration_v181_profile_photo_test.dart`, then rerun Step 3.

- [ ] **Step 5: Commit any fixes**

```bash
dart format .
git add <only the specific files you changed>
git commit -m "chore: full-suite verification fixes"
```

Never `git add -A` or `git add -u`: sibling worktrees share this checkout.

---

## Deferred, to be filed as issues

These are deliberately out of scope. File them rather than building them:

1. **PDF export** does not embed profile photos.
2. **Bulk address-book matching** of existing buddies to contacts.
3. **`Species.photoPath`** stays a path; species photos are reference data.
4. **Oversized existing certification photos** are not backfilled; only new picks are bounded.
5. **`image_resize_job.dart` never calls `img.bakeOrientation`**, so media-store thumbnails of EXIF-rotated photos render sideways. One-line fix, separate change, needs its own test.
