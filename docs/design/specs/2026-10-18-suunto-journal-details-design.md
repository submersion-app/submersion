# Suunto journal dive details on cloud import

Issue: #3491. Follows #3266 (buddies, PR #3492).

## Intent

A diver who logs a dive's details in the Suunto app (dive center, visibility,
current, weight, suit, marine life, how the dive felt) and then imports it into
Submersion through the Suunto cloud import should find those details on the
imported dive, not have to type them in again. Today only the notes and, since
#3266, the buddies come over.

## Where the data is

The details live in the cloud workout's `journal` object, returned with each
workout by `api.sports-tracker.com`. The dive export (SML) never carries them.
A real workout shared on #3266 is the reference, trimmed and anonymized in
`test/fixtures/suunto_cloud/workout_journal_buddies.json`:

| Journal key | Shape | Example |
| --- | --- | --- |
| `diveCenter` | `{id, value}` | value is the center's name |
| `diveVisibility` | `{id, value}` | id `good`, value localized ("Gut") |
| `diveCurrent` | `{id, value}` | id `none`, value localized ("Keine") |
| `diveWeights` | `{value, unit}` | `12.0`, `KG` |
| `diveSuit` | list of `{id, value}` | free text |
| `diveEnvironmentalFeatures` | list of `{id, value}` | "See" |
| `diveMarineEncounters` | list of `{id, value}` | "Aal", "Barsch", "Krebse" |
| `diveComfort` | list of `{id, value}` | id `optimal` |
| `diveBuoyancy` | list of `{id, value}` | ids `negative`, `neutral` |
| `diveStateOfMind` | list of `{id, value}` | id `relaxed` |
| `privateNotes` | string or null | null in the sample |

Known limit: that sample came from the single-workout request the
sports-tracker.com website makes, while the importer reads the
`workouts?since=` listing. #3266 made the same assumption that the listing
carries `journal`. If it does not, this feature imports nothing extra, exactly
as today.

## Goals

- Every journal detail the diver logged comes over onto the imported dive.
- Nothing written in Submersion is overwritten. Each detail fills only what the
  dive does not have yet.
- Importing the same dive again adds nothing twice.
- A detail that cannot be read or saved never fails the import or costs the
  dive its other details.

## Non-goals

- The Suunto app JSON file import. The file export holds none of this.
- Translating Suunto's text. Values stay in the language the diver uses the
  Suunto app in.
- Matching Suunto's free-text animal names to existing species in another
  language ("Aal" is not matched to "Eel").
- Writing details back to Suunto.

## Anti-goals

- Guessing. A code whose meaning is unknown is never mapped to a Submersion
  value. It is kept as text instead (see Visibility and current).
- Clobbering. A re-import must not replace a value the diver changed in
  Submersion.

## Behaviour, field by field (decided with the user)

Every write below runs after the dive is saved, on the same paths that already
fill the notes and buddies (new dive, replace source, folded consolidation
target, dive kept standalone), and on none of the paths that skip
(skipped duplicate, same-computer consolidation).

- **Dive center:** matched to one of the diver's dive centers by name, ignoring
  case, or created for the diver. Linked only when the dive has no dive center.
- **Visibility:** a known code is stored the way Submersion's own band picker
  stores a band (issue #3226): the band's metre range on the diver's chosen
  visibility scale (`AppSettings.visibilityScale`, `VisibilityScale.rangeFor`),
  written to `visibilityMinMeters`/`visibilityMaxMeters`. So Suunto's "good"
  is 15-30 m for a diver on the tropical scale and narrower on cold water. The
  legacy `visibility` column is never written (its doc comment forbids it).
  Written only when the dive has no visibility at all: `visibility`,
  `visibilityMeters`, `visibilityMinMeters` and `visibilityMaxMeters` all null.
- **Current:** current strength set from a known code only when it is empty.
- **Weight:** one weight of type Belt (the same default the Garmin cloud import
  uses, since Suunto does not say what kind), converted to kg when the unit is
  pounds, added only when the dive records no weight.
- **Marine life:** each encounter becomes a sighting of the species with that
  common name (found or created, category Other when created), count 1. A
  species already sighted on the dive is skipped.
- **Suit, environment, comfort, buoyancy, state of mind:** custom fields, one
  per journal key, value is Suunto's text, several values joined with ", "
  ("Buoyancy: Negativ, Neutral"). Added only when the dive has no custom field
  with that label (ignoring case).
- **Private notes:** appended below the public notes (`description`), with a
  blank line between, as one notes text written by the existing
  fill-notes-if-empty rule. If the dive already has notes, neither is written,
  exactly as for notes today.

Decided with the user after review: visibility uses the band-from-scale form
above, not a custom field and not the legacy column.

## Decisions marked as the builder's calls

These were proposed to the user and not objected to; they are calls, not
requirements the user asked for:

- **Custom field labels are fixed English words:** "Suit", "Environment",
  "Comfort", "Buoyancy", "State of mind". They are stored data, not UI strings.
- **Unknown visibility or current codes** become a custom field
  ("Visibility" or "Current", with Suunto's `value` text), so nothing is lost.
- **Known code mapping.** Only codes seen in real data map: visibility `good`
  to the Good band, current `none` to None. Every other code, even one that
  reads like a Submersion value (`excellent`, `light`), is unknown until a real
  workout shows it, and is kept as the custom field described above. Adding a
  code later is a one-line change with a fixture.
- **Dive center ownership:** a center with no owner (`diverId` null) matches by
  name and is claimed for the diver, as the buddy import does for people.
- **Species are shared:** `Species` has no owner column, so
  `getOrCreateSpecies` (first common-name match, built-in included) is the
  intended lookup.
- **Weight unit:** `KG` and `LB`/`LBS` (case-insensitive) are understood; any
  other unit skips the weight rather than guessing.
- Blank values (after trimming) are ignored everywhere; a field whose every
  value is blank is not written.

## Shape of the change

- `SuuntoCloudClient` parses the journal into one immutable value object
  (for example `SuuntoJournal`) on `SuuntoWorkoutSummary`, alongside the
  existing `buddies` (which can move into it). Malformed entries are passed
  over, never thrown.
- `SuuntoParsedDive` carries it, set by the fetch step as notes and buddies are.
- A writer next to `SuuntoBuddyWriter` applies it after save, each detail in its
  own try/catch with a log line, following `GarminCloudAdapter._tryExtra`.
- New fill-if-missing repository methods where none exist, each one statement
  or a small transaction that checks emptiness in SQL (as `fillNotesIfEmpty`
  does), marks the record pending for sync, and returns whether it wrote:
  dive center link, visibility, current strength, custom fields. Weight reuses
  `addWeightIfNone`; sightings reuse `SpeciesRepository.getOrCreateSpecies`
  and `addSighting`.
- The core keeps `_fillFromWorkout` as the single call site.

## Testing

- Client: the fixture yields every field above; malformed, blank and missing
  shapes yield nothing and never throw.
- Writer: against a real test database, each field fills an empty dive, leaves
  a filled one alone, and a second import adds nothing; one failing write does
  not stop the others.
- Core: the writer runs on exactly the paths listed above.

## Left to the builder

File and class names, how the journal value object is laid out, and whether
the new repository methods live in `DiveRepository` or a small helper.
