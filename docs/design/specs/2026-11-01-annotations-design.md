# Annotations: notes tied to a moment in the dive

Date: 2026-11-01
Status: implemented on the feature branch, PR pending
Release: v1.8.4

## Intent

A diver writing up a dive wants to say *when* something happened: the
regulator free-flowed, they started feeling unwell, they lost the buddy.
Today a dive's Notes are one block of Markdown with no connection to the
profile, and the only events on the profile are the computer's own. An
annotation ties a passage of the Notes to a time in the dive, so it shows
up on the profile at the depth it happened and the Notes read back to that
spot.

The feature is called **Annotations** everywhere a user sees it.

## Goals

- Pin a passage of a dive's Notes to a time from the start of the dive.
- See annotations on the profile as markers distinct from the computer's
  events, with the passage as the label.
- Create one from the chart (pick the spot, then write) and from Notes
  (select the words, then pick the time).
- Move or remove one later.
- Keep annotations through resync, reparse, sync, export and a UDDF
  backup restore.

## Non-goals

- Annotations on planned dives, on the profile editor, or on anything that
  is not a logged dive.
- Any kind, category or severity on an annotation. One kind only.
- Photos, species or gear attached to a moment. Only words.
- Dragging a marker along the chart with a finger or mouse. A drag already
  pans the chart.
- Annotations in the dive edit page beyond what the Notes editor already
  offers. The edit page has no profile chart and gains none.

## Anti-goals

- A second place to write prose. The words of an annotation live in the
  dive's Notes and nowhere else. If the Notes passage goes, so does the
  annotation.
- A new gesture that fights the chart's existing tap, hold, double-tap and
  drag.
- A marker that lies: the time drawn after a Notes link is the
  annotation's current time, never text the diver typed.

## What the diver sees

### On the profile

Every annotation draws as a vertical line in the annotation colour (an
amber distinct from the grey the computer's events use and from every
metric colour) with a filled dot on the depth curve at its time and the
first few words of its passage as the label. The existing event marker
pipeline (grouping by timestamp, pixel-space thinning, collision-aware
labels) handles them with one rule added: an annotation is never dropped
in favour of a computer event at the same spot, and two annotations too
close together keep both lines. Their labels go through the same placement
as every other event, stacked where there is room; where there is none, the
label earlier in the dive stays and the later one is hidden.

Tapping a marker opens a small popup anchored to it:

- the linked words, in full;
- the time (mm:ss from the start) and the depth there, in the diver's
  units;
- "Open in Notes", which scrolls the page to the Notes card and briefly
  highlights the passage;
- "Move", which re-enters placement mode for this annotation;
- "Remove", which deletes the marker and turns the Notes link back into
  plain words.

Tapping the time in the popup opens the time box so a new mm:ss can be
typed instead of pointed at.

The fullscreen profile page shows the same markers, popup and placement
mode.

### In the Notes card

A linked passage draws as a link with a small pin glyph before it and the
annotation's time after it in a smaller muted style. Tapping it scrolls to
the profile, pans a zoomed plot to the marker when it is out of view, lights
it up and opens its popup. On a dive with no profile there is no marker to
open, so it opens the time sheet instead. The time after the link is rendered by the app from the annotation, so moving the marker
updates it and it never appears in the stored text.

### Creating from the chart

1. The Dive Profile card's header gains a pin icon button, "Add
   annotation". Tapping it puts the chart in placement mode: a banner above
   the plot reads "Tap the profile where it happened. Press and hold to
   fine-tune." and the chart's own cursor readout follows the finger with
   the time and depth. Any tap or hold-and-release on the plot places the
   annotation; the legend, zoom and metric controls still work. Tapping the
   pin again, or the banner's close, leaves placement mode with nothing
   added.
2. A sheet opens: the chosen time (tappable, to type a different one), the
   depth there, and a single text field for what happened. "Add" writes
   it; "Cancel" discards it and leaves placement mode.
3. The words are appended to the dive's Notes as a new paragraph that is
   entirely the annotation's link, and the marker appears.

On desktop a right-click (secondary tap) on the plot opens a context menu
with one item, "Annotate at mm:ss", which skips the pin button and opens
the same sheet for that time.

### Creating from Notes

In the dive edit page's Notes editor, the Markdown toolbar gains a pin
button, "Annotate".

- With text selected, it opens a sheet titled with the selected words:
  a time box (mm:ss), and under it a small read-only copy of the dive's
  profile; tapping the small profile fills the time box. "Annotate" wraps
  the selection as the annotation's link. The annotation itself is
  created when the dive is saved, like every other change on the edit
  page; until then the editor shows the link and nothing exists on the
  profile.
- With nothing selected, the same sheet also asks for the words, and
  inserts a new linked line at the cursor.

A dive with no profile samples (a manual dive) still accepts an
annotation by typed time; the small profile is replaced by a note saying
there is no profile to point at.

### Moving and removing

- "Move" from the popup re-enters placement mode for that annotation (the
  banner names it) and the next placement updates its time and depth.
  The Notes text is untouched; the time after the link updates.
- Typing a new time in the popup's time box does the same.
- "Remove" deletes the annotation and rewrites the Notes so the link's
  words stay as plain text.
- Deleting the linked words from Notes, or stripping the link (in the
  editor, or by any Markdown edit), deletes the annotation when the dive
  is saved. Orphan annotations (an id not present in Notes) are never
  drawn and are deleted on the next save, so a Notes edit arriving by
  sync has the same effect. This is the one rule the diver chose: delete
  the note, the marker goes with it.

## Data model

An annotation is a row in the existing `dive_profile_events` table:

| column | value |
| --- | --- |
| `event_type` | `annotation` (new `ProfileEventType` value) |
| `source` | `user` |
| `timestamp` | seconds from the start of the dive |
| `depth` | depth at that time, from the active profile, metres; null when the dive has no profile |
| `description` | a cached copy of the linked words, refreshed whenever Notes are saved |
| `computer_id` | null |

No schema change. The table already syncs, exports and tombstones per
dive (#1926). A peer older than this feature reads the unknown type as a
bookmark (the mapper's existing fallback) and draws it as one.

The link in Notes is a plain Markdown link whose address is
`annotation:<event id>`:

```markdown
Current picked up and I [started feeling nauseous](annotation:4f1c...) at the wall.
```

Notes stay valid Markdown everywhere they already go. The address is the
only coupling between the two tables; nothing else is stored.

The words of an annotation are the link text in Notes. `description` is a
cache for consumers that read events without Notes (UDDF export, the 3D
view, sync peers, the conflict catalogue) and is rewritten from Notes on
every save of the dive, so the two cannot drift for more than one save. It
holds the words as the Notes render them: a Markdown mark the diver typed
(asterisks, backticks) is formatting there, not text, so it is formatting in
the marker label and the popup too.

## Behaviour rules

- **Resync and reparse keep annotations.** Both paths today delete every
  event on the dive before re-inserting the file's or computer's events.
  They must delete only rows whose `source` is not `user`, so every
  user-authored event survives, annotations included. This is a bug fix
  with its own tests.
- **Preserved events and the dive-scoped sync tombstone.** Resync,
  reparse and a native re-download each log one `EventScopeTombstone` for
  the whole dive after deleting, and a peer deletes every event whose
  clock is older than that tombstone. Keeping `user` rows locally is not
  enough: each surviving `user` row is re-marked pending after the scope
  tombstone is logged, so it carries a newer clock and every peer keeps it
  too. No change to the tombstone's shape and no compatibility floor.
  (Builder's call.)
- **Dangling links.** A link whose id has no event row on this dive (text
  pasted from another dive, bulk "append notes" putting one id on many
  dives, a stripped event) draws as plain words in the Notes card with no
  pin and no time, and the text is left untouched. Reconciliation runs in
  one direction only: it deletes orphan events, it never rewrites a
  dangling link. (Builder's call.)
- **Plain text, narrowed.** The shared `markdownToPlainText` is a pure
  function of the string with many callers that never load events, so it
  renders an annotation link as its bare words everywhere. Only the PDF
  (its own renderer, fed the dive's annotation times by the export
  service) appends ` (mm:ss)`. There is no share-as-text feature for a
  dive, so nothing else renders the time. Search still finds the words. (Builder's call,
  narrowing the rule below.)
- **Move does not re-stamp the dive.** Add and Remove rewrite Notes and so
  bump the dive row; Move and a typed time change only the event row,
  whose own clock carries the change (clockless child sync, #1769). The
  dive row is left alone so it cannot collide with a peer's Notes edit.
  (Builder's call.)
- **UDDF round trip keeps annotations.** The full UDDF export writes each
  event's `id` and `source` as app-namespaced extensions; the restore and
  resync readers keep an annotation's id and `user` source, and skip an
  incoming event whose id already exists on the dive, so a resync from a
  file that carries annotations alongside the preserved rows cannot
  duplicate them. Readers of other files, and older readers of ours,
  ignore the extensions as today. (Diver's choice.)
- **Legend.** The profile legend gains its own "Annotations" toggle, on by
  default and independent of the Events toggle, so hiding the computer's
  events keeps the diver's own. (Diver's choice.)
- **Dive split, merge, uncombine, timeline re-zero and consolidation**
  already move or copy events by dive id and shift timestamps; an
  annotation follows the same rules as any other event with no special
  case. Where a service drops events outright, it must keep `user` rows,
  on the same principle as resync.
- **Delete a dive**: cascade, as today.
- **Reconciliation on save** (the dive edit page's save, the popup's
  Remove, the chart's Add, and any in-place Notes rewrite): parse Notes
  for `annotation:` links; delete annotations whose id is absent; refresh
  `description` for those present. The chart-side writes run it inside the
  Notes write's transaction; the edit page runs it right after the dive
  save, in its own transaction, because the save goes through the dive
  repository. A crash between the two is self-healing: a pending link
  renders as plain words and an orphan row stays hidden until the next
  save reconciles both.
- **Chart-side writes** (Add, Move, Remove, typed time) go through the
  repository in one transaction that writes the event row and the Notes
  text together, marks both records pending for sync, and bumps the dive's
  `updated_at` once. The detail page's chart and Notes card refresh from
  the normal dive watch.
- **Plain text and exports.** The plain-text rendering of Notes renders
  an annotation link as its bare words; the PDF renders `words (mm:ss)` from the annotation's current time (see "Plain
  text, narrowed" above). Web and mail links keep their existing
  `text (address)` form. The address `annotation:<id>` is never shown to
  a user.
- **Tappable links.** `isTappableNotesLink` keeps refusing everything but
  web and mail; annotation links are handled by a separate hook the Notes
  view exposes, so other Notes consumers (courses, medical info, trip
  notes) render them as plain words with no behaviour. Only the dive
  detail Notes card wires the hook.
- **Units.** Depth in the popup, the sheet and the readout uses the active
  diver's depth unit via the existing unit formatter.
- **Times** are mm:ss from the start of the dive, matching the chart's
  axis and the profile event tooltip. Input accepts `m`, `mm`, `m:ss`,
  `mm:ss` and clamps to the dive's runtime.
- **Localisation.** Every new string is added to `app_en.arb` and all ten
  locale ARBs before `flutter gen-l10n` runs.

## Constraints

- No schema bump; this must not take a migration rung.
- PR #4073 (gas switch editing) merged on 2026-11-01 and is not yet in
  this branch. The work starts with a merge of main and reuses its mm:ss
  helper (`lib/core/utils/minutes_seconds.dart`) and depth-at-time helper
  (`profile_depth_at.dart`). It touched the reparse and reimport services,
  the dive edit page and the conflict catalogue, which this feature edits
  too.
- The chart file is at 7,500 lines. New chart behaviour (placement mode,
  the popup, right-click) goes in new files that the chart composes,
  never inline.
- `dive_edit_page.dart` is large; the Notes toolbar sheet goes in its own
  file under `edit_sections/` or `shared/widgets/markdown_notes/`.
- Tests first, per the repo's rule. The reconciliation, plain-text
  rendering, resync preservation and time parsing are pure functions with
  unit tests; the popup, placement mode and toolbar flow get widget tests.

## Left to the builder

- Exact amber token and how it is themed for light and dark.
- How many words the chart label shows before an ellipsis.
- Whether the placement readout reuses the existing cursor tooltip or a
  simpler banner readout.
- The sheet's widget (bottom sheet on phone, dialog on desktop, per the
  app's existing convention).
- Whether the Notes card's scroll-to-passage highlight is a background
  flash or a brief outline.
- Including `annotation` events in the 3D view's bookmark pass.
- Where `annotation` sits in the conflict catalogue labels.

## Decisions made in design

- Words live in Notes; the event row caches them. (Diver's choice.)
- Marker popup shows only the linked words, not the paragraph.
  (Diver's choice, option A.)
- Chart creation starts from a pin button on the card header with
  right-click as the desktop shortcut, not from the point readout.
  (Diver's choice, option A.)
- Deleting the Notes passage deletes the marker. (Diver's choice.)
- Moving is by placement mode or typed time, never by dragging the dot.
  (Diver's agreement.)
- New `ProfileEventType.annotation` rather than reusing `bookmark` or
  `note`, so imported bookmarks (Subsurface, Suunto) stay what they are
  and an annotation is recognisable by type alone. (Builder's call.)
- `annotation:<id>` link scheme, id-based so moving an annotation never
  touches the text. (Builder's call.)
- Edit-page annotations materialise on save, chart annotations
  immediately. (Builder's call; matches how each page already writes.)
- Resync and reparse preserve all `user` events, not only annotations.
  (Builder's call; the narrower rule would leave the same bug for
  bookmarks.)
