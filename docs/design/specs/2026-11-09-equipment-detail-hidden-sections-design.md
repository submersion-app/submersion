# Equipment detail: sections a diver can hide

Issue: #4185 (closes).

## Why

The equipment detail page shows up to 17 sections. Several are always shown
with an empty state (Passport, Service clocks, Exposure, Observations,
Components, Service history, Documents), so simple gear like a mask or a snorkel
gets a long page of things the diver never uses. The person who filed #4185
asked for two things: switch off a section they never use anywhere ("I do not
use the passport"), and switch off sections for particular kinds of gear ("for
the mask or the snorkel, I do not care about reviews, components").

## Goals

- A diver can hide a section for all gear, and hide or show it for one
  equipment type, overriding the all-gear choice.
- They can do it from the page that bothers them, and review every choice they
  have made in one place in Settings.
- Hiding never hides a safety signal, and never makes data look lost.

## Non-goals

- Reordering sections.
- Per-item visibility (one particular mask different from other masks).
- Built-in defaults for simple gear. Nothing is hidden until the diver hides it,
  and existing data is untouched.
- Changing the edit page.

## Anti-goals

- A service that is due going unnoticed because its section is hidden.
- A diver thinking their documents or history are gone.
- Two editors (sheet and Settings) with different rules about what can be
  hidden.

## Current state (for orientation)

`lib/features/equipment/presentation/pages/equipment_detail_page.dart` builds
the body around :222-320. Today a section shows or hides by type (computer,
transmitter, tank, rebreather, child host types, colour), by wishlist status,
or by whether it has data (condition findings and trend, legacy documents,
notes, multi-diver history). No per-type rule is configurable by the diver.

## Design

### Sections

A new enum, stable string names (they are stored and synced):

| Id | What it covers |
| --- | --- |
| `location` | `EquipmentLocationCard` |
| `passport` | `PassportEntryCard` and `TwinSetCard` (tanks), `GearPassportEntryCard` (others) |
| `serviceClocks` | `ServiceClocksCard` |
| `exposure` | `ExposureCard` |
| `condition` | `ConditionFindingsCard` and every `ConditionTrendCard` |
| `fittedParts` | `ChildrenCard` |
| `observations` | `ObservationsCard` |
| `components` | `ComponentsCard` |
| `unitConfigurations` | `UnitConfigurationsCard` |
| `serviceHistory` | `ServiceHistorySection` |
| `documents` | `DocumentsSection` and the legacy `EquipmentDocumentsSection` |
| `history` | `EquipmentHistoryCard` |

Never hideable: the header card (including the service-due banner), the Details
card, `DiveComputerSection`, `TransmitterSection`, and the Notes card. (my call:
the computer and transmitter sections are what those items are for; notes are
the diver's own words.)

### Rule

effective(type, section) = types[type][section], else all[section], else shown.

The diver's choice can only hide. It never forces a section the page would not
show anyway (a mask never gets Unit configurations, a wishlist item never gets
Service clocks). The existing type, wishlist and has-data rules apply on top.

### Storage

- New nullable TEXT column on `diver_settings`, JSON:
  `{"all": {"passport": false}, "types": {"mask": {"components": false, "location": true}}}`.
  A missing key means "inherit". `true` in a type entry shows a section that
  all-gear hides. Null column means nothing customised.
- Unknown section ids and unknown type names are kept on read and written back
  untouched, so a newer build's choices survive a round trip through an older
  one.
- A per-diver setting synced like other diver settings. Follow the
  `firstDayOfWeek` path (#4234, commit 869017751fb): schema bump, migration
  helper, ladder rung, before-open backstop, serializer default for older
  payloads, repository mapping, `AppSettings` field with `copyWith` and setter,
  select provider, conflict catalogue entry, agent SQL column notes, demo mode
  and `test/helpers/mock_providers.dart`.
- No backfill. Fresh and existing databases both start with null.

### The sheet ("Customise sections")

- Opened from the detail page's overflow menu, and from Settings (below).
- Top: a segmented choice, "<Type> only" and "All gear". From the detail page it
  starts on "<Type> only". From Settings it is locked to the row's scope.
- One switch per section, showing the effective value in the chosen scope.
  - In type scope, only sections that can apply to that type are listed (no
    Unit configurations for a mask, Fitted parts only for child host types,
    History only when the diver has more than one diver profile, and so on).
    Flipping a switch writes an explicit value for that type. A switch whose
    type value differs from all gear carries a small "Changed for <type>" note.
  - In all-gear scope, every hideable section is listed.
- A caption row says the header and details are always shown.
- In type scope, a "Reset to All gear" action clears that type's entry.
- Changes apply as they are made (no Save button), matching other settings
  sheets. (builder may follow whatever the nearest existing settings sheet does)

### The Settings page ("Detail sections")

- Lives with the other equipment settings. (builder finds the exact spot)
- Rows:
  - "All gear", with a summary of what it hides ("Passport hidden", or
    "Nothing hidden").
  - One row per type that has an entry, in canonical type order, with a summary
    ("Passport, Components, Service clocks hidden"; "Location shown" when the
    entry only shows things).
  - "Add a type...", which picks from types without an entry and opens the
    sheet locked to that type. Nothing is written until a switch changes.
- Tapping a row opens the sheet locked to that scope. Each type row has a Reset
  action that removes its entry.

### Hidden, not lost

- When at least one section that would otherwise appear on this page is hidden,
  the page ends with a line: "3 sections hidden · Show". Show reveals them for
  this visit only. The line also offers "Customise". (my call: shown whenever
  something is hidden, not only when the hidden section has data; it is simpler
  and never misleads.)
- A hidden Service clocks section still drives the header's service banner, the
  list's service badge, the service-due filter and reminders. Only the card goes.
- A hidden Condition section does not change the condition badge in the list.
- Safety exception (my call, from the anti-goal "a safety signal hidden"): while
  the item has an active finding of caution or significant severity, the
  `ConditionFindingsCard` shows even if Condition is hidden, with a short note
  "Shown because of an active finding". It is not counted in the hidden line.
  The trend cards (including the rebreather's scrubber minutes) stay hidden.
  The sheet's Condition switch carries a caption saying active findings still
  show.

## Testing

- Pure resolution (inherit, override, show-over-hide, unknown keys preserved,
  only-hide rule) unit tested.
- JSON parse and write round trip, including malformed JSON falling back to
  "nothing customised" without crashing.
- Widget tests: hiding from the sheet removes the card, type scope overrides all
  gear, reset, the hidden line and its Show, banner still shown with Service
  clocks hidden, Settings page rows and summaries.
- Migration test, repository round trip, sync serializer default.

## Left to the builder

- Enum and provider names, file layout.
- Exact wording beyond the strings above (all go through ARB).
- Whether the hidden line reveals in place or scrolls to the first revealed
  section.

## Delivery

One PR, second of three. Branch from the foldable groups PR's head and target
main, so the schema version and ladder rung follow that PR's; rebase and
renumber if main moves before it merges. (my call) Description:
`Closes #4185`. Screenshots of the sheet, the detail page with hidden sections
and the hidden line, and the Settings page, light and dark.
