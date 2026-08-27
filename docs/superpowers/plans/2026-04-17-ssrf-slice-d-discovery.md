# Slice D Discovery

## Date
2026-04-17

## Importer key inventory (from uddf_entity_importer.dart)

### Already on DivesCompanion (no change needed)
- `surfacePressure` (line 1128)
- `gradientFactorLow` (line 1130)
- `gradientFactorHigh` (line 1131)
- `diveComputerModel` (line 1132)
- `diveComputerSerial` (line 1133)
- `diveComputerFirmware` (line 1134)

### Already on DiveDataSourcesCompanion (no change needed)
- `computerModel` (line 1466)
- `computerSerial` (line 1467)

### Missing, Task 4 will add
- `DivesCompanion.decoAlgorithm` (absent — Task 4 adds)
- `DiveDataSourcesCompanion.decoAlgorithm` (absent — Task 4 adds)
- `DiveDataSourcesCompanion.gradientFactorLow` (absent — Task 4 adds)
- `DiveDataSourcesCompanion.gradientFactorHigh` (absent — Task 4 adds)

## Parser current state
- Zero references to Slice D keys in `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` (confirmed at line search) — all parser-side work is new.

## Fixture content for end-to-end test (dual-cylinder.ssrf, lines 7-20)
- divecomputer model: `Shearwater Peregrine`
- Serial: `98d09a47`
- FW Version: `86`
- Deco model: `GF 40/85`
- Surface pressure: `1.012 bar`

## Notes / surprises
None. All findings align with plan pre-findings:
- Importer has full DivesCompanion coverage for dive-level metadata
- DiveDataSourcesCompanion is missing decoAlgorithm and the gradient factor fields that Task 4 will add
- Parser has no existing extraction logic — all Task 5 parser work is greenfield
- Fixture has all required extradata keys and surface pressure in the expected format
