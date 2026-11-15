# Site catalogue gap fill (slice 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pair a diver's existing sites with built-in catalogue records, let the diver review the pairs, and on their say-so link each site and fill only its empty fields.

**Architecture:** Two pure rules in the dive sites domain (which record pairs with a site; what a record would add) are fed by the catalogue's `near` and `byId` reads and one new exact-name read. One repository write applies a pair inside a transaction, re-running the offer rule on the fresh row so a value typed meanwhile is never overwritten. A new synced text column on the site remembers answers and merged-away records; for shared library sites the same two values ride the profile's `library_site_notes` record. A review page, a comparison sheet, a notice and a site page line all read one provider of current pairs.

**Tech Stack:** Flutter, Dart, Drift (main database schema 364 to 365), Riverpod (`flutter_riverpod` with legacy `StateNotifier`), go_router, ARB localisation in 11 locales.

**Spec:** `docs/design/specs/2026-11-14-site-catalogue-gap-fill-design.md`

## Global Constraints

- Tests first for every task. Run one test file per `flutter test` invocation, with output redirected to a `.txt` file in the session scratchpad. Never run the whole suite locally.
- Main schema goes 364 to 365. Renumber if main has moved. (It had: the step shipped as 369, and the test file is `migration_v369_site_catalogue_answers_test.dart`.) Tables in `lib/core/database/tables/`, rungs in `lib/core/database/migrations/ladder/`, the backstop in `before_open_child_columns.dart`. Nothing new in `database.dart` beyond the version constant and the `migrationVersions` entry.
- After changing a table, run `dart run build_runner build --delete-conflicting-outputs` unfiltered (never `--build-filter`), then `dart run tool/generate_sql_column_notes.dart`.
- New repository code does not go into `site_repository_impl.dart` (2,053 lines), `site_list_content.dart` (1,838) or `shared_library_store.dart` (834) beyond one-line insertions and the edits to existing methods named below.
- The pairing distance is 150 m, one constant: `kCataloguePairRadiusMeters`.
- Only fields that are empty at the moment of writing are filled. Name, notes, rating, access notes, parking, mooring number, exit methods and an existing position are never written.
- Depths and distances shown go through `UnitFormatter`.
- Every new string is in all 11 ARB files; run `flutter gen-l10n` and commit the generated files. No plurals: counts go in brackets.
- No button or chip in `ListTile.trailing`. A snack bar with an action states `persist`. A scroll-controlled bottom sheet states `useSafeArea`. A provider whose body calls a repository self-invalidates or carries `// no-tick: <reason>`.
- No em-dashes, no spaced hyphens as punctuation, no emojis, in code, comments, docs and commit messages. No mention of the tool or model anywhere.
- Paths are built with `p.join`. A test that replaces process-wide state restores it.
- `dart format .` before each commit; `flutter analyze` on the whole repo before pushing.
- Never commit `test/zz_shots/`.

## Review Focus

1. A site whose name is blank, or folds to an empty key (punctuation only): it must pair with nothing by name. Test in Task 4.
2. `catalogue_answers` holding text that is valid JSON of the wrong shape (an array, a number, a `declined` whose values are strings): it reads as empty and the site list still loads. Test in Task 1.
3. A record id that is a prefix of another (`osm_node_1`, `osm_node_12`) or contains a LIKE wildcard (`_`): the "stands for" lookup must match the exact id only. Test in Task 2.
4. Apply pressed twice, or pressed while the pairs recompute: the second press writes nothing and counts nothing twice. Test in Task 12.
5. The catalogue not imported yet, or empty: no pairs, no error, no notice, and the review page shows its empty state. Tests in Tasks 9 and 12.

## File Structure

Created:

| File | Responsibility |
|---|---|
| `lib/features/dive_sites/domain/entities/site_catalogue_answers.dart` | The value object behind `dive_sites.catalogue_answers`, with its JSON codec |
| `lib/features/dive_sites/domain/catalogue_gaps/catalogue_name_key.dart` | Name folding for equality |
| `lib/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart` | The offerable fields |
| `lib/features/dive_sites/domain/catalogue_gaps/catalogue_offer.dart` | What a record would add to a site |
| `lib/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart` | A pair and its kind |
| `lib/features/dive_sites/domain/catalogue_gaps/catalogue_pairing.dart` | Which record pairs with which site |
| `lib/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart` | The apply write and the answers write |
| `lib/features/dive_sites/data/services/catalogue_gap_service.dart` | Gathers candidates, finds pairs, applies requests |
| `lib/features/dive_sites/data/services/catalogue_sea_name.dart` | A record's sea in the diver's place-name language (moved out of the adoption service) |
| `lib/core/database/migrations/helpers/site_catalogue_answers_migrations.dart` | The v365 columns |
| `lib/core/services/shared_library/library_site_catalogue.dart` | Keeping a library site's link and answers for a profile |
| `lib/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart` | Service, pairs, per-site pair, notice memory |
| `lib/features/dive_sites/presentation/providers/catalogue_gap_review_notifier.dart` | Review page state |
| `lib/features/dive_sites/presentation/catalogue_gap_display.dart` | Field labels, values and the "Adds" line |
| `lib/features/dive_sites/presentation/pages/catalogue_gap_review_page.dart` | The review list |
| `lib/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart` | The comparison |
| `lib/features/dive_sites/presentation/widgets/catalogue_gap_notice.dart` | The notice and the shared menu entry |
| `lib/features/dive_sites/presentation/widgets/site_catalogue_offer_line.dart` | The line on a site's page |

Modified: `dive_site.dart`, `dive_site_row_mapper.dart`, `site_tables.dart`, `shared_library_tables.dart`, `database.dart`, `app_database_migrations.dart`, `rungs_v340_onward.dart`, `before_open_child_columns.dart`, `site_repository_impl.dart` (existing methods only), `catalogue_site_visibility.dart`, `site_catalogue.dart`, `local_site_catalogue.dart`, `catalogue_adoption_service.dart`, `library_edit_stamper.dart`, `library_site_notes.dart`, `uddf_export_builders.dart`, `uddf_import_parsers.dart`, `uddf_entity_importer.dart`, `site_trip_fields.dart`, `app_router.dart`, `site_list_page.dart`, `site_list_content.dart`, `site_detail_header.dart`, the 11 ARB files and their generated code, `sql_column_notes.generated.dart`, `test/helpers/fake_site_catalogue.dart`, `docs/user/dive-sites.md`.

---

### Task 0: Before screenshots (done before any code)

- [x] A throwaway test at `test/zz_shots/gap_fill_shots_test.dart` renders the Sites list (phone 390x844, desktop 1280x860), the Sites overflow menu and a site's page, with SDK Roboto loaded in `setUpAll`. Run with `--update-goldens`; the four PNGs are copied to `<scratchpad>/shots/before/`. The test stays untracked for the after shots in Task 15.

### Task 1: The answers column, on the site and in sync

**Files:**
- Create: `lib/features/dive_sites/domain/entities/site_catalogue_answers.dart`, `lib/core/database/migrations/helpers/site_catalogue_answers_migrations.dart`
- Modify: `dive_site.dart`, `dive_site_row_mapper.dart`, `site_tables.dart`, `shared_library_tables.dart`, `database.dart` (version 365 and the `migrationVersions` entry), `app_database_migrations.dart` (the `part`), `rungs_v340_onward.dart`, `before_open_child_columns.dart`, `site_repository_impl.dart` (`createSite`, `_updateSiteRow`, the undo re-insert at about line 1295, the `metadataPatch` block), `site_trip_fields.dart`, ARB files, `sql_column_notes.generated.dart`
- Test: `test/features/dive_sites/domain/entities/site_catalogue_answers_test.dart`, `test/core/database/migration_v365_site_catalogue_answers_test.dart`, `test/core/services/sync/site_catalogue_answers_sync_test.dart`, `test/core/services/sync/sync_record_overlay_site_catalogue_answers_test.dart`, `test/features/dive_sites/data/repositories/site_catalogue_answers_repository_test.dart`

**Interfaces:**
- Produces:

```dart
class SiteCatalogueAnswers extends Equatable {
  const SiteCatalogueAnswers({
    this.also = const {},
    this.notSame = const {},
    this.declined = const {},
    this.unknown = const {},
  });
  static const empty = SiteCatalogueAnswers();
  final Set<String> also;                    // JSON key "also"
  final Set<String> notSame;                 // JSON key "not"
  final Map<String, Set<String>> declined;   // JSON key "declined": record id -> field names
  final Map<String, Object?> unknown;        // keys this build does not know, kept on rewrite
  bool get isEmpty;                          // the three known parts are empty and unknown is empty
  factory SiteCatalogueAnswers.decode(String? text); // never throws; wrong shapes read as empty
  String? encode();                          // null when isEmpty; keys and ids sorted
  SiteCatalogueAnswers copyWith({Set<String>? also, Set<String>? notSame, Map<String, Set<String>>? declined});
  SiteCatalogueAnswers withNotSame(String recordId);
  SiteCatalogueAnswers withDeclined(String recordId, Iterable<String> fieldNames); // unions
}
```
- `DiveSite.catalogueAnswers` (`SiteCatalogueAnswers`, default `empty`), a `catalogueAnswers` parameter on `copyWith`, and a `props` entry.
- Columns: `dive_sites.catalogue_answers TEXT NULL`; `library_site_notes.catalogue_id TEXT NULL` and `library_site_notes.catalogue_answers TEXT NULL`. Drift getters `catalogueAnswers`, `catalogueId`. Every column carries a `///` comment (the column notes generator reads it).
- `DiveSitesCompanion.catalogueAnswers` on a `metadataPatch` is honoured by `_writeSiteUpdate` exactly as `catalogueId` is. The ordinary update still writes neither.

- [ ] **Step 1: Write the value object tests.** Cases: `decode(null)`, `decode('')` and `decode('not json')` are `empty`; `decode('[1,2]')`, `decode('7')` and `decode('{"declined":{"r1":"depth"}}')` are `empty` in their known parts; a round trip of `also`, `not` and `declined`; `encode()` of `empty` is null; an unknown key `{"future":[1]}` survives `decode` then `withNotSame('r1')` then `encode`; `withDeclined('r1', ['depth'])` twice with different fields unions them; `encode` output is the same for two equal values built in different orders.
- [ ] **Step 2: Run, expect a compile failure.** `flutter test test/features/dive_sites/domain/entities/site_catalogue_answers_test.dart`
- [ ] **Step 3: Implement the value object, the entity field and the mapper line** (`catalogueAnswers: SiteCatalogueAnswers.decode(row.catalogueAnswers)`).
- [ ] **Step 4: Write the migration test**, copying `test/core/database/migration_v363_site_catalogue_id_test.dart`: v365 is in the ladder and the floor does not move; upgrading from 364 adds all three columns; a stored value is kept; a database stamped current without the columns is healed by the backstop; a database without either table upgrades without failing.
- [ ] **Step 5: Add the table columns, the helper, the rung, the backstop and the version.**

```dart
extension SiteCatalogueAnswersMigrations on AppDatabase {
  Future<void> _assertSiteCatalogueAnswersColumns() async {
    await _addColumnIfMissing('dive_sites', 'catalogue_answers', 'TEXT');
    await _addColumnIfMissing('library_site_notes', 'catalogue_id', 'TEXT');
    await _addColumnIfMissing('library_site_notes', 'catalogue_answers', 'TEXT');
  }
}
```
- [ ] **Step 6: Run codegen and the column notes generator**, in the background, and check `database.g.dart` mentions `catalogueAnswers`.
- [ ] **Step 7: Write the repository and sync tests.** Repository: `createSite` stores answers and `getSiteById` reads them back; `updateSite` with an entity whose answers are empty leaves stored answers alone; `updateSiteWithImportedMetadata` with `catalogueAnswers` present writes them. Sync (copy `site_catalogue_link_sync_test.dart`): `fetchRecord('diveSites', id)['catalogueAnswers']` is the encoded text; `upsertRecord` with the key stores it; a round trip through a second database keeps it. Overlay (copy the link's overlay test): an older peer's row without the key keeps ours; an explicit null clears ours.
- [ ] **Step 8: Wire the repository writes** (`createSite`, `_updateSiteRow`, the undo re-insert, the `metadataPatch` block), add the conflict label `'catalogueAnswers'` in `site_trip_fields.dart` with the key `settings_conflict_field_catalogueAnswers` ("Built-in catalogue answers") in all 11 ARB files, and run `flutter gen-l10n`.
- [ ] **Step 9: Run** the five test files of this task, then `test/features/settings/presentation/conflicts/conflict_field_catalogue_coverage_test.dart`, `test/features/agent_access/data/resources/schema_resource_test.dart`, `test/core/database/shared_library_schema_test.dart` and `test/l10n/arb_parity_test.dart`. Expected: all pass.
- [ ] **Step 10: Commit** `feat(dive-sites): a synced column for what a diver answered about catalogue records`

### Task 2: Claimed records and the merge gap

**Files:**
- Modify: `catalogue_site_visibility.dart`, `site_repository_impl.dart` (`getSiteByCatalogueId`, `_withMergedCatalogueLink`)
- Test: `test/features/dive_sites/domain/services/catalogue_site_visibility_test.dart` (extend), `test/features/dive_sites/data/repositories/site_catalogue_claims_test.dart`, `test/features/dive_sites/data/repositories/site_merge_catalogue_answers_test.dart`

**Interfaces:**
- Consumes: `DiveSite.catalogueAnswers` (Task 1).
- Produces: `linkedCatalogueIds(Iterable<DiveSite>)` now returns each site's link and its `also` ids. `const double kCataloguePairRadiusMeters = 150;` in `catalogue_site_visibility.dart`, used as the default of `offerableCatalogueSites`. `getSiteByCatalogueId(String id, {String? diverId})` keeps its signature and now answers with: the diver's own site linked to `id`, else a library site of one of the diver's memberships linked to `id`, else such a site that stands for `id` through `also`; the oldest wins within each step.

- [ ] **Step 1: Write the tests.** Visibility: a site with `also: {'r2'}` hides `r2` by link in `offerableCatalogueSites` with `byPosition` false. Claims: `getSiteByCatalogueId('r2')` finds a site whose `also` holds `r2`; with sites standing for `osm_node_12` and `osm_x_node_1`, a lookup of `osm_node_1` finds neither (Review Focus 3); a library site (no diver, `shared_library_id` set, a membership for the diver) linked to `r1` is found for that diver and not for another diver. Merge: two sites linked to `r1` and `r2` merged leave the survivor linked to `r1` with `also == {'r2'}`; a merged site's own `also` joins the survivor's; `not` lists are united minus anything now claimed; `declined` survives only for the survivor's link; `undoMerge` restores both sites' links and answers exactly. Adoption: `CatalogueAdoptionService.adopt` of a record a site stands for returns that site with `created` false.
- [ ] **Step 2: Run each file, expect failures.**
- [ ] **Step 3: Implement.** In `getSiteByCatalogueId` the `also` step prefilters with `catalogue_answers LIKE '%"<escaped id>"%'` and then decodes each candidate row and checks `also.contains(id)`. `_withMergedCatalogueLink` returns the survivor with both the link and the merged answers; rename it `_withMergedCatalogueClaims`.
- [ ] **Step 4: Run the three files plus** `test/features/dive_sites/data/repositories/site_catalogue_link_test.dart` and `test/features/dive_sites/data/services/site_matching_service_test.dart`. Expected: pass.
- [ ] **Step 5: Commit** `fix(dive-sites): a record merged into another site is no longer offered again`

### Task 3: UDDF carries the answers

**Files:**
- Modify: `uddf_export_builders.dart`, `uddf_import_parsers.dart`, `uddf_entity_importer.dart`
- Test: `test/core/services/export/uddf/uddf_site_catalogue_answers_round_trip_test.dart`

**Interfaces:**
- Produces: the site element `catalogueanswers` beside `catalogueid`, holding `SiteCatalogueAnswers.encode()`; the parsed map key `catalogueAnswers`. The importer's create path sets the answers; its overwrite path sets them only on a site whose own answers are empty, through the `metadataPatch`.

- [ ] **Step 1: Write the test**, copying `uddf_site_catalogue_link_round_trip_test.dart`: answers survive export and import; a site without answers writes no element; importing over a site with answers keeps the site's; importing over a site without takes the file's; unreadable text in the file imports as no answers.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass**, and rerun the link's round-trip test.
- [ ] **Step 5: Commit** `feat(export): UDDF carries a site's catalogue answers`

### Task 4: Name key, fields and the offer rule

**Files:**
- Create: `catalogue_name_key.dart`, `catalogue_gap_field.dart`, `catalogue_offer.dart`
- Test: `test/features/dive_sites/domain/catalogue_gaps/catalogue_name_key_test.dart`, `catalogue_offer_test.dart`

**Interfaces:**
- Produces:

```dart
/// normalize(name), every run of characters that are not letters or digits
/// (Unicode) replaced by one space, trimmed. Empty when nothing is left.
String catalogueNameKey(String name);
/// False when either key is empty.
bool catalogueNamesEqual(String a, String b);

enum CatalogueGapField {
  position, depth, country, region, city, island, bodyOfWater,
  waterType, siteTypes, entry, difficulty, hazards, description;
  static const place = {position, country, region, city, island, bodyOfWater};
}

/// The fields of [record] that [site] has empty and may take, in enum order.
Set<CatalogueGapField> catalogueOfferFor(
  DiveSite site, {
  required bool siteHasTypes,
  required CatalogueSite record,
});
```
- Rules pinned by the spec, section 2: a field is offered only when the record carries it and the site's is blank (null, or text that is empty after trim; empty list for entry); `depth` needs both of the site's depths missing and at least one of the record's; `country` needs a blank site country and a record country; place fields only when the site has no position or lies within `kCataloguePairRadiusMeters` of the record; `position` only when the site has none and the record has one; fields named in `site.catalogueAnswers.declined[record.id]` (by `CatalogueGapField.name`) are left out.

- [ ] **Step 1: Write the tests.** Name key: "Salt-Pier" equals "salt  pier"; "Cancún" equals "cancun"; "Thistlegorm" does not equal "SS Thistlegorm"; a blank name and a punctuation-only name equal nothing, including each other (Review Focus 1); a name in Cyrillic keeps its letters. Offer: one case per field for offered and not offered; whitespace-only text counts as blank; a site with a maximum depth only gets no depth; a record with only a maximum gives depth; a site 400 m from its record gets no place fields but still gets depth and description; a site with no position gets every place field; a declined field is left out and an undeclined one stays; a declined field under another record id does not count; a site with types gets no site types.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass.**
- [ ] **Step 5: Commit** `feat(dive-sites): the rule for what a catalogue record may add to a site`

### Task 5: The pairing rule

**Files:**
- Create: `catalogue_pair.dart`, `catalogue_pairing.dart`
- Test: `test/features/dive_sites/domain/catalogue_gaps/catalogue_pairing_test.dart`

**Interfaces:**
- Consumes: Task 4, `linkedCatalogueIds` (Task 2).
- Produces:

```dart
enum CataloguePairKind { linked, sure, nearby, named }

class CataloguePair extends Equatable {
  const CataloguePair({required this.site, required this.record, required this.kind,
      required this.fields, this.distanceMeters});
  final DiveSite site;
  final CatalogueSite record;
  final CataloguePairKind kind;
  final Set<CatalogueGapField> fields;
  final double? distanceMeters;          // null when either has no position
  bool get addsLink => site.catalogueId == null;
  /// Listed ticked: linked or sure, no position in the offer, a verified record.
  bool get preTicked;
  /// site id, record id and the sorted field names: the notice's memory.
  String get key;
}

class PairingCandidates {
  const PairingCandidates({this.linkedRecords = const {}, this.near = const {}, this.named = const {}});
  final Map<String, CatalogueSite> linkedRecords;        // site id -> its linked record
  final Map<String, List<CatalogueSite>> near;           // site id -> records within the radius
  final Map<String, List<CatalogueSite>> named;          // site id -> records with an equal name
}

/// [claimed] are record ids no site may be offered (linkedCatalogueIds of
/// every site the diver sees). Result order: linked and sure, then nearby,
/// then named; within each by site name.
List<CataloguePair> pairSitesWithCatalogue({
  required List<DiveSite> sites,
  required Set<String> sitesWithTypes,
  required Set<String> claimed,
  required PairingCandidates candidates,
});
```
- Algorithm the signature does not determine: settle in three passes over unlinked sites. Pass 1 (sure): each site's candidates within the radius whose name equals the site's, ordered dive site before register then nearer; sites are visited in order of their best candidate's distance; a site takes its first candidate not yet taken. Pass 2 (nearby): sites that have a position and no equal-named candidate at all, same ordering, skipping taken records. Pass 3 (named): sites without a position; candidates are the equal-named records not taken, not claimed, not in the site's `notSame`, with a position, and in the site's country when the site has one (`site.countryCode`, else `countryCodeFor(site.country)`); a pair only when exactly one remains; visit sites by id so a contested record goes to one of them deterministically. A linked site pairs with `candidates.linkedRecords[site.id]` only when its offer is not empty. An unlinked pair is kept even with an empty offer.

- [ ] **Step 1: Write the tests.** One per kind; 150 m is a pair and 151 m is not; an equal name beats a nearer different name; a dive site record beats a nearer register record; claimed records and `notSame` records are never paired; a site with an equal-named candidate taken by a nearer site gets no nearby pair; two position-less sites of one name and one record give exactly one pair; named with one, two and no candidates; named narrowed by the site's country code, and by its country text when it has no code; a linked site with an empty offer gives no pair and with a new depth gives a `linked` pair; `preTicked` is true for sure and linked, false for nearby and named, false for any pair with `position` in its fields (a linked site without coordinates), false for a `researched` record; an unlinked sure pair with no fields is kept; `key` changes when the fields change.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass.**
- [ ] **Step 5: Commit** `feat(dive-sites): the rule that pairs a diver's site with a catalogue record`

### Task 6: The catalogue's exact-name read

**Files:**
- Modify: `site_catalogue.dart`, `local_site_catalogue.dart`, `test/helpers/fake_site_catalogue.dart`
- Test: `test/features/dive_sites/data/catalogue/local_site_catalogue_named_test.dart`

**Interfaces:**
- Produces on `SiteCatalogue`:

```dart
/// Every located record whose name equals [name] (catalogueNamesEqual),
/// in [countryCode] when given. A blank name answers nothing.
Future<List<CatalogueSite>> named(String name, {String? countryCode});
```
- The local implementation prefilters in SQL (every word of the name key as a `LIKE` on `search_text`, the country code when given, a non-null latitude) and decides equality in Dart with `catalogueNamesEqual`. No limit.

- [ ] **Step 1: Write the test** over a real local cache database (the setup at `local_site_catalogue_test.dart:113-122`): finds "Blue Hole" among "Blue Hole" and "Blue Hole North"; "blue-hole" finds it; a country code narrows two same-named records to one; a record without a position is not returned; a blank name returns nothing; more than 50 records containing the word still return the exact one.
- [ ] **Step 2: Run, expect failure. Step 3: Implement in the interface, the local class and the fake** (the fake gains a `namedCalls` counter). **Step 4: Run, expect pass**, and rerun `local_site_catalogue_test.dart`.
- [ ] **Step 5: Commit** `feat(dive-sites): the catalogue can be asked for a site by its exact name`

### Task 7: The apply write

**Files:**
- Create: `site_catalogue_fill_repository.dart`
- Test: `test/features/dive_sites/data/repositories/site_catalogue_fill_repository_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 2, 4.
- Produces:

```dart
enum CatalogueFillOutcome { applied, claimedElsewhere, siteChanged, notEditable, missing }

class CatalogueFillWrite {
  final CatalogueFillOutcome outcome;
  final bool linked;                       // this write set the link
  final Set<CatalogueGapField> filled;     // fields actually written
}

class SiteCatalogueFillRepository {
  SiteCatalogueFillRepository({LibraryEditStamper? stamper, SiteClassificationRepository? classification});

  /// Links [siteId] to [record] if it has no link, and writes those of
  /// [fields] the site still has empty. [declined] joins the site's answers.
  /// [bodyOfWater] replaces the record's own sea name when given.
  Future<CatalogueFillWrite> applyFill({
    required String siteId,
    required CatalogueSite record,
    required Set<CatalogueGapField> fields,
    Set<CatalogueGapField> declined = const {},
    String? bodyOfWater,
    String? actingDiverId,
  });

  /// Rewrites the site's answers with [change] and marks the site for sync.
  Future<void> updateAnswers(
    String siteId,
    SiteCatalogueAnswers Function(SiteCatalogueAnswers current) change, {
    String? actingDiverId,
  });
}
```
- Behaviour: a library site the profile may not edit gives `notEditable`. In one transaction: read the row (`missing` when gone); a row linked to a different record gives `siteChanged`; another site of this diver, or a library site, claiming the record (link or `also`) gives `claimedElsewhere`; otherwise recompute `catalogueOfferFor` on the fresh row and write only `fields` that are still in it, plus the link when the row has none, plus the answers, with one `updatedAt` and one `markRecordPending('diveSites')`. Site types go through `addTypesToSites` inside the transaction, only when the site still has none. Country is written with its code. After the commit a library site is stamped with `LibraryEditStamper.changedFields(before, after)` (plus `'siteTypes'` when types were added), then `SyncEventBus.notifyLocalChange()`. When nothing at all would change, nothing is written and the outcome is `applied` with an empty `filled`.

- [ ] **Step 1: Write the tests** over a real database (`setUpTestDatabase`, `seedDivers`, `clearPendingMarks`, `pendingCount`): writes only the chosen fields; a field chosen but filled meanwhile is not overwritten; the link is set once and kept on a second call; a site linked to another record gives `siteChanged` and writes nothing; a record linked by another site of the diver gives `claimedElsewhere`; types are added only to a site with none; country arrives with its code; `declined` lands in the answers under the record id; one pending mark for the site; name, notes, rating and exit methods are byte-identical before and after; a missing site gives `missing`; `updateAnswers` writes the column and marks pending; a library site that may be edited has its changed fields stamped (a fake stamper records the call); one that may not gives `notEditable`.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass.**
- [ ] **Step 5: Commit** `feat(dive-sites): one write that links a site and fills its empty fields`

### Task 8: Library sites keep the link and answers per profile

**Files:**
- Create: `lib/core/services/shared_library/library_site_catalogue.dart`
- Modify: `library_edit_stamper.dart`, `library_site_notes.dart`, `site_catalogue_fill_repository.dart`, `site_repository_impl.dart` (after a merge whose survivor is a library site)
- Test: `test/core/services/shared_library/library_site_catalogue_test.dart`

**Interfaces:**
- Produces:

```dart
/// Keeps [diverId]'s link and answers for the library site [siteId] in
/// their library_site_notes record, for personal sync to carry. A new
/// record starts from the row's current notes and rating.
Future<void> putLibrarySiteCatalogue(AppDatabase db, SyncRepository sync, {
  required String diverId, required String siteId,
  required String? catalogueId, required String? catalogueAnswers,
});

// LibraryEditStamper
Future<void> keepCatalogue(String siteId, {
  required String? catalogueId, required SiteCatalogueAnswers answers, String? actingDiverId,
});
```
- `keepCatalogue` resolves the profile as `keepPrivate` does (the acting diver, else the library's sole local profile, else nothing). `applyLibrarySiteNotes` also copies the newest record that holds a link onto the row's `catalogue_id`, and the newest that holds answers onto `catalogue_answers`; a record holding neither changes neither. `applyFill` and `updateAnswers` call `keepCatalogue` after writing a library site.

- [ ] **Step 1: Write the tests.** `putLibrarySiteCatalogue` creates a record seeded with the row's notes and rating, marks `librarySiteNotes` pending, and on a second call updates only the two columns; a later `putSiteNotes` leaves the link and answers in place; `applyLibrarySiteNotes` copies a record's link and answers onto a library row that has none; a newer record with notes only clears neither; a personal site is never touched; a sync round trip of a `librarySiteNotes` record keeps both columns and an older peer's record without them keeps ours (`overlayOntoLocal('librarySiteNotes', ...)`); `applyFill` on an editable library site leaves the link on the row and in the profile's record; a library pull through `SiteDocumentBridge.apply` on an existing row keeps both columns; `SiteDetacher` carries both to the personal copy.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass**, and rerun `test/core/services/shared_library/library_site_notes_test.dart`.
- [ ] **Step 5: Commit** `feat(shared-library): a library site's catalogue link and answers travel per profile`

### Task 9: The gap service

**Files:**
- Create: `catalogue_gap_service.dart`, `catalogue_sea_name.dart`
- Modify: `catalogue_adoption_service.dart` (calls the moved function)
- Test: `test/features/dive_sites/data/services/catalogue_gap_service_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 5, 6, 7, 8.
- Produces:

```dart
Future<String?> catalogueSeaInDiversLanguage(CatalogueSite site, {
  required Future<SeaAreaIndex?> Function()? loadSeas,
  required String Function()? placeNameLanguage,
}); // the body of today's CatalogueAdoptionService._seaInDiversLanguage

class CatalogueApplyRequest {
  const CatalogueApplyRequest(this.pair, this.fields); // fields is a subset of pair.fields
  final CataloguePair pair;
  final Set<CatalogueGapField> fields;
}

class CatalogueApplyResult {
  final int linked; final int filled; final int notApplied;
}

class CatalogueGapService {
  CatalogueGapService({
    required SiteRepository siteRepository,
    required SiteCatalogue catalogue,
    required SiteClassificationRepository classification,
    required SiteCatalogueFillRepository fills,
    LibraryEditStamper? stamper,
    this.fetchElevation, this.loadSeas, this.placeNameLanguage,
    Future<T> Function<T>(Future<T> Function() body)? runBulk, // defaults to ChangeLogScope.bulk, label bulkEdit
  });
  Future<List<CataloguePair>> findPairs({required String? diverId});
  Future<CatalogueApplyResult> apply(List<CatalogueApplyRequest> requests, {required String? diverId});
  Future<void> answerNotSame(CataloguePair pair, {required String? diverId});
  Future<void> declineAll(CataloguePair pair, {required String? diverId});
}
```
- `findPairs`: sites are `getAllSites(diverId:)`. Those taking part are the diver's own (`site.diverId == diverId`) and library sites for which `mayEdit` holds; another diver's shared site never takes part. `claimed` is `linkedCatalogueIds` over every site returned. Reads: `byId` per linked site, `near(location, radiusMeters: kCataloguePairRadiusMeters, limit: 50)` per unlinked located site, `named(site.name)` per unlinked site without a position.
- `apply`: one `runBulk`; per request `fills.applyFill` with `declined = pair.fields` minus `fields`, and the sea name from `catalogueSeaInDiversLanguage` when `bodyOfWater` is among the fields; `linked` counts writes that set a link, `filled` writes with a non-empty `filled`, `notApplied` every outcome other than `applied` and every thrown error (logged). After the bulk scope, a site that gained a position and has no altitude gets `updateSiteAltitude` from `fetchElevation`, best effort.
- `answerNotSame` adds the record to the site's `notSame`; `declineAll` adds every offered field to `declined` for that record.

- [ ] **Step 1: Write the tests** with `FakeSiteCatalogue` and a real database: the four kinds end to end; another diver's shared site is not paired but its link still claims its record; a library site the profile may not edit is left out; an empty catalogue gives no pairs and no error (Review Focus 5); `apply` counts linked, filled and not applied; un-chosen fields become declined and the pair's next `findPairs` no longer offers them; a failure on one request does not stop the next; `answerNotSame` removes the pair from the next `findPairs`; `declineAll` removes a linked pair; a position write triggers one altitude lookup and a failing lookup leaves the result intact; the adoption service's own tests still pass after the move.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass**, plus `test/features/dive_sites/data/services/catalogue_adoption_service_test.dart`.
- [ ] **Step 5: Commit** `feat(dive-sites): find and apply catalogue pairs for existing sites`

### Task 10: Providers and the notice's memory

**Files:**
- Create: `site_catalogue_gap_providers.dart`
- Test: `test/features/dive_sites/presentation/providers/site_catalogue_gap_providers_test.dart`

**Interfaces:**
- Produces:

```dart
final siteCatalogueFillRepositoryProvider = Provider<SiteCatalogueFillRepository>(...);
final catalogueGapServiceProvider = Provider<CatalogueGapService>(...);
/// Recomputes on site changes, classification changes, a catalogue import and a diver switch.
final catalogueGapPairsProvider = FutureProvider<List<CataloguePair>>(...);
final catalogueGapPairForSiteProvider = Provider.family<CataloguePair?, String>(...);

const kCatalogueGapNoticeSeenPrefsKey = 'site_catalogue_gap_notice_seen';
class CatalogueGapNoticeNotifier extends StateNotifier<Set<String>> {
  /// Replaces what is remembered with [keys].
  void dismiss(Iterable<String> keys);
}
final catalogueGapNoticeSeenProvider = StateNotifierProvider<CatalogueGapNoticeNotifier, Set<String>>(...);
/// Pairs waiting that the diver has not dismissed; 0 hides the notice.
final catalogueGapNoticeCountProvider = Provider<int>(...);
```
- The memory is per diver (`'$key:$diverId'`), in SharedPreferences, as `collapsedTripIdsProvider` is. The count is the number of current pairs, and is reported only when at least one pair's `key` is not remembered.

- [ ] **Step 1: Write the tests** with a `ProviderContainer`: the count is the number of pairs; after `dismiss` of the current keys it is 0; a new pair brings it back with the full count; a pair whose fields grew brings it back; the memory survives a new container on the same preferences; another diver's memory is separate; `catalogueGapPairForSiteProvider` finds a pair by site id and is null while loading.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass**, plus `test/architecture/provider_change_tick_test.dart`.
- [ ] **Step 5: Commit** `feat(dive-sites): providers for catalogue pairs and the notice's memory`

### Task 11: Strings

**Files:**
- Modify: the 11 ARB files, generated localisation files
- Create: `catalogue_gap_display.dart`
- Test: `test/features/dive_sites/presentation/catalogue_gap_display_test.dart`

**Interfaces:**
- Produces the keys below (English shown) and:

```dart
String catalogueGapFieldLabel(CatalogueGapField field, AppLocalizations l10n);
/// The record's value for [field] as shown in the comparison, in the diver's units.
String catalogueGapFieldValue(CatalogueGapField field, CatalogueSite record, UnitFormatter units, AppLocalizations l10n);
/// "link, depth 5-15 m, reef, shore entry": the link first when the pair adds it.
String catalogueGapAddsLine(CataloguePair pair, UnitFormatter units, AppLocalizations l10n);
```

| Key | English |
|---|---|
| `diveSites_list_menu_catalogueReview` | Check sites against built-in catalogue |
| `diveSites_gapReview_title` | Built-in details for your sites |
| `diveSites_gapReview_sectionSame` | Same site ({count}) |
| `diveSites_gapReview_sectionCheck` | Check these ({count}) |
| `diveSites_gapReview_empty` | Your sites already carry everything the built-in catalogue has for them. |
| `diveSites_gapReview_apply` | Apply ({count}) |
| `diveSites_gapReview_adds` | Adds: {items} |
| `diveSites_gapReview_addsLink` | link |
| `diveSites_gapReview_nearby` | {distance} from "{name}" |
| `diveSites_gapReview_named` | No position. "{name}", {place} |
| `diveSites_gapReview_namedNoPlace` | No position. "{name}" |
| `diveSites_gapReview_compare` | Compare with the built-in record |
| `diveSites_gapReview_applied` | Sites linked: {linked}. Sites with details filled: {filled}. |
| `diveSites_gapReview_appliedSome` | Sites linked: {linked}. Sites with details filled: {filled}. Not applied: {failed}. |
| `diveSites_gapCompare_yours` | Your site |
| `diveSites_gapCompare_record` | Built-in record |
| `diveSites_gapCompare_empty` | (empty) |
| `diveSites_gapCompare_staysYours` | yours stays |
| `diveSites_gapCompare_apart` | {distance} apart |
| `diveSites_gapCompare_fill` | Fill in ({count}) |
| `diveSites_gapCompare_linkOnly` | Link only |
| `diveSites_gapCompare_notSame` | Not the same site |
| `diveSites_gapCompare_noThanks` | No thanks |
| `diveSites_gapField_position` | Position |
| `diveSites_gapField_depth` | Depth |
| `diveSites_gapField_siteTypes` | Site types |
| `diveSites_gapField_entry` | Entry |
| `diveSites_gapField_name` | Name |
| `diveSites_gapNotice_text` | Built-in details are available for your sites ({count}) |
| `diveSites_gapNotice_review` | Review |
| `diveSites_gapNotice_dismiss` | Dismiss |
| `diveSites_gapLine_linked` | The built-in catalogue has more details for this site. |
| `diveSites_gapLine_unlinked` | The built-in catalogue may hold this site. |

Country, region, town, island, body of water, description, difficulty, hazards and water type reuse the site editor's existing label keys (`diveSites_edit_field_*_label`, `diveSites_edit_section_*`).

- [ ] **Step 1: Write the display test**: the adds line leads with the link for an unlinked pair and omits it for a linked one; depth is in the diver's unit (metres and feet); site types and entry methods are translated names; a long description is cut to 40 characters with an ellipsis in the adds line and shown whole by `catalogueGapFieldValue`.
- [ ] **Step 2: Add the keys to all 11 ARB files with a script** (inserted after `diveSites_catalogue_credit`), run `flutter gen-l10n`, implement the display helpers.
- [ ] **Step 3: Run** the display test and the whole `test/l10n/` folder one file at a time for `arb_parity_test.dart`, `arb_no_duplicate_keys_test.dart`, `untranslated_english_values_test.dart`, `german_informal_address_test.dart`, `arb_diacritics_test.dart`. Expected: pass.
- [ ] **Step 4: Commit** `feat(l10n): strings for the catalogue review of existing sites`

### Task 12: The review page

**Files:**
- Create: `catalogue_gap_review_notifier.dart`, `catalogue_gap_review_page.dart`
- Modify: `app_router.dart` (a `catalogue-review` child of `/sites`, declared before `:siteId`, name `siteCatalogueReview`)
- Test: `test/features/dive_sites/presentation/pages/catalogue_gap_review_page_test.dart`

**Interfaces:**
- Consumes: Tasks 9, 10, 11.
- Produces:

```dart
class CatalogueGapReviewState {
  final bool isLoading;
  final List<CataloguePair> pairs;
  final Set<String> ticked;                                  // site ids
  final Map<String, Set<CatalogueGapField>> fieldChoices;    // site id -> fields chosen in the comparison
  final bool isApplying;
  int get tickedCount;
  Set<CatalogueGapField> fieldsFor(CataloguePair pair);      // the choice, else every offered field
}

class CatalogueGapReviewNotifier extends StateNotifier<CatalogueGapReviewState> {
  void toggle(String siteId);
  void setFields(String siteId, Set<CatalogueGapField> fields);
  Future<CatalogueApplyResult?> applyTicked();   // null when already applying or nothing is ticked
  Future<CatalogueApplyResult?> applyOne(CataloguePair pair, Set<CatalogueGapField> fields);
  Future<void> notSame(CataloguePair pair);
  Future<void> noThanks(CataloguePair pair);
}
final catalogueGapReviewProvider = StateNotifierProvider.autoDispose<CatalogueGapReviewNotifier, CatalogueGapReviewState>(...);
```
- The notifier follows `catalogueGapPairsProvider`. A pair is ticked when it first appears if `preTicked`; a row the diver un-ticked is not ticked again when the pairs recompute; ticks and choices of pairs that left are dropped.
- The page: an app bar with the title; two sections with their counts ("Same site" for `preTicked` pairs, "Check these" for the rest), an empty section hidden; each row a `ListTile` with a leading `Checkbox`, the site's name as the title, a subtitle of the pairing line (nearby or named wording, nothing for sure and linked) and the adds line, a trailing `Icons.chevron_right`, and `onTap` opening the comparison (Task 13; until then a no-op); a bottom bar with one `FilledButton` reading `Apply ({count})`, disabled at zero and while applying. Apply stays on the page and shows `diveSites_gapReview_applied`, or `..._appliedSome` when `notApplied > 0`. With no pairs, including while the catalogue has not loaded, the body is the empty text and there is no bottom bar. No indeterminate spinner anywhere on the page.

- [ ] **Step 1: Write the widget tests** with the pairs provider and the service overridden: sections and counts; seeded ticks; tapping a checkbox changes the Apply count; Apply sends only ticked rows with their fields and stays on the page; the message with and without failures; a second Apply while the first runs sends nothing (Review Focus 4); the empty state with no pairs and with the provider still loading (Review Focus 5); a row the diver un-ticked stays un-ticked after the pairs recompute; the page pumps with `pumpAndSettle` (no endless animation).
- [ ] **Step 2: Run, expect failure. Step 3: Implement the notifier, the page and the route. Step 4: Run, expect pass**, plus `test/architecture/list_tile_trailing_width_test.dart` and `test/architecture/snack_bar_action_times_out_test.dart`.
- [ ] **Step 5: Commit** `feat(dive-sites): a review list of catalogue details for existing sites`

### Task 13: The comparison

**Files:**
- Create: `catalogue_gap_comparison_sheet.dart`
- Modify: `catalogue_gap_review_page.dart` (rows open it)
- Test: `test/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet_test.dart`

**Interfaces:**
- Produces:

```dart
sealed class CatalogueComparisonResult {}
class ComparisonKept extends CatalogueComparisonResult { final Set<CatalogueGapField> fields; } // closed without acting
class ComparisonApply extends CatalogueComparisonResult { final Set<CatalogueGapField> fields; }
class ComparisonNotSame extends CatalogueComparisonResult {}
class ComparisonNoThanks extends CatalogueComparisonResult {}

/// A modal bottom sheet (isScrollControlled: true, useSafeArea: true).
Future<CatalogueComparisonResult?> showCatalogueGapComparison(
  BuildContext context, {
  required CataloguePair pair,
  Set<CatalogueGapField>? initialFields,   // defaults to every offered field
});
```
- Content: a header with the site's name and the record's name and source credit (`catalogueSourceProvider`, the `diveSites_catalogue_credit` wording); one `CheckboxListTile` per offered field showing the label, "(empty)" and the record's value; below them, un-ticked plain rows for the name ("yours stays") and, when both have a position, the two positions and the distance apart; for a pair that adds a position, the record's coordinates, country and region in full. Actions: "Not the same site" for an unlinked pair or "No thanks" for a linked one, and a primary button reading `Fill in ({count})`, or "Link only" when nothing is ticked on an unlinked pair; the primary button is disabled for a linked pair with nothing ticked. The sheet only returns a result: the caller acts on it.
- The review page maps the result: `ComparisonKept` to `setFields` (and ticks the row if any field is kept and it was ticked before), `ComparisonApply` to `applyOne`, the other two to `notSame` and `noThanks`.

- [ ] **Step 1: Write the tests**: every offered field is listed and ticked; un-ticking changes the button's count; all un-ticked on an unlinked pair reads "Link only"; each action returns its result; closing returns `ComparisonKept` with the current ticks; a named pair shows the record's coordinates and place; depth follows the diver's unit; on the page, a kept choice is what the row's tick then applies, and "Not the same site" removes the row.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass**, plus `test/architecture/bottom_sheet_safe_area_test.dart`.
- [ ] **Step 5: Commit** `feat(dive-sites): compare a site with its catalogue record field by field`

### Task 14: Ways in

**Files:**
- Create: `catalogue_gap_notice.dart`, `site_catalogue_offer_line.dart`
- Modify: `site_list_page.dart`, `site_list_content.dart` (two menus, the `buildContent` column and the table column), `site_detail_header.dart`
- Test: `test/features/dive_sites/presentation/widgets/catalogue_gap_notice_test.dart`, `site_catalogue_offer_line_test.dart`; extend `test/features/dive_sites/presentation/pages/site_list_page_test.dart`

**Interfaces:**
- Produces: `PopupMenuItem<String> catalogueReviewMenuItem(BuildContext context)` with the value `kCatalogueReviewMenuValue = 'catalogue_review'`, used by all three menus, whose handlers `context.push('/sites/catalogue-review')`. `class CatalogueGapNotice extends ConsumerWidget`: nothing when `catalogueGapNoticeCountProvider` is 0; otherwise one row (an icon, the text with the count, a `TextButton` "Review", an `IconButton` close with the "Dismiss" tooltip) styled like `SiteActiveFiltersBar`. It is placed above the list and shown only when `!filter.hasActiveFilters`. Dismiss calls `dismiss` with the current pairs' keys. `class SiteCatalogueOfferLine extends ConsumerWidget` takes a `DiveSite`; nothing when the site has no pair; otherwise the linked or unlinked wording and a `TextButton` "Review" that opens the comparison and applies its result through `catalogueGapServiceProvider`. `SiteDetailHeader` shows it after the catalogue credit line.

- [ ] **Step 1: Write the tests**: the notice shows the count, opens the route, hides after dismiss and returns for a new pair; the Sites page shows it with no filter and hides it under a search; each of the three menus has the entry and it navigates; the offer line shows each wording, opens the comparison, and disappears after the pair is applied; a site with no pair shows no line.
- [ ] **Step 2: Run, expect failure. Step 3: Implement. Step 4: Run, expect pass**, plus `test/features/dive_sites/presentation/widgets/site_detail_header_test.dart` and `site_detail_page_header_test.dart`.
- [ ] **Step 5: Commit** `feat(dive-sites): reach the catalogue review from the Sites menu, a notice and a site's page`

### Task 15: Documentation, checks and after screenshots

**Files:**
- Modify: `docs/user/dive-sites.md`, `docs/design/specs/2026-11-14-site-catalogue-gap-fill-design.md` (any ruling that changed the design), `test/zz_shots/gap_fill_shots_test.dart` (untracked)

- [ ] **Step 1: Write the user guide section** "Filling in sites you already have": what is paired, that only empty fields are filled, the two answers, where to find the list.
- [ ] **Step 2: Run** `python3.14 scripts/check_docs_links.py`, `dart format .`, `flutter analyze` (whole repo, expect no issues), then one at a time every test file under `test/architecture/` and `test/shared/` through `flutter test test/architecture` and `flutter test test/shared`, and `flutter test test/features/dive_sites` and `flutter test test/core/database`.
- [ ] **Step 3: After screenshots.** Extend the throwaway test with the pairs provider overridden: Sites list with the notice (phone and desktop), the menu with the new entry, the review page (phone and desktop), the comparison, the site page with the line. Copy the PNGs to `<scratchpad>/shots/after/`, then delete `test/zz_shots` and confirm `git status --porcelain` is empty.
- [ ] **Step 4: Commit** `docs(dive-sites): the review list for sites you already have`

### Task 16: Pull request

- [ ] **Step 1: Check** `gh pr list --search "4514 in:body"` for a sibling PR, fetch and merge `origin/main`, renumber the schema step if main has moved, rerun codegen and the Task 1 tests if it did.
- [ ] **Step 2: Push** and open the PR to main from `.github/PULL_REQUEST_TEMPLATE`, with `Part of #4514` in the description.
- [ ] **Step 3: Screenshots.** Re-list the project gists, use the highest numbered one (start the next if it is over 75 MB or a push warns), add the images as `<pr>-<nn>-<screen>-<state>.png`, and embed them with raw URLs pinned to the gist commit.
- [ ] **Step 4: Review.** Run the code review with `--max-findings all`, fix every valid finding with a test that fails first, and bring CI to green.
