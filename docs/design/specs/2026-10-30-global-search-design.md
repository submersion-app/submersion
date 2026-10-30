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
| Errors | `describeQueryError` |
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

Equipment sets, documents, plans and tracks have no query entity. Each gets a
text-only `QueryEntity` that is not registered, plus a `QuerySubject` value,
following the precedent of the name-only subjects. Field syntax does not apply
to them, so they simply drop out of a field query.

## 5. Behaviour

**Parsing per source.** The text is parsed once for each source. A source that
refuses it (`depth > 30m` for buddies) is left out rather than treated as an
error. If every source refuses it, the page shows the error for the first
source, which is Dives.

**Dive numbers.** A bare number also matches that dive number, as the jump list
does (#3455), by widening the Dives query to text OR number.

**Results.** Each source with a match shows a header with its total and its
first five rows in the order of its list: dives and trips newest first,
equipment active first, the rest by name.

**See all.** A source with a list applies the same query to that list, clears
its other filters, and pushes it, so Back returns to the results, unless that
list was already under the search page, when the app walks back to it. The
Training tabs replace the stack instead, because both share one constant page
key. Chips on the list show the search and clear it. A source with no list expands in place; those
tables are small, so they load every match.

**Equipment.** The list hides retired and sold gear by default but search finds
it, so See all selects all statuses or the count would disagree.

**Species.** Results search the catalog rather than sightings, because the
question may be whether the app knows a species at all. Built-in names show in
the diver's language; matching stays on the stored English and scientific
names, as the species lists do.

**Live.** Results refresh when a table they read changes.

**Units and dates.** Dive rows show depth and date through `UnitFormatter`.

## 6. Reaching it

- **Route:** `/search`, inside the shell, so navigation stays visible.
- **Navigation:** a `search` destination after Trips, which a diver can move like
  any other. Existing phone bottom bars do not change: it lands first in More,
  where it can be pinned. A diver with a saved order finds it at the end.
- **Keyboard:** Cmd/Ctrl+K, from anywhere, listed in the shortcuts help.
  Cmd/Ctrl+F stays the Dives search. Pressing it again on the page refocuses
  the field and selects the text.
- **Field:** focused on open. Esc clears it. Results live in the page, so
  leaving the section starts fresh and Back from a result keeps them.

## 7. Structure

`lib/features/global_search/`:

- `domain/global_search_models.dart`: source kinds, hits, sections.
- `query/global_search_entities.dart`: the text-only entities.
- `data/global_search_sources.dart`: one declaration per source (entity,
  columns, order, visibility scope, preview limit).
- `data/global_search_repository.dart`: runs one source (count and rows).
- `presentation/providers/`: results provider, focus tick, list handoff.
- `presentation/pages/global_search_page.dart`, plus `widgets/`.

The rows are read in one SQL statement per source rather than hydrating domain
entities, so a keystroke never loads a dive's profile or a document's pages.

## 8. Testing

- Repository tests over a real database: every source finds a row, is scoped to
  the diver, shows a shared site and trip, hides a hidden one, and counts past
  the preview limit.
- A census test: every `GlobalSearchKind` has a source, and every list subject
  in `QuerySubject` has a source, so a new list cannot be forgotten.
- Provider tests: per-source parsing, all sources refusing, dive numbers.
- Handoff tests: each list's filter state after See all.
- Widget tests: sections, See all, in-place expansion, empty and error states,
  focus, Esc.
- Nav and shortcut tests updated for the new destination.
