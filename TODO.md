# Submersion Development TODO List
## Actionable Tasks for AI-Assisted Development

> **Current Phase:** v1.0 Development
> **Last Updated:** 2025-12-15
> **Sprint:** Sprint 1 - Buddy System
> **Photos Note:** Photo features have been moved to v2.0 to focus on core dive logging capabilities first

---

## Quick Reference

**Priority Levels:**
- 🔥 **P0** - Critical, blocking other work
- 🎯 **P1** - High priority, needed for current phase
- 📌 **P2** - Medium priority, nice to have
- 💭 **P3** - Low priority, future consideration

**Status:**
- ⏳ **TODO** - Not started
- 🏗️ **IN PROGRESS** - Currently being worked on
- ✅ **DONE** - Completed
- ⏸️ **BLOCKED** - Waiting on dependency
- ❌ **CANCELLED** - No longer needed

---

# v1.0 Development Overview

## Revised Priorities

After reviewing the roadmap, **photos have been moved to v2.0** to allow v1.0 to focus on:
1. **Buddy System** - Replace text field with proper entity relationships
2. **Certifications** - Track certification cards and expiry dates
3. **Service Records** - Complete the service tracking feature
4. **Dive Centers** - Link dives to operators and boats
5. **Testing & Polish** - Achieve production-ready quality

**Rationale:** Most divers need buddy tracking and certifications before photos. Photos are a "nice-to-have" that can wait until after cloud sync is available (v2.0), which will make photo storage and sharing more practical.

---

# 🚀 SPRINT 1: Buddy System (Weeks 1-2)

## Task 1.1: Buddy Database Schema 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** None

### Subtasks:
- [ ] Add `buddies` table to database schema
- [ ] Add `dive_buddies` junction table (many-to-many with role)
- [ ] Create migration script
- [ ] Run code generation
- [ ] Test migration

**SQL Schema:**
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

-- Remove old buddy text field from dives
-- ALTER TABLE dives DROP COLUMN buddy; (mark as deprecated first)
```

**Files to modify:**
- `lib/core/database/database.dart`

---

## Task 1.2: Buddy Entity & Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 1.1

### Subtasks:
- [ ] Create `lib/features/buddies/data/buddy_entity.dart`
- [ ] Create `lib/features/buddies/data/buddy_repository.dart`
- [ ] Implement CRUD methods:
  - [ ] `Future<Buddy> createBuddy(BuddyCompanion buddy)`
  - [ ] `Future<Buddy?> getBuddyById(String id)`
  - [ ] `Future<List<Buddy>> getAllBuddies()`
  - [ ] `Future<List<Buddy>> searchBuddies(String query)`
  - [ ] `Future<void> updateBuddy(String id, BuddyCompanion buddy)`
  - [ ] `Future<void> deleteBuddy(String id)`
  - [ ] `Future<List<Buddy>> getBuddiesForDive(String diveId)`
  - [ ] `Future<void> addBuddiesToDive(String diveId, List<BuddyWithRole> buddies)`
  - [ ] `Future<void> removeBuddyFromDive(String diveId, String buddyId)`
- [ ] Write unit tests

**Files to create:**
- `lib/features/buddies/data/buddy_entity.dart`
- `lib/features/buddies/data/buddy_repository.dart`
- `test/features/buddies/data/buddy_repository_test.dart`

---

## Task 1.3: Buddy Providers 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 1.2

### Subtasks:
- [ ] Create `lib/features/buddies/providers/buddy_providers.dart`
- [ ] Create providers:
  - [ ] `buddyRepositoryProvider`
  - [ ] `allBuddiesProvider` - FutureProvider<List<Buddy>>
  - [ ] `buddyByIdProvider(String id)` - FutureProvider<Buddy?>
  - [ ] `buddiesForDiveProvider(String diveId)` - FutureProvider<List<BuddyWithRole>>
  - [ ] `buddySearchProvider(String query)` - FutureProvider<List<Buddy>>

**Files to create:**
- `lib/features/buddies/providers/buddy_providers.dart`

---

## Task 1.4: Buddy List Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 1.3

### Subtasks:
- [ ] Create `lib/features/buddies/presentation/pages/buddy_list_page.dart`
- [ ] Implement features:
  - [ ] List all buddies with photo, name, cert level
  - [ ] Search bar at top
  - [ ] Floating action button to add new buddy
  - [ ] Tap buddy to view detail page
  - [ ] Empty state ("No buddies yet")
  - [ ] Pull-to-refresh
- [ ] Add to main navigation (bottom nav or settings)
- [ ] Update router

**Files to create:**
- `lib/features/buddies/presentation/pages/buddy_list_page.dart`

**Files to modify:**
- `lib/core/router/router.dart`
- `lib/shared/widgets/main_scaffold.dart` (if adding to nav)

---

## Task 1.5: Buddy Detail Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 1.4

### Subtasks:
- [ ] Create `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- [ ] Display:
  - [ ] Photo (large)
  - [ ] Name, email, phone (with tap-to-call/email)
  - [ ] Certification level, agency
  - [ ] Notes
  - [ ] Statistics: Total dives together, first/last dive, favorite site
  - [ ] List of shared dives (scrollable)
- [ ] Actions:
  - [ ] Edit button (navigate to edit page)
  - [ ] Delete button (with confirmation)
  - [ ] Share contact (VCF export)
- [ ] Tap on shared dive to view dive detail

**Files to create:**
- `lib/features/buddies/presentation/pages/buddy_detail_page.dart`

---

## Task 1.6: Buddy Edit Page 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 1.4

### Subtasks:
- [ ] Create `lib/features/buddies/presentation/pages/buddy_edit_page.dart`
- [ ] Form fields:
  - [ ] Photo (tap to change, option to remove)
  - [ ] Name (required)
  - [ ] Email
  - [ ] Phone
  - [ ] Certification level dropdown (Open Water, Advanced, Rescue, Divemaster, Instructor, etc.)
  - [ ] Agency dropdown (PADI, SSI, NAUI, SDI, TDI, etc.)
  - [ ] Notes (multiline)
- [ ] Validation:
  - [ ] Name required
  - [ ] Email format validation (if provided)
  - [ ] Phone format validation (if provided)
- [ ] Save button
- [ ] Cancel button (confirm if changes made)

**Files to create:**
- `lib/features/buddies/presentation/pages/buddy_edit_page.dart`

---

## Task 1.7: Buddy Picker for Dive Edit 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 4 hours
**Dependencies:** Task 1.6

### Subtasks:
- [ ] Create `lib/features/buddies/presentation/widgets/buddy_picker.dart`
- [ ] Multi-select buddy picker with roles:
  - [ ] Search/filter buddies
  - [ ] Select multiple buddies
  - [ ] Assign role per buddy (Buddy, Guide, Instructor, Student, Solo)
  - [ ] Display selected buddies as chips with role badges
  - [ ] Remove buddy (tap X on chip)
- [ ] "Add New Buddy" quick action in picker
- [ ] Modify `dive_edit_page.dart`:
  - [ ] Replace old buddy text field with BuddyPicker widget
  - [ ] Load existing dive buddies when editing
  - [ ] Save dive_buddies relationships when saving dive
  - [ ] Handle migration: if old buddy text field has data, suggest creating buddy

**Files to create:**
- `lib/features/buddies/presentation/widgets/buddy_picker.dart`

**Files to modify:**
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

---

## Task 1.8: Update Dive Detail to Show Buddies 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 1.7

### Subtasks:
- [ ] Modify `dive_detail_page.dart`
- [ ] Replace old buddy text display with:
  - [ ] List of buddy chips (photo, name, role badge)
  - [ ] Tap buddy chip to navigate to buddy detail page
  - [ ] Display "Solo dive" if no buddies
- [ ] Update dive statistics to use buddy relationships

**Files to modify:**
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

---

## Task 1.9: Buddy Import from Contacts (Mobile) 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 1.6

### Subtasks:
- [ ] Add contacts_service package (or flutter_contacts)
- [ ] Add "Import from Contacts" button in buddy list
- [ ] Request contacts permission
- [ ] Show contact picker
- [ ] Pre-fill buddy form with contact data (name, email, phone)
- [ ] Handle permission denial

**New dependencies:**
```yaml
dependencies:
  flutter_contacts: ^1.1.0
```

---

## Task 1.10: Buddy Export & Sharing 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 1.5

### Subtasks:
- [ ] Add "Share Buddy" action in buddy detail page
- [ ] Generate VCF (vCard) file with buddy contact info
- [ ] Use share_plus to share VCF
- [ ] Export all buddies to CSV (from buddy list page)

---

## Task 1.11: Testing & Bug Fixes 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** All above tasks

### Subtasks:
- [ ] Unit tests for BuddyRepository
- [ ] Widget tests for BuddyListPage, BuddyDetailPage, BuddyEditPage
- [ ] Widget tests for BuddyPicker
- [ ] Test buddy relationships with dives
- [ ] Test buddy deletion (ensure dives don't break)
- [ ] Test search functionality
- [ ] Fix bugs

---

## Task 1.12: Documentation 📌 P2
**Status:** ⏳ TODO
**Estimated:** 1 hour
**Dependencies:** Task 1.11

### Subtasks:
- [ ] Update CLAUDE.md
- [ ] Update README.md
- [ ] Document buddy feature

---

# 🚀 SPRINT 2: Certifications & Service Records (Weeks 3-4)

## Task 2.1: Certifications Database Schema 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 2 hours

### Subtasks:
- [ ] Add `certifications` table
- [ ] Create migration
- [ ] Run code generation

**SQL:**
```sql
CREATE TABLE certifications (
  id TEXT PRIMARY KEY,
  agency TEXT NOT NULL,
  level TEXT NOT NULL,
  cert_number TEXT,
  issue_date INTEGER NOT NULL,
  expiry_date INTEGER,
  instructor_name TEXT,
  card_image_path TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

---

## Task 2.2: Certification Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.1

### Subtasks:
- [ ] Create entity and repository
- [ ] CRUD operations
- [ ] Methods for checking expiry status
- [ ] Unit tests

---

## Task 2.3: Certification List Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.2

### Subtasks:
- [ ] List all certifications
- [ ] Display card images as thumbnails
- [ ] Show expiry warnings (red if expired, yellow if expiring <30 days)
- [ ] Search/filter by agency, level
- [ ] Add button for new cert

---

## Task 2.4: Certification Detail Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 2.3

### Subtasks:
- [ ] Display full cert card image
- [ ] Show all cert details
- [ ] Edit/delete actions
- [ ] Share cert (export image or PDF)

---

## Task 2.5: Certification Edit Page 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.3

### Subtasks:
- [ ] Form with all fields
- [ ] Agency dropdown (PADI, SSI, NAUI, SDI, TDI, GUE, RAID, BSAC, etc.)
- [ ] Level dropdown (Open Water, Advanced, Rescue, Divemaster, Instructor, Specialty names)
- [ ] Photo picker for cert card (use image_picker, already in pubspec)
- [ ] Date pickers
- [ ] Validation
- [ ] Save/cancel

**Note:** Since photos are moved to v2.0, cert card images will use the basic image_picker package directly without the full media management system. This is acceptable for v1.0.

---

## Task 2.6: Certification Wallet View 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.4

### Subtasks:
- [ ] Card-style UI (like Apple Wallet)
- [ ] Swipe between certs
- [ ] Tap to flip card (front/back if multiple images)
- [ ] Export as image for sharing

---

## Task 2.7: Service Records Schema 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 1 hour

### Subtasks:
- [ ] Verify service_records table schema (should already be defined)
- [ ] Create migration if needed
- [ ] Run code generation

**Note:** ServiceRecord entity should already exist in the codebase, just needs UI implementation.

---

## Task 2.8: Service Records Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 2.7

### Subtasks:
- [ ] Verify entity exists, create if missing
- [ ] Create repository with CRUD
- [ ] Method to get service history for equipment
- [ ] Unit tests

---

## Task 2.9: Service History UI 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.8

### Subtasks:
- [ ] Add "Service History" section to equipment detail page
- [ ] List all service records (date, shop, cost, work done)
- [ ] Add service record button
- [ ] Edit/delete service records
- [ ] Update next service due date

**Files to modify:**
- `lib/features/equipment/presentation/pages/equipment_detail_page.dart`

---

## Task 2.10: Service Record Edit Dialog 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 2.9

### Subtasks:
- [ ] Form: date, shop name, cost, work performed, next due date, notes
- [ ] Date picker
- [ ] Cost input with currency
- [ ] Save/cancel

---

## Task 2.11: Service Log Export 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 2.9

### Subtasks:
- [ ] Export equipment service history to PDF
- [ ] Include all service records
- [ ] Formatted like a maintenance log

---

## Task 2.12: Testing & Docs 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours

### Subtasks:
- [ ] Unit tests for repositories
- [ ] Widget tests for pages
- [ ] Update documentation (CLAUDE.md, README.md)

---

# 🚀 SPRINT 3: Dive Centers, Conditions & Equipment (Weeks 5-6)

## Task 3.1: Dive Centers Database Schema 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 2 hours

### Subtasks:
- [ ] Create dive_centers table
- [ ] Add dive_center_id FK to dives
- [ ] Add boat_name, operator_name to dives
- [ ] Migration

**SQL:**
```sql
CREATE TABLE dive_centers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  location TEXT,
  country TEXT,
  gps_latitude REAL,
  gps_longitude REAL,
  phone TEXT,
  email TEXT,
  website TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

ALTER TABLE dives ADD COLUMN dive_center_id TEXT REFERENCES dive_centers(id);
ALTER TABLE dives ADD COLUMN boat_name TEXT;
ALTER TABLE dives ADD COLUMN operator_name TEXT;
```

---

## Task 3.2: Dive Center Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.1

### Subtasks:
- [ ] Create entity and repository
- [ ] CRUD operations
- [ ] Search by name/location
- [ ] Get all dives for a center
- [ ] Unit tests

---

## Task 3.3: Dive Center List Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.2

### Subtasks:
- [ ] List all dive centers
- [ ] Search bar
- [ ] Display name, location, dive count
- [ ] Add new button
- [ ] Tap to view detail

---

## Task 3.4: Dive Center Detail Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.3

### Subtasks:
- [ ] Display center info
- [ ] Contact details (tap to call/email/open website)
- [ ] Map location
- [ ] List all dives at this center
- [ ] Statistics (total dives, date range)
- [ ] Edit/delete actions

---

## Task 3.5: Dive Center Edit Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 3.3

### Subtasks:
- [ ] Form with all fields
- [ ] GPS picker (use current location or map)
- [ ] Validation
- [ ] Save/cancel

---

## Task 3.6: Add Dive Center to Dive Edit 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 3.5

### Subtasks:
- [ ] Add dive center picker to dive edit form
- [ ] Dropdown with search
- [ ] "Add new center" quick action
- [ ] Boat name and operator name text fields
- [ ] Save relationships

**Files to modify:**
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

---

## Task 3.7: Add Conditions Fields to Dive Edit 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours

### Subtasks:
- [ ] Add to dives table:
  - [ ] current_direction (N/S/E/W/NE/NW/SE/SW/None)
  - [ ] current_strength (None/Slight/Moderate/Strong)
  - [ ] swell_height_meters
  - [ ] entry_method (Shore/Boat/Zodiac/Giant Stride/Back Roll/etc.)
  - [ ] exit_method (same options)
  - [ ] water_type (Fresh/Salt/Brackish)
- [ ] Migration
- [ ] Update DiveEntity
- [ ] Add to dive edit form with appropriate UI (dropdowns, number input)
- [ ] Update dive detail page to display conditions

**Files to modify:**
- `lib/core/database/database.dart`
- `lib/features/dive_log/data/dive_entity.dart`
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

---

## Task 3.8: Equipment Enhancements 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours

### Subtasks:
- [ ] Add to equipment table:
  - [ ] size (S/M/L/XL or numeric)
  - [ ] status (Active/Retired/Sold/Lost/In Service)
- [ ] Migration
- [ ] Update EquipmentEntity
- [ ] Add fields to equipment edit form
- [ ] Filter equipment by status in equipment list

**Files to modify:**
- `lib/core/database/database.dart`
- `lib/features/equipment/data/equipment_entity.dart`
- `lib/features/equipment/presentation/pages/equipment_edit_page.dart`
- `lib/features/equipment/presentation/pages/equipment_list_page.dart`

---

## Task 3.9: Equipment Set Templates 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.8

### Subtasks:
- [ ] Predefined equipment set templates:
  - [ ] Tropical Single Tank (BCD, reg, wetsuit, fins, mask, computer)
  - [ ] Cold Water Drysuit (drysuit, hood, gloves, doubles, etc.)
  - [ ] Technical Twinset (doubles, stages, deco regs, etc.)
  - [ ] Sidemount (sidemount harness, dual tanks, etc.)
  - [ ] Photography (camera, strobes, tray, arms)
- [ ] Store templates in local JSON or hardcoded
- [ ] "Create from template" option in equipment sets page
- [ ] Populate set with items matching template types

---

## Task 3.10: Weight System Fields 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours

### Subtasks:
- [ ] Add to dives table:
  - [ ] weight_system (Belt/Integrated/Trim Pockets/Ankle Weights/None)
  - [ ] total_weight_kg
- [ ] Migration
- [ ] Add to dive edit form
- [ ] Display on dive detail
- [ ] Simple weight calculator based on suit type, water type

**Files to modify:**
- `lib/core/database/database.dart`
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

---

## Task 3.11: Testing & Docs 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours

### Subtasks:
- [ ] Unit tests for new repositories
- [ ] Widget tests for new pages
- [ ] Integration tests for dive center workflow
- [ ] Update documentation

---

# 🚀 SPRINT 4: Testing, Polish & v1.0 Release (Weeks 7-9)

## Task 4.1: Fix N+1 Query Issues 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 4 hours

### Subtasks:
- [ ] Refactor `DiveRepository.getAllDives()` to use JOINs
- [ ] Load tanks, profiles, sites, buddies in single query
- [ ] Benchmark performance improvement (before/after)
- [ ] Update repository tests

**Files to modify:**
- `lib/features/dive_log/data/dive_repository.dart`

---

## Task 4.2: Error Handling Improvements 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 4 hours

### Subtasks:
- [ ] Add try-catch blocks to all repository methods
- [ ] Add error logging (use logger package)
- [ ] Show user-friendly error messages (SnackBar or AlertDialog)
- [ ] Handle specific errors:
  - [ ] File not found
  - [ ] Permission denied
  - [ ] Network errors (future)
  - [ ] Database errors
- [ ] Add error boundary for catastrophic failures

---

## Task 4.3: Unit Test Coverage (80% Goal) 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 8 hours

### Subtasks:
- [ ] Write tests for all repositories:
  - [ ] DiveRepository (expand existing)
  - [ ] BuddyRepository
  - [ ] CertificationRepository
  - [ ] ServiceRecordRepository
  - [ ] DiveCenterRepository
  - [ ] EquipmentRepository (expand existing)
- [ ] Write tests for services:
  - [ ] ExportService (expand existing)
- [ ] Run coverage report: `flutter test --coverage`
- [ ] View coverage: `genhtml coverage/lcov.info -o coverage/html`
- [ ] Fix gaps until 80%+

---

## Task 4.4: Widget Test Coverage (60% Goal) 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 8 hours

### Subtasks:
- [ ] Write widget tests for key pages:
  - [ ] DiveListPage
  - [ ] DiveDetailPage
  - [ ] DiveEditPage (with new buddy picker, dive center picker)
  - [ ] BuddyListPage
  - [ ] BuddyDetailPage
  - [ ] BuddyEditPage
  - [ ] CertificationListPage
  - [ ] DiveCenterListPage
  - [ ] EquipmentListPage (expand existing)
- [ ] Test user interactions (taps, swipes, form input)
- [ ] Test navigation
- [ ] Test state changes

---

## Task 4.5: Integration Tests 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 6 hours

### Subtasks:
- [ ] Write integration tests for:
  - [ ] Complete dive creation flow (with buddies, equipment, dive center)
  - [ ] Dive editing and deletion
  - [ ] Buddy creation and association
  - [ ] Import/export flows
- [ ] Set up test database with seed data
- [ ] Run tests on emulators/simulators

---

## Task 4.6: Performance Testing 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 4 hours

### Subtasks:
- [ ] Create test database with 1000+ dives
- [ ] Test dive list scrolling (frame rate)
- [ ] Test search performance
- [ ] Test export performance (100 dives)
- [ ] Profile app with DevTools
- [ ] Fix any performance bottlenecks found

---

## Task 4.7: Deprecation Warnings 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours

### Subtasks:
- [ ] Fix `withOpacity()` deprecation (replace with `Color.withValues()`)
- [ ] Fix any other deprecation warnings
- [ ] Ensure code is compatible with Flutter 3.5+

---

## Task 4.8: GPS Auto-Capture on Mobile 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours

### Subtasks:
- [ ] Add geolocator package
- [ ] When creating dive on mobile, capture GPS
- [ ] Suggest nearby dive sites (within 1km radius)
- [ ] "Use Current Location" button in site edit
- [ ] Handle permission request/denial

**New dependencies:**
```yaml
dependencies:
  geolocator: ^10.1.0
  geocoding: ^2.1.0  # For reverse geocoding
```

---

## Task 4.9: Reverse Geocoding for Sites 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 4.8

### Subtasks:
- [ ] When GPS is set (manually or auto), reverse geocode
- [ ] Auto-populate country and region fields
- [ ] User can override
- [ ] Handle rate limits and errors

---

## Task 4.10: Map Marker Clustering 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours

### Subtasks:
- [ ] Add flutter_map_marker_cluster package
- [ ] Cluster nearby dive sites on map
- [ ] Different marker colors for dive count
- [ ] Tap cluster to zoom in
- [ ] Tap marker to view site detail

**New dependencies:**
```yaml
dependencies:
  flutter_map_marker_cluster: ^1.0.0
```

---

## Task 4.11: Records Page (Superlatives) 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours

### Subtasks:
- [ ] Create "Records" page in Statistics
- [ ] Display cards for:
  - [ ] Deepest Dive (depth, date, site)
  - [ ] Longest Dive (duration, date, site)
  - [ ] Coldest Water (temp, date, site)
  - [ ] Best Visibility (visibility, date, site)
  - [ ] Most Species Seen (count, date, site)
  - [ ] Most Dives with Buddy (buddy name, count)
- [ ] Tap card to view dive detail
- [ ] Handle ties (show most recent)

---

## Task 4.12: Profile Chart Zoom/Pan 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 4 hours

### Subtasks:
- [ ] Use fl_chart's InteractiveChart wrapper
- [ ] Enable pinch-to-zoom on mobile
- [ ] Enable scroll-to-zoom on desktop
- [ ] Add pan/drag
- [ ] Add reset zoom button
- [ ] Show depth/time/temp at touch point (crosshair)

**Files to modify:**
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`

---

## Task 4.13: Profile Export as Image 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours

### Subtasks:
- [ ] Add "Export Chart" button in dive detail
- [ ] Render profile chart to PNG
- [ ] Save to device
- [ ] Share via share_plus

---

## Task 4.14: UI Polish & Consistency 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 4 hours

### Subtasks:
- [ ] Ensure consistent spacing/padding across all pages
- [ ] Consistent button styles
- [ ] Loading indicators for all async operations
- [ ] Empty states for all lists
- [ ] Confirm dialogs for destructive actions
- [ ] Form validation messages
- [ ] Accessibility improvements (labels, hints)

---

## Task 4.15: Documentation Complete 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 4 hours

### Subtasks:
- [ ] Update CLAUDE.md with all v1.0 features
- [ ] Update README.md with feature list
- [ ] Write user guide (markdown or PDF)
- [ ] Create FAQ section
- [ ] Document known issues
- [ ] Update ARCHITECTURE.md if needed
- [ ] Add migration notes for users upgrading from MVP

---

## Task 4.16: App Store Preparation 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 6 hours

### Subtasks:
- [ ] Create app icons (all required sizes)
- [ ] Create App Store screenshots (iOS + Android)
- [ ] Write app description
- [ ] Privacy policy
- [ ] Terms of service
- [ ] Set up app signing (iOS + Android)
- [ ] Build release APK/AAB (Android)
- [ ] Build release IPA (iOS)
- [ ] Submit to App Store Connect (iOS)
- [ ] Submit to Google Play Console (Android)

---

## Task 4.17: Final Testing & Bug Bash 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 6 hours

### Subtasks:
- [ ] Test on iOS (iPhone, iPad)
- [ ] Test on Android (phone, tablet)
- [ ] Test on macOS
- [ ] Test on Windows
- [ ] Test on Linux
- [ ] Create test checklist
- [ ] Fix all critical bugs
- [ ] Fix high-priority bugs
- [ ] Document known issues

---

# 📊 Progress Tracking

## Sprint 1 Summary: Buddy System
- **Total Tasks:** 12
- **Estimated Hours:** 33
- **Status:** ⏳ NOT STARTED
- **Start Date:** TBD
- **Target Completion:** Week 2

## Sprint 2 Summary: Certifications & Service Records
- **Total Tasks:** 12
- **Estimated Hours:** 33
- **Status:** ⏳ NOT STARTED
- **Start Date:** Week 3
- **Target Completion:** Week 4

## Sprint 3 Summary: Dive Centers, Conditions & Equipment
- **Total Tasks:** 11
- **Estimated Hours:** 29
- **Status:** ⏳ NOT STARTED
- **Start Date:** Week 5
- **Target Completion:** Week 6

## Sprint 4 Summary: Testing, Polish & Release
- **Total Tasks:** 17
- **Estimated Hours:** 73
- **Status:** ⏳ NOT STARTED
- **Start Date:** Week 7
- **Target Completion:** Week 9

**v1.0 Total:** 52 tasks, ~168 hours, 9 weeks

---

# 🔄 Workflow Instructions for Claude

## How to Work Through This List

1. **Start at the top** - Work through tasks in order unless blocked
2. **Update status** as you work:
   - Change ⏳ TODO → 🏗️ IN PROGRESS when you start
   - Change 🏗️ IN PROGRESS → ✅ DONE when complete
   - Add ⏸️ BLOCKED if you encounter a blocker
3. **Check dependencies** before starting a task
4. **Create branches** for each task: `feature/task-X.Y-description`
5. **Commit frequently** with clear messages
6. **Test as you go** - Don't wait until the end
7. **Ask for clarification** if task is unclear
8. **Update estimates** if actual time differs significantly

## Example Workflow

```bash
# Start Sprint 1, Task 1.1
git checkout develop
git pull
git checkout -b feature/task-1.1-buddy-schema

# Make changes...
# lib/core/database/database.dart

# Test migration
flutter pub run build_runner build --delete-conflicting-outputs

# Commit
git add .
git commit -m "feat: add buddy and dive_buddies tables

- Add buddies table with contact info and cert details
- Add dive_buddies junction table with roles
- Migration from v2 to v3
- Deprecated old buddy text field on dives

Refs: SPRINT-1 Task 1.1"

git push -u origin feature/task-1.1-buddy-schema

# Update this TODO.md:
# Change Task 1.1 status from ⏳ TODO to ✅ DONE
# Move to Task 1.2
```

---

# 📝 Notes & Decisions

## Architecture Decisions

- **Photo Deferral:** Photos moved to v2.0 to focus on core features. Cert card images will use basic image_picker without full media management system.
- **Buddy Migration:** Keep old buddy text field temporarily, mark deprecated, remove in v2.0
- **Permissions:** Request permissions just-in-time, not on app launch
- **Testing:** Prioritize repository tests > widget tests > integration tests

## Open Questions

- [ ] **Certification Agencies:** Should we use a comprehensive hardcoded list or allow user-defined agencies?
- [ ] **Buddy Photo Storage:** Store in app documents or allow reference to device photos?
- [ ] **Multi-language:** Should v1.0 include any localization, or wait for v2.0?
- [ ] **Analytics:** Should we include opt-in crash reporting (Firebase Crashlytics)?

---

# 🐛 Known Issues & Technical Debt

## From MVP Phase

1. **N+1 Queries in DiveRepository** - ⏳ TODO (Sprint 4, Task 4.1)
2. **withOpacity() deprecated** - ⏳ TODO (Sprint 4, Task 4.7)
3. **Limited error handling** - ⏳ TODO (Sprint 4, Task 4.2)
4. **No widget tests** - ⏳ TODO (Sprint 4, Task 4.4)
5. **Media table exists but unused** - ⏸️ DEFERRED to v2.0

## Introduced in v1.0

- Will be documented as discovered during development

---

# 📚 Reference Links

- **Feature Roadmap:** [FEATURE_ROADMAP.md](FEATURE_ROADMAP.md)
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)
- **Developer Guide:** [CLAUDE.md](CLAUDE.md)
- **Migration Strategy:** [docs/MIGRATION_STRATEGY.md](docs/MIGRATION_STRATEGY.md)
- **UI Wireframes:** [docs/UI_WIREFRAMES.md](docs/UI_WIREFRAMES.md)

---

# 📅 v2.0 Preview: Photos & Media

**Note:** Photos have been moved to v2.0 (alongside cloud sync) for the following reasons:

1. **Cloud Dependency:** Photos are much more valuable with cloud backup/sync
2. **Storage Concerns:** Local-only photo storage raises questions about limits and cleanup
3. **Core Features First:** Buddies, certifications, and service tracking are more critical for professional divers
4. **Complexity:** Full media management (thumbnails, EXIF, caching) is a significant effort better suited for v2.0

**v2.0 Photo Tasks Preview:**
- Photo/video attachment to dives
- Bulk photo import with timestamp matching
- EXIF GPS extraction and auto-site suggestion
- Thumbnail generation and caching
- Photo gallery view with swipe
- Full-screen viewer with zoom/pan
- Caption editing
- Export dives with photos (ZIP)
- Cloud photo backup (optional)
- Species tagging in photos (with ML suggestions)
- Underwater color correction filters

---

**Last Updated:** 2025-12-15
**Document Version:** 2.0
**Current Sprint:** Sprint 1 - Buddy System
**Next Review:** End of Sprint 1
