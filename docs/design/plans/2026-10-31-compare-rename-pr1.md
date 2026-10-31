# Compare rename (PR 1 of the Compare design) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the Dive Lab to Compare in every user-visible string of PR #2407 before it merges, with no schema or behaviour change.

**Architecture:** Six l10n keys change value in all eleven ARB files and the generated localizations are rebuilt; two English fallbacks in `DiveDetailSectionId` follow. Code identifiers (`dive_lab`, `diveLab_`, `whatIf`) do not change. The PR's title, body and screenshots are redone for the new name.

**Tech Stack:** Flutter l10n (ARB + `flutter gen-l10n`), flutter_test, `gh`, one secret gist for screenshots.

**Spec:** `docs/design/specs/2026-10-31-compare-plan-vs-dive-design.md` (sections "Names" and "PR 1").

## Global Constraints

- No em dashes, en dashes as punctuation, double hyphens or spaced hyphens in anything written: code, comments, commit messages, the PR body.
- No mention of the tool or its vendor anywhere: commits, PR body, gist commits.
- Every renamed key gets a real translation in all ten non-English locales (ar, de, es, fr, he, hu, it, nl, pt, zh). `flutter gen-l10n` runs **last**, after every ARB is edited, and the generated `app_localizations_*.dart` files are committed with the ARBs.
- ARB files are edited line by line on the key's own line, never JSON round-tripped.
- Keys that keep their value: `diveLab_panel_whatIf` ("What if", the what-if column header), `diveLab_handoff_planName` ("What if: {dive} ({scenario})"), and every key whose prose says "what-if" (`diveLab_interventions_none`, `diveLab_kindDesc_changeGf`, `diveLab_panel_identity`).
- No code identifier changes: folder `lib/features/dive_lab/`, key prefix `diveLab_`, `DiveDetailSectionId.diveLab`, menu value `'whatIf'`, `openWhatIf`, test file names.
- `dart format .` before every commit; `flutter analyze` clean.
- The PR body keeps `Closes #2405`.
- Screenshots go into gist `7ea450ed9b16c94870b5c1b7f7d1caaf` ("PR screenshots: submersion-app/submersion"). Never delete a file from it; add new files with new names.
- No push without the maintainer's go-ahead (Task 4, last step).
- No user-guide page describes the Lab (checked 2026-10-31: `docs/user/` has no "Dive Lab" and its only "what if" is the planner's), and the demo seeder's scenario notes do not say "Lab", so neither changes in this PR. A Compare guide page is PR 2's docs step.

## Review Focus

- A locale whose ARB edit silently failed ships the English "Compare" as a fallback: Task 1 checks every locale's generated getter after `gen-l10n`.
- The Settings "Manage sections" list shows the section's name and description from `DiveDetailSectionId`: Task 1 pins both fallbacks and both l10n values.
- A gauge dive's "Compare…" entry still opens the rebuild sheet, not the Compare page: `what_if_entry_test.dart` already covers the routing and is in Task 3's run.
- The what-if column header in the delta panel must still read "What if" after the section header becomes "Compare": `lab_delta_panel_test.dart` line 76 already asserts it and is in Task 3's run.
- The PR body cites `docs/superpowers/specs/...` paths that no longer exist (the folder moved to `docs/design/specs/`), and `scripts/check_docs_links.py` fails CI if that folder is cited from code: Task 4 fixes the paths and runs the check.

---

### Task 1: Rename the strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (six keys each)
- Modify: `lib/core/constants/dive_detail_sections.dart:88` (English fallback name) and the `diveLab` arm of `description` (English fallback description)
- Modify: doc comments that quote the old menu label: `lib/features/dive_lab/presentation/what_if_entry.dart:7`, `lib/features/dive_lab/presentation/widgets/dive_lab_section.dart:13`, `tool/demo_data/src/seeders/lab_seeder.dart:13`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_test.dart:793-801`, `test/features/dive_lab/presentation/widgets/dive_lab_section_test.dart:36`, `test/features/dive_lab/presentation/pages/dive_lab_page_planner_test.dart`, `test/core/constants/dive_detail_sections_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: the l10n getters keep their names; only their values change. Task 4's screenshots show these values.

- [ ] **Step 1: Change the four test expectations to the new names**

`dive_detail_page_test.dart`: both `'What if…'` literals (lines 796 and 801) become `'Compare…'`; the comment on line 793 says "Compare is a whole-dive action".

`dive_lab_section_test.dart:36`: `expect(find.text('Compare'), findsOneWidget);`

`dive_lab_page_planner_test.dart`: a new `testWidgets('the app bar is titled Compare', ...)` in the style of 'the overflow lists share and planner actions' (line 112): pump `_app(router, _inputs())`, tap `find.text('open lab')`, settle, then
`expect(find.widgetWithText(AppBar, 'Compare'), findsOneWidget);`

`dive_detail_sections_test.dart`, inside the existing group:

```dart
test('the Compare section is named for what it does', () {
  expect(DiveDetailSectionId.diveLab.displayName, 'Compare');
  expect(
    DiveDetailSectionId.diveLab.description,
    'Plan, dive and saved what-ifs side by side',
  );
});
```

- [ ] **Step 2: Run the four files and confirm they fail on the old strings**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_lab/presentation/widgets/dive_lab_section_test.dart test/features/dive_lab/presentation/pages/dive_lab_page_planner_test.dart test/core/constants/dive_detail_sections_test.dart`
Expected: FAIL, four failures, each "Expected: exactly one matching candidate / Actual: zero" or the string mismatch on `displayName`.

- [ ] **Step 3: Replace the six values in every ARB**

Edit each key's own line in each file (a line-anchored substitution of the quoted value; `json.loads` the whole file afterwards to prove it still parses). `@` metadata lines are untouched. Values:

| Key | en | ar | de | es | fr |
| --- | --- | --- | --- | --- | --- |
| `diveLab_title` | Compare | مقارنة | Vergleichen | Comparar | Comparer |
| `diveDetailSection_diveLab_name` | Compare | مقارنة | Vergleichen | Comparar | Comparer |
| `diveLog_detail_menu_whatIf` | Compare… | مقارنة… | Vergleichen… | Comparar… | Comparer… |
| `diveDetailSection_diveLab_description` | Plan, dive and saved what-ifs side by side | الخطة والغوصة وسيناريوهات «ماذا لو» المحفوظة جنبًا إلى جنب | Plan, Tauchgang und gespeicherte Was-wäre-wenn-Szenarien nebeneinander | Plan, inmersión y escenarios hipotéticos guardados, lado a lado | Plan, plongée et scénarios « et si » enregistrés côte à côte |
| `diveLab_pdf_title` | What-if slate | بطاقة السيناريو | Szenario-Slate | Ficha del escenario | Fiche du scénario |
| `diveLab_sublab_notes` | Shared via a what-if scenario file | تمت المشاركة عبر ملف سيناريو | Geteilt über eine Szenariodatei | Compartido mediante un archivo de escenario | Partagé via un fichier de scénario |

| Key | he | hu | it | nl | pt | zh |
| --- | --- | --- | --- | --- | --- | --- |
| `diveLab_title` | השוואה | Összehasonlítás | Confronta | Vergelijken | Comparar | 对比 |
| `diveDetailSection_diveLab_name` | השוואה | Összehasonlítás | Confronta | Vergelijken | Comparar | 对比 |
| `diveLog_detail_menu_whatIf` | השוואה… | Összehasonlítás… | Confronta… | Vergelijken… | Comparar… | 对比… |
| `diveDetailSection_diveLab_description` | תוכנית, צלילה ותרחישי "מה אם" שמורים זה לצד זה | Terv, merülés és mentett „mi lett volna, ha” forgatókönyvek egymás mellett | Piano, immersione e scenari ipotetici salvati a confronto | Plan, duik en opgeslagen wat-als-scenario's naast elkaar | Plano, mergulho e cenários hipotéticos guardados lado a lado | 计划、潜水和已保存的假设情形并列对比 |
| `diveLab_pdf_title` | דף התרחיש | Forgatókönyv-lap | Scheda scenario | Scenario-slate | Ficha do cenário | 假设情形卡片 |
| `diveLab_sublab_notes` | שותף באמצעות קובץ תרחיש | Megosztva forgatókönyvfájlon keresztül | Condiviso tramite un file scenario | Gedeeld via een scenariobestand | Partilhado através de um ficheiro de cenário | 通过假设情形文件分享 |

The Hebrew description's inner quotes are `\"` in the ARB, as the current value has them. The ellipsis is the single character `…`, as the current menu values use.

- [ ] **Step 4: Confirm every locale changed by the same amount**

Run: `git diff --numstat -- lib/l10n/arb/app_*.arb`
Expected: eleven rows, each `6 6`. A smaller row means a key's line was not found in that file; fix it before going on.

- [ ] **Step 5: Change the two English fallbacks and the three doc comments**

`dive_detail_sections.dart`: `diveLab => 'Compare'` in `displayName`; `diveLab => 'Plan, dive and saved what-ifs side by side'` in `description`.

Doc comments: "What if..." front door becomes "Compare..." in `what_if_entry.dart:7`; "The "What if" section" becomes "The Compare section" in `dive_lab_section.dart:13`; "Saved Dive Lab what-ifs" becomes "Saved Compare what-ifs" in `lab_seeder.dart:13`.

- [ ] **Step 6: Regenerate localizations, last**

Run: `flutter gen-l10n`
Then: `grep -A1 'get diveLab_title' lib/l10n/arb/app_localizations_de.dart lib/l10n/arb/app_localizations_zh.dart lib/l10n/arb/app_localizations_he.dart`
Expected: `'Vergleichen'`, `'对比'`, `'השוואה'`. Any `'Compare'` outside `app_localizations_en.dart` means that ARB was not edited.

- [ ] **Step 7: Run the four test files again**

Run: the command from Step 2.
Expected: PASS, all tests.

- [ ] **Step 8: Format and commit**

```bash
dart format lib/core/constants/dive_detail_sections.dart lib/features/dive_lab test/features/dive_lab test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/core/constants/dive_detail_sections_test.dart tool/demo_data/src/seeders/lab_seeder.dart
git add lib/l10n/arb lib/core/constants/dive_detail_sections.dart lib/features/dive_lab/presentation/what_if_entry.dart lib/features/dive_lab/presentation/widgets/dive_lab_section.dart tool/demo_data/src/seeders/lab_seeder.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_lab/presentation/widgets/dive_lab_section_test.dart test/features/dive_lab/presentation/pages/dive_lab_page_planner_test.dart test/core/constants/dive_detail_sections_test.dart
git commit -m "feat(compare): rename the Dive Lab to Compare in every locale"
```

Check `git show --stat HEAD` lists 11 ARBs, 11 generated files, the constants file, three comment edits and four tests, and nothing else.

### Task 2: Commit the design records

**Files:**
- Add: `docs/design/specs/2026-10-31-compare-plan-vs-dive-design.md` (already written, untracked)
- Add: `docs/design/plans/2026-10-31-compare-rename-pr1.md` (this file)
- Modify: `docs/design/specs/2026-09-25-counterfactual-dive-lab-rethink-design.md:1-10` (a one-line pointer)

- [ ] **Step 1: Point the Lab rethink spec at the Compare design**

Under its `Amends:` lines, add: `Amended by: 2026-10-31-compare-plan-vs-dive-design.md (the Lab becomes Compare; the plan line and the by-hand link)`.

- [ ] **Step 2: Run the docs check**

Run: `python3.14 scripts/check_docs_links.py`
Expected: `Retired docs folders: ok` and `User docs rules: ok`.

- [ ] **Step 3: Commit**

```bash
git add docs/design/specs/2026-10-31-compare-plan-vs-dive-design.md docs/design/plans/2026-10-31-compare-rename-pr1.md docs/design/specs/2026-09-25-counterfactual-dive-lab-rethink-design.md
git commit -m "docs(design): Compare design and the rename plan"
```

### Task 3: Verify the branch

**Files:** none changed unless a check fails; a fix is its own commit.

- [ ] **Step 1: Analyze and format**

Run: `flutter analyze && dart format --set-exit-if-changed .`
Expected: `No issues found!` and `0 changed`.

- [ ] **Step 2: Generated localizations are not stale**

Run: `flutter gen-l10n && git status --short lib/l10n`
Expected: no output from `git status` (the tree is unchanged by regenerating).

- [ ] **Step 3: Run the module, the dive detail page and the guards**

Run: `flutter test test/features/dive_lab test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/core/constants test/architecture test/shared test/tool/demo_data/seeded_realism_test.dart`
Expected: `All tests passed!` Log to the scratchpad and gate on `grep -c "\[E\]"` being 0, not on the last line.

### Task 4: Redo the PR's title, body and screenshots

**Files:**
- Gist `7ea450ed9b16c94870b5c1b7f7d1caaf`: five new PNGs
- PR #2407 title and body (via `gh`)

**Interfaces:**
- Consumes: the renamed UI from Task 1, built and running.

- [ ] **Step 1: Capture five screenshots of the renamed screens**

The macOS debug build on the demo logbook, the way the existing five were taken (phone at 420 px wide, desktop at 1400 px; dark where named). Open a dive with saved what-ifs (the demo's "Tighter gradient factors" dive).

| File | Shows |
| --- | --- |
| `2407-06-compare-phone-light.png` | the Compare page, phone, light |
| `2407-07-compare-phone-dark.png` | the Compare page, phone, dark |
| `2407-08-compare-desktop-light.png` | the Compare page, desktop, light |
| `2407-09-compare-menu-phone.png` | the dive detail overflow menu open, showing "Compare…" |
| `2407-10-compare-section.png` | the Compare section on dive detail with one saved what-if |

- [ ] **Step 2: Add them to the gist and record the commit**

```bash
gh gist clone 7ea450ed9b16c94870b5c1b7f7d1caaf <scratchpad>/gist2407
cp <the five files> <scratchpad>/gist2407/
cd <scratchpad>/gist2407 && git add -A && git commit -m "PR 2407: Compare rename screenshots" && git push && git rev-parse HEAD
```

Then for each file: `curl -sI https://gist.githubusercontent.com/ericgriffin/7ea450ed9b16c94870b5c1b7f7d1caaf/raw/<sha>/<file> | head -1` reads `HTTP/2 200`.

- [ ] **Step 3: Rewrite the title and body**

`gh pr view 2407 --json body --jq .body > <scratchpad>/pr_body.md`, then edit:

- Title: `Compare: what-if scenarios branched from a logged dive`.
- "Adds the Dive Lab:" becomes "Adds Compare:"; every other "Dive Lab" and "the lab" in prose becomes "Compare" or "the Compare page"; `"What if..."` as the menu label becomes `"Compare..."`; "the `whatIf` card" wording becomes "the Compare section (`DiveDetailSectionId.diveLab`)".
- The Design line cites `docs/design/specs/2026-08-21-counterfactual-dive-lab-design.md`, `docs/design/specs/2026-09-25-counterfactual-dive-lab-rethink-design.md` and `docs/design/specs/2026-10-31-compare-plan-vs-dive-design.md` (the `docs/superpowers/` paths go).
- Screenshots section: the five `<img>` tags point at the Step 2 URLs; captions name Compare; the closing note reads: "All screens are new, so there is no before except the menu label, which changes from "Replan this dive" to "Compare…"." The old images stay in the gist but are no longer linked.
- Test plan: add a line "Renamed to Compare per the 2026-10-31 design; no behaviour change."
- `Closes #2405` stays.

Then `gh pr edit 2407 --title "<title>" --body-file <scratchpad>/pr_body.md`, and `gh pr view 2407 --json body --jq .body | grep -c 'Dive Lab'` reads `0`.

- [ ] **Step 4: Ask the maintainer, then push**

Ask before pushing. Then `SKIP_TESTS=1 git -c http.postBuffer=524288000 push` (the hook's static checks still run; Task 3 was the test run). Confirm `git rev-parse --short HEAD` equals `git rev-parse --short @{u}`.
