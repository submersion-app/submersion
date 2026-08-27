# Certification "Level" dropdown: rename to Certification, make Name optional

Date: 2026-08-09
Status: Approved

## Problem

A user reported:

> The Certification Level drop-down shows a list of course names which is
> redundant with the Certification Name field. Not really levels at all.

Both halves of the report are accurate.

**The values are not levels.** `CertificationLevel` (`lib/core/constants/enums.dart:167`)
mixes three different kinds of thing in one enum: progression grades
(`openWater`, `rescue`, `diveMaster`, `instructor`), agency-specific grades
(`bsacSportsDiver`, `cmas3StarDiver`, `gueTech1`), and pure specialties
(`nitrox`, `wreck`, `sidemount`, `cavern`). "Sidemount" is not a level of
anything. `CertificationLevelCatalog.levelsFor()`
(`lib/core/constants/certification_levels.dart:137`) then concatenates the
agency ladder and the specialty set into one flat dropdown, so the two
concepts are presented as a single ranked list.

**The redundancy is manufactured by the form.** The edit page derives the
Name field from Agency + Level:

```dart
// lib/features/certifications/presentation/pages/certification_edit_page.dart:129
String _generateDefaultName() {
  if (_level == null) return '';
  return '${_agency.displayName} : ${_level!.displayName}';
}
```

Choosing "Open Water" writes `"PADI : Open Water"` into Name. Downstream, the
detail page (`certification_detail_page.dart:485,492`), the e-card
(`certification_ecard.dart:160`) and the shareable card renderer
(`certification_card_renderer.dart:91,385`) each render both strings, stacked:

```
Type:  PADI : Open Water
Level: Open Water
```

A related existing wart: `certification_list_content.dart:540` builds its
accessibility label as `"${agency.displayName} ${cert.name}"`, which a screen
reader speaks as "PADI PADI : Open Water".

## Decisions

Four decisions were taken during design, each chosen over stated alternatives.

1. **The dropdown remains the structured value; it is renamed.** It keeps
   driving ranking, e-cards, filtering and export. The free-text Name becomes
   optional. Rejected: deriving a true tier enum (Entry / Advanced /
   Leadership / Technical / Specialty) alongside the course catalog; and
   deleting the dropdown in favour of free text, which would strip
   `primaryCertification()` of its ranking input.

2. **Existing rows are never rewritten in bulk.** Certs already stored as
   `"PADI : Open Water"` stop showing the duplicate because the *display layer*
   recognises a derived name and suppresses it. Rejected: a one-time
   startup-maintenance migration, which would rewrite untouched rows, bump
   `updatedAt`, and push an edit to every synced device.

3. **Labels are "Certification" (dropdown) and "Name on card" (free text).**
   Rejected: "Course", which collides with the first-class Courses feature
   (`lib/features/courses/`, issue #601) where a course is an *in-progress*
   training record with requirements and linked dives — a different concept
   from a completed card. Also rejected: "Rating" (jargon) and "Qualification"
   (BSAC/UK-specific register).

4. **The dropdown is grouped with non-selectable section headers**
   (Progression / Specialties / Other), which is what makes "Sidemount is not
   a rank" legible in the UI. Rejected: leaving the list flat; and replacing
   the dropdown with a searchable modal picker, which is a new shared widget
   and a larger test surface than this fix warrants.

## Non-goals

- No new tier/rank enum. Cross-agency ranking keeps its current best-effort
  behaviour (see the #553 design's non-goals).
- No change to how `primaryCertification()` ranks certs.
- No renaming of the `CertificationLevel` Dart type, the `level` column, or
  any enum value name.
- No bulk data migration.

## Design

### 1. Data model — no schema change

`CertificationLevel`, the `level` column, and `Certifications.name` are all
unchanged. `name` stays non-nullable `text()` (`database.dart:1780`);
"optional" is modelled as the **empty string**, not NULL.

This deliberately avoids: a `schemaVersion` bump and migration step, the sync
`toCompanion` clear-field path for a newly-nullable column, and any change to
UDDF import/export (`uddf_import_parsers.dart:544,667`,
`uddf_entity_importer.dart:580,685`) or the sync field maps
(`certification_field.dart:179`, `buddy_field.dart:142`), all of which
round-trip `level` as enum-name text.

The `CertificationLevel` enum declaration gains a doc comment recording that
the UI presents it as "Certification", and that the type name is retained
because renaming it would churn sync-critical code for no user-visible gain.

### 2. New unit: `lib/features/certifications/domain/certification_title.dart`

A single title authority, with no Flutter dependency so it is unit-testable:

```dart
/// "PADI Open Water"; the agency alone when [level] is null.
String derivedCertificationTitle(CertificationAgency agency, CertificationLevel? level);

/// True when the stored name carries no information beyond the derivation.
bool hasDerivedName(Certification cert);

/// The string to show as the certification's title anywhere one is needed.
String certificationTitle(Certification cert);

/// The custom name, or null when there is nothing extra to show.
String? customNameOrNull(Certification cert);

/// The level, but only when the title is a custom name — otherwise the
/// title already contains it. Surfaces that draw a title with a smaller
/// line beneath it (e-card, card renderer, PDF) use this for that line.
String? certificationSubtitle(Certification cert);
```

`hasDerivedName` normalises case and collapses whitespace, then compares
against every derivation format the app has ever produced:

| Format | Origin |
| --- | --- |
| `"PADI : Open Water"` | current `_generateDefaultName`, spaced colon — what is in users' databases today |
| `"PADI: Open Water"` | tolerated variant |
| `"PADI Open Water"` | the new derived form |

An empty or whitespace-only name also counts as derived. Recognising the
legacy spaced-colon form is what allows existing certs to stop showing the
duplicate with zero writes; it is the single most important behaviour in this
change.

`certificationTitle` returns `customNameOrNull(cert) ?? derivedCertificationTitle(...)`.
It becomes load-bearing rather than cosmetic, because the list, picker,
summary and wallet card currently render `cert.name` alone as their title
(`certification_list_content.dart:549`, `certification_picker.dart:206`,
`certification_summary_widget.dart:223`, `certification_wallet_card.dart:281`)
and would render blank rows once Name may be empty.

### 3. Catalog: expose the ladder/specialty split

`CertificationLevelCatalog` gains:

```dart
/// Specialties offered for [agency] that are not already on its ladder.
static List<CertificationLevel> specialtiesFor(CertificationAgency? agency);
```

`ladderFor` and `levelsFor` keep their current behaviour and signatures, so
`test/core/constants/certification_levels_test.dart` and the agency-switch
reset check in the edit page continue to work unchanged. `levelsFor` is
refactored to be expressed in terms of `ladderFor` + `specialtiesFor` so the
grouped dropdown and the reset check cannot drift apart.

### 4. Edit form (`certification_edit_page.dart`)

Field order becomes **Agency → Certification → Name on card → Card number**.

Removed entirely: `_generateDefaultName`, `_updateNameIfDefault`,
`_onNameChanged`, and the `_isNameManuallyEdited` flag, along with the
`_nameController.addListener(_onNameChanged)` registration and its matching
`removeListener` in `dispose`.

The Certification dropdown renders grouped, non-selectable headers using
`DropdownMenuItem(enabled: false)`:

```
-- Progression --      ladderFor(agency)
-- Specialties --      specialtiesFor(agency)
                       CertificationLevel.other   (no header)
```

`CertificationLevel.other` trails the Specialties group **without** a header
of its own. A header reading "Other" directly above an item reading "Other"
is noise on screen and makes `find.text('Other')` ambiguous in tests, so the
third header from the original sketch is dropped and the
`certifications_edit_group_other` key is not created.

The "Not specified" entry stays as the leading selectable `null` item, above
the first header. The `ensure:` escape hatch for a stored value from another
agency's catalog is preserved: such a value is appended to the Specialties
group so existing data always renders.

"Name on card" is plain optional text. Its `hintText` is the live derived
title (recomputed as Agency or Certification changes), so the user sees
exactly what leaving it blank produces; a static `helperText` reading
"Optional" marks it as not required.

**Validation.** Name is currently required. It cannot simply become optional,
or a cert with neither a certification nor a name has no identity. The new
rule is: **at least one of {Certification selected, Name on card non-empty}**,
reported on the Name field. `validation_nameRequired` is replaced by
`validation_certificationOrNameRequired`.

**Prefill and save.** When editing a cert whose stored name is derived, Name
on card shows empty (with the derived hint). Saving then persists `""`,
replacing the stored `"PADI : Open Water"`. This is an accepted consequence:
it is a write the user initiated by saving that cert, not a background
migration. Certs the user never edits are never touched.

### 5. Display surfaces

`certificationTitle()` replaces bare `cert.name` in: the list
(`certification_list_content.dart:540,549`, including the doubled-agency
accessibility label), picker (`certification_picker.dart:39,189,190,206`),
summary (`certification_summary_widget.dart:223`), wallet card
(`certification_wallet_card.dart:281`), e-card (`certification_ecard.dart`),
share sheet, card renderer (`certification_card_renderer.dart`) and the PDF
templates (`pdf_shared_components.dart`, `pdf_template_professional.dart`).

On the detail page (`certification_detail_page.dart:484-497`):

- the `Type` row takes `customNameOrNull()` and is **omitted when null**;
- the `Level` row is relabelled `Certification`.

Result: `Type: PADI : Open Water` + `Level: Open Water` collapses to a single
`Certification: Open Water`. The `Certification` row keeps its existing
`if (certification.level != null)` guard, so the three combinations behave as:

| Stored | Rows shown |
| --- | --- |
| derived name + level | `Certification: Open Water` |
| custom name + level | `Type: Bali OW w/ Made` and `Certification: Open Water` |
| custom name, no level | `Type: Bali OW w/ Made` only |

The fourth combination — no name and no level — is prevented by the §4
validation rule.

The buddy surfaces (`buddy_edit_page.dart:476`,
`buddy_detail_page.dart:509`) already do `cert.level?.displayName ?? cert.name`
and so never doubled up; they switch to `certificationTitle()` for
consistency.

The entity-table column label for `CertificationField.level`
(`certification_providers.dart:308,344`) is renamed to match the new field
label.

### 6. l10n

Eleven locales: `ar de en es fr he hu it nl pt zh`.

Added:

| Key | English |
| --- | --- |
| `certifications_edit_label_certification` | Certification |
| `certifications_edit_certification_notSpecified` | Not specified |
| `certifications_edit_label_nameOnCard` | Name on card |
| `certifications_edit_helper_nameOnCard` | Optional |
| `certifications_edit_group_progression` | Progression |
| `certifications_edit_group_specialties` | Specialties |
| `certifications_edit_validation_certificationOrNameRequired` | Choose a certification or enter a name |
| `certifications_detail_label_certification` | Certification |

Removed: `certifications_edit_label_level`,
`certifications_edit_level_notSpecified`,
`certifications_edit_validation_nameRequired`,
`certifications_detail_label_level`,
`certifications_edit_label_certificationName` (superseded by
`label_nameOnCard`), and `certifications_edit_hint_certificationName` (the
hint is now the runtime-derived title, not a translated string).

Note the derived title itself is **not** an l10n key: it is built at runtime
from `agency.displayName` and `level.displayName`, both of which are already
English-only enum display strings today. Localising those is out of scope
here.

Every added key is translated in all eleven locales in the same change; none
are left as English placeholders.

### 7. Testing

Tests are written before the implementation they cover.

**`test/features/certifications/domain/certification_title_test.dart`** (the
critical one):

- legacy `"PADI : Open Water"` recognised as derived
- `"PADI: Open Water"` and `"PADI Open Water"` recognised as derived
- case and surrounding-whitespace insensitivity
- empty and whitespace-only name treated as derived
- a genuinely custom name (`"Bali OW w/ Made"`) preserved and returned by
  `customNameOrNull`
- a custom name that coincidentally equals the derivation is treated as
  derived (accepted: it renders identically either way)
- `level == null` yields the agency alone
- `certificationTitle` never returns an empty string

**`test/core/constants/certification_levels_test.dart`** (extended):

- `specialtiesFor` excludes anything already on the agency's ladder
- `ladderFor + specialtiesFor + other` reproduces `levelsFor` exactly, for
  every agency and for a null agency

**Edit-page widget tests:**

- the three group headers render and are non-selectable
- a stored level from another agency appears under Specialties (the `ensure:`
  path)
- saving with a certification chosen and Name blank succeeds
- saving with both blank fails with
  `validation_certificationOrNameRequired`
- saving with Name filled and no certification succeeds
- editing a cert stored as `"PADI : Open Water"` shows Name on card empty

**Detail-page widget test:**

- a derived-name cert renders exactly one identifying row
  (`Certification: Open Water`) and no `Type` row
- a custom-name cert renders both rows

## Implementation notes (2026-08-09)

Three things diverged from the design above while building it. Each is
recorded here so the document matches what shipped.

**1. The dropdown is keyed by `CertificationOption`, not `CertificationLevel`.**
The design assumed group headers could be `DropdownMenuItem(enabled: false)`
with a null value, on the belief that Flutter skips its selected-value assert
when the value is null. It does not. `DropdownButton._updateSelectedIndex`
(`dropdown.dart:1427`) short-circuits only when *no enabled item* matches, and
a selectable "Not specified" entry is enabled with a null value -- so the
assert on the next line runs and counts all three null-valued items. At most
one item in the list may carry any given value, null included. Since
`CertificationLevel` has no spare values to use as header sentinels, a small
wrapper type (`lib/features/certifications/presentation/widgets/certification_option.dart`)
gives every row a distinct value.

**2. The derived title carries no agency prefix.** The design specified
"PADI Open Water". Implementing the PDF and picker surfaces showed that both
render the agency on its own line directly beneath the title
(`pdf_shared_components.dart`, `certification_picker.dart`), as do the detail
page's Agency row and the list's Agency column -- so an agency-prefixed title
would have replaced one duplication with another. `derivedCertificationTitle`
is now `level?.displayName ?? agency.displayName`, matching the pattern the
buddy pages already used. `hasDerivedName` is unaffected and still matches the
legacy `"PADI : Open Water"`, which is the part that matters for existing rows.

**3. Two pre-existing table bugs were fixed in passing.** Both are in
`certification_field.dart`, the file the column rename already touched:
`extractValue` returned the raw stored name for the Name column (blank once a
name may be empty), and `formatValue` rendered the level with `.name` -- the
enum identifier -- so the column read `openWater` instead of `Open Water`.

**Not fixed, noted for later:** `formatValue` has the same enum-identifier bug
for `CertificationField.agency`, which renders `padi` rather than `PADI`. Left
alone as outside this change's scope.

## Risks

| Risk | Mitigation |
| --- | --- |
| A user's deliberate name happens to equal the derivation and is "lost" | It renders identically, so nothing is visibly lost; covered by an explicit test |
| Saving an old cert blanks its stored name | User-initiated only; the rendered title is unchanged because the helper derives the same string |
| A display surface is missed and renders blank once Name may be empty | The audit list in §5 is derived from a grep of every `cert.name` / `certification.name` reference; `flutter analyze` plus the widget tests cover the rest |
| Translations drift | All eleven locales updated in the same change, per project practice |
