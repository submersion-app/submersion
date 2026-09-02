# Species

Track species sightings and build a database of your underwater encounters.

## Species Database

Submersion includes a pre-seeded species database with 511 species, plus you can add your own.

<div class="screenshot-placeholder">
  <strong>Screenshot: Species List</strong><br>
  <em>Browsable species database with categories</em>
</div>

The catalog covers freshwater species too (lakes, rivers, springs and
cenotes: pike, trout, cichlids, crayfish, turtles, otters and water plants
among them). Catalog corrections and additions reach existing installs on
the next launch after an update; a species you edited yourself is left as
you set it.

## Species Categories

| Category | Examples |
|----------|----------|
| **Fish** | Grouper, angelfish, clownfish |
| **Shark** | Reef sharks, whale shark |
| **Ray** | Manta ray, eagle ray, stingray |
| **Mammal** | Dolphins, whales, sea lions |
| **Turtle** | Green, hawksbill, loggerhead |
| **Invertebrate** | Octopus, lobster, nudibranch |
| **Coral** | Hard coral, soft coral |
| **Plant** | Seagrass, kelp, algae |
| **Other** | Anything else |

## Logging Sightings

### Adding Sightings to a Dive

1. In dive entry, find **Sightings** section
2. Tap **+ Add Sighting**
3. Search for species
4. Enter count (how many seen)
5. Add optional notes

<div class="screenshot-placeholder">
  <strong>Screenshot: Add Sighting</strong><br>
  <em>Species search and sighting entry</em>
</div>

### Sighting Fields

| Field | Description |
|-------|-------------|
| **Species** | Which species |
| **Count** | Number observed |
| **Notes** | Behavior, size, etc. |

## Species Details

Each species entry contains:

| Field | Description |
|-------|-------------|
| **Common Name** | English name |
| **Scientific Name** | Latin binomial |
| **Category** | Classification |
| **Description** | About this species |
| **Photo** | Reference image |

### Viewing Species Info

1. Tap a species in the list
2. View full details
3. See your sighting history
4. View where you've seen it

## Species Page

The Species page lists every species you have logged, across all your dives.
Open it from **Statistics** > **Marine Life** > **See all species**.

- **Search** matches the common name (in your language), the English name
  and the scientific name.
- **Category chips** narrow the list to fish, sharks, turtles and so on.
- **Sort** by most sightings, recently seen, first seen (the order you
  discovered each species) or name.
- Each row shows the sighting count, the number of dives and the date you
  last saw the species. Tap it to open the species details.
- The **Manage catalog** action in the toolbar opens the species catalog,
  where you add, edit and delete species.

The Species page is not affected by the Statistics filter.

## Adding Custom Species

For species not in the database:

1. Go to **Settings** > **Manage species** (or tap **Manage catalog** on the Species page)
2. Tap **+ Add Species**
3. Enter common name
4. Enter scientific name (optional)
5. Select category
6. Add description
7. Add photo (optional)
8. Save

### Looking a species up online

When you add a species, tap **Look up online** to search iNaturalist by common
or scientific name. Choosing a result fills the common name (in your language
where iNaturalist has it), the scientific name, the category and the taxonomy
class; you can still edit anything before saving. The same lookup is offered
when you add a species from the dive's marine life picker, and on a dive site's
"Recorded nearby" list for names the catalog does not know yet.

Lookups happen only when you tap **Look up**; nothing is sent while you type,
and nothing from iNaturalist is stored except the fields you save.

### Suggesting a species for the catalog

On a custom species, the menu offers **Suggest for the catalog**. It opens a
prefilled GitHub issue in your browser with the species' details; posting it
is up to you.

## Sighting Statistics

### Marine Life Dashboard

In Statistics, the Marine Life section shows:

| Stat | Description |
|------|-------------|
| **Species Seen** | Total unique species |
| **Total Sightings** | All sighting entries |
| **Top Species** | Most frequently seen |
| **Rare Finds** | Seen only once |
| **Category Breakdown** | By species type |

### Species History

For each species, view:

- Total sightings count
- Number of dives with sighting
- First sighting date
- Sites where seen
- Depth range observed
- Every dive where you saw it, newest first, with the site, date, count and notes

## Site-Species Correlation

### What Lives Where

Discover patterns:

- Which species at which sites
- Seasonal variations
- Depth preferences

### Site Species List

Each dive site shows:

- Species seen there
- Sighting frequency
- Best depth for species

## Photo Integration

### Species Photos

Tag the photos on your dives with the species in them, and see every photo of
a species in one place.

- On a species page, the **Photos** section shows every photo tagged with it.
  **Tag photos** offers the untagged photos from the dives where you logged
  the species; **Add photos** imports pictures from your camera roll, matches
  each one to a dive as the media importer does, and tags it.
- In the photo viewer, the **Species** action lists the dive's sightings as
  chips you can toggle, plus a search for any other species. Tagging a species
  that is not yet logged on that dive adds the sighting for you.
- Tagged species appear as chips under the photo; tap one to open the species.
- The Species page shows each species' newest tagged photo in place of its
  category icon. On a dive, each sighting row shows how many of the dive's
  photos carry the species; tap the count to view them. The media library's
  filter has a **Species** facet, which smart albums keep too.

A species with tagged photos cannot be deleted from the catalog until the
tags are removed, the same rule as for sightings.

## Growing the Catalog (maintainers)

The bundled catalog is `assets/data/species.json`; its `version` gates a
one-time upgrade pass on each device that rewrites rows the diver never
edited. To add species:

1. Add entries to `tool/data/freshwater_species_seed.json` (or a sibling seed)
   with descriptions in all 11 locales, and any locale names iNaturalist lacks
   to `tool/data/freshwater_species_name_overrides.json`.
2. `dart run tool/generate_freshwater_species.dart` (network) writes the
   catalog rows and the localized names file and bumps the version.
3. `dart run tool/generate_species_arb_keys.dart`, `flutter gen-l10n`,
   `dart run tool/generate_species_lookups.dart`,
   `dart run tool/generate_species_gbif_keys.dart` (network).
4. Run `test/features/marine_life/presentation/species_lookup_coverage_test.dart`.

Suggestions filed through the in-app "Suggest for the catalog" action arrive
as GitHub issues labelled `species-suggestion`; they land in the seed the same
way.

## Identification Tips

### Recording Details

Good sighting records include:

- Accurate species ID
- Behavior observed
- Size estimate
- Depth where seen
- Any unusual features

### Uncertain IDs

If unsure of species:

- Add to "Other" category
- Note distinguishing features
- Update later when identified

## Conservation Notes

### Tracking Rare Species

Flag notable sightings:

- Endangered species
- Unusual behavior
- Out-of-range sightings
- Breeding behavior

### Environmental Changes

Track over time:

- Species diversity changes
- Coral health observations
- Invasive species
- Bleaching events

## Export & Sharing

### Sighting Data

Export sighting data:

- Included in UDDF export
- Available in CSV export
- For citizen science projects

### Contributing Data

Consider sharing:

- Reef monitoring programs
- Shark sighting databases
- Manta ray identification
- Whale shark registries

## Best Practices

1. **ID before logging** - Be confident in identification
2. **Count accurately** - Estimate when schools are large
3. **Note behavior** - Feeding, cleaning, mating
4. **Include context** - Depth, substrate, time of day
5. **Update records** - Correct misidentifications
6. **Learn continuously** - Use field guides
