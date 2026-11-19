# Unified editing, phase 3, plan 4: courses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A course opens locked and edits in place, every card held in one sitting written as one History entry, behind `kUnlockRecordEditing` (issue #4527, phase 3). That includes what the course page writes at once today: Mark completed, and the requirement tracker (add, apply a template, edit, delete, tick, credit and uncredit dives). The edit form stays until the switch-over plan; a new course is plan 11's.

**Architecture:** As plan 3's certification page: the page's state mixes in `RecordEditHost` and `RecordOpenUnlocked`, its cards are `EditCard`s keyed by `CourseCardId` (shipped by plan 1), and a `CourseEditSaveService` writes through `writeRecordSitting`. The requirements and their credited dives are one `SittingList` of `CourseRequirementProgress` rows (a requirement with its credited dives, the shape the tracker already draws), written at Save by one repository method that applies the difference in a safe order. The earned certifications are a second `SittingList`, written through `setCourseCertifications`. The instructor editor plan 3 built for certifications becomes one editor that both pages use.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift, go_router, `flutter gen-l10n`.

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), sections "Design: courses", "Design: rules every phase 3 type follows", "Values shown nowhere today" (the course's instructor row) and "Testing"; on top of plans 1 to 3 ([records-1](2026-11-19-unified-editing-records-1-shared.md), [records-2](2026-11-19-unified-editing-records-2-documents-species.md), [records-3](2026-11-19-unified-editing-records-3-buddies-centres-certifications.md)).

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **Which card the completion date belongs to.** The spec puts "completed and completion date" on Details and "mark completed" on Status, but a value belongs to one card (its changed dot, its name in History). **Recommended:** Details. Mark completed on the Status card sets it, so the dot and the History entry say Details. The other way: the completion date is a Status value, and the Details editor's switch and date edit it there. (Tasks 1, 3.)
2. **Mark completed in a sitting.** Today the button asks "Mark completed?" before writing. **Recommended:** inside a sitting it asks nothing, since Cancel takes it back, as plan 3 settled for held removals. The other way: keep the question. (Task 3.)
3. **A credit another device made meanwhile.** A dive credited in the sitting may, by Save, credit another requirement of the same course (a sync landed). Today `linkDive` skips such a credit silently, to keep a dive to one requirement per course. **Recommended:** the same at Save: the credit is skipped, the rest is written, and the page shows the dive under the other requirement afterwards. The other way: the Save is refused whole (`RecordSittingRefusal`) naming the dive, and the page stays unlocked. (Task 4.)

## Calls made in this plan, for Eric to check

1. **One instructor editor for both pages.** Plan 3's `CertificationInstructorCardEditor` becomes a generic `InstructorCardEditor<T>`; the certification editor is a thin wrapper and keeps its test keys and labels. `instructorPicked` moves with it.
2. **Requirement deletes stay without a question**, as today (the menu deletes at once); in a sitting Cancel brings it back.
3. **The tracker's write order at Save:** uncredits, deleted requirements (with a tombstone per credit, as today), new requirements (keeping the id, order and tick the sitting gave them), changed requirements, then credits. A tick keeps the time it was ticked, not the time of Save.
4. **Suggestions and the dive picker in a sitting.** Dives credited in the sitting leave both. Dives uncredited in the sitting come back to the picker; the suggestion chips stay the stored query's until Save.
5. **A credit held for a requirement deleted underneath** (by sync) is skipped at Save, as a credit for a requirement that no longer exists cannot be written.
6. **The Status card's state and duration follow the sitting** while unlocked (Mark completed shows "Completed" at once); they stay read only.
7. **The Instructor card shows with any of name, number or linked buddy** (today only with a name). With no name, its Name row shows the linked buddy's name, so no new string is needed.
8. **The list's bulk "Mark complete" is unchanged** (a bulk action, a phase 3 non-goal).
9. **No wide-screen move into the pane is added.** The course page has none today (the certification page has); a full course page opened with `?mode=edit` on a wide screen opens unlocked where it is.
10. **The Mark completed button at the bottom of the page stays with the switch off**, and goes with it on.

## Global Constraints

- No other phase 2 or phase 3 plan is in flight as this is written (#4765 and #4767 merged). Merge origin/main before each task with a merge (never a rebase or a force-push), adapt to any renamed names, and run a whole-repo `flutter analyze` after each merge.
- Built on the names already shipped: `RecordEditHost`, `RecordOpenUnlocked`, `EditCard`, `RecordCardFrame`, `RecordCardFade`, `RecordCardPencil`, `AddStripEntry`, `EditSession` (`set`, `valueOf`, `applyTo`, `holdWrite`, `track`, `changedCardIds`, `runHeldWrites`), `EditField`, `FieldTextBinding`, `SittingList` (`load`, `current`, `set`, `wroteChange`) with `sameIdSets`, `writeRecordSitting`, `RecordSittingRefusal`, `recordOperationRunnerOf`, `recordOperationBlockOf`, `DocumentsSection<T>(owner:, editing:)`, `holdDocumentLinks`, `confirmLeaveRecordSitting`, `CourseCardId` with `localizedDisplayName`, and plan 3's certification editing files.
- With `kUnlockRecordEditing` false (the default) the course page, its list pane, table mode and routes look and behave exactly as today: no existing test changes its expectations. The page takes `unlockEditing` defaulting to the switch.
- A locked page writes nothing on any tap. History label: `record_edit:courses:<id>:<cards>`, source "manual". Writes to other tables in the sitting (requirements, credits, the dives' representative course, certifications moved, document links) are in that one entry.
- Only what changed is written: the sitting's changes are applied to the course as stored at Save (`EditSession.applyTo`), with a field census test. `Course.copyWith` cannot clear the completion date, instructor or location, so the fields build the course through one private `_with` that copies every field, as plan 3 did.
- Rules move from the form unchanged: the name is required; switching completed on fills today's date; a start after the completion date pulls the completion date with it; the date pickers clamp their first date as the form's `_selectDate` does. Dates show in the active diver's format.
- No new strings are expected: every label comes from the form or the read page. A task that finds one missing names it, and it goes into all eleven ARB files, translated, then `flutter gen-l10n`.
- `course_detail_page.dart` (768 lines) and `app_router.dart` do not grow past 800: editing goes in `part` files and `course_edit_routes.dart`; the router gains only references to them.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. `dart format` changed files before each commit. Anything acting after an `await` checks `mounted` and reads `ref` and `context` before its first `await`.
- Test runs: only the test FILES a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or `test/shared/` by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db`.

## Review Focus

1. **A dive uncredited from one requirement and credited to another in one sitting.** Save writes both in one entry (the uncredit first, so the one-requirement-per-course check passes); Cancel writes neither. Pinned in Task 4.
2. **A certification taken from another course, then Cancel.** It stays on that course with that course's representative unchanged. With Save it moves, both courses' representatives are recomputed in the one entry, and reverting the entry restores both. Pinned in Task 5.
3. **The start date changed on a course with assigned dives.** Each dive whose representative course changes is rewritten in the same entry, and reverting it restores `dives.course_id`. Pinned in Task 1.
4. **A requirement added in the sitting and a dive credited to it before Save.** The requirement is inserted before its credit; Cancel leaves neither. Pinned in Task 4.
5. **Locked with the switch on, the tracker writes nothing on any tap**: the checkbox shows its state disabled, and the suggestion chips, unlink, Choose dive, Add and Template are not offered. Pinned in Task 4.

## Form test accounting

The form stays until the switch-over plan, so no test is deleted here. Each of its cases gets its counterpart in this plan, so the switch-over can delete the form's tests with nothing lost:

| Form test (`test/features/courses/presentation/pages/`) | Case | Counterpart |
| --- | --- | --- |
| `course_edit_agency_test.dart` | offers every agency, including FFESSM | Task 3, `the Details editor offers every agency, including FFESSM` |
| | course and certification editors offer the same agencies | Task 3, `the course and certification Details editors offer the same agencies` |
| `course_edit_certifications_test.dart` | ticking two links both | Task 5, `ticking two certifications holds both, written at Save` |
| | removing a chip unlinks it on save | Task 5, `removing one unlinks it at Save` |
| | the field stays inert until the set has loaded | Task 5, `the field stays inert until the sitting's list has loaded` |
| `course_edit_date_range_test.dart` | start date more than one year ahead | Task 3, `the start date can be set more than one year ahead` |
| | completion picker opens when the start is in the future | Task 3, `the completion date picker opens when the start date is in the future` |
| `course_edit_embedded_save_test.dart` | embedded Save persists edits | Task 6, `the pane's Save updates the course` |
| | embedded Save updates, never creates | Task 6, `the pane's Save creates no course` |
| `course_edit_instructor_test.dart` | a credentialed buddy fills name and number | Task 2, `picking a credentialed buddy fills name and number` |
| | a buddy without a credential clears the number | Task 2, `switching to a buddy without a credential clears the number` |
| | a buddy with no credential is still offered | Task 2, `a buddy with no credential is still offered` |
| | the instructor id reaches the repository | Task 1, census (`instructorId` assertion) |

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`); generate code unfiltered in the background if fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Before any code changes, take the "before" goldens (headless widget tests, switch off): the course page locked at phone and desktop width, with requirements and earned certifications.

## File Structure

New (`lib/features/courses/...`):

| File | Responsibility |
| --- | --- |
| `data/services/course_edit_save_service.dart` | `CourseEditSaveService`, provider |
| `presentation/editing/course_edit_fields.dart` | Fields and the form's rules |
| `presentation/editing/course_card_editors.dart` | Status, Details, Notes editors |
| `presentation/editing/course_edit_cards.dart` | `courseEditCards`, `courseOptionalCards` |
| `presentation/editing/course_requirements_sitting.dart` | Held requirements and credits, pure edits, `RequirementActions` |
| `presentation/editing/course_certifications_sitting.dart` | Held earned certifications and their editor |
| `presentation/pages/course_detail_page_editing.dart` | `part`: the page's use of the host |
| `presentation/pages/course_detail_page_sections.dart` | `part`: the read sections moved out of the page |
| `presentation/pages/course_edit_routes.dart` | Redirect, pane |

New shared (`lib/features/buddies/presentation/editing/instructor_card_editor.dart`): `InstructorValue`, `instructorPicked`, `InstructorCardEditor<T>`.

Modified: `course_detail_page.dart`, `course_list_page.dart`, `course_requirements_section.dart`, `requirement_tile.dart`, `credit_dive_picker_sheet.dart`, `course_requirement_repository.dart`, `certification_edit_fields.dart` and `certification_card_editors.dart` (instructor moved out), `app_router.dart`, `test/architecture/markdown_notes_adoption_test.dart` (new Markdown editor; not run by hand).

---

### Task 1: The course save service and fields

**Files:**
- Create: `lib/features/courses/data/services/course_edit_save_service.dart`, `lib/features/courses/presentation/editing/course_edit_fields.dart`
- Test: `test/features/courses/data/services/course_edit_save_service_test.dart`, `test/features/courses/presentation/editing/course_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - `class CourseEditSaveService { CourseEditSaveService(CourseRepository courses); Future<({Course before, Course after})?> save({required String courseId, required Course Function(Course stored) apply, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false}) }`: `writeRecordSitting<Course>(table: 'courses', read: () => getCourseById(courseId), write: (_, merged) => updateCourse(merged))`. `updateCourse` writes neither `diverId`, `createdAt` nor `certificationId` (derived), and refreshes the representative course of each assigned dive inside the sitting. `courseEditSaveServiceProvider`.
  - Fields, card `status`: `courseNameField` (`String`, trimmed); card `details`: `courseAgencyField` (`String`), `courseStartDateField` (`DateTime`), `courseCompletionDateField` (`DateTime?`, Question 1), `courseLocationField` (`String?`, blank stores null); card `instructor`: `courseInstructorField` (`EditField<Course, InstructorValue>`, from Task 2's type; one value, so a pick is one change); card `notes`: `courseNotesField` (`String`, trimmed).
  - Rules, pure: `bool courseNameValid(String name)`; `DateTime? courseCompletedSwitched(bool on, {DateTime? now})` (today when on, null when off); `({DateTime start, DateTime? completion}) courseStartPicked(DateTime start, DateTime? completion)` (a completion before the new start becomes the start); `({DateTime first, DateTime last, DateTime initial}) courseDatePickerBounds({required bool isStart, required DateTime start, DateTime? completion, DateTime? now})` (the form's clamp: first 1950 or the start, last 2100, initial clamped).
- Consumes: `writeRecordSitting`; `InstructorValue` (Task 2; until then a local record type of the same shape).

- [ ] **Step 1: Write the failing tests** (test database; course `k1` "Rescue", PADI, started 2026-03-01, instructor buddy `b1`, two dives assigned, one of which also has course `k0`, started 2026-03-05):
  - Service: `writes a location change as one History entry` (label `record_edit:courses:k1:details`); census `a field the sitting did not touch keeps its newer value`, one assertion per column `updateCourse` writes (name, agency, start date, completion date, instructor id, name and number, location, notes); `clearing the completion date stores null`; `a start date after k0's makes k0 the dive's representative, in the same entry, and reverting restores it` (Review Focus 3); `unchanged returns null`; `a course that has gone throws`.
  - Fields: `switching completed on fills today`; `switching it off clears it`; `a start after the completion date pulls it along`; `a blank name is invalid`; `bounds clamp a future start's completion picker` (start 2027-06-01, today 2026-11-19: first 2027-06-01, initial 2027-06-01).
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(courses): save a course's editing sitting as one History entry`.

### Task 2: One instructor editor for certifications and courses

**Files:**
- Create: `lib/features/buddies/presentation/editing/instructor_card_editor.dart`
- Modify: `lib/features/certifications/presentation/editing/certification_edit_fields.dart`, `certification_card_editors.dart`, `course_edit_fields.dart`
- Test: `test/features/buddies/presentation/editing/instructor_card_editor_test.dart` (create), `test/features/certifications/presentation/editing/certification_card_editors_test.dart` (existing, unchanged expectations)

**Interfaces:**
- Produces:
  - `typedef InstructorValue = ({String? id, String? name, String? number});` `CertificationInstructor` stays as an alias of it.
  - `InstructorValue instructorPicked(Buddy? buddy, Certification? instructorCert, InstructorValue previous)`, moved from `certification_edit_fields.dart` unchanged.
  - `class InstructorCardEditor<T> extends StatefulWidget { const InstructorCardEditor({required EditSession<T> session, required EditField<T, InstructorValue> field, required String nameLabel, String? nameHint, required String numberLabel, String? numberHint, required String keyPrefix}) }`: `InstructorPickerField`, then the name and number text fields (keys `'$keyPrefix-instructor-name'`, `'$keyPrefix-instructor-number'`), as plan 3's editor.
  - `CertificationInstructorCardEditor` builds it with `keyPrefix: 'cert-edit'` and its labels; the course's is built in Task 3 with `keyPrefix: 'course-edit'` and `courses_field_instructorName` / `courses_field_instructorNumber`.
- Consumes: Task 1's `courseInstructorField` switches to `InstructorValue`.

- [ ] **Step 1: Write the failing tests** (a small fake record type, as plan 1's host tests): `picking a credentialed buddy fills name and number`; `switching to a buddy without a credential clears the number`; `a buddy with no credential is still offered`; `clearing the pick keeps the text`; `typing the name is one change of the field's card`.
- [ ] **Step 2:** Run it. Expected: fail to compile.
- [ ] **Step 3:** Implement; reduce the certification editor to the wrapper.
- [ ] **Step 4:** Run it and `certification_card_editors_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `refactor(editing): one instructor editor for certifications and courses`.

### Task 3: The course page on the host

**Files:**
- Create: `course_card_editors.dart`, `course_edit_cards.dart`, `course_detail_page_editing.dart` (part), `course_detail_page_sections.dart` (part)
- Modify: `course_detail_page.dart`, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/courses/presentation/pages/course_detail_page_unlock_harness.dart`, `course_detail_page_unlock_test.dart`, `test/features/courses/presentation/editing/course_card_editors_test.dart`

**Interfaces:**
- Produces:
  - `CourseStatusCardEditor({required EditSession<Course> session})`: the name field (`courses_field_courseName`, required, its error while blank), the state and duration read only from `session.working`, and Mark completed (`courses_action_markCompleted`) while the working course is in progress: it sets `courseCompletionDateField` to today with no question (Questions 1 and 2).
  - `CourseDetailsCardEditor`: `CertificationAgencyDropdown`, the start date tile, the completed switch with the completion date tile, location; dates through `showAppDatePicker` with `courseDatePickerBounds`; the switch through `courseCompletedSwitched`, the start through `courseStartPicked`.
  - `CourseNotesCardEditor`: `MarkdownNotesField` over `courseNotesField`.
  - `courseEditCards` (`Map<CourseCardId, EditCard<Course>>`): `status` (`isEmpty` false, `isValid`: `courseNameValid`), `details` (`isEmpty` false), `instructor` (`isEmpty`: no id, name or number; Task 2's editor), `notes` (`isEmpty`: blank), `documents` (`DocumentsSection<Course>`, links held by `holdDocumentLinks`), `requirements` (Task 4), `earnedCertifications` (Task 5). `courseOptionalCards`: instructor, earned certifications, notes.
  - `class CourseDetailPage extends ConsumerStatefulWidget { const CourseDetailPage({required String courseId, bool embedded = false, VoidCallback? onDeleted, bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false, VoidCallback? onSittingEnded}) }` on `RecordEditHost<CourseDetailPage, Course>` and `RecordOpenUnlocked`; `followStored(courseByIdProvider(id))`; `editingTitle`: `recordEdit_editingTitle(course.name)`; `rereadStored` invalidates `courseByIdProvider`. Its bar and embedded header take `host.lockButton`, and Edit unlocks, as the certification page. The sections move into `course_detail_page_sections.dart`. With the switch on: the Instructor card shows when any of its three values is set, its Name row falling back to the linked buddy's name (`buddyByIdProvider`); Training dives fades as calculated; the Mark completed button at the page's bottom goes.
- Consumes: Tasks 1 and 2.

- [ ] **Step 1: Write the failing tests**:
  - Editors: `each editor sets only its card's fields`; `the Details editor offers every agency, including FFESSM`; `the course and certification Details editors offer the same agencies`; `the start date can be set more than one year ahead`; `the completion date picker opens when the start date is in the future`; `switching completed on shows today's date`.
  - Page: `with the switch off there is no lock and Mark completed stays at the bottom`; `locked, no tap writes`; `name and location in one sitting save as one entry and lock`; `a blank name cannot be saved`; `Mark completed in the Status editor shows Completed at once and writes at Save`; `the Instructor card shows a number alone`; `the Instructor card names a linked buddy when there is no name`; `empty Instructor and Notes are offered in the strip`; `Training dives fades as calculated`; `the documents card holds a detach until Save`; `Cancel with changes asks first`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement; add the notes editor to the Markdown guard's list.
- [ ] **Step 4:** Run them, and unchanged `course_detail_certifications_test.dart`, `course_detail_export_units_test.dart`, `course_detail_label_column_test.dart`, `course_detail_page_connections_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(courses): unlock a course page to edit it in place, behind a switch`.

### Task 4: The requirement tracker held in the sitting

**Files:**
- Create: `lib/features/courses/presentation/editing/course_requirements_sitting.dart`
- Modify: `lib/features/courses/data/repositories/course_requirement_repository.dart`, `presentation/widgets/course_requirements_section.dart`, `requirement_tile.dart`, `credit_dive_picker_sheet.dart`, `course_edit_cards.dart`, `course_detail_page_editing.dart`
- Test: `test/features/courses/data/repositories/course_requirement_repository_test.dart` (existing; add cases), `test/features/courses/presentation/editing/course_requirements_sitting_test.dart` (create), `test/features/courses/presentation/course_requirements_section_test.dart`, `test/features/courses/presentation/widgets/requirement_tile_test.dart`, `credit_dive_picker_sheet_test.dart` (existing; add cases, adapt to the new return type), `course_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `Future<bool> CourseRequirementRepository.writeRequirementChanges(String courseId, {required List<CourseRequirementProgress> loaded, required List<CourseRequirementProgress> current})`: the difference, in Call 3's order: credits gone (`unlinkDive`); requirements gone (as `deleteRequirement`, a tombstone per credit); requirements new (inserted with their own id, `sortOrder`, `completedAt`); requirements changed (name, kind, target, sort order, notes; `completedAt` for a checklist, null for a dive kind, as `updateRequirement` and `setChecklistComplete` do); credits new (`linkDive`, which skips a dive already crediting a requirement of the course, Question 3), skipping a requirement that no longer exists (Call 5). Each row marked pending; no notify (the sitting tells sync once). Returns whether it wrote anything.
  - `final courseRequirementsList = SittingList<Course, CourseRequirementProgress>(key: 'course.requirements', cardId: 'requirements', read: (c) async => (await CourseRequirementRepository().getCourseProgress(c.id)).requirements, write: (c, loaded, current) => CourseRequirementRepository().writeRequirementChanges(c.id, loaded: loaded, current: current))`.
  - Pure edits over `List<CourseRequirementProgress>`: `withRequirementAdded(rows, RequirementDraft draft, {required String courseId, DateTime? now})` (fresh uuid, sort order after the last row); `withTemplateApplied(rows, CourseTemplate template, {required String courseId, DateTime? now})` (appends, twice appends twice); `withRequirementEdited(rows, String id, RequirementDraft draft)`; `withRequirementTicked(rows, String id, bool done, {DateTime? now})`; `withRequirementRemoved(rows, String id)`; `withDiveCredited(rows, String requirementId, RequirementDiveSummary dive)` (unchanged when the dive credits a row already); `withDiveUncredited(rows, String requirementId, String diveId)`. `List<RequirementDiveSummary> suggestionsInSitting(List<RequirementDiveSummary> stored, List<CourseRequirementProgress> rows)`: stored less dives credited in rows.
  - `abstract interface class RequirementActions { Future<void> add(BuildContext); Future<void> applyTemplate(BuildContext); Future<void> edit(BuildContext, CourseRequirement); Future<void> remove(CourseRequirement); Future<void> tick(CourseRequirement, bool done); Future<void> credit(BuildContext, CourseRequirement, RequirementDiveSummary? suggestion); Future<void> uncredit(CourseRequirement, String diveId); }` with `StoredRequirementActions(WidgetRef ref, String courseId)` (today's writes, moved from the section and tile) and `HeldRequirementActions(EditSession<Course> session)` (each through the pure edits and `courseRequirementsList.set`).
  - `CourseRequirementsSection({required String courseId, EditSession<Course>? editing, bool readOnly = false})`: with a session it draws the sitting's rows and acts through `HeldRequirementActions`; `readOnly` (locked with the switch on) offers no action and disables the checkbox; neither, as today. `RequirementTile({required CourseRequirementProgress progress, required List<RequirementDiveSummary> suggestions, RequirementActions? actions})`: null actions is read only. `RequirementMenuButton` takes the actions.
  - `Future<RequirementDiveSummary?> showCreditDivePickerSheet(BuildContext, {required String courseId, Set<String> excludeDiveIds = const {}, List<RequirementDiveSummary> restoredDives = const []})`: it now returns the chosen dive's summary (a search hit is mapped to one); in a sitting it leaves out dives credited in it and lists those uncredited in it (Call 4).
  - The page loads the list in `onSittingStart`; its held write joins the Save's `alsoWrite`.
- Consumes: Task 3's page, `saveSitting`.

- [ ] **Step 1: Write the failing tests**:
  - Repository: `new requirements keep their ids and order`; `a tick keeps the time it was ticked`; `a dive moved between requirements in one write lands` (Review Focus 1); `a credit to a requirement gone underneath is skipped`; `a credit to a dive another requirement of the course has is skipped` (Question 3); `a removed requirement tombstones its credits`.
  - Sitting: `a template appends after the sitting's last row, and twice appends twice`; `crediting a dive already credited in the sitting changes nothing`; `suggestions leave out dives credited in the sitting`; `turning a checklist into a dive requirement clears its tick`.
  - Section and tile: `locked with the switch on, no tap writes` (Review Focus 5: checkbox disabled; chips, unlink, Choose dive, Add and Template absent; a recording repository fake records nothing); `in a sitting, a tick writes nothing until Save`; with the switch off, the existing cases unchanged.
  - Picker: `held credits are left out and held uncredits come back`; `it returns the chosen dive's summary`.
  - Page: `a requirement added, a dive credited to it, then Save: one entry, the requirement before its credit` (Review Focus 4); `the same, then Cancel: neither written` (Review Focus 4); `a dive moved between requirements, then Cancel: unchanged` (Review Focus 1); `a tick and a name change are one entry`; `reverting the entry restores ticks and credits`.
- [ ] **Step 2:** Run the six files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `requirement_sheets_test.dart`, `course_requirement_providers_test.dart`, `suggested_dives_provider_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(courses): requirements ticked and dives credited on a course page wait for Save`.

### Task 5: Earned certifications held

**Files:**
- Create: `lib/features/courses/presentation/editing/course_certifications_sitting.dart`
- Modify: `course_edit_cards.dart`, `course_detail_page_editing.dart`, `course_detail_page_sections.dart`
- Test: `test/features/courses/presentation/editing/course_certifications_sitting_test.dart`, `course_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `final courseCertificationsList = SittingList<Course, Certification>(key: 'course.certifications', cardId: 'earnedCertifications', read: <getCertificationsForCourse>, write: (c, loaded, current) => <CourseRepository.setCourseCertifications(c.id, ids of current)>, same: (a, b) => sameIdSets(a, b, (x) => x.id))`. `setCourseCertifications` already moves a certification off another course and recomputes both representatives; inside the sitting it runs in its transaction.
  - `CourseEarnedCertificationsEditor({required EditSession<Course> session})`: `CertificationMultiSelectField(courseId:, selectedCertificationIds:, onChanged:)` over the sitting's list (ids mapped back through `certificationListNotifierProvider`), a `LinearProgressIndicator` until the list has loaded; the card's rows draw the sitting's list, held ones with the changed dot.
  - The card is on the page while stored or held certifications exist, or while it is open or added; otherwise it is offered in the strip (Task 3's `courseOptionalCards`).
- Consumes: Task 3.

- [ ] **Step 1: Write the failing tests**: sitting: `ticking two certifications holds both, written at Save`; `removing one unlinks it at Save`; `the field stays inert until the sitting's list has loaded`. Page: `a certification taken from another course, then Cancel: still on that course` (Review Focus 2); `the same, then Save: moved, both representatives recomputed in one entry, and reverting restores both` (Review Focus 2); `empty Earned certifications is offered in the strip`.
- [ ] **Step 2:** Run the two files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `course_detail_certifications_test.dart`, `course_multi_select_field_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(courses): earned certifications chosen on a course page wait for Save`.

### Task 6: Course hosts, routes and Delete

**Files:**
- Create: `lib/features/courses/presentation/pages/course_edit_routes.dart`
- Modify: `course_detail_page.dart`, `course_detail_page_editing.dart`, `course_list_page.dart`, `app_router.dart`
- Test: `course_detail_page_unlock_test.dart`, `test/features/courses/presentation/pages/course_list_page_test.dart` (existing; add cases), `test/core/router/app_router_test.dart`

**Interfaces:**
- Produces: `String? courseEditLocation(String courseId, {bool unlockEditing = kUnlockRecordEditing})` (`/courses/<id>?mode=edit`, else null), `String? courseEditRedirect(BuildContext, GoRouterState)`, `Widget courseEditPane(BuildContext, String id, void Function(String) onSaved, VoidCallback onCancel, {VoidCallback? onDeleted, bool unlockEditing = kUnlockRecordEditing})` (the page unlocked with the switch, `onSittingEnded: onCancel`; else the form), used by both `editBuilder`s (master-detail and table mode); `createBuilder` and `/courses/new` stay the form. The detail route passes `openUnlocked` from `?mode=edit`; `/courses` and `:courseId` get `onExit: confirmLeaveRecordSitting`. Delete runs through `recordOperationRunnerOf`; History, Open in Connections and Export training log work locked.
- Consumes: Tasks 3 to 5.

- [ ] **Step 1: Write the failing tests**: `opened with mode=edit, the page is unlocked`; `the pane's and table mode's edit open the page unlocked, Cancel returns to view`; `the pane's Save updates the course`; `the pane's Save creates no course`; `the edit address redirects with the switch on, not off`; `locked, Delete is disabled under "Unlock to use these"`; `unlocked and clean, Delete asks and deletes`; `Export training log works locked`; `with the switch off the pane opens the form`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(courses): edit addresses and panes open the page unlocked; delete as a whole-record operation`.

### Task 7: Push, open the pull request, track it to green

- [ ] **Step 1:** Merge origin/main once more; whole-repo `flutter analyze`; `dart format` every changed file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file while it runs. Fix any hook failure in its own commit.
- [ ] **Step 3:** `/code-review xhigh --fix --max-findings all`; fix every valid finding test first; push again.
- [ ] **Step 4:** Screenshots from headless widget-test goldens with the switch on (never `flutter test ... -d macos`): the page locked (before and after) and unlocked, with the Status editor open, the Details editor open, the Requirements card holding a tick and a credit, and the Earned certifications editor; light and dark for the unlocked bar; phone and desktop for the pane. Attached through the project's current secret screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, title `feat(editing): courses edit in place, behind a switch`, body with `Refs #4527` and the screenshots; bind it, turn Auto-fix on, and follow it until every check is green, fixing each failure and review comment as it comes.
