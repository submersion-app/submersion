# Where on the dive each species was seen

Issue: to be opened from this design. Release: v1.8.7.

## Why

In the maintainer's words, this is "just another way to view where in a dive
certain species were seen (ie. were they seen near the surface, or down deep,
etc.)". It is a view onto data the diver already has, plus one small optional
input. It answers "shallow or deep, early or late" for one species at a time on
the dive details page.

How much of a real log it covers (the maintainer's log, read 2026-11-27): 208
sightings on 17 dives. 183 are placed by a tagged video from that dive, 7 by a
tagged photo, and 18 have no media at all. The new sighting time is for those
18, and for every diver who logs marine life without a camera.

## Where a species' positions come from

A sighting's positions are every one of these, shown together. No source hides
or overrides another.

1. **The sighting's own time** (new, optional): one moment, in seconds from the
   dive start. Its depth is read from the dive's profile at that second, never
   stored.
2. **Photos on this dive tagged with the species** (`media_species` rows whose
   media belongs to the dive): each photo's place on the profile, exactly as
   `photoMarkerFor` gives it for the camera chips (time and depth from the
   photo's enrichment). A photo with no place there contributes nothing.
3. **Videos on this dive tagged with the species:**
   - Each accepted identification on the video whose decided species is this
     species (`media_identifications`, `decision = accepted`,
     `decided_species_id` = species, video only) gives a **span**: from the
     clip's place on the profile plus `start_ms`, to that plus `end_ms`.
   - A video tagged with the species that has no such identification (a tag
     the diver added by hand) gives the span of the whole clip: its place on
     the profile to that plus its duration.
   - The clip's place on the profile is its enrichment elapsed seconds, the
     same base the dive computer overlay on video playback uses
     (`baseElapsedSeconds + position`). A video `photoMarkerFor` gives no place
     contributes nothing.
   - Spans are clamped to the profile's range and merged where they overlap or
     touch, so two tracks of one animal read as one band.

**Tags the app applied and the diver has not confirmed count** (maintainer's
decision, 2026-11-27): `media_species.unconfirmed = 1` tags, and the
identifications `reconcileDecisions` marked accepted for them, place a species
exactly like the diver's own tags, with no different style. The sighting
itself often exists only because of such a tag ("log sightings straight
away"), and the row's photo chip already counts them. Rejecting the tag in
species review removes its positions with it. In the maintainer's log this is
26 of 255 tags, and 9 sightings are placed only by them.

A span's depth is the shallowest to deepest profile depth inside it. A
moment's depth is the profile depth at that second (the same interpolation the
chart's cursor uses).

## What the diver sees

### Marine life card

- A sighting with at least one position gets a **depth chip** beside the
  existing photo chip: `27 m` when every position gives the same depth after
  rounding, `16 to 18 m` otherwise (shallowest to deepest over all of them).
  Depth is in the active diver's depth unit and rounded the way the profile's
  readouts round. The words "to" and the unit come from l10n.
- **Tapping the chip highlights that species on the profile**; tapping it again
  clears the highlight. Tapping another species' chip moves the highlight to
  that species. One species at a time. The selected chip shows the selected
  chip style.
- Tapping the rest of the row opens the species page, as today. Nothing about
  the row's existing behaviour changes.
- A sighting with no position has no chip.
- **A dive with no recorded profile:** a sighting with its own time shows it as
  plain text (`at 12 min`) next to the name and has no chip, since there is no
  depth to show and nothing to highlight. Depths from an estimated profile are
  never used.
- Accessibility: the chip's semantics label says what it does (for example
  "Show Grey reef shark on the profile, 27 m") and announces selected state.

### The profile

- The highlight shows on the **dive details profile chart** and on the
  **pinned profile strip** (issue #4423), which is what is on screen when the
  diver has scrolled down to the Marine life card.
- **Spans** draw as bands that look like a selected safety finding's window.
  **Moments** draw as a dot on the depth line with a thin cursor line, so a
  photo and a typed time are visible at a glance. The chart's existing inputs
  do not fit: `highlightRange` holds one span, and `secondaryRanges` belongs to
  the O2 cell divergence overlay and only draws while that overlay is on. So
  the chart gains its own species input (a list of spans and moments plus a
  colour), and the pinned strip gains a species layer.
- The strip draws the species layer **whenever a species is selected**, not
  only while the Marine life card is in view (unlike the per-card layers in
  `kStripLayersByCard`). *(Designer's call: the selection is the diver's
  explicit request.)*
- **When no profile can show it:** if the dive's profile card is hidden from
  the section list, or the dive has no chart, the chip is a plain depth label
  and cannot be selected. If only the pinned strip is turned off
  (`pinProfileOnScroll`), the chip still selects, and the highlight is there
  when the diver scrolls back to the profile. *(Designer's call.)*
- The colour is the species' category colour (`colorForSpeciesCategory`), the
  same colour as the row's avatar, so the row and the chart read as one thing.
  *(Builder's call within the theme; check contrast in light and dark.)*
- **Species and safety highlights share the chart, one at a time:** selecting
  a species clears a selected safety finding, and selecting a finding clears
  the species. *(Designer's call: the chart has one emphasised range today and
  two competing ones would be unreadable.)*
- A highlight outside the zoomed or panned window draws nothing there, as
  safety findings do (`visibleHighlightSpan`). No auto-pan.
- The selection lives the way the safety finding selection does: a per-dive
  provider keyed by dive id (`selectedSafetyFindingProvider` is a
  `StateProvider.family`), kept for the session, so returning to a dive shows
  the species still selected. A sighting deleted while selected clears it.

### Editing a sighting's time

- The sighting edit sheet (`EditSightingSheet`) gains an optional **Seen at**
  field below "How many": a time box in the same format as the annotation time
  sheet, and, when the dive has a profile, the dive's small profile
  (`MiniProfilePicker`) to tap or drag. Picking on the profile fills the box;
  typing in the box moves the marker. With a profile, the depth at that
  second shows under it in the diver's unit.
- A clear button removes the time. An empty box means no time.
- Valid range: 0 to the profile's last second when there is a profile; else 0
  to the dive's recorded runtime; else 0 to the recorded bottom time; else any
  time from 0 to 24 hours. Estimated runtimes (`effectiveRuntime`) are never
  the bound. Out of range shows an inline error and does not save. The same
  check applies to agent (MCP) writes and the UDDF import, which drop an out
  of range time rather than fail the write. *(Designer's call.)*
- A stored time that a later profile (added or replaced after the time was
  typed) ends before is clamped to the profile's end for display, never
  rewritten. *(Designer's call.)*
- The bulk dive editor's shared `SightingsEditor` does not show the field.
- Adding a species (the species picker sheet) does not ask for a time; the
  diver sets it from the edit sheet. *(Designer's call: keeps the add flow as
  fast as it is.)*
- The bulk dive editor's sighting actions do not set a time.

## Data model

- `sightings` gains a nullable integer column for the time, in **seconds from
  the dive start** (the chart's x-axis unit). Null means no time, which is
  every existing row; no data rewrite, no backfill.
- New schema rung on the current ladder file (`rungs_v340_onward.dart`), the
  column added to the before-open child-column backstop the way v350's
  `abundance` was (`before_open_child_columns.dart`), and
  `currentSchemaVersion` bumped. Main is at 386; several open PRs claim 387 and
  388, so check open PRs for claimed numbers when building and take the next
  free one.
- The domain `Sighting` entity gains the field with `copyWith` and `props`.
  `MarineSighting` (dive merge) carries it.
- **Sync:** the column travels with the sighting like `abundance`. The sync
  compatibility floor (`minimumCompatibleSchemaVersion`) rises to the new
  version, for the same reason it rose for `abundance` at v350: a peer below
  it drops the time, and once it upgrades its next edit of that sighting
  publishes an explicit null that the merge applies as a real value, erasing
  the time on every device. The floor's doc comment gains the paragraph that
  says so. Payloads from older peers still decode: a missing time is null.

## Everything else that carries a sighting

Each of these keeps the time when it copies or moves a sighting, and leaves it
null when it creates one:

- Dive merge (`DiveMergeService`, `dive_merge_builder.dart`): merge combines
  dives in sequence and shifts each source's profile by its offset from the
  merged start (`offsets[d.id]`). A sighting's time shifts by the same offset,
  or it would land on the wrong part of the merged profile. Merging two
  sightings of one species keeps the earlier shifted time, or whichever one
  exists. *(Designer's call.)*
- Consolidation (`dive_consolidation_service.dart`, target wins): a time on
  the secondary computer's sighting fills the target's sighting when the
  target has none; a target time is never replaced. Both computers share one
  timeline, so no shift. *(Designer's call.)*
- Bulk dive edit: carried through unchanged.
- Agent access (MCP): sighting writes accept the new field (seconds, with the
  same range check as the editor), and the dive document and record family
  return it. `sql_column_notes.generated.dart` is regenerated.
- Dive search (`dive_child_query_entities.dart`): no new search term (non-goal).
- Exports and imports: UDDF export writes the time on the sighting as a
  Submersion attribute so a Submersion to Submersion round trip keeps it, and
  the UDDF importer reads it when present. Other formats and the PDF logbook
  are unchanged. *(Designer's call: UDDF is the format this app round-trips.)*
- Photo tagging (`SpeciesTaggingService`) creates sightings with no time; the
  photo already places the species.
- Sync conflict catalogue (`dive_log_fields.dart`): the field is listed so a
  conflict on it is named.

## Screen sizes and range of divers

- Phones: the depth chip and the photo chip sit in the row's trailing area and
  wrap below the name when they do not fit; check a long species name with
  both chips at 360 px.
- Desktop and tablet: the Marine life card may lay rows in two columns (PR
  #5076, open at the time of writing, condenses the list and changes
  `DiveSightingRow`). Build on whichever version of the row is on main when
  this is built, and resolve against #5076 if it lands first.
- A dive with 40 species: only one highlight at a time, so the chart stays
  readable; the chips cost no height.
- A deep trimix dive with stops from 40 m: a long-lived video span covering the
  descent can produce a wide range (`6 to 42 m`), which is the truth.
- A dive with no profile, a dive with no sightings, a sighting whose only
  photo has no place on the profile: no chip, nothing breaks.

## Approaches considered

**Display (maintainer picked B):**

- A. Always-on species markers on the profile. At-a-glance spread, but about
  12 species per dive turns into a cloud of dots over the camera chips.
- **B. Tap a sighting to highlight it.** The profile stays clean, one species at
  a time, reusing the chart's existing highlight (safety findings) and the
  pinned strip's band layer.
- C. A species lane under the chart. Shows when, not depth (the actual
  question), and grows tall.

**Storing a hand-logged position (maintainer picked 1):**

- **1. One optional time per sighting**, depth read from the profile. One
  column, one field.
- 2. Time and an editable depth. Works on profileless dives, but a typed depth
  can disagree with the profile, and the editor grows.
- 3. Several times per sighting in a child table. Most flexible, a new synced
  table and a list editor; photos and video already give several points.

**Scope (maintainer picked "add a sighting time"):** media only (no schema
change, nothing for camera-less divers) was the smaller alternative.

## Goals

- From the Marine life card, see how deep each species was and highlight
  where on the profile it was seen.
- Give hand-logged sightings an optional time with no extra step for divers
  who do not want one.

## Non-goals

- Map or GPS-track positions.
- Several manual times per sighting; an editable depth on the sighting.
- Showing species on the fullscreen profile page, the dive list cards, the
  species page, or the statistics (a depth-by-species view across dives can
  build on this later).
- Searching or filtering dives by sighting time or depth.
- Auto-panning a zoomed chart to the highlight.

## Anti-goals

- A depth the diver cannot trace to the profile or their media (no estimated
  profile depths, no invented positions for sightings without data).
- A busier profile when nothing is selected.
- Changing what tapping a sighting row does.
- Losing a diver's typed time to an older synced device.

## Left to the builder

- Where the position logic lives (a pure function from sighting, tagged media,
  accepted identifications and profile to a list of spans and moments is the
  expected shape, unit tested without widgets) and how its provider is keyed.
- The selection provider's shape and how it clears the safety finding
  selection; how the pinned strip layer reads it.
- Dot and cursor styling for moments, within the chart's existing vocabulary.
- The UDDF attribute name.
- The exact l10n key names; every new string goes into all locales.
