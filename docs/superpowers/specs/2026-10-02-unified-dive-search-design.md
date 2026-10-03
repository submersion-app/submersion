# Unified dive search: one search icon for every way of finding dives

Date: 2026-10-02
Status: design approved in brainstorming, awaiting written-spec review
Issue: to be opened before PR 1 (every PR in this program links it)

## 1. Problem

The Dives area offers four separate ways to find dives, each with its own
entry point, state and behaviour:

| Surface | Entry | Behaviour today |
|---|---|---|
| Search overlay (`DiveSearchDelegate`) | magnifier icon | Phrase match over notes, name, buddy, dive master, site name/country/region, center, linked buddies, tags, custom fields. Results overlay only: it never filters the list and ignores active filters. Hint text is hard-coded English. |
| Filter sheet (`DiveFilterSheet`) | funnel icon with badge | About 20 axes, saved-query chips, links out to Advanced Search and to the query editor. |
| Advanced Search (`DiveSearchPage`, `/dives/search`) | overflow menu, sheet link, Cmd/Ctrl+F | Sectioned form holding the query editor (Text + Builder). Its axis set overlaps the sheet's but differs from it. |
| Explore (`ExplorePage`, `/dives/explore`) | sparkle icon, Cmd/Ctrl+E | On-device natural-language search. Its dive handoff REPLACES every active filter axis. |

Further confusion: the magnifier's tooltip "Search dives" and Cmd/Ctrl+F's
label "Search dives" open different surfaces; the app-bar action list is
hand-copied three times (phone, desktop master pane, table mode) and has
drifted; saved queries can only be managed from Settings.

## 2. Goal and success criteria

One search icon on the Dives screen opens one search bar. Every way of
searching (plain words, query syntax, natural language, structured filters,
saved searches) ends in the dive list filtered in place, with chips showing
exactly why.

Hard constraint from the maintainer: **no search capability that exists
today may be lost.** Two Explore capabilities were explicitly released from
that constraint (section 9).

Success:

- The Dives app bar has one search entry point (plus Sort, Map, Select and
  the overflow menu, which stay).
- Each capability in the inventory (section 9) has a named home in the new
  design and a test that proves it.
- Insights and Connections use the same Refine panel and lose no axis.

## 3. Decisions (fixed in brainstorming, do not re-litigate)

1. **Scope.** Search overlay, Filter sheet, Advanced Search, query editor
   and Explore all go behind one search icon. Sort stays its own icon.
2. **Plain words filter the list.** No new text axis is needed: the query
   language already reads a bare word as a `TextNode` over the dive
   entity's `textSearchSql`, which covers the same columns as the overlay.
3. **Natural language is an explicit Ask action**, because every sentence is
   also valid query text. Ask is shown only where the on-device model works.
   The answer is written back into the field as editable query text plus
   chips.
4. **Surface shape: an inline search bar over the live list** (option A in
   brainstorming). The list filters as you type.
5. **Field equals `query`; chips show everything.** The field shows and
   edits only `DiveFilterState.query`. Structured axes stay axes. The chip
   row shows both.
6. **Explore page retired.** Its sparkle icon, route and Cmd/Ctrl+E go.
7. **Refine panel everywhere, bar on Dives only.** The new panel replaces
   the Filter sheet in Dives, Insights and Connections. Only Dives gets the
   bar.
8. **Save captures the whole search** (axes and query), folded into one
   saved query.
9. **The bar stays open while anything is active.** Back/Esc with an active
   search clears everything and collapses.
10. **Approach: new small components, delivered in four phased PRs.**
11. **"Search all dives while filtered" is kept twice:** a Within filters /
    All dives scope toggle AND a jump-to-dive dropdown over all dives.
12. **Quotes mean an exact phrase.** Bare words each match somewhere.
13. **Refine panel:** bottom sheet on phones, right-side panel on wide
    layouts.

## 4. User experience

### 4.1 The search bar (Dives only)

States:

1. **Nothing searched.** App bar shows the title and: Search, Sort, Map
   toggle (where it exists today), Select, overflow. No Filter icon, no
   sparkle icon, no "Advanced Search" overflow item. Cmd/Ctrl+F opens the
   bar.
2. **Open, empty.** The title is replaced by the field (leading back arrow,
   trailing tune button that opens the Refine panel, badged with the count
   of active panel axes). Below the bar: saved searches (chips, plus a
   "Manage" link to the existing Settings page), recent searches (typed and
   asked, marked as such), and syntax hints (`manta`, `"blue hole"`,
   `depth > 30m`, `buddy = Ana`, "or ask a question"). Until PR 4 ships,
   this state shows saved chips and hints only.
3. **Typing.** The list filters live (debounced). Field and name
   completions come from the existing `QueryTextField`. A jump-to-dive
   dropdown lists the top 8 matches over ALL dives for the typed query
   alone (panel axes ignored); tapping one opens that dive. When the model
   is available, an Ask row reads `Ask: <text>`. When any panel axis is
   active, a Within filters / All dives toggle is shown.
4. **All dives.** Panel axes are suspended: their chips dim and stay in
   place; the typed query alone filters the list. Switching back restores
   them. The chip row carries **Save**, **Open in Insights** and
   **Clear all**.
5. **Invalid text.** The localized parse error appears on one line under
   the field; the list keeps its last valid result.
6. **After Ask.** The sentence is replaced by the printed query and chips.
   Parts the compiler could not place show in a notice ("Couldn't use:
   ...") with **Undo**, which restores the sentence and the previous
   query. A sentence about another subject (sites, equipment, buddies,
   species, trips, centers) opens that list already filtered, through the
   existing handoff.

Rules:

- **Open state is derived:** open if the diver opened it, or if the filter
  has any axis or a query. A filter written elsewhere (Connections, an
  Insights drill-down) therefore arrives with the bar open.
- **Back/Esc with an active search** snapshots the state, resets to
  `const DiveFilterState()`, collapses, and shows a snackbar whose Undo
  writes the snapshot back.
- **Keyboard:** Cmd/Ctrl+F opens and focuses the bar (navigating to
  `/dives` first when elsewhere). Cmd/Ctrl+Enter inside the bar runs Ask.
  Cmd/Ctrl+E is removed.
- **Phrases:** `"blue hole"` matches that exact phrase; `blue hole` matches
  dives containing both words anywhere in the searched columns.
- The bar lives in the phone app bar, the desktop master pane's compact
  app bar, and the table-mode app bar, all built by one shared actions
  builder.

### 4.2 The Refine panel (Dives, Insights, Connections)

Replaces both the Filter sheet and the Advanced Search page.

Layout, top to bottom: title with "Clear all"; saved-search chips; then
collapsible groups, each showing a one-line summary of what is set; then
**Cancel** and **Show N dives** (live count). Nothing is applied until that
button is pressed, as the sheet behaves today.

Groups, holding the union of both surfaces' axes:

| Group | Axes |
|---|---|
| Rules | the query editor (Text + Builder tabs, Save as...) editing the same `query` as the bar's field |
| Date | date range with presets, weekdays |
| Location | dive site (one or several), trip, dive center |
| Conditions | depth, duration, deco, water temperature, visibility, water type |
| Gas and equipment | dive type, gas mix / O2, equipment, gear attributes, suit thickness, dive computer |
| People and life | buddy name, no buddy, species |
| Organization | tags, minimum rating, favorites only, excluded from statistics |
| Custom fields | key and value |

Trip, dive center, deco, equipment and custom fields are Advanced-only
today; water temperature, visibility, water type, gear attributes, suit
thickness, dive computer, species and excluded-from-statistics are
sheet-only today. Insights and Connections therefore gain axes.

Form factor: modal bottom sheet below the master-detail breakpoint; a
right-side panel at and above it, so the list stays visible.

Tapping a saved chip loads the whole saved search (section 5.4) and closes
the panel.

## 5. State and architecture

### 5.1 One source of truth

`diveFilterProvider` (`DiveFilterState`) stays the only search state for
the Dives screen. `DiveFilterState.toQuery()` stays the only evaluator, so
the list, count, map, table and Insights all follow every change below.

### 5.2 Bar text and `query`

The bar parses its own text (debounced) and writes `query` only on a
successful parse. When `query` changes from outside (chip removed, panel
applied, saved search loaded, Ask answer), the bar re-prints its text,
unless the new tree equals the parse of the current text (so the cursor
never jumps while typing). This mirrors how the query editor already keeps
its Text and Builder tabs in sync; the bar reuses `QueryTextField`.

### 5.3 Scope toggle: `axesSuspended`

New field `bool axesSuspended` on `DiveFilterState` (default false):

- `toQuery()` returns only `query` when it is true.
- Included in value equality and `copyWith`, and named in `toQuery` so
  `dive_filter_query_census_test` stays green.
- `activeDiveFilterChips` renders suspended axis chips dimmed and
  non-removable while suspended.
- `activeAxisCount` is unchanged (the axes are still set), so the bar stays
  open.
- Only the Dives bar can set it. "Open in Insights" writes the EFFECTIVE
  search (`DiveFilterState(query: query)` while suspended, the state as-is
  otherwise), because Insights has no toggle that could show or undo a
  suspension.

### 5.4 Saving and loading the whole search

Save writes `toQuery()` of the current state through the existing
saved-query path (`saveQueryFromEditor`, versioned AST JSON, refs stored by
id and relabelled from the `NameIndex` on load). Loading sets
`DiveFilterState(query: loaded)`: axes clear and the whole search appears
as text and chips. This replaces today's chip behaviour of
`copyWith(query: ...)`, which kept unrelated axes.

A census test asserts that every `DiveFilterState` axis, lowered by
`toQuery()`, prints with `QueryPrinter`, re-parses, and reloads to an equal
tree. If an axis (for example `diveIds` or equipment attribute conditions)
cannot round-trip, that is fixed in PR 4 before Save ships; it is never
dropped silently.

### 5.5 Recent searches

The recent-queries repository (device-local cache database, 20 rows) gains
a kind: typed or asked. This is a cache-database change, not a rung on the
synced schema. Typed searches are recorded when the diver commits them
(Enter, or leaving the bar with a non-empty valid query).

### 5.6 Units

| Unit | Purpose | Depends on |
|---|---|---|
| `DiveSearchBar` | field, back/clear, tune button, error line, Ask row | `diveFilterProvider`, query parser, `QueryTextField` |
| `DiveJumpDropdown` | top 8 matches over all dives for the parsed text alone | existing list query with `DiveFilterState(query: q)`, limit 8 |
| `DiveSearchScopeToggle` | Within filters / All dives | `axesSuspended` |
| `DiveListAppBarActions` | ONE action builder for phone, desktop and table layouts | replaces three copies in `dive_list_page.dart` and `dive_list_content.dart` |
| `RefinePanel` + one widget per group | section 4.2 | a `filterProvider` parameter (Dives, Insights, Connections) |
| `AskController` | runs the existing NL engine and compiler; dives replace only `query`; other subjects use the existing per-subject handoff | `lib/features/explore/domain`, `lib/features/explore/data` (kept) |
| `SearchSuggestions` | saved, recent, hints | saved queries, recent-queries repository |

Each group widget is its own file; no file in this program exceeds 800
lines (the sheet it replaces is 1651, the page 1205).

### 5.7 Engine change: quoted phrase

In `QueryCompiler._text`, a `TextNode` with more than one word compiles to
one `LIKE '%<words joined by one space>%'` per search column instead of one
AND-ed clause per word. Parser, printer and JSON are unchanged: a
multi-word `TextNode` is only ever produced by quoted text or a rule-builder
text row, and bare words each produce a one-word node. Consequence:
existing saved queries with quoted multi-word text, and builder text rows
with several words, become phrase matches (stricter).

### 5.8 Deleted, redirected, kept

Deleted: `DiveSearchDelegate`; `DiveFilterSheet`; `DiveSearchPage`;
`ExplorePage` with `ExploreCharts`, `ExploreResultsList`,
`ExploreSubjectResultsList`, `ExploreHandoffBar` (its per-subject handoff
logic moves to a plain function used by `AskController`); the Explore
app-bar entries; Cmd/Ctrl+E and its `shortcut_display` entry; the
hard-coded "Search dives..." string.

Redirected: `/dives/search` and `/dives/explore` go to `/dives` with the
bar open.

Kept: `diveSearchProvider` and `searchDiveSummaries` (the pre-dive link
picker uses them); the Saved Queries management page in Settings; the
Explore domain and data layers (engine, compiler, lowering, gate
providers, name index).

## 6. Error handling

| Situation | Behaviour |
|---|---|
| Text does not parse | localized `QueryError` on one line under the field; list keeps its last valid result; `query` untouched |
| Compile error | same line; saved-search loads flag unresolved refs as today |
| Ask fails (`NlError`: refusal, context exceeded, guardrail, not ready, unsupported locale, quota, schema mismatch, decoding, unknown) | existing localized message in the Ask row; typed text untouched |
| Model downloadable / downloading | Ask row offers the download / shows progress, reusing the existing re-probe logic |
| Model unavailable or platform unsupported | no Ask row, no Cmd/Ctrl+Enter |
| Jump-dropdown query fails | dropdown hides, error logged; list unaffected |
| Panel live count fails | button reads "Show dives" without a number |

## 7. Testing

TDD in every task (test first, watch it fail, then implement).

- **Compiler:** quoted phrase matches only the phrase; bare words match
  across columns; a multi-word builder text row is a phrase.
- **State:** `axesSuspended` honoured by `toQuery()`, equality, `copyWith`;
  census test updated.
- **Bar:** live filtering (debounce pumped explicitly); error line and
  last-result retention; external change re-prints text without moving the
  cursor; open-while-active; Back/Esc clear with Undo; scope toggle; jump
  dropdown ignores panel axes; Open in Insights writes
  `insightsFilterProvider`.
- **No axis lost (the guard for the maintainer's constraint):** a test
  enumerates every diver-editable `DiveFilterState` axis and asserts the
  Refine panel edits each one. Group widgets get ported tests from the
  existing sheet and page suites.
- **Ask:** fake `NlEngine`; dive answer replaces only `query`; Undo
  restores sentence and previous query; non-dive answer navigates to the
  filtered list; hidden when unavailable; download state.
- **Save:** every axis prints, re-parses, reloads to an equal `toQuery()`.
- **Shortcuts:** Cmd/Ctrl+F, Cmd/Ctrl+Enter, Cmd/Ctrl+E removed,
  `shortcut_display_test`.
- **Router:** both redirects.
- **Insights and Connections:** panel bound to their providers; existing
  `insights_filter_action_test` and Connections filter-tab tests pass.
- `test/architecture/` after every PR and after every main merge.

## 8. Delivery

One GitHub issue for the program. Four PRs, each shippable, in order:

| PR | Contents | Retires | Link |
|---|---|---|---|
| 1. Search bar | bar with live query; quoted phrase; jump dropdown; scope toggle (`axesSuspended`); shared `DiveListAppBarActions`; Cmd/Ctrl+F; Open in Insights; clear with Undo. The tune button opens the EXISTING Filter sheet for now. | Search overlay, Filter icon | `Refs` |
| 2. Refine panel | grouped panel, union of axes, side panel on wide layouts, used by Dives, Insights, Connections; the no-axis-lost guard | Filter sheet, Advanced Search page, `/dives/search`, overflow item | `Refs` |
| 3. Ask | Ask row, download state, couldn't-place notice with Undo, Cmd/Ctrl+Enter, non-dive handoff | Explore page and icon, Cmd/Ctrl+E, `/dives/explore` | `Refs` |
| 4. Saving and suggestions | whole-search save with round-trip census, recent searches (typed and asked), empty-bar suggestions | none | `Closes` |

Every PR touches `presentation/`, so each carries before and after
screenshots at phone and desktop widths (light and dark where colours
change).

Interim states are acceptable: between PR 1 and PR 3 the sparkle icon and
the Advanced Search overflow item still exist beside the new bar.

## 9. Capability inventory (the no-loss audit)

| # | Capability today | Where today | New home |
|---|---|---|---|
| 1 | Answer charts (dives over time, trends, top-N counts) | Explore | **Dropped by the maintainer**; Insights (item 3) covers charts for a search |
| 2 | Non-dive answers ranked by matching-dive count, with a per-row chart | Explore | **Dropped by the maintainer**; non-dive answers still open their list already filtered |
| 3 | Open the answer in Insights | Explore | Chip row "Open in Insights" (PR 1) |
| 4 | Exact-phrase text search | Search overlay | Quotes = phrase (PR 1) |
| 5 | Find any dive while a filter is on | Search overlay | Scope toggle + jump dropdown (PR 1) |
| 6 | Recent sentences, model download prompt, couldn't-place feedback | Explore | Suggestions (PR 4), Ask row (PR 3), notice with Undo (PR 3) |
| 7 | Every structured axis of both forms | Sheet, Advanced page | Refine panel union + guard test (PR 2) |
| 8 | Saved queries, typed syntax, rule builder, Settings management | Sheet, Advanced page, Settings | Bar field, Rules group, saved chips, Manage link (PRs 1, 2, 4) |
| 9 | Jump straight to one dive from a search | Search overlay | Jump dropdown (PR 1); tapping a filtered row also opens it |
| 10 | Field typeahead and name completions | Query editor | Reused in the bar via `QueryTextField` (PR 1) |
| 11 | Non-dive natural-language subjects reach their list | Explore | `AskController` handoff (PR 3) |
| 12 | Keyboard: search shortcut | Cmd/Ctrl+F, Cmd/Ctrl+E | Cmd/Ctrl+F opens the bar; Cmd/Ctrl+Enter asks (PR 1, PR 3) |

## 10. Out of scope

- A search bar on Insights, Connections or any non-dive list.
- Charts for typed searches.
- Migrating the pre-dive link picker off `searchDiveSummaries`.
- Changing the query language beyond the quoted-phrase rule.

## 11. Amendments recorded while planning PR 1

1. **The field is a second row, not a title replacement** (maintainer's
   choice, 2026-10-02). Replacing the title left room for one icon, and
   since the bar stays open while a filter is active, Select (bulk actions
   on a filtered list), Sort and the overflow menu would have been hidden.
   The app bar keeps every icon; the search row sits directly under it, in
   the list body, above the chips. One `DiveSearchHeader` therefore serves
   the phone, desktop master pane and table layouts, and survives the
   loading and empty states (it sits outside them).
2. **Closing the bar** is the close button at the end of the search row,
   or Esc in the field (there is no back arrow in a second row). With an
   active search it clears everything with an Undo snackbar, as decided.
3. **The shared app-bar builder covers the search controls only.** The
   three overflow menus differ on purpose (table mode has Fetch
   conditions, the list modes have trip grouping), so each layout keeps its
   own overflow; all three use one `DiveSearchAction` for the search icon.
4. **The jump-to-dive list is inline under the field, at most 5 rows**,
   shown only while the field has focus and holds a valid query. An
   overlay would race the field's tap-outside unfocus on desktop.
5. **Applying the (legacy) Filter sheet clears `axesSuspended`,** so a
   filter added while "All dives" is selected takes effect instead of
   arriving dimmed. PR 2's Refine panel keeps the rule.
6. **A hyphen inside a word is part of the word** (maintainer's choice,
   2026-10-02, from the PR 1 code review). The old Search overlay matched
   any text literally; the query grammar read `Abu-Nuhas` as `Abu` AND NOT
   `Nuhas`. Now only a hyphen that starts a term negates it (`-wreck`), and
   a number keeps a trailing `%` (`100%` is one text term; `cns > 40%` is
   accepted on a percent field and refused elsewhere). Commas, colons and
   brackets in plain text still need quotes.
