# Dive Number Auto-Assignment and Manual Editing

## Problem

When dives are downloaded from a dive computer via libdivecomputer, no dive number is assigned. The `DivesCompanion` created in `dive_computer_repository_impl.dart` omits the `diveNumber` field entirely, leaving it null. This means:

1. Downloaded dives appear unnumbered or are assigned fallback index-based numbers in the UI
2. The dive computer's native numbering is not available (libdivecomputer does not expose it via its parser API)
3. Users have no way to manually set or correct dive numbers from the dive edit form

The health/fitness import path (`dive_import_providers.dart`) already auto-assigns chronological numbers using `getDiveNumberForDate()`, but the dive computer import path does not.

## Solution

Two changes:

1. **Auto-assign dive numbers during dive computer import** using the same `getDiveNumberForDate()` approach as the health/fitness import path
2. **Add a dive number field to the dive edit form** for manual editing

## Design

### Feature 1: Auto-assign during dive computer import

**Location:** `dive_computer_repository_impl.dart`, in the method that creates `DivesCompanion` from downloaded dive data.

**Approach:**
- Before inserting downloaded dives, sort the selected dives by dateTime ascending (oldest first)
- For each dive, call `getDiveNumberForDate(diveDateTime, diverId: diverId)` to get the chronologically correct number
- Include the result as `diveNumber` in the `DivesCompanion`

**Why oldest-first ordering matters:** Each call to `getDiveNumberForDate()` counts existing dives before the given date. Processing oldest first ensures each successive call accounts for the dives just inserted before it, producing a correct sequential numbering.

**Edge case — importing older dives into an existing log:** New dives get correct numbers based on their date position, but existing dives' numbers are not shifted. Users can use the existing batch renumbering dialog to reconcile if needed.

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

**New dive auto-numbering:** When creating a new dive manually (not from import), if the user leaves the dive number blank, call `getDiveNumberForDate()` at save time. This ensures manually-created dives also get proper chronological numbers.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | Add `getDiveNumberForDate()` call when creating `DivesCompanion` from downloaded dives; sort dives chronologically before processing |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Add `TextFormField` for dive number; add `TextEditingController`; include in save logic with auto-assign fallback |

## Testing

- **Unit test:** Dive computer import assigns sequential numbers matching chronological order
- **Unit test:** Importing newest-first device data still produces correct oldest-first numbering
- **Unit test:** Manual dive creation with blank dive number auto-assigns correctly
- **Widget test:** Dive edit form displays and saves dive number field
- **Widget test:** Editing existing dive pre-populates dive number
- **Widget test:** Clearing dive number field saves null

## Out of Scope

- Preserving native dive computer numbering (libdivecomputer does not expose it)
- Cascade renumbering when one dive's number is changed (existing batch dialog handles this)
- Duplicate number warnings (user has full control, batch dialog for cleanup)
