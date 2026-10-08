# Agency-Dependent Certification Levels

- **Issue:** [#546](https://github.com/submersion-app/submersion/issues/546) - Certification level should depend on Certification Agency
- **Date:** 2026-07-10
- **Status:** Approved

## Problem

The certification level dropdown shows the same flat, PADI-flavored list (Open
Water, Advanced Open Water, ...) regardless of the selected agency. A CMAS
diver holds 1\*D through 3\*I star grades; a BSAC diver holds Ocean Diver
through First Class Diver. Neither can record their actual level. The buddy
edit form additionally asks for level *before* agency, which is backwards for
a dependent field.

## Goals

- The level dropdown offers levels appropriate to the selected agency.
- Agency is always presented before level in forms.
- CMAS grades from the issue (1\*D-4\*D, 3\*D/4\*D Assistant Instructor,
  1\*I-3\*I) are all selectable.
- No database migration, no sync-format change, no data loss for existing
  records.

## Non-Goals

- Free-text / user-defined levels (the certification `name` field already
  captures exact wording; `Other` covers the rest).
- Localizing level names (agency level names are brand names and stay
  English, matching the existing enum `displayName` convention).
- Exhaustive modeling of every agency's full catalog (specialty courses
  beyond the shared specialty set, junior ratings, etc.).
- Dropdown section headers / dividers inside the level list.

## Design

### Data model (no schema change)

`level` is already stored as nullable text holding the enum's `.name`;
unknown names parse to `CertificationLevel.other`. Everything below is
Dart-side only.

**1. Extend `CertificationLevel`** (`lib/core/constants/enums.dart`) with
agency-specific values. Existing values are untouched (their `.name` is a
persistence format). New values:

| Group | Enum values (displayName) |
| ----- | ------------------------- |
| Generic | `masterDiver` (Master Diver), `assistantInstructor` (Assistant Instructor) |
| Tech | `extendedRange` (Extended Range), `advancedTrimix` (Advanced Trimix) |
| CMAS | `cmas1StarDiver` (1★ Diver) ... `cmas4StarDiver` (4★ Diver), `cmas3StarDiverAssistantInstructor` (3★ Diver - Assistant Instructor), `cmas4StarDiverAssistantInstructor` (4★ Diver - Assistant Instructor), `cmas1StarInstructor` (1★ Instructor) ... `cmas3StarInstructor` (3★ Instructor) |
| BSAC | `bsacOceanDiver` (Ocean Diver), `bsacSportsDiver` (Sports Diver), `bsacDiveLeader` (Dive Leader), `bsacAdvancedDiver` (Advanced Diver), `bsacFirstClassDiver` (First Class Diver), `bsacOpenWaterInstructor` (Open Water Instructor), `bsacAdvancedInstructor` (Advanced Instructor), `bsacNationalInstructor` (National Instructor) |
| GUE | `gueFundamentals` (Fundamentals), `gueRec1` (Rec 1) ... `gueRec3` (Rec 3), `gueTech1` (Tech 1), `gueTech2` (Tech 2), `gueCave1` (Cave 1), `gueCave2` (Cave 2), `gueDpv` (DPV) |

Agency-prefixed enum *names* keep `.name` collisions impossible;
`displayName` omits the agency prefix because the dropdown is already scoped
by the agency field above it.

**2. New catalog** `lib/core/constants/certification_levels.dart`:

```dart
class CertificationLevelCatalog {
  /// Core progression ladder for an agency, in rank order.
  static List<CertificationLevel> ladderFor(CertificationAgency? agency);

  /// Cross-agency specialty levels.
  static const List<CertificationLevel> specialties = [
    nitrox, advancedNitrox, decompression, trimix, cavern, cave,
    wreck, sidemount, rebreather, techDiver,
  ];

  /// Full dropdown list: ladder + specialties (deduplicated) + other.
  static List<CertificationLevel> levelsFor(CertificationAgency? agency);
}
```

Ladders (rank order):

| Agency | Ladder |
| ------ | ------ |
| PADI | openWater, advancedOpenWater, rescue, masterDiver, diveMaster, assistantInstructor, instructor, masterInstructor, courseDirector |
| SSI | openWater, advancedOpenWater, rescue, masterDiver, diveMaster, assistantInstructor, instructor |
| NAUI | openWater, advancedOpenWater, rescue, masterDiver, diveMaster, assistantInstructor, instructor, courseDirector |
| SDI | openWater, advancedOpenWater, rescue, masterDiver, diveMaster, assistantInstructor, instructor, courseDirector |
| RAID | openWater, advancedOpenWater, rescue, masterDiver, diveMaster, instructor |
| TDI | nitrox, advancedNitrox, decompression, extendedRange, trimix, advancedTrimix, cavern, cave, rebreather, instructor |
| IANTD | nitrox, advancedNitrox, decompression, extendedRange, trimix, advancedTrimix, cavern, cave, rebreather, instructor |
| PSAI | nitrox, advancedNitrox, decompression, extendedRange, trimix, advancedTrimix, cavern, cave, rebreather, instructor |
| GUE | gueFundamentals, gueRec1, gueRec2, gueRec3, gueTech1, gueTech2, gueCave1, gueCave2, gueDpv, instructor |
| BSAC | bsacOceanDiver, bsacSportsDiver, bsacDiveLeader, bsacAdvancedDiver, bsacFirstClassDiver, bsacOpenWaterInstructor, bsacAdvancedInstructor, bsacNationalInstructor |
| CMAS | cmas1StarDiver, cmas2StarDiver, cmas3StarDiver, cmas4StarDiver, cmas3StarDiverAssistantInstructor, cmas4StarDiverAssistantInstructor, cmas1StarInstructor, cmas2StarInstructor, cmas3StarInstructor |
| other / null | All generic values (the pre-existing enum list) |

For tech agencies whose ladder overlaps `specialties`, `levelsFor` removes
duplicates while preserving ladder order.

### UI behavior

Applies to **certification edit page**
(`lib/features/certifications/presentation/pages/certification_edit_page.dart`)
and **buddy edit page**
(`lib/features/buddies/presentation/pages/buddy_edit_page.dart`).

- **Order:** agency dropdown renders above the level dropdown. The
  certification page already does; the buddy page's two blocks (each a `Row`
  with merge-cycle support) swap positions. Merge-mode cycling logic is
  unaffected.
- **Filtering:** level dropdown items come from
  `CertificationLevelCatalog.levelsFor(_agency)`, rebuilt when agency
  changes. Buddy agency is nullable; `null` behaves like `other` (full
  generic list).
- **Stale-value preservation:** if the current `_level` is not in the
  computed list (e.g. a record saved before this change, or merge-cycled
  values), it is appended to the dropdown items so the form renders and the
  value survives unrelated edits. Data is never silently dropped.
- **Reset on agency switch:** when the user changes agency and the currently
  selected level is not in the new agency's list, `_level` resets to null
  ("Not specified"). This is a deliberate, user-visible consequence of the
  user's own action - not a background mutation.

### Compatibility

- **Database/sync:** none. Level remains enum-name text. Older app versions
  reading a new name (e.g. `cmas2StarDiver`) fall back to `other` on parse -
  the pre-existing lossy-but-safe behavior. The raw text is preserved on
  their disk only if they do not rewrite the row; this matches how all prior
  enum additions behaved and is acceptable.
- **UDDF import/export, universal import adapter, repositories:** parse by
  enum name against `CertificationLevel.values`; new values work with zero
  changes.
- **PDF templates / detail pages / list items:** render via `displayName`;
  no changes needed.

## Testing (TDD)

Unit tests (`test/core/constants/certification_levels_test.dart`):

- Every `CertificationAgency` (and null) yields a non-empty `levelsFor` list
  ending in `other`, with no duplicates.
- CMAS list contains exactly the nine grades from the issue.
- Ladder/specialty overlap is deduplicated for tech agencies.
- Every enum value's `.name` is unique (guards against persistence
  collisions).

Widget tests (certification + buddy edit pages):

- Agency field appears before level field.
- Selecting CMAS restricts the level list (e.g. `advancedOpenWater` absent,
  `cmas2StarDiver` present; specialties still present).
- Loading an existing record with an out-of-catalog level renders and
  preserves it on save.
- Switching agency with an incompatible level selected resets level to
  "Not specified".

## Implementation Notes

- Work happens in worktree `worktree-issue-546-agency-cert-levels`.
- `dart format .` before committing; existing widget-test gotchas apply
  (labels, `ensureVisible` before taps).
