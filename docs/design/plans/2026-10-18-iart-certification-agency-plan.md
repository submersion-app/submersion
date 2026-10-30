# IART certification agency (issue #3357)

## Goal

Add IART (International Association of Rebreather Trainers) as a built-in
`CertificationAgency`, mirroring TDI's dedicated course-category structure
(`TdiCourseCategory`, issue #3072) with a parallel `IartCourseCategory`. The
generic ladder/specialties logic is untouched; this is purely additive.

## Source

Course catalog from the issue body (iart.de/kursfinder), five categories:
Open Circuit, Rebreather, Overhead (Caves/Mines), Service, Professional.

## New `CertificationLevel` values (all `displayName` kept untranslated,
proper nouns, same as TDI/BSAC/GUE/ACUC/DAN)

Open Circuit:
- `iartOpenWaterNitroxDiver` 'Open Water Nitrox Diver'
- `iartAdvancedNitroxDiver` 'Advanced Nitrox Diver'
- `iartRecreationalTrimix` 'Recreational Trimix'
- `iartExtendedRangeNormoxicTrimix` 'Extended Range Normoxic Trimix'
- `iartSidemount` 'Sidemount'
- `iartDecompression` 'Decompression'
- `iartDriftDiving` 'Drift Diving'
- `iartNightDiving` 'Night Diving'
- `iartDrysuitDiving` 'Drysuit Diving'

Rebreather:
- `iartRebreatherLevel1` / `iartRebreatherLevel2` / `iartRebreatherLevel3`
- `iartRebreatherRescue` 'Rescue' (mandatory add-on to beginner rebreather
  courses per the issue; kept distinct from the generic `rescue` / 'Rescue
  Diver', which is a different, open-water-only credential)

Overhead:
- `iartCavern` 'Cavern'
- `iartCaveIntroduce` 'Introduce' (verbatim course name from the catalog)
- `iartFullCave` 'Full Cave'
- `iartTechCave` 'Tech Cave'
- `iartCaveDpv` 'Cave/DPV'
- `iartWreck` 'Wreck'
- `iartDpvScooter` 'DPV/Scooter'

Service:
- `iartGasBlender` 'Gas Blender'

Professional:
- `iartIoc` 'IOC', `iartItp` 'ITP', `iartIe` 'IE', `iartIdc` 'IDC'
- `iartDiveGuide` 'Dive Guide' (dedicated value, not the generic `diveGuide`,
  for the same reason TDI built its own `tdiNitroxGasBlender` rather than
  reusing a cross-agency generic: keeps the whole IART catalog self-contained
  and easy to audit/remove as a block)

None of the four instructor-track steps (IOC/ITP/IE/IDC) is marked
`isInstructorLevel`: the issue lists them as training-program steps, not a
named terminal "IART Instructor" rating, so there's nothing to safely flag
as independently certifying yet.

## Ladder vs. specialties (`certification_levels.dart`)

- `_iartLadder`: the four Open Circuit depth/gas progression courses only
  (OWND -> Advanced Nitrox -> Recreational Trimix -> Extended Range Normoxic
  Trimix). TDI's ladder also carried its professional track, but IART has no
  comparably unambiguous terminal credential to anchor that on, so everything
  else — side Open Circuit specialties, all of Rebreather/Overhead/Service,
  and all of Professional — goes to `_iartSpecialties`.
- `ladderFor`/`specialtiesFor` get a `CertificationAgency.iart` case each,
  same shape as the `tdi` cases.

## `IartCourseCategory` (new file, mirrors `tdi_course_category.dart`)

5 values: `openCircuit`, `rebreather`, `overhead`, `service`, `professional`.
Same shape: a `_categories` map covering every ladder+specialties IART level,
`iartCourseCategoryOf`, `groupLevelEntriesByIartCategory`, `groupIartCatalog`.

## Wiring (same hook points TDI uses)

- `certification_enums.dart`: add `iart('IART')` to `CertificationAgency`
  (alphabetically placed next to other brand entries) with primary/secondary
  colors, plus the 26 new `CertificationLevel` values and `fromId` needs no
  change (loop-based).
- `certification_levels.dart`: `_iartLadder`, `_iartSpecialties`, and a
  `CertificationAgency.iart => ...` arm in both `ladderFor`/`specialtiesFor`.
- `certification_level_display.dart`: the exhaustive switch needs an arm
  for all 26 new values -> `displayName` (untranslated), same bucket as the
  TDI/BSAC/GUE/ACUC/DAN proper nouns. This file was not in the original TDI
  file list and must not be missed, or the build fails to compile (good —
  the switch is exhaustive by design).
- `certification_level_dropdown_items.dart`: extend the
  `agency != CertificationAgency.tdi.name` early-return guard to also bypass
  for IART, with an `IartCourseCategory`-grouped branch (own `if`/`else if`,
  not nested inside the TDI branch).
- `certification_agency_edit_page.dart`: same, an `_iartLevelSections` helper
  parallel to `_tdiLevelSections`.
- `certification_agency_display.dart`: `enum_certificationAgency_iart` case.
- l10n: `app_en.arb` (+ the other 9 locale files) get
  `enum_certificationAgency_iart` = "IART" and five
  `certifications_edit_group_iart*` keys (English text identical to TDI's
  group labels: Open Circuit/Rebreather/Overhead/Service/Professional — kept
  as separate `iart`-prefixed keys rather than reusing TDI's, for the same
  reason the CertificationLevel values stay separate). Non-English locale
  values for the five group labels are copied from the existing TDI
  translations in each file (same English words); `enum_certificationAgency_iart`
  stays "IART" untranslated in every locale, like every other agency acronym.
- No migration helper needed (unlike `tdi_certification_migrations.dart`):
  IART has no prior generic-value data to repair, since it does not exist in
  the app yet.

## Tests (new, mirroring the TDI ones)

- `test/features/certification_agencies/presentation/iart_course_category_test.dart`
  (mirrors `tdi_course_category_test.dart`)
- Extend `test/core/constants/certification_levels_test.dart` with an IART
  ladder/specialties-overlap case (mirrors the TDI case at line ~77)
- Extend `test/l10n/certification_agency_brand_names_test.dart` with `iart`
- `certification_level_instructor_test.dart` needs no new case: nothing new
  is instructor-level.

## Cross-examination notes (resolved without asking, see final report)

- iart.de/kursfinder is a JS-rendered SPA; WebFetch/WebSearch could not pull
  the individual course page titles. The issue body is treated as the
  authoritative, already-sourced catalog and course names are taken from it
  verbatim (including the literal "Introduce" and the abbreviations OWND/
  IOC/ITP/IE/IDC), the same way the TDI comment cites tdisdi.com.
- Brand colors are not independently verifiable the same way; picked a pair
  not already in use (`0xFF006064` / `0xFF00ACC1`, a teal distinct from every
  existing agency) rather than guessing at an exact hex from the real IART
  branding.
- `test/l10n/certification_agency_brand_names_test.dart` needs no new case:
  it already scans every `enum_certificationAgency_*` key generically.
- `certification_agency_dropdown.dart` needs no change: it is driven by the
  catalog/provider layer generically, not a per-agency switch.

## Scope change: currency/refresher rule added

The issue does not ask for an IART refresher rule, and this plan originally
left currency rules out of scope on that basis. That was wrong:
`currency_seed_catalog_test.dart`'s `every agency with a diver ladder has a
refresher` test enforces, as a standing invariant of the currency feature
(issue #2267), that every agency with a diver ladder is deliberately
assigned to a refresher rule or explicitly excepted (today only GUE and DAN,
each for a stated reason) -- not an optional nice-to-have. Leaving IART out
is exactly the silent gap that test exists to catch: a diver holding an
IART certification would never be warned it had lapsed. An `iart_refresher`
rule was added (`certification_currency_tables.dart`), activity-clock,
scoped to `["iart"]`, covering exactly `_iartLadder` -- the same shape as
`tdi_refresher`. It is a brand-new seeded row matched by `INSERT OR IGNORE`;
no existing certification has agency `iart` (the agency did not exist before
this PR), so it changes nothing for any current user -- there is nothing for
it to match yet.

## Out of scope

- PDF export templates (only PADI/NAUI/generic templates exist today; TDI
  has none either).
