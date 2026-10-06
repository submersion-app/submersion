# Improve dive site selection lists (#1080)

## Problem

A diver with hundreds of dive sites around the world struggles to pick one.
The issue asks for three things:

1. Search across every location attribute (country, region, city, island,
   body of water), so a site can be found by where it is when its name is
   forgotten.
2. A hierarchical view, Country then Region, instead of one flat list.
3. (From the issue comment) Some organisation on the Dive Sites page beyond an
   alphabetical list.

Already shipped before this work: the Refine panel's site field is a
type-ahead matching name, `locationString`, country and region (#1674), and
the repository sorts names case-insensitively, so the case-sensitive ordering
the reporter saw is gone.

Remaining gaps:

- City, island and body of water are not searchable anywhere.
- Three different widgets pick a site, each with its own search: the Refine
  type-ahead (`SearchableFilterDropdown`), the dive edit `SitePickerSheet`
  (also used by both nav track pages), and the media import review's
  `showSitePickerSheet`, which has no search at all and shows names only.
- The Refine type-ahead rows show only the name, so two sites called
  "Blue Hole" are indistinguishable.
- Nothing groups sites by location.

## Approved design

### 1. Shared search and grouping (pure logic)

**Search**, `lib/features/dive_sites/domain/utils/site_search.dart`:

- `siteSearchText(DiveSite)` joins name, country, region, city, island and
  body of water with `buildFilterSearchText`.
- `SiteQuery(query)` normalizes the query once (trim, lowercase, strip
  diacritics, via `normalize` from `core/text/fuzzy_match.dart`) and splits it
  on whitespace. `matches(normalizedSearchText)` is true when every word is a
  substring of the normalized search text. An empty query matches everything.
  So "cancun" finds "Cancún" and "blue egypt" finds Blue Hole (Dahab, Egypt).
- Replaces `siteMatchesPickerQuery` (`dive_log/presentation/utils/
  site_picker_search.dart`) and the Refine field's inline search text.

**Grouping**, `lib/features/dive_sites/domain/utils/site_grouping.dart`:

- `groupSitesByLocation<T>(List<T> items, DiveSite Function(T) siteOf)`
  returns `List<SiteCountryGroup<T>>`. Generic so it groups plain `DiveSite`s
  (picker) and `SiteWithDiveCount` (Sites page).
- Country key: trimmed and case-folded (via `textSortKey`), so "australia" and
  "Australia " form one group. The header label is the most common trimmed
  spelling in the group (ties: first seen).
- Countries ordered with `compareTextForSort`. Sites with a null or blank
  country go into a final group whose key is a reserved sentinel and whose
  label the UI renders as "No country".
- Inside a country: sites with no region first, without a subheader, then
  region subgroups ordered with `compareTextForSort`, keyed the same way as
  countries.
- Items keep their input order inside each group, so the caller's sort carries
  through.

**Flattening**, same file:

- `flattenSiteGroups<T>(groups, {required Set<String> expanded})` returns
  `List<SiteListRow<T>>`, a sealed type with `CountryHeaderRow` (key, label,
  site count, isExpanded), `RegionHeaderRow` (label) and `SiteRow<T>` (item).
- Children of a country whose key is not in `expanded` are omitted.

### 2. One shared site picker sheet

Location: `lib/features/dive_sites/presentation/widgets/site_picker/`.

- `site_picker_sheet.dart`: the sheet and `pickOrCreateSite`.
- `grouped_site_list_view.dart`: header widgets and the flattened-row
  rendering, reused by the Sites page.
- `site_picker_field.dart`: the Refine panel field.

The old `dive_log/presentation/widgets/pickers/site_picker_sheet.dart` and
`media/presentation/widgets/site_picker_sheet.dart` are removed.

**Layout**, top to bottom, in the style of the buddy picker sheet:

1. Title row with an optional "New Dive Site" button.
2. The existing "sorted by distance" hint line, when a location anchor exists.
3. A full-width search field with a clear button, filtering on every
   keystroke (no debounce; the list is in memory and each site's search text
   is normalized once).
4. The existing `SimilarValueHint` "did you mean" suggestion.
5. Divider, then the list.

**List contents:**

- Filter mode only: a leading "All sites" row that clears the selection.
- A "Nearby" section, only when a dive or device location is known: sites
  within 50 km, nearest first, each with its distance in the diver's units.
  These sites also appear in their country group.
- Collapsible country groups with a site count on each header, region
  subheaders and site rows inside.

**Expansion:**

- Starts with the selected site's country expanded.
- If every site is in one country, that country starts expanded.
- While the query is non-empty, every group containing a match is expanded,
  and the Nearby section is filtered by the same query. Clearing the query
  restores the manually chosen expansion set.

**Rows:** the existing leading avatar (selected, nearby or plain), the site
name, a trailing check on the selected site, and a subtitle:

- Inside a group: locality (city, else island) and body of water joined by
  " · ", e.g. "Dahab · Red Sea". No subtitle when both are empty.
- In Nearby: the full `locationString` plus the distance.

**Call sites:**

- Dive edit and both nav track pages keep calling `pickOrCreateSite(...)`
  with an unchanged signature.
- Media import review opens the same sheet without "New Dive Site" and
  without a location anchor.
- The Refine panel's Location group replaces its site type-ahead with
  `SitePickerField`: a read-only decorated field (label "Dive site", site icon)
  showing "All sites" or the selected site's name with its location. Tapping
  opens the sheet in filter mode; a clear button resets to "All sites".

### 3. Sites page grouping

- `enum SiteGroupBy { none, location }` and a session `StateProvider`
  `siteGroupByProvider`, default `none`. Not persisted, like `siteSortProvider`.
- `SortBottomSheet` gains an optional `footer` widget. Only the Sites page
  passes one: a "Group by" segmented control (None / Country & region). It is
  hidden in table mode, where the list stays flat.
- Grouped detailed and compact modes group the output of
  `sortedSitesWithCountsProvider`, so filters and the chosen sort still apply,
  inside each group. Rows render through the flattened rows, with the existing
  site tiles for sites and the shared header widgets.
- Expansion state lives in a session provider so it survives opening a site
  and returning. Countries start collapsed, except the country of the site
  shown in the desktop master-detail pane. An active search or filter expands
  every group with a match.
- Multi-select, select-all and swipe actions keep working on site rows;
  headers are not selectable. The map view is unchanged.

### Strings

New ARB keys: "No country", "Nearby", "Group by", "None", "Country & region",
and a pluralized country header site count. The "All sites" row reuses the
existing `diveLog_filter_allSites` key. Every locale ARB gets a real translation, then l10n is
regenerated.

### Testing (TDD)

- Unit: search (every field, diacritics, multi-word), grouping (case-folded
  keys, spelling choice, No country last, no-region-first, order preserved),
  flattening (collapsed countries hide children).
- Widget: the sheet (search filters and auto-expands, Nearby section with an
  anchor, "All sites" row in filter mode, selected site's country expanded),
  `SitePickerField`, the Sites page grouped mode and its hidden option in table
  mode.
- Existing picker, Refine and media import tests updated to the new widgets.

## Out of scope

- Persisting the Sites page group-by choice per diver.
- Grouping by fields other than country and region.
- Pinned (sticky) section headers.
