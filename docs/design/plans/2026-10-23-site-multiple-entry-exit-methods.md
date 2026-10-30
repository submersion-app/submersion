# Several Entry and Exit Methods per Dive Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dive site records any number of entry and exit methods; dives stay single-valued and never inherit a guess.

**Architecture:** `DiveSite.entryMethod`/`exitMethod` become `List<EntryMethod> entryMethods`/`exitMethods`, stored comma-joined (enum order) in the existing `dive_sites.entry_method`/`exit_method` text columns through one codec. Every "the site's method" reader goes through `soleEntryMethod`/`soleExitMethod` (non-null only for exactly one), so single-method sites behave exactly as today. Boat/Shore labels drop "entry" in all 11 ARB files.

**Tech Stack:** Flutter, Drift, Riverpod, ARB/gen-l10n.

**Spec:** `docs/design/specs/2026-10-23-site-multiple-entry-exit-methods-design.md`

## Global Constraints

- No schema bump, no migration: a single method is stored exactly as today (`shore`); empty list stored as null.
- Stored list format: enum names, enum declaration order, deduplicated, joined by `,` with no spaces.
- Dives stay single-valued; no change to `dives` columns or the dive form's Entry/Exit pickers.
- `EntryMethod.displayName` ("Shore Entry", "Boat Entry") is unchanged.
- UDDF is out of scope.
- No em-dash characters anywhere; no emojis; `dart format .` before each commit.

## Review Focus

1. A stored value with an unknown name (`shore,jetpack`, written by a newer peer) decodes to the known names only, and `jetpack` alone decodes to empty. Test in Task 1.
2. A stored value with stray spaces or a duplicate (`boat, shore,boat`) decodes to `[shore, boat]`. Test in Task 1.
3. A site with one entry and several exits assigned to a linked dive keeps the dive's current exit, not exit = entry. Test in Task 3.
4. A multi-method site's dives fall into "not recorded" in the Insights entry-method distribution and focus factors, not a `shore,boat` bucket. Test in Task 4.
5. Exit list equal to entry list in a different tick order is not shown as a separate Exit row on the site page. Test in Task 6.

---

### Task 1: Entry-method list codec

**Files:**
- Create: `lib/features/dive_sites/domain/entry_method_list.dart`
- Test: `test/features/dive_sites/domain/entry_method_list_test.dart`

**Interfaces:**
- Produces: `String? encodeEntryMethods(Iterable<EntryMethod> methods)`; `List<EntryMethod> decodeEntryMethods(String? stored)`; `List<EntryMethod> canonicalEntryMethods(Iterable<EntryMethod> methods)` (dedupe + enum order).

- [ ] **Step 1: Write the failing tests**

```dart
expect(encodeEntryMethods(const []), isNull);
expect(encodeEntryMethods(const [EntryMethod.shore]), 'shore');
expect(encodeEntryMethods(const [EntryMethod.boat, EntryMethod.shore, EntryMethod.boat]), 'shore,boat');
expect(decodeEntryMethods(null), isEmpty);
expect(decodeEntryMethods(''), isEmpty);
expect(decodeEntryMethods('shore'), [EntryMethod.shore]);
expect(decodeEntryMethods('boat, shore,boat'), [EntryMethod.shore, EntryMethod.boat]);
expect(decodeEntryMethods('shore,jetpack'), [EntryMethod.shore]);
expect(decodeEntryMethods('jetpack'), isEmpty);
// round trip for every value
for (final m in EntryMethod.values) { expect(decodeEntryMethods(encodeEntryMethods([m])), [m]); }
```

- [ ] **Step 2: Run** `flutter test test/features/dive_sites/domain/entry_method_list_test.dart`; expect FAIL (file missing).
- [ ] **Step 3: Implement** the three functions. `canonicalEntryMethods` sorts by `index` after `toSet()`.
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): codec for a site's list of entry methods`.

### Task 2: Entity, storage and mechanical moves to the list

Renaming the fields breaks every consumer at compile time; this task moves them all, keeping single-method behaviour identical. Behaviour changes for several methods come in Tasks 3 to 7.

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart` (fields, constructor, `copyWith`, `props`)
- Modify: `lib/features/dive_sites/data/mappers/dive_site_row_mapper.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (4 companion writes, lines ~178, ~300, ~1192, ~1559)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (~2024, ~2115: `decodeEntryMethods(siteData['entryMethod'] as String?)`)
- Modify: `lib/core/services/shared_library/site_document_bridge.dart:121-122` (`encodeEntryMethods`)
- Modify: every other compile error `flutter analyze` reports in `lib/` and `test/` (about 25 test files construct `DiveSite(entryMethod: X)`; they become `entryMethods: [X]`)
- Test: `test/features/dive_sites/domain/entities/dive_site_entry_exit_test.dart`, `test/features/dive_log/data/repositories/dive_repository_site_mapping_test.dart`

**Interfaces:**
- Consumes: Task 1 codec.
- Produces: `DiveSite.entryMethods`, `DiveSite.exitMethods` (`List<EntryMethod>`, default `const []`, canonical order enforced by writers via `canonicalEntryMethods`); getters `EntryMethod? get soleEntryMethod` and `EntryMethod? get soleExitMethod` (the method when the list has exactly one, else null); `copyWith({List<EntryMethod>? entryMethods, List<EntryMethod>? exitMethods})`.

- [ ] **Step 1: Write failing tests** in `dive_site_entry_exit_test.dart`: `soleEntryMethod` is null for `[]` and `[shore, boat]`, `shore` for `[shore]`; `copyWith(entryMethods: const [])` clears; two sites with equal lists are `==`. In `dive_repository_site_mapping_test.dart`: a row with `entry_method = 'shore,boat'` maps to `entryMethods == [shore, boat]`, and saving a site with `[boat, shore]` stores `'shore,boat'`.
- [ ] **Step 2: Run** them; expect FAIL (compile).
- [ ] **Step 3: Implement** the entity change, mapper (`decodeEntryMethods(row.entryMethod)`), repository writes (`Value(encodeEntryMethods(site.entryMethods))`), importer and bridge.
- [ ] **Step 4: Fix remaining compile errors.** Run `flutter analyze`. For each error: a reader that meant "the site's one method" uses `soleEntryMethod`/`soleExitMethod`; a writer passes a list. Do not add behaviour here beyond Tasks 3 to 7's own steps; where a later task owns the file, use `soleX` as the interim and leave the rest to it.
- [ ] **Step 5: Run** `flutter analyze` (clean), the two tests, and `flutter test test/features/dive_sites test/core/services/shared_library test/features/dive_import`; expect PASS.
- [ ] **Step 6: Commit** `feat(dive-sites): store a list of entry and exit methods per site`.

### Task 3: Site assignment and effective fallback never guess

**Files:**
- Modify: `lib/features/dive_log/presentation/utils/entry_exit_autofill.dart` (`entryExitAfterSiteAssign`)
- Modify: `lib/features/dive_log/domain/entities/dive.dart:371` (`effectiveEntryMethod => entryMethod ?? site?.soleEntryMethod`)
- Test: `test/features/dive_log/presentation/utils/entry_exit_autofill_test.dart`, `test/features/dive_log/domain/entities/dive_effective_entry_method_test.dart`, `test/features/dive_log/data/repositories/` site-snap test (whichever file covers `siteSnapColumns`; add one if none)

**Interfaces:**
- Consumes: `soleEntryMethod`, `soleExitMethod`, `exitMethods`.

- [ ] **Step 1: Write failing tests** for `entryExitAfterSiteAssign` (current dive: entry null, exit null, linked true unless noted):
  - site entries `[shore, boat]`: entry stays null, exit stays null.
  - site entries `[shore, boat]`, current entry `ladder`: entry stays `ladder`.
  - site entries `[boat]`, exits `[ladder, shore]`, linked: entry `boat`, exit stays null (not `boat`).
  - site entries `[boat]`, exits `[ladder, shore]`, current exit `ladder`, linked false: exit stays `ladder`.
  - site entries `[boat]`, exits `[]`: entry `boat`, exit `boat` (today's behaviour).
  - site entries `[boat]`, exits `[ladder]`: exit `ladder` (today's behaviour).
  - `effectiveEntryMethod`: dive entry null, site `[shore, boat]` gives null; site `[shore]` gives `shore`.
  - `siteSnapColumns` with a `[shore, boat]` site leaves `entryMethod` and `exitMethod` `Value.absent()`.
- [ ] **Step 2: Run**; expect the multi-method cases to FAIL.
- [ ] **Step 3: Implement.** Site entry = `site?.soleEntryMethod`; explicit site exit = `site?.soleExitMethod`; the "exit follows entry" branch is skipped when `site != null && site.exitMethods.length >= 2`. Update the doc comment's rule list to say so.
- [ ] **Step 4: Run** the tests plus `flutter test test/features/dive_log/presentation/pages/dive_edit_site_entry_method_test.dart test/features/dive_log/presentation/pages/dive_detail_inherited_site_fields_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): leave a dive's entry and exit alone for a multi-method site`.

### Task 4: Insights SQL falls back only to a single-method site

**Files:**
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (~1421-1422)
- Modify: `lib/features/insights/data/repositories/insights_repository_focus.dart` (~47)
- Test: the existing Insights entry-method distribution and focus-factor repository tests (find with `grep -rln "entry_method\|entryMethod" test/features/insights`)

- [ ] **Step 1: Write failing tests:** a dive with no entry method at a site stored `'shore,boat'` counts under `kNotRecordedDistributionKey` in the entry-method distribution, and has `entryMethod == null` in the focus-factor rows; a dive at a site stored `'shore'` still counts as `shore`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** Replace each `NULLIF(<site>.entry_method, '')` fallback with `CASE WHEN instr(<site>.entry_method, ',') = 0 THEN NULLIF(<site>.entry_method, '') END`. Check `grep -rn "entry_method\|exit_method" lib --include='*.dart'` for any other site-column fallback and apply the same.
- [ ] **Step 4: Run** `flutter test test/features/insights`; expect PASS.
- [ ] **Step 5: Commit** `feat(insights): count a multi-method site's dives as not recorded`.

### Task 5: Multi-select on the site edit page

**Files:**
- Create: `lib/shared/widgets/forms/enum_multi_picker_row.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (state ~144, load ~382, merge ~557-579 and ~1484-1502, suggestion ~887-923, summary ~1010-1014, section wiring ~1159-1171, save ~2063)
- Test: `test/shared/widgets/forms/enum_multi_picker_row_test.dart`, `test/features/dive_sites/presentation/pages/site_edit_entry_method_test.dart`, `site_edit_merge_entry_method_test.dart`, `site_edit_entry_suggestion_test.dart`

**Interfaces:**
- Produces: `EnumMultiPickerRow<T extends Enum>({required String label, required List<T> value, required List<T> values, required String Function(T) displayName, required ValueChanged<List<T>> onChanged, String? placeholder})`. A `FormRow.picker` whose value is `value.map(displayName).join(', ')` (placeholder `diveLog_edit_notSpecified` when empty); tapping opens a modal bottom sheet (`showDragHandle: true`, as in `DiveTypeMultiSelectField`) of `CheckboxListTile`s, one per `values`, each toggle calling `onChanged` immediately with the selection in `values` order. Empty selection is allowed.
- `AccessSafetySection`: `entryMethods`/`exitMethods` (`List<EntryMethod>`) and `ValueChanged<List<EntryMethod>>` callbacks replace the single-value ones.

- [ ] **Step 1: Write failing widget tests** for `EnumMultiPickerRow`: shows "Not specified" for `[]`; shows `"Shore Entry, Boat Entry"`-style joined names (use a test enum and plain `displayName`); ticking two items in reverse order reports them in `values` order; unticking the last reports `[]`.
- [ ] **Step 2: Write failing page tests:** editing a site, ticking Shore and Boat for entry and saving stores `[shore, boat]`; the merge candidates for two sites with `[shore]` and `[shore, boat]` cycle between the two whole lists (and two sites with equal lists give one candidate, via `listEquals`); the "most logged" chip still appears only when both lists are empty and fills `[entry]` and `[exit]` (or `[]` when the suggestion has no exit).
- [ ] **Step 3: Run**; expect FAIL.
- [ ] **Step 4: Implement** the widget, then the section and page. Merge candidates use `_buildDistinctCandidates<List<EntryMethod>>(..., equals: listEquals)` and `_firstMeaningfulIndex(..., (v) => v.isNotEmpty)`. The form summary lists entry names, then exit names when `!setEquals(exit.toSet(), entry.toSet())` and exit is non-empty.
- [ ] **Step 5: Run** the tests, `flutter test test/features/dive_sites test/shared` and `flutter test test/architecture`; expect PASS.
- [ ] **Step 6: Commit** `feat(dive-sites): pick several entry and exit methods on the site form`.

### Task 6: Site page and site list show the lists

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (~1339-1340, ~2057-2075)
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart:720-723`
- Test: `test/features/dive_sites/presentation/pages/site_detail_entry_method_test.dart`, `test/features/dive_sites/domain/constants/site_field_entry_method_test.dart`

- [ ] **Step 1: Write failing tests:** detail page for entries `[shore, boat]` shows one Entry row reading the two localized names joined by ", "; exits `[boat, shore]` (same set) shows no Exit row; exits `[ladder]` shows an Exit row. Site list `extractValue(SiteField.entryType, ...)` for `[shore, boat]` is `'Shore Entry, Boat Entry'` (displayName, unchanged vocabulary) and null for `[]`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** Exit row condition: `exitMethods.isNotEmpty && !setEquals(exitMethods.toSet(), entryMethods.toSet())`.
- [ ] **Step 4: Run** the tests and `flutter test test/features/dive_sites`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): show every entry and exit method on the site page`.

### Task 7: Exports, CSV import and sync conflict labels

**Files:**
- Modify: `lib/core/services/export/csv/csv_sites_writer.dart:85,99` (`joinCsvList(methods.map((m) => m.displayName))`)
- Modify: `lib/core/services/export/excel/excel_export_service.dart:393` (entry only, joined `', '`)
- Modify: `lib/core/services/export/kml/kml_export_service.dart:232-240` (entry joined `', '`; exit when non-empty and a different set)
- Modify: `lib/features/universal_import/data/parsers/submersion_csv/submersion_sites_csv_parser.dart:131-156` (split with `splitCsvList` + `unescapeCsvListItem`, match each by `displayName`, emit `encodeEntryMethods(...)`)
- Modify: `lib/features/settings/presentation/conflicts/conflict_enum_labels.dart:35-38` (`entryMethodLabeler`)
- Test: `test/core/services/export/csv/` sites writer test, the Excel and KML export tests, the Submersion CSV sites parser test, and the conflict-labels test (find each with `grep -rln`)

**Interfaces:**
- Consumes: Task 1 codec; `joinCsvList`, `splitCsvList`, `unescapeCsvListItem` from `lib/core/services/export/csv/codec/csv_list_codec.dart`.

- [ ] **Step 1: Write failing tests:** CSV writes `Shore Entry; Boat Entry` for `[shore, boat]` and `Shore Entry` for `[shore]`; CSV parser reads `Shore Entry; Boat Entry` back to `'shore,boat'` and `Shore Entry` to `'shore'`, ignoring an unknown item; CSV export-then-import round trip keeps `[shore, boat]`; KML shows `Entry: Shore Entry, Boat Entry` and no Exit line for an equal set; Excel writes `Shore Entry, Boat Entry`; `entryMethodLabeler(l10n, 'shore,boat')` returns the two localized names joined by ", ", `'shore'` returns one name, `'jetpack'` returns null.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** `entryMethodLabeler`: when the stored value contains `,`, decode with `decodeEntryMethods` and join localized names with ", " (null if the decode is empty); otherwise the existing single-name behaviour.
- [ ] **Step 4: Run** the tests plus `flutter test test/core/services/export test/features/universal_import test/features/settings`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): export and import a site's list of entry and exit methods`.

### Task 8: Boat and Shore labels without "entry"

**Files:**
- Modify: `enum_entryMethod_boat` and `enum_entryMethod_shore` in all 11 `lib/l10n/arb/app_*.arb`, then regenerate with `flutter gen-l10n`.

| Locale | boat | shore |
| --- | --- | --- |
| en | Boat | Shore |
| fr | Bateau | Bord |
| de | Boot | Ufer |
| es | Barco | Costa |
| it | Barca | Riva |
| nl | Boot | Kant |
| pt | Barco | Praia |
| hu | Hajó | Part |
| ar | القارب | الشاطئ |
| he | סירה | חוף |
| zh | 船只 | 岸边 |

- [ ] **Step 1:** Edit the ARB values with a script that edits only those two keys per file (preserve CRLF if a file uses it; check `git diff --numstat` shows 2 changed lines per ARB).
- [ ] **Step 2:** `flutter gen-l10n`.
- [ ] **Step 3: Run** `grep -rn "Boat Entry\|Shore Entry" test` and fix any test that asserted the old localized label (displayName assertions stay). Run `flutter test test/features/dive_sites test/features/dive_log/presentation test/l10n` (whichever exist); expect PASS.
- [ ] **Step 4: Commit** `feat(l10n): Boat and Shore labels read as entry or exit`.

### Task 9: Final verification

- [ ] `dart format .`, `flutter analyze` (clean), `flutter test test/architecture test/shared`, and the affected feature folders: `test/features/dive_sites test/features/dive_log test/features/insights test/core/services test/features/universal_import test/features/settings test/features/rules test/features/dive_import`.
- [ ] Rules: `site_rule_applier.dart` writes a single enum name into the column, which decodes to a one-item list, so "set entry method" already replaces the list as the spec says. Confirm `flutter test test/features/rules` passes; no code change expected.
- [ ] Spec check: walk the spec's Behaviour and Storage sections against the diff.
