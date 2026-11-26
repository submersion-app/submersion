# Trim figure: a posable side-view diver on the Weights and buoyancy card

Status: approved 2026-11-25. Release: v1.8.7. Delivery: one PR.

## 1. Why

A diver wants to understand their weight distribution, not only how much lead
they carry. Two questions in the diver's own words:

- "If I need to add another heavy piece of equipment, where should I place it
  so that it doesn't throw off my balance or buoyancy?"
- "Do I need to carry weight higher up to compensate for heavy fins?"

Both are questions of trim: how the weight of lead, gear, tanks and the
diver's own limbs balances head to foot (pitch) and side to side (roll)
around the point the diver floats from. The Weights and buoyancy card
(issue #5005) already says how much lead was carried and whether it was the
right amount. It says nothing about where that lead sits or what it does to
the diver's position in the water.

## 2. Goals

1. On the dive's Weights and buoyancy card, a side-view diver, drawn in the
   style of the gear figure, tilted by how hard the logged rig pulls it
   head-down or feet-down, with a pitch gauge, a roll gauge and a plain verdict.
2. A try-out mode where the diver can move any weight or gear item to another
   spot, switch its side, add a test item (a name and a weight), and change
   the pose (arm reach, knee bend), watching pitch and roll respond.
3. Left/right placement for weight entries, so roll is real for lead and not
   only for gear that already has a side.

## 3. Non-goals

- The Weight planner. The same figure belongs there later (decided
  2026-11-25: "leave it out of the planner for now"); nothing in this PR
  touches the planner.
- Saving anything from try-out mode. Moves, test items and pose are thrown
  away when the sheet closes. Changing the logged weights stays the job of
  the weights editor.
- Front-to-back roll ("turtling"). The figure shows pitch and roll only.
- The diver's own natural trim (how their body floats without gear). The
  model treats the torso and head as acting at the float point; see 7.2.
- A literal tilt angle. A real diver given a pitching pull keeps rotating
  until something stops them; the figure's tilt is a picture of the pull's
  strength, capped, not a prediction of an angle.
- Sharing the figure as an image, or any export of it.

## 4. Anti-goals

- A figure that claims more precision than the inputs carry. Many gear
  weights are type defaults until measured; the verdict is phrased as a
  direction and strength ("Slightly feet-heavy"), never as degrees or a
  claim of being exactly level.
- A card that becomes hard to read for a diver with 25 gear items, or with
  one weight entry. See 9.
- Losing anything the card shows today. The weights list and the buoyancy
  model keep their current form and order; the figure is added.

## 5. Decisions made during design

| Question | Decision |
| --- | --- |
| What it shows | Trim: pitch (head to foot) and roll (side to side) around the float point |
| View | A side view of a prone diver that visibly tilts, chosen over the upright front/back gear figure with a gauge, which cannot show pitch |
| Interaction | Drag-and-drop in a try-out mode (prototype accepted 2026-11-25) |
| Where | The dive's Weights and buoyancy card only, this PR |
| Test item | A chip with a name and a weight that can be added and placed in try-out mode |
| Roll | Shown, with a second gauge; weight entries gain a side |
| Artwork | Full side-view artwork for every gear type that has front/back artwork today (approach B below) |
| Pose | Arm reach and knee bend are adjustable in try-out mode; fins always point to the rear |
| Delivery | One PR |
| Calibration | Tuned to four reference rigs (7.5) |
| Try-out moment | A time slider through the dive (9.4) |

## 6. Approaches considered

How the figure is drawn was the open choice.

- **A. Side-view base artwork plus labelled chips.** Body, tanks and fins as
  new side-view SVG pieces; every other item a chip on a leader line. About
  8 pieces. Cheapest art, but most gear is a label rather than a drawing.
- **B. Full side-view artwork for every gear type.** The gear figure's
  placement table re-drawn from the side, jointed for posing. Roughly 60 to
  70 pieces. Most faithful to the gear figure.
- **C. Shapes drawn in code** (as in the brainstorming prototype). Fastest,
  no artwork pipeline, but it does not look like the gear figure.

**Chosen: B** (Eric's pick, kept after posing was added and the piece count
grew).

## 7. The trim model

Pure Dart under `lib/core/buoyancy/` (or a sibling `trim/` folder), with no
Flutter imports, fully unit-tested.

### 7.1 Frames and the float point

- Body axis `s`: metres along the body from the top of the head (0) toward
  the feet, in the straight reference pose. Lateral axis `l`: metres, diver's
  left negative, right positive.
- Segment lengths and joint positions scale with the diver's height
  (`heightCm` from the diver's latest weight entry; 175 cm when unknown),
  using standard anthropometric proportions (Winter, *Biomechanics and Motor
  Control of Human Movement*, segment length fractions of height).
- The float point (centre of buoyancy) is a fixed fraction along the torso,
  at the lower chest. It does not move with pose.
- **Pitch moment** = sum over every weight-bearing element of
  `inWaterKg * (s_element - s_float)` in the posed figure, in kg·m.
  Positive is feet-heavy. **Roll moment** = sum of `inWaterKg * l_element`,
  positive rolls right. In-water kg is signed: negative buoyancy (heavy)
  counts positive here, positive buoyancy (an aluminium tank near empty)
  counts negative, so a floating item lifts the end it sits on.

### 7.2 What carries weight, and where it comes from

| Element | In-water kg | Position |
| --- | --- | --- |
| Weight entry (typed) | `amountKg` | By `weightType`, see 7.3; side from the new field |
| Legacy single weight (no typed entries) | `weightAmount` | By its `weightType`, centred |
| Lead carried as weights gear | `EquipmentLead.kgFor(item)` | By its `weight_style` attribute, see 7.3 |
| Gear item (non-suit) | The item's **prior**: its `buoyancy_kg` when the diver entered one, else the type default. Never the fitted coefficient (builder's call, see below) | Its side-view zone (8.3) |
| Tank | Its buoyancy at the moment shown (full to empty as the dive goes), from `BuoyancyPhysics` with the same pressure the model uses at that sample | By role, see 7.3 |
| Exposure suit and whole-body layers (undersuit, baselayer, rash guard, vest) | Their lift is spread along the body | Act at the float point (no moment) |
| Item with no spot on the body: tray types (hose, tool, bag, other, tank band), and top-level O2 cells and batteries | As the gear row | At the float point (no moment) |
| Camera accessories (lens, port, float arm, tray handle, arm clamp, strobe) | As the gear row | With the camera or housing when there is one (so a float arm trims the camera, as it does in the water); else at the float point |
| A child item (parent link) or an assembly part | As the gear row | At its parent's or assembly's spot, and moves with it |
| Lift that holds the diver neutral | When the model's net at the moment is heavy, lift equal to it | At the BCD's spot: the wing or backplate bladder on the upper back; a jacket BCD, or no BCD (drysuit gas), at the float point. A light net gets no balancing term |
| Body limbs | Segment mass fraction x body mass x (1 - water density / segment density), from Winter's tables | Segment centre of mass in the posed figure |
| Head, torso, personal and body-composition terms, water term | Act at the float point (no moment) | |

The gear item terms are produced today by
`BuoyancyTwinAssembler.composeRigTerms`, which drops the item identity:
`TwinStaticTerm` gains an optional `itemId` and the item's prior beside the
value the model uses, so the trim model can place each term and read its
prior. Rolled-up assemblies stay as the model treats them (parts carry the
mass) and are placed and moved as one piece, at the assembly's spot, as the
gear figure draws them.

Builder's calls recorded from the design review:

- **Priors, not fitted coefficients, for trim.** The fit splits leftover
  buoyancy between items always worn together, which is harmless for the
  lead total but not for trim: fins sit about a metre from the float point,
  so a 1 kg error is a whole verdict band. The model's lead total is
  unaffected.
- **The balancing lift is part of the moment.** The forces must sum to zero
  for the moment to be independent of where it is taken. An overweighted
  diver holds the difference with wing gas on the upper back, which pulls
  that end up; adding a test item in try-out also adds the lift that holds
  it.

### 7.3 Placement of lead and tanks

| Source | Spot | Side |
| --- | --- | --- |
| `WeightType.belt` | Waist, front | The entry's side |
| `WeightType.integrated` | Hip pockets | The entry's side; "both" splits evenly |
| `WeightType.trimWeights` | Trim pockets, upper back | The entry's side |
| `WeightType.backplate` | Backplate, mid back | Centred |
| `WeightType.ankleWeights` | Ankles (on the shin segment) | The entry's side |
| `WeightType.mixed`, or no type | Waist, front, with a note on the chip ("spot not known") | The entry's side |
| Weights gear with a `figure_position` (issue #4493) | That spot | That spot's side |
| Weights gear, `weight_style` integrated / trim / ankle / belt | As the matching `WeightType` row | Both |
| Weights gear with no style and no position | Backplate, mid back: unstyled weights gear is how weighted backplates, V-weights and tank adapters are logged (`EquipmentLead`) | Centred |
| Tank with a `worn_as` choice on its cylinder item | The zone `wornAsZones` gives | That zone's side |
| Tank, back gas, twin set, CCR diluent, O2 supply, suit inflation, pony | Back | Centred |
| Tank, sidemount left / right | Beside the torso, under the arm | Left / right |
| Tank, stage, deco, bailout | Clipped at the hip and chest D-rings | Left (the usual convention) |

Any gear item's `figure_position` override wins over the side placement
table, as it does on the gear figure.

### 7.4 Pose

- **Arm reach** 0 to 100: 0 is arms along the sides, 50 is hands together
  under the chest, 100 is arms straight out ahead. One rotation at the
  shoulder; the arm is straight. Hand-held and wrist items ride the arm.
- **Knee bend** 0 to 90 degrees: the shin rotates up toward the back. The
  thigh stays in line with the torso. The foot counter-rotates so the fins
  always point straight to the rear, whatever the bend.
- **Default pose** on the card and when try-out opens: arm reach 50, knee
  bend 90 (the classic horizontal trim position).

### 7.5 Calibration (decided 2026-11-25: tune to reference rigs)

Textbook constants alone make almost every real rig read "Feet-heavy",
because the float point (which Winter's tables do not give) is a free
constant. The float-point fraction and the verdict bands are therefore tuned
so these reference rigs, for a 175 cm, 80 kg diver in salt water at the final
stop in the default pose, give these verdicts. They are the trim model's key
tests:

| Rig | Verdict |
| --- | --- |
| 1. 7 mm wetsuit, AL80 back-mounted, 4 kg integrated (both), 2 kg trim (both), ordinary fins | Level |
| 2. Rig 1 with all 6 kg on a belt | Slightly feet-heavy |
| 3. Rig 2 with jet fins | Feet-heavy |
| 4. Steel 15 L back-mounted, 2 kg backplate weights, 2 kg trim (both), light fins | Slightly head-heavy |

Roll uses the same band widths as pitch.

### 7.6 Verdict and drawing

- Pitch verdict bands on the absolute moment: "Level", "Slightly
  feet-heavy" / "Slightly head-heavy", then "Feet-heavy" / "Head-heavy",
  with thresholds from 7.5. Roll reads "Rolls left / right" on the same
  bands. Constants are named.
- Tilt drawn = clamp(k x pitch moment, -20 degrees, +20 degrees), about the
  float point. Roll is the gauge only.
- Gauges are centred bars, scaled so the "heavy" band reaches about
  two thirds of the half-width; anything beyond is clamped and still reads
  correctly.
- Moments are not shown as numbers on the card; the try-out sheet shows the
  pitch and roll figures in kg·m (lb·ft for imperial divers).

## 8. Artwork

### 8.1 The side view in the existing pipeline

- `FigureView` gains `side`. Side pieces are authored in a new side space,
  400 wide by 200 tall, y down, diver facing left (head at small x), back
  up. `figure_space.dart` gains the side constants.
- Pieces live in `tool/figure/` as `<type>[_<variant>]_side[_<segment>].svg`
  and are declared in `manifest.json` with `"view": "side"` and a new
  `"segment"` key: `torso` (head, torso, thighs), `arm`, `shin`, `foot`, and
  the far-side `farArm`, `farShin`, `farFoot`. `build_figure_artwork.py`
  carries the segment through to `figure_artwork.gen.dart`; the SVG subset
  and its rejection rules are unchanged (no transforms in source).
- Each segment has a joint pivot in side space (shoulder, knee, ankle). The
  painter draws each segment's pieces under a canvas rotation about its
  pivot; the far limbs are drawn first, in the body shade, offset slightly.
- Pieces that cross a joint are split per segment: every suit layer
  (wetsuit, drysuit, undersuit, baselayer, rash guard, vest), gloves, boots,
  socks. Each split carries an overlap shape at the joint so the outline
  does not crack at any bend.
- Item colour, theme palette and contrast rules are the gear figure's, so an
  item looks the same colour in both figures.

### 8.2 Coverage

Every piece that exists for the front/back figure today gets a side
equivalent, plus side pieces for the weight placements (belt, hip pockets,
trim pockets, backplate weights, ankle weights) so typed lead is drawn, not
only labelled. Types with no artwork in the gear figure (hose, tool, tank
band, other, top-level O2 cell and battery) have none here either.

### 8.3 Side placement table

A side-view twin of `FigurePlacement`: for each `EquipmentType` and its
variant attributes, the side zone, the segment, the lateral side, and the
piece. It follows the front/back table's choices (a BCD worn on the back,
lights in the left hand, cameras in the right, the knife on the left calf,
SMB and reel at the butt D-ring, and so on), and the same placement order and
capacity rules. A test covers every `EquipmentType` value.

## 9. The card

### 9.1 Where it sits

Inside the Weights and buoyancy card, between the weights list and the
buoyancy model. At pane widths of 720 dp and up, the weights list and the
figure sit side by side; below that, stacked. The card's other parts are
unchanged.

### 9.2 When it shows

Only when the buoyancy model has an outcome for the dive (it needs the
model's gear terms and tank states). While the model loads, or for a dive
it cannot model, the card shows what it shows today.

### 9.3 What it shows

- The posed figure in the default pose, tilted, drawn from the dive.
- A chip per lead source (typed entry, legacy weight, weights gear) and per
  test item, with its name or type, its weight in the diver's units, and an
  L or R mark when it has a side. Gear is drawn, not chipped, on the card.
- The pitch gauge, the roll gauge, and the verdict line, for example
  "Slightly feet-heavy, rolls right".
- It follows the shared profile cursor the buoyancy chart already uses: tank
  buoyancy, and so pitch and roll, are those at the cursor; with no cursor,
  the model's rest anchor (the final stop).
- A "Try placements" button opens try-out mode.

### 9.4 Try-out mode

A full-height modal sheet (dragging inside a scrolling card fights the
scroll on a phone).

- The same figure, large, with the gauges and the verdict, and pitch and
  roll in kg·m (lb·ft).
- Drag any chip, or any drawn gear piece, to another spot; it snaps to the
  nearest zone that type may use (any zone for lead and test items). Tapping
  a chip or piece cycles its side: both, left, right (centred-only spots
  ignore it).
- "Add test item": a name and a weight (diver's units, 0.1 to 20 kg
  equivalent, validated inline), placed at the waist, then movable like
  anything else.
- Two sliders: Arms (along your sides to reaching ahead) and Knees (straight
  to bent 90 degrees).
- A time slider through the whole dive (decided 2026-11-25), opening at the
  card's cursor (or the rest anchor when there is none), labelled with the
  run time and depth at that moment. Tank buoyancy, the balancing lift, and
  so pitch and roll follow it. A dive with no profile has no time slider and
  uses the rest anchor.
- A "Pieces" list under the figure with every placed element (name, weight,
  spot, side) and a menu per row to move it or change its side. This is the
  non-drag path for screen readers and keyboard users, and the way to reach
  an item covered by another.
- Reset returns to the logged dive and the default pose. Closing discards
  everything.

## 10. Weight side: data and editing

- `DiveWeights` gains a nullable text column `side` (`left`, `right`; null
  means both, split evenly). `DiveWeight` gains `WeightSide? side` with
  `copyWith`. No stored row is rewritten: existing entries read as both.
- A schema rung adds the column (the next version number at build time; main
  is at 382 today). The column joins the sync serializer for weight rows and
  every other place a weight row is copied, exported to the agent-access
  records, or compared, wherever a repo guard expects new columns to be
  listed. UDDF export leaves it out (UDDF has no field for it).
- The weights editor row gains a compact Both / Left / Right choice,
  default Both, for every weight type except backplate (always centred).

## 11. Units and text

- Every weight shown respects the active diver's units; moments show as
  kg·m or lb·ft.
- All new strings in every locale under `lib/l10n/arb/`.
- The figure has a screen-reader summary: the verdict, then the lead and
  its spots.

## 12. Range checks (CLAUDE.md)

- Few and many: one weight entry and no gear; eight weight entries, 25 gear
  items, sidemount plus three stages. Chips stack without overlapping text;
  the Pieces list scrolls with the sheet.
- Long names on chips truncate with an ellipsis; the full name is in the
  Pieces list and the screen-reader text.
- Phone (360 dp) and desktop widths, light and dark.
- Imperial and metric divers.

## 13. Left to the builder

- Exact anthropometric constants and the float-point fraction, from
  Winter's tables, named and documented in code.
- The tilt gain `k`, gauge scaling, and the zone coordinates in side space.
- How the far limbs are offset and shaded.
- Whether try-out uses `showModalBottomSheet` or a full-screen route on
  desktop, following what the What if? sheet does.
- Splitting the trim model, the side placement table and the painter into
  files that stay under the 800-line guard.
- Golden or painter tests for the jointed artwork at knee bends 0, 45 and
  90 and arm reach 0, 50 and 100.
