# Trim figure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A posable side-view diver on the dive's Weights and buoyancy card that shows trim (pitch and roll) from the logged rig, with a try-out sheet for moving weights and gear, adding a test item, posing, and scrubbing through the dive.

**Architecture:** Pure trim physics in `lib/core/buoyancy/trim/` (pose, body, spots, moments, verdicts; no Flutter). A feature-side builder in `lib/features/dive_log/domain/services/trim/` turns a `Dive` plus the buoyancy model's outcome into trim elements. Side-view artwork is compiled from `tool/figure_side/` into its own generated map by a sibling of the gear figure's generator. Widgets in `lib/features/dive_log/presentation/widgets/trim/` paint the jointed figure and host the try-out sheet.

**Tech Stack:** Flutter, Riverpod, Drift (one new column), Python 3 generator for SVG to Dart path data.

**Spec:** `docs/design/specs/2026-11-25-trim-figure-design.md` (approved 2026-11-25).

## Global Constraints

- Issue #5028; release v1.8.7; one PR.
- Every displayed weight follows the active diver's units; moments show kg·m or lb·ft.
- Every new string goes into all 13 ARB files under `lib/l10n/arb/` and the generated localizations are regenerated (`flutter gen-l10n`).
- No em-dashes anywhere; no emojis; files under 800 lines (200-400 typical).
- Paths built with `p.join`; tests restore any global state they replace.
- New column is nullable with no backfill (null = both sides); the schema floor does not move.
- Nothing from try-out mode is ever saved.
- Deviation from spec 8.1, recorded here: the side view does not extend `FigureView` (45 front/back call sites would change for nothing). Side pieces compile into their own map, `trimArtwork`, with a `TrimSegment` in place of a view. Same SVG subset and rules; same `FigureRole` and palette.
- Builder's call recorded here: the buoyancy model's type default for fins is 0 kg. Trim uses its own fin default by `blade_style` when the diver entered no `buoyancy_kg`: paddle -0.6 kg, split -0.3 kg, vented -1.4 kg, unknown -0.6 kg (pair, negative = sinks; tune in Task 6 against the reference rigs). The model itself is unchanged.

## Review Focus

1. A dive with no profile (manual log): the card shows the figure at the rest anchor, the try-out sheet has no time slider. Test in Task 10 and Task 11.
2. An imperial diver adds a test item in lb: the stored kg is the converted value, chips read in lb. Test in Task 11.
3. A dive whose only lead is the legacy single weight, or only weights gear: the figure still draws and places it. Test in Task 5.
4. A large rig (8 weight entries, 25 gear items, sidemount pair plus 3 stages): chips do not overlap and the Pieces list holds every element. Test in Task 9 and Task 11.
5. A diver with no height or body weight on file: 175 cm and the model's default mass are used, no crash, figure draws. Test in Task 3.

---

### Task 1: Weight side, end to end in storage

**Files:**
- Create: `lib/core/database/migrations/helpers/dive_weight_side_migrations.dart`
- Modify: `lib/core/constants/app_enums.dart` (add `WeightSide`), `lib/features/dive_log/domain/entities/dive_weight.dart`, `lib/core/database/tables/dive_tables.dart` (`DiveWeights.side`), `lib/core/database/database.dart` (`currentSchemaVersion` and `migrationVersions` gain the next version, 383 unless main moved), `lib/core/database/migrations/ladder/rungs_v340_onward.dart`, `lib/core/database/migrations/app_database_migrations.dart` (part), `lib/core/database/migrations/before_open_child_columns.dart` (backstop), `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`_mapWeightRow` near 6352 and every `DiveWeightsCompanion` near 2696, 8522, 8533, 9415), `lib/features/agent_access/data/writes/families/weight_writes.dart`, `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` (regenerate with `dart run tool/generate_sql_column_notes.dart`), and every site that copies one `DiveWeight` into another: `editing/new_dive_prefill.dart`, `equipment/data/services/dive_set_bundle_applier.dart`, `dive_log/data/services/bulk_dive_edit_service.dart`.
- Test: `test/core/database/migration_v388_dive_weight_side_test.dart`, `test/features/dive_log/domain/entities/dive_weight_test.dart`, the repository's existing weight round-trip test file (add a case).

**Interfaces:**
- Produces: `enum WeightSide { left, right }` (in `app_enums.dart`, exported by `enums.dart`); `DiveWeight.side` of type `WeightSide?` (null = both), in `props` and `copyWith` (copyWith cannot clear to null: add `bool clearSide = false`). Column `dive_weights.side TEXT NULL` storing `'left'` / `'right'`.

- [ ] **Step 1: Write the failing migration test** modelled on `migration_v382_dive_hand_set_fields_test.dart`: `v383 is in the migration ladder`, `the new column kept the floor`, `a fresh database has dive_weights.side, nullable TEXT`, `an existing weight upgrades to both sides (null)` (create a v382 `dive_weights` table with one row, open, read `side` is null).
- [ ] **Step 2: Write the failing entity test:** `copyWith(side: WeightSide.left).side == WeightSide.left`; `copyWith(clearSide: true).side == null`; two weights differing only by side are not equal.
- [ ] **Step 3: Run both; expect FAIL** (`flutter test test/core/database/migration_v388_dive_weight_side_test.dart test/features/dive_log/domain/entities/dive_weight_test.dart`).
- [ ] **Step 4: Implement** the enum, entity field, table column, helper `_assertDiveWeightSideColumn()` via `_addColumnIfMissing('dive_weights', 'side', 'TEXT')`, rung `if (from < 383)` with a comment in the house style, backstop call, version list entry. Run `dart run build_runner build --delete-conflicting-outputs` in the background (never `--build-filter`).
- [ ] **Step 5: Map the column** in the repository read and every companion write; carry `side` at every copy site listed above. Add a repository test: save a dive with a left integrated weight, reload, `side == WeightSide.left`.
- [ ] **Step 6:** Check sync and backup: run `grep -rn "dive_weights" lib/core/services/sync lib/core/services/export` and add `side` wherever weight columns are listed by name; if the UDDF full backup carries every column of `dive_weights` (see `uddf_exclusion_roundtrip_test.dart`), carry `side` there and add it to that round trip, otherwise leave UDDF alone as the spec says.
- [ ] **Step 7: Run** the three test files; expect PASS. `flutter analyze`.
- [ ] **Step 8: Commit** `feat(dive-log): weight entries record which side they are carried on`.

### Task 2: Side choice in the weights editor

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_weight_entry_row.dart`, `lib/l10n/arb/app_*.arb` (13 files)
- Test: `test/features/dive_log/presentation/widgets/dive_weight_entry_row_test.dart` (create if absent)

**Interfaces:**
- Consumes: `WeightSide`, `DiveWeight.side` (Task 1).
- Produces: strings `diveLog_weight_side_both`, `diveLog_weight_side_left`, `diveLog_weight_side_right`, `diveLog_weight_side_label` ("Side").

- [ ] **Step 1: Failing tests:** `the row offers Both, Left and Right, Both selected for a new weight`; `choosing Left reports a weight with side left`; `a backplate weight shows no side choice`.
- [ ] **Step 2: Run; expect FAIL.**
- [ ] **Step 3: Implement** a compact `SegmentedButton<WeightSide?>` (null = Both) under the type field, hidden for `WeightType.backplate`; changing the type to backplate clears the side.
- [ ] **Step 4: Add the strings** to all 13 ARB files, run `flutter gen-l10n`.
- [ ] **Step 5: Run; expect PASS.** `flutter analyze`.
- [ ] **Step 6: Commit** `feat(dive-log): choose a weight's side in the weights editor`.

### Task 3: Pose and body model

**Files:**
- Create: `lib/core/buoyancy/trim/trim_pose.dart`, `lib/core/buoyancy/trim/trim_body.dart`
- Test: `test/core/buoyancy/trim/trim_body_test.dart`

**Interfaces:**
- Produces:
  - `class TrimPose { final double armReach; /* 0..1 */ final double kneeBendDeg; /* 0..90 */ static const TrimPose standard = TrimPose(armReach: 0.5, kneeBendDeg: 90); TrimPose copyWith({double? armReach, double? kneeBendDeg}); }` (clamps in the constructor via a factory).
  - `class TrimPoint { final double s; final double z; }` body frame, metres: `s` along the body from the crown toward the feet in the straight pose, `z` toward the back (up when prone).
  - `enum TrimSegment { torso, arm, shin, foot, farArm, farShin, farFoot }`.
  - `class TrimBody { factory TrimBody({double? heightCm, double? bodyMassKg}); final double heightM; final double massKg; TrimPoint get floatPoint; TrimPoint shoulder; TrimPoint hip; TrimPoint knee; TrimPoint ankle(TrimPose p); TrimPoint hand(TrimPose p); double segmentAngle(TrimSegment s, TrimPose p); /* radians, about its joint */ List<TrimLimbMass> limbMasses(TrimPose p, {double waterDensity = 1.025}); }` and `class TrimLimbMass { final TrimSegment segment; final TrimPoint centre; final double inWaterKg; }`.
  - Constants, named and documented with their Winter source: segment length fractions of height, mass fractions, segment densities, `kFloatPointTorsoFraction`.

- [ ] **Step 1: Failing tests:**
  - `no height or mass falls back to 175 cm and the model's default mass` (`TrimBody().heightM == 1.75`, `massKg == BuoyancyPhysics.defaultBodyMassKg`).
  - `knee bend 0 puts the ankle behind the knee on the body line` (`ankle.s > knee.s`, `ankle.z` within 1e-9 of `knee.z`).
  - `knee bend 90 lifts the ankle above the knee` (`ankle.s` within 1e-9 of `knee.s`, `ankle.z > knee.z`).
  - `the foot always points to the rear` (for bends 0, 30, 60, 90 the foot segment's absolute angle is 0, pointing toward +s).
  - `arm reach 1 puts the hand ahead of the crown` (`hand.s < 0`); `arm reach 0 puts it beside the hip` (`hand.s` within 0.1 m of `hip.s`).
  - `limbs sink slightly` (every `limbMasses` entry has `0 < inWaterKg < 1` for an 80 kg diver).
  - `the float point sits on the torso between shoulder and hip`.
- [ ] **Step 2: Run; expect FAIL.**
- [ ] **Step 3: Implement.** Arm: one straight segment rotated about the shoulder from pointing at the feet (reach 0, angle 0) through straight down to straight ahead (reach 1, angle pi). Shin: rotated about the knee by `-kneeBendDeg` toward the back. Foot: counter-rotated so its absolute angle is 0. Far limbs share the near limbs' angles.
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): posable body model for trim`.

### Task 4: Spots, moments and verdicts

**Files:**
- Create: `lib/core/buoyancy/trim/trim_spot.dart`, `lib/core/buoyancy/trim/trim_moment.dart`
- Test: `test/core/buoyancy/trim/trim_moment_test.dart`

**Interfaces:**
- Consumes: `TrimBody`, `TrimPose`, `TrimPoint`, `TrimSegment` (Task 3).
- Produces:
  - `enum TrimSpot { head, mouth, chest, chestClip, upperBack, backTank, wing, trimPockets, backplate, buttDRing, waist, hipPockets, sidemount, stageClip, thigh, calf, ankles, feet, fins, hand, wrist, console, cameraArm, floatPoint }` with `TrimSegment segment`, `bool sided` (whether a side moves it laterally), and `TrimPoint pointOn(TrimBody b, TrimPose p)`, `double lateralM(TrimBody b)` (magnitude; 0 for centred spots).
  - `enum TrimLateral { centre, left, right }`.
  - `enum TrimElementKind { lead, gear, tank, test, limb, lift }`.
  - `class TrimElement { final String id; final String label; final TrimElementKind kind; final double sinkKg; /* + sinks, - floats */ final TrimSpot spot; final TrimLateral lateral; final String? itemId; final List<String> pieceIds; TrimElement copyWith({TrimSpot? spot, TrimLateral? lateral}); }`.
  - `enum TrimVerdict { level, slightlyFeetHeavy, feetHeavy, slightlyHeadHeavy, headHeavy }`, `enum RollVerdict { level, slightlyLeft, left, slightlyRight, right }`.
  - `class TrimResult { final double pitchKgM; /* + feet-heavy */ final double rollKgM; /* + rolls right */ final double balancingLiftKg; TrimVerdict get pitch; RollVerdict get roll; double get tiltDeg; /* clamp(kTiltDegPerKgM * pitch, -20, 20) */ }`.
  - `TrimResult computeTrim({required TrimBody body, required TrimPose pose, required List<TrimElement> elements, required double modelNetKg, required TrimSpot liftSpot})`: adds the limbs from `body.limbMasses(pose)`; balancing lift `L = max(0, -(modelNetKg - extraSinkKg))` where `extraSinkKg` is the sum of `kind == test` elements, acting at `liftSpot`; the remaining force acts at the float point (no moment).
  - Constants `kLevelBandKgM`, `kSlightBandKgM`, `kTiltDegPerKgM` (tuned in Task 6).

- [ ] **Step 1: Failing tests:**
  - `weight at the float point gives no moment`.
  - `lead moved from trimPockets to hipPockets increases pitch` (strictly).
  - `an element that floats at the feet makes the diver less feet-heavy` (negative `sinkKg` at fins lowers pitch).
  - `left and right lead of equal weight cancel in roll`; `1 kg on the right hip gives positive roll`.
  - `an overweighted diver's wing lift on the upper back lowers pitch` (`modelNetKg: -3`, `liftSpot: wing` vs `liftSpot: floatPoint`, the wing case reads lower pitch, `balancingLiftKg == 3`).
  - `a test item adds its own lift` (adding a 2 kg test element raises `balancingLiftKg` by 2).
  - `tilt is capped at 20 degrees`.
  - `centred spots ignore lateral` (backplate with `TrimLateral.right` gives roll 0).
- [ ] **Step 2: Run; expect FAIL.**
- [ ] **Step 3: Implement.** Moment arm for pitch is `point.s - floatPoint.s` in the posed frame; roll arm is `+/- lateralM` for `left` / `right` on sided spots.
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): trim moments and verdicts`.

### Task 5: Placement from the dive

**Files:**
- Create: `lib/features/dive_log/domain/services/trim/trim_placement.dart` (types, weight types, tank roles, attributes to spot, lateral and piece ids), `lib/features/dive_log/domain/services/trim/trim_scene_builder.dart`
- Modify: `lib/core/buoyancy/buoyancy_twin.dart` (`TwinStaticTerm` gains `final String? itemId; final double? priorKg;`), `lib/features/dive_log/data/services/buoyancy_twin_assembler.dart` (fill both in `composeRigTerms`)
- Test: `test/features/dive_log/domain/services/trim/trim_placement_test.dart`, `test/features/dive_log/domain/services/trim/trim_scene_builder_test.dart`, add a case to the assembler's test (`composeRigTerms` terms carry the item id and prior).

**Interfaces:**
- Consumes: Tasks 1, 3, 4; `BuoyancyTwinOutcome` (`result.input`, `result.samples`, `outputs.verdict`), `twinTankKgAt`, `twinTankPressureAt`, `EquipmentLead.kgFor`, `figurePositionZone`, `wornAsZones`, `figureAttributesOf`.
- Produces:
  - `TrimPlacement trimPlacementForGear(EquipmentType type, Map<String, String?> attributes)` returning `class TrimPlacement { final TrimSpot spot; final TrimLateral lateral; final List<String> pieceIds; }` (pieceIds are `trimArtwork` keys; empty for types with no artwork).
  - `TrimPlacement trimPlacementForWeight(WeightType? type, WeightSide? side)`; `TrimPlacement trimPlacementForTank(TankRole role, {String? wornAs})`; `TrimSpot trimSpotForFigureZone(FigureZone zone)` with lateral.
  - `double trimFinSinkKg(Map<String, String?> attributes)` (the fin defaults in Global Constraints).
  - `class TrimScene { final List<TrimElement> elements; final double modelNetKg; final TrimSpot liftSpot; final TrimBody body; final int timestamp; }`
  - `TrimScene buildTrimScene({required Dive dive, required BuoyancyTwinOutcome outcome, required int? timestamp, double? heightCm})`: `timestamp` null means the rest anchor (`outputs.verdict` anchor; the static convention for a no-profile dive).

- [ ] **Step 1: Failing placement tests:**
  - `every EquipmentType has a placement` (loop `EquipmentType.values`, no throw; tray types and top-level O2 cells or batteries map to `floatPoint`).
  - `weight types map as the spec table` (belt `waist`, integrated `hipPockets`, trimWeights `trimPockets`, backplate `backplate` centred, ankleWeights `ankles`, mixed and null `waist`).
  - `a weight's side becomes its lateral`, `both stays centre`.
  - `tank roles map as the spec table` (backGas, twinSet, hydrotank, diluent, oxygenSupply, suitInflation, pony `backTank`; sidemountLeft/Right `sidemount` left/right; stage, deco, bailout `stageClip` left), and `worn_as wins over role`.
  - `a figure_position override wins for gear and weights gear`.
  - `unstyled weights gear sits at the backplate`.
  - `fins use the blade-style default unless buoyancy_kg is set`.
- [ ] **Step 2: Failing scene tests** with a hand-built `Dive` and `buoyancyOutcome()` from `test/features/dive_log/presentation/widgets/buoyancy_outcome_fixture.dart`:
  - `typed weights become lead elements at their spots`; `the legacy single weight is used only when there are no typed weights`; `weights gear becomes lead at its style's spot`.
  - `gear terms are placed by item id and use the prior`.
  - `camera accessories follow the camera`; `a child item sits at its parent's spot`; `an assembly's parts are one element at the assembly's spot`.
  - `tank buoyancy follows the timestamp` (an aluminium tank's `sinkKg` at the last sample is lower than at the first).
  - `a jacket BCD lifts at the float point, a wing at the wing spot`.
  - `no height on file uses 175 cm`.
- [ ] **Step 3: Run; expect FAIL.**
- [ ] **Step 4: Implement** `itemId` and `priorKg` on `TwinStaticTerm` (optional, defaulted null so every existing construction compiles), the placement tables, and the builder. The side placement table follows `FigurePlacement`'s choices and the spec's 7.2 and 7.3 tables; piece ids follow Task 7's naming.
- [ ] **Step 5: Run; expect PASS.** Also run the assembler's existing test file.
- [ ] **Step 6: Commit** `feat(dive-log): place a dive's lead, gear and tanks for trim`.

### Task 6: Calibration against the reference rigs

**Files:**
- Modify: `lib/core/buoyancy/trim/trim_body.dart` (`kFloatPointTorsoFraction`), `lib/core/buoyancy/trim/trim_moment.dart` (bands, tilt gain), `trim_placement.dart` (fin defaults)
- Test: `test/core/buoyancy/trim/trim_reference_rigs_test.dart`

**Interfaces:**
- Consumes: Tasks 3 to 5.

- [ ] **Step 1: Failing tests,** one per rig, 175 cm, 80 kg, salt water, `TrimPose.standard`, elements built directly (no database): wetsuit at the float point; AL80 at `backTank` with its kg from `twinTankKgAt` at 50 bar; BCD as a wing; `modelNetKg: -1.0`, `liftSpot: wing`.
  - `rig 1 (4 kg hips, 2 kg trim, paddle fins) reads level`.
  - `rig 2 (6 kg belt, paddle fins) reads slightly feet-heavy`.
  - `rig 3 (6 kg belt, vented fins) reads feet-heavy`.
  - `rig 4 (steel 15 L at 50 bar, 2 kg backplate, 2 kg trim, split fins) reads slightly head-heavy`.
  - `knee bend 90 is less feet-heavy than 0 for rig 3`; `arm reach 1 with a 1.2 kg light in the hand is more head-heavy than reach 0`.
- [ ] **Step 2: Run; expect FAIL** (or pass by accident; tune anyway so each rig sits inside its band, not on an edge).
- [ ] **Step 3: Tune** the float-point fraction first, then the band widths, then the fin defaults, keeping each within physically plausible ranges (float point between the nipple line and the navel; fin defaults within -0.2 to -1.8 kg). Document the chosen values and the rigs in a comment above the constants.
- [ ] **Step 4: Run Tasks 3 to 6 tests; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): tune trim to reference rigs`.

### Task 7: Side artwork pipeline

**Files:**
- Create: `tool/figure_side/manifest.json`, `tool/figure_side/body_side_torso.svg` (and the other body segments), `tool/build_trim_artwork.py`, `lib/features/dive_log/presentation/widgets/trim/trim_artwork.gen.dart`, `lib/features/dive_log/presentation/widgets/trim/trim_piece_data.dart`, `lib/features/dive_log/presentation/widgets/trim/trim_space.dart`
- Test: `test/features/dive_log/presentation/widgets/trim/trim_artwork_test.dart`

**Interfaces:**
- Produces: `class TrimPieceData { final String id; final TrimSegment segment; final int layer; final List<FigurePathData> paths; }`; `const Map<String, TrimPieceData> trimArtwork`; `const String trimArtworkDigest`; `kTrimWidth = 400`, `kTrimHeight = 200`; joint pivots `kTrimShoulder`, `kTrimKnee`, `kTrimAnkle` (Offsets in side space, the straight pose, diver facing left, back up).
- Piece ids: `<type>[_<variant>]_side[_<segment>]`; body pieces `body_side_torso`, `body_side_arm`, `body_side_shin`, `body_side_foot`, and far-side `body_side_far_arm` and so on.

- [ ] **Step 1: Failing test** modelled on `test/features/equipment/figure/artwork/figure_artwork_test.dart`: digest matches `tool/figure_side`; every path parses and stays inside 400 x 200; every manifest segment is a `TrimSegment` name.
- [ ] **Step 2: Run; expect FAIL.**
- [ ] **Step 3: Implement** `build_trim_artwork.py` by importing the shape and path functions from `build_figure_artwork.py` (no duplication), with `SRC = tool/figure_side`, `OUT` above, `segment` in place of `view`, and `--verify`. Draw the body segments. Run `python3.14 tool/build_trim_artwork.py`.
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): side-view artwork pipeline for the trim figure`.

### Task 8: Side artwork for every gear type

**Files:**
- Create: SVGs in `tool/figure_side/` and manifest entries; regenerate `trim_artwork.gen.dart`
- Test: extend `trim_artwork_test.dart`

**Interfaces:**
- Consumes: Task 5's `pieceIds` for every type and variant; Task 7's pipeline.

- [ ] **Step 1: Failing test:** `every piece id the placement tables name exists in trimArtwork` (walk `EquipmentType.values` with each variant attribute value from the catalog, every `WeightType`, every `TankRole`), and `every type with front or back artwork has side artwork` (compare against `FigurePlacement`'s pieces, minus the tray types).
- [ ] **Step 2: Run; expect FAIL** listing the missing ids.
- [ ] **Step 3: Author the pieces** in side space, by segment: suits and layers split torso / arm / shin / foot with joint overlap shapes; weights (belt, hip pockets, trim pockets, backplate weights, ankle weights); tanks (single, doubles, sidemount, stage); BCD styles; fins by blade style; then the rest following the gear figure's table. Roles as in the gear figure's manifest. Regenerate after each batch.
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): side-view artwork for every gear type`.

### Task 9: Figure painter and read-only figure

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/trim/trim_figure_painter.dart`, `trim_figure.dart` (figure, chips and leader lines), `trim_gauges.dart` (pitch, roll, verdict line), `trim_strings.dart` (verdict and spot names to l10n)
- Modify: ARB files (verdicts, gauge ends, chip side marks, spot names, figure summary)
- Test: `test/features/dive_log/presentation/widgets/trim/trim_figure_test.dart`, `trim_gauges_test.dart`, `trim_figure_painter_test.dart`

**Interfaces:**
- Consumes: Tasks 3 to 8; `FigurePalette` from the gear figure for item colours.
- Produces: `class TrimFigure extends StatelessWidget { const TrimFigure({required TrimScene scene, required TrimPose pose, required TrimResult result, String? selectedElementId, ValueChanged<TrimElement>? onElementTap, bool showChips = true}); }`; `class TrimGauges extends StatelessWidget { const TrimGauges({required TrimResult result}); }`; `TrimFigurePainter` draws far limbs first, then each segment's pieces rotated about its pivot, all under the tilt about the float point.

- [ ] **Step 1: Failing tests:**
  - `the verdict line reads Slightly feet-heavy, rolls right` for a result in those bands.
  - `chips show each lead element's name, weight in the diver's units and L or R`.
  - `long chip names ellipsize and the semantics label carries the full name`.
  - `25 gear items and 8 weights lay out with no overlapping chips` (compare chip rects pairwise).
  - `the figure summary for screen readers names the verdict and the lead spots`.
  - Painter: `paints without error at knee 0/45/90 and arm 0/0.5/1, light and dark` (pump in a `RepaintBoundary`, no exceptions).
- [ ] **Step 2: Run; expect FAIL.**
- [ ] **Step 3: Implement;** add strings to all 13 ARB files and `flutter gen-l10n`.
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): draw the posable trim figure`.

### Task 10: The figure on the Weights and buoyancy card

**Files:**
- Create: `lib/features/dive_log/presentation/providers/trim_scene_provider.dart` (scene at the shared cursor), `lib/features/dive_log/presentation/widgets/trim/trim_card_section.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_weights_buoyancy_card.dart`, ARB files ("Try placements")
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_weights_buoyancy_card_test.dart` (extend), `test/features/dive_log/presentation/widgets/trim/trim_card_section_test.dart`

**Interfaces:**
- Consumes: `buoyancyTwinProvider`, `profileTrackingIndexProvider(diveId)`, `diveProfileProvider`, latest diver weight entry for height, Tasks 5 and 9.
- Produces: `trimSceneProvider` family keyed by `(String diveId, int? timestamp)`; `TrimCardSection({required Dive stored, required BuoyancyTwinOutcome outcome})` with a "Try placements" button calling `showTrimTryoutSheet` (Task 11).

- [ ] **Step 1: Failing tests:**
  - `the figure sits between the weights list and the model`.
  - `no model outcome, no figure, the list still shows`.
  - `at 720 dp and wider the list and the figure sit side by side; narrower they stack`.
  - `moving the profile cursor changes the tanks' state the figure uses` (verdict text changes between first and last sample for an aluminium-tank dive built to cross a band).
  - `a dive with no profile shows the figure at the rest anchor`.
- [ ] **Step 2: Run; expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; expect PASS,** plus the card's existing tests.
- [ ] **Step 5: Commit** `feat(dive-log): trim figure on the Weights and buoyancy card`.

### Task 11: Try-out sheet

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/trim/trim_tryout_controller.dart` (`ChangeNotifier` holding moved elements, test items, pose, timestamp; `reset()`), `trim_tryout_sheet.dart`, `trim_pieces_list.dart`, `trim_test_item_form.dart`
- Modify: ARB files
- Test: `test/features/dive_log/presentation/widgets/trim/trim_tryout_controller_test.dart`, `trim_tryout_sheet_test.dart`

**Interfaces:**
- Consumes: Tasks 4, 5, 9, 10.
- Produces: `Future<void> showTrimTryoutSheet(BuildContext context, {required TrimScene scene, required List<int> sampleTimestamps, required TrimSceneAt sceneAt})` where `typedef TrimSceneAt = TrimScene Function(int? timestamp)`; follows `showBuoyancyWhatIfSheet`'s modal style.

- [ ] **Step 1: Failing controller tests:** `moving an element snaps it to the nearest allowed spot` (gear only to spots its type may use; lead and test items anywhere); `tapping cycles both, left, right on sided spots and does nothing on centred ones`; `adding a test item places it at the waist`; `reset restores the scene, the standard pose and the opening time`; `nothing is written` (the controller has no repository dependency).
- [ ] **Step 2: Failing sheet tests:** `dragging a chip to the trim pockets changes the verdict`; `the Arms and Knees sliders change pitch`; `the time slider is absent for a dive with no profile`; `the time slider label shows run time and depth`; `the test item form refuses an empty name and a weight outside 0.1 to 20 kg, inline`; `an imperial diver enters 5 lb and the chip reads 5 lb`; `the Pieces list holds every element and its menu moves one and changes its side`; `pitch and roll show in kg·m, lb·ft for imperial`; `closing the sheet leaves the card unchanged`.
- [ ] **Step 3: Run; expect FAIL.**
- [ ] **Step 4: Implement;** strings in all 13 ARB files, `flutter gen-l10n`.
- [ ] **Step 5: Run; expect PASS.**
- [ ] **Step 6: Commit** `feat(dive-log): try placements, pose and time in the trim sheet`.

### Task 12: Finish

- [ ] **Step 1:** `dart format .`; `flutter analyze` (whole repo, zero issues).
- [ ] **Step 2:** Run every test file created or changed by Tasks 1 to 11, by path (never a folder).
- [ ] **Step 3:** After screenshots with the throwaway golden in `test/_pr_shots/trim_card_shots_test.dart` (`--dart-define=STAGE=after`): the card at phone and desktop, light and dark, plus the try-out sheet with a moved chip, a test item and knees bent. Copy to the scratchpad; delete `test/_pr_shots/` before any commit or push.
- [ ] **Step 4:** Commit any formatting fallout as `chore(dive-log): format`.
