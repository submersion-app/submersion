# Single Import Entry Point

## Summary

Remove redundant format-specific import entries (CSV, UDDF, FIT) from the Transfer
page, leaving a single "File Import" entry point that auto-detects file format.
The universal adapter already delegates to format-specific adapters internally, so
the user-facing format shortcuts provide no functional benefit.

## Motivation

The Transfer page currently shows two ways to import files:

1. "Auto-Detect Import" (universal) -- auto-detects format, supports all file types
2. "By Format" section -- separate entries for CSV, UDDF, and FIT

Both paths produce identical results. The redundancy adds visual clutter and
decision fatigue ("which one do I pick?") with no upside.

## Design

### Approach

Remove format-specific UI paths and routes. Keep all adapters as internal
implementation. Rename "Auto-Detect Import" to "File Import".

### Changes

#### 1. Transfer page UI (`transfer_page.dart`)

- Remove the "By Format" section header and card (CSV, UDDF, FIT entries)
- Remove the legacy `_handleImport` method (only used by the CSV "By Format" entry)
- Rename "Auto-Detect Import" to "File Import"
- Update subtitle to: "UDDF, Subsurface, CSV, FIT, and more"

#### 2. Router (`app_router.dart`)

- Remove the `fit-import` route and `_FitImportWizardRoute` wrapper class
- Remove the `uddf-import` route and `_UddfImportWizardRoute` wrapper class
- Keep the `import-wizard` route as the sole file import path

#### 3. Localization strings

- Remove: `transfer_import_byFormatHeader`, `transfer_import_csvTitle`,
  `transfer_import_csvSubtitle`, `transfer_import_uddfTitle`,
  `transfer_import_uddfSubtitle`, `transfer_import_fitTitle`,
  `transfer_import_fitSubtitle`
- Rename: `transfer_import_autoDetectTitle` -> `transfer_import_fileImportTitle`
  (value: "File Import")
- Update: `transfer_import_autoDetectSubtitle` -> `transfer_import_fileImportSubtitle`
  (value: "UDDF, Subsurface, CSV, FIT, and more")
- Update: `transfer_import_autoDetectSemanticLabel` ->
  `transfer_import_fileImportSemanticLabel`

#### 4. What stays untouched

- All adapters (`UddfAdapter`, `FitAdapter`, `UniversalAdapter`,
  `HealthKitAdapter`, `DiveComputerAdapter`) -- internal implementation
- The unified import wizard shell (`UnifiedImportWizard`)
- HealthKit and Dive Computer import paths -- not file-based imports
- All parsing and import logic
- The source confirmation step in the universal flow (user still sees detected
  format and can override)

### Estimated scope

- ~40 lines removed from `_ImportSectionContent` (the "By Format" card)
- ~55 lines removed for `_handleImport` method
- 2 routes + wrapper classes removed from `app_router.dart`
- L10n string cleanup across ARB files
