# Recompression Chamber Directory Rework

Date: 2026-08-26
Status: approved, ready for implementation planning

## Problem

The bundled chamber directory reads as placeholder data, because that is what
it is. `assets/data/chambers.json` holds 14 chambers for the entire world, all
stamped `lastVerified: 2026-07-01`, and the file's own `note` calls itself a
"starter directory".

This was a known gap, not an oversight in design. The original safety spec
(`docs/superpowers/specs/2026-07-16-safety-features-design.md`) called for a
"bundled JSON asset compiled from DAN regional lists and national hyperbaric
registries", described as "a scoped data-curation task within this phase". The
curation task never happened; the 14 hand-typed entries shipped in its place.

A diver opening the emergency card in the Caribbean, the Red Sea, or anywhere in
North America sees a list of facilities on other continents. That is worse than
useless: it signals that the whole safety feature is decorative.

## Research findings

These findings constrain the design, so they are recorded here rather than left
implicit.

### There is no dataset to harvest

- **OpenStreetMap**: an Overpass query for `healthcare=hyperbaric`,
  `health_facility:type=hyperbaric`, and `healthcare:speciality~hyperbaric`
  returns **22 features worldwide** (15 nodes, 7 ways). Unusable.
- **Wikidata**: a SPARQL query for instances of Q549046 ("diving chamber")
  returns **zero** facilities. A query for items whose field of specialty is
  hyperbaric medicine returns 3, one of which is an elective wellness clinic.
- **DAN**: publishes nothing, by policy. DAN Southern Africa states it plainly:
  "DAN does not provide hyperbaric chamber location information to the general
  public." DAN Europe's Alert Diver article "Where's the nearest chamber?"
  directs divers to call emergency services rather than self-refer. Their
  internal referral network is roughly 160-200 chambers and is not public.
- **UHMS**: the chamber directory is behind a Cloudflare bot challenge (HTTP 403
  with `cf-mitigated: challenge`) to both automated fetch and a browser
  user-agent curl. Its separate accredited-facilities program is a
  wound-care quality scheme, not a diving-emergency directory.
- **ECHM/EUBS OXYNET**, the natural European aggregator, is dead. The homepage
  reads "Last update: April 1, 2015" and the listing pages return HTTP 500.
- **Prior art**: no open, structured, global chamber dataset exists on GitHub,
  Kaggle, or elsewhere. No competing dive-logging app publishes one.

### What is reachable

| Source | Coverage | Format | Notes |
| --- | --- | --- | --- |
| SIMSI (Italy) | 40-65 centres | Live HTML, dated 2024 | Tags each centre `Urgenza h24` / `Pazienti critici h24` |
| BHA (UK) | 10 facilities | Live HTML | No emergency-capability flag |
| SPUMS (AU/NZ) | 12 units | Live HTML | Includes national diving hotlines |
| FFESSM (France) | ~25 | Mirrored PDF | Tags civil/military; phone formats suggest 1990s vintage |

Everything else is individually-named facilities from press, hospital pages, and
personal sites: Egypt around 5, Southeast Asia around 25 (from a page last
updated 2002-2004), a handful in Spain, and scattered Caribbean and Central
American facilities with no aggregator. No source was found for Africa beyond
South Africa, or for South America.

### Licensing posture

No source found grants an affirmative redistribution license. All are silent;
several carry "not responsible for errors" disclaimers. Silence, for a
commercial application, means treat as all-rights-reserved. This matters most in
the EU, where the sui generis database right protects substantial extraction
from a compilation even when the individual facts are not protectable.

The design's answer is to treat every listing as a **lead**, verify each fact
against the facility's own website, and record that URL per row. This gives each
row independent provenance, which resolves the licensing exposure and the
staleness problem in the same pass.

### Acute-capable versus elective

The distinction between a chamber that will treat a bent diver at 3am and an
elective HBOT wound-care clinic that will not is real and is encoded differently
by each source: SIMSI uses `Urgenza h24`, FFESSM uses civil/military plus "non
ouvert au public sauf urgence", the UK and Australasian lists imply it through
membership. DAN's published acceptance criteria for its referral network give a
concrete, non-invented bar: the facility must be capable and willing to treat
injured divers, use standard USN/Comex-style oxygen treatment tables for DCI,
provide oxygen for every diving treatment table, and have space to monitor a
diver before and after treatment.

## Decisions

1. **Scope**: expand the dataset substantially, add per-row provenance, and
   rework the presentation. Not a live/refreshable directory; updates continue
   to ride app releases.
2. **Inclusion**: all hyperbaric facilities are eligible, carrying a capability
   flag, rather than dive-casualty chambers only. North America must be covered
   despite having no reachable aggregator.
3. **`phone` stays required.** A row with no callable number does not help a
   diver at 2am. This keeps `EmergencyChamber.phone` non-nullable, leaves the
   `emergencyChambers` table untouched, and preserves the existing assertion in
   `emergency_data_service_test.dart`. Candidates without a number are dropped
   at harvest time.
4. **No database schema version is required.** Bundled chambers are
   asset-resident and never touch the database; only user-added chambers are
   persisted, and their shape is unchanged. No migration, no schema-ladder
   claim, no change to the sync or backup surface.
5. **Existing chamber ids are preserved** for facilities that survive into the
   new dataset. `hiddenChamberIds` in settings stores raw ids, so renaming
   `us-duke` would silently resurrect a chamber a user deliberately hid.
6. **Unverifiable rows ship flagged, not dropped**, consistent with the tiered
   model in decision 2.

## Implementation notes

Two decisions changed during implementation, both recorded here because they
contradict what this spec originally said.

**SPUMS is not parsed.** The spec named it as one of four structured sources.
Its page turned out to be flat prose with no record delimiter: unit names,
clinicians' names, and several labelled phone numbers per unit run together. A
trial parser attached the national Diver Emergency Service hotline to a named
hospital unit and a clinician's name to another unit's switchboard. A wrong
number in an emergency directory is worse than a missing one, so the twelve
Australian and New Zealand units are hand-curated instead, and a test asserts
`parse_spums` does not exist so nobody re-adds it.

**One preserved id was deliberately dropped.** `th-samui` was on the
preserve list, but the SSS Chamber Network's own site now lists exactly two
Thai locations, Koh Tao and Phuket, and the only Samui page still reachable
carries a 2010 copyright. The preserve rule exists to stop a surviving
facility being silently renamed, not to freeze a chamber that has closed. The
removal is asserted by its own test, with the reasoning attached.

The verification pass also corrected two rows that had shipped wrong:
`nz-slark` carried North Shore Hospital's general switchboard rather than the
hyperbaric unit's own line, and `mt-gozo`'s number had changed. Neither error
was detectable by schema validation, since both were well-formed numbers.

## Data model

`assets/data/chambers.json` gains a metadata block and per-row provenance,
following the shape `dive_sites.json` already uses:

```json
{
  "datasetVersion": "2026-09",
  "generatedAt": "2026-09-01T00:00:00Z",
  "note": "...",
  "sources": [
    {"id": "simsi", "name": "SIMSI", "url": "https://simsi.it/...", "retrieved": "2026-08-26"}
  ],
  "chambers": [
    {
      "id": "us-duke",
      "name": "Duke Center for Hyperbaric Medicine",
      "country": "US",
      "city": "Durham, NC",
      "phone": "+1-919-684-8111",
      "emergencyPhone": "+1-919-684-8111",
      "latitude": 36.0076,
      "longitude": -78.9382,
      "capability": "diving_emergency",
      "availability": "h24",
      "verified": {
        "date": "2026-08-26",
        "via": "facility",
        "url": "https://www.dukehealth.org/locations/duke-hyperbaric-center"
      }
    }
  ]
}
```

Field definitions:

- `capability`: `diving_emergency` | `hyperbaric_unit` | `elective` | `unknown`.
  `diving_emergency` requires documentation that the facility accepts acute
  diving injuries, per DAN's acceptance criteria above.
- `availability`: `h24` | `on_call` | `business_hours` | `unknown`. Derived
  directly from source tagging where present (SIMSI's `Urgenza h24`).
- `emergencyPhone`: optional dedicated emergency line, distinct from the main
  switchboard. Preferred by the call action when present.
- `verified.via`: `facility` when confirmed against the facility's own site,
  `registry` when only a third-party listing could be reached.

`EmergencyChamber` (`lib/features/safety/domain/entities/emergency_info.dart`)
gains `capability`, `availability`, `emergencyPhone`, and `verifiedUrl`. User
chambers keep their current shape and default to `capability: unknown`; the
`add_chamber_page` flow is unchanged.

## Build pipeline

New `scripts/chamber_harvester.py`, mirroring `dive_site_harvester.py`
conventions (path resolution relative to project root, rate-limited requests,
Nominatim geocoding with a coordinate cache, a `metadata` block in the output),
with `scripts/chamber_harvester_test.py` alongside it per the existing
`scripts/*_test.py` convention.

Three stages:

1. **Harvest leads** from SIMSI, BHA, SPUMS, and the FFESSM PDF into
   `scripts/chamber_leads.json`. This intermediate file is not shipped.
2. **Verify** each lead against the facility's own website, recording the
   confirming URL and the date. Rows confirmed this way are stamped
   `via: "facility"`; rows where the facility site is unreachable, bot-blocked,
   or has no public page are stamped `via: "registry"`.
3. **Merge** `scripts/data/chambers_overlay.json`, a hand-maintained file
   checked into the repository with per-row citations. North America lives here,
   along with the Caribbean, Mexico, Egypt, Southeast Asia, and South Africa,
   assembled facility by facility because no aggregator is reachable for them.

Validation gates, all fatal:

- ids unique and stable across runs
- `country` a valid ISO 3166-1 alpha-2 code
- latitude in [-90, 90], longitude in [-180, 180]
- `phone` present and E.164-shaped
- `verified.date` present and parseable
- total row count at or above 100, so a broken parser cannot silently ship a
  shrunken dataset. Raise the floor as coverage grows.

The harvester is run manually and its output committed, exactly as
`dive_site_harvester.py` is today. It is not wired into CI.

## Runtime

`EmergencyDataService.loadBundledChambers()` keeps its current shape: lazy load,
static cache. This is the same strategy `DiveSiteApiService._loadBundledSites()`
uses for 3,612 sites, so a dataset an order of magnitude smaller needs no new
storage layer. Estimated asset size at 200 rows is under 100 KB.

`emergencyCardDataProvider`
(`lib/features/safety/presentation/providers/emergency_providers.dart`) changes
in three ways:

- **Capability-banded ordering.** Sort by capability band first, then by
  distance within the band. Pure distance sorting would rank an elective
  wound-care clinic 5 km away above a 24h dive chamber 80 km away, which is the
  central hazard of including elective facilities at all.
- **Carry the computed distance through** to the UI. The provider already runs a
  full haversine calculation and currently discards the result after sorting.
- **Cap the card at the nearest 5.** `emergency_card_page.dart` currently renders
  `for (final chamber in data.chambers)` unbounded, which is acceptable at 14
  rows and a wall at 200.

## User interface

Emergency card chamber section:

- Distance per tile, formatted with the existing
  `UnitFormatter.formatGeoDistance()`, which auto-scales m/km/ft/mi from the
  diver's depth-unit preference and so satisfies the project's unit rule without
  new formatting code.
- A capability chip per tile, visually distinct for elective facilities so a
  wound-care clinic is never mistaken for an on-call dive chamber.
- The verification date, as today, plus the source when available.
- A "View all N chambers" action opening a new searchable directory page.
- An explicit empty state when the nearest chamber is more than 500 km away,
  pointing at the hotline rather than listing a chamber on another continent.
  The full directory page remains reachable, so nothing is hidden, it is only
  kept off the emergency card where proximity is the point.
- The hotline-first note stays prominent and above the list, matching the
  protocol every published source endorses.

New directory page (`chambers_directory_page.dart`): the full dataset,
searchable by name, city, and country, distance-sorted when GPS is known, with
the same capability chips.

All new strings are added to `lib/l10n/arb/app_en.arb` and every other supported
locale.

## Testing

Tests are written before implementation.

- **Dataset invariants** over the shipped asset: unique ids, valid ISO country
  codes, coordinate ranges, phone present, verification date present, row count
  floor, every `capability` and `availability` value within its enum.
- **Entity parsing** for the new fields, including rows that omit the optional
  ones.
- **Provider**: capability-banded ordering, the nearest-5 cap, the empty-state
  radius, and preservation of the existing per-diver and hidden-chamber
  behaviour.
- **Widget**: chips, distance rendering under both unit preferences, the
  "view all" action, directory-page search.
- **Python**: harvester parsers against committed fixture HTML, plus the
  validation gates.

## Phasing

1. Schema, entity, loader, and invariant tests against the current 14 rows. No
   user-visible change.
2. Harvester, verification pass, and the full dataset.
3. UI rework and localization.

## Out of scope

- Remote or over-the-air refresh of the directory. Updates ride app releases, as
  in the original safety spec.
- Any change to user-added chamber persistence, sync, or backup.
- Routing or navigation to a chamber.
- Any claim of accreditation or endorsement of a listed facility.
