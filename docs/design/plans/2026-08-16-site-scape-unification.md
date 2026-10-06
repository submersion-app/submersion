# Site Scape Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One morphable map/3D pane (`SiteScapeView`) hosted by the sites map surfaces and site detail, replacing the standalone `SiteSeascapePage`, with Map + 3D pills on the dive detail header card and a `?site=<id>&scape=3d` deep link.

**Architecture:** `SiteTerrainPane` is the extraction of `SiteSeascapePage`'s body into a host-agnostic widget (controls move from the AppBar into the pane). `SiteScapeView` is a mode-CONTROLLED wrapper: the host owns the ephemeral `SiteScapeMode` in its own state, the view renders the docked 2D/3D toggle, keeps the 2D stack alive under `Offstage` (so the map camera survives mode flips), enforces the 3D availability rules, and fits the 2D camera to the grid on 3D-to-2D transitions. Four hosts: `SiteMapContent` (master-detail map pane), standalone `SiteMapPage` (which also gains the depth-overlay layer it was missing), and the site detail embedded card + fullscreen variant.

**Tech Stack:** Flutter, flutter_map, Riverpod (project hub `core/providers/provider.dart`), go_router.

**Spec:** `docs/superpowers/specs/2026-08-15-site-scape-unification-design.md` (PR 3 section). Planning-time corrections to the spec are folded into Task 9.

## Global Constraints

- Never use an em-dash (U+2014) anywhere: code, comments, docs, commits, PR body.
- No Co-Authored-By in commits; no attribution line or session URL in the PR body.
- New l10n keys go into ALL 11 arb files (en, ar, de, es, fr, he, hu, it, nl, pt, zh) with `"@key": {}` metadata lines, then `flutter gen-l10n` from the project root. The generated `app_localizations*.dart` files under `lib/l10n/arb/` ARE committed.
- `dart format .` before every commit; `flutter analyze` must be clean (infos are CI-fatal).
- Never commit `database.g.dart`.
- Riverpod 3: `StateNotifier` and `valueOrNull` come from `package:submersion/core/providers/provider.dart`, NOT raw flutter_riverpod.
- Map-hosting widget tests use bounded pumps (`await tester.pump(); await tester.pump(const Duration(seconds: 1));`), never `pumpAndSettle`.
- Run all commands from the new worktree; capture test exit codes directly (`flutter test ... > log 2>&1; code=$?`), never through a pipe.
- The dives-surface `?site=` query param on `/dives` (used by `dive_detail_page.dart` embedded navigation) is UNRELATED to the new `/sites/map?site=` param; do not touch it.

## Key facts discovered at planning time (deviations from the spec)

1. There are TWO near-duplicate sites-map surfaces: `SiteMapContent` (embeddable pane used by `/sites?view=map` master-detail and table mode; has the depth-overlay layer and the info-card terrain button) and the standalone `SiteMapPage` at `/sites/map` (has the `DepthOverlayToggleButton` but NEVER renders `BathymetryDepthOverlayLayer`, a latent PR-1 gap). Both become hosts; the gap gets fixed here.
2. The spec's "the `?site=` mechanism already exists" is wrong for the sites surface: master-detail uses `?selected=<id>&view=map` via `MasterDetailScaffold`. The deep link lands on the standalone route `/sites/map?site=<id>&scape=3d` instead; master-detail keeps `?selected=`.
3. Chart mode stays an internal toggle of `SiteTerrainPane` (as shipped in slice 1), not a third `SiteScapeView` mode.
4. `SiteSeascapePage` has no go_router route; every entry is a raw `Navigator.push` (3 call sites: `site_map_content.dart:486`, `site_detail_page.dart:288`, `site_detail_page.dart:377`).
5. `bathymetryGridBounds(BathymetryGrid)` already exists in `lib/features/bathymetry/presentation/bathymetry_overlay_image.dart:30` and returns the flutter_map `LatLngBounds` the camera fit needs.
6. The dive detail "View Site" pill is DECORATIVE (no own onTap); the whole card body is one InkWell. The tap tests (`dive_detail_view_site_tap_test.dart`) find InkWell ANCESTORS of `DiveLocationsMap`, so pills added as Stack siblings with their own InkWells do not break them. `dive_header_gps_test.dart:132` asserts `find.text('View Site')` and MUST be updated.

---

### Task 1: Stacked worktree setup

**Files:** none (environment only).

- [ ] **Step 1: Create the stacked worktree**

From `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-scape-imagery`:

```bash
git worktree add /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-scape-unification -b worktree-site-scape-unification worktree-site-scape-imagery
```

- [ ] **Step 2: Initialize the worktree**

From `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-scape-unification` (ALL later tasks run here; print `pwd` in the same compound command as any build/test to catch silent cwd resets):

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Sanity check**

Run: `pwd && flutter test test/features/dive_3d/presentation/site_seascape_page_test.dart > /tmp/wt_sanity.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0.

---

### Task 2: `SiteTerrainPane` extraction

**Files:**
- Create: `lib/features/site_scape/presentation/site_terrain_pane.dart`
- Modify: `lib/features/dive_3d/presentation/pages/site_seascape_page.dart` (becomes a thin wrapper; deleted in Task 8)
- Create: `test/features/site_scape/presentation/site_terrain_pane_test.dart`
- Delete: `test/features/dive_3d/presentation/site_seascape_page_test.dart`

**Interfaces:**
- Consumes: `siteSeascapeProvider` and the whole current body of `SiteSeascapePage` (`lib/features/dive_3d/presentation/pages/site_seascape_page.dart`).
- Produces: `class SiteTerrainPane extends ConsumerStatefulWidget { final String siteId; const SiteTerrainPane({super.key, required this.siteId}); }`, a Scaffold-free pane that renders every terminal state of the site seascape and carries its own tune + chart controls. Tasks 3-6 embed it.

- [ ] **Step 1: Create the pane by moving the page body**

Create `lib/features/site_scape/presentation/site_terrain_pane.dart`. Copy the ENTIRE contents of `lib/features/dive_3d/presentation/pages/site_seascape_page.dart` into it, then apply these deltas:

1. Rename `SiteSeascapePage` to `SiteTerrainPane`, `_SiteSeascapePageState` to `_SiteTerrainPaneState`. Class doc becomes:

```dart
/// Host-agnostic site seascape pane: real bathymetry around the site pin
/// with the site's dives draped in place, plus its own appearance and
/// chart-mode controls (no Scaffold or AppBar; hosts embed it anywhere).
/// Every terminal state renders something, never a permanent spinner.
```

2. Delete the `Scaffold`/`AppBar` wrapper: `build` returns `stateAsync.when(...)` directly (the `loading`/`error`/`data` cases keep their exact current bodies).

3. The two former AppBar actions move INTO the ready-state `Stack`, inserted immediately after the `_hoverTooltip(grid)` entry (so they paint above everything):

```dart
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: const ValueKey(
                                    'seascapeAppearanceButton',
                                  ),
                                  icon: const Icon(Icons.tune, size: 20),
                                  tooltip:
                                      context.l10n.dive3d_seascape_appearance,
                                  onPressed: () =>
                                      showTerrainAppearanceSheet(context),
                                ),
                                IconButton(
                                  key: const ValueKey('seascapeChartToggle'),
                                  icon: Icon(
                                    _chartMode
                                        ? Icons.view_in_ar
                                        : Icons.map_outlined,
                                    size: 20,
                                  ),
                                  tooltip: _chartMode
                                      ? context.l10n.dive3d_seascape_orbitView
                                      : context.l10n.dive3d_seascape_chartView,
                                  onPressed: () => setState(
                                    () => _chartMode = !_chartMode,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
```

4. Reposition the chrome so nothing collides with the new controls card (top-right) or the host's mode toggle (top-left, Task 3): the `_sourceChip` `Positioned` changes from `top: 8, left: 8, right: 8` to `top: 56, left: 8, right: 8`; the legend `Positioned` changes from `top: 40` to `top: 96`; the attribution-chip `Positioned` stays `bottom: 8, right: 8`.

5. Imports: the pane needs everything the page imported. Keep them all.

- [ ] **Step 2: Shrink the page to a thin wrapper**

Replace the whole of `lib/features/dive_3d/presentation/pages/site_seascape_page.dart` with:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Thin fullscreen wrapper around [SiteTerrainPane], kept only until the
/// map hosts adopt the pane; deleted at the end of the unification work.
class SiteSeascapePage extends StatelessWidget {
  final String siteId;

  const SiteSeascapePage({super.key, required this.siteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dive3d_seascape_siteTitle)),
      body: SiteTerrainPane(siteId: siteId),
    );
  }
}
```

- [ ] **Step 3: Move the test file**

Create `test/features/site_scape/presentation/site_terrain_pane_test.dart` as a copy of `test/features/dive_3d/presentation/site_seascape_page_test.dart` with these deltas, then `git rm` the old file:

1. Replace the `site_seascape_page.dart` import with `package:submersion/features/site_scape/presentation/site_terrain_pane.dart`.
2. In the `page(...)` helper, `home:` becomes `Scaffold(body: SiteTerrainPane(siteId: 'site-1'))` (the pane needs a Material ancestor). Because the pane no longer owns an AppBar, drop `const` from the `MaterialApp` if the analyzer demands it.
3. All finders keep working: `seascapeAppearanceButton`, `seascapeChartToggle`, `seascapeDepthLegend`, chip texts, and the viewport assertions are unchanged because the keys moved with the controls.

- [ ] **Step 4: Run, format, commit**

Run: `flutter test test/features/site_scape/ test/features/dive_3d/ > /tmp/t2.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0. Then:

```bash
dart format .
git add lib/features/site_scape/ lib/features/dive_3d/presentation/pages/site_seascape_page.dart test/features/site_scape/ test/features/dive_3d/presentation/site_seascape_page_test.dart
git commit -m "refactor(seascape): extract SiteTerrainPane from the site seascape page"
```

---

### Task 3: `SiteScapeView` mode-controlled wrapper + l10n

**Files:**
- Create: `lib/features/site_scape/presentation/site_scape_view.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/site_scape/presentation/site_scape_view_test.dart` (new)

**Interfaces:**
- Consumes: `SiteTerrainPane` (Task 2), `bathymetryGridProvider` + `BathymetryRepository.quantize`, `bathymetryGridBounds` from `bathymetry_overlay_image.dart`.
- Produces:

```dart
enum SiteScapeMode { map2d, terrain3d }

class SiteScapeView extends ConsumerStatefulWidget {
  final SiteScapeMode mode;
  final ValueChanged<SiteScapeMode> onModeChanged;
  final WidgetBuilder mapBuilder;        // the host's ENTIRE 2D stack
  final String? selectedSiteId;
  final GeoPoint? selectedSiteLocation;
  final MapController? mapController;    // for the 3D-to-2D camera fit
}
```

  Hosts own the ephemeral mode in their own State (spec: "mode is ephemeral"); the view renders the docked toggle (keys `siteScape2dButton` / `siteScape3dButton`), keeps the 2D stack alive under `Offstage`, disables 3D without a selection or with a known-absent grid, requests `map2d` when the selection disappears, and fits the 2D camera to the grid bounds on a 3D-to-2D transition. Tasks 4-6 consume this exact contract.

- [ ] **Step 1: Add the l10n keys**

In all 11 arb files, insert next to the `dive3d_seascape_*` block (anchor: immediately before `"dive3d_seascape_appearance_rampRange"`), matching the `"@key": {}` metadata style:

| locale | `siteScape_mode2d` | `siteScape_mode3d` |
|---|---|---|
| en | Map | 3D |
| de | Karte | 3D |
| es | Mapa | 3D |
| fr | Carte | 3D |
| it | Mappa | 3D |
| nl | Kaart | 3D |
| pt | Mapa | 3D |
| hu | Térkép | 3D |
| ar | خريطة | 3D |
| he | מפה | 3D |
| zh | 地图 | 3D |

Then run `flutter gen-l10n` from the project root.

- [ ] **Step 2: Write the failing test**

Create `test/features/site_scape/presentation/site_scape_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_scape_view.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.initial = const AppSettings()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _loc = GeoPoint(12.15, -68.3);

class _Host extends StatefulWidget {
  final String? selectedSiteId;
  final GeoPoint? selectedSiteLocation;
  final SiteScapeMode initialMode;
  const _Host({
    this.selectedSiteId,
    this.selectedSiteLocation,
    this.initialMode = SiteScapeMode.map2d,
  });

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late SiteScapeMode mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    return SiteScapeView(
      mode: mode,
      onModeChanged: (m) => setState(() => mode = m),
      selectedSiteId: widget.selectedSiteId,
      selectedSiteLocation: widget.selectedSiteLocation,
      mapController: null,
      mapBuilder: (_) => const ColoredBox(
        color: Colors.green,
        child: Text('MAP_STACK'),
      ),
    );
  }
}

Widget _app(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      // The pane resolves via its own provider; park it on no-data so the
      // pane renders a terminal message without touching the network.
      siteSeascapeProvider.overrideWith(
        (ref, id) async => const SiteSeascapeNoData(),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('toggle swaps to the terrain pane and back', (tester) async {
    await tester.pumpWidget(
      _app(
        const _Host(selectedSiteId: 'site-1', selectedSiteLocation: _loc),
        overrides: [
          bathymetryGridProvider.overrideWith((ref, key) async => null),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('MAP_STACK'), findsOneWidget);
    expect(find.byType(SiteTerrainPane), findsNothing);
    // Known-absent grid: the 3D button is disabled.
    final disabled = tester.widget<IconButton>(
      find.byKey(const ValueKey('siteScape3dButton')),
    );
    expect(disabled.onPressed, isNull);
  });

  testWidgets('with a grid the toggle enters 3D and Offstage hides the map', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const _Host(selectedSiteId: 'site-1', selectedSiteLocation: _loc),
        overrides: [
          // A never-completing fetch: the grid stays LOADING, so the 3D
          // button stays enabled (only a known-absent grid disables it).
          bathymetryGridProvider.overrideWith(
            (ref, key) => Completer<BathymetryGrid?>().future,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('siteScape3dButton')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SiteTerrainPane), findsOneWidget);
    final offstage = tester.widget<Offstage>(
      find.ancestor(
        of: find.text('MAP_STACK'),
        matching: find.byType(Offstage),
      ),
    );
    expect(offstage.offstage, isTrue);
    await tester.tap(find.byKey(const ValueKey('siteScape2dButton')));
    await tester.pump();
    expect(find.byType(SiteTerrainPane), findsNothing);
  });

  testWidgets('no selection disables 3D', (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    await tester.pump();
    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('siteScape3dButton')),
    );
    expect(button.onPressed, isNull);
  });
}
```

Add `import 'dart:async';` and `import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';` at the top of the test file for the `Completer<BathymetryGrid?>` override; a real fetch in tests is forbidden.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/site_scape/presentation/site_scape_view_test.dart`
Expected: compile FAIL (`SiteScapeView` undefined).

- [ ] **Step 4: Implement `SiteScapeView`**

Create `lib/features/site_scape/presentation/site_scape_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_overlay_image.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How the site scape pane is showing its region: the host's 2D map, or
/// the 3D terrain of the selected site.
enum SiteScapeMode { map2d, terrain3d }

/// Mode-controlled morphable pane: the HOST owns the ephemeral
/// [SiteScapeMode] (each entry starts where the caller asked) and this
/// view renders the docked toggle, the host's 2D stack, and the terrain
/// pane. The 2D stack stays alive under [Offstage] so the map camera and
/// tiles survive mode flips. 3D needs a selected site and is disabled
/// when the site's grid is known to be absent; returning to 2D fits the
/// map camera to the grid bounds (camera continuity).
class SiteScapeView extends ConsumerStatefulWidget {
  final SiteScapeMode mode;
  final ValueChanged<SiteScapeMode> onModeChanged;
  final WidgetBuilder mapBuilder;
  final String? selectedSiteId;
  final GeoPoint? selectedSiteLocation;
  final MapController? mapController;

  const SiteScapeView({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.mapBuilder,
    required this.selectedSiteId,
    required this.selectedSiteLocation,
    this.mapController,
  });

  @override
  ConsumerState<SiteScapeView> createState() => _SiteScapeViewState();
}

class _SiteScapeViewState extends ConsumerState<SiteScapeView> {
  @override
  void didUpdateWidget(covariant SiteScapeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Selection VANISHED while in 3D: fall back to the map. Transition
    // only (old non-null, new null): a deep link that starts in 3D before
    // the seeded selection lands must not be knocked back to 2D. Deferred
    // a frame because the host may be mid-build.
    if (widget.mode == SiteScapeMode.terrain3d &&
        oldWidget.selectedSiteId != null &&
        widget.selectedSiteId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onModeChanged(SiteScapeMode.map2d);
      });
    }
    // 3D to 2D: fit the (still-alive, Offstage) map to the terrain box.
    if (oldWidget.mode == SiteScapeMode.terrain3d &&
        widget.mode == SiteScapeMode.map2d) {
      _fitMapToGrid();
    }
  }

  void _fitMapToGrid() {
    final controller = widget.mapController;
    final location = widget.selectedSiteLocation;
    if (controller == null || location == null) return;
    final grid = ref
        .read(bathymetryGridProvider(BathymetryRepository.quantize(location)))
        .valueOrNull;
    if (grid == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        controller.fitCamera(
          CameraFit.bounds(
            bounds: bathymetryGridBounds(grid),
            padding: const EdgeInsets.all(40),
          ),
        );
      } catch (_) {
        // Camera continuity is cosmetic: a not-yet-attached controller
        // (host swapped its map out) must never crash the mode switch.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.selectedSiteLocation;
    final gridAsync = location == null
        ? null
        : ref.watch(
            bathymetryGridProvider(BathymetryRepository.quantize(location)),
          );
    // Disabled only when the grid is KNOWN absent; while loading the
    // toggle stays live and the pane itself shows the no-data terminal
    // state if the fetch comes back empty.
    final gridKnownAbsent =
        gridAsync != null && gridAsync.hasValue && gridAsync.value == null;
    final canEnter3d = widget.selectedSiteId != null && !gridKnownAbsent;
    final show3d =
        widget.mode == SiteScapeMode.terrain3d && widget.selectedSiteId != null;

    return Stack(
      children: [
        Offstage(offstage: show3d, child: widget.mapBuilder(context)),
        if (show3d)
          Positioned.fill(
            child: SiteTerrainPane(siteId: widget.selectedSiteId!),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('siteScape2dButton'),
                    icon: const Icon(Icons.map_outlined, size: 20),
                    isSelected: widget.mode == SiteScapeMode.map2d,
                    tooltip: context.l10n.siteScape_mode2d,
                    onPressed: () =>
                        widget.onModeChanged(SiteScapeMode.map2d),
                  ),
                  IconButton(
                    key: const ValueKey('siteScape3dButton'),
                    icon: const Icon(Icons.terrain, size: 20),
                    isSelected: widget.mode == SiteScapeMode.terrain3d,
                    tooltip: canEnter3d
                        ? context.l10n.siteScape_mode3d
                        : context.l10n.dive3d_seascape_noData,
                    onPressed: canEnter3d
                        ? () => widget.onModeChanged(SiteScapeMode.terrain3d)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run, format, commit**

Run: `flutter test test/features/site_scape/ > /tmp/t3.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0. Then:

```bash
dart format .
git add lib/features/site_scape/ test/features/site_scape/ lib/l10n/arb/
git commit -m "feat(sitescape): mode-controlled SiteScapeView wrapper"
```

---

### Task 4: Host `SiteMapContent`

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
- Test: `test/features/dive_sites/presentation/widgets/site_map_content_test.dart` (extend)

**Interfaces:**
- Consumes: `SiteScapeView`/`SiteScapeMode` (Task 3).
- Produces: the master-detail map pane morphs in place; the info card's terrain button flips to 3D instead of pushing `SiteSeascapePage`.

- [ ] **Step 1: Write the failing test**

Append to `site_map_content_test.dart` (reuse its existing `_pump` helper and fixtures; the helper already overrides `bathymetryGridProvider`, keep whatever grid it supplies):

```dart
  testWidgets('info card terrain button morphs the pane to 3D in place', (
    tester,
  ) async {
    await _pump(tester, selectedId: 'site-1');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SiteTerrainPane), findsNothing);
    await tester.tap(find.byIcon(Icons.terrain).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // No route push: the pane replaced the map inside the same widget.
    expect(find.byType(SiteTerrainPane), findsOneWidget);
    expect(find.byKey(const ValueKey('siteScape2dButton')), findsOneWidget);
    // Back via the docked toggle.
    await tester.tap(find.byKey(const ValueKey('siteScape2dButton')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SiteTerrainPane), findsNothing);
  });
```

Add imports for `SiteTerrainPane` and adapt to `_pump`'s real signature (it takes the selected id however the existing tests pass it; mirror the `renders the FlutterMap and info card for a selected site` test's setup). If `_pump` does not override `siteSeascapeProvider`, add an override parking it on `SiteSeascapeNoData` as in Task 3's test.

- [ ] **Step 2: Run to verify failure, then implement**

Run the file (expect the new test FAILS: tapping terrain pushes a route today). Then in `site_map_content.dart`:

1. Imports: REMOVE the `site_seascape_page.dart` import and ADD
   `import 'package:submersion/features/site_scape/presentation/site_scape_view.dart';`
   (the lib file needs only the view; the TEST file additionally imports `site_terrain_pane.dart` for its finder).
2. State field on `_SiteMapContentState`:

```dart
  // Ephemeral morph state: each entry to this widget starts in 2D.
  SiteScapeMode _scapeMode = SiteScapeMode.map2d;
```

3. `_buildMapWithInfoCard` (currently returns a `Stack` at its end): wrap that exact `Stack` as the view's 2D side. Replace `return Stack(children: [...]);` with:

```dart
    return SiteScapeView(
      mode: _scapeMode,
      onModeChanged: (m) => setState(() => _scapeMode = m),
      selectedSiteId: selectedSite?.id,
      selectedSiteLocation: selectedSite?.location,
      mapController: _mapController,
      mapBuilder: (context) => Stack(
        children: [
          // ... the existing Stack children, byte for byte ...
        ],
      ),
    );
```

   The existing children list (`_buildMap(...)`, the controls `Positioned`, the built-in card `Positioned`, the selected-site card `Positioned`) moves inside unchanged. The controls card at `top: 8, right: 8` and the mode toggle at `top: 8, left: 8` do not collide.

4. `_buildMapInfoCard`'s trailing terrain button (currently `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SiteSeascapePage(siteId: site.id)))` around line 484-488): the `onPressed` becomes:

```dart
                onPressed: () =>
                    setState(() => _scapeMode = SiteScapeMode.terrain3d),
```

   Icon, tooltip (`dive3d_seascape_siteTitle`), and the `site.hasCoordinates` gate stay.

- [ ] **Step 3: Run, format, commit**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_map_content_test.dart test/features/dive_sites/presentation/widgets/site_map_content_built_in_test.dart test/features/osm_tile_user_agent_test.dart > /tmp/t4.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0 (the depth-overlay and built-in tests keep passing: in 2D mode the map subtree is identical). Then:

```bash
dart format .
git add lib/features/dive_sites/presentation/widgets/site_map_content.dart test/features/dive_sites/presentation/widgets/site_map_content_test.dart
git commit -m "feat(sitescape): morph the master-detail sites map in place"
```

---

### Task 5: Host `SiteMapPage` + deep link + overlay-layer gap fix

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `sitesMap` route, currently `builder: (context, state) => const SiteMapPage()` around line 424-428)
- Test: `test/features/dive_sites/presentation/pages/site_map_page_test.dart` (extend)

**Interfaces:**
- Consumes: `SiteScapeView` (Task 3), `mapListSelectionProvider('sites')`, `BathymetryDepthOverlayLayer`.
- Produces: `const SiteMapPage({super.key, this.initialSiteId, this.initialScape3d = false})`; route `/sites/map` accepts `?site=<id>&scape=3d`. Task 7's dive pills navigate here.

- [ ] **Step 1: Write the failing tests**

Extend `site_map_page_test.dart` (mirror its existing pump/override setup; add `siteSeascapeProvider` parked on `SiteSeascapeNoData` and a `bathymetryGridProvider` override if missing):

```dart
  testWidgets('deep link seeds the selection and lands in 3D', (tester) async {
    await _pumpPage(
      tester,
      const SiteMapPage(initialSiteId: 'site-1', initialScape3d: true),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SiteTerrainPane), findsOneWidget);
  });

  testWidgets('plain site deep link stays in 2D with the site selected', (
    tester,
  ) async {
    await _pumpPage(tester, const SiteMapPage(initialSiteId: 'site-1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SiteTerrainPane), findsNothing);
    // The info card for the seeded selection is visible.
    expect(find.text('Test Site'), findsWidgets);
  });
```

Adapt `_pumpPage` and the site name to the file's real helper and fixture (the existing test builds one site; use its actual name). The selection provider is process-global state per ProviderScope, so each test gets a fresh scope from the helper.

- [ ] **Step 2: Run to verify failure, then implement**

1. Router (`app_router.dart`):

```dart
              GoRoute(
                path: 'map',
                name: 'sitesMap',
                builder: (context, state) => SiteMapPage(
                  initialSiteId: state.uri.queryParameters['site'],
                  initialScape3d: state.uri.queryParameters['scape'] == '3d',
                ),
              ),
```

2. `SiteMapPage` widget:

```dart
class SiteMapPage extends ConsumerStatefulWidget {
  /// Deep-link seed: preselect this site on entry (`/sites/map?site=<id>`).
  final String? initialSiteId;

  /// Deep-link seed: start morphed to 3D (`&scape=3d`).
  final bool initialScape3d;

  const SiteMapPage({
    super.key,
    this.initialSiteId,
    this.initialScape3d = false,
  });
  ...
}
```

3. State: add fields and `initState`:

```dart
  SiteScapeMode _scapeMode = SiteScapeMode.map2d;
  bool _seedZoomPending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialScape3d) _scapeMode = SiteScapeMode.terrain3d;
    final seed = widget.initialSiteId;
    if (seed != null) {
      _seedZoomPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(mapListSelectionProvider('sites').notifier).select(seed);
      });
    }
  }
```

   (If the state class already has an `initState`, merge these lines into it.)

4. In `build`, after `selectedSite` is computed (around line 67-75): zoom the 2D map to a seeded selection once, when the site data lands:

```dart
    if (_seedZoomPending && selectedSite?.hasCoordinates == true) {
      _seedZoomPending = false;
      final loc = selectedSite!.location!;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _animateToLocation(loc.latitude, loc.longitude),
      );
    }
```

5. `mapPane:` wraps the map in the view. Replace `data: (sitesWithCounts) => _buildMap(context, sitesWithCounts),` with:

```dart
        data: (sitesWithCounts) => SiteScapeView(
          mode: _scapeMode,
          onModeChanged: (m) => setState(() => _scapeMode = m),
          selectedSiteId: selectedSite?.id,
          selectedSiteLocation: selectedSite?.location,
          mapController: _mapController,
          mapBuilder: (context) => _buildMap(context, sitesWithCounts),
        ),
```

6. `infoCard:` hides in 3D (it would overlay the pane's chips):

```dart
      infoCard: _scapeMode == SiteScapeMode.terrain3d
          ? null
          : _selectedBuiltInId != null
          ? _buildBuiltInInfoCard(context)
          : (selectedSite != null
                ? _buildMapInfoCard(context, selectedSite)
                : null),
```

7. `_buildMapInfoCard` gains the terrain trailing button (parity with `SiteMapContent`), inserted into the `MapInfoCard(...)` call:

```dart
      trailing: site.hasCoordinates
          ? IconButton(
              icon: const Icon(Icons.terrain),
              tooltip: context.l10n.dive3d_seascape_siteTitle,
              onPressed: () =>
                  setState(() => _scapeMode = SiteScapeMode.terrain3d),
            )
          : null,
```

8. The PR-1 gap fix in `_buildMap`: after the `TileLayer(...)` child (around line 271-278) insert:

```dart
              BathymetryDepthOverlayLayer(
                location: sitesWithCounts
                    .where((s) => s.site.id == selectionState.selectedId)
                    .firstOrNull
                    ?.site
                    .location,
              ),
```

   with the import `package:submersion/features/bathymetry/presentation/bathymetry_depth_overlay_layer.dart`. Also add the imports for `site_scape_view.dart`. (`collection`'s `firstOrNull` is already in scope project-wide via Dart 3 extensions; if the analyzer disagrees, use the `.isEmpty ? null : .first` form used elsewhere in this file.)

- [ ] **Step 3: Run, format, commit**

Run: `flutter test test/features/dive_sites/presentation/pages/site_map_page_test.dart test/features/dive_sites/presentation/pages/site_map_page_built_in_test.dart > /tmp/t5.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0. Then:

```bash
dart format .
git add lib/features/dive_sites/presentation/pages/site_map_page.dart lib/core/router/app_router.dart test/features/dive_sites/presentation/pages/site_map_page_test.dart
git commit -m "feat(sitescape): morphable standalone sites map with 3D deep link"
```

---

### Task 6: Host site detail (embedded card + fullscreen)

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_test.dart` (extend)

**Interfaces:**
- Consumes: `SiteScapeView` (Task 3).
- Produces: the 200px map card and the fullscreen variant morph; the app-bar and embedded-header terrain buttons open the fullscreen variant already in 3D (no more `SiteSeascapePage` pushes from this file).

- [ ] **Step 1: Write the failing test**

Append to `site_detail_page_test.dart` inside the `SiteDetailPage embedded seascape action` group (reuse the group's pump helper and overrides; add `siteSeascapeProvider` parked on `SiteSeascapeNoData` to the overrides if the helper lacks it):

```dart
    testWidgets('embedded seascape button opens the fullscreen scape in 3D', (
      tester,
    ) async {
      // Same pump as 'embedded header shows the seascape button...'.
      await pumpEmbedded(tester); // adapt to the group's real helper name
      await tester.tap(find.byTooltip('Site Seascape'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SiteTerrainPane), findsOneWidget);
      expect(find.byType(SiteScapeView), findsOneWidget);
    });
```

- [ ] **Step 2: Run to verify failure, then implement**

In `site_detail_page.dart`:

1. Imports: remove `site_seascape_page.dart`; add `site_scape_view.dart` (and `site_terrain_pane.dart` only if the test needs it, which lives on the test side).
2. State field on `_SiteDetailContentState`:

```dart
  SiteScapeMode _previewScapeMode = SiteScapeMode.map2d;
```

3. `_buildMapSection` (line ~508): the returned `Card > SizedBox(height: 200) >` child becomes the view. The existing `Stack` (map + fullscreen button) moves into `mapBuilder` unchanged:

```dart
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: SiteScapeView(
          mode: _previewScapeMode,
          onModeChanged: (m) => setState(() => _previewScapeMode = m),
          selectedSiteId: site.id,
          selectedSiteLocation: site.location,
          mapController: _previewController,
          mapBuilder: (context) => Stack(
            children: [
              // ... the existing Stack children unchanged ...
            ],
          ),
        ),
      ),
    );
```

4. `_showFullscreenMap` gains a named parameter and its pushed page becomes a private stateful widget (mode state cannot live in the builder closure):

```dart
  void _showFullscreenMap(
    BuildContext context,
    WidgetRef ref,
    DiveSite site, {
    bool initialScape3d = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenSiteScapePage(
          site: site,
          controller: _fullController,
          initialScape3d: initialScape3d,
        ),
      ),
    );
  }
```

   New private widget at the bottom of the file. Its `build` returns `Scaffold(appBar: AppBar(title: Text(site.name)), body: SiteScapeView(...))` where `mapBuilder` contains the EXACT current fullscreen map subtree (`TrackpadZoomMap > FlutterMap` with TileLayer, `BathymetryDepthOverlayLayer(location: site.location)`, the scuba marker, `MapAttribution`), lifted verbatim from the current `_showFullscreenMap` body:

```dart
class _FullscreenSiteScapePage extends ConsumerStatefulWidget {
  final DiveSite site;
  final MapController controller;
  final bool initialScape3d;

  const _FullscreenSiteScapePage({
    required this.site,
    required this.controller,
    required this.initialScape3d,
  });

  @override
  ConsumerState<_FullscreenSiteScapePage> createState() =>
      _FullscreenSiteScapePageState();
}

class _FullscreenSiteScapePageState
    extends ConsumerState<_FullscreenSiteScapePage> {
  late SiteScapeMode _mode = widget.initialScape3d
      ? SiteScapeMode.terrain3d
      : SiteScapeMode.map2d;

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: SiteScapeView(
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
        selectedSiteId: site.id,
        selectedSiteLocation: site.location,
        mapController: widget.controller,
        mapBuilder: (context) => TrackpadZoomMap(
          // ... lifted verbatim from today's _showFullscreenMap ...
        ),
      ),
    );
  }
}
```

5. The app-bar terrain action (line ~282-291) and the embedded-header terrain button (line ~371-380): both `onPressed` bodies become

```dart
              onPressed: () =>
                  _showFullscreenMap(context, ref, site, initialScape3d: true),
```

   (in the embedded header the site variable in scope is `site`; keep the existing `site.hasCoordinates` gates and tooltips). Check `ref` is in scope at each call site; both methods already receive `WidgetRef ref` today via their builders, keep whatever access pattern each uses.

- [ ] **Step 3: Run, format, commit**

Run: `flutter test test/features/dive_sites/presentation/pages/site_detail_page_test.dart test/features/dive_sites/presentation/pages/site_detail_navigation_test.dart > /tmp/t6.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0. The existing groups keep passing: the depth-overlay tests still find `OverlayImageLayer` (2D subtree unchanged), the map-section tests still find `FlutterMap` and the `Icons.fullscreen` tap still lands on a `FlutterMap`. Then:

```bash
dart format .
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart test/features/dive_sites/presentation/pages/site_detail_page_test.dart
git commit -m "feat(sitescape): morphable site detail maps, fullscreen opens in 3D"
```

---

### Task 7: Dive detail Map + 3D pills + l10n

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (header card, pill block at ~line 1358-1399)
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/dive_log/presentation/pages/dive_header_gps_test.dart` (update), `test/features/dive_log/presentation/pages/dive_detail_site_pills_test.dart` (new)

**Interfaces:**
- Consumes: the `/sites/map?site=<id>[&scape=3d]` deep link (Task 5).
- Produces: two tappable pills replacing the decorative "View Site" pill. The card-body InkWell and its `?site=` embedded navigation on `/dives` stay EXACTLY as they are; the `diveLog_detail_viewSite` key stays (the card's Semantics label still uses it).

- [ ] **Step 1: Add the l10n keys**

In all 11 arb files, next to `"diveLog_detail_viewSite"` (en anchor at app_en.arb line ~2809), add `diveLog_detail_viewMap` / `diveLog_detail_view3d` with the same values as Task 3's table (Map/Karte/Mapa/Carte/Mappa/Kaart/Mapa/Térkép/خريطة/מפה/地图 and 3D everywhere), each with its `"@key": {}` line. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Update `dive_header_gps_test.dart` line ~132: replace

```dart
    expect(find.text('View Site'), findsWidgets);
```

with

```dart
    expect(find.text('Map'), findsWidgets);
    expect(find.text('3D'), findsWidgets);
```

Create `test/features/dive_log/presentation/pages/dive_detail_site_pills_test.dart`, modeled on `dive_detail_view_site_tap_test.dart` (copy its fixtures, `pumpAndTapViewSite`-style router capture with a `/sites/map` stub route added, and the overflow-error filter):

```dart
  testWidgets('Map pill deep-links to the unified map', (tester) async {
    final location = await pumpAndTapPill(tester, pillText: 'Map');
    expect(location, '/sites/map?site=site-1');
  });

  testWidgets('3D pill deep-links to the unified map in 3D', (tester) async {
    final location = await pumpAndTapPill(tester, pillText: '3D');
    expect(location, contains('/sites/map?site=site-1'));
    expect(location, contains('scape=3d'));
  });
```

with the helper tapping via widget lookup (pills sit under the gradient, so tap the InkWell directly as the view-site test does):

```dart
Future<String?> pumpAndTapPill(
  WidgetTester tester, {
  required String pillText,
}) async {
  // Identical pump to dive_detail_view_site_tap_test (embedded: true,
  // Size(400, 800)), plus a stub route:
  //   GoRoute(path: '/sites/map', builder: (c, s) =>
  //       const Scaffold(body: Text('MAP_STUB_PAGE'))),
  // After pumping:
  final pill = find.ancestor(
    of: find.text(pillText),
    matching: find.byType(InkWell),
  );
  tester.widget<InkWell>(pill.first).onTap!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  tester.takeException();
  return lastLocation;
}
```

- [ ] **Step 3: Run to verify failure, then implement**

The pill block (`if (site != null) Positioned(right: 8, top: 8, child: Container(...)))` at ~1359-1399) becomes:

```dart
              // Map / 3D pills: deep links into the unified sites map.
              if (site != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sitePill(
                        context,
                        icon: Icons.map_outlined,
                        label: context.l10n.diveLog_detail_viewMap,
                        onTap: () =>
                            context.push('/sites/map?site=${site.id}'),
                      ),
                      const SizedBox(width: 6),
                      _sitePill(
                        context,
                        icon: Icons.terrain,
                        label: context.l10n.diveLog_detail_view3d,
                        onTap: () => context.push(
                          '/sites/map?site=${site.id}&scape=3d',
                        ),
                      ),
                    ],
                  ),
                ),
```

New helper on the same class, styled exactly like the old pill container:

```dart
  Widget _sitePill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

The card's `Semantics(label: '${context.l10n.diveLog_detail_viewSite} ${site.name}')` and the card-wide InkWell stay untouched.

- [ ] **Step 4: Run, format, commit**

Run: `flutter test test/features/dive_log/presentation/pages/dive_header_gps_test.dart test/features/dive_log/presentation/pages/dive_detail_site_pills_test.dart test/features/dive_log/presentation/pages/dive_detail_view_site_tap_test.dart test/features/dive_log/presentation/pages/embedded_site_navigation_test.dart > /tmp/t7.log 2>&1; code=$?; echo "exit=$code"`
Expected: exit=0. Then:

```bash
dart format .
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/l10n/arb/ test/features/dive_log/presentation/pages/
git commit -m "feat(sitescape): Map and 3D pills on the dive detail header"
```

---

### Task 8: Delete `SiteSeascapePage`

**Files:**
- Delete: `lib/features/dive_3d/presentation/pages/site_seascape_page.dart`

- [ ] **Step 1: Verify no references remain, then delete**

```bash
grep -rn "SiteSeascapePage\|site_seascape_page" lib test
```

Expected: only the file itself (Tasks 4 and 6 removed all three pushes; the test moved in Task 2). Then `git rm lib/features/dive_3d/presentation/pages/site_seascape_page.dart`.

- [ ] **Step 2: Run, commit**

Run: `flutter analyze > /tmp/t8a.log 2>&1; echo "exit=$?"` and `flutter test test/features/site_scape/ test/features/dive_3d/ test/features/dive_sites/ > /tmp/t8.log 2>&1; code=$?; echo "exit=$code"`
Expected: both exit=0. Then:

```bash
git commit -m "refactor(sitescape): delete the superseded SiteSeascapePage"
```

---

### Task 9: Spec amendment + full verification + stacked PR

- [ ] **Step 1: Amend the spec's PR 3 section**

In `docs/superpowers/specs/2026-08-15-site-scape-unification-design.md`, append to the PR 3 section:

```markdown
Corrections at planning time (PR 3): the sites surface has no `?site=`
mechanism; master-detail uses `?selected=` + `?view=map`, so the deep
link lives on the standalone route `/sites/map?site=<id>&scape=3d`.
Chart stays an internal toggle of `SiteTerrainPane`, not a third
`SiteScapeView` mode. BOTH sites-map surfaces host the pane: the
master-detail `SiteMapContent` AND the standalone `SiteMapPage`, which
also gains the `BathymetryDepthOverlayLayer` its toggle was flipping
without rendering (PR 1 gap). `SiteScapeView` is mode-controlled: hosts
hold the ephemeral mode in their own state, and the 2D stack stays
alive under `Offstage` so the map camera survives mode flips.
```

- [ ] **Step 2: Full verification**

```bash
pwd
dart format .
flutter analyze
flutter test        # capture: > /tmp/full.log 2>&1; code=$?
flutter gen-l10n
git status --short
```

Expected: no format changes, zero analyze issues, full suite green, no l10n drift, no unexpected dirty files.

- [ ] **Step 3: Push and open the stacked PR**

```bash
git push -u origin worktree-site-scape-unification
gh pr create --repo submersion-app/submersion --base worktree-site-scape-imagery --head worktree-site-scape-unification --title "feat(sitescape): unify the sites map and 3D terrain into one morphable pane" --body-file <body file>
```

PR body per repo conventions (no attribution line, no session URL); cover: the SiteScapeView/SiteTerrainPane split, the four hosts, the Offstage camera-continuity trick, the SiteMapPage overlay gap fix, the deep link, the pill change, and the SiteSeascapePage deletion.

## Execution notes

- Manual visual pass before merge: `flutter run -d macos`; on the sites map select a site with bathymetry, flip 2D/3D both via the info-card terrain button and the docked toggle, confirm the map camera lands on the terrain box when returning to 2D; open site detail and morph the 200px card; tap the dive header's Map and 3D pills.
- The `siteSeascapeProvider` override in host tests is required whenever a test can enter 3D; without it the pane fires real bathymetry fetch paths.
- `MockSettingsNotifier` and the three page-local settings mocks lack `noSuchMethod` guards for NEW setters only; this PR adds no settings setters, so they are safe.
- If any host test starts flaking on `Offstage` timers, remember the map is now alive in 3D mode; unmount with a `pumpWidget(Container())` + `pump` tail as the viewport tests do.
