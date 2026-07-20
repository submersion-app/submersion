# Weight Planner: Attribute-Informed Buoyancy Priors — Design

**Date:** 2026-07-17
**Status:** Approved pending review
**Depends on:** equipment attributes (PR #608, `equipment_attributes` + catalog); this
branch is stacked on `worktree-equipment-attributes` and must merge after it.
**Schema version:** none — no database, migration, sync, or UI changes.

## Problem

The weight-prediction planner derives each gear item's buoyancy prior from
almost nothing. Wetsuits parse a thickness number out of raw strings
(`thickness`/`size`/name) at 1 kg/mm and treat "5/4/3" as a flat 5 mm suit.
Hood (0.3 kg), gloves (0.2), boots (0.4), drysuit (10.0), and BCD (-0.5) are
flat constants. Meanwhile the equipment-attribute system now stores parsed
numeric thickness, panel designations, `suit_style`, `shell_material`,
`glove_type`, `bcd_style`, and `lift_capacity_kg` — none of which reach the
buoyancy engine. `GearFeature` even re-parses the thickness text whose parsed
`valueNum` the attribute system already computed.

## Goals

1. Feed equipment attributes into per-item buoyancy priors: multi-panel
   wetsuit thickness with a `suit_style` factor; per-mm hood/gloves/boots
   priors with a `glove_type` modifier; drysuit `shell_material` factors;
   BCD `bcd_style` offsets plus a lift-capacity bladder term.
2. Prefer the attribute store's parsed numeric thickness (`valueNum`) over
   re-parsing text; keep string parsing as fallback for pre-migration data.
3. Give attribute-derived priors an intermediate ridge strength (4.0) between
   type defaults (2.0) and explicit user buoyancy (8.0).
4. Exact backward compatibility: items with no attributes produce today's
   priors and strengths (regression-pinned).

## Non-goals

- Tank equipment attributes feeding the planner. Tanks already reach the
  physics engine with real specs via `dive_tanks` rows (history) and the
  planner's tank state (prediction); a third path is redundant.
- Depth/suit-compression modeling (existing engine non-goal, unchanged).
- New `TermSource` enum value: attribute-derived priors report as
  `typeDefault` in the prediction breakdown (they are still priors, not
  user-entered buoyancy).
- Undergarment modeling for drysuits (learned per-item term absorbs it).
- Any schema, sync, or UI change.

## Architecture

```
EquipmentItem.attributes
  -> gearFeatureFor()             (weight_planner_providers.dart - the ONLY
       builds GearBuoyancyTraits   place that knows EquipmentAttribute)
  -> GearFeature.fromEquipment(traits: ...)   (core/buoyancy - pure Dart)
  -> prior + strength             (ridge model downstream unchanged)
```

`lib/core/buoyancy/` stays pure Dart with no equipment-model imports. The
engine (`weight_prediction_engine.dart`), ridge regression, observations,
physics, and placement predictor are untouched.

### GearBuoyancyTraits (new, `lib/core/buoyancy/gear_buoyancy_traits.dart`)

```dart
class GearBuoyancyTraits {
  final double? primaryThicknessMm;      // attrNum('thickness_mm')
  final List<double> panelThicknessesMm; // parsed from valueText "5/4/3"
  final String? suitStyle;               // 'full'|'shorty'|'two_piece'|'semi_dry'
  final String? shellMaterial;           // drysuit choice key
  final String? bcdStyle;                // 'jacket'|'back_inflate'|'wing'|'sidemount'
  final double? liftCapacityKg;          // attrNum('lift_capacity_kg')
  final String? gloveType;               // 'five_finger'|'mitt'|'dry'
}
```

The bridge builds it from `attrNum`/`attrText`; panel list splits the
designation `valueText` on the same tolerant separators the legacy parser
accepts (`/`, `,`, `-`), thickest-first by convention.

### Prior resolution ladder (per item, strict order)

1. Explicit `buoyancy_kg` attribute -> prior as-is, strength 8.0
   (`hasUserSpec`, unchanged, always wins).
2. Attribute-derived prior (new) -> per-type factor function below,
   strength `_attributeStrength = 4.0`.
3. Legacy string parse (existing regexes on `thickness`/`size`/`name`, valid
   for wetsuits) -> treated as attribute-derived (strength 4.0). Note this
   RAISES pre-migration parsed-name wetsuits from 2.0 to 4.0 -- deliberate:
   a parsed "7mm Farmer John" carries real information.
4. Flat type default -> strength 2.0 (unchanged values and behavior).

## Factor functions

Pure static functions in `gear_feature.dart`.

**Effective thickness** (wetsuit, hood, gloves, boots): first (thickest,
torso) panel x 0.5 + mean of remaining panels x 0.5; single panel = itself.
"5/4/3" -> 5x0.5 + 3.5x0.5 = 4.25 mm.

**Wetsuit:** `effectiveMm x styleFactor x 1.0 kg/mm`, clamp 0-10 kg (raised
from 8 for two-piece 7 mm suits). Style factors: full 1.0, semi_dry 1.1,
two_piece 1.35, shorty 0.55, unknown/absent 1.0. No thickness anywhere ->
default 4.0 kg at type-default strength.

**Drysuit:** shell_material lookup: neoprene 13.0, crushed_neoprene 11.0,
trilaminate 9.0, vulcanized_rubber 9.0; absent -> 10.0 default (strength 2.0).

**Hood / gloves / boots:** per-mm x effective thickness: hood 0.10 kg/mm,
gloves 0.06 kg/mm, boots 0.12 kg/mm. glove_type modifier: mitt x1.15,
dry x0.5, five_finger/absent x1.0. No thickness -> current flat defaults
(0.3 / 0.2 / 0.4) at strength 2.0.

**BCD:** base by bcd_style: jacket +0.5, back_inflate 0.0, wing -0.5,
sidemount -0.3, absent -> current -0.5. Plus bladder term `+0.01 kg per kg
of lift_capacity_kg` when present. Strength rule (applies to every type):
4.0 if AT LEAST ONE contributing attribute was present (style or lift for
BCD), else 2.0. Dry mass unchanged (`dry_weight_kg` or 3.5 default).

All other types: unchanged flat defaults.

Rationale for the 0.5/0.5 torso/limb blend: a torso panel covers roughly
half a suit's neoprene area and designations are written thickest-first
(the same convention `parsePrimaryThickness` relies on). The blend only ever
reduces the prior versus today's take-the-max, which systematically
overweights multi-panel suits.

## API changes

- `GearFeature.fromEquipment` gains optional `GearBuoyancyTraits? traits`.
  Existing positional/named params stay for the legacy string fallback path.
- `gearFeatureFor(EquipmentItem)` builds traits from the attribute store:
  numeric `thickness_mm` valueNum preferred; panel list from valueText;
  choice keys via `attrText`. New `EquipmentAttrKeys` constants are NOT
  required -- the bridge may use the catalog's string keys directly, but
  adding constants for `suitStyle`, `shellMaterial`, `bcdStyle`,
  `liftCapacityKg`, `gloveType` to `EquipmentAttrKeys` is preferred for
  greppability.
- `EquipmentItem` needs no changes (`attrText`/`attrNum` already public).

## Error handling

- Malformed panel designations parse to whatever panels are valid; zero valid
  panels behaves as no-thickness (fallback ladder).
- Unknown choice keys (future catalog additions) fall through to the absent
  branch of each factor table -- never throw.
- Negative or absurd attribute numbers: effective thickness clamps to
  [0, 15] mm before factors; final wetsuit prior clamps [0, 10] kg;
  accessory priors clamp [0, 2] kg; BCD prior clamps [-2, 2] kg.

## Testing

- `gear_feature_test.dart`: table-driven cases for every factor row and
  fallback; regression pin "no attributes reproduces today's priors and
  strengths exactly" for every type; clamps; multi-panel blend; glove
  modifiers; strength ladder (8.0 / 4.0 / 2.0).
- Bridge tests (`weight_planner_providers_test.dart`): traits built from
  attribute rows; numeric valueNum preferred over text re-parse; choice keys
  passed through; tanks/weights still excluded.
- Engine-level test: shorty vs full suit of equal thickness predicts less
  lead; drysuit shell material shifts an unseen-drysuit swap prediction.
- No DB/widget/sync tests needed (no such surface changes).

## Touched files

- Create: `lib/core/buoyancy/gear_buoyancy_traits.dart`
- Modify: `lib/core/buoyancy/gear_feature.dart` (factor functions + traits
  param + strength ladder)
- Modify: `lib/features/weight_planner/presentation/providers/weight_planner_providers.dart`
  (bridge builds traits)
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`
  (add EquipmentAttrKeys constants only)
- Tests: `test/core/buoyancy/gear_feature_test.dart`,
  `test/features/weight_planner/presentation/weight_planner_providers_test.dart`,
  `test/core/buoyancy/weight_prediction_engine_test.dart`
