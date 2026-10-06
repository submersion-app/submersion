# Buddy Profile Dive Linking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a buddy be linked to a local diver profile, offer to log a saved dive into that profile as a linked planned sibling, give planned dives a lifecycle a diver can drive by hand, and fill a planned dive from a dive computer download.

**Architecture:** Two new columns (`buddies.linked_diver_id`, `dives.outing_id`) ride the existing schema-driven sync. New services (`BuddyProfileLinkRepository`, `DiveMirrorService`, `PlannedDiveFillService`, `PlannedDiveMatcher`) sit beside the existing repositories and reuse `dives.is_planned`, `convertPlanToActualDive`, `DiveMergeSnapshot`, and the attach-to-existing-dive branch of `importProfile` (which gains its missing `dive_data_sources` insert). UI work touches the buddy edit page, the dive edit and detail pages, the dive list, the add-dive sheet, the planner's convert path, and the import wizard's review and summary steps.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), go_router, mockito, gen-l10n ARB files (11 locales).

**Spec:** `docs/superpowers/specs/2026-09-15-buddy-profile-dive-linking-design.md`

**Issue:** #2002

**Executed note:** the rung was renumbered from 219 to **220** during Task 19, because equipment tags (#1942) shipped 219 while this branch was open. Read every "219" below as 220; the rung test is `migration_v220_buddy_profile_dive_links_test.dart`.

## Global Constraints

- Never write an em-dash or an en-dash used as punctuation, and never use ` -- ` or ` - ` as prose punctuation, anywhere: code, comments, docs, commit messages, PR text. Rewrite with commas, colons, semicolons or parentheses.
- No mention of Claude, Claude Code or Anthropic in any commit, trailer, PR or comment. No `Co-Authored-By` trailers.
- No emojis in code, comments or docs.
- Schema rung is written as **219** below. Four open PRs (#1964, #1978, #1980, #1860) also claim 219. Before opening the PR, rebase onto `origin/main`, read `currentSchemaVersion` there, and renumber every 219 in this branch (the constant, the `migrationVersions` entry and comment, the `if (from < 219)` block, the rung test file name and literals) to main's version plus one. `minimumCompatibleSchemaVersion` stays **210**: both columns are additive and nullable.
- Every new ARB key goes into all 11 files: `lib/l10n/arb/app_en.arb` (alphabetical, insert before the neighbouring key) and `app_ar/de/es/fr/he/hu/it/nl/pt/zh.arb` (feature-grouped, insert after an existing neighbouring key that `grep -n '"<key>"' lib/l10n/arb/app_*.arb` shows in all 11 files). Translate for real in every locale; never leave the English value in a non-English file. Run `flutter gen-l10n` only after all 11 files hold the key, and commit the regenerated `lib/l10n/arb/app_localizations*.dart` with the ARBs. Verify with `git diff --numstat -- lib/l10n/arb` that every ARB gained the same number of lines.
- Strings in widgets come from `context.l10n.<key>` (extension in `lib/l10n/l10n_extension.dart`).
- Stage explicit paths only. Never `git add -A` or `git add .`.
- Run `dart format .` (whole project) before every commit.
- Never pipe `flutter test` or `flutter analyze` into `grep`, `tail` or `head` when you need the pass/fail result: the pipe hides the exit status. Redirect to a file in the scratchpad and read the file if the output is long.
- A Bash command containing the bare word `build` is refused by a permission rule. The worktree is already initialized (submodules, pub get, codegen). If codegen is ever needed again, run `bash scripts/setup.sh`.
- The Bash tool runs zsh: `for f in $VAR` does not word-split. Use explicit paths or `bash -c` with an array.
- Lints that are fatal in CI: `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `require_trailing_commas`, `always_use_package_imports`. `flutter analyze` must report "No issues found!" for the whole project.
- After adding or changing any file under `lib/`, run `flutter test test/architecture/` before calling the task green. Any new repository member whose SQL reads `FROM dives` or `JOIN dives` must use `DiveStatsScope` or carry `// stats-scope-exempt: <reason>` (see `test/core/database/dive_stats_scope_census_test.dart`).
- Immutability: never mutate a list or entity in place; build new ones.
- Files stay under 800 lines; new files aim for 200 to 400. `buddy_repository.dart` (1230 lines) and `dive_repository_impl.dart` (7917 lines) are already over; add only thin members there and put logic in the new files named below.
- Commit messages: Conventional Commits (`feat(buddies): ...`), body explains why, last line `Refs #2002`.
- Worktree root (all paths below are relative to it): `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/buddy-submersion-dive-linking-18925d`
- Scratchpad (throwaway scripts and test output): `/private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion--claude-worktrees-buddy-submersion-dive-linking-18925d/eb308156-b724-490a-9959-ad03be7418c0/scratchpad`
- Test database helpers: `test/helpers/test_database.dart` (`setUpTestDatabase()` returns the `AppDatabase`, `tearDownTestDatabase()`), `test/helpers/mock_providers.dart` (`getBaseOverrides()`, `MockSettingsNotifier`), `test/helpers/test_app.dart` (`testApp`).

## File Map

**Create**
- `lib/features/buddies/data/repositories/buddy_profile_link_repository.dart`: `BuddyProfileLinkRepository` (link validation, suggestion lookup, reciprocal buddy), `BuddyLinkRefused`.
- `lib/features/buddies/presentation/providers/buddy_profile_link_providers.dart`: `buddyProfileLinkRepositoryProvider`, `linkedProfileSuggestionProvider`.
- `lib/features/buddies/presentation/widgets/linked_profile_field.dart`: `LinkedProfileField` (picker row) and `showLinkedProfilePicker`.
- `lib/features/buddies/presentation/widgets/linked_profile_suggestion.dart`: `LinkedProfileSuggestion` (inline prompt).
- `lib/features/dive_log/domain/services/dive_mirror_fields.dart`: `mirroredDiveFrom`, `kMirroredDiveFields`, `kUnmirroredDiveFields`.
- `lib/features/dive_log/data/services/dive_mirror_service.dart`: `DiveMirrorService`, `MirrorCandidate`, `MirrorOutcome`.
- `lib/features/dive_log/presentation/providers/dive_mirror_providers.dart`: `diveMirrorServiceProvider`, `siblingDivesProvider`, `mirrorCandidatesProvider`.
- `lib/features/dive_log/presentation/widgets/mirror_dive_dialog.dart`: `showMirrorDiveDialog`, `runDiveMirror`.
- `lib/features/dive_log/presentation/widgets/logged_with_tiles.dart`: `LoggedWithTiles`.
- `lib/features/dive_log/presentation/widgets/planned_dive_banner.dart`: `PlannedDiveBanner`.
- `lib/features/dive_computer/domain/services/planned_dive_matcher.dart`: `PlannedDiveMatcher`.
- `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart`: `kMeasuredDiveFields`, `kHumanDiveFields`.
- `lib/features/dive_computer/data/services/planned_dive_fill_service.dart`: `PlannedDiveFillService`, `PlannedDiveFillOutcome`.
- `lib/features/import_wizard/presentation/widgets/planned_dive_picker_sheet.dart`: `showPlannedDivePicker`.
- Tests: `test/core/database/migration_v219_buddy_profile_dive_links_test.dart`, `test/features/buddies/domain/entities/buddy_linked_diver_test.dart`, `test/features/buddies/data/repositories/buddy_repository_linked_diver_test.dart`, `test/features/buddies/data/repositories/buddy_profile_link_repository_test.dart`, `test/features/buddies/data/repositories/buddy_merge_linked_diver_test.dart`, `test/features/divers/data/repositories/diver_merge_linked_buddy_test.dart`, `test/features/buddies/presentation/pages/buddy_edit_linked_profile_test.dart`, `test/features/buddies/presentation/widgets/buddy_list_tile_profile_chip_test.dart`, `test/features/dive_log/domain/entities/dive_outing_id_test.dart`, `test/features/dive_log/data/repositories/dive_repository_outing_test.dart`, `test/core/services/sync/sync_outing_and_linked_diver_test.dart`, `test/features/dive_log/data/repositories/dive_repository_planned_lifecycle_test.dart`, `test/features/dive_log/presentation/providers/dive_providers_planned_numbering_test.dart`, `test/features/dive_log/presentation/pages/dive_edit_planned_switch_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_planned_test.dart`, `test/features/dive_log/presentation/widgets/add_dive_bottom_sheet_plan_test.dart`, `test/features/dive_log/presentation/pages/dive_list_planned_chip_test.dart`, `test/features/dive_log/domain/services/dive_mirror_fields_test.dart`, `test/features/dive_log/data/services/dive_mirror_service_test.dart`, `test/features/dive_log/presentation/widgets/mirror_dive_dialog_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_logged_with_test.dart`, `test/features/dive_log/data/repositories/dive_computer_repository_existing_dive_source_test.dart`, `test/features/dive_computer/domain/services/planned_dive_matcher_test.dart`, `test/features/dive_computer/data/services/dive_import_service_planned_exclusion_test.dart`, `test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart`, `test/features/dive_computer/data/services/planned_dive_fill_service_test.dart`, `test/features/import_wizard/presentation/providers/import_wizard_fill_planned_test.dart`, `test/features/import_wizard/presentation/widgets/planned_dive_picker_sheet_test.dart`, `test/features/import_wizard/data/adapters/dive_computer_adapter_fill_planned_test.dart`, `test/features/import_wizard/presentation/widgets/import_summary_filled_test.dart`.

**Modify**
- `lib/core/database/database.dart` (two columns, v219 rung, beforeOpen backstop)
- `test/core/database/migration_v218_site_detail_sections_test.dart` (relax the exact-version tripwire)
- `lib/features/buddies/domain/entities/buddy.dart`, `lib/features/buddies/data/repositories/buddy_repository.dart`, `buddy_merge_repository.dart`
- `lib/features/divers/data/repositories/diver_merge_repository.dart` (repoint `linked_diver_id`)
- `lib/features/buddies/presentation/pages/buddy_edit_page.dart`, `buddy_detail_page.dart`, `widgets/buddy_list_tile.dart`
- `lib/features/dive_log/domain/entities/dive.dart`, `dive_summary.dart`, `dive_prefill.dart`
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (column round trip, `getDivesByOutingId`, `is_planned` in the summary SQL, `assignMissingDiveNumbers` gate)
- `lib/features/dive_log/presentation/providers/dive_providers.dart` (planned dives skip renumbering)
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, `widgets/edit_sections/the_dive_section.dart`, `pages/dive_detail_page.dart`, `pages/dive_list_page.dart`, `widgets/compact_dive_list_tile.dart`, `widgets/add_dive_bottom_sheet.dart`, `widgets/dive_list_content.dart`
- `lib/features/planner/presentation/pages/plan_canvas_page.dart` (convert through `createPlannedDive`)
- `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (existing-dive data-source insert, `is_planned = 0` in the fuzzy SQL and the containing-time SQL)
- `lib/features/dive_import/domain/services/dive_matcher.dart` (`plannedDiveId`)
- `lib/features/import_wizard/domain/models/duplicate_action.dart`, `import_bundle.dart` (`EntityGroup.copyWith`), `unified_import_result.dart` (`filledCount`, `fillOutcomes`)
- `lib/features/import_wizard/domain/adapters/import_source_adapter.dart`, `data/adapters/dive_computer_adapter.dart`
- `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`, `widgets/review_step.dart`, `widgets/duplicate_action_card.dart`, `widgets/entity_review_list.dart`, `widgets/import_summary_step.dart`
- `lib/core/presentation/widgets/dive_comparison_card.dart`
- `lib/l10n/arb/app_*.arb` (11 files) and generated `lib/l10n/arb/app_localizations*.dart`

## Shared interfaces (defined once, used across tasks)

```dart
// Buddy entity (Task 2)
class Buddy { final String? linkedDiverId; Buddy clearLinkedDiver(); }

// Dive entity (Task 3)
class Dive { final String? outingId; }

// Task 4
class BuddyLinkRefused implements Exception {
  final BuddyLinkRefusal reason;   // self, taken
  final Buddy? existingBuddy;      // set when reason == taken
}
class BuddyProfileLinkRepository {
  Future<void> assertLinkAllowed({required String? ownerDiverId, required String linkedDiverId, String? buddyId});
  Future<Diver?> suggestProfileFor({required String? ownerDiverId, required String name, String? email});
  Future<Buddy?> linkedBuddyFor({required String ownerDiverId, required String linkedDiverId});
  Future<Buddy> ensureReciprocalBuddy({required String ownerDiverId, required String linkedDiverId});
}

// Task 3 / Task 8
Future<List<Dive>> DiveRepository.getDivesByOutingId(String outingId);
Future<List<Dive>> DiveRepository.getPlannedDives({String? diverId});      // exists
Future<String> DiveRepository.convertPlanToActualDive(String planId, {DateTime? actualDateTime}); // exists

// Task 11
typedef MirrorCandidate = ({Buddy buddy, Diver diver});
class MirrorOutcome { final String outingId; final bool mintedOutingId; final List<String> createdDiveIds; final String sourceDiveId; }
class DiveMirrorService {
  Future<List<MirrorCandidate>> candidates(String diveId);
  Future<MirrorOutcome> mirror({required String sourceDiveId, required List<String> targetDiverIds});
  Future<void> undo(MirrorOutcome outcome);
}

// Task 15
class DiveMatchResult { final String? plannedDiveId; bool get isPlannedFill => plannedDiveId != null; }
class PlannedDiveMatcher { Map<int, String> pair({required List<DateTime> incomingStarts, required List<Dive> plannedDives}); }

// Task 17
class PlannedDiveFillOutcome { final String diveId; final DiveMergeSnapshot snapshot; final int? assignedDiveNumber; }
class PlannedDiveFillService {
  Future<PlannedDiveFillOutcome> fill({required String plannedDiveId, required DownloadedDive dive, required String computerId, String? descriptorVendor, String? descriptorProduct, int? descriptorModel, String? libdivecomputerVersion});
  Future<void> undo(PlannedDiveFillOutcome outcome);
}
```

---

### Task 1: Schema v219, two nullable columns

**Files:**
- Modify: `lib/core/database/database.dart` (Buddies table at 2283-2310, Dives table near 884, `currentSchemaVersion` at 4184, `migrationVersions` tail at 4784-4791, onUpgrade rungs at 12176-12188, beforeOpen backstop near 12547-12551, helper block near 6242)
- Modify: `test/core/database/migration_v218_site_detail_sections_test.dart:12-13`
- Test: `test/core/database/migration_v219_buddy_profile_dive_links_test.dart`

**Interfaces:**
- Produces: Drift columns `Buddies.linkedDiverId` (`String?`) and `Dives.outingId` (`String?`), generated into `BuddiesCompanion`, `Buddy` data class, `DivesCompanion`, `Dive` data class after codegen.

- [ ] **Step 1: Write the failing rung test**

```dart
// test/core/database/migration_v219_buddy_profile_dive_links_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v219 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 219);
    expect(AppDatabase.migrationVersions, contains(219));
  });

  test('the columns are additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('a fresh database has both columns, nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final buddyCols = await db
        .customSelect("PRAGMA table_info('buddies')")
        .get();
    final buddyByName = {for (final c in buddyCols) c.read<String>('name'): c};
    expect(buddyByName, contains('linked_diver_id'));
    expect(buddyByName['linked_diver_id']!.read<int>('notnull'), 0);

    final diveCols = await db.customSelect("PRAGMA table_info('dives')").get();
    final diveByName = {for (final c in diveCols) c.read<String>('name'): c};
    expect(diveByName, contains('outing_id'));
    expect(diveByName['outing_id']!.read<int>('notnull'), 0);
  });

  test('buddies.linked_diver_id references divers with ON DELETE SET NULL',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final fks = await db
        .customSelect("PRAGMA foreign_key_list('buddies')")
        .get();
    final link = fks.firstWhere(
      (r) => r.read<String>('from') == 'linked_diver_id',
    );
    expect(link.read<String>('table'), 'divers');
    expect(link.read<String>('on_delete'), 'SET NULL');
  });

  test('a v218 database upgrades to v219 with both columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 218');
        rawDb.execute('''
          CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)
        ''');
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT REFERENCES divers (id),
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            dive_date_time INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final buddyCols = await db
        .customSelect("PRAGMA table_info('buddies')")
        .get();
    expect(
      buddyCols.map((c) => c.read<String>('name')),
      contains('linked_diver_id'),
    );
    final diveCols = await db.customSelect("PRAGMA table_info('dives')").get();
    expect(diveCols.map((c) => c.read<String>('name')), contains('outing_id'));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 219);
  });

  test('the asserts are no-ops when the tables are absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v219_buddy_profile_dive_links_test.dart`
Expected: FAIL, the first test reports `Expected: <219> Actual: <218>` and the column tests fail on the missing columns.

- [ ] **Step 3: Add the columns**

In `class Buddies`, directly after `TextColumn get diverId => text().nullable().references(Divers, #id)();`:

```dart
  /// The local diver profile this buddy IS (issue #2002). Distinct from
  /// [diverId], which says whose contact list the buddy belongs to. Set NULL
  /// when that profile is deleted; repointed by the diver merge.
  TextColumn get linkedDiverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.setNull)();
```

In `class Dives`, directly after the `isPlanned` column (line 884-885):

```dart
  /// Shared id across the sibling dives created by one mirror action (issue
  /// #2002). Not a foreign key: a lone dive with an outing id is valid, and a
  /// group id written once per row never half-applies under sync.
  TextColumn get outingId => text().nullable()();
```

- [ ] **Step 4: Bump the version, add the rung, the helper and the backstop**

Change `static const int currentSchemaVersion = 218;` to `219`.

Append to `migrationVersions` after the `218,` entry:

```dart
    // v219: buddies.linked_diver_id (a buddy that IS a local profile) and
    // dives.outing_id (sibling dives mirrored from one save), issue #2002.
    // Additive nullable columns, no backfill, so the floor stays at 210.
    219,
```

Add the helper next to `_assertSiteDetailColumns` (near line 6242):

```dart
  /// v219: buddies.linked_diver_id and dives.outing_id (issue #2002).
  /// Idempotent, so it is safe from both onUpgrade and the beforeOpen
  /// backstop, and a no-op for either table when it does not exist yet.
  /// SQLite lets ADD COLUMN carry a REFERENCES clause only for a nullable
  /// column with no default, which this one is.
  Future<void> _assertBuddyProfileDiveLinkColumns() async {
    final buddyCols = await customSelect(
      "PRAGMA table_info('buddies')",
    ).get();
    if (buddyCols.isNotEmpty) {
      final names = buddyCols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('linked_diver_id')) {
        await customStatement(
          'ALTER TABLE buddies ADD COLUMN linked_diver_id TEXT '
          'REFERENCES divers (id) ON DELETE SET NULL',
        );
      }
    }
    final diveCols = await customSelect("PRAGMA table_info('dives')").get();
    if (diveCols.isNotEmpty) {
      final names = diveCols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('outing_id')) {
        await customStatement('ALTER TABLE dives ADD COLUMN outing_id TEXT');
      }
    }
  }
```

Add the rung directly after the v218 rung (after `if (from < 218) await reportProgress();`):

```dart
        // v219: buddy profile links and dive outings (issue #2002). Column-only
        // rung, no backfill: null reads back as "not linked" and "no siblings".
        if (from < 219) {
          await _assertBuddyProfileDiveLinkColumns();
        }
        if (from < 219) await reportProgress();
```

Add the backstop directly after the v218 backstop call `await _assertSiteDetailColumns();` in `beforeOpen` (this sits after `PRAGMA foreign_keys = ON`, which is fine for ADD COLUMN):

```dart
        // v219 backstop: re-assert the buddy link and outing columns. The
        // buddy and dive mappers read the whole row, so a database that
        // arrives by restore or sync-adopt without them would throw on the
        // first read.
        await _assertBuddyProfileDiveLinkColumns();
```

- [ ] **Step 5: Regenerate Drift code and relax the v218 tripwire**

Run: `bash scripts/setup.sh` (this is the permitted way to run codegen; it also re-runs pub get).

In `test/core/database/migration_v218_site_detail_sections_test.dart` replace lines 9-14 with:

```dart
  test('v218 is at or below the current schema version and in the ladder', () {
    // Relaxed once v219 (buddy profile dive links) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(218));
    expect(AppDatabase.migrationVersions, contains(218));
  });
```

Then grep the test tree for any other exact `218` version assertion and relax it the same way:

Run: `grep -rn "currentSchemaVersion, 218\|user_version'), 218" test/`

- [ ] **Step 6: Run the rung tests and the sync schema tests**

Run: `flutter test test/core/database/migration_v219_buddy_profile_dive_links_test.dart test/core/database/migration_v218_site_detail_sections_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/hlc_column_test.dart`
Expected: all PASS. The parent-refs test stays green because `divers` is deliberately excluded from `deletableParents`.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/core/database/database.dart test/core/database/migration_v219_buddy_profile_dive_links_test.dart test/core/database/migration_v218_site_detail_sections_test.dart
git commit -m "feat(db): schema v219, buddies.linked_diver_id and dives.outing_id

A buddy can name the local profile it is, and sibling dives mirrored
from one save share an outing id. Both columns are nullable and
additive, so the sync floor stays at 210.

Refs #2002"
```

---

### Task 2: Buddy entity and repository carry `linkedDiverId`

**Files:**
- Modify: `lib/features/buddies/domain/entities/buddy.dart` (fields 10-30, ctor 32-47, `copyWith` 97-129, `clearPhoto` 137-154, `props` 157-172)
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (`createBuddy` companion 180-193, `updateBuddy` companion 310-321, `_mapRowToBuddy` 1202-1220)
- Test: `test/features/buddies/domain/entities/buddy_linked_diver_test.dart`, `test/features/buddies/data/repositories/buddy_repository_linked_diver_test.dart`

**Interfaces:**
- Produces: `Buddy.linkedDiverId` (`String?`), `Buddy.copyWith(linkedDiverId:)`, `Buddy clearLinkedDiver()`. `BuddyRepository.createBuddy`, `updateBuddy` and every read path round-trip the column.

- [ ] **Step 1: Write the failing entity test**

```dart
// test/features/buddies/domain/entities/buddy_linked_diver_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';

void main() {
  final base = Buddy(
    id: 'b1',
    name: 'Chris',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('linkedDiverId defaults to null and is carried by copyWith', () {
    expect(base.linkedDiverId, isNull);
    final linked = base.copyWith(linkedDiverId: 'diver-chris');
    expect(linked.linkedDiverId, 'diver-chris');
    expect(linked.copyWith(name: 'C').linkedDiverId, 'diver-chris');
  });

  test('clearLinkedDiver removes the link and keeps everything else', () {
    final linked = base.copyWith(linkedDiverId: 'diver-chris', notes: 'n');
    final cleared = linked.clearLinkedDiver();
    expect(cleared.linkedDiverId, isNull);
    expect(cleared.notes, 'n');
    expect(cleared.id, 'b1');
  });

  test('linkedDiverId takes part in equality', () {
    expect(base.copyWith(linkedDiverId: 'x'), isNot(equals(base)));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/buddies/domain/entities/buddy_linked_diver_test.dart`
Expected: FAIL to compile, `linkedDiverId` is not defined.

- [ ] **Step 3: Add the field to the entity**

In `buddy.dart`:
- After `final String? diverId;` add:
  ```dart
  /// The local diver profile this buddy is (issue #2002). Null for a buddy
  /// with no profile on this library. Not the owner: that is [diverId].
  final String? linkedDiverId;
  ```
- In the constructor after `this.diverId,` add `this.linkedDiverId,`.
- In `copyWith` add the parameter `String? linkedDiverId,` and the assignment `linkedDiverId: linkedDiverId ?? this.linkedDiverId,`.
- In `clearPhoto()` add `linkedDiverId: linkedDiverId,` after `diverId: diverId,`.
- Add, directly after `clearPhoto()`:
  ```dart
  /// Create a copy with the profile link removed. [copyWith] keeps the
  /// current value on a null argument, so clearing needs its own method,
  /// as [clearPhoto] does for the photo.
  Buddy clearLinkedDiver() {
    return Buddy(
      id: id,
      diverId: diverId,
      linkedDiverId: null,
      name: name,
      email: email,
      phone: phone,
      certificationLevel: certificationLevel,
      certificationAgency: certificationAgency,
      certificationTitle: certificationTitle,
      photoPath: photoPath,
      photo: photo,
      notes: notes,
      isFavorite: isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
  ```
- In `props` add `linkedDiverId,` after `diverId,`.

- [ ] **Step 4: Run the entity test**

Run: `flutter test test/features/buddies/domain/entities/buddy_linked_diver_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing repository round-trip test**

```dart
// test/features/buddies/data/repositories/buddy_repository_linked_diver_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddies;
  late String ownerId;
  late String chrisId;

  setUp(() async {
    await setUpTestDatabase();
    buddies = BuddyRepository();
    final divers = DiverRepository();
    ownerId = (await divers.createDiver(
      Diver(
        id: '',
        name: 'Eric',
        isDefault: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    )).id;
    chrisId = (await divers.createDiver(
      Diver(
        id: '',
        name: 'Chris',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    )).id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Buddy buddy({String? linkedDiverId}) => Buddy(
    id: '',
    diverId: ownerId,
    linkedDiverId: linkedDiverId,
    name: 'Chris',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('createBuddy stores the link and getBuddyById reads it back', () async {
    final created = await buddies.createBuddy(buddy(linkedDiverId: chrisId));
    final read = await buddies.getBuddyById(created.id);
    expect(read?.linkedDiverId, chrisId);
  });

  test('updateBuddy writes the link and clearLinkedDiver removes it', () async {
    final created = await buddies.createBuddy(buddy());
    await buddies.updateBuddy(created.copyWith(linkedDiverId: chrisId));
    expect((await buddies.getBuddyById(created.id))?.linkedDiverId, chrisId);
    await buddies.updateBuddy(created.clearLinkedDiver());
    expect((await buddies.getBuddyById(created.id))?.linkedDiverId, isNull);
  });

  test('getAllBuddies carries the link', () async {
    await buddies.createBuddy(buddy(linkedDiverId: chrisId));
    final all = await buddies.getAllBuddies(diverId: ownerId);
    expect(all.single.linkedDiverId, chrisId);
  });
}
```

Check the exact names of `createDiver`, `getBuddyById` and `getAllBuddies` against the repositories before running; the buddy edit page test at `test/features/buddies/presentation/pages/buddy_edit_cert_fields_test.dart:26-50` shows the diver setup idiom.

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_repository_linked_diver_test.dart`
Expected: FAIL, `linkedDiverId` reads back null because the companions and mapper ignore it.

- [ ] **Step 7: Round-trip the column in the repository**

In `buddy_repository.dart`:
- `createBuddy` companion (line ~182): after `diverId: Value(buddy.diverId),` add `linkedDiverId: Value(buddy.linkedDiverId),`.
- `updateBuddy` companion (line ~311): same addition.
- `_mapRowToBuddy` (line ~1205): after `diverId: row.diverId,` add `linkedDiverId: row.linkedDiverId,`.

- [ ] **Step 8: Run the buddy tests**

Run: `flutter test test/features/buddies/data/repositories/buddy_repository_linked_diver_test.dart test/features/buddies/`
Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/features/buddies/domain/entities/buddy.dart lib/features/buddies/data/repositories/buddy_repository.dart test/features/buddies/domain/entities/buddy_linked_diver_test.dart test/features/buddies/data/repositories/buddy_repository_linked_diver_test.dart
git commit -m "feat(buddies): carry linkedDiverId on the Buddy entity

Refs #2002"
```

---

### Task 3: Dive entity and repository carry `outingId`, plus `getDivesByOutingId`

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (field near 175, ctor near 280, `copyWith` near 685 and 782, `props` near 882)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`createDive` companion near 1531, `updateDive` companion near 1825, `_mapRowToDiveWithPreloadedData` near 3962, `_mapRowToDive` near 4383, new `getDivesByOutingId` next to `getDivesForSite` at 2708)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:5151` (carry-through)
- Test: `test/features/dive_log/domain/entities/dive_outing_id_test.dart`, `test/features/dive_log/data/repositories/dive_repository_outing_test.dart`, `test/core/services/sync/sync_outing_and_linked_diver_test.dart`

**Interfaces:**
- Produces: `Dive.outingId` (`String?`, `copyWith(outingId:)`), `Future<List<domain.Dive>> DiveRepository.getDivesByOutingId(String outingId)`.

- [ ] **Step 1: Write the failing entity test**

```dart
// test/features/dive_log/domain/entities/dive_outing_id_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  final base = Dive(id: 'd1', dateTime: DateTime(2026, 6, 1, 9));

  test('outingId defaults to null and copyWith carries it', () {
    expect(base.outingId, isNull);
    final withOuting = base.copyWith(outingId: 'outing-1');
    expect(withOuting.outingId, 'outing-1');
    expect(withOuting.copyWith(name: 'x').outingId, 'outing-1');
    expect(withOuting, isNot(equals(base)));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_outing_id_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Add the field**

In `dive.dart`, directly after the `isPlanned` field:

```dart
  /// Shared id across sibling dives mirrored from one save (issue #2002).
  /// Null for a dive that was never mirrored.
  final String? outingId;
```

Constructor: after `this.isPlanned = false,` add `this.outingId,`. `copyWith` parameters: after `bool? isPlanned,` add `String? outingId,` and `bool clearOutingId = false,`; body: after `isPlanned: isPlanned ?? this.isPlanned,` add `outingId: clearOutingId ? null : (outingId ?? this.outingId),` (the mirror undo in Task 11 needs the explicit clear, since the `??` idiom cannot express null). `props`: after `isPlanned,` add `outingId,`. Add a third entity test: `withOuting.copyWith(clearOutingId: true).outingId` is null.

- [ ] **Step 4: Write the failing repository test**

```dart
// test/features/dive_log/data/repositories/dive_repository_outing_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('createDive and updateDive round-trip outingId', () async {
    final created = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9), outingId: 'outing-1'),
    );
    expect((await repository.getDiveById(created.id))?.outingId, 'outing-1');
    await repository.updateDive(created.copyWith(outingId: 'outing-2'));
    expect((await repository.getDiveById(created.id))?.outingId, 'outing-2');
  });

  test('getDivesByOutingId returns every dive in the outing, newest first',
      () async {
    final a = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9), outingId: 'o'),
    );
    final b = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9, 5), outingId: 'o'),
    );
    await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9), outingId: 'other'),
    );
    final ids = (await repository.getDivesByOutingId('o')).map((d) => d.id);
    expect(ids, [b.id, a.id]);
  });
}
```

- [ ] **Step 5: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_outing_test.dart`
Expected: FAIL to compile on `getDivesByOutingId`.

- [ ] **Step 6: Round-trip the column and add the query**

In `dive_repository_impl.dart`:
- `createDive` companion: after `isPlanned: Value(dive.isPlanned),` add `outingId: Value(dive.outingId),`.
- `updateDive` companion: same addition.
- Both mappers: after `isPlanned: row.isPlanned,` add `outingId: row.outingId,`.
- Add next to `getDivesForSite`:

```dart
  /// Every dive in an outing: the siblings mirrored from one save (issue
  /// #2002) plus the source dive itself. Ordered newest first like the
  /// other per-parent lists. Crosses profiles on purpose: the caller shows
  /// each sibling with its owner's name.
  // stats-scope-exempt: navigation between sibling dives, not a statistic.
  Future<List<domain.Dive>> getDivesByOutingId(String outingId) async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.outingId.equals(outingId))
        ..orderBy([
          (t) => OrderingTerm.desc(coalesce([t.entryTime, t.diveDateTime])),
          (t) => OrderingTerm.desc(t.diveNumber),
        ]);
      final rows = await query.get();
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives for outing: $outingId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

In `dive_edit_page.dart`, in the carry-through block after `isPlanned: _existingDive?.isPlanned ?? false,` add:

```dart
        outingId: _existingDive?.outingId,
```

(The census test `dive_edit_save_field_census_test.dart` fails without this line.)

- [ ] **Step 7: Write the sync round-trip test**

```dart
// test/core/services/sync/sync_outing_and_linked_diver_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('the generated toJson/fromJson carry both new columns', () async {
    final now = DateTime(2026).millisecondsSinceEpoch;
    await db.into(db.divers).insert(
      DiversCompanion.insert(id: 'chris', name: 'Chris', createdAt: now, updatedAt: now),
    );
    final buddy = BuddiesCompanion.insert(
      id: 'b1',
      name: 'Chris',
      linkedDiverId: const Value('chris'),
      createdAt: now,
      updatedAt: now,
    );
    await db.into(db.buddies).insert(buddy);
    final buddyRow = await (db.select(db.buddies)..where((t) => t.id.equals('b1'))).getSingle();
    expect(Buddy.fromJson(buddyRow.toJson()).linkedDiverId, 'chris');

    final dive = DivesCompanion.insert(
      id: 'd1',
      diveDateTime: now,
      outingId: const Value('outing-1'),
      createdAt: now,
      updatedAt: now,
    );
    await db.into(db.dives).insert(dive);
    final diveRow = await (db.select(db.dives)..where((t) => t.id.equals('d1'))).getSingle();
    expect(Dive.fromJson(diveRow.toJson()).outingId, 'outing-1');
  });
}
```

Adjust the `DiversCompanion.insert` and `DivesCompanion.insert` required arguments to whatever the generated companions demand (read `database.g.dart` for the `insert` factory signatures).

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/dive_log/domain/entities/dive_outing_id_test.dart test/features/dive_log/data/repositories/dive_repository_outing_test.dart test/core/services/sync/sync_outing_and_linked_diver_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart test/core/database/dive_stats_scope_census_test.dart`
Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/domain/entities/dive_outing_id_test.dart test/features/dive_log/data/repositories/dive_repository_outing_test.dart test/core/services/sync/sync_outing_and_linked_diver_test.dart
git commit -m "feat(dive-log): carry outingId on Dive and query dives by outing

Refs #2002"
```

---

### Task 4: `BuddyProfileLinkRepository` (validation, suggestion, reciprocal buddy)

**Files:**
- Create: `lib/features/buddies/data/repositories/buddy_profile_link_repository.dart`
- Create: `lib/features/buddies/presentation/providers/buddy_profile_link_providers.dart`
- Test: `test/features/buddies/data/repositories/buddy_profile_link_repository_test.dart`

**Interfaces:**
- Consumes: `Buddy.linkedDiverId` (Task 2), `BuddyRepository.createBuddy/getAllBuddies`, `DiverRepository.getDiverById/getAllDivers`.
- Produces: see "Shared interfaces" (`BuddyLinkRefused`, `BuddyLinkRefusal`, `assertLinkAllowed`, `suggestProfileFor`, `linkedBuddyFor`, `ensureReciprocalBuddy`), providers `buddyProfileLinkRepositoryProvider` and `linkedProfileSuggestionProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/buddies/data/repositories/buddy_profile_link_repository_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddies;
  late DiverRepository divers;
  late BuddyProfileLinkRepository links;
  late String eric;
  late String chris;

  Future<String> diver(String name, {String? email}) async => (await divers
          .createDiver(
    Diver(
      id: '',
      name: name,
      email: email,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ))
      .id;

  Buddy buddy(String owner, String name, {String? linked, String? email}) =>
      Buddy(
        id: '',
        diverId: owner,
        linkedDiverId: linked,
        name: name,
        email: email,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  setUp(() async {
    await setUpTestDatabase();
    buddies = BuddyRepository();
    divers = DiverRepository();
    links = BuddyProfileLinkRepository(buddies: buddies, divers: divers);
    eric = await diver('Eric', email: 'eric@example.com');
    chris = await diver('Chris', email: 'chris@example.com');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('assertLinkAllowed', () {
    test('refuses linking a buddy to its own owner', () async {
      expect(
        () => links.assertLinkAllowed(ownerDiverId: eric, linkedDiverId: eric),
        throwsA(
          isA<BuddyLinkRefused>()
              .having((e) => e.reason, 'reason', BuddyLinkRefusal.self),
        ),
      );
    });

    test('refuses a second buddy in the same list linking the same profile',
        () async {
      final existing = await buddies.createBuddy(buddy(eric, 'C', linked: chris));
      expect(
        () => links.assertLinkAllowed(ownerDiverId: eric, linkedDiverId: chris),
        throwsA(
          isA<BuddyLinkRefused>()
              .having((e) => e.reason, 'reason', BuddyLinkRefusal.taken)
              .having((e) => e.existingBuddy?.id, 'existing', existing.id),
        ),
      );
    });

    test('allows re-saving the buddy that already holds the link', () async {
      final existing = await buddies.createBuddy(buddy(eric, 'C', linked: chris));
      await links.assertLinkAllowed(
        ownerDiverId: eric,
        linkedDiverId: chris,
        buddyId: existing.id,
      );
    });

    test('allows the same profile linked from a different owner list', () async {
      await buddies.createBuddy(buddy(eric, 'C', linked: chris));
      final dana = await diver('Dana');
      await links.assertLinkAllowed(ownerDiverId: dana, linkedDiverId: chris);
    });
  });

  group('suggestProfileFor', () {
    test('matches a single profile by case-folded, trimmed name', () async {
      final hit = await links.suggestProfileFor(ownerDiverId: eric, name: '  chris ');
      expect(hit?.id, chris);
    });

    test('matches by email when the name differs', () async {
      final hit = await links.suggestProfileFor(
        ownerDiverId: eric,
        name: 'C.',
        email: 'chris@example.com',
      );
      expect(hit?.id, chris);
    });

    test('never suggests the owner itself', () async {
      final hit = await links.suggestProfileFor(ownerDiverId: eric, name: 'Eric');
      expect(hit, isNull);
    });

    test('returns null when two profiles match', () async {
      await diver('Chris');
      final hit = await links.suggestProfileFor(ownerDiverId: eric, name: 'Chris');
      expect(hit, isNull);
    });

    test('returns null when the profile is already linked in this list', () async {
      await buddies.createBuddy(buddy(eric, 'Chris', linked: chris));
      final hit = await links.suggestProfileFor(ownerDiverId: eric, name: 'Chris');
      expect(hit, isNull);
    });
  });

  group('ensureReciprocalBuddy', () {
    test('creates a linked buddy in the owner list from the profile', () async {
      final created = await links.ensureReciprocalBuddy(
        ownerDiverId: chris,
        linkedDiverId: eric,
      );
      expect(created.diverId, chris);
      expect(created.linkedDiverId, eric);
      expect(created.name, 'Eric');
      expect(created.email, 'eric@example.com');
    });

    test('is idempotent: a second call returns the same buddy', () async {
      final first = await links.ensureReciprocalBuddy(ownerDiverId: chris, linkedDiverId: eric);
      final second = await links.ensureReciprocalBuddy(ownerDiverId: chris, linkedDiverId: eric);
      expect(second.id, first.id);
      expect((await buddies.getAllBuddies(diverId: chris)).length, 1);
    });

    test('linkedBuddyFor finds an existing link and null otherwise', () async {
      expect(await links.linkedBuddyFor(ownerDiverId: chris, linkedDiverId: eric), isNull);
      final created = await buddies.createBuddy(buddy(chris, 'E', linked: eric));
      expect((await links.linkedBuddyFor(ownerDiverId: chris, linkedDiverId: eric))?.id, created.id);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_profile_link_repository_test.dart`
Expected: FAIL to compile, the repository does not exist.

- [ ] **Step 3: Write the repository**

```dart
// lib/features/buddies/data/repositories/buddy_profile_link_repository.dart
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// Why a buddy-to-profile link was refused.
enum BuddyLinkRefusal {
  /// The buddy would link to the profile that owns it.
  self,

  /// Another buddy in the same owner's list already links to that profile.
  taken,
}

/// Thrown by [BuddyProfileLinkRepository.assertLinkAllowed].
class BuddyLinkRefused implements Exception {
  final BuddyLinkRefusal reason;

  /// The buddy holding the link when [reason] is [BuddyLinkRefusal.taken].
  final Buddy? existingBuddy;

  const BuddyLinkRefused(this.reason, {this.existingBuddy});

  @override
  String toString() => 'BuddyLinkRefused($reason)';
}

/// Links between buddy records and the local diver profiles they are
/// (issue #2002). The rules live here, not in the schema: at most one buddy
/// per (owner, linked profile), and never a link to the buddy's own owner.
class BuddyProfileLinkRepository {
  final BuddyRepository _buddies;
  final DiverRepository _divers;

  BuddyProfileLinkRepository({
    required BuddyRepository buddies,
    required DiverRepository divers,
  }) : _buddies = buddies,
       _divers = divers;

  /// Throws [BuddyLinkRefused] when [linkedDiverId] may not be set on a buddy
  /// owned by [ownerDiverId]. Pass [buddyId] when re-saving an existing
  /// buddy so its own current link does not count as taken.
  Future<void> assertLinkAllowed({
    required String? ownerDiverId,
    required String linkedDiverId,
    String? buddyId,
  }) async {
    if (ownerDiverId != null && ownerDiverId == linkedDiverId) {
      throw const BuddyLinkRefused(BuddyLinkRefusal.self);
    }
    final holder = await _holderOf(
      ownerDiverId: ownerDiverId,
      linkedDiverId: linkedDiverId,
    );
    if (holder != null && holder.id != buddyId) {
      throw BuddyLinkRefused(BuddyLinkRefusal.taken, existingBuddy: holder);
    }
  }

  /// The buddy in [ownerDiverId]'s list that links to [linkedDiverId], or
  /// null when there is none.
  Future<Buddy?> linkedBuddyFor({
    required String ownerDiverId,
    required String linkedDiverId,
  }) => _holderOf(ownerDiverId: ownerDiverId, linkedDiverId: linkedDiverId);

  /// The one other local profile whose trimmed, case-folded name equals
  /// [name] or whose email equals [email]. Null when none or several match,
  /// when the match is the owner, or when the owner's list already links it.
  Future<Diver?> suggestProfileFor({
    required String? ownerDiverId,
    required String name,
    String? email,
  }) async {
    final wantedName = _fold(name);
    final wantedEmail = _fold(email ?? '');
    final candidates = <Diver>[];
    for (final diver in await _divers.getAllDivers()) {
      if (diver.id == ownerDiverId) continue;
      final nameHit = wantedName.isNotEmpty && _fold(diver.name) == wantedName;
      final emailHit =
          wantedEmail.isNotEmpty && _fold(diver.email ?? '') == wantedEmail;
      if (nameHit || emailHit) candidates.add(diver);
    }
    if (candidates.length != 1) return null;
    final match = candidates.single;
    final holder = await _holderOf(
      ownerDiverId: ownerDiverId,
      linkedDiverId: match.id,
    );
    return holder == null ? match : null;
  }

  /// The buddy in [ownerDiverId]'s list that is [linkedDiverId], created
  /// from the profile's name, email, phone and photo when absent.
  Future<Buddy> ensureReciprocalBuddy({
    required String ownerDiverId,
    required String linkedDiverId,
  }) async {
    final existing = await _holderOf(
      ownerDiverId: ownerDiverId,
      linkedDiverId: linkedDiverId,
    );
    if (existing != null) return existing;
    final profile = await _divers.getDiverById(linkedDiverId);
    if (profile == null) {
      throw StateError('Diver $linkedDiverId does not exist');
    }
    final now = DateTime.now();
    return _buddies.createBuddy(
      Buddy(
        id: '',
        diverId: ownerDiverId,
        linkedDiverId: linkedDiverId,
        name: profile.name,
        email: profile.email,
        phone: profile.phone,
        photo: profile.photo,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<Buddy?> _holderOf({
    required String? ownerDiverId,
    required String linkedDiverId,
  }) async {
    final list = await _buddies.getAllBuddies(diverId: ownerDiverId);
    for (final buddy in list) {
      if (buddy.linkedDiverId == linkedDiverId) return buddy;
    }
    return null;
  }

  static String _fold(String value) => value.trim().toLowerCase();
}
```

Check `getAllBuddies({String? diverId})` semantics at `buddy_repository.dart:84-99`: with a null `diverId` it must return every buddy (owner-less lists are the legacy case). If it filters differently, add a private query here instead of relying on it.

- [ ] **Step 4: Add the providers**

```dart
// lib/features/buddies/presentation/providers/buddy_profile_link_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final buddyProfileLinkRepositoryProvider = Provider<BuddyProfileLinkRepository>(
  (ref) => BuddyProfileLinkRepository(
    buddies: ref.watch(buddyRepositoryProvider),
    divers: ref.watch(diverRepositoryProvider),
  ),
);

/// Arguments for [linkedProfileSuggestionProvider]: the owner list and the
/// name/email typed on the buddy page.
typedef LinkedProfileSuggestionArgs = ({
  String? ownerDiverId,
  String name,
  String? email,
});

/// The single profile a buddy page should offer to link, or null.
final linkedProfileSuggestionProvider =
    FutureProvider.autoDispose.family<Diver?, LinkedProfileSuggestionArgs>(
  (ref, args) => ref
      .watch(buddyProfileLinkRepositoryProvider)
      .suggestProfileFor(
        ownerDiverId: args.ownerDiverId,
        name: args.name,
        email: args.email,
      ),
);
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/buddies/data/repositories/buddy_profile_link_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/buddies/data/repositories/buddy_profile_link_repository.dart lib/features/buddies/presentation/providers/buddy_profile_link_providers.dart test/features/buddies/data/repositories/buddy_profile_link_repository_test.dart
git commit -m "feat(buddies): repository for buddy-to-profile links

Validation (one link per owner list, never the owner itself), the
single-match name/email suggestion, and the reciprocal buddy the
mirror flow needs.

Refs #2002"
```

---

### Task 5: Merge behaviour, diver merge repoint, delete SET NULL

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_merge_repository.dart` (validation block 164-173, `_updateBuddyRow` 589-603)
- Modify: `lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart` (surface the surviving link)
- Modify: `lib/features/divers/data/repositories/diver_merge_repository.dart` (`mergeDivers` at 99)
- Test: `test/features/buddies/data/repositories/buddy_merge_linked_diver_test.dart`, `test/features/divers/data/repositories/diver_merge_linked_buddy_test.dart`

**Interfaces:**
- Consumes: `Buddy.linkedDiverId`.
- Produces: `mergeBuddies` throws `StateError('Cannot merge buddies linked to different profiles')` on conflicting links and writes the single link onto the survivor; `mergeDivers` repoints `buddies.linked_diver_id` from the merged diver to the survivor and drops a link that would collide with the survivor's own list rule.

- [ ] **Step 1: Write the failing buddy-merge test**

Read `test/features/buddies/data/repositories/buddy_merge_repository_error_test.dart` first and copy its setup (how `BuddyMergeRepository` is constructed and how `mergeBuddies` is called). Then:

```dart
// test/features/buddies/data/repositories/buddy_merge_linked_diver_test.dart
// (imports and setUp as in buddy_merge_repository_error_test.dart, plus a
// DiverRepository to create profiles 'chris' and 'dana')

  test('merge carries the single non-null link onto the survivor', () async {
    final survivor = await buddies.createBuddy(buddy(owner, 'Chris'));
    final dup = await buddies.createBuddy(buddy(owner, 'C', linked: chris));
    await merges.mergeBuddies(
      mergedBuddy: survivor.copyWith(linkedDiverId: chris),
      buddyIds: [survivor.id, dup.id],
    );
    expect((await buddies.getBuddyById(survivor.id))?.linkedDiverId, chris);
  });

  test('merge refuses buddies linked to different profiles', () async {
    final a = await buddies.createBuddy(buddy(owner, 'Chris', linked: chris));
    final b = await buddies.createBuddy(buddy(owner, 'Dana', linked: dana));
    expect(
      () => merges.mergeBuddies(mergedBuddy: a, buddyIds: [a.id, b.id]),
      throwsA(isA<StateError>().having(
        (e) => e.message, 'message', contains('different profiles'))),
    );
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_linked_diver_test.dart`
Expected: the "refuses" test FAILS (no error thrown); the "carries" test may fail if `_updateBuddyRow` omits the column.

- [ ] **Step 3: Implement the merge rules**

In `buddy_merge_repository.dart`, directly after the "different divers" check (line ~173):

```dart
      // A buddy is at most one local profile. Two different links cannot be
      // reconciled by picking one, so refuse; the diver merges profiles first.
      final links = allBuddies
          .map((b) => b.linkedDiverId)
          .whereType<String>()
          .toSet();
      if (links.length > 1) {
        throw StateError('Cannot merge buddies linked to different profiles');
      }
      final survivingLink = links.isEmpty
          ? null
          : (mergedBuddy.linkedDiverId ?? links.single);
```

and make the survivor row write use `survivingLink`: in `_updateBuddyRow` add `linkedDiverId: Value(buddy.linkedDiverId),` to the companion, and pass `mergedBuddy.copyWith(linkedDiverId: survivingLink)` (or `clearLinkedDiver()` when `survivingLink == null`) where the survivor row is written.

In `buddy_merge_form_controller.dart` `initialize()`, compute the surviving link the same way (first non-null across the candidates) and expose `String? get mergedLinkedDiverId`, so the buddy edit page's merge branch (Task 6) can pass it. No cycling UI: the link is not a text field.

- [ ] **Step 4: Write the failing diver-merge test**

Read `test/features/divers/diver_merge_repository_test.dart` for the setup, then:

```dart
// test/features/divers/data/repositories/diver_merge_linked_buddy_test.dart
  test('mergeDivers repoints buddies linked to the merged diver', () async {
    // eric owns a buddy linked to 'chris2', a duplicate of 'chris'.
    final b = await buddies.createBuddy(buddy(eric, 'Chris', linked: chris2));
    await merges.mergeDivers(survivorId: chris, mergedIds: [chris2]);
    expect((await buddies.getBuddyById(b.id))?.linkedDiverId, chris);
  });

  test('a repointed link that collides with an existing one is cleared', () async {
    final keep = await buddies.createBuddy(buddy(eric, 'Chris', linked: chris));
    final dup = await buddies.createBuddy(buddy(eric, 'C', linked: chris2));
    await merges.mergeDivers(survivorId: chris, mergedIds: [chris2]);
    expect((await buddies.getBuddyById(keep.id))?.linkedDiverId, chris);
    expect((await buddies.getBuddyById(dup.id))?.linkedDiverId, isNull);
  });

  test('deleting a profile clears links to it', () async {
    final b = await buddies.createBuddy(buddy(eric, 'Chris', linked: chris));
    await divers.deleteDiverWithReassignment(chris, /* args as the repo needs */);
    expect((await buddies.getBuddyById(b.id))?.linkedDiverId, isNull);
  });
```

Match `mergeDivers` and `deleteDiverWithReassignment` argument names to the actual signatures at `diver_merge_repository.dart:99` and `diver_repository.dart:490`.

- [ ] **Step 5: Implement the repoint**

In `DiverMergeRepository.mergeDivers`, inside the transaction, before the generic `_tablesWithDiverId` loop, add a step that runs for each merged id:

```dart
  /// buddies.linked_diver_id is not a diver_id column, so the generic
  /// repoint skips it. Move each link to the survivor unless the same owner
  /// list already links the survivor, in which case clear it (one link per
  /// owner list, see BuddyProfileLinkRepository).
  Future<void> _repointLinkedBuddies({
    required String survivorId,
    required String mergedId,
  }) async {
    final rows = await (_db.select(_db.buddies)
          ..where((t) => t.linkedDiverId.equals(mergedId)))
        .get();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      final clash = await (_db.select(_db.buddies)
            ..where(
              (t) =>
                  t.linkedDiverId.equals(survivorId) &
                  (row.diverId == null
                      ? t.diverId.isNull()
                      : t.diverId.equals(row.diverId!)),
            ))
          .get();
      await (_db.update(_db.buddies)..where((t) => t.id.equals(row.id))).write(
        BuddiesCompanion(
          linkedDiverId: Value(clash.isEmpty ? survivorId : null),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'buddies',
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
  }
```

Use whatever sync-repository handle `DiverMergeRepository` already holds (see how it marks other repointed rows pending). Record the touched buddy ids in the merge snapshot the way other repointed rows are recorded so `undoMerge` restores them; if the snapshot is generic row maps (`_rowAsMap`), the buddy rows are already captured by the generic path only when they carry `diver_id` equal to the merged diver, so add the linked rows explicitly.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_linked_diver_test.dart test/features/divers/data/repositories/diver_merge_linked_buddy_test.dart test/features/buddies/ test/features/divers/`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/buddies/data/repositories/buddy_merge_repository.dart lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart lib/features/divers/data/repositories/diver_merge_repository.dart test/features/buddies/data/repositories/buddy_merge_linked_diver_test.dart test/features/divers/data/repositories/diver_merge_linked_buddy_test.dart
git commit -m "feat(buddies): keep profile links consistent across merges

Buddy merge carries a single link and refuses two different ones;
diver merge repoints linked buddies to the survivor, clearing a link
that would give one owner list two buddies for the same profile.

Refs #2002"
```

---

### Task 6: Buddy edit page: "Linked profile" field and suggestion prompt

**Files:**
- Create: `lib/features/buddies/presentation/widgets/linked_profile_field.dart`, `lib/features/buddies/presentation/widgets/linked_profile_suggestion.dart`
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart` (state 67-86, `_loadBuddy` 145-185, form body after the phone field 415-429, `_saveBuddy` 695-801)
- Modify: `lib/l10n/arb/app_*.arb` (11 files) and regenerate
- Test: `test/features/buddies/presentation/pages/buddy_edit_linked_profile_test.dart`

**Interfaces:**
- Consumes: `BuddyProfileLinkRepository` (Task 4), `allDiversProvider`, `validatedCurrentDiverIdProvider`.
- Produces: `LinkedProfileField({required String? ownerDiverId, required String? linkedDiverId, required ValueChanged<String?> onChanged})`, `Future<String?> showLinkedProfilePicker(BuildContext, {required String? ownerDiverId, String? selectedDiverId})` (returns the chosen diver id, `''` for "no link", null on cancel), `LinkedProfileSuggestion({required Diver diver, required VoidCallback onLink, required VoidCallback onDismiss})`.

ARB keys (English values; translate in all 10 other locales, anchor on `buddies_field_phoneHint`):

| key | en |
| --- | --- |
| `buddies_field_linkedProfile` | Linked profile |
| `buddies_field_linkedProfileHint` | The local profile this buddy is |
| `buddies_field_linkedProfileNone` | Not linked |
| `buddies_linkedProfile_pickerTitle` | Link to a profile |
| `buddies_linkedProfile_suggestion` | {name} has a profile here. Link this buddy to it? (placeholder `name`) |
| `buddies_linkedProfile_link` | Link |
| `buddies_linkedProfile_notNow` | Not now |
| `buddies_linkedProfile_refusedSelf` | A buddy cannot be linked to its own profile. |
| `buddies_linkedProfile_refusedTaken` | {buddyName} is already linked to this profile. (placeholder `buddyName`) |
| `buddies_linkedProfile_openBuddy` | Open buddy |
| `buddies_linkedProfile_chip` | Profile |
| `buddies_merge_refusedDifferentLinks` | These buddies are linked to different profiles. Merge the profiles first. |

- [ ] **Step 1: Write the failing widget test**

Copy the harness from `test/features/buddies/presentation/pages/buddy_edit_cert_fields_test.dart:26-76` (real database, `sharedPreferencesProvider` and `settingsProvider` overrides, `BuddyEditPage(embedded: true)`), create two divers (the owner `D`, default, active; and `Chris`), then:

```dart
  testWidgets('shows the suggestion when the name matches a profile and links on tap',
      (tester) async {
    final buddy = await buddyRepo.createBuddy(Buddy(
      id: '', diverId: ownerId, name: 'Chris',
      createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    await tester.pumpWidget(harness(buddyId: buddy.id));
    await tester.pumpAndSettle();

    expect(find.text('Chris has a profile here. Link this buddy to it?'), findsOneWidget);
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    expect(find.text('Chris has a profile here. Link this buddy to it?'), findsNothing);
    expect(find.text('Chris'), findsWidgets); // the field now shows the profile

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await buddyRepo.getBuddyById(buddy.id))?.linkedDiverId, chrisId);
  });

  testWidgets('Not now hides the suggestion without saving a link', (tester) async {
    final buddy = await buddyRepo.createBuddy(/* name Chris as above */);
    await tester.pumpWidget(harness(buddyId: buddy.id));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Chris has a profile here. Link this buddy to it?'), findsNothing);
    expect(find.text('Not linked'), findsOneWidget);
  });

  testWidgets('refuses a link another buddy already holds', (tester) async {
    await buddyRepo.createBuddy(/* name 'C', linkedDiverId: chrisId */);
    final buddy = await buddyRepo.createBuddy(/* name 'Chris' */);
    await tester.pumpWidget(harness(buddyId: buddy.id));
    await tester.pumpAndSettle();
    // No suggestion: the profile is already linked in this list.
    expect(find.text('Chris has a profile here. Link this buddy to it?'), findsNothing);
    await tester.tap(find.text('Not linked'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chris').last); // pick the profile in the sheet
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('C is already linked to this profile.'), findsOneWidget);
    expect((await buddyRepo.getBuddyById(buddy.id))?.linkedDiverId, isNull);
  });
```

Check the Save button's label key in the page (`buddies_action_save` or similar) and use `find.text` with the English value.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/buddies/presentation/pages/buddy_edit_linked_profile_test.dart`
Expected: FAIL, no suggestion text and no "Not linked" row.

- [ ] **Step 3: Add the ARB keys to all 11 files, then `flutter gen-l10n`**

Insert the twelve keys (with their `@` placeholder entries for `buddies_linkedProfile_suggestion` and `buddies_linkedProfile_refusedTaken`) before `buddies_field_phoneHint` in `app_en.arb` and after it in the other ten. Then run `flutter gen-l10n` and confirm with `grep -A1 "get buddies_linkedProfile_link " lib/l10n/arb/app_localizations_de.dart` that the German getter holds German.

- [ ] **Step 4: Write the two widgets**

```dart
// lib/features/buddies/presentation/widgets/linked_profile_field.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The "Linked profile" row on the buddy page: shows the linked local
/// profile (or "Not linked") and opens [showLinkedProfilePicker] on tap.
class LinkedProfileField extends ConsumerWidget {
  final String? ownerDiverId;
  final String? linkedDiverId;
  final ValueChanged<String?> onChanged;

  const LinkedProfileField({
    super.key,
    required this.ownerDiverId,
    required this.linkedDiverId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divers = ref.watch(allDiversProvider).valueOrNull ?? const <Diver>[];
    Diver? linked;
    for (final d in divers) {
      if (d.id == linkedDiverId) linked = d;
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: linked == null
          ? const Icon(Icons.person_outline)
          : ProfileAvatar(
              photo: linked.photo,
              initials: linked.initials,
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
      title: Text(context.l10n.buddies_field_linkedProfile),
      subtitle: Text(linked?.name ?? context.l10n.buddies_field_linkedProfileNone),
      trailing: linked == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              icon: const Icon(Icons.clear),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final picked = await showLinkedProfilePicker(
          context,
          ownerDiverId: ownerDiverId,
          selectedDiverId: linkedDiverId,
        );
        if (picked == null) return;
        onChanged(picked.isEmpty ? null : picked);
      },
    );
  }
}

/// Bottom sheet listing every local profile except the owner. Returns the
/// chosen id, an empty string for "no link", or null when dismissed.
Future<String?> showLinkedProfilePicker(
  BuildContext context, {
  required String? ownerDiverId,
  String? selectedDiverId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final diversAsync = ref.watch(allDiversProvider);
        return SafeArea(
          child: diversAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (divers) {
              final choices = [
                for (final d in divers)
                  if (d.id != ownerDiverId) d,
              ];
              return ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.buddies_linkedProfile_pickerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: Text(context.l10n.buddies_field_linkedProfileNone),
                    trailing: selectedDiverId == null ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(sheetContext, ''),
                  ),
                  for (final d in choices)
                    ListTile(
                      leading: ProfileAvatar(
                        photo: d.photo,
                        initials: d.initials,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      title: Text(d.name),
                      subtitle: d.email == null ? null : Text(d.email!),
                      trailing: d.id == selectedDiverId ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(sheetContext, d.id),
                    ),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}
```

```dart
// lib/features/buddies/presentation/widgets/linked_profile_suggestion.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Inline prompt: "{name} has a profile here. Link this buddy to it?"
class LinkedProfileSuggestion extends StatelessWidget {
  final Diver diver;
  final VoidCallback onLink;
  final VoidCallback onDismiss;

  const LinkedProfileSuggestion({
    super.key,
    required this.diver,
    required this.onLink,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.buddies_linkedProfile_suggestion(diver.name),
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: Text(context.l10n.buddies_linkedProfile_notNow),
                ),
                FilledButton.tonal(
                  onPressed: onLink,
                  child: Text(context.l10n.buddies_linkedProfile_link),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the page**

In `_BuddyEditPageState`:
- Add state: `String? _linkedDiverId; bool _suggestionDismissed = false;`.
- In `_loadBuddy()` set `_linkedDiverId = buddy.linkedDiverId;` next to `_photo = buddy.photo;`.
- In the form body, after the phone field's `const SizedBox(height: 24),` and only when `!widget.isMerging`, insert:

```dart
            if (!widget.isMerging) ...[
              if (!_suggestionDismissed && _linkedDiverId == null)
                Consumer(
                  builder: (context, ref, _) {
                    final ownerId =
                        _originalBuddy?.diverId ??
                        ref.watch(currentDiverIdProvider);
                    final suggestion = ref.watch(
                      linkedProfileSuggestionProvider((
                        ownerDiverId: ownerId,
                        name: _nameController.text,
                        email: _emailController.text.trim().isEmpty
                            ? null
                            : _emailController.text.trim(),
                      )),
                    );
                    final diver = suggestion.valueOrNull;
                    if (diver == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: LinkedProfileSuggestion(
                        diver: diver,
                        onLink: () => setState(() {
                          _linkedDiverId = diver.id;
                          _hasChanges = true;
                        }),
                        onDismiss: () =>
                            setState(() => _suggestionDismissed = true),
                      ),
                    );
                  },
                ),
              LinkedProfileField(
                ownerDiverId: _originalBuddy?.diverId,
                linkedDiverId: _linkedDiverId,
                onChanged: (id) => setState(() {
                  _linkedDiverId = id;
                  _hasChanges = true;
                }),
              ),
              const SizedBox(height: 24),
            ],
```

The suggestion re-evaluates as the name is typed because the provider family key includes the text; `_onFieldChanged` already calls `setState`.

- In `_saveBuddy`, before the `Buddy(...)` literal is built (after `diverId` is resolved), validate:

```dart
      final linkedDiverId = widget.isMerging
          ? _mergeCtrl?.mergedLinkedDiverId
          : _linkedDiverId;
      if (linkedDiverId != null) {
        try {
          await ref
              .read(buddyProfileLinkRepositoryProvider)
              .assertLinkAllowed(
                ownerDiverId: diverId,
                linkedDiverId: linkedDiverId,
                buddyId: widget.buddyId,
              );
        } on BuddyLinkRefused catch (refusal) {
          if (!mounted) return;
          _showLinkRefused(refusal);
          return;
        }
      }
```

and pass `linkedDiverId: linkedDiverId,` into the `Buddy(...)` literal. Add:

```dart
  void _showLinkRefused(BuddyLinkRefused refusal) {
    final l10n = context.l10n;
    final existing = refusal.existingBuddy;
    final text = switch (refusal.reason) {
      BuddyLinkRefusal.self => l10n.buddies_linkedProfile_refusedSelf,
      BuddyLinkRefusal.taken => l10n.buddies_linkedProfile_refusedTaken(
        existing?.name ?? '',
      ),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: existing == null
            ? null
            : SnackBarAction(
                label: l10n.buddies_linkedProfile_openBuddy,
                onPressed: () => context.push('/buddies/${existing.id}'),
              ),
      ),
    );
  }
```

Also map the merge refusal: in the merge branch's `catch`, when `e is StateError && e.message.contains('different profiles')`, show `l10n.buddies_merge_refusedDifferentLinks` instead of the raw message.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/buddies/presentation/pages/ test/l10n/arb_parity_test.dart`
Expected: all PASS.

- [ ] **Step 7: Commit (ARBs and generated files in their own commit first)**

```bash
dart format .
git add lib/l10n/arb/app_en.arb lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations.dart lib/l10n/arb/app_localizations_ar.dart lib/l10n/arb/app_localizations_de.dart lib/l10n/arb/app_localizations_en.dart lib/l10n/arb/app_localizations_es.dart lib/l10n/arb/app_localizations_fr.dart lib/l10n/arb/app_localizations_he.dart lib/l10n/arb/app_localizations_hu.dart lib/l10n/arb/app_localizations_it.dart lib/l10n/arb/app_localizations_nl.dart lib/l10n/arb/app_localizations_pt.dart lib/l10n/arb/app_localizations_zh.dart
git commit -m "i18n(buddies): strings for linked profiles

Refs #2002"
git add lib/features/buddies/presentation/widgets/linked_profile_field.dart lib/features/buddies/presentation/widgets/linked_profile_suggestion.dart lib/features/buddies/presentation/pages/buddy_edit_page.dart test/features/buddies/presentation/pages/buddy_edit_linked_profile_test.dart
git commit -m "feat(buddies): link a buddy to a local profile from the buddy page

An explicit picker, plus a one-time suggestion when the name or email
matches exactly one other profile.

Refs #2002"
```

---

### Task 7: Profile marker on the buddy list tile and detail page

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_tile.dart` (chip row 109-137, `_BuddyAvatar` 271-294)
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart` (`_buildContactSection` 458-492, `_buildProfileHeader` 437-456)
- Test: `test/features/buddies/presentation/widgets/buddy_list_tile_profile_chip_test.dart`

**Interfaces:**
- Consumes: `Buddy.linkedDiverId`, `diverByIdProvider` (family, `diver_providers.dart:50`).

- [ ] **Step 1: Write the failing test**

Read an existing tile test (`grep -rl "BuddyListTile(" test/features/buddies/presentation/widgets/ | head -1`) for the pump idiom, then:

```dart
  testWidgets('a linked buddy shows the Profile chip', (tester) async {
    final buddy = Buddy(
      id: 'b1', name: 'Chris', linkedDiverId: 'chris',
      createdAt: DateTime(2026), updatedAt: DateTime(2026));
    await tester.pumpWidget(testApp(
      overrides: [
        ...await getBaseOverrides(),
        diverByIdProvider('chris').overrideWith((ref) async => Diver(
          id: 'chris', name: 'Chris',
          createdAt: DateTime(2026), updatedAt: DateTime(2026))),
      ],
      locale: const Locale('en'),
      child: Scaffold(body: BuddyListTile(buddy: buddy, /* other required args */)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('an unlinked buddy shows no Profile chip', (tester) async {
    /* same with linkedDiverId null */
    expect(find.text('Profile'), findsNothing);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_list_tile_profile_chip_test.dart`
Expected: FAIL, no "Profile" text.

- [ ] **Step 3: Add the chip and the photo fallback**

In `buddy_list_tile.dart`, in the chip row (near `_BuddyChip(icon: Icons.card_membership, ...)`), add before it:

```dart
          if (buddy.linkedDiverId != null)
            _BuddyChip(
              icon: Icons.account_circle_outlined,
              label: context.l10n.buddies_linkedProfile_chip,
            ),
```

In `_BuddyAvatar`, when `buddy.photo == null && buddy.linkedDiverId != null`, watch `diverByIdProvider(buddy.linkedDiverId!)` (the widget becomes a `ConsumerWidget`) and pass `diver?.photo` to `ProfileAvatar` as the photo.

In `buddy_detail_page.dart`, in `_buildContactSection` add a `ListTile` (same shape as the email row) when `buddy.linkedDiverId != null`, leading `Icons.account_circle_outlined`, title `context.l10n.buddies_field_linkedProfile`, subtitle the diver's name from `diverByIdProvider`. Make the contact card show when `buddy.hasContactInfo || buddy.linkedDiverId != null`. Apply the same photo fallback to the two `ProfileAvatar` calls in the header.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/buddies/`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/buddies/presentation/widgets/buddy_list_tile.dart lib/features/buddies/presentation/pages/buddy_detail_page.dart test/features/buddies/presentation/widgets/buddy_list_tile_profile_chip_test.dart
git commit -m "feat(buddies): mark linked buddies and borrow the profile photo

Refs #2002"
```

---

### Task 8: Planned-dive data plumbing (summary flag, numbering gate, planner convert)

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart` (fields 13-54, ctor 56, `fromDive` 91, `copyWith` 161, `props` 222)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (summary SQL at 2173 and 3039, `_mapSummaryRows` at 3144)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (`addDive` 644-671, paginated `addDive` 1170-1205)
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart:733`
- Test: `test/features/dive_log/data/repositories/dive_repository_planned_lifecycle_test.dart`, `test/features/dive_log/presentation/providers/dive_providers_planned_numbering_test.dart`

**Interfaces:**
- Produces: `DiveSummary.isPlanned` (`bool`, default false), populated by both summary queries; `addDive` leaves a planned dive unnumbered; the planner creates through `createPlannedDive`.

- [ ] **Step 1: Write the failing repository test**

```dart
// test/features/dive_log/data/repositories/dive_repository_planned_lifecycle_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('summaries carry isPlanned', () async {
    await repository.createPlannedDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)),
    );
    await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 5, 1, 9), diveNumber: 1),
    );
    final page = await repository.getDiveSummaries(limit: 10, offset: 0);
    expect(page.map((s) => s.isPlanned), [true, false]);
  });

  test('convertPlanToActualDive clears the flag, numbers and keeps the date',
      () async {
    await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 5, 1, 9), diveNumber: 7),
    );
    final planned = await repository.createPlannedDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)),
    );
    expect(planned.diveNumber, isNull);
    await repository.convertPlanToActualDive(planned.id);
    final promoted = await repository.getDiveById(planned.id);
    expect(promoted?.isPlanned, isFalse);
    expect(promoted?.diveNumber, 8);
    expect(promoted?.dateTime, DateTime(2026, 6, 1, 9));
  });
}
```

Match `getDiveSummaries`'s real name and arguments (read the definition near `dive_repository_impl.dart:2160`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_planned_lifecycle_test.dart`
Expected: the first test FAILS to compile (`isPlanned` missing on `DiveSummary`); the second passes already (it pins existing behaviour).

- [ ] **Step 3: Add `isPlanned` to summaries**

In `dive_summary.dart`: field `final bool isPlanned;` after `excludedFromGasStats`, ctor `this.isPlanned = false,`, `fromDive` `isPlanned: dive.isPlanned,`, `copyWith` parameter and assignment, `props` entry.

In both summary SELECT strings, change `'d.is_favorite, d.excluded_from_stats, d.excluded_from_gas_stats, '` to `'d.is_favorite, d.excluded_from_stats, d.excluded_from_gas_stats, d.is_planned, '`. In `_mapSummaryRows` after `excludedFromGasStats: ...` add `isPlanned: row.read<int>('is_planned') == 1,`.

- [ ] **Step 4: Write the failing numbering test**

Read `test/features/dive_log/presentation/providers/` for an existing `DiveListNotifier` test harness (a `ProviderContainer` with `diveRepositoryProvider` overridden to a real repository on the test database), then:

```dart
// test/features/dive_log/presentation/providers/dive_providers_planned_numbering_test.dart
  test('addDive leaves a planned dive unnumbered', () async {
    await repository.createDive(Dive(id: '', dateTime: DateTime(2026, 5, 1), diveNumber: 3));
    final notifier = container.read(paginatedDiveListProvider.notifier);
    final planned = await notifier.addDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1), isPlanned: true),
    );
    expect((await repository.getDiveById(planned.id))?.diveNumber, isNull);
  });

  test('addDive still numbers an unnumbered logged dive', () async {
    final notifier = container.read(paginatedDiveListProvider.notifier);
    final logged = await notifier.addDive(Dive(id: '', dateTime: DateTime(2026, 6, 1)));
    expect((await repository.getDiveById(logged.id))?.diveNumber, isNotNull);
  });
```

- [ ] **Step 5: Gate the renumbering and route the planner**

In both `addDive` methods change `if (dive.diveNumber == null) {` to `if (dive.diveNumber == null && !dive.isPlanned) {` with the comment `// A planned dive stays unnumbered until it is promoted (issue #2002).`

In `plan_canvas_page.dart:733` change `.createDive(dive)` to `.createPlannedDive(dive)` and update the comment above it: the dive is a planned, unnumbered entry until the diver's download fills it or they mark it as logged.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_planned_lifecycle_test.dart test/features/dive_log/presentation/providers/dive_providers_planned_numbering_test.dart test/features/dive_log/domain/ test/features/planner/`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log/domain/entities/dive_summary.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/presentation/providers/dive_providers.dart lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/dive_log/data/repositories/dive_repository_planned_lifecycle_test.dart test/features/dive_log/presentation/providers/dive_providers_planned_numbering_test.dart
git commit -m "feat(dive-log): planned dives stay unnumbered and reach the list

Summaries carry is_planned, addDive no longer renumbers a planned
dive, and the planner's convert goes through createPlannedDive on
purpose instead of by accident.

Refs #2002"
```

---

### Task 9: Dive edit page: planned switch, hidden number, "Plan a dive" entry

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_prefill.dart` (add `isPlanned`)
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart:87-93` (optional number row)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state near 330, `initState` 440-462, `_applyPrefill`, form body 915-960, `Dive(...)` literal 5049-5160, save tail 5191-5205)
- Modify: `lib/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart`, `pages/dive_list_page.dart:92-106`, `widgets/dive_list_content.dart:2379-2392`
- Modify: ARB files and regenerate
- Test: `test/features/dive_log/presentation/pages/dive_edit_planned_switch_test.dart`, `test/features/dive_log/presentation/widgets/add_dive_bottom_sheet_plan_test.dart`

ARB keys (anchor on `diveLog_listPage_bottomSheet_logManually`):

| key | en |
| --- | --- |
| `diveLog_listPage_bottomSheet_planDive` | Plan a dive |
| `diveLog_listPage_bottomSheet_planDiveSubtitle` | Fill in the details now, add the dive computer data later |
| `diveLog_edit_planned_switch` | Planned dive |
| `diveLog_edit_planned_switchSubtitle` | Awaiting dive computer data. No dive number until it is logged. |

- [ ] **Step 1: Write the failing edit-page test**

Copy the harness from `test/features/dive_log/presentation/pages/dive_edit_page_test.dart:1-62`, then:

```dart
  testWidgets('a prefill with isPlanned shows the switch on and hides the number',
      (tester) async {
    await tester.pumpWidget(page(prefill: const DivePrefill(isPlanned: true)));
    await tester.pumpAndSettle();
    final sw = tester.widget<SwitchListTile>(find.byKey(const Key('dive_edit_planned_switch')));
    expect(sw.value, isTrue);
    expect(find.text('Dive Number'), findsNothing);
  });

  testWidgets('saving with the switch on creates an unnumbered planned dive',
      (tester) async {
    await tester.pumpWidget(page(prefill: const DivePrefill(isPlanned: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit_form_save')));
    await tester.pumpAndSettle();
    final dives = await repository.getAllDives();
    expect(dives.single.isPlanned, isTrue);
    expect(dives.single.diveNumber, isNull);
  });

  testWidgets('turning the switch off on a planned dive promotes it on save',
      (tester) async {
    final planned = await repository.createPlannedDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)));
    await tester.pumpWidget(page(diveId: planned.id));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dive_edit_planned_switch')));
    await tester.pumpAndSettle();
    expect(find.text('Dive Number'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit_form_save')));
    await tester.pumpAndSettle();
    final saved = await repository.getDiveById(planned.id);
    expect(saved?.isPlanned, isFalse);
    expect(saved?.diveNumber, 1);
  });

  testWidgets('a dive with a primary data source cannot be marked planned',
      (tester) async {
    /* create a dive, then insert a dive_data_sources row with is_primary = 1 for it */
    await tester.pumpWidget(page(diveId: dive.id));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dive_edit_planned_switch')), findsNothing);
  });
```

Use the real English label of the number row (`diveLog_edit_label_diveNumber` in `app_en.arb`) and the real key of the save button in `EditFormScaffold` (grep `edit_form_scaffold.dart` for `Key(`).

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_planned_switch_test.dart`
Expected: FAIL to compile on `DivePrefill(isPlanned:)`.

- [ ] **Step 3: Add the strings (11 ARBs, then `flutter gen-l10n`)**

- [ ] **Step 4: Implement**

`dive_prefill.dart`: add `final bool isPlanned;` and `this.isPlanned = false,`.

`the_dive_section.dart`: add `final bool showDiveNumber;` with `this.showDiveNumber = true,` in the constructor, and wrap the number `FormRow.text` in `if (showDiveNumber)`.

`dive_edit_page.dart`:
- State: `bool _isPlanned = false; bool _hasPrimarySource = false;`.
- `initState` (new-dive branch): `_isPlanned = widget.prefill?.isPlanned ?? false;` and skip `_suggestNextDiveNumber()` when `_isPlanned`.
- `_loadExistingDive`: after `_existingDive = dive;` set `_isPlanned = dive.isPlanned;` and `_hasPrimarySource = await ref.read(diveRepositoryProvider).hasPrimaryDataSource(dive.id);`. Add to `DiveRepository` next to `backfillPrimaryDataSource`:

```dart
  /// Whether a primary dive_data_sources row exists for [diveId]. A dive
  /// with one holds downloaded data and cannot be marked planned.
  Future<bool> hasPrimaryDataSource(String diveId) async {
    final row = await (_db.select(_db.diveDataSources)
          ..where((t) => t.diveId.equals(diveId) & t.isPrimary.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }
```

- Form body: as the first child of the `ResponsiveFormColumns` (before `_buildTheDiveSection(units)`), when `!_hasPrimarySource`:

```dart
                if (!_hasPrimarySource)
                  SwitchListTile(
                    key: const Key('dive_edit_planned_switch'),
                    value: _isPlanned,
                    title: Text(context.l10n.diveLog_edit_planned_switch),
                    subtitle: Text(context.l10n.diveLog_edit_planned_switchSubtitle),
                    secondary: const Icon(Icons.event_available_outlined),
                    onChanged: (value) {
                      setState(() {
                        _isPlanned = value;
                        if (value) _diveNumberController.clear();
                      });
                      _markDirty();
                      if (!value && _diveNumberController.text.isEmpty) {
                        _suggestNextDiveNumber();
                      }
                    },
                  ),
```

- Pass `showDiveNumber: !_isPlanned` into `TheDiveSection`.
- In the `Dive(...)` literal replace `isPlanned: _existingDive?.isPlanned ?? false,` with `isPlanned: _isPlanned,` and make `diveNumber` null when `_isPlanned` (find where `diveNumber:` is parsed from the controller and wrap it: `diveNumber: _isPlanned ? null : parsedNumber,`).
- In the save tail, after `await notifier.updateDive(dive);`:

```dart
        if ((_existingDive?.isPlanned ?? false) && !_isPlanned) {
          // The switch was turned off: promote through the one path that
          // numbers the dive. updateDive above wrote isPlanned false, so
          // write it back to true first, then convert.
          final repository = ref.read(diveRepositoryProvider);
          await repository.updateDive(dive.copyWith(isPlanned: true));
          await repository.convertPlanToActualDive(widget.diveId!);
          ref.invalidate(diveNumberingInfoProvider);
          await notifier.refresh();
        }
```

Simpler and preferred: build the entity with `isPlanned: _isPlanned || (_existingDive?.isPlanned ?? false)` so `updateDive` never clears the flag itself, then call `convertPlanToActualDive` when `(_existingDive?.isPlanned ?? false) && !_isPlanned`. Use this form; it avoids the double write.

`add_dive_bottom_sheet.dart`: add a parameter `required VoidCallback onPlanDive` and, after the "Log manually" tile:

```dart
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: Text(sheetContext.l10n.diveLog_listPage_bottomSheet_planDive),
                subtitle: Text(
                  sheetContext.l10n.diveLog_listPage_bottomSheet_planDiveSubtitle,
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onPlanDive();
                },
              ),
```

Both call sites (`dive_list_page.dart:92-106` and `dive_list_content.dart:2379-2392`) pass `onPlanDive: () => context.push('/dives/new', extra: const DivePrefill(isPlanned: true))`. On desktop the `?mode=new` branch has no extra channel; keep `context.push('/dives/new', extra: ...)` for the planned entry on every layout.

- [ ] **Step 5: Write the bottom-sheet test and run everything**

```dart
// test/features/dive_log/presentation/widgets/add_dive_bottom_sheet_plan_test.dart
  testWidgets('Plan a dive calls onPlanDive', (tester) async {
    var planned = false;
    await tester.pumpWidget(testApp(
      locale: const Locale('en'),
      child: Builder(builder: (context) => TextButton(
        onPressed: () => showAddDiveBottomSheet(
          context: context, onLogManually: () {}, onPlanDive: () => planned = true),
        child: const Text('open'))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan a dive'));
    await tester.pumpAndSettle();
    expect(planned, isTrue);
  });
```

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_planned_switch_test.dart test/features/dive_log/presentation/widgets/add_dive_bottom_sheet_plan_test.dart test/features/dive_log/presentation/pages/ test/features/dive_log/presentation/widgets/`
Expected: all PASS (the census test still passes because `isPlanned` and `outingId` are named in the literal).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "i18n(dive-log): strings for planning a dive

Refs #2002"
git add lib/features/dive_log/domain/entities/dive_prefill.dart lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart lib/features/dive_log/presentation/pages/dive_list_page.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/presentation/pages/dive_edit_planned_switch_test.dart test/features/dive_log/presentation/widgets/add_dive_bottom_sheet_plan_test.dart
git commit -m "feat(dive-log): plan a dive by hand and promote it from the edit page

Refs #2002"
```

(`git add lib/l10n/arb/` is a directory of explicit, expected files; it is acceptable here because every file under it belongs to this change.)

---

### Task 10: Detail page banner and "Mark as logged", list "Planned" chip

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/planned_dive_banner.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (banner slot 1076-1083, both overflow menus 1181-1290 and 1413-1520)
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart:983-1000`, `widgets/compact_dive_list_tile.dart:327-360`
- Modify: ARB files and regenerate
- Test: `test/features/dive_log/presentation/pages/dive_detail_planned_test.dart`, `test/features/dive_log/presentation/pages/dive_list_planned_chip_test.dart`

ARB keys (anchor on `diveLog_detail_menu_logNearMiss`):

| key | en |
| --- | --- |
| `diveLog_planned_chip` | Planned |
| `diveLog_planned_bannerTitle` | Planned dive |
| `diveLog_planned_bannerBody` | Awaiting dive computer data. Mark it as logged if you dived without one. |
| `diveLog_detail_menu_markLogged` | Mark as logged |
| `diveLog_planned_markedLogged` | Marked as logged |

- [ ] **Step 1: Write the failing detail test**

Use `_buildDetailPage` from `test/features/dive_log/presentation/pages/dive_detail_page_test.dart:50-80` for the banner assertion, and the real-database harness from `dive_detail_pre_dive_link_menu_test.dart` for the menu action:

```dart
  testWidgets('a planned dive shows the banner', (tester) async {
    final dive = Dive(id: 'd1', dateTime: DateTime(2026, 6, 1), isPlanned: true);
    await tester.pumpWidget(_buildDetailPage(dive, await getBaseOverrides()));
    await tester.pumpAndSettle();
    expect(find.byType(PlannedDiveBanner), findsOneWidget);
    expect(find.text('Planned dive'), findsOneWidget);
  });

  testWidgets('a logged dive shows no banner and no Mark as logged item', (tester) async {
    final dive = Dive(id: 'd1', dateTime: DateTime(2026, 6, 1));
    await tester.pumpWidget(_buildDetailPage(dive, await getBaseOverrides()));
    await tester.pumpAndSettle();
    expect(find.byType(PlannedDiveBanner), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Mark as logged'), findsNothing);
  });

  testWidgets('Mark as logged promotes the dive', (tester) async {
    final planned = await repository.createPlannedDive(Dive(id: '', dateTime: DateTime(2026, 6, 1)));
    await tester.pumpWidget(realPage(planned.id));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as logged'));
    await tester.pumpAndSettle();
    final saved = await repository.getDiveById(planned.id);
    expect(saved?.isPlanned, isFalse);
    expect(saved?.diveNumber, 1);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_planned_test.dart`
Expected: FAIL to compile on `PlannedDiveBanner`.

- [ ] **Step 3: Add strings (11 ARBs, `flutter gen-l10n`), the banner and the action**

```dart
// lib/features/dive_log/presentation/widgets/planned_dive_banner.dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Shown above the header of a planned dive: awaiting dive computer data,
/// with the promote action.
class PlannedDiveBanner extends StatelessWidget {
  final VoidCallback onMarkLogged;

  const PlannedDiveBanner({super.key, required this.onMarkLogged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.diveLog_planned_bannerTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    context.l10n.diveLog_planned_bannerBody,
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onMarkLogged,
              child: Text(context.l10n.diveLog_detail_menu_markLogged),
            ),
          ],
        ),
      ),
    );
  }
}
```

In `dive_detail_page.dart`:
- Directly before the `SiteSuggestionCard` line at 1076-1083, add `if (dive.isPlanned) PlannedDiveBanner(onMarkLogged: () => _markAsLogged(dive)),` (in both the full and the embedded layouts if the embedded one renders its own top area; check `_buildEmbeddedHeader`).
- Add the method:

```dart
  Future<void> _markAsLogged(Dive dive) async {
    final container = ProviderScope.containerOf(context, listen: false);
    await ref.read(diveRepositoryProvider).convertPlanToActualDive(dive.id);
    container.invalidate(diveProvider(dive.id));
    container.invalidate(paginatedDiveListProvider);
    container.invalidate(diveListNotifierProvider);
    container.invalidate(divesProvider);
    container.invalidate(diveStatisticsProvider);
    container.invalidate(diveNumberingInfoProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.diveLog_planned_markedLogged)),
    );
  }
```

- In both `PopupMenuButton` `onSelected` switches add `case 'markLogged': await _markAsLogged(dive);` and in both `itemBuilder` lists, right after the `logNearMiss` item, add:

```dart
              if (dive.isPlanned)
                PopupMenuItem(
                  value: 'markLogged',
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(context.l10n.diveLog_detail_menu_markLogged),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
```

- [ ] **Step 4: Add the list chip**

`dive_list_page.dart`, in the badge row before the `isFavorite` block:

```dart
                              if (summary?.isPlanned == true) ...[
                                const SizedBox(width: 6),
                                _PlannedChip(),
                              ],
```

with a small private widget in the same file:

```dart
class _PlannedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.diveLog_planned_chip,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onTertiaryContainer,
        ),
      ),
    );
  }
}
```

Check how the tile receives its data (`summary` versus `dive`) and read `isPlanned` from whichever it holds. Add the same chip to `compact_dive_list_tile.dart` next to the `DiveModeBadge` at 352, using the compact tile's own data object.

Write `test/features/dive_log/presentation/pages/dive_list_planned_chip_test.dart` by copying an existing `DiveListTile` test and asserting `find.text('Planned')` appears for a planned summary and not for a logged one.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_planned_test.dart test/features/dive_log/presentation/pages/dive_list_planned_chip_test.dart test/features/dive_log/presentation/`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "i18n(dive-log): strings for planned dives

Refs #2002"
git add lib/features/dive_log/presentation/widgets/planned_dive_banner.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/dive_list_page.dart lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart test/features/dive_log/presentation/pages/dive_detail_planned_test.dart test/features/dive_log/presentation/pages/dive_list_planned_chip_test.dart
git commit -m "feat(dive-log): show planned dives and promote them from the detail page

Refs #2002"
```

---

### Task 11: Mirror field classification and `DiveMirrorService`

**Files:**
- Create: `lib/features/dive_log/domain/services/dive_mirror_fields.dart`
- Create: `lib/features/dive_log/data/services/dive_mirror_service.dart`
- Create: `lib/features/dive_log/presentation/providers/dive_mirror_providers.dart`
- Test: `test/features/dive_log/domain/services/dive_mirror_fields_test.dart`, `test/features/dive_log/data/services/dive_mirror_service_test.dart`

**Interfaces:**
- Consumes: `Dive.outingId`, `DiveRepository.createDive/getDiveById/getDivesByOutingId/bulkDeleteDives/updateDive`, `BuddyRepository.getBuddiesForDive/setBuddiesForDive/getAllBuddies/createBuddy`, `BuddyProfileLinkRepository.ensureReciprocalBuddy/linkedBuddyFor`, `DiverRepository.getDiverById`, `SiteRepository.getSiteById/setShared`, `TripRepository.getTripById`, `DiveCenterRepository.getDiveCenterById`, `DiveTypeRepository.getAllDiveTypes`, `TagRepository.getAllTags`, `DiveRoleRepository.getAllDiveRoles`, `DiveRole.buddyId`.
- Produces: `mirroredDiveFrom(...)`, `kMirroredDiveFields`, `kUnmirroredDiveFields`, `DiveMirrorService.candidates/mirror/undo`, `MirrorCandidate`, `MirrorOutcome`, providers `diveMirrorServiceProvider`, `siblingDivesProvider(diveId)`, `mirrorCandidatesProvider(diveId)`.

Every repository in this codebase is constructed with no arguments and reads the database through `DatabaseService.instance` (see `test/helpers/test_database.dart`), so the service can construct its collaborators itself and the tests only need `setUpTestDatabase()`.

- [ ] **Step 1: Write the failing field-census test**

```dart
// test/features/dive_log/domain/services/dive_mirror_fields_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/services/dive_mirror_fields.dart';

/// Every Dive constructor parameter must be classified as mirrored or not,
/// so a new column cannot silently leak into (or vanish from) a sibling.
void main() {
  test('every Dive field is classified exactly once', () {
    final source = File('lib/features/dive_log/domain/entities/dive.dart')
        .readAsStringSync();
    final start = source.indexOf('  const Dive({');
    final end = source.indexOf('\n  });', start);
    final ctor = source.substring(start, end);
    final params = RegExp(r'this\.(\w+)')
        .allMatches(ctor)
        .map((m) => m.group(1)!)
        .toSet();
    expect(params.length, greaterThan(60));

    final classified = kMirroredDiveFields.union(kUnmirroredDiveFields);
    expect(kMirroredDiveFields.intersection(kUnmirroredDiveFields), isEmpty);
    expect(params.difference(classified), isEmpty,
        reason: 'unclassified Dive fields');
    expect(classified.difference(params), isEmpty,
        reason: 'classified names that are not Dive fields');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/dive_mirror_fields_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the classification**

Read the `const Dive({` constructor in `dive.dart` and place every parameter name in exactly one set. The mirrored set holds the shared facts from the spec; everything else is unmirrored. Start from this list and add whatever the constructor has that is missing (the test tells you):

```dart
// lib/features/dive_log/domain/services/dive_mirror_fields.dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Dive fields copied onto a sibling created by the mirror flow (issue
/// #2002): the facts two divers on the same dive share. Identity, ownership
/// and references are set by the service, so they are listed here only to
/// make the census exhaustive.
const Set<String> kMirroredDiveFields = {
  // identity and ownership (set by the service, not copied verbatim)
  'id', 'diverId', 'outingId', 'isPlanned', 'diverRoleId',
  // when
  'dateTime', 'entryTime', 'exitTime',
  // where (resolved per profile by the service)
  'site', 'siteId', 'trip', 'tripId', 'diveCenter', 'diveCenterId',
  'altitude', 'surfacePressure', 'waterType',
  // conditions
  'waterTemp', 'airTemp', 'visibility', 'visibilityMeters',
  'currentDirection', 'currentStrength', 'swellHeight',
  'surfaceConditions', 'entryMethod', 'exitMethod', 'weatherCode',
  // logistics
  'boatName', 'boatCaptain', 'diveOperator',
  // what kind of dive
  'diveType', 'diveTypeIds', 'tags', 'diveMode',
};

/// Dive fields that stay with the source: the diver's own measurements,
/// gear, opinions and provenance.
const Set<String> kUnmirroredDiveFields = {
  'diveNumber', 'name', 'bottomTime', 'runtime', 'maxDepth', 'avgDepth',
  'buddy', 'diveMaster', 'notes', 'rating', 'isFavorite',
  'excludedFromStats', 'excludedFromGasStats',
  'surfaceInterval', 'surfaceIntervalSeconds',
  'gradientFactorLow', 'gradientFactorHigh', 'decoAlgorithm',
  'decoConservatism', 'diveComputerModel', 'diveComputerSerial',
  'diveComputerFirmware', 'computerId', 'weightAmount', 'weightType',
  'weightingFeedback', 'weightingFeedbackKg', 'cnsStart', 'cnsEnd', 'otu',
  'setpointLow', 'setpointHigh', 'setpointDeco', 'scrType',
  'tanks', 'weights', 'equipment', 'profile', 'photoIds', 'customFields',
  'courseId', 'importId', 'createdAt', 'updatedAt',
};

/// The sibling dive for [targetDiverId], before references are resolved.
/// [siteId], [tripId], [diveCenterId], [diveTypeIds], [tags] and
/// [diverRoleId] are passed in already resolved for the target profile.
Dive mirroredDiveFrom(
  Dive source, {
  required String targetDiverId,
  required String outingId,
  required String? siteId,
  required String? tripId,
  required String? diveCenterId,
  required List<String> diveTypeIds,
  required List<Tag> tags,
  required String? diverRoleId,
}) {
  return Dive(
    id: '',
    diverId: targetDiverId,
    outingId: outingId,
    isPlanned: true,
    diverRoleId: diverRoleId,
    dateTime: source.dateTime,
    entryTime: source.entryTime,
    exitTime: source.exitTime,
    siteId: siteId,
    tripId: tripId,
    diveCenterId: diveCenterId,
    altitude: source.altitude,
    surfacePressure: source.surfacePressure,
    waterType: source.waterType,
    waterTemp: source.waterTemp,
    airTemp: source.airTemp,
    visibility: source.visibility,
    visibilityMeters: source.visibilityMeters,
    currentDirection: source.currentDirection,
    currentStrength: source.currentStrength,
    swellHeight: source.swellHeight,
    surfaceConditions: source.surfaceConditions,
    entryMethod: source.entryMethod,
    exitMethod: source.exitMethod,
    weatherCode: source.weatherCode,
    boatName: source.boatName,
    boatCaptain: source.boatCaptain,
    diveOperator: source.diveOperator,
    diveTypeIds: diveTypeIds,
    tags: tags,
    diveMode: source.diveMode,
  );
}
```

Adjust names to the real constructor (some of the above may be named differently or absent; the census test is the authority). Import `Tag` from wherever `Dive` imports it. If `Dive` exposes `siteId` only through `site`, pass a `DiveSite` fetched by id instead; check how `createDive` derives the `site_id` column (line ~1445).

- [ ] **Step 4: Run the census test**

Run: `flutter test test/features/dive_log/domain/services/dive_mirror_fields_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing service tests**

```dart
// test/features/dive_log/data/services/dive_mirror_service_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository dives;
  late BuddyRepository buddies;
  late DiverRepository divers;
  late SiteRepository sites;
  late DiveMirrorService service;
  late String eric;
  late String chris;
  late Buddy chrisBuddy;

  Future<String> diver(String name) async => (await divers.createDiver(Diver(
        id: '', name: name, createdAt: DateTime(2026), updatedAt: DateTime(2026),
      ))).id;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    buddies = BuddyRepository();
    divers = DiverRepository();
    sites = SiteRepository();
    service = DiveMirrorService();
    eric = await diver('Eric');
    chris = await diver('Chris');
    chrisBuddy = await buddies.createBuddy(Buddy(
      id: '', diverId: eric, linkedDiverId: chris, name: 'Chris',
      createdAt: DateTime(2026), updatedAt: DateTime(2026)));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Dive> sourceDive({String? siteId, String? diverRoleId}) async {
    final dive = await dives.createDive(Dive(
      id: '', diverId: eric, dateTime: DateTime(2026, 6, 1, 9),
      entryTime: DateTime(2026, 6, 1, 9), exitTime: DateTime(2026, 6, 1, 9, 45),
      siteId: siteId, waterTemp: 18, notes: 'private', rating: 5,
      diverRoleId: diverRoleId, diveNumber: 12,
    ));
    await buddies.setBuddiesForDive(dive.id, [
      BuddyWithRole(buddy: chrisBuddy, role: DiveRole.builtIn(DiveRole.buddyId)),
    ]);
    return dive;
  }

  test('candidates lists linked buddies with no sibling yet', () async {
    final dive = await sourceDive();
    final cands = await service.candidates(dive.id);
    expect(cands.map((c) => c.diver.id), [chris]);
  });

  test('mirror creates a planned sibling owned by the buddy profile', () async {
    final dive = await sourceDive();
    final outcome = await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.diverId, chris);
    expect(sibling?.isPlanned, isTrue);
    expect(sibling?.diveNumber, isNull);
    expect(sibling?.outingId, outcome.outingId);
    expect((await dives.getDiveById(dive.id))?.outingId, outcome.outingId);
    expect(sibling?.waterTemp, 18);
    expect(sibling?.entryTime, DateTime(2026, 6, 1, 9));
    // unmirrored
    expect(sibling?.notes, '');
    expect(sibling?.rating, isNull);
  });

  test('the source diver becomes a linked buddy on the sibling', () async {
    final dive = await sourceDive();
    final outcome = await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
    final siblingBuddies = await buddies.getBuddiesForDive(outcome.createdDiveIds.single);
    expect(siblingBuddies.single.buddy.linkedDiverId, eric);
    expect(siblingBuddies.single.buddy.diverId, chris);
    expect(siblingBuddies.single.buddy.name, 'Eric');
  });

  test('the target takes the role its buddy held on the source', () async {
    final dive = await sourceDive();
    final outcome = await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
    final sibling = await dives.getDiveById(outcome.createdDiveIds.single);
    expect(sibling?.diverRoleId, DiveRole.buddyId);
  });

  test('other buddies are matched by name or created in the target list', () async {
    final dave = await buddies.createBuddy(Buddy(
      id: '', diverId: eric, name: 'Dave', email: 'dave@example.com',
      createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    final dive = await sourceDive();
    await buddies.setBuddiesForDive(dive.id, [
      BuddyWithRole(buddy: chrisBuddy, role: DiveRole.builtIn(DiveRole.buddyId)),
      BuddyWithRole(buddy: dave, role: DiveRole.builtIn(DiveRole.buddyId)),
    ]);
    final outcome = await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
    final names = (await buddies.getBuddiesForDive(outcome.createdDiveIds.single))
        .map((b) => b.buddy.name).toSet();
    expect(names, {'Eric', 'Dave'});
    final chrisList = await buddies.getAllBuddies(diverId: chris);
    expect(chrisList.firstWhere((b) => b.name == 'Dave').email, 'dave@example.com');
  });

  test('an unshared site becomes shared', () async {
    final site = await sites.createSite(DiveSite(
      id: '', name: 'Blue Hole', diverId: eric, createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    final dive = await sourceDive(siteId: site.id);
    final outcome = await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
    expect((await sites.getSiteById(site.id))?.isShared, isTrue);
    expect((await dives.getDiveById(outcome.createdDiveIds.single))?.site?.id, site.id);
  });

  test('candidates is empty once a sibling exists, and mirror is idempotent', () async {
    final dive = await sourceDive();
    await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
    expect(await service.candidates(dive.id), isEmpty);
    final again = await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
    expect(again.createdDiveIds, isEmpty);
    expect((await dives.getDivesByOutingId(again.outingId)).length, 2);
  });

  test('undo removes the siblings and a minted outing id', () async {
    final dive = await sourceDive();
    final outcome = await service.mirror(sourceDiveId: dive.id, targetDiverIds: [chris]);
    await service.undo(outcome);
    expect(await dives.getDiveById(outcome.createdDiveIds.single), isNull);
    expect((await dives.getDiveById(dive.id))?.outingId, isNull);
  });
}
```

Fix constructor names against the real entities (`DiveSite` required fields, `BuddyWithRole`, `DiveRole.builtIn` or whatever factory yields the built-in buddy role; grep `dive_role.dart:60-75`).

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/features/dive_log/data/services/dive_mirror_service_test.dart`
Expected: FAIL to compile.

- [ ] **Step 7: Write the service**

```dart
// lib/features/dive_log/data/services/dive_mirror_service.dart
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_mirror_fields.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

/// A linked buddy on a dive whose profile has no sibling of it yet.
typedef MirrorCandidate = ({Buddy buddy, Diver diver});

/// What one mirror action wrote, enough to undo it.
class MirrorOutcome {
  final String sourceDiveId;
  final String outingId;

  /// True when this action stamped the outing id on the source, so undo
  /// clears it again.
  final bool mintedOutingId;
  final List<String> createdDiveIds;

  const MirrorOutcome({
    required this.sourceDiveId,
    required this.outingId,
    required this.mintedOutingId,
    required this.createdDiveIds,
  });
}

/// Logs a dive into the profiles of its linked buddies as planned sibling
/// dives sharing one outing id (issue #2002).
class DiveMirrorService {
  final DiveRepository _dives;
  final BuddyRepository _buddies;
  final BuddyProfileLinkRepository _links;
  final DiverRepository _divers;
  final SiteRepository _sites;
  final TripRepository _trips;
  final DiveCenterRepository _centers;
  final DiveTypeRepository _types;
  final TagRepository _tags;
  final DiveRoleRepository _roles;
  final _uuid = const Uuid();

  DiveMirrorService({
    DiveRepository? dives,
    BuddyRepository? buddies,
    BuddyProfileLinkRepository? links,
    DiverRepository? divers,
    SiteRepository? sites,
    TripRepository? trips,
    DiveCenterRepository? centers,
    DiveTypeRepository? types,
    TagRepository? tags,
    DiveRoleRepository? roles,
  }) : _dives = dives ?? DiveRepository(),
       _buddies = buddies ?? BuddyRepository(),
       _divers = divers ?? DiverRepository(),
       _sites = sites ?? SiteRepository(),
       _trips = trips ?? TripRepository(),
       _centers = centers ?? DiveCenterRepository(),
       _types = types ?? DiveTypeRepository(),
       _tags = tags ?? TagRepository(),
       _roles = roles ?? DiveRoleRepository(),
       _links =
           links ??
           BuddyProfileLinkRepository(
             buddies: buddies ?? BuddyRepository(),
             divers: divers ?? DiverRepository(),
           );

  /// Linked buddies on [diveId] whose profile owns no dive in its outing.
  Future<List<MirrorCandidate>> candidates(String diveId) async {
    final dive = await _dives.getDiveById(diveId);
    if (dive == null) return const [];
    final siblingsOwners = <String>{};
    if (dive.outingId != null) {
      for (final d in await _dives.getDivesByOutingId(dive.outingId!)) {
        if (d.diverId != null) siblingsOwners.add(d.diverId!);
      }
    }
    final result = <MirrorCandidate>[];
    for (final bwr in await _buddies.getBuddiesForDive(diveId)) {
      final linked = bwr.buddy.linkedDiverId;
      if (linked == null || linked == dive.diverId) continue;
      if (siblingsOwners.contains(linked)) continue;
      final diver = await _divers.getDiverById(linked);
      if (diver == null) continue;
      result.add((buddy: bwr.buddy, diver: diver));
    }
    return result;
  }

  /// Creates one planned sibling per target profile. Targets that already
  /// own a dive in the outing are skipped, so the call is idempotent.
  Future<MirrorOutcome> mirror({
    required String sourceDiveId,
    required List<String> targetDiverIds,
  }) async {
    final db = DatabaseService.instance.database;
    return db.transaction(() async {
      final source = await _dives.getDiveById(sourceDiveId);
      if (source == null) {
        throw StateError('Source dive $sourceDiveId does not exist');
      }
      final minted = source.outingId == null;
      final outingId = source.outingId ?? _uuid.v4();
      if (minted) {
        await _dives.updateDive(source.copyWith(outingId: outingId));
      }
      final existingOwners = {
        for (final d in await _dives.getDivesByOutingId(outingId))
          if (d.diverId != null) d.diverId!,
      };
      final sourceBuddies = await _buddies.getBuddiesForDive(sourceDiveId);
      final created = <String>[];
      for (final target in targetDiverIds) {
        if (existingOwners.contains(target)) continue;
        final id = await _createSibling(
          source: source,
          sourceBuddies: sourceBuddies,
          targetDiverId: target,
          outingId: outingId,
        );
        created.add(id);
      }
      return MirrorOutcome(
        sourceDiveId: sourceDiveId,
        outingId: outingId,
        mintedOutingId: minted,
        createdDiveIds: created,
      );
    });
  }

  /// Deletes the siblings this outcome created and clears the outing id
  /// from the source when this action minted it. Buddy records stay.
  Future<void> undo(MirrorOutcome outcome) async {
    final db = DatabaseService.instance.database;
    await db.transaction(() async {
      if (outcome.createdDiveIds.isNotEmpty) {
        await _dives.bulkDeleteDives(outcome.createdDiveIds);
      }
      if (outcome.mintedOutingId) {
        final source = await _dives.getDiveById(outcome.sourceDiveId);
        if (source != null) {
          await _dives.updateDive(source.copyWith(clearOutingId: true));
        }
      }
    });
  }

  Future<String> _createSibling({
    required Dive source,
    required List<BuddyWithRole> sourceBuddies,
    required String targetDiverId,
    required String outingId,
  }) async {
    final sourceOwner = source.diverId;
    final sourceRoleId = source.diverRoleId ?? DiveRole.buddyId;

    // The target's own role: what its buddy held on the source.
    String? targetRoleId;
    for (final bwr in sourceBuddies) {
      if (bwr.buddy.linkedDiverId == targetDiverId) {
        targetRoleId = bwr.role.id;
      }
    }

    final dive = mirroredDiveFrom(
      source,
      targetDiverId: targetDiverId,
      outingId: outingId,
      siteId: await _shareSite(source.site?.id),
      tripId: await _sharedTripId(source.tripId),
      diveCenterId: await _visibleCenterId(source.diveCenter?.id),
      diveTypeIds: await _resolveTypeIds(source.diveTypeIds, targetDiverId),
      tags: await _resolveTags(source.tags, targetDiverId),
      diverRoleId: await _resolveRoleId(targetRoleId, targetDiverId),
    );
    final created = await _dives.createDive(dive);

    final members = <BuddyWithRole>[];
    if (sourceOwner != null) {
      final me = await _links.ensureReciprocalBuddy(
        ownerDiverId: targetDiverId,
        linkedDiverId: sourceOwner,
      );
      members.add(
        BuddyWithRole(
          buddy: me,
          role: await _roleFor(sourceRoleId, targetDiverId),
        ),
      );
    }
    for (final bwr in sourceBuddies) {
      if (bwr.buddy.linkedDiverId == targetDiverId) continue;
      final buddy = await _buddyInList(bwr.buddy, targetDiverId);
      members.add(
        BuddyWithRole(
          buddy: buddy,
          role: await _roleFor(bwr.role.id, targetDiverId),
        ),
      );
    }
    await _buddies.setBuddiesForDive(created.id, members);
    return created.id;
  }

  /// A site shared by two profiles is shared; flip the flag if needed.
  Future<String?> _shareSite(String? siteId) async {
    if (siteId == null) return null;
    final site = await _sites.getSiteById(siteId);
    if (site == null) return null;
    if (!site.isShared) await _sites.setShared(siteId, true);
    return siteId;
  }

  Future<String?> _sharedTripId(String? tripId) async {
    if (tripId == null) return null;
    final trip = await _trips.getTripById(tripId);
    return (trip?.isShared ?? false) ? tripId : null;
  }

  Future<String?> _visibleCenterId(String? centerId) async {
    if (centerId == null) return null;
    final center = await _centers.getDiveCenterById(centerId);
    if (center == null) return null;
    return center.diverId == null ? centerId : null;
  }

  Future<List<String>> _resolveTypeIds(
    List<String> sourceIds,
    String targetDiverId,
  ) async {
    if (sourceIds.isEmpty) return const [];
    final all = await _types.getAllDiveTypes();
    final targetVisible = await _types.getAllDiveTypes(diverId: targetDiverId);
    final byName = {for (final t in targetVisible) t.name.trim().toLowerCase(): t};
    final result = <String>[];
    for (final id in sourceIds) {
      final type = all.where((t) => t.id == id).firstOrNull;
      if (type == null) continue;
      if (type.isBuiltIn) {
        result.add(id);
        continue;
      }
      final match = byName[type.name.trim().toLowerCase()];
      if (match != null) result.add(match.id);
    }
    return result;
  }

  Future<List<Tag>> _resolveTags(List<Tag> sourceTags, String targetDiverId) async {
    if (sourceTags.isEmpty) return const [];
    final targetTags = await _tags.getAllTags(diverId: targetDiverId);
    final byName = {for (final t in targetTags) t.name.trim().toLowerCase(): t};
    return [
      for (final tag in sourceTags)
        if (byName[tag.name.trim().toLowerCase()] case final match?) match,
    ];
  }

  Future<String?> _resolveRoleId(String? roleId, String targetDiverId) async {
    if (roleId == null) return null;
    return (await _roleFor(roleId, targetDiverId)).id;
  }

  /// Built-in roles are shared by id; a custom role is matched by name in
  /// the target's list and falls back to the built-in buddy role.
  Future<DiveRole> _roleFor(String roleId, String targetDiverId) async {
    final visible = await _roles.getAllDiveRoles(diverId: targetDiverId);
    final direct = visible.where((r) => r.id == roleId).firstOrNull;
    if (direct != null && direct.isBuiltIn) return direct;
    final all = await _roles.getAllDiveRoles();
    final source = all.where((r) => r.id == roleId).firstOrNull;
    if (source == null) return visible.firstWhere((r) => r.id == DiveRole.buddyId);
    final byName = visible
        .where((r) => r.name.trim().toLowerCase() == source.name.trim().toLowerCase())
        .firstOrNull;
    return byName ?? visible.firstWhere((r) => r.id == DiveRole.buddyId);
  }

  /// The buddy in the target's list that is [sourceBuddy]: matched by link,
  /// then by exact trimmed name, else created with the same details.
  Future<Buddy> _buddyInList(Buddy sourceBuddy, String targetDiverId) async {
    if (sourceBuddy.linkedDiverId != null) {
      return _links.ensureReciprocalBuddy(
        ownerDiverId: targetDiverId,
        linkedDiverId: sourceBuddy.linkedDiverId!,
      );
    }
    final list = await _buddies.getAllBuddies(diverId: targetDiverId);
    final wanted = sourceBuddy.name.trim();
    for (final b in list) {
      if (b.name.trim() == wanted) return b;
    }
    final now = DateTime.now();
    return _buddies.createBuddy(
      Buddy(
        id: '',
        diverId: targetDiverId,
        name: sourceBuddy.name,
        email: sourceBuddy.email,
        phone: sourceBuddy.phone,
        photo: sourceBuddy.photo,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
```

Notes for the implementer:
- `Dive.copyWith(clearOutingId: true)` was added in Task 3.
- `getAllDiveRoles({diverId})` returns built-ins plus the diver's custom roles (see `dive_role_repository.dart:59-75`); `getAllDiveTypes` behaves the same (`dive_type_repository.dart:31-50`).
- `getBuddiesForDive` returns `BuddyWithRole` with a resolved `DiveRole`; `setBuddiesForDive(diveId, List<BuddyWithRole>)` marks the links pending (`buddy_repository.dart:533-581`).
- Every write happens inside one `db.transaction`; the repositories share the same connection through `DatabaseService`, so nested calls join it.
- `createDive` hoists child ids before its batch and marks them pending; the mirror needs no extra pending marks beyond what the repositories do.

- [ ] **Step 8: Add the providers**

```dart
// lib/features/dive_log/presentation/providers/dive_mirror_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

final diveMirrorServiceProvider = Provider<DiveMirrorService>(
  (ref) => DiveMirrorService(dives: ref.watch(diveRepositoryProvider)),
);

/// The other dives in this dive's outing, with their owners' names resolved
/// by the widget. Empty for a dive with no outing.
final siblingDivesProvider = FutureProvider.autoDispose.family<List<Dive>, String>(
  (ref, diveId) async {
    final repository = ref.watch(diveRepositoryProvider);
    ref.invalidateSelfWhen(repository.watchDivesChanges());
    final dive = await repository.getDiveById(diveId);
    final outingId = dive?.outingId;
    if (outingId == null) return const [];
    return [
      for (final d in await repository.getDivesByOutingId(outingId))
        if (d.id != diveId) d,
    ];
  },
);

final mirrorCandidatesProvider =
    FutureProvider.autoDispose.family<List<MirrorCandidate>, String>(
  (ref, diveId) => ref.watch(diveMirrorServiceProvider).candidates(diveId),
);
```

Check that `invalidateSelfWhen` and `watchDivesChanges` exist with those names (`dive_providers.dart:312`); if the extension lives elsewhere, import it.

- [ ] **Step 9: Run the tests and the architecture guards**

Run: `flutter test test/features/dive_log/data/services/dive_mirror_service_test.dart test/features/dive_log/domain/services/dive_mirror_fields_test.dart test/features/dive_log/domain/entities/ test/architecture/`
Expected: all PASS.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/features/dive_log/domain/services/dive_mirror_fields.dart lib/features/dive_log/data/services/dive_mirror_service.dart lib/features/dive_log/presentation/providers/dive_mirror_providers.dart lib/features/dive_log/domain/entities/dive.dart test/features/dive_log/domain/services/dive_mirror_fields_test.dart test/features/dive_log/data/services/dive_mirror_service_test.dart
git commit -m "feat(dive-log): mirror a dive into a linked buddy's profile

Creates a planned sibling per target profile sharing one outing id,
copies the shared facts, resolves site, trip, types, tags and roles per
profile, and rebuilds the buddy group with a reciprocal linked buddy.

Refs #2002"
```

---

### Task 12: Mirror dialog after save, snackbar with Undo, detail-page action

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/mirror_dive_dialog.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (save tail, before the navigation block at 5344)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (both overflow menus)
- Modify: ARB files and regenerate
- Test: `test/features/dive_log/presentation/widgets/mirror_dive_dialog_test.dart`

ARB keys (anchor on `diveLog_detail_menu_logNearMiss`):

| key | en |
| --- | --- |
| `diveLog_mirror_dialogTitle` | Also log this dive in another profile? |
| `diveLog_mirror_dialogBody` | These buddies have profiles on this device. The dive is added to their logs as a planned dive until their own dive computer data fills it. |
| `diveLog_mirror_log` | Log |
| `diveLog_mirror_notNow` | Not now |
| `diveLog_mirror_snackbar` | Logged for {names} (placeholder `names`) |
| `diveLog_mirror_undone` | Mirrored dives removed |
| `diveLog_mirror_failed` | Could not log for {names} (placeholder `names`) |
| `diveLog_detail_menu_logForBuddy` | Log for a buddy's profile |

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/dive_log/presentation/widgets/mirror_dive_dialog_test.dart
  testWidgets('lists candidates checked and returns the chosen diver ids', (tester) async {
    List<String>? chosen;
    await tester.pumpWidget(testApp(
      locale: const Locale('en'),
      child: Builder(builder: (context) => TextButton(
        onPressed: () async {
          chosen = await showMirrorDiveDialog(context, candidates: [
            (buddy: chrisBuddy, diver: chrisDiver),
            (buddy: danaBuddy, diver: danaDiver),
          ]);
        },
        child: const Text('open'))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Also log this dive in another profile?'), findsOneWidget);
    await tester.tap(find.text('Dana')); // uncheck
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    expect(chosen, ['chris']);
  });

  testWidgets('Not now returns null', (tester) async { /* ... expect(chosen, isNull) */ });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/mirror_dive_dialog_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Add strings (11 ARBs, `flutter gen-l10n`) and write the dialog and runner**

```dart
// lib/features/dive_log/presentation/widgets/mirror_dive_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Asks which linked buddies' profiles should receive the dive. Returns the
/// chosen diver ids, or null for "Not now".
Future<List<String>?> showMirrorDiveDialog(
  BuildContext context, {
  required List<MirrorCandidate> candidates,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => _MirrorDiveDialog(candidates: candidates),
  );
}

class _MirrorDiveDialog extends StatefulWidget {
  final List<MirrorCandidate> candidates;
  const _MirrorDiveDialog({required this.candidates});

  @override
  State<_MirrorDiveDialog> createState() => _MirrorDiveDialogState();
}

class _MirrorDiveDialogState extends State<_MirrorDiveDialog> {
  late Set<String> _selected = {for (final c in widget.candidates) c.diver.id};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.diveLog_mirror_dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.diveLog_mirror_dialogBody),
          const SizedBox(height: 12),
          for (final c in widget.candidates)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(c.diver.id),
              secondary: ProfileAvatar(
                photo: c.diver.photo ?? c.buddy.photo,
                initials: c.diver.initials,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              title: Text(c.diver.name),
              onChanged: (checked) => setState(() {
                _selected = checked == true
                    ? {..._selected, c.diver.id}
                    : _selected.difference({c.diver.id});
              }),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.diveLog_mirror_notNow),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final c in widget.candidates)
                    if (_selected.contains(c.diver.id)) c.diver.id,
                ]),
          child: Text(l10n.diveLog_mirror_log),
        ),
      ],
    );
  }
}

/// Runs the mirror, shows the snackbar with View and Undo, and invalidates
/// the dive lists through [container] so it works after the caller's State
/// is gone (the edit page navigates away right after).
Future<void> runDiveMirror({
  required BuildContext context,
  required ProviderContainer container,
  required String sourceDiveId,
  required List<MirrorCandidate> chosen,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final names = chosen.map((c) => c.diver.name).join(', ');
  final service = container.read(diveMirrorServiceProvider);

  void refreshLists() {
    container.invalidate(paginatedDiveListProvider);
    container.invalidate(diveListNotifierProvider);
    container.invalidate(divesProvider);
    container.invalidate(diveStatisticsProvider);
  }

  final MirrorOutcome outcome;
  try {
    outcome = await service.mirror(
      sourceDiveId: sourceDiveId,
      targetDiverIds: [for (final c in chosen) c.diver.id],
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveLog_mirror_failed(names))),
    );
    return;
  }
  refreshLists();
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.diveLog_mirror_snackbar(names)),
      duration: const Duration(seconds: 6),
      persist: false,
      showCloseIcon: true,
      action: SnackBarAction(
        label: l10n.diveLog_bulkDelete_undo,
        onPressed: () async {
          await service.undo(outcome);
          refreshLists();
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.diveLog_mirror_undone)),
          );
        },
      ),
    ),
  );
}
```

One action per snackbar (Undo), as `run_dive_consolidation.dart` does; the sibling is reachable from the detail page's "Logged with" row (Task 13), so the `diveLog_mirror_view` key is reserved for a later View action and may be left out of this task's ARB batch. Import `diveMirrorServiceProvider` from Task 11's providers file; `persist:` is the app's SnackBar extension (see `run_dive_consolidation.dart:60`).

- [ ] **Step 4: Hook the edit page**

In `_saveDive`, after the buddies are written and before the navigation block (line ~5344), add:

```dart
      // Offer to log the dive for linked buddies (issue #2002). Runs before
      // navigation so the dialog has this page's context; the runner uses
      // the container so its snackbar and refresh outlive this State.
      if (mounted && savedDiveId != null && !_isPlanned) {
        final candidates = await ref
            .read(diveMirrorServiceProvider)
            .candidates(savedDiveId);
        if (candidates.isNotEmpty && mounted) {
          final chosenIds = await showMirrorDiveDialog(
            context,
            candidates: candidates,
          );
          if (chosenIds != null && chosenIds.isNotEmpty && mounted) {
            await runDiveMirror(
              context: context,
              container: ProviderScope.containerOf(context, listen: false),
              sourceDiveId: savedDiveId,
              chosen: [
                for (final c in candidates)
                  if (chosenIds.contains(c.diver.id)) c,
              ],
            );
          }
        }
      }
```

A planned dive being saved (`_isPlanned`) does not prompt: the spec mirrors logged dives, and a mirrored sibling is itself planned and must not cascade.

- [ ] **Step 5: Add the detail-page action**

In both overflow menus, after the `markLogged` item, add a conditional item whose visibility comes from `ref.watch(mirrorCandidatesProvider(dive.id)).valueOrNull?.isNotEmpty ?? false`:

```dart
              if (hasMirrorCandidates)
                PopupMenuItem(
                  value: 'logForBuddy',
                  child: ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: Text(context.l10n.diveLog_detail_menu_logForBuddy),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
```

and the `onSelected` case:

```dart
        case 'logForBuddy':
          final candidates = await ref.read(mirrorCandidatesProvider(dive.id).future);
          if (!context.mounted || candidates.isEmpty) return;
          final chosenIds = await showMirrorDiveDialog(context, candidates: candidates);
          if (chosenIds == null || chosenIds.isEmpty || !context.mounted) return;
          await runDiveMirror(
            context: context,
            container: ProviderScope.containerOf(context, listen: false),
            sourceDiveId: dive.id,
            chosen: [for (final c in candidates) if (chosenIds.contains(c.diver.id)) c],
          );
          ref.invalidate(mirrorCandidatesProvider(dive.id));
          ref.invalidate(siblingDivesProvider(dive.id));
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_log/presentation/widgets/mirror_dive_dialog_test.dart test/features/dive_log/presentation/pages/ test/architecture/`
Expected: all PASS. If an existing dive-edit test now fails with a provider-in-error on `diveMirrorServiceProvider`, the harness needs `diveRepositoryProvider` overridden (most already do); fix the harness, not the page.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "i18n(dive-log): strings for mirroring a dive

Refs #2002"
git add lib/features/dive_log/presentation/widgets/mirror_dive_dialog.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/mirror_dive_dialog_test.dart
git commit -m "feat(dive-log): offer to log a saved dive for linked buddies

Refs #2002"
```

---

### Task 13: "Logged with" tiles in the buddies card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/logged_with_tiles.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildBuddiesSection` 4649-4715)
- Modify: ARB files and regenerate
- Test: `test/features/dive_log/presentation/pages/dive_detail_logged_with_test.dart`

ARB keys (anchor on `diveLog_detail_menu_logNearMiss`):

| key | en |
| --- | --- |
| `diveLog_detail_loggedWith` | Logged with |
| `diveLog_detail_loggedWithPlanned` | awaiting their dive computer |

- [ ] **Step 1: Write the failing test**

Use `_buildDetailPage` from `dive_detail_page_test.dart`, overriding `siblingDivesProvider(dive.id)` with one sibling dive owned by `chris` and `diverByIdProvider('chris')`:

```dart
  testWidgets('shows each sibling with its owner name', (tester) async {
    final dive = Dive(id: 'd1', dateTime: DateTime(2026, 6, 1), outingId: 'o');
    final sibling = Dive(id: 'd2', diverId: 'chris', dateTime: DateTime(2026, 6, 1), outingId: 'o', isPlanned: true);
    await tester.pumpWidget(_buildDetailPage(dive, [
      ...await getBaseOverrides(),
      siblingDivesProvider('d1').overrideWith((ref) async => [sibling]),
      diverByIdProvider('chris').overrideWith((ref) async => Diver(id: 'chris', name: 'Chris', createdAt: DateTime(2026), updatedAt: DateTime(2026))),
      buddiesForDiveProvider('d1').overrideWith((ref) async => []),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Logged with'), findsOneWidget);
    expect(find.text('Chris'), findsOneWidget);
    expect(find.textContaining('awaiting their dive computer'), findsOneWidget);
  });

  testWidgets('no outing, no row', (tester) async {
    /* dive without outingId, siblingDivesProvider -> [] */
    expect(find.text('Logged with'), findsNothing);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_logged_with_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add strings and the widget**

```dart
// lib/features/dive_log/presentation/widgets/logged_with_tiles.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The sibling dives of [diveId] (other profiles' logs of the same outing),
/// one tile each, opening the sibling. Renders nothing without siblings.
class LoggedWithTiles extends ConsumerWidget {
  final String diveId;

  const LoggedWithTiles({super.key, required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siblings = ref.watch(siblingDivesProvider(diveId)).valueOrNull;
    if (siblings == null || siblings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            context.l10n.diveLog_detail_loggedWith,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final sibling in siblings) _SiblingTile(dive: sibling),
      ],
    );
  }
}

class _SiblingTile extends ConsumerWidget {
  final Dive dive;
  const _SiblingTile({required this.dive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = dive.diverId;
    final owner = ownerId == null
        ? null
        : ref.watch(diverByIdProvider(ownerId)).valueOrNull;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ProfileAvatar(
        photo: owner?.photo,
        initials: owner?.initials ?? '?',
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      title: Text(owner?.name ?? ''),
      subtitle: dive.isPlanned
          ? Text(context.l10n.diveLog_detail_loggedWithPlanned)
          : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push('/dives/${dive.id}'),
    );
  }
}
```

In `_buildBuddiesSection`, after the `...buddies.map(...)` tiles inside the card, add `LoggedWithTiles(diveId: diveId),`. The card must render when there are siblings even with no buddies; check the section's empty-state branch and include `siblings.isNotEmpty` in its "has content" condition (watch `siblingDivesProvider(diveId)` there too).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_logged_with_test.dart test/features/dive_log/presentation/pages/ test/architecture/`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "i18n(dive-log): strings for sibling dives

Refs #2002"
git add lib/features/dive_log/presentation/widgets/logged_with_tiles.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_logged_with_test.dart
git commit -m "feat(dive-log): open sibling dives from the buddies card

Refs #2002"
```

---

### Task 14: `importProfile` records a data source on the existing-dive branch; planned dives leave the fuzzy and contained passes

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (new-dive insert 1430-1487, existing-dive head 1489-1512, fuzzy SQL 935-945, containing-time SQL near 1070)
- Test: `test/features/dive_log/data/repositories/dive_computer_repository_existing_dive_source_test.dart`, `test/features/dive_computer/data/services/dive_import_service_planned_exclusion_test.dart`

**Interfaces:**
- Produces: after `importProfile` attaches to an existing dive, a `dive_data_sources` row for that computer exists (primary when the dive had no series), carrying `raw_fingerprint`, `source_uuid`, descriptor and summary numbers, and the series' `source_id` points at it. `findMatchingDiveWithScore` and `findComputerDivesContainingTime` never return a planned dive.

- [ ] **Step 1: Write the failing repository tests**

Copy the setup from `test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart:14-27` (`insertComputer`, `insertDive` helpers), then:

```dart
  group('attach to existing dive', () {
    test('inserts a primary data source with the fingerprint', () async {
      final computerId = await insertComputer();
      final diveId = await insertDive(start: DateTime(2026, 6, 1, 9));
      final fingerprint = Uint8List.fromList([1, 2, 3]);
      final returned = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 6, 1, 9, 2),
        points: [for (var t = 0; t <= 600; t += 10) ProfilePointData(timestamp: t, depth: 10)],
        durationSeconds: 600,
        maxDepth: 10,
        rawFingerprint: fingerprint,
      );
      expect(returned, diveId);
      final sources = await (db.select(db.diveDataSources)..where((t) => t.diveId.equals(diveId))).get();
      expect(sources, hasLength(1));
      expect(sources.single.isPrimary, isTrue);
      expect(sources.single.computerId, computerId);
      expect(sources.single.rawFingerprint, fingerprint);
      final series = await profileSeries.getRowsForDives([diveId]);
      expect(series.single.sourceId, sources.single.id);
    });

    test('a re-download of the attached profile is found by the fingerprint pass', () async {
      /* import as above, then */
      final keys = await DiveRepository().getSourceKeysByDiveId();
      expect(keys[diveId], contains('010203'));
    });

    test('a dive that already has a primary source gets a secondary row', () async {
      /* new-dive import from computer A (primary), then importProfile from computer B
         with forceNew false and a start within 5 minutes; assert two rows, B not primary */
    });
  });

  group('planned dives are invisible to matching', () {
    test('findMatchingDiveWithScore skips a planned dive', () async {
      await insertDive(start: DateTime(2026, 6, 1, 9), isPlanned: true);
      final match = await repository.findMatchingDiveWithScore(
        profileStartTime: DateTime(2026, 6, 1, 9, 1), durationSeconds: 600, maxDepth: 10);
      expect(match, isNull);
    });

    test('findComputerDivesContainingTime skips a planned dive', () async {
      /* planned dive with a series on computerId spanning the time */
      final hits = await repository.findComputerDivesContainingTime(
        computerId: computerId, time: DateTime(2026, 6, 1, 9, 5));
      expect(hits, isEmpty);
    });
  });
```

Extend `insertDive` with an `isPlanned` parameter (write `isPlanned: Value(true)` on the companion). Use `ProfilePointData`'s real constructor (grep `class ProfilePointData`).

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_repository_existing_dive_source_test.dart`
Expected: the data-source tests FAIL (no row); the planned tests FAIL (planned dive is returned).

- [ ] **Step 3: Extract the companion builder and insert on both branches**

In `importProfile`, replace the inline `DiveDataSourcesCompanion.insert(...)` in the new-dive branch with a call to a new private method, and call the same method on the existing-dive branch:

```dart
  DiveDataSourcesCompanion _downloadSourceCompanion({
    required String diveId,
    required String computerId,
    required bool isPrimary,
    required DiveComputer? computer,
    required DateTime profileStartTime,
    required int durationSeconds,
    required double? maxDepth,
    required double? effectiveAvgDepth,
    required double? minWaterTemp,
    required double? maxCns,
    required DateTime nowDt,
    required double? entryLatitude,
    required double? entryLongitude,
    required double? exitLatitude,
    required double? exitLongitude,
    required String? decoAlgorithm,
    required int? gfLow,
    required int? gfHigh,
    required Uint8List? rawData,
    required Uint8List? rawFingerprint,
    required String? descriptorVendor,
    required String? descriptorProduct,
    required int? descriptorModel,
    required String? libdivecomputerVersion,
  }) {
    return DiveDataSourcesCompanion.insert(
      id: _uuid.v4(),
      diveId: diveId,
      computerId: Value(computerId),
      isPrimary: Value(isPrimary),
      computerModel: Value(computer?.fullName),
      computerSerial: Value(computer?.serialNumber),
      sourceFormat: const Value('dive_computer'),
      maxDepth: Value(maxDepth),
      avgDepth: Value(effectiveAvgDepth),
      duration: Value(durationSeconds),
      waterTemp: Value(minWaterTemp),
      entryLatitude: Value(entryLatitude),
      entryLongitude: Value(entryLongitude),
      exitLatitude: Value(exitLatitude),
      exitLongitude: Value(exitLongitude),
      entryTime: Value(profileStartTime),
      exitTime: Value(profileStartTime.add(Duration(seconds: durationSeconds))),
      cns: Value(maxCns),
      decoAlgorithm: Value(decoAlgorithm),
      gradientFactorLow: Value(gfLow),
      gradientFactorHigh: Value(gfHigh),
      rawData: Value(rawData),
      rawFingerprint: Value(rawFingerprint),
      descriptorVendor: Value(descriptorVendor),
      descriptorProduct: Value(descriptorProduct),
      descriptorModel: Value(descriptorModel),
      libdivecomputerVersion: Value(libdivecomputerVersion),
      lastParsedAt: Value(rawData != null ? DateTime.now() : null),
      importedAt: nowDt,
      createdAt: nowDt,
    );
  }
```

Hoist `sampleTemps`/`minWaterTemp` and `nowDt` above the `if (isNewDive)` branch so both branches see them. Then, on the existing-dive path, directly after the `hadSeries` check (line ~1497) and before `_dataSourceIdFor` is read:

```dart
      // A profile attached to an existing dive used to leave no
      // dive_data_sources row, so its fingerprint was invisible to the
      // re-download pass and the series had no owning source (issue #2002).
      if (await _dataSourceIdFor(diveId, computerId) == null) {
        await _db.into(_db.diveDataSources).insert(
              _downloadSourceCompanion(
                diveId: diveId,
                computerId: computerId,
                isPrimary: !hadSeries,
                computer: computer,
                /* remaining named args as in the new-dive call */
              ),
            );
      }
```

`_dataSourceIdFor(diveId, computerId)` (line 791) returns the row for this computer, so the `replaceSource` path (which deletes the row first) also gets a fresh one, which is what its comment at 1755-1760 already claims happens.

- [ ] **Step 4: Exclude planned dives from the two match queries**

In `findMatchingDiveWithScore` change the WHERE to:

```sql
        WHERE ABS(COALESCE(entry_time, dive_date_time) - ?) <= ?
          AND is_planned = 0
          $diverClause
```

In `findComputerDivesContainingTime` add `AND d.is_planned = 0` after the computer clause. Add to both a comment: `// A planned dive holds no recorded data to match against; the wizard's planned pass pairs it separately (issue #2002).`

- [ ] **Step 5: Add the service-level exclusion test**

```dart
// test/features/dive_computer/data/services/dive_import_service_planned_exclusion_test.dart
// mockito setup copied from dive_import_service_test.dart:1-90
  test('detectDuplicate reports no match when the repository filters planned dives',
      () async {
    // The repository is where the filter lives; this pins that the service
    // passes the call straight through and returns noMatch on null.
    final result = await service.detectDuplicate(
      DownloadedDive(startTime: DateTime(2026, 6, 1, 9), durationSeconds: 600,
        maxDepth: 10, profile: const [], tanks: const [], events: const []),
    );
    expect(result.isDuplicate, isFalse);
    verify(mockComputerRepo.findMatchingDiveWithScore(
      profileStartTime: anyNamed('profileStartTime'),
      toleranceMinutes: anyNamed('toleranceMinutes'),
      durationSeconds: anyNamed('durationSeconds'),
      maxDepth: anyNamed('maxDepth'),
      diverId: anyNamed('diverId'))).called(1);
  });
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_repository_existing_dive_source_test.dart test/features/dive_computer/data/services/dive_import_service_planned_exclusion_test.dart test/features/dive_log/data/repositories/ test/features/dive_computer/`
Expected: all PASS. Watch `replace_source_gear_link_test.dart` and `issue_206_reimport_regression_test.dart`: they exercise the existing-dive branch and must still pass (the new row is idempotent per computer).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/features/dive_log/data/repositories/dive_computer_repository_existing_dive_source_test.dart test/features/dive_computer/data/services/dive_import_service_planned_exclusion_test.dart
git commit -m "fix(dive-computer): record a data source when a profile attaches to an existing dive

The existing-dive branch of importProfile never inserted the
dive_data_sources row, so the series had no owner and a re-download
was invisible to the fingerprint pass. Planned dives are also excluded
from the fuzzy and contained-segment matches; the wizard pairs them
on purpose.

Refs #2002"
```

---

### Task 15: `PlannedDiveMatcher` and the planned pass in the adapter

**Files:**
- Create: `lib/features/dive_computer/domain/services/planned_dive_matcher.dart`
- Modify: `lib/features/dive_import/domain/services/dive_matcher.dart` (`DiveMatchResult`, 79-146)
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` (`checkDuplicates` 421-474)
- Test: `test/features/dive_computer/domain/services/planned_dive_matcher_test.dart`, `test/features/import_wizard/data/adapters/dive_computer_adapter_fill_planned_test.dart` (first group)

**Interfaces:**
- Produces: `DiveMatchResult.plannedDiveId` (`String?`), `DiveMatchResult.isPlannedFill`, `DiveMatchResult.copyWith({String? plannedDiveId, bool clearPlannedDiveId})`; `PlannedDiveMatcher.pair({required List<DateTime> incomingStarts, required List<Dive> plannedDives}) -> Map<int, String>` (incoming index to planned dive id); the adapter marks every unmatched downloaded dive that pairs with a same-day planned dive as a duplicate with `plannedDiveId` set, `diveId` equal to the planned dive, `score` 1.0.

- [ ] **Step 1: Write the failing matcher test**

```dart
// test/features/dive_computer/domain/services/planned_dive_matcher_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/domain/services/planned_dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const matcher = PlannedDiveMatcher();
  Dive planned(String id, DateTime at) => Dive(id: id, dateTime: at, isPlanned: true);

  test('pairs a download with the only planned dive on the same local day', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 1, 14)],
      plannedDives: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, {0: 'p1'});
  });

  test('ignores a planned dive on another day', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 2, 9)],
      plannedDives: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, isEmpty);
  });

  test('pairs several downloads and planned dives in start-time order', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 1, 14), DateTime(2026, 6, 1, 9, 30)],
      plannedDives: [planned('pm', DateTime(2026, 6, 1, 13)), planned('am', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, {1: 'am', 0: 'pm'});
  });

  test('never suggests one planned dive twice', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 1, 9), DateTime(2026, 6, 1, 14)],
      plannedDives: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, {0: 'p1'});
  });

  test('uses entryTime over dateTime when present', () {
    final p = Dive(id: 'p', dateTime: DateTime(2026, 5, 31, 23), entryTime: DateTime(2026, 6, 1, 1), isPlanned: true);
    expect(matcher.pair(incomingStarts: [DateTime(2026, 6, 1, 8)], plannedDives: [p]), {0: 'p'});
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_computer/domain/services/planned_dive_matcher_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the matcher**

```dart
// lib/features/dive_computer/domain/services/planned_dive_matcher.dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Pairs downloaded dives with a profile's unfilled planned dives (issue
/// #2002). Pure: takes start times and entities, returns an index-to-id map.
///
/// Rule: same local calendar day, both lists sorted by start time, walked in
/// order so no planned dive is offered twice and the earliest download takes
/// the earliest plan. A day with more downloads than plans leaves the extra
/// downloads unpaired; more plans than downloads leaves plans unfilled.
class PlannedDiveMatcher {
  const PlannedDiveMatcher();

  Map<int, String> pair({
    required List<DateTime> incomingStarts,
    required List<Dive> plannedDives,
  }) {
    final incoming = [
      for (var i = 0; i < incomingStarts.length; i++)
        (index: i, start: incomingStarts[i].toLocal()),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final plans = [
      for (final d in plannedDives)
        (id: d.id, start: (d.entryTime ?? d.dateTime).toLocal()),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final byDay = <DateTime, List<({String id, DateTime start})>>{};
    for (final p in plans) {
      byDay.putIfAbsent(_day(p.start), () => []).add(p);
    }
    final result = <int, String>{};
    for (final inc in incoming) {
      final candidates = byDay[_day(inc.start)];
      if (candidates == null || candidates.isEmpty) continue;
      final taken = candidates.removeAt(0);
      result[inc.index] = taken.id;
    }
    return result;
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
```

- [ ] **Step 4: Extend `DiveMatchResult`**

Add to `DiveMatchResult`:

```dart
  /// When non-null, [diveId] is an unfilled PLANNED dive of the target
  /// profile on the same local day as the download (issue #2002). The
  /// wizard defaults such a row to [DuplicateAction.fillPlanned]; the
  /// planned dive keeps its human-entered facts and the download supplies
  /// the measured ones.
  final String? plannedDiveId;

  bool get isPlannedFill => plannedDiveId != null;
```

Constructor: `this.plannedDiveId,`. Add:

```dart
  DiveMatchResult copyWith({String? plannedDiveId, bool clearPlannedDiveId = false}) {
    return DiveMatchResult(
      diveId: clearPlannedDiveId ? '' : (plannedDiveId ?? diveId),
      score: score,
      timeDifferenceMs: timeDifferenceMs,
      depthDifferenceMeters: depthDifferenceMeters,
      durationDifferenceSeconds: durationDifferenceSeconds,
      siteName: siteName,
      matchedComputerId: matchedComputerId,
      matchedExistingSource: matchedExistingSource,
      inBatchIndex: inBatchIndex,
      plannedDiveId: clearPlannedDiveId ? null : (plannedDiveId ?? this.plannedDiveId),
    );
  }
```

(`diveId` tracks the planned dive so the comparison card and `existingDiveIdForIndex` show the right dive without new plumbing.)

- [ ] **Step 5: Add the planned pass to the adapter**

In `checkDuplicates`, after the loop and before building the bundle:

```dart
    // Planned pass (issue #2002): downloads that matched nothing may fill a
    // planned dive of the target profile on the same local day. Runs after
    // the fingerprint, fuzzy and contained passes so a real duplicate never
    // becomes a fill.
    final planned = await _diveRepository.getPlannedDives(diverId: _diverId);
    if (planned.isNotEmpty) {
      final unmatched = [
        for (var i = 0; i < _downloadedDives.length; i++)
          if (!duplicateIndices.contains(i)) i,
      ];
      final pairs = const PlannedDiveMatcher().pair(
        incomingStarts: [for (final i in unmatched) _downloadedDives[i].startTime],
        plannedDives: planned,
      );
      for (final entry in pairs.entries) {
        final index = unmatched[entry.key];
        duplicateIndices.add(index);
        matchResults[index] = DiveMatchResult(
          diveId: entry.value,
          score: 1.0,
          timeDifferenceMs: 0,
          plannedDiveId: entry.value,
        );
      }
    }
```

Pass `_diverId` as the planned-dive scope; when it is empty or null (legacy libraries), `getPlannedDives()` returns every planned dive, which is the right fallback.

- [ ] **Step 6: Write the adapter test (first group)**

Read `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart` for how the adapter is constructed with a fake download and mock repositories, then:

```dart
  group('planned pass', () {
    test('an unmatched download on a planned day gets plannedDiveId', () async {
      when(mockDiveRepo.getPlannedDives(diverId: anyNamed('diverId')))
          .thenAnswer((_) async => [Dive(id: 'p1', dateTime: DateTime(2026, 6, 1, 9), isPlanned: true)]);
      /* detectDuplicate stubbed to noMatch */
      final bundle = await adapter.checkDuplicates(bundleWithOneDive(start: DateTime(2026, 6, 1, 14)));
      final group = bundle.groups[ImportEntityType.dives]!;
      expect(group.duplicateIndices, {0});
      expect(group.matchResults![0]!.plannedDiveId, 'p1');
      expect(group.matchResults![0]!.diveId, 'p1');
    });

    test('a fingerprint hit is never turned into a fill', () async {
      /* detectDuplicate returns matchedExistingSource true for index 0 */
      expect(group.matchResults![0]!.plannedDiveId, isNull);
    });
  });
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/dive_computer/domain/services/planned_dive_matcher_test.dart test/features/import_wizard/data/adapters/ test/features/dive_import/`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/features/dive_computer/domain/services/planned_dive_matcher.dart lib/features/dive_import/domain/services/dive_matcher.dart lib/features/import_wizard/data/adapters/dive_computer_adapter.dart test/features/dive_computer/domain/services/planned_dive_matcher_test.dart test/features/import_wizard/data/adapters/dive_computer_adapter_fill_planned_test.dart
git commit -m "feat(import): pair downloads with same-day planned dives

Refs #2002"
```

---

### Task 16: `DuplicateAction.fillPlanned` plumbing (enum, switches, defaults, bulk guard, summary count)

**Files:**
- Modify: `lib/features/import_wizard/domain/models/duplicate_action.dart`
- Modify: every exhaustive switch: `review_step.dart:412, 615`, `duplicate_action_card.dart:88, 312`, `entity_review_list.dart:765, 1191`, `lib/core/presentation/widgets/dive_comparison_card.dart:433`
- Modify: `import_source_adapter.dart:58-65` (leave base set unchanged), `dive_computer_adapter.dart:337-348` (add to the set)
- Modify: `import_wizard_providers.dart` (`setBundle` 282-360, `applyBulkAction` 739-790)
- Modify: `dive_comparison_card.dart:448-503` (button), `unified_import_result.dart` (`filledCount`), `import_summary_step.dart` (row and `hasActivity`)
- Modify: ARB files and regenerate
- Test: `test/features/import_wizard/presentation/providers/import_wizard_fill_planned_test.dart`, `test/features/import_wizard/presentation/widgets/import_summary_filled_test.dart`

ARB keys (anchor on `universalImport_label_skip`):

| key | en |
| --- | --- |
| `universalImport_label_fillPlanned` | Fill planned dive |
| `universalImport_compare_fillPlannedSubtitle` | Attach this download to the dive you planned |
| `universalImport_label_filledPlanned` | Filled planned dives |
| `universalImport_fillPlanned_target` | Fills planned dive: {label} (placeholder `label`) |
| `universalImport_fillPlanned_replacesProfile` | Its sketched profile will be replaced. |
| `universalImport_fillPlanned_change` | Change |
| `universalImport_fillPlanned_pickerTitle` | Choose a planned dive |
| `universalImport_fillPlanned_importAsNew` | Import as a new dive instead |
| `universalImport_fillPlanned_undo` | Undo fills |
| `universalImport_fillPlanned_undone` | Planned dives restored |

- [ ] **Step 1: Write the failing provider test**

Read `test/features/import_wizard/presentation/providers/` for the existing `ImportWizardNotifier` harness (a fake adapter with `duplicateActionsFor`), then:

```dart
// test/features/import_wizard/presentation/providers/import_wizard_fill_planned_test.dart
  test('setBundle pre-selects fillPlanned for a planned match and keeps it selected', () {
    final bundle = bundleWith(matchResults: {
      0: const DiveMatchResult(diveId: 'p1', score: 1, timeDifferenceMs: 0, plannedDiveId: 'p1'),
    });
    notifier.setBundle(bundle);
    expect(notifier.state.duplicateActions[ImportEntityType.dives]![0], DuplicateAction.fillPlanned);
    expect(notifier.state.selections[ImportEntityType.dives], contains(0));
    expect(notifier.state.pendingFor(ImportEntityType.dives), isEmpty);
  });

  test('applyBulkAction never applies fillPlanned', () {
    notifier.setBundle(bundleWith(/* two fuzzy matches pending */));
    notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.fillPlanned);
    expect(notifier.state.duplicateActions[ImportEntityType.dives] ?? {}, isEmpty);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_fill_planned_test.dart`
Expected: FAIL to compile on `fillPlanned`.

- [ ] **Step 3: Add the enum member and satisfy every switch**

`duplicate_action.dart`:

```dart
  /// Attach the incoming item's measured data to a planned dive the diver
  /// entered ahead of time, then promote that dive (issue #2002).
  fillPlanned,
```

Run `flutter analyze` and fix each "missing case" error:
- `review_step.dart:412` `_actionLabel`: `DuplicateAction.fillPlanned => l10n.universalImport_label_fillPlanned`.
- `review_step.dart:615` counter: add `int filling` to `_AggregateCounts` and `case DuplicateAction.fillPlanned: filling++;`; render it where `consolidating` is rendered (same row style, label `universalImport_label_fillPlanned`).
- `duplicate_action_card.dart:88` border and `:312` badge, `entity_review_list.dart:765, 1191`, `dive_comparison_card.dart:433`: use `colorScheme.tertiary` and the `fillPlanned` label.
- `dive_computer_adapter.dart:337-348`: add `DuplicateAction.fillPlanned` to the supported set. The other adapters keep their sets, so the button never appears for file, cloud or HealthKit imports.
- `dive_comparison_card.dart` button list, after the `consolidate` block:

```dart
    if (showAction(DuplicateAction.fillPlanned)) {
      buttons.add(
        _ActionButton(
          label: context.l10n.universalImport_label_fillPlanned,
          subtitle: context.l10n.universalImport_compare_fillPlannedSubtitle,
          onPressed: callbackFor(DuplicateAction.fillPlanned, null),
          style: styleFor(DuplicateAction.fillPlanned, _ActionButtonStyle.outlined),
          color: colorFor(DuplicateAction.fillPlanned),
        ),
      );
    }
```

Add `DuplicateAction.fillPlanned => colorScheme.tertiary` to `colorFor`. The button should only show when the match is a planned fill: pass `showFillPlanned: matchResult.isPlannedFill` from `DuplicateActionCard._buildExpanded` into `DiveComparisonCard` (new optional `bool showFillPlanned = false`) and gate the block on it as well as `showAction`.

- [ ] **Step 4: Default selection and the bulk guard**

In `setBundle`, inside the `for (final index in group.duplicateIndices)` loop, after the `matchedExistingSource || inBatchIndex` branch:

```dart
            if (match.isPlannedFill) {
              duplicateActions.putIfAbsent(type, () => {})[index] =
                  DuplicateAction.fillPlanned;
              selections[type] = {...selections[type]!, index};
              pendingForType = pendingForType.difference({index});
              continue;
            }
```

Document it in the method's doc comment (255-281). In `applyBulkAction`, at the top: `if (action == DuplicateAction.fillPlanned) return; // one planned dive per row, never in bulk`.

Anywhere the wizard maps an action to a selection (`setDuplicateAction`, 672-704), `fillPlanned` behaves like `consolidate`: the row is selected.

- [ ] **Step 5: Summary count**

`unified_import_result.dart`: add `final int filledCount;` with `this.filledCount = 0,`. `import_summary_step.dart`: pass it to `_SuccessView`, include it in `hasActivity` and the headline switch, and render:

```dart
            if (filledCount > 0)
              _CountRow(
                icon: Icons.event_available_outlined,
                label: l10n.universalImport_label_filledPlanned,
                count: filledCount,
                key: const Key('import_summary_filled_row'),
              ),
```

Write `test/features/import_wizard/presentation/widgets/import_summary_filled_test.dart` by copying an existing summary-step test and asserting the row appears for `filledCount: 2` and not for 0.

- [ ] **Step 6: Run analyze and the wizard tests**

Run: `flutter analyze`
Expected: No issues found!
Run: `flutter test test/features/import_wizard/ test/core/presentation/`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "i18n(import): strings for filling planned dives

Refs #2002"
git add lib/features/import_wizard/domain/models/duplicate_action.dart lib/features/import_wizard/domain/models/unified_import_result.dart lib/features/import_wizard/presentation/widgets/review_step.dart lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart lib/features/import_wizard/presentation/widgets/entity_review_list.dart lib/features/import_wizard/presentation/widgets/import_summary_step.dart lib/core/presentation/widgets/dive_comparison_card.dart lib/features/import_wizard/data/adapters/dive_computer_adapter.dart lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_fill_planned_test.dart test/features/import_wizard/presentation/widgets/import_summary_filled_test.dart
git commit -m "feat(import): fill-planned action in the download review

Refs #2002"
```

---

### Task 17: Planned-dive picker and the "Fills planned dive" row

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/planned_dive_picker_sheet.dart`
- Modify: `lib/features/import_wizard/domain/models/import_bundle.dart` (`EntityGroup.copyWith`)
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` (`setPlannedFillTarget`)
- Modify: `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart` (`_CollapsedHeader`), `entity_review_list.dart` (`_buildDuplicateCard`), `review_step.dart` (`_EntityTab.build`)
- Test: `test/features/import_wizard/presentation/widgets/planned_dive_picker_sheet_test.dart`

**Interfaces:**
- Produces: `EntityGroup copyWith({Set<int>? duplicateIndices, Map<int, DiveMatchResult>? matchResults})`; `ImportWizardNotifier.setPlannedFillTarget(int index, String? plannedDiveId)` (null switches the row to import-as-new); `Future<String?> showPlannedDivePicker(BuildContext, {required List<Dive> plannedDives, String? selectedId})` returning the chosen id, `''` for "import as new", null on dismiss; `DuplicateActionCard` gains `onChangeFillTarget: VoidCallback?`.

- [ ] **Step 1: Write the failing picker test**

```dart
// test/features/import_wizard/presentation/widgets/planned_dive_picker_sheet_test.dart
  testWidgets('lists planned dives and returns the tapped id', (tester) async {
    String? picked;
    await tester.pumpWidget(testApp(locale: const Locale('en'), child: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          picked = await showPlannedDivePicker(context, plannedDives: [
            Dive(id: 'p1', name: 'Blue Hole', dateTime: DateTime(2026, 6, 1, 9), isPlanned: true),
            Dive(id: 'p2', name: 'Reef', dateTime: DateTime(2026, 6, 2, 9), isPlanned: true),
          ], selectedId: 'p1');
        },
        child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a planned dive'), findsOneWidget);
    await tester.tap(find.text('Reef'));
    await tester.pumpAndSettle();
    expect(picked, 'p2');
  });

  testWidgets('Import as a new dive instead returns an empty string', (tester) async { /* ... expect(picked, '') */ });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/import_wizard/presentation/widgets/planned_dive_picker_sheet_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the sheet**

```dart
// lib/features/import_wizard/presentation/widgets/planned_dive_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/units/unit_formatter_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver pick which planned dive a download fills. Returns the
/// dive id, an empty string for "import as new", or null when dismissed.
Future<String?> showPlannedDivePicker(
  BuildContext context, {
  required List<Dive> plannedDives,
  String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final units = ref.watch(unitFormatterProvider);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.universalImport_fillPlanned_pickerTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final dive in plannedDives)
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(plannedDiveLabel(dive, units)),
                  subtitle: dive.site?.name == null ? null : Text(dive.site!.name),
                  trailing: dive.id == selectedId ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(sheetContext, dive.id),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.l10n.universalImport_fillPlanned_importAsNew),
                onTap: () => Navigator.pop(sheetContext, ''),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// "Blue Hole, 1 Jun 09:00" or the formatted date when the dive is unnamed.
String plannedDiveLabel(Dive dive, UnitFormatter units) {
  final when = units.formatDateTime(dive.entryTime ?? dive.dateTime);
  final name = dive.name?.trim();
  final site = dive.site?.name.trim();
  final label = (name != null && name.isNotEmpty) ? name : site;
  return label == null || label.isEmpty ? when : '$label, $when';
}
```

Check the real names of the unit formatter provider and its date-time method (grep `unitFormatterProvider` and `formatDateTime(`); pass `l10n:` if `formatDateTime` takes it (see memory note on the English "at" connector).

- [ ] **Step 4: Plumb the target change**

`import_bundle.dart`: add to `EntityGroup`:

```dart
  EntityGroup copyWith({
    Set<int>? duplicateIndices,
    Map<int, DiveMatchResult>? matchResults,
  }) {
    return EntityGroup(
      items: items,
      duplicateIndices: duplicateIndices ?? this.duplicateIndices,
      matchResults: matchResults ?? this.matchResults,
      entityMatches: entityMatches,
      autoSkipIndices: autoSkipIndices,
    );
  }
```

`import_wizard_providers.dart`, in the notifier:

```dart
  /// Point a planned-fill row at another planned dive, or at none (the row
  /// then imports as new). Rewrites the bundle's match result so the card
  /// and the adapter read one source of truth.
  void setPlannedFillTarget(int index, String? plannedDiveId) {
    final bundle = state.bundle;
    final group = bundle?.groups[ImportEntityType.dives];
    final current = group?.matchResults?[index];
    if (bundle == null || group == null || current == null) return;
    final updated = plannedDiveId == null
        ? current.copyWith(clearPlannedDiveId: true)
        : current.copyWith(plannedDiveId: plannedDiveId);
    final matchResults = {...group.matchResults!, index: updated};
    final duplicateIndices = plannedDiveId == null
        ? group.duplicateIndices.difference({index})
        : group.duplicateIndices;
    final groups = {
      ...bundle.groups,
      ImportEntityType.dives: group.copyWith(
        duplicateIndices: duplicateIndices,
        matchResults: matchResults,
      ),
    };
    state = state.copyWith(
      bundle: ImportBundle(source: bundle.source, groups: groups),
    );
    setDuplicateAction(
      ImportEntityType.dives,
      index,
      plannedDiveId == null ? DuplicateAction.importAsNew : DuplicateAction.fillPlanned,
    );
  }
```

Also expose `Future<List<Dive>> plannedDivesForTarget()` on the notifier that reads `diveRepositoryProvider` and calls `getPlannedDives(diverId: <the wizard's target diver id>)`; find where the notifier learns the diver id (the adapter's `_diverId` is private, so read `validatedCurrentDiverIdProvider` here, which is what the adapter was built from).

`duplicate_action_card.dart`: add `final VoidCallback? onChangeFillTarget;` and pass it to `_CollapsedHeader`. In `_CollapsedHeader`, when `matchResult.isPlannedFill`, render under the title:

```dart
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.universalImport_fillPlanned_target(
                    existingDiveLabel,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (onChangeFillTarget != null)
                TextButton(
                  onPressed: onChangeFillTarget,
                  child: Text(context.l10n.universalImport_fillPlanned_change),
                ),
            ],
          ),
```

where `existingDiveLabel` comes from a new `String? existingDiveLabel` on the card, computed in `entity_review_list.dart` `_buildDuplicateCard` from `widget.plannedDiveLabelForIndex?.call(index)`. `review_step.dart` `_EntityTab.build` supplies `plannedDiveLabelForIndex` (looks the planned dive up from `notifier.plannedDivesForTarget()` cached in the tab's state, falls back to the id) and `onChangeFillTarget: (index) async { final planned = await notifier.plannedDivesForTarget(); final picked = await showPlannedDivePicker(context, plannedDives: planned, selectedId: currentId); if (picked == null) return; notifier.setPlannedFillTarget(index, picked.isEmpty ? null : picked); }`. When the planned dive holds a profile series (`dive.profile.isNotEmpty`), append `universalImport_fillPlanned_replacesProfile` to the row.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/import_wizard/`
Expected: all PASS. Add a provider test to `import_wizard_fill_planned_test.dart`: `setPlannedFillTarget(0, 'p2')` rewrites `matchResults[0].plannedDiveId` and keeps `fillPlanned`; `setPlannedFillTarget(0, null)` clears it and sets `importAsNew`.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/import_wizard/presentation/widgets/planned_dive_picker_sheet.dart lib/features/import_wizard/domain/models/import_bundle.dart lib/features/import_wizard/presentation/providers/import_wizard_providers.dart lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart lib/features/import_wizard/presentation/widgets/entity_review_list.dart lib/features/import_wizard/presentation/widgets/review_step.dart test/features/import_wizard/presentation/widgets/planned_dive_picker_sheet_test.dart test/features/import_wizard/presentation/providers/import_wizard_fill_planned_test.dart
git commit -m "feat(import): choose which planned dive a download fills

Refs #2002"
```

---

### Task 18: `PlannedDiveFillService`, the adapter's fill branch, and Undo on the summary

**Files:**
- Create: `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart`
- Create: `lib/features/dive_computer/data/services/planned_dive_fill_service.dart`
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart` (expose the parser and preset loaders the fill needs, or add `attachToPlannedDive`)
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` (`performImport` 474-683)
- Modify: `lib/features/import_wizard/domain/models/unified_import_result.dart` (`fillOutcomes`), `import_summary_step.dart` (Undo button)
- Test: `test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart`, `test/features/dive_computer/data/services/planned_dive_fill_service_test.dart`, `test/features/import_wizard/data/adapters/dive_computer_adapter_fill_planned_test.dart` (second group)

**Interfaces:**
- Consumes: `DiveComputerRepository.importProfile` (Task 14 fix), `DiveRepository.convertPlanToActualDive`, `DiveRepository.attributeDiveToComputer` (on `DiveComputerRepository`, line 1789), `ProfileSeriesRepository.deleteForDive`, `DiveMergeSnapshot.capture`, `DiveConsolidationService.undo`-style restore, `DiveImportService`'s `_parser` output (`parseProfile/parseTanks/parseGasSwitches`, `_convertEvents`) which must become reachable: add a public `DiveImportService.attachToPlannedDive(...)` that does the parsing and calls `importProfile`, mirroring `_updateExistingDive` at 822-880.
- Produces: `kMeasuredDiveFields`, `kHumanDiveFields`, `PlannedDiveFillService.fill/undo`, `PlannedDiveFillOutcome`, `UnifiedImportResult.fillOutcomes` (`List<PlannedDiveFillOutcome>`), summary Undo.

- [ ] **Step 1: Write the failing field-census test**

Same shape as Task 11's census, over `kMeasuredDiveFields ∪ kHumanDiveFields`. The measured set: `entryTime, exitTime, bottomTime, runtime, maxDepth, avgDepth, waterTemp, cnsStart, cnsEnd, otu, gradientFactorLow, gradientFactorHigh, decoAlgorithm, decoConservatism, diveComputerModel, diveComputerSerial, diveComputerFirmware, computerId, diveMode, profile, tanks, isPlanned, diveNumber, updatedAt, surfaceInterval, surfaceIntervalSeconds, setpointLow, setpointHigh, setpointDeco, scrType`. Everything else is human (including `dateTime`, which stays: the computer's start goes to `entryTime`, and `dateTime` follows only through the existing `convertPlanToActualDive` when no actual date is passed, which leaves it alone). Reconcile against the constructor with the test.

- [ ] **Step 2: Write the failing service tests**

```dart
// test/features/dive_computer/data/services/planned_dive_fill_service_test.dart
// real database: setUpTestDatabase(); DiveRepository, DiveComputerRepository,
// a computer row (copy insertComputer from dive_computer_repository_impl_test.dart)

  DownloadedDive download() => DownloadedDive(
    startTime: DateTime(2026, 6, 1, 9, 3),
    durationSeconds: 2700,
    maxDepth: 18.4,
    avgDepth: 11.2,
    minTemperature: 17,
    profile: [for (var t = 0; t <= 2700; t += 30) ProfileSample(timeSeconds: t, depth: t < 2400 ? 15 : 3)],
    tanks: [DownloadedTank(o2Percent: 32, hePercent: 0, startPressure: 200, endPressure: 60, volume: 12)],
    events: const [],
    rawFingerprint: Uint8List.fromList([9, 9]),
    gfLow: 40, gfHigh: 85, decoAlgorithm: 'Buhlmann ZHL-16C',
  );

  Future<Dive> plannedDive() => dives.createPlannedDive(Dive(
    id: '', diverId: eric, dateTime: DateTime(2026, 6, 1, 9), name: 'Blue Hole plan',
    notes: 'bring the camera', rating: 4, maxDepth: 20, waterTemp: 20,
    tanks: [DiveTank(id: '', gasMix: GasMix(o2: 32, he: 0), volume: 12)],
    profile: [DiveProfilePoint(timestamp: 0, depth: 0), DiveProfilePoint(timestamp: 600, depth: 20)],
  ));

  test('fill keeps human facts, takes measured facts, promotes and numbers', () async {
    await dives.createDive(Dive(id: '', diverId: eric, dateTime: DateTime(2026, 5, 1), diveNumber: 41));
    final planned = await plannedDive();
    final outcome = await service.fill(plannedDiveId: planned.id, dive: download(), computerId: computerId);
    final filled = await dives.getDiveById(planned.id);
    expect(filled?.isPlanned, isFalse);
    expect(filled?.diveNumber, 42);
    expect(outcome.assignedDiveNumber, 42);
    // human
    expect(filled?.notes, 'bring the camera');
    expect(filled?.rating, 4);
    expect(filled?.name, 'Blue Hole plan');
    // measured
    expect(filled?.maxDepth, closeTo(18.4, 0.01));
    expect(filled?.entryTime, DateTime(2026, 6, 1, 9, 3));
    expect(filled?.waterTemp, 17);
    expect(filled?.gradientFactorLow, 40);
    expect(filled?.computerId, computerId);
    expect(filled?.profile.length, greaterThan(50));
  });

  test('the sketched profile is replaced, not merged', () async {
    final planned = await plannedDive();
    await service.fill(plannedDiveId: planned.id, dive: download(), computerId: computerId);
    final series = await ProfileSeriesRepository().getRowsForDives([planned.id]);
    expect(series, hasLength(1));
    expect(series.single.computerId, computerId);
  });

  test('planned tanks are matched by gas mix and receive pressures', () async {
    final planned = await plannedDive();
    await service.fill(plannedDiveId: planned.id, dive: download(), computerId: computerId);
    final filled = await dives.getDiveById(planned.id);
    expect(filled?.tanks, hasLength(1));
    expect(filled?.tanks.single.startPressure, 200);
    expect(filled?.tanks.single.endPressure, 60);
  });

  test('an unmatched downloaded tank is added', () async {
    /* download with a second tank o2 50 -> filled.tanks has 2 */
  });

  test('a data source with the fingerprint exists after the fill', () async {
    final planned = await plannedDive();
    await service.fill(plannedDiveId: planned.id, dive: download(), computerId: computerId);
    final keys = await dives.getSourceKeysByDiveId();
    expect(keys[planned.id], contains('0909'));
  });

  test('undo restores the planned dive exactly', () async {
    final planned = await plannedDive();
    final before = await dives.getDiveById(planned.id);
    final outcome = await service.fill(plannedDiveId: planned.id, dive: download(), computerId: computerId);
    await service.undo(outcome);
    final after = await dives.getDiveById(planned.id);
    expect(after?.isPlanned, isTrue);
    expect(after?.diveNumber, isNull);
    expect(after?.maxDepth, before?.maxDepth);
    expect(after?.profile.length, before?.profile.length);
    expect(after?.tanks.single.startPressure, isNull);
    final sources = await (db.select(db.diveDataSources)..where((t) => t.diveId.equals(planned.id))).get();
    expect(sources, isEmpty);
  });
```

Use the real constructors of `DownloadedDive`, `ProfileSample`, `DownloadedTank`, `DiveTank`, `GasMix`, `DiveProfilePoint` (grep each class).

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/dive_computer/data/services/planned_dive_fill_service_test.dart`
Expected: FAIL to compile.

- [ ] **Step 4: Expose the attach step on `DiveImportService`**

Add next to `_updateExistingDive`:

```dart
  /// Attach [dive]'s download to [plannedDiveId] (issue #2002). Like
  /// [_updateExistingDive] but without clearing anything first: a planned
  /// dive has no source for this computer. importProfile matches the
  /// planned dive back by its (already rewritten) entry time.
  Future<void> attachToPlannedDive(
    DownloadedDive dive,
    String plannedDiveId,
    String computerId, {
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    final profilePoints = _parser.parseProfile(dive);
    final events = _convertEvents(dive.events);
    final gasSwitches = _parser.parseGasSwitches(dive);
    final tanks = _parser.parseTanks(dive);
    final attachedTo = await _repository.importProfile(
      computerId: computerId,
      profileStartTime: dive.startTime,
      points: profilePoints,
      durationSeconds: dive.durationSeconds,
      maxDepth: dive.maxDepth,
      avgDepth: dive.avgDepth,
      isPrimary: true,
      tanks: tanks,
      decoAlgorithm: dive.decoAlgorithm,
      gfLow: dive.gfLow,
      gfHigh: dive.gfHigh,
      decoConservatism: dive.decoConservatism,
      diveMode: dive.diveMode,
      events: events,
      gasSwitches: gasSwitches,
      rawData: dive.rawData,
      rawFingerprint: dive.rawFingerprint,
      descriptorVendor: descriptorVendor,
      descriptorProduct: descriptorProduct,
      descriptorModel: descriptorModel,
      libdivecomputerVersion: libdivecomputerVersion,
      entryLatitude: dive.entryLatitude,
      entryLongitude: dive.entryLongitude,
      exitLatitude: dive.exitLatitude,
      exitLongitude: dive.exitLongitude,
      minTemperature: dive.minTemperature,
    );
    if (attachedTo != plannedDiveId) {
      throw StateError(
        'importProfile attached to $attachedTo, expected $plannedDiveId',
      );
    }
  }
```

`importProfile` matches by time within five minutes; the fill service rewrites the planned dive's `entryTime` to the download's start before calling this, and the planned exclusion from Task 14 means `findMatchingDive` must NOT filter planned dives out here. Resolve this by having the fill service promote first (Step 5 order) so the dive is no longer planned when `importProfile` looks for it. `findMatchingDive` (885-909) is the unscoped wrapper; it must also gain `AND is_planned = 0` consistency by delegating to `findMatchingDiveWithScore`, which it already does.

- [ ] **Step 5: Write the service**

```dart
// lib/features/dive_computer/data/services/planned_dive_fill_service.dart
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// What one fill wrote, enough to undo it.
class PlannedDiveFillOutcome {
  final String diveId;
  final DiveMergeSnapshot snapshot;
  final int? assignedDiveNumber;

  const PlannedDiveFillOutcome({
    required this.diveId,
    required this.snapshot,
    required this.assignedDiveNumber,
  });
}

/// Fills a planned dive from a dive computer download (issue #2002): the
/// computer supplies the measured facts, the plan keeps the human ones.
class PlannedDiveFillService {
  final DiveRepository _dives;
  final DiveComputerRepository _computers;
  final DiveImportService _import;
  final ProfileSeriesRepository _series;

  PlannedDiveFillService({
    DiveRepository? dives,
    DiveComputerRepository? computers,
    DiveImportService? importService,
    ProfileSeriesRepository? series,
  }) : _dives = dives ?? DiveRepository(),
       _computers = computers ?? DiveComputerRepository(),
       _series = series ?? ProfileSeriesRepository(),
       _import =
           importService ??
           DiveImportService(
             repository: computers ?? DiveComputerRepository(),
             diveRepository: dives ?? DiveRepository(),
           );

  Future<PlannedDiveFillOutcome> fill({
    required String plannedDiveId,
    required DownloadedDive dive,
    required String computerId,
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    final db = DatabaseService.instance.database;
    return db.transaction(() async {
      final planned = await _dives.getDiveById(plannedDiveId);
      if (planned == null || !planned.isPlanned) {
        throw StateError('Dive $plannedDiveId is not a planned dive');
      }
      final snapshot = await DiveMergeSnapshot.capture(
        db,
        [plannedDiveId],
        plannedDiveId,
      );

      // 1. Drop the sketched or planner-generated curve; the download is
      //    the record of what happened.
      await _series.deleteForDive(plannedDiveId);

      // 2. Measured facts onto the row, tanks reconciled by serial then mix.
      final tanks = _mergeTanks(planned.tanks, dive.tanks);
      final measured = planned.copyWith(
        entryTime: dive.startTime,
        exitTime: dive.startTime.add(Duration(seconds: dive.durationSeconds)),
        bottomTime: Duration(seconds: dive.durationSeconds),
        runtime: Duration(seconds: dive.durationSeconds),
        maxDepth: dive.maxDepth,
        avgDepth: dive.avgDepth ?? planned.avgDepth,
        waterTemp: dive.minTemperature ?? planned.waterTemp,
        gradientFactorLow: dive.gfLow ?? planned.gradientFactorLow,
        gradientFactorHigh: dive.gfHigh ?? planned.gradientFactorHigh,
        decoAlgorithm: dive.decoAlgorithm ?? planned.decoAlgorithm,
        decoConservatism: dive.decoConservatism ?? planned.decoConservatism,
        diveMode: dive.diveMode,
        tanks: tanks,
        profile: const [],
      );
      await _dives.updateDive(measured);

      // 3. Promote before attaching: the matcher skips planned dives.
      final promotedId = await _dives.convertPlanToActualDive(plannedDiveId);
      final promoted = await _dives.getDiveById(promotedId);

      // 4. Attach the download (profile, pressures, switches, events,
      //    data source with fingerprint, computer model and serial).
      await _import.attachToPlannedDive(
        dive,
        plannedDiveId,
        computerId,
        descriptorVendor: descriptorVendor,
        descriptorProduct: descriptorProduct,
        descriptorModel: descriptorModel,
        libdivecomputerVersion: libdivecomputerVersion,
      );
      await _computers.attributeDiveToComputer(
        diveId: plannedDiveId,
        computerId: computerId,
      );

      return PlannedDiveFillOutcome(
        diveId: plannedDiveId,
        snapshot: snapshot,
        assignedDiveNumber: promoted?.diveNumber,
      );
    });
  }

  /// Restores the planned dive from the snapshot: row, tanks, series,
  /// sources, events, switches and pressure series.
  Future<void> undo(PlannedDiveFillOutcome outcome) async {
    final db = DatabaseService.instance.database;
    await db.transaction(() async {
      await DiveMergeSnapshot.restore(db, outcome.snapshot);
    });
  }

  /// Planned tanks matched by transmitter serial first, then by gas mix
  /// (0.5 percent), receive the downloaded pressures; unmatched downloaded
  /// tanks are appended.
  List<DiveTank> _mergeTanks(List<DiveTank> planned, List<DownloadedTank> downloaded) {
    final remaining = [...downloaded];
    final merged = <DiveTank>[];
    for (final tank in planned) {
      DownloadedTank? hit;
      for (final d in remaining) {
        final a = normalizeTransmitterSerial(tank.transmitterSerial);
        final b = normalizeTransmitterSerial(d.transmitterSerial);
        if (a != null && b != null && a == b) {
          hit = d;
          break;
        }
      }
      hit ??= remaining.where((d) =>
          (d.o2Percent - tank.gasMix.o2).abs() <= 0.5 &&
          (d.hePercent - tank.gasMix.he).abs() <= 0.5).firstOrNull;
      if (hit != null) {
        remaining.remove(hit);
        merged.add(tank.copyWith(
          startPressure: hit.startPressure ?? tank.startPressure,
          endPressure: hit.endPressure ?? tank.endPressure,
          transmitterSerial: hit.transmitterSerial ?? tank.transmitterSerial,
        ));
      } else {
        merged.add(tank);
      }
    }
    for (final d in remaining) {
      merged.add(DiveTank(
        id: '',
        gasMix: GasMix(o2: d.o2Percent, he: d.hePercent),
        volume: d.volume,
        startPressure: d.startPressure,
        endPressure: d.endPressure,
        transmitterSerial: d.transmitterSerial,
      ));
    }
    return merged;
  }
}
```

Implementation notes:
- `DiveMergeSnapshot.restore(db, snapshot)` does not exist; extract it from `DiveConsolidationService.undo` (660-720): the "delete current children of `mergedDiveId` not in the snapshot, re-insert snapshot rows verbatim" body, as a static on `DiveMergeSnapshot` that `DiveConsolidationService.undo` then calls. Keep the consolidation tests green while extracting (run `test/features/dive_log/data/services/`).
- Since `importProfile` passes tanks only for new dives (`:1536`) and reconciles existing ones by gas mix on the existing-dive branch (`:1575-1585`), write the merged tanks through `updateDive` first (step 2) so the pressure series and gas switches find them.
- `attributeDiveToComputer` is the only writer of `dives.computer_id` (`:1789`).
- `DownloadedTank` field names (`o2Percent`, `hePercent`, `startPressure`, `endPressure`, `volume`, `transmitterSerial`) must be checked against `downloaded_dive.dart:~300`; `normalizeTransmitterSerial` lives where `dive_consolidation_builder.dart` imports it from.

- [ ] **Step 6: Adapter branch and result**

In `performImport`: add `final indicesToFillPlanned = <int>{};`, bucket `DuplicateAction.fillPlanned` into it in both loops (like consolidate), include it in `allIndices`, and in the loop before the consolidate branch:

```dart
      if (indicesToFillPlanned.contains(index)) {
        final match = bundle.groups[ImportEntityType.dives]?.matchResults?[index];
        final plannedId = match?.plannedDiveId;
        if (plannedId == null) {
          // The target was cleared after selection; treat as import-as-new.
          indicesToImport.add(index);
        } else {
          try {
            final outcome = await _fillService.fill(
              plannedDiveId: plannedId,
              dive: dive,
              computerId: comp.id,
              descriptorVendor: _descriptorVendor,
              descriptorProduct: _descriptorProduct,
              descriptorModel: _descriptorModel,
              libdivecomputerVersion: _libdivecomputerVersion,
            );
            fillOutcomes.add(outcome);
            filled++;
            importedDiveIds.add(plannedId);
          } catch (e, st) {
            _log.error('Fill of planned dive $plannedId failed', error: e, stackTrace: st);
            notices.add(/* an ImportNotice naming the dive, same shape as the consolidation-failed notice */);
          }
        }
      } else if (indicesToConsolidate.contains(index)) {
```

The adapter gains a `PlannedDiveFillService _fillService` constructed alongside `_consolidationService`. The result gets `filledCount: filled, fillOutcomes: fillOutcomes`; add `final List<PlannedDiveFillOutcome> fillOutcomes;` with `this.fillOutcomes = const [],` to `UnifiedImportResult`.

Summary step: when `result.fillOutcomes.isNotEmpty`, render a `TextButton.icon` (`Icons.undo`, `universalImport_fillPlanned_undo`) under the counts that calls `PlannedDiveFillService().undo(outcome)` for each outcome, invalidates the dive list providers through the container, disables itself, and shows `universalImport_fillPlanned_undone` in a snackbar.

- [ ] **Step 7: Adapter test (second group) and run everything**

```dart
  group('fillPlanned import', () {
    test('performImport routes a fillPlanned row through the fill service and counts it', () async {
      /* bundle with matchResults[0].plannedDiveId 'p1', duplicateActions {0: fillPlanned};
         fake fill service records the call and returns an outcome */
      final result = await adapter.performImport(bundle, selections, actions);
      expect(result.filledCount, 1);
      expect(result.fillOutcomes.single.diveId, 'p1');
      expect(result.importedCounts[ImportEntityType.dives], 0);
    });
  });
```

Run: `flutter test test/features/dive_computer/ test/features/import_wizard/ test/features/dive_log/data/services/ test/architecture/`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart lib/features/dive_computer/data/services/planned_dive_fill_service.dart lib/features/dive_computer/data/services/dive_import_service.dart lib/features/dive_log/data/services/dive_merge_snapshot.dart lib/features/dive_log/data/services/dive_consolidation_service.dart lib/features/import_wizard/data/adapters/dive_computer_adapter.dart lib/features/import_wizard/domain/models/unified_import_result.dart lib/features/import_wizard/presentation/widgets/import_summary_step.dart test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart test/features/dive_computer/data/services/planned_dive_fill_service_test.dart test/features/import_wizard/data/adapters/dive_computer_adapter_fill_planned_test.dart
git commit -m "feat(import): fill a planned dive from a dive computer download

The computer supplies the measured facts, profile, pressures, switches
and a data source with the fingerprint; the plan keeps site, buddies,
notes, gear and conditions. The dive is promoted and numbered, and the
summary can undo the fills from a snapshot.

Refs #2002"
```

---

### Task 19: Whole-project verification and the pull request

**Files:** none new.

- [ ] **Step 1: Rebase and renumber the rung**

```bash
git fetch origin main
git rebase origin/main
```

Read `currentSchemaVersion` on the rebased tree. If it is no longer 218, renumber every 219 in this branch to main's version plus one: the constant, the `migrationVersions` entry and comment, the `if (from < 219)` rung, the backstop comment, `test/core/database/migration_v219_buddy_profile_dive_links_test.dart` (rename the file and its literals), and relax the newest shipped rung's exact tripwire. Resolve ARB conflicts by key-set arithmetic (each file must gain exactly this branch's keys). Re-run `flutter gen-l10n` after any ARB merge.

- [ ] **Step 2: Format, analyze, guards**

```bash
dart format .
flutter analyze
flutter test test/architecture/
```

Expected: "No issues found!" and every guard passing. Run `flutter analyze` unpiped and read the exit status.

- [ ] **Step 3: Affected test directories, then the full suite once**

```bash
flutter test test/core/database/ test/core/services/sync/ test/features/buddies/ test/features/divers/ test/features/dive_log/ test/features/dive_computer/ test/features/import_wizard/ test/features/dive_import/ test/features/planner/ test/l10n/
```

Then one full run (the suite is IO-bound, do not overlap it with another run):

```bash
flutter test > "$SCRATCHPAD/full_suite.log" 2>&1; echo "exit=$?" >> "$SCRATCHPAD/full_suite.log"
```

Read the tail of the log and the exit line. Investigate any failure against the flaky-test memory index before blaming the branch.

- [ ] **Step 4: Manual smoke on macOS (owed, listed in the PR body)**

Build with `flutter build macos --debug` through a scratchpad script (the word `build` in a Bash command is refused). Launch from Ghostty, not from the Claude terminal (TCC crash memory). Walk: link a buddy to a profile, save a dive with that buddy, accept the mirror, switch profile, see the planned sibling, plan a dive by hand, download from a computer or use "Import as new" on a file with a same-day dive, confirm "Fill planned dive" pre-selected, fill, check the number and the Logged with row, undo from the summary.

- [ ] **Step 5: Open the PR**

Push with `git push -u origin ericgriffin/buddy-submersion-dive-linking-18925d`. Create the PR against `main` with `gh pr create` (fall back to `gh api -X POST repos/submersion-app/submersion/pulls` if GraphQL is rate-limited). Title: `feat(dive-log): log a dive for a buddy's profile and fill planned dives from a download`. Body, no attribution of any kind:

```
## Summary

- A buddy can be linked to a local diver profile (explicit picker on the buddy page, one-time suggestion on a name or email match). Links survive buddy and diver merges and clear when the profile is deleted.
- Saving a dive with a linked buddy offers to log the same dive in that profile as a planned sibling sharing an outing id. The sibling carries the shared facts, the whole buddy group with roles, and a reciprocal linked buddy. The buddies card lists siblings under "Logged with".
- Planned-dive lifecycle: "Plan a dive" in the add sheet, a planned switch on the edit page that hides the number, a banner and "Mark as logged" on the detail page, a "Planned" chip in the list. The planner's convert-to-dive now creates a planned dive on purpose.
- The download review pairs same-day planned dives with downloads and pre-selects "Fill planned dive", with a picker to change the target. The fill takes measured facts from the computer, keeps the plan's human facts, matches tanks by serial then mix, promotes and numbers the dive, and can be undone from the summary.
- Fix: a profile attached to an existing dive now records its `dive_data_sources` row, so a re-download is caught by the fingerprint pass.

Schema v<N>: `buddies.linked_diver_id` (FK divers, ON DELETE SET NULL) and `dives.outing_id`. Additive; sync floor unchanged.

Spec: `docs/superpowers/specs/2026-09-15-buddy-profile-dive-linking-design.md`
Plan: `docs/superpowers/plans/2026-09-16-buddy-profile-dive-linking.md`

## Test plan

- [ ] Full suite green locally (one run)
- [ ] `flutter analyze` clean, architecture guards green
- [ ] macOS smoke walk (Step 4)

Closes #2002
```

Bind the PR for CI monitoring with the desktop app's PR tools rather than polling `gh`.
