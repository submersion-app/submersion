# Planner Redesign Phase 2: Mission Control Layout - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the planner the whole window: a 52px icon rail replaces the 440px Planning sidebar, the planner becomes a three-pane Mission Control on desktop and a Chart + Tab Deck on phone, and the monolithic settings panel becomes a Setup accordion.

**Architecture:** `PlanningShell` gets two wide states (full-width hub on the index route, icon rail beside any tool). `PlanCanvasPage` becomes a thin layout router over three extracted panes (`PlanEditorPane`, chart column, `PlanResultsPane`), choosing three-pane / drawer / phone modes from `LayoutBuilder` constraints - the space actually given, not window width. `PlanSettingsPanel` is decomposed into per-topic Setup sections hosted by an accordion sized for the full parity control set (spec section 6.2; later phases only add controls into existing sections). Engine-facing state (`DivePlanNotifier`, `planOutcomeProvider`) is untouched.

**Tech Stack:** Flutter, Riverpod 3, go_router, phase-1 chart + plan_kit vocabulary. No new dependencies. Stacked on branch `worktree-planner-ui-redesign` (phase 1, PR #612).

## Global Constraints

- Worktree `.claude/worktrees/planner-ui-redesign`, branch `worktree-planner-ui-redesign` (stack on phase 1; do not rebase).
- No emojis anywhere. No hard-coded colors - `Theme.of(context).colorScheme` or `PlanChartPalette` only.
- `dart format .` produces no changes before every commit; `flutter analyze` clean.
- New user-visible strings into ALL 11 locales (`app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`) + `flutter gen-l10n`.
- Commit messages conventional, no Co-Authored-By, no attribution.
- Run targeted test files; the full suite runs in CI / pre-push.
- Never bare `git stash`.
- Units always via `UnitFormatter`.

## Verified facts you will build against

- Breakpoints (`lib/shared/widgets/master_detail/responsive_breakpoints.dart`): `desktop = 800`, `masterDetail = 1100`, `desktopExtended = 1200`; methods `isDesktop/isMasterDetail/isDesktopExtended/isMobile` read window width via MediaQuery.
- Router (`lib/core/router/app_router.dart:202-276`): inner `ShellRoute` whose `pageBuilder` wraps children in `PlanningShell(child:)`; the `/planning` index route branches `ResponsiveBreakpoints.isMasterDetail` to `PlanningWelcome` (wide) or `PlanningPage` (narrow); tool routes are nested children (`dive-planner` with `compare` and `:planId` children; `deco-calculator`, `gas-calculators`, `weight-calculator`, `surface-interval`, `gps-logger` redirect).
- Only the router imports `planning_shell.dart` and `planning_welcome.dart`; `PlanningShell` and `PlanningWelcome` have zero test coverage. `PlanningPage` has one widget test (`test/features/planning/planning_page_test.dart`) that renders it directly - unaffected by shell changes.
- `PlanCanvasPage` currently branches phone/wide on `ResponsiveBreakpoints.isDesktop` (window width >= 800) - replaced in this phase by constraint-based modes.
- Editor widgets (`SegmentList`, `PlanTankList`, `PlanGearWeightsSection`, `CcrSettingsSection`, `ContingencySettingsSection`) are layout-agnostic Cards/rows with no width checks; safe to re-host.
- `PlanResultsSheet({required ScrollController controller})` hands the controller to its root ListView; section order: grip, deco schedule, gas, bailout, contingencies (collapsible via `contingenciesExpandedProvider`), range table, warnings.
- `PlanChip({label, value, tint, emphasized, onTap})` is public in `plan_status_chips.dart`; `PlanStatusChips({required VoidCallback onIssuesTap})`.
- `DivePlanState` (lib/features/dive_planner/domain/entities/plan_result.dart:465) fields used by the header: `name`, `mode` (PlanMode.oc/ccr), `gfLow`, `gfHigh`, `altitude` (double?, meters). There is NO waterType field - the environment chip shows altitude only.
- `selectedSegmentIdProvider` (dive_planner_providers.dart:615) is currently write-only (chart writes it; nothing reads it). Phase 3 consumes it; do not remove it.
- `planResultsSheetSectionProvider` (plan_canvas_providers.dart:58) is dead - this phase deletes it.
- Existing l10n keys to REUSE: `divePlanner_tab_plan` ("Plan"), `divePlanner_tab_results` ("Results"), `divePlanner_label_tanks` ("Tanks"), `divePlanner_label_planSettings` ("Plan Settings"), `divePlanner_label_gfLow`/`_gfHigh`/`_sacRate`/`_altitude`/`_reserve`, `plannerCanvas_contingency_title`, `planner_gearWeights_title`, `divePlanner_segmentList_title`, `planning_sidebar_*_title` (rail tooltips), `planning_appBar_title` ("Planning"). Only "Setup" and pane collapse/expand tooltips need new keys.
- Affected tests (complete list): `test/features/planner/plan_canvas_page_test.dart` (10 cases - phone cases at 420x900 assert chart/chips/SegmentList/DraggableScrollableSheet; wide cases at 1400x900 assert PlanSettingsPanel and no sheet; menu cases), `test/features/dive_planner/presentation/widgets/plan_settings_panel_test.dart` (reserve-field, reserve-validation, altitude-input, and 5 parameterized overflow cases), `test/features/planner/ccr_ui_test.dart` (OC/CCR badge via PlanCanvasPage at 420x900; other two cases render PlanResultsSheet/CcrSettingsSection directly - unaffected). `test/features/planning/planning_page_test.dart` unaffected.

## File structure

Create:
- `lib/features/planning/presentation/widgets/planning_rail.dart` - 52px icon rail
- `lib/features/planner/presentation/providers/planner_layout_providers.dart` - pane collapse + phone tab state
- `lib/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart` - GF sliders (moved)
- `lib/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart` - SAC + logged-SAC + reserve (moved)
- `lib/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart` - altitude (moved)
- `lib/features/planner/presentation/panes/plan_setup_accordion.dart`
- `lib/features/planner/presentation/panes/plan_editor_pane.dart`
- `lib/features/planner/presentation/panes/plan_results_pane.dart`
- `lib/features/planner/presentation/pages/plan_chart_fullscreen_page.dart`

Modify: `planning_shell.dart` (rewrite, delete `_PlanningSidebar`), `app_router.dart` (index route + fullscreen chart route), `plan_canvas_page.dart` (rebuild body/header), `plan_kit.dart` (add `PlanStatTile`), `plan_canvas_providers.dart` (delete dead provider), 11 arb files.

Delete: `planning_welcome.dart`, `plan_settings_panel.dart` (after accordion adoption).

---

### Task 1: Layout state providers + l10n keys

**Files:**
- Create: `lib/features/planner/presentation/providers/planner_layout_providers.dart`
- Modify: `lib/l10n/arb/app_en.arb` + the 10 other locale files
- Test: `test/features/planner/planner_layout_providers_test.dart`

**Interfaces:**
- Produces: `final editorPaneCollapsedProvider = StateProvider<bool>((_) => false);` `final resultsPaneCollapsedProvider = StateProvider<bool>((_) => false);` `final plannerPhoneTabProvider = StateProvider<int>((_) => 0);` (0 Plan, 1 Tanks, 2 Setup, 3 Results) and `final setupFocusSectionProvider = StateProvider<String?>((_) => null);` (accordion section key to reveal: 'deco' | 'gas' | 'environment' | 'ccr' | 'contingencies' | 'gear').
- New l10n keys (all 11 locales): `plannerCanvas_tab_setup`, `plannerCanvas_pane_collapse`, `plannerCanvas_pane_expand`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';

void main() {
  test('layout providers default to expanded panes, Plan tab, no focus', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(editorPaneCollapsedProvider), isFalse);
    expect(container.read(resultsPaneCollapsedProvider), isFalse);
    expect(container.read(plannerPhoneTabProvider), 0);
    expect(container.read(setupFocusSectionProvider), isNull);
  });

  test('providers hold written state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editorPaneCollapsedProvider.notifier).state = true;
    container.read(plannerPhoneTabProvider.notifier).state = 3;
    container.read(setupFocusSectionProvider.notifier).state = 'gas';
    expect(container.read(editorPaneCollapsedProvider), isTrue);
    expect(container.read(plannerPhoneTabProvider), 3);
    expect(container.read(setupFocusSectionProvider), 'gas');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/planner_layout_providers_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the providers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-scoped layout state for the planner's Mission Control layout.
/// Collapse state is remembered for the session, not persisted (same policy
/// as [contingenciesExpandedProvider]).

/// Whether the desktop editor pane (segments/tanks/setup) is collapsed.
final editorPaneCollapsedProvider = StateProvider<bool>((_) => false);

/// Whether the desktop results pane is collapsed.
final resultsPaneCollapsedProvider = StateProvider<bool>((_) => false);

/// Active phone tab: 0 Plan, 1 Tanks, 2 Setup, 3 Results.
final plannerPhoneTabProvider = StateProvider<int>((_) => 0);

/// Setup-accordion section to reveal (header chip deep-links). Keys:
/// 'deco' | 'gas' | 'environment' | 'ccr' | 'contingencies' | 'gear'.
/// Consumed and cleared by the accordion after expanding the section.
final setupFocusSectionProvider = StateProvider<String?>((_) => null);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/planner/planner_layout_providers_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Add the l10n keys**

In `lib/l10n/arb/app_en.arb`, insert alphabetically among the `plannerCanvas_` keys (before `"plannerCanvas_pane..."` sorts after `chart_meanDepth`; keep each file's alphabetical order):

```json
"plannerCanvas_pane_collapse": "Collapse panel",
"plannerCanvas_pane_expand": "Expand panel",
"plannerCanvas_tab_setup": "Setup",
```

Values for the other locales (same three keys, no placeholders, so no `@` metadata blocks are required by the existing house style for placeholder-free keys - match how neighboring simple keys are declared in each file):

| Locale | pane_collapse | pane_expand | tab_setup |
| --- | --- | --- | --- |
| ar | "طي اللوحة" | "توسيع اللوحة" | "الإعداد" |
| de | "Bereich einklappen" | "Bereich ausklappen" | "Einrichtung" |
| es | "Contraer panel" | "Expandir panel" | "Configuración" |
| fr | "Réduire le panneau" | "Développer le panneau" | "Réglages" |
| he | "כווץ חלונית" | "הרחב חלונית" | "הגדרה" |
| hu | "Panel összecsukása" | "Panel kibontása" | "Beállítás" |
| it | "Comprimi pannello" | "Espandi pannello" | "Configurazione" |
| nl | "Paneel inklappen" | "Paneel uitklappen" | "Instellingen" |
| pt | "Recolher painel" | "Expandir painel" | "Configuração" |
| zh | "折叠面板" | "展开面板" | "设置" |

Run: `flutter gen-l10n`
Expected: regenerates cleanly; `context.l10n.plannerCanvas_tab_setup` etc. become available.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/providers/planner_layout_providers.dart test/features/planner/planner_layout_providers_test.dart lib/l10n
git commit -m "feat(planner): layout state providers and pane/tab l10n keys"
```

---

### Task 2: PlanningRail + shell rewrite + router index (the space fix)

**Files:**
- Create: `lib/features/planning/presentation/widgets/planning_rail.dart`
- Rewrite: `lib/features/planning/presentation/widgets/planning_shell.dart`
- Modify: `lib/core/router/app_router.dart` (index route builder ~lines 208-220; remove the `planning_welcome.dart` import at ~line 121)
- Delete: `lib/features/planning/presentation/widgets/planning_welcome.dart`
- Test: `test/features/planning/planning_shell_test.dart` (new - the shell currently has none)

**Interfaces:**
- Produces: `class PlanningRail extends StatelessWidget { const PlanningRail({super.key, required this.currentPath}); final String currentPath; }` - 52px wide column: back-to-hub button (tooltip `planning_appBar_title`, navigates `context.go('/planning')`) then five tool icons (tooltips = existing `planning_sidebar_*_title` keys) with selected-state tint, each `context.go(route)`. Rail width constant: `static const double width = 52;`
- `PlanningShell` behavior contract: narrow (`!isMasterDetail`) returns child unchanged (unchanged behavior); wide + path == `/planning` returns the child full-width (the hub - no sidebar, no rail); wide + any tool path returns `Row[PlanningRail, VerticalDivider, Expanded(child)]`.
- Router: the `/planning` index route always builds `PlanningPage` (the wide/narrow branch and `PlanningWelcome` are deleted). On wide screens `PlanningPage`'s ListView content is constrained to 720px and centered by the shell (see shell code - hub content looks intentional full-width, not stretched).

- [ ] **Step 1: Write the failing shell test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_rail.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_shell.dart';

import '../../helpers/test_app.dart';

Widget _shellAt(String path, {required Size size}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      ShellRoute(
        builder: (context, state, child) => PlanningShell(child: child),
        routes: [
          GoRoute(
            path: '/planning',
            builder: (_, __) => const Text('HUB'),
            routes: [
              GoRoute(
                path: 'dive-planner',
                builder: (_, __) => const Text('PLANNER'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: testAppRouter(router: router),
  );
}

void main() {
  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('wide hub renders full width with no rail and no sidebar', (
    tester,
  ) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(_shellAt('/planning', size: const Size(1400, 900)));
    await tester.pumpAndSettle();
    expect(find.text('HUB'), findsOneWidget);
    expect(find.byType(PlanningRail), findsNothing);
  });

  testWidgets('wide tool route shows the rail beside the tool', (tester) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(
      _shellAt('/planning/dive-planner', size: const Size(1400, 900)),
    );
    await tester.pumpAndSettle();
    expect(find.text('PLANNER'), findsOneWidget);
    expect(find.byType(PlanningRail), findsOneWidget);
  });

  testWidgets('rail back button returns to the hub', (tester) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(
      _shellAt('/planning/dive-planner', size: const Size(1400, 900)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('HUB'), findsOneWidget);
    expect(find.byType(PlanningRail), findsNothing);
  });

  testWidgets('narrow returns the child bare', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(
      _shellAt('/planning/dive-planner', size: const Size(420, 900)),
    );
    await tester.pumpAndSettle();
    expect(find.text('PLANNER'), findsOneWidget);
    expect(find.byType(PlanningRail), findsNothing);
  });
}
```

Note: `testAppRouter({required GoRouter router, overrides})` exists in `test/helpers/test_app.dart`. The outer `MediaQuery` wrapper is defensive; the real width signal is `tester.view.physicalSize`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planning/planning_shell_test.dart`
Expected: FAIL (PlanningRail does not exist).

- [ ] **Step 3: Implement PlanningRail**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The 52px icon rail shown beside an open Planning tool on wide screens.
/// Replaces the 440px master sidebar so the tool gets the window.
class PlanningRail extends StatelessWidget {
  const PlanningRail({super.key, required this.currentPath});

  static const double width = 52;

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        icon: Icons.edit_calendar,
        tooltip: context.l10n.planning_sidebar_divePlanner_title,
        route: '/planning/dive-planner',
      ),
      (
        icon: Icons.calculate,
        tooltip: context.l10n.planning_sidebar_decoCalculator_title,
        route: '/planning/deco-calculator',
      ),
      (
        icon: Icons.science,
        tooltip: context.l10n.planning_sidebar_gasCalculators_title,
        route: '/planning/gas-calculators',
      ),
      (
        icon: Icons.fitness_center,
        tooltip: context.l10n.planning_sidebar_weightCalculator_title,
        route: '/planning/weight-calculator',
      ),
      (
        icon: Icons.timer,
        tooltip: context.l10n.planning_sidebar_surfaceInterval_title,
        route: '/planning/surface-interval',
      ),
    ];

    return Container(
      width: width,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: context.l10n.planning_appBar_title,
            onPressed: () => context.go('/planning'),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _RailButton(
                icon: item.icon,
                tooltip: item.tooltip,
                selected: currentPath.startsWith(item.route),
                onPressed: () => context.go(item.route),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Remove the `material_design_icons_flutter` import if the analyzer flags it unused (it is only needed if a chosen icon comes from MDI; the icons above are all Material).

- [ ] **Step 4: Rewrite PlanningShell**

Replace the entire contents of `planning_shell.dart` (the `_PlanningSidebar`, `_SidebarItem`, `_SidebarTile` classes are deleted with it):

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/planning/presentation/widgets/planning_rail.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Shell for the Planning section.
///
/// Narrow screens: pass-through (push navigation).
/// Wide screens, hub route (/planning): the hub renders full width, its
/// content centered at a comfortable reading width.
/// Wide screens, tool route: a 52px [PlanningRail] beside the tool, so the
/// tool (especially the planner) gets effectively the whole window.
class PlanningShell extends StatelessWidget {
  final Widget child;

  const PlanningShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBreakpoints.isMasterDetail(context)) {
      return child;
    }

    final path = GoRouterState.of(context).uri.path;
    final onHub = path == '/planning';
    if (onHub) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: child,
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          PlanningRail(currentPath: path),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Update the router**

In `lib/core/router/app_router.dart`:
1. Delete the import of `planning_welcome.dart` (~line 121).
2. Replace the index-route builder (current code, quoted for exact match):

```dart
      pageBuilder: (context, state) {
        // On wide screens show welcome placeholder, on mobile show hub
        final isWide = ResponsiveBreakpoints.isMasterDetail(context);
        return NoTransitionPage(
          key: state.pageKey,
          child: isWide
              ? const PlanningWelcome()
              : const PlanningPage(),
        );
      },
```

with:

```dart
      pageBuilder: (context, state) {
        // The hub is the landing surface on every width; the shell decides
        // how much width it gets.
        return NoTransitionPage(key: state.pageKey, child: const PlanningPage());
      },
```

If `ResponsiveBreakpoints` is now unused in this file's imports, leave it - other routes in the file use it (verify with the analyzer, remove only if flagged).

3. Delete `lib/features/planning/presentation/widgets/planning_welcome.dart`:

```bash
git rm lib/features/planning/presentation/widgets/planning_welcome.dart
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/planning/ && flutter analyze`
Expected: new shell tests PASS, existing `planning_page_test.dart` PASS, analyzer clean. If the analyzer reports unused `planning_welcome_*` l10n keys, leave the keys (harmless; phase 8 rebuilds the hub and may reuse or remove them).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(planning): icon rail shell, full-width hub, drop 440px sidebar"
```

---

### Task 3: Setup section widgets (decompose PlanSettingsPanel)

**Files:**
- Create: `lib/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart`
- Create: `lib/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart`
- Create: `lib/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart`
- Test: `test/features/dive_planner/presentation/widgets/setup/plan_setup_sections_test.dart`
- (PlanSettingsPanel itself is deleted in Task 6, after its last consumer is rebuilt.)

**Interfaces:**
- Produces: `class PlanDecoSection extends ConsumerWidget { const PlanDecoSection({super.key}); }` (GF low/high slider row), `class PlanGasSection extends ConsumerWidget { const PlanGasSection({super.key}); }` (SAC slider + logged-SAC button + reserve input), `class PlanEnvironmentSection extends ConsumerWidget { const PlanEnvironmentSection({super.key}); }` (altitude input with group chip). Each is a plain Column (no Card, no header) - the accordion provides chrome. Later phases add controls INTO these files (deco-model radio into PlanDecoSection, water type into PlanEnvironmentSection, etc.).
- Source of the moved code: `plan_settings_panel.dart` private widgets `_GfSlider`, `_LoggedSacButton`, `_AltitudeInput` (+ `_AltitudeInputState`), `_ReservePressureInput` (+ state). Move them verbatim into the new files as private classes; only the public wrappers are new.

- [ ] **Step 1: Write the failing tests**

The existing `plan_settings_panel_test.dart` cases define the behavior contract. Write the new test file exercising the same behaviors against the new sections (the old file is deleted in Task 6 together with the panel):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([AppSettings? initial])
    : super(initial ?? const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(Widget child, {AppSettings? settings}) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
  ],
  child: SingleChildScrollView(child: child),
);

void main() {
  testWidgets('deco section renders both GF sliders and updates state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
  });

  testWidgets('gas section shows SAC slider and reserve field with unit', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanGasSection()));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('bar'), findsWidgets);
  });

  testWidgets('reserve validation: zero shows error, valid updates state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanGasSection()));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    await tester.enterText(field, '0');
    await tester.pumpAndSettle();
    expect(find.textContaining('positive'), findsOneWidget);
    await tester.enterText(field, '60');
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasSection)),
    );
    expect(container.read(divePlanNotifierProvider).reservePressure, 60);
  });

  testWidgets('environment section shows altitude group chip at 1000m', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(const PlanEnvironmentSection()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Group 2'), findsOneWidget);
  });

  testWidgets('no overflow at narrow widths', (tester) async {
    for (final size in const [Size(300, 600), Size(375, 667)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        _harness(
          const Column(
            children: [
              PlanDecoSection(),
              PlanGasSection(),
              PlanEnvironmentSection(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
    tester.view.reset();
  });
}
```

Adjust the reserve-error assertion string to the actual `divePlanner_error_reserveMustBePositive` English value if `textContaining('positive')` does not match it (check `app_en.arb`; the old test file asserts these strings - copy the exact expectations from there).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_planner/presentation/widgets/setup/plan_setup_sections_test.dart`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement the three sections**

`plan_deco_section.dart` - move `_GfSlider` verbatim from `plan_settings_panel.dart:543-587` and wrap:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Deco settings for the Setup accordion: gradient factors now; the
/// deco-model radio (Buhlmann / VPM-B / Recreational) lands here in later
/// phases (spec G1/G2).
class PlanDecoSection extends ConsumerWidget {
  const PlanDecoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    return Row(
      children: [
        Expanded(
          child: _GfSlider(
            label: context.l10n.divePlanner_label_gfLow,
            value: planState.gfLow,
            onChanged: (value) => ref
                .read(divePlanNotifierProvider.notifier)
                .updateGradientFactors(value, planState.gfHigh),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _GfSlider(
            label: context.l10n.divePlanner_label_gfHigh,
            value: planState.gfHigh,
            onChanged: (value) => ref
                .read(divePlanNotifierProvider.notifier)
                .updateGradientFactors(planState.gfLow, value),
          ),
        ),
      ],
    );
  }
}

// _GfSlider moved verbatim from plan_settings_panel.dart (lines 543-587).
```

`plan_gas_section.dart` - move `_LoggedSacButton` (167-196) and `_ReservePressureInput` (+state, 377-541) verbatim; the public widget reproduces the panel's SAC row (79-113) and altitude/reserve row's reserve half (137-155), stacked vertically (the accordion is a narrow column - no need for the old side-by-side row or its `compact` LayoutBuilder):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gas settings for the Setup accordion: SAC (with one-tap logged average)
/// and reserve pressure. Bottom/deco SAC split and SAC factor land here in
/// later phases (spec G25).
class PlanGasSection extends ConsumerWidget {
  const PlanGasSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              flex: 0,
              child: Text(context.l10n.divePlanner_label_sacRate),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                label:
                    'SAC Rate: ${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol} per minute',
                child: Slider(
                  value: planState.sacRate,
                  min: 8,
                  max: 30,
                  divisions: 22,
                  label:
                      '${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol}/min',
                  onChanged: (value) => ref
                      .read(divePlanNotifierProvider.notifier)
                      .updateSacRate(value),
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                '${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol}/min',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        _LoggedSacButton(currentSac: planState.sacRate, units: units),
        const SizedBox(height: 12),
        _ReservePressureInput(
          reservePressure: planState.reservePressure,
          defaultPressureBar: settings.pressureUnit == PressureUnit.psi
              ? PressureUnit.psi.convert(500, PressureUnit.bar)
              : DivePlanState.kDefaultReservePressureBar,
          maxPressureBar: planState.tanks
              .map((t) => t.startPressure ?? 0.0)
              .fold(0.0, (a, b) => a > b ? a : b),
          units: units,
          compact: true,
          onChanged: (value) => ref
              .read(divePlanNotifierProvider.notifier)
              .updateReservePressure(value),
        ),
      ],
    );
  }
}

// _LoggedSacButton and _ReservePressureInput(+State) moved verbatim from
// plan_settings_panel.dart.
```

Note: `DivePlanState` lives in `plan_result.dart` (the old panel imported it via `plan_result.dart` - keep that import). The reserve widget's `compact: true` variant stacks label above field (already implemented in the moved code).

`plan_environment_section.dart` - move `_AltitudeInput`/`_AltitudeInputState` (199-375) verbatim:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Environment settings for the Setup accordion: altitude with the altitude
/// group indicator. Water type / salinity lands here in later phases.
class PlanEnvironmentSection extends ConsumerWidget {
  const PlanEnvironmentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    return _AltitudeInput(
      altitude: planState.altitude,
      units: units,
      compact: true,
      onChanged: (value) =>
          ref.read(divePlanNotifierProvider.notifier).updateAltitude(value),
    );
  }
}

// _AltitudeInput(+State) moved verbatim from plan_settings_panel.dart.
```

Do NOT delete `plan_settings_panel.dart` yet (PlanCanvasPage still uses it until Task 6); the moved private classes are duplicated for now - acceptable for two tasks, resolved when the panel is deleted.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_planner/presentation/widgets/setup/plan_setup_sections_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_planner/presentation/widgets/setup test/features/dive_planner/presentation/widgets/setup
git commit -m "feat(planner): setup sections extracted from the settings panel"
```

---

### Task 4: PlanSetupAccordion

**Files:**
- Create: `lib/features/planner/presentation/panes/plan_setup_accordion.dart`
- Test: `test/features/planner/panes/plan_setup_accordion_test.dart`

**Interfaces:**
- Consumes: the three setup sections (Task 3), `CcrSettingsSection`, `ContingencySettingsSection`, `PlanGearWeightsSection`, `setupFocusSectionProvider` (Task 1), `divePlanNotifierProvider` (mode for the conditional CCR section), `PlanSectionHeader` (plan_kit).
- Produces: `class PlanSetupAccordion extends ConsumerStatefulWidget { const PlanSetupAccordion({super.key}); }` - a Column of `ExpansionTile`s with section keys 'deco', 'gas', 'environment', 'ccr' (only when mode == ccr), 'contingencies', 'gear'. Titles reuse existing l10n: deco -> `divePlanner_label_decompression`, gas -> `diveField_category_gas`, environment -> `diveDetailSection_environment_name`, ccr -> 'CCR' literal is NOT acceptable - reuse `plannerCanvas_ccr_setpointLow`'s section: use the existing `divePlanner_label_planSettings`? No - use these existing keys verified in the arb: deco `divePlanner_label_decompression` ("Decompression"), gas `diveField_category_gas` ("Gas"), environment `diveDetailSection_environment_name` ("Environment"), contingencies `plannerCanvas_contingency_title`, gear `planner_gearWeights_title`. For CCR reuse the OC/CCR chip label pattern: the tile title is the literal string 'CCR' via `PlanChip`-consistent text - acceptable as it is a proper acronym, not a translatable word.
- Behavior: watching `setupFocusSectionProvider`; when it emits a key, that tile expands (via per-tile `ExpansionTileController`), the provider resets to null.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness() => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  child: const SingleChildScrollView(child: PlanSetupAccordion()),
);

void main() {
  testWidgets('renders all sections collapsed; CCR hidden on OC plans', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(5));
    expect(find.byType(CcrSettingsSection), findsNothing);
    expect(find.byType(PlanDecoSection), findsNothing);
  });

  testWidgets('tapping a section expands its content', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decompression'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanDecoSection), findsOneWidget);
  });

  testWidgets('CCR section appears for CCR plans', (tester) async {
    await tester.pumpWidget(_harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .updateMode(domain.PlanMode.ccr);
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(6));
    expect(find.text('CCR'), findsOneWidget);
  });

  testWidgets('setup focus expands the requested section and clears', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    container.read(setupFocusSectionProvider.notifier).state = 'deco';
    await tester.pumpAndSettle();
    expect(find.byType(PlanDecoSection), findsOneWidget);
    expect(container.read(setupFocusSectionProvider), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/panes/plan_setup_accordion_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the accordion**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_settings_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Plan Setup accordion: every plan-level setting grouped by topic.
/// Sized for the full parity control set - later phases add controls into
/// the existing sections (deco-model radio into Deco, rate bands into a new
/// Rates tile, water type into Environment) without relayout.
class PlanSetupAccordion extends ConsumerStatefulWidget {
  const PlanSetupAccordion({super.key});

  @override
  ConsumerState<PlanSetupAccordion> createState() =>
      _PlanSetupAccordionState();
}

class _PlanSetupAccordionState extends ConsumerState<PlanSetupAccordion> {
  final _controllers = <String, ExpansionTileController>{};

  ExpansionTileController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, ExpansionTileController.new);

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(divePlanNotifierProvider.select((s) => s.mode));

    // Header-chip deep link: expand the requested section, then clear.
    ref.listen(setupFocusSectionProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controllers[next]?.expand();
        ref.read(setupFocusSectionProvider.notifier).state = null;
      });
    });

    final sections = <(String, String, Widget)>[
      ('deco', context.l10n.divePlanner_label_decompression,
          const PlanDecoSection()),
      ('gas', context.l10n.diveField_category_gas, const PlanGasSection()),
      ('environment', context.l10n.diveDetailSection_environment_name,
          const PlanEnvironmentSection()),
      if (mode == domain.PlanMode.ccr)
        ('ccr', 'CCR', const CcrSettingsSection()),
      ('contingencies', context.l10n.plannerCanvas_contingency_title,
          const ContingencySettingsSection()),
      ('gear', context.l10n.planner_gearWeights_title,
          const PlanGearWeightsSection()),
    ];

    return Column(
      children: [
        for (final (key, title, child) in sections)
          ExpansionTile(
            key: PageStorageKey('planSetup_$key'),
            controller: _controllerFor(key),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [child],
          ),
      ],
    );
  }
}
```

Note: `PlanGearWeightsSection` renders its own Card + header today; inside the accordion that reads as double chrome, but restyling it is out of scope here - it is acceptable for this phase (the accordion tile is its navigation). If the analyzer objects to the records-in-list syntax on the project's Dart version, fall back to a small private `_Section` class with the same three fields.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/planner/panes/plan_setup_accordion_test.dart`
Expected: PASS (4 tests). If the 'Decompression'/'Gas'/'Environment' finder strings mismatch, check the actual English values of `divePlanner_label_decompression`, `diveField_category_gas`, `diveDetailSection_environment_name` in `app_en.arb` and use those exact strings in both the widget and test.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/panes/plan_setup_accordion.dart test/features/planner/panes/plan_setup_accordion_test.dart
git commit -m "feat(planner): plan setup accordion hosting decomposed settings sections"
```

---

### Task 5: PlanStatTile + editor and results panes

**Files:**
- Modify: `lib/features/planner/presentation/widgets/plan_kit.dart` (add `PlanStatTile`)
- Create: `lib/features/planner/presentation/panes/plan_editor_pane.dart`
- Create: `lib/features/planner/presentation/panes/plan_results_pane.dart`
- Test: `test/features/planner/panes/plan_panes_test.dart`

**Interfaces:**
- Produces:
  - `class PlanStatTile extends StatelessWidget { const PlanStatTile({required this.label, required this.value, this.emphasisColor, super.key}); final String label; final String value; final Color? emphasisColor; }` - small surface tile, uppercase label over bold value; `emphasisColor` tints background and value (used by the Issues tile).
  - `class PlanEditorPane extends StatelessWidget { const PlanEditorPane({super.key}); }` - `ListView(padding: EdgeInsets.all(12))` of `SegmentList`, 12px gap, `PlanTankList`, 12px gap, `PlanSectionHeader(divePlanner_label_planSettings)`, `PlanSetupAccordion`.
  - `class PlanResultsPane extends ConsumerWidget { const PlanResultsPane({super.key, required this.controller}); final ScrollController controller; }` - Column: stat-tile grid (2 columns: Runtime `divePlanner_label_runtime`, TTS `divePlanner_label_tts` or NDL `divePlanner_label_ndl` when not in deco, CNS `plannerCanvas_chip_cns`, Issues `plannerCanvas_chip_issues` with error tint when > 0) then `Expanded(PlanResultsSheet(controller: controller))`. Values from `planOutcomeProvider` (`runtimeSeconds`, `ttsAtBottom`, `ndlAtBottom`, `cnsEnd`, `issues.length`; `inDeco` == `outcome.stops.isNotEmpty` - check `PlanOutcome` for an existing `inDeco`/`stops` getter and use what `PlanStatusChips` uses, mirroring its branch exactly).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_results_pane.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

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
  final overrides = [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
  ];

  testWidgets('PlanStatTile shows label and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlanStatTile(label: 'Runtime', value: "46'")),
      ),
    );
    expect(find.text('RUNTIME'), findsOneWidget);
    expect(find.text("46'"), findsOneWidget);
  });

  testWidgets('editor pane stacks segments, tanks, setup', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SizedBox(width: 320, child: PlanEditorPane()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SegmentList), findsOneWidget);
    expect(find.byType(PlanTankList), findsOneWidget);
    expect(find.byType(PlanSetupAccordion), findsOneWidget);
  });

  testWidgets('results pane shows stat tiles reflecting the outcome', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: SizedBox(
          width: 340,
          height: 700,
          child: PlanResultsPane(controller: controller),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanResultsPane)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();
    expect(find.byType(PlanStatTile), findsNWidgets(4));
    expect(find.text('RUNTIME'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/planner/panes/plan_panes_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add PlanStatTile to plan_kit.dart**

Append to `lib/features/planner/presentation/widgets/plan_kit.dart`:

```dart
class PlanStatTile extends StatelessWidget {
  const PlanStatTile({
    required this.label,
    required this.value,
    this.emphasisColor,
    super.key,
  });

  final String label;
  final String value;
  final Color? emphasisColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = emphasisColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tint != null
            ? Color.alphaBlend(tint.withValues(alpha: 0.12), scheme.surface)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tint ?? scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: tint ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the panes**

`plan_editor_pane.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The editing column of Mission Control: segments and tanks always visible,
/// everything else in the Setup accordion.
class PlanEditorPane extends StatelessWidget {
  const PlanEditorPane({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const SegmentList(),
        const SizedBox(height: 12),
        const PlanTankList(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: PlanSectionHeader(context.l10n.divePlanner_label_planSettings),
        ),
        const PlanSetupAccordion(),
      ],
    );
  }
}
```

`plan_results_pane.dart` - mirror `PlanStatusChips`' deco branch exactly (open `plan_status_chips.dart`, copy how it decides NDL vs TTS and formats minutes; reuse its formatting helpers if they are public, else inline the same expressions):

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The always-visible results column of Mission Control: headline stat tiles
/// over the full results content.
class PlanResultsPane extends ConsumerWidget {
  const PlanResultsPane({super.key, required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(planOutcomeProvider);
    final scheme = Theme.of(context).colorScheme;
    final inDeco = outcome.stops.isNotEmpty;

    String minutes(int seconds) => "${(seconds / 60).round()}'";

    final tiles = [
      PlanStatTile(
        label: context.l10n.divePlanner_label_runtime,
        value: minutes(outcome.runtimeSeconds),
      ),
      if (inDeco)
        PlanStatTile(
          label: context.l10n.divePlanner_label_tts,
          value: minutes(outcome.ttsAtBottom),
        )
      else
        PlanStatTile(
          label: context.l10n.divePlanner_label_ndl,
          value: minutes(outcome.ndlAtBottom),
        ),
      PlanStatTile(
        label: context.l10n.plannerCanvas_chip_cns,
        value: '${outcome.cnsEnd.round()}%',
      ),
      PlanStatTile(
        label: context.l10n.plannerCanvas_chip_issues,
        value: '${outcome.issues.length}',
        emphasisColor: outcome.issues.isEmpty ? null : scheme.error,
      ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: tiles,
          ),
        ),
        Expanded(child: PlanResultsSheet(controller: controller)),
      ],
    );
  }
}
```

Check the exact `PlanOutcome` member names against `lib/features/planner/domain/entities/plan_outcome.dart` (`runtimeSeconds`, `ttsAtBottom`, `ndlAtBottom`, `cnsEnd`, `issues`, `stops` are the names reported by the phase-1 inventory; if any differ, mirror `plan_status_chips.dart`, which compiles against them today). If the `plannerCanvas_chip_cns` value already contains "CNS {value}" formatting (it is a chip label with placeholder), use `divePlanner_label_status`-style plain keys instead - open `app_en.arb` and pick the key whose English value is exactly "CNS"; if none exists, use the literal uppercase output of the chip key without its placeholder or mint nothing and reuse `plannerCanvas_chip_cns` splitting is NOT allowed - in that case reuse `divePlanner_label_max`? No: the correct fallback is to reuse the same l10n call `PlanStatusChips` makes for its CNS chip and pass only the label part it renders. Resolve at implementation time against the actual arb values; do not mint new keys for words that exist.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/planner/panes/plan_panes_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/planner/presentation/widgets/plan_kit.dart lib/features/planner/presentation/panes test/features/planner/panes/plan_panes_test.dart
git commit -m "feat(planner): stat tiles, editor pane, and results pane"
```

---

### Task 6: PlanCanvasPage rebuild (three modes + header chips + fullscreen chart) and test migration

**Files:**
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart` (replace `_buildPhone`/`_buildWide` and the AppBar title row; keep all action methods: `_savePlan`, `_convertToDive`, `_timeWeightedAverageDepth`, `_exportSlate`, `_sharePlanFile`, `_resetPlan`, `_showRenameDialog`, `_onMenu`, `_menuItem` - unchanged)
- Create: `lib/features/planner/presentation/pages/plan_chart_fullscreen_page.dart`
- Modify: `lib/core/router/app_router.dart` (add `chart` child route under `dive-planner`)
- Modify: `lib/features/planner/presentation/providers/plan_canvas_providers.dart` (delete dead `planResultsSheetSectionProvider`, line ~58)
- Delete: `lib/features/dive_planner/presentation/widgets/plan_settings_panel.dart` and `test/features/dive_planner/presentation/widgets/plan_settings_panel_test.dart`
- Modify: `test/features/planner/plan_canvas_page_test.dart` (migrate all 10 cases)

**Interfaces:**
- Consumes: panes (Task 5), accordion (Task 4), layout providers (Task 1), `PlanChip`, `PlanStatusChips`, `ContingencyChips`, `PlanProfileChart`.
- Produces layout contract (used by tests):
  - Constraint-based modes via the page body's `LayoutBuilder`: width >= 1160 three-pane (editor SizedBox 300 + chart column Expanded + results SizedBox 320, each side pane hidden when its collapsed provider is true, with a chevron `IconButton` (tooltips `plannerCanvas_pane_collapse`/`_expand`) in the chart column's corners to toggle); 760-1160 chart column + results pane, editor accessible via `Scaffold.drawer` containing `PlanEditorPane` (drawer button in the AppBar leading area only in this mode); < 760 phone Tab Deck.
  - Phone Tab Deck: Column [ SizedBox(height: constraints.maxHeight * 0.40, child: chart), PlanStatusChips, ContingencyChips, TabBar-like segmented row bound to `plannerPhoneTabProvider` (labels: `divePlanner_tab_plan`, `divePlanner_label_tanks`, `plannerCanvas_tab_setup`, `divePlanner_tab_results`), Expanded(per-tab body) ]. Tab bodies: 0 -> ListView(SegmentList); 1 -> ListView(PlanTankList); 2 -> ListView(PlanSetupAccordion); 3 -> PlanResultsPane(controller: page-owned controller). No DraggableScrollableSheet anywhere.
  - Chart expand: a small ⤢ `IconButton` overlaid on the chart (phone mode only) pushes `/planning/dive-planner/chart`.
  - Header: title InkWell (rename) + OC/CCR `PlanChip` toggle (existing) + two new chips: deco summary `PlanChip(label: 'GF', value: '${gfLow}/${gfHigh}')` tapping sets `setupFocusSectionProvider = 'deco'` (and in drawer mode opens the drawer; on phone switches to the Setup tab), environment chip `PlanChip(label: units.formatAltitude(...))` -> focus 'environment'. Header chips hidden below 560px width (phone keeps the bar clean).
  - `onIssuesTap`: three-pane/drawer -> scroll the results controller to max (existing `_scrollWideToIssues`); phone -> set `plannerPhoneTabProvider = 3`.
- `PlanChartFullscreenPage`: Scaffold with close button, body = `Padding(8, PlanProfileChart())`. Route: child of `dive-planner`, `path: 'chart'`, name `planChart`, standard page.

- [ ] **Step 1: Migrate the test file first (failing tests define the new layout)**

Rewrite `test/features/planner/plan_canvas_page_test.dart`. Keep the existing harness/`setSize`/`seed` helpers verbatim, migrate the cases:

```dart
// Case 1 (phone structure):
testWidgets('phone layout shows chart, chips, tab deck, no sheet', (
  tester,
) async {
  await setSize(tester, const Size(420, 900));
  await tester.pumpWidget(harness());
  seed(tester);
  await tester.pumpAndSettle();

  expect(find.byType(PlanProfileChart), findsOneWidget);
  expect(find.byType(PlanStatusChips), findsOneWidget);
  expect(find.byType(SegmentList), findsOneWidget); // Plan tab is default
  expect(find.byType(DraggableScrollableSheet), findsNothing);
});

// New case (tab switching):
testWidgets('phone tabs switch between plan, tanks, setup, results', (
  tester,
) async {
  await setSize(tester, const Size(420, 900));
  await tester.pumpWidget(harness());
  seed(tester);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Tanks'));
  await tester.pumpAndSettle();
  expect(find.byType(PlanTankList), findsOneWidget);

  await tester.tap(find.text('Setup'));
  await tester.pumpAndSettle();
  expect(find.byType(PlanSetupAccordion), findsOneWidget);

  await tester.tap(find.text('Results'));
  await tester.pumpAndSettle();
  expect(find.byType(PlanResultsPane), findsOneWidget);
});

// Case 2 (wide structure) becomes:
testWidgets('wide layout shows three panes and no draggable sheet', (
  tester,
) async {
  await setSize(tester, const Size(1400, 900));
  await tester.pumpWidget(harness());
  seed(tester);
  await tester.pumpAndSettle();

  expect(find.byType(PlanEditorPane), findsOneWidget);
  expect(find.byType(PlanResultsPane), findsOneWidget);
  expect(find.byType(PlanProfileChart), findsOneWidget);
  expect(find.byType(DraggableScrollableSheet), findsNothing);
});

// New case (pane collapse):
testWidgets('editor pane collapses and expands via the chevron', (
  tester,
) async {
  await setSize(tester, const Size(1400, 900));
  await tester.pumpWidget(harness());
  seed(tester);
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Collapse panel').first);
  await tester.pumpAndSettle();
  expect(find.byType(PlanEditorPane), findsNothing);

  await tester.tap(find.byTooltip('Expand panel').first);
  await tester.pumpAndSettle();
  expect(find.byType(PlanEditorPane), findsOneWidget);
});

// New case (middle mode):
testWidgets('middle width shows chart and results with editor drawer', (
  tester,
) async {
  await setSize(tester, const Size(1000, 800));
  await tester.pumpWidget(harness());
  seed(tester);
  await tester.pumpAndSettle();

  expect(find.byType(PlanResultsPane), findsOneWidget);
  expect(find.byType(PlanEditorPane), findsNothing);
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  expect(find.byType(PlanEditorPane), findsOneWidget);
});

// Cases 3, 4, 5, 7, 8, 9 (save/quick-plan/saved/reset/convert/rename at
// 420x900): keep VERBATIM - they exercise the AppBar and menu, which are
// unchanged apart from added chips.

// Case 6 (settings menu) becomes:
testWidgets('settings menu focuses the setup tab on phone', (tester) async {
  await setSize(tester, const Size(420, 900));
  await tester.pumpWidget(harness());
  seed(tester);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Plan Settings'));
  await tester.pumpAndSettle();
  expect(find.byType(PlanSetupAccordion), findsOneWidget);
});

// Case 10 (wide issues chip): keep, but the assertion target is unchanged
// behavior (tapping the issues chip scrolls the results pane) - keep verbatim.

// New case (header chip deep link, wide):
testWidgets('GF header chip expands the deco section', (tester) async {
  await setSize(tester, const Size(1400, 900));
  await tester.pumpWidget(harness());
  seed(tester);
  await tester.pumpAndSettle();
  await tester.tap(find.text('30/70'));
  await tester.pumpAndSettle();
  expect(find.byType(PlanDecoSection), findsOneWidget);
});
```

Update imports: drop `plan_settings_panel.dart`, add `plan_editor_pane.dart`, `plan_results_pane.dart`, `plan_setup_accordion.dart`, `plan_deco_section.dart`, `plan_tank_list.dart`, `segment_list.dart`, `plan_profile_chart.dart`, `plan_status_chips.dart` as needed by the finders above.

- [ ] **Step 2: Run to verify the new expectations fail**

Run: `flutter test test/features/planner/plan_canvas_page_test.dart`
Expected: FAIL (new panes/tabs do not exist in the page yet).

- [ ] **Step 3: Implement the fullscreen chart page and route**

`plan_chart_fullscreen_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';

/// Distraction-free chart view for phones (and anyone who wants it):
/// pushed from the chart's expand button.
class PlanChartFullscreenPage extends StatelessWidget {
  const PlanChartFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Padding(
        padding: EdgeInsets.all(8),
        child: PlanProfileChart(),
      ),
    );
  }
}
```

Router: inside the `dive-planner` route's `routes: [...]`, next to `compare`, add (import the page at the top of `app_router.dart`):

```dart
GoRoute(
  path: 'chart',
  name: 'planChart',
  builder: (context, state) => const PlanChartFullscreenPage(),
),
```

Place it BEFORE the `:planId` route so the literal segment wins over the parameter.

- [ ] **Step 4: Rebuild the page body and header**

In `plan_canvas_page.dart`:

1. Replace imports of `plan_settings_panel.dart`, `plan_tank_list.dart`, `segment_list.dart`, `plan_gear_weights_section.dart`, `ccr_settings_section.dart`, `contingency_settings_section.dart` with the pane imports (`plan_editor_pane.dart`, `plan_results_pane.dart`, `plan_setup_accordion.dart`) plus `planner_layout_providers.dart`. Keep `simple_plan_dialog.dart`, `plan_status_chips.dart`, `contingency_chips.dart`, results/saved/follow sheets, chart import.
2. Delete the `_sheetController` field (and its dispose call); keep `_wideResultsController` (now used by `PlanResultsPane` in all non-phone modes and the phone Results tab).
3. Replace `body: isWide ? _buildWide() : _buildPhone()` and both builders with:

```dart
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width >= 1160) return _buildThreePane();
          if (width >= 760) return _buildDrawerMode();
          return _buildPhone(constraints);
        },
      ),
```

The page needs a `GlobalKey<ScaffoldState>` field `_scaffoldKey` on the State for the drawer mode; attach it to the page's Scaffold and set `drawer: width < 1160 && width >= 760 ? const Drawer(child: PlanEditorPane()) : null`. Since `Scaffold` sits above the LayoutBuilder, compute the mode from `MediaQuery.sizeOf(context).width` minus nothing - NO: the body LayoutBuilder is authoritative for panes, but the drawer must live on the Scaffold. Resolve pragmatically: give the Scaffold `drawer: const Drawer(child: PlanEditorPane())` unconditionally and only render the drawer-opening `IconButton` in drawer mode; the drawer being technically available in other modes is harmless (nothing opens it).

```dart
  Widget _buildThreePane() {
    final editorCollapsed = ref.watch(editorPaneCollapsedProvider);
    final resultsCollapsed = ref.watch(resultsPaneCollapsedProvider);
    return Row(
      children: [
        if (!editorCollapsed) ...[
          const SizedBox(width: 300, child: PlanEditorPane()),
          const VerticalDivider(width: 1),
        ],
        Expanded(child: _chartColumn(showPaneToggles: true)),
        if (!resultsCollapsed) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 320,
            child: PlanResultsPane(controller: _wideResultsController),
          ),
        ],
      ],
    );
  }

  Widget _buildDrawerMode() {
    return Row(
      children: [
        Expanded(child: _chartColumn(showPaneToggles: false)),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 320,
          child: PlanResultsPane(controller: _wideResultsController),
        ),
      ],
    );
  }

  Widget _chartColumn({required bool showPaneToggles}) {
    final editorCollapsed = ref.watch(editorPaneCollapsedProvider);
    final resultsCollapsed = ref.watch(resultsPaneCollapsedProvider);
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: PlanProfileChart(),
                ),
              ),
              if (showPaneToggles) ...[
                Positioned(
                  left: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: editorCollapsed
                        ? context.l10n.plannerCanvas_pane_expand
                        : context.l10n.plannerCanvas_pane_collapse,
                    icon: Icon(
                      editorCollapsed
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                    ),
                    onPressed: () => ref
                        .read(editorPaneCollapsedProvider.notifier)
                        .update((v) => !v),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: resultsCollapsed
                        ? context.l10n.plannerCanvas_pane_expand
                        : context.l10n.plannerCanvas_pane_collapse,
                    icon: Icon(
                      resultsCollapsed
                          ? Icons.chevron_left
                          : Icons.chevron_right,
                    ),
                    onPressed: () => ref
                        .read(resultsPaneCollapsedProvider.notifier)
                        .update((v) => !v),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PlanStatusChips(onIssuesTap: _scrollWideToIssues),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: ContingencyChips(),
        ),
      ],
    );
  }

  Widget _buildPhone(BoxConstraints constraints) {
    final tab = ref.watch(plannerPhoneTabProvider);
    final tabs = [
      context.l10n.divePlanner_tab_plan,
      context.l10n.divePlanner_label_tanks,
      context.l10n.plannerCanvas_tab_setup,
      context.l10n.divePlanner_tab_results,
    ];
    return Column(
      children: [
        SizedBox(
          height: constraints.maxHeight * 0.40,
          child: Stack(
            children: [
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: PlanProfileChart(),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.open_in_full, size: 18),
                  onPressed: () =>
                      context.go('/planning/dive-planner/chart'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: PlanStatusChips(
            onIssuesTap: () =>
                ref.read(plannerPhoneTabProvider.notifier).state = 3,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: ContingencyChips(),
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
            onSelectionChanged: (selection) => ref
                .read(plannerPhoneTabProvider.notifier)
                .state = selection.first,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _phoneTabBody(tab)),
      ],
    );
  }

  Widget _phoneTabBody(int tab) {
    switch (tab) {
      case 0:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: const [SegmentList()],
        );
      case 1:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: const [PlanTankList()],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: const [PlanSetupAccordion()],
        );
      case 3:
      default:
        return PlanResultsPane(controller: _wideResultsController);
    }
  }
```

(Phone tab bodies still need the `SegmentList`/`PlanTankList` imports - keep those two imports after all.)

4. Header: in the AppBar title Row, after the OC/CCR PlanChip add (watch `planState` is already available):

```dart
            const SizedBox(width: 6),
            if (MediaQuery.sizeOf(context).width >= 560) ...[
              PlanChip(
                label: 'GF',
                value: '${planState.gfLow}/${planState.gfHigh}',
                onTap: () => _focusSetup('deco'),
              ),
              const SizedBox(width: 6),
              PlanChip(
                label: UnitFormatter(
                  ref.watch(settingsProvider),
                ).formatAltitude(planState.altitude ?? 0),
                onTap: () => _focusSetup('environment'),
              ),
            ],
```

with the helper:

```dart
  void _focusSetup(String section) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      ref.read(plannerPhoneTabProvider.notifier).state = 2;
    } else if (width < 1160) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      ref.read(editorPaneCollapsedProvider.notifier).state = false;
    }
    ref.read(setupFocusSectionProvider.notifier).state = section;
  }
```

Check `UnitFormatter` for the altitude formatting method name (`formatAltitude` exists per the settings-panel code using `convertAltitude`/`altitudeSymbol`; if `formatAltitude` does not exist, use `'${units.convertAltitude(planState.altitude ?? 0).toStringAsFixed(0)} ${units.altitudeSymbol}'`).

5. The `'settings'` menu item handler `_showSettingsSheet` is replaced: `case 'settings': _focusSetup('deco');` and delete `_showSettingsSheet`. The drawer-mode AppBar gets `leading` only when in drawer mode - simplest: add to the Scaffold `drawer:` as decided above and in the AppBar add:

```dart
        leading: Builder(
          builder: (context) {
            final width = MediaQuery.sizeOf(context).width;
            if (width >= 760 && width < 1160) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            }
            return const BackButton();
          },
        ),
```

(The page previously relied on the router's implicit back button; `BackButton()` preserves it.)

6. Delete `plan_settings_panel.dart` and its test file; delete `planResultsSheetSectionProvider` from `plan_canvas_providers.dart`:

```bash
git rm lib/features/dive_planner/presentation/widgets/plan_settings_panel.dart test/features/dive_planner/presentation/widgets/plan_settings_panel_test.dart
```

- [ ] **Step 5: Run the migrated tests**

Run: `flutter test test/features/planner/ test/features/dive_planner/ && flutter analyze`
Expected: all planner tests PASS including the migrated page tests and `ccr_ui_test.dart` (the OC/CCR badge test is unaffected: the chip still renders in the AppBar at 420x900; header GF/environment chips are hidden below 560px so they cannot shift it). Analyzer clean.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(planner): Mission Control three-pane layout, phone tab deck, header chips"
```

---

### Task 7: Phase gate - full sweep and live verification

**Files:** none; verification only.

- [ ] **Step 1: Static + targeted suites**

```bash
dart format .
flutter analyze
flutter test test/features/planner/ test/features/dive_planner/ test/features/planning/ test/l10n/
```
Expected: no format changes, analyzer clean, all suites PASS (including phase-1 chart goldens - the chart widget itself is untouched).

- [ ] **Step 2: Live verification on macOS**

Check no other `flutter run -d macos` session is active, then `flutter run -d macos`. Verify:
- Planning hub opens full-width on desktop; opening the Dive Planner shows the 52px rail (tooltips work, back returns to hub) and the planner fills the rest of the window.
- Three panes at full-screen width; chevrons collapse/expand editor and results panes; chart grows accordingly.
- Shrink to ~1000pt: editor pane becomes a drawer behind the menu button; results pane stays.
- Shrink below ~760pt: Tab Deck appears (Plan / Tanks / Setup / Results); no draggable sheet; expand button opens the full-screen chart with working scrub; back returns.
- Header chips: GF chip opens/reveals the Deco section (all three modes); environment chip reveals Environment.
- Dark + light theme, one non-default preset.
- Quick Plan 40m/30min: stop tags, ceiling band, contingency ghost chips still work end to end.

- [ ] **Step 3: Confirm clean tree**

```bash
git status
```
Expected: clean. Do not push until asked.

---

## Self-Review (completed during planning)

- Spec 6.2 coverage: icon rail + full-width hub (Task 2), three panes with exact widths 300/320 and collapse-with-memory (Tasks 1, 5, 6), constraint-based breakpoints 1160/760 measured by the page's own LayoutBuilder (Task 6), drawer middle mode (Task 6), phone Chart + Tab Deck with sheet deletion and full-screen chart route (Task 6), header summary chips deep-linking into Setup (Tasks 1, 4, 6), PlanSettingsPanel decomposed into accordion sections designed for the parity control set (Tasks 3, 4), engine state untouched (no provider changes beyond deleting a dead one), restyle-not-rewrite of SegmentList/PlanTankList/results (re-hosted, not modified).
- Deviations from spec, intentional: spec's stat-tile list named OTU and gas density; `PlanOutcome` exposes `otuTotal` but density only via issues, and four tiles fit the 320px pane cleanly - Runtime/TTS-or-NDL/CNS/Issues ship now, OTU/density tiles land with phase 4's engine work when the results pane grows. Recorded here so the spec drift is deliberate.
- Placeholder scan: clean; two resolve-at-implementation notes (exact l10n English values for section titles, `formatAltitude` existence) give the exact fallback code inline.
- Type consistency: `PlanEditorPane()`/`PlanResultsPane(controller:)`/`PlanSetupAccordion()`/`PlanStatTile(label:, value:, emphasisColor:)`/`setupFocusSectionProvider` names match across Tasks 1, 4, 5, 6; section keys 'deco'/'gas'/'environment'/'ccr'/'contingencies'/'gear' consistent between Tasks 1, 4, 6.
