# Diving Log / DiveLogDT SQLite Import, Phase 2

Date: 2026-09-20
Status: approved design, implementation plan pending
Branch: ericgriffin/github-issue-2187-phase2
Issue: #2187 (this PR body says `Closes #2187`)
Phase 1: merged 2026-09-20 as 06d62e0b58f (PR #2198)
Phase 1 design: `docs/superpowers/specs/2026-09-19-divinglog-sqlite-import-design.md`

## Problem

Phase 1 imports dives, profiles, tanks, weights, and the sites and buddies it
can read from the free text on each dive row. The relational tables it was
gated on are now known, from a 444-dive DiveLogDT logbook supplied by the
reporter of discussion #2144. Everything that discussion asked for and phase 1
did not deliver lives in those tables: equipment, trips, dive centers, real
site records with coordinates, and real buddy records.

Phase 1 also left a visible defect. Splitting the free-text `Buddy` column
produced 68 buddies from a `Buddy` table holding 16 people. Phase 2 must fix
that, not add a second set of records beside it.

## Decisions

Taken during brainstorming and fixed for this spec.

- One pull request covering every remaining table, closing #2187.
- Marine life is included. It needs no new `ImportEntityType`, but it does
  need a persistence step: see below. The first reading of this, that the
  entity importer "already reads them", was wrong.
- Photos are included, through the existing media contract.
- Dive references come from the id columns, not the free text. The text path
  stays only as a per-dive fallback.
- Equipment type is read with the existing `typeFromName`, the same reader
  MacDive and CSV imports use, so gear from any source types consistently.

## Reference formats

Confirmed against the reference logbook, not assumed.

`Logbook.BuddyIDs`, `Logbook.UsedEquip` and `Logbook.Divetype` are
comma-separated integer id lists (`3,15,16`). `Trip.BuddyIDs` is the same.
`Logbook.PlaceID`, `CityID`, `CountryID`, `ShopID` and `TripID` are scalar
ids. One shared parser reads all the list columns.

| Table | Rows | Columns that matter |
| --- | --- | --- |
| Buddy | 16 | FirstName, LastName, Email, Phone, Mobile, Street, Zip, City, State, Country, Birthdate, Comments, URL |
| Place | 260 | Place, CountryID, Lat, Lon, MaxDepth, Water, Altitude, WaterName, Difficulty, Rating, Comments |
| City | 27 | City, CountryID |
| Country | 14 | Country |
| Equipment | 31 | Object, Manufacturer, Serial, DateP, Weight, Inactive, O2ServiceDate, Price, Comments |
| Trip | 28 | TripName, StartDate, EndDate, ShopID, CountryID, CityID, BuddyIDs, Rating, Comments |
| Shop | 22 | ShopName, ShopType, Email, Phone, URL, address fields, Rating, Comments |
| Divetype | 10 | Typename, SortOrd |
| Brevets | 5 | Brevet, Org, CertDate, Number, Instructor, InstructorNo |
| Fish | 189 | CommonName, ScientificName, plus taxonomy |
| FishRel | 546 | LogID, FishID |
| Pictures | 0 | LogID, Path, Description |

`Equipment` has **no type column**. `Object` is a free-text name ("Teric",
"Go Sport Fins", "Wet Suit (5mm full body)"). `Equipment.Weight` is kilograms
(`0.45359237` is one pound). `Inactive` means retired. `Shop.ShopType` is one
of "Dive Center", "Dive Operator", "Hotel".

## Mapping

| Source | Payload destination |
| --- | --- |
| Place joined to City and Country | `sites` with `latitude`, `longitude`, `maxDepth`, notes; dive refs by `PlaceID` |
| Buddy | `buddies` with name, email, phone, notes; dive refs by `BuddyIDs` |
| Equipment | `equipment`, type from `typeFromName`, `other` when the name says nothing; dive refs by `UsedEquip` |
| Trip | `trips`; dive scalar ref `tripRef` from `TripID` |
| Shop | `diveCenters`; dive scalar ref `diveCenterRef` from `ShopID` |
| Divetype | `diveTypes`; dive refs from the `Divetype` id list |
| Brevets | `certifications` |
| Fish joined through FishRel | `dive['sightings']` entries with `speciesRef` |
| Pictures | `media` entries with `filename`, `_diveIndex`, `caption` |

### Folding with phase 1

Phase 1 is already in main, so its keys are the ones to match.

Sites are the easy case: phase 1 keys on
`divinglog_site_<country|city|place>` lowercased, and phase 2 can build the
identical key from the `Place`, `City` and `Country` rows, so the two fold
exactly and a re-import produces no duplicates.

Buddies cannot fold that cleanly. Phase 1 keys on the raw text
("Alice"); a `Buddy` row gives "Alice Smith". The rule is therefore per dive:
**when a dive has `BuddyIDs`, those are the only buddy refs it emits, and its
free-text column is ignored.** The text path survives only for dives with no
ids. That keeps a single import self-consistent.

What it cannot fix is a diver who already ran phase 1 and imports again: their
stored "Alice" and the incoming "Alice Smith" are different records and no
payload key reconciles them. That is the wizard's duplicate-review step's job,
and this spec does not pretend otherwise.

### Marine life

No new entity type, but the payload alone is not enough, and the first draft
of this spec was wrong to imply it was.

`UddfEntityImporter` does build a `MarineSighting` from each entry of
`dive['sightings']`, which is what made the path look complete. Those objects
then go nowhere: sightings are a child row rather than a column, `createDive`
writes the dive with its tanks, weights, custom fields and gear and nothing
else persists `Dive.sightings`, and `updateDive` does not either. On top of
that `sightings.species_id` is a foreign key to `species`, so even a write
would have failed with no species rows emitted.

The importer therefore persists them itself, after the dive exists, through
`SpeciesRepository.getOrCreateSpecies` and `addSighting` so the sync marking
is correct. `getOrCreateSpecies` matches on the lowercased common name, which
keeps an import from minting a twin of a species already in the bundled
catalogue. Each sighting carries `speciesName` and `speciesScientificName`
alongside the `species_<snake_case>` ref, because deriving the name back out
of the ref loses its spelling and punctuation. A sighting that cannot be read
is skipped rather than failing its dive.

Out of scope and worth its own issue: `UddfImportResult` also carries
top-level `species` and `sightings` lists that the entity importer never
consumes, so Submersion's own UDDF backups parse marine life and drop it.

### Photos

`Pictures` is empty in the reference logbook, so this path ships validated by
synthetic fixtures only, and the spec says so rather than implying otherwise.
Entries follow the contract the Subsurface and MacDive parsers already feed:
`filename` is the path exactly as the source recorded it, resolved later
against a folder the user picks in the wizard's Photos step, with
`_diveIndex` naming the owning dive and `offsetSeconds`, `latitude` and
`longitude` present but null.

## Error handling

Phase 1's three tiers carry over unchanged, and every new table joins the
same schema-note discipline: a missing table, a missing join key, and missing
columns each produce their own diagnostic naming what the diver loses. An id
in a list column that matches no row is skipped and counted once per table
rather than per dive.

## Testing

Tests first. Unit tests for the id-list parser, including blank entries and
ids that match nothing. Reader tests build synthetic databases per table,
including drifted and keyless variants. Mapper tests run against hand-built
logbook values and assert the folding rules, especially that a dive with
`BuddyIDs` emits no text-derived buddy. A scale check against the reference
logbook confirms 16 buddies rather than 68, 260 sites carrying coordinates,
31 equipment items, 28 trips, 22 dive centers, 5 certifications and 546
sightings.

## Out of scope

- Reconciling records a previous phase 1 import already created.
- `Fish` taxonomy beyond the scientific name.
- `Bookmarks`, `Signature`, `Userdefined`, `Personal`, `DBInfo`.
- Equipment service history beyond `O2ServiceDate`.
