# Safety Finding Chart Highlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a safety review finding highlights its time range on the dive profile chart (detail page and fullscreen) and scrolls the chart into view.

**Architecture:** A new `StateProvider.family<SafetyFinding?, String>` holds the selected finding per dive. The safety review section writes it on tile tap; both chart host pages read it, map it to a `ProfileHighlightRange` (timestamps + severity color), and pass it to `DiveProfileChart` as a plain constructor param. The chart renders a translucent `VerticalRangeAnnotation` band with edge lines for real ranges, or a single dashed `VerticalLine` for instant findings (`start == end`), clamped to the visible zoom window.

**Tech Stack:** Flutter, Riverpod (legacy `StateProvider` via `package:submersion/core/providers/provider.dart`), fl_chart.

**Spec:** `docs/superpowers/specs/2026-08-07-safety-finding-chart-highlight-design.md`

## Global Constraints

- Working directory is the worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/safety-finding-chart-highlight`. Run all commands there.
- After each task: `dart format lib/ test/` must produce no changes (run it before committing).
- `flutter analyze` must stay clean — infos are CI-fatal. Never pipe analyze output through `tail`/`head`.
- No emojis anywhere. No new user-facing strings (no l10n changes needed).
- Commit messages: plain sentence style (e.g. "Add profile highlight range geometry"), no Co-Authored-By line, no session URL.
- Import grouping: dart, flutter, packages, local — match each file's existing style.
- All timestamps in this feature are **seconds from dive start** (`int`), the chart x-axis unit.

---

### Task 1: Highlight range value class and visibility geometry

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_highlight_range.dart`
- Create: `test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart`

**Interfaces:**
- Consumes: nothing (leaf module; no safety-domain imports — the chart must not depend on safety entities).
- Produces: `ProfileHighlightRange` (fields `int startTimestamp`, `int endTimestamp`, `Color color`; const constructor with named required params) and top-level function `({double x1, double x2})? visibleHighlightSpan(ProfileHighlightRange range, {required double visibleMinX, required double visibleMaxX})`. Tasks 4–6 use both.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';

void main() {
  ProfileHighlightRange range(int start, int end) => ProfileHighlightRange(
    startTimestamp: start,
    endTimestamp: end,
    color: Colors.teal,
  );

  group('visibleHighlightSpan', () {
    test('returns the full span when inside the window', () {
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 0,
        visibleMaxX: 300,
      );
      expect(span, (x1: 60.0, x2: 120.0));
    });

    test('clamps the left edge to the window', () {
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 90,
        visibleMaxX: 300,
      );
      expect(span, (x1: 90.0, x2: 120.0));
    });

    test('clamps the right edge to the window', () {
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 0,
        visibleMaxX: 100,
      );
      expect(span, (x1: 60.0, x2: 100.0));
    });

    test('returns null when the range is entirely outside the window', () {
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 150,
        visibleMaxX: 300,
      );
      expect(span, isNull);
    });

    test('returns null when the visible overlap has zero width', () {
      // Window touches the range at exactly one point (x = 120).
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 120,
        visibleMaxX: 300,
      );
      expect(span, isNull);
    });

    test('keeps an instant range while its timestamp is inside the window', () {
      final span = visibleHighlightSpan(
        range(90, 90),
        visibleMinX: 0,
        visibleMaxX: 300,
      );
      expect(span, (x1: 90.0, x2: 90.0));
    });

    test('drops an instant range outside the window', () {
      final span = visibleHighlightSpan(
        range(90, 90),
        visibleMinX: 100,
        visibleMaxX: 300,
      );
      expect(span, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart`
Expected: FAIL — compile error, `profile_highlight_range.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_log/presentation/widgets/profile_highlight_range.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

/// A time range on the dive profile to emphasize, e.g. the span of a selected
/// safety finding. Timestamps are seconds from dive start (the chart x-axis
/// unit). [startTimestamp] == [endTimestamp] marks a single instant, which the
/// chart renders as a cursor line instead of a band.
class ProfileHighlightRange {
  final int startTimestamp;
  final int endTimestamp;

  /// Fully opaque accent color; the chart applies its own band/edge alphas.
  final Color color;

  const ProfileHighlightRange({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.color,
  });
}

/// Clamps [range] to the chart's visible x-window.
///
/// Returns the drawable span, or null when nothing of the range is visible.
/// fl_chart asserts that annotations and extra lines lie within [minX, maxX],
/// so callers must only draw what this returns. An instant range survives
/// while its timestamp is inside the window; a true range collapses to null
/// when the visible overlap has zero width (window just touching an edge).
({double x1, double x2})? visibleHighlightSpan(
  ProfileHighlightRange range, {
  required double visibleMinX,
  required double visibleMaxX,
}) {
  final start = range.startTimestamp.toDouble();
  final end = range.endTimestamp.toDouble();

  if (start == end) {
    if (start < visibleMinX || start > visibleMaxX) return null;
    return (x1: start, x2: start);
  }

  final x1 = math.max(start, visibleMinX);
  final x2 = math.min(end, visibleMaxX);
  if (x1 >= x2) return null;
  return (x1: x1, x2: x2);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/widgets/profile_highlight_range.dart test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart
git commit -m "Add profile highlight range geometry"
```

---

### Task 2: Selection provider and severity-to-highlight mapping

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/safety_review_providers.dart`
- Create: `lib/features/dive_log/presentation/widgets/safety_finding_highlight.dart`
- Create: `test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart`

**Interfaces:**
- Consumes: `ProfileHighlightRange` from Task 1; `SafetyFinding`, `SafetySeverity` from `lib/features/dive_log/domain/entities/safety_finding.dart`.
- Produces:
  - `selectedSafetyFindingProvider` — `StateProvider.family<SafetyFinding?, String>` keyed by diveId (Tasks 3, 5, 6).
  - `Color safetySeverityColor(SafetySeverity severity, ColorScheme colorScheme)` (Tasks 3, and indirectly 5/6 via the next function).
  - `ProfileHighlightRange? profileHighlightRangeFor(SafetyFinding? finding, ColorScheme colorScheme)` (Tasks 5, 6).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  final now = DateTime.utc(2026, 8, 7);

  SafetyFinding finding({
    SafetySeverity severity = SafetySeverity.caution,
    int? start = 300,
    int? end = 420,
  }) => SafetyFinding(
    id: 'f1',
    diveId: 'dive-1',
    ruleId: SafetyRuleId.rapidAscent,
    severity: severity,
    startTimestamp: start,
    endTimestamp: end,
    value: 12.0,
    engineVersion: 1,
    createdAt: now,
  );

  group('safetySeverityColor', () {
    test('significant maps to tertiary', () {
      expect(
        safetySeverityColor(SafetySeverity.significant, scheme),
        scheme.tertiary,
      );
    });

    test('info and caution stay neutral', () {
      expect(
        safetySeverityColor(SafetySeverity.info, scheme),
        scheme.onSurfaceVariant,
      );
      expect(
        safetySeverityColor(SafetySeverity.caution, scheme),
        scheme.onSurfaceVariant,
      );
    });
  });

  group('profileHighlightRangeFor', () {
    test('maps a finding to its range and severity color', () {
      final range = profileHighlightRangeFor(
        finding(severity: SafetySeverity.significant),
        scheme,
      );
      expect(range, isNotNull);
      expect(range!.startTimestamp, 300);
      expect(range.endTimestamp, 420);
      expect(range.color, scheme.tertiary);
    });

    test('returns null for a null finding', () {
      expect(profileHighlightRangeFor(null, scheme), isNull);
    });

    test('returns null when either timestamp is missing', () {
      expect(profileHighlightRangeFor(finding(start: null), scheme), isNull);
      expect(profileHighlightRangeFor(finding(end: null), scheme), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart`
Expected: FAIL — compile error, `safety_finding_highlight.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_log/presentation/widgets/safety_finding_highlight.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';

/// Severity accent shared by the finding tile icon and the chart highlight.
/// Follows the safety spec's tone rules (muted, no alarm red): significant
/// maps to tertiary, everything else stays neutral.
Color safetySeverityColor(SafetySeverity severity, ColorScheme colorScheme) {
  return switch (severity) {
    SafetySeverity.significant => colorScheme.tertiary,
    SafetySeverity.info ||
    SafetySeverity.caution => colorScheme.onSurfaceVariant,
  };
}

/// Maps the selected finding to the chart's highlight parameter. Returns null
/// when nothing is selected or the finding has no profile time range.
ProfileHighlightRange? profileHighlightRangeFor(
  SafetyFinding? finding,
  ColorScheme colorScheme,
) {
  if (finding == null) return null;
  final start = finding.startTimestamp;
  final end = finding.endTimestamp;
  if (start == null || end == null) return null;
  return ProfileHighlightRange(
    startTimestamp: start,
    endTimestamp: end,
    color: safetySeverityColor(finding.severity, colorScheme),
  );
}
```

Then add the provider at the end of `lib/features/dive_log/presentation/providers/safety_review_providers.dart`:

```dart
/// The safety finding currently selected for profile-chart highlighting, or
/// null when none. Session state keyed by dive ID: the safety review section
/// writes it on tile tap; the detail and fullscreen profile charts read it.
/// Stores the whole finding (timestamps, severity) so chart consumers never
/// depend on the async [safetyReviewProvider]. Not persisted.
final selectedSafetyFindingProvider =
    StateProvider.family<SafetyFinding?, String>((ref, diveId) => null);
```

(`StateProvider` is already available via the file's existing `package:submersion/core/providers/provider.dart` import.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/providers/safety_review_providers.dart lib/features/dive_log/presentation/widgets/safety_finding_highlight.dart test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart
git commit -m "Add safety finding selection provider and highlight mapping"
```

---

### Task 3: Finding tile tap, selected styling, scroll-to-chart, clear-on-dismiss

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/safety_review_section.dart`
- Modify: `test/features/dive_log/presentation/widgets/safety_review_section_test.dart`

**Interfaces:**
- Consumes: `selectedSafetyFindingProvider`, `safetySeverityColor` from Task 2.
- Produces: user-facing selection behavior; no new symbols for later tasks.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/dive_log/presentation/widgets/safety_review_section_test.dart`. Add these imports at the top (keep existing ones):

```dart
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
```

(already imported) — additionally the test needs nothing new imported; `ProviderScope.containerOf` comes from flutter_riverpod which is already imported.

Add this fake repository class after the existing imports/helpers (top level of the file):

```dart
class _FakeSafetyFindingsRepository extends Fake
    implements SafetyFindingsRepository {
  @override
  Future<void> setDismissed({
    required String findingId,
    required bool dismissed,
    required DateTime now,
  }) async {}
}
```

`Fake` comes from `package:flutter_test/flutter_test.dart` (already imported). Check the real signature of `SafetyFindingsRepository.setDismissed` in `lib/features/dive_log/data/repositories/safety_findings_repository.dart` and mirror it exactly (the section calls it with named args `findingId`, `dismissed`, `now`).

Add a new group at the end of `main()`:

```dart
  group('finding selection', () {
    SafetyFinding secondFinding() => SafetyFinding(
      id: 'f2',
      diveId: 'dive-1',
      ruleId: SafetyRuleId.missedDecoStop,
      severity: SafetySeverity.caution,
      startTimestamp: 600,
      endTimestamp: 700,
      value: 2.0,
      engineVersion: 1,
      createdAt: now,
    );

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(SafetyReviewSection)),
        );

    Future<void> pumpSelectable(
      WidgetTester tester,
      SafetyReview review, {
      ScrollController? controller,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            safetyReviewProvider('dive-1').overrideWith((ref) async => review),
            safetyFindingsRepositoryProvider.overrideWithValue(
              _FakeSafetyFindingsRepository(),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    const SizedBox(height: 2000),
                    SafetyReviewSection(diveId: 'dive-1'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a finding selects it', (tester) async {
      await pumpSelectable(tester, reviewWith([rapidAscent()]));

      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();

      final selected = containerOf(
        tester,
      ).read(selectedSafetyFindingProvider('dive-1'));
      expect(selected?.id, 'f1');
    });

    testWidgets('tapping the selected finding clears the selection', (
      tester,
    ) async {
      await pumpSelectable(tester, reviewWith([rapidAscent()]));

      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();
      // Selecting scrolled the view back to the top; scroll down again to
      // reach the tile for the second tap.
      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(selectedSafetyFindingProvider('dive-1')),
        isNull,
      );
    });

    testWidgets('tapping a different finding replaces the selection', (
      tester,
    ) async {
      await pumpSelectable(
        tester,
        reviewWith([rapidAscent(), secondFinding()]),
      );

      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('ceiling'),
        400,
      );
      await tester.tap(find.textContaining('ceiling'));
      await tester.pumpAndSettle();

      final selected = containerOf(
        tester,
      ).read(selectedSafetyFindingProvider('dive-1'));
      expect(selected?.id, 'f2');
    });

    testWidgets('selecting scrolls the page toward the chart (offset 0)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpSelectable(
        tester,
        reviewWith([rapidAscent()]),
        controller: controller,
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
    });

    testWidgets('dismissing the selected finding clears the selection', (
      tester,
    ) async {
      await pumpSelectable(tester, reviewWith([rapidAscent()]));

      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byIcon(Icons.close), 400);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(selectedSafetyFindingProvider('dive-1')),
        isNull,
      );
    });

    testWidgets('a finding without timestamps is not tappable', (
      tester,
    ) async {
      await pumpSelectable(
        tester,
        reviewWith([
          SafetyFinding(
            id: 'f-no-time',
            diveId: 'dive-1',
            ruleId: SafetyRuleId.sawtoothProfile,
            severity: SafetySeverity.info,
            startTimestamp: null,
            endTimestamp: null,
            value: 4.0,
            engineVersion: 1,
            createdAt: now,
          ),
        ]),
      );

      await tester.scrollUntilVisible(find.byType(ListTile), 400);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(selectedSafetyFindingProvider('dive-1')),
        isNull,
      );
    });
  });
```

Notes for the implementer:
- The missed-deco-stop tile title comes from `l10n.safetyReview_missedDecoStop_title`. Before relying on `find.textContaining('ceiling')`, check the actual English template in `lib/l10n/arb/app_en.arb` (search `safetyReview_missedDecoStop_title`) and adjust the finder substring to match a distinctive word in it.
- The existing `reviewWith`, `rapidAscent`, and `now` helpers at the top of `main()` are reused; keep them untouched.

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_review_section_test.dart`
Expected: existing tests PASS, all six new "finding selection" tests FAIL (tap has no effect, provider stays null / offset unchanged — the first assertion failure will be `selected?.id == 'f1'`).

- [ ] **Step 3: Implement the section changes**

In `lib/features/dive_log/presentation/widgets/safety_review_section.dart`:

1. Add import:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
```

2. In `_SafetyReviewSectionState.build`, watch the selection (after the `units` line):

```dart
    final selectedFinding = ref.watch(
      selectedSafetyFindingProvider(widget.diveId),
    );
```

3. Pass selection state and tap handler to every `_FindingTile` (both the active list and the dismissed list):

```dart
              _FindingTile(
                finding: finding,
                units: units,
                selected: selectedFinding?.id == finding.id,
                onTap:
                    finding.startTimestamp != null &&
                        finding.endTimestamp != null
                    ? () => _toggleSelected(finding)
                    : null,
                onDismissChanged: (dismissed) =>
                    _setDismissed(finding, dismissed),
              ),
```

4. Add the toggle method to `_SafetyReviewSectionState`:

```dart
  void _toggleSelected(SafetyFinding finding) {
    final notifier = ref.read(
      selectedSafetyFindingProvider(widget.diveId).notifier,
    );
    final wasSelected = notifier.state?.id == finding.id;
    notifier.state = wasSelected ? null : finding;
    if (wasSelected) return;
    // Bring the profile chart (fixed near the top of the page) into view so
    // the highlight is visible immediately. Works for both the master-detail
    // retained controller and a standalone page's internal controller.
    Scrollable.maybeOf(context)?.position.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }
```

5. In `_setDismissed`, clear a dismissed finding's selection (before the repository call):

```dart
    if (dismissed) {
      final selectedNotifier = ref.read(
        selectedSafetyFindingProvider(widget.diveId).notifier,
      );
      if (selectedNotifier.state?.id == finding.id) {
        selectedNotifier.state = null;
      }
    }
```

6. Extend `_FindingTile` with the two new fields and wire them into the `ListTile`; also switch the leading icon color to the shared severity mapping:

```dart
class _FindingTile extends StatelessWidget {
  final SafetyFinding finding;
  final UnitFormatter units;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<bool> onDismissChanged;

  const _FindingTile({
    required this.finding,
    required this.units,
    required this.selected,
    required this.onTap,
    required this.onDismissChanged,
  });
```

In its `build`, the `ListTile` gains:

```dart
    final severityColor = safetySeverityColor(finding.severity, colorScheme);

    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: severityColor.withValues(alpha: 0.08),
      onTap: onTap,
      leading: Icon(
        _iconFor(finding.severity),
        size: 20,
        color: severityColor,
      ),
```

(The old inline `finding.severity == SafetySeverity.significant ? colorScheme.tertiary : colorScheme.onSurfaceVariant` expression is replaced by `severityColor` — same colors, now shared with the chart. Everything else in the tile stays as is.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/safety_review_section_test.dart`
Expected: PASS (all existing + 6 new).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/widgets/safety_review_section.dart test/features/dive_log/presentation/widgets/safety_review_section_test.dart
git commit -m "Select safety findings by tap and scroll the chart into view"
```

---

### Task 4: Chart rendering — band, edge lines, instant cursor

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- Create: `test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart`

**Interfaces:**
- Consumes: `ProfileHighlightRange`, `visibleHighlightSpan` from Task 1.
- Produces: `DiveProfileChart` constructor param `ProfileHighlightRange? highlightRange` (Tasks 5, 6).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  // 10 points, 30 s apart: x axis spans 0..270 s.
  final profile = List.generate(
    10,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 5 ? i * 3.0 : (10 - i) * 3.0,
    ),
  );

  Future<void> pumpChart(
    WidgetTester tester, {
    ProfileHighlightRange? highlightRange,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DiveProfileChart(
                profile: profile,
                highlightRange: highlightRange,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  LineChartData chartData(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart).first).data;

  testWidgets('no highlight renders no annotations or highlight lines', (
    tester,
  ) async {
    await pumpChart(tester);
    final data = chartData(tester);
    expect(data.rangeAnnotations.verticalRangeAnnotations, isEmpty);
    expect(data.extraLinesData.verticalLines, isEmpty);
  });

  testWidgets('a range highlight renders a band with two edge lines', (
    tester,
  ) async {
    await pumpChart(
      tester,
      highlightRange: const ProfileHighlightRange(
        startTimestamp: 60,
        endTimestamp: 120,
        color: Colors.teal,
      ),
    );
    final data = chartData(tester);

    final annotations = data.rangeAnnotations.verticalRangeAnnotations;
    expect(annotations, hasLength(1));
    expect(annotations.single.x1, 60);
    expect(annotations.single.x2, 120);

    final lines = data.extraLinesData.verticalLines;
    expect(lines, hasLength(2));
    expect(lines.map((l) => l.x), containsAll([60.0, 120.0]));
  });

  testWidgets('an instant highlight renders a single dashed cursor, no band', (
    tester,
  ) async {
    await pumpChart(
      tester,
      highlightRange: const ProfileHighlightRange(
        startTimestamp: 90,
        endTimestamp: 90,
        color: Colors.teal,
      ),
    );
    final data = chartData(tester);

    expect(data.rangeAnnotations.verticalRangeAnnotations, isEmpty);
    final lines = data.extraLinesData.verticalLines;
    expect(lines, hasLength(1));
    expect(lines.single.x, 90);
    expect(lines.single.dashArray, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart`
Expected: FAIL — compile error: `DiveProfileChart` has no `highlightRange` parameter.

- [ ] **Step 3: Implement the chart changes**

In `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`:

1. Add the import (local import group):

```dart
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
```

2. Add the field next to `highlightedTimestamp` (around line 195):

```dart
  /// Optional time range to emphasize (e.g. the selected safety finding).
  /// A true range renders as a translucent vertical band with edge lines;
  /// an instant (start == end) renders as a single dashed cursor line.
  final ProfileHighlightRange? highlightRange;
```

3. Add `this.highlightRange,` to the `const DiveProfileChart({...})` constructor (next to `this.highlightedTimestamp,`).

4. In the chart build (search for `extraLinesData: ExtraLinesData(`, currently near line 2583), the `LineChartData` gains `rangeAnnotations` and the vertical-lines list gains the highlight lines. `visibleMinX` and `visibleMaxX` are already in scope there:

```dart
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: _buildHighlightRangeAnnotations(
                visibleMinX,
                visibleMaxX,
              ),
            ),
            extraLinesData: ExtraLinesData(
              verticalLines: [
                ..._buildPlaybackCursor(colorScheme),
                ..._buildHighlightCursor(colorScheme),
                ..._buildHighlightRangeLines(visibleMinX, visibleMaxX),
                if (_showEvents && widget.events != null)
                  ..._buildEventVerticalLines(colorScheme),
              ],
            ),
```

5. Add the two builder methods next to `_buildHighlightCursor` (near line 4954):

```dart
  /// Translucent band for the externally highlighted time range, clamped to
  /// the visible window (fl_chart asserts annotations stay within bounds).
  /// Instant ranges draw no band; see [_buildHighlightRangeLines].
  List<VerticalRangeAnnotation> _buildHighlightRangeAnnotations(
    double visibleMinX,
    double visibleMaxX,
  ) {
    final range = widget.highlightRange;
    if (range == null || range.startTimestamp == range.endTimestamp) {
      return [];
    }
    final span = visibleHighlightSpan(
      range,
      visibleMinX: visibleMinX,
      visibleMaxX: visibleMaxX,
    );
    if (span == null) return [];
    return [
      VerticalRangeAnnotation(
        x1: span.x1,
        x2: span.x2,
        color: range.color.withValues(alpha: 0.12),
      ),
    ];
  }

  /// Edge lines for a range highlight (only the edges inside the visible
  /// window), or the single dashed cursor for an instant highlight.
  List<VerticalLine> _buildHighlightRangeLines(
    double visibleMinX,
    double visibleMaxX,
  ) {
    final range = widget.highlightRange;
    if (range == null) return [];
    final start = range.startTimestamp.toDouble();
    final end = range.endTimestamp.toDouble();

    bool inWindow(double x) => x >= visibleMinX && x <= visibleMaxX;

    if (range.startTimestamp == range.endTimestamp) {
      if (!inWindow(start)) return [];
      return [
        VerticalLine(
          x: start,
          color: range.color,
          strokeWidth: 1.5,
          dashArray: [3, 3],
        ),
      ];
    }

    return [
      for (final x in [start, end])
        if (inWindow(x))
          VerticalLine(
            x: x,
            color: range.color.withValues(alpha: 0.7),
            strokeWidth: 1,
          ),
    ];
  }
```

If the `LineChartData` already has a `rangeAnnotations:` argument (it should not — verify with a search before editing), merge the annotation list into it instead of adding a second argument.

- [ ] **Step 4: Run the new test and the existing chart tests**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_ceiling_fill_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_deco_stop_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart`
Expected: all PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart
git commit -m "Render an external highlight range on the dive profile chart"
```

---

### Task 5: Detail page wiring

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Modify: `test/features/dive_log/presentation/pages/dive_detail_page_test.dart`

**Interfaces:**
- Consumes: `selectedSafetyFindingProvider` (Task 2), `profileHighlightRangeFor` (Task 2), `DiveProfileChart.highlightRange` (Task 4).
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Append a new group to `test/features/dive_log/presentation/pages/dive_detail_page_test.dart` (reuse the existing `_buildDetailPage` / `getBaseOverrides` helpers in that file). Add imports:

```dart
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
```

New group:

```dart
  group('safety finding highlight wiring', () {
    Dive diveWithProfile() => Dive(
      id: 'dive-highlight',
      dateTime: DateTime(2026, 1, 1, 10),
      profile: List.generate(
        20,
        (i) => DiveProfilePoint(timestamp: i * 60, depth: 15),
      ),
    );

    testWidgets('selected finding reaches the chart as a highlight range', (
      tester,
    ) async {
      final dive = diveWithProfile();
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(_buildDetailPage(dive, overrides));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      );
      container.read(selectedSafetyFindingProvider(dive.id).notifier).state =
          SafetyFinding(
            id: 'f1',
            diveId: dive.id,
            ruleId: SafetyRuleId.rapidAscent,
            severity: SafetySeverity.significant,
            startTimestamp: 300,
            endTimestamp: 420,
            value: 14.0,
            engineVersion: 1,
            createdAt: DateTime.utc(2026, 8, 7),
          );
      await tester.pump();

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chart.highlightRange, isNotNull);
      expect(chart.highlightRange!.startTimestamp, 300);
      expect(chart.highlightRange!.endTimestamp, 420);
    });

    testWidgets('no selection means no highlight range', (tester) async {
      final dive = diveWithProfile();
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(_buildDetailPage(dive, overrides));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chart.highlightRange, isNull);
    });
  });
```

Notes for the implementer:
- If the bare `Dive` constructor requires more arguments than the fullscreen test's `_dive()` helper uses (id, dateTime, profile), copy the full argument list from `createTestDiveWithBottomTime` in `test/helpers/mock_providers.dart` and add the profile.
- If pumping produces overflow errors, wrap the pump like `_pumpDetailPage` does (it filters "overflowed" FlutterErrors).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart`
Expected: existing tests PASS; the first new test FAILS on compile if imports are wrong, otherwise on `chart.highlightRange` not existing as a wired value (`isNotNull` fails since the page never passes it).

- [ ] **Step 3: Implement the wiring**

In `lib/features/dive_log/presentation/pages/dive_detail_page.dart`:

1. Add imports (local group, keep alphabetical placement consistent with neighbors):

```dart
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
```

(Search first — `safety_review_providers.dart` may already be imported.)

2. In the profile section's `LayoutBuilder` (search for `final trackingIndex = ref.watch(`, currently near line 1642), add below it:

```dart
                final selectedFinding = ref.watch(
                  selectedSafetyFindingProvider(diveId),
                );
```

3. In the `DiveProfileChart(...)` construction below (near the existing `highlightedTimestamp:` argument), add:

```dart
                        highlightRange: profileHighlightRangeFor(
                          selectedFinding,
                          Theme.of(context).colorScheme,
                        ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart`
Expected: PASS (all existing + 2 new).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart
git commit -m "Pass the selected safety finding to the detail profile chart"
```

---

### Task 6: Fullscreen profile wiring

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`
- Modify: `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`

**Interfaces:**
- Consumes: `selectedSafetyFindingProvider` (Task 2), `profileHighlightRangeFor` (Task 2), `DiveProfileChart.highlightRange` (Task 4).
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Append to `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`, reusing its `_wrap` / `_defaultOverrides` helpers. Add imports:

```dart
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
```

New test:

```dart
  testWidgets('selected safety finding carries into fullscreen as a highlight', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FullscreenProfilePage)),
    );
    container.read(selectedSafetyFindingProvider('d1').notifier).state =
        SafetyFinding(
          id: 'f1',
          diveId: 'd1',
          ruleId: SafetyRuleId.missedDecoStop,
          severity: SafetySeverity.caution,
          startTimestamp: 120,
          endTimestamp: 240,
          value: 2.0,
          engineVersion: 1,
          createdAt: DateTime.utc(2026, 8, 7),
        );
    await tester.pump();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    expect(chart.highlightRange, isNotNull);
    expect(chart.highlightRange!.startTimestamp, 120);
    expect(chart.highlightRange!.endTimestamp, 240);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`
Expected: existing tests PASS, new test FAILS (`chart.highlightRange` is null — the page never passes it).

- [ ] **Step 3: Implement the wiring**

In `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`:

1. Add imports (search first in case either is already present):

```dart
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
```

2. In the build method, near where other per-dive providers are read (e.g. next to the `reviewTimestamp` / playback reads), add:

```dart
    final selectedFinding = ref.watch(
      selectedSafetyFindingProvider(widget.diveId),
    );
```

3. In the `DiveProfileChart(...)` construction (near the existing `highlightedTimestamp: reviewTimestamp,` argument at ~line 390), add:

```dart
                          highlightRange: profileHighlightRangeFor(
                            selectedFinding,
                            Theme.of(context).colorScheme,
                          ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`
Expected: PASS (all existing + 1 new).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
git commit -m "Carry the safety finding highlight into the fullscreen profile"
```

---

### Task 7: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Format the whole project**

Run: `dart format lib/ test/`
Expected: "0 changed" (if files change, commit the formatting as "Format").

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: "No issues found!" — infos count as failures. Do not pipe through tail/head.

- [ ] **Step 3: Run the affected test suites together**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_highlight_range_test.dart test/features/dive_log/presentation/widgets/safety_finding_highlight_test.dart test/features/dive_log/presentation/widgets/safety_review_section_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_highlight_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`
Expected: all PASS.

- [ ] **Step 4: Run the full unit test suite**

Run: `flutter test`
Expected: PASS. Known flaky suites unrelated to this change (backup/restore, media upload drain, recovery-code) may need a rerun — rerun the individual failing file once before investigating; only investigate failures that touch dive_log presentation code.

- [ ] **Step 5: Commit any stragglers and stop**

If anything was fixed in steps 1–4, commit it with a message describing the fix. Do not push or open a PR — integration is decided by the user afterward (superpowers:finishing-a-development-branch).
