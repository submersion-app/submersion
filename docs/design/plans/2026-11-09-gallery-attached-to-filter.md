# Gallery Attached to Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the media library filter by what a picture is attached to (dive, site, equipment, nothing), and label the site, equipment and Unlinked runs in the By dive view with section headings.

**Architecture:** A new `MediaAttachmentKind` set on `MediaLibraryFilter`, compiled to one OR'd clause in `MediaLibraryRepository._baseWhere` over the media row's own link columns, so every view that reads the filter gets it. The sheet gains a self-contained chip section, the active strip one chip. The By dive list adds a `MediaGroupHeaderKind.section` spec ahead of a group whenever the group kind changes, reusing the multi-header-per-group support the timeline's month headers already use.

**Tech Stack:** Flutter, Riverpod, Drift, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-11-09-gallery-attached-to-filter-design.md`

## Global Constraints

- Precedence, identical to `groupByDive` and the By dive SQL key: Dive = `dive_id` set; Site = `dive_id` null and `site_id` set; Equipment = `dive_id` and `site_id` null and `equipment_id` set; Unlinked = all three null.
- Several kinds may be picked; a row matches any picked kind; empty set = no constraint.
- JSON key `attachedTo`, a sorted list of enum names, omitted when empty. Unknown names dropped; non-list decodes to empty.
- Legacy `"health": "unlinked"` keeps decoding to no constraint (not mapped).
- No schema change, no migration, no sync change.
- New strings in all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh); ARB files are feature-grouped, insert next to a neighbouring key of the same group.
- No file over 800 lines. No em-dashes anywhere. `dart format .` before each commit.

## Review Focus

1. An album holding only `attachedTo` must not be treated as empty (`isEmpty` false), or the agent-access write refuses it and the strip hides. Pinned in Task 1.
2. Site plus a site id filter: a dive photo at that site must NOT come back. Pinned in Task 2.
3. Map view and `countInScope` read the same clause: count must agree with the page. Pinned in Task 2.
4. A section heading's measured extent must equal its rendered height, or the grid's precomputed layout drifts and tiles overlap. Pinned in Task 5.
5. A section heading appears once per section even when the section spans two loaded pages (the group list grows, the heading must not repeat). Pinned in Task 5.

---

### Task 1: Filter facet in the domain

**Files:**
- Modify: `lib/features/media/domain/entities/media_library_filter.dart`
- Test: `test/features/media/domain/media_library_filter_attached_to_test.dart`

**Interfaces:**
- Produces: `enum MediaAttachmentKind { dive, site, equipment, unlinked }` (declared beside `MediaHealthFilter`, doc comment states the precedence); `MediaLibraryFilter.attachedTo` (`Set<MediaAttachmentKind>`, default `const {}`); `copyWith({Set<MediaAttachmentKind>? attachedTo})`.

- [ ] **Step 1: Write the failing tests**

```dart
test('attachedTo alone makes the filter non-empty', () {
  expect(const MediaLibraryFilter(attachedTo: {MediaAttachmentKind.site}).isEmpty, isFalse);
});
test('equality and hash follow attachedTo as a set', () {
  const a = MediaLibraryFilter(attachedTo: {MediaAttachmentKind.site, MediaAttachmentKind.dive});
  const b = MediaLibraryFilter(attachedTo: {MediaAttachmentKind.dive, MediaAttachmentKind.site});
  expect(a, b); expect(a.hashCode, b.hashCode);
  expect(a == const MediaLibraryFilter(attachedTo: {MediaAttachmentKind.dive}), isFalse);
});
test('copyWith keeps and replaces attachedTo', () { /* keep on unrelated change, replace when passed, {} clears */ });
test('toJson writes a sorted list and omits it when empty', () {
  expect(const MediaLibraryFilter(attachedTo: {MediaAttachmentKind.unlinked, MediaAttachmentKind.dive}).toJson()['attachedTo'], ['dive', 'unlinked']);
  expect(MediaLibraryFilter.none.toJson().containsKey('attachedTo'), isFalse);
});
test('fromJson round-trips and drops unknown names', () {
  expect(MediaLibraryFilter.fromJson({'attachedTo': ['site', 'boat']}).attachedTo, {MediaAttachmentKind.site});
  expect(MediaLibraryFilter.fromJson({'attachedTo': 'site'}).attachedTo, isEmpty);
});
test('the retired health unlinked value still decodes to no constraint', () {
  final f = MediaLibraryFilter.fromJson({'health': 'unlinked'});
  expect(f.health, isNull); expect(f.attachedTo, isEmpty); expect(f.isEmpty, isTrue);
});
```

- [ ] **Step 2: Run** `flutter test test/features/media/domain/media_library_filter_attached_to_test.dart`. Expected: compile FAIL (`MediaAttachmentKind` undefined).
- [ ] **Step 3: Implement** the enum and field through `isEmpty`, `copyWith`, `toJson` (sorted by `name`, like `tagIds`), `fromJson` (via `_enumByName` per element, skipping nulls), `==` and `hashCode` (`SetEquality`).
- [ ] **Step 4: Run** the new test plus `test/features/media/domain/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): add an Attached to facet to the library filter`.

### Task 2: SQL clause

**Files:**
- Modify: `lib/features/media/data/repositories/media_library_repository.dart` (`_baseWhere`, plus a private `_attachedToFacet(Set<MediaAttachmentKind>)` returning `Expression<bool>`)
- Test: `test/features/media/data/media_library_attached_to_filter_test.dart`

**Interfaces:**
- Consumes: `MediaLibraryFilter.attachedTo`, `MediaAttachmentKind` (Task 1).

- [ ] **Step 1: Write the failing tests.** Fixture via `setUpTestDatabase`: one dive at site `S1`, sites `S1` and `S2`, one equipment row; media rows `dive-photo` (dive_id = the dive), `site1-map` (site_id `S1`), `site2-map` (site_id `S2`), `gear-photo` (equipment_id), `loose` (no links, `retain_in_library` 1 if the library query needs it to be visible). Tests:
  - `{dive}` gives `[dive-photo]`; `{site}` gives both site maps; `{equipment}` gives `[gear-photo]`; `{unlinked}` gives `[loose]`.
  - `{site, equipment}` gives the three non-dive, linked rows; `{}` gives all five.
  - `siteId: 'S1'` with `{site}` gives `[site1-map]` only (not `dive-photo`).
  - `countInScope` equals the page length for `{site}`.
- [ ] **Step 2: Run** it. Expected: FAIL (filter ignored, all rows returned).
- [ ] **Step 3: Implement** `_attachedToFacet`: OR of one predicate per picked kind using `m.diveId`, `m.siteId`, `m.equipmentId` with the precedence in Global Constraints; `_baseWhere` ANDs it when the set is not empty. No join added.
- [ ] **Step 4: Run** the test, then `test/features/media/data/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): filter the library by what a picture is attached to`.

### Task 3: Strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`; regenerate with `flutter gen-l10n`.

**Interfaces:**
- Produces (en values):
  - `media_library_filter_attachedTo`: "Attached to"
  - `media_library_filter_attachedDive`: "Dive"
  - `media_library_filter_attachedSite`: "Site"
  - `media_library_filter_attachedEquipment`: "Equipment"
  - `media_library_filter_attachedUnlinked`: "Unlinked"
  - `media_library_filter_attachedToChip`: "Attached to: {kinds}" (placeholder `kinds`, String)
  - `media_library_filter_listSeparator`: ", " (description: joins kinds in the chip; include any trailing space)
  - `media_library_sectionSitePictures`: "Site pictures"
  - `media_library_sectionEquipmentPictures`: "Equipment pictures"
- Real translations in every locale; zh separator "、", ar "، ".

- [ ] **Step 1:** Add the keys beside `media_library_filter_tags` / `media_library_unlinkedHeader` in each file, with `@` descriptions in en.
- [ ] **Step 2: Run** `flutter gen-l10n` and `flutter analyze lib/l10n`. Expected: no errors, no untranslated-message warnings for the new keys.
- [ ] **Step 3: Commit** with Task 4 (strings unused until then would only be noise in history).

### Task 4: Filter sheet section and active chip

**Files:**
- Create: `lib/features/media/presentation/widgets/media_library_attachment_filter_section.dart`
- Modify: `lib/features/media/presentation/widgets/media_library_filter_sheet.dart` (state `_attachedTo`, set in `initState` from the filter, cleared in `_clearAll`, applied in the apply builder, loaded from an album in `_loadAlbum`; section placed between the Type chips and the `Divider` above Site)
- Modify: `lib/features/media/presentation/widgets/media_library_active_filter_chips.dart`
- Test: `test/features/media/presentation/media_library_attachment_filter_test.dart`

**Interfaces:**
- Consumes: Task 1 types; Task 3 strings.
- Produces: `MediaLibraryAttachmentFilterSection({required Set<MediaAttachmentKind> selected, required ValueChanged<Set<MediaAttachmentKind>> onChanged})`, `FilterChip` per kind in enum order, keys `ValueKey('media_filter_attached_${kind.name}')`, title styled `labelLarge` like the Type title. A top-level `String mediaAttachmentKindLabel(AppLocalizations l10n, MediaAttachmentKind kind)` in the same file, shared with the chip strip.

- [ ] **Step 1: Write the failing widget tests:**
  - Section: tapping Site then Equipment calls `onChanged` with `{site}` then `{site, equipment}`; tapping a selected chip removes it.
  - Sheet: opening with a filter holding `{dive}` shows Dive selected; Clear all deselects it; Apply writes `{dive, site}` to `mediaLibraryFilterProvider` after tapping Site.
  - Strip: with `{site, equipment}` it shows one chip reading "Attached to: Site, Equipment" (kinds in enum order); deleting it leaves `attachedTo` empty and the strip, with nothing else set, renders nothing.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement** the section, wire the sheet, and add the strip chip (joined with `media_library_filter_listSeparator`, in enum order) after the existing type chip.
- [ ] **Step 4: Run** the new test plus `test/features/media/presentation/media_library_filter_sheet_test.dart`, `media_library_active_filter_chips_test.dart`, `media_smart_album_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): pick what pictures are attached to in the library filter`.

### Task 5: By dive section headings

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_group_header.dart`
- Modify: `lib/features/media/presentation/widgets/media_library_grouped_list.dart` (`_headers`)
- Test: `test/features/media/presentation/media_group_header_test.dart` (extend), `test/features/media/presentation/media_library_grouped_list_sections_test.dart` (new)

**Interfaces:**
- Produces: `MediaGroupHeaderKind.section`; `MediaGroupHeaderSpec.icon` (`IconData?`, used only by sections); a section's style is `textTheme.titleSmall` in `colorScheme.primary` with a leading icon sized to the style's font size and a 1px primary rule under the text. The rule's height is carried by the spec (a `ruleExtent` getter, 1 for sections, 0 otherwise) and added by `MediaGroupHeaderMeasurer.extentOf`, so measure and paint stay one source.
- Headings: `Icons.place_outlined` + "Site pictures", `Icons.build_outlined` + "Equipment pictures", `Icons.link_off` + the existing `media_library_unlinkedHeader`.

- [ ] **Step 1: Write the failing tests:**
  - Header: a section spec renders its icon and label, is not a button, and `measurer.extentOf(spec, width)` equals the rendered `MediaGroupHeader`'s height at text scale 1.0 and 2.0.
  - Grouped list, groups dive, dive, site, site, equipment, unlinked: exactly one "Site pictures" above the first site header, one "Equipment pictures", one Unlinked text (the section, not a second plain header), and no section text above the dives.
  - Groups of dives only: no section heading.
  - Groups site, site (filter = Site): the list starts with "Site pictures".
  - Rebuilding with one more site group appended (next page) still shows one "Site pictures".
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.** In `_headers`, track the previous group's kind (dive, site, equipment, unlinked) and prepend a section spec when it changes to site or equipment; the Unlinked `DiveGroupHeader` (null `diveId`) gets the section spec instead of its plain header when its kind changes, which it always does since it is pinned last. Section padding `EdgeInsets.fromLTRB(12, 20, 12, 6)`.
- [ ] **Step 4: Run** the new tests plus `test/features/media/presentation/` grouped-list and header tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): label the site, equipment and unlinked runs in By dive`.

### Task 6: Agent access pin and final checks

**Files:**
- Test: `test/features/agent_access/data/records/logbook_records_test.dart` (extend: an album with `attachedTo: {site}` reads back `'attachedTo': ['site']`, and the smart album write accepts a filter holding only `attachedTo`).

- [ ] **Step 1:** Add the tests; run them. Expected: PASS without code changes (the facet flows through `toJson`/`fromJson`). If the write refuses, fix `isEmpty` (Task 1), not the writer.
- [ ] **Step 2:** `dart format .`, `flutter analyze`, `flutter test test/features/media test/features/agent_access test/architecture test/shared`. Expected: no issues, all pass.
- [ ] **Step 3: Commit** `test(agent-access): pin the Attached to facet in album reads and writes`.
