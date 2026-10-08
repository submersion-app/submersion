# Dive Number Auto-Assignment and Manual Editing

## Problem

When dives are downloaded from a dive computer via libdivecomputer, no dive number is assigned. The `DivesCompanion` created in `dive_computer_repository_impl.dart` omits the `diveNumber` field entirely, leaving it null. This means:

1. Downloaded dives appear unnumbered or are assigned fallback index-based numbers in the UI
2. The dive computer's native numbering is not available (libdivecomputer does not expose it via its parser API)
3. Users have no way to manually set or correct dive numbers from the dive edit form

The health/fitness import path (`dive_import_providers.dart`) already auto-assigns chronological numbers using `getDiveNumberForDate()`, but the dive computer import path does not.

**Note:** The `DownloadedDive` entity has a `diveNumber` field (described as "Computer-assigned dive number"), but it is always null in practice because the Pigeon `ParsedDive` class and the underlying libdivecomputer C struct do not expose dive numbers. This field remains unused.

## Solution

Two changes:

1. **Auto-assign dive numbers during dive computer import** using the same `getDiveNumberForDate()` approach as the health/fitness import path
2. **Add a dive number field to the dive edit form** for manual editing

## Design

### Feature 1: Auto-assign during dive computer import

**Import flow architecture:** The dive computer import goes through several layers:
1. `download_providers.dart` calls `_importService.importDives()`
2. `dive_import_service.dart` orchestrates the import via `_importNewDive()`
3. `_importNewDive()` calls `_repository.importProfile()`
4. `importProfile()` in `dive_computer_repository_impl.dart` builds the `DivesCompanion`

**Where the change happens:**
- **`dive_import_service.dart`**: Sort dives chronologically (oldest first) in `importDives()` before the for-loop. In `_importNewDive()`, call `getDiveNumberForDate()` and pass the result to `importProfile()`. Also applies to the `resolveConflict()` path which calls `_importNewDive()` with `ConflictResolution.importAsNew`.
- **`dive_computer_repository_impl.dart`**: Add a `diveNumber` parameter to `importProfile()` and include it in the `DivesCompanion`.

**Cross-repository dependency:** `getDiveNumberForDate()` lives in `DiveRepositoryImpl`, not `DiveComputerRepositoryImpl`. The `DiveImportService` does not currently have access to it. Solution: inject `DiveRepository` (or its interface) into `DiveImportService` so it can call `getDiveNumberForDate()`. The `diveImportServiceProvider` in `download_providers.dart` must be updated to pass in the additional dependency. Ensure `diverId` is forwarded to `getDiveNumberForDate()` to maintain per-diver numbering consistency.

**Why oldest-first ordering matters:** Each call to `getDiveNumberForDate()` counts existing dives before the given date. Processing oldest first ensures each successive call accounts for the dives just inserted before it (each dive is fully committed before the next number is calculated), producing correct sequential numbering. The sort must happen in `importDives()` before the iteration loop.

**Wall-clock-as-UTC convention:** Per the project's time convention (commit 8b043de3), the `startTime` from `DownloadedDive` must use `DateTime.utc()` when passed to `getDiveNumberForDate()`. Verify this is already the case in the dive computer import path; if not, ensure consistency.

**Edge case — importing older dives into an existing log:** New dives get correct numbers based on their date position, but existing dives' numbers are not shifted. Users can use the existing batch renumbering dialog to reconcile if needed.

**Edge case — multiple dives at the same timestamp:** `getDiveNumberForDate()` uses a strict less-than comparison (`entry_time < ?`), so two dives with identical timestamps would get the same dive number. This is unlikely in practice (dive computers record precise start times) and can be corrected via the batch renumbering dialog if it occurs.

**Infrastructure reused:**
- `getDiveNumberForDate()` in `dive_repository_impl.dart` (lines 1447-1483)
- Same pattern as `dive_import_providers.dart` (lines 367-376)

### Feature 2: Manual dive number editing

**Location:** `dive_edit_page.dart`

**Placement:** At the top of the form, before date/time fields. Dive number is a primary identifier.

**Behavior:**
- `TextFormField` with integer-only input (numeric keyboard, `FilteringTextInputFormatter.digitsOnly`)
- Nullable: user can clear the field to remove the number
- Pre-populated with existing `diveNumber` when editing an existing dive
- For new dives created manually, left empty; if still empty at save time, auto-assign via `getDiveNumberForDate()`
- Free-form: no validation against other dives' numbers, no cascade renumbering
- The existing batch renumbering dialog (accessible from dive list) handles bulk corrections

**New dive auto-numbering:** When creating a new dive manually (not from import), if the user leaves the dive number blank, call `getDiveNumberForDate()` at save time. This requires the async call to happen before constructing the `Dive` entity in `_saveDive()`. The repository call should be made before entity construction, and the result passed into the entity.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/dive_computer/data/services/dive_import_service.dart` | Sort dives chronologically in `importDives()` before the for-loop; call `getDiveNumberForDate()` in `_importNewDive()` and pass result to `importProfile()`; inject `DiveRepository` dependency |
| `lib/features/dive_computer/presentation/providers/download_providers.dart` | Update `diveImportServiceProvider` to inject `DiveRepository` into `DiveImportService` constructor |
| `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | Add `diveNumber` parameter to `importProfile()`; include it in the `DivesCompanion`. Note: `_updateExistingDive` also calls `importProfile()` — pass `null` for `diveNumber` there since it only updates existing records |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Add `TextFormField` for dive number; add `TextEditingController`; auto-assign in `_saveDive()` for new dives with blank number |

## Testing

- **Unit test:** Dive computer import assigns sequential numbers matching chronological order
- **Unit test:** Importing newest-first device data still produces correct oldest-first numbering
- **Unit test:** Importing a dive between two existing dives gets the correct intermediate number; existing dive numbers remain unchanged
- **Unit test:** `resolveConflict()` with `ConflictResolution.importAsNew` also assigns a dive number
- **Unit test:** Manual dive creation with blank dive number auto-assigns correctly
- **Widget test:** Dive edit form displays and saves dive number field
- **Widget test:** Editing existing dive pre-populates dive number
- **Widget test:** Clearing dive number field saves null

## Out of Scope

- Preserving native dive computer numbering (libdivecomputer does not expose it)
- Cascade renumbering when one dive's number is changed (existing batch dialog handles this)
- Duplicate number warnings (user has full control, batch dialog for cleanup)
