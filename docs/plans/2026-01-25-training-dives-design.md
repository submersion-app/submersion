# Training Dives Feature Design

> **Created:** 2026-01-25
> **Status:** Approved
> **Target:** v1.5

## Overview

Implement training dive tracking with course management, instructor signatures, and certification linking. This enables divers to maintain professional training logs with instructor sign-off.

## Requirements

1. **Course Entity** - Track training courses with instructor details
2. **Dive-Course Association** - Link training dives to courses (many-to-one)
3. **Bidirectional Certification Link** - Course links to earned cert and vice versa
4. **Instructor Signatures** - Per-dive signature capture and storage
5. **Training Log Export** - PDF with signatures (future phase)

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Course-Cert relationship | Bidirectional | Best navigation UX between related records |
| Instructor storage | Buddy FK + text fallback | Flexible: use buddy if in system, otherwise store name/number |
| Instructor comments | Reuse existing notes field | No schema change, simpler implementation |
| Signature scope | Per-dive | Standard practice for training logs, granular verification |
| Signature types | Instructor only | Covers main use case, avoids complexity |

---

## Data Model

### New Table: `courses`

```sql
CREATE TABLE courses (
  id TEXT PRIMARY KEY,
  diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  agency TEXT NOT NULL,
  start_date INTEGER NOT NULL,
  completion_date INTEGER,  -- null = in progress
  instructor_id TEXT REFERENCES buddies(id) ON DELETE SET NULL,
  instructor_name TEXT,
  instructor_number TEXT,
  certification_id TEXT REFERENCES certifications(id) ON DELETE SET NULL,
  location TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### Schema Changes

**dives table:**
- Add `course_id TEXT REFERENCES courses(id) ON DELETE SET NULL`

**certifications table:**
- Add `course_id TEXT REFERENCES courses(id) ON DELETE SET NULL`

**media table:**
- Add `signer_id TEXT` (buddy ID if known)
- Add `signer_name TEXT` (always populated)

### Schema Version

Bump to **v19** with migration for existing databases.

---

## Domain Entity

### Course

```dart
class Course extends Equatable {
  final String id;
  final String diverId;
  final String name;
  final CertificationAgency agency;
  final DateTime startDate;
  final DateTime? completionDate;
  final String? instructorId;      // FK to buddy
  final String? instructorName;    // Text fallback
  final String? instructorNumber;
  final String? certificationId;   // FK to cert earned
  final String? location;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed properties
  bool get isCompleted => completionDate != null;
  bool get isInProgress => completionDate == null;
  String get instructorDisplay => instructorName ?? 'Unknown';

  // Constructor, copyWith, props...
}
```

---

## Repository Methods

### CourseRepository

```dart
class CourseRepository {
  // CRUD
  Future<List<Course>> getAllCourses();
  Future<Course?> getCourseById(String id);
  Future<Course> createCourse(Course course);
  Future<Course> updateCourse(Course course);
  Future<void> deleteCourse(String id);

  // Queries
  Future<List<Course>> getCoursesForDiver(String diverId);
  Future<List<Course>> getInProgressCourses(String diverId);
  Future<List<Course>> getCompletedCourses(String diverId);
  Future<List<Course>> getCoursesByAgency(CertificationAgency agency);

  // Relationships
  Future<Course?> getCourseForDive(String diveId);
  Future<Course?> getCourseForCertification(String certId);
  Future<List<Dive>> getDivesForCourse(String courseId);
  Future<int> getDiveCountForCourse(String courseId);
}
```

### Updated Repositories

**DiveRepository:**
- `getDivesForCourse(courseId)` - already covered by CourseRepository

**CertificationRepository:**
- `getCertificationForCourse(courseId)`

---

## Riverpod Providers

```dart
// All courses for current diver
final allCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final diverId = ref.watch(currentDiverIdProvider);
  final repository = ref.watch(courseRepositoryProvider);
  return repository.getCoursesForDiver(diverId);
});

// Filtered by status
final inProgressCoursesProvider = FutureProvider<List<Course>>(...);
final completedCoursesProvider = FutureProvider<List<Course>>(...);

// Single course by ID
final courseByIdProvider = FutureProvider.family<Course?, String>(...);

// Dives linked to a course
final courseDivesProvider = FutureProvider.family<List<Dive>, String>(...);

// Mutable state for CRUD
final courseNotifierProvider = StateNotifierProvider<CourseNotifier, AsyncValue<List<Course>>>(...);
```

---

## UI Components

### New Pages

| Page | Route | Description |
|------|-------|-------------|
| Course List | `/courses` | All courses with filter (All/In Progress/Completed) |
| Course Detail | `/courses/:id` | Course info, instructor, linked dives, cert |
| Course Edit | `/courses/:id/edit` | Create/edit course form |

### New Widgets

| Widget | Purpose |
|--------|---------|
| `CourseCard` | Summary card for list display |
| `CoursePicker` | Dropdown for selecting course on dive edit |
| `CourseProgressIndicator` | Visual progress (X/Y dives) |
| `SignatureCaptureWidget` | Canvas drawing with clear/save |
| `SignatureDisplayWidget` | Show saved signature image |

### Modified Pages

| Page | Changes |
|------|---------|
| Dive Edit | Add course picker dropdown (in-progress courses only) |
| Dive Detail | Show course link, signature display, "Sign" action |
| Certification Detail | Show linked course with navigation |

---

## Signature Capture

### Widget Behavior

1. Full-width canvas drawing area
2. Touch/stylus input for signature
3. Clear button to reset
4. Signer name field (pre-filled from instructor buddy if available)
5. Save button captures canvas as PNG

### Storage

- PNG saved to app documents: `signatures/{diveId}_{timestamp}.png`
- Media record created with:
  - `diveId` = signed dive
  - `fileType` = 'instructor_signature'
  - `filePath` = PNG path
  - `signerId` = instructor buddy ID (if known)
  - `signerName` = instructor name (always)
  - `takenAt` = signature timestamp

### Display

- Show signature image on dive detail page (if exists)
- Include signer name and timestamp
- Tap to view full-size

---

## File Structure

### New Files

```
lib/features/courses/
├── data/
│   └── repositories/
│       └── course_repository.dart
├── domain/
│   └── entities/
│       └── course.dart
└── presentation/
    ├── pages/
    │   ├── course_list_page.dart
    │   ├── course_detail_page.dart
    │   └── course_edit_page.dart
    ├── providers/
    │   └── course_providers.dart
    └── widgets/
        ├── course_card.dart
        ├── course_picker.dart
        └── course_progress_indicator.dart

lib/features/signatures/
├── data/
│   └── services/
│       └── signature_storage_service.dart
└── presentation/
    ├── widgets/
    │   ├── signature_capture_widget.dart
    │   └── signature_display_widget.dart
    └── providers/
        └── signature_providers.dart
```

### Modified Files

```
lib/core/database/database.dart
lib/core/router/router.dart
lib/features/dive_log/presentation/pages/dive_edit_page.dart
lib/features/dive_log/presentation/pages/dive_detail_page.dart
lib/features/certifications/domain/entities/certification.dart
lib/features/certifications/presentation/pages/certification_detail_page.dart
```

---

## Implementation Order

### Phase 1: Database & Domain Layer
1. Add `courses` table to database.dart (schema v19)
2. Add `courseId` FK to `dives` table
3. Add `courseId` FK to `certifications` table
4. Add `signerId`, `signerName` fields to `media` table
5. Create `Course` domain entity
6. Create migration for existing databases

### Phase 2: Data Layer
7. Create `CourseRepository` with CRUD + queries
8. Update `DiveRepository` - course filtering
9. Update `CertificationRepository` - course lookup

### Phase 3: State Management
10. Create course providers

### Phase 4: UI - Course Management
11. Course list page with filtering
12. Course detail page
13. Course edit page with instructor picker

### Phase 5: UI - Integration
14. Add course picker to dive edit page
15. Show course link on dive detail page
16. Show course link on certification detail page

### Phase 6: Signature Feature
17. Signature capture widget
18. Signature storage service
19. "Sign Dive" action on dive detail
20. Signature display on dive detail page

### Phase 7: Export (Future)
21. Training log PDF export with signatures

---

## Testing Strategy

### Unit Tests
- Course entity: copyWith, equality, computed properties
- CourseRepository: CRUD operations, queries
- Signature storage service: file operations

### Widget Tests
- Course list filtering
- Course picker behavior
- Signature capture canvas interactions

### Integration Tests
- Create course → add dives → complete → link cert
- Sign dive → verify media record → display signature

---

## Dependencies

No new packages required. Uses existing:
- `drift` for database
- `flutter_riverpod` for state
- `go_router` for navigation
- Canvas API for signature drawing (built into Flutter)

---

## Success Criteria

- [ ] Create/edit/delete courses
- [ ] Link dives to courses
- [ ] Bidirectional course-certification navigation
- [ ] Capture instructor signature per dive
- [ ] Display signature on dive detail
- [ ] Filter courses by status
- [ ] Course progress indicator (X/Y dives)
