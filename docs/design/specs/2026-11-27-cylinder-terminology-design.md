# Cylinder terminology, cylinder search and preset management

Discussion #4118, suggestion 1 ("Consistent terminology: Tank, Cylinder and
Bottle"), plus the last open gap of issue #800 (manage tank presets from the
tank editor). Release v1.8.7.

## Intent

A diver reading Submersion in English meets "Tank" on the equipment type, the
dive editor, the planner and the presets, and "Cylinder" on the dive detail
section, the PDF, cylinder passports, the trip cylinder board and the gas
blender. Data-quality messages say "Cylinder 2" in one line and "Tank 2" in
the next. Technical divers also say "bottle". The reporter asked for one word,
"Cylinder", with the other words still finding cylinders in search.

Separately, issue #800 asked that tank presets be manageable from where they
are picked (the tank editor's preset field), and that a built-in preset can be
copied into an editable one. Its other two gaps (link a dive tank to an owned
cylinder, save a tank as a preset) shipped earlier.

## Decisions (the maintainer's)

1. **English says "Cylinder" everywhere** the user reads: the owned equipment
   item, the dive's gas record, presets, the planner, data quality, insights,
   help text, PDFs. ("Rule B" of three offered; the others were "Cylinder for
   owned items, Tank for the dive record" and "rename the equipment type
   only".)
2. **Every language settles on one word**, its standard diving term: es
   botella, fr bloc, he בלון, pt cilindro, de Flasche, nl Fles; it bombola, hu
   palack, ar أسطوانة, zh 气瓶 and ja タンク already use one word and only lose
   stragglers. The words dropped from labels become search words in that
   language.
3. **Search:** a plain word that matches the name of any equipment type, in
   any app language, finds items of that type ("regulator", "Flasche", "BCD").
   Cylinders also answer to extra words per language: English "tank",
   "bottle", "stage", "pony".
4. **Manage presets:** the last entry of the preset dropdown in the tank
   editor opens the presets page.
5. **Duplicate:** a built-in preset on the presets page gets a Duplicate
   action that opens the new-preset form filled from it.
6. **Exports say "Cylinder" too.** The CSV and Excel exports write enums by
   their English Dart `displayName`; those change with the screens, and
   re-importing an older file that says "Tank", "Tank Band" or "Pony Bottle"
   still works.
7. **Hard-coded English strings move into the ARB files.** About 15
   user-visible literals in Dart (planner warnings, the "Tank N" fallback
   name, `DiveField.tankCount`'s labels, a bulk-edit error) become ARB keys,
   translated into every language, so they follow the same rule.

## Goals

- One word per language for the cylinder concept in every user-visible string.
- Typing the dropped words, or any type's name, in the equipment search or
  Global Search finds the matching items.
- Preset management one tap away from the preset field, without losing the
  dive being edited.
- Built-in presets can seed custom ones.

## Non-goals

- No ARB key renames. Keys such as `diveLog_edit_overline_tanks` and
  `enum_equipmentType_tank` keep their names; only values change. Renaming
  keys would churn every locale file and generated Dart for no visible gain.
- No code identifier, table, column, enum value or route renames
  (`EquipmentType.tank`, `dive_tanks`, `/tank-presets` stay).
- No change to the query language's typed syntax: field keys (`tanks`) and enum
  values (`type = tank`) are code names, so saved searches keep working. (See
  "Builder calls" for the typed alias.)
- No change to import or export file structure (columns, tags). Exported
  English values do change with the wording (decision 6), and the importers
  keep reading the old values.
- Dive search ("tank" finding dives that carry a cylinder) is out of scope.
- The planner's "Saved cylinders" (cylinder configurations) flow is unchanged
  apart from wording.

## Anti-goals

- A saved search, sync payload, export or import that behaves differently
  after the rename.
- Wording that names a real device's screen or event differently from the
  device: a replica of a computer's display or a computer's own event name
  keeps the device's word (see exceptions).

## Terminology change

### English

Every value in `app_en.arb` that uses "tank" for the cylinder concept says
"cylinder" instead, with grammar and capitalisation kept ("Add Tank" becomes
"Add Cylinder", "per-tank SAC" becomes "per-cylinder SAC", "Tank {number}"
becomes "Cylinder {number}", "Tank Presets" becomes "Cylinder Presets").
"Bottle" for the cylinder concept also becomes "cylinder" ("Bottle number" on
the trip board becomes "Cylinder number"). About 170 values.

Proposed wording for the special cases (part of this design's approval):

| Key | Today | Proposed |
| --- | --- | --- |
| `enum_equipmentType_tank` | Tank | Cylinder |
| `enum_equipmentType_tankBand` | Tank Band | Cylinder Band |
| `enum_tankRole_pony` | Pony Bottle | Pony |
| `tank_al30Stage_description` and kin | ... stage tank | ... stage cylinder |
| `trips_cylinders_bottle` | Bottle {label} | Cylinder {label} |

Exceptions that keep "tank" (device replicas and product names):

- `enum_profileEvent_suunto_tankPressure*`: Suunto's own event names.
- `media_perdixOverlay_labelTank`: the label on the Perdix screen replica.
- `enum_tankRole_hydrotank` and `diveLog_cylinders_hydrotankNote`: "Hydrotank"
  is the Avelo product name.
- `species_bottlenose_dolphin_name` (not a cylinder).

The English Dart `displayName`s change the same way: `EquipmentType.tank`
('Tank' to 'Cylinder'), `EquipmentType.tankBand` ('Tank Band' to 'Cylinder
Band') and `TankRole.pony` ('Pony Bottle' to 'Pony'). They feed the CSV and
Excel exports (`csv_equipment_writer.dart`, `excel_export_service.dart`, the
maintenance log rows). `enumByDisplayName` already falls back to the code name,
so an old "Tank" still reads back; "Tank Band" and "Pony Bottle" get explicit
aliases so an older export re-imports unchanged.

### Hard-coded English strings

The user-visible English literals in Dart that name the cylinder (found so far:
`plan_engine.dart` warnings around lines 2360 to 2524, `plan_calculator_service.dart`
427 and 438, the `'Tank N'` fallback name in the profile markers, the dive
repository and the gas switch sitting, `DiveField.tankCount`'s 'Tank Count' and
'Tanks', a bulk-edit error) move into ARB keys translated into all 11
languages. Where the literal is built in a domain or data layer with no
`BuildContext`, it carries a code and its arguments and the presentation layer
localizes it, the way the codebase already handles domain messages; the plan
picks the pattern each site uses.

The `@key` descriptions for translators are updated where they define the word.

### Other languages

Each locale's ARB gets the same treatment towards its one word (decision 2).
Strings in those files that use the dropped word for the cylinder concept are
rewritten with the language's word, grammar adjusted. Values that use the
dropped word for something else (a generic container, a product name) stay.

### Guard

A test fails when an English ARB value uses `tank` or `bottle` as a word for
the cylinder concept, with the exceptions above in an explicit allowlist, so
the wording does not drift back. This follows the German SAC guard
(`test/l10n/german_sac_terminology_test.dart`).

## Search

Equipment search goes through `equipmentQueryEntity`, which the equipment
list's search field and Global Search both read. Today its plain-word match
covers name, brand, model, serial and tag names.

A new `TextSearchExpansion` on `equipmentQueryEntity` (the mechanism dive types
and species already use for translated labels) adds: the item's `type` is one
of the equipment types whose words contain the searched term. A type's words
are, folded with `foldForSearch`:

- its label in every app language (`enum_equipmentType_*`), and
- for cylinders (and cylinder bands), the extra search words of every app
  language, from one new ARB key per type with search words, a comma-separated
  list. English cylinder words: `tank, bottle, stage, pony`. English cylinder
  band words: `tank band, cam band`.

Matching every language, not just the active one, keeps the compiler
locale-free and a saved search stable across devices, as #2884 decided for dive
types. Matching is "contains", like the other text matches.

## Manage presets from the tank editor (#800 gap 2)

`TankPresetDropdown` gets a last entry, below the built-in presets and set
apart by a divider: a settings icon and "Manage presets". Choosing it does not
change the field's selection; it pushes the presets page (`/tank-presets`) on
top of the current route. The dive editor stays mounted underneath, so the
in-progress edit survives. The dropdown already watches `tankPresetsProvider`,
so presets added, edited or hidden there show on return. The dropdown is shared
with the cylinder configuration editor, which gets the entry too.

## Duplicate a built-in preset (#800)

On the presets page, each built-in preset's row gets a Duplicate icon button
(copy icon, tooltip "Duplicate") between the star and the show switch. It opens
the new-preset form filled with the built-in's volume, working pressure,
material, rated capacity and description, named "<localized name> (copy)".
Saving creates a custom preset; the built-in is untouched. Custom presets do not
get Duplicate in this change (they can already be edited).

## Approaches considered

- **Naming rule:** B (Cylinder everywhere) chosen over A (Cylinder for owned,
  Tank for the dive record: about 60 strings, keeps "Tank" for US divers) and
  C (equipment type only: smallest, leaves the mixes).
- **Search:** a `TextSearchExpansion` (chosen; precedent in dive types and
  species, locale-free, no schema change) over storing search words in the
  database (needs a migration and sync for static data) or matching only the
  active language (a saved search would differ by device).
- **Manage presets placement:** last dropdown entry (chosen) over an icon in
  every cylinder card header (crowds a header that already has three actions)
  or a link on the Cylinders section heading (further from the field).

## Builder calls (left to the plan)

- Exact wording of each of the ~170 English strings, following the rule above.
- Whether the typed query accepts `type = cylinder` as an alias for `tank`
  (would print back as `tank`); allowed but not required.
- How the guard test tells a cylinder use from an allowed one (allowlist of
  keys is fine).
- Translations: one consistent word per language, rewritten by hand string by
  string, not by blind find-and-replace.
- Search words for languages other than English: each language's dropped
  words (es tanque, fr bouteille, he מיכל, pt garrafa, de/nl tank) plus its own
  usual synonyms.
- A duplicated preset's name may collide with an existing custom preset; the
  form's existing name handling applies, nothing new.
- The Manage entry appears wherever `TankPresetDropdown` is used, nowhere
  else.
- User guides under `docs/user/` that name the old labels are updated in the
  same change.

## Testing

- The search expansion: unit tests for the word-to-type mapping (English
  "tank", "bottle", "cylinder"; German "Flasche"; a type label like
  "regulator"; no match for an unrelated word) and a compiler or repository
  test that a cylinder named "AL80" is found by "tank".
- `TankPresetDropdown`: the Manage entry pushes the presets page and leaves the
  selection unchanged.
- Presets page: Duplicate opens the form prefilled and saving creates a custom
  preset.
- The terminology guard test.
- Import: an equipment CSV with type "Tank" or "Tank Band" and a tank role
  "Pony Bottle" still reads back to the same enums.
- The moved planner and profile strings render through the localized getters.
- Existing widget tests that find text by English string are updated.

## Screenshots

Before and after: equipment list and type picker, dive editor cylinder card,
dive detail cylinders section, presets page (with Duplicate), the preset
dropdown open with Manage presets, equipment search for "tank". Phone and
desktop width for the dropdown; light only (no colour change).
