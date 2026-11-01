# Global search: one search field for every kind of record

Date: 2026-10-30
Status: approved to build; the maintainer chose to skip the design questions, so
every decision below is the builder's call, recorded here so it can be changed.
Release: v1.8.4

## 1. Problem

Dives have a strong search: plain words filter the list, and the same field
reads query syntax such as `depth > 30m` (#2773). Every other record type can
only be searched from inside its own list, so a diver has to know whether
"Bonaire" is a site, a trip or a dive center before they can look for it.

## 2. Goal

One search, reachable from anywhere, that finds any kind of record from one
field and opens it, or opens its list with the search applied.

Success:

- Typing a word shows matches grouped by record type, as you type.
- The field reads what the Dives field reads: words, quoted phrases and query
  syntax.
- A record type's results are exactly what its own list would show for the same
  search, including shared and hidden rows.

Not goals: a new search index, ranking across record types, natural language
(Ask stays on Dives), recent searches, saved searches.

## 3. Reused, not rebuilt

| Need | Reused |
| --- | --- |
| What a word matches | Each entity's `textSearchSql` |
| Parsing | `QueryParser`, `validateQuery` |
| SQL | `compileQuery` |
| Who sees what | `VisibilityFilter`, the same rule each list applies |
| Debounce and keeping results while typing | `DebouncedSearchResults` |
| The field | `QueryTextField`, completions and error underlines included |
| Errors | `describeQueryError` |
| Each result's row | The tile its own list draws, from the provider that list reads |
| Applying a search to a list | The lists' existing query providers |

## 4. Record types

Fourteen sources, in this fixed order, which follows the navigation:

| Source | Table | See all |
| --- | --- | --- |
| Dives | `dives` | Dives list |
| Sites | `dive_sites` | Sites list |
| Trips | `trips` | Trips list |
| Equipment | `equipment` | Equipment list, all statuses |
| Equipment sets | `equipment_sets` | in place |
| Buddies | `buddies` | Buddies list |
| Dive centers | `dive_centers` | Dive centers list |
| Certifications | `certifications` | Certifications list |
| Courses | `courses` | Courses list |
| Species | `species` | Species catalog (Manage) |
| Documents | `documents` | in place |
| Dive plans | `dive_plans` | in place |
| GPS tracks | `gps_tracks` | in place |
| Underwater routes | `nav_tracks` | in place |

Left out on purpose:

- **Media.** It has no page of its own, and the query program left it out too.
- **Tags and dive types.** A dive's text search already matches them, so the
  dives that carry them are the useful answer.
- **Children of a record** (tanks, weights, sightings, custom fields). They are
  found through their parent.

Equipment gains `textSearchSql` (name, brand, model, serial number, tags), the
columns its search route already reads. As a side effect, a bare word in the
Equipment query field now works rather than being refused.

Equipment sets, documents, plans and tracks have no list query. Each gets a
registered `QueryEntity` of its own in its feature, with real fields, so the
language reaches every record: `expires < 2027`, `mode = ccr`, `itemCount > 3`,
`file ~ reef`. The fields are the ones each record's row or page shows. The
registry guards hold them to the schema as they do every other entity. No list
reads them, so nothing else about those records changes.

| Record | Fields | Relations |
| --- | --- | --- |
| Equipment set | name, description, default, itemCount | items |
| Document | title, type, issuer, referenceNumber, issueDate, expiryDate, primary, notes | tags, dive, site, trip, equipment, course, certification, buddy, center |
| Dive plan | name, mode, date, depth, runtime, notes | site |
| GPS track | name, date, duration, deviceName, source, file | |
| Underwater route | name, date, depth, distance, duration, deviceName, source, file | dive, site, equipment |

Shared key names are deliberate: `depth > 30m` finds dives, sites, plans and
routes from one query.

## 5. Behaviour

**Parsing per source.** The text is parsed once for each source. A source that
refuses it (`depth > 30m` for buddies) is left out rather than treated as an
error. If every source refuses it, the field underlines the error for the first
source that can suggest a fix, or else the first, which is Dives: a typo in
`expirs < 2027` means nothing to Dives, but Documents knows what was meant.

**The field.** It is `QueryTextField`, the Dives field. That widget assumes one
root, so it takes a `QueryTextReader` that answers for several: the text stands
if any source reads it, and completions pool every source's, one from each in
turn so a type with few fields is not crowded out by Dives. As on Dives, text
that does not parse yet (`depth >`) leaves the last results up.

**Dive numbers.** A bare number also matches that dive number, as the jump list
does (#3455), by widening the Dives query to text OR number.

**Results.** Each source with a match shows a header with its total and its
first five rows in the order of its list: dives and trips newest first,
equipment active first, the rest by name.

**Rows.** A result is the row its own list draws, so it carries that list's
statistics, ratings, badges and card settings, and any later change to the row.
Compact where a list offers the choice, whatever view that list is set to:
search shows many types at once. Sets, plans and catalog species had rows
private to their pages, which are now shared widgets. Search reads only ids and
totals; the records come from the provider the list reads, so a row is as
current as the list. Those providers hold every record and are normally loaded
already. Dives are paged, so their rows read by id.

**See all.** A source with a list applies the same query to that list, clears
its other filters, and pushes it, so Back returns to the results, unless that
list was already under the search page, when the app walks back to it. The
Training tabs replace the stack instead, because both share one constant page
key. Chips on the list show the search and clear it. A source with no list expands in place; those
tables are small, so they load every match.

**Equipment.** The list hides retired and sold gear by default but search finds
it, so See all selects all statuses or the count would disagree.

**Species.** Results search the catalog rather than sightings, because the
question may be whether the app knows a species at all. A species the diver has
logged shows the logbook's row, with its sightings; any other, the catalog's. Built-in names show in
the diver's language, and a word matches a built-in name in any of the app's
languages, as dive types do. The species query field gains this too.

**Documents.** A word matches what the Documents page searches (title, issuer,
reference number, owner, tags) plus the notes. Notes are the one difference from
a list: this section has no list to disagree with, and a note is shown on its
document.

**Live.** Results refresh when a table they read changes, including the tables
behind who can see a row (shares, hides, shared library memberships).

**Units and dates.** Dive rows show depth and date through `UnitFormatter`.

## 6. Reaching it

- **Route:** `/search`, inside the shell, so navigation stays visible.
- **Navigation:** a `search` destination last before Settings, which a diver
  can move like any other. It is a door to the other sections rather than one
  of them, so it sits at the end; existing phone bottom bars do not change,
  since it lands in More, where it can be pinned.
- **From every list:** each list's search row has a `Search everything for
  "text"` row beneath it while the field is focused, which opens global search
  with the text as typed, parsed or not: `expires < 2027` typed on Buddies
  still finds the documents and certifications that read it.
- **Keyboard:** Cmd/Ctrl+K, from anywhere, listed in the shortcuts help.
  Cmd/Ctrl+F stays the Dives search. Pressing it again on the page refocuses
  the field and selects the text.
- **Field:** focused on open. Esc clears it. Results live in the page, so
  leaving the section starts fresh and Back from a result keeps them.

## 6a. One search row for every list

The Dives list had the only inline query field; every other list searched
plain words in a full-screen box and kept its query language behind a filter
icon. The maintainer asked for all of them to work the same way, so the Dives
row becomes `EntitySearchHeader`, shared by the ten lists that have a query:
dives, sites, trips, equipment, buddies, dive centers, certifications,
courses, species (the logbook page and the catalog) and documents.

- The list's search icon (`EntitySearchAction`) opens the row with the caret
  in it, closes an idle row, and wears a badge while the list has a query.
  The row also shows whenever the list has a query, so a search is never
  active out of sight. Species and Documents had a search box always on show,
  and keep it that way (`alwaysShown`): Close clears rather than hides.
- The row is the `QueryTextField`, rooted at the list's entity: words, quoted
  phrases, the list's fields, completions and underlined errors. It writes the
  list's existing query provider once typing rests (300 ms), so the chips, the
  filter sheet's query section and the saved queries all keep working on the
  same value.
- The old full-screen `SearchDelegate`s (buddies, dive centers,
  certifications, sites, equipment, trips) are deleted: one way to search
  everywhere. Documents gains a query provider (`documentQueryProvider`) in
  place of its in-page text match, so `type = insurance` works there too.
- Equipment sets, saved plans and tracks have no list query and keep their
  pages as they are; global search reaches them.

## 7. Structure

`lib/features/global_search/`:

- `domain/global_search_models.dart`: source kinds, hits, sections.
- `data/global_search_sources.dart`: one declaration per source (entity, order,
  visibility scope, preview limit).
- `data/global_search_plan.dart`: reads the text against each source.
- `data/global_search_repository.dart`: runs one source (count and ids).
- `presentation/global_search_text_reader.dart`: the field's reading of the text.
- `lib/features/query/presentation/widgets/entity_search_header.dart` and
  `entity_search_action.dart`, `entity_search_frame.dart`,
  `search_everywhere_row.dart`: the shared list search row and its parts;
  `providers/entity_search_providers.dart` holds its open and focus state per
  subject.
- `presentation/providers/`: results provider, focus tick, dives by id.
- `presentation/pages/global_search_page.dart`, plus `widgets/`, where
  `global_search_rows.dart` draws each type's own row.

The entities live with their features (`lib/features/<feature>/query/`), as
every other entity does.

## 8. Testing

- Repository tests over a real database: every source finds a row, is scoped to
  the diver, shows a shared site and trip, hides a hidden one, and counts past
  the preview limit.
- A census test: every `GlobalSearchKind` has a source, and every list subject
  in `QuerySubject` has a source, so a new list cannot be forgotten.
- Provider tests: per-source parsing, all sources refusing, dive numbers.
- Handoff tests: each list's filter state after See all.
- Widget tests: sections, See all, in-place expansion, empty and error states,
  focus, Esc, completions, half a query keeping the last results.
- Row tests: every kind draws its own list's tile and opens its record.
- Entity tests: each new field and relation against a real database.
- Nav and shortcut tests updated for the new destination.
- Header tests: opens from the icon, debounced write, the list's language,
  Close and Esc clearing, Search everything offering unreadable text and
  opening global search with it; a request made before the page is up.
