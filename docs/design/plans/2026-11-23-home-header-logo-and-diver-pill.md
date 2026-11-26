# Home header logo spacing and always-shown diver pill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Home's header logo room to breathe (a 32 pt tile instead of 40 pt) and show the diver profile pill even when only one profile exists.

**Architecture:** Both changes live in one widget file, `home_header_bar.dart`: `_AboutLogo` and the bar's padding for the logo, and `_DiverSwitcher` for the pill. No providers, routes or screens change; the existing diver switcher sheet already handles a single profile.

**Tech Stack:** Flutter, Riverpod, flutter_test widget tests.

**Spec:** `docs/design/specs/2026-11-23-home-header-logo-and-diver-pill-design.md`

## Global Constraints

- Tile size 32 pt, corner radius 8; bar height stays 48 pt.
- Distances are to the drawn tile: 8 pt from the diver switcher's edge, 12 pt from the bar's end.
- Every control keeps a hit area of at least 44 by 44 pt.
- Layout is directional: the same distances hold mirrored in a right-to-left language.
- No em-dashes in code, comments or commit messages. No attribution trailers in commits.
- Run only the test file this plan changes, by path; never a folder or the suite.
- Run `dart format` on changed files before each commit.

## Review Focus

- A single-profile diver on a phone: the avatar-only pill and every other control stay at least 44 by 44 (Task 2, step 1 adds the one-profile run of the phone 44-point test).
- Right-to-left with the smaller tile: 12 pt from the left edge and 8 pt from the switcher, mirrored (Task 1, step 1 covers both locales).
- A single-profile diver taps the pill: the switcher sheet opens with its "Add New Diver" row, never a dead end (Task 2, step 1).

---

### Task 0: Prepare the worktree

- [ ] **Step 1: Initialise submodules and packages**

Run: `git submodule update --init --recursive && flutter pub get`
Expected: both finish without errors.

---

### Task 1: Smaller logo tile with more space

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/home_header_bar.dart` (`logoSize` at line 65, the bar padding at line 104, the gap at line 139, `_AboutLogo` radius at line 229, doc comments on `HomeHeaderBar` and `logoSize`)
- Test: `test/features/dashboard/presentation/widgets/home_header_bar_test.dart`

**Interfaces:**
- Produces: `HomeHeaderBar.logoSize == 32`.

- [ ] **Step 1: Update and add the failing tests**

Rewrite the loop at line 176 (`'the logo is 40 points and fits the bar at $width wide'`) as `'the logo is 32 points with room above and below at $width wide'`:

```dart
expect(tester.getSize(_logo), const Size(32, 32));
final bar = tester.getRect(find.byType(HomeHeaderBar));
final logo = tester.getRect(_logo);
expect(logo.top - bar.top, greaterThanOrEqualTo(7));
expect(bar.bottom - logo.bottom, greaterThanOrEqualTo(7));
```

Add a locale loop (`en` and `he`), `'the logo sits 8 from the switcher and 12 from the end (<lang>)'`, pumped at width 1280 with `divers: 2` (the switcher only shows with two until Task 2):

```dart
// en
expect(bar.right - logo.right, closeTo(12, 0.5));
expect(logo.left - switcher.right, closeTo(8, 0.5));
// he
expect(logo.left - bar.left, closeTo(12, 0.5));
expect(switcher.left - logo.right, closeTo(8, 0.5));
```

where `switcher = tester.getRect(find.byKey(HomeHeaderBar.switcherKey))`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dashboard/presentation/widgets/home_header_bar_test.dart --plain-name 'the logo'`
Expected: FAIL on the 32 by 32 size (actual 40) and on the 12 and 8 distances (actual 10 and 6).

- [ ] **Step 3: Implement**

In `home_header_bar.dart`: `logoSize` 40 to 32; the bar's `EdgeInsetsDirectional.only(start: 4, end: 8)` end to 6 (the tile's 6 pt inside its 44 pt button makes 12); the `SizedBox(width: 4)` before `_AboutLogo` to 2 (2 + 6 = 8); `_AboutLogo`'s `BorderRadius.circular(10)` to 8. Update the `logoSize` doc comment to say the tile leaves about 8 pt above and below, and the comments at the padding and the gap to say the visible distances are 12 and 8 including the button's 6.

- [ ] **Step 4: Run the whole changed test file**

Run: `flutter test test/features/dashboard/presentation/widgets/home_header_bar_test.dart`
Expected: all pass, including the existing ordering tests (`<= 12` from the edge) and both 44-point tests.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dashboard/presentation/widgets/home_header_bar.dart test/features/dashboard/presentation/widgets/home_header_bar_test.dart
git add lib/features/dashboard/presentation/widgets/home_header_bar.dart test/features/dashboard/presentation/widgets/home_header_bar_test.dart
git commit -m "fix(dashboard): give the Home header logo room above, below and beside it"
```

---

### Task 2: Always show the diver pill

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/home_header_bar.dart` (`_DiverSwitcher.build` at lines 248-257, the `HomeHeaderBar` class doc at line 51, the `_DiverSwitcher` doc at line 241, the `diver_providers.dart` import if it becomes unused)
- Test: `test/features/dashboard/presentation/widgets/home_header_bar_test.dart`

**Interfaces:**
- Consumes: nothing new from Task 1.
- Produces: `_DiverSwitcher` no longer reads `diverCountProvider`. The provider itself stays (used in `lib/app.dart`).

- [ ] **Step 1: Flip and add the failing tests**

- Rename `'no switcher with one diver'` to `'a switcher with one diver'`; expect `find.byKey(HomeHeaderBar.switcherKey)` `findsOneWidget` and `find.text('Eric')` `findsOneWidget` at width 1280.
- Add `'phone: one diver shows the avatar alone'`: width 400, default one diver; switcher `findsOneWidget`, `find.text('Eric')` `findsNothing`.
- Add `'one diver: the switcher opens the sheet with Add New Diver'`: width 1280, tap the switcher, `pumpAndSettle`; expect `find.text('Switch Diver')` (the sheet title) and `find.text('Add New Diver')` each `findsOneWidget`. If the sheet's diver list needs an override that `getBaseOverrides` lacks, assert only these two texts, which render outside the list.
- Turn `'phone: every button is at least 44 by 44'` (line 349) into a loop over `divers` 1 and 2.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dashboard/presentation/widgets/home_header_bar_test.dart --plain-name 'one diver'`
Expected: FAIL, the switcher is not found with one diver.

- [ ] **Step 3: Implement**

In `_DiverSwitcher.build`, remove the `diverCountProvider` watch and the `count < 2` early return, along with the comment about unknown counting as one. Keep the `dashboardDiverProvider` read and the 44 by 44 placeholder while it is null. Update the class docs: `HomeHeaderBar` says "the diver switcher" (drop "with more than one diver profile"), and `_DiverSwitcher` drops "Absent with a single profile". Remove the `diver_providers.dart` import if `flutter analyze` reports it unused.

- [ ] **Step 4: Run the whole changed test file and analyze the file**

Run: `flutter test test/features/dashboard/presentation/widgets/home_header_bar_test.dart && flutter analyze lib/features/dashboard/presentation/widgets/home_header_bar.dart test/features/dashboard/presentation/widgets/home_header_bar_test.dart`
Expected: all tests pass; analyze reports no issues.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dashboard/presentation/widgets/home_header_bar.dart test/features/dashboard/presentation/widgets/home_header_bar_test.dart
git add lib/features/dashboard/presentation/widgets/home_header_bar.dart test/features/dashboard/presentation/widgets/home_header_bar_test.dart
git commit -m "feat(dashboard): show the diver pill on Home with a single profile"
```

---

### Task 3: Commit the design records

- [ ] **Step 1: Commit**

```bash
git add docs/design/specs/2026-11-23-home-header-logo-and-diver-pill-design.md docs/design/plans/2026-11-23-home-header-logo-and-diver-pill.md
git commit -m "docs(design): Home header logo spacing and diver pill"
```
