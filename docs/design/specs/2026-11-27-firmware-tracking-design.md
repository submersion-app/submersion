# Firmware tracking and update checks

Source: discussion #4118, suggestion 5 ("Automated firmware update checks").
Related: #1524 (Suunto Nautic firmware not shown).

## Intent

More diving gear runs firmware that its maker updates: dive computers, DPVs,
rebreather electronics, transmitters, lights. A diver wants to know which
version each item runs, hear when a newer one exists (with the release notes
and the maker's update instructions one tap away), and keep a record of each
update in the item's maintenance history, next to its services.

Submersion never installs firmware. It records, compares and points to the
maker.

## Goals

- Record the installed firmware version of electronic gear.
- Keep a history of firmware updates in the item's service history.
- Learn of newer releases from a curated, project-maintained list, without the
  diver searching maker sites.
- Tell the diver on the item, in the equipment list, on the home dashboard and
  with a system notification.

## Non-goals

- Installing or downloading firmware.
- Scraping maker websites from the app, or AI-assisted lookups from the app.
- Telling the diver whether to update. The app shows what changed and links
  the maker's notes; the decision is the diver's.
- Firmware for gear with no recorded version and no catalogue match.

## Anti-goals (failures even if it works)

- A false "update available". A wrong alarm on a dive computer teaches divers
  to ignore the real ones. The app claims an update only when it finds the
  item's exact version in the list and a newer release above it.
- Overwriting a version the diver typed with anything other than what the
  device itself reports.
- Sending diver data anywhere. The check is a plain GET of a public file; all
  matching happens on the device.

## Decided with the maintainer

1. Scope: record the version, log updates in service history, and curated
   update checks (not maker-site scraping in the app).
2. The curated list lives in a new public repo,
   `submersion-app/firmware-catalogue`. The app fetches its latest release at
   most once a day.
3. Upkeep: hand-curated by PR, checked by a schema validator in CI, plus a
   scheduled watcher job in that repo that watches maker pages with a usable
   format and opens a PR when it sees a new release. A person merges every
   change.
4. Notices: item page and equipment list, home dashboard, and a system
   notification once per new release.
5. Build order: the catalogue format is fixed in this document with a sample
   file. This session builds the app; a separate session builds the
   catalogue repo. Both test against the same sample file.
6. Existing data: read through. Versions already stored on dive computer
   registrations are read when the item has none of its own; nothing stored
   is rewritten.

## Approaches considered

| Approach | Trade-off | Outcome |
| --- | --- | --- |
| Record and log only | Contained, but the diver still has to check makers by hand | Folded in as the base layer |
| Record, log, curated list in its own repo, fetched daily | Fresh without an app release; needs a repo and upkeep | Chosen |
| Curated list bundled as an app asset | Simple and offline, but up to ~3 weeks stale | Rejected: freshness matters for safety fixes |
| Maker-site scraping in the app | Freshest in theory; fragile, breaks on any redesign, terms-of-use risk | Rejected; the scraping that exists runs as the catalogue's watcher, where a break is a red CI run, not wrong data |

Build order options were: format first then both in parallel (chosen),
catalogue first then app, app only now.

## The catalogue format (the contract)

Published as the asset `firmware-catalogue.json` on each release of
`submersion-app/firmware-catalogue`. The app reads:

`https://github.com/submersion-app/firmware-catalogue/releases/latest/download/firmware-catalogue.json`

overridable with `--dart-define=FIRMWARE_CATALOGUE_URL=...` for development,
as the species pack does.

```json
{
  "format": 1,
  "generatedAt": "2026-11-27T00:00:00Z",
  "models": [
    {
      "id": "shearwater-perdix-2",
      "manufacturer": "Shearwater",
      "manufacturerAliases": ["Shearwater Research"],
      "model": "Perdix 2",
      "aliases": ["Perdix2"],
      "equipmentTypes": ["computer"],
      "firmwarePageUrl": "https://example.com/perdix-2/firmware",
      "releases": [
        {
          "version": "V95",
          "reportedAs": ["95"],
          "date": "2026-10-01",
          "notesUrl": "https://example.com/perdix-2/v95-notes",
          "instructionsUrl": "https://example.com/perdix-2/how-to-update",
          "summary": "Short plain-text summary of what changed.",
          "safety": false,
          "source": "https://example.com/where-this-was-read"
        }
      ]
    }
  ]
}
```

Rules:

- `format` is an integer. The app ignores a file whose format it does not
  know and keeps its last good copy.
- `id` is stable and unique; the app never shows it.
- `manufacturer` and `model` are the maker's spelling. `manufacturerAliases`
  (optional) holds other maker spellings and former brand names
  ("Shearwater Research"; "Uwatec" under Scubapro). `aliases` holds other
  model spellings divers or devices use.
- `equipmentTypes` uses the app's `EquipmentType` names. It narrows matching
  so a "Mares Quad" computer is never matched to a light called "Quad".
- `releases` is ordered newest first. Order, not version parsing, decides
  what is newer, because makers write versions differently (`V95`, `1.2.3`,
  `Build 4567`).
- `version` is the maker's spelling. `reportedAs` lists other spellings the
  same release appears under (what libdivecomputer or a cloud service reports).
- `date`, `notesUrl`, `instructionsUrl`, `summary`, `safety` and
  `firmwarePageUrl` are optional. `source` is required by the catalogue's
  validator (provenance) and ignored by the app.
- Unknown keys are ignored by the app, so the catalogue can add fields
  without an app release.

The same sample file is committed in both repos: in the app as
`test/fixtures/firmware_catalogue/sample.json`, in the catalogue repo as its
schema sample. The app's parser tests and the catalogue's validator both run
against it.

## App design

### Recording the installed version

- New curated attributes in `equipment_attribute_catalog.dart`:
  `firmware_version` (text) and `firmware_page_url` (url), on the types that
  commonly carry updatable firmware: computer, transmitter, rebreather, dpv,
  light, camera, housing, strobe. Any other item can still use a custom
  attribute, but only curated ones take part in checks.
- The attribute is what checks read for every type, so one code path serves
  every item.
- Dive computers: when a live download reports a firmware version
  (`_persistDeviceInfo` in `download_providers.dart`), the registration keeps
  storing it as today, and the gear twin's `firmware_version` attribute is
  set to it. If it had none, the attribute is set with no history entry.
  If it had a different non-empty version, that change is logged (below),
  except when the two spellings are the same release: equal after trimming
  and ignoring case, or both listed under one release of the cached
  catalogue (`version` / `reportedAs`). Then nothing is logged and the stored
  spelling is kept, so a diver's "V95" is not churned to a device's "95".
  When the cached catalogue shows the reported version is older than the
  stored one, the entry reads "Firmware changed to ..." rather than
  "updated". Files and cloud imports do not change the attribute, because
  an old file can carry old firmware.
- Existing data (decided): nothing stored is rewritten. When a computer item
  has no `firmware_version` attribute of its own, the Firmware card and the
  checks read the version stored on its most recent registration
  (`dive_computers.firmware_version`). The next live download records it on
  the item as above. No migration and no sync repair.
- A custom attribute a diver already named "Firmware" is left alone: it is
  not adopted into the curated key and takes no part in checks (my call;
  guessing at a free-text label could pick up the wrong field).
- The attribute is stored, not recomputed from history (my call). Deleting
  or editing a firmware record never rolls the attribute back: deleting
  history is not uninstalling firmware. Sync needs no hook because the
  attribute row itself syncs.

### History

- New `ServiceCategory.firmwareUpdate` ("Firmware update").
- New nullable `firmware_version` column on `service_records`: the version
  installed by that update. Schema rung, sync serializer and conflict
  catalogue entry as for any new column.
- A download-detected change writes a record: category firmware update,
  date of the download, `firmware_version` the new version, empty notes,
  no service kind.
- A "Log firmware update" action on the item's Firmware card opens a short
  form: new version (prefilled with the latest catalogue release when an
  update is available), date (today), notes. Saving writes the record and
  sets the item's `firmware_version` attribute in one transaction.
- The general service record form shows a version field when the firmware
  update category is chosen, and saving it also updates the attribute when
  the record is the item's newest firmware record.
- History rows show "Firmware updated to V95".
- Older app versions read the unknown category as `other` (the repository's
  existing fallback); if such a device edits that record it is saved back as
  `other`. Accepted.

### Fetching the list

- A client modelled on `SpeciesPackManifestClient`: GET with a timeout, no
  query parameters, no diver data.
- Runs at app start and on resume when the last successful fetch is more than
  24 hours old and the "Check for firmware updates" setting is on.
- The last good file is cached in the app support directory with its fetch
  time. A failed fetch, a 404 (no release yet), a malformed file or an
  unknown format keeps the cached copy and logs; the diver sees nothing.
- The setting is per device, default on. Off means no network call and no
  update notices; recorded versions and history still work.

### Matching and comparing (pure, unit tested)

For an item with a curated firmware attribute or a firmware-capable type:

1. Find the catalogue model: item brand matches `manufacturer` or a
   `manufacturerAliases` entry, and item model
   matches `model` or an alias, compared after normalising (case, spaces and
   punctuation removed, using the existing `normalizeComputerIdentityPart`
   rules where they fit), and the item's type is in `equipmentTypes`. For a
   gear twin with no brand or model of its own, the registration's
   manufacturer and model are used.
2. Find the item's version among that model's releases (`version` or any
   `reportedAs`, compared trimmed and case-insensitive).
3. Status:
   - `upToDate`: found, and it is the newest release.
   - `updateAvailable`: found below the top; carries the newer releases.
   - `unknownVersion`: model found, version not in the list; carries the
     latest release. Shown as information, never as an update.
   - `noVersion`: model found, no version recorded; carries the latest
     release and invites the diver to record theirs.
   - `notListed`: no model match. The Firmware card still shows the
     recorded version and the diver's `firmware_page_url` if set.

### Telling the diver

- Item page: a Firmware card on firmware-capable items showing the installed
  version, the status, the newer releases with summary, date, a safety marker
  when `safety` is true, and links to release notes, instructions and the
  firmware page, plus "Log firmware update".
- Equipment list: an "Update" badge on rows whose status is
  `updateAvailable`.
- Home dashboard: the gear service panel lists firmware updates available
  after the service rows, one row per item, capped like the existing rows
  with an "and N more" line.
- System notification: one per item and newest version, the first time that
  pair is seen as `updateAvailable`. The pairs already notified are kept per
  device. Tapping opens the item. Follows the app's notification permission
  and a "Firmware update notifications" switch shown with the notification
  settings. Both this switch and "Check for firmware updates" are per device
  (SharedPreferences, like the draft reminder switch), because the check
  itself runs per device (my call; avoids a synced settings column).
  System notifications appear where `NotificationService` supports them;
  on desktop, where it shows none, the diver gets the in-app notices only.
- Checks and notices cover the active diver's equipment, as the service
  reminders do (my call).
- Links open through the existing safe link handling (`parseWebLink`).

### Range of divers

- A diver with no electronic gear sees nothing new apart from the setting.
- A diver with dozens of items: the dashboard caps its rows; the list badge
  is per row; notifications are one per item and release, never repeated.
- Long version strings and long model names wrap on phone width.
- A model with many releases between installed and latest: the card shows
  the newest few with a "Show all" expansion.

## The catalogue repo (built in a separate session)

- `firmware-catalogue.json` source, its JSON Schema, and the shared sample.
- CI: validates the schema, unique ids, newest-first order (by `date` where
  both have one), well-formed URLs, required `source` on each release.
- Release workflow publishes `firmware-catalogue.json` as a release asset.
- Seed: current releases for common dive computers and any DPV or rebreather
  electronics whose maker publishes versions, each with a source link.
- Watcher: a scheduled workflow with one small parser per maker page that has
  a usable format. On a new version it opens a PR with the entry for a person
  to check and merge. A parser that fails opens or updates an issue rather
  than guessing.

## Left to the builder

- Widget structure, provider layout, where the setting rows sit in Settings.
- Exact wording of strings (all locales, per the l10n workflow).
- How many releases the card shows before "Show all", and the dashboard cap
  (match the existing panel).
- The fetch client's timeout and retry details.
