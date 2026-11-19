# Import review shows each dive's trip

Issue: #3022 (remaining part). Discussion 4742 asked for the same thing.

## Intent

Imports already place a new dive in the trip whose dates cover its day: files
since #2743, dive computer downloads since #4323 and Apple Health since #4340.
What a diver cannot do is see it happen. The review step never mentions a trip,
so a diver who planned a trip only learns afterwards whether the dives landed
in it. This change shows the trip before the import and confirms it after.

## Goals

- Each dive row in the import review that will be saved as a new dive shows
  the trip it will join, as read-only text.
- The label follows the diver's choices on the review step: unticking a file
  trip, marking a row skip or merge, or changing the target profile updates it.
- The import summary lists how many dives went into each trip, read from the
  dives actually saved.

## Non-goals

- Changing or removing the trip during the import (chosen against: the diver
  changes it on the dive afterwards, as today).
- Placing dives a file leaves outside its own trips (Subsurface, Diving Log,
  UDDF). That rule stays as it is.
- Any change to which trip a dive joins. Save behaviour is unchanged.

## Anti-goals

- A label that disagrees with what is saved. A wrong prediction is worse than
  none, so the review and the save routes must use one rule.

## Approaches

1. **One shared rule (chosen).** The importer's decision moves into one pure
   function under `lib/features/trips/domain/services/`. The file importer,
   the dive computer download and Apple Health keep calling it at save time;
   the review step calls it through a provider that watches the diver's trips
   and the review state. It cannot drift from the save, and it reacts to
   selection changes.
2. **Each source labels its rows.** Every adapter looks the trip up while it
   builds the review list. Simpler per adapter, but fixed once built (it
   ignores unticked trips and row actions) and repeated in five adapters.
3. **Summary only.** Always accurate and smallest, but shows nothing before
   the import finishes, which is the part the issue asks for.

## Design

### The rule

One pure function decides a new dive's trip from:

- the dive's own date (none: no trip, as today),
- the file trip it links to, if any, and whether that trip is imported,
- whether its file carried trips at all,
- the trips the owning diver can see, plus the file's selected trips.

It returns the linked file trip when that trip is imported (or resolved to an
existing duplicate, #3879); otherwise, when the file had no trips or the
dive's own trip was not imported, the trip from `tripForDiveDate`; otherwise
none. The file importer's inline block (around `uddf_entity_importer.dart`
line 3051) calls it. Downloads and Apple Health are the date-only case.

### Review rows

- Adapters that read files attach to each dive item the link it needs (its
  file trip's row index, and whether its file had trips), and to each trip
  item its name and dates. Sources without trips attach nothing; their dives
  are the date-only case.
- A wizard provider maps row index to trip name, from the target diver's
  trips (`ImportTargetChoice`, or each item's `ImportTarget` in a multi-diver
  import; a brand-new profile has no trips) and the current selections and
  duplicate actions. Only rows saved as new dives get a name: non-duplicates
  and rows marked import as new. (Found in review: a row merged into a dive
  with no trip gets one too, because a merge saves the dive on its own first
  and then copies its trip onto the match when the match has none.)
- The row shows it as one extra line under the subtitle, with the trip icon:

  ```
  12 Nov 2026, 09:14
  Blue Hole · 28.4 m max · 52 min
  [trip] Maldives 2026
  ```

### Summary

The summary step reads the saved dives' trip ids (`importedDiveIds`), groups
them, and shows one line per trip, most dives first:

```
Trips
  Maldives 2026: 12 dives
  Red Sea: 3 dives
```

No section when no dive joined a trip.

## Left to the builder

- Names of the new fields, provider and l10n keys; strings go to every ARB.
- Whether the trip line reuses `_NonDuplicateRow`'s subtitle styling or its
  own `Text`; it must also appear on the duplicate card when the row is
  marked import as new.
- Test seams: the pure rule gets unit tests covering each branch, the provider
  gets tests for selection and action changes, and the importer keeps its
  existing `uddf_entity_importer_existing_trip_test.dart` green unchanged.
