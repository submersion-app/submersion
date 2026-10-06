# Hide built-in entries from the pickers

Issue: #401 (Editable or Removable dive types and Tank presets)

## Problem

Settings > Manage lists several catalogs that ship with built-in entries. A
diver can delete their own custom entries but cannot remove or hide the
built-in ones, so every picker offers entries the diver never uses. The issue
asks for this mainly as decluttering.

Tank presets already solved this for one catalog (issue #2305, PR #2315): each
built-in preset has a switch that hides it from the pickers, stored per diver
in `diver_settings.hidden_tank_preset_ids`. This design brings the same
behaviour to every other catalog with built-in entries that a diver picks
from, and labels the switch column on every page.

## Scope

In scope, each with a "Show" switch on its built-in rows:

| Catalog | Built-ins | Manage page |
| --- | --- | --- |
| Dive types | seeded, shared | `lib/features/dive_types/presentation/pages/dive_types_page.dart` |
| Dive roles | 9, shared | `lib/features/dive_roles/presentation/pages/dive_roles_page.dart` |
| Site types | 16, shared | `lib/features/site_types/presentation/pages/site_types_page.dart` |
| Service types | 12, shared | `lib/features/equipment/presentation/pages/service_kind_list_page.dart` |
| Pre-dive checklist templates | 4, shared | `lib/features/pre_dive/presentation/pages/pre_dive_templates_page.dart` |

Tank presets keep their existing storage and switches; their page only gains
the column label.

Out of scope:

- Species (685 global entries, built-ins already editable; a switch per row
  does not fit that catalog).
- Column layout presets (a single built-in "Standard" preset).
- Gas templates and course templates (code constants with no Manage page).
- Editing or deleting built-in entries. Hiding is the declutter mechanism.

## Data and domain

### Storage

One new nullable column, `diver_settings.hidden_built_in_ids` (TEXT, JSON),
added by a column-only rung v269 (renumbered as other rungs landed while this was open; 268 is held by #3043) in
`lib/core/database/migrations/ladder/rungs_v231_onward.dart`. No backfill:
null reads back as "nothing hidden". The column syncs with the rest of the
settings row, as `hidden_tank_preset_ids` does. `hidden_tank_preset_ids` is
left untouched.

The value is a JSON object mapping a catalog key to a list of ids:

```json
{"diveTypes":["night"],"diveRoles":["solo"],"siteTypes":["lake"],
 "serviceKinds":["vip"],"preDiveTemplates":["builtin-predive-ccr-build"]}
```

### AppSettings

`AppSettings.hiddenBuiltInIds` is a `Map<String, Set<String>>` keyed by the
catalog's string key, not by an enum. A key written by a newer app version and
delivered by sync therefore survives a save by an older version instead of
being dropped.

- `BuiltInCatalog` enum: `diveTypes`, `diveRoles`, `siteTypes`,
  `serviceKinds`, `preDiveTemplates`, each with a stable `key` string.
- Read helper: `settings.hiddenBuiltIns(BuiltInCatalog kind)` returns the
  set for that catalog, empty when absent.
- Setter: `SettingsNotifier.setBuiltInHidden(BuiltInCatalog kind, String id,
  bool hidden)` adds or removes the id and saves. Removing the last id of a
  catalog removes its key.

Encoding writes keys and ids in sorted order so equal contents encode equal.
Decoding treats null, empty, malformed JSON, and wrongly typed values as
"nothing hidden" and never throws.

### Visibility helper

A pure generic function, the generalized form of `visibleTankPresets` and
`withKeptTankPresets`:

```dart
List<T> visibleBuiltIns<T>(
  List<T> all,
  Set<String> hidden, {
  required bool Function(T) isBuiltIn,
  required String Function(T) idOf,
  Iterable<String?> keep = const [],
})
```

- Drops built-in entries whose id is in `hidden`.
- Never drops a custom entry, even one that shares an id with a built-in.
- Keeps any entry whose id is in `keep` (the values currently selected), so a
  record that uses a hidden entry still shows it.
- Preserves the input order. Returns `all` itself when `hidden` is empty.

### Providers

One provider family, `hiddenBuiltInIdsProvider(BuiltInCatalog)`, yields the
active diver's hidden set for one catalog. It watches only that catalog's
slice of settings through `select` with a sorted, joined key (as
`tankPresetsProvider` does), so toggling one catalog does not rebuild the
others' pickers.

Each picker reads its full list plus that hidden set and applies
`visibleBuiltIns` itself, because most pickers must keep a selected value and
only the picker knows it. Where the picker is a reusable widget
(`DiveTypeMultiSelectField`, `TypeTagsSection`, `showDiveRoleSelector`,
`LegacyBuddyReviewRow`), the filtering lives inside it, behind a hidden-ids
parameter, so its own widget tests cover it.

The existing full-list providers do not change. Labels, exports, UDDF import
and export, import vocabulary matching, list filters, insights, connections
search, statistics, and the Manage pages keep reading every entry.

## UI

### Labeled switch column

Two shared widgets in `lib/shared/widgets/`:

- `BuiltInShowColumnHeader`: the built-in section header row with the section
  title on the left and a right-aligned "Show" label positioned above the
  switch column.
- `BuiltInShowSwitch`: the per-row switch with a "Show in pickers" tooltip and
  a stable key (`built-in-show-<catalog>-<id>`).

A hidden row stays listed. Only its text and leading icon are dimmed with
`disabledColor`; the tile is not disabled, so its switch stays usable. This
matches the Tank Presets page.

### Manage pages

| Page | Change |
| --- | --- |
| Tank Presets | "Show" label above the existing switch column. Switches unchanged. |
| Dive Types | Switch on built-in rows, after the short-name badge preview. Recreational is switchable. |
| Dive Roles | Switch on built-in rows. Buddy is switchable. |
| Site Types | Switch on built-in rows, next to the site count. |
| Service Types | Switch in the trailing slot of built-in rows, hidden in selection mode like the custom rows' delete button. The leading lock icon stays. |
| Pre-dive checklist templates | Switch before the View/Clone menu. The "Built-in" chip stays. |

Custom rows get no switch.

### Pickers narrowed

| Catalog | Picker | Keeps selected |
| --- | --- | --- |
| Dive types | `DiveTypeMultiSelectField` (single and bulk edit) | yes |
| Dive roles | `showDiveRoleSelector` (buddy chip, Me chip, add buddy, bulk my-role, bulk buddy role) | yes |
| Dive roles | Legacy buddy review dropdown | yes |
| Site types | Type tag chips in the site edit page | yes |
| Service types | Add-clock sheet | n/a |
| Service types | Service record type dropdown | yes |
| Pre-dive templates | Start session dropdown | n/a |

### Strings

New strings in every ARB locale: the "Show" column label and a generic "Show
in pickers" tooltip. Tank Presets keeps its existing tooltip string.

## Behaviour rules

1. Defaults stay pre-filled. New dives still start as Recreational and new
   buddy entries as Buddy even when hidden; the picker shows the hidden
   default because it is the selected value.
2. Hidden service types stop auto-attaching to newly created equipment, using
   the hidden set of the diver who owns the equipment. Clocks already on
   existing equipment are untouched. Cylinder passport adoption still creates
   its O2-clean clock, since that is a deliberate action.
3. Hiding narrows pickers only (see Providers).
4. Only built-in entries get the switch. A custom entry is never hidden.
5. Hidden sets are per diver and follow the active diver profile.
6. Ids in a hidden set that no longer exist are ignored. Unknown catalog keys
   are preserved on save.

## Testing

- Unit: `visibleBuiltIns` (hide, custom never hidden, keep selected, order
  preserved, identity when nothing hidden); encode and decode, including
  unknown keys, sorted output, and malformed input.
- Data: v269 migration test (column present, null reads as empty); diver
  settings repository round trip; `setBuiltInHidden` on the real notifier.
- Providers: `hiddenBuiltInIdsProvider` yields only its own catalog's set.
- Widgets: each Manage page shows the "Show" header and switches on built-in
  rows only, and toggling hides and dims the row. Each picker excludes hidden
  entries and keeps a selected one.
- Service auto-attach: new equipment skips hidden kinds; existing clocks are
  unaffected.
- Test helpers: fake settings notifiers implement `setBuiltInHidden`.
- `test/architecture/` passes with the new `lib/` files.
