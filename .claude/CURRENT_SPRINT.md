# Current Sprint - v1.0 Development

> **Current Phase:** v1.0 Development
> **Last Updated:** 2025-12-14
> **Sprint:** Sprint 1 - Buddy System
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

# Sprint 1: Buddy System (Weeks 1-2)

## 1.1: Buddy Database Schema (P0)
**Estimated:** 2 hours | **Dependencies:** None

- [ ] Add `buddies` table to database schema
- [ ] Add `dive_buddies` junction table (many-to-many with role)
- [ ] Run code generation
- [ ] Test migration

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

## 1.2: Buddy Entity & Repository (P0)
**Estimated:** 3 hours | **Dependencies:** 1.1

- [ ] Create `lib/features/buddies/domain/entities/buddy.dart`
- [ ] Create `lib/features/buddies/data/repositories/buddy_repository.dart`
- [ ] Implement CRUD methods
- [ ] Write unit tests

---

## 1.3: Buddy Providers (P1)
**Estimated:** 2 hours | **Dependencies:** 1.2

- [ ] Create `lib/features/buddies/presentation/providers/buddy_providers.dart`
- [ ] `buddyRepositoryProvider`
- [ ] `allBuddiesProvider`
- [ ] `buddyByIdProvider(String id)`
- [ ] `buddiesForDiveProvider(String diveId)`
- [ ] `buddySearchProvider(String query)`

---

## 1.4: Buddy List Page (P1)
**Estimated:** 3 hours | **Dependencies:** 1.3

- [ ] Create `lib/features/buddies/presentation/pages/buddy_list_page.dart`
- [ ] List with photo, name, cert level
- [ ] Search bar
- [ ] FAB to add new buddy
- [ ] Empty state
- [ ] Add to navigation and router

---

## 1.5: Buddy Detail Page (P1)
**Estimated:** 3 hours | **Dependencies:** 1.4

- [ ] Create `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- [ ] Display photo, contact info, certs
- [ ] Statistics: total dives together, first/last dive
- [ ] List of shared dives
- [ ] Edit/delete actions

---

## 1.6: Buddy Edit Page (P0)
**Estimated:** 3 hours | **Dependencies:** 1.4

- [ ] Create `lib/features/buddies/presentation/pages/buddy_edit_page.dart`
- [ ] Form: photo, name, email, phone, cert level, agency, notes
- [ ] Validation (name required, email/phone format)
- [ ] Save/cancel

---

## 1.7: Buddy Picker for Dive Edit (P0)
**Estimated:** 4 hours | **Dependencies:** 1.6

- [ ] Create `lib/features/buddies/presentation/widgets/buddy_picker.dart`
- [ ] Multi-select with roles (Buddy, Guide, Instructor, Student, Solo)
- [ ] Display as chips with role badges
- [ ] "Add New Buddy" quick action
- [ ] Modify `dive_edit_page.dart` to use BuddyPicker
- [ ] Handle migration from old buddy text field

---

## 1.8: Update Dive Detail for Buddies (P1)
**Estimated:** 2 hours | **Dependencies:** 1.7

- [ ] Modify `dive_detail_page.dart`
- [ ] Display buddy chips (photo, name, role)
- [ ] Tap chip to navigate to buddy detail
- [ ] Show "Solo dive" if no buddies

---

## 1.9: Buddy Import from Contacts (P2)
**Estimated:** 3 hours | **Dependencies:** 1.6

- [ ] Add flutter_contacts package
- [ ] "Import from Contacts" button
- [ ] Request permission, show contact picker
- [ ] Pre-fill buddy form

---

## 1.10: Testing & Bug Fixes (P0)
**Estimated:** 3 hours | **Dependencies:** All above

- [ ] Unit tests for BuddyRepository
- [ ] Widget tests for pages
- [ ] Test buddy-dive relationships
- [ ] Test deletion behavior

---

# Sprint 2: Certifications & Service Records (Weeks 3-4)

## 2.1-2.6: Certifications Feature (P0-P1)
- [ ] Database schema (certifications table)
- [ ] Entity and repository
- [ ] List, detail, edit pages
- [ ] Photo storage for cert cards
- [ ] Expiry warnings

## 2.7-2.11: Service Records Feature (P0-P1)
- [ ] Verify/create service_records schema
- [ ] Repository with CRUD
- [ ] Service history UI on equipment detail
- [ ] Service record edit dialog
- [ ] Service log PDF export

---

# Sprint 3: Dive Centers & Conditions (Weeks 5-6)

## 3.1-3.6: Dive Centers Feature
- [ ] Database schema (dive_centers table, FK on dives)
- [ ] Entity and repository
- [ ] List, detail, edit pages
- [ ] Add to dive edit form

## 3.7: Conditions Fields
- [ ] Add current_direction, current_strength, swell_height, entry/exit_method, water_type to dives
- [ ] Update dive edit and detail pages

## 3.8-3.10: Equipment Enhancements
- [ ] Add size, status fields to equipment
- [ ] Equipment set templates
- [ ] Weight system fields on dives

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
