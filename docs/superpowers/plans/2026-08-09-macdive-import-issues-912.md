# MacDive Import Issue Sweep (#912)

**Goal:** Fix the MacDive import problems reported by two ScubaBoard users (issue #912).

**Source reports:**
- Manatee Diver — profiles not differentiated, dive profiles missing, weird pressure, equipment service lists missing, inactive gear not retired, certifications missing.
- glazerama — photos, weight-as-note, dive type, operator not mapped to dive center, trips spanning dive centers, whole-degree Celsius.

**Reference data:** `scripts/sample_data/MacDive.sqlite` (540 dives, glazerama's own logbook) paired with `Apr 4 no iPad Mini sync.xml` and `Apr 4 no iPad sync.uddf`.

---

## Headline finding: MacDive SQLite profiles ARE decodable

`docs/import-formats/macdive-zsamples.md` currently records a NO-GO on `ZRAWDATA`. **That conclusion was wrong.** `ZRAWDATA` is the raw Shearwater download stream stored *still compressed*, as the device emits it when `shearwater_common_download()` runs with `compression=1`. Two passes recover Petrel Native Format:

1. **9-bit RLE**, MSB-first over the whole blob. Bit `0x100` set → emit `value & 0xFF` as a literal. `value == 0` → end of stream. Else → emit `value` zero bytes.
2. **32-byte XOR delta**, in place: `for i in 32..n-1: data[i] ^= data[i-32]`.

Both are vendored at `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_common.c:103` and `:149`, but are `static` and therefore not callable from the plugin — port to Dart.

Verified against the paired XML ground truth: **266/267 dives** match the XML depth series sample-for-sample; 0 fail PNF structure. The units flag is byte 8 of opening record `0x10` (`1` = imperial); **40 of 267 dives are metric**, so unit handling is mandatory. `ZSAMPLES` remains encrypted but is redundant — `ZRAWDATA` covers every Shearwater dive.

---

## Scope decisions (confirmed with maintainer)

| Item | Decision |
|---|---|
| Photos (glazerama a) | **Separate PR.** Revise `docs/superpowers/plans/2026-04-21-macdive-photo-import.md` first: it assumes `ZDIVEIMAGE.ZPATH` is an absolute path, but the real DB stores a bare filename inside MacDive's own image folder. |
| "Profiles" (Manatee Diver 1) | **Both readings.** Import `ZDIVELOG` static membership as tags, *and* read `ZDIVER` so multi-diver databases are separated rather than silently merged. |
| Temperature precision | 1 decimal for both units, trailing `.0` trimmed. |
| Trips ↔ dive centers (glazerama d) | No schema change. A Trip already spans centers because `diveCenterId` lives on the dive, not the trip. Answer in the issue thread. |

---

## Phase 1 — Shearwater `ZRAWDATA` profile decode

Fixes: dive profiles missing; per-sample tank pressure.

- Create `lib/features/universal_import/data/services/shearwater_raw_decompressor.dart` — `decompressLre` + `xorDelta32`, plus a `decompress()` convenience returning `null` when the bit count is not a multiple of 9.
- `macdive_dive_mapper.dart`: `toPayload` becomes `Future<ImportPayload>`. For dives with non-empty `rawDataBlob`, decompress and call `DiveComputerHostApi().parseRawDiveData(vendor, product, 0, buf)`, mirroring `shearwater_dive_mapper.mapDive` (rethrow `MissingPluginException` / `UNSUPPORTED`, collect data errors as warnings, degrade to metadata-only).
- Vendor/product from `ZCOMPUTER` by stripping the `Shearwater ` prefix and reusing `ShearwaterFilenameParser.vendorProduct`.
- Replace the blanket "cannot decode" warning with one that fires only for dives that carry `ZSAMPLES` but no `ZRAWDATA` (non-Shearwater computers).
- Emit `allTankPressures` per sample so `_storeTankPressures` populates tank pressure.
- Update `docs/import-formats/macdive-zsamples.md` — the NO-GO section is now historical.

## Second finding: MacDive's Core Data store is mixed-unit

"The pressure data is super weird" is a units bug, and a two-sided one.

MacDive's SQLite store does **not** use one unit system:

| Column | Stored as |
|---|---|
| `ZMAXDEPTH`, `ZAVERAGEDEPTH` | metres (SI), always |
| `ZTEMPLOW`, `ZTEMPHIGH`, `ZAIRTEMP` | Celsius (SI), always |
| `ZTANKANDGAS.ZAIRSTART` / `ZAIREND` | the diver's **display** unit |
| `ZTANK.ZSIZE`, `ZTANK.ZWORKINGPRESSURE` | the diver's **display** unit |
| `ZDIVE.ZWEIGHT` | the diver's **display** unit |

Established by pairing the reference library against MacDive's own Imperial XML export of the same data: depth ratios are 3.2808 across 527 and 349 dives, `ZTEMPLOW` is the exact Celsius of the exported Fahrenheit across 513 dives, and pressures and cylinder sizes match the Imperial export 1:1 across 313–328 dives.

The importer applied a single system to everything, taken from `ZMETADATA.ZALL` where `ZIDENTIFIER = 'SystemOfUnits'` — **a row the reference library does not contain**. That fell through to `unknown`, i.e. passthrough, so 3118 psi imported as 3118 bar and an 80 cft AL80 became an 80-litre cylinder (also wrecking SAC). Had the row been present and said Imperial, the mirror bug would have hit instead: a 25.4 m dive converted as feet becomes 7.7 m.

Fix: `MacDiveUnitConverter.coreData()` leaves depth and temperature alone, and `MacDiveUnitInference` recovers the display unit from stored magnitudes when MacDive omits its declaration — cylinder pressures are ~200–300 bar or ~2400–3500 psi, more than an order of magnitude apart.

## Phase 2 — Dive-level mapper gaps

- **Weight.** `uddf_entity_importer.dart:1283` appends `weightUsed` to notes. Build a `DiveWeight` row instead (and stop polluting notes). Affects MacDive, UDDF, and `uddf_import_service`.
- **Dive types.** XML: `MacDiveXmlDive.diveTypes` is parsed then dropped. SQLite: read `ZDIVETYPE` + `Z_5RELATIONSHIPDIVETYPES`. Emit `diveTypeIds` plus `ImportEntityType.diveTypes` entries so unknown MacDive types are created as custom types.
- **Dive centers.** Dedupe `ZDIVEOPERATOR` into `ImportEntityType.diveCenters` entries and emit `diveCenterRef` per dive. Keep the existing free-text `diveOperator` column populated.

## Phase 3 — Equipment

- `ZGEARITEM.ZDISABLED` → `EquipmentStatus.retired` + `isActive: false`.
- `ZSERVICERECORD` → new `ImportEntityType.serviceRecords` + `_importServiceRecords` in `uddf_entity_importer`, resolving `ZRELATIONSHIPGEARITEM` (Z_PK) through the gear map to `equipmentIdMapping`.
- Fix the key mismatches that silently drop gear data: mapper emits `price`/`nextServiceDate`/`weight`/`sourceUuid`; importer reads `purchasePrice`/`lastServiceDate` and ignores the rest.
- Map MacDive type strings (`"BCD - Wing"`, `"Regulator"`) onto `EquipmentType` instead of falling through to `other`.

## Phase 4 — Certifications

- Emit `ZCERTIFICATION` rows as `ImportEntityType.certifications` (`_importCertifications` already exists).
- Map `ZAGENCY` strings onto `CertificationAgency` — `_parseCertificationAgency` currently defaults any unknown string to PADI, which would mislabel the NAUI card in the sample DB.

## Phase 5 — Divers and logbook groups

- Read `ZDIVER` + `ZDIVE.ZRELATIONSHIPDIVER`. When a database holds more than one diver, surface it rather than merging silently.
- Read `ZDIVELOG`; import static membership as tags. Smart groups carry an `NSPredicate` blob and are skipped with a warning.

## Phase 6 — Temperature display

- `unit_formatter.formatTemperature` — 1 decimal, trailing `.0` trimmed, both units.

---

## Verification

- `flutter analyze`, `dart format .`, `flutter test`.
- Real-data tests stay opt-in behind `MACDIVE_SQLITE_REAL_SAMPLE_PATH` (`@Tags(['real-data'])`), per existing convention — but Phase 1 gets a **byte-level unit test on a real captured blob** so the ZRAWDATA regression cannot repeat. The 2026-04 failure happened precisely because tests mocked `parseFn` against a synthetic fixture.
