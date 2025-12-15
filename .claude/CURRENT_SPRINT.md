# Current Sprint - v1.0 Development

> **Current Phase:** v1.0 Development
> **Last Updated:** 2025-12-14
> **Sprint:** Sprint 3 - Dive Centers & Conditions (COMPLETED)
> **Reference:** See [FEATURE_ROADMAP.md](../FEATURE_ROADMAP.md) for full roadmap

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
- [ ] Write unit tests (deferred to Sprint 4)

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

## 1.9: Buddy Import from Contacts (P2) - DEFERRED
**Estimated:** 3 hours | **Dependencies:** 1.6

- [ ] Add flutter_contacts package
- [ ] "Import from Contacts" button
- [ ] Request permission, show contact picker
- [ ] Pre-fill buddy form

*Deferred to v1.5 - lower priority feature*

---

## 1.10: Testing & Bug Fixes (P0) - PARTIAL
**Estimated:** 3 hours | **Dependencies:** All above

- [ ] Unit tests for BuddyRepository (deferred to Sprint 4)
- [ ] Widget tests for pages (deferred to Sprint 4)
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
- [ ] Service log PDF export (deferred to Sprint 4)

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
- [ ] Update dive edit and detail page UI (entity ready, UI deferred to Sprint 4)

## 3.8-3.10: Equipment Enhancements (P1) - DONE
- [x] Add size, status fields to equipment entity
- [x] Add purchasePrice, purchaseCurrency to equipment entity
- [x] Equipment set tables exist (EquipmentSets, EquipmentSetItems)
- [x] Equipment set routes and pages exist
- [x] Weight system fields on dives (weightAmount, weightType, weightBeltUsed)
- [ ] Update equipment edit page UI with new fields (entity ready, UI deferred to Sprint 4)

---

# Sprint 4: Testing & Polish (Weeks 7-9)

## Critical Tasks (P0)
- [ ] Fix N+1 query issues in DiveRepository
- [ ] Unit test coverage (80% goal)
- [ ] App store preparation

## High Priority (P1)
- [ ] Error handling improvements
- [ ] Widget test coverage (60% goal)
- [ ] Integration tests
- [ ] Performance testing (1000+ dives)
- [ ] Profile chart zoom/pan
- [ ] GPS auto-capture on mobile
- [ ] UI polish & consistency
- [ ] Documentation complete

## Medium Priority (P2)
- [ ] Fix deprecation warnings
- [ ] Reverse geocoding for sites
- [ ] Map marker clustering
- [ ] Records page (superlatives)
- [ ] Profile export as image

---

# Known Issues & Technical Debt

## From MVP Phase
1. **N+1 Queries in DiveRepository** - Sprint 4 priority
2. **withOpacity() deprecated** - Replace with Color.withValues()
3. **Limited error handling** - Add try-catch and logging
4. **No widget tests** - Sprint 4 priority
5. **Media table exists but unused** - Deferred to v2.0

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

# Open Questions

- [ ] Certification agencies: hardcoded list or user-defined?
- [ ] Buddy photo storage: app documents or device photos reference?
- [ ] Include any localization in v1.0?
- [ ] Include opt-in crash reporting?

---

**v1.0 Total Estimate:** ~52 tasks, ~168 hours, 9 weeks
