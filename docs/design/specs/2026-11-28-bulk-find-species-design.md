# Find species across many dives (issue #5127)

## Problem

Find species (#4727) runs on one dive, started from the dive's Marine life
card. A diver with an existing logbook (the model is downloaded once, after
years of photos) or a trip with dozens of dives has to open every dive and
start the run by hand.

## Scope

Issue #5127 is delivered in two parts.

**Part 1 (this change):**

1. Start one run over many dives from three places:
   - the dive list selection (new bulk action),
   - a trip (trip details overflow menu: every dive of the trip, side trips
     included),
   - the whole logbook (dive list overflow menu and the Species ID settings
     page).
2. Before it starts, one confirmation sums up what the run will do: how many
   dives, how many photos and videos it will look at, and how many of them are
   not on this device. When some are not, the diver chooses between
   downloading them (today's behaviour) and looking only at what is on this
   device.
3. One progress line for the whole run (dives and items done, pause reason,
   Resume, Cancel), on Home and on the Species ID settings page. Each dive's
   own card shows its part.
4. One History entry for the whole run. A cancelled run keeps what it tagged
   so far in that entry; starting again makes a new entry.
5. A notice when the run ends, wherever the diver is.

**Part 2 (follow-up PR, same issue):**

- Resume an interrupted run after the app restarts.
- "Download for species ID only": fetch a missing original, analyse it,
  delete it again, keep only results and crops.
- Undo part of a run's History entry, chosen by dive.
- A Home notice when new photos or videos arrive that the installed model
  has not looked at (after a manifest poll or a dive computer import), with
  Find species for exactly those dives. Never starts a run by itself.

## Current design (what is reused)

- `DiveSpeciesRun` (`lib/features/species_id/data/services/dive_species_run.dart`)
  is a session-scoped queue: one dive at a time, the rest wait. It pauses in
  the background and when the device is too warm, stops on cancel, on another
  logbook or on a deleted dive, and at the end of each dive calls
  `applyAll(looked, generation)`, which `AutoApplier.applyAllInScope` files as
  one automatic History entry (`ChangeLogLabels.marineLifeId`).
- `ChangeLogScope` opens an operation row and points the global
  `change_log_context` at it while its body runs: whatever is written in that
  window, by the job or by the diver, is filed under it. Applying therefore
  stays a short window per dive.
- The settler (`change_log_settler.dart`) files events by their
  `operation_id` and loads an existing operation by id, so later events can
  join an operation that already holds earlier ones.
- `notOnDeviceCount` (`run_media_resolvers.dart`) and
  `MediaIdentificationService.upToDate` (readiness) answer "what would a run
  download" and "what would it skip" for any list of media.

## Design

### Batch coordinator

`SpeciesBatchRun` (new, `StateNotifier<SpeciesBatchRunState?>`, session
scoped like `DiveSpeciesRun`) owns the list of dives still to do and hands
**one dive at a time** to `DiveSpeciesRun.start`. It never queues the whole
logbook in `DiveSpeciesRun`: that state is one map, copied on every update,
which 15,000 queued dives would make quadratic.

- `start(plan)`: refused while a batch is active (the entry points then say
  so and point at the progress line). Keeps the pending dive ids, the
  planned item count and the diver's download choice.
- For each dive: `DiveSpeciesRun.start(diveId, onDeviceOnly:, operationId:)`,
  awaited; then the dive's final counts are added to the batch totals and the
  dive's entry is dropped from `DiveSpeciesRun`'s map (`forget`), so the map
  stays small.
- A dive the diver started from its card meanwhile runs in its turn, ahead of
  the batch's next dive (the batch only ever has one dive queued). When the
  batch reaches a dive whose card run is still queued or running, it waits
  for that run instead of starting another.
- `cancel()`: clears the pending list and cancels the dive in progress.
- `resume()`: forwards to the dive in progress.
- Another logbook opened: the dive in progress stops (existing rule), the
  batch drops its pending list and ends as cancelled.

Pending dives' cards show "Waiting" by asking the batch
(`isPending(diveId)`), not through `DiveSpeciesRun`'s map.

### One History entry, applied per dive

Applying stays per dive, right after the dive's run, as today. What changes
is where it is filed:

- `ChangeLogScope.automatic` gains an optional `operationId`. Given one, the
  scope reopens that operation (inserted if missing, `closed = 0` if it
  exists) instead of creating a new one, and closes it again at the end.
- The batch picks one operation id at its start and passes it to every
  dive's apply (`DiveSpeciesRun` hands it to `applyAll`, `AutoApplier`
  to the scope). Result: one entry for the whole run, while each scope window
  stays as short as one dive's apply, so a save the diver makes during the
  run is filed under the run only in that same short window, as today.
- The settler deletes a closed operation that has no events. A dive that
  tags nothing therefore may leave no row; the next dive's scope inserts it
  again under the same id.
- If the diver reverts the entry while the batch still runs, the batch
  switches to a new operation id for the remaining dives, so new tags never
  join an entry that shows as reverted.
- An app kill loses at most the dive in progress: everything before it is
  already applied. Its media are up to date afterwards; a later run picks it
  up as "apply only" (below).

### Run engine changes

`DiveSpeciesRun.start(diveId, {fresh, onDeviceOnly, operationId})`:

- `onDeviceOnly`: before each item, `onDevice(item)` (injected; the same
  rule as `notOnDeviceCount`: a library item whose original is on this
  device, or a file that exists) decides; an item not on this device is left
  out of the run and its total, and counted as `notOnDevice` in the
  summary. Checked at run time, so media added after planning, or
  originals the system moved to the cloud meanwhile, follow the diver's
  choice too.
- `operationId`: passed through to `applyAll`.
- `forget(diveId)`: drops a finished dive's state.

### Planning (counting before the confirmation)

`SpeciesBatchPlanner` turns dive ids into a plan without running the models,
in chunks of 250 dives so memory stays flat and the dialog fills in as it
goes:

1. All photos and videos of the chunk's dives in one query
   (`MediaRepository.getMediaForDives`).
2. The chunk's dive places in one query (`DivePlaceRepository.placesOf`).
3. `upToDate` over the chunk's items. `upToDate` first decides with
   `cropsPresent: true` and checks the crops on disk only when that already
   says "nothing to do", which skips the file checks for every item that
   needs work anyway (the dive card benefits too).
4. A dive is planned when an item is not up to date, or, when auto-apply can
   tag (`AutoApplier.isOn`), when it holds open suggestions
   (`MediaIdentificationRepository.mediaWithOpenSuggestions`), so a dive the
   card would offer Find for is never called "already checked".
5. Items to look at that are not on this device are counted with at most 8
   photo library lookups at a time.

The plan keeps per dive: its id, its photo and video count (progress) and
how many of them it will look at (the dialog). The whole logbook is every
dive of the current diver with a photo or video
(`MediaRepository.getDiveIdsWithMedia(diverId)`).

### Confirmation

- Opens at once with a spinner and a running count; Cancel stops counting.
- Body: "40 dives, 900 photos and videos to look at."
- Nothing to do: "All photos and videos of these dives are already
  checked." with only OK.
- Some not on this device: two choices, "Download them (120)" (default) and
  "Only what is on this device".
- More than 500 items: "This can take a while. Keep the app open; the run
  pauses while the app is in the background."

### Entry points

- Dive list selection: `findSpeciesBulkAction(...)` next to
  `fetchConditionsBulkAction` in `_bulkActions`, shown only when
  `marineLifeIdEnabled` and a pack is installed.
- Dive list overflow menu: "Find species in all dives", same gate.
- Trip details overflow menu: "Find species", dives from
  `diveIdsForTripProvider`, same gate.
- Species ID settings page: "Find species in all dives" row below the
  auto-apply section, when a pack is installed.

### Progress and end notice

- `SpeciesBatchProgressCard`: linear progress, "Dive 3 of 40 · 120 of 900",
  the pause reason (too warm / in the background), Resume, Cancel. Items
  done count every photo and video of the finished dives plus the current
  dive's progress, against all photos and videos of the planned dives, so
  the bar never runs past its end. Shown on Home and on the Species ID
  settings page while a batch is active.
- End notice: a snack bar through the app's root `ScaffoldMessenger`
  (`app.dart`, like the background import notice), with the summary and a
  Review action to Species to review when there is something to review.

## Edge cases

- A dive deleted during the batch: that dive stops and applies nothing
  (existing rule), the rest go on.
- Media unreadable or failing to download: counted as unreadable, as today.
- 15,000 dives: planning works in chunks; the run holds one dive in
  `DiveSpeciesRun` at a time and the batch holds only ids and counts.
- One selected dive: behaves like the card's own run, with the batch
  confirmation.
- No pack installed, or no engine here (web): no entry point is shown.

## Testing

- `ChangeLogScope`: a given operation id is reopened, not duplicated; a
  missing one is inserted; a save outside the window is not filed under it.
- `DiveSpeciesRun`: `onDeviceOnly` leaves items out of total and run and
  counts them; `operationId` reaches `applyAll`; `forget` drops the state.
- `SpeciesBatchRun`: dives run one at a time in order; one operation id for
  all; cancel stops after the current dive; a reverted entry rotates the id;
  logbook change ends the batch; a second start is refused.
- `SpeciesBatchPlanner`: up-to-date dives are dropped unless they can still
  be applied; counts and not-on-device count are right; chunking.
- Repositories: `getMediaForDives`, `getDiveIdsWithMedia` (diver scoped),
  `placesOf`, `mediaWithOpenSuggestions`.
- Widgets: bulk action visibility, confirmation states, progress card.
