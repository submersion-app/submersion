# Trip day notes from the trip's Notes: design

Date: 2026-11-16. Release: v1.8.5.

## Intent

When the diver looks at one day of a trip, they want to see the notes that
belong to that day. They want to write those notes once, in the trip's own
Notes, as a journal with a heading per day, rather than in a separate field on
each day.

Today a day's notes live on its itinerary row (`trip_itinerary_days.notes`),
edited in the itinerary day sheet and shown in the day page's plan section
(`TripStoryDayPlan`). A day with no itinerary row has nowhere to put notes, and
many trips have no itinerary rows at all. The trip's Notes
(`trips.notes`, Markdown) show only as a card on the whole-trip page.

## Goals

- A passage in the trip's Notes under a heading that names a trip day shows on
  that day's page.
- Works for every calendar day of the trip, with or without an itinerary row.
- One source of truth: the text is stored once, in `trips.notes`.
- From a day's page, the diver can start (or go to) that day's note in the trip
  editor without typing the heading by hand.

## Non-goals

- No change to how itinerary day notes are stored or edited. They still show,
  first, on their day.
- No change to the whole-trip page's Notes card: it still shows the whole note.
- No inline links that tie a single sentence to a day (rejected option B).
- No change to PDF, export, import or sync. Nothing new is stored.
- No rename or rewrite of headings when trip dates change. A `Day 3` heading
  follows day 3; a date heading that falls outside the trip after a date change
  simply stops matching.

## Anti-goals

- A second copy of the day's text anywhere (table, itinerary row, cache that
  syncs). It would drift from the trip's Notes.
- Showing a passage on the wrong day. A heading that is ambiguous or names no
  trip day must match nothing rather than guess.
- Treating a `#` line inside a fenced code block as a heading.

## Approaches considered

1. **A scanner over the Notes source (chosen).** A pure function reads the
   trip's Notes line by line, finds ATX headings outside fenced code blocks,
   works out which trip day each one names, and cuts the raw Markdown into one
   passage per day. Drawn with the existing `MarkdownNotesView`. Nothing stored.
   Trade-off: a small, hand-written, Markdown-aware line scanner, because the
   `markdown` package gives no source positions.
2. **Split the parsed Markdown tree.** Reuses `parseNotesMarkdown`, but changes
   the shared `MarkdownNotesView` to draw node lists and loses the passage's
   source text. Rejected.
3. **Save each passage when the trip saves.** Needs a schema rung, sync repair
   and a second copy of the text. Rejected; it is the anti-goal above.

The diver picked option 1, and marking by heading per day (option A of the
marking question) over inline day links (B) and gathering per-day notes into
the trip page (C).

## Behaviour (decided with the diver)

- Notes for a day are written in the trip's Notes, under a heading per day.
- Opening a single day shows the passage(s) for that day.
- The day page has an "Add note" action that opens the trip editor with the
  day's heading added and the cursor under it.

## Behaviour (proposed in the conversation, not objected to)

### Which headings name a day

A heading is an ATX heading (`#` to `######`, then a space or end of line) that
is not inside a fenced code block (``` or ~~~, any length of 3 or more, closed
by a fence of the same character at least as long). Setext headings
(underlined with `===` or `---`) do not count. Trailing closing `#`s and
surrounding whitespace are ignored. Matching ignores case and a trailing
period or colon.

The heading text names a trip day when, in full, it is one of:

- **Day number:** the app's day label with a number, `Day 3`, read through the
  `trips_story_dayLabel` template (`Day {number}` in English, `Tag {number}` in
  German, `{number}. nap` in Hungarian), so the number may sit anywhere the
  template puts it. The template is accepted in English and in the app's
  current language. The number is `TripStoryDay.dayNumber`, the number the day
  page shows ("Day 2 of 6") and the picker uses. *Builder's-check call:* the
  story's span can start before the trip's start date when a dive or itinerary
  row falls outside it (`tripStoryDaySpan`); headings follow the numbers the
  diver sees on screen, so they move with the page if the span moves.
- **ISO date:** `2026-11-05`.
- **Month and day:** `Nov 5`, `November 5`, `5 Nov`, `5 November`, optionally
  with a year (`Nov 5, 2026`, `5 November 2026`) and optionally led by a
  weekday (`Wed Nov 5`, `Wednesday, 5 November`). Month and weekday names are
  accepted in full and abbreviated form, in English and in the app's current
  language (from `intl` date symbols). A day number with an ordinal suffix
  (`5th`) is accepted in English.

The days a heading can name are the story's days (`TripStory.days`), which is
every day the day picker offers, including any the story's span added outside
the trip's own dates.

A date with no year matches the story day with that month and day; a story is
shorter than a year, so this is unique. A date with a year must match exactly.
A weekday that contradicts the date makes the heading match nothing. A number
or date outside the story's days matches nothing. Anything that does not match
one of the forms in full matches nothing. Only the listed forms are promised;
a language's own date order beyond them (`5. Nov.`, native digits) is not.

### Where a passage runs

A day heading's passage is every line after it up to, not including, the next
heading (outside code fences) at the same level or a higher one (fewer `#`s).
Deeper subheadings stay inside the passage, even when a subheading itself names
a different day. Leading and trailing blank lines are trimmed; a passage that is
empty after trimming counts as no passage. Text before the first day heading,
and passages under non-day headings, show only on the whole-trip page.

When several headings name the same day, their passages show in the order they
appear, separated by a blank line.

### On the day page

The passage draws in the day's plan section (`TripStoryDayPlan`), after the
itinerary row's notes when there are any, and before the planned-dive progress
line and history pills. Above it, a small caption "From trip notes" with a
chevron. Tapping the caption selects the whole-trip ("All") page in the day
picker and scrolls it to the Notes card.

The plan section's content check (`TripStoryDayPlan.hasContent`) counts a
passage as content, so a day whose only notes come from the trip's Notes shows
its plan section and not the "no dives this day" line.

### Add note

A text button on the day page, under the plan section (or where the plan
section would be when it is empty), labelled "Add note" when the day has no
passage and "Edit note" when it does. It opens the trip editor (in the
master-detail pane when the trip is shown embedded, pushed otherwise, as
`openTripEdit` already does) with the Notes field focused:

- When the Notes have no heading for this day, the editor appends, after one
  blank line, `## ` plus the day label in the app's current language
  (`trips_story_dayLabel`, for example `## Day 3`), then a new line, and puts
  the cursor on that new line. What Add note writes is always a form the
  scanner reads.
- When they have one, the cursor goes to the end of that day's last passage.
- The Notes field scrolls into view.
- Adding the heading does not by itself mark the form changed: leaving the
  editor without typing asks no "discard changes?" question and saves nothing.
- *Builder's-check call:* if the diver saves the trip for another reason (a
  renamed trip, say) while the added heading still has nothing under it, the
  save drops that heading, so no empty `Day 3` lands on the trip's Notes card.
  The same holds when they typed under it and then deleted it all again.
  Only the heading Add note added in this editor visit is dropped, never one
  the diver wrote.

The edit route names the day by its date (`yyyy-MM-dd`) and its day number,
so the editor can write the label and find the day's passages without
rebuilding the story.

The action shows wherever the trip's own edit button shows; that button is not
gated today, so neither is Add note.

## Constraints

- Every user-visible string goes through l10n (ARB files and generated l10n
  must stay in step; the pre-push hook checks staleness).
- The scanner is pure Dart with no Flutter import, unit-tested directly.
- No new tables, columns or rungs. No sync changes.
- Files stay under the repo's 800-line guard; `trip_edit_page.dart` is already
  1293 lines, so new editor logic goes in a helper file, not inline.
- Day boundaries use the same local calendar-day logic the story builder uses
  (`DateTime(y, m, d)` from the trip's start date), not UTC.

## Where the work lands (builder's guide, not binding)

- `lib/features/trips/domain/services/trip_day_notes.dart` (new): the scanner.
  Inputs: the Notes text, the trip's calendar days (date and day number), and a
  vocabulary (day words, month and weekday names). Output: a map from day date
  to passage text, plus, for the editor, the source offset where each day's
  last passage ends.
- The vocabulary is built in presentation from the app's current locale and
  English, so the domain function never reads a locale itself.
- The passages are computed once per story and language where the story view
  has a `BuildContext` (`TripStoryView`), and handed to `TripStoryDayPage` and
  `TripStoryDayPlan`. The `TripStoryDay` entity need not change; the builder may
  choose to put the passage on it instead if that reads better.
- `TripEditSection` gains a `notes` value; the edit route gains a query
  parameter naming the day to add or find a note for.

## Left to the builder

- Exact widget for the caption and the Add note button, within the page's
  existing visual language (`TripDaySectionCaption`, text buttons).
- How the trip page is scrolled to its Notes card (a key on the card plus
  `Scrollable.ensureVisible`, as the edit form already does for Planning).
- Whether the scanner also returns offsets or the editor rescans.
- Test layout and names.
