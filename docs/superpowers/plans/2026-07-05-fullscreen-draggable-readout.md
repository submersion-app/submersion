# Fullscreen Draggable Readout Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fullscreen profile page's clipped hover tooltip with an always-visible draggable readout card whose position persists in settings.

**Architecture:** The chart's existing external-tooltip mode (`tooltipBelow: true` + `onTooltipData`) suppresses the painted bubble and streams `TooltipRow` data to the page, which renders it in a new `DraggableReadoutCard` positioned inside a `Stack` over the chart area. Position is a `FractionalOffset`-style fraction of the movable range, clamped, and saved to two new nullable `AppSettings` doubles on drag end.

**Tech Stack:** Flutter widgets (Stack/Align/GestureDetector), Riverpod settings notifier, SharedPreferences, flutter gen-l10n.

**Spec:** `docs/superpowers/specs/2026-07-05-fullscreen-draggable-readout-design.md`

## Global Constraints

- WORKTREE: all paths are relative to the worktree root `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/fullscreen-tooltip-clamp` (branch `worktree-fullscreen-draggable-readout`). Never edit files under the main checkout path. Do not run bare `git stash`.
- Run `dart format .` (whole repo) before every commit; commit only if it reports the files you touched (or 0 changed).
- No emojis anywhere. Sound null safety. New strings translated into all 10 non-English locales: ar, de, es, fr, he, hu, it, nl, pt, zh, then `flutter gen-l10n`.
- `flutter analyze` must stay at the baseline 22 pre-existing issues (none in touched files).
- Run specific test files, never whole directories (Bash timeout).
- Commits per task are pre-authorized by plan approval. Plain commit messages, no Co-Authored-By trailers.

---

### Task 1: Reset the interim clamp work; keep the detail-page placement pin

The branch has uncommitted `tooltipInsidePlot` changes (an interim fix this
feature supersedes). Reset them, then re-add the one test worth keeping:
the pin on the detail page's above-the-chart placement.

**Files:**
- Reset: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`, `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`, `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`, `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`
- Modify: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`

**Interfaces:**
- Produces: clean HEAD state for all later tasks; a `DiveProfileChart - tooltip placement` test group other tasks must keep passing.

- [ ] **Step 1: Reset the four files to HEAD**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/fullscreen-tooltip-clamp
git checkout -- \
  lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart \
  lib/features/dive_log/presentation/widgets/dive_profile_chart.dart \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart \
  test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git status --short
```

Expected: `git status --short` prints nothing (clean tree).

- [ ] **Step 2: Add the detail-page placement pin test**

In `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`,
insert this group directly above the line
`// =========================================================================`
that precedes `group('DiveProfileChart.tankTooltipLabel', () {`:

```dart
  group('DiveProfileChart - tooltip placement', () {
    testWidgets('default keeps the bubble pinned above the chart box '
        '(detail-page behavior)', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      final tooltip = tester
          .widget<LineChart>(find.byType(LineChart).first)
          .data
          .lineTouchData
          .touchTooltipData;
      expect(tooltip.showOnTopOfTheChartBoxArea, isTrue);
      expect(tooltip.fitInsideVertically, isFalse);
      expect(tooltip.tooltipMargin, 0);
    });
  });

```

- [ ] **Step 3: Run the test**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart --plain-name 'tooltip placement'
```

Expected: `+1: All tests passed!`

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart
git commit -m "test(dive_log): pin detail-page tooltip placement above the chart box"
```

---

### Task 2: Settings plumbing for the card position

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `test/features/settings/presentation/providers/settings_notifier_real_test.dart`
- Modify: `test/helpers/mock_providers.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, `test/features/statistics/presentation/pages/records_page_test.dart`

**Interfaces:**
- Produces: `AppSettings.fullscreenReadoutCardX` / `AppSettings.fullscreenReadoutCardY` (`double?`, null = unset) and `Future<void> SettingsNotifier.setFullscreenReadoutCardPosition(double x, double y)`. Task 5 consumes all three.

- [ ] **Step 1: Write the failing test**

In `test/features/settings/presentation/providers/settings_notifier_real_test.dart`,
add this group inside `main()`, after the closing `});` of the existing
`group('Real SettingsNotifier.setShowDetailsPaneForSection', ...)`. It reuses
the file-level fakes (`_InMemorySettingsRepository`, `_EmptyDiverRepository`,
`_NullDiverIdNotifier`) and mirrors the existing group's setUp:

```dart
  group('Real SettingsNotifier.setFullscreenReadoutCardPosition', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diverSettingsRepositoryProvider.overrideWithValue(
            _InMemorySettingsRepository(),
          ),
          diverRepositoryProvider.overrideWithValue(_EmptyDiverRepository()),
          currentDiverIdProvider.overrideWith((ref) => _NullDiverIdNotifier()),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      container.dispose();
    });

    test('defaults to null and round-trips through SharedPreferences',
        () async {
      // Let the notifier's async _initializeAndLoad settle.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final notifier = container.read(settingsProvider.notifier);

      expect(container.read(settingsProvider).fullscreenReadoutCardX, isNull);
      expect(container.read(settingsProvider).fullscreenReadoutCardY, isNull);

      await notifier.setFullscreenReadoutCardPosition(0.25, 0.75);

      expect(container.read(settingsProvider).fullscreenReadoutCardX, 0.25);
      expect(container.read(settingsProvider).fullscreenReadoutCardY, 0.75);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('fullscreen_readout_card_x'), 0.25);
      expect(prefs.getDouble('fullscreen_readout_card_y'), 0.75);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart
```

Expected: FAIL to compile with "The getter 'fullscreenReadoutCardX' isn't defined" (and the setter missing).

- [ ] **Step 3: Implement the settings plumbing**

All edits in `lib/features/settings/presentation/providers/settings_providers.dart`.

(a) In `SettingsKeys`, directly after
`static const String fullscreenHiddenTiles = 'fullscreen_hidden_tiles';` (line ~75):

```dart
  static const String fullscreenReadoutCardX = 'fullscreen_readout_card_x';
  static const String fullscreenReadoutCardY = 'fullscreen_readout_card_y';
```

(b) In `AppSettings`, directly after
`final List<String> fullscreenHiddenTiles;` (line ~308):

```dart
  /// Fullscreen readout card position as fractions (0..1) of the movable
  /// range; null means the default corner. See DraggableReadoutCard.
  final double? fullscreenReadoutCardX;
  final double? fullscreenReadoutCardY;
```

(c) In the `AppSettings` constructor, directly after
`this.fullscreenHiddenTiles = const [],` (line ~405):

```dart
    this.fullscreenReadoutCardX,
    this.fullscreenReadoutCardY,
```

(d) In `copyWith`, add parameters directly after
`List<String>? fullscreenHiddenTiles,` (line ~535):

```dart
    double? fullscreenReadoutCardX,
    double? fullscreenReadoutCardY,
```

and assignments directly after the
`fullscreenHiddenTiles: fullscreenHiddenTiles ?? this.fullscreenHiddenTiles,`
line (~line 655):

```dart
      fullscreenReadoutCardX:
          fullscreenReadoutCardX ?? this.fullscreenReadoutCardX,
      fullscreenReadoutCardY:
          fullscreenReadoutCardY ?? this.fullscreenReadoutCardY,
```

(There is no clear-to-null requirement; positions are only ever set.)

(e) In `_loadSettings`, directly after the
`final fullscreenHiddenTiles = prefs.getStringList(...) ?? const [];`
statement (line ~750):

```dart
      final fullscreenReadoutCardX = prefs.getDouble(
        SettingsKeys.fullscreenReadoutCardX,
      );
      final fullscreenReadoutCardY = prefs.getDouble(
        SettingsKeys.fullscreenReadoutCardY,
      );
```

Then find BOTH `AppSettings(`/`copyWith(` construction sites inside
`_loadSettings` that pass `fullscreenTileOrder: fullscreenTileOrder,`
(lines ~757 and ~766; `grep -n "fullscreenTileOrder: fullscreenTileOrder"`)
and add to each, right after their `fullscreenHiddenTiles:` argument:

```dart
        fullscreenReadoutCardX: fullscreenReadoutCardX,
        fullscreenReadoutCardY: fullscreenReadoutCardY,
```

(f) In `_saveSettings`, directly after the
`await prefs.setStringList(SettingsKeys.fullscreenTileOrder, ...)` statement
group (there is a matching `fullscreenHiddenTiles` write just below it; add
after both, keeping the device-local comment block intact):

```dart
    final readoutCardX = state.fullscreenReadoutCardX;
    if (readoutCardX != null) {
      await prefs.setDouble(SettingsKeys.fullscreenReadoutCardX, readoutCardX);
    }
    final readoutCardY = state.fullscreenReadoutCardY;
    if (readoutCardY != null) {
      await prefs.setDouble(SettingsKeys.fullscreenReadoutCardY, readoutCardY);
    }
```

(g) In `SettingsNotifier`, directly after the closing brace of
`setFullscreenTilePreferences` (line ~1267):

```dart
  Future<void> setFullscreenReadoutCardPosition(double x, double y) async {
    state = state.copyWith(
      fullscreenReadoutCardX: x,
      fullscreenReadoutCardY: y,
    );
    await _saveSettings();
  }
```

- [ ] **Step 4: Stub the explicit fakes**

Three test fakes implement `SettingsNotifier` without `noSuchMethod` and
need the new member. In each of
`test/helpers/mock_providers.dart`,
`test/features/settings/presentation/pages/settings_page_test.dart`,
`test/features/statistics/presentation/pages/records_page_test.dart`,
add inside the fake class (next to its other setter overrides):

```dart
  @override
  Future<void> setFullscreenReadoutCardPosition(double x, double y) async {
    state = state.copyWith(
      fullscreenReadoutCardX: x,
      fullscreenReadoutCardY: y,
    );
  }
```

If a fake's class does not expose `state` mutation that way, an empty body
`async {}` is acceptable there; match each file's existing stub style.

- [ ] **Step 5: Run tests to verify they pass**

```bash
flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart
flutter analyze
```

Expected: settings test file all pass; analyze reports exactly the baseline
22 pre-existing issues and nothing in the files touched here. If analyze
flags another `SettingsNotifier` fake, add the same stub there.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/settings/presentation/providers/settings_providers.dart \
  test/features/settings/presentation/providers/settings_notifier_real_test.dart \
  test/helpers/mock_providers.dart \
  test/features/settings/presentation/pages/settings_page_test.dart \
  test/features/statistics/presentation/pages/records_page_test.dart
git commit -m "feat(settings): persist fullscreen readout card position"
```

---

### Task 3: Localized placeholder hint

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` plus `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`

**Interfaces:**
- Produces: `context.l10n.diveLog_fullscreenProfile_readoutHint` (Task 4 consumes it).

- [ ] **Step 1: Add the key to the template arb**

In `lib/l10n/arb/app_en.arb`, next to the existing
`"diveLog_fullscreenProfile_close"` entry (line ~2189), add:

```json
  "diveLog_fullscreenProfile_readoutHint": "Hover or scrub the profile",
  "@diveLog_fullscreenProfile_readoutHint": {
    "description": "Placeholder shown in the fullscreen readout card before any profile point has been hovered or scrubbed"
  },
```

- [ ] **Step 2: Add translations to the 10 locale arbs**

Add `"diveLog_fullscreenProfile_readoutHint": "<value>"` to each locale file
(next to that locale's `diveLog_fullscreenProfile_close` entry; locale files
carry values only, no `@` metadata). Before inserting, check how each file
translates "profile" in its other `diveLog_fullscreenProfile_*` keys and
keep the same noun. Values:

| File | Value |
| --- | --- |
| app_ar.arb | "مرر المؤشر أو اسحب فوق ملف الغوص" |
| app_de.arb | "Zeiger über das Profil bewegen oder scrubben" |
| app_es.arb | "Pasa el cursor o desliza sobre el perfil" |
| app_fr.arb | "Survolez ou faites glisser sur le profil" |
| app_he.arb | "רחפו או גררו על הפרופיל" |
| app_hu.arb | "Vigye az egérmutatót a profil fölé, vagy húzza rajta az ujját" |
| app_it.arb | "Passa il cursore o scorri sul profilo" |
| app_nl.arb | "Beweeg de muis over het profiel of veeg erover" |
| app_pt.arb | "Passe o cursor ou deslize sobre o perfil" |
| app_zh.arb | "悬停或滑动查看剖面图" |

- [ ] **Step 3: Regenerate and verify**

```bash
flutter gen-l10n
flutter test test/l10n/localization_test.dart
```

Expected: generation succeeds; localization test passes (it checks key
parity across locales).

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "feat(l10n): add fullscreen readout card hint string"
```

---

### Task 4: DraggableReadoutCard widget (TDD)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/draggable_readout_card.dart`
- Create: `test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart`

**Interfaces:**
- Consumes: `TooltipRow` (label/value/bulletColor) from `dive_profile_chart.dart`; the l10n hint from Task 3.
- Produces: `DraggableReadoutCard({required List<TooltipRow>? rows, required Offset? initialFraction, required ValueChanged<Offset> onDragEnd})`, `DraggableReadoutCard.defaultFraction == Offset(1, 0)`, and the inner card's `ValueKey('readout-card')`. Task 5 consumes all of these. The widget must be placed directly inside a `Stack` (it renders `Positioned.fill`).

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draggable_readout_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _cardKey = ValueKey('readout-card');

Widget _wrap({
  List<TooltipRow>? rows,
  Offset? initialFraction,
  ValueChanged<Offset>? onDragEnd,
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
                onDragEnd: onDragEnd ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the localized hint before any rows arrive', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(rows: null));
    await tester.pumpAndSettle();

    expect(find.text('Hover or scrub the profile'), findsOneWidget);
  });

  testWidgets('renders rows with label and value, hint gone', (tester) async {
    await tester.pumpWidget(
      _wrap(
        rows: const [
          TooltipRow(label: 'Depth', value: '18.2 m', bulletColor: Colors.blue),
          TooltipRow(label: 'Temp', value: '22 C', bulletColor: Colors.red),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hover or scrub the profile'), findsNothing);
    expect(find.text('Depth'), findsOneWidget);
    expect(find.text('18.2 m'), findsOneWidget);
    expect(find.text('Temp'), findsOneWidget);
  });

  testWidgets('defaults to the top-right corner', (tester) async {
    await tester.pumpWidget(_wrap(rows: null));
    await tester.pumpAndSettle();

    final stackRect = tester.getRect(find.byKey(const ValueKey('arena')));
    final cardRect = tester.getRect(find.byKey(_cardKey));
    // Right edge inset by the 12px padding; top edge likewise.
    expect(cardRect.right, closeTo(stackRect.right - 12, 1.0));
    expect(cardRect.top, closeTo(stackRect.top + 12, 1.0));
  });

  testWidgets('dragging moves the card and clamps at the bounds', (
    tester,
  ) async {
    Offset? lastFraction;
    await tester.pumpWidget(
      _wrap(rows: null, onDragEnd: (f) => lastFraction = f),
    );
    await tester.pumpAndSettle();

    // Drag far past the top-left corner: must clamp to fraction (0,0).
    await tester.drag(find.byKey(_cardKey), const Offset(-2000, -2000));
    await tester.pumpAndSettle();

    final stackRect = tester.getRect(find.byKey(const ValueKey('arena')));
    final cardRect = tester.getRect(find.byKey(_cardKey));
    expect(cardRect.left, closeTo(stackRect.left + 12, 1.0));
    expect(cardRect.top, closeTo(stackRect.top + 12, 1.0));
    expect(lastFraction, const Offset(0, 0));
  });

  testWidgets('a partial drag reports an interior fraction', (tester) async {
    Offset? lastFraction;
    await tester.pumpWidget(
      _wrap(
        rows: null,
        initialFraction: const Offset(0, 0),
        onDragEnd: (f) => lastFraction = f,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(_cardKey), const Offset(80, 60));
    await tester.pumpAndSettle();

    expect(lastFraction, isNotNull);
    expect(lastFraction!.dx, greaterThan(0));
    expect(lastFraction!.dx, lessThan(1));
    expect(lastFraction!.dy, greaterThan(0));
    expect(lastFraction!.dy, lessThan(1));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart
```

Expected: FAIL to compile ("draggable_readout_card.dart" not found).

- [ ] **Step 3: Implement the widget**

Create `lib/features/dive_log/presentation/widgets/draggable_readout_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Always-visible floating readout for the fullscreen profile page.
///
/// Renders the latest externally emitted tooltip rows (see
/// [DiveProfileChart.onTooltipData]) in a compact card the user can drag
/// anywhere within the enclosing [Stack]. Position is a fraction of the
/// movable range (stack size minus card size): (0,0) is flush top-left,
/// (1,1) flush bottom-right. Must be placed directly inside a [Stack].
class DraggableReadoutCard extends StatefulWidget {
  /// Latest tooltip rows; null or empty shows the placeholder hint.
  final List<TooltipRow>? rows;

  /// Starting position fraction; null uses [defaultFraction].
  final Offset? initialFraction;

  /// Called with the final position fraction when a drag ends. The caller
  /// persists it (fullscreen page saves to settings).
  final ValueChanged<Offset> onDragEnd;

  const DraggableReadoutCard({
    super.key,
    required this.rows,
    required this.initialFraction,
    required this.onDragEnd,
  });

  /// Default position: top-right corner.
  static const Offset defaultFraction = Offset(1, 0);

  @override
  State<DraggableReadoutCard> createState() => _DraggableReadoutCardState();
}

class _DraggableReadoutCardState extends State<DraggableReadoutCard> {
  static const _inset = 12.0;
  final GlobalKey _cardKey = GlobalKey();
  late Offset _fraction =
      widget.initialFraction ?? DraggableReadoutCard.defaultFraction;

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final cardSize = _cardKey.currentContext?.size;
    if (cardSize == null) return;
    final movableW = constraints.maxWidth - cardSize.width;
    final movableH = constraints.maxHeight - cardSize.height;
    setState(() {
      _fraction = Offset(
        movableW <= 0
            ? 0
            : (_fraction.dx + details.delta.dx / movableW).clamp(0.0, 1.0),
        movableH <= 0
            ? 0
            : (_fraction.dy + details.delta.dy / movableH).clamp(0.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rows = widget.rows;

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: FractionalOffset(_fraction.dx, _fraction.dy),
            child: GestureDetector(
              onPanUpdate: (details) => _onPanUpdate(details, constraints),
              onPanEnd: (_) => widget.onDragEnd(_fraction),
              child: Container(
                key: const ValueKey('readout-card'),
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: rows == null || rows.isEmpty
                    ? Text(
                        context.l10n.diveLog_fullscreenProfile_readoutHint,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final row in rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: row.bulletColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      row.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(row.value, style: textTheme.bodySmall),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart
```

Expected: `+5: All tests passed!`

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/draggable_readout_card.dart \
  test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart
git commit -m "feat(dive_log): add draggable readout card widget"
```

---

### Task 5: Fullscreen page wiring

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`
- Modify: `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`

**Interfaces:**
- Consumes: `DraggableReadoutCard` (Task 4), `setFullscreenReadoutCardPosition` + the two `AppSettings` fields (Task 2), `DiveProfileChart.tooltipBelow`/`onTooltipData` (existing).

- [ ] **Step 1: Write the failing page tests**

In `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`:

(a) Add imports next to the existing widget imports:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draggable_readout_card.dart';
```

(b) Replace the `_FakeSettingsNotifier` class with a version that captures
the persisted position (keep `noSuchMethod`):

```dart
class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier([AppSettings? initial])
    : super(initial ?? const AppSettings());

  double? savedCardX;
  double? savedCardY;

  @override
  Future<void> setFullscreenReadoutCardPosition(double x, double y) async {
    savedCardX = x;
    savedCardY = y;
    state = state.copyWith(
      fullscreenReadoutCardX: x,
      fullscreenReadoutCardY: y,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

(c) Add these tests after the `'renders chart and instrument bar'` test:

```dart
  testWidgets('shows the readout card with the placeholder hint', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableReadoutCard), findsOneWidget);
    expect(find.text('Hover or scrub the profile'), findsOneWidget);
  });

  testWidgets('chart runs in external-tooltip mode (no painted bubble)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    expect(chart.tooltipBelow, isTrue);
    expect(chart.onTooltipData, isNotNull);
  });

  testWidgets('long-press populates the card and values stick after release', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final chartCenter = tester.getCenter(find.byType(LineChart).first);
    final gesture = await tester.startGesture(chartCenter);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(2, 0));
    await tester.pump();

    // Rows arrived: hint is gone from the card.
    expect(find.text('Hover or scrub the profile'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    // Sticky: hover ended but the card keeps the last values.
    expect(find.text('Hover or scrub the profile'), findsNothing);
  });

  testWidgets('dragging the card persists a clamped fraction to settings', (
    tester,
  ) async {
    final fake = _FakeSettingsNotifier();
    final overrides = _defaultOverrides()
      ..removeAt(0)
      ..insert(0, settingsProvider.overrideWith((ref) => fake));
    await tester.pumpWidget(_wrap(overrides));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('readout-card')),
      const Offset(-3000, 3000),
    );
    await tester.pumpAndSettle();

    expect(fake.savedCardX, 0.0);
    expect(fake.savedCardY, 1.0);
  });

  testWidgets('saved position seeds the card at bottom-left', (tester) async {
    final overrides = _defaultOverrides()
      ..removeAt(0)
      ..insert(
        0,
        settingsProvider.overrideWith(
          (ref) => _FakeSettingsNotifier(
            const AppSettings(
              fullscreenReadoutCardX: 0,
              fullscreenReadoutCardY: 1,
            ),
          ),
        ),
      );
    await tester.pumpWidget(_wrap(overrides));
    await tester.pumpAndSettle();

    final chartRect = tester.getRect(find.byType(DiveProfileChart));
    final cardRect = tester.getRect(
      find.byKey(const ValueKey('readout-card')),
    );
    expect(cardRect.left, lessThan(chartRect.center.dx));
    expect(cardRect.bottom, greaterThan(chartRect.center.dy));
  });
```

Note: `_defaultOverrides()` puts the settings override at index 0; the
`removeAt(0)`/`insert(0, ...)` pattern swaps in the parameterized fake.

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
```

Expected: FAIL (card type not found / `tooltipBelow` false).

- [ ] **Step 3: Wire the page**

All edits in `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`.

(a) Add the import next to the other widget imports:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/draggable_readout_card.dart';
```

(b) In `_FullscreenProfilePageState`, add a field next to the existing state
fields at the top of the class:

```dart
  /// Last non-null tooltip rows; the readout card keeps showing these after
  /// the hover ends (sticky values).
  List<TooltipRow>? _readoutRows;
```

and this method next to the other private helpers:

```dart
  void _onTooltipData(List<TooltipRow>? rows) {
    if (rows == null || rows.isEmpty) return; // sticky: keep last values
    setState(() => _readoutRows = rows);
  }
```

(c) In `build`, wrap the chart in a `Stack` and add the card. The current
code is:

```dart
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: DiveProfileChart(
```

Change to (the chart's argument list is unchanged apart from (d) below;
`settings` is defined in (e)):

```dart
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: DiveProfileChart(
```

and close the new `Stack` after the chart's `Padding`: the current closing
sequence at the end of the chart call is

```dart
                    ),
                  ),
                ),
                // Source switching and overlay comparison, mirroring the
```

which becomes

```dart
                        ),
                      ),
                      DraggableReadoutCard(
                        // Re-key on the saved position so a settings load
                        // that lands after first build still seeds the card.
                        key: ValueKey(
                          'readout-card-seed-'
                          '${settings.fullscreenReadoutCardX}-'
                          '${settings.fullscreenReadoutCardY}',
                        ),
                        rows: _readoutRows,
                        initialFraction:
                            settings.fullscreenReadoutCardX != null &&
                                settings.fullscreenReadoutCardY != null
                            ? Offset(
                                settings.fullscreenReadoutCardX!,
                                settings.fullscreenReadoutCardY!,
                              )
                            : null,
                        onDragEnd: (fraction) => ref
                            .read(settingsProvider.notifier)
                            .setFullscreenReadoutCardPosition(
                              fraction.dx,
                              fraction.dy,
                            ),
                      ),
                    ],
                  ),
                ),
                // Source switching and overlay comparison, mirroring the
```

(Re-indent the whole chart argument block by four extra spaces to match;
`dart format .` normalizes any misses.)

(d) Inside the chart's argument list, directly after
`maxDepth: dive.maxDepth,`, add:

```dart
                          // The painted tooltip would clip at the screen edge
                          // (no headroom above the plot in fullscreen); the
                          // draggable readout card renders the data instead.
                          tooltipBelow: true,
                          onTooltipData: _onTooltipData,
```

(e) At the top of `build`, next to the other `ref.watch` calls (around
`final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);`), add:

```dart
    final settings = ref.watch(settingsProvider);
```

and add the import for it if not already present:

```dart
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
```

Expected: all pass, including the pre-existing page tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
git commit -m "feat(dive_log): draggable readout card on fullscreen profile"
```

---

### Task 6: Full verification sweep

**Files:** none new; fixes only if something fails.

- [ ] **Step 1: Run every touched test file**

```bash
flutter test \
  test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart \
  test/features/dive_log/presentation/widgets/draggable_readout_card_test.dart \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart \
  test/features/settings/presentation/providers/settings_notifier_real_test.dart \
  test/l10n/localization_test.dart
```

Expected: all pass.

- [ ] **Step 2: Whole-project format and analyze**

```bash
dart format .
flutter analyze
```

Expected: format 0 changed; analyze at the 22-issue pre-existing baseline
with nothing in files this plan touched. Fix and re-run if not.

- [ ] **Step 3: Commit any verification fixes**

Only if Steps 1-2 required changes:

```bash
git add -A
git commit -m "test(dive_log): verification fixes for draggable readout card"
```
