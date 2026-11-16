# My Role in Insights and the Dive Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver see, filter and query their dives by their own role (issue #4409).

**Architecture:** One SQL builder applies `DiveRoleSet.resolve` to a dive. A new
`myRole` query relation to a new `diveRoles` subject uses it; the dive filter
lowers a role list into that relation; the Insights card counts with the same
builder and drills in through the relation, so chart and filter agree by
construction. Explore gains a `myRole` name clause.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), the in-repo query language
(`lib/core/query`), ARB localization.

**Spec:** `docs/design/specs/2026-11-16-own-role-insights-design.md`

## Global Constraints

- Counting: a dive with several roles counts once under each; a dive with no role counts once under Not set.
- Role set rule: exactly `DiveRoleSet.resolve` (blank scalar = no role; junction only when its normalized primary equals the scalar; else `[scalar]`; Solo dropped beside another role).
- Only role ids with a `dive_roles` row visible to the diver (built-in, `diver_id IS NULL`, or `diver_id = active diver`) count, in chart and relation alike.
- The `role` query field keeps key `role` and ops `isEmpty`/`isSet`; it loses only the `myRole` alias.
- `kQuerySchemaVersion` goes from 5 to 6.
- No schema change, no migration. Files under 800 lines. No em-dashes anywhere. Every new ARB key is added to all 11 locales in the task that introduces it (completeness guards would fail a task that adds English only), then `flutter gen-l10n`.
- TDD; `dart format .`, `flutter analyze`, affected tests, and `test/architecture/` (new `lib/` files) before each commit. Never the full suite.

## Review Focus

1. Stale junction (an older app version changed `diver_role` after the junction was written): the dive counts only under its scalar role, in chart and filter. Test in Task 1.
2. Solo beside another role in the junction: Solo is not counted; a dive whose scalar is Solo with other junction rows counts only as Solo. Test in Task 1.
3. Another diver's custom role: not in the picker, not counted, not matched. Test in Task 4.
4. Insights scope already narrowed to a role, then a bar tapped: the drill-in ANDs, so tapping Safety Diver while scoped to Instructor opens only dives with both. Test in Task 4.
5. Non-English locale: built-in names localized on chips, bars and printed queries; typed English names still parse. Test in Task 2 (name index) and Task 4 (widget).

---

### Task 1: Resolved role-set SQL

**Files:**
- Create: `lib/features/dive_roles/data/diver_role_set_sql.dart`
- Test: `test/features/dive_roles/data/diver_role_set_sql_test.dart`

**Interfaces:**
- Produces: `String diverRoleIdsOfDiveSql({required String diveId, required String scalar})`, a `SELECT` yielding one column of role ids for the dive whose id expression is `diveId` and whose `diver_role` expression is `scalar` (for example `'{from}.id'`, `'{from}.diver_role'`, or `'d.id'`, `'d.diver_role'`). Binds no parameters; built-in ids are inlined from `DiveRole.builtInIds`.

- [ ] **Step 1: Write the failing test.** `diverRoleIdsOfDiveSql matches DiveRoleSet.resolve`: an in-memory `AppDatabase` seeded with one dive per case, running `SELECT x FROM (<sql with 'd.id','d.diver_role'>) ...` per dive and comparing the set to `DiveRoleSet.resolve(scalar:, junction:)`. Cases (scalar / junction rows / expected):
  - `null` / `[instructor]` / `[]`
  - `''` / `[]` / `[]`
  - `instructor` / `[]` / `[instructor]`
  - `instructor` / `[instructor, safetyDiver]` / `[instructor, safetyDiver]`
  - `buddy` / `[instructor, buddy]` / `[buddy]` (stale: junction primary is instructor)
  - `solo` / `[solo]` / `[solo]`
  - `solo` / `[solo, buddy]` / `[solo]` (stale: Solo dropped, primary buddy)
  - `instructor` / `[instructor, solo]` / `[instructor]`
  - `<uuid-b>` / `[<uuid-b>, <uuid-a>]` / `[<uuid-b>]` (stale: uuid-a sorts first)
  - `<uuid-a>` / `[<uuid-a>, <uuid-b>, buddy]` / `[<uuid-a>, <uuid-b>, buddy]`
  - `instructor` / `[instructor, instructor]` / `[instructor]` (duplicates)
- [ ] **Step 2:** Run `flutter test test/features/dive_roles/data/diver_role_set_sql_test.dart`; expect FAIL (function not defined).
- [ ] **Step 3: Implement.** Rank expression `CASE id WHEN '<builtInIds[i]>' THEN i ... ELSE builtInIds.length END`, with buddy ranked `builtInIds.length + 1`. The junction is current when the scalar is non-blank, a junction row equals it, the scalar is not Solo unless every non-blank row is Solo, and no non-blank, non-Solo row ranks before it by `(rank, id)`. Output: the scalar alone when it is non-blank and the junction is not current; otherwise the distinct non-blank junction ids, Solo kept only when the scalar is Solo.
- [ ] **Step 4:** Re-run; expect PASS.
- [ ] **Step 5:** Commit `feat(dive-roles): resolve a dive's own role set in SQL`.

### Task 2: `diveRoles` query subject and `myRole` relation

**Files:**
- Modify: `lib/core/query/domain/query_subject.dart` (add `diveRoles`, a relation target of dives)
- Create: `lib/features/dive_roles/query/dive_role_query_entity.dart`
- Modify: `lib/features/query/app_query_registry.dart` (register the entity)
- Modify: `lib/core/query/names/name_index.dart` (`NameTarget.diveRoleId`, `rowTargetFor`)
- Modify: `lib/features/query/data/name_index_loader.dart` (`refSubjects`, `_extra: ['is_built_in']`, `_builtInTypeName` uses `builtInDiveRoleName`)
- Modify: `lib/features/dive_log/query/dive_query_entity.dart` (drop the `role` field's `myRole` alias; add the relation)
- Modify: any exhaustive switch the compiler flags (rules labels, Explore subject switches)
- Modify: `lib/l10n/arb/app_en.arb` (query labels for the subject, its fields and the relation, following `query_diveTypes_*` naming)
- Test: `test/features/dive_roles/query/dive_role_query_test.dart`; update `test/features/query/app_query_registry_test.dart` and `test/features/query/data/name_index_loader_test.dart` if they enumerate subjects

**Interfaces:**
- Consumes: `diverRoleIdsOfDiveSql` (Task 1).
- Produces: query path `myRole` (alias `myRoles`) on dives; `QuerySubject.diveRoles`; `NameTarget.diveRoleId`; entity `diveRoleQueryEntity` with fields `name` (text), `builtIn` (bool), `diverScopeColumn: 'diver_id'`.

Relation: `QueryRelation(key: 'myRole', aliases: ['myRoles'], target: QuerySubject.diveRoles, shape: RelationShape.custom, joinSql: '{to}.id IN (${diverRoleIdsOfDiveSql(diveId: '{from}.id', scalar: '{from}.diver_role')})', isMany: true, emptySql: "({from}.diver_role IS NULL OR {from}.diver_role = '')", tables: ['dive_diver_roles'])`.

- [ ] **Step 1: Write the failing tests** (seeded in-memory DB, compiled through the app registry, as the existing dive query tests do):
  - `myRole = instructor ref matches a secondary role`: a dive with scalar `instructor`, junction `[instructor, safetyDiver]` is returned by `myRole = <safetyDiver ref>`.
  - `myRole ignores a stale junction`: scalar `buddy`, junction `[instructor, buddy]` is not returned by `myRole = <instructor ref>`.
  - `myRole:none matches what role:none matched` and `myRole:any matches what role:any matched`, over the same seeded dives.
  - `myRole resolves to the relation, role to the field`: `resolvePath` on `['myRole']` gives a relation hop; on `['role']` the text field.
  - `another diver's custom role is not matched`: custom role row with `diver_id = other` on the active diver's dive yields nothing for `myRole = <that ref>`.
  - Name index: built-in `instructor` gets the localized label under `de` and the English stored name as an alternate; a custom role keeps its stored name.
- [ ] **Step 2:** Run the new test file; expect FAIL.
- [ ] **Step 3: Implement** the files above; follow `diveTypeQueryEntity` and the dive types entries in the name index loader. Add the ARB keys in `app_en.arb` next to the `query_diveTypes_*` group and run `flutter gen-l10n`.
- [ ] **Step 4:** Run the new tests plus `test/features/query/`, `test/core/query/` and `test/features/explore/`; expect PASS.
- [ ] **Step 5:** Commit `feat(query): query dives by the diver's own role`.

### Task 3: My role filter axis

**Files:**
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart` (`final List<String> diverRoleIds`, default `const []`; constructor, active-axis list, `==`, `hashCode`, `copyWith(diverRoleIds:, clearDiverRoleIds:)`, mirroring `waterTypes`)
- Modify: `lib/features/dive_log/query/dive_filter_query.dart` (role choices: `myRole inList refs(diverRoleIds)` and, when `noRoleOnly`, `role isEmpty`; one choice alone, two as `OrNode`, as the water choices do)
- Modify: `lib/features/dive_log/presentation/widgets/refine/groups/refine_people_group.dart` (replace the No Role Assigned switch with a My role chip row: one `FilterChip` per role from `allDiveRolesProvider`, `localizedName(l10n)`, plus a Not set chip bound to `noRoleOnly`; axis keys gain `'diverRoleIds'`)
- Modify: `lib/features/dive_log/presentation/widgets/active_filter_chips.dart`, `active_filter_chip_labels.dart` (one chip for the role axis, labelled like the water type chip: the single role's name, or a count)
- Modify: `lib/l10n/arb/app_en.arb` (`diveLog_filter_myRole` label, `diveLog_filter_myRole_notSet`, chip count string)
- Test: `test/features/dive_log/query/dive_filter_save_census_test.dart` (samples `diverRoleIds` and `diverRoleIds with noRoleOnly`), `test/features/dive_log/query/dive_filter_query_test.dart` (lowering), refine people group widget test, active filter chip test

**Interfaces:**
- Consumes: `myRole` path (Task 2).
- Produces: `DiveFilterState.diverRoleIds`, `copyWith(diverRoleIds: List<String>?, clearDiverRoleIds: bool)`.

- [ ] **Step 1: Write the failing tests:**
  - lowering: `diverRoleIds: ['instructor']` gives `myRole in [instructor]`; with `noRoleOnly: true` gives `OrNode([myRole in [...], role isEmpty])`; `noRoleOnly` alone is unchanged.
  - census: both new samples survive save, relabel, print and re-parse.
  - widget: Refine > People shows a chip per role (localized built-ins, the diver's custom roles) and Not set; tapping Instructor sets `diverRoleIds: ['instructor']`; tapping Not set sets `noRoleOnly: true`; the old switch key `kRefineNoRoleSwitchKey` is gone.
  - chips: one active chip for the role axis; removing it clears both `diverRoleIds` and `noRoleOnly`.
- [ ] **Step 2:** Run them; expect FAIL.
- [ ] **Step 3: Implement** as listed.
- [ ] **Step 4:** Run the touched test files plus `test/features/dive_log/query/` and `test/features/dive_log/presentation/widgets/`; expect PASS.
- [ ] **Step 5:** Commit `feat(dive-log): filter dives by my role`.

### Task 4: My role card on Insights > Social

**Files:**
- Create: `lib/features/insights/data/repositories/insights_repository_roles.dart` (extension on `InsightsRepository`, as `insights_repository_focus.dart` is, or a part file if `_db`/`_diveFilter` are private to the library)
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart` (`diverRoleDistributionProvider`, scoped like `diveTypeDistributionProvider`)
- Modify: `lib/features/insights/presentation/insights_dive_filters.dart` (`diverRoleDivesFilter`)
- Create: `lib/features/insights/presentation/widgets/my_role_card.dart`
- Modify: `lib/features/insights/presentation/pages/insights_social_page.dart` (card after Solo vs Buddy)
- Modify: `lib/l10n/arb/app_en.arb` (`insights_social_myRole_title`, `_subtitle`, `_empty`, `_error`, `_notSet`, and an info summary noting the once-per-role counting)
- Test: `test/features/insights/data/insights_repository_roles_test.dart`, `test/features/insights/presentation/widgets/my_role_card_test.dart`

**Interfaces:**
- Consumes: `diverRoleIdsOfDiveSql` (Task 1), `myRole` path (Task 2).
- Produces: `Future<List<DistributionSegment>> getDiverRoleDistribution({String? diverId, DiveFilterState filter = const DiveFilterState()})`, keyed by role id, plus a segment keyed `kNotRecordedDistributionKey`, count descending; `DiveFilterState diverRoleDivesFilter(DiveFilterState scope, String key)`.

Query shape: `FROM dive_roles dr JOIN dives d ON dr.id IN (<diverRoleIdsOfDiveSql('d.id','d.diver_role')>)`, role visibility `(dr.diver_id IS NULL OR dr.diver_id = ?)`, the usual diver and `_diveFilter` clauses, `GROUP BY dr.id`, with `COUNT(*)` and `SUM(measuredRuntimeSecondsSql('d'))`; Not set counted by a second query over blank `diver_role`.

- [ ] **Step 1: Write the failing tests:**
  - counts: seeded dives give Instructor 2, Safety Diver 1, Not set 1 for a dive set where one dive holds both Instructor and Safety Diver; summed times match.
  - agreement: for every returned segment, `getCountedDiveIds(filter: diverRoleDivesFilter(scope, key))` has exactly `count` ids (including Not set).
  - stale junction and Solo cases from Task 1 counted as their resolved sets.
  - another diver's custom role on a dive is not a segment.
  - scope AND: `diverRoleDivesFilter(DiveFilterState(diverRoleIds: ['instructor']), 'safetyDiver')` returns only dives holding both.
  - widget: bars show localized names under `de`, Not set label, counts; tapping a bar calls `openFilteredChartDives`; empty and error states render their strings.
- [ ] **Step 2:** Run them; expect FAIL.
- [ ] **Step 3: Implement.** Bars reuse `DistributionBarRow` with the overview's dive type styling; `diverRoleDivesFilter` ANDs `myRole = RefValue(key, key)` or, for `kNotRecordedDistributionKey`, `role isEmpty`, via `_withConditions`.
- [ ] **Step 4:** Run the new tests plus `test/features/insights/`; expect PASS.
- [ ] **Step 5:** Commit `feat(insights): break dives down by my role`.

### Task 5: Explore understands my role

**Files:**
- Modify: `lib/features/explore/domain/explore_fields.dart` (`ExploreField('myRole', ['myRole', 'name'], ExploreValueKind.typeName)` beside `diveType`)
- Modify: `lib/features/explore/domain/nl_engine.dart` (prompt line: `myRole: the name of the diver's own role on the dive, such as Instructor or Dive Guide.`)
- Modify: `lib/features/explore/domain/query_model.dart` (`kQuerySchemaVersion = 6`)
- Test: `test/features/explore/domain/explore_compiler_query_fields_test.dart`, `nl_prompt_test.dart`, `query_model_test.dart`, and any fixture pinned to version 5

- [ ] **Step 1: Write the failing tests:** a clause `{field: myRole, op: eq, value: "Instructor"}` compiles to `myRole.name in ["Instructor"]` and matches a seeded dive whose secondary role is Instructor; the prompt contains the `myRole` line; the schema version is 6.
- [ ] **Step 2:** Run them; expect FAIL.
- [ ] **Step 3: Implement** as listed; update version-pinned fixtures.
- [ ] **Step 4:** Run `test/features/explore/`; expect PASS.
- [ ] **Step 5:** Commit `feat(explore): understand my role in plain-language queries`.

### Task 6: Final checks

- [ ] **Step 1:** Run `test/architecture/`, `test/shared/` and the l10n guards (ARB completeness, info-sentence cap); expect PASS.
- [ ] **Step 2:** `dart format .` and `flutter analyze`; expect no issues. Commit any formatting as `style: format`.
