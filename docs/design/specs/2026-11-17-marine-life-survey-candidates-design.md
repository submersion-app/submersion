# Marine life candidates from dive surveys: design

Part of the marine life identification program
([program design](2026-11-17-marine-life-identification-program-design.md)).
Follows the measured accuracy piece
([findings](../findings/2026-11-17-marine-life-measured-accuracy.md)), whose
Limits section names this gap.

## Why

The species pack can only suggest a species that is on its candidate list.
Beyond the catalogue's own species, the list is every species with at least
50 photographed human observations on GBIF. Species that divers record often
but rarely photograph never get on it. Creole Wrasse (GBIF 5209750) has about
32,000 shallow human observations, mostly from reef visual census programmes,
and only a few dozen photographed ones, so the app can never suggest it.

BioCLIP 2 names a crop zero-shot against text embeddings of the candidates'
names (`models.text_embeddings` embeds only the scientific and common names),
and a candidate's region comes from GBIF's density map for its key
(`regions.cells_for`), which draws every kind of record. So a candidate
needs a name and a region, not photos.

## Goals

- Species that divers survey often get on the list even when few people
  photograph them.
- Nothing on today's list leaves.
- The naming bars are measured again on the new pack and applied to it.

## Non-goals

- Changing the photo route, the catalogue route, the detector or the
  classifier. The detector choice stays open.
- Publishing a pack or turning the feature on.
- Changing the app or the shape of `candidates.json`.

## What the measurement showed

Measured on 2026-11-17 against the full pack 2026.11.17.1617 (7,646
candidates), within the same 90 orders the build widens within.

- The 8,000 cap does not bind today: 679 catalogue species plus every
  species with 50 or more photographed observations comes to 7,646. The
  photo floor is what keeps survey species out.
- A ranking by all human observations is dominated by fishery and deep-sea
  records: ocular coral (2.66 million, one Norwegian petroleum ROV dataset),
  Peruvian anchoveta (1.7 million, a Chilean fishery programme). Swapped in at
  the same size it would drop 2,475 photographed species.
- Many monitoring datasets publish absence rows (`NOT_DETECTED`): 19,650 of
  Creole Wrasse's 32,056 shallow rows are absences.
- Present records at 0 to 40 m keep the reef census programmes. Creole
  Wrasse keeps 12,406 records across about 89 datasets. With a floor of 50
  such records, 1,365 species are added (778 fish, 352 invertebrates, 186
  corals, 49 sharks and rays).
- Share of each region's 300 most surveyed shallow species that are
  candidates: Caribbean 88% today, 100% after; Indo-Pacific 77%, 100%;
  Mediterranean 63%, 92%. The 300 most photographed per region stay at
  100% (Red Sea 96%, unchanged).
- About 23% of the added species come mostly from catch surveys (trawl,
  seine, longline), for example ponyfish and threadfin bream from a northern
  Australia prawn bycatch dataset. A higher floor does not lower that share.

## Approaches

1. **A second way in (chosen).** Keep the photo route as it is and also admit
   species with enough present, 0 to 40 m human observations. Nothing
   leaves; catch-survey species come in too, and the scorer measures what
   the larger list costs.
2. **A second way in, visual surveys only.** The same, leaving out catch
   survey datasets. Cleaner, but dataset titles are unreliable ("NOAA ...
   Fisheries Science Center" publishes diver visual census), so it needs a
   hand-kept dataset list in the tool.
3. **One ranking by all human observations.** Measured above: fishery and
   deep-sea species fill the list and photographed ones leave.

Eric chose 1, with a floor of 50 records, the same number as the photo
floor.

## Design

- `candidates.py` gains a survey query beside the photo one: GBIF
  occurrence search, `basis_of_record=HUMAN_OBSERVATION`,
  `occurrence_status=PRESENT`, `depth=0,40`, faceted by species, within the
  same order keys. Records without a depth are not counted; the photo route
  still covers them.
- `build_pack.py` gains `--min-survey-records` (default 50). The list is the
  catalogue species, then the photographed species in their order, then the
  surveyed species not already on it, in their order, up to
  `--max-candidates`.
- `--max-candidates` defaults to 10,000 (was 8,000), so the cap stays a
  safety limit; the list comes to about 9,000. When it does bind (a small
  development pack), survey-only species are the ones left out.
- Land and freshwater: the survey query uses the same order keys, so the
  land-order exclusions apply unchanged. Freshwater survey species can
  enter, as freshwater species already do through photos.
- The pack is rebuilt, the scorer runs again on the committed test set, and
  `NAMING_MEASURED` in `manifest.py` is replaced with the new pack's bars and
  content hashes. The findings document gets the new numbers, and its Limits
  bullet is updated.
- The developer guide lists the new option and the new default.

## Decided during review

The whole-branch review found that GBIF's species facet, paged 1,000 at a
time with `facetOffset`, repeats species at page boundaries and skips
others: 7,485 distinct photographed species where one request returns
7,642, and 4 surveyed species lost (Pacific Cornetfish among them). Both
lists had the gap, the 7,646 pack included. Eric chose to fix both routes
in this piece: each facet is one request (`facetLimit` set to the limit,
with a warning if GBIF returns that many), under new cache names. This
changes the photo route, which the non-goals above had kept as it was, and
the pack is rebuilt and scored again with the fix. The numbers above were
measured with the paged facets; the rebuilt list has 9,151 candidates: the
7,646, 156 photographed species the paging had skipped, and 1,349
surveyed-only species.

## Builder's calls

- The merge of the two rankings is a pure function with tests in the
  existing candidates tests (`manifest_test.py` holds them today), so CI
  runs them without network access.
- The survey facet has its own cache file names. (The photo query's names
  changed too with the paging fix above, so an earlier work folder's photo
  pages are not reused.)
- The photo query's filters are unchanged (no absence filter; iNaturalist
  records are all presence).
