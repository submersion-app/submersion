# UI Conventions, Spacing Scale and Named Radii Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `Spacing` and `Radii` constants, an AST guard that keeps spacing and radius literals out of `lib/shared/widgets/`, the migration of that folder with no visual change, and a UI conventions doc.

**Architecture:** Constants live in `lib/core/theme/spacing.dart`. A `package:analyzer` scanner in `test/architecture/` reports each flagged literal with its offset, so the same findings drive both the guard test and a one-off mechanical rewrite of on-scale values. Off-scale values become named constants by hand.

**Tech Stack:** Dart, Flutter, `package:analyzer` (already a dev dependency, used by the other scanners).

**Spec:** `docs/design/specs/2026-11-27-ui-conventions-spacing-radii-design.md`

## Global Constraints

- No visual change: every migrated site keeps its exact value; an off-scale value gets a name, never a nearby step.
- `Spacing`: `s2, s4, s6, s8, s12, s16, s20, s24, s32, s40, s48`. `Radii`: `r2, r4, r6, r8, r12, r16, r20, r24`, `pill = 999`.
- Names carry their value (`Spacing.s16 == 16`).
- Imports use `package:submersion/core/theme/spacing.dart`.
- The doc names APIs and files, never hex values or pixel numbers that live in code.
- No em-dashes in any file. No emojis. `dart format .` before each commit.
- Local test runs: only the test files this plan creates or changes, by path.

## Review Focus

1. A construction without `const` parses as a `MethodInvocation` (`EdgeInsets.all(8)`, `SizedBox(width: 8)`), not an `InstanceCreationExpression`. Both shapes must be flagged (Task 2 tests both).
2. `16.0`, `-4` and `0.0`: a double and a negated literal are flagged; zero in either spelling is not (Task 2).
3. A `const pad = EdgeInsets.all(10);` local inside a method is not a named constant in the spec's sense and is flagged; a top-level or class field is exempt (Task 2).
4. A multi-line `EdgeInsets.fromLTRB(` whose arguments sit on separate lines reports the line of each literal, so the rewrite hits the right token (Task 2 asserts offsets).
5. The guard could pass vacuously if the scanner stops matching. The guard test also scans `lib/features/` and asserts it finds more than 1000 literals there (Task 3).

---

### Task 1: Spacing and Radii constants

**Files:**
- Create: `lib/core/theme/spacing.dart`
- Test: `test/core/theme/spacing_test.dart`

**Interfaces:**
- Produces: `abstract final class Spacing { static const double s2 ... s48; }` and `abstract final class Radii { static const double r2 ... r24; static const double pill = 999; }`. Later tasks map a value `N` to `Spacing.sN` / `Radii.rN` by name.

- [ ] **Step 1: Write the failing test** `spacing values match their names`: for each of `{2: Spacing.s2, 4: Spacing.s4, 6: Spacing.s6, 8: Spacing.s8, 12: Spacing.s12, 16: Spacing.s16, 20: Spacing.s20, 24: Spacing.s24, 32: Spacing.s32, 40: Spacing.s40, 48: Spacing.s48}` expect value equals key; same for `Radii` with `{2,4,6,8,12,16,20,24}` and `Radii.pill == 999`.
- [ ] **Step 2: Run** `flutter test test/core/theme/spacing_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 3: Implement** the two classes. Each class doc comment points at `docs/developer/ui-conventions.md` and says an off-scale value gets its own named constant with a reason, beside the code that uses it.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(theme): add Spacing and Radii scales`.

### Task 2: Spacing literal scanner

**Files:**
- Create: `test/architecture/spacing_literal_scanner.dart`
- Test: `test/architecture/spacing_literal_scanner_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class SpacingLiteral {
    final String file;   // relativized path
    final int line;      // 1-based line of the literal
    final int offset;    // offset of the literal token (including a leading '-')
    final int length;    // length of that source span
    final String call;   // 'EdgeInsets.all', 'SizedBox.height', 'Wrap.spacing', 'Radius.circular'
    final num value;     // parsed value, negative when negated
    String toString() => '$file:$line  $call  $value';
  }
  List<SpacingLiteral> scanForSpacingLiterals({
    required List<File> files,
    required String Function(String path) relativize,
  });
  ```
- Matching rules (from the spec): flag a non-zero numeric literal that is the argument, or a branch of a `ConditionalExpression`, or the right side of `??`, recursively through `ParenthesizedExpression`, of:
  - positional and named args of `EdgeInsets.all / symmetric / only / fromLTRB` and `EdgeInsetsDirectional.all / symmetric / only / fromSTEB`;
  - `BorderRadius.circular`, `Radius.circular`, `Radius.elliptical`;
  - `SizedBox(...)` unnamed constructor with no `child` and exactly one of `width` / `height`;
  - named args `spacing`, `runSpacing`, `mainAxisSpacing`, `crossAxisSpacing`, `indent`, `endIndent` on any call (`call` is `<Type>.<arg>`).
- Both `InstanceCreationExpression` and `MethodInvocation` shapes are visited; an import prefix (`w.EdgeInsets.all`) is matched by its last two identifiers.
- Exempt: anything inside the initializer of a `TopLevelVariableDeclaration` or a `FieldDeclaration`; arithmetic operands; `SizedBox.square`, `SizedBox.fromSize`, two-axis boxes; files ending in `.g.dart`.

- [ ] **Step 1: Write the failing tests** with the temp-directory harness of `list_tile_trailing_scanner_test.dart`:
  - `group('flags')`, one test per form, each asserting `values == [N]` and `call`:
    `const EdgeInsets.all(16)`, `EdgeInsets.all(16)` (no const), `EdgeInsets.symmetric(horizontal: 8, vertical: 4)` gives `[8, 4]`, `EdgeInsets.only(left: 10)`, `EdgeInsets.fromLTRB(16, 0, 16, 6)` gives `[16, 16, 6]`, `EdgeInsetsDirectional.fromSTEB(4, 0, 4, 0)`, `BorderRadius.circular(12)`, `Radius.circular(8)`, `Radius.elliptical(4, 6)`, `SizedBox(width: 8)`, `const SizedBox(height: 12)`, `Wrap(spacing: 24, runSpacing: 12)`, `Row(spacing: 8)`, `GridView.count(crossAxisCount: 2, mainAxisSpacing: 4)`, `Divider(indent: 16, endIndent: 16)`, `EdgeInsets.all(compact ? 8 : 16)` gives `[8, 16]`, `EdgeInsets.all(gap ?? 4)`, `EdgeInsets.all((12))`, `EdgeInsets.all(16.0)`, `EdgeInsets.only(top: -4)` gives `[-4]`, a local `const pad = EdgeInsets.all(10);` inside a function.
  - `group('ignores')`: `EdgeInsets.zero`, `EdgeInsets.all(0)`, `EdgeInsets.all(0.0)`, `EdgeInsets.all(Spacing.s8)`, `EdgeInsets.all(Spacing.s8 * 2)`, `SizedBox(width: 8, height: 8)`, `SizedBox(width: 150, child: x)`, `SizedBox.square(dimension: 24)`, `GridView.count(crossAxisCount: 2)`, a top-level `const kPad = EdgeInsets.only(bottom: 88);`, a `static const rowPadding = EdgeInsets.symmetric(horizontal: 14);` field, `// EdgeInsets.all(16)` in a comment, `'EdgeInsets.all(16)'` in a string, a file named `x.g.dart`.
  - `test('reports the line and offset of each literal')`: a multi-line `EdgeInsets.fromLTRB(\n  16,\n  8,\n  16,\n  4,\n)`; expect lines `[2, 3, 4, 5]` relative to the snippet and `source.substring(offset, offset + length)` equal to `'16','8','16','4'`; for `-4` the substring is `'-4'`.
- [ ] **Step 2: Run** `flutter test test/architecture/spacing_literal_scanner_test.dart`. Expected: FAIL (scanner missing).
- [ ] **Step 3: Implement** `scanForSpacingLiterals` with `parseString(content:, featureSet: FeatureSet.latestLanguageVersion(), throwIfDiagnostics: false)` and a `RecursiveAstVisitor` that tracks when it is inside a top-level or field initializer.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `test(architecture): add spacing literal scanner`.

### Task 3: Guard test (red until Task 4)

**Files:**
- Create: `test/architecture/spacing_literals_test.dart`

**Interfaces:**
- Consumes: `scanForSpacingLiterals` (Task 2).
- Produces: `const guardedRoots = ['lib/shared/widgets'];` at the top of the test, the list later feature migrations extend.

- [ ] **Step 1: Write the tests:**
  - `the scanner still matches real code, so the guard cannot pass vacuously`: scanning `lib/features` finds more than 1000 literals.
  - `guarded folders hold no spacing or radius literals`: scanning every `.dart` file under `guardedRoots` gives an empty list; `reason` lists each `toString()` and says to use `Spacing` / `Radii` from `lib/core/theme/spacing.dart`, or a named constant with a reason, per `docs/developer/ui-conventions.md`.
- [ ] **Step 2: Run** `flutter test test/architecture/spacing_literals_test.dart`. Expected: the first test PASSES, the second FAILS listing roughly 190 findings. Do not commit yet; Task 4 turns it green.

### Task 4: Migrate `lib/shared/widgets/`

**Files:**
- Modify: the files the Task 3 failure lists, under `lib/shared/widgets/`.
- Scratch (not committed): `<scratchpad>/rewrite_spacing.dart`, `<scratchpad>/check_spacing_diff.py`.

**Interfaces:**
- Consumes: `SpacingLiteral.offset/length/value/call` (Task 2), `Spacing` / `Radii` (Task 1).

- [ ] **Step 1: Mechanical rewrite.** Write `rewrite_spacing.dart` (imports the scanner by absolute path; run with `dart run --packages=.dart_tool/package_config.json`). For each finding in `lib/shared/widgets/`, in descending offset per file: when `call` is a radius call and `value` is on the `Radii` scale (999 maps to `pill`), replace with `Radii.rN`; when it is a spacing call and on the `Spacing` scale, replace with `Spacing.sN`; otherwise leave it and print it. Add `import 'package:submersion/core/theme/spacing.dart';` to each changed file that lacks it, in the package-import group.
- [ ] **Step 2: Diff check** before formatting. `check_spacing_diff.py` reads `git diff -U0 -- lib/shared/widgets`, pairs each removed line with its added line, substitutes `Spacing.sN` and `Radii.rN` back to `N` and `Radii.pill` back to `999` in the added line, and asserts it equals the removed line. Import-only additions are allowed. Expected: `OK` with zero mismatches.
- [ ] **Step 3: Hand edits** for the printed off-scale findings. Each becomes a named constant with a `///` reason: a private `static const` or top-level `const` in its file when one widget uses it, or a member of the family's style class (`FormStyle`) when several share it. Keep the exact value.
- [ ] **Step 4: Run** `flutter test test/architecture/spacing_literals_test.dart`. Expected: PASS.
- [ ] **Step 5: Run** `dart format .`, `flutter analyze`, and the existing test files that cover the hand-edited widgets (by path).
- [ ] **Step 6: Commit** `refactor(shared): use Spacing and Radii in shared widgets` with the guard test from Task 3.

### Task 5: UI conventions doc

**Files:**
- Create: `docs/developer/ui-conventions.md`
- Modify: `CLAUDE.md` (Code Conventions: one bullet linking the doc), `docs/developer/README.md` (Quick Links)

- [ ] **Step 1: Write the doc** with the six sections the spec lists (colour roles, contrast, type, spacing and radii, standing rules, where styling lives). Cite real files: `status_colors.dart`, `record_pencil_colors.dart`, `feature_accent_colors.dart`, `app_colors.dart`, `foreground_on.dart`, `backdrop_color.dart`, `form_style.dart`, `spacing.dart`, the contrast tests under `test/core/theme/`, and `test/architecture/spacing_literals_test.dart` (how to add a folder to `guardedRoots`).
- [ ] **Step 2: Verify** every cited path exists (`ls` each) and run `python3.14 scripts/check_docs_links.py`. Expected: no failures.
- [ ] **Step 3: Commit** `docs(theme): add UI conventions guide`.
