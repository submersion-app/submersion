# Pre-Dive Checklist — Design

Date: 2026-07-16
Status: Approved pending user review
Feature branch: `worktree-pre-dive-checklist`

## Summary

A pre-dive checklist system spanning the full rigor spectrum: casual buddy
checks (BWRAF, GUE EDGE), gear packing/assembly lists driven by equipment
sets, and audit-grade technical/CCR build checklists with enforced ordering,
recorded values, and locked completion records. Checklist sessions are
standalone (started before any dive record exists) and link to dives
automatically when a matching dive is later imported or logged.

Architecture: a new self-contained feature module (`lib/features/pre_dive/`)
that mirrors the proven template-to-instance snapshot pattern of the shipped
trip checklists feature (`lib/features/checklists/`) without modifying it.
Trip checklists are due-date-oriented to-dos; pre-dive sessions are timed
audit runs. The semantics differ enough that sharing schema would couple two
features that must evolve independently. Presentation idioms and small
widgets are reused where they fit.

## Requirements (from brainstorming)

- All four checklist kinds: at-the-site safety check, gear assembly/prep,
  tech/CCR build procedure, and simple reusable to-dos.
- Sessions are standalone with a timestamp; auto-link to a dive imported or
  created later (manual link/unlink always available).
- Built-in starter templates (read-only, clonable) plus fully custom user
  templates.
- Full audit mode: per-item states Done / Skipped / Flagged with notes,
  per-item completion timestamps, per-template enforced ordering, required
  value fields (e.g. cell millivolts), sessions locked after completion.
- Equipment-set integration: template sections expand dynamically from an
  equipment set at session start; items with overdue service demand an
  explicit decision.
- Entry points: add-dive sheet, dive detail page, home dashboard card, Tools
  section, and upcoming-trip pages.

## Data model

Four new tables in `lib/core/database/database.dart`. Schema bump to the
next free version (v113 as of writing — confirm the ladder at implementation
time), registered in `migrationVersions`, with an idempotent `beforeOpen`
backstop following the v111 equipment-set pattern.

### PreDiveChecklistTemplates

| Column | Type | Notes |
| ------ | ---- | ----- |
| id | text PK | uuid |
| diverId | text, nullable | refs Divers; scopes the template to a diver, matching the nullable-diverId convention of other owned entities |
| name | text | |
| description | text | default '' |
| category | text, nullable | e.g. "Safety", "CCR", "Packing" |
| strictOrder | bool | default false; enforce item order during sessions |
| isBuiltIn | bool | default false |
| builtinKey | text, nullable | stable identity for re-seeding/upgrades |
| createdAt / updatedAt | datetime | |
| hlc | text, nullable | sync clock |

### PreDiveChecklistTemplateItems

| Column | Type | Notes |
| ------ | ---- | ----- |
| id | text PK | |
| templateId | text | refs templates, cascade delete |
| section | text, nullable | visual grouping header |
| title | text | |
| notes | text | default '' |
| sortOrder | int | |
| itemType | text enum | `check` / `value` / `equipmentSet` |
| valueLabel | text, nullable | value items only |
| valueUnit | text, nullable | free text: "mV", "bar" |
| valueMin / valueMax | real, nullable | warning thresholds, not hard blocks |
| isRequired | bool | required items must end Done or Flagged (not Skipped) |
| createdAt / updatedAt | datetime | |
| hlc | text, nullable | sync clock (matches the existing `checklist_template_items` pattern: child tables are first-class HLC entities) |

### PreDiveChecklistSessions

| Column | Type | Notes |
| ------ | ---- | ----- |
| id | text PK | |
| diverId | text, nullable | refs Divers |
| templateId | text, nullable | refs templates, SET NULL on delete |
| templateName | text | snapshot; survives template deletion |
| strictOrder | bool | snapshot of the template's flag at session start |
| diveId | text, nullable | refs Dives, SET NULL on delete |
| tripId | text, nullable | refs Trips, SET NULL on delete |
| startedAt | datetime | |
| completedAt | datetime, nullable | |
| status | text enum | `inProgress` / `completed` / `aborted` |
| equipmentSetId | text, nullable | navigation only |
| equipmentSetName | text, nullable | display snapshot |
| notes | text | default '' |
| createdAt / updatedAt | datetime | |
| hlc | text, nullable | |

### PreDiveChecklistSessionItems

| Column | Type | Notes |
| ------ | ---- | ----- |
| id | text PK | |
| sessionId | text | refs sessions, cascade delete |
| section / title / notes / sortOrder / itemType / valueLabel / valueUnit / valueMin / valueMax / isRequired | | full snapshot of the template item at session start |
| state | text enum | `pending` / `done` / `skipped` / `flagged` |
| valueNumber | real, nullable | recorded value |
| valueText | text, nullable | |
| note | text | default ''; per-item diver note |
| completedAt | datetime, nullable | stamped at tap time |
| equipmentId | text, nullable | refs Gear, SET NULL; set for equipment-expanded rows |
| createdAt / updatedAt | datetime | |
| hlc | text, nullable | session items are mutated individually during a run, so each row is a first-class HLC entity |

### Design invariants

- **Snapshot everything at session start.** A completed session renders
  identically forever, even after the template, equipment set, and gear
  items are deleted. Foreign keys are for navigation, never display data.
- **Completed sessions are immutable.** Enforced in the repository layer,
  not just the UI.
- **Dive/trip links use SET NULL, never cascade.** Sessions are audit
  history and outlive the records they reference.

## Domain services

All in `lib/features/pre_dive/`; each unit-testable without UI.

### Session engine (`domain/services/checklist_session_engine.dart`)

Pure functions over a session and its items:

- `nextActionableItem()` — under `strictOrder`, the first `pending` item by
  `sortOrder`; later items are disabled. Without `strictOrder`, all pending
  items are actionable.
- `canComplete()` — no required item still `pending`. Optional items may be
  Skipped; required items must be Done or Flagged.
- Transition validation — rejects any mutation once status is `completed`;
  `aborted` is terminal too.

Flagged items do not block completion (a diver noting "cell 2 sluggish" and
diving anyway is an informed decision the record should capture), but
completing with flags requires an explicit confirmation, and the session
permanently shows a flag-count badge.

### Equipment expansion (`data/services/equipment_item_expander.dart`)

At session start, each `equipmentSet` placeholder item expands into one
session item per gear item in the chosen set (`equipmentId` set, title from
the gear item, grouped under the placeholder's section). Set choice
pre-selects the diver's default set with a manual picker; geofenced
pre-selection via `bestSetFor()` would need current-phone-location plumbing
the start flow does not have, so it is a follow-up, not v1. Service status is computed at expansion time from existing service
records: an overdue item starts pre-`flagged` with an explanatory note; the
diver may clear it to `done`, which is itself a timestamped audit event.
Expanded rows inherit `isRequired` from their placeholder. If no set is
chosen (or the set is empty), the placeholder degrades to a single plain
`check` item so the checklist stays runnable.

### Dive auto-linking (`data/services/checklist_dive_linker.dart`)

On dive creation/import, find unlinked sessions for the same diver whose
`startedAt` falls within a window before the dive's start time (0 to 3
hours before `diveDateTime`, same wall-clock basis the app uses for dive
times). Nearest session wins; strictly one-to-one (dives that already have
a session are skipped). Hooks the same non-interactive dive-creation choke
point as `DiveEquipmentDefaulter.applyDefaultEquipmentIfEmpty`, covering
imports, manual adds, and plan conversions. Manual link/unlink from both
the dive detail page and the session page covers everything outside the
window. Under multi-computer consolidation, the link rides the surviving
primary dive.

### Built-in seeding (`data/services/builtin_checklist_seeder.dart`)

Ships four read-only templates (Clone creates an editable user copy):

1. **BWRAF buddy check** — recreational pre-dive safety check.
2. **GUE EDGE** — team-oriented pre-dive sequence.
3. **Generic CCR build** — `strictOrder` on; includes `value` items (e.g.
   cell millivolts) and required steps.
4. **Gear packing** — with an `equipmentSet` placeholder section.

Seeder upserts by `builtinKey` in `beforeOpen` (restores sync-adopt wipes,
upgrades content across app versions). Export and sync skip `isBuiltIn`
rows — the established dive-types built-in pattern.

## Sync

- Templates and sessions register in `sync_data_serializer.dart` as HLC
  last-write-wins entities; template items and session items serialize as
  child rows under their parents, following the existing checklist tables.
- Deletes go through the standard deletion-log/tombstone path.
- Completed-session immutability keeps the long-lived records conflict-free;
  the realistic conflict surface (an in-progress session) lives on one
  device in one hand.

## UI

Routes (go_router): templates page, sessions list page, session
runner/viewer page. All entry points are thin doors into the same runner
parameterized by (template, optional dive, optional trip).

### Template management

"Pre-Dive Checklists" page under Settings alongside trip checklist
templates. Built-ins show a lock glyph and a Clone action. The editor
extends the existing checklist-editor idiom with: item type picker, value
label/unit/min/max fields, required toggle, section headers, drag reorder,
and a template-level Strict Order switch.

### Session runner

Full-screen page designed for dive-deck conditions: large touch targets,
high contrast, grouped by section, sticky progress indicator ("11 of 16").

- Tap = Done. A secondary affordance per tile (long-press or trailing menu)
  offers Skip / Flag / add note. Skip is not offered on required items —
  the engine's rule (required ends Done or Flagged) is enforced at the
  affordance, not just at completion.
- `value` items show an inline field with the unit label; out-of-range
  values tint amber (warning, not block).
- Under `strictOrder`, the next actionable item is highlighted; later items
  are dimmed and inert.
- Complete button disabled until `canComplete()`; flagged completion runs a
  confirmation dialog. Abort (with confirmation) in the app bar.
- Every tap writes through to the database immediately: crash-safe resume
  for free, and per-item `completedAt` stamped at tap time is honest audit
  evidence.
- Completed/aborted sessions render the same page read-only with per-item
  timestamps.

### Session history

Sessions list: in-progress session pinned with Resume, then history with
status badges, flag counts, and linked-dive chips.

### Entry points

1. **Add-dive sheet** — "Pre-Dive Checklist" tile in
   `add_dive_bottom_sheet.dart`; planned dives get "Run pre-dive checklist"
   in the detail page, pre-linking the session.
2. **Dashboard card** — "Resume — 11 of 16" when in progress, else "Start
   pre-dive check"; hidden until the feature has been used or a user
   template exists.
3. **Tools tile** — leads to the sessions/history page.
4. **Trips** — action on upcoming-trip pages beside the trip to-dos,
   stamping `tripId`.

### Dive detail

Compact "Pre-Dive Check" section on linked dives (template name, completion
time, flag count, tap-through to the read-only session). Unlinked dives
offer "Link a checklist session".

### Conventions

- All strings localized in English plus the 10 other locales.
- Unit-bearing display respects the active diver's unit settings.
- Riverpod provider naming and domain/data separation per project
  conventions; files organized by feature, 200-400 lines typical.

## Edge cases

- App killed mid-session: nothing lost (write-through); session resumes.
- Session never finished: stays `inProgress`; dashboard keeps offering
  Resume; diver can Abort.
- Template deleted mid-session: session unaffected (snapshot).
- Dive or trip deleted: link nulls out; session survives.
- Two back-to-back boat dives: nearest-wins + one-to-one linking assigns
  each session to its own dive.
- Cross-diver isolation: linker and queries filter by `diverId`.

## Testing

TDD throughout, per project rules.

- **Unit**: session engine (strict-order gating, `canComplete()` truth
  table, immutability enforcement), linker (window boundaries,
  nearest-wins, one-to-one, cross-diver), expander (overdue service →
  pre-flagged with note; empty/missing set degradation), seeder idempotence
  (double-run, restore-after-delete, `builtinKey` content upgrade).
- **Repository**: in-memory Drift database, arranged like the existing
  checklist repository tests; locked-session mutation guards.
- **Migration**: v113 upgrade path plus `beforeOpen` backstop on fresh DB.
- **Serializer**: round-trip including the `isBuiltIn` skip.
- **Widget**: runner page (tap-to-done, strict-order dimming, value
  validation, Complete gating, flagged-completion dialog), using the repo's
  known test arrangements (zero theme-animation duration, `ensureVisible`
  before taps).

## Implementation phasing

One spec, landed as reviewable slices:

1. Schema v113 + entities + repositories + built-in seeding + sync
   registration.
2. Session runner UI + session engine + templates management + history.
3. Dive auto-linking + dive detail section + add-dive sheet entry.
4. Equipment expansion + service warnings.
5. Dashboard card, Tools tile, Trips entry point, localization sweep.

## Out of scope (explicitly)

- Buddy/instructor signature capture on sessions (the signatures feature
  exists; integration is a natural follow-up, not v1).
- In-water or post-dive checklists.
- Notifications/reminders to run a checklist.
- Sharing templates between users.
