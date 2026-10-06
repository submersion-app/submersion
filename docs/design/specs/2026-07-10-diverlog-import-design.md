# Aqualung DiverLog+ / DiverLog Import (DAN DL7)

**Date:** 2026-07-10
**Status:** Approved

## Summary

Import dive data exported from the Aqualung DiverLog+ (mobile) and DiverLog (desktop) applications by implementing a DAN DL7 (`.zxu` / `.zxl`) parser in the universal import engine, including the proprietary `ZAR{<AQUALUNG>...}` block that carries all the rich data (GPS and site names, tank pressures and gas mixes, ratings, dive stats), plus direct ingestion of the DiveCloud export ZIP with automatic photo attachment.

Parsing the Aqualung ZAR block is the differentiator: Subsurface deliberately skips it, so migrating users lose sites, gas, and consumption data there. Submersion will import DiverLog data more completely than any other consumer of this format.

## Background: the DiverLog export landscape

DiverLog and DiverLog+ are Pelagic Pressure Systems products (the OEM behind Aqualung, Apeks, Oceanic, Sherwood, Aeris, and Hollis computers). Research findings that constrain this design:

- **Mobile DiverLog+ has no in-app file export.** The only data path out is: sync to the DiveCloud web service, log into divecloud.net in a browser, select dives, Export. This produces a **ZIP of per-dive `.zxu` files plus attached photos**, with files named `ProductCode_Serial_YYYYMMDDhhmmss_DiveNo.zxu`.
- **Desktop DiverLog "Full"** exports `.zxu` directly (Export Dive Data, DL7 Standard) but is discontinued and can no longer be purchased. The still-downloadable **Lite versions cannot export.**
- The desktop databases (`.db3` SQLite, `.dlg` renamed Access) are **encrypted**; no public keys or schemas exist. Database extraction is rejected as an approach.
- Therefore **DAN DL7 `.zxu` is the single practical interchange format**, and the DiveCloud ZIP is the artifact nearly every migrating user will hold.

DL7 is a 2006 DAN standard modeled on HL7: pipe-delimited segments terminated by CR. A `.zxu` file contains `FSH` (file header), `ZRH` (record header with unit declarations), `ZAR{...}` (application-reserved block), then per dive `ZDH` (dive header), `ZDP{...}` (profile rows), `ZDT` (dive trailer). `.zxl` adds diver-demographic segments (`ZPD`, `ZPA`, `ZDD`, `ZSR`). DiverLog+ writes all rich data into `ZAR{<AQUALUNG>...}` as pseudo-XML tags (`LOCATION`, `TANK`, `DIVESTATS`, `DUID`, `PDC_MODEL`, per-sample arrays).

## Requirements

1. **Parse any spec-conformant DL7 file** (`.zxu`, `.zxl`): standard segments yield dives with timestamps, depth/temperature profiles, per-sample tank pressure, PO2, ceiling, CNS, violation events, and gas switches.
2. **Parse the Aqualung ZAR dialect** when present: site name and GPS, city/state/country, tank details (cylinder size, working/start/end pressure, FO2), dive number, duration, surface interval, min temperature, rating, title, dive computer model/serial/firmware, and the `DUID` unique dive ID.
3. **Import everything the format carries** (user decision): dives, profiles, tanks, sites, ratings, notes, computer identity, photos.
4. **Accept the DiveCloud export ZIP directly**: member `.zxu` files fan out into the existing bulk import pipeline; photos are matched to dives and attached automatically.
5. **Automatic format detection** via content sniffing; users never select a format manually.
6. **Duplicate safety**: exact re-import dedup via `DUID`; fuzzy cross-source dedup (e.g. dives already BLE-downloaded from the same computer) via the existing `DiveMatcher`, with computer serial enabling multi-computer consolidation.
7. **Fill the existing scaffold**: the `danDl7` format enum, detector markers, and `SourceApp.dan` entry already exist but dead-end at `PlaceholderParser`; this feature makes them real.

### Non-goals

- Reading DiverLog desktop databases (`.db3`, `.dlg`) — encrypted, no public schema. User guidance points Windows/Mac Lite users at the Wi-Fi-sync-to-mobile → DiveCloud path instead.
- DL7 export (write side) — remains deferred.
- DiveCloud API integration — export is a manual browser step; there is no public API.

## Architecture

One new parser (five files), four registration touches (including the format-detector fix), and two intake-layer services for ZIP handling. All persistence is handled by the existing `UddfEntityImporter` with zero format-specific changes; the parser's job is to emit `ImportPayload` maps with the established keys.

### Key components

| Component | Location | Responsibility |
|-----------|----------|----------------|
| `DanDl7Parser` | `lib/features/universal_import/data/parsers/dan_dl7_import_parser.dart` | `ImportParser` implementation; orchestrates reader, units, dialect; emits `ImportPayload` |
| `Dl7Reader` | `lib/features/universal_import/data/parsers/dl7/dl7_reader.dart` | Segment scanner: pipe-field tokenizer; CR/CRLF/LF tolerant; handles `ZDP{...}` / `ZAR{...}` multi-line blocks and single-line header variants |
| `Dl7Document` | `lib/features/universal_import/data/parsers/dl7/dl7_document.dart` | Typed segment model: `Fsh`, `Zrh`, `Zdh`, `ZdpRow`, `Zdt`, `ZarBlock` |
| `Dl7Units` | `lib/features/universal_import/data/parsers/dl7/dl7_units.dart` | ZRH unit codes to SI: depth `MSWG`/`FSWG`, temp `C`/`F`, pressure `BAR`/`PSI`/`PSIA`, volume `L`/`CF`; `ThFt` altitude code doubles as an imperial hint |
| `AqualungZarDialect` | `lib/features/universal_import/data/parsers/dl7/aqualung_zar_dialect.dart` | Parses `ZAR{<AQUALUNG>...}` pseudo-XML: bracket-aware value extraction (values contain commas and `¶` separators) |
| `ZipExpansionService` | `lib/features/universal_import/data/services/zip_expansion_service.dart` | Detects ZIP at file intake, expands to a session temp dir, substitutes member files into the selection |
| `DiveCloudZipReader` | `lib/features/universal_import/data/services/divecloud_zip_reader.dart` | Classifies ZIP entries: `.zxu`/`.zxl` files vs photos; matches photos to dives by DUID (folder name, then filename prefix); reports unmatched photos |
| Photo attachment hook | `lib/features/import_wizard/data/adapters/universal_adapter.dart` | Post-commit: uses the entity importer's new `uddfId -> created diveId` map to call `MediaImportService.importLocalFileForDive` per matched photo |

### Registration points

1. `import_enums.dart` — mark `danDl7` supported; add `SourceApp.diverLog` ("DiverLog+ / DiverLog") with DiveCloud export instructions; update `SourceApp.dan` instructions (currently say DL7 support is "planned"); add to `SourceOverrideOption.supported`.
2. `format_detector.dart` — add a plain-text branch: content beginning with `FSH|` (after optional BOM/whitespace) detects as `danDl7` with high confidence. The existing XML-marker branch is kept but is insufficient: real `.zxu` files are not XML, so the scaffold as shipped can never match one.
3. `parser_registry.dart` — route `danDl7` to `DanDl7Parser`, retiring that `PlaceholderParser` case.
4. `pubspec.yaml` — promote `archive` from transitive to direct dependency.

### Dialect layering

`DanDl7Parser` first parses standard segments (usable output on its own), then inspects the ZAR block. If it contains `<AQUALUNG>`, `AqualungZarDialect` enriches the payload. Unknown ZAR content (e.g. DiveLogDT's plain-text ZAR) is ignored gracefully. This mirrors the UDDF MacDive dialect pattern. Multi-dive files (repeated ZDH/ZDP/ZDT groups) produce one payload dive each. `.zxl` demographic segments are parsed leniently: extract what maps, never fail on extras.

## Data mapping

All values convert to the same SI units the other parsers emit.

### Standard segments

| DL7 source | Payload destination | Notes |
|------------|---------------------|-------|
| ZDH field 5 (leave-surface `YYYYMMDDHHMMSS`) | `dateTime` | Wall-clock-as-UTC house convention; FSH timezone offsets ignored |
| ZDH field 6 (air temp) | `airTemperature` | Per ZRH temp unit |
| ZDH field 3 (record type `I`/`M`) | metadata | `M` = manually logged, profile optional |
| ZDP col 1 (time, decimal minutes) | profile sample time | `0.50` = 30 s. Integer-only time columns are treated as seconds (Subsurface-compatible heuristic). Sample interval is derived from time deltas, never from ZDH field 4, which lies in real files (`Q1S` declared, 30 s actual) |
| ZDP col 2 (depth) | profile depth | Per ZRH depth unit |
| ZDP col 3 (gas switch: `1` = air, `2.xy` = nitrox xy% O2) | gas switch events + tank gas mixes | |
| ZDP col 4 (PO2), col 7 (ceiling), col 13 (CNS) | profile sample fields | Mapped where the profile schema has columns |
| ZDP col 5 / col 6 (ascent / deco violation `T`/`F`) | dive events | |
| ZDP col 8 (water temp, sparse) | profile temperature | Carried only on samples where present |
| ZDP col 10 (main cylinder pressure) | per-sample tank pressure | |
| ZDT field 3 (max depth) | `maxDepth` | ZAR DIVESTATS MAXDEPTH preferred when present (more precise) |
| ZDT field 4 (reach-surface timestamp) | duration derivation | DIVESTATS EDT preferred when present |
| ZDT field 5 (min water temp) | not trusted | Real DiverLog files write `0.000000`; min temp comes from DIVESTATS MINTEMP or profile minimum |

### Aqualung ZAR block

| ZAR content | Destination | Notes |
|-------------|-------------|-------|
| `DUID` | `sourceUuid` | Exact-match dedup on re-import |
| `LOCATION`: `GPS=[lat,lon]`, `LOCNAME`/`DIVESITE`, `CITY`, `STATE/PROVINCE`, `COUNTRY` | site entity + dive entry coordinates | Feeds existing site dedup (name + 100 m proximity) and the post-import site matcher |
| `PDC_MODEL`, `PDC_SERIAL`, `PDC_FIRMWARE` | dive computer identity | Serial ties imports to the same physical computer for consolidation with prior BLE downloads |
| `DIVESTATS`: `DIVENO`, `EDT`, `SI`, `MAXDEPTH`, `MINTEMP`, `PO2`, `MODE`, `DECO`/`VIOL`, `MANUALDIVE` | dive number, duration, surface interval, min temp, max PO2, mode/flags | Preferred over the less reliable standard-segment equivalents |
| `TANK` entries: `NUMBER`, `CYLNAME`, `CYLSIZE`, `WORKINGPRESSURE`, `STARTPRESSURE`, `ENDPRESSURE`, `FO2`, `AVGDEPTH`, `SAC` | `tanks` list | `GEAR_UNITS` disambiguates cu ft vs L; avg depth mapped to the dive |
| `RATING` | dive rating | |
| `TITLE` | dive title/notes | |
| `DIVER_NAME` | metadata only | It is the log owner, not a buddy |
| Per-sample arrays: `DECOTIME`, `DTR`, `ARBG`, `TLBG`, `O2BG`, `ATR`, `VSTATUS` | profile deco/NDL fields where the schema has columns | Index-aligned with ZDP samples; extras dropped silently |

## ZIP container ingestion and photos

ZIP handling lives at the file-intake layer, not in the parser: a ZIP is a container whose members each flow through normal detection.

- **Expansion**: when any picked/dropped/shared file sniffs as ZIP (`PK\x03\x04`), `ZipExpansionService` expands it to a session temp directory and substitutes member files into the selection before `_loadBatchFromPaths` runs. A DiveCloud ZIP of N dives becomes an N-file batch in the existing #501 bulk pipeline (per-file payload namespacing, intra-batch dedup, triage UI all reused). A single-member ZIP flows down the single-file path.
- **Filtering**: `__MACOSX/`, hidden files, and non-`.zxu`/`.zxl`/non-image entries are skipped with a count surfaced in the triage step. Nested folders are walked.
- **Photo matching**: `DiveCloudZipReader` matches image entries (jpg/jpeg/png/heic) to dives by the DUID join key: per-dive folder name match first, filename-prefix match as fallback. Unmatched photos produce a visible `ImportWarning` listing the skipped files; photos are never silently lost.
- **Attachment timing**: photos attach after persistence. `UddfEntityImporter`'s result is extended with a `uddfId -> created diveId` map; `UniversalAdapter` then calls `MediaImportService.importLocalFileForDive(file, diveId:)` (the existing OCR-flow hook) per matched photo of each newly created dive. Photos are not attached to dives the user skipped as duplicates. The temp extraction directory is deleted afterward.
- **Safety**: password-protected ZIPs produce a clear error; a total-uncompressed-size cap guards against zip bombs; an archive that is empty after filtering reports "no importable files found".

## UI, guidance, and platform integration

No new wizard steps; the unified import wizard handles everything.

- `SourceApp.diverLog` export instructions walk the DiveCloud path: sync in DiverLog+, log into divecloud.net, select dives, Export, then import the downloaded ZIP into Submersion. A note covers desktop Full's Export Dive Data for those who still have it.
- Detection is automatic; `danDl7` also joins the manual source-override dropdown.
- File associations: `.zxu`/`.zxl` document types added to iOS and macOS Info.plists so share-to-Submersion works. ZIP is deliberately not associated (too generic); ZIPs enter via picker or drag-and-drop.
- Docs: user-guide page for the DiverLog migration path. New UI strings are translated into all 10 non-English locales.

## Error handling and edge cases

- **Per-dive isolation**: a malformed segment skips that dive with an `ImportWarning` naming the file and reason; the rest of the file and batch continue.
- **Missing ZDP**: header/stats-only dives import without profiles.
- **Reader tolerance**: CR, CRLF, and LF; single-line FSH/ZRH variants; UTF-8 with lenient decoding (`¶` separators, accented site names).
- **Distrust declared metadata**: interval from time deltas; min temp from DIVESTATS/profile; model from ZAR when ZRH's model code is empty.
- **Duplicates**: `DUID -> sourceUuid` catches exact re-imports. The fuzzy `DiveMatcher` time-gate catches cross-source overlap (same dives previously BLE-downloaded from the computer); `PDC_SERIAL` lets consolidation recognize the same physical computer.
- **Non-Aqualung ZAR**: standard-segment import still succeeds.

## Testing

TDD, fixtures first. Research artifacts are staged (untracked) under `test/features/universal_import/data/parsers/fixtures/dl7/`; before committing any third-party file, verify license compatibility, and prefer regenerating equivalent synthetic fixtures where provenance is unclear.

| Fixture | Locks down |
|---------|------------|
| Real DiverLog+ i330R export (`diverlog_real.zxu`, from vche/divelog_convert) | Full ZAR dialect: GPS/site, tanks/FO2, rating, DUID, 30 s interval derivation, bogus-min-temp override |
| Subsurface synthetic `DL7.zxu` | Multi-dive files, integer-seconds time heuristic |
| PyDL7/DiveLogDT sample (`pydl7_sample.zxu`) | Non-Aqualung ZAR graceful handling, single-line headers, temp+pressure profile columns |
| Spec-example file (imperial: `ThFt`/`F`/`PSIA`/`CF`), hand-built from the DL7 spec | Imperial-to-SI unit conversion |
| Synthetic DiveCloud ZIP (constructed) | Expansion, junk filtering, photo-to-DUID matching, unmatched-photo warnings |

Test layers mirror existing suites: `format_detector_test` additions (`FSH|` prefix, ZIP magic, pipe-delimited text that is not DL7); parser unit tests per segment, dialect, and unit table; `ZipExpansionService` and `DiveCloudZipReader` tests; an end-to-end integration test (ZIP to batch parse to merge to dedup to persist to photo attach with mocked media service) following the `bulk_import_integration_test` pattern.

## Phasing

1. **Phase 1 — parser**: `Dl7Reader`/`Dl7Document`/`Dl7Units`/`AqualungZarDialect`/`DanDl7Parser`, detector fix, registry and enum wiring, fixtures and tests. Single and multi-select `.zxu` import works end-to-end.
2. **Phase 2 — container and polish**: `ZipExpansionService`, `DiveCloudZipReader`, photo attachment, `SourceApp.diverLog` guidance, file associations, docs, l10n.

## Open risks

- **DiveCloud ZIP internal layout is undocumented.** The photo-matching heuristics are validated against a real ZIP as soon as one is available; the uncertainty is isolated inside `DiveCloudZipReader`. De-risk: Eric attempts DiveCloud signup early (free tier covers 10 dives).
- **DiveCloud signup itself is reportedly flaky** (March 2025 report: verification emails never arrive, support unresponsive). Worst case the feature ships on the bundled fixtures and serves desktop-Full users immediately; Eric's own historical data waits on Pelagic support or direct computer re-download.
- **ZAR field drift**: DiveCloud exports and desktop exports show slightly different LOCATION/TANK field sets (`COUNTRY` vs `DIVESITE` presence). The dialect parser treats every field as optional.

## References

- DL7 spec: "DL7 Standard", Petar J. Denoble, DAN, 2006-07-27 (copy in PyDL7 repo, `docs/reference/dl7-specification.doc`)
- Real DiverLog+ export and ZAR reference parser: github.com/vche/divelog_convert (`data/7168_13960_20220224130600_1.zxu`, `formaters/dl7.py`)
- Subsurface DL7 handling: `core/import-csv.cpp` (`parse_dan_format`), `desktop-widgets/divelogimportdialog.cpp` (DL7 preset), `xslt/csv2xml.xslt`, test pair `dives/DL7.zxu`/`dives/DL7.xml`
- PyDL7: github.com/johnstonskj/PyDL7 (archived)
- DiveCloud export flow: divecloud.net/help; gatetoadventures.com i300C walkthrough
- Export-capability sourcing: ediverlog.com FAQ and how-to pages; ScubaBoard and Subsurface mailing-list threads on DiverLog migration
