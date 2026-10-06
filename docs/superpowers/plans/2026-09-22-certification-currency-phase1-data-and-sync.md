# Certification Currency Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The data foundation for certification currency: two new certification levels, three synced tables (a seeded rule catalog, per certification overrides, and an event ledger), and every sync and backup seam wired, with no user-visible UI.

**Architecture:** The rule catalog is a synced table seeded with built-in rows, in the shape of `service_kinds`. Built-in rows are reference data: they are seeded on every device, excluded from sync export, spared by `deleteAllRecords`, and re-asserted on every database open. Per certification overrides and the event ledger are ordinary synced child tables of `certifications` with their own `hlc`, in the shape of `service_schedules` and `service_records`. Nothing computed is stored.

**Tech Stack:** Flutter, Drift (`dart run build_runner build`), Riverpod (hand-written providers), `flutter gen-l10n` ARB localization, `flutter_test`, in-memory SQLite for schema and repository tests.

**Spec:** `docs/superpowers/specs/2026-09-22-certification-currency-design.md`. Every decision there is fixed; this plan implements the phase 1 slice of it. One deliberate deviation from the spec text: the spec says the new tables go into "the provider-capture test that catches the writers being right while the app is broken". No such enumerating test exists in this repository. What exists is a per-feature capture test (`export_uddf_site_features_test.dart` and two siblings) that intercepts `#saveAllDataToUddfFile` and asserts one named argument. Task 6 writes a new test in that shape rather than extending a test that is not there.

## Global Constraints

- Worktree root is `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/build-feature-2267-788b28`. Run every command from there. The Bash tool's working directory can reset between calls, so do not rely on a previous `cd`.
- Branch is `ericgriffin/build-feature-2267-788b28`, cut from main on 2026-10-05. This plan was first written on 2026-09-22 against the pre-split `database.dart`; it was revised on 2026-10-05 for the post-split layout (#2502). Tasks 1 to 3 were partly executed on `ericgriffin/cert-renewal-warning-chips-481afd` and are ported from there.
- Schema rung is **261**. Main is at 260. Re-check before Task 2 and again before the push:
  `git fetch origin && git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion ="`
  and search open PRs for a claim on 261. If 261 has been taken, use the next free number everywhere this plan says 261.
- `minimumCompatibleSchemaVersion` stays **240**. Adding a table never raises the floor.
- Since #2502 no table class, seed SQL, schema helper or rung goes in `database.dart`. Tables and their seed SQL live in `lib/core/database/tables/`, schema helpers in `lib/core/database/migrations/helpers/` (part files declaring an extension on `AppDatabase`), rungs in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, and the self-heal in `lib/core/database/migrations/before_open.dart`. `database.dart` gets only the import, the `@DriftDatabase` table list entries, `currentSchemaVersion` and the `migrationVersions` entry.
- The Drift output `lib/core/database/database.g.dart` is gitignored and rebuilt per tree. After any change to `database.dart` run `dart run build_runner build --delete-conflicting-outputs` before compiling. Never stage a `.g.dart` file.
- The l10n output `lib/l10n/arb/app_localizations*.dart` (12 files) IS committed. Run `flutter gen-l10n` only after all 11 ARBs carry the new keys, then commit the 11 ARBs and the 12 generated files together.
- New user-visible strings are translated in all 11 locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh. Only `app_en.arb` carries `@` metadata and is alphabetical; the other ten are feature-grouped, so anchor an insert on a neighbouring key rather than assuming position.
- Enum text read from the database uses `Enum.values.firstWhere((v) => v.name == text, orElse: ...)`, never `byName`.
- Timestamps are Unix milliseconds in integer columns, matching every neighbouring table.
- Immutability: never mutate a list or map that was passed in.
- TDD: write the failing test first, run it, watch it fail for the right reason, then implement.
- Run `dart format .` on the whole project before each commit.
- Run `flutter analyze` on its own, never piped through `grep`, `tail` or `head`. A pipe hides the exit status, and infos are fatal in CI.
- Run the specific test files named in each task. The full suite runs once, after the last phase. Never start a `flutter test` while another is running on this machine.
- Stage explicit paths (`git add <path>`). Never `git add -A` or `git add -u`: sibling worktrees share this checkout's index in ways that sweep in unrelated edits, and `git add -u` can restage a stale submodule pointer.
- Never use em-dashes, en-dashes as sentence punctuation, double hyphens or spaced hyphens as punctuation, anywhere: code, comments, tests, ARB strings, commit messages, PR body.
- No mention of Claude, Claude Code or Anthropic in any commit message, PR title or body, or file. No `Co-Authored-By` trailer.
- No emojis in code, comments or documentation.
- The feature ships as one PR covering phases 1 to 5; its body says `Closes #2267`. Phase 1 opens no PR of its own.
- Names, fixed: sync entity types `certificationCurrencyRules`, `certificationCurrencyPrefs`, `certificationCurrencyEvents`; SQL tables `certification_currency_rules`, `certification_currency_prefs`, `certification_currency_events`; Drift table classes `CertificationCurrencyRules`, `CertificationCurrencyPrefs`, `CertificationCurrencyEvents`; Drift row classes `CurrencyRuleRow`, `CurrencyPrefRow`, `CurrencyEventRow`; domain entities `CurrencyRule`, `CurrencyPref`, `CurrencyEvent`.

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/constants/enums.dart` (modify) | `CertificationLevel.firstAid`, `CertificationLevel.oxygenProvider` |
| `lib/core/constants/certification_levels.dart` (modify) | the two new values in `specialties` |
| `lib/features/certifications/presentation/certification_level_display.dart` (modify) | localized names for the two new values (the switch is exhaustive, so this is a compile error until done) |
| `lib/core/database/tables/certification_currency_tables.dart` (create) | three tables and `kSeedBuiltInCurrencyRulesSql` |
| `lib/core/database/migrations/helpers/certification_currency_migrations.dart` (create) | `_assertCertificationCurrencySchema` |
| `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (modify) | rung 261 |
| `lib/core/database/migrations/before_open.dart` (modify) | the backstop call |
| `lib/core/database/database.dart` (modify) | import, table list, `currentSchemaVersion`, `migrationVersions` |
| `lib/features/certifications/domain/entities/currency_rule.dart` (create) | `CurrencyClockKind` enum, `CurrencyRule` entity, `copyWith`, row mapping |
| `lib/features/certifications/domain/entities/currency_pref.dart` (create) | `CurrencyPref` entity, `copyWith`, row mapping |
| `lib/features/certifications/domain/entities/currency_event.dart` (create) | `CurrencyEventType` enum, `CurrencyEvent` entity, `copyWith`, row mapping |
| `lib/features/certifications/domain/entities/currency_scope.dart` (create) | JSON codec for the four scope arrays, tolerant of unknown enum names |
| `lib/features/certifications/data/repositories/certification_currency_repository.dart` (create) | CRUD for the three tables, change streams, pending marks and tombstones |
| `lib/features/certifications/presentation/providers/certification_currency_providers.dart` (create) | repository provider plus one future provider per table |
| `lib/core/data/repositories/sync_repository.dart` (modify) | three `hlcTargets` entries |
| `lib/core/services/sync/sync_data_serializer.dart` (modify) | 13 seams plus three exporters and one `deleteAllRecords` case |
| `lib/core/services/sync/sync_service.dart` (modify) | apply order, `entityHasUpdatedAt`, `parentRefs` |
| `lib/features/divers/data/repositories/diver_owned_rows.dart` (modify) | custom rules counted and cleaned up when a diver is deleted |
| `lib/core/services/export/uddf/uddf_full_export_service.dart` (modify) | three new named parameters threaded to the builder |
| `lib/core/services/export/uddf/uddf_export_builders.dart` (modify) | three new blocks inside `buildApplicationData` |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` (modify) | parse the three blocks back |
| `lib/core/services/export/models/uddf_import_result.dart` (modify) | three new fields |
| `lib/features/settings/presentation/providers/export_providers.dart` (modify) | collect and pass the three lists |

---

### Task 1: Two new certification levels

**Files:**
- Modify: `lib/core/constants/enums.dart` (the specialty block after `CertificationLevel.techDiver`)
- Modify: `lib/core/constants/certification_levels.dart:11-22` (`specialties`)
- Modify: `lib/features/certifications/presentation/certification_level_display.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus the 10 locale ARBs
- Test: `test/features/certifications/certification_level_first_aid_test.dart` (create)

**Interfaces:**
- Produces: `CertificationLevel.firstAid` and `CertificationLevel.oxygenProvider`, whose `.name` strings `firstAid` and `oxygenProvider` are what Task 2's seed SQL puts in `applicable_levels`.

- [ ] **Step 1: Write the failing test**

Create `test/features/certifications/certification_level_first_aid_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test('first aid levels exist and are specialties, not ladder rungs', () {
    expect(CertificationLevel.firstAid.displayName, 'First Aid / CPR');
    expect(
      CertificationLevel.oxygenProvider.displayName,
      'Emergency Oxygen Provider',
    );
    expect(
      CertificationLevelCatalog.specialties,
      containsAll([
        CertificationLevel.firstAid,
        CertificationLevel.oxygenProvider,
      ]),
    );
  });

  test('both round trip by enum name, which is how rows store them', () {
    for (final level in [
      CertificationLevel.firstAid,
      CertificationLevel.oxygenProvider,
    ]) {
      final parsed = CertificationLevel.values.firstWhere(
        (v) => v.name == level.name,
        orElse: () => CertificationLevel.other,
      );
      expect(parsed, level);
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/certifications/certification_level_first_aid_test.dart`
Expected: FAIL to compile, "The getter 'firstAid' isn't defined for the type 'CertificationLevel'".

- [ ] **Step 3: Add the enum values**

In `lib/core/constants/enums.dart`, immediately after `techDiver('Tech Diver'),`:

```dart
  // Agency-agnostic safety credentials. These genuinely expire on a date
  // (typically 24 months) and are the prerequisite that lapses first for
  // rescue and professional ratings, so certification currency needs them
  // as first-class values rather than folding them into `other`.
  firstAid('First Aid / CPR'),
  oxygenProvider('Emergency Oxygen Provider'),
```

- [ ] **Step 4: Add them to the specialties catalog**

In `lib/core/constants/certification_levels.dart`, inside `specialties`, after `CertificationLevel.techDiver,`:

```dart
    CertificationLevel.firstAid,
    CertificationLevel.oxygenProvider,
```

- [ ] **Step 5: Wire the localized names**

`CertificationLevelDisplay.localizedName` is an exhaustive switch, so the project does not compile until both values are handled. In `lib/features/certifications/presentation/certification_level_display.dart`, next to the other specialty entries:

```dart
    CertificationLevel.firstAid => l10n.enum_certificationLevel_firstAid,
    CertificationLevel.oxygenProvider =>
      l10n.enum_certificationLevel_oxygenProvider,
```

- [ ] **Step 6: Add the ARB keys to all 11 locales**

`app_en.arb` is alphabetical, so place these among the other `enum_certificationLevel_` keys:

```json
  "enum_certificationLevel_firstAid": "First Aid / CPR",
  "@enum_certificationLevel_firstAid": {
    "description": "Certification level: a first aid and CPR credential"
  },
  "enum_certificationLevel_oxygenProvider": "Emergency Oxygen Provider",
  "@enum_certificationLevel_oxygenProvider": {
    "description": "Certification level: an emergency oxygen provider credential"
  },
```

The other ten are feature-grouped, so anchor on the neighbouring `enum_certificationLevel_techDiver` key in each file and add the pair without `@` metadata:

| locale | firstAid | oxygenProvider |
| --- | --- | --- |
| ar | `الإسعافات الأولية / الإنعاش القلبي الرئوي` | `مزود الأكسجين في حالات الطوارئ` |
| de | `Erste Hilfe / HLW` | `Notfall-Sauerstoff Provider` |
| es | `Primeros auxilios / RCP` | `Proveedor de oxígeno de emergencia` |
| fr | `Premiers secours / RCP` | `Oxygénothérapie de secours` |
| he | `עזרה ראשונה / החייאה` | `ספק חמצן חירום` |
| hu | `Elsősegély / újraélesztés` | `Vészhelyzeti oxigénadagolás` |
| it | `Primo soccorso / RCP` | `Fornitore di ossigeno di emergenza` |
| nl | `Eerste hulp / reanimatie` | `Noodzuurstof-verstrekker` |
| pt | `Primeiros socorros / RCP` | `Fornecedor de oxigénio de emergência` |
| zh | `急救 / 心肺复苏` | `紧急供氧员` |

- [ ] **Step 7: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: 12 files under `lib/l10n/arb/` are rewritten with the two new getters.

- [ ] **Step 8: Run the test and the analyzer**

Run: `flutter test test/features/certifications/certification_level_first_aid_test.dart`
Expected: PASS.
Run: `flutter analyze`
Expected: no issues. If the analyzer reports a non-exhaustive switch anywhere else, that file also renders levels and needs the two new cases.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/core/constants/enums.dart lib/core/constants/certification_levels.dart lib/features/certifications/presentation/certification_level_display.dart lib/l10n/arb test/features/certifications/certification_level_first_aid_test.dart
git commit -m "feat(certifications): first aid and oxygen provider levels"
```

---

### Task 2: Schema rung 261, three tables and the seeded catalog

**Files:**
- Create: `lib/core/database/tables/certification_currency_tables.dart` (three table classes and `kSeedBuiltInCurrencyRulesSql`, in the shape of `tables/service_tables.dart`)
- Create: `lib/core/database/migrations/helpers/certification_currency_migrations.dart` (`part of '../app_database_migrations.dart';`, an extension on `AppDatabase` holding `_assertCertificationCurrencySchema`, in the shape of `helpers/trip_migrations.dart`), plus its `part` line in `app_database_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (the rung after v260)
- Modify: `lib/core/database/migrations/before_open.dart` (the backstop, beside `_assertServiceLedgerSchema`)
- Modify: `lib/core/database/database.dart` (import of the new tables file, the `@DriftDatabase` tables list, `currentSchemaVersion`, `migrationVersions` with a comment in the house style)
- Test: `test/core/database/migration_v261_certification_currency_test.dart` (create)

**Interfaces:**
- Consumes: Task 1's enum names, as text inside the seed SQL.
- Produces: `db.certificationCurrencyRules`, `db.certificationCurrencyPrefs`, `db.certificationCurrencyEvents`, and the row classes `CurrencyRuleRow`, `CurrencyPrefRow`, `CurrencyEventRow`. Ten built-in rules with the ids `padi_reactivate`, `ssi_skills_update`, `generic_refresher`, `first_aid_24mo`, `pro_membership_annual`, `gue_revalidation`, `ffessm_licence_annual`, `cave_currency`, `rebreather_currency`, `deco_currency`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v261_certification_currency_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v261 (issue #2267): the certification currency tables and the seeded
/// built-in rule catalog.
NativeDatabase setupDb({int userVersion = 260}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('''
        CREATE TABLE certifications (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          agency TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    },
  );
}

Future<Set<String>> columnsOf(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v261 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 261);
    expect(AppDatabase.migrationVersions, contains(261));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a v260 database upgrades and gains the three tables', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'certification_currency_rules'),
      containsAll([
        'id',
        'diver_id',
        'name',
        'clock_kind',
        'applicable_agencies',
        'applicable_levels',
        'lapse_days',
        'lead_days',
        'counted_dive_type_ids',
        'counted_dive_modes',
        'advisory_key',
        'advisory_text',
        'supersedes_rule_id',
        'is_built_in',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await columnsOf(db, 'certification_currency_prefs'),
      containsAll([
        'id',
        'certification_id',
        'rule_id',
        'lapse_days_override',
        'lead_days_override',
        'counted_dive_type_ids',
        'counted_dive_modes',
        'muted',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await columnsOf(db, 'certification_currency_events'),
      containsAll([
        'id',
        'certification_id',
        'rule_id',
        'event_type',
        'event_date',
        'provider',
        'notes',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('the upgrade seeds exactly the ten built-in rules', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id FROM certification_currency_rules WHERE is_built_in = 1',
        )
        .get();
    expect(rows.map((r) => r.read<String>('id')).toSet(), {
      'padi_reactivate',
      'ssi_skills_update',
      'generic_refresher',
      'first_aid_24mo',
      'pro_membership_annual',
      'gue_revalidation',
      'ffessm_licence_annual',
      'cave_currency',
      'rebreather_currency',
      'deco_currency',
    });
  });

  test('re-seeding is idempotent and never rewrites a diver edit', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    await db.customStatement(
      'UPDATE certification_currency_rules SET lapse_days = 999 '
      "WHERE id = 'cave_currency'",
    );
    // The beforeOpen backstop runs on every open; simulate a second one.
    await db.customStatement(kSeedBuiltInCurrencyRulesSql);

    final row = await db
        .customSelect(
          "SELECT lapse_days, COUNT(*) AS n FROM certification_currency_rules "
          "WHERE id = 'cave_currency'",
        )
        .getSingle();
    expect(row.read<int>('n'), 1);
    expect(
      row.read<int>('lapse_days'),
      999,
      reason: 'INSERT OR IGNORE must not overwrite a tuned built-in',
    );
  });

  test('prefs and events cascade when their certification goes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO certifications (id, name, agency, created_at, updated_at) "
      "VALUES ('c1', 'OW', 'padi', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO certification_currency_prefs "
      "(id, certification_id, rule_id, muted, created_at, updated_at) "
      "VALUES ('p1', 'c1', 'cave_currency', 0, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO certification_currency_events "
      "(id, certification_id, rule_id, event_type, event_date, notes, "
      "created_at, updated_at) "
      "VALUES ('e1', 'c1', 'cave_currency', 'refresher', 100, '', 0, 0)",
    );
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement("DELETE FROM certifications WHERE id = 'c1'");

    final prefs = await db
        .customSelect('SELECT id FROM certification_currency_prefs')
        .get();
    final events = await db
        .customSelect('SELECT id FROM certification_currency_events')
        .get();
    expect(prefs, isEmpty);
    expect(events, isEmpty);
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    for (final table in const [
      'certification_currency_rules',
      'certification_currency_prefs',
      'certification_currency_events',
    ]) {
      expect(
        await columnsOf(upgraded, table),
        await columnsOf(fresh, table),
        reason: '$table must be identical on both paths',
      );
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/database/migration_v261_certification_currency_test.dart`
Expected: FAIL, `AppDatabase.currentSchemaVersion` is 260, and the tables do not exist.

- [ ] **Step 3: Add the three table classes**

In the new `lib/core/database/tables/certification_currency_tables.dart` (import `diver_tables.dart` for `Divers` and `buddy_tables.dart` for `Certifications`):

```dart
/// The certification currency rule catalog (issue #2267). Built-in rows are
/// reference data: seeded on every device, excluded from sync export, spared
/// by deleteAllRecords, and re-asserted on every open. They are never edited
/// in place, because an edit to a row the export omits would be device-local
/// and silent; the UI copies a built-in into a custom rule that carries
/// [supersedesRuleId] instead.
@DataClassName('CurrencyRuleRow')
class CertificationCurrencyRules extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();

  /// `date` counts from a date on the card; `activity` counts from the last
  /// qualifying dive. See CurrencyClockKind.
  TextColumn get clockKind => text()();

  /// JSON arrays of CertificationAgency and CertificationLevel names.
  /// '[]' means "any", the same convention as ServiceKinds.applicableTypes.
  TextColumn get applicableAgencies =>
      text().withDefault(const Constant('[]'))();
  TextColumn get applicableLevels => text().withDefault(const Constant('[]'))();

  IntColumn get lapseDays => integer()();
  IntColumn get leadDays => integer()();

  /// Activity clocks only: which dives count. '[]' means any dive.
  TextColumn get countedDiveTypeIds =>
      text().withDefault(const Constant('[]'))();
  TextColumn get countedDiveModes => text().withDefault(const Constant('[]'))();

  /// Built-ins name an l10n key resolved at render time, so a seeded row
  /// never stores a translated string. Custom rules carry the diver's own
  /// text, which is never translated.
  TextColumn get advisoryKey => text().nullable()();
  TextColumn get advisoryText => text().nullable()();

  /// Set on a custom rule that replaces a built-in one. The engine drops the
  /// built-in while a live custom rule supersedes it.
  TextColumn get supersedesRuleId => text().nullable()();

  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per (certification, rule) overrides. An absent row inherits everything,
/// which is what lets rules apply by default with no seeding per card.
@DataClassName('CurrencyPrefRow')
class CertificationCurrencyPrefs extends Table {
  TextColumn get id => text()();
  TextColumn get certificationId =>
      text().references(Certifications, #id, onDelete: KeyAction.cascade)();

  /// Plain text, no FK, so a pref survives deleting the custom rule it
  /// referenced, exactly as service_records.service_kind_id does.
  TextColumn get ruleId => text()();

  IntColumn get lapseDaysOverride => integer().nullable()();
  IntColumn get leadDaysOverride => integer().nullable()();

  /// Null inherits the rule's mapping; '[]' means the diver chose "any dive".
  TextColumn get countedDiveTypeIds => text().nullable()();
  TextColumn get countedDiveModes => text().nullable()();

  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What the diver did to reset a clock: a refresher, a renewal, a
/// revalidation. The ledger twin of ServiceRecords.
@DataClassName('CurrencyEventRow')
class CertificationCurrencyEvents extends Table {
  TextColumn get id => text()();
  TextColumn get certificationId =>
      text().references(Certifications, #id, onDelete: KeyAction.cascade)();

  /// Nullable and FK-free: a refresher the diver logged without tying it to
  /// a rule still belongs in the history.
  TextColumn get ruleId => text().nullable()();

  TextColumn get eventType => text()();
  IntColumn get eventDate => integer()();
  TextColumn get provider => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Import the file from `database.dart` and add all three to the `@DriftDatabase(tables: [...])` list.

- [ ] **Step 4: Add the seed SQL**

In the same tables file, below the table classes. `INSERT OR IGNORE` is what makes the beforeOpen backstop idempotent and what preserves a diver's tuning:

```dart
/// The built-in currency rules (issue #2267). INSERT OR IGNORE, so running
/// this on every open re-seeds a stranded catalog without ever rewriting a
/// row the diver has tuned. A later release adds rules here; it never
/// UPDATEs an existing one, because a default correction is for fresh
/// databases only.
const String kSeedBuiltInCurrencyRulesSql = '''
  INSERT OR IGNORE INTO certification_currency_rules
    (id, diver_id, name, clock_kind, applicable_agencies, applicable_levels,
     lapse_days, lead_days, counted_dive_type_ids, counted_dive_modes,
     advisory_key, advisory_text, supersedes_rule_id, is_built_in,
     created_at, updated_at)
  SELECT r.id, NULL, r.name, r.clock_kind, r.agencies, r.levels,
         r.lapse_days, r.lead_days, r.dive_types, r.dive_modes,
         r.advisory_key, NULL, NULL, 1, n.now_ms, n.now_ms
  FROM (
    SELECT 'padi_reactivate' AS id, 'PADI refresher (ReActivate)' AS name,
      'activity' AS clock_kind, '["padi"]' AS agencies,
      '["openWater","advancedOpenWater","rescue","masterDiver"]' AS levels,
      365 AS lapse_days, 185 AS lead_days, '[]' AS dive_types,
      '[]' AS dive_modes,
      'currencyRule_padi_reactivate_advisory' AS advisory_key
    UNION ALL SELECT 'ssi_skills_update', 'SSI Scuba Skills Update',
      'activity', '["ssi"]',
      '["openWater","advancedOpenWater","rescue","masterDiver"]',
      365, 185, '[]', '[]', 'currencyRule_ssi_skills_update_advisory'
    UNION ALL SELECT 'generic_refresher', 'Refresher',
      'activity',
      '["naui","sdi","tdi","raid","bsac","cmas","iantd","psai","ffessm","other"]',
      '["openWater","advancedOpenWater","rescue","masterDiver","cmas1StarDiver","cmas2StarDiver","cmas3StarDiver","bsacOceanDiver","bsacSportsDiver","bsacDiveLeader","ffessmN1","ffessmN2","ffessmN3"]',
      365, 185, '[]', '[]', 'currencyRule_generic_refresher_advisory'
    UNION ALL SELECT 'first_aid_24mo', 'First aid and CPR renewal',
      'date', '[]', '["firstAid","oxygenProvider"]',
      730, 60, '[]', '[]', 'currencyRule_first_aid_advisory'
    UNION ALL SELECT 'pro_membership_annual',
      'Professional membership renewal', 'date',
      '["padi","ssi","naui","sdi","tdi","raid","bsac","cmas","iantd","psai","other"]',
      '["diveGuide","diveMaster","assistantInstructor","instructor","masterInstructor","courseDirector","cmas1StarInstructor","cmas2StarInstructor","cmas3StarInstructor","bsacOpenWaterInstructor","bsacAdvancedInstructor","bsacNationalInstructor"]',
      365, 45, '[]', '[]', 'currencyRule_pro_membership_advisory'
    UNION ALL SELECT 'gue_revalidation', 'GUE revalidation',
      'date', '["gue"]', '[]',
      1095, 90, '[]', '[]', 'currencyRule_gue_revalidation_advisory'
    UNION ALL SELECT 'ffessm_licence_annual',
      'FFESSM licence and medical certificate', 'date', '["ffessm"]', '[]',
      365, 45, '[]', '[]', 'currencyRule_ffessm_licence_advisory'
    UNION ALL SELECT 'cave_currency', 'Cave currency',
      'activity', '[]', '["cave","cavern","gueCave1","gueCave2"]',
      365, 90, '["cave","cavern"]', '[]',
      'currencyRule_cave_currency_advisory'
    UNION ALL SELECT 'rebreather_currency', 'Rebreather currency',
      'activity', '[]', '["rebreather"]',
      180, 90, '[]', '["ccr","scr"]',
      'currencyRule_rebreather_currency_advisory'
    UNION ALL SELECT 'deco_currency', 'Decompression currency',
      'activity', '[]',
      '["decompression","trimix","advancedTrimix","advancedNitrox","techDiver","extendedRange","gueTech1","gueTech2"]',
      365, 90, '["technical"]', '[]',
      'currencyRule_deco_currency_advisory'
  ) r
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';
```

Note that `lead_days` is the lead window in days, so the spec's "amber at 6 months, red at 12" becomes `lapse_days: 365, lead_days: 185`.

- [ ] **Step 5: Add the schema assert and the backstop**

In the new helper part file, inside `extension CertificationCurrencyMigrations on AppDatabase`. Skip when `certifications` or `divers` is absent (`_tableExists`), so a partial migration-test fixture written for an older rung does not gain tables whose foreign keys point nowhere:

```dart
/// Creates the certification currency tables if they are missing and
/// re-seeds the built-in catalog. Idempotent, and run from both the v261
/// rung and beforeOpen: parallel branches have collided on this ladder
/// before, and a device that upgraded across a collision can arrive with
/// the rung recorded and the tables absent.
Future<void> _assertCertificationCurrencySchema() async {
  await createMigrator().createTable(certificationCurrencyRules);
  await createMigrator().createTable(certificationCurrencyPrefs);
  await createMigrator().createTable(certificationCurrencyEvents);
  await customStatement(kSeedBuiltInCurrencyRulesSql);
}
```

Call it from the new rung after the v260 step in `rungs_v231_onward.dart`:

```dart
        if (from < 261) {
          await _assertCertificationCurrencySchema();
        }
        if (from < 261) await reportProgress();
```

And from `before_open.dart`, beside `_assertServiceLedgerSchema`.

- [ ] **Step 6: Bump the version and regenerate**

Set `static const int currentSchemaVersion = 261;` and append `261` to `migrationVersions` with a comment. Leave `minimumCompatibleSchemaVersion` at 240.

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` regenerates with the three new tables.

- [ ] **Step 7: Run the migration test**

Run: `flutter test test/core/database/migration_v261_certification_currency_test.dart`
Expected: PASS, all six tests.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/tables/certification_currency_tables.dart lib/core/database/migrations test/core/database/migration_v261_certification_currency_test.dart
git commit -m "feat(certifications): currency tables and the built-in rule catalog (v261)"
```

---

### Task 3: Domain entities and the scope codec

**Files:**
- Create: `lib/features/certifications/domain/entities/currency_scope.dart`
- Create: `lib/features/certifications/domain/entities/currency_rule.dart`
- Create: `lib/features/certifications/domain/entities/currency_pref.dart`
- Create: `lib/features/certifications/domain/entities/currency_event.dart`
- Test: `test/features/certifications/domain/currency_entities_test.dart` (create)

**Interfaces:**
- Consumes: Task 2's `CurrencyRuleRow`, `CurrencyPrefRow`, `CurrencyEventRow`.
- Produces: `CurrencyRule`, `CurrencyPref`, `CurrencyEvent`, each with `fromRow`, `toCompanion`, `copyWith`; `CurrencyClockKind { date, activity }`; `CurrencyEventType { refresher, renewal, revalidation, skillsUpdate, other }`; `CurrencyScopeCodec.decodeAgencies / decodeLevels / decodeModes / decodeStrings / encode`.

- [ ] **Step 1: Write the failing test**

Create `test/features/certifications/domain/currency_entities_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

void main() {
  group('scope codec', () {
    test('decodes an agency array', () {
      expect(CurrencyScopeCodec.decodeAgencies('["padi","ssi"]'), [
        CertificationAgency.padi,
        CertificationAgency.ssi,
      ]);
    });

    test('an empty array means any, and stays empty rather than becoming null',
        () {
      expect(CurrencyScopeCodec.decodeAgencies('[]'), isEmpty);
      expect(CurrencyScopeCodec.decodeLevels('[]'), isEmpty);
    });

    test('an unknown enum name is dropped, not mapped to other', () {
      // A rule written by a newer build can name a level this build lacks.
      // Mapping it to `other` would silently widen the rule's scope.
      expect(
        CurrencyScopeCodec.decodeLevels('["cave","levelFromTheFuture"]'),
        [CertificationLevel.cave],
      );
    });

    test('malformed JSON decodes to empty instead of throwing', () {
      expect(CurrencyScopeCodec.decodeStrings('not json'), isEmpty);
    });

    test('encode round trips', () {
      expect(
        CurrencyScopeCodec.encode(['cave', 'cavern']),
        '["cave","cavern"]',
      );
    });
  });

  group('entities', () {
    test('clock kind parses by name and falls back to activity', () {
      expect(CurrencyClockKind.parse('date'), CurrencyClockKind.date);
      expect(CurrencyClockKind.parse('activity'), CurrencyClockKind.activity);
      expect(CurrencyClockKind.parse('nonsense'), CurrencyClockKind.activity);
    });

    test('event type parses by name and falls back to other', () {
      expect(CurrencyEventType.parse('refresher'), CurrencyEventType.refresher);
      expect(CurrencyEventType.parse('nonsense'), CurrencyEventType.other);
    });

    test('a built-in rule reports its advisory key, a custom one its text', () {
      final builtIn = CurrencyRule(
        id: 'cave_currency',
        name: 'Cave currency',
        clockKind: CurrencyClockKind.activity,
        lapseDays: 365,
        leadDays: 90,
        advisoryKey: 'currencyRule_cave_currency_advisory',
        isBuiltIn: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(builtIn.advisoryKey, isNotNull);
      expect(builtIn.advisoryText, isNull);

      final custom = builtIn.copyWith(
        id: 'custom-1',
        isBuiltIn: false,
        advisoryText: 'My club asks for a refresher every spring',
        supersedesRuleId: 'cave_currency',
      );
      expect(custom.supersedesRuleId, 'cave_currency');
      expect(custom.isBuiltIn, isFalse);
      expect(custom.name, builtIn.name);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/certifications/domain/currency_entities_test.dart`
Expected: FAIL to compile, the imported files do not exist.

- [ ] **Step 3: Write the scope codec**

Create `lib/features/certifications/domain/entities/currency_scope.dart`:

```dart
import 'dart:convert';

import 'package:submersion/core/constants/enums.dart';

/// Reads and writes the JSON arrays a currency rule stores for its scope and
/// its activity mapping.
///
/// An unknown enum name is DROPPED rather than mapped to `other`: these
/// arrays can be written by a newer build, and folding an unrecognized level
/// into `other` would silently widen a rule to cards it was never meant to
/// match. Malformed JSON decodes to empty for the same reason, so a corrupt
/// row narrows a rule instead of firing it everywhere.
abstract final class CurrencyScopeCodec {
  static List<String> decodeStrings(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String) item,
      ];
    } on FormatException {
      return const [];
    }
  }

  static List<CertificationAgency> decodeAgencies(String raw) => [
    for (final name in decodeStrings(raw))
      ...CertificationAgency.values.where((v) => v.name == name),
  ];

  static List<CertificationLevel> decodeLevels(String raw) => [
    for (final name in decodeStrings(raw))
      ...CertificationLevel.values.where((v) => v.name == name),
  ];

  static List<DiveMode> decodeModes(String raw) => [
    for (final name in decodeStrings(raw))
      ...DiveMode.values.where((v) => v.name == name),
  ];

  static String encode(List<String> values) => jsonEncode(values);
}
```

- [ ] **Step 4: Write the three entities**

Create `lib/features/certifications/domain/entities/currency_rule.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

/// What a currency clock counts from.
enum CurrencyClockKind {
  /// Counts from a date on the card: its expiry, a ledger event, or the
  /// issue date plus the interval.
  date,

  /// Counts from the last qualifying dive, or a ledger event.
  activity;

  static CurrencyClockKind parse(String raw) => CurrencyClockKind.values
      .firstWhere((v) => v.name == raw, orElse: () => CurrencyClockKind.activity);
}

/// One rule in the currency catalog.
class CurrencyRule extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final CurrencyClockKind clockKind;

  /// Empty means "any". Never null.
  final List<CertificationAgency> agencies;
  final List<CertificationLevel> levels;

  final int lapseDays;
  final int leadDays;

  /// Activity clocks only. Empty means any dive counts.
  final List<String> countedDiveTypeIds;
  final List<DiveMode> countedDiveModes;

  final String? advisoryKey;
  final String? advisoryText;
  final String? supersedesRuleId;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CurrencyRule({
    required this.id,
    this.diverId,
    required this.name,
    required this.clockKind,
    this.agencies = const [],
    this.levels = const [],
    required this.lapseDays,
    required this.leadDays,
    this.countedDiveTypeIds = const [],
    this.countedDiveModes = const [],
    this.advisoryKey,
    this.advisoryText,
    this.supersedesRuleId,
    this.isBuiltIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CurrencyRule copyWith({
    String? id,
    String? diverId,
    String? name,
    CurrencyClockKind? clockKind,
    List<CertificationAgency>? agencies,
    List<CertificationLevel>? levels,
    int? lapseDays,
    int? leadDays,
    List<String>? countedDiveTypeIds,
    List<DiveMode>? countedDiveModes,
    String? advisoryKey,
    String? advisoryText,
    String? supersedesRuleId,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CurrencyRule(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    name: name ?? this.name,
    clockKind: clockKind ?? this.clockKind,
    agencies: agencies ?? this.agencies,
    levels: levels ?? this.levels,
    lapseDays: lapseDays ?? this.lapseDays,
    leadDays: leadDays ?? this.leadDays,
    countedDiveTypeIds: countedDiveTypeIds ?? this.countedDiveTypeIds,
    countedDiveModes: countedDiveModes ?? this.countedDiveModes,
    advisoryKey: advisoryKey ?? this.advisoryKey,
    advisoryText: advisoryText ?? this.advisoryText,
    supersedesRuleId: supersedesRuleId ?? this.supersedesRuleId,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Scope arrays as they are stored.
  String get agenciesJson =>
      CurrencyScopeCodec.encode([for (final a in agencies) a.name]);
  String get levelsJson =>
      CurrencyScopeCodec.encode([for (final l in levels) l.name]);
  String get diveTypesJson => CurrencyScopeCodec.encode(countedDiveTypeIds);
  String get diveModesJson =>
      CurrencyScopeCodec.encode([for (final m in countedDiveModes) m.name]);

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    clockKind,
    agencies,
    levels,
    lapseDays,
    leadDays,
    countedDiveTypeIds,
    countedDiveModes,
    advisoryKey,
    advisoryText,
    supersedesRuleId,
    isBuiltIn,
    createdAt,
    updatedAt,
  ];
}
```

Create `lib/features/certifications/domain/entities/currency_pref.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A diver's override of one rule for one certification. An absent row means
/// "inherit everything", so rules can apply by default with nothing seeded
/// per card.
class CurrencyPref extends Equatable {
  final String id;
  final String certificationId;
  final String ruleId;
  final int? lapseDaysOverride;
  final int? leadDaysOverride;

  /// NULL inherits the rule's mapping. An EMPTY list is the diver saying
  /// "any dive counts". The two are different answers and must not be
  /// collapsed.
  final List<String>? countedDiveTypeIds;
  final List<DiveMode>? countedDiveModes;

  final bool muted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CurrencyPref({
    required this.id,
    required this.certificationId,
    required this.ruleId,
    this.lapseDaysOverride,
    this.leadDaysOverride,
    this.countedDiveTypeIds,
    this.countedDiveModes,
    this.muted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CurrencyPref copyWith({
    String? id,
    String? certificationId,
    String? ruleId,
    int? lapseDaysOverride,
    int? leadDaysOverride,
    List<String>? countedDiveTypeIds,
    List<DiveMode>? countedDiveModes,
    bool? muted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CurrencyPref(
    id: id ?? this.id,
    certificationId: certificationId ?? this.certificationId,
    ruleId: ruleId ?? this.ruleId,
    lapseDaysOverride: lapseDaysOverride ?? this.lapseDaysOverride,
    leadDaysOverride: leadDaysOverride ?? this.leadDaysOverride,
    countedDiveTypeIds: countedDiveTypeIds ?? this.countedDiveTypeIds,
    countedDiveModes: countedDiveModes ?? this.countedDiveModes,
    muted: muted ?? this.muted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    certificationId,
    ruleId,
    lapseDaysOverride,
    leadDaysOverride,
    countedDiveTypeIds,
    countedDiveModes,
    muted,
    createdAt,
    updatedAt,
  ];
}
```

`copyWith` cannot clear a nullable field back to null, which is the usual
Dart limitation. The repository therefore writes a pref by full value, and
"go back to inheriting" is expressed by deleting the pref row, not by
nulling its fields.

Create `lib/features/certifications/domain/entities/currency_event.dart`:

```dart
import 'package:equatable/equatable.dart';

/// What the diver did to reset a clock.
enum CurrencyEventType {
  refresher,
  renewal,
  revalidation,
  skillsUpdate,
  other;

  static CurrencyEventType parse(String raw) => CurrencyEventType.values
      .firstWhere((v) => v.name == raw, orElse: () => CurrencyEventType.other);
}

/// One entry in a certification's currency history.
class CurrencyEvent extends Equatable {
  final String id;
  final String certificationId;

  /// Null when the diver logged a refresher without tying it to a rule.
  final String? ruleId;

  final CurrencyEventType eventType;
  final DateTime eventDate;
  final String? provider;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CurrencyEvent({
    required this.id,
    required this.certificationId,
    this.ruleId,
    required this.eventType,
    required this.eventDate,
    this.provider,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  CurrencyEvent copyWith({
    String? id,
    String? certificationId,
    String? ruleId,
    CurrencyEventType? eventType,
    DateTime? eventDate,
    String? provider,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CurrencyEvent(
    id: id ?? this.id,
    certificationId: certificationId ?? this.certificationId,
    ruleId: ruleId ?? this.ruleId,
    eventType: eventType ?? this.eventType,
    eventDate: eventDate ?? this.eventDate,
    provider: provider ?? this.provider,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    certificationId,
    ruleId,
    eventType,
    eventDate,
    provider,
    notes,
    createdAt,
    updatedAt,
  ];
}
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/certifications/domain/currency_entities_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/certifications/domain/entities test/features/certifications/domain/currency_entities_test.dart
git commit -m "feat(certifications): currency rule, pref and event entities"
```

---

### Task 4: Repository and providers

**Files:**
- Create: `lib/features/certifications/data/repositories/certification_currency_repository.dart`
- Create: `lib/features/certifications/presentation/providers/certification_currency_providers.dart`
- Test: `test/features/certifications/data/certification_currency_repository_test.dart` (create)

**Interfaces:**
- Consumes: Task 3's entities, Task 2's tables.
- Produces: `CertificationCurrencyRepository` with `getRules()`, `getRulesForDiver(String diverId)`, `createRule`, `updateRule`, `deleteRule`, `getPrefs(String certificationId)`, `getAllPrefs()`, `upsertPref`, `deletePref`, `getEvents(String certificationId)`, `getAllEvents()`, `createEvent`, `deleteEvent`; providers `certificationCurrencyRepositoryProvider`, `currencyRulesProvider`, `currencyPrefsProvider`, `currencyEventsProvider`.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/certifications/data/certification_currency_repository_test.dart`. Use the existing in-memory database helper the other repository tests use (`test/helpers/test_database.dart`, `setUpTestDatabase` / `tearDownTestDatabase`). Cover:

```dart
  test('getRules returns the ten seeded built-ins', () async {
    final rules = await repository.getRules();
    expect(rules.where((r) => r.isBuiltIn).length, 10);
    expect(
      rules.firstWhere((r) => r.id == 'cave_currency').countedDiveTypeIds,
      ['cave', 'cavern'],
    );
  });

  test('a custom rule round trips with its scope arrays', () async {
    final rule = await repository.createRule(
      CurrencyRule(
        id: 'custom-1',
        diverId: diverId,
        name: 'Club refresher',
        clockKind: CurrencyClockKind.activity,
        agencies: const [CertificationAgency.bsac],
        levels: const [CertificationLevel.openWater],
        lapseDays: 200,
        leadDays: 30,
        countedDiveTypeIds: const ['boat'],
        supersedesRuleId: 'generic_refresher',
        createdAt: DateTime(2026, 9, 22),
        updatedAt: DateTime(2026, 9, 22),
      ),
    );
    final read = (await repository.getRules()).firstWhere(
      (r) => r.id == rule.id,
    );
    expect(read.agencies, [CertificationAgency.bsac]);
    expect(read.countedDiveTypeIds, ['boat']);
    expect(read.supersedesRuleId, 'generic_refresher');
    expect(read.isBuiltIn, isFalse);
  });

  test('a pref with a null mapping is distinct from an empty one', () async {
    // Null inherits the rule's mapping; an empty list is the diver saying
    // "any dive counts". Collapsing the two would silently change a rule.
    await repository.upsertPref(inheritingPref);
    expect((await repository.getPrefs(certId)).single.countedDiveTypeIds, isNull);

    await repository.upsertPref(
      inheritingPref.copyWith(countedDiveTypeIds: const []),
    );
    expect((await repository.getPrefs(certId)).single.countedDiveTypeIds, isEmpty);
  });

  test('deleting a custom rule leaves its prefs and events intact', () async {
    await repository.deleteRule('custom-1');
    expect(await repository.getPrefs(certId), isNotEmpty);
    expect(await repository.getEvents(certId), isNotEmpty);
  });

  test('every write marks a pending sync record', () async {
    await repository.createEvent(event);
    expect(await pendingCountFor('certificationCurrencyEvents'), 1);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/certifications/data/certification_currency_repository_test.dart`
Expected: FAIL to compile, the repository does not exist.

- [ ] **Step 3: Write the repository**

Follow `lib/features/equipment/data/repositories/service_schedule_repository.dart` for structure: a `DatabaseService`-backed class, Drift queries, `_stampHlc` on write, `markRecordPending` after the write, and a tombstone on delete.

Two rules this repository must honor:

```dart
  /// A pending mark must be written AFTER the batch closure, never inside
  /// it: a `_db.batch` closure is synchronous, so an await inside it is
  /// dropped and the record is published without its pending mark.
```

and the null-versus-empty distinction for `countedDiveTypeIds`, which is the difference between "inherit" and "any dive counts".

- [ ] **Step 4: Write the providers**

Create `lib/features/certifications/presentation/providers/certification_currency_providers.dart` with a `Provider` for the repository and three `FutureProvider`s, matching the naming convention in `certification_providers.dart`.

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/certifications/data/certification_currency_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/certifications/data lib/features/certifications/presentation/providers/certification_currency_providers.dart test/features/certifications/data/certification_currency_repository_test.dart
git commit -m "feat(certifications): currency repository and providers"
```

---

### Task 5: Sync registration for the three entities

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart:110` (`hlcTargets`, after `serviceSchedules`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` at these seams, using the `serviceSchedules` entry at each as the anchor: `SyncData` field `:283`, constructor default `:379`, `toJson` `:470`, `fromJson` `:562`, `_baseTables` `:892`, `_buildSyncData` `:1784`, `fetchRecord` `:2354`, `fetchRecords` `:2918`, `upsertRecord` `:3653`, `upsertRecords` `:4505`, `recordIdsFor` `:5405`, `deleteAllRecords` `:5488` (the built-in case, for the rules table only), `_syncTableFor` `:5782`, `deleteRecord` `:5983`, and a new `_exportCertificationCurrencyRules` next to `_exportServiceKinds` `:6698`
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` `:1582`, `entityHasUpdatedAt` `:2391`, `parentRefs` `:2678`)
- Modify: `lib/features/divers/data/repositories/diver_owned_rows.dart:170` (beside the `service_kinds` query)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart:24` (`syncedTables`)
- Modify: `test/core/services/sync/sync_builtin_reference_data_test.dart:19` (`_entityForTable`) and `:36` (`_insert`)
- Test: `test/core/services/sync/certification_currency_sync_test.dart` (create)

**Interfaces:**
- Consumes: Task 2's tables and row classes.
- Produces: the three entity types accepted by `upsertRecord`, `upsertRecords`, `fetchRecord`, `fetchRecords`, `deleteRecord` and `recordIdsFor`, carried by `SyncData.certificationCurrencyRules / Prefs / Events`, applied by `SyncService` after `certifications`.

The three entities are top-level, NOT parent-gated children. Editing a pref never touches the certification row, so a clockless child riding the parent's clock would never replicate. That is the same reasoning the `serviceSchedules` comment records at `sync_repository.dart:107`.

- [ ] **Step 1: Write the failing sync test**

Create `test/core/services/sync/certification_currency_sync_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  test('all three entities are registered everywhere', () {
    expect(SyncRepository.hlcTargets['certificationCurrencyRules'],
        (table: 'certification_currency_rules', pk: 'id'));
    expect(SyncRepository.hlcTargets['certificationCurrencyPrefs'],
        (table: 'certification_currency_prefs', pk: 'id'));
    expect(SyncRepository.hlcTargets['certificationCurrencyEvents'],
        (table: 'certification_currency_events', pk: 'id'));

    expect(SyncService.entityHasUpdatedAt['certificationCurrencyRules'], isTrue);
    expect(SyncService.parentRefs['certificationCurrencyPrefs'], [
      (field: 'certificationId', parent: 'certifications', nullable: false),
    ]);
    expect(SyncService.parentRefs['certificationCurrencyEvents'], [
      (field: 'certificationId', parent: 'certifications', nullable: false),
    ]);
  });

  test('the export omits built-in rules, so a refill cannot restore them',
      () async {
    final data = (await serializer.exportData(
      deviceId: 'peer',
      deletions: const [],
    )).data;
    expect(
      data.certificationCurrencyRules,
      isEmpty,
      reason: 'ten built-ins are seeded; none of them may travel',
    );
  });

  test('a custom rule does travel', () async {
    await serializer.upsertRecord('certificationCurrencyRules', {
      'id': 'custom-1',
      'diverId': null,
      'name': 'Club refresher',
      'clockKind': 'activity',
      'applicableAgencies': '["bsac"]',
      'applicableLevels': '[]',
      'lapseDays': 200,
      'leadDays': 30,
      'countedDiveTypeIds': '[]',
      'countedDiveModes': '[]',
      'advisoryKey': null,
      'advisoryText': 'Club rule',
      'supersedesRuleId': 'generic_refresher',
      'isBuiltIn': false,
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': null,
    });
    final data = (await serializer.exportData(
      deviceId: 'peer',
      deletions: const [],
    )).data;
    expect(data.certificationCurrencyRules.single['id'], 'custom-1');
  });

  test('deleteAllRecords spares built-ins and clears custom rules', () async {
    await serializer.deleteAllRecords('certificationCurrencyRules');
    final remaining = await serializer.fetchRecords(
      'certificationCurrencyRules',
    );
    expect(remaining.length, 10);
    expect(remaining.every((r) => r['isBuiltIn'] == true), isTrue);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/services/sync/certification_currency_sync_test.dart`
Expected: FAIL, `hlcTargets` has no such key.

- [ ] **Step 3: Register the three entities at every serializer seam**

Work down the seam list in the Files block above, adding each entity immediately after the `serviceSchedules` entry so payload order, base-table order and apply order agree. Three separate tests pin those orders, so a mismatch is caught rather than shipped.

The rules exporter filters built-ins, mirroring `_exportServiceKinds`:

```dart
  /// Built-ins are re-seeded identically on every device, so exporting one
  /// publishes nothing. Custom rules, including the copy-on-write rules that
  /// supersede a built-in, are ordinary synced rows.
  Future<List<Map<String, dynamic>>> _exportCertificationCurrencyRules(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.certificationCurrencyRules)
      ..where((t) => t.isBuiltIn.equals(false));
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

In `_baseTables`, the rules entry takes the built-in-filtered form used by `serviceKinds` at `:886` (`table: null`, `full: () => _exportCertificationCurrencyRules(null)`). Prefs and events take the plain form.

Add the `deleteAllRecords` case for the rules table only:

```dart
      case 'certificationCurrencyRules':
        await (_db.delete(
          _db.certificationCurrencyRules,
        )..where((t) => t.isBuiltIn.equals(false))).go();
        return;
```

- [ ] **Step 4: Register in the sync service**

`mergeOrder` after the `certifications` entry, `entityHasUpdatedAt` true for all three, and `parentRefs` for prefs and events pointing at `certifications`. Rules have no parent ref (`diverId` is nullable and divers are not a deletable parent in this map; check the `serviceKinds` entry and match whatever it does).

- [ ] **Step 5: Count custom rules as diver-owned rows**

In `lib/features/divers/data/repositories/diver_owned_rows.dart`, beside the
`service_kinds` query at `:170`, add the same shape for
`certification_currency_rules`, scoped to `diver_id` and excluding built-ins:
a seeded rule belongs to the device, not to the diver, so deleting a diver
must never take the catalog with it. Prefs and events are reached through
their certification and need no entry of their own.

Do NOT add a `_hlcBackfillTargets` entry for any of the three tables. That
list exists to stamp rows written before a table gained its `hlc` column;
these tables are born with one, so every row has a clock from its first
write.

- [ ] **Step 6: Update the two hand-kept test maps**

`sync_parent_refs_completeness_test.dart:24`: add the three SQL-table to entity-type pairs.

`sync_builtin_reference_data_test.dart:19`: add `'certification_currency_rules': 'certificationCurrencyRules',` to `_entityForTable`, and a `case` in `_insert` (`:36`) that inserts one minimal custom row. This test auto-discovers every table with an `is_built_in` column from `sqlite_master` and asserts the map covers them, so it fails the moment Task 2 lands and stays failing until this step. That is the intended guard: it is the test written after built-in dive types were permanently wiped by an unguarded adopt.

- [ ] **Step 7: Run the sync tests**

Run: `flutter test test/core/services/sync/certification_currency_sync_test.dart test/core/services/sync/sync_builtin_reference_data_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart`
Expected: all PASS. The last four are auto-discovering tests that fail if any seam was missed.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync lib/features/divers/data/repositories/diver_owned_rows.dart test/core/services/sync
git commit -m "feat(sync): replicate certification currency rules, prefs and events"
```

---

### Task 6: UDDF full backup coverage

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (named params at `:58` and the threading at `:378`, `:385`, `:456`, `:462`, `:519`, `:533`, `:598`, `:612`)
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:739` (`buildApplicationData`, new blocks beside the certifications block at `:930`)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:228` (accumulators and per-block parsers)
- Modify: `lib/core/services/export/models/uddf_import_result.dart` (three fields, defaults, `isEmpty`, total count, summary)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart:1294` (collect and pass)
- Test: `test/core/services/export/uddf/uddf_certification_currency_backup_test.dart` (create)
- Test: `test/features/settings/presentation/providers/export_uddf_certification_currency_test.dart` (create)

**Interfaces:**
- Consumes: Task 3's entities and Task 4's repository.
- Produces: custom rules, prefs and events surviving a full backup round trip.

The `.db` byte-copy backup carries these tables for free. The UDDF full backup is hand-written, so a table absent from it is lost on format conversion, which is how site features were lost. Built-in rules are excluded here too: they are re-seeded on restore, and exporting them would let a stale file overwrite a catalog a newer app is correcting.

- [ ] **Step 1: Write the failing round-trip test**

Create `test/core/services/export/uddf/uddf_certification_currency_backup_test.dart`, modelled on `test/core/services/export/uddf/uddf_dive_roles_backup_test.dart`: build a full backup XML from one custom rule, one pref and one event, parse it back with `UddfFullImportService`, and assert these four things:

```dart
  test('a custom rule survives the round trip with its scope arrays', () async {
    final result = await roundTrip(rules: [customRule]);
    final read = result.currencyRules.single;
    expect(read['id'], 'custom-1');
    expect(read['applicableAgencies'], '["bsac"]');
    expect(read['supersedesRuleId'], 'generic_refresher');
  });

  test('a built-in rule is never written to the file', () async {
    final xml = await buildXml(rules: [builtInCaveRule, customRule]);
    expect(xml, isNot(contains('cave_currency')));
    expect(xml, contains('custom-1'));
  });

  test('an inheriting pref comes back inheriting, not empty', () async {
    // NULL means "inherit the rule's mapping"; '[]' means "any dive counts".
    // A round trip that turns one into the other silently changes the rule.
    final result = await roundTrip(prefs: [inheritingPref]);
    expect(result.currencyPrefs.single['countedDiveTypeIds'], isNull);
  });

  test('an event keeps its date and type', () async {
    final result = await roundTrip(events: [refresherEvent]);
    expect(result.currencyEvents.single['eventType'], 'refresher');
    expect(result.currencyEvents.single['eventDate'], 1758499200000);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/services/export/uddf/uddf_certification_currency_backup_test.dart`
Expected: FAIL, `buildApplicationData` has no such parameters.

- [ ] **Step 3: Write the export blocks**

Add three named parameters to `buildApplicationData` beside `certifications`, and three XML blocks beside the certifications block at `:930`. Include each in the emptiness guard at `:790` so an empty backup stays empty.

- [ ] **Step 4: Thread them through the full export service**

Add the three named parameters at `:58` and pass them at each of the eight call sites listed in Files.

- [ ] **Step 5: Write the import side**

Accumulators beside `certifications` at `:230`, per-block parsers beside `:281`, and the three new fields in `UddfImportResult` including `isEmpty`, the total count and the summary string.

- [ ] **Step 6: Write the provider capture test**

Create `test/features/settings/presentation/providers/export_uddf_certification_currency_test.dart` in the shape of `export_uddf_site_features_test.dart`: a `_CapturingExportService` whose `noSuchMethod` intercepts `#saveAllDataToUddfFile` and records the three named arguments, then assert the provider passed the diver's custom rules, prefs and events. This is the test that catches a correct writer that the app never calls with the data.

- [ ] **Step 7: Run both tests**

Run: `flutter test test/core/services/export/uddf/uddf_certification_currency_backup_test.dart test/features/settings/presentation/providers/export_uddf_certification_currency_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/core/services/export lib/features/settings/presentation/providers/export_providers.dart test/core/services/export/uddf/uddf_certification_currency_backup_test.dart test/features/settings/presentation/providers/export_uddf_certification_currency_test.dart
git commit -m "feat(backup): carry certification currency rules, prefs and events"
```

---

### Task 7: Phase 1 checkpoint

**Files:** none changed unless a check fails.

The full-project verification, the main merge and the PR happen once, after
phase 5. At the end of phase 1:

- [ ] **Step 1: Re-check the schema rung**

Run: `git fetch origin && git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion ="`
Expected: still 260. If another rung landed, renumber 261 everywhere (`database.dart`, the ladder, the migration test file name and its assertions) before continuing.

- [ ] **Step 2: Format, analyze and run the phase 1 tests**

```bash
dart format .
flutter analyze
flutter test test/core/database/migration_v261_certification_currency_test.dart test/core/services/sync test/features/certifications test/architecture
```
Expected: no analyzer issues, all PASS. Do not pipe `flutter analyze` into anything.
