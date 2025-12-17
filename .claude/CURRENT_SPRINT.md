# Current Sprint - v1.1 Development

> **Current Phase:** v1.1/v1.5 Notes & Tags - COMPLETE
> **Last Updated:** 2025-12-16
> **Sprint:** Sprint 6 - Notes & Tags (COMPLETE)
> **Reference:** See [FEATURE_ROADMAP.md](../FEATURE_ROADMAP.md) for full roadmap
> **Status:** v1.0 complete. v1.1/v1.5 Notes & Tags complete.

---

## Quick Reference

**Priority Levels:**
- P0 - Critical, blocking other work
- P1 - High priority, needed for current phase
- P2 - Medium priority, nice to have
- P3 - Low priority, future consideration

**Status:**
- [ ] TODO - Not started
- [~] IN PROGRESS - Currently being worked on
- [x] DONE - Completed
- [!] BLOCKED - Waiting on dependency

---

# Sprint 1: Buddy System (Weeks 1-2) - COMPLETED

## 1.1: Buddy Database Schema (P0) - DONE
**Estimated:** 2 hours | **Dependencies:** None

- [x] Add `buddies` table to database schema
- [x] Add `dive_buddies` junction table (many-to-many with role)
- [x] Run code generation
- [x] Test migration

**Schema:**
```sql
CREATE TABLE buddies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  certification_level TEXT,
  agency TEXT,
  photo_path TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE dive_buddies (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  buddy_id TEXT NOT NULL REFERENCES buddies(id) ON DELETE CASCADE,
  role TEXT NOT NULL, -- Buddy, Guide, Instructor, Student, Solo
  created_at INTEGER NOT NULL,
  UNIQUE(dive_id, buddy_id)
);
```

**Files:** `lib/core/database/database.dart`

---

## 1.2: Buddy Entity & Repository (P0) - DONE
**Estimated:** 3 hours | **Dependencies:** 1.1

- [x] Create `lib/features/buddies/domain/entities/buddy.dart`
- [x] Create `lib/features/buddies/data/repositories/buddy_repository.dart`
- [x] Implement CRUD methods
- [x] Write unit tests (20 tests in Sprint 4)

---

## 1.3: Buddy Providers (P1) - DONE
**Estimated:** 2 hours | **Dependencies:** 1.2

- [x] Create `lib/features/buddies/presentation/providers/buddy_providers.dart`
- [x] `buddyRepositoryProvider`
- [x] `allBuddiesProvider`
- [x] `buddyByIdProvider(String id)`
- [x] `buddiesForDiveProvider(String diveId)`
- [x] `buddySearchProvider(String query)`

---

## 1.4: Buddy List Page (P1) - DONE
**Estimated:** 3 hours | **Dependencies:** 1.3

- [x] Create `lib/features/buddies/presentation/pages/buddy_list_page.dart`
- [x] List with photo, name, cert level
- [x] Search bar
- [x] FAB to add new buddy
- [x] Empty state
- [x] Add to navigation and router

---

## 1.5: Buddy Detail Page (P1) - DONE
**Estimated:** 3 hours | **Dependencies:** 1.4

- [x] Create `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- [x] Display photo, contact info, certs
- [x] Statistics: total dives together, first/last dive
- [x] List of shared dives
- [x] Edit/delete actions

---

## 1.6: Buddy Edit Page (P0) - DONE
**Estimated:** 3 hours | **Dependencies:** 1.4

- [x] Create `lib/features/buddies/presentation/pages/buddy_edit_page.dart`
- [x] Form: photo, name, email, phone, cert level, agency, notes
- [x] Validation (name required, email/phone format)
- [x] Save/cancel

---

## 1.7: Buddy Picker for Dive Edit (P0) - DONE
**Estimated:** 4 hours | **Dependencies:** 1.6

- [x] Create `lib/features/buddies/presentation/widgets/buddy_picker.dart`
- [x] Multi-select with roles (Buddy, Guide, Instructor, Student, Solo)
- [x] Display as chips with role badges
- [x] "Add New Buddy" quick action
- [x] Modify `dive_edit_page.dart` to use BuddyPicker
- [x] Handle migration from old buddy text field (kept legacy fields)

---

## 1.8: Update Dive Detail for Buddies (P1) - DONE
**Estimated:** 2 hours | **Dependencies:** 1.7

- [x] Modify `dive_detail_page.dart`
- [x] Display buddy chips (photo, name, role)
- [x] Tap chip to navigate to buddy detail
- [x] Show "Solo dive" if no buddies

---

## 1.9: Buddy Import from Contacts (P2) - MOVED TO SPRINT 5
**Estimated:** 3 hours | **Dependencies:** 1.6

*Moved to Sprint 5 as task 5.9*

---

## 1.10: Testing & Bug Fixes (P0) - COMPLETE
**Estimated:** 3 hours | **Dependencies:** All above

- [x] Unit tests for BuddyRepository (20 tests in Sprint 4)
- [x] Widget tests for pages (completed in Sprint 4)
- [x] Test buddy-dive relationships (manual testing)
- [x] Test deletion behavior (CASCADE working)

---

# Sprint 2: Certifications & Service Records (Weeks 3-4) - COMPLETED

## 2.1-2.6: Certifications Feature (P0-P1) - DONE
- [x] Database schema (certifications table)
- [x] Entity and repository
- [x] List, detail, edit pages
- [x] Photo storage for cert cards (placeholder - photos in v2.0)
- [x] Expiry warnings

## 2.7-2.11: Service Records Feature (P0-P1) - DONE
- [x] Verify/create service_records schema
- [x] Repository with CRUD
- [x] Service history UI on equipment detail
- [x] Service record edit dialog
- [ ] Service log PDF export (deferred to v2.0)

---

# Sprint 3: Dive Centers & Conditions (Weeks 5-6) - COMPLETED

## 3.1-3.6: Dive Centers Feature (P0-P1) - DONE
- [x] Database schema (dive_centers table, FK on dives)
- [x] Entity and repository
- [x] List, detail, edit pages
- [x] Add to dive edit form (dive center picker ready, UI integration deferred)
- [x] Routes and navigation
- [x] Settings page link to dive centers

## 3.7: Conditions Fields (P1) - DONE
- [x] Add current_direction, current_strength, swell_height, entry/exit_method, water_type to dives
- [x] Add to Dive entity and repository
- [x] Update dive edit and detail page UI (completed in Sprint 4)

## 3.8-3.10: Equipment Enhancements (P1) - DONE
- [x] Add size, status fields to equipment entity
- [x] Add purchasePrice, purchaseCurrency to equipment entity
- [x] Equipment set tables exist (EquipmentSets, EquipmentSetItems)
- [x] Equipment set routes and pages exist
- [x] Weight system fields on dives (weightAmount, weightType, weightBeltUsed)
- [x] Update equipment edit page UI with new fields (completed in Sprint 4)

---

# Sprint 4: Testing & Polish (Weeks 7-9) - COMPLETED

## Completed Tasks
- [x] Fix N+1 query issues in DiveRepository (batch loading for getAllDives)
- [x] Fix deprecation warnings (withOpacity -> withValues)
- [x] Records/Superlatives page (deepest, longest, coldest, warmest, first, last)
- [x] Update dive edit page with conditions and weight fields
- [x] Update dive detail page with conditions display
- [x] Update equipment edit page with size, status, price fields
- [x] Error handling improvements (try-catch and logging in all repositories)
- [x] Unit test infrastructure with in-memory database
- [x] Repository unit tests (137 tests covering all 6 repositories)
  - SiteRepository: 19 tests
  - BuddyRepository: 20 tests
  - DiveCenterRepository: 23 tests
  - CertificationRepository: 22 tests
  - EquipmentRepository: 26 tests
  - DiveRepository: 27 tests
- [x] Widget tests (12 tests for SettingsPage and RecordsPage)
  - SettingsPage: 7 tests
  - RecordsPage: 5 tests
- [x] Release build verified (macOS)

## Test Summary
- **Total Tests:** 185+
- **Repository Unit Tests:** 165 (137 + 28 TripRepository)
- **Widget Tests:** 48 (12 + 36 Trip pages)
- **All core tests passing**

## Deferred to v1.1+
- [ ] Integration tests
- [ ] Performance testing (1000+ dives)
- [ ] Profile chart zoom/pan
- [ ] GPS auto-capture on mobile
- [ ] Reverse geocoding for sites
- [ ] Map marker clustering
- [ ] Profile export as image

---

# Known Issues & Technical Debt

## From MVP Phase
1. ~~**N+1 Queries in DiveRepository**~~ - Fixed with batch loading
2. ~~**withOpacity() deprecated**~~ - Replaced with Color.withValues()
3. ~~**Limited error handling**~~ - Added try-catch and logging via LoggerService
4. ~~**No unit tests**~~ - 137 repository unit tests now in place
5. ~~**No widget tests**~~ - 12 widget tests now in place
6. **Media table exists but unused** - Deferred to v2.0

---

# Sprint 5: Trips & Bulk Operations (Weeks 10-11) - COMPLETE

## 5.1: Trips Database Schema (P0) - COMPLETE
**Estimated:** 1 hour | **Dependencies:** None

- [x] Add `trips` table to database schema
- [x] Add `trip_id` FK to dives table
- [x] Run code generation
- [x] Test migration

**Schema:**
```sql
CREATE TABLE trips (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  start_date INTEGER NOT NULL,
  end_date INTEGER NOT NULL,
  location TEXT,
  resort_name TEXT,
  liveaboard_name TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

ALTER TABLE dives ADD COLUMN trip_id TEXT REFERENCES trips(id);
```

---

## 5.2: Trip Repository (P0) - COMPLETE
**Estimated:** 3 hours | **Dependencies:** 5.1

- [x] Create trip entity and repository
- [x] Implement CRUD operations
- [x] Methods: create, get, getAll, search, update, delete
- [x] Get dives for trip
- [x] Assign/remove dives to/from trip
- [x] Computed properties: dive count, total bottom time, deepest dive, avg depth
- [x] Unit tests (28 tests in 5.8)

**Files:**
- `lib/features/trips/data/repositories/trip_repository.dart`
- `lib/features/trips/domain/entities/trip.dart`

---

## 5.3: Trip Providers (P1) - COMPLETE
**Estimated:** 2 hours | **Dependencies:** 5.2

- [x] Create trip providers
- [x] tripRepositoryProvider
- [x] allTripsProvider
- [x] tripByIdProvider
- [x] divesForTripProvider
- [x] tripSearchProvider
- [x] tripListNotifierProvider

**Files:**
- `lib/features/trips/presentation/providers/trip_providers.dart`

---

## 5.4: Trip UI Pages (P1) - COMPLETE
**Estimated:** 8 hours | **Dependencies:** 5.3

- [x] Trip list page (sorted by start date)
- [x] Trip detail page (stats, dive list, export)
- [x] Trip edit page (form with validation)
- [x] Trip picker for dive edit form
- [x] Auto-suggest trip based on dive date
- [x] Update router
- [x] Add trips link in settings page

**Files:**
- `lib/features/trips/presentation/pages/trip_list_page.dart`
- `lib/features/trips/presentation/pages/trip_detail_page.dart`
- `lib/features/trips/presentation/pages/trip_edit_page.dart`
- `lib/features/trips/presentation/widgets/trip_picker.dart`

---

## 5.5: Trip Export (P2) - COMPLETE
**Estimated:** 2 hours | **Dependencies:** 5.4

- [x] Export trip to CSV (all dives)
- [x] Export trip to PDF (summary + dive details)
- [x] Use existing export service

**Files:**
- `lib/core/services/export_service.dart` (added exportTripsToCsv, exportTripToPdf)

---

## 5.6: Bulk Delete UI (P0) - COMPLETE
**Estimated:** 3 hours | **Dependencies:** None

- [x] Multi-select mode in dive list
- [x] Long-press to enter select mode
- [x] Show checkboxes when in select mode
- [x] App bar actions: Select All, Deselect All, Delete, Cancel
- [x] Display selection count

**Files modified:**
- `lib/features/dive_log/presentation/pages/dive_list_page.dart`

---

## 5.7: Bulk Delete Logic (P0) - COMPLETE
**Estimated:** 2 hours | **Dependencies:** 5.6

- [x] Add bulkDeleteDives method to repository
- [x] Confirmation dialog with count
- [x] Undo functionality (5-second timeout)
- [x] Show snackbar with undo button
- [x] Exit select mode after delete

**Files modified:**
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- `lib/features/dive_log/presentation/providers/dive_providers.dart`

---

## 5.8: Testing & Documentation (P0) - COMPLETE
**Estimated:** 3 hours | **Dependencies:** All above

- [x] Unit tests for TripRepository (28 tests)
- [x] Widget tests for trip pages (36 tests)
  - TripListPage: 8 tests
  - TripDetailPage: 15 tests
  - TripEditPage: 13 tests
- [x] Test bulk delete with undo (verified in code)
- [x] Update CLAUDE.md
- [x] Update CURRENT_SPRINT.md

---

## 5.9: Buddy Import from Contacts (P2) - COMPLETE
**Estimated:** 3 hours | **Dependencies:** Sprint 1 complete

- [x] Add flutter_contacts package
- [x] "Import from Contacts" button on buddy list page (app bar menu)
- [x] Request permission, show contact picker
- [x] Pre-fill buddy form with name, email, phone from contact

**Files modified:**
- `pubspec.yaml` (added flutter_contacts)
- `lib/features/buddies/presentation/pages/buddy_list_page.dart`
- `lib/features/buddies/presentation/pages/buddy_edit_page.dart`
- `lib/core/router/app_router.dart`

---

**Sprint 5 Summary:**
- **Total Tasks:** 9
- **Estimated Hours:** 27
- **Target:** Add trip grouping, bulk operations, and buddy import to v1.0

---

# Workflow Instructions

## How to Work Through This List

1. **Start at the top** - Work through tasks in order unless blocked
2. **Update status** as you work (change [ ] to [x])
3. **Check dependencies** before starting a task
4. **Create branches** for each task: `feature/buddy-schema`, etc.
5. **Commit frequently** with clear messages
6. **Test as you go**
7. **Ask for clarification** if task is unclear

## Git Workflow

```bash
# Start a task
git checkout main
git pull
git checkout -b feature/buddy-schema

# Make changes, then commit
git add .
git commit -m "feat: add buddy and dive_buddies tables"

git push -u origin feature/buddy-schema
```

## After Completing a Sprint

1. Update this file - mark tasks complete
2. Update FEATURE_ROADMAP.md if needed
3. Move to next sprint

---

# Architecture Decisions

- **Photo Deferral:** Photos moved to v2.0 to focus on core features
- **Buddy Migration:** Keep old buddy text field temporarily, mark deprecated
- **Permissions:** Request just-in-time, not on app launch
- **Testing Priority:** repositories > widgets > integration

---

# Architecture Decisions (Resolved)

- **Certification agencies:** Hardcoded list (not user-defined)
- **Buddy photo storage:** App documents directory
- **Localization:** Deferred to v1.1+
- **Crash reporting:** Not included in v1.0

---

**v1.0 Total Estimate:** ~60 tasks, ~192 hours, 11 weeks

**Status:** v1.0 COMPLETE. All sprints finished, 185+ tests passing. Ready for release.

---

# Sprint 6: Notes & Tags (v1.1/v1.5) - COMPLETE

## 6.1: Favorites Feature (v1.1) - COMPLETE
**Estimated:** 4 hours | **Dependencies:** None

- [x] Add `is_favorite` boolean to dives table (schema v8)
- [x] Update Dive entity with `isFavorite` field
- [x] Update DiveRepository with toggle/set favorite methods
- [x] Add favorite icon to dive list (heart icon, tap to toggle)
- [x] Add favorite button to dive detail page app bar
- [x] Add "Favorites Only" filter in filter sheet
- [x] Add favorites filter chip display

**Files modified:**
- `lib/core/database/database.dart`
- `lib/features/dive_log/domain/entities/dive.dart`
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- `lib/features/dive_log/presentation/providers/dive_providers.dart`
- `lib/features/dive_log/presentation/pages/dive_list_page.dart`
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

---

## 6.2: Tags Database Schema (v1.5) - COMPLETE
**Estimated:** 2 hours | **Dependencies:** 6.1

- [x] Add `tags` table (id, name, color, timestamps)
- [x] Add `dive_tags` junction table (many-to-many)
- [x] Add indexes for efficient lookups
- [x] Run code generation

**Schema:**
```sql
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE dive_tags (
  id TEXT PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL
);

CREATE UNIQUE INDEX idx_tags_name ON tags(name);
CREATE INDEX idx_dive_tags_dive_id ON dive_tags(dive_id);
CREATE INDEX idx_dive_tags_tag_id ON dive_tags(tag_id);
```

---

## 6.3: Tag Entity & Repository (v1.5) - COMPLETE
**Estimated:** 4 hours | **Dependencies:** 6.2

- [x] Create Tag entity with color support
- [x] Create TagRepository with CRUD operations
- [x] Batch loading for dive tags (getTagsForDives)
- [x] Tag statistics query (usage counts)
- [x] Get or create tag by name
- [x] Search tags

**Files created:**
- `lib/features/tags/domain/entities/tag.dart`
- `lib/features/tags/data/repositories/tag_repository.dart`

---

## 6.4: Tag Providers (v1.5) - COMPLETE
**Estimated:** 2 hours | **Dependencies:** 6.3

- [x] tagRepositoryProvider
- [x] tagsProvider (all tags)
- [x] tagProvider (by ID)
- [x] tagStatisticsProvider
- [x] tagsForDiveProvider
- [x] tagSearchProvider
- [x] tagListNotifierProvider (with mutations)

**Files created:**
- `lib/features/tags/presentation/providers/tag_providers.dart`

---

## 6.5: Tag Input Widget (v1.5) - COMPLETE
**Estimated:** 4 hours | **Dependencies:** 6.4

- [x] TagInputWidget with chip selector
- [x] Autocomplete suggestions
- [x] Create new tag inline
- [x] 20 predefined colors
- [x] TagChips compact display for list views
- [x] TagManagementDialog for editing/deleting tags
- [x] TagColorPicker widget

**Files created:**
- `lib/features/tags/presentation/widgets/tag_input_widget.dart`

---

## 6.6: Tags in Dive Edit/Detail (v1.5) - COMPLETE
**Estimated:** 3 hours | **Dependencies:** 6.5

- [x] Add TagInputWidget to dive edit page
- [x] Load existing tags when editing dive
- [x] Save tags with dive (create/update)
- [x] Display tags on dive detail page
- [x] Display tag chips in dive list

**Files modified:**
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- `lib/features/dive_log/presentation/pages/dive_list_page.dart`

---

## 6.7: Tag Filtering (v1.5) - COMPLETE
**Estimated:** 2 hours | **Dependencies:** 6.6

- [x] Add tagIds to DiveFilterState
- [x] Tag filter chips in filter sheet
- [x] Filter dives by selected tags (match any)
- [x] Display tag filter count in active filters bar

**Files modified:**
- `lib/features/dive_log/presentation/providers/dive_providers.dart`
- `lib/features/dive_log/presentation/pages/dive_list_page.dart`

---

## 6.8: Tag Statistics (v1.5) - COMPLETE
**Estimated:** 2 hours | **Dependencies:** 6.7

- [x] Add Tag Usage section to statistics page
- [x] Show tag name, color, dive count
- [x] Progress bars showing relative usage
- [x] Empty state when no tags exist

**Files modified:**
- `lib/features/statistics/presentation/pages/statistics_page.dart`

---

## Sprint 6 Summary

**Total Tasks:** 8
**Estimated Hours:** 23
**Features Implemented:**
- Favorites system (v1.1)
- Tags system with colors (v1.5)
- Tag input widget with autocomplete
- Tag-based filtering
- Tag statistics

**New Files Created:**
- `lib/features/tags/domain/entities/tag.dart`
- `lib/features/tags/data/repositories/tag_repository.dart`
- `lib/features/tags/presentation/providers/tag_providers.dart`
- `lib/features/tags/presentation/widgets/tag_input_widget.dart`

**Database Changes:**
- Schema version 7 → 8
- Added `is_favorite` column to dives
- Added `tags` table
- Added `dive_tags` junction table
