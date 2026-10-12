# Multiple Courses per Dive and Certifications per Course

Issue: #2515

## Problem

A dive belongs to at most one training course (`dives.course_id`), and a course
links to at most one certification (`courses.certification_id`). Combined
courses break both limits. TDI Advanced Nitrox / Decompression Procedures is
usually taught as one course over one set of dives, and it issues two distinct
cards, each with its own card number. Recognitions (`additionalCredentials`)
do not fit, because they describe extra credentials printed on one physical
card.

The issue asks for both capabilities:

1. A single dive can belong to several courses.
2. A single course can result in several certifications.

Together they let a diver record a combined course either way: one "AN/DP"
course earning two certifications, or two courses sharing the same dives.

## Decisions

| Question | Decision |
| --- | --- |
| Can a certification come from several courses? | No. A course earns many certifications; each certification names at most one course. |
| Storage for a dive's courses | A `dive_courses` junction is the source of truth; `dives.course_id` stays as a denormalized representative. |
| Storage for a course's certifications | `certifications.course_id` is the source of truth; `courses.certification_id` stays as a denormalized representative. No new table. |
| Dive editor | Chip field plus a multi-select course sheet with checkboxes. |
| Course editor | Chip field plus a multi-select certification sheet. A certification linked to another course shows "Linked to: <course>", and ticking it moves the certification on save. |
| Bulk edit | The tri-state membership list dive types, tags and buddies use: each course shows all, some or none of the selected dives; tick adds to all, untick removes from all. |
| Scope | Both capabilities ship in one PR. |

## Existing state

- `dives.course_id` is a nullable FK to `courses` (`ON DELETE SET NULL`).
- The course/certification link is stored on both sides: `courses.certification_id`
  (no FK) and `certifications.course_id` (FK, `ON DELETE SET NULL`).
  `CourseRepository.linkCourseToCertification` writes both, and readers OR the
  two (`getCourseForCertification`, `course_query_entity.dart`,
  `certification_query_entity.dart`).
- Course requirements already credit a dive at most once per course
  (`course_requirement_dives`), so a dive shared by two courses can count
  toward each course's requirements without changing that logic.
- Precedent: multiple dive types (spec `2026-06-24-multiple-dive-types-design.md`)
  added the `dive_dive_types` junction and kept `dives.dive_type` as a
  representative for older app versions and single-value exports.

## 1. Data model and migration

### Dive to courses

New table `dive_courses`, defined under `lib/core/database/tables/` (never in
`database.dart`):

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, PK | Deterministic UUIDv5 (below) |
| `dive_id` | text, FK `dives(id)` `ON DELETE CASCADE` | |
| `course_id` | text, FK `courses(id)` `ON DELETE CASCADE` | |
| `created_at` | integer | Unix ms |
| `hlc` | text, nullable | Own clock for the parent-gated child merge guard |

- **Identity.** `id = Uuid().v5(Namespace.url.value, 'submersion:dive-course:$diveId:$courseId')`,
  exposed as one helper (`diveCourseLinkId`). The same link created on two
  devices, or seeded by the migration on two devices, is the same row, so sync
  upserts converge instead of unioning duplicates (the dive-types issue #1360).
  The namespace string must never change once shipped.
- **Unique index** `idx_dive_courses_dive_course_unique` on `(dive_id, course_id)`
  as a backstop, matching `dive_dive_types` since v178.
- **Representative.** `dives.course_id` is rewritten on every write of the set:
  the dive's first course ordered by course `start_date`, then `name`, then
  `id` (stable across devices), or NULL when the set is empty.
- **Rung.** Creates the table and the unique index, then seeds one junction row
  per dive whose `course_id` is non-null. The id is computed in Dart (SQLite has
  no UUIDv5) and inserted with `INSERT OR IGNORE`, so a re-run is a no-op.
- **beforeOpen backstop.** In a part file (not `before_open.dart`, which is at
  its line cap): re-runs the same idempotent seed, so a database that skipped the
  rung, or received representative-only edits from an older app version, still
  converges.
- **Older app versions.** They write only `dives.course_id`. When a dive row
  merges in from sync and its `course_id` is not in that dive's junction set,
  the merge adds that course to the set. It only adds, never removes: an older
  device can attach a course but cannot strip a second one.

### Course to certifications

- `certifications.course_id` is the source of truth. A course's certifications
  are the rows with `course_id = <course>`.
- `courses.certification_id` stays as the representative: the course's
  earliest-issued linked certification (NULL issue dates last, then `name`,
  then `id`), or NULL. Rewritten whenever the set changes.
- **Rung backfill.** First, clear old-version leftovers: an older app version
  only half-unlinked (swapping or clearing a course's card rewrote the course
  row and left the old card's `course_id` pointing at it). A card the course
  does not name and that is older than the course row (`updated_at`) is such a
  leftover and loses its `course_id`; a card at least as new as the course is
  a link the new app made (a device already on v288) and stays. Then, for each
  course whose `certification_id` names a certification with a NULL
  `course_id`, set that certification's `course_id`. A certification still
  pointing at a different course is left alone: the certification side wins.
  Decided after the final review; a leftover card edited after the correction
  is the one case that comes back.
- Readers that OR both sides switch to the certification side only.

### Deletion

- Deleting a course: collect its `dive_courses` rows, let the cascade remove
  them, log a tombstone for each (cascade alone does not tombstone, #466), and
  recompute the representative for each affected dive. Certifications keep the
  existing `UPDATE ... SET course_id = NULL`.
- Deleting a dive: `dive_courses` joins the dive's existing child tombstoning.
- Diver deletion: covered through the dive and course cascades; confirm the
  diver-owned-rows path tombstones the junction.

## 2. Sync, repositories and domain

### Sync

`dive_courses` registers as entity `diveCourses` in every place `diveDiveTypes`
is registered:

- `SyncDataSerializer`: payload field, JSON read/write, export list, table map,
  `parentGatedChildEntities`, apply/upsert, deletion and revival switches.
- `SyncRepository` table map (`'diveCourses': (table: 'dive_courses', pk: 'id')`).
- `SyncService`: payload application order, parent refs
  (`diveId` to `dives`, `courseId` to `courses`, both non-nullable), and the
  conflict-card flag map.
- `sync_migrations.dart` HLC column list.
- The incoming-row apply uses the unique-index-aware upsert written for
  `dive_dive_types`, so a row colliding on `(dive_id, course_id)` merges rather
  than failing.
- The older-version reconciliation (section 1) runs in the dive merge path
  after a dive row is applied.

### Domain

- `Dive` gains `List<String> courseIds` (in `copyWith` and `props`). The
  existing `courseId` stays as the representative for single-value consumers.
- Read mappers hydrate `courseIds` from the junction. A dive with no junction
  rows falls back to `[courseId]` when `courseId` is non-null.
- `Course` keeps `certificationId` (the representative). The full set comes from
  a new `certificationsForCourseProvider(courseId)`, so course list rows stay a
  single query.

### Repositories

- `DiveRepository` insert and update write the junction set and the
  representative column in one transaction, tombstoning removed links and
  marking added links pending.
- `CourseRepository`:
  - `linkDiveToCourse(diveId, courseId)` and `unlinkDiveFromCourse(diveId, courseId)`
    add and remove one junction row and rewrite the representative. Unlink takes
    the course, since a dive no longer has a single course.
  - `setCourseCertifications(courseId, certificationIds)` replaces
    `linkCourseToCertification`. In one transaction it sets `course_id` on newly
    ticked certifications (moving them off another course, whose representative
    is then recomputed), clears it on unticked ones, and rewrites this course's
    representative. Every touched row is marked pending.
  - `getDiveCountForCourse`, the course dives query and
    `getCourseForCertification` read the junction or the certification side.
- `CourseRequirementRepository.getSuggestedDives` reads the junction instead of
  `d.course_id`.

### Dive operations that carry courses

- **Merge and consolidation:** the merged dive gets the union of its sources'
  courses (today the first non-null wins). Undo restores each source dive's own
  set from the merge snapshot, as dive types do.
- **Uncombine** keeps today's behaviour: a dive split out of a consolidated dive
  starts with no course (it clears `courseId` now), so it gets no junction rows.
- **Field censuses.** `kMirroredDiveFields` (mirror flow) and the planned-dive
  fill sets classify every `Dive` field. `courseIds` joins whichever set
  `courseId` is in: mirror does not copy courses (they belong to one diver), and
  a download filling a planned dive keeps the planned dive's courses, so the fill
  must leave its junction rows in place.
- **Bulk edit:** a courses membership editor producing add and remove operations.

## 3. Screens

- **Dive editor:** the Course field becomes a chip field with one removable chip
  per course. Tapping it opens the course sheet in multi-select mode, with
  checkboxes and a Done button.
- **Dive detail, Details card:** the "Training course" row becomes one tappable
  row per course, each opening that course.
- **Dive detail, Signatures card:** the instructor signature stays one per dive.
  Its header course chip becomes a wrapping row of chips, one per course, each
  tappable.
- **Bulk edit:** the single Course field becomes a courses membership list
  (all / some / none per course), with the multi-select sheet to add courses.
- **Course editor:** "Earned Certification" becomes "Earned Certifications", a
  chip field opening a multi-select certification sheet. A certification linked
  to another course shows "Linked to: <course>" beneath its name; ticking it
  moves it to this course on save.
- **Course detail:** the earned certifications section lists one row per
  certification (agency, level, card number), each opening the certification,
  and stays hidden when there are none. The dives list, dive count and
  signatures read the junction, so a shared dive appears under both courses.
- **Certification detail:** unchanged in shape (one Course row), now reading
  `certifications.course_id` only.
- **Copy:** new and changed strings go through the ARB files for every locale,
  with plural forms where a label can name several items.

## 4. Other readers and import/export

### Readers moving to the junction

- Query language: `course` on dives changes from an FK relation to a junction
  relation over `dive_courses`, so `course:"Decompression Procedures"` matches a
  dive in either course and the relation is many-valued.
- `course_query_entity.dart` and `certification_query_entity.dart`: the OR over
  both link columns becomes the certification side only; a dive-to-course hop
  goes through the junction.
- Connections graph membership (`connections_membership_sql.dart`).
- Data-quality "has course" checks (`diver_data_sql.dart`).
- Course signatures (`SignatureStorageService.getSignaturesForCourse`).
- Table-update wiring (`TableUpdateQuery.onTable`) adds `dive_courses` wherever
  `dive_dive_types` is listed, so screens refresh when only a link changes.

Left on the representative by design: the PADI PDF "training dive" heuristic
(any course means a training dive) and the `idx_dives_course_id` index.

### UDDF

- **Export:** one `<link ref="course_...">` per course on each dive, and one
  `<link ref="cert_...">` per earned certification on each course. UDDF allows
  repeated links.
- **Import:** collect every course ref on a dive into its set (the first becomes
  the representative), and resolve each course's certification refs into
  `certifications.course_id`.

## Follow-ups (in this PR)

- **UDDF drops the course/certification link today.** The parser reads a
  course's `certificationRef` (`uddf_import_parsers.dart`) but the entity
  importer never applies it, so a UDDF round-trip loses which certification a
  course earned. The import change above fixes it.

## Testing

TDD throughout.

- **Migration:** the seed copies every non-null `course_id` into the junction
  with deterministic ids; a second run is a no-op; the certification backfill
  fills only NULL `course_id`; the beforeOpen backstop converges a database that
  skipped the rung; schema tripwire tests updated.
- **Repository:** the course set round-trips; the representative follows the
  ordering rule; moving a certification recomputes both courses'
  representatives; deleting a course tombstones its links and recomputes the
  affected dives' representatives.
- **Sync:** the same link made on two devices converges to one row; a dive
  arriving with only `course_id` gains that course and loses no other; the
  parent-refs and synced-table completeness tests include `diveCourses`.
- **Dive operations:** merge unions courses and undo restores them; bulk Add,
  Remove and Replace; mirror leaves the sibling with no courses; a planned
  dive's courses survive a computer fill.
- **Query:** `course:` matches a dive in either of its courses.
- **UDDF:** round-trip of a dive with two courses and a course with two
  certifications.
- **Widgets:** the multi-select sheets, the chip fields, the course detail
  certification list and the multi-course dive detail rows, at phone and
  desktop widths.
- `test/architecture/` and `test/shared/` guard suites, since files are added
  under `lib/`.

## Out of scope

- A certification earned through several courses (full many-to-many).
- Per-course instructor signatures on a shared dive; a dive keeps one signature.
- CSV export of courses (dives CSV has no course column today).
