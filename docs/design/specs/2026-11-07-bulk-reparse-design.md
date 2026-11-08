# Bulk re-parse of dives from raw data (issue #224)

## Intent

Submersion keeps the raw bytes each dive computer download produced
(`dive_data_sources.raw_data`), so a dive can be re-parsed later. Re-parsing
is worth doing when the parser improves: a libdivecomputer update, or a fix in
how Submersion maps parsed data (the Mares event-code table fix was one). When
that happens, every dive parsed before the change is stale, and that is most of
the log, across every computer the diver has used.

Today a diver can re-parse one dive (dive page overflow menu) or every dive
from one computer ("Re-parse all dives" on the computer's page, which shows a
snackbar and offers no progress, cancel or failure detail). Neither fits
"the parser changed, refresh everything". This feature adds two bulk entry
points, one shared engine behind them, and a progress and results experience
that all batch re-parses use.

## Goals

1. **Selected dives:** a "Re-parse" bulk action in the dive list's selection
   mode.
2. **Whole log:** a "Re-parse dives" tool under Settings > Data > Data tools
   that re-parses every dive with stored raw data.
3. **One engine:** selected, whole-log and per-computer re-parse run the same
   service loop, so they preserve the same edits, treat combined dives the same
   way and refresh the same derived data.
4. **Blocking progress with cancel:** while a batch runs, a modal dialog shows a
   progress bar and "Re-parsing N of M dives"; the app cannot be used, but the
   run can be cancelled.
5. **Results:** counts (succeeded, failed, not processed after cancel), plus a
   list of failed dives with their error, each tappable to open that dive.

## Non-goals

- No "only dives parsed by an older parser version" filter. Submersion-side
  mapping fixes do not change the stored `libdivecomputer_version`, so a
  version filter would miss exactly the fixes that prompt a re-parse. The
  whole-log tool re-parses everything with raw data.
- No background or resumable runs. Leaving the app mid-run is not supported;
  dives already re-parsed keep their new data.
- No change to what a single re-parse writes (`applyParsedUpdate` is unchanged).
- File-imported dives (re-import from the stored original file) are not part
  of this; only raw dive computer bytes.

## Anti-goals

- A cancelled run, or a parse failure, must never leave a dive half
  re-parsed (see "Parse first, then apply" for the one database-fault case).
- A batch must not drop edits the single-dive re-parse preserves (notes, site,
  buddies, diver-edited tanks, and so on).
- A whole-log run must not record hundreds of change-log entries; it is one
  "Reparsed dives" bulk entry, as the per-computer run is today.

## Design

### Engine (`ReparseService`)

A new batch method replaces `_reparseAllForComputerInner`'s loop and serves all
three callers. It takes a list of dive ids, a `parseFn`, an optional progress
callback and a cancel check, and returns a result:

- **Unit of work is the dive**, not the source row. A dive with several stored
  sources (multi-computer) is one step of progress. Each of its sources is
  parsed and applied in turn, exactly as `reparseDive` does now.
- **Per dive outcome:** succeeded (every source with raw data applied),
  failed (at least one source threw; carries the first error message), or
  skipped (no source with raw data and complete descriptors). A source missing
  vendor, product or model counts as a failure with a clear message, matching
  the current per-computer behaviour rather than the single-dive one, which
  silently skips it.
- **Profiles preserved:** the count of dives whose profile was left alone
  because the dive was combined (`profilePreserved`), counted as succeeded.
- **Parse first, then apply.** For each dive the engine first parses every
  source with raw data and runs the descriptor and empty-parse checks. Only
  when all of them pass does it apply them, one `applyParsedUpdate` per source
  (each its own `db.transaction`, unchanged). A parse failure on any source
  therefore leaves the whole dive untouched. An apply-time exception on a
  later source can still leave earlier sources of that dive committed; that
  is a database-level fault, rare, and the dive is reported as failed. Full
  per-dive atomicity would mean nesting `applyParsedUpdate`'s after-commit
  steps (sync notification, transmitter registration) inside an outer
  transaction, which changes the single-dive path, so it is out of scope.
- **Cancel** is checked before each dive, never between a dive's sources, so
  cancel never splits a dive. Dives not reached are reported as not processed.
- **Change log:** the whole run is wrapped in one
  `ChangeLogScope.bulk(label: ChangeLogLabels.reparse)`, as today.
- **Derived data:** after the loop, schedule the sensor-summary and
  derived-metrics refresh for every dive that changed (the single-dive path
  does this; the per-computer path currently does not, and gains it).
- **Candidate queries:** the whole-log tool and the per-computer button
  resolve their dive ids with queries over `dive_data_sources` with non-null
  `raw_data` (whole log: scoped to the active diver's dives; per computer:
  that computer's sources). The selection action passes the checked ids, and
  the engine skips the ones without raw data.
- **Optional computer filter (decided with the diver).** The engine accepts an
  optional computer id. When set, each dive re-parses only the sources from
  that computer and leaves other computers' sources on the same dive alone.
  The per-computer button always passes it, so on a dive combined from
  computers A and B, A's button re-parses only A's data, as it does today.
  The selection action and the whole-log tool never pass it and re-parse
  every source of each dive.

`reparseDive` (single dive) keeps its current return shape for the dive page;
it may delegate to the shared per-dive step internally.

### Progress and results dialog (shared widget)

A notifier owns one run at a time (pattern:
`SiteLocationBackfillNotifier`), with states idle, running (done, total) and
finished (result). A modal, non-dismissible dialog (`barrierDismissible: false`,
back gesture blocked) watches it:

- **Running:** title "Re-parsing dives", a determinate `LinearProgressIndicator`,
  "Re-parsing 137 of 412 dives", and a Cancel button. After Cancel is pressed
  it reads "Cancelling..." and is disabled until the current dive finishes.
- **Finished:** the counts, for example "Re-parsed 405 of 412 dives. 4 failed,
  3 not processed." When dives were combined, a line says how many kept their
  combined profile. When any failed, a scrollable list follows: one row per
  failed dive with dive number, date and site name (as the dive list formats
  them, respecting the diver's settings), and the error text. Tapping a row
  closes the dialog and opens that dive's detail page. A Done button closes it.

### Entry points

1. **Dive list selection bar:** a new `BulkAction` "Re-parse" (overflow menu,
   after the existing actions). Hidden when the device cannot parse
   (`deviceCapabilitiesProvider.diveComputerDownload` is false, for example
   the web build). On invoke: count which checked dives have raw data, confirm
   ("Re-parse N dives? M selected dives have no raw data and will be skipped.
   Your notes, sites, buddies and other edits are preserved."), then run.
   When none of the checked dives have raw data, show a snackbar saying so
   instead of the dialog.
2. **Settings > Data > Data tools > "Re-parse dives":** a new row (same
   capability gating) opening a new page. The page shows how many dives have
   raw data and how many do not, broken down per dive computer, and a
   "Re-parse all" button that confirms, then runs. When there are none, the
   page says so and the button is disabled.
3. **Dive computer page "Re-parse all dives":** keeps its button and its
   confirmation (which still counts that computer's stored data), but runs
   through the shared engine, filtered to that computer, and the shared
   dialog instead of the snackbar.

### Strings

New strings go in `app_en.arb` and are translated into every locale file, as
the project does for all user-visible text. Existing per-computer strings are
reused where they still fit.

## Constraints

- `reparse_service.dart` is already about 1,500 lines. The batch engine goes in
  its own file (for example `reparse_batch_service.dart` or a part file), not
  into the existing file.
- Re-parse persistence must keep mirroring the download path (see
  `applyParsedUpdate`); this feature does not change that path.
- Tests use the injected `parseFn`, never the native bridge.
- `test/architecture/` guards must pass for new files under `lib/`.

## Left to the builder

- Exact file names, provider names and class names.
- Whether the per-computer breakdown on the Data tools page is a list of rows
  or a compact table.
- Exact wording of strings, within the meaning above.
- Icon choice for the bulk action and Data tools row (for example
  `Icons.refresh` or `Icons.restart_alt`).

## Calls made by the designer (not discussed with the diver)

- The whole-log tool is scoped to the active diver's dives, matching how the
  dive list and every other Data tool scope their data.
- A source with missing descriptors counts as a failure, not a silent skip.
- Each dive's sources are all parsed before any is applied, so a parse
  failure leaves the dive untouched; full per-dive atomicity is out of scope.
- The per-computer button moves to the new dialog (raised in the
  conversation, not objected to).

## Decided with the diver

- Whole-log re-parse lives under Settings > Data > Data tools.
- While a batch runs the app is blocked by a progress dialog that can be
  cancelled.
- The results show both the counts and a tappable list of failed dives.
- The per-computer button re-parses only that computer's sources on a
  combined dive.
