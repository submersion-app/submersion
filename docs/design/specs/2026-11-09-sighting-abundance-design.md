# Sighting abundance: seen, REEF groups, or an exact number

Issue: #4337 ("Default number of species").

## Why

When a diver adds a species to a dive, the add dialog starts at a count of 1.
The dive page hides the count unless it is 2 or more, so the dialog and the
dive disagree, and a diver who never touched the stepper ends up recording
"exactly one animal" when they meant "I saw this". Insights and the species
pages then add those counts up, so "I saw it" quietly counts as one animal.

The two people who commented on the issue both said exact numbers stop being
meaningful past four or five animals. The maintainer wants rough sizes and
still wants a way to record an exact number (one whale shark matters).

## What a sighting records about "how many"

Every sighting has exactly one of these six values:

| Value      | Meaning                          | Badge on the dive page |
| ---------- | -------------------------------- | ---------------------- |
| Seen       | Seen, no number given            | none                   |
| Single     | REEF group: 1                    | `Single`               |
| Few        | REEF group: 2 to 10              | `Few`                  |
| Many       | REEF group: 11 to 100            | `Many`                 |
| Abundant   | REEF group: more than 100        | `Abundant`             |
| Exact      | An exact number, 1 or more       | `x<n>` (so `x1` too)   |

The four groups and their ranges are REEF's (the Reef Environmental Education
Foundation volunteer fish survey: Single, Few, Many, Abundant). The ranges
are fixed, so an exact number always falls inside one group.

## Screens

Approved mockup (in chat, 2026-11-09):

1. **Add a sighting** (the dialog after picking a species, in
   `species_picker_sheet.dart`; the same dialog serves the media species
   sheet). Under the species name, a "How many" label and one row of choice
   chips: Seen, Single, Few, Many, Abundant, Exact. **Seen is selected by
   default.** A muted helper line under the chips gives the ranges ("Few 2 to
   10, Many 11 to 100, Abundant 100+"). Picking Exact shows the existing
   +/- stepper below the chips, starting at 1, minimum 1. Notes field and
   Cancel / Add buttons as today.
2. **Edit a sighting** (`edit_sighting_sheet.dart`): the same chip row and
   stepper replace the current stepper, starting from the sighting's stored
   value.
3. **Dive page marine life list** (`dive_sighting_row.dart`) and the dive
   edit page's sightings list: the badge column shows the table above. Seen
   shows nothing, which matches how a count of 1 looks today.
4. **Detailed PDF** (`pdf_template_detailed.dart`): the same labels as the
   dive page (`Name x3`, `Name (Few)` style is the builder's call, as long as
   Seen shows the name alone).

Chip labels and the helper line are new localized strings. Chips wrap on a
narrow phone.

## Existing data

- **No stored value is rewritten.** Every sighting that exists today keeps
  its count and is read as Exact with that number, including a count of 1
  (the maintainer chose this explicitly: some of those 1s are deliberate).
- Only sightings created after this change can be Seen or a group.

## Totals

A total of animals stops making sense once "Many" and `x3` sit side by side,
so every aggregate that sums `sightings.count` today counts dives instead:

- Insights marine life page: species ranking orders by the number of dives
  the species was seen on (`COUNT(DISTINCT dive_id)`), not `SUM(count)`.
- Species insights detail: "Total sightings" becomes the number of dives the
  species was seen on; its top-sites ranking counts dives per site.
- `seen_species_repository.dart` `total_sightings`: same change.
- Any other `SUM(s.count)` the builder finds gets the same treatment.

Counting dives makes "Total sightings" equal to the "Dives" figure that
already sits beside it, so (maintainer's decision) the duplicate goes:

- The species detail page drops its "Total sightings" card and keeps "Dives"
  and "Sites".
- Seen-species rows (`seen_species_tile.dart`) drop "N sightings" and keep
  "N dives" and "last seen".
- The seen-species "Most sightings" sort (`seen_species_filter.dart`) goes,
  since it would equal sorting by dives. A saved sort that pointed at it
  falls back to the by-dives sort.
- Strings that only those removed parts used are deleted.

### Trip story day card

`trip_story_day_card.dart` sums a species' counts across the day's dives
today ("Turtle x7"). It shows the day's largest abundance instead, using the
merge rule below: every dive Exact gives the summed `x<n>` as today; any
group gives the largest group (an Exact number placed in its REEF group);
only Seen gives the name alone.

## Import, export, sync, agent access

- **Imports:** a source that gives a number (UDDF `count`, MacDive, and so
  on) imports as Exact with that number, 1 included, matching the existing
  data rule. A source that gives no number imports as Seen: the UDDF importer
  when the `count` attribute is absent, and the Diving Log mapper, which has
  no count and hard-codes 1 today. *(Builder's call, flagged for review.)*
- **UDDF export:** Exact writes `count` as today. Seen and the groups omit
  `count` and write the value in a Submersion attribute on the sighting
  element so a Submersion to Submersion round trip keeps it; the importer
  reads that attribute when present. Other UDDF consumers see no count, which
  is correct for Seen and the groups.
- **Sync:** the new value travels with the sighting. A sighting arriving
  without the field is Exact with its count. **The sync compatibility floor
  (`minimumCompatibleSchemaVersion`) rises to the new schema version**
  (maintainer's decision): otherwise an older device stores a Seen or group
  sighting as only `count = 1`, and after it upgrades its next edit publishes
  an explicit null that turns the sighting into `x1` on every device. Older
  versions must update before syncing again.
- **Agent access (MCP)** sighting writes and the dive document gain the new
  field next to `count`, with the same values and the same default (Seen when
  a write gives neither).
- **Bulk edit, dive merge and consolidation** carry the value through.
  **Merging two sightings of the same species** (dive merge sums counts
  today): both Exact, the counts add up as today; otherwise the result is the
  larger of the two, ordering Seen < Single < Few < Many < Abundant and
  placing an Exact number in its REEF group first. *(Builder's call, flagged
  for review.)*

- **Every sighting created without a number is Seen.** That covers the
  repository's `addSighting` default, photo tagging
  (`SpeciesTaggingService`, which creates the dive's sighting when a photo is
  tagged with a species the dive lacks), the agent media write path and the
  Suunto journal writer. *(Builder's call.)*
- **Photo tagging hides "How many".** The media species sheet reuses the
  add dialog but has always thrown its count away; it shows the dialog
  without the chip row, and a sighting it creates is Seen. *(Builder's
  call.)*
- **Dive search `sightings.count`** (`dive_child_query_entities.dart`)
  matches Exact sightings only, since Seen and the groups have no number.
  *(Builder's call.)*

## Data model (constraints for the builder)

- `sightings.count` stays as it is (non-null integer, default 1).
- A new nullable text column holds the value. **Null means Exact**, which is
  what makes existing rows and older peers correct with no data rewrite and
  no sync repair. New writes store `seen`, `single`, `few`, `many`,
  `abundant`, or null for Exact.
- For Seen and the groups, `count` holds 1, so anything still reading only
  `count` (an old backup, a third-party reader) shows no number rather than a
  made-up one. *(Builder's call.)*
- New schema rung on the current ladder file (`rungs_v340_onward.dart`;
  main is at 347),
  `currentSchemaVersion` bumped, the column added to whatever before-open
  backstop the ladder's other added columns use. Check the open PRs for a
  claimed schema number before picking one.
- The domain `Sighting` entity (and `MarineSighting` used by merge) gains the
  field with `copyWith` and `props`; a small enum with the REEF ranges and an
  `fromCount` helper for the merge rule is the builder's call.

## Non-goals

- No change to how many sightings a dive can have, or to species data.
- No new filters or search terms for abundance (dive search can add them
  later).
- No conversion of existing counts into groups.

## Anti-goals

- Showing a number the diver did not pick (the bug this issue is about).
- Rewriting existing sightings.
- Inventing an animal total from groups.

## Left to the builder

- Widget structure for the chip row (a shared widget used by the add dialog
  and the edit sheet is expected), chip styling within the app theme.
- The exact Submersion UDDF attribute name.
- Enum naming and where the REEF ranges live.
