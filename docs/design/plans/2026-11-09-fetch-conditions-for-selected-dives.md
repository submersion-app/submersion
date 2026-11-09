# Fetch conditions for selected dives (issue #4329)

Design approved in chat on 2026-11-09. No separate spec: the change is small
and reuses the existing logbook-wide fetch (`71aeb6f47e2`).

## Behaviour

- A "Fetch Conditions" action joins the dive list's selection bar, after
  Re-parse. It is enabled with at least one dive checked, on every platform.
- It counts the checked dives that have an empty weather column and a
  location, and confirms: "4 of 6 selected dives are missing conditions. Only
  empty fields are filled, so nothing you have already entered will change."
  When every checked dive qualifies, the existing logbook wording is used.
- Checked dives that have a gap but no location add a line: "2 dives have no
  site location or GPS fix and will be skipped."
- The run, progress dialog, cache, pacing and summary are the existing ones.
  It never overwrites: `fillDiveConditions` leaves populated columns out of
  the UPDATE.
- Nothing to do: a snackbar says none of the selected dives are missing
  conditions, or that the ones missing them have no location.
- Selection mode follows the `BulkActionOutcome` rule: a run that happened
  ends the mode; backing out, or nothing to do, keeps it; a failure keeps it.
- The bulk edit form is unchanged.

## Location fallback (applies to the logbook-wide action too)

A dive's location is, in order: its site's coordinates, its own entry GPS
fix, its own exit GPS fix. Each is used only as a complete pair. A dive with
none is not a candidate. The single-dive Fetch Weather button on the edit page
is unchanged: it follows the site picked in the form.

## Steps

1. Repository (`dive_repository_impl.dart`): the candidate condition joins
   sites with a LEFT OUTER JOIN, accepts the GPS fallback, and takes an
   optional `diveIds` restriction, bound in chunks of `kSeriesIdChunkSize`.
   Add `countDivesMissingConditionsWithoutLocation`. Tests first in
   `dive_repository_conditions_test.dart`.
2. `BulkConditionsService`: `countCandidates`, `run` and a new
   `countWithoutLocation` take `diveIds`. Tests first.
3. `showFetchAllConditionsFlow` takes `diveIds`, uses the selection wording,
   and returns a `BulkActionOutcome`. Tests first.
4. `fetchConditionsBulkAction` in the weather feature, wired into
   `DiveListContent._bulkActions`. Widget test that it is offered.
5. Strings in all 11 ARB files, then `flutter gen-l10n` last.
