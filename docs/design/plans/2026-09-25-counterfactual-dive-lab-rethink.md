# Counterfactual Dive Lab Rethink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the completed Dive Lab program on main in one PR, re-homed as the front door for "What if..." on dive detail, with a hand-off that opens the current scenario in the planner.

**Architecture:** Merge branch `worktree-counterfactual-dive-lab` (42 commits, five finished phases) into this branch, which sits at main's tip, and resolve the six code conflicts plus the localization files. Then add the new work as ordinary commits: an eligibility function and front-door routing, a converter parameter that authors a logged dive through a chosen sample, a pure-Dart hand-off service that concatenates the converter's segments with the lab's compiled remainder into a `DivePlanState`, and a lab overflow menu with "Open in planner" and "Rebuild in planner...".

**Tech Stack:** Flutter / Dart, Riverpod (StateNotifier and Future providers), Drift (schema rung and sync registration), go_router, flutter_test, python3.14 for text surgery on generated or merged files.

**Spec:** `docs/superpowers/specs/2026-09-25-counterfactual-dive-lab-rethink-design.md` (the rethink) and `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md` (the original program, which arrives with the merge in Task 1). Executors read both.

**Deviations from the spec, decided while planning (the code is the source of truth):**

- The hand-off returns a `DivePlanState`, not a `DivePlan`. The planner notifier's `loadPlan` takes a `DivePlanState`, and the converter already returns one; the lab's compiled `DivePlan` is mapped through `stateFromDivePlan`.
- The converter parameter is `throughTimestamp` (an absolute profile timestamp), not an index. The converter sorts samples and inserts gas-switch waypoints, so an index into the caller's profile would not survive.
- Apnea has no `DiveMode`; there is nothing to test for. Eligibility is "not gauge, and at least two profile samples", exactly the rule the old branch and main's menu already use.
- A lost cylinder that was breathed before the branch stays on the plan (the converter's segments reference it) and the hand-off emits a note. Removing it would leave segments pointing at a missing tank.
- "Settings adoption" needs no separate task: the compiled plan carries no per-plan ppO2 or air-break values, so the hand-off sets ppO2 from the scenario settings and air breaks, SAC factor, problem-solving minutes and END target from the planner defaults. Task 6 tests that mapping.

## Global Constraints

- No em-dashes, en-dashes as punctuation, double hyphens or spaced hyphens in any output, including code comments, commit messages and ARB values.
- No mention of Claude, Claude Code or Anthropic anywhere in the repository, commit messages, issue or PR text.
- Run `dart format .` on the whole project before every commit; CI treats analyzer infos as fatal, so `flutter analyze` on the whole project must print "No issues found".
- Every new string goes through `AppLocalizations`, with the key added to all eleven ARBs: `app_ar`, `app_de`, `app_en`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`. Only `app_en.arb` is alphabetical; in the other ten, insert next to the neighbouring `diveLab_` keys. Regenerate with `flutter gen-l10n` and commit the generated `lib/l10n/arb/app_localizations*.dart` with the ARBs.
- Everything displaying a unit goes through `UnitFormatter` and respects the active diver's settings.
- TDD: the failing test is written and run before the implementation.
- Stage explicit paths only; never `git add -A` or `git add .` (a sibling worktree's edits and a stale submodule pointer get swept in). Never use bare `git stash`.
- Build paths with `p.join`, never string concatenation; temporary space through `Directory.systemTemp`.
- The schema rung is main's `currentSchemaVersion + 1` at merge time. It is 227 on 2026-09-25; re-grep before editing and substitute everywhere this plan says 227.
- Local test runs are I/O bound: never run two `flutter test` invocations at once, and run the full suite exactly once at the end.
- The old worktree `.claude/worktrees/counterfactual-dive-lab` and its branch are the reference copy. Never edit, rebase or delete them.

## Review Focus

Inputs the spec implies but did not spell out, most likely to bite first. Each line names the task whose tests pin it.

1. A branch at the very first sample (branch seconds 0). The converter yields fewer than two waypoints and no segments; the hand-off must still produce a plan made of the lab's segments alone and must not throw. Task 6.
2. A branch during the final ascent, inside a deco stop. The converter must keep the ascent and stops already done up to that sample rather than trimming back to the last deep hold, or the plan restarts the ascent from the bottom. Task 5.
3. A lost cylinder that was already breathed before the branch. The converter's segments reference it; dropping it from the plan leaves segments pointing at a missing tank. The tank stays and a note says so. Task 6.
4. A rebreather dive reaching the hand-off. The converter cannot author loop segments; the service must refuse loudly rather than produce an open-circuit plan of a loop dive, and the menu item must be disabled with a reason. Tasks 6 and 8.
5. Opening the planner from a page pushed on the root navigator. If `context.push` does not resolve the router from the lab page, the hand-off silently does nothing. The widget test in Task 8 runs under a real `GoRouter` and asserts the matched location.

---

### Task 0: Initialize the worktree

This worktree was created empty of build state: no submodules, no `.dart_tool`, no generated code.

**Files:** none changed in git.

- [ ] **Step 1: Initialize submodules and dependencies**

Run:

```bash
git submodule update --init --recursive && flutter pub get
```

Expected: the libdivecomputer submodule checks out; `flutter pub get` ends with "Got dependencies".

- [ ] **Step 2: Generate code**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: about 65 s, ends with "Succeeded after ...". If the Bash tool refuses the command, run `bash scripts/setup.sh` instead, which performs the same steps.

- [ ] **Step 3: Confirm the baseline is clean**

Run:

```bash
flutter analyze
```

Expected: "No issues found!". If not, stop: main is red and the problem is not this branch (see the `main-red-1686` memory note).

---

### Task 1: Merge the old branch and resolve the conflicts

**Files:**
- Modify (conflict resolution): `lib/core/database/database.dart`, `lib/core/constants/dive_detail_sections.dart`, `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `lib/features/planner/domain/services/plan_engine.dart`, `test/core/constants/dive_detail_sections_test.dart`, all eleven `lib/l10n/arb/app_*.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Rename: `test/core/database/migration_v161_dive_scenarios_test.dart` to `test/core/database/migration_v227_dive_scenarios_test.dart`

**Interfaces:**
- Produces: the whole `lib/features/dive_lab/` module, `DecoStatus.gfLowCeilingAnchor`, `PlanEngine.ascentPlanFor`, the `dive_scenarios` table at rung 227, `DiveDetailSectionId.diveLab`, and `showDiveLab(BuildContext, String diveId, {String? scenarioId})` in `lib/features/dive_lab/presentation/pages/dive_lab_page.dart`. Later tasks depend on all of these.

- [ ] **Step 1: Make sure main has not moved**

Run:

```bash
git fetch origin && git rev-list --count HEAD..origin/main
```

Expected: `0`. If greater, run `git merge origin/main` first (this branch only holds the spec commit, so it merges clean), then re-grep `currentSchemaVersion` and substitute the new rung for 227 throughout this task.

- [ ] **Step 2: Start the merge without committing**

Run:

```bash
git merge --no-commit --no-ff worktree-counterfactual-dive-lab; git diff --name-only --diff-filter=U
```

Expected: 28 unmerged paths: the five Dart files and the test named above, eleven ARBs, and eleven generated `app_localizations*.dart`.

- [ ] **Step 3: Resolve `plan_engine.dart` (a rename made public)**

Take main's file and apply the branch's one change:

```bash
git checkout --ours -- lib/features/planner/domain/services/plan_engine.dart && python3.14 - <<'PY'
from pathlib import Path
p = Path("lib/features/planner/domain/services/plan_engine.dart")
s = p.read_text(encoding="utf-8")
assert s.count("_ascentPlanFor(") == 2, s.count("_ascentPlanFor(")
s = s.replace(": _ascentPlanFor(plan.tanks);", ": ascentPlanFor(plan.tanks);")
old = "  AscentGasPlan _ascentPlanFor(List<DiveTank> tanks) {"
new = ("  /// The open-circuit ascent gas plan for [tanks]: the richest eligible mix\n"
       "  /// at each depth under the deco ppO2. Public so the Dive Lab synthesises\n"
       "  /// the same gas switches the engine schedules.\n"
       "  AscentGasPlan ascentPlanFor(List<DiveTank> tanks) {")
assert old in s
s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
PY
grep -c "ascentPlanFor" lib/features/planner/domain/services/plan_engine.dart
```

Expected: `3` (one call site, one declaration, one doc mention).

- [ ] **Step 4: Resolve `dive_detail_sections.dart` (new section, inserted before `dataSources`)**

Main gained an icon switch since the branch, so the section now touches five switches plus the defaults list.

```bash
git checkout --ours -- lib/core/constants/dive_detail_sections.dart && python3.14 - <<'PY'
from pathlib import Path
p = Path("lib/core/constants/dive_detail_sections.dart")
s = p.read_text(encoding="utf-8")
edits = [
    ("  customFields,\n  dataSources;", "  customFields,\n  diveLab,\n  dataSources;"),
    ("      dataSources => 'Data Sources',", "      diveLab => 'What if',\n      dataSources => 'Data Sources',"),
    ("      dataSources => 'Connected dive computers, source management',",
     "      diveLab => 'Saved what-if scenarios from the Dive Lab',\n      dataSources => 'Connected dive computers, source management',"),
    ("      dataSources => Icons.watch_outlined,", "      diveLab => Icons.science_outlined,\n      dataSources => Icons.watch_outlined,"),
    ("      dataSources => l10n.diveDetailSection_dataSources_name,",
     "      diveLab => l10n.diveDetailSection_diveLab_name,\n      dataSources => l10n.diveDetailSection_dataSources_name,"),
    ("      dataSources => l10n.diveDetailSection_dataSources_description,",
     "      diveLab => l10n.diveDetailSection_diveLab_description,\n      dataSources => l10n.diveDetailSection_dataSources_description,"),
    ("    DiveDetailSectionConfig(id: DiveDetailSectionId.dataSources, visible: true),",
     "    DiveDetailSectionConfig(id: DiveDetailSectionId.diveLab, visible: true),\n    DiveDetailSectionConfig(id: DiveDetailSectionId.dataSources, visible: true),"),
]
for old, new in edits:
    assert s.count(old) == 1, old
    s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
PY
grep -c "diveLab" lib/core/constants/dive_detail_sections.dart
```

Expected: `7`. If the `defaultSections` entry for `dataSources` is formatted across several lines, adjust the last pair to match the file and re-run.

- [ ] **Step 5: Resolve the section tripwire test**

```bash
git checkout --ours -- test/core/constants/dive_detail_sections_test.dart && sed -i '' 's/expect(DiveDetailSectionId.values.length, 23);/expect(DiveDetailSectionId.values.length, 24);/' test/core/constants/dive_detail_sections_test.dart && grep -n "values.length, 24\|values.last, DiveDetailSectionId.dataSources" test/core/constants/dive_detail_sections_test.dart
```

Expected: both lines print. `dataSources` stays last.

- [ ] **Step 6: Resolve `dive_detail_page.dart` (teaser section only; menu routing comes in Task 4)**

Keep main's menu handlers unchanged for now. Add the teaser section builder, which takes the page's `topGap` like the sightings builder does.

```bash
git checkout --ours -- lib/features/dive_log/presentation/pages/dive_detail_page.dart && python3.14 - <<'PY'
from pathlib import Path
p = Path("lib/features/dive_log/presentation/pages/dive_detail_page.dart")
s = p.read_text(encoding="utf-8")
imp = "import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';\n"
assert s.count(imp) == 1
s = s.replace(imp, "import 'package:submersion/features/dive_lab/presentation/widgets/dive_lab_section.dart';\n" + imp)
anchor = "      DiveDetailSectionId.dataSources: (_) {\n"
assert s.count(anchor) == 1
builder = ("      DiveDetailSectionId.diveLab: (topGap) {\n"
           "        if (dive.isGauge || dive.profile.length < 2) return [];\n"
           "        return [SizedBox(height: topGap), DiveLabSection(diveId: dive.id)];\n"
           "      },\n")
s = s.replace(anchor, builder + anchor)
p.write_text(s, encoding="utf-8")
PY
grep -n "DiveLabSection" lib/features/dive_log/presentation/pages/dive_detail_page.dart
```

Expected: two lines, the import and the builder. The import order (dive_lab before dive_log) matches the project's alphabetical package-import grouping.

- [ ] **Step 7: Resolve `database.dart` (table, rung 227, migration block, backstop)**

Take main's file and re-apply the branch's hunks renumbered. Every anchor is asserted so a silent no-op is impossible.

```bash
git checkout --ours -- lib/core/database/database.dart && python3.14 - <<'PY'
from pathlib import Path
import re
p = Path("lib/core/database/database.dart")
s = p.read_text(encoding="utf-8")
RUNG = 227

table = '''/// Saved "what if" scenarios on a logged dive (Dive Lab, v227). Inputs only:
/// the branch point, the mode and the interventions; outcomes are always
/// recomputed. Synced like dive plans (hlc column, deletion_log tombstones).
class DiveScenarios extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Runtime seconds on the dive's primary profile where the timelines part.
  IntColumn get branchSeconds => integer()();

  /// ScenarioMode name: `replay` or `replan`.
  TextColumn get mode => text().withDefault(const Constant('replay'))();

  /// Versioned JSON envelope (scenario_intervention_codec: formatVersion +
  /// interventions). A kind the reader does not know fails loudly on decode.
  TextColumn get interventionsJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

'''.replace("v227", f"v{RUNG}")

# 1. Table class immediately before the database annotation.
anchor = "@DriftDatabase("
assert s.count(anchor) == 1
s = s.replace(anchor, table + anchor)

# 2. Register the table: last entry of the tables list.
m = re.search(r"@DriftDatabase\(\s*tables: \[(.*?)\]", s, re.S)
assert m, "tables list not found"
tables_block = m.group(1)
assert "DiveScenarios" not in tables_block
trimmed = tables_block.rstrip()
if not trimmed.endswith(","):
    trimmed += ","
new_block = trimmed + "\n    DiveScenarios,\n  "
s = s[:m.start(1)] + new_block + s[m.end(1):]

# 3. Version constant.
old = f"static const int currentSchemaVersion = {RUNG - 1};"
assert s.count(old) == 1, old
s = s.replace(old, f"static const int currentSchemaVersion = {RUNG};")

# 4. Ladder entry after the previous rung's entry.
prev_entry = re.search(rf"^(\s*){RUNG - 1},\n", s, re.M)
assert prev_entry, "previous ladder entry not found"
indent = prev_entry.group(1)
entry = (f"{indent}// v{RUNG} (Dive Lab): dive_scenarios, saved what-if scenarios on a logged\n"
         f"{indent}// dive (branch point, mode, interventions), synced with an hlc column.\n"
         f"{indent}{RUNG},\n")
s = s[:prev_entry.end()] + entry + s[prev_entry.end():]

# 5. Assert helper, placed before the v226 helper's doc comment.
helper_decl = "Future<void> _assertMediaCloudAssetIdColumn()"
i = s.index(helper_decl)
doc_start = s.rfind("\n\n", 0, i) + 2
helper = f'''  /// v{RUNG}: the Dive Lab scenarios table. Migrator.createTable is IF NOT
  /// EXISTS and the index is guarded, so this is safe from both onUpgrade and
  /// the beforeOpen backstop.
  Future<void> _assertDiveScenariosSchema() async {{
    await createMigrator().createTable(diveScenarios);
    await customStatement(\'\'\'
      CREATE INDEX IF NOT EXISTS idx_dive_scenarios_dive_id
      ON dive_scenarios(dive_id)
    \'\'\');
  }}

'''
s = s[:doc_start] + helper + s[doc_start:]

# 6. onUpgrade block after the previous rung's progress report.
old = f"        if (from < {RUNG - 1}) await reportProgress();\n"
assert s.count(old) == 1, old
block = (f"        // v{RUNG}: dive_scenarios (Dive Lab saved scenarios). createTable is IF\n"
         f"        // NOT EXISTS and the index is guarded, so the block is idempotent;\n"
         f"        // the beforeOpen backstop re-asserts the same objects.\n"
         f"        if (from < {RUNG}) {{\n"
         f"          await _assertDiveScenariosSchema();\n"
         f"        }}\n"
         f"        if (from < {RUNG}) await reportProgress();\n")
s = s.replace(old, old + block)

# 7. beforeOpen backstop after the v226 backstop statement.
m = re.search(r"        // v226 backstop:.*?\n(?:        //.*\n)*        await _assertMediaCloudAssetIdColumn\(\);\n", s)
assert m, "v226 backstop not found"
backstop = (f"        // v{RUNG} backstop: re-assert the dive_scenarios table and its index for\n"
            f"        // databases that reached {RUNG} through a parallel branch, a restore or\n"
            f"        // sync-adopt without running the onUpgrade block.\n"
            f"        await _assertDiveScenariosSchema();\n")
s = s[:m.end()] + backstop + s[m.end():]
p.write_text(s, encoding="utf-8")
print("ok")
PY
grep -n "currentSchemaVersion = \|_assertDiveScenariosSchema\|DiveScenarios,$" lib/core/database/database.dart
```

Expected: `ok`, then the constant at 227, two helper mentions plus its declaration, one backstop call, and the tables-list entry. If a regex fails, open the file at the named anchor, adapt the anchor, and re-run; do not hand-edit around a failed assertion.

- [ ] **Step 8: Rename and renumber the migration test**

```bash
git mv test/core/database/migration_v161_dive_scenarios_test.dart test/core/database/migration_v227_dive_scenarios_test.dart && python3.14 - <<'PY'
from pathlib import Path
p = Path("test/core/database/migration_v227_dive_scenarios_test.dart")
s = p.read_text(encoding="utf-8")
s = s.replace("PRAGMA user_version = 160", "PRAGMA user_version = 226")
s = s.replace("PRAGMA user_version = 161", "PRAGMA user_version = 227")
s = s.replace("minimumCompatibleSchemaVersion, 160", "minimumCompatibleSchemaVersion, 224")
s = s.replace("161", "227")
p.write_text(s, encoding="utf-8")
print(s.count("227"), s.count("161"))
PY
```

Expected: a positive count then `0`. The test opens a database at `user_version 226`, so only the 227 block runs; main's `beforeOpen` backstops may need scaffold tables (`divers`, `dive_sites`, `dives`, `dive_centers`, `equipment`, `tags`, `media`) that the v226 test creates. Copy that test's `setupDb` scaffolding into this one if Task 2's run of it fails naming a missing table.

- [ ] **Step 9: Resolve the eleven ARBs three-way**

A key the branch has that main lacks is kept only when the merge base also lacks it; otherwise main deleted it. Entries are copied as raw text spans so the files do not reformat. Each new key is inserted after the same neighbour it follows on the branch.

```bash
python3.14 - <<'PY'
import json, subprocess
from pathlib import Path

LOCALES = ["ar", "de", "en", "es", "fr", "he", "hu", "it", "nl", "pt", "zh"]

def stage(n, path):
    return subprocess.run(["git", "show", f":{n}:{path}"], check=True,
                          capture_output=True, text=True, encoding="utf-8").stdout

def spans(text):
    """Top-level entries as (key, raw_text) in file order, by a brace walk."""
    i = text.index("{") + 1
    end = text.rindex("}")
    out = []
    while i < end:
        j = text.find('"', i)
        if j < 0 or j >= end:
            break
        k = text.index('"', j + 1)
        key = text[j + 1:k]
        colon = text.index(":", k)
        m = colon + 1
        while text[m] in " \t\r\n":
            m += 1
        if text[m] == "{":
            depth = 0
            n = m
            while True:
                c = text[n]
                if c == '"':
                    n = text.index('"', n + 1)
                    while text[n - 1] == "\\":
                        n = text.index('"', n + 1)
                elif c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        break
                n += 1
            v_end = n + 1
        else:
            n = m
            if text[n] == '"':
                n = text.index('"', n + 1)
                while text[n - 1] == "\\":
                    n = text.index('"', n + 1)
                v_end = n + 1
            else:
                while text[n] not in ",\n}":
                    n += 1
                v_end = n
        line_start = text.rfind("\n", 0, j) + 1
        out.append((key, text[line_start:v_end]))
        i = v_end
        while i < end and text[i] in " \t\r\n,":
            i += 1
    return out

for loc in LOCALES:
    path = f"lib/l10n/arb/app_{loc}.arb"
    base, ours, theirs = stage(1, path), stage(2, path), stage(3, path)
    base_keys = {k for k, _ in spans(base)}
    ours_spans = spans(ours)
    ours_keys = [k for k, _ in ours_spans]
    theirs_spans = spans(theirs)
    ours_map = dict(ours_spans)
    new = [(i, k, raw) for i, (k, raw) in enumerate(theirs_spans)
           if k not in ours_map and k not in base_keys]
    dropped = [k for k, _ in theirs_spans if k not in ours_map and k in base_keys]
    result = list(ours_spans)
    for i, k, raw in new:
        prev = next((theirs_spans[j][0] for j in range(i - 1, -1, -1)
                     if theirs_spans[j][0] in dict(result)), None)
        if prev is None:
            result.append((k, raw))
            continue
        pos = [idx for idx, (rk, _) in enumerate(result) if rk == prev][0] + 1
        result.insert(pos, (k, raw))
    body = ",\n".join(raw for _, raw in result)
    Path(path).write_text("{\n" + body + "\n}\n", encoding="utf-8")
    json.loads(Path(path).read_text(encoding="utf-8"))
    print(f"{loc}: +{len(new)} new, {len(dropped)} dropped (main deleted them)")
PY
```

Expected: eleven lines; each locale reports roughly 150 new entries (the 143 `diveLab_` keys, the two `diveDetailSection_diveLab_` keys, and their `@` metadata objects, which the walker counts separately). Every file parses as JSON.

- [ ] **Step 10: Regenerate the localizations and stage everything**

```bash
flutter gen-l10n && git add lib/l10n/arb/app_*.arb lib/l10n/arb/app_localizations*.dart lib/core/database/database.dart lib/core/constants/dive_detail_sections.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/planner/domain/services/plan_engine.dart test/core/constants/dive_detail_sections_test.dart test/core/database/migration_v227_dive_scenarios_test.dart && git diff --name-only --diff-filter=U
```

Expected: `flutter gen-l10n` prints nothing alarming; the final command prints nothing (no unmerged paths left).

- [ ] **Step 11: Run the l10n structural tests before committing the merge**

```bash
flutter test test/l10n/arb_parity_test.dart test/l10n/arb_no_duplicate_keys_test.dart
```

Expected: all pass. A parity failure listing `diveLab_` keys missing from one locale means Step 9's neighbour lookup dropped an entry for that locale; re-run Step 9 for that file after inspecting the branch's version of it.

- [ ] **Step 12: Commit the merge**

```bash
git commit -m "Merge branch 'worktree-counterfactual-dive-lab' into the rethink branch

Brings the five finished Dive Lab phases onto current main. Resolved: the
schema rung moves from 161 to 227, DiveDetailSectionId.diveLab sits before
dataSources with the new icon switch, the plan engine's ascentPlanFor rename,
the teaser section builder on dive detail, and a three-way ARB merge with the
generated localizations rebuilt."
```

Expected: the merge commit lands; `git status --short` is empty.

- [ ] **Step 13: Rebuild generated code for the new table**

```bash
dart run build_runner build --delete-conflicting-outputs && flutter analyze 2>&1 | tail -5
```

Expected: build succeeds. `flutter analyze` is allowed to report errors here; Task 2 fixes them. Record the count.

---

### Task 2: Compile the merged module against main and get its tests green

The old branch composed public engine seams that all still exist, but 1,771 commits of API drift may have changed constructor parameters, renamed providers, or added required fields. This task is a fix-forward pass with the ported test suite as the oracle.

**Files:**
- Modify: whatever `flutter analyze` names under `lib/features/dive_lab/` and `test/features/dive_lab/`; nothing outside the module unless an error forces it (record any such edit in the commit message)

**Interfaces:**
- Consumes: the merged module from Task 1.
- Produces: a module that compiles and whose 35 ported test files pass; `runScenarioEngine(ScenarioRequest)` and `const ScenarioEngine().run(request)` return a `ScenarioOutcome` whose `compiledPlan` is non-null in re-plan mode. Task 6 relies on that.

- [ ] **Step 1: List the analyzer errors**

```bash
flutter analyze 2>&1 | grep -E "^\s*(error|warning|info)" | sort | uniq -c | sort -rn | head -40
```

Expected: a list. Typical drift to expect, with the fix for each:

- `PlanEngineConfig` gained parameters since August (per-plan RMV factor, problem-solving minutes, ppO2 overrides). Fix in `lib/features/dive_lab/domain/entities/scenario_settings.dart`: pass the new named parameters in `engineConfig` from the existing settings fields, or their engine defaults where the lab has no equivalent.
- `DivePlan` gained fields with defaults (`sacFactor`, `problemSolvingMinutes`, `stopMinimums`, `ppO2Bottom`, `ppO2Deco`, `bestMixEndMeters`, `o2Narcotic`). The compiler in `scenario_plan_compiler.dart` should compile unchanged; if a field became required, pass the engine default.
- `PlanOutcome` gained `authoredDecoSeconds`; readers in `counterfactual_profile_synthesizer.dart` and `scenario_delta_builder.dart` are unaffected unless a field was renamed.
- Drift's generated `DiveScenario` data class clashes with the domain entity in tests: alias the database import (`import '.../database.dart' as db;`), as the ported tests already do.
- `seededTissueState` moved to `plan_state_outcome.dart`; the lab does not call it.

Fix every error at its source file; do not suppress with `// ignore`.

- [ ] **Step 2: Re-run analyze until clean**

```bash
flutter analyze
```

Expected: "No issues found!". Infos count as failures in CI, so clear them too.

- [ ] **Step 3: Run the ported and touched suites**

```bash
flutter test test/features/dive_lab test/core/deco test/features/planner test/core/database/migration_v227_dive_scenarios_test.dart test/core/constants
```

Expected: all pass. Known traps recorded during the original build, so a failure of this shape is a port issue, not a product bug:

- an `autoDispose` provider read without a listener disposes mid-await (the test must `listen`);
- widget tests that render PDFs run under `tester.runAsync`;
- `PlanSectionHeader` uppercases labels, so finders look for `'BUOYANCY'`;
- `DateTime ==` compares `isUtc`; the codec parses without `toLocal()`;
- a `List ==` is identity; the importer uses `ListEquality`.

If the migration test fails naming a missing table, add that table to its `setupDb` scaffold using the `CREATE TABLE ...` lines from `test/core/database/migration_v226_media_cloud_asset_id_test.dart`.

- [ ] **Step 4: Format and commit**

```bash
dart format . && git add -u lib/features/dive_lab test/features/dive_lab lib/core test/core && git status --short
```

Expected: only files you edited are staged (`git add -u` restages tracked files only; confirm no submodule pointer is listed). Then:

```bash
git commit -m "chore(dive-lab): compile the merged module against current main

<one line per API drift fixed, naming the file and the parameter or type>"
```

---

### Task 3: Re-verify sync registration and the schema rung

The old branch registered `dive_scenarios` at eighteen sync sites. Those hunks auto-merged, but the enumerations in main's structural tests may have grown a new site the branch never knew about. The tests are the oracle.

**Files:**
- Modify (only if a test names it): `test/core/services/sync/pending_child_export_test.dart`, `test/core/services/sync/sync_parent_refs_completeness_test.dart`, `lib/core/services/sync/sync_service.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/data/repositories/sync_repository.dart`, `lib/core/database/performance_indexes.dart`

- [ ] **Step 1: Confirm every registration site is present**

```bash
grep -n "diveScenarios\|dive_scenarios" lib/core/services/sync/sync_service.dart lib/core/services/sync/sync_data_serializer.dart lib/core/data/repositories/sync_repository.dart lib/core/database/performance_indexes.dart | wc -l
```

Expected: at least 20 lines (three in `sync_service.dart`: the merge-order entry after `divePlanEquipment`, the `entityHasUpdatedAt` map, the parent refs map; fourteen in the serializer; one in `sync_repository.dart` hlc targets; one index in `performance_indexes.dart`). If any file has zero, re-apply that file's hunk from `git diff f8eff021a52 worktree-counterfactual-dive-lab -- <file>`.

- [ ] **Step 2: Run the sync and database structural suites**

```bash
flutter test test/core/services/sync test/core/data test/core/database
```

Expected: all pass. If `pending_child_export_test.dart` fails listing `diveScenarios` as an unregistered child, add to its child map, next to the `divePlanEquipment` entry:

```dart
      'diveScenarios': {'diveId': 'd1'},
```

If `sync_parent_refs_completeness_test.dart` fails, its `syncedTables` map needs `'dive_scenarios': 'diveScenarios',` next to `'dive_plan_equipment': 'divePlanEquipment',` (the branch added this line; check it survived the merge).

- [ ] **Step 3: Run the section registry and dive-detail suites**

```bash
flutter test test/core/constants test/features/dive_log/presentation/pages
```

Expected: all pass, including the tripwire at 24 and any settings-page test that enumerates sections (those read `DiveDetailSectionId.values`, so they follow automatically; a hard-coded count elsewhere is bumped from 23 to 24).

- [ ] **Step 4: Commit if anything changed**

```bash
dart format . && git add -u lib/core test/core && git commit -m "chore(dive-lab): register dive_scenarios at the sync sites main gained since August"
```

Skip the commit when `git status --short` is empty after formatting.

---

### Task 4: Eligibility function and the front door

"What if..." on dive detail keeps its label, icon and string key, and routes to the lab when the dive is eligible, else to today's rebuild sheet. The old branch's duplicate menu item, toolbar icon and their two string keys go away.

**Files:**
- Create: `lib/features/dive_lab/domain/dive_lab_eligibility.dart`
- Create: `lib/features/dive_lab/presentation/what_if_entry.dart`
- Create: `test/features/dive_lab/domain/dive_lab_eligibility_test.dart`
- Create: `test/features/dive_lab/presentation/what_if_entry_test.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (two `case 'whatIf':` handlers and the `diveLab` section builder), `lib/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart`
- Modify: all eleven `lib/l10n/arb/app_*.arb` (remove `diveLab_action_whatIf` and `diveLab_tooltip_open`), regenerate `app_localizations*.dart`

**Interfaces:**
- Consumes: `showDiveLab(BuildContext, String diveId, {String? scenarioId})` from `dive_lab_page.dart`; `showWhatIfSheet(BuildContext, Dive)` from `what_if_sheet.dart`.
- Produces: `bool isDiveLabEligible(Dive dive)` and `Future<void> openWhatIf(BuildContext context, Dive dive)`. Task 8 reuses `showWhatIfSheet` directly.

- [ ] **Step 1: Write the failing eligibility test**

`test/features/dive_lab/domain/dive_lab_eligibility_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

Dive _dive({required DiveMode mode, required int samples}) => Dive(
  id: 'd',
  dateTime: DateTime(2026, 1, 1),
  diveMode: mode,
  profile: [
    for (var i = 0; i < samples; i++)
      DiveProfilePoint(timestamp: i * 10, depth: 10),
  ],
);

void main() {
  group('isDiveLabEligible', () {
    for (final mode in [DiveMode.oc, DiveMode.ccr, DiveMode.scr]) {
      test('$mode with two samples is eligible', () {
        expect(isDiveLabEligible(_dive(mode: mode, samples: 2)), isTrue);
      });
    }
    test('gauge is never eligible', () {
      expect(isDiveLabEligible(_dive(mode: DiveMode.gauge, samples: 50)), isFalse);
    });
    test('one sample is not a profile to branch from', () {
      expect(isDiveLabEligible(_dive(mode: DiveMode.oc, samples: 1)), isFalse);
    });
    test('no profile is not eligible', () {
      expect(isDiveLabEligible(_dive(mode: DiveMode.oc, samples: 0)), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
flutter test test/features/dive_lab/domain/dive_lab_eligibility_test.dart
```

Expected: compile failure, `dive_lab_eligibility.dart` not found.

- [ ] **Step 3: Write the eligibility function**

`lib/features/dive_lab/domain/dive_lab_eligibility.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Whether the Dive Lab can branch [dive]: a profile of at least two samples
/// on an open-circuit or rebreather dive. Gauge dives carry no deco analysis
/// to branch from. The menu, the teaser section and the page's empty state
/// all decide through this one function.
bool isDiveLabEligible(Dive dive) =>
    !dive.isGauge && dive.profile.length >= 2;
```

- [ ] **Step 4: Run it to see it pass**

```bash
flutter test test/features/dive_lab/domain/dive_lab_eligibility_test.dart
```

Expected: 6 tests pass.

- [ ] **Step 5: Write the failing front-door test**

`test/features/dive_lab/presentation/what_if_entry_test.dart`. The lab page is pushed on the root navigator, so the harness uses a plain `MaterialApp` with a button; the sheet is a modal bottom sheet on the same navigator.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/what_if_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

List<DiveProfilePoint> _profile() => [
  for (var t = 0; t <= 600; t += 10) DiveProfilePoint(timestamp: t, depth: 20),
];

Dive _dive(DiveMode mode) => Dive(
  id: 'd',
  dateTime: DateTime(2026, 1, 1),
  diveMode: mode,
  profile: _profile(),
);

Widget _harness(Dive dive) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    labRequestInputsProvider('d').overrideWith((ref) async => null),
    labDefaultBranchProvider('d').overrideWith((ref) async => 0),
    diveProvider.overrideWith((ref, id) async => dive),
    divesProvider.overrideWith((ref) async => <Dive>[]),
    diveProfileProvider.overrideWith((ref, id) async => dive.profile),
    gasSwitchesProvider.overrideWith((ref, id) async => <GasSwitchWithTank>[]),
  ],
  locale: const Locale('en'),
  child: Builder(
    builder: (context) => ElevatedButton(
      onPressed: () => openWhatIf(context, dive),
      child: const Text('open'),
    ),
  ),
);

void main() {
  testWidgets('an eligible dive opens the Dive Lab', (tester) async {
    await tester.pumpWidget(_harness(_dive(DiveMode.oc)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(DiveLabPage), findsOneWidget);
    expect(find.byType(WhatIfSheet), findsNothing);
  });

  testWidgets('a gauge dive with a profile opens the rebuild sheet', (tester) async {
    await tester.pumpWidget(_harness(_dive(DiveMode.gauge)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(WhatIfSheet), findsOneWidget);
    expect(find.byType(DiveLabPage), findsNothing);
  });
}
```

- [ ] **Step 6: Run it to see it fail**

```bash
flutter test test/features/dive_lab/presentation/what_if_entry_test.dart
```

Expected: compile failure, `what_if_entry.dart` not found.

- [ ] **Step 7: Write the entry function**

`lib/features/dive_lab/presentation/what_if_entry.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';

/// The single "What if..." front door on dive detail: the Dive Lab when the
/// dive can be branched, else the rebuild-in-planner sheet, so a gauge dive
/// with a profile keeps the path it has today.
Future<void> openWhatIf(BuildContext context, Dive dive) {
  if (isDiveLabEligible(dive)) return showDiveLab(context, dive.id);
  return showWhatIfSheet(context, dive);
}
```

- [ ] **Step 8: Run it to see it pass**

```bash
flutter test test/features/dive_lab/presentation/what_if_entry_test.dart
```

Expected: 2 tests pass. If the lab page test fails on a missing provider override, add the override the error names to `_harness` (the page reads only `labRequestInputsProvider`, `labDefaultBranchProvider`, `labDraftProvider` and `settingsProvider` before its body renders).

- [ ] **Step 9: Route the detail page through the entry and the eligibility function**

```bash
python3.14 - <<'PY'
from pathlib import Path
p = Path("lib/features/dive_log/presentation/pages/dive_detail_page.dart")
s = p.read_text(encoding="utf-8")
old_imp = "import 'package:submersion/features/dive_lab/presentation/widgets/dive_lab_section.dart';\n"
assert s.count(old_imp) == 1
s = s.replace(old_imp,
    "import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';\n"
    "import 'package:submersion/features/dive_lab/presentation/what_if_entry.dart';\n" + old_imp)
assert s.count("showWhatIfSheet(context, dive);") == 2
s = s.replace("showWhatIfSheet(context, dive);", "openWhatIf(context, dive);")
old_guard = "        if (dive.isGauge || dive.profile.length < 2) return [];\n        return [SizedBox(height: topGap), DiveLabSection(diveId: dive.id)];"
assert s.count(old_guard) == 1
s = s.replace(old_guard, "        if (!isDiveLabEligible(dive)) return [];\n        return [SizedBox(height: topGap), DiveLabSection(diveId: dive.id)];")
if "what_if_sheet.dart" in s and "WhatIfSheet" not in s.replace("import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';", ""):
    s = s.replace("import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';\n", "")
p.write_text(s, encoding="utf-8")
print("ok")
PY
grep -n "openWhatIf\|isDiveLabEligible\|what_if_sheet" lib/features/dive_log/presentation/pages/dive_detail_page.dart
```

Expected: `ok`; two `openWhatIf` calls, one `isDiveLabEligible` use plus the two imports, and no remaining `what_if_sheet` import (the page no longer references the sheet directly).

- [ ] **Step 10: Use the function in the inputs provider**

In `lib/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart`, the provider currently returns null for `dive.isGauge` and again for `profile.length < 2`. Keep both checks (the profile there is the primary profile from `diveProfileProvider`, which is the authoritative sample list) but route the gauge check through the function so the rule has one home:

```bash
python3.14 - <<'PY'
from pathlib import Path
p = Path("lib/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart")
s = p.read_text(encoding="utf-8")
old = "      if (dive == null || dive.isGauge) return null;\n"
assert s.count(old) == 1
s = s.replace(old, "      if (dive == null || dive.isGauge) return null;\n      // The primary profile below is the sample list that counts; the entity's\n      // own profile may be lean-hydrated, so isDiveLabEligible is not enough here.\n")
p.write_text(s, encoding="utf-8")
PY
```

Expected: the comment lands; behaviour unchanged. (The function is the menu-side rule on a fully hydrated detail-page dive; the provider keeps its own sample count because it sees the primary profile.)

- [ ] **Step 11: Remove the two dead string keys from every ARB and regenerate**

```bash
python3.14 - <<'PY'
import json, re
from pathlib import Path
for path in sorted(Path("lib/l10n/arb").glob("app_*.arb")):
    s = path.read_text(encoding="utf-8")
    before = s
    for key in ("diveLab_action_whatIf", "diveLab_tooltip_open"):
        # The value entry and an optional @metadata object, each ending at the next top-level key.
        s = re.sub(rf'\s*"{key}": "(?:[^"\\]|\\.)*",?', "", s)
        s = re.sub(rf'\s*"@{key}": \{{(?:[^{{}}]|\{{[^{{}}]*\}})*\}},?', "", s)
    s = re.sub(r",(\s*\n\s*})", r"\1", s)
    json.loads(s)
    if s != before:
        path.write_text(s, encoding="utf-8")
        print("cleaned", path.name)
PY
grep -rn "diveLab_action_whatIf\|diveLab_tooltip_open" lib/ && echo "STILL REFERENCED" || echo "no references"
flutter gen-l10n && flutter test test/l10n/arb_parity_test.dart test/l10n/arb_no_duplicate_keys_test.dart
```

Expected: eleven "cleaned" lines, `no references`, and both l10n tests pass.

- [ ] **Step 12: Run the touched suites, format, commit**

```bash
flutter test test/features/dive_lab test/features/dive_log/presentation/pages test/features/dive_log/presentation/widgets/what_if_sheet_test.dart && dart format . && flutter analyze
```

Expected: all pass, "No issues found!".

```bash
git add lib/features/dive_lab/domain/dive_lab_eligibility.dart lib/features/dive_lab/presentation/what_if_entry.dart test/features/dive_lab/domain/dive_lab_eligibility_test.dart test/features/dive_lab/presentation/what_if_entry_test.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart lib/l10n/arb && git commit -m "feat(dive-lab): What if opens the lab when the dive can be branched

The existing What if menu item keeps its label and icon and routes to the
Dive Lab for open-circuit and rebreather dives with a profile, and to the
rebuild-in-planner sheet otherwise. The old branch's second menu item,
toolbar icon and their two string keys are gone."
```

---

### Task 5: Converter `throughTimestamp`

`DiveToPlanConverter` authors a logged dive only up to the last hold at working depth. The hand-off needs it authored through the branch sample, ascent and stops included, with no trailing-ramp trim.

**Files:**
- Modify: `lib/features/planner/domain/services/dive_to_plan_converter.dart`
- Test: `test/features/planner/domain/services/dive_to_plan_converter_test.dart`

**Interfaces:**
- Produces: `DiveToPlanConverter.convert(..., int? throughTimestamp)` and `DiveToPlanConverter.breakpoints(..., int? throughTimestamp)`. When supplied, the last breakpoint is the sample at or before that absolute timestamp, at its snapped depth. When null, behaviour is unchanged. Task 6 passes the branch sample's timestamp.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/planner/domain/services/dive_to_plan_converter_test.dart`, inside `main()`, using the file's existing `_squareProfile` (descent 120 s, bottom to 1320 s, ascent to 1620 s at 30 m by default), `_dive` and `_defaults` helpers:

```dart
  group('throughTimestamp', () {
    test('authors through a sample in the ascent and keeps the ascent so far', () {
      final profile = _squareProfile();
      final points = const DiveToPlanConverter().breakpoints(
        profile: profile,
        gasSwitches: const [],
        levels: 3,
        throughTimestamp: 1500,
      );
      // 1500 s is 180 s into a 300 s ascent from 30 m: 30 * (1 - 0.6) = 12 m.
      expect(points.last.timeSeconds, 1500);
      expect(points.last.depth, 12);
      // The bottom hold is still present before it.
      expect(points.any((p) => p.depth == 30), isTrue);
    });

    test('without throughTimestamp the trim rule still ends on the bottom hold', () {
      final points = const DiveToPlanConverter().breakpoints(
        profile: _squareProfile(),
        gasSwitches: const [],
        levels: 3,
      );
      expect(points.last.depth, 30);
      expect(points.last.timeSeconds, lessThanOrEqualTo(1320));
    });

    test('a timestamp in the descent authors the descent only', () {
      final points = const DiveToPlanConverter().breakpoints(
        profile: _squareProfile(),
        gasSwitches: const [],
        levels: 3,
        throughTimestamp: 60,
      );
      expect(points.last.timeSeconds, 60);
      expect(points.last.depth, 15);
      expect(points.length, 2);
    });

    test('the first sample yields no segments', () {
      final dive = _dive(profile: _squareProfile());
      final state = const DiveToPlanConverter().convert(
        dive: dive,
        profile: dive.profile,
        gasSwitches: const [],
        levels: 3,
        planName: 'p',
        defaults: _defaults(),
        throughTimestamp: 0,
      );
      expect(state.segments, isEmpty);
    });

    test('segment durations sum to the branch time', () {
      final dive = _dive(profile: _squareProfile());
      final state = const DiveToPlanConverter().convert(
        dive: dive,
        profile: dive.profile,
        gasSwitches: const [],
        levels: 3,
        planName: 'p',
        defaults: _defaults(),
        throughTimestamp: 1500,
      );
      final total = state.segments.fold<int>(0, (a, s) => a + s.durationSeconds);
      expect(total, 1500);
      expect(state.segments.last.targetDepth, 12);
    });
  });
```

- [ ] **Step 2: Run them to see them fail**

```bash
flutter test test/features/planner/domain/services/dive_to_plan_converter_test.dart
```

Expected: compile failure, no named parameter `throughTimestamp`.

- [ ] **Step 3: Implement the parameter**

In `lib/features/planner/domain/services/dive_to_plan_converter.dart`:

1. Add `int? throughTimestamp,` to `convert`'s parameters (after `surfaceInterval`) and pass it into the `breakpoints(...)` call.
2. Add `int? throughTimestamp,` to `breakpoints`'s parameters and change the end-index and the trim:

```dart
    final endIndex = throughTimestamp == null
        ? _workingEndIndex(pts, maxDepth)
        : _indexAtOrBefore(pts, (throughTimestamp - t0).toDouble());
```

and at the end of `breakpoints`:

```dart
    // A plan authored through a chosen sample ends exactly there: the caller
    // continues it (the Dive Lab appends the branched remainder), so the
    // trailing ramp must not be folded back onto the previous level.
    return throughTimestamp == null
        ? _trimTrailingRamp(result, maxDepth)
        : result;
```

3. Add the helper next to `_indexAtTime`:

```dart
  /// Index of the last sample at or before [time]; 0 when [time] precedes the
  /// profile. The Dive Lab's branch is always a real sample, so this is exact
  /// there and a floor everywhere else.
  int _indexAtOrBefore(List<_Point> pts, double time) {
    for (var i = pts.length - 1; i >= 0; i--) {
      if (pts[i].x <= time) return i;
    }
    return 0;
  }
```

4. Update the class doc comment's last paragraph:

```dart
/// The plan is authored only up to the last hold at working depth (at or
/// deeper than half the max depth). The ascent, any decompression stops and
/// the surfacing are deliberately not authored: the plan engine computes them
/// from that point, so the planner shows its own TTS and deco schedule for the
/// diver to compare against what the dive computer actually did. A caller that
/// passes `throughTimestamp` (the Dive Lab, handing a branched scenario to the
/// planner) gets the profile authored through that sample instead, ascent and
/// stops included, ending exactly there.
```

- [ ] **Step 4: Run the tests to see them pass**

```bash
flutter test test/features/planner/domain/services/dive_to_plan_converter_test.dart test/features/dive_log/presentation/widgets/what_if_sheet_test.dart
```

Expected: all pass, including the pre-existing converter tests (the null path is untouched).

- [ ] **Step 5: Format and commit**

```bash
dart format . && flutter analyze && git add lib/features/planner/domain/services/dive_to_plan_converter.dart test/features/planner/domain/services/dive_to_plan_converter_test.dart && git commit -m "feat(planner): DiveToPlanConverter can author a dive through a chosen sample

throughTimestamp replaces the working-depth trim so the Dive Lab can hand
a branched scenario to the planner with the ascent and stops done so far
authored as segments, ending exactly at the branch."
```

---

### Task 6: The hand-off service

Pure Dart, no Flutter imports. Concatenates the converter's segments (through the branch) with the lab's compiled remainder, maps settings field for field, restores the dive's original start pressures, and reports what it could not carry.

**Files:**
- Create: `lib/features/dive_lab/domain/services/scenario_plan_handoff.dart`
- Test: `test/features/dive_lab/domain/services/scenario_plan_handoff_test.dart`

**Interfaces:**
- Consumes: `DiveToPlanConverter.convert(..., throughTimestamp:)` (Task 5); `ScenarioOutcome.compiledPlan` (a `domain.DivePlan`, non-null in re-plan mode) and `ScenarioOutcome.branch.index`; `stateFromDivePlan(domain.DivePlan)` from `dive_plan_state_mapper.dart`; `LoseTankIntervention`, `AscentPolicyIntervention`, `DiveScenario.effectiveMode`.
- Produces:

```dart
enum ScenarioHandoffNote { replayReplanned, extraLastStopNotCarried, lostTankKept }

class ScenarioPlanHandoffResult {
  final DivePlanState plan;
  final List<ScenarioHandoffNote> notes;
}

ScenarioPlanHandoffResult buildScenarioPlanHandoff({
  required ScenarioRequest request,
  required ScenarioOutcome outcome,      // computed with the scenario in re-plan mode
  required DiveScenario scenario,        // the draft as the diver had it
  required Dive dive,
  required List<DiveProfilePoint> profile,
  required List<GasSwitch> gasSwitches,
  required DivePlanState defaults,
  required String planName,
  String Function()? idGenerator,
});
```

Task 8 calls it from the lab page.

- [ ] **Step 1: Write the failing tests**

`test/features/dive_lab/domain/services/scenario_plan_handoff_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_plan_handoff.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';

import '../support/synthetic_dives.dart';

ScenarioRequest _request(
  SyntheticDive dive, {
  required int branchSeconds,
  ScenarioMode mode = ScenarioMode.replan,
  List<ScenarioIntervention> interventions = const [],
  DiveMode diveMode = DiveMode.oc,
  ScenarioSettings settings = const ScenarioSettings(),
}) => ScenarioRequest(
  diveId: 'd',
  depths: dive.depths,
  timestamps: dive.timestamps,
  diveMode: diveMode,
  tanks: dive.tanks,
  gasSwitches: dive.switches,
  tankPressures: dive.tankPressures,
  settings: settings,
  scenario: DiveScenario(
    id: 's',
    diveId: 'd',
    name: 'n',
    branchSeconds: branchSeconds,
    mode: mode,
    interventions: interventions,
    createdAt: DateTime(2026, 9, 25),
    updatedAt: DateTime(2026, 9, 25),
  ),
);

Dive _dive(SyntheticDive d) => Dive(
  id: 'd',
  dateTime: DateTime(2026, 9, 25, 9),
  diveMode: DiveMode.oc,
  tanks: d.tanks,
  profile: [
    for (var i = 0; i < d.depths.length; i++)
      DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
  ],
);

List<GasSwitch> _switches(SyntheticDive d) => [
  for (final (i, s) in d.switches.indexed)
    GasSwitch(
      id: 'gs$i',
      diveId: 'd',
      timestamp: s.timestamp,
      tankId: s.tankId,
      createdAt: DateTime(2026, 9, 25, 9),
    ),
];

DivePlanState _defaults() {
  final now = DateTime(2026, 9, 25);
  return DivePlanState(
    id: 'template',
    name: 'template',
    segments: const [],
    tanks: const [],
    sacFactor: 3.0,
    problemSolvingMinutes: 4,
    createdAt: now,
    updatedAt: now,
  );
}

ScenarioPlanHandoffResult _handoff(
  SyntheticDive d,
  ScenarioRequest request, {
  DiveScenario? scenario,
}) {
  final outcome = const ScenarioEngine().run(request);
  return buildScenarioPlanHandoff(
    request: request,
    outcome: outcome,
    scenario: scenario ?? request.scenario,
    dive: _dive(d),
    profile: _dive(d).profile,
    gasSwitches: _switches(d),
    defaults: _defaults(),
    planName: 'What if: test',
  );
}

void main() {
  final d = squareDive(depth: 40, bottomMinutes: 25);

  test('segments are continuous at the branch and the remainder follows', () {
    final request = _request(d, branchSeconds: 900);
    final outcome = const ScenarioEngine().run(request);
    final result = _handoff(d, request);
    final remainder = outcome.compiledPlan!.segments.length;
    final authored = result.plan.segments.length - remainder;
    expect(authored, greaterThanOrEqualTo(2));
    final authoredSeconds = result.plan.segments
        .take(authored)
        .fold<int>(0, (a, s) => a + s.durationSeconds);
    expect(authoredSeconds, 900);
    // The lab's remainder keeps its segments in order after the authored ones.
    for (var i = 0; i < result.plan.segments.length; i++) {
      expect(result.plan.segments[i].order, i);
    }
    expect(result.plan.sourceDiveId, 'd');
    expect(result.plan.name, 'What if: test');
    expect(result.notes, isEmpty);
  });

  test('a tank lost after the branch is absent from the plan', () {
    final request = _request(
      d,
      branchSeconds: 900,
      interventions: const [LoseTankIntervention(tankId: 'deco50')],
    );
    final result = _handoff(d, request);
    expect(result.plan.tanks.any((t) => t.id == 'deco50'), isFalse);
    expect(result.notes, isEmpty);
  });

  test('a tank already breathed before the branch stays, with a note', () {
    final afterSwitch = d.timestamps[d.switchIndex] + 60;
    final request = _request(
      d,
      branchSeconds: afterSwitch,
      interventions: const [LoseTankIntervention(tankId: 'deco50')],
    );
    final result = _handoff(d, request);
    expect(result.plan.segments.any((s) => s.tankId == 'deco50'), isTrue);
    expect(result.plan.tanks.any((t) => t.id == 'deco50'), isTrue);
    expect(result.notes, contains(ScenarioHandoffNote.lostTankKept));
  });

  test('original start pressures are restored and a hypothetical tank is added', () {
    final request = _request(
      d,
      branchSeconds: 900,
      interventions: const [
        SwitchGasIntervention(
          tank: HypotheticalTankRef(
            gasMix: GasMix(o2: 32, he: 0),
            volumeLiters: 11,
            startPressureBar: 200,
          ),
        ),
      ],
    );
    final result = _handoff(d, request);
    final back = result.plan.tanks.firstWhere((t) => t.id == 'back');
    final original = request.tanks.firstWhere((t) => t.id == 'back');
    expect(back.startPressure, original.startPressure);
    expect(result.plan.tanks.any((t) => t.gasMix.o2 == 32), isTrue);
  });

  test('gradient factors come from the intervention', () {
    final request = _request(
      d,
      branchSeconds: 900,
      interventions: const [ChangeGfIntervention(gfLow: 40, gfHigh: 85)],
    );
    final result = _handoff(d, request);
    expect(result.plan.gfLow, 40);
    expect(result.plan.gfHigh, 85);
  });

  test('share-gas hands off the stressed SAC', () {
    final plain = _handoff(d, _request(d, branchSeconds: 900));
    final shared = _handoff(
      d,
      _request(
        d,
        branchSeconds: 900,
        interventions: const [ShareGasIntervention()],
      ),
    );
    expect(shared.plan.sacRate, greaterThan(plain.plan.sacRate));
    expect(
      shared.plan.sacRate,
      closeTo(plain.plan.sacRate * 2.5 * const ScenarioSettings().buddyFactor, 1e-6),
    );
  });

  test('settings and defaults map field for field', () {
    final request = _request(d, branchSeconds: 900);
    final result = _handoff(d, request);
    expect(result.plan.ppO2Bottom, request.settings.ppO2Working);
    expect(result.plan.ppO2Deco, request.settings.ppO2Deco);
    expect(result.plan.sacFactor, 3.0);
    expect(result.plan.problemSolvingMinutes, 4);
    expect(result.plan.stopMinimums, isEmpty);
    expect(result.plan.surfaceInterval, isNull);
    expect(result.plan.isDirty, isFalse);
  });

  test('the residual tissue seed rides along', () {
    final seed = const ScenarioEngine()
        .run(_request(d, branchSeconds: 900))
        .actual
        .decoStatuses
        .last
        .compartments;
    final base = _request(d, branchSeconds: 900);
    final request = ScenarioRequest(
      diveId: base.diveId,
      depths: base.depths,
      timestamps: base.timestamps,
      diveMode: base.diveMode,
      tanks: base.tanks,
      gasSwitches: base.gasSwitches,
      tankPressures: base.tankPressures,
      startCompartments: seed,
      startCns: 0,
      startOtu: 0,
      settings: base.settings,
      scenario: base.scenario,
    );
    final result = _handoff(d, request);
    expect(result.plan.initialTissueState, seed);
  });

  test('notes name what was not carried', () {
    final replay = _request(d, branchSeconds: 900, mode: ScenarioMode.replan);
    final replayDraft = replay.scenario.copyWith(mode: ScenarioMode.replay);
    expect(
      _handoff(d, replay, scenario: replayDraft).notes,
      [ScenarioHandoffNote.replayReplanned],
    );
    final policy = _request(
      d,
      branchSeconds: 900,
      interventions: const [AscentPolicyIntervention(extraLastStopSeconds: 120)],
    );
    expect(
      _handoff(d, policy).notes,
      [ScenarioHandoffNote.extraLastStopNotCarried],
    );
  });

  test('a branch at the first sample yields the remainder alone', () {
    final request = _request(d, branchSeconds: 0);
    final outcome = const ScenarioEngine().run(request);
    final result = _handoff(d, request);
    expect(result.plan.segments.length, outcome.compiledPlan!.segments.length);
  });

  test('a branch at the last sample does not throw', () {
    final request = _request(d, branchSeconds: d.timestamps.last);
    expect(() => _handoff(d, request), returnsNormally);
  });

  test('a rebreather request is refused', () {
    final request = _request(d, branchSeconds: 900, diveMode: DiveMode.ccr);
    final outcome = const ScenarioEngine().run(
      _request(d, branchSeconds: 900),
    );
    expect(
      () => buildScenarioPlanHandoff(
        request: request,
        outcome: outcome,
        scenario: request.scenario,
        dive: _dive(d),
        profile: _dive(d).profile,
        gasSwitches: _switches(d),
        defaults: _defaults(),
        planName: 'x',
      ),
      throwsArgumentError,
    );
  });

  test('a replay outcome without a compiled plan is refused', () {
    final request = _request(d, branchSeconds: 900, mode: ScenarioMode.replay);
    final outcome = const ScenarioEngine().run(request);
    expect(outcome.compiledPlan, isNull);
    expect(
      () => buildScenarioPlanHandoff(
        request: request,
        outcome: outcome,
        scenario: request.scenario,
        dive: _dive(d),
        profile: _dive(d).profile,
        gasSwitches: _switches(d),
        defaults: _defaults(),
        planName: 'x',
      ),
      throwsArgumentError,
    );
  });
}
```

If `GasSwitch`'s constructor names differ from the ones used in `_switches` (check `lib/features/dive_log/domain/entities/gas_switch.dart`), match the constructor; the fields used are `id`, `diveId`, `timestamp`, `tankId`, `createdAt`.

- [ ] **Step 2: Run them to see them fail**

```bash
flutter test test/features/dive_lab/domain/services/scenario_plan_handoff_test.dart
```

Expected: compile failure, `scenario_plan_handoff.dart` not found.

- [ ] **Step 3: Write the service**

`lib/features/dive_lab/domain/services/scenario_plan_handoff.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/dive_to_plan_converter.dart';
import 'package:uuid/uuid.dart';

/// What the planner could not take over from the scenario. Rendered through
/// l10n by the page before the planner opens.
enum ScenarioHandoffNote {
  /// The draft was in replay mode; a plan always re-plans the ascent.
  replayReplanned,

  /// `ascentPolicy.extraLastStopSeconds` has no planner equivalent: the
  /// planner's per-depth stop minimum is a floor, not an addition.
  extraLastStopNotCarried,

  /// A lost cylinder was breathed before the branch, so the authored segments
  /// reference it and it stays on the plan.
  lostTankKept,
}

class ScenarioPlanHandoffResult {
  const ScenarioPlanHandoffResult({required this.plan, required this.notes});

  final DivePlanState plan;
  final List<ScenarioHandoffNote> notes;
}

/// The rebuild sheet's default detail level, reused so a hand-off and a
/// rebuild of the same dive author the pre-branch profile identically.
const int kHandoffDetailLevels = 3;

/// Builds the unsaved plan "Open in planner" loads: the dive authored through
/// the branch sample by [DiveToPlanConverter], then the lab's compiled
/// remainder with its interventions already applied, computed from the
/// surface like any other plan. Exact after the branch, approximate before
/// it, exactly as the rebuild sheet is.
///
/// Open-circuit only: the converter cannot author loop segments, so a
/// rebreather [request] is refused rather than handed off as open circuit.
/// [outcome] must be computed in re-plan mode (it carries the compiled plan);
/// [scenario] is the draft as the diver had it, so a replay draft yields a
/// note rather than a silent mode change.
ScenarioPlanHandoffResult buildScenarioPlanHandoff({
  required ScenarioRequest request,
  required ScenarioOutcome outcome,
  required DiveScenario scenario,
  required Dive dive,
  required List<DiveProfilePoint> profile,
  required List<GasSwitch> gasSwitches,
  required DivePlanState defaults,
  required String planName,
  String Function()? idGenerator,
}) {
  if (request.diveMode != DiveMode.oc) {
    throw ArgumentError.value(
      request.diveMode,
      'request.diveMode',
      'the planner hand-off is open-circuit only',
    );
  }
  final compiled = outcome.compiledPlan;
  if (compiled == null) {
    throw ArgumentError.value(
      outcome.mode,
      'outcome.mode',
      'the hand-off needs an outcome computed in re-plan mode',
    );
  }
  final newId = idGenerator ?? const Uuid().v4;
  final branchTimestamp = request.timestamps[outcome.branch.index];

  final converted = const DiveToPlanConverter().convert(
    dive: dive,
    profile: profile,
    gasSwitches: gasSwitches,
    levels: kHandoffDetailLevels,
    planName: planName,
    defaults: defaults,
    throughTimestamp: branchTimestamp,
    idGenerator: newId,
  );

  final notes = <ScenarioHandoffNote>[];

  // The compiled plan carries pressures at the branch (it starts there). A
  // plan computed from the surface must start from the logged start pressure
  // or the pre-branch consumption is charged twice. A hypothetical tank has no
  // logged counterpart and keeps its own.
  final original = {for (final t in request.tanks) t.id: t};
  var tanks = [
    for (final t in compiled.tanks)
      switch (original[t.id]?.startPressure) {
        final double p => t.copyWith(startPressure: p),
        _ => t,
      },
  ];

  for (final i in scenario.interventions) {
    if (i is! LoseTankIntervention) continue;
    final breathedBefore = converted.segments.any((s) => s.tankId == i.tankId);
    final lost = original[i.tankId];
    if (breathedBefore && lost != null && !tanks.any((t) => t.id == lost.id)) {
      tanks = [...tanks, lost]..sort((a, b) => a.order.compareTo(b.order));
      notes.add(ScenarioHandoffNote.lostTankKept);
    }
  }

  final authored = converted.segments.length;
  final remainder = [
    for (final (i, s) in compiled.segments.indexed)
      s.copyWith(order: authored + i),
  ];
  final segments = [...converted.segments, ...remainder];

  if (scenario.effectiveMode == ScenarioMode.replay) {
    notes.add(ScenarioHandoffNote.replayReplanned);
  }
  for (final i in scenario.interventions) {
    if (i is AscentPolicyIntervention && (i.extraLastStopSeconds ?? 0) > 0) {
      notes.add(ScenarioHandoffNote.extraLastStopNotCarried);
    }
  }

  final now = DateTime.now();
  final plan = stateFromDivePlan(compiled).copyWith(
    id: newId(),
    name: planName,
    segments: segments,
    tanks: tanks,
    initialTissueState: request.startCompartments,
    sourceDiveId: dive.id,
    altitude: converted.altitude,
    waterType: converted.waterType,
    salinityPpt: converted.salinityPpt,
    ppO2Bottom: request.settings.ppO2Working,
    ppO2Deco: request.settings.ppO2Deco,
    airBreaks: defaults.airBreaks,
    sacFactor: defaults.sacFactor,
    problemSolvingMinutes: defaults.problemSolvingMinutes,
    bestMixEndMeters: defaults.bestMixEndMeters,
    stopMinimums: const {},
    isDirty: false,
    createdAt: now,
    updatedAt: now,
  );
  return ScenarioPlanHandoffResult(plan: plan, notes: notes);
}
```

`DivePlanState.copyWith` gained `ppO2Bottom` and `ppO2Deco` with the gas options in PR #1639. If the analyzer reports either as an unknown named parameter, set them on the `DivePlan` before mapping instead (`stateFromDivePlan(compiled.copyWith(ppO2Bottom: ..., ppO2Deco: ...))`) and keep the rest of the `copyWith` as written. `PlanSegment.copyWith(order:)` and `DiveTank.copyWith(startPressure:)` exist (the compiler and the lab already use them).

- [ ] **Step 4: Run the tests to see them pass**

```bash
flutter test test/features/dive_lab/domain/services/scenario_plan_handoff_test.dart
```

Expected: 13 tests pass. If "a branch at the last sample" throws inside the converter, the converter's `_anchorIndices` received `endIndex` equal to the last sample; that path is legal and the fix belongs in the converter, not the service.

- [ ] **Step 5: Format and commit**

```bash
dart format . && flutter analyze && git add lib/features/dive_lab/domain/services/scenario_plan_handoff.dart test/features/dive_lab/domain/services/scenario_plan_handoff_test.dart && git commit -m "feat(dive-lab): build a planner plan from a branched scenario

buildScenarioPlanHandoff authors the dive through the branch with the
converter, appends the lab's compiled remainder, restores logged start
pressures, maps settings field for field and reports what the planner
cannot carry: a replay draft, extra last-stop seconds, a lost cylinder
that was breathed before the branch."
```

---

### Task 7: Strings for the overflow menu and the hand-off

Nine keys in all eleven locales. `app_en.arb` is alphabetical; the other ten are feature-grouped, so the keys go right after the `diveLab_share_image` entry in each.

**Files:**
- Modify: all eleven `lib/l10n/arb/app_*.arb`; regenerate `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: `l10n.diveLab_menu_title`, `diveLab_menu_openInPlanner`, `diveLab_menu_rebuildInPlanner`, `diveLab_menu_openInPlanner_loopDisabled`, `diveLab_handoff_planName(String dive, String scenario)`, `diveLab_handoff_note_replay`, `diveLab_handoff_note_extraLastStop`, `diveLab_handoff_note_lostTankKept`, `diveLab_handoff_failed(String error)`. Task 8 uses all of them.

- [ ] **Step 1: Insert the keys**

```bash
python3.14 - <<'PY'
import json
from pathlib import Path

STRINGS = {
  "en": ["More", "Open in planner", "Rebuild in planner...",
         "Open in planner is available for open-circuit dives only",
         "What if: {dive} ({scenario})",
         "The planner re-plans the ascent; the replay path was not carried over.",
         "Extra last-stop time was not carried over; set a stop minimum in the planner.",
         "The lost cylinder stays listed because it was breathed before the branch; remove it in the planner if needed.",
         "Couldn't open in planner: {error}"],
  "de": ["Mehr", "Im Planer öffnen", "Im Planer neu aufbauen...",
         "Im Planer öffnen ist nur für Tauchgänge mit offenem Kreislauf verfügbar",
         "Was wäre wenn: {dive} ({scenario})",
         "Der Planer berechnet den Aufstieg neu; der Replay-Pfad wurde nicht übernommen.",
         "Zusätzliche Zeit am letzten Stopp wurde nicht übernommen; lege im Planer eine Mindeststoppzeit fest.",
         "Die verlorene Flasche bleibt aufgeführt, weil sie vor der Verzweigung geatmet wurde; entferne sie bei Bedarf im Planer.",
         "Öffnen im Planer fehlgeschlagen: {error}"],
  "es": ["Más", "Abrir en el planificador", "Reconstruir en el planificador...",
         "Abrir en el planificador solo está disponible para inmersiones en circuito abierto",
         "Y si: {dive} ({scenario})",
         "El planificador recalcula el ascenso; la trayectoria de repetición no se ha trasladado.",
         "El tiempo extra en la última parada no se ha trasladado; fija un mínimo de parada en el planificador.",
         "La botella perdida sigue en la lista porque se respiró antes de la bifurcación; elimínala en el planificador si hace falta.",
         "No se pudo abrir en el planificador: {error}"],
  "fr": ["Plus", "Ouvrir dans le planificateur", "Reconstruire dans le planificateur...",
         "Ouvrir dans le planificateur n'est disponible que pour les plongées en circuit ouvert",
         "Et si : {dive} ({scenario})",
         "Le planificateur recalcule la remontée ; le trajet rejoué n'a pas été repris.",
         "Le temps supplémentaire au dernier palier n'a pas été repris ; définissez un minimum de palier dans le planificateur.",
         "La bouteille perdue reste listée car elle a été respirée avant l'embranchement ; retirez-la dans le planificateur si besoin.",
         "Impossible d'ouvrir dans le planificateur : {error}"],
  "it": ["Altro", "Apri nel pianificatore", "Ricostruisci nel pianificatore...",
         "Apri nel pianificatore è disponibile solo per immersioni a circuito aperto",
         "E se: {dive} ({scenario})",
         "Il pianificatore ricalcola la risalita; il percorso del replay non è stato riportato.",
         "Il tempo extra all'ultima tappa non è stato riportato; imposta un minimo di tappa nel pianificatore.",
         "La bombola persa resta in elenco perché è stata respirata prima della diramazione; rimuovila nel pianificatore se serve.",
         "Impossibile aprire nel pianificatore: {error}"],
  "nl": ["Meer", "Openen in planner", "Opnieuw opbouwen in planner...",
         "Openen in planner is alleen beschikbaar voor open-circuitduiken",
         "Wat als: {dive} ({scenario})",
         "De planner berekent de opstijging opnieuw; het replay-pad is niet overgenomen.",
         "Extra tijd op de laatste stop is niet overgenomen; stel een minimale stop in de planner in.",
         "De verloren fles blijft vermeld omdat er vóór de vertakking uit is geademd; verwijder hem zo nodig in de planner.",
         "Kon niet openen in planner: {error}"],
  "pt": ["Mais", "Abrir no planeador", "Reconstruir no planeador...",
         "Abrir no planeador só está disponível para mergulhos em circuito aberto",
         "E se: {dive} ({scenario})",
         "O planeador recalcula a subida; o trajeto do replay não foi transposto.",
         "O tempo extra na última paragem não foi transposto; define um mínimo de paragem no planeador.",
         "A garrafa perdida continua listada porque foi respirada antes da ramificação; remove-a no planeador se necessário.",
         "Não foi possível abrir no planeador: {error}"],
  "hu": ["Több", "Megnyitás a tervezőben", "Újraépítés a tervezőben...",
         "A tervezőben megnyitás csak nyitott rendszerű merülésekhez érhető el",
         "Mi lenne, ha: {dive} ({scenario})",
         "A tervező újratervezi a felmerülést; a visszajátszott útvonal nem került át.",
         "Az utolsó megállón töltött plusz idő nem került át; állíts be megállási minimumot a tervezőben.",
         "Az elveszett palack listázva marad, mert az elágazás előtt lélegeztél belőle; szükség esetén távolítsd el a tervezőben.",
         "Nem sikerült megnyitni a tervezőben: {error}"],
  "ar": ["المزيد", "فتح في المخطط", "إعادة البناء في المخطط...",
         "فتح في المخطط متاح لغوصات الدائرة المفتوحة فقط",
         "ماذا لو: {dive} ({scenario})",
         "يعيد المخطط تخطيط الصعود؛ لم يُنقل مسار إعادة التشغيل.",
         "لم يُنقل الوقت الإضافي في المحطة الأخيرة؛ حدد حدًا أدنى للمحطة في المخطط.",
         "تبقى الأسطوانة المفقودة مدرجة لأنك تنفست منها قبل نقطة التفرع؛ أزلها في المخطط عند الحاجة.",
         "تعذر الفتح في المخطط: {error}"],
  "he": ["עוד", "פתיחה במתכנן", "בנייה מחדש במתכנן...",
         "פתיחה במתכנן זמינה רק לצלילות במעגל פתוח",
         "מה אם: {dive} ({scenario})",
         "המתכנן מתכנן מחדש את העלייה; מסלול השחזור לא הועבר.",
         "זמן נוסף בתחנה האחרונה לא הועבר; הגדר מינימום תחנה במתכנן.",
         "הבלון שאבד נשאר ברשימה כי נשמת ממנו לפני נקודת ההסתעפות; הסר אותו במתכנן במידת הצורך.",
         "לא ניתן לפתוח במתכנן: {error}"],
  "zh": ["更多", "在计划器中打开", "在计划器中重建...",
         "仅开放式回路潜水可在计划器中打开",
         "假如：{dive}（{scenario}）",
         "计划器会重新规划上升；回放路径未被带入。",
         "最后一站的额外时间未被带入；请在计划器中设置停留最短时间。",
         "丢失的气瓶仍在列表中，因为在分支点之前曾使用过；如有需要请在计划器中移除。",
         "无法在计划器中打开：{error}"],
}
KEYS = ["diveLab_menu_title", "diveLab_menu_openInPlanner", "diveLab_menu_rebuildInPlanner",
        "diveLab_menu_openInPlanner_loopDisabled", "diveLab_handoff_planName",
        "diveLab_handoff_note_replay", "diveLab_handoff_note_extraLastStop",
        "diveLab_handoff_note_lostTankKept", "diveLab_handoff_failed"]
META = {
  "diveLab_handoff_planName": '{"placeholders": {"dive": {"type": "String"}, "scenario": {"type": "String"}}}',
  "diveLab_handoff_failed": '{"placeholders": {"error": {"type": "String"}}}',
}

def entry(key, value, with_meta):
    lines = [f'  "{key}": {json.dumps(value, ensure_ascii=False)}']
    if with_meta and key in META:
        lines.append(f'  "@{key}": {META[key]}')
    return ",\n".join(lines)

for loc, values in STRINGS.items():
    path = Path(f"lib/l10n/arb/app_{loc}.arb")
    s = path.read_text(encoding="utf-8")
    assert not any(f'"{k}"' in s for k in KEYS), f"{loc}: already present"
    with_meta = '"@diveLab_share_failed"' in s
    block = ",\n".join(entry(k, v, with_meta) for k, v in zip(KEYS, values))
    if loc == "en":
        # Alphabetical: each key goes before the first existing top-level key that sorts after it.
        for k, v in zip(KEYS, values):
            keys = [line.split('"')[1] for line in s.splitlines() if line.startswith('  "') and not line.startswith('  "@')]
            after = next((x for x in keys if x > k), None)
            piece = entry(k, v, with_meta) + ",\n"
            if after is None:
                s = s.rstrip().rstrip("}").rstrip().rstrip(",") + ",\n" + piece.rstrip(",\n") + "\n}\n"
            else:
                idx = s.index(f'\n  "{after}":') + 1
                s = s[:idx] + piece + s[idx:]
    else:
        anchor = '"diveLab_share_image":'
        idx = s.index(anchor)
        line_end = s.index("\n", idx)
        # Skip a following @metadata object for the anchor key, if any.
        if s[line_end + 1:].lstrip().startswith('"@diveLab_share_image"'):
            line_end = s.index("\n", s.index("}", line_end))
        insert = "\n" + block + ("," if s[line_end - 1] == "," else "")
        if s[line_end - 1] != ",":
            s = s[:line_end] + "," + insert + s[line_end:]
        else:
            s = s[:line_end] + insert + s[line_end:]
    json.loads(s)
    path.write_text(s, encoding="utf-8")
    print(loc, "ok")
PY
```

Expected: eleven `ok` lines and every file still parses. If the `en` insertion lands a key at a wrong spot, the file is still valid; ordering is a convention, not a test.

- [ ] **Step 2: Regenerate and check parity**

```bash
flutter gen-l10n && flutter test test/l10n/arb_parity_test.dart test/l10n/arb_no_duplicate_keys_test.dart test/l10n/arb_diacritics_test.dart && grep -c "diveLab_handoff_planName" lib/l10n/arb/app_localizations.dart
```

Expected: tests pass; the count is at least 1.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb && git commit -m "feat(dive-lab): strings for the lab overflow and the planner hand-off"
```

---

### Task 8: Lab overflow menu, Open in planner, Rebuild in planner

The share-only menu on the lab page becomes one overflow: the three share actions, a divider, then the two planner actions. "Open in planner" runs the engine once in re-plan mode, builds the hand-off, loads it into the planner notifier, shows the notes, and pushes the planner route on top of the lab.

**Files:**
- Modify: `lib/features/dive_lab/presentation/pages/dive_lab_page.dart`
- Test: `test/features/dive_lab/presentation/pages/dive_lab_page_planner_test.dart` (new)

**Interfaces:**
- Consumes: `buildScenarioPlanHandoff` (Task 6), the strings (Task 7), `showWhatIfSheet` from `what_if_sheet.dart`, `divePlanNotifierProvider` (`newPlan()`, `loadPlan(DivePlanState)`), `gasSwitchesProvider(diveId)` (a `FutureProvider.family` of `List<GasSwitchWithTank>`), `scenarioEngineRunnerProvider`, `labScenarioSummary` and `labTankName` from `lab_format.dart`.

- [ ] **Step 1: Write the failing widget tests**

`test/features/dive_lab/presentation/pages/dive_lab_page_planner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

LabRequestInputs _inputs({DiveMode mode = DiveMode.oc}) {
  final d = squareDive(depth: 40, bottomMinutes: 25);
  final dive = Dive(
    id: 'd',
    diveNumber: 1,
    name: 'Wreck',
    dateTime: DateTime(2026, 9, 25, 9),
    diveMode: mode,
    tanks: d.tanks,
    profile: [
      for (var i = 0; i < d.depths.length; i++)
        DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
    ],
  );
  return LabRequestInputs(
    dive: dive,
    profile: dive.profile,
    depths: d.depths,
    timestamps: d.timestamps,
    diveMode: mode,
    tanks: d.tanks,
    gasSwitches: d.switches,
    tankPressures: d.tankPressures,
    startCns: 0,
    startOtu: 0,
    settings: const ScenarioSettings(),
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/dives/d',
  routes: [
    GoRoute(
      path: '/dives/:id',
      builder: (_, _) => Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDiveLab(context, 'd'),
            child: const Text('open lab'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/planning/dive-planner',
      builder: (_, _) => const Scaffold(body: Text('planner page')),
    ),
  ],
);

Widget _app(GoRouter router, LabRequestInputs inputs) => testAppRouter(
  router: router,
  locale: const Locale('en'),
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    labRequestInputsProvider('d').overrideWith((ref) async => inputs),
    labDefaultBranchProvider('d').overrideWith((ref) async => 900),
    scenarioEngineRunnerProvider.overrideWithValue(
      (request) async => const ScenarioEngine().run(request),
    ),
    gasSwitchesProvider.overrideWith((ref, id) async => <GasSwitchWithTank>[]),
    diveProvider.overrideWith((ref, id) async => inputs.dive),
    divesProvider.overrideWith((ref) async => <Dive>[]),
    diveProfileProvider.overrideWith((ref, id) async => inputs.profile),
  ],
);

Future<void> _openLabAndMenu(WidgetTester tester) async {
  await tester.tap(find.text('open lab'));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.byTooltip('More'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the overflow lists share and planner actions', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, _inputs()));
    await tester.pumpAndSettle();
    await _openLabAndMenu(tester);
    expect(find.text('Share as PDF'), findsOneWidget);
    expect(find.text('Open in planner'), findsOneWidget);
    expect(find.text('Rebuild in planner...'), findsOneWidget);
    expect(find.byType(PopupMenuDivider), findsOneWidget);
  });

  testWidgets('Open in planner loads the hand-off and pushes the planner', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, _inputs()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('open lab')),
    );
    await _openLabAndMenu(tester);
    await tester.tap(find.text('Open in planner'));
    await tester.pumpAndSettle();
    final state = container.read(divePlanNotifierProvider);
    expect(state.sourceDiveId, 'd');
    expect(state.name, startsWith('What if: Wreck'));
    expect(state.segments, isNotEmpty);
    expect(find.text('planner page'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/planning/dive-planner',
    );
  });

  testWidgets('Open in planner is disabled on a rebreather dive', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, _inputs(mode: DiveMode.ccr)));
    await tester.pumpAndSettle();
    await _openLabAndMenu(tester);
    final item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Open in planner'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(item.enabled, isFalse);
    expect(
      find.text('Open in planner is available for open-circuit dives only'),
      findsOneWidget,
    );
  });

  testWidgets('Rebuild in planner opens the rebuild sheet over the lab', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, _inputs()));
    await tester.pumpAndSettle();
    await _openLabAndMenu(tester);
    await tester.tap(find.text('Rebuild in planner...'));
    await tester.pumpAndSettle();
    expect(find.byType(WhatIfSheet), findsOneWidget);
    expect(find.byType(DiveLabPage), findsOneWidget);
  });
}
```

The replay-note path is covered by Task 6's unit test; the page renders whatever notes the service returns, so no widget test repeats it.

- [ ] **Step 2: Run them to see them fail**

```bash
flutter test test/features/dive_lab/presentation/pages/dive_lab_page_planner_test.dart
```

Expected: the first test fails at `find.byTooltip('More')` (the button is still the share menu).

- [ ] **Step 3: Replace the share menu with the overflow and add the two actions**

In `lib/features/dive_lab/presentation/pages/dive_lab_page.dart`:

1. Add imports (keep the file's alphabetical grouping):

```dart
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_plan_handoff.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
```

2. Replace the `PopupMenuButton<String>` in the app bar `actions` with:

```dart
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.diveLab_menu_title,
            enabled: inputs != null,
            onSelected: (value) {
              if (inputs == null) return;
              switch (value) {
                case 'pdf' || 'file' || 'image':
                  _share(value, inputs);
                case 'planner':
                  _openInPlanner(inputs);
                case 'rebuild':
                  showWhatIfSheet(context, inputs.dive);
              }
            },
            itemBuilder: (context) {
              final canShare = draft.isSeeded;
              final isOc = inputs?.diveMode == DiveMode.oc;
              return [
                PopupMenuItem(
                  value: 'pdf',
                  enabled: canShare,
                  child: Text(l10n.diveLab_share_pdf),
                ),
                PopupMenuItem(
                  value: 'file',
                  enabled: canShare,
                  child: Text(l10n.diveLab_share_file),
                ),
                PopupMenuItem(
                  value: 'image',
                  enabled: canShare,
                  child: Text(l10n.diveLab_share_image),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'planner',
                  enabled: canShare && isOc,
                  child: isOc
                      ? Text(l10n.diveLab_menu_openInPlanner)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.diveLab_menu_openInPlanner),
                            Text(
                              l10n.diveLab_menu_openInPlanner_loopDisabled,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                ),
                PopupMenuItem(
                  value: 'rebuild',
                  child: Text(l10n.diveLab_menu_rebuildInPlanner),
                ),
              ];
            },
          ),
```

3. Add the hand-off method to `_DiveLabPageState`, next to `_share`:

```dart
  String _noteText(AppLocalizations l10n, ScenarioHandoffNote note) =>
      switch (note) {
        ScenarioHandoffNote.replayReplanned => l10n.diveLab_handoff_note_replay,
        ScenarioHandoffNote.extraLastStopNotCarried =>
          l10n.diveLab_handoff_note_extraLastStop,
        ScenarioHandoffNote.lostTankKept =>
          l10n.diveLab_handoff_note_lostTankKept,
      };

  /// Hands the current draft to the planner as an unsaved plan and opens the
  /// planner on top of the lab, so back returns here. The engine runs once
  /// more in re-plan mode (the hand-off needs the compiled remainder even for
  /// a replay draft); the result is loaded only after it is fully built.
  Future<void> _openInPlanner(LabRequestInputs inputs) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final units = UnitFormatter(ref.read(settingsProvider));
    final draft = ref.read(labDraftProvider(diveId));
    if (!draft.isSeeded) return;
    try {
      final base = draft.toScenario(diveId);
      final scenario = base.copyWith(
        name:
            draft.name ??
            labScenarioSummary(
              l10n,
              units,
              base,
              (id) => labTankName(inputs.tanks, id),
            ),
      );
      final request = inputs.toRequest(
        scenario.copyWith(mode: ScenarioMode.replan),
      );
      final outcome = await ref.read(scenarioEngineRunnerProvider)(request);
      final switches = await ref.read(gasSwitchesProvider(diveId).future);
      if (!mounted) return;
      final dive = inputs.dive;
      final title = (dive.name?.isNotEmpty ?? false)
          ? dive.name!
          : units.formatDate(dive.entryTime ?? dive.dateTime);
      // newPlan() seeds exactly the defaults a fresh plan gets (reserve, GF,
      // water, SAC from the diver's settings); the rebuild sheet does the same.
      final notifier = ref.read(divePlanNotifierProvider.notifier);
      notifier.newPlan();
      final defaults = ref.read(divePlanNotifierProvider);
      final result = buildScenarioPlanHandoff(
        request: request,
        outcome: outcome,
        scenario: scenario,
        dive: dive,
        profile: inputs.profile,
        gasSwitches: [for (final s in switches) s.gasSwitch],
        defaults: defaults,
        planName: l10n.diveLab_handoff_planName(title, scenario.name),
      );
      notifier.loadPlan(result.plan);
      if (result.notes.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.notes.map((n) => _noteText(l10n, n)).join(' '),
            ),
          ),
        );
      }
      router.push('/planning/dive-planner');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLab_handoff_failed(e.toString()))),
      );
    }
  }
```

`GoRouter.of(context)` is read before the first `await` so no `BuildContext` crosses an async gap. If `units.formatDate` does not exist under that name on `UnitFormatter`, use the same call `what_if_sheet.dart` makes for its plan title.

- [ ] **Step 4: Run the tests to see them pass**

```bash
flutter test test/features/dive_lab/presentation/pages
```

Expected: the four new tests and the existing lab page tests pass. If the second test fails with `find.text('planner page')` finding nothing while the notifier state is correct, `GoRouter.of` did not resolve from the root-navigator page; switch to the rebuild sheet's sequence (`Navigator.of(context, rootNavigator: true).pop()` is not wanted here, so instead capture `GoRouter.of` from the `context` that called `showDiveLab` and pass a `void Function(String) push` into `DiveLabPage`; record the deviation in the commit message).

- [ ] **Step 5: Check the existing share tests still find the menu**

```bash
flutter test test/features/dive_lab/presentation/widgets/lab_saved_scenarios_sheet_share_test.dart test/features/dive_lab/presentation/pages/dive_lab_page_save_test.dart
```

Expected: pass. If a test opened the old share menu through `find.byTooltip('Share')` (`diveLab_share_menu`), update it to `find.byTooltip('More')`.

- [ ] **Step 6: Format and commit**

```bash
dart format . && flutter analyze && git add lib/features/dive_lab/presentation/pages/dive_lab_page.dart test/features/dive_lab/presentation/pages && git commit -m "feat(dive-lab): Open in planner and Rebuild in planner from the lab

One overflow replaces the share menu: share as PDF, file or image, then
Open in planner, which hands the draft to the planner as an unsaved plan
and pushes the planner on top of the lab, and Rebuild in planner, which
opens the existing rebuild sheet. Open in planner is disabled on loop
dives with the reason shown."
```

---

### Task 9: Point the original spec at the rethink

**Files:**
- Modify: `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md` (top status block)

- [ ] **Step 1: Add the note**

```bash
python3.14 - <<'PY'
from pathlib import Path
p = Path("docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md")
s = p.read_text(encoding="utf-8")
old = "Status: Approved design, pending implementation planning\n"
assert s.count(old) == 1
new = ("Status: Implemented on branch worktree-counterfactual-dive-lab; amended by\n"
       "`docs/superpowers/specs/2026-09-25-counterfactual-dive-lab-rethink-design.md`\n"
       "(front door, planner hand-off, single-PR delivery). Where the two differ,\n"
       "the rethink spec wins.\n")
p.write_text(s.replace(old, new), encoding="utf-8")
PY
git add docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md && git commit -m "docs: point the original Dive Lab spec at the rethink"
```

Expected: one commit.

---

### Task 10: Verification, issue and PR

**Files:** none new. Everything below is evidence gathering.

- [ ] **Step 1: Whole-project format, analyze and localization staleness**

```bash
dart format . && git status --short && flutter analyze && flutter gen-l10n && git status --short lib/l10n
```

Expected: `git status --short` empty after format (nothing left to format), "No issues found!", and nothing dirty under `lib/l10n` after regeneration.

- [ ] **Step 2: Architecture guards and the touched suites**

```bash
flutter test test/architecture test/features/dive_lab test/features/planner test/features/dive_log/presentation/widgets/what_if_sheet_test.dart test/core/constants test/core/database test/core/services/sync test/l10n
```

Expected: all pass.

- [ ] **Step 3: The full suite, once**

```bash
flutter test --exclude-tags performance
```

Expected: exit code 0. Do not pipe into `grep` (the pipe hides the exit status). Do not start a second run while this one is going. A single failure in a file this PR never touched is main's problem: check `git log origin/main -1 -- <file>` before touching it.

- [ ] **Step 4: Manual macOS smoke**

```bash
flutter build macos --debug
```

Then launch the built bundle from `build/macos/Build/Products/Debug/` with `open -n <bundle>.app` (not the installed app). If the app aborts right after its first frame, that is the TCC launching-app trap; launch it from a Ghostty terminal instead. Walk:

1. Open a real logged open-circuit dive with a profile. Menu: "What if...". Expect the Dive Lab, branch at the final-ascent start, panel populated.
2. Add "Ascend now". Expect the counterfactual overlay and a negative deco delta.
3. Overflow: "Open in planner". Expect the planner with the dashed original profile, the compare strip, and a plan whose segments end at the branch time followed by a zero-length hold. Back returns to the lab.
4. Overflow: "Rebuild in planner...". Expect today's sheet with the detail slider.
5. Open a gauge dive. Menu: "What if...". Expect the rebuild sheet directly.
6. Save a scenario, reopen the dive, confirm the "What if" section card lists it and opens it.

Record what you saw, including anything that did not match, in the PR body.

- [ ] **Step 5: Open the umbrella issue**

```bash
gh issue create --repo submersion-app/submersion --title "Dive Lab: branch a logged dive at a moment and compare what would have happened" --body "$(cat <<'BODY'
**Is your feature request related to a problem? Please describe.**
After a dive the questions are specific to a moment: what if I had lost the 50% at the first stop, what if we had started up five minutes earlier, could my remaining back gas have supported an out-of-gas buddy at minute 30, what would 40/85 have done. "What if..." today rebuilds the whole dive in the planner from simplified waypoints, which is the right tool for editing anything but cannot start from the exact tissue, CNS and gas state at a chosen instant, cannot follow the path actually swum with changed inputs, and cannot express a decision like "lost the deco bottle here" without hand-editing segments.

**Describe the solution you'd like**
A Dive Lab page on a logged dive: pick the branch moment, choose replay (same path, changed inputs) or re-plan (the engine computes the ascent from the branch), add interventions as named decisions (switch gas, lose a tank, ascend now or earlier, change gradient factors, share gas, bail out, ascent policy), and read the delta against what actually happened: TTS, deco, surface GF, CNS, gas per tank with reserve and empty instants, tissues, issues, buoyancy. Save scenarios (synced), share them as a PDF slate, a scenario file or an image.

"What if..." on dive detail opens the lab for eligible dives and keeps opening the rebuild sheet for gauge dives. From the lab, "Open in planner" hands the current scenario to the planner as an unsaved plan (the dive authored through the branch, then the branched remainder), and "Rebuild in planner..." opens today's sheet, so the free-form editor stays one tap away.

**Describe alternatives you've considered**
Folding the lab into the planner as a branch mode: loses replay mode and the named-decision chips, and needs a planner-wide locked-prefix concept. Keeping two unrelated "What if" entries: confusing on one dive.

**Additional context**
Design: docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md and docs/superpowers/specs/2026-09-25-counterfactual-dive-lab-rethink-design.md on the PR branch.
BODY
)"
```

Expected: an issue URL. Note its number as N for the next step.

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin ericgriffin/counterfactual-dive-lab-rethink-f2b015
```

Then:

```bash
gh pr create --repo submersion-app/submersion --title "Dive Lab: branch a logged dive at a moment and compare what would have happened" --body "$(cat <<'BODY'
## Summary

Adds the Dive Lab: branch a logged dive at any moment, apply interventions, and compare the alternate timeline (deco, tissues, CNS/OTU, gas, buoyancy) against what happened. Scenarios save to a new synced table and share as a PDF slate, a `.sublab` file or an image.

"What if..." on dive detail now opens the lab for open-circuit and rebreather dives with a profile, and still opens the rebuild-in-planner sheet for gauge dives. From the lab, "Open in planner" hands the current scenario to the planner as an unsaved plan and "Rebuild in planner..." opens the existing sheet.

Closes #N

## Changes

- Engine and domain (`lib/features/dive_lab/domain/`): `ScenarioEngine` composes `ProfileAnalysisService` (replay) with `PlanEngine.compute(plan, startState:)` (re-plan); `DecoStatus.gfLowCeilingAnchor` makes the mid-dive restore exact; interventions with a versioned JSON codec; consumption pass; deltas and verdict.
- Lab page: chart overlay, branch slider and steppers, mode toggle, intervention chips and sheet, delta panel with buoyancy rows, saved-scenarios sheet, PDF slate, `.sublab` export and import.
- Persistence and sync: `dive_scenarios` at schema v227 (hlc column, deletion_log tombstones, cascade on dive delete), registered at every sync site with the structural tests as backstop.
- Dive detail: `DiveDetailSectionId.diveLab` teaser card; the "What if..." item routes through `openWhatIf`.
- Planner: `DiveToPlanConverter` gains `throughTimestamp`; `PlanEngine.ascentPlanFor` is public.
- Hand-off: `buildScenarioPlanHandoff` (pure Dart) authors the dive through the branch with the converter, appends the lab's compiled remainder, restores logged start pressures, maps settings field for field and reports what the planner cannot carry (replay drafts, extra last-stop seconds, a lost cylinder breathed before the branch). Open-circuit only in this PR.

## Not in this PR

- An exact branched plan in the planner (locked prefix, branch state on saved plans).
- Hand-off on rebreather dives (converter work).
- Universal-import routing for `.sublab`; hypothetical cylinders in the buoyancy twin.

## Verification

- `flutter analyze` clean, `dart format` clean, generated l10n up to date.
- Full suite: <count> passed, exit 0.
- Manual macOS walk: <what you saw in Task 10 Step 4>.

Design: `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md`, `docs/superpowers/specs/2026-09-25-counterfactual-dive-lab-rethink-design.md`.
BODY
)"
```

Replace `N` with the issue number and the two `<...>` placeholders with the real figures before running. No attribution lines, no session links.

Expected: a PR URL. The "PR Issue Link" check needs `Closes #N` exactly as written; a number elsewhere does not count.

- [ ] **Step 7: Bind the PR in the desktop app and read CI**

Use the app's PR tools (`get_status`, then `bind_pr` if the PR is not reported) and read CI from there. Do not poll CI by hand. If CI fails in a file this PR never touched, main is red: cherry-pick the fix verbatim only if this branch has the flagged files.
