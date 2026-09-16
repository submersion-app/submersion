# Link legacy buddy text to buddy records

Date: 2026-09-13
Issue: #1831 (follow-up: "a way to turn it into buddy records")
Depends on: PR #1837 (the Buddies card's plain text-buddy tile)

## Problem

A dive can carry its people only as free text: the legacy `dives.buddy`
and `dives.dive_master` columns. CSV imports (the MySSI preset from #1830,
the Subsurface and generic presets) write only those columns, never
`dive_buddies` rows. PR #1837 made the dive detail Buddies card show that
text as a plain, non-tappable tile instead of "Solo dive", but the diver
still cannot turn it into real buddy records, so those people have no
buddy page, no statistics, no role, and do not appear in buddy filters.

Every reader already treats the `dive_buddies` junction as authoritative
once it holds anyone (`_buddyColumnValue` and `_diveMasterColumnValue` in
`lib/core/constants/dive_field_extractor.dart`), so a conversion only has
to create the right junction rows; the text can stay.

Real data (`ogbillavista_submersion_2026-09-10.db`) shows the shapes to
handle: `", "` joins several names (`Jim Dunfield, John Ratcliffe`, the
same format the UDDF importers write), a name can hold parentheses
(`Joe (Customer)`), two records can share one name (`Jack Evans` twice),
the text can be a short form of an existing record (`Leo` vs `Leo Cox`),
and the only unlinked values in that library are the placeholder `None`.

## Goals

- From one dive's Buddies card, the diver reviews the parsed names and
  links them to existing or new buddy records.
- From Settings > Data Tools, the diver links every dive in the library
  that still has unlinked buddy text, after a preview.
- No duplicate buddy records for names that already exist, and one new
  record per new name across a whole batch.
- Both flows are undoable from a snackbar.
- Writes are sync-correct and never restamp the parent dive row.

## Non-goals

- Clearing or rewriting `dives.buddy` / `dives.dive_master`. They stay
  untouched.
- Fixing the CSV, Excel and PADI PDF exporters, which read only the text
  columns and so omit picker-linked buddies today. That is a pre-existing
  bug, tracked separately.
- Converting at import time, or prompting after an import.
- A dive list multi-select action.
- Creating custom dive roles from the review sheet.
- Any schema change. No new tables or columns.

## Decisions

| Topic | Decision |
| --- | --- |
| Scope | Per-dive action and bulk page, one PR |
| Bulk home | Settings > Data Tools, beside Fix dive times |
| Splitting | Punctuation and conjunction words, reviewed before saving |
| Matching | Exact (case and whitespace insensitive, diver scoped); unique-prefix suggestions in the per-dive review only; any row can be re-pointed |
| Role | Built-in Buddy for `dives.buddy`, built-in Dive Master for `dives.dive_master`; editable per row in the per-dive review; bulk uses those defaults |
| Legacy text | Left untouched |
| Dive-master text | Converted too, shown on the card before conversion |
| Placeholders | Ignored everywhere; a text holding only placeholders reads as "Solo dive" |
| Undo | Snackbar Undo for both flows |
| Base | Built on #1837's commit, PR to main |

## Design

### 1. Parsing (`lib/features/buddies/domain/services/legacy_name_parser.dart`)

`LegacyNameParser.parse(String? text) -> List<String>`, pure Dart.

1. Null or blank input returns an empty list.
2. Collapse runs of whitespace to one space and trim.
3. Split on these separators, except inside `(...)` or `[...]`:
   - characters `,` `;` `/` `&` `+`, newline, full-width comma `，`,
     ideographic comma `、`;
   - the whole words `and`, `und`, `et`, `en`, `és`, matched
     case-insensitively, and the single letters `e` and `y` only when
     written in lowercase (a capital one, as in `John E Smith`, is a
     middle initial), all only when surrounded by whitespace.
4. Trim each part. Drop a part that is empty, holds no letter
   (`--`, `3`), or is a placeholder. Placeholders, compared
   case-insensitively after trimming: `none`, `solo`, `n/a`, `na`, `-`,
   `--`, `nobody`, `no buddy`, `keine`, `aucun`, `ninguno`, `nessuno`,
   `nenhum`, `geen`. Because `/` is a separator, `n/a` is removed as a
   whole token (case-insensitive, bounded by non-letters) before
   splitting, so `John / N/A` yields only `John` and never the names
   `N` and `A`.
5. Dedupe case-insensitively, keeping the first spelling and order.

An empty result means "no names". The Buddies card uses exactly this test
to choose between a text tile and "Solo dive", so there is one rule.

Arabic and Hebrew prefix conjunctions are not split. A Spanish compound
surname such as `Ortega y Gasset` is split into two names; this is the
accepted cost of splitting on `y`, it is pinned by a test, and both
review surfaces show the split before anything is written.

### 2. Matching (`lib/features/buddies/domain/services/buddy_name_matcher.dart`)

`BuddyNameMatcher`, pure Dart, built once from the candidate buddies: the
diver's own records plus unowned ones (`diver_id IS NULL`), each with its
linked-dive count.

- Key: the name lowercased with Dart's Unicode-aware `toLowerCase()` and
  whitespace collapsed. Matching happens in Dart because SQLite's `LOWER`
  folds only ASCII (`ÉRIC` would not match `éric`).
- `match(name)` returns a `NameMatch`:
  - `exact(buddy, tieCount)` when one or more candidates share the key.
    Ties rank the diver's own record first, then the most linked dives,
    then the oldest `createdAt`, then `id`, so the pick is deterministic.
    `tieCount > 1` lets the review warn about it.
  - `none(suggestion?)` otherwise. The suggestion is set only when exactly
    one candidate's key starts with `key + " "` (a whole-word prefix), so
    `Leo` suggests `Leo Cox` and `Le` suggests nothing.
- Suggestions are used only by the per-dive review. The bulk flow ignores
  them and creates a new record.

### 3. Plan model (`lib/features/buddies/domain/entities/legacy_buddy_conversion.dart`)

- `LinkTarget`: `existing(buddyId, name)` or `create(name)`.
- `PlannedLink { name, target, roleId, suggestion?, tieCount }`.
- `ConversionPlan { diveId, buddyText, diveMasterText, links }`.
- `ConversionReceipt { linkIds, createdBuddyIds, claimedBuddyIds }`, with
  `isEmpty` when nothing was written.

All immutable with `copyWith` and value equality, per the project
conventions.

Planning one dive: parse `buddy` into links with role `DiveRole.buddyId`
and `dive_master` into links with role `DiveRole.diveMasterId`, then
match each. Names that resolve to the same existing record, or share a
key as new names, collapse into one link; when one of them came from the
dive-master text the link keeps the Dive Master role.

### 4. Service (`lib/features/buddies/data/services/legacy_buddy_conversion_service.dart`)

`LegacyBuddyConversionService`, provided through Riverpod.

- `Future<(ConversionPlan, BuddyNameMatcher)> planFor(Dive dive, String
  diverId)`, where the caller passes the dive's own diver, falling back
  to the active diver. The matcher travels with the plan because the
  review sheet re-matches edited names against it.
- `Future<LinkBuddyNamesData> planCandidates(String diverId)` (the
  diver id, the matcher, and a `List<CandidateDive>`): one query
  for the diver's dives (scoped exactly as the dive list scopes dives to
  the active diver, so neither surface sees a dive the other hides) with
  no `dive_buddies` row and a non-blank
  `buddy` or `dive_master`, with the dive number, date and site name for
  display, plus one fetch of the candidate buddies. Parsing and matching
  run in memory; dives that parse to no names are dropped.
- `Future<ConversionReceipt> apply(List<ConversionPlan> plans, {required
  String diverId, required String newBuddyNote})`, in one transaction,
  then one `SyncEventBus.notifyLocalChange()`. For each plan:
  1. Skip the dive if it gained any `dive_buddies` row since planning.
  2. Resolve each `create` target again against the current candidates
     and a per-run cache keyed by the match key, so a new name shared by
     many dives creates one record, and a record created elsewhere since
     planning is reused.
  3. Create missing records with `diverId` and `newBuddyNote` (the
     localized "Converted from dive buddy text", passed in from the UI).
  4. Claim an unowned matched record for the diver, as the UDDF importer
     does (#1806); `getAllBuddies(diverId:)` filters strictly on
     `diver_id`, so an unclaimed record would be linked yet missing from
     the diver's buddy list.
  5. Insert the links.
  The receipt lists every link id, created buddy id and claimed buddy id.
- `Future<void> undo(ConversionReceipt receipt)`, in one transaction,
  then one notify:
  1. Delete the receipt's link rows that still exist, tombstoning each.
  2. Delete each created buddy that now has no dive link, through the
     same cert-tombstoning path `deleteBuddy` uses. A created buddy that
     another dive has linked since is kept.
  3. Set `diver_id` back to NULL on claimed records that are still owned
     by that diver.
  Because the text columns were never touched, the text tile and the
  Link action reappear on their own.

A throw anywhere in `apply` or `undo` rolls back the whole transaction;
the UI shows an error snackbar and nothing is half-written. `apply`
returns an empty receipt, and the UI offers no Undo, when every plan was
skipped.

### 5. Repository (`BuddyConversionRepository`, reached through `BuddyRepository`)

`buddy_repository.dart` is already 1,230 lines, past the project's 800
line cap, so the conversion's reads and writes live in
`lib/features/buddies/data/repositories/buddy_conversion_repository.dart`
and `BuddyRepository` exposes thin delegating methods, the same shape as
`BuddyMergeRepository` behind `mergeBuddies` and `bulkDeleteBuddies`.
Every write still goes through the sync-aware buddy repository layer.

- `candidateBuddies(String diverId) -> List<MatchCandidate>`: the
  diver's own and unowned buddies with linked-dive counts.
- `unlinkedTextDives(String diverId) -> List<UnlinkedTextDive>`.
- `apply(plans, diverId, newBuddyNote) -> ConversionReceipt`: owns its
  transaction and its single notify, like `mergeBuddies`.
- `undo(ConversionReceipt)`: likewise.

The service in section 4 delegates `apply` and `undo` to these through
`BuddyRepository`, and keeps planning (parse and match) for itself.

Sync: these mark only `buddies` and `diveBuddies` rows. They do **not**
stamp the parent dive. `diveBuddies` is a parent-gated child
(`SyncDataSerializer.parentGatedChildEntities`), and since #1769 a
pending child mark exports on its own through `_withPendingChildren`.
Restamping the dive would let this device's whole dive row win
last-writer-wins over a newer edit made on another device, across
potentially hundreds of dives in one bulk run. The older
`addBuddyToDive` still stamps the dive; this path deliberately does not.

### 6. Buddies card (`dive_detail_page.dart`)

The page is already 5,747 lines, so the new pieces live in their own
widget files and the page only wires them in. While the dive has no
`dive_buddies` rows:

- The buddy text tile from #1837 shows the raw trimmed text only when
  `LegacyNameParser.parse(dive.buddy)` is non-empty.
- A second plain tile shows the raw dive-master text, subtitled with the
  localized Dive Master role name, when that text parses to names.
- Below the text tiles, a `TextButton.icon` ("Link to buddy records")
  opens the review sheet.
- "Solo dive" shows when there are no links, no diver role, and both
  texts parse to nothing.

### 7. Review sheet (`lib/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart`)

A modal bottom sheet, like `BuddyPicker`'s selection sheet.

```text
Link buddy records
From "Jim Dunfield and Leo" · Dive master "Ana Ruiz"

Jim Dunfield            [Buddy ▾]        ⋮
  Existing buddy
Leo                     [Buddy ▾]        ⋮
  New buddy · Did you mean Leo Cox?  [Use]
Ana Ruiz                [Dive master ▾]  ⋮
  New buddy
+ Add a name
                          [Cancel] [Link 3]
```

- One flat list; each row's role is pre-seeded from the text it came
  from.
- Role dropdown: every role from `allDiveRolesProvider`, localized.
- Row menu: Edit name (re-runs matching for that row), Choose existing
  buddy (a searchable single-select list of the diver's buddies), Remove.
- Status line: Existing buddy; New buddy; New buddy with a "Did you mean
  X?" suggestion and a Use button; Existing buddy with "2 buddies named
  X" on a tie.
- Add a name appends a row with the Buddy role.
- The Link button reads "Link N" and is disabled at zero rows.
- The sheet returns the edited plan; the caller applies it, refreshes
  the affected providers explicitly, and shows "Linked N buddies" with
  Undo. The refresh cannot be left to table-change streams: the
  paginated dive list's stream does not watch `dive_buddies`, and the
  buddy count providers tick only on `buddies` and `dives`, which a
  links-only conversion does not write. It invalidates the
  `buddiesForDiveProvider`, `buddyStatsProvider`,
  `diveIdsForBuddyProvider` and `divesForBuddyProvider` families,
  `allBuddiesProvider`, `allBuddiesWithDiveCountProvider`,
  `divesProvider` and `diveListNotifierProvider` (the table's Buddy
  column reads `getAllDives`), and the bulk page's data provider. It
  runs through the `ProviderContainer`, never a `WidgetRef`, because
  Undo can be tapped after the page that ran the conversion is gone.

The bulk page opens this same sheet for a single dive.

### 8. Bulk page (`lib/features/settings/presentation/pages/link_buddy_names_page.dart`)

- Route `/settings/link-buddy-names`, a `ListTile` in the Data Tools card
  of `settings_page.dart` beside Fix dive times and Data quality.
- Loads `planCandidates(activeDiverId)`. Empty state: "Every buddy name
  is linked to a buddy record".
- Header summary: dives count, new buddies count, links to existing
  buddies count, recomputed as dives are unchecked.
- One row per dive: its identity (number, date through the l10n-aware
  formatter, site name; reusing the Data Quality `DiveIdentityLabel` if
  it fits), the parsed names as chips marked Existing or New with the
  Dive Master ones labelled, and a checkbox on by default.
- Tapping a row opens the per-dive review sheet; linking there converts
  that dive alone and removes it from the list.
- "Link N dives" applies the checked plans in one transaction, re-plans,
  and shows "Linked buddies on N dives" with Undo, which reverses the
  whole batch from its receipt.
- `ListView.builder`, two queries to plan, in-memory parse and match, so
  a library of thousands of imported dives stays responsive.

## Testing

TDD, one unit at a time, each test failing before its code exists.

1. Parser table tests: commas, each conjunction word, `/ & + ;`,
   newlines, `，` and `、`, parentheses kept whole (`Joe (Customer)`,
   `Ann (instructor, PADI)`), placeholders including `N/A`, `keine` and
   `John / N/A` (only `John`),
   letterless parts, case-insensitive dedupe, the `Ortega y Gasset`
   split pinned as documented behaviour.
2. Matcher tests: Unicode case folding (`ÉRIC` / `éric`), tie ranking,
   suggestion only on a unique whole-word prefix, two names resolving to
   one record collapsing into one link, Dive Master role winning the
   collapse.
3. Service and repository tests on an in-memory database: plan and apply;
   one created record per new name across a batch; a dive that gained
   links after planning is skipped; an unowned match is claimed; only
   `buddies` and `diveBuddies` are staged, never `dives`; undo removes
   links, deletes created and unlinked records, keeps a created record
   another dive has linked, and reverts claims; a throw mid-apply rolls
   everything back.
4. Widget tests: the card (a `None` text reads Solo, the dive-master
   tile, the Link button), extending #1837's
   `dive_detail_text_buddy_test.dart`; the review sheet (edit, remove,
   re-point, Use a suggestion, change a role, the Link count); the bulk
   page (summary counts, unchecking, empty state, Undo snackbar).

## Localization

Every new string is added to all 11 ARB files (ar, de, en, es, fr, he,
hu, it, nl, pt, zh) with real translations, inserted beside a
neighbouring key in the feature-grouped non-English files, then
regenerated. Dates go through the l10n-aware formatter.

## Delivery

- This worktree's branch starts at #1837's commit `40e41ad4129`.
- The PR targets main, with `Refs #1831` and a note that it depends on
  #1837. After #1837 squash-merges: `git rebase --onto origin/main
  40e41ad4129`.
- `dart format .` and a clean `flutter analyze`, then one full test run.
