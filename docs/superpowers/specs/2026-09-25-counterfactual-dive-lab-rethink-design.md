# Counterfactual Dive Lab: Rethink Design

Date: 2026-09-25
Status: Approved design, pending implementation planning
Branch / worktree: `ericgriffin/counterfactual-dive-lab-rethink-f2b015` at
`.claude/worktrees/counterfactual-dive-lab-rethink-f2b015`
Amends: `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md`
(the original spec; it arrives on this branch with the merge described
below and stays the reference for the engine, the scenario model, the page,
persistence and outputs)

## Why a rethink

The original program was completed on branch `worktree-counterfactual-dive-lab`
(five phases, 42 commits, never pushed, no PR). Two things changed while it
sat:

1. PR #1639 (merged 2026-09-13, closing issue #1637) shipped a "What if..."
   action on dive detail that converts the logged dive into an unsaved plan
   and opens it in the planner, with the original profile as a dashed overlay
   and a plan-vs-actual compare strip. It took the `whatIf` menu slot and the
   "What if" label. The lab branch adds a second `whatIf` item with the same
   label, so as built there would be two "What if" features on one dive.
2. main moved 1,771 commits and 65 schema rungs (branch claims v161, main is
   at v226 on 2026-09-25). A dry-run merge conflicts in 28 files, 22 of them
   localization files that are regenerated. Every engine seam the lab
   composes still exists on main.

The two features are not duplicates. They differ on one axis: the planner
gives editing freedom (rebuild the dive however you like); the lab gives
exactness and speed (branch at an exact instant with the actual tissue, CNS
and gas state, follow the swum path or re-plan, express a decision such as
"lost the 50% here" as a named intervention). The rethink decides how they
share one dive.

## Decisions made during the rethink

| Question | Decision |
| --- | --- |
| What drives the rethink? | The overlap with the shipped replan-in-planner flow |
| How do the lab and the replan flow relate? | The lab is the front door; the planner is the deep tool. "What if..." opens the lab; the lab hands its counterfactual off to the planner and keeps the rebuild sheet reachable |
| How much of the built program lands? | Everything: engine, page, persistence and sync, extras, outputs. Nothing is dropped |
| How is the hand-off built? | Approximate before the branch (the converter's waypoints), exact after it (the lab's compiled segments). No planner-wide branch concept in v1 |
| How does it reach main? | One merge of the old branch into this branch, one PR carrying everything, new work as separate commits on top |
| Extra toolbar icon into the lab? | No. Main's entry is menu-only; the old branch's flask toolbar button and its duplicate string key are dropped |
| Lab app bar | One overflow menu: share actions, a divider, then the two planner actions |
| Hand-off on rebreather dives | Disabled with a reason in v1 (the converter cannot author loop segments) |
| Anything the hand-off cannot carry | Said out loud: the service returns notes and the page shows them before pushing the planner |

## Product surface

### Front door

- The existing "What if..." item in both dive-detail menus keeps its label
  (`diveLog_detail_menu_whatIf`) and icon (`Icons.tune`). When the dive is
  lab-eligible it opens the Dive Lab page directly. When it is not, it opens
  today's rebuild sheet (`showWhatIfSheet`) exactly as it does now, so gauge
  dives with a profile keep their current path.
- Eligibility is one pure function in the lab domain,
  `isDiveLabEligible(Dive)`: a primary profile of at least two samples on an
  OC, CCR or SCR dive. Gauge and apnea dives are not eligible. The menu, the
  teaser section builder and the page's empty state all call it.
- No new toolbar icon. The chart's selected point still pre-seeds the branch
  moment when one is selected; otherwise the branch defaults to the start of
  the final ascent (unchanged from the original spec).

### Lab app bar

Save and Saved stay as built. The third button becomes a single overflow
menu:

1. Share as PDF
2. Share scenario file
3. Share image
4. (divider)
5. Open in planner: hands the current draft to the planner as a plan
6. Rebuild in planner...: opens today's rebuild sheet for this dive

Item 5 is disabled on CCR and SCR dives with a tooltip naming the reason.

### Teaser card

Unchanged from the original spec: the "What if" section on dive detail lists
saved scenarios with their one-line summaries and a "New scenario" action,
hidden for ineligible dives.

## The "Open in planner" hand-off

### Service

A pure-Dart service in `lib/features/dive_lab/domain/services/`,
`ScenarioPlanHandoff`, builds a `DivePlan` from the current draft:

```dart
class ScenarioPlanHandoffResult {
  final DivePlan plan;
  final List<ScenarioHandoffNote> notes;   // enum, rendered through l10n
}

ScenarioPlanHandoffResult buildScenarioPlanHandoff({
  required ScenarioRequest request,        // the lab's existing request
  required BranchState branch,
  required ScenarioSettings settings,
  required DiveScenario scenario,
  required Dive dive,
  required List<DiveProfilePoint> profile,
  required List<GasSwitch> gasSwitches,
  required DivePlanState defaults,         // a fresh plan's defaults
  required String planName,
});
```

No Flutter imports. Unit-tested on the lab's synthetic dives.

### Before the branch: the converter

`DiveToPlanConverter.convert` gains one optional parameter, `throughIndex`.
When supplied it replaces the "trim at the last hold at working depth" rule:
the profile is authored through that sample, including any ascent and stops
already done when the branch sits in the ascent. When absent the converter
behaves exactly as today. The hand-off calls it at the rebuild sheet's
default detail level (3) with the branch sample as `throughIndex` and takes
the resulting segments and tanks.

### After the branch: the lab's compiler

`compileScenarioPlan` already produces the remaining-bottom segments with
interventions applied: lost tank removed, gas switched, ascent shifted, or no
remaining segments after `ascendNow`, `shareGas` or `bailOut`. Those segments
are appended after the converter's. Both sides emit `PlanSegment`, so this is
a concatenation.

Tanks come from the lab, not the converter: the lab's effective tank list
after interventions (the dive's tanks minus a lost tank, plus a hypothetical
tank from `switchGas`). `throughIndex` changes which samples the converter
authors, not which cylinders it would include; a deco cylinder first breathed
after the branch must still be on the plan for the engine to schedule it.

### Settings mapping

| Plan field | Source |
| --- | --- |
| `gfLow`, `gfHigh` | `changeGf` intervention when present, else the dive's effective pair (as the converter does today) |
| `ppO2Bottom`, `ppO2Deco` | `ScenarioSettings.ppO2Working`, `ppO2Deco` |
| `sacBottom`, `sacDeco` | the lab's resolved SAC; stressed SAC times the buddy factor when `shareGas` or `bailOut` is present |
| ascent rates, `lastStopDepth`, `gasSwitchStopSeconds` | `ScenarioSettings`, with `ascentPolicy` overrides applied |
| `reservePressure`, `sacStressed` | `ScenarioSettings.reservePressureBar` and the lab's stressed SAC |
| `airBreaks`, `sacFactor`, `problemSolvingMinutes`, everything not listed | the planner defaults (`DivePlanState`) |
| `initialTissueState`, `surfaceInterval` | the residual seed the lab used at the dive start (`request.startCompartments`) and `null`; `seededTissueState` restores compartments untouched when the interval is null |
| `sourceDiveId` | the dive id, so the dashed overlay and compare strip appear unchanged |
| `name` | `planName`, built by the page from the dive title and the scenario's default name |

### Notes: what is not carried

- Replay mode: the planner re-plans the ascent; the replay path is not a
  plan. Note `replayReplanned`.
- `ascentPolicy.extraLastStopSeconds`: the planner's per-depth stop minimum
  (`stopMinimums`) is a floor, not an addition, so the extra seconds are not
  mapped. Note `extraLastStopNotCarried`.
- A plain re-plan draft yields no notes.

The page renders the notes as one line (a snackbar) before pushing the
planner route.

### Presentation

From the lab page's overflow: obtain a fresh plan's defaults the way the
rebuild sheet does (`divePlanNotifierProvider.notifier.newPlan()` then read
the state), build the hand-off, `loadPlan(plan)`, show the notes line, then
`context.push('/planning/dive-planner')` on top of the lab so back returns
to the lab. The plan is loaded into the notifier only after it is fully
built, so a failure never leaves the planner half-loaded. The lab page is
pushed on the root navigator; the implementation plan verifies that the
router resolves from that context before relying on it, and falls back to
the rebuild sheet's pop-then-push sequence if it does not.

### Errors

A converter or compiler failure surfaces as a snackbar naming the reason.
The service never throws on an undiveable scenario; the planner shows its
own issues once the plan is loaded.

## Delivery: one merged PR

### Where

In this worktree, on this branch (at main's tip): `git merge
worktree-counterfactual-dive-lab`. The old branch and its worktree stay
untouched as the reference copy. This worktree is uninitialized: submodule
init, `flutter pub get` and `dart run build_runner build` run first.

### Conflict resolution, by kind

- Eleven ARB files: three-way. A key on the branch that main lacks is kept
  only if the merge base also lacks it; otherwise main deleted it and it is
  dropped. Entries are split by raw text span, not re-serialized.
- Generated `app_localizations*.dart`: regenerated with `flutter gen-l10n`,
  never merged by hand.
- `database.dart`: the schema rung moves from 161 to main's next rung (227
  on 2026-09-25; re-grep `currentSchemaVersion` at merge time). Sites: the
  constant, the `migrationVersions` entry and comment, the `if (from < 161)`
  block, and the migration test, renamed and its literal moved.
  `minimumCompatibleSchemaVersion` is not changed.
- `dive_detail_sections.dart`: `diveLab` is inserted before `dataSources` so
  that one stays last; the tripwire test moves from 23 to 24.
- `plan_engine.dart`: the `_ascentPlanFor` to `ascentPlanFor` rename, applied
  to main's current file.
- `dive_detail_page.dart`: resolved as the front-door routing above, not as
  a second menu item.

### Re-verification against the drift

A clean merge is not a compiling merge.

- Sync registration for `dive_scenarios` is checked site by site against
  main's current list, with the structural sync tests (including
  `sync_parent_refs_completeness_test.dart`) as the backstop.
- `ScenarioSettings` resolution adopts the per-plan gas options and air-break
  defaults that arrived with PR #1639, so a re-plan in the lab and the same
  plan after hand-off agree.
- The architecture guard tests under `test/architecture/` run, since the
  module adds files under `lib/`.
- The duplicate string key `diveLab_action_whatIf` is removed from every ARB.

### New work, as separate commits on top of the merge

1. Converter `throughIndex` parameter with tests.
2. `isDiveLabEligible` and the front-door routing in both menus, with tests.
3. `ScenarioPlanHandoff` with notes, with tests.
4. Lab overflow menu (share actions plus the two planner actions), with tests.
5. Settings adoption of the newer planner defaults.
6. This spec, plus a one-line note at the top of the original spec pointing
   here.

### Verification before the PR opens

Whole-project `flutter analyze` (infos fatal), whole-project `dart format`,
generated-localization staleness check, one full `flutter test` run (never
overlapped with another local run), then a manual macOS smoke: open the lab
from a real logged dive, run an ascend-now and a lost-deco-gas scenario, hand
off to the planner and confirm the dashed overlay and compare strip appear.

### Issue and PR

One umbrella issue describing the lab and this rethink is opened first. The
PR body says `Closes #<that number>`. No attribution lines anywhere.

## Testing

- Ported with the merge: 35 test files covering engine invariants,
  intervention and `.sublab` codecs, repository and sync round-trips, the
  migration, the PDF service, providers and widgets.
- New unit tests (pure Dart, synthetic dives): converter `throughIndex`
  (ends at the sample, keeps ascent and stops already done, trim rule
  untouched when absent); hand-off (continuous at the branch, lost tank
  dropped, hypothetical tank added, GF from intervention, stressed SAC times
  buddy factor for share-gas, residual seed and source dive id carried, notes
  for replay and extra last-stop seconds, no notes for a plain re-plan);
  eligibility across OC, CCR, SCR, gauge, apnea and a one-sample profile.
- New widget tests: the dive-detail menu opens the lab for an eligible dive
  and the rebuild sheet for a gauge dive with a profile; the lab overflow
  lists share and planner actions, disables Open in planner on a loop dive
  with a reason, and on an open-circuit dive loads the plan into the notifier
  and pushes the planner route.
- Registry and schema: tripwire at 24 with `dataSources` last; migration
  test asserts the exact new version.
- Traps on record the port respects: auto-dispose providers need a listener
  in tests; PDF tests run under `tester.runAsync`; list equality by contents;
  `PlanSectionHeader` uppercases labels; Drift's generated `Dive` is aliased
  in tests.

## Explicitly out of scope (this rethink)

- An exact branched plan in the planner (locked prefix, branch state on
  saved plans): a natural v2 if the hand-off proves popular.
- Hand-off on CCR and SCR dives: converter work (loop segments), not lab
  work.
- Universal-import routing for `.sublab` and hypothetical cylinders in the
  buoyancy twin: still deferred, as recorded in the original spec.
- A toolbar icon into the lab.

## Amendments to the original spec

- "Entry points" under `DiveLabPage`: superseded by Front door above. There
  is no toolbar icon and no second menu item; the existing "What if..." item
  routes to the lab when eligible.
- The page's share menu becomes the overflow menu described above.
- The l10n key `diveLab_action_whatIf` no longer exists.
- Schema version: the original spec's v161 claim is replaced by main's next
  rung at merge time.
