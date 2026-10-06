# SAC to RMV Relabel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Relabel every surface that only ever handles a volume rate (L/min or cuft/min) from "SAC" to "RMV", in all eleven locales, without touching any calculation, schema, or persisted field.

**Architecture:** The planner, the dive planner's gas section, the two gas calculators, the gas-model explanation, and the rock-bottom "about" text are hard-wired to L/min and never read the SAC unit preference. This PR changes their l10n *values* (key names stay), renames the two non-persisted `UnitAxis` factories, and pins the rule with an l10n test. It is the first of two PRs; the second (`2026-08-26-sac-rmv-split.md`) restructures the preference and is independent of this one.

**Tech Stack:** Flutter, `flutter gen-l10n` (ARB files under `lib/l10n/arb/`, generated `app_localizations*.dart` checked in), `flutter test`.

**Spec:** `docs/superpowers/specs/2026-08-26-sac-rmv-split-design.md`, sections D1 (code naming), D8 (planner and calculator keys), and Sequencing item 1.

## Global Constraints

- No em-dashes or en-dashes anywhere (code, comments, commits, ARB values).
- No emojis in code or comments.
- Persisted planner fields (`DivePlan.sacBottom`, `sacDeco`, `sacStressed`, their Drift columns, plan-file codec keys) and the calculator provider names (`consumptionSacProvider`, `rockBottomSacProvider`, `rockBottomBuddySacProvider`) are NOT renamed.
- l10n key names are NOT renamed in this PR; only values change.
- German keeps `AMV` for the volume rate (it already does; no German value changes in this PR).
- `flutter gen-l10n` runs LAST, after every locale ARB has its new value; running it earlier bakes English fallbacks into `app_localizations_XX.dart`.
- Never json-round-trip an ARB file (it re-indents the compact `@meta` entries and produces hundreds of unrelated changed lines). Edit values line by line.
- Run `dart format .` before every commit.
- Commit messages carry no `Co-Authored-By` trailer and no session URL.

## Worktree

This plan runs in its own worktree, cut from `origin/main`:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git fetch -q origin
git worktree add -b worktree-sac-rmv-relabel .claude/worktrees/sac-rmv-relabel origin/main
cd .claude/worktrees/sac-rmv-relabel
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Every path below is relative to `.claude/worktrees/sac-rmv-relabel/`. Use worktree-absolute paths for every Read/Edit/Write; the Bash cwd can silently revert to the main checkout between turns.

Copy this plan into the worktree before starting so it can be committed on the branch:

```bash
cp /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/sac-rmv-split/docs/superpowers/plans/2026-08-26-sac-rmv-relabel.md \
   /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/sac-rmv-relabel/docs/superpowers/plans/
```

---

### Task 1: Rename the volume-only `UnitAxis` factories

**Files:**
- Modify: `lib/core/utils/unit_axis.dart:7` (doc comment), `:111-128` (factories)
- Modify: `lib/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart:108`
- Modify: `lib/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart:171`, `:181`
- Test: `test/core/utils/unit_axis_test.dart`

**Interfaces:**
- Produces: `factory UnitAxis.stressedRmv(UnitFormatter units)` (canonical 15-40 L/min) and `factory UnitAxis.normalRmv(UnitFormatter units)` (canonical 8-30 L/min). Same `UnitAxis` shape as before (`min`, `max`, `step`, `decimals`, `symbol`, `toDisplay`, `toCanonical`, `format`).

- [ ] **Step 1: Rename the test group and add the missing `normalRmv` coverage**

In `test/core/utils/unit_axis_test.dart`, replace the group header `group('UnitAxis.stressedSac', () {` with `group('UnitAxis.stressedRmv', () {` and every `UnitAxis.stressedSac(` inside it with `UnitAxis.stressedRmv(`. Then add this group directly after it (before `group('UnitAxis.ascentRate'`):

```dart
  group('UnitAxis.normalRmv', () {
    test('metric exposes the canonical 8-30 L/min range', () {
      final axis = UnitAxis.normalRmv(_metric());
      expect(axis.min, 8);
      expect(axis.max, 30);
      expect(axis.step, 1);
      expect(axis.decimals, 0);
      expect(axis.symbol, 'L/min');
    });

    test('imperial snaps inward to a selectable cuft/min range', () {
      final axis = UnitAxis.normalRmv(_imperial());
      // 8 L/min = 0.2825 cuft/min, ceiled to 0.30; 30 L/min = 1.0594,
      // floored to 1.05. Snapping inward keeps both bounds inside the
      // canonical range.
      expect(axis.min, closeTo(0.30, 1e-9));
      expect(axis.max, closeTo(1.05, 1e-9));
      expect(axis.step, closeTo(0.05, 1e-9));
      expect(axis.decimals, 2);
      expect(axis.symbol, 'cuft/min');
    });

    test('roundtrips canonical -> display -> canonical', () {
      final axis = UnitAxis.normalRmv(_imperial());
      final display = axis.toDisplay(17.0);
      expect(axis.toCanonical(display), closeTo(17.0, 1e-6));
    });
  });
```

- [ ] **Step 2: Run the test file to verify it fails**

Run: `flutter test test/core/utils/unit_axis_test.dart`
Expected: compile error, `The method 'stressedRmv' isn't defined` / `'normalRmv' isn't defined`.

- [ ] **Step 3: Rename the factories**

In `lib/core/utils/unit_axis.dart`, replace lines 111-128:

```dart
  /// Stressed SAC for emergency planning, canonical 15-40 L/min.
  factory UnitAxis.stressedSac(UnitFormatter units) => _sac(units, 15, 40);

  /// Working SAC for consumption planning, canonical 8-30 L/min.
  factory UnitAxis.normalSac(UnitFormatter units) => _sac(units, 8, 30);

  static UnitAxis _sac(UnitFormatter units, double minL, double maxL) {
```

with:

```dart
  /// Stressed RMV for emergency planning, canonical 15-40 L/min.
  factory UnitAxis.stressedRmv(UnitFormatter units) => _rmv(units, 15, 40);

  /// Working RMV for consumption planning, canonical 8-30 L/min.
  factory UnitAxis.normalRmv(UnitFormatter units) => _rmv(units, 8, 30);

  static UnitAxis _rmv(UnitFormatter units, double minL, double maxL) {
```

The body of `_rmv` is unchanged. On line 7 of the same file, change the doc fragment `liters per minute for SAC` to `liters per minute for RMV`.

- [ ] **Step 4: Update the three call sites**

`gas_consumption_calculator.dart:108`: `axis: UnitAxis.normalSac(units),` becomes `axis: UnitAxis.normalRmv(units),`.

`rock_bottom_calculator.dart:171` and `:181`: `axis: UnitAxis.stressedSac(units),` becomes `axis: UnitAxis.stressedRmv(units),` in both places.

- [ ] **Step 5: Run the tests and analyze**

Run: `flutter test test/core/utils/unit_axis_test.dart test/features/gas_calculators/`
Expected: all pass.

Run: `flutter analyze lib/core/utils/unit_axis.dart lib/features/gas_calculators/`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
dart format lib/core/utils/unit_axis.dart lib/features/gas_calculators/ test/core/utils/unit_axis_test.dart
git add lib/core/utils/unit_axis.dart lib/features/gas_calculators/ test/core/utils/unit_axis_test.dart
git commit -m "refactor(units): rename the volume-only UnitAxis factories to RMV"
```

---

### Task 2: Pin the relabel with an l10n test

**Files:**
- Create: `test/l10n/rmv_relabel_test.dart`

**Interfaces:**
- Consumes: the l10n getters listed in the test. Their key names do not change; only their values do (Task 3).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The planner, the gas calculators, the gas-model explanation, and the
/// rock-bottom about text only ever handle a volume rate (L/min), which the
/// app calls RMV. SAC is reserved for the pressure rate (bar/min). German
/// keeps AMV, its established term for the volume rate.
void main() {
  List<String> volumeOnlyLabels(AppLocalizations l10n) => [
    l10n.divePlanner_label_sacRate,
    l10n.divePlanner_semantics_sacRate('15', 'L'),
    l10n.gasCalculators_sacRate,
    l10n.gasCalculators_rockBottom_yourSac,
    l10n.gasCalculators_rockBottom_buddySac,
    l10n.gasCalculators_rockBottom_stressedSacRates,
    l10n.gasCalculators_rockBottom_stressedSacHint,
    l10n.gasCalculators_rockBottom_combinedStressedSac,
    l10n.gasCalculators_rockBottom_aboutDescription,
    l10n.settings_units_gasModel_explanation,
  ];

  test('the English volume-only labels say RMV', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.divePlanner_label_sacRate, 'RMV:');
    expect(
      en.divePlanner_semantics_sacRate('15', 'L'),
      'RMV: 15 L per minute',
    );
    expect(en.gasCalculators_sacRate, 'RMV');
    expect(en.gasCalculators_rockBottom_yourSac, 'Your RMV');
    expect(en.gasCalculators_rockBottom_buddySac, 'Buddy RMV');
    expect(en.gasCalculators_rockBottom_stressedSacRates, 'Stressed RMV');
    expect(
      en.gasCalculators_rockBottom_stressedSacHint,
      'Use a higher RMV to account for stress during an emergency',
    );
    expect(
      en.gasCalculators_rockBottom_combinedStressedSac,
      'Combined stressed RMV',
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('no volume-only label says SAC in ${locale.languageCode}', () {
      final l10n = lookupAppLocalizations(locale);
      for (final label in volumeOnlyLabels(l10n)) {
        expect(label, isNot(contains('SAC')), reason: label);
        // French used "CAS" for the same acronym in three keys.
        expect(label, isNot(contains('CAS')), reason: label);
      }
    });
  }

  test('German keeps AMV for the volume rate', () {
    final de = lookupAppLocalizations(const Locale('de'));
    expect(de.gasCalculators_rockBottom_yourSac, 'Dein AMV');
    expect(de.divePlanner_label_sacRate, 'AMV:');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/l10n/rmv_relabel_test.dart`
Expected: FAIL. The English test fails on `'RMV:'` vs `'SAC Rate:'`; every non-German locale test fails on `contains('SAC')` (French also on `CAS`). The German test passes already.

No commit yet; Task 3 turns it green.

---

### Task 3: Change the ten l10n values in all eleven ARBs

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (`app_de.arb` unchanged)
- Regenerate: `lib/l10n/arb/app_localizations*.dart` (12 files)
- Test: `test/l10n/rmv_relabel_test.dart` (from Task 2), `test/l10n/arb_parity_test.dart`, `test/l10n/german_sac_terminology_test.dart`

Values are edited in place, one line each; ICU placeholders (`{value}`, `{volumeSymbol}`) are kept verbatim. Where a locale's neighbouring keys in the same block are diacritic-stripped (es, fr, hu in the `gasCalculators_rockBottom_*` block), the new value matches that style.

- [ ] **Step 1: Edit the eight short keys**

Set each key to the value listed for the locale. `de` is not listed because it does not change.

`divePlanner_label_sacRate`
| locale | value |
| --- | --- |
| en | `RMV:` |
| ar | `RMV:` |
| es | `RMV:` |
| fr | `RMV :` |
| he | `RMV:` |
| hu | `RMV:` |
| it | `RMV:` |
| nl | `RMV:` |
| pt | `RMV:` |
| zh | `RMV:` |

`divePlanner_semantics_sacRate`
| locale | value |
| --- | --- |
| en | `RMV: {value} {volumeSymbol} per minute` |
| ar | `RMV: {value} {volumeSymbol} في الدقيقة` |
| es | `RMV: {value} {volumeSymbol} por minuto` |
| fr | `RMV : {value} {volumeSymbol} par minute` |
| he | `RMV: {value} {volumeSymbol} לדקה` |
| hu | `RMV: {value} {volumeSymbol} percenként` |
| it | `RMV: {value} {volumeSymbol} al minuto` |
| nl | `RMV: {value} {volumeSymbol} per minuut` |
| pt | `RMV: {value} {volumeSymbol} por minuto` |
| zh | `RMV：每分钟 {value} {volumeSymbol}` |

`gasCalculators_sacRate`: `RMV` in en, ar, es, fr, he, hu, it, nl, pt, zh.

`gasCalculators_rockBottom_yourSac`
| locale | value |
| --- | --- |
| en | `Your RMV` |
| ar | `RMV الخاص بك` |
| es | `Tu RMV` |
| fr | `Votre RMV` |
| he | `ה-RMV שלך` |
| hu | `Sajat RMV` |
| it | `Il tuo RMV` |
| nl | `Jouw RMV` |
| pt | `Seu RMV` |
| zh | `您的 RMV` |

`gasCalculators_rockBottom_buddySac`
| locale | value |
| --- | --- |
| en | `Buddy RMV` |
| ar | `RMV الرفيق` |
| es | `RMV del companero` |
| fr | `RMV du binome` |
| he | `RMV השותף` |
| hu | `Buddy RMV` |
| it | `RMV compagno` |
| nl | `RMV buddy` |
| pt | `RMV do Companheiro` |
| zh | `潜伴 RMV` |

`gasCalculators_rockBottom_stressedSacRates`
| locale | value |
| --- | --- |
| en | `Stressed RMV` |
| ar | `RMV تحت الضغط` |
| es | `RMV bajo estres` |
| fr | `RMV majoree` |
| he | `RMV במצב לחץ` |
| hu | `Stresszes RMV` |
| it | `RMV sotto stress` |
| nl | `Stress-RMV` |
| pt | `RMV sob Stress` |
| zh | `应激 RMV` |

`gasCalculators_rockBottom_stressedSacHint`
| locale | value |
| --- | --- |
| en | `Use a higher RMV to account for stress during an emergency` |
| ar | `استخدم RMV أعلى لاحتساب الإجهاد أثناء الطوارئ` |
| es | `Usa un RMV mas alto para compensar el estres durante una emergencia` |
| fr | `Utilisez un RMV majore pour tenir compte du stress en urgence` |
| he | `השתמש ב-RMV גבוה יותר לפיצוי על לחץ במצב חירום` |
| hu | `Hasznaljon magasabb RMV erteket a veszhelyzeti stressz figyelembevetelere` |
| it | `Usa un RMV più alto per tenere conto dello stress durante l'emergenza` |
| nl | `Gebruik een hogere RMV om rekening te houden met stress tijdens een noodsituatie` |
| pt | `Use um RMV mais alto para compensar o stress durante emergencias` |
| zh | `使用较高的 RMV 以应对紧急情况下的压力` |

`gasCalculators_rockBottom_combinedStressedSac`
| locale | value |
| --- | --- |
| en | `Combined stressed RMV` |
| ar | `RMV المشترك تحت الضغط` |
| es | `RMV combinado bajo estres` |
| fr | `RMV majore combine` |
| he | `RMV משולב במצב לחץ` |
| hu | `Kombinalt stresszes RMV` |
| it | `RMV combinato sotto stress` |
| nl | `Gecombineerde stress-RMV` |
| pt | `RMV combinado sob stress` |
| zh | `合计应激 RMV` |

- [ ] **Step 2: Edit the two prose keys**

English, `app_en.arb:13623`, `gasCalculators_rockBottom_aboutDescription`: change the bullet `• Uses stressed SAC rates (2-3x normal)` to `• Uses a stressed RMV (2-3x normal)`. The rest of the value is unchanged.

English, `app_en.arb:9406`, `settings_units_gasModel_explanation`: set the value to

```
How cylinder pressure is converted to gas volume. This affects RMV, gas statistics, the planner, and the gas calculators. Ideal gas matches the arithmetic taught by training agencies; real gas is physically accurate and reads roughly 5% lower for RMV.
```

For the nine other non-German locales, replace the token `SAC` with `RMV` inside the value of those two keys only (and `CAS` with `RMV` in `app_fr.arb`), leaving every other character of the line untouched. Do it with a line-based script so nothing else in the file moves:

```bash
python3 - <<'EOF'
import json, pathlib, re
keys = ('gasCalculators_rockBottom_aboutDescription', 'settings_units_gasModel_explanation')
for code in ('ar', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh'):
    path = pathlib.Path(f'lib/l10n/arb/app_{code}.arb')
    src = path.read_text(encoding='utf-8')
    out = []
    for line in src.splitlines(keepends=True):
        if any(line.lstrip().startswith(f'"{k}"') for k in keys):
            line = line.replace('SAC', 'RMV')
            if code == 'fr':
                line = line.replace('CAS', 'RMV')
        out.append(line)
    new = ''.join(out)
    json.loads(new)  # prove it still parses
    path.write_text(new, encoding='utf-8')
    print(code, 'ok')
EOF
```

Then confirm by hand that each locale's two lines read naturally (`grep -n "gasCalculators_rockBottom_aboutDescription\|settings_units_gasModel_explanation" lib/l10n/arb/app_*.arb`). If a locale's value never contained the token (it describes the rate with a native phrase), it is correct as is; leave it.

- [ ] **Step 3: Prove every ARB still parses and no other line changed**

```bash
for f in lib/l10n/arb/app_*.arb; do python3 -c "import json,sys; json.load(open('$f', encoding='utf-8'))" && echo "$f ok"; done
git diff --stat -- lib/l10n/arb/
```

Expected: every file `ok`; the diff touches only the ten (nine plus English) ARBs, and each shows at most 10 changed lines (`app_de.arb` does not appear).

- [ ] **Step 4: Regenerate the localizations (last, after every ARB is edited)**

Run: `flutter gen-l10n`
Expected: no new "untranslated message" count beyond the pre-existing debt; `git status` shows the 12 `app_localizations*.dart` files modified.

Spot-check that a locale file carries its own value rather than the English fallback:

```bash
grep -A1 "get gasCalculators_rockBottom_yourSac" lib/l10n/arb/app_localizations_es.dart
```

Expected: `'Tu RMV'`.

- [ ] **Step 5: Run the l10n tests**

Run: `flutter test test/l10n/rmv_relabel_test.dart test/l10n/arb_parity_test.dart test/l10n/german_sac_terminology_test.dart`
Expected: all pass.

- [ ] **Step 6: Run the widget tests of the surfaces whose labels changed**

Run: `flutter test test/features/gas_calculators/ test/features/dive_planner/ test/features/data_quality/ test/features/settings/presentation/pages/settings_page_test.dart`
Expected: all pass. If a test asserts an old English label (`find.text('Your SAC')`, `find.text('SAC Rate:')`), update that assertion to the new value from Step 1; do not weaken it to a `contains`.

- [ ] **Step 7: Commit the ARBs and the generated files together**

```bash
git add lib/l10n/arb/ test/l10n/rmv_relabel_test.dart
git commit -m "i18n: label the volume-only consumption surfaces RMV"
```

---

### Task 4: Update the comments that still describe the volume rate as SAC

**Files:**
- Modify: `lib/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart:14-16`, `:85`
- Modify: `lib/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart:18`, `:137`
- Modify: `lib/features/data_quality/presentation/widgets/quality_finding_message.dart:16-18`
- Modify: `lib/features/data_quality/presentation/widgets/quality_unit_formatters.dart:14`

No behavior changes; comment text only. No test.

- [ ] **Step 1: Edit the comments**

`plan_gas_section.dart:14-16`: replace

```dart
/// Gas settings for the Setup accordion: SAC (with one-tap logged average)
/// and reserve pressure. Bottom/deco SAC split and SAC factor land here in
/// later phases (spec G25).
```

with

```dart
/// Gas settings for the Setup accordion: RMV (with one-tap logged average)
/// and reserve pressure. Bottom/deco RMV split and RMV factor land here in
/// later phases (spec G25).
```

`plan_gas_section.dart:85`: `/// One-tap SAC auto-fill from the diver's logged average ("from your log").` becomes `/// One-tap RMV auto-fill from the diver's logged average ("from your log").`

`rock_bottom_calculator.dart:18` and `:137`: replace the word `SAC` with `RMV` in those two comment lines (read each line first; keep the rest of the sentence).

`quality_finding_message.dart:16-18`: replace

```dart
  /// Formats a surface air consumption rate given in L/min into the diver's
  /// preferred volume unit (L/min vs cuft/min), including the unit suffix.
```

with

```dart
  /// Formats an RMV given in L/min into the diver's preferred volume unit
  /// (L/min vs cuft/min), including the unit suffix.
```

`quality_unit_formatters.dart:14`: the comment `// preference (L/min vs cuft/min) rather than the pressure-based SAC mode.` becomes `// preference (L/min vs cuft/min); this is an RMV, never a pressure rate.`

- [ ] **Step 2: Analyze and commit**

Run: `flutter analyze lib/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart lib/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart lib/features/data_quality/`
Expected: `No issues found!`

```bash
git add lib/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart lib/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart lib/features/data_quality/presentation/widgets/
git commit -m "docs(planner): describe the volume rate as RMV in comments"
```

---

### Task 5: Full verification and PR

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze`
Expected: `No issues found!` (infos count as failures in CI; fix any).

- [ ] **Step 2: Run the full test suite once**

Run: `flutter test`
Expected: all pass. A lone failure in a file unrelated to this change (media share, sync round trip, zip temp dir) is a known full-suite flake; rerun that file alone before treating it as real.

- [ ] **Step 3: Commit the plan file, push, open the PR**

```bash
git add docs/superpowers/plans/2026-08-26-sac-rmv-relabel.md
git commit -m "docs(plan): SAC to RMV relabel"
git push -u origin worktree-sac-rmv-relabel
gh pr create --title "i18n: label volume-only consumption surfaces RMV" --body "$(cat <<'EOF'
## Summary

The planner, the dive planner's gas section, the gas calculators, the gas-model explanation, and the rock-bottom about text only ever handle a volume rate (L/min or cuft/min). Divers and MacDive call that RMV; SAC is the tank-pressure rate (bar/min). This PR relabels those surfaces RMV in all eleven locales and renames the two non-persisted `UnitAxis` factories to match. No calculation, schema, or persisted field changes.

German keeps AMV (Atemminutenvolumen), which is already the volume-rate term throughout the German catalog.

Answers the label half of #803. The separate SAC/RMV representation from #354 follows in a second PR.

## Changes

- `UnitAxis.stressedSac` / `normalSac` renamed `stressedRmv` / `normalRmv`; `normalRmv` gains the imperial snapping test it never had.
- Ten l10n values relabeled in en, ar, es, fr, he, hu, it, nl, pt, zh (key names unchanged). French's three `CAS` spellings are folded into `RMV`.
- `test/l10n/rmv_relabel_test.dart` pins that no volume-only label says SAC in any locale and that German says AMV.

## Testing

- `flutter test` full suite green.
- `flutter analyze` clean.
EOF
)"
```

---

## Self-review notes

- Spec coverage: D1 code naming (UnitAxis rename: Task 1), D8 planner and calculator keys reworded to RMV with key names kept (Task 3), Sequencing item 1 (this whole plan). `dataQuality_msg_sac` and `plannerCanvas_sac_useLogged` are listed in D8 but their values never contained "SAC"; they are covered by the Task 2 test and need no edit.
- The Task 2 test references only getters that exist today with their current signatures (`divePlanner_semantics_sacRate(Object value, Object volumeSymbol)`).
- Task 1 imperial bounds were computed, not estimated: 8 L/min is 0.2825 cuft/min (ceil to 0.30), 30 L/min is 1.0594 (floor to 1.05), matching the inward-snapping rule the existing `stressedRmv` test already asserts for 15 and 40.
