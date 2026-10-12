# Cylinder fills and passport ids in UDDF

Issue #2651. Follows the smart cylinder passports program (#2333), spec
`2026-09-25-smart-cylinder-passports-design.md`, sections 4, 10.2 and 18.

## 1. Problem

Fills export and import through their own Submersion CSV (#2339, PR #2631),
and the `.db` backup is a byte copy that carries every table. A UDDF export
carries no fills, so a diver who restores a UDDF backup, or moves through
UDDF between devices, loses the fill history.

A second gap sits under the first. A fill is keyed by its cylinder's
passport id, and the passport id is a system equipment attribute that no
export writes. A UDDF restore into a fresh database would bring fills back
unlinked, invisible on every cylinder until each physical tag is scanned
again.

A third gap was found while tracing the import path: the full UDDF backup
writes equipment service records and `UddfFullImportService` parses them,
but `UddfImportParser` (the wizard's adapter) never puts them in the
payload, so every service record is dropped on a real UDDF import.

## 2. Decisions

- Fills are written in the **full** UDDF export only, as a top-level
  `<cylinderfills>` section under `<applicationdata><submersion>`. Not
  nested in `<item>`: a fill with no cylinder row (logged against a tag the
  diver does not own a row for) has nowhere to nest and would be lost.
- The full export also writes each item's passport id as `<passportid>` in
  its `<item>`, for any item type that holds one (the attribute is universal
  since #2652).
- On import a passport id is **adopted** only into an empty slot: the target
  item has no passport id of its own, and no other item the diver can see
  holds that id, in service or not. An import never moves a tag, never
  re-keys fills and never fails because of a passport id.
- Values use UDDF's SI units (fractions, pascal, kelvin), as `<mix>` and
  `<tankdata>` do. The parser rounds back to 0.01 % (O2, He), 0.001 bar and
  0.01 degrees C, so a stored 32 % returns as exactly 32.
- Import rules match the fills CSV (passports spec 10.2): keep the fill id,
  skip one already here or deleted here, link to the importing diver's tank
  holding the passport id.
- The service-record payload gap is fixed in the same PR (a follow-up).
- The dives-only export and the simple `UddfImportService` are unchanged:
  neither has an `<applicationdata>` gear path.

## 3. File format

```xml
<applicationdata>
  <submersion version="1.0">
    <equipment>
      <item id="equip_<equipment id>">
        ...existing fields...
        <passportid>9f1c...</passportid>
      </item>
    </equipment>
    <cylinderfills>
      <fill id="fill_<fill id>">
        <passportid>9f1c...</passportid>
        <datetime>2026-10-01T14:05:00.000Z</datetime>
        <o2>0.32</o2>
        <he>0</he>
        <pressure>23200000</pressure>
        <temperature>295.15</temperature>
        <analyzer>...</analyzer>
        <filledby>...</filledby>
        <source>nfc</source>
        <notes>...</notes>
      </fill>
    </cylinderfills>
  </submersion>
</applicationdata>
```

- `id`: the fill id with the file's usual `fill_` prefix, stripped on parse
  so the stored id is byte-identical to the original.
- `passportid`, `datetime`, `o2` and `he` are always written. `datetime` is
  the instant in UTC (ISO 8601).
- `pressure` (Pa), `temperature` (K), `analyzer`, `filledby`
  (`station_name`) and `notes` are omitted when null or empty.
- `source` is the `FillSource` name, read back through
  `FillSource.fromName` (unknown text reads as `manual`).
- Not written: the reserved `station_key` and `signed_record`, the
  `diver_id` (the importing diver owns the copy) and the `equipment_id`
  (linking is by passport id). The cylinder's name and serial are already in
  its `<item>`.
- Order: newest first, as the CSV.
- Scope: `CylinderFillRepository.getAllVisibleTo(diverId)`, the query the
  fills CSV uses (passports spec 10.8).
- An empty fill list writes no `<cylinderfills>` element.

## 4. Export

- `UddfFillWriters.writeFills(builder, fills)` in a new
  `lib/core/services/export/uddf/uddf_fill_writers.dart`, beside
  `uddf_site_feature_writers.dart`, called from the `<applicationdata>`
  builder in `UddfExportBuilders`.
- `<passportid>` is written in the `<item>` builder from the item's
  attributes (`EquipmentAttrKeys.passportId`, non-custom, non-empty).
- A `List<CylinderFill>? fills` parameter threads through
  `ExportService.exportAllDataToUddf` and `saveAllDataToUddfFile`,
  `UddfFullExportService` (both public paths and the test generator) and the
  builder, next to `serviceRecords`.
- Both export provider entry points (share and save to file) read the active
  diver's visible fills, through the same validated diver id as the CSV.

## 5. Import

1. **Parse.** `UddfFillWriters.parseFills(submersionElement)` returns one map
   per valid `<fill>`, with the keys `SubmersionFillsCsvParser` emits (`id`,
   `passportId`, `filledAt`, `o2Percent`, `hePercent`, `pressureBar`,
   `temperatureC`, `analyzer`, `stationName`, `source`, `notes`), so
   `CsvFillImporter.fromPayload` reads both formats. A fill missing an id,
   a passport id, a parseable time or an O2 value is dropped; the mix check
   stays in `fromPayload`. `UddfFullImportService` puts the list on
   `UddfImportResult.fills`. `UddfImportParsers.parseEquipmentItem` reads
   `<passportid>` into `itemData['passportId']`.
2. **Wizard.** `UddfImportParser` maps `result.fills` to
   `ImportEntityType.fills` and `result.serviceRecords` to
   `ImportEntityType.serviceRecords`. The diver expander already routes both
   (fills to the primary profile, service records with their equipment), and
   the review step's existing Fills group marks fills already here.
3. **Passport adoption.** New
   `CylinderPassportRepository.adoptImportedPassportId({equipmentId,
   passportId, diverId})`, returning whether it wrote the id. In one
   transaction:
   - the target keeps any passport id it already has (no write when it
     differs; nothing to do when it is equal);
   - any other item visible to `diverId` holding `passportId`, whatever its
     status, means no write;
   - otherwise the attribute is written through the equipment repository's
     attribute path, and when the target is a tank the fills already stored
     under that passport id are relinked to it.
   `UddfEntityImporter` runs adoption after equipment and before service
   records and fills, for every selected item with a `passportId` that
   resolved to a row: one it created, or a duplicate the wizard matched to an
   existing row. A refusal is logged at info level; an exception is logged
   and the import continues. Adoption needs the passport repository already
   in `ImportRepositories`; without it the step is skipped.
4. **Fills.** Unchanged: `CsvFillImporter.importRows` keeps ids, skips known
   and deleted ids, and links to the diver's tank holding the passport id,
   which step 3 has just restored.

## 6. Testing

Each test is written red first.

- `uddf_fill_writers_test.dart`: element shape, newest first, optional
  elements omitted, reserved fields absent, no element for an empty list,
  SI conversion, rounding (32 % to 0.32 and back to exactly 32.0;
  22.0 degrees C through kelvin), the `fill_` prefix stripped, and a fill
  missing a required field dropped.
- Equipment item: `<passportid>` written when held, absent otherwise, and
  parsed into `passportId`.
- `cylinder_passport_repository` adoption tests: writes into an empty slot
  and relinks orphan fills for a tank; refuses when the target has its own
  id; refuses when another visible item (in service or retired) holds it;
  does not relink for a non-tank.
- Wizard-shaped round trip into a clean database (`UddfImportParser`, the
  payload's entity lists, `UddfEntityImporter` with real repositories):
  fills return with identical ids, linked to the restored cylinder; a second
  import adds nothing; a fill deleted here is not resurrected; an id held by
  another visible item is not adopted and the fill links to that holder; an
  item with its own tag keeps it.
- Service records: a wizard-shaped UDDF round trip restores them (red
  today).
- `export_uddf_fills_test.dart`, modelled on
  `export_uddf_site_features_test.dart`: the real export provider passes the
  active diver's visible fills, and not another diver's unlinked fills, on
  both the share and save paths.

## 7. Documentation

- `docs/guide/import-export.md`: a UDDF backup carries cylinder fills and
  passport ids.
- Passports spec: a dated "Decided" note under the section 4 non-goal and
  the section 18 follow-up, pointing here.

## 8. Out of scope

- A passport id column on the equipment CSV.
- Fills in the dives-only UDDF export.
- Any UI, schema or sync change.
