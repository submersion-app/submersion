# Equipment catalogue, phase 1: foundation

Date: 2026-11-27
Status: draft for the maintainer's approval (builder check done)
Program: `2026-11-27-equipment-catalogue-program.md`
Source: discussion #4118, suggestion 6
Release: v1.8.7

## Intent

A diver adding a Shearwater Perdix 2 today types "Shearwater", types
"Perdix 2", picks Dive computer, and fills the connectivity by hand. Nothing
in the app knows that model, so the next diver types it all again, and the
manual, the support page and the product page are found by a web search
each time they are needed.

This phase builds the catalogue every later phase reads, and gives it its
first use: as the diver types a brand and model in the gear editor, the
app suggests the catalogue's names; once the typed name is a catalogue
model, a line under the fields offers that model's details, shown beside
the diver's own values, each with a tick. Nothing reaches the item until
the diver applies the review and saves the editor. A linked item then shows
the manufacturer's product, manual and support links on its page, read
live from the catalogue, so a corrected link reaches the diver without
touching their data.

Terms. A **record** is one model in the catalogue. An item is **linked**
when `equipment.catalogue_id` holds a record's id. An **offer** is what a
record would add to an item: the link, and the record's values for fields
it carries.

## What was decided

Chosen by the maintainer on 2026-11-27.

1. **Source.** A curated catalogue in its own public repository,
   `submersion-app/equipment-catalogue` (named for the app's "Equipment",
   at the maintainer's suggestion). Each fact cites the page it was read
   from.
2. **Firmware.** `submersion-app/firmware-catalogue` keeps firmware data.
   A record carries that catalogue's id for the same model; this
   catalogue holds no firmware releases.
3. **Delivery.** Bundled in each app release and fetched: the app fetches
   the latest catalogue release at most daily, sending no diver data, and
   uses whichever copy is newer. A per-device setting of its own,
   "Download equipment catalogue updates", default on, turns the fetch off.
4. **Seed data.** Every dive computer libdivecomputer knows (brand, model,
   type, connectivity), so suggestions cover any computer. Manufacturer
   links (product, manual, support), each read on the maker's own page, for
   the models the firmware catalogue covers (46 when this was written).
5. **Manufacturer links are read live from the record.** They are never
   copied into the item. The gear page shows them on a "From the
   manufacturer" card while the item is linked.
6. **What the review offers.** Fields the item has empty are offered
   ticked. Fields where the item holds a different value are shown beside
   it, unticked. Fields where the two agree are not shown.
7. **Editor entry (option A).** Brand and model fields suggest catalogue
   names as the diver types. Picking one fills only the brand and model
   text. A line under the fields then says the catalogue has details for
   this model and opens the review. The review never opens by itself.
8. **The repository is created by the builder** (approved 2026-11-27).
9. **Web is bundled only:** no fetch and no setting on the web build.

## Goals

1. A public catalogue repository with a versioned format, a validator, a
   release workflow and the seed data above.
2. The app reads the bundled catalogue offline, fetches newer releases when
   allowed, and never shows a broken or unknown-format file.
3. Brand and model suggestions from the catalogue in the gear editor, for
   new and existing items.
4. A field-by-field review that writes nothing until the editor is saved,
   and never changes a field the diver did not tick.
5. A stored, synced link from an item to its record, and the answers the
   diver gave (declined fields, "Not this model"), so an offer the diver
   dealt with does not come back.
6. A "From the manufacturer" card on a linked item's page.

## Non-goals

- Gear outside the seed below (phase 2). The format and the app handle
  every type from the start.
- Pairing a diver's existing inventory in bulk (phase 3). In this phase an
  existing item is offered its record only when the diver opens its editor
  and the brand and model resolve to a record.
- Offering a linked record's later changes (phase 4).
- Firmware versions, releases or update notices (suggestion 5).
- Product photos. A record carries no images; the diver's own gear photos
  (#3355) are unchanged.
- Copying manuals or documents into the app or into Documents.
- Specs the app has no attribute for. A record's values are limited to the
  app's curated attribute keys for that type (see Format); a new spec key
  is an app change first.

## Anti-goals (a failure even if it works)

- A value the diver typed replaced without a tick.
- Anything written to the item before the editor is saved, or after the
  diver cancels the editor.
- A review that opens on its own while the diver is typing.
- An offer the diver declined or answered "Not this model" to, offered
  again on this device or another.
- A record of one type offered for an item of another (a "Quad" light
  matched to a dive computer).
- The fetch sending anything about the diver, their gear or their device
  beyond what any HTTPS GET of a public file sends.
- A failed or malformed fetch the diver notices: the app keeps the copy it
  has and says nothing.
- The gear editor or gear page waiting on the catalogue to load.

## Constraints

- **Main database.** The schema version takes the next free number at build
  time; renumber at merge if main has moved. Tables in
  `lib/core/database/tables/`, rungs in `lib/core/database/migrations/`;
  nothing is added to `database.dart`. `before_open.dart` is at its
  800-line guard: a backstop goes in a part file of its own (the site
  catalogue's went in `before_open_child_columns.dart`).
- **Sync.** `equipment` rows sync whole, last writer wins. Every new synced
  column needs a label in the conflict field catalogue
  (`lib/features/settings/presentation/conflicts/catalogue/`), as
  `catalogueId` has for sites in `site_trip_fields.dart`.
- **File size.** 800 lines at most per file, 200 to 400 typical.
  `gear_item_details_editor.dart` is 444 lines: suggestions and the offer
  line go in widgets of their own with a short insertion there.
- **Units.** Any value shown in the review follows the active diver's unit
  settings, through the attribute catalogue's dimensions. The seed data's
  only value (connectivity) has no unit; phase 2 values will.
- **Localisation.** Every new string in all 11 ARB files.
- **Guards.** `test/architecture/` and `test/shared/` scan all of `lib/`.
  No buttons or chips in `ListTile.trailing`; no indeterminate spinner in a
  widget that consumer tests settle.
- **Concurrent work.** Firmware tracking (#5104) adds a fetch client, a
  per-device setting and `firmware_version` / `firmware_page_url`
  attributes in a branch not yet merged. PR #5096 (reorder and hide gear
  page cards) is open. Whichever lands second adapts: the new card joins
  the card ordering if #5096 is on main, and the setting sits beside the
  firmware one if that is on main.
- **Links.** Every link opens through the existing safe link handling
  (`parseWebLink`), and only `https` URLs are accepted, in the validator
  and again in the app's parser.

## Approaches

**How the two catalogues relate.**

| Approach | For | Against | Outcome |
|---|---|---|---|
| Separate repositories, shared ids | Each repository keeps one job; firmware's watcher and format stay untouched | Two release streams to fetch | Chosen |
| Grow the firmware catalogue into the equipment catalogue | One data set and one validator | A repository named for firmware holds fins and masks; its format changes while the firmware app work is in flight | Rejected |

**Delivery.**

| Approach | For | Against | Outcome |
|---|---|---|---|
| Bundled only, like the site catalogue | Simplest, fully offline, every value reviewed in an app PR | Corrections wait for an app release | Rejected |
| Bundled plus fetched | Offline first use; corrections arrive within a day | A fetch, cache and fallback path in phase 1 | Chosen |

**Where the catalogue meets the diver.**

| Approach | For | Against | Outcome |
|---|---|---|---|
| A. Suggest names, then an offer line opens the review | A diver who only wanted the spelling gets no sheet; same shape as the site catalogue's offer line | Two steps to take details | Chosen |
| B. Picking a suggestion opens the review at once | One step fewer | A sheet every time a name is picked | Rejected |
| C. A separate "Find in catalogue" search | Text fields unchanged | A diver who types the name never learns the catalogue has it | Rejected |

## Design

### 1. The repository

`submersion-app/equipment-catalogue`, public, laid out like
`firmware-catalogue`:

- `data/<maker>.json`, one file per maker, so data PRs rarely conflict.
- `schema/format-1.schema.json`, the contract, and `schema/sample.json`,
  byte for byte the app's test fixture, with a test in each repository
  pinning its hash (the firmware catalogue's arrangement).
- A validator (Python 3, standard library only) that checks the schema in
  strict mode for the repository's own data, then what a schema cannot:
  unique ids; no two records that could match the same item (same
  normalised manufacturer, model or alias, and type); `https` URLs only;
  every record has at least one source; every `attributes` key is a
  curated key the app has for that record's type, with a value of that
  key's kind (choice values among its choice keys); a `firmwareId`, where
  given, exists in the firmware catalogue's latest release.
- A seed script that reads libdivecomputer's descriptor table from the
  `submersion-app/libdivecomputer` fork and writes or refreshes the
  libdivecomputer-sourced records, never touching a field a researched
  source set.
- A release workflow that builds `equipment-catalogue.json` from `data/`
  when it changes on main and publishes it as the asset of a `YYYY.MM.DD`
  release, unless the records match the last release's.
- `README.md` and `AGENTS.md` stating the sourcing rules: a fact is taken
  from the maker's own page wherever one exists; a page whose terms forbid
  reuse is not used; values are restated, never copied as prose.

The attribute key list the validator checks against is a generated file
in the repository (`schema/attribute-keys.json`: type to curated keys,
kinds and choice keys), copied from the app by a script in the app
repository, so the two cannot drift silently. The app side has a test that
fails when its curated attribute catalogue no longer matches the copy in
its test fixtures.

### 2. Record format (format 1)

```json
{
  "format": 1,
  "generatedAt": "2026-11-27T00:00:00Z",
  "records": [
    {
      "id": "shearwater-perdix-2",
      "manufacturer": "Shearwater",
      "manufacturerAliases": ["Shearwater Research"],
      "model": "Perdix 2",
      "aliases": ["Perdix2"],
      "equipmentType": "computer",
      "attributes": { "connectivity": "ble" },
      "links": {
        "product": "https://...",
        "manual": "https://...",
        "support": "https://..."
      },
      "firmwareId": "shearwater-perdix-2",
      "sources": [
        {
          "url": "https://...",
          "publisher": "manufacturer",
          "checked": "2026-11-27",
          "fields": ["links.product", "links.manual", "links.support"]
        },
        {
          "url": "https://github.com/submersion-app/libdivecomputer",
          "publisher": "libdivecomputer",
          "checked": "2026-11-27",
          "fields": ["manufacturer", "model", "equipmentType",
                     "attributes.connectivity"]
        }
      ]
    }
  ]
}
```

- **One record per model a diver can own.** Each libdivecomputer row is its
  own record (Puck Lite and Puck Pro EZ, Symbios HUD and Symbios Handset),
  even where the firmware catalogue folds them into one model with aliases
  (my call). Several records may therefore share one `firmwareId`.
- `id` is permanent: never reused or changed once published, because items
  store it. A new id is `<maker>-<model>` slugged (the firmware catalogue's
  rule); when that collides, as for a model sold as two types (Mares
  Horizon as rebreather and computer), the later one takes a `-<type>`
  suffix (my call). The validator checks uniqueness only; it never derives
  an id.
- `equipmentType` is one `EquipmentType` name. A model sold as two types is
  two records.
- `attributes` holds only curated attribute keys of that type, in the
  app's storage units (metres, bar, kilograms), so the app converts for
  display the way it does for the diver's own values.
- `links` keys are optional; a record with none shows no card.
- `sources[].publisher` is `manufacturer`, `libdivecomputer` or
  `thirdParty`. Where two sources give the same field, the validator
  requires the `manufacturer` one to win (rule 4 of the program).
- Unknown keys are ignored by the app, so later formats can add fields
  without breaking older apps; a change that older apps would misread bumps
  `format`.

**What phase 1 seeds** (my call, from the builder check):

- One record per descriptor row of libdivecomputer's table
  (`src/descriptor.c` in the fork), type `computer`.
- The firmware catalogue's models, with the type and links read on the
  maker's page. Where libdivecomputer and the maker disagree on a type,
  the maker wins (program rule 4): the Divesoft Liberty is a `rebreather`
  record, and a libdivecomputer `computer` record for it is kept only if
  the maker sells a separate computer by that name. The Ratio transmitter
  is a `transmitter` record and the Garmin Descents, absent from
  libdivecomputer, are researched records with the maker as source. Such
  records offer their links and no attribute values where their type has
  no curated key the source gives.

**Connectivity from libdivecomputer** (my call): BLE transport gives `ble`;
USB or USB HID gives `usb`; IrDA gives `infrared`. The `SERIAL` and
Bluetooth Classic flags are ambiguous (Shearwater Petrel and Ratio iX3M GPS
rows mark Bluetooth Classic as serial), so a row whose only transports are
those gets no connectivity value rather than a wrong one, unless the maker's
page states it.

### 3. Delivery in the app

- **Bundled:** `assets/data/equipment_catalogue.json`, taken in by an
  intake workflow modelled on `.github/workflows/site-catalogue-release.yml`
  (weekly or by hand, opens a PR copying the newest release's file and the
  contract fixture into place).
- **Fetched:** a client modelled on `SpeciesPackManifestClient`
  (`lib/features/species_id/data/pack/species_pack_downloader.dart`): GET
  the latest release asset with a timeout, no query parameters, no diver
  data. It runs at app start and on resume when the setting is on and the
  last successful fetch is more than 24 hours old. A good file is cached in
  the app support directory with its fetch time.
- **Choosing a copy:** the app reads the bundled file and the cached one,
  drops either if its `format` is unsupported or it does not parse, and
  uses the one with the newer `generatedAt`. A failed fetch, a 404, a
  malformed file or an unknown format keeps what the app has and is logged;
  the diver sees nothing.
- **Web:** bundled only (decided 2026-11-27). GitHub release downloads
  send no CORS header, so a browser cannot read them; the web build makes
  no fetch and hides the setting, and gets corrections with each web
  deploy.
- **Setting:** "Download equipment catalogue updates", per device, default
  on. Off means no network call; the bundled copy (or the last cached one)
  still serves suggestions and the card.
- **Reading:** the chosen file is parsed off the UI thread into an
  in-memory index (several hundred records now, a few thousand after
  phase 2): by normalised manufacturer and aliases, then by normalised
  model and aliases within a manufacturer, filtered by type. Normalising
  removes case, spaces and punctuation, the rules firmware matching uses
  (`normalizeComputerIdentityPart` where it fits). The parser skips a bad
  record and keeps the rest, as the site catalogue's parser does.

### 4. Storage on the item

Two nullable text columns on `equipment`, both synced:

- `catalogue_id`: the linked record's id. Written only by applying a
  review (or cleared by Unlink or a brand/model change, below), never by
  an ordinary edit of another field.
- `catalogue_answers`: JSON, the shape of the site catalogue's
  `SiteCatalogueAnswers`: `notSame` (record ids the diver said are not this
  item), `declined` (per record id, the field names the diver left
  unticked when the offer was for an empty field), and `unknown` (keys
  from newer builds, kept on rewrite).

Both carry conflict field labels, migrate with a rung and a before-open
backstop, and travel in backups and the JSON export with the rest of the
row. UDDF: the builder mirrors what the UDDF export and import do for a
site's `catalogueId` if equipment rows carry Submersion extension fields
there; if they carry none, UDDF is left alone (my call).

### 5. The gear editor

**Suggestions.**

- The brand field suggests manufacturer names (and their aliases' main
  name) from the catalogue for the item's type, after the brands the
  diver has already used (my call: their own spelling first).
- The model field suggests the catalogue models of the brand typed, for
  the item's type. With no brand typed it suggests nothing (my call:
  model names alone are too short to search usefully).
- Picking a suggestion sets the field to the catalogue's spelling. It
  writes nothing else. Typing over a suggestion is always allowed; the
  fields stay free text.
- A record whose type differs from the item's is never suggested or
  offered.

**The offer line.** Under the brand and model row, shown when all hold:

- the typed brand and model resolve to exactly one record of the item's
  type (by name or alias, normalised);
- the record is not in `notSame` for this item;
- (several items may link to one record: two divers' Perdix 2s, or a spare,
  are normal; unlike the site catalogue, a record is never withheld because
  another item holds it)
- the item is not linked, or is linked to this record and the record
  offers an empty field not yet declined.

Text: "Built-in equipment catalogue has details for this model", with a
Review button. When the only thing to offer is the link (every field
agrees or is declined), the line still shows for an unlinked item, so the
link can be made.

**The review sheet.** Reuses the shape of the site catalogue's comparison
sheet (`catalogue_gap_comparison_sheet.dart`): a bottom sheet on phones, a
dialog at desktop width.

- Header: the record's manufacturer and model, and a source line naming
  the publisher of its sources and the newest `checked` date.
- One row per offered field: field label, the item's value ("none" when
  empty), the record's value, and a tick. Empty-field rows start ticked;
  differing rows start unticked; equal values have no row.
- A note that manufacturer links show on the gear page once linked, when
  the record has any.
- Buttons: "Not this model" and "Apply" with the ticked count.

**Applying** holds everything in the editor's session, the way
`site_catalogue_sitting.dart` holds a site review until Save:

- the ticked values are set into the editor's fields, visibly, so the
  diver sees them before saving;
- the link is set to the record;
- empty-field rows left unticked are recorded as declined for that record;
  differing rows left unticked are not recorded (they are the diver's
  value standing, phase 4's ground).

Cancelling the editor discards all of it. Saving writes it in the
editor's one save.

**"Not this model"** records the record id in `notSame`, also held until
Save, and hides the line for that record.

**Changing the name of a linked item.** On Save, if the linked record is
in the catalogue the app holds and the brand and model no longer resolve
to it, the link is cleared (the item is no
longer that model); values already taken stay, they are the diver's now.
Correcting a spelling that still resolves (an alias, a case change) keeps
the link.

### 6. The gear page card

"From the manufacturer", shown when the item is linked, its record is in
the catalogue the app holds, and the record has at least one link:

- one row per link present: Product page, Manual, Support, each opening
  through `parseWebLink`;
- a source line: the publisher and the newest `checked` date of the
  sources that cover the links;
- an Unlink action in the card's overflow menu (not a trailing button),
  which clears `catalogue_id` through the page's usual edit path; the
  values taken stay.

A linked item whose record is absent from the catalogue (withdrawn, or the
device's copy is older than the one that linked it on another device)
keeps its link and shows no card.

If #5096 (reorder and hide gear page cards) is on main when this is built,
the card is one of its cards, with an id, default position after the
specification card, and hideable like the rest.

### 7. Settings and credits

- The "Download equipment catalogue updates" switch, with one line of
  explanation (fetched from GitHub at most once a day; nothing about you or
  your gear is sent).
- The licences page gains an "Equipment data" entry naming the repository
  and libdivecomputer as the source of the dive computer names.

## Scale

- 5 items or 1,500: suggestions and the offer line work per item in the
  editor; no list-wide pass runs in this phase.
- A catalogue of a few hundred records now and a few thousand after
  phase 2: the index is built once per catalogue copy, off the UI thread;
  suggestions filter it in memory.
- Long names (Heinrichs Weikamp OSTC 4 hwOS Sport) and long links fit at
  phone width: suggestion rows and review rows wrap, the card's link rows
  show the label, not the URL.

## Testing (for the plan)

- Repository: validator tests on good and bad samples (each check above
  failing on its own), seed script tests on a saved descriptor table, the
  release workflow's build step on a fixture.
- App, pure: parser (bad records skipped, unknown format rejected, unknown
  keys ignored, non-https links dropped), copy choice (bundled versus
  cached by `generatedAt`), index and normalising, the offer rule (empty
  ticked, differing unticked, equal absent, type mismatch, notSame,
  declined), answers JSON round trip keeping unknown keys, the link-clear
  rule on rename.
- App, data: the rung and backstop, sync of both columns, conflict labels.
- App, widgets: suggestions; the offer line's appearance rules; the sheet's
  ticks and counts; Apply held until Save and dropped on Cancel; "Not this
  model"; the card's rows, Unlink, absence rules; the setting.
- Fetch client: success, 404, timeout, malformed, unknown format, setting
  off makes no call.

## Left to the builder

- Exact strings, within the wording above, and their 11 translations.
- Where the switch sits in Settings, beside the firmware switch if that has
  landed.
- The fetch client's timeout and retry details.
- Whether the index lives in a provider of its own or beside the attribute
  catalogue's providers.
- The seed script's handling of libdivecomputer vendor spellings that
  differ from the maker's own (record the maker's spelling as
  `manufacturer` and libdivecomputer's as an alias).
