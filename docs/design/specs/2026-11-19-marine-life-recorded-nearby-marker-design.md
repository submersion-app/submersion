# Marine life identification: "Recorded nearby" marker

A small marker on marine life suggestions saying the species has been
recorded near the dive, taken from the same list a site page shows under
"Recorded nearby". Refs #4668.

## Why

The maintainer asked whether a site's "Recorded nearby" list would help
when tagging species in a dive. The species pack already limits names to
species recorded in a block of nine 5° cells, about 1,650 km across at the
equator. The site's list is GBIF's records within 5 km. That is far more
local: it can tell apart look-alikes that share an ocean region but not a
reef. Shown next to a suggestion, it helps the diver decide whether to add
the tag.

## Decided by the maintainer

1. **The marker shows everywhere a species is offered with a score:**
   - the Suggested rows in a photo's species sheet;
   - the "Possible matches" list opened from a suggestion's crop (also
     what tapping a video's label opens);
   - each species row in Species to review.
2. **It is looked up when shown** (approach 1 below), from the list the
   site page already fetches and saves.
3. **Added 2026-11-22: the viewer's suggestion chips get it too**, as a
   small pin at the end of the chip (see Look). That covers the chips over
   a photo and the "+N" sheet they open, which draws the same chips.

## Goals and limits

- **A hint only.** Scores, the suggest and confident bars, which crops are
  suggestable, auto-apply and the species pack do not change.
- **Positive only.** The marker says "Recorded nearby" or nothing. There is
  no "not recorded here": the list leaves out every record not licensed
  CC0 or CC BY, which removes most iNaturalist sightings, so absence says
  little about the reef.
- **Never in the way.** While the list loads, when it cannot be fetched,
  or offline with nothing saved, the row looks exactly as it does today.
  Suggestions never wait for the list.
- **No extra traffic per photo.** One lookup per place, shared with the
  site page and saved for 30 days, as today.
- **Not in this:** the name labels drawn over a playing video (tapping one
  opens a screen that shows the marker), tags already added, including the
  app's tags still awaiting a confirm, any new setting, and using the list
  in scoring (that would need the bars measured again).

## Approaches considered

1. **Look it up when shown (chosen).** The three screens check each
   suggestion against the dive's nearby list, fetching it from GBIF when it
   is not saved, as the site page does. Nothing new is stored with
   identifications and sync is untouched. Offline with nothing saved, there
   is no marker until the diver is back online.
2. **Record it during Find species.** A run fetches the list once and stores
   a flag with each suggestion. Works offline afterwards, but adds a synced
   field, leaves earlier identifications without it, and a run done offline
   never gets one.
3. **Ship local lists in the species pack.** Offline everywhere, but a much
   bigger pack to build and publish, and no longer the site page's list.

## Design

- **Place.** The dive's site point when it has coordinates, else the
  photo's own GPS, else where the dive computer logged the entry. This puts
  the first two the other way round from naming (`mediaLocation`), on
  purpose: the marker then matches the site page's list exactly, and a
  dive needs one lookup rather than one per photo position. At a 5 km
  radius the difference is negligible. A Species to review row covers one
  dive, so it uses the site, else the entry point. A photo in no dive uses
  its own GPS. With no place, there is no marker.
- **Data.** `NearbySpecies` also keeps the GBIF species key of every species
  in the search's facet (up to 300), so a pack candidate matches by
  `gbifKey` exactly. Today it keeps catalogue ids plus at most 25 other
  names, which would miss most of the pack's 9,151 candidates. The key
  list is saved with the rest of the result; the cache variant in
  `ReefRepository` goes from `v3` to `v4`, so lists saved before are
  fetched again rather than read without keys.
- **Lookup.** Through `reefNearbySpeciesProvider` and
  `ReefRepository.speciesFor`, so the species sheet, the review page and
  the site page share one in-flight request and one saved copy. The site
  page's display of the list does not change.
- **Wording.** The existing string `reef_species_recordedNearby`
  ("Recorded nearby"), already translated into every language the app
  ships, so no new strings are needed.
- **Look.** A short line under the species name, in the row's secondary
  text style, so the marker adds no colour. It is part of the row's spoken
  label for screen readers.
- **Look on a viewer chip.** The viewer's chips sit on one line, and what
  does not fit becomes a "+N" chip, so a second line of text does not fit.
  The chip ends with a small outlined pin in the label's colour, about
  20 px wider. Screen readers hear "Recorded nearby" with the chip. The
  two choices set aside: the word "nearby" in the label (about 50 px
  wider, so fewer chips fit) and the pin in place of the "+" (no extra
  width, but the chips stop all reading as "add a suggestion").

## Left to the builder

- Whether the marker carries a small icon, and its exact spacing on each
  screen.
- How the review page asks for many dives' lists at once (one per distinct
  site, never more requests than the site pages would make).

## Testing

- `NearbySpecies` keeps the keys through its JSON round trip, and a `v3`
  entry is not served as a `v4` one.
- The place rule: site first, then photo GPS, then entry; review rows use
  site then entry; nothing without a place.
- Each of the three screens: the marker shows when the candidate's key is
  in the list, and is absent when it is not, while the list loads, and when
  it is unavailable.
- Pull request screenshots: before and after of the three screens. Colours
  do not change, so light only.

## Decided during build and review (2026-11-19)

- **Look:** text only, no icon; `bodySmall`'s size in the colour of the text
  around it, so under a list tile's secondary line it adds no colour; one
  line, ellipsised, so a long translation cannot push a row's buttons down
  when the list arrives.
- **Review rows** are matched by every GBIF key the species is known by on
  the device: the row's candidate, each grouped suggestion, and the key each
  of the app's tags was made from (the tagged species' own entry in the
  identification behind the tag, which also gives the row its score). Rows
  of photos in no dive read the shown photo's own GPS.
- **Traffic:** at most two lists are fetched at a time, in the page's
  order; a list already loaded or on its way is read at once; a row that
  leaves the screen gives up its turn; photo positions use the reef cache's
  ~110 m cell, so nearby photos share one list.
- **Data:** a list GBIF could name nothing of keeps its keys (saved as
  `ok` with empty tiers, which the site page hides as before).
- **Offline, all four reef parts (the maintainer's call):** a request that
  got no answer at all (`http.ClientException`: no network, host not found,
  connection dropped) is not saved as a one-hour failure, so the next view
  asks again. A server's failure and a timeout are still saved.
- **Failures** in the marker's own read are not retried: they only mean no
  marker.
