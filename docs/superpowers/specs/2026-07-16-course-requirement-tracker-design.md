# Course Requirement Tracker — Design

**Date:** 2026-07-16
**Status:** Approved design, pending implementation plan
**Schema:** v121 (drafted as v112; renumbered repeatedly as main advanced —
v112 went to equipment.thickness, v113 to CNS calc method, v114 to the
tombstone-GC migration, and v120 to planner Subsurface-parity, so the course
requirement tables land at the next free number, v121 — see the schema-version
ladder)

## Problem

Courses in Submersion track start/completion dates but nothing in between. Real
courses have countable requirements — AOW needs five adventure dives (Deep and
Navigation mandatory, three electives), Rescue needs a current EFR cert plus
scenario dives, Deep/Cave have prerequisite dive counts. A diver mid-course has
no way to see "3 of 5 done" or which logged dives counted.

## Decisions (from brainstorming)

1. **Scope:** two requirement kinds — `dive` (progress derived from linked
   logbook dives) and `checklist` (manual check-off for non-dive items such as
   knowledge development, EFR prerequisite, swim test). No per-dive skill
   sign-offs; Submersion is a diver's log, not an instructor slate.
2. **Definitions:** requirements are ordinary editable per-course rows. Built-in
   starter templates (code constants, not database rows) can seed them; once
   copied, template origin is irrelevant.
3. **Crediting:** explicit dive↔requirement links, user-confirmed. The course
   page suggests candidate dives (logged since course start, not yet linked in
   this course) but never auto-counts.
4. **Surfaces:** the course detail page (primary) and a dashboard progress card
   for in-progress courses. A dive-detail "credited to" chip is explicitly out
   of scope for this iteration.

## Data model (schema v121)

### New table `course_requirements`

| Column | Type | Notes |
|--------|------|-------|
| `id` | text PK | UUID |
| `courseId` | text FK → `courses.id`, cascade delete | |
| `name` | text | e.g. "Deep adventure dive" |
| `kind` | text | `'dive'` or `'checklist'` (`RequirementKind` enum) |
| `targetCount` | int, default 1 | dive kind only; checklist rows ignore it |
| `completedAt` | datetime, nullable | checklist check-off; always null for dive kind |
| `sortOrder` | int | template order; user-reorderable later |
| `notes` | text, nullable | |
| `createdAt`, `updatedAt` | datetime | standard |
| `hlc` | text, nullable | per-row sync clock |

### New junction `course_requirement_dives`

Columns: `id` PK, `requirementId` (FK → `course_requirements`, cascade),
`diveId` (FK → `dives`, cascade), `createdAt`. The `id` is a DETERMINISTIC
UUIDv5 of `(requirementId, diveId)` (`CourseRequirementRepository.linkIdFor`),
so the same link created on two devices converges to a single row under sync
upsert and duplicate links dedupe on the primary key — no unique index
needed. The junction is CLOCKLESS (no `hlc` column): delta export rides the
parent requirement's `hlc`, which `linkDive`/`unlinkDive` bump (the
`equipment_set_items` pattern). A dive may link to requirements in
*different* courses — deliberate; agencies differ on double-counting and we
do not police it.

*(Revised during implementation: an earlier draft of this section specified a
junction-local `hlc` column and a unique index on `(requirementId, diveId)`;
the deterministic-id + parent-gated design replaced both.)*

### Migration & sync

- `onUpgrade` `from < 121` creates both tables; matching `beforeOpen`
  re-assert backstop (v109 pattern). No data migration, no seeding.
- Both tables emit per-row tombstones on delete (#466 child-delete lesson).
  `course_requirements` is an HLC merge-root (registered in `_hlcTargets`,
  applied with `.toCompanion(false)` per the #474 rule); the junction is a
  clockless child applied with the plain companion form.

### Template catalog

`CourseTemplateCatalog` in `lib/core/constants/course_templates.dart` —
`abstract final class` of constants, modeled on `CertificationLevelCatalog`.
Starter set (agency-neutral naming, PADI-shaped): AOW, Rescue, Deep, Night,
Navigation, Nitrox, Cavern/Intro to Cave, Wreck. Each template is a list of
`(name, kind, targetCount)` entries. Templates are a copy source only; they
carry no identity into the database and agency curriculum changes affect only
future instantiations. This deliberately avoids the built-in reference-data
adopt/wipe/re-seed machinery that database-seeded reference tables require.

## Domain entities

In `lib/features/courses/domain/entities/` (requirements live inside the
existing `courses` feature — they are meaningless without a course):

- `CourseRequirement` — Equatable, mirrors the table, `copyWith`;
  `RequirementKind` enum (`dive`, `checklist`).
- `CourseRequirementProgress` — computed view: the requirement plus
  `linkedDives` (lightweight summaries: id, dive number, date, site name) with
  derived `creditCount` and
  `isSatisfied` (`kind == checklist ? completedAt != null : creditCount >= targetCount`).
- `CourseProgress` — roll-up: list of `CourseRequirementProgress`,
  `satisfiedCount`, `totalCount`, `isComplete`.

Progress is always computed at read time, never stored. Stored counters would
require conflict resolution when two devices link dives concurrently; derived
counts make sync merge-and-repaint with no drift possible.

## Repository

`lib/features/courses/data/repositories/course_requirement_repository.dart`,
following the `dive_role_repository` shape (`_db`, `SyncRepository`, `Uuid`,
`LoggerService`):

- `watchRequirementsChanges()` — stream for provider self-invalidation
- `getRequirementsWithProgress(courseId)` — single joined query returning
  requirements with linked dive summaries (no N+1)
- `createRequirement`, `updateRequirement`, `deleteRequirement` (tombstone)
- `setChecklistComplete(id, bool)` — sets/clears `completedAt`
- `applyTemplate(courseId, template)` — bulk insert, appends to existing rows,
  never destructive (applying twice duplicates; user's choice to fix)
- `linkDive(requirementId, diveId)` / `unlinkDive(...)` — junction writes with
  tombstones; linking an already-linked dive is a silent no-op (guard +
  unique index), not a surfaced error
- `getSuggestedDives(courseId)` — current diver's dives dated on/after the
  course `startDate` (fallback: last 60 days when no start date), excluding
  dives already linked to any requirement in this course, newest first,
  capped at 10

## Providers

`lib/features/courses/presentation/providers/`:

- `courseRequirementRepositoryProvider` — plain `Provider`
- `courseProgressProvider` — `FutureProvider.family<CourseProgress, String>`
  by courseId; self-invalidates via
  `ref.invalidateSelfWhen(repo.watchRequirementsChanges())` so progress stays
  live after sync merges
- `activeCoursesProgressProvider` — `FutureProvider` for the dashboard: all
  in-progress courses (null `completionDate`) for the current diver with their
  `CourseProgress`; watches both the requirements stream and
  `watchDivesChanges` (#217 lesson — dive edits must refresh derived stats)

## UI

New widgets under `lib/features/courses/presentation/widgets/` (five focused
files):

- **`CourseRequirementsSection`** — card section on the course detail page.
  Header: "3 of 6 complete" + linear progress bar. Empty state offers *Add
  from template* and *Add requirement*.
- **`RequirementTile`** — checklist kind renders a checkbox (tap toggles
  `completedAt`); dive kind shows `2/3` progress, a satisfied check icon, and
  an expandable linked-dive list (tap → dive detail; swipe/menu → unlink).
  Unsatisfied dive requirements show **suggestion chips** ("Dive #47 · Jul 12 ·
  Blue Hole") — one tap links; linking anywhere removes the dive from the
  course's suggestion pool.
- **`AddRequirementSheet`** — bottom sheet for create and edit: name, kind
  toggle, target count (dive kind only).
- **`TemplatePickerSheet`** — lists catalog templates with a preview of rows
  each adds; confirm copy ("Adds 6 requirements").
- **`ActiveCourseProgressCard`** — dashboard card, rendered only when
  `activeCoursesProgressProvider` is non-empty. One compact row per active
  course: name, satisfied-requirement fraction, thin progress bar; tap
  navigates to the course.

All new strings go through l10n: English plus all 10 other locales, with ARB
regeneration.

## Error handling

- Repository methods wrap Drift calls in try/catch with `LoggerService`.
- Duplicate link attempts are no-ops, not exceptions.
- Course deletion cascades requirements and junction rows and writes
  per-row tombstones so sync propagates the deletes.

## Testing

TDD throughout:

- **Repository tests** (in-memory Drift): CRUD; `applyTemplate` appends;
  link/unlink writes tombstone rows; `getSuggestedDives` filtering (date
  window, already-linked exclusion, diver scoping, cap); cascade on course
  delete; schema-shape migration test (v121).
- **Entity tests:** `isSatisfied` and `CourseProgress` roll-up, including
  `targetCount > 1` and checklist kinds.
- **Widget tests:** requirements section (checkbox toggle, progress text,
  suggestion-chip link flow); dashboard card hidden when no active course.
  Use established guards: `themeAnimationDuration: Duration.zero`, post-pump
  Drift awaits inside `tester.runAsync`.

## Out of scope (this iteration)

- Dive-detail "credited to" chip
- Per-dive skill sign-offs / instructor-slate features
- Requirement reordering UI (schema supports it via `sortOrder`)
- Authoritative agency curricula
