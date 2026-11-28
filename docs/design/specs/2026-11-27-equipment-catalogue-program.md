# Equipment catalogue and external data: program overview

Date: 2026-11-27
Status: approved by the maintainer in the design conversation, 2026-11-27
Source: discussion #4118, suggestion 6 ("Reusing External Data and
Automated Data Enrichment")

## Why

A diver moving a gear inventory into Submersion types the same facts every
other owner of that model has already typed: the maker, the model, what it
is, how it connects, where its manual lives. The reporter of #4118 asked for
the app to fill those from existing sources, the way music and book
collection software fills an album or an edition from a few identifiers,
and for dive sites to be filled from existing site collections.

The reporter set four rules, and the maintainer adopted them:

1. Data from outside is always shown to the diver for review before anything
   is saved, field by field.
2. A value the diver holds is never overwritten silently.
3. The source is kept with what is taken.
4. Manufacturer data is preferred over unverified third-party data.

## What already exists for dive sites

Most of the site half is built:

- The built-in site catalogue (`submersion-app/site-catalogue`, bundled,
  offline) is in the site picker and on the Sites search, and an adopted
  site keeps its record's id in `dive_sites.catalogue_id` (#4514 slice 1).
- "Fill gaps" (#4549) pairs the diver's sites with catalogue records and
  offers a record's values for empty fields only, ticked per field, and
  offers again when a linked record gains details in a later catalogue.
- The private shared site library (#3324) is how clubs, dive centres and
  groups keep a common site collection.

## What was decided

Chosen by the maintainer on 2026-11-27.

- **Equipment data comes from a built-in, curated catalogue** in its own
  repository, `submersion-app/equipment-catalogue`, like the site
  catalogue. No live scraping of manufacturer sites and no AI extraction in
  the app.
- **Dive sites stay offline.** The site catalogue's earlier decision of no
  online site lookups stands. The site half of this program is phase 4 only.
- **The equipment catalogue and the firmware catalogue are separate
  repositories with shared ids.** `submersion-app/firmware-catalogue`
  (suggestion 5, issue #5104) keeps firmware releases and its watcher. An
  equipment record carries the firmware catalogue's id for the same model,
  so firmware never has a second source.
- **Delivery: bundled plus fetched.** Each app release bundles a copy, and
  the app also fetches newer catalogue releases (at most daily, no diver
  data sent), behind a per-device setting of its own.
- **Order:** phases 1, 2, 3, 4 below. Each phase gets its own spec, plan and
  PR.

## The phases

| # | Phase | What it delivers | Status |
|---|---|---|---|
| 1 | Equipment catalogue foundation | The repository, record format, validator and release; seed data (every dive computer libdivecomputer knows, manufacturer links for the firmware catalogue's models); bundled and fetched delivery; brand and model suggestions in the gear editor; a field-by-field review; a stored link; a "From the manufacturer" card | Design: `2026-11-27-equipment-catalogue-foundation-design.md` |
| 2 | Coverage | Regulators, BCDs, lights, rebreathers, suits and other types, researched from manufacturer pages with citation checks | Not designed |
| 3 | Existing gear | A review list pairing items already in the inventory with catalogue records, for divers moving a large inventory in | Not designed |
| 4 | Updates to linked records, gear and sites | When a linked record's value changes where the diver already holds one, offer the new value beside theirs; never replaced silently | Not designed |

## Out of the program

- Online dive site collections (decided above).
- Firmware release data in the equipment catalogue (it lives in the
  firmware catalogue).
- Copying product photos or manuals into the app. Media is stored as links
  only (standing rule); a manual is a link the diver opens.
