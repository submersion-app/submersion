# Single Import Entry Point Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove redundant format-specific import entries from the Transfer page, leaving a single "File Import" entry point.

**Architecture:** This is a removal/cleanup change. The unified import wizard architecture stays intact -- we're just removing duplicate UI paths (routes, menu items, wrapper classes) that expose format-specific adapters the universal adapter already delegates to internally.

**Tech Stack:** Flutter, go_router, Flutter l10n (ARB files)

**Spec:** `docs/superpowers/specs/2026-03-24-single-import-entry-point-design.md`

---

### Task 1: Remove "By Format" UI section from Transfer page

**Files:**
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:277-318`

- [ ] **Step 1: Remove the "By Format" section**

In `_ImportSectionContent.build()`, remove lines 277-318 (the spacer, header, and card with CSV/UDDF/FIT entries). The build method should go from the closing `)` of the Universal Import card (line 276) directly to the info card:

```dart
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
```

- [ ] **Step 2: Remove the `_handleImport` method**

Delete the entire `_handleImport` method (lines 330-387). It was only called by the CSV "By Format" entry.

- [ ] **Step 3: Verify the build compiles**

Run: `flutter analyze lib/features/transfer/presentation/pages/transfer_page.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/features/transfer/presentation/pages/transfer_page.dart
git commit -m "refactor: remove 'By Format' import section from Transfer page"
```

---

### Task 2: Update localization strings

**Files:**
- Modify: All 10 ARB files in `lib/l10n/arb/`:
  `app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`,
  `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`

- [ ] **Step 1: Update English ARB file (`app_en.arb`)**

Remove these keys (and any `@key` metadata entries):
- `transfer_import_byFormatHeader`
- `transfer_import_csvTitle`
- `transfer_import_csvSubtitle`
- `transfer_import_uddfTitle`
- `transfer_import_uddfSubtitle`
- `transfer_import_fitTitle`
- `transfer_import_fitSubtitle`
- `transfer_import_operationCompleted`
- `transfer_import_operationFailed`

Rename these keys (keep values for now, update content):
- `transfer_import_autoDetectTitle` -> `transfer_import_fileImportTitle` with value `"File Import"`
- `transfer_import_autoDetectSubtitle` -> `transfer_import_fileImportSubtitle` with value `"UDDF, Subsurface, CSV, FIT, and more"`
- `transfer_import_autoDetectSemanticLabel` -> `transfer_import_fileImportSemanticLabel` with value `"Import dive data from file"`

- [ ] **Step 2: Update all non-English ARB files**

For each of the 9 non-English ARB files, apply the same key removals and renames. For renamed keys, keep the translated values but update to match the new meaning where the translation clearly refers to "auto-detect":
- `fileImportTitle` -> translate "File Import" appropriately
- `fileImportSubtitle` -> keep format list, remove "auto-detect" reference
- `fileImportSemanticLabel` -> translate "Import dive data from file"

- [ ] **Step 3: Regenerate l10n**

Run: `flutter gen-l10n`
Run: `flutter analyze lib/l10n/`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "refactor: update l10n strings for single import entry point"
```

---

### Task 3: Update primary import card to "File Import"

**Files:**
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:227,242,252,258`

- [ ] **Step 1: Update icon**

Change `Icons.auto_fix_high` (line 242) to `Icons.upload_file`.

- [ ] **Step 2: Update l10n references in the widget**

Change these three l10n key references:
- Line 227: `transfer_import_autoDetectSemanticLabel` -> `transfer_import_fileImportSemanticLabel`
- Line 252: `transfer_import_autoDetectTitle` -> `transfer_import_fileImportTitle`
- Line 258: `transfer_import_autoDetectSubtitle` -> `transfer_import_fileImportSubtitle`

- [ ] **Step 3: Format and verify**

Run: `dart format lib/features/transfer/presentation/pages/transfer_page.dart`
Run: `flutter analyze lib/features/transfer/presentation/pages/transfer_page.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/features/transfer/presentation/pages/transfer_page.dart
git commit -m "refactor: rename import card to 'File Import' with upload icon"
```

---

### Task 4: Remove format-specific routes and wrapper classes

**Files:**
- Modify: `lib/core/router/app_router.dart:726-735` (routes), `1024-1141` (wrapper classes)

- [ ] **Step 1: Remove the two route entries**

In the `/transfer` route's `routes:` list (lines 725-742), remove the `fit-import` GoRoute (lines 726-730) and the `uddf-import` GoRoute (lines 731-735). Keep the `import-wizard` GoRoute.

After removal, the routes list should contain only:
```dart
            routes: [
              GoRoute(
                path: 'import-wizard',
                name: 'universalImport',
                builder: (context, state) =>
                    const _UniversalImportWizardRoute(),
              ),
            ],
```

- [ ] **Step 2: Remove the `_FitImportWizardRoute` class**

Delete lines 1024-1044 (the `_FitImportWizardRoute` class and its doc comment).

- [ ] **Step 3: Remove the `_UddfImportWizardRoute` class**

Delete lines 1046-1141 (the `_UddfImportWizardRoute` class and its doc comments).

- [ ] **Step 4: Clean up unused imports**

Run `flutter analyze` to identify unused imports. The following imports are likely to become unused after removing the two wrapper classes (verify with analyze output before removing):

- `fit_adapter.dart` (line 14)
- `uddf_adapter.dart` (line 16)
- `uddf_duplicate_checker.dart` (line 22)
- `uddf_entity_importer.dart` (line 23)
- `uddf_parser_service.dart` (line 24)
- `default_tank_preset_resolver.dart` (line 32)
- Various provider imports only used in the UDDF wrapper (buddy, certification,
  course, dive_center, site, dive_type, equipment, equipment_set, tag,
  tank_preset, trip providers; export_providers; settings_providers)

Note: Do NOT remove `dive_matcher.dart` (line 10) -- it is still used by
`_HealthKitImportWizardRoute`.

Remove only imports that `flutter analyze` flags as unused.

- [ ] **Step 5: Format and verify**

Run: `dart format lib/core/router/app_router.dart`
Run: `flutter analyze lib/core/router/app_router.dart`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "refactor: remove format-specific import routes and wrapper classes"
```

---

### Task 5: Update navigation documentation

**Files:**
- Modify: `docs/developer/navigation.md:267-268`

- [ ] **Step 1: Remove route entries**

Delete these two lines from the Transfer routes table:
```
| `/transfer/fit-import` | fitImport | FitImportPage |
| `/transfer/uddf-import` | uddfImport | UddfImportPage |
```

- [ ] **Step 2: Commit**

```bash
git add docs/developer/navigation.md
git commit -m "docs: remove format-specific import routes from navigation docs"
```

---

### Task 6: Full verification

- [ ] **Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: Run formatter**

Run: `dart format lib/ test/`
Expected: No formatting changes needed

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: All tests pass. If any tests reference the removed routes (`/transfer/uddf-import`, `/transfer/fit-import`) or removed l10n keys, update them.

- [ ] **Step 4: Fix any test failures**

If tests fail due to removed routes or l10n keys, update the test files accordingly (remove references to format-specific import navigation, update l10n key references).

- [ ] **Step 5: Final commit (if test fixes needed)**

```bash
git add -A
git commit -m "test: update tests for single import entry point"
```
