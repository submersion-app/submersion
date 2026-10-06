# Sync conflict comparison: show exactly what each choice keeps and discards

Date: 2026-10-05
Issue: #694 (Unclear conflict resolution during logbook synchronisation)

## Problem

A diver who edits the same record on two devices gets a sync conflict and must
choose "Keep local", "Keep remote" or "Keep both". The dialog
(`lib/features/settings/presentation/widgets/conflict_resolution_dialog.dart`)
shows two stacked cards, one per version, and the diver cannot tell from them
what they would lose by picking either one.

Since the issue was filed (1.6.0), `conflict_data_preview.dart` learned to add
up to five differing columns to each card (v1.7.6). What is still wrong:

- Nothing marks which rows differ. Shared fields such as a long `notes` value
  print in full on both cards, and the reader compares by scrolling.
- Labels are raw column names (`waterTemp`, `diveNumber`, `visibilityMeters`).
- Values are partly raw: only 13 hard-coded columns are unit formatted, enum
  columns print stored names (`good`, `shore`), JSON payloads print as JSON.
- Differences past the fifth are dropped silently.
- A remote deletion renders as a raw `_deleted: true` row.
- "Keep both" is offered where it silently behaves as "Keep local".
- The cards use hard-coded `Colors.blue` and `Colors.green`.

## Goal

For every conflict the dialog shows every field the two versions disagree on,
both values in the active diver's units and language, and, for the selected
choice, which values it discards. Presentation only: the sync engine, the
schema and the meaning of each resolution are unchanged.

## Constraints found in the code

- A conflict stores only the remote row (`sync_records.conflict_data`); the
  local side is the current local row re-read by `SyncService.getConflicts`.
  There is no common ancestor, so the dialog can show what differs, never which
  device made the change. Highlights therefore mean "only on this side", not
  "added" or "removed".
- "Keep remote" overlays the remote map onto the local row
  (`overlayOntoLocal`) for HLC-bearing entities, and clockless entities upsert
  with `nullToAbsent`. Either way a key the remote map omits keeps its local
  value.
- "Keep both" (`SyncService.resolveConflict`) copies the remote row under a new
  id only when the record has an `id` and the entity is not `settings`, and
  only when the remote side is not a deletion. Otherwise it keeps the local row.
- Every synced row carries an `hlc` of the form `<millis>:<counter>:<nodeId>`;
  the nodeId is the device that last wrote it. `PeerDeviceNameStore` maps peer
  device ids to the names they publish on their manifests, and
  `DeviceDisplayNameService` resolves this device's name.
- Enum-valued columns are plain `TextColumn`s; nothing in the schema marks a
  column as an enum or as metric.

## Design

### 1. Comparison model (pure Dart)

`buildConflictComparison(...)` turns a `SyncConflict` into a
`ConflictComparison` with one of four states:

| State | Detected by | Shown |
| --- | --- | --- |
| `differing` | both sides present, at least one compared field differs | differences table plus collapsed same fields |
| `remoteDeleted` | remote map has `_deleted: true` | banner "<remote> deleted this <entity>", then the local values |
| `localDeleted` | `localData` is empty | banner "<local> deleted this <entity>", then the remote values |
| `sameContent` | both present, no compared field differs | banner: the versions match, only the edit time differs; either choice loses nothing |

Rules:

- Bookkeeping is never compared: `id`, `hlc`, `deviceId`, `originDeviceId`,
  `syncedAt`, `createdAt`, `updatedAt`. The two modified times stay in the
  header.
- A key absent from the remote map is not a difference (see the overlay
  constraint). An explicit `null` on either side is a difference and renders
  as "Not set".
- Foreign keys are compared by id and displayed through the existing
  `ConflictReference` resolution ("Site: Blue Hole"). They take their place in
  the field list rather than a separate reference block.
- Quality findings keep their localized sentence row; the raw columns that
  sentence replaces stay hidden only when the sentence was built, as today.
- No cap: every difference is listed. Order is the catalogue's preferred fields
  first (name, title, date, location, depth, duration, notes), then by
  localized label.

Each difference is a `FieldDifference(key, label, kind, localDisplay,
remoteDisplay)`; each same field is `(key, label, display)`.

Device labels: the local label is `DeviceDisplayNameService`'s name; the remote
label is the nodeId parsed from the remote `hlc` and looked up in
`PeerDeviceNameStore`. A missing name or an unparseable `hlc` falls back to
"This device" and "Other device".

### 2. Field catalogue and formatting

`conflict_field_catalogue.dart` maps each column name to a `ConflictField`:
a label getter `String Function(AppLocalizations)` and a `FieldKind`. A second
map, keyed by `(entityType, column)`, overrides names whose label or kind
depends on the entity (`type`, `status`, `kind`, `category`, `source` and
similar).

Kinds and rendering (through the active diver's `UnitFormatter`):

| Kind | Rendering |
| --- | --- |
| depth, distance, pressure, temperature, weight, volume, speed, altitude | the diver's units |
| durationSeconds | "1h 5m", "45min", sub-minute keeps seconds (as today) |
| dateTime, date | epoch millis formatted; pre-1973 negative epochs handled (as today) |
| bool | "Yes" / "No" |
| number, shortText | as stored |
| longText | as stored, plus the word diff (section 3) |
| enum(E) | the stored name through E's localized label; an unknown value prints as stored |
| reference | resolved reference (name, date) |
| opaque | JSON and blob payloads: "Changed" in the differences, never raw JSON |

Labels are `settings_conflict_field_<column>`, except where an existing
`DiveField.localizedDisplayName` label has the same meaning, which is reused.
Enum values reuse the app's existing localized enum labels; enums without one
get new `enum_<Enum>_<value>` keys beside their enum. All new keys are
translated into all 11 locales.

The old `formatConflictScalar` and its hard-coded column sets fold into the
catalogue; `conflict_data_preview.dart` is removed.

**Coverage guard.** `conflict_field_catalogue_coverage_test.dart` walks every
entity in `SyncService.entityHasUpdatedAt`, reads its Drift table's columns,
and fails naming any non-bookkeeping column that has neither a catalogue entry
nor an override. A new synced column cannot fall back to a raw name.

### 3. Dialog layout and interaction

- The dialog grows to 720 px wide on wide windows and goes full-screen below
  600 px. Header, counter, previous and next, Cancel and Apply are all
  unchanged.
- Body: the record card (unchanged); one modified line per side with device
  names; "What differs (N)"; a collapsed "N fields are the same" expansion
  listing label and value; or, in the deletion and same-content states, the
  banner from section 1.
- Wide layout (600 px and up): a three-column table, label, local, remote.
  Narrow layout: one block per field, label then one line per device.
- Long text: each side shows its full text with the words found only on that
  side highlighted by a tinted background and bold weight (not colour alone).
  A word-level LCS over whitespace and punctuation tokens; when the two texts
  together exceed 2,000 tokens the diff is skipped and both texts show plainly.
- Choices: chips "Keep <local>", "Keep <remote>", "Keep both". Once one is
  selected a line below states its effect:
  - Keep local: "Keeps <local>'s version. <remote>'s values for A, B and C are
    discarded."
  - Keep remote: the mirror.
  - Keep both: "Keeps <local>'s version and adds <remote>'s version as a
    separate <entity>."
  - Before any choice: "Choose which version to keep."
  - Deletion states name the deletion instead of fields (keeping the deleting
    side deletes the record here or everywhere).
- "Keep both" is hidden when it cannot make a copy: a deletion state, an
  entity with no `id` of its own, or `settings`.
- Local and remote tints come from the theme's colour scheme, so light and dark
  mode both read correctly.

### 4. Files

New, under `lib/features/settings/presentation/conflicts/`:

- `conflict_comparison.dart`: model and `buildConflictComparison`.
- `conflict_field_catalogue.dart`: catalogue and overrides.
- `conflict_field_format.dart`: kind-based formatting.
- `conflict_enum_labels.dart`: enum value label lookups.
- `word_diff.dart`: tokenizer and LCS marking.
- `conflict_device_labels.dart`: device naming from `hlc` and the stores.
- Widgets: `conflict_comparison_view.dart`, `conflict_difference_table.dart`,
  `conflict_text_diff.dart`, `conflict_choice_consequence.dart`.

Changed: `conflict_resolution_dialog.dart` (layout, chips, consequence,
Keep both visibility, theme colours). Removed: `conflict_data_preview.dart`.
The catalogue may split across several files by domain to stay under the
800-line limit.

## Testing

- Comparison: four states, omitted key versus explicit null, bookkeeping
  exclusion, no cap, ordering, references compared by id.
- Word diff: tokenizing, only-on-this-side marking, identical and empty texts,
  CJK and RTL text, the size cutoff.
- Formatting: every kind in metric and imperial, enum reuse and unknown value,
  opaque payloads, pre-1973 dates (absorbs `conflict_scalar_format_test.dart`).
- Coverage guard (section 2).
- Device labels: known peer, unknown peer, unparseable `hlc`.
- Widgets: wide and narrow layouts, the consequence line per choice, Keep both
  hidden in each of its three cases, the same-fields expansion, the deletion
  and same-content banners; existing dialog tests updated.

## Delivery

One PR closing #694, with before and after screenshots, light and dark, phone
and desktop widths. Translations land in their own `i18n:` commit, inserted by
anchor in every ARB with `flutter gen-l10n` run last.

## Out of scope

- Per-field merging of the two versions.
- Storing a common ancestor to say which device changed what.
- Grouping a dive's child-row conflicts (tanks, weights) under the dive.
