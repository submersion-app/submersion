# Realistic Six-Year Sample Logbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the demo-mode sample logbook as about 700 dives over six years with 60 to 100 people, about 25 destinations worldwide plus the home lakes, a full gear story that exercises every equipment tracking and monitoring feature, and scooter routes and boat tracks. Then publish it to the `demo-data` release.

**Architecture:**
- The story planner (`tool/demo_data/src/story/`) decides everything that happens, as pure data:
  - dives, trips, centres and people;
  - gear milestones, scooter dives and planned faults.
- The seeders (`tool/demo_data/src/seeders/`) write that story through the app's own repositories.
- Gear ownership and the kit on each dive come from two pure helpers, `GearTimeline` and `kitFor`. That keeps "never used before it was bought" testable without a database.
- Condition findings are not written directly. The generator writes the signals into dives, observations and incidents, and the app's own findings pass raises them.

**Tech Stack:** Dart and Flutter test, Drift (in-memory test database), the app's repositories, `scripts/demo_data/pack.sh`.

**Spec:** `docs/design/specs/2026-10-27-demo-data-realism-design.md` (read it with this plan). The earlier design is `docs/design/specs/2026-10-26-demo-mode-design.md`.

## Global Constraints

- No change under `lib/`. Generator, tests, README and package only. A feature that cannot be shown without an app change is listed in the PR and the issue.
- About 700 dives (`StoryPlanner.plan` default `diveCount: 700`). The rebreather phase is 15 to 18 dives (`ccrCount = 15 + random.nextInt(4)`).
- 6 to 8 trips in every year. 30 or more dive centres used by dives. 60 to 100 people. 25 or more trip destinations.
- No shape is used more than `ShapeLibrary.maxUses` (3) times. The harvest has 3,083 recreational, 187 deep open circuit, 66 multi-gas deco and 6 rebreather shapes.
- Every name is fictional. Every site and centre comes from `assets/data/dive_sites.json` or `dive_centers.json`. The privacy and coverage checks pass unchanged.
- Limits in `DemoBuilder`: `maxDatabaseZipBytes = 12 * 1024 * 1024` and `maxPackageBytes = 20 * 1024 * 1024`.
- A given seed builds the same logbook (determinism).
- Files stay at 800 lines or fewer (aim for 200 to 400). Paths use `p.join`. Tests restore any global state they replace. Run `dart format .` before each commit.
- No em dashes, en dashes as punctuation, or double hyphens in prose: comments, strings, docs or commit messages.
- No mention of Claude, Claude Code or Anthropic in commits, the PR or the issue.
- Commit by explicit path (`git add <paths>`), never `git add -A`.

## Review Focus

1. **A purchase, service or fill dated inside a trip.**
   - What a diver expects: gear is bought, serviced and filled on home days.
   - Owner: Task 6 (`GearTimeline` moves each date to the nearest earlier day outside every trip) and Task 8.
   - Test: "no purchase, service record or fill falls inside a trip".
2. **Findings must survive the demo preparer's date shift.**
   - What happens: the preparer (`lib/features/demo_mode/data/demo_database_preparer.dart`) shifts every date by whole weeks. Summary rules only use summaries whose source stamp matches the dive.
   - What an explorer expects: they still see the findings.
   - Owner: Task 9.
   - Test: "findings are still raised after the demo date shift".
3. **A generated name equal to a source value.**
   - What happens: the privacy check refuses the package and names the value.
   - What should happen: the name pools are large enough that the builder can skip a refused name deterministically.
   - Owner: Task 3.
   - Test: "a refused name is replaced by the next one from the pool and the plan is otherwise unchanged".
4. **A real harvest thinner than the synthetic test shapes.**
   - What should happen: the build stops before seeding and names each shortfall. It must not quietly fall back to recreational shapes for technical dives.
   - Owner: Task 1.
   - Test: "the builder refuses a plan the shapes cannot cover".
5. **Wall-clock times on far-away destinations.**
   - What happens: tracks and routes use wall-clock-as-UTC seconds, the same convention as dives (`asWallClockUtc`).
   - What should happen: a route recorded at a destination many hours from home still lines up with its dive.
   - Owner: Task 12.
   - Test: "each route starts within the dive's runtime".

---

### Task 1: Shape supply and the budget check

**Files:**
- Modify: `test/tool/demo_data/synthetic_shapes.dart`
- Create: `tool/demo_data/src/shape/shape_budget.dart`
- Modify: `tool/demo_data/src/packaging/demo_builder.dart`
- Test: `test/tool/demo_data/shape_budget_test.dart`, `test/tool/demo_data/demo_builder_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class ShapeShortfall {
    const ShapeShortfall({required this.diveMode, required this.kinds, required this.needed, required this.available});
    final String diveMode; final Set<ShapeKind> kinds; final int needed; final int available;
  }
  List<ShapeShortfall> shapeShortfalls(StoryPlan plan, List<DiveShape> shapes, {int maxUses = ShapeLibrary.maxUses});
  ```
- The synthetic set mirrors the real harvest's scarcity. Use these counts (kinds):
  - 260 recreational;
  - 80 `{deepOpenCircuit}`;
  - 45 `{deepOpenCircuit, multiGasDeco}`;
  - 40 `{multiGasDeco}`;
  - 25 `{trimix, deepOpenCircuit, multiGasDeco}`;
  - 6 ccr.

- [ ] **Step 1: Write the failing tests** in `shape_budget_test.dart`:
  - `'a rebreather phase of 18 dives fits six rebreather shapes'`: a plan of 18 ccr dives against 6 ccr shapes gives `isEmpty`.
  - `'a 19th rebreather dive is a shortfall'`: one entry with `diveMode: 'ccr'`, `needed: 19` and `available: 18`.
  - `'a shape that fits two groups is counted once'`: one `{deepOpenCircuit, multiGasDeco}` shape, 2 dives wanting `{deepOpenCircuit}` and 2 wanting `{multiGasDeco}`. Expect one shortfall with `needed` 4 in total and `available` 3.

  In `demo_builder_test.dart`, add `'the builder refuses a plan the shapes cannot cover'`: build with 5 ccr shapes, expect a `StateError` whose message contains `ccr`, and expect no file written.
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/shape_budget_test.dart test/tool/demo_data/demo_builder_test.dart`. Expected: FAIL (`shapeShortfalls` is not defined).
- [ ] **Step 3: Implement `shapeShortfalls`.**
  - Group the dives by `(diveMode, wantedKinds)`. Walk the groups from the largest kinds set to the smallest.
  - Give each group capacity greedily from the shapes that fit (same mode, `kinds.containsAll`), at `maxUses` per shape. Track remaining uses per shape id.
  - Return a shortfall for each group left short. When two groups share shapes, report a single shortfall summing their demand.
  - In `DemoBuilder`, call it after planning and before `seedAll`. If the list is not empty, throw `StateError('not enough dive shapes: ${...}')`.
  - Update the synthetic counts.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): refuse a story the harvested shapes cannot cover`.

### Task 2: Destinations worldwide

**Files:**
- Create: `tool/demo_data/src/story/destinations.dart`
- Modify: `tool/demo_data/src/story/story_plan.dart` (`Destination`), `tool/demo_data/src/story/destination_life.dart`
- Test: `test/tool/demo_data/destinations_test.dart`

**Interfaces:**
- `Destination` gains these fields:
  - `minPhase` (`StoryPhase`, default `recreational`);
  - `nearHome` (`bool`, default `false`), for weekend trips;
  - `scooterOk` (`bool`, default `true`);
  - `nameRegion` (`String`), a key into Task 3's name pools;
  - `boatNames` (`List<String>`) and `resortNames` (`List<String>`): fictional, at least 2 each where they apply.
- Produces:
  - `const Destination homeDestination` (the Bavarian lakes, as `StoryPlanner.home` today);
  - `const List<Destination> tripDestinations` (25 or more).

  `StoryPlanner.home`, `tropical` and `mediterranean` are removed, and callers use these instead.
- Candidate destinations to settle against the catalogue. `country` and `region` must equal catalogue strings exactly.
  - Red Sea (Egypt; one entry a liveaboard, one a resort)
  - Sudan (liveaboard, technical)
  - Maldives (liveaboard)
  - Indonesia: Bali, Raja Ampat (liveaboard), Komodo
  - Philippines: Cebu, Bohol
  - Thailand: Similan (liveaboard), Koh Tao
  - Malaysia: Sabah
  - Chuuk in Micronesia (technical wrecks)
  - Palau
  - Marshall Islands (technical wrecks)
  - Japan
  - Queensland, Australia
  - Mexico: the Quintana Roo cenotes (freshwater, `scooterOk: false`), and Cozumel
  - Curaçao
  - Dominican Republic
  - Colombia
  - Galápagos, Ecuador (liveaboard)
  - Mediterranean wrecks (France, Croatia, Malta; `minPhase: technicalOc`)
  - Cyprus
  - Norway (cold sea)
  - Austrian lakes and Swiss lakes (freshwater, `nearHome: true`)

- [ ] **Step 1: Write the failing tests** in `destinations_test.dart`, using `Catalog.load('assets/data')`:
  - `'at least 25 trip destinations with unique keys'`
  - `'every destination has at least 6 catalogue sites in its country and region'`
  - `'every destination has a catalogue dive centre in its country'`
  - `'destinations span the world'`. Assert 15 or more distinct countries; at least one destination with a site longitude below -30, one between -30 and 60, and one above 60; and at least 3 south of the equator.
  - `'freshwater beyond home'`: 3 or more freshwater destinations including home, and the cenotes have `scooterOk == false`.
  - `'every destination names known species and built-in site types'`:
    - each key has 3 or more `destinationSpecies` names present in `assets/data/species.json`;
    - each key has `destinationSiteTypes` ids from `lib/core/database/site_type_seed.dart` (lake, quarry, reef, wall, wreck, muck, cenote, cavern, spring, kelp_forest...).
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/destinations_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 3: Implement** `destinations.dart`, and extend `destination_life.dart` with every new key.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): about 25 destinations worldwide plus the home lakes`.

### Task 3: People

**Files:**
- Create: `tool/demo_data/src/story/name_pools.dart`, `tool/demo_data/src/story/people.dart`
- Modify: `tool/demo_data/src/story/story_plan.dart` (`FictionalPerson`), `tool/demo_data/src/seeders/diver_seeder.dart`, `tool/demo_data/src/seeders/dive_extras.dart`, `tool/demo_data/src/seeders/training_seeder.dart`
- Test: `test/tool/demo_data/people_test.dart`

**Interfaces:**
- `enum PersonRole { regular, techTeam, instructor, guide, boatBuddy }`.
- `FictionalPerson.role` becomes a `PersonRole`. Add `String? destinationKey` (for guides and boat buddies) and `CertLevel? course` (for instructors).
- `const Map<String, ({List<String> first, List<String> last})> namePools`. Region keys include de, en, id, th, ph, ar, es, fr, it, hr, ja, mh. Each pool has 25 or more first names and 25 or more last names.
- `class PeopleFactory`:
  - `PeopleFactory(Random random, {Set<String> refused = const {}})`;
  - `FictionalPerson make(PersonRole role, {required String nameRegion, String? destinationKey, CertLevel? course})`;
  - `List<FictionalPerson> get all`.

  Full names are unique, and a name in `refused` is skipped.
- `DiverSeeder` maps `PersonRole` to the certification level and notes it writes today.

- [ ] **Step 1: Write the failing tests:**
  - `'names are unique and drawn from the region pool'`
  - `'a refused name is replaced by the next one from the pool and the plan is otherwise unchanged'`: build twice with and without one refused name. The people differ only at that index, and later random draws are unchanged.
  - `'the same seed gives the same people'`
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/people_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Draw both name parts from a separate `Random` stream derived from the seed, so a skipped name does not shift the planner's draws. Update the three seeders for the enum.
- [ ] **Step 4: Run** the test, plus `test/tool/demo_data/people_places_seeder_test.dart` and `training_seeder_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): a people factory with regional fictional names`.

### Task 4: The story: 700 dives, trips, centres, buddies and scooter dives

**Files:**
- Create:
  - `tool/demo_data/src/story/schedule.dart` (slots and trips)
  - `tool/demo_data/src/story/dive_spec.dart` (`_spec` moved out)
  - `tool/demo_data/src/story/course_plan.dart`
  - `tool/demo_data/src/story/milestones.dart`
  - `tool/demo_data/src/story/buddy_picker.dart`
- Modify: `tool/demo_data/src/story/story_planner.dart` (orchestration only, under 300 lines), `story_plan.dart`, `tool/demo_data/src/seeders/dive_tank_plan.dart`
- Test: `test/tool/demo_data/story_planner_test.dart` (rewritten expectations), `test/tool/demo_data/dive_tank_plan_test.dart`

**Interfaces:**
- **Milestones:** `enum StoryMilestone { firstDive, firstTrip, ownRegulator, advanced, firstColdLake, drysuit, photo, airIntegrated, nitrox, techStart, trimix, scooter, ccrCourse, cellSwap }`. `StoryPlan.milestones` is a `Map<StoryMilestone, int>` of dive numbers.
- **`PlannedTrip`:**
  - `centerId` is replaced by `List<String> centerIds` (1 or 2);
  - add `List<String> guideIds`, `List<String> boatBuddyIds`, `String? boatName` and `String? resortName`.
- **`PlannedDive`:** add `String? centerId`, `bool scooter` and `bool boat`.
- **Course dives:** `courseDives(int diveCount, int ccrCount)` returns, for 700 dives:
  - OW (1, 4), AOW (25, 29), rescue (90, 91), deep (150, 153);
  - deco (250, 253), trimix (380, 383), ccr (ccrStart, ccrStart + 4).

  Nitrox is issued 3 days before dive 50. The technical phase starts at dive 250.
- **Dive kinds by destination and phase:**
  - Recreational phase: `{recreational}`.
  - Technical phase at home, or at a destination with `minPhase: technicalOc`:
    - 40% `{deepOpenCircuit}` (28 to 45 m);
    - 45% `{multiGasDeco}` (35 to 55 m);
    - 15% `{deepOpenCircuit, multiGasDeco}` (50 to 70 m) once trimix is held.
  - Technical phase at a tropical destination: 80% `{recreational}`.
  - Rebreather phase: `{ccr}`.
- **`planTanks`** gives trimix back gas (21/35 at 50 to 60 m, 18/45 deeper) to any dive deeper than 45 m after the trimix cert, whatever the shape's gas.
- **Buddies:**
  - Home dives get 1 or 2 regulars, chosen with weights `1 / rank`.
  - Technical and rebreather dives at home, or at technical destinations, get 1 or 2 of the tech team.
  - Trip dives get the trip's guide on 70% of dives, a boat buddy on 40%, and a regular who travelled along on 25% of trips.
  - Course dives add the course instructor.
  - Each trip gets 1 or 2 new guides and 1 to 3 new boat buddies, so revisits bring new faces.
- **Scooter dives:** from the `scooter` milestone, a technical or rebreather dive is a scooter dive with probability 0.3, when its destination has `scooterOk` and it has 2 or more tanks or is a rebreather dive.
- **Trip shape:**
  - Liveaboards: 6 to 10 days at 3 or 4 dives a day.
  - Resorts: 5 to 12 days at 2 or 3 dives a day.
  - `nearHome` trips: 2 to 3 days at 2 dives a day.
  - Each year gets 6 to 8 trips. Home weekends fill the rest of the year's target.
  - Dives per year ramp up: about 80 in year 1, then about 124 a year.
  - Trips never overlap, and there are at least 10 days between trips.

- [ ] **Step 1: Write the failing tests.** Rewrite `story_planner_test.dart` with these, keeping the existing order, certification and determinism tests:
  - `'about 700 dives over six years before the anchor, in order'`: `plan.dives.length == 700`.
  - `'15 to 18 rebreather dives at the end'`
  - `'6 to 8 trips in every year, never overlapping'`
  - `'at least 25 destinations and 30 dive centres used'`: the distinct `d.centerId`s.
  - `'every trip dive's centre is one of its trip's centres'`
  - `'60 to 100 people, skewed to a few'`: the top 8 people hold 50% or more of all buddy appearances, and 30 or more people appear on 5 or fewer dives.
  - `'guides dive only at their destination, instructors only on their course'`
  - `'the tech team appears only on technical or rebreather dives'`
  - `'scooter dives come after the scooter milestone and never at a cenote'`
  - `'no technical-phase dive deeper than 45 m uses a recreational shape kind'`

  In `dive_tank_plan_test.dart`, add `'a 60 m dive after the trimix card breathes trimix'`.
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/story_planner_test.dart test/tool/demo_data/dive_tank_plan_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the split and the new rules. `shapeShortfalls(plan, syntheticShapes())` must be empty for seed 42.
- [ ] **Step 4: Run** both tests, plus `shape_budget_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): plan 700 dives with 6 to 8 trips a year and a real cast`.

### Task 5: The gear catalogue: full complement, assemblies and installs

**Files:**
- Modify: `tool/demo_data/src/seeders/gear_catalog.dart`
- Create: `tool/demo_data/src/seeders/gear_assemblies.dart`
- Test: `test/tool/demo_data/gear_catalog_test.dart`

**Interfaces:**
- **`DemoGear` changes:**
  - `boughtAtDive` is replaced by `StoryMilestone bought` and `int boughtOffset` (dives after the milestone, default 0);
  - add `GearDeparture? leaves`, with `({StoryMilestone at, int offset, EquipmentStatus status})` and status one of sold, lost, retired or loaned;
  - add `Map<String, Object> attributes`, keyed by `EquipmentAttrKeys` (`hose_type`, `hose_length_m`, `volume_l`, `working_pressure_bar`, `tank_material`, `last_hydro_test`, `last_visual_inspection`, `thickness_mm`...);
  - add `Set<KitUse> uses`, with `enum KitUse { always, warm, temperate, cold, tech, ccr, scooter, photo, night, spare }`.
- **Assemblies:**
  - `class DemoAssembly { const DemoAssembly(this.parentKey, this.parts); final String parentKey; final List<(String key, String role)> parts; }`;
  - `const List<DemoAssembly> demoAssemblies`.
- **Installs:**
  - `class DemoInstall { const DemoInstall({required this.childKey, required this.parentKey, this.slot, required this.at}); ... final StoryMilestone at; }`;
  - `const List<DemoInstall> demoInstalls`.
- **The kit:** the full list as approved in the spec ("Bought as the diver progresses").
  - **Regulator assemblies:**
    - `reg-warm`: first stage, primary, octopus, inflator hose `lpi` 0.6 m, HP hose `hp` 0.8 m, SPG, compass.
    - `reg-cold`: a sealed first stage, primary, octopus, inflator hose, and a transmitter that replaces the SPG from the `airIntegrated` milestone.
    - `reg-left` and `reg-right` for doubles: a 2.1 m long hose `lp` on the right primary, a necklace second stage on the left, button SPG, transmitter on the right.
    - `reg-stage-1` and `reg-stage-2`: first stage, second stage, 1 m hose, button SPG.
    - `reg-bailout`.
  - **Installed children:** `o2-cell-1` to `o2-cell-3` in the rebreather (slots 1 to 3, at `ccrCourse`); `o2-cell-2b` in slot 2 (at `cellSwap`); the rebreather battery; the scooter battery.
  - **Departures:**
    - the jacket BCD (sold, at techStart plus 10);
    - `reg-warm` (loaned, at ccrCourse minus 20);
    - the first mask (lost on a trip, with `mask-2` bought after it);
    - the first computer (retired, at airIntegrated);
    - `o2-cell-2` (retired, at cellSwap);
    - one hose and one fin strap, retired and each replaced;
    - one wished-for item (status `wanted`, never on a dive).
  - **Current statuses:** `reg-cold` is `inService`, one item is `needsService`, and two items are `spare`.

- [ ] **Step 1: Write the failing tests:**
  - `'every regulator assembly has a first stage, a second stage and a hose'`
  - `'every assembly part and install child exists, and no part is in two assemblies'`
  - `'every equipment status appears'`: all 9 values.
  - `'the kit covers each kind of diving'`, checked against these lists:
    - warm: mask, fins, wetsuit, bcd, regulator, computer, smb;
    - cold: drysuit, undersuit, hood, gloves, regulator, light;
    - tech: backplate, wing, harness, tankBand, two first stages, light ×2, reel, knife or tool;
    - ccr: rebreather, o2Cell ×3, battery, regulator (bailout);
    - scooter: dpv;
    - photo: housing, port, strobe, arm, tray.
  - `'cells and batteries are installs, never assembly parts'`
  - `'hoses carry their type and length'`
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/gear_catalog_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the catalogue. Keep `demoGearProductNames` working for the privacy allow list.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): a full kit with regulators built from their parts`.

### Task 6: Gear timeline and the kit on each dive

**Files:**
- Create: `tool/demo_data/src/seeders/gear_timeline.dart`, `tool/demo_data/src/seeders/dive_kit.dart`
- Test: `test/tool/demo_data/dive_kit_test.dart`

**Interfaces:**
- `class GearTimeline`:
  - `GearTimeline(StoryPlan plan, List<DemoGear> gear)`;
  - `DateTime boughtOn(String key)`;
  - `DateTime? leftOn(String key)`;
  - `bool ownedOn(String key, DateTime when)`;
  - `DateTime homeDayOnOrBefore(DateTime when)`.

  It is public, because the service, fill and life seeders use it.
- `({List<String> gearKeys, String? setKey, List<DiveWeight> weights}) kitFor(PlannedDive d, GearTimeline t, {required bool photo})`.
- **Suit by the coldest water** (the destination's range, and at home the month):
  - 26 °C or warmer: 3 mm;
  - 20 to 26 °C: 5 mm;
  - 14 to 20 °C: 7 mm with hood;
  - below 14 °C: drysuit with undersuit, hood and gloves.

  Before the drysuit milestone, the 7 mm suit is used and lake dives stay in the warm months.
- **Regulator:** `reg-cold` below 14 °C, `reg-warm` above that once owned, and none before `ownRegulator` (rented).
- **Weights:** follow the suit and the tanks.

- [ ] **Step 1: Write the failing tests:**
  - `'no dive uses gear before it was bought or after it left'` (over the whole seed-42 plan)
  - `'a drysuit only below 14 degrees, a wetsuit only at 14 or above'`
  - `'early trips before the own regulator carry no regulator'`
  - `'scooter dives carry the scooter, rebreather dives the rebreather and bailout'`
  - `'no purchase, service record or fill falls inside a trip'` (for `boughtOn`; Task 8 extends it)
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/dive_kit_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): ownership timeline and the kit each dive used`.

### Task 7: Seed the gear and attach it to dives

**Files:**
- Modify: `tool/demo_data/src/seeders/gear_seeder.dart` (items, attributes, assemblies, installs, sets), `tool/demo_data/src/seeders/dive_seeder.dart`, `tool/demo_data/src/seeders/seed_context.dart` (add `GearTimeline timeline`), `tool/demo_data/src/seeders/demo_seeding.dart`
- Create: `tool/demo_data/src/seeders/gear_cylinder_seeder.dart` (computers, transmitters, cylinder configs, passports and fills, presets, moved out of `gear_seeder.dart`)
- Test: `test/tool/demo_data/gear_seeder_test.dart` (new), and update `gear_trip_seeder_test.dart`

**Interfaces:**
- **Installs:** an install child is created with `parentEquipmentId`, plus attributes `cell_slot` (value_num) and `installed_date` (ms of the install date). It has no `equipment_components` row. This fixes today's cells-as-components.
- **Gear on each dive:**
  - The dive seeder replaces `_gear` with `kitFor` plus `GearExpander.expand`. The index comes from `ComponentsIndex.fromRows(await EquipmentComponentRepository()...)`, with `isActive` = owned on the dive date.
  - Each dive tank gets `equipmentId` (an owned cylinder), `regulatorEquipmentId` (the assembly on it) and `transmitterSerial` (when that assembly has a fitted transmitter).
  - `Dive.diveCenter` is set from `d.centerId`.
- **Sets:**
  - "Warm water single", "Cold lake drysuit", "Tech doubles" and "Rebreather", plus "Scooter" and "Camera";
  - `isDefault` on warm, `autoApply` on lake (with the existing geofence), `showFigure` on tech.
- **Transmitters:** every transmitter item gets a `transmitters` row, configured, with `equipmentId` set to the item and a non-blank serial. These are the one in `reg-cold` and the one on `reg-right`. The dive tanks carry the same serial.

- [ ] **Step 1: Write the failing tests** in `gear_seeder_test.dart`, using `seedContext()` from `seed_harness.dart`:
  - `'assembly parts ride on dives under their assembly'`: every `dive_equipment` row of a hose has `via_equipment_id` equal to a regulator.
  - `'cells are installed children with slot and date, never components'`
  - `'every usage path counts somewhere'`. There are dives linked through each of:
    - `dive_equipment`;
    - `dive_tanks.equipment_id`;
    - `dive_tanks.regulator_equipment_id`;
    - a transmitter serial;
    - a rebreather parent.
  - `'trip dives name their dive centre'`
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/gear_seeder_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the test, plus `gear_trip_seeder_test.dart`, `dive_seeder_test.dart` and `coverage_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): seed the kit and carry its parts onto every dive`.

### Task 8: Service clocks on schedule, two overdue now

**Files:**
- Create: `tool/demo_data/src/seeders/gear_service_seeder.dart` (replaces the service part of `_storageAndService`)
- Test: `test/tool/demo_data/gear_service_test.dart`

**Interfaces:**
- **Kinds:** every built-in service kind (hydro, vip, o2-clean, regulator-service, computer-battery, transmitter-battery, bcd-inspection, drysuit-seals, scrubber-repack, o2-cell-replacement, rebreather-annual, general-service) gets records on its interval from ownership to the anchor.
- **Schedules:** the app's auto-attach creates them through the repository method at `service_schedule_repository.dart` around line 165 (call it per item if `createEquipmentWithTags` does not). Add hand-made schedules for the items that need a different interval.
- **Clocks today:**
  - two items left overdue: `reg-cold` (its service is now booked; the item is `inService`) and the visual inspection of `tank-12`;
  - two or more due soon: the rebreather annual service and the computer battery.
- **Dates:** every record lands on `timeline.homeDayOnOrBefore(...)`.

- [ ] **Step 1: Write the failing tests:**
  - `'every built-in service kind has a clock or a record'`
  - `'exactly two clocks are overdue and at least two are due soon at the anchor'`: evaluate with `ServiceDueEngine().evaluate(...)` for each active item, at `now = ctx.anchor`.
  - Extend `'no purchase, service record or fill falls inside a trip'` with service records and fills.
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/gear_service_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): service history for every clock, two overdue today`.

### Task 9: Faults written into the data, and the findings they raise

**Files:**
- Create: `tool/demo_data/src/seeders/gear_faults.dart` (pure plan), `tool/demo_data/src/seeders/fault_signals.dart` (sample transforms)
- Modify: `tool/demo_data/src/seeders/dive_seeder.dart`, `tool/demo_data/src/seeders/misc_seeder.dart` (link the incident to `reg-cold`)
- Test: `test/tool/demo_data/gear_condition_test.dart`

**Interfaces:**
- **The fault plan:**
  - `class FaultPlan { final List<int> freeFlowDives; final List<int> lightFloodDives; final List<int> dropoutDives; final List<int> cellSwapDives; final List<int> divergentCellDives; }`;
  - `FaultPlan planFaults(StoryPlan plan, GearTimeline t)`.
- **Transforms:**
  - `List<(int, double)> withDropouts(List<(int, double)> pressures, {required double gapFraction, required Random random})` cuts runs of samples so the gaps total `gapFraction` of the span. Each gap is longer than 3 × the cadence.
  - `int cellMv(double ppO2, double gainMvPerBar)`. A healthy gain is 48 to 52 mV/bar. Every rebreather sample gets `o2SensorMv1..3`.
- **What the data must hold** (thresholds from `equipment_condition_engine.dart`):
  - **`issueRecurring` and `issueColdCorrelated` on `reg-cold`:**
    - 4 `freeFlow` observations, each with its `diveId`, within its last 20 dives, all in water below 10 °C;
    - at least 5 of its dives at 10 °C or warmer with no issue.
  - **`issueDeepCorrelated` on a light:** 3 `flood` observations on dives of 30 m or deeper, and 5 or more shallow dives without one.
  - **`incidentLinked`:** the existing moderate free-flow incident with `equipmentId` set to `reg-cold`.
  - **`transmitterDropoutHigh` on the doubles' transmitter:** 3 of its last 5 dives with `gapFraction` of 0.12 or more, and earlier dives clean.
  - **`cellDivergent` on `o2-cell-3`:**
    - the last 5 rebreather dives have cell 3 reading 0.15 bar above the other cells' median in 30% or more of the samples (p95 above 0.1 on 3 or more dives);
    - `o2-cell-2` drifted low earlier, then `o2-cell-2b` was installed at `cellSwap`.

- [ ] **Step 1: Write the failing tests:**
  - `'the findings pass raises every planned finding'`: after `seedAll(ctx)`, `equipment_findings` holds rows for `issueRecurring`, `issueColdCorrelated`, `issueDeepCorrelated`, `incidentLinked`, `transmitterDropoutHigh` and `cellDivergent`.
  - `'findings are still raised after the demo date shift'`: apply the preparer's week shift to the seeded test database, run `EquipmentFindingsPass` again, and expect the same rule ids.
  - `'withDropouts gaps exceed three cadences and total the fraction'` (pure).
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/gear_condition_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** If the date shift test shows the summary stamps go stale, have the derived seeder or preparer path rebuild summaries the way the app's launch sweep does. Do not change `lib/`: if only an app change can fix it, stop and report.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): faults in the dive data that raise condition findings`.

### Task 10: Where gear is, who has it, what left

**Files:**
- Create: `tool/demo_data/src/seeders/gear_life_seeder.dart` (locations, moves, the loan, shares, ownership transfer, observations with status ok, the lost and sold items, the wish list). It replaces the rest of `_storageAndService`.
- Test: `test/tool/demo_data/gear_life_test.dart`

**Interfaces:**
- **Locations:** garage shelf (storage), travel bag (storage), regulator service shop (serviceShop), and a person location for the buddy holding the loaned `reg-warm` (kind `person`). Moves are in date order. `reg-cold` sits at the shop now.
- **Ownership:** the sold jacket BCD goes through `EquipmentTransferService` to the partner profile, as today. The fins are shared with the partner.
- **Routine checks:** a status `ok` observation every 10th dive on the primary regulator in use.

- [ ] **Step 1: Write the failing tests:**
  - `'the loaned regulator is at a person location'`
  - `'every item's moves are in date order and end where its status says'`
  - `'the lost mask was last on a trip dive and its replacement bought after'`
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/gear_life_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): gear locations, a loan, a sale and a loss`.

### Task 11: Trips and centres that match the dives

**Files:**
- Modify: `tool/demo_data/src/seeders/trip_seeder.dart`, `tool/demo_data/src/seeders/places_seeder.dart`
- Test: `test/tool/demo_data/gear_trip_seeder_test.dart`, `test/tool/demo_data/people_places_seeder_test.dart`

**Interfaces:**
- **Trips:** names, boats and resorts come from `PlannedTrip.boatName` and `resortName`. Packing is the union of `kitFor` over the trip's dives. Trip cylinders and fills are recorded for every trip on rental tanks.
- **Centre gear notes** come from what was actually rented: a regulator before `ownRegulator`, tanks and weights on every trip. Each centre has 1 to 3 notes.
- **Privacy:** add the fixed boat and resort names to `public_vocabulary.dart` only if the privacy check needs them.
- **Checklists:** the pre-dive checklist sessions in `planning_seeder.dart` name items from the dive's own kit (`kitFor`), so gear appears on the checklist.

- [ ] **Step 1: Write the failing tests:**
  - `'every trip's packing list is the kit its dives used'`
  - `'every centre a dive used has a gear note'`
  - `'liveaboard names vary between trips'`
  - `'checklist gear items are from that dive's kit'`
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): trips, rentals and centres that match the dives`.

### Task 12: Scooter routes and boat tracks

**Files:**
- Create: `tool/demo_data/src/seeders/track_seeder.dart` (moved from `PlanningSeeder._tracks`), `tool/demo_data/src/seeders/route_shapes.dart` (pure)
- Modify: `tool/demo_data/src/seeders/planning_seeder.dart`, `demo_seeding.dart`
- Test: `test/tool/demo_data/track_test.dart`

**Interfaces:**
- **Route shapes:** `enum RoutePattern { outAndBack, loop, reefRun }`, and `List<NavTrackPoint> scooterRoute(RoutePattern p, {required List<ShapeSample> samples, required DateTime start, required Random random})`:
  - north and east offsets in metres;
  - 30 to 60 m a minute while scooting, slower on the descent and the stops;
  - depth taken from the dive's own samples at the same second;
  - 5 s spacing;
  - timestamps from `_wallSeconds`.
- **Boat tracks:** a GPS track for about 40% of resort boat days, harbour to site to harbour. The harbour is a fixed point 3 to 12 km from the trip's sites.
- **Dive exposure:** the scooter and its battery gain exposure through the scooter appearing in each scooter dive's gear rows (Task 7).

- [ ] **Step 1: Write the failing tests:**
  - `'every scooter dive has one route linked to it'`
  - `'each route starts within the dive's runtime and follows its depth'`: each point's depth is within 1 m of the dive sample at that second.
  - `'at least 20 boat tracks, each returning to its harbour'`: first and last point within 100 m of each other, and some point within 300 m of the dive's site.
- [ ] **Step 2: Run** `flutter test test/tool/demo_data/track_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(demo-data): scooter routes for every scooter dive and boat tracks`.

### Task 13: Limits, README and the full suite

**Files:**
- Modify: `tool/demo_data/src/packaging/demo_builder.dart` (limits), `tool/demo_data/README.md`, `test/tool/demo_data/demo_builder_test.dart`

- [ ] **Step 1: Write the failing test** `'the limits are 12 MB for the database and 20 MB for the package'` (asserts the two constants).
- [ ] **Step 2: Run** it. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - Set the two constants.
  - Update the README: the story (700 dives, the phases, the rebreather phase held to 15 to 18 dives by the 6 rebreather shapes), the limits, and the shape budget refusal.
  - Add a line under "Limits" saying the harvest must cover the plan.
- [ ] **Step 4: Verify the whole branch.**
  - Run `dart format .`, `flutter analyze`, `flutter test test/tool/demo_data test/architecture test/shared`, then `scripts/run_all_tests.sh`, with logs written to the scratchpad.
  - Expected: all pass. Any failure goes in the report by name, including unrelated ones (for example the local Homebrew ffmpeg smoke test).
- [ ] **Step 5: Commit** `docs(demo-data): describe the larger story and its limits`.

### Task 14: Build, walk the app, publish, open the PR

- [ ] **Step 1: Keep the harvest safe.**
  - Copy `/private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion--claude-worktrees-demo-mode-bundled-data-3b6a53/679dec60-dbc3-431d-8db2-80f141f409ed/scratchpad/harvest_real` and its sibling `demo_photos` to `~/.submersion-demo-data/` (outside the repository).
  - Expected: `shapes.jsonl.gz` is 17,786,697 bytes, and there are 23 photos plus `credits.json`.
- [ ] **Step 2: Build:** `scripts/demo_data/pack.sh ~/.submersion-demo-data/harvest_real ~/.submersion-demo-data/demo_photos <scratchpad>/pkg_out 42`.
  - Expected: both checks pass, the database is under 12 MB compressed and the package under 20 MB. Record the actual sizes.
  - If the privacy check refuses a name, add it to the factory's refused set and rebuild.
- [ ] **Step 3: Walk the app in demo mode** with the built package (macOS app from this worktree). Confirm each of these shows the new data:
  - the equipment list and an assembly's parts;
  - a cell's slot;
  - service due, overdue and due soon;
  - condition findings;
  - the loaned item;
  - trips, buddies and dive centres;
  - the world map;
  - a scooter route and a boat track.

  Capture screenshots for the maintainer.
- [ ] **Step 4: Ask the maintainer which release the issue targets,** then open the issue (type Feature, with that Release field) and the PR with `Closes #<issue>`. The PR touches no UI paths, so delete the Screenshots section. Wait for green checks.
- [ ] **Step 5: Publish** (pre-approved by the maintainer): download the release's current `demo-manifest.json`, merge, then `gh release upload demo-data <zip> <out_dir>/demo-manifest.json --clobber`. Never mark the release latest. Confirm by downloading the manifest again and checking the new entry's size and SHA-256.
