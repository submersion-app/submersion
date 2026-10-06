# Planner Phone Layout Rebalance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reclaim vertical space in the phone dive-planner layout by moving the status and contingency chip rows onto the chart as dive-computer-style overlays and shrinking the chart from 40% to a clamped 30% of body height.

**Architecture:** Spec: `docs/superpowers/specs/2026-08-07-planner-phone-layout-design.md`. Only the phone branch (`_buildPhone`, width < 760 px) of `PlanCanvasPage` changes. A new `PlanChartReadouts` widget overlays instrument readouts on the chart `Stack` (no painter changes); `ContingencyChips` gains an `overlay` mode; desktop layouts and the fullscreen chart page are untouched.

**Tech Stack:** Flutter 3.x, Riverpod (legacy StateNotifier/StateProvider style via `core/providers/provider.dart`), existing planner providers, flutter_test widget tests.

## Global Constraints

- Work ONLY in the isolated worktree for this branch: `<repo-root>/.claude/worktrees/planner-phone-layout`. Every Read/Edit/Write absolute path must start with that worktree root; run every command from that directory (`pwd` first if unsure).
- Branch: `worktree-planner-phone-layout`. Commit after each task; no pushes.
- Commit messages: plain summary line only. NO `Co-Authored-By:` trailer, NO session-URL trailer.
- `dart format .` must produce no changes before each commit (format the whole project, not just touched files).
- `flutter analyze` (run plainly — never pipe through `tail`/`grep`) must report zero issues; infos are CI-fatal.
- No new l10n keys, no schema changes, no new dependencies, no emojis in code or comments.
- Desktop/tablet (>= 760 px) behavior must not change: `PlanStatusChips` and `ContingencyChips` (default mode) stay below the chart in `_chartColumn`.
- Bash test commands: set `timeout: 600000`; run targeted files/dirs, never the full suite.

## File Structure

- Create `lib/features/planner/presentation/widgets/plan_chart_readouts.dart` — the overlay readouts widget (single responsibility: display outcome numbers over the chart; no layout knowledge of the page).
- Modify `lib/features/planner/presentation/widgets/contingency_chips.dart` — add compact `overlay` rendering next to the existing `Wrap` rendering.
- Modify `lib/features/planner/presentation/pages/plan_canvas_page.dart` — `_buildPhone` only.
- Create `test/features/planner/plan_chart_readouts_test.dart`.
- Modify `test/features/planner/contingency_ui_test.dart` (add overlay test).
- Modify `test/features/planner/plan_canvas_page_test.dart` (update phone-layout test, add clamp/tap/overflow tests).

---

### Task 1: `PlanChartReadouts` widget

**Files:**
- Create: `lib/features/planner/presentation/widgets/plan_chart_readouts.dart`
- Test: `test/features/planner/plan_chart_readouts_test.dart`

**Interfaces:**
- Consumes: `planOutcomeProvider` (`plan_canvas_providers.dart`), `cnsWarningThresholdProvider` (`settings_providers.dart`), `PlanChip` / `FollowingChip` / `planIssueSeverityColor` (`plan_status_chips.dart`).
- Produces: `class PlanChartReadouts extends ConsumerWidget` with constructor `const PlanChartReadouts({super.key, required VoidCallback onIssuesTap})`. Its `build` returns a `Positioned.fill`, so it MUST be placed as a direct child of a `Stack`. Task 3 relies on exactly this name and constructor.

- [ ] **Step 1: Write the failing tests**

Create `test/features/planner/plan_chart_readouts_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_chart_readouts.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  var issuesTapped = false;

  Widget harness({List<Override> extraOverrides = const []}) {
    issuesTapped = false;
    return testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ...extraOverrides,
      ],
      locale: const Locale('en'),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.black12)),
            PlanChartReadouts(onIssuesTap: () => issuesTapped = true),
          ],
        ),
      ),
    );
  }

  void seed(WidgetTester tester, {required double depth, required int time}) {
    ProviderScope.containerOf(tester.element(find.byType(PlanChartReadouts)))
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: depth, bottomTimeMinutes: time);
  }

  testWidgets('shallow plan shows runtime and NDL, no TTS or deco', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    seed(tester, depth: 12, time: 20);
    await tester.pumpAndSettle();

    expect(find.text('Runtime'), findsOneWidget);
    expect(find.text('NDL'), findsOneWidget);
    expect(find.text('TTS'), findsNothing);
    expect(find.text('DECO'), findsNothing);
    expect(find.textContaining('CNS'), findsOneWidget);
  });

  testWidgets('deco plan shows TTS and DECO; issues pill taps through', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    // A deep air plan trips a critical gas-density issue and mandatory deco,
    // so TTS/DECO render and the issues pill has a tap target.
    seed(tester, depth: 50, time: 25);
    await tester.pumpAndSettle();

    expect(find.text('TTS'), findsOneWidget);
    expect(find.text('DECO'), findsOneWidget);
    expect(find.text('NDL'), findsNothing);

    await tester.tap(find.textContaining('issue'));
    await tester.pumpAndSettle();
    expect(issuesTapped, isTrue);
  });

  testWidgets('CNS readout tints orange at the warning threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        extraOverrides: [cnsWarningThresholdProvider.overrideWithValue(0)],
      ),
    );
    seed(tester, depth: 30, time: 20);
    await tester.pumpAndSettle();

    final cns = tester.widget<Text>(
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('CNS')),
    );
    expect(cns.style?.color, Colors.orange);
  });

  testWidgets('following pill shows under runtime and clears on tap', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    seed(tester, depth: 30, time: 20);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanChartReadouts)),
    );
    container.read(divePlanNotifierProvider.notifier).setFollowedDive(
      diveId: 'missing-dive',
      surfaceInterval: const Duration(hours: 1),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Following'), findsOneWidget);
    await tester.tap(find.textContaining('Following'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).sourceDiveId, isNull);
    expect(find.textContaining('Following'), findsNothing);
  });
}
```

Note: if `List<Override>` fails to resolve, check how other planner tests type
their override lists (`contingency_ui_test.dart` uses `List<dynamic>`); match
that.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/planner/plan_chart_readouts_test.dart`
Expected: FAIL — `plan_chart_readouts.dart` does not exist (compile error).

- [ ] **Step 3: Implement the widget**

Create `lib/features/planner/presentation/widgets/plan_chart_readouts.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dive-computer-style readouts overlaid on the phone planner chart,
/// replacing the phone chip rows: runtime (with the following pill beneath
/// it) top-left; TTS-or-NDL, deco, CNS, and the issues pill top-right.
/// Passive readouts sit under [IgnorePointer] so chart gestures pass
/// through; only the issues and following pills take taps.
///
/// Renders a [Positioned.fill], so it must be a direct child of the chart
/// [Stack].
class PlanChartReadouts extends ConsumerWidget {
  const PlanChartReadouts({super.key, required this.onIssuesTap});

  /// Invoked when the issues pill is tapped (phone: switch to Results tab).
  final VoidCallback onIssuesTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(planOutcomeProvider);
    final cnsThreshold = ref.watch(cnsWarningThresholdProvider);
    final theme = Theme.of(context);

    String minutes(int seconds) => '${(seconds / 60).ceil()}′';
    final inDeco = outcome.ndlAtBottom < 0;
    final maxSeverity = outcome.issues.isEmpty
        ? null
        : outcome.issues
              .map((i) => i.severity)
              .reduce((a, b) => a.index >= b.index ? a : b);

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Scrim panel keeps the numbers legible over grid lines in both themes.
    Widget panel(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );

    Widget row(String label, String value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 5),
        Text(value, style: valueStyle),
      ],
    );

    final cnsWarn = outcome.cnsEnd >= cnsThreshold;

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgnorePointer(
                    child: panel(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            minutes(outcome.runtimeSeconds),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            context.l10n.divePlanner_label_runtime,
                            style: labelStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const FollowingChip(),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IgnorePointer(
                    child: panel(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (inDeco)
                            row(
                              context.l10n.divePlanner_label_tts,
                              minutes(outcome.ttsAtBottom),
                            )
                          else
                            row(
                              context.l10n.divePlanner_label_ndl,
                              minutes(outcome.ndlAtBottom.clamp(0, 1 << 30)),
                            ),
                          if (outcome.totalDecoSeconds > 0)
                            row(
                              context.l10n.divePlanner_label_deco,
                              minutes(outcome.totalDecoSeconds),
                            ),
                          Text(
                            context.l10n.plannerCanvas_chip_cns(
                              outcome.cnsEnd.toStringAsFixed(0),
                            ),
                            style: labelStyle?.copyWith(
                              color: cnsWarn ? Colors.orange : null,
                              fontWeight: cnsWarn ? FontWeight.w600 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (maxSeverity != null) ...[
                    const SizedBox(height: 4),
                    PlanChip(
                      label: context.l10n.plannerCanvas_chip_issues(
                        outcome.issues.length,
                      ),
                      tint: planIssueSeverityColor(
                        theme.colorScheme,
                        maxSeverity,
                      ),
                      onTap: onIssuesTap,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/planner/plan_chart_readouts_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/planner/presentation/widgets/plan_chart_readouts.dart test/features/planner/plan_chart_readouts_test.dart
git commit -m "Add PlanChartReadouts overlay widget for the phone planner chart"
```

---

### Task 2: `ContingencyChips` overlay mode

**Files:**
- Modify: `lib/features/planner/presentation/widgets/contingency_chips.dart`
- Test: `test/features/planner/contingency_ui_test.dart`

**Interfaces:**
- Consumes: nothing new — same providers as today (`divePlanNotifierProvider`, `selectedDeviationProvider`, `settingsProvider`).
- Produces: `const ContingencyChips({super.key, bool overlay = false})`. Default rendering (the `Wrap`) is byte-for-byte unchanged; Task 3 uses `ContingencyChips(overlay: true)`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/planner/contingency_ui_test.dart` (inside `main`, after the existing first test; reuses the file's existing imports and `_overrides()`):

```dart
  testWidgets('overlay chips render a single row strip and drive selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        child: const Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 8,
                right: 56,
                bottom: 8,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ContingencyChips(overlay: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContingencyChips)),
    );
    // No segments: the selector renders nothing.
    expect(find.text('Base'), findsNothing);

    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    expect(find.text('Base'), findsOneWidget);
    // Overlay mode is a single-row strip, not the wrapping layout.
    expect(find.byType(Wrap), findsNothing);

    await tester.tap(find.text('+5m'));
    await tester.pumpAndSettle();
    expect(container.read(selectedDeviationProvider), 'deeper');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/contingency_ui_test.dart`
Expected: the new test FAILS (no `overlay` parameter — compile error). The three existing tests must not be touched.

- [ ] **Step 3: Implement the overlay mode**

In `lib/features/planner/presentation/widgets/contingency_chips.dart`, replace the constructor and the `return Wrap(...)` tail of `build` (keep everything else — the empty-segments guard, `depthLabel`, `timeLabel`, `select`, and `chip` — exactly as is):

```dart
  const ContingencyChips({super.key, this.overlay = false});

  /// Compact single-row on-chart styling for the phone layout: a scrimmed
  /// horizontal strip instead of a wrapping row of bare chips.
  final bool overlay;
```

```dart
    final chips = [
      chip(null, context.l10n.plannerCanvas_contingency_base),
      chip('deeper', depthLabel),
      chip('longer', timeLabel),
      chip('both', '$depthLabel $timeLabel'),
    ];

    if (!overlay) {
      return Wrap(spacing: 6, runSpacing: 6, children: chips);
    }

    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              chips[i],
            ],
          ],
        ),
      ),
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/planner/contingency_ui_test.dart`
Expected: PASS (4 tests — 3 existing + 1 new).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/planner/presentation/widgets/contingency_chips.dart test/features/planner/contingency_ui_test.dart
git commit -m "Add overlay mode to ContingencyChips"
```

---

### Task 3: Rewire `_buildPhone`

**Files:**
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart` (`_buildPhone`, currently lines 400-461, plus one new import)
- Test: `test/features/planner/plan_canvas_page_test.dart`

**Interfaces:**
- Consumes: `PlanChartReadouts` (Task 1), `ContingencyChips(overlay: true)` (Task 2), existing `plannerPhoneTabProvider` / `_phoneTabBody` / `PlanProfileChart`.
- Produces: nothing new — page-internal layout change. Desktop `_buildDesktop`/`_chartColumn` untouched.

- [ ] **Step 1: Update and extend the page tests**

In `test/features/planner/plan_canvas_page_test.dart`:

1. Add imports:

```dart
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_chart_readouts.dart';
```

2. Replace the first test (`'phone layout shows chart, chips, tab deck, no sheet'`) with:

```dart
  testWidgets('phone layout shows chart, readouts, tab deck, no chip rows', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    seed(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PlanProfileChart), findsOneWidget);
    expect(find.byType(PlanChartReadouts), findsOneWidget);
    expect(find.byType(PlanStatusChips), findsNothing);
    expect(find.text('Base'), findsOneWidget);
    expect(find.byType(SegmentList), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });
```

(`find.text('Base')` is the overlay `ContingencyChips`; the `PlanStatusChips`
absence is the point of the feature. Keep the `PlanStatusChips` import — the
wide-layout tests still exercise it indirectly, and the finder above needs it.)

3. Add three new tests at the end of `main`:

```dart
  testWidgets('phone chart height is 30% of body, clamped to a 160 floor', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    seed(tester);
    await tester.pumpAndSettle();
    // Body = 900 - 56 appbar = 844; 30% = 253.2; chart padding eats 16.
    expect(
      tester.getSize(find.byType(PlanProfileChart)).height,
      closeTo(253.2 - 16, 0.5),
    );
  });

  testWidgets('short viewport pins the chart to the 160 px floor', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 560));
    await tester.pumpWidget(harness());
    seed(tester);
    await tester.pumpAndSettle();
    // Body = 560 - 56 = 504; 30% = 151.2 -> clamped to 160; minus padding.
    expect(
      tester.getSize(find.byType(PlanProfileChart)).height,
      closeTo(160.0 - 16, 0.5),
    );
  });

  testWidgets('phone issues pill switches to the Results tab', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    // Deep air plan trips a critical gas-density issue (see the wide issues
    // chip test) so the pill renders.
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 50, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('issue'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanResultsPane), findsOneWidget);
  });

  testWidgets('no overflow at SE-class size with a deco-heavy plan', (
    tester,
  ) async {
    await setSize(tester, const Size(320, 568));
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 50, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Run the page tests to verify the new ones fail**

Run: `flutter test test/features/planner/plan_canvas_page_test.dart`
Expected: FAIL — `PlanChartReadouts` not found in the tree, chip-row finders assert the old layout, heights are 40%.

- [ ] **Step 3: Rewire `_buildPhone`**

In `plan_canvas_page.dart`, add the import (with the other `widgets/` imports):

```dart
import 'package:submersion/features/planner/presentation/widgets/plan_chart_readouts.dart';
```

Replace the whole `_buildPhone` method with:

```dart
  Widget _buildPhone(BoxConstraints constraints) {
    final tab = ref.watch(plannerPhoneTabProvider);
    final tabs = [
      context.l10n.divePlanner_tab_plan,
      context.l10n.divePlanner_label_tanks,
      context.l10n.plannerCanvas_tab_setup,
      context.l10n.divePlanner_tab_results,
    ];
    // 30% of the body, clamped so the chart neither vanishes on short
    // viewports nor dominates tall ones; the deck gets everything else.
    final chartHeight = (constraints.maxHeight * 0.30)
        .clamp(160.0, 260.0)
        .toDouble();
    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: PlanProfileChart(),
                ),
              ),
              PlanChartReadouts(
                onIssuesTap: () =>
                    ref.read(plannerPhoneTabProvider.notifier).state = 3,
              ),
              const Positioned(
                left: 8,
                right: 56,
                bottom: 8,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ContingencyChips(overlay: true),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.open_in_full, size: 18),
                  onPressed: () => context.go('/planning/dive-planner/chart'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<int>(
            segments: [
              for (var i = 0; i < tabs.length; i++)
                ButtonSegment(value: i, label: Text(tabs[i])),
            ],
            selected: {tab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                ref.read(plannerPhoneTabProvider.notifier).state =
                    selection.first,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _phoneTabBody(tab)),
      ],
    );
  }
```

The two chip-row `Padding`s (`PlanStatusChips`, `ContingencyChips`) that sat
between the chart `SizedBox` and the `SegmentedButton` are gone — do NOT
remove the `plan_status_chips.dart` or `contingency_chips.dart` imports; the
desktop `_chartColumn` still uses both.

- [ ] **Step 4: Run the page tests to verify they pass**

Run: `flutter test test/features/planner/plan_canvas_page_test.dart`
Expected: PASS (all, including the four new tests). If the two height
assertions are off by exactly the `SafeArea`/appbar difference, print
`tester.getRect(find.byType(PlanProfileChart))` once, correct the expected
constant with a comment explaining the body height, and re-run — the clamp
logic itself must not change.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/planner/plan_canvas_page_test.dart
git commit -m "Rebalance phone planner layout: clamped 30% chart with on-chart readouts"
```

---

### Task 4: Full planner verification sweep

**Files:**
- None created; fixes only if the sweep finds regressions.

**Interfaces:**
- Consumes: everything above.
- Produces: green planner suites on the branch.

- [ ] **Step 1: Run the planner widget/unit suites**

Run (timeout 600000): `flutter test test/features/planner`
Expected: all PASS. Golden tests in `test/features/planner/chart/goldens/` run on macOS and must pass unchanged — this feature touches no painter; a golden diff means an accidental chart change, which must be reverted, not re-recorded.

- [ ] **Step 2: Run the neighboring dive_planner widget suites**

Run (timeout 600000): `flutter test test/features/dive_planner`
Expected: all PASS (SegmentList/PlanTankList/setup sections are consumed by the phone deck).

- [ ] **Step 3: Final format/analyze check**

```bash
dart format .
flutter analyze
```
Expected: no formatting changes, zero analyzer issues. If `dart format` touched files, commit them:

```bash
git add -A
git commit -m "Format planner phone layout changes"
```

---

## Self-review notes

- Spec coverage: section 1 (structure/clamp) = Task 3; section 2 (readouts) = Task 1; section 3 (contingency overlay) = Task 2; section 4 (edge cases) = Tasks 1/3 tests; section 5 (testing incl. SE no-overflow) = Tasks 1-4. Desktop-unchanged criterion = untouched `_buildDesktop` + existing wide-layout tests still passing (Task 4).
- Names cross-checked against the current tree: `planOutcomeProvider`, `cnsWarningThresholdProvider`, `plannerPhoneTabProvider`, `selectedDeviationProvider`, `setFollowedDive`/`clearFollowedDive`, l10n keys (`divePlanner_label_runtime` = "Runtime", `divePlanner_label_tts` = "TTS", `divePlanner_label_ndl` = "NDL", `divePlanner_label_deco` = "DECO", `plannerCanvas_chip_cns` = "CNS {value}%", `plannerCanvas_chip_issues`, `plannerCanvas_contingency_base` = "Base"), and the `'+5m'` deviation label used by the existing contingency test.
