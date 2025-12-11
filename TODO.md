# Submersion Development TODO List
## Actionable Tasks for AI-Assisted Development

> **Current Phase:** v1.0 Development
> **Last Updated:** 2025-12-11
> **Sprint:** Sprint 1 - Photos & Media

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

# 🚀 SPRINT 1: Photos & Media (Weeks 1-4)

## Task 1.1: Database Schema for Media 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** None

### Subtasks:
- [ ] Review existing `media` table schema in `lib/core/database/database.dart`
- [ ] Add missing fields if needed:
  - [ ] `dive_id` (foreign key to dives)
  - [ ] `file_path` (local storage path)
  - [ ] `file_type` (photo, video)
  - [ ] `caption` (user description)
  - [ ] `taken_at` (datetime from EXIF or user input)
  - [ ] `gps_latitude`, `gps_longitude` (from EXIF)
  - [ ] `thumbnail_path` (cached thumbnail)
  - [ ] `file_size_bytes`
  - [ ] `width`, `height` (image dimensions)
- [ ] Create migration script from current schema version to new version
- [ ] Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Test migration on sample database

**Files to modify:**
- `lib/core/database/database.dart`
- `docs/MIGRATION_STRATEGY.md` (document migration)

---

## Task 1.2: Media Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 4 hours
**Dependencies:** Task 1.1

### Subtasks:
- [ ] Create `lib/features/media/data/media_entity.dart` (domain entity)
- [ ] Create `lib/features/media/data/media_repository.dart`
- [ ] Implement CRUD methods:
  - [ ] `Future<Media> createMedia(MediaCompanion media)`
  - [ ] `Future<Media?> getMediaById(String id)`
  - [ ] `Future<List<Media>> getMediaByDiveId(String diveId)`
  - [ ] `Future<List<Media>> getAllMedia()`
  - [ ] `Future<void> updateMedia(String id, MediaCompanion media)`
  - [ ] `Future<void> deleteMedia(String id)` (also delete file from storage)
  - [ ] `Future<void> deleteMediaByDiveId(String diveId)` (cascade delete)
- [ ] Add file system operations:
  - [ ] Copy file to app documents directory
  - [ ] Generate and cache thumbnail
  - [ ] Delete file from storage on media deletion
- [ ] Write unit tests for repository

**Files to create:**
- `lib/features/media/data/media_entity.dart`
- `lib/features/media/data/media_repository.dart`
- `test/features/media/data/media_repository_test.dart`

---

## Task 1.3: Media Storage Service 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** None

### Subtasks:
- [ ] Create `lib/core/services/media_storage_service.dart`
- [ ] Implement methods:
  - [ ] `Future<String> saveMediaFile(File file, String diveId)` - Copy file to app storage, return path
  - [ ] `Future<String> generateThumbnail(String imagePath)` - Create thumbnail, return path
  - [ ] `Future<void> deleteMediaFile(String filePath)` - Delete file
  - [ ] `Future<Map<String, dynamic>> extractEXIF(String imagePath)` - Read EXIF data
  - [ ] `Future<int> getFileSize(String filePath)`
  - [ ] `Future<Size> getImageDimensions(String imagePath)`
- [ ] Add error handling for file operations
- [ ] Use path_provider for app documents directory
- [ ] Use image package for thumbnail generation and EXIF parsing
- [ ] Write unit tests

**New dependencies to add to pubspec.yaml:**
```yaml
dependencies:
  image: ^4.0.0  # Image manipulation and EXIF reading
```

**Files to create:**
- `lib/core/services/media_storage_service.dart`
- `test/core/services/media_storage_service_test.dart`

---

## Task 1.4: Media Providers (Riverpod) 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 1.2, Task 1.3

### Subtasks:
- [ ] Create `lib/features/media/providers/media_providers.dart`
- [ ] Create providers:
  - [ ] `mediaRepositoryProvider` - Provider<MediaRepository>
  - [ ] `mediaStorageServiceProvider` - Provider<MediaStorageService>
  - [ ] `mediaByDiveProvider(String diveId)` - FutureProvider<List<Media>>
  - [ ] `allMediaProvider` - FutureProvider<List<Media>>
- [ ] Add state management for media operations
- [ ] Ensure providers invalidate on changes

**Files to create:**
- `lib/features/media/providers/media_providers.dart`

---

## Task 1.5: Photo Picker Integration 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 1.2, Task 1.3, Task 1.4

### Subtasks:
- [ ] Create `lib/shared/widgets/media_picker_button.dart` - Reusable widget
- [ ] Implement photo picker:
  - [ ] Single photo selection
  - [ ] Multiple photo selection
  - [ ] Camera capture option
  - [ ] Video selection support (future)
- [ ] Add permission handling:
  - [ ] Camera permission
  - [ ] Photo library permission
  - [ ] Handle permission denial gracefully
- [ ] Process selected media:
  - [ ] Save to app storage
  - [ ] Generate thumbnail
  - [ ] Extract EXIF data
  - [ ] Create Media entity
  - [ ] Save to database
- [ ] Show loading indicator during processing
- [ ] Handle errors (file too large, unsupported format, etc.)

**Files to create:**
- `lib/shared/widgets/media_picker_button.dart`

**Files to modify:**
- Update AndroidManifest.xml and Info.plist for permissions

---

## Task 1.6: Photo Gallery Widget 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 4 hours
**Dependencies:** Task 1.4, Task 1.5

### Subtasks:
- [ ] Create `lib/features/media/presentation/widgets/media_gallery.dart`
- [ ] Implement grid layout for photos:
  - [ ] 3 columns on mobile, 4-5 on tablet/desktop
  - [ ] Thumbnail display with aspect ratio preserved
  - [ ] Loading placeholder while thumbnails load
- [ ] Add tap interaction to open full-screen viewer
- [ ] Add long-press menu:
  - [ ] View full size
  - [ ] Edit caption
  - [ ] Delete photo (with confirmation)
  - [ ] Share photo
- [ ] Display photo count badge
- [ ] Empty state ("No photos yet" with add button)
- [ ] Implement photo reordering (drag & drop on desktop)

**Files to create:**
- `lib/features/media/presentation/widgets/media_gallery.dart`

---

## Task 1.7: Full-Screen Photo Viewer 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 1.6

### Subtasks:
- [ ] Create `lib/features/media/presentation/pages/photo_viewer_page.dart`
- [ ] Use photo_view package for zoom/pan functionality
- [ ] Implement features:
  - [ ] Swipe left/right to navigate between photos
  - [ ] Pinch to zoom, double-tap to zoom
  - [ ] Display caption at bottom (overlay)
  - [ ] Display metadata (date, GPS, dimensions) - toggle overlay
  - [ ] Share button in app bar
  - [ ] Delete button with confirmation
  - [ ] Edit caption button
- [ ] Add hero animation from gallery thumbnail
- [ ] Support both portrait and landscape orientation

**Files to create:**
- `lib/features/media/presentation/pages/photo_viewer_page.dart`

---

## Task 1.8: Add Photos to Dive Edit Form 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 1.5, Task 1.6

### Subtasks:
- [ ] Modify `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- [ ] Add "Photos" section below existing fields
- [ ] Integrate MediaGallery widget
- [ ] Add MediaPickerButton (camera + gallery options)
- [ ] Load existing photos when editing dive
- [ ] Handle photo deletion (remove from dive, optionally delete file)
- [ ] Save photo associations when saving dive
- [ ] Update UI to show photo count in section header

**Files to modify:**
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

---

## Task 1.9: Display Photos on Dive Detail Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 1.6, Task 1.7

### Subtasks:
- [ ] Modify `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- [ ] Add "Photos" section after profile chart
- [ ] Integrate MediaGallery widget (read-only mode)
- [ ] Tap photo to open full-screen viewer
- [ ] Show photo count in section header
- [ ] Handle empty state (no photos)

**Files to modify:**
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

---

## Task 1.10: Photo Caption Editing 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 1.7

### Subtasks:
- [ ] Create caption edit dialog
- [ ] Add "Edit Caption" to photo long-press menu
- [ ] Add "Edit Caption" button in full-screen viewer
- [ ] Save caption to database
- [ ] Update gallery to show caption on hover (desktop) or in overlay

**Files to create:**
- `lib/features/media/presentation/widgets/caption_edit_dialog.dart`

---

## Task 1.11: Export Dives with Photos 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 4 hours
**Dependencies:** Task 1.2

### Subtasks:
- [ ] Modify `lib/core/services/export_service.dart`
- [ ] Update PDF export:
  - [ ] Include photos in dive pages
  - [ ] Add photo thumbnails below dive details
  - [ ] Include captions
- [ ] Add ZIP export option:
  - [ ] Create folder structure: `DiveLogs_Export_YYYYMMDD/`
  - [ ] Subfolder per dive: `Dive_001_Location_Date/`
  - [ ] Copy all photos for each dive
  - [ ] Include dive summary text file or CSV
- [ ] Update UDDF export to reference photo files (external references)
- [ ] Add export option toggle in settings: "Include photos in exports"

**Files to modify:**
- `lib/core/services/export_service.dart`

**New dependencies:**
```yaml
dependencies:
  archive: ^3.4.0  # For creating ZIP files
```

---

## Task 1.12: Testing & Bug Fixes 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 4 hours
**Dependencies:** All above tasks

### Subtasks:
- [ ] Write unit tests for MediaRepository
- [ ] Write unit tests for MediaStorageService
- [ ] Write widget tests for MediaGallery
- [ ] Write widget tests for PhotoViewerPage
- [ ] Test photo picker on iOS and Android
- [ ] Test permissions handling
- [ ] Test with various image formats (JPEG, PNG, HEIC)
- [ ] Test with large images (10MB+)
- [ ] Test thumbnail generation
- [ ] Test EXIF extraction
- [ ] Test photo deletion (cascade delete)
- [ ] Test export with photos
- [ ] Fix any bugs found

**Files to create/modify:**
- `test/features/media/` - All test files

---

## Task 1.13: Documentation 📌 P2
**Status:** ⏳ TODO
**Estimated:** 1 hour
**Dependencies:** Task 1.12

### Subtasks:
- [ ] Update CLAUDE.md with media feature details
- [ ] Document media storage strategy
- [ ] Document EXIF extraction capabilities
- [ ] Update README.md feature list
- [ ] Add comments to key methods

**Files to modify:**
- `CLAUDE.md`
- `README.md`
- Various source files (inline documentation)

---

# 🚀 SPRINT 2: Buddy System (Weeks 5-6)

## Task 2.1: Buddy Database Schema 🔥 P0
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

## Task 2.2: Buddy Entity & Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.1

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

## Task 2.3: Buddy Providers 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 2.2

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

## Task 2.4: Buddy List Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.3

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

## Task 2.5: Buddy Detail Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.4

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

## Task 2.6: Buddy Edit Page 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.4

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

## Task 2.7: Buddy Picker for Dive Edit 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 4 hours
**Dependencies:** Task 2.6

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

## Task 2.8: Update Dive Detail to Show Buddies 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 2.7

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

## Task 2.9: Buddy Import from Contacts (Mobile) 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 2.6

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

## Task 2.10: Buddy Export & Sharing 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 2.5

### Subtasks:
- [ ] Add "Share Buddy" action in buddy detail page
- [ ] Generate VCF (vCard) file with buddy contact info
- [ ] Use share_plus to share VCF
- [ ] Export all buddies to CSV (from buddy list page)

---

## Task 2.11: Testing & Bug Fixes 🔥 P0
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

## Task 2.12: Documentation 📌 P2
**Status:** ⏳ TODO
**Estimated:** 1 hour
**Dependencies:** Task 2.11

### Subtasks:
- [ ] Update CLAUDE.md
- [ ] Update README.md
- [ ] Document buddy feature

---

# 🚀 SPRINT 3: Certifications & Service Records (Weeks 7-8)

## Task 3.1: Certifications Database Schema 🔥 P0
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

## Task 3.2: Certification Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.1

### Subtasks:
- [ ] Create entity and repository
- [ ] CRUD operations
- [ ] Methods for checking expiry status
- [ ] Unit tests

---

## Task 3.3: Certification List Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.2

### Subtasks:
- [ ] List all certifications
- [ ] Display card images as thumbnails
- [ ] Show expiry warnings (red if expired, yellow if expiring <30 days)
- [ ] Search/filter by agency, level
- [ ] Add button for new cert

---

## Task 3.4: Certification Detail Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 3.3

### Subtasks:
- [ ] Display full cert card image
- [ ] Show all cert details
- [ ] Edit/delete actions
- [ ] Share cert (export image or PDF)

---

## Task 3.5: Certification Edit Page 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.3

### Subtasks:
- [ ] Form with all fields
- [ ] Agency dropdown (PADI, SSI, NAUI, SDI, TDI, GUE, RAID, BSAC, etc.)
- [ ] Level dropdown (Open Water, Advanced, Rescue, Divemaster, Instructor, Specialty names)
- [ ] Photo picker for cert card
- [ ] Date pickers
- [ ] Validation
- [ ] Save/cancel

---

## Task 3.6: Certification Wallet View 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.4

### Subtasks:
- [ ] Card-style UI (like Apple Wallet)
- [ ] Swipe between certs
- [ ] Tap to flip card (front/back if multiple images)
- [ ] Export as image for sharing

---

## Task 3.7: Service Records Schema 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 1 hour

### Subtasks:
- [ ] Service records table already defined, verify schema
- [ ] Create migration if needed

---

## Task 3.8: Service Records Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 3.7

### Subtasks:
- [ ] Create entity (if not exists, check existing code)
- [ ] Create repository with CRUD
- [ ] Method to get service history for equipment
- [ ] Unit tests

---

## Task 3.9: Service History UI 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 3.8

### Subtasks:
- [ ] Add "Service History" section to equipment detail page
- [ ] List all service records (date, shop, cost, work done)
- [ ] Add service record button
- [ ] Edit/delete service records
- [ ] Update next service due date

---

## Task 3.10: Service Record Edit Dialog 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 3.9

### Subtasks:
- [ ] Form: date, shop name, cost, work performed, next due date, notes
- [ ] Date picker
- [ ] Cost input with currency
- [ ] Save/cancel

---

## Task 3.11: Service Log Export 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 3.9

### Subtasks:
- [ ] Export equipment service history to PDF
- [ ] Include all service records
- [ ] Formatted like a maintenance log

---

## Task 3.12: Testing & Docs 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours

### Subtasks:
- [ ] Unit tests
- [ ] Widget tests
- [ ] Update documentation

---

# 🚀 SPRINT 4: Dive Centers, Conditions & Equipment (Weeks 9-10)

## Task 4.1: Dive Centers Database Schema 🔥 P0
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

## Task 4.2: Dive Center Repository 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 4.1

### Subtasks:
- [ ] Create entity and repository
- [ ] CRUD operations
- [ ] Search by name/location
- [ ] Get all dives for a center
- [ ] Unit tests

---

## Task 4.3: Dive Center List Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 4.2

### Subtasks:
- [ ] List all dive centers
- [ ] Search bar
- [ ] Display name, location, dive count
- [ ] Add new button
- [ ] Tap to view detail

---

## Task 4.4: Dive Center Detail Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 4.3

### Subtasks:
- [ ] Display center info
- [ ] Contact details (tap to call/email/open website)
- [ ] Map location
- [ ] List all dives at this center
- [ ] Statistics (total dives, date range)
- [ ] Edit/delete actions

---

## Task 4.5: Dive Center Edit Page 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 4.3

### Subtasks:
- [ ] Form with all fields
- [ ] GPS picker (use current location or map)
- [ ] Validation
- [ ] Save/cancel

---

## Task 4.6: Add Dive Center to Dive Edit 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 4.5

### Subtasks:
- [ ] Add dive center picker to dive edit form
- [ ] Dropdown with search
- [ ] "Add new center" quick action
- [ ] Boat name and operator name text fields
- [ ] Save relationships

**Files to modify:**
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

---

## Task 4.7: Add Conditions Fields to Dive Edit 🎯 P1
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

## Task 4.8: Equipment Enhancements 🎯 P1
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

## Task 4.9: Equipment Set Templates 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours
**Dependencies:** Task 4.8

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

## Task 4.10: Weight System Fields 📌 P2
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

## Task 4.11: Testing & Docs 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 3 hours

---

# 🚀 SPRINT 5: Testing, Polish & v1.0 Release (Weeks 11-12)

## Task 5.1: Fix N+1 Query Issues 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 4 hours

### Subtasks:
- [ ] Refactor `DiveRepository.getAllDives()` to use JOINs
- [ ] Load tanks, profiles, sites in single query
- [ ] Benchmark performance improvement (before/after)
- [ ] Update repository tests

**Files to modify:**
- `lib/features/dive_log/data/dive_repository.dart`

---

## Task 5.2: Error Handling Improvements 🎯 P1
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

## Task 5.3: Unit Test Coverage (80% Goal) 🔥 P0
**Status:** ⏳ TODO
**Estimated:** 8 hours

### Subtasks:
- [ ] Write tests for all repositories:
  - [ ] DiveRepository (expand existing)
  - [ ] MediaRepository
  - [ ] BuddyRepository
  - [ ] CertificationRepository
  - [ ] ServiceRecordRepository
  - [ ] DiveCenterRepository
  - [ ] EquipmentRepository (expand existing)
- [ ] Write tests for services:
  - [ ] ExportService (expand existing)
  - [ ] MediaStorageService
- [ ] Run coverage report: `flutter test --coverage`
- [ ] View coverage: `genhtml coverage/lcov.info -o coverage/html`
- [ ] Fix gaps until 80%+

---

## Task 5.4: Widget Test Coverage (60% Goal) 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 8 hours

### Subtasks:
- [ ] Write widget tests for key pages:
  - [ ] DiveListPage
  - [ ] DiveDetailPage
  - [ ] DiveEditPage
  - [ ] MediaGallery
  - [ ] PhotoViewerPage
  - [ ] BuddyListPage
  - [ ] BuddyDetailPage
  - [ ] BuddyEditPage
  - [ ] CertificationListPage
  - [ ] EquipmentListPage (expand existing)
- [ ] Test user interactions (taps, swipes, form input)
- [ ] Test navigation
- [ ] Test state changes

---

## Task 5.5: Integration Tests 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 6 hours

### Subtasks:
- [ ] Write integration tests for:
  - [ ] Complete dive creation flow (with photos, buddies, equipment)
  - [ ] Dive editing and deletion
  - [ ] Photo attachment and viewing
  - [ ] Import/export flows
  - [ ] Buddy creation and association
- [ ] Set up test database with seed data
- [ ] Run tests on emulators/simulators

---

## Task 5.6: Performance Testing 🎯 P1
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

## Task 5.7: Deprecation Warnings 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours

### Subtasks:
- [ ] Fix `withOpacity()` deprecation (replace with `Color.withValues()`)
- [ ] Fix any other deprecation warnings
- [ ] Ensure code is compatible with Flutter 3.5+

---

## Task 5.8: GPS Auto-Capture on Mobile 🎯 P1
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

## Task 5.9: Reverse Geocoding for Sites 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours
**Dependencies:** Task 5.8

### Subtasks:
- [ ] When GPS is set (manually or auto), reverse geocode
- [ ] Auto-populate country and region fields
- [ ] User can override
- [ ] Handle rate limits and errors

---

## Task 5.10: Map Marker Clustering 📌 P2
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

## Task 5.11: Records Page (Superlatives) 📌 P2
**Status:** ⏳ TODO
**Estimated:** 3 hours

### Subtasks:
- [ ] Create "Records" page in Statistics
- [ ] Display cards for:
  - [ ] Deepest Dive (depth, date, site, photo)
  - [ ] Longest Dive (duration, date, site)
  - [ ] Coldest Water (temp, date, site)
  - [ ] Best Visibility (visibility, date, site)
  - [ ] Most Species Seen (count, date, site)
  - [ ] Longest Dive Trip (days, location, dive count)
- [ ] Tap card to view dive detail
- [ ] Handle ties (show most recent)

---

## Task 5.12: Profile Chart Zoom/Pan 🎯 P1
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

## Task 5.13: Profile Export as Image 📌 P2
**Status:** ⏳ TODO
**Estimated:** 2 hours

### Subtasks:
- [ ] Add "Export Chart" button in dive detail
- [ ] Render profile chart to PNG
- [ ] Save to device
- [ ] Share via share_plus

---

## Task 5.14: UI Polish & Consistency 🎯 P1
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

## Task 5.15: Documentation Complete 🎯 P1
**Status:** ⏳ TODO
**Estimated:** 4 hours

### Subtasks:
- [ ] Update CLAUDE.md with all v1.0 features
- [ ] Update README.md
- [ ] Write user guide (markdown or PDF)
- [ ] Create FAQ section
- [ ] Document known issues
- [ ] Update ARCHITECTURE.md if needed

---

## Task 5.16: App Store Preparation 🔥 P0
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

## Task 5.17: Final Testing & Bug Bash 🔥 P0
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

## Sprint 1 Summary: Photos & Media
- **Total Tasks:** 13
- **Estimated Hours:** 37
- **Status:** ⏳ NOT STARTED
- **Start Date:** TBD
- **Target Completion:** Week 4

## Sprint 2 Summary: Buddy System
- **Total Tasks:** 12
- **Estimated Hours:** 33
- **Status:** ⏳ NOT STARTED
- **Start Date:** Week 5
- **Target Completion:** Week 6

## Sprint 3 Summary: Certifications & Service Records
- **Total Tasks:** 12
- **Estimated Hours:** 33
- **Status:** ⏳ NOT STARTED
- **Start Date:** Week 7
- **Target Completion:** Week 8

## Sprint 4 Summary: Dive Centers, Conditions & Equipment
- **Total Tasks:** 11
- **Estimated Hours:** 29
- **Status:** ⏳ NOT STARTED
- **Start Date:** Week 9
- **Target Completion:** Week 10

## Sprint 5 Summary: Testing, Polish & Release
- **Total Tasks:** 17
- **Estimated Hours:** 73
- **Status:** ⏳ NOT STARTED
- **Start Date:** Week 11
- **Target Completion:** Week 12

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
git checkout -b feature/task-1.1-media-schema

# Make changes...
# lib/core/database/database.dart

# Test migration
flutter pub run build_runner build --delete-conflicting-outputs

# Commit
git add .
git commit -m "feat: add media table schema with EXIF support

- Add media table with fields for photos/videos
- Add foreign key to dives
- Include GPS, caption, file metadata fields
- Create migration from v2 to v3

Refs: SPRINT-1 Task 1.1"

git push -u origin feature/task-1.1-media-schema

# Update this TODO.md:
# Change Task 1.1 status from ⏳ TODO to ✅ DONE
# Move to Task 1.2
```

---

# 📝 Notes & Decisions

## Architecture Decisions

- **Media Storage:** Store files in app documents directory, not database (file paths only)
- **Thumbnail Strategy:** Generate thumbnails on import, cache in separate directory
- **Buddy Migration:** Keep old buddy text field temporarily, mark deprecated, remove in v2.0
- **Permissions:** Request permissions just-in-time, not on app launch
- **Testing:** Prioritize repository tests > widget tests > integration tests

## Open Questions

- [ ] **Photo Storage Limits:** Should we impose max photo size (e.g., 10MB)? Compress larger?
- [ ] **Cloud Photo Backup:** v2.0 feature, but should we design schema now for sync?
- [ ] **Certification Agencies:** Comprehensive list vs user-defined?
- [ ] **Multi-language:** Should v1.0 include any localization, or wait for v2.0?
- [ ] **Analytics:** Should we include opt-in crash reporting (Firebase Crashlytics)?

---

# 🐛 Known Issues & Technical Debt

## From MVP Phase

1. **N+1 Queries in DiveRepository** - ⏳ TODO (Sprint 5, Task 5.1)
2. **withOpacity() deprecated** - ⏳ TODO (Sprint 5, Task 5.7)
3. **Limited error handling** - ⏳ TODO (Sprint 5, Task 5.2)
4. **No widget tests** - ⏳ TODO (Sprint 5, Task 5.4)
5. **Media table exists but unused** - ⏳ TODO (Sprint 1, Tasks 1.1-1.13)

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

**Last Updated:** 2025-12-11
**Document Version:** 1.0
**Current Sprint:** Sprint 1 - Photos & Media
**Next Review:** End of Sprint 1
