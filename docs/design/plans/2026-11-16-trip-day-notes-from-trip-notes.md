# Trip day notes from the trip's Notes: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A passage in a trip's Notes under a heading that names a trip day shows on that day's page, and the day page can open the trip editor at that day's note.

**Architecture:** A pure Dart scanner (`trip_day_notes.dart`) cuts the Notes source into per-day passages using a vocabulary of day labels and month/weekday names. `TripStoryView` builds the vocabulary from the app's language, memoizes the passages, and hands each day's passage to `TripStoryDayPage` / `TripStoryDayPlan`. The edit route carries the day (date and number); a presentation helper places or finds the day's heading in the editor and drops an untouched inserted heading on save.

**Tech Stack:** Flutter, Riverpod, go_router, intl `DateFormat`, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-11-16-trip-day-notes-from-trip-notes-design.md`

## Global Constraints

- No schema, sync, export or import change. Nothing new is stored.
- Every new user-visible string is added to all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh), in the `trips_story_*` group next to `trips_story_dayLabel`, then `flutter gen-l10n`.
- The scanner has no Flutter import.
- `trip_edit_page.dart` is 1293 lines: new editor logic goes in `lib/features/trips/presentation/helpers/trip_day_note_editing.dart`; the page only calls it.
- Day dates are local date-only `DateTime(y, m, d)`, as `TripStoryDay.date` is.
- No em-dashes anywhere, code or copy.

## Review Focus

1. A `#` line inside a fenced code block (``` or ~~~) is not a heading, and does not end a passage. Test in Task 1.
2. A heading with a weekday that contradicts its date (`Tue Nov 5` when Nov 5 is a Wednesday) matches nothing. Test in Task 1.
3. Whitespace-only passage, or a heading at the very end of the note, gives no passage (the day page must not draw an empty caption). Test in Task 1.
4. Hungarian `{number}. nap` and Chinese/Arabic label templates read back what `trips_story_dayLabel` writes. Test in Task 2.
5. Leaving the editor after Add note without typing asks no discard question; saving after a rename drops only the inserted empty heading, never a pre-existing empty day heading. Test in Task 6.

---

### Task 1: The scanner

**Files:**
- Create: `lib/features/trips/domain/services/trip_day_notes.dart`
- Test: `test/features/trips/domain/services/trip_day_notes_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class TripNoteDay {             // Equatable
    const TripNoteDay({required this.date, required this.dayNumber});
    final DateTime date;          // local date-only
    final int dayNumber;
  }
  class TripDayNotesVocabulary {  // Equatable
    const TripDayNotesVocabulary({
      required this.dayLabels,    // List<({String prefix, String suffix})>, lowercased, trimmed
      required this.months,       // Map<String, int> lowercased name (full and abbr, no trailing '.') -> 1..12
      required this.weekdays,     // Map<String, int> lowercased name -> DateTime.monday..sunday
    });
  }
  class TripDayNotes {
    const TripDayNotes({required this.passages, required this.passageEnds});
    static const empty = TripDayNotes(passages: {}, passageEnds: {});
    final Map<DateTime, String> passages;  // day date -> passages joined by '\n\n'
    final Map<DateTime, int> passageEnds;  // day date -> source offset just after the last non-blank char of its last passage
  }
  TripDayNotes tripDayNotes(String notes, List<TripNoteDay> days, TripDayNotesVocabulary vocabulary);
  DateTime? dayNamedByHeading(String headingText, List<TripNoteDay> days, TripDayNotesVocabulary vocabulary);
  ```

- [ ] **Step 1: Write the failing tests.** Use an English vocabulary fixture (`dayLabels: [(prefix: 'day', suffix: '')]`, English month full/abbr names incl. `sept`, weekday full/abbr names) and a 7-day trip, 2026-11-03 (Tue, Day 1) to 2026-11-09. Groups and assertions:
  - `dayNamedByHeading`: `Day 3` -> 2026-11-05; `day 3:` -> 2026-11-05; `Day 12` -> null; `2026-11-05` -> 2026-11-05; `2026-12-05` -> null; `Nov 5`, `November 5`, `5 Nov`, `5 November`, `Nov. 5`, `Nov 5th`, `Nov 5, 2026`, `5 November 2026`, `Wed Nov 5`, `Wednesday, 5 November` -> 2026-11-05; `Tue Nov 5` -> null; `Nov 5, 2025` -> null; `Packing list` -> null; `Day 3 notes` -> null; `Nov 5 dives` -> null.
  - Year-boundary trip 2026-12-30 to 2027-01-02: `Jan 1` -> 2027-01-01, `Dec 31` -> 2026-12-31.
  - `tripDayNotes`: passage under `## Day 3` runs to the next `##`; a `###` inside stays; text before the first day heading and under `## Packing` is in no passage; two `## Day 3` sections join with `'\n\n'` in order; a `## Day 4` line inside a ```` ``` ```` fence neither starts nor ends a passage; `~~~` fences too; `## Day 3` followed only by blank lines gives no entry; a heading at end of text gives no entry; `#Day 3` (no space) is not a heading; trailing `##` closers (`## Day 3 ##`) are ignored; leading/trailing blank lines are trimmed from a passage; `passageEnds[day3]` equals the offset just past the last non-blank character of the last Day 3 passage.

- [ ] **Step 2: Run to verify they fail.**
  Run: `flutter test test/features/trips/domain/services/trip_day_notes_test.dart`
  Expected: FAIL, `trip_day_notes.dart` not found.

- [ ] **Step 3: Implement.** Line scanner over `notes` with offsets: track fence state (opening fence = up to 3 spaces then 3+ backticks or tildes; closes on the same char, at least as long). ATX heading = up to 3 spaces, 1 to 6 `#`, then a space or end of line; strip a closing `#` run preceded by a space. For each heading outside a fence, `dayNamedByHeading(text)`; a day heading opens a passage that ends at the next heading (outside a fence) with level <= its own. Heading matching: lowercase, trim, drop one trailing `.` or `:`; try each day label (`text` starts with prefix and ends with suffix, middle is `\d+` after trimming); else ISO `^\d{4}-\d{2}-\d{2}$`; else tokenize on whitespace and commas, strip a trailing `.` from each token, optional leading weekday token, then `month day` or `day month` (day may carry `st|nd|rd|th`), then optional 4-digit year, and nothing else. Yearless dates match by month and day among `days`.

- [ ] **Step 4: Run to verify they pass.** Same command. Expected: all pass.

- [ ] **Step 5: Commit.** `git add` the two files; `git commit -m "feat(trips): read day passages out of a trip's Notes"`.

### Task 2: Vocabulary from the app's language

**Files:**
- Create: `lib/features/trips/presentation/helpers/trip_day_notes_vocabulary.dart`
- Test: `test/features/trips/presentation/helpers/trip_day_notes_vocabulary_test.dart`

**Interfaces:**
- Consumes: `TripDayNotesVocabulary`, `dayNamedByHeading` (Task 1).
- Produces: `TripDayNotesVocabulary tripDayNotesVocabularyFor(AppLocalizations l10n)` (adds English always via `lookupAppLocalizations(const Locale('en'))`; month and weekday names from `DateFormat.MMMM / MMM / EEEE / EEE` in `l10n.localeName` and `'en'`; day label prefix/suffix by formatting `l10n.trips_story_dayLabel(987654)` and splitting on `'987654'`).

- [ ] **Step 1: Write the failing tests.** For each of `en`, `de`, `hu`, `zh`, `ar` (via `lookupAppLocalizations(Locale(code))`, after `initializeDateFormatting()`): `dayNamedByHeading(l10n.trips_story_dayLabel(3), days, vocab)` returns the third day. Under `de`: `5 November` and `Mittwoch 5 November` -> 2026-11-05 (German month and weekday names), `Tag 3` and English `Day 3` both -> the third day. Forms outside the spec's list (`5. Nov.`) are not asserted either way.
- [ ] **Step 2: Run to verify they fail.** `flutter test test/features/trips/presentation/helpers/trip_day_notes_vocabulary_test.dart`. Expected: FAIL, file not found.
- [ ] **Step 3: Implement** `tripDayNotesVocabularyFor`. Lowercase everything, strip a trailing `.` from abbreviations.
- [ ] **Step 4: Run to verify they pass.**
- [ ] **Step 5: Commit** `feat(trips): build the day-note vocabulary from the app's language`.

### Task 3: Strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`, next to `trips_story_dayLabel`.

New keys (English values; translate each locale):
- `trips_story_fromTripNotes`: `From trip notes`
- `trips_story_addDayNote`: `Add note`
- `trips_story_editDayNote`: `Edit note`

- [ ] **Step 1:** Add the keys with an `@` description in `app_en.arb` and translations in the other 10.
- [ ] **Step 2:** Run `flutter gen-l10n`. Expected: no warnings about untranslated messages for these keys.
- [ ] **Step 3:** Fold into the commit of Task 4.

### Task 4: The day page draws the passage and offers Add note

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_plan.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_page.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_day_page_test.dart`

**Interfaces:**
- Consumes: Task 3 strings.
- Produces:
  - `TripStoryDayPlan({..., String? tripNotes, VoidCallback? onOpenTripNotes})`; `static bool hasContent(TripStoryDay day, {required bool hasHistory, String? tripNotes})`. Keys: `TripStoryDayPlan.tripNotesKey = Key('trip-day-trip-notes')`, `TripStoryDayPlan.fromTripNotesKey = Key('trip-day-from-trip-notes')`.
  - `TripStoryDayPage({..., String? tripNotes, VoidCallback? onOpenTripNotes, VoidCallback? onEditNote})`. Key: `TripStoryDayPage.editNoteKey = Key('trip-day-edit-note')`.

- [ ] **Step 1: Write the failing tests** in `trip_story_day_page_test.dart`:
  - a day with no dives, no itinerary and `tripNotes: 'Vis 30 m'` shows `From trip notes`, shows `Vis 30 m`, and does not show `TripStoryDayPage.noDivesKey`;
  - an itinerary note and trip notes both present: the itinerary note's text is above the trip notes' text (compare `tester.getTopLeft(...).dy`);
  - tapping `fromTripNotesKey` calls `onOpenTripNotes` once;
  - `onEditNote` set and no `tripNotes`: button text `Add note`; with `tripNotes`: `Edit note`; tap calls `onEditNote`; `onEditNote` null: no `editNoteKey`.
- [ ] **Step 2: Run to verify they fail.** `flutter test test/features/trips/presentation/widgets/story/trip_story_day_page_test.dart`.
- [ ] **Step 3: Implement.** In the plan: after the itinerary notes, when `tripNotes` is non-blank, an `InkWell` caption row (`TripDaySectionCaption`-style text plus `Icons.chevron_right`, size 16) keyed `fromTripNotesKey`, then `MarkdownNotesView(tripNotes, key: tripNotesKey, style: bodySmall)`. In the page: pass both through; `hasPlan` uses `tripNotes`; add a left-aligned `TextButton.icon(icon: Icon(Icons.edit_note), ...)` keyed `editNoteKey` right after `plan` in both the one- and two-column stacks, only when `onEditNote != null`.
- [ ] **Step 4: Run to verify they pass**, plus `trip_story_day_plan`-related tests in the same folder.
- [ ] **Step 5: Commit** (with Task 3's ARB and generated files) `feat(trips): show a day's passage from the trip's Notes on its page`.

### Task 5: Wire passages and actions through the story

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_trip_page.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_overview_tab.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_detail_tabs.dart`
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart`
- Modify: `lib/features/trips/presentation/helpers/trip_edit_navigation.dart`
- Modify: `lib/core/router/app_router.dart` (editTrip route), `lib/features/trips/presentation/pages/trip_list_page.dart` (`_buildEditPane`)
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`, `test/features/trips/presentation/helpers/trip_edit_navigation_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 2, 4.
- Produces:
  - `TripEditSection.notes` (new enum value).
  - `TripNoteDay` query codec in `trip_edit_navigation.dart`: `Map<String, String> tripNoteDayQuery(TripNoteDay day)` -> `{'noteDate': 'yyyy-MM-dd', 'noteDay': '<n>'}`; `TripNoteDay? tripNoteDayFromQuery(Map<String, String> query)` (null when either is missing or malformed).
  - `openTripEdit(..., TripNoteDay? noteDay)`; with `noteDay`, section is `notes` and the query carries the codec's keys.
  - `TripStoryView({..., ValueChanged<TripNoteDay>? onEditDayNote})`, `TripOverviewTab({..., ValueChanged<TripNoteDay>? onEditDayNote})`, `TripDetailTabs({..., ValueChanged<TripNoteDay>? onEditDayNote})`.
  - `TripStoryTripPage({..., Key? notesKey})`: the Notes card carries `notesKey`.
  - `TripEditPage({..., TripNoteDay? noteDay})` constructor parameter (used in Task 6); both edit routes pass `tripNoteDayFromQuery(state.uri.queryParameters)`.

- [ ] **Step 1: Write the failing tests.**
  - navigation test: `tripNoteDayFromQuery(tripNoteDayQuery(d)) == d`; `{'noteDate': 'x', 'noteDay': '3'}` -> null; pushed location for `openTripEdit(..., embedded: false, noteDay: d)` is `/trips/t1/edit?section=notes&noteDate=2026-11-05&noteDay=3`.
  - story view test: a trip with Notes `'## Day 2\nCurrent was strong'`, selected day 2 shows `Current was strong`; tapping `From trip notes` shows the Trip page (its totals key) and the Notes card is visible (`tester.getRect` inside the viewport); `onEditDayNote` receives `TripNoteDay(date: day2, dayNumber: 2)` when the edit button is tapped.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.** In `_TripStoryViewState`: a `_notesKey = GlobalKey()`; a small memo keyed on (`trip.notes`, the days' (date, dayNumber) list, `l10n.localeName`) holding `TripDayNotes`; pass `passages[day.date]` as `tripNotes`; `onOpenTripNotes` = `_select(null)` then a post-frame `Scrollable.ensureVisible(_notesKey.currentContext!, duration: 300 ms)` when the context exists; `onEditNote` only when `widget.onEditDayNote != null`. `_TripDetailContent` passes `onEditDayNote: (day) => openTripEdit(context, trip.id, embedded: embedded, noteDay: day)`.
- [ ] **Step 4: Run to verify they pass**, plus `trip_overview_tab`, `trip_detail_tabs` and `trip_detail_page` tests if present.
- [ ] **Step 5: Commit** `feat(trips): open a day's passage in the trip page and the editor`.

### Task 6: The editor places the day's heading

**Files:**
- Create: `lib/features/trips/presentation/helpers/trip_day_note_editing.dart`
- Modify: `lib/features/trips/presentation/pages/trip_edit_page.dart`
- Test: `test/features/trips/presentation/helpers/trip_day_note_editing_test.dart`, `test/features/trips/presentation/pages/trip_edit_page_test.dart`

**Interfaces:**
- Consumes: `tripDayNotes`, `TripNoteDay`, `TripDayNotesVocabulary` (Task 1); `tripDayNotesVocabularyFor` (Task 2); `TripEditPage.noteDay` (Task 5).
- Produces:
  ```dart
  class DayNotePlacement {
    final String text;            // the Notes text to load into the field
    final int cursor;             // where the caret goes
    final String? insertedHeading; // the heading line Add note appended, or null when it found one
  }
  DayNotePlacement placeDayNote(String notes, TripNoteDay day, TripDayNotesVocabulary vocabulary, {required String headingLabel});
  String dropUntouchedDayHeading(String notes, String insertedHeading);
  ```

- [ ] **Step 1: Write the failing helper tests.**
  - `placeDayNote('', d3, v, headingLabel: 'Day 3')` -> text `'## Day 3\n'`, cursor at text length, insertedHeading `'## Day 3'`.
  - `placeDayNote('Trip intro', ...)` -> text `'Trip intro\n\n## Day 3\n'`; `'Trip intro\n\n'` (trailing blank lines) -> same text, not three newlines.
  - Notes with `## Nov 5\nWreck` -> text unchanged, cursor = offset after `Wreck`, insertedHeading null.
  - `dropUntouchedDayHeading('Trip intro\n\n## Day 3\n', '## Day 3')` -> `'Trip intro'`; with `'## Day 3\nSaw a turtle'` -> unchanged; `'## Day 3\n\n## Day 4\nX'` with insertedHeading `'## Day 3'` -> `'## Day 4\nX'`; when the heading line occurs twice (diver also wrote one) only the LAST empty match is dropped.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement the helper.**
- [ ] **Step 4: Write the failing page tests** in `trip_edit_page_test.dart`: with a trip whose notes are `'Intro'` and `noteDay: d3`, after load the notes field text ends with `'## Day 3\n'`; the notes field has focus; the selection is collapsed at the end; popping the route shows no discard dialog; with the name changed and Save tapped, the saved trip's `notes` is `'Intro'`; typing `Turtle` after load and saving stores `'Intro\n\n## Day 3\nTurtle'`.
- [ ] **Step 5: Implement in the page.** Add `final _notesFocusNode = FocusNode()` and `final _notesKey = GlobalKey()` (dispose the node); pass them to the `MarkdownNotesField`. In `_loadTrip`, where `_notesController.text = trip.notes` is set (while `_isLoading` is still true, so the listener does not dirty the form), when `widget.noteDay != null` load `placement.text` instead and remember `_insertedDayHeading = placement.insertedHeading`; after `setState(... _isLoading = false)` add a post-frame callback (as Planning does) that ensures `_notesKey` visible, requests `_notesFocusNode` focus and sets `_notesController.selection = TextSelection.collapsed(offset: placement.cursor)`. In `_saveTrip`, `notes:` becomes `(inserted == null ? text : dropUntouchedDayHeading(text, inserted)).trim()`. `initialSection == TripEditSection.notes` without `noteDay` scrolls to `_notesKey` only.
- [ ] **Step 6: Run both test files to verify they pass.**
- [ ] **Step 7: Commit** `feat(trips): Add note opens the trip editor at the day's heading`.

### Task 7: Checks

- [ ] `dart format .` (no changes expected after it).
- [ ] `flutter analyze` -> `No issues found!`.
- [ ] `flutter test test/features/trips test/architecture test/shared/widgets/markdown_notes` -> all pass.
- [ ] Commit any formatting changes with the task they belong to.
