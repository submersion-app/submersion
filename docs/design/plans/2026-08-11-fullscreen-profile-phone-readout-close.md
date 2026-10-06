# Fullscreen Profile Phone Readout Close-Button Clearance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the fullscreen dive-profile close button visible and tappable on phones even when the draggable metric readout is positioned at the upper-left.

**Architecture:** `DraggableReadoutCard` will expose a configurable `EdgeInsets` movement arena while preserving its existing 12 px default. `FullscreenProfilePage` will pass a 56 px phone-only top inset, so automatic, persisted, and dragged `(0, 0)` positions map below the close/title row without rewriting settings or changing desktop behavior.

**Tech Stack:** Flutter 3.x, Material 3, Riverpod, `flutter_test` widget tests.

## Global Constraints

- Work only in `/Users/ericgriffin/repos/submersion-app/submersion/.worktrees/fix-phone-profile-readout-close` on `codex/fix-phone-profile-readout-close`.
- Phone detection remains exactly `MediaQuery.sizeOf(context).shortestSide < 600`.
- Phone readout placement is exactly `EdgeInsets.fromLTRB(12, 56, 12, 12)`; desktop/tablet retain `EdgeInsets.all(12)` through the default.
- Do not change dive metric values, formatting, unit conversion, tooltip content, least-occupied-corner selection, inline profile layout, or fullscreen transport behavior.
- Do not rewrite persisted readout coordinates; reinterpret them inside the phone-safe movement arena.
- Widget tests that exercise phone behavior must inject an explicit `MediaQueryData(size: Size(400, 800))` through the existing `_wrap(..., size: _phoneSize)` helper.
- Follow strict red-green TDD: each production change follows a test that failed for the expected reason.
- Run `dart format .`; it must leave the worktree unchanged after formatting.
- `flutter analyze` must exit successfully.
- The clean baseline has one unrelated failure in `test/architecture/provider_change_tick_test.dart`; `speciesSightingCountsProvider` lacks a change-tick subscription. Do not modify it in this work.

---

### Task 1: Make the readout movement inset configurable

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/draggable_readout_card.dart:16-32,41-42,95-98`
- Test: `test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart:7-34,45-63`

**Interfaces:**
- Consumes: the existing `DraggableReadoutCard` fractional-position contract and `Padding`-based 12 px movement arena.
- Produces: `DraggableReadoutCard.placementInsets` of type `EdgeInsets`, defaulting to `const EdgeInsets.all(12)`, and used as the outer `Padding.padding`.

- [ ] **Step 1: Extend the widget-test wrapper and add the failing custom-inset test**

Change `_wrap` so tests can pass the new contract:

```dart
Widget _wrap({
  List<TooltipRow>? rows,
  Offset? initialFraction,
  ValueChanged<Offset>? onDragEnd,
  EdgeInsets placementInsets = const EdgeInsets.all(12),
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          key: const ValueKey('arena'),
          width: 600,
          height: 400,
          child: Stack(
            children: [
              DraggableReadoutCard(
                rows: rows,
                initialFraction: initialFraction,
                placementInsets: placementInsets,
                onDragEnd: onDragEnd ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

Add this test after `defaults to the top-right corner`:

```dart
testWidgets('custom placement insets reserve the phone header area', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      rows: null,
      initialFraction: Offset.zero,
      placementInsets: const EdgeInsets.fromLTRB(12, 56, 12, 12),
    ),
  );
  await tester.pumpAndSettle();

  final stackRect = tester.getRect(find.byKey(const ValueKey('arena')));
  final cardRect = tester.getRect(find.byKey(_cardKey));
  expect(cardRect.left, closeTo(stackRect.left + 12, 1.0));
  expect(cardRect.top, closeTo(stackRect.top + 56, 1.0));
}
```

The production mutation this catches is ignoring the caller-provided top inset and placing `(0, 0)` at the historical 12 px top edge.

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
flutter test test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart
```

Expected: compilation fails because `DraggableReadoutCard` does not define the named parameter `placementInsets`.

- [ ] **Step 3: Add the minimal production contract**

In `DraggableReadoutCard`, add the field and defaulted constructor argument:

```dart
/// Insets that bound the card's draggable movement arena.
final EdgeInsets placementInsets;

const DraggableReadoutCard({
  super.key,
  required this.rows,
  required this.initialFraction,
  required this.onDragEnd,
  this.placementInsets = const EdgeInsets.all(12),
});
```

Delete `_DraggableReadoutCardState._inset` and change the outer padding to:

```dart
return Positioned.fill(
  child: Padding(
    padding: widget.placementInsets,
```

Update the class documentation to describe the default 12 px inset and configurable reserved areas. Do not change sanitization or drag fraction math.

- [ ] **Step 4: Run the focused test to verify GREEN**

Run:

```bash
flutter test test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart
```

Expected: all tests pass, including the existing default 12 px assertions and the new 56 px custom-top assertion.

- [ ] **Step 5: Commit the reusable placement contract**

```bash
git add \
  lib/features/dive_log/presentation/widgets/draggable_readout_card.dart \
  test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart
git commit -m "fix(dive-log): support safe readout placement insets"
```

---

### Task 2: Reserve the fullscreen phone close/title row

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart:526-549`
- Test: `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart:191-258,272-279`

**Interfaces:**
- Consumes: `DraggableReadoutCard({EdgeInsets placementInsets = const EdgeInsets.all(12), ...})` from Task 1 and the existing `isPhone` breakpoint in `FullscreenProfilePage.build`.
- Produces: phone-only `placementInsets: const EdgeInsets.fromLTRB(12, 56, 12, 12)` at the fullscreen readout call site; desktop and tablet omit the argument and retain the default.

- [ ] **Step 1: Turn the automatic upper-left fixture into a failing phone-overlap regression**

In `without a saved position the card defaults to the corner the profile occupies least`, pump the existing dive with the phone size:

```dart
await tester.pumpWidget(_wrap(overrides, size: _phoneSize));
await tester.pumpAndSettle();
```

Keep the assertion that `initialFraction` is `const Offset(0, 0)`. Replace the broad top-half geometry assertion with the control-clearance contract and verify the control remains usable:

```dart
final closeButton = find.widgetWithIcon(IconButton, Icons.close);
final closeRect = tester.getRect(closeButton);
final cardRect = tester.getRect(find.byKey(const ValueKey('readout-card')));
expect(
  cardRect.top,
  greaterThanOrEqualTo(closeRect.bottom + 8),
  reason: 'the phone readout must clear the close/title row',
);

await tester.tap(closeButton);
await tester.pumpAndSettle();
expect(find.byType(FullscreenProfilePage), findsNothing);
```

The production mutation this catches is omitting the phone-safe inset, which leaves the readout at 12 px and overlapping the compact close button.

- [ ] **Step 2: Add the failing persisted upper-left regression**

Add after the automatic placement test:

```dart
testWidgets('phone saved upper-left position clears the close button', (
  tester,
) async {
  final overrides = _defaultOverrides()
    ..removeAt(0)
    ..insert(
      0,
      settingsProvider.overrideWith(
        (ref) => _FakeSettingsNotifier(
          const AppSettings(
            fullscreenReadoutCardX: 0,
            fullscreenReadoutCardY: 0,
          ),
        ),
      ),
    );
  await tester.pumpWidget(_wrap(overrides, size: _phoneSize));
  await tester.pumpAndSettle();

  final closeRect = tester.getRect(
    find.widgetWithIcon(IconButton, Icons.close),
  );
  final cardRect = tester.getRect(
    find.byKey(const ValueKey('readout-card')),
  );
  expect(cardRect.top, greaterThanOrEqualTo(closeRect.bottom + 8));
  expect(
    tester
        .widget<DraggableReadoutCard>(find.byType(DraggableReadoutCard))
        .initialFraction,
    Offset.zero,
    reason: 'the saved fraction stays unchanged inside the safer arena',
  );
});
```

The production mutation this catches is adjusting only automatic corner selection while continuing to restore persisted `(0, 0)` at the unsafe top edge.

- [ ] **Step 3: Run both regressions to verify RED**

Run:

```bash
flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
```

Expected: the two phone clearance assertions fail because `cardRect.top` is still near 12 px while the close button extends below it. Existing tests continue to compile.

- [ ] **Step 4: Pass the phone-only safe inset**

Add this named argument to the fullscreen `DraggableReadoutCard` call:

```dart
placementInsets: isPhone
    ? const EdgeInsets.fromLTRB(12, 56, 12, 12)
    : const EdgeInsets.all(12),
```

Keep the saved/automatic `initialFraction` expression and settings persistence unchanged.

- [ ] **Step 5: Run focused fullscreen and readout tests to verify GREEN**

Run:

```bash
flutter test \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart \
  test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart \
  test/features/dive_log/presentation/widgets/readout_card_placement_test.dart
```

Expected: all focused tests pass. The automatic upper-left fraction remains `(0, 0)`, the persisted fraction remains `(0, 0)`, and both render below the close button on phone.

- [ ] **Step 6: Format and analyze**

Run:

```bash
dart format .
git diff --check
flutter analyze
```

Expected: formatting completes without leaving additional changes, `git diff --check` emits no output, and analysis exits successfully.

- [ ] **Step 7: Run the affected dive-log presentation suite**

Run:

```bash
flutter test test/features/dive_log/presentation
```

Expected: all affected presentation tests pass. The known unrelated provider architecture failure is outside this command and outside this task.

- [ ] **Step 8: Commit the phone integration**

```bash
git add \
  lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
git commit -m "fix(dive-log): keep fullscreen close clear on phones"
```

---

### Task 3: Final verification and handoff

**Files:**
- Verify only: all files committed by Tasks 1-2

**Interfaces:**
- Consumes: the completed phone-safe placement contract and its widget regressions.
- Produces: verification evidence and a clean worktree ready for review.

- [ ] **Step 1: Re-run the exact focused regression set from a clean commit**

Run:

```bash
flutter test \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart \
  test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart \
  test/features/dive_log/presentation/widgets/readout_card_placement_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Re-run static verification**

Run:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
git diff --check
git status --short --branch
```

Expected: formatter and analyzer exit successfully, `git diff --check` emits no output, and status shows a clean `codex/fix-phone-profile-readout-close` branch.

- [ ] **Step 3: Review the final diff for scope**

Run:

```bash
git diff main...HEAD -- \
  docs/superpowers/specs/2026-08-11-fullscreen-profile-phone-readout-close-design.md \
  docs/superpowers/plans/2026-08-11-fullscreen-profile-phone-readout-close.md \
  lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart \
  lib/features/dive_log/presentation/widgets/draggable_readout_card.dart \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart \
  test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart
```

Expected: only the design, plan, configurable readout inset, phone call-site integration, and their regression tests appear.
