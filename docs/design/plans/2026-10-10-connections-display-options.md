# Connections display options, alternative views and node dragging: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Connections explorer free node dragging, four alternative layouts, styling and spacing controls, and Pairs, Entities and Matrix views of the same map.

**Architecture:** A new device-local `ConnectionsDisplay` value with its own notifier sits beside the existing `ConnectionsViewState`. Each static layout is a pure Dart function producing a `LayoutFrame`; `ConnectionsLayoutController` dispatches on a `ConnectionsLayout` enum, morphs between frames with the existing `LayoutMorph`, and keeps pins for static layouts in an override map. The tables and the matrix are new widgets that read the same `ConnectionGraph` and write the same `connectionsSelectionProvider`.

**Tech Stack:** Flutter, Riverpod (legacy `StateNotifierProvider`, as the feature already uses), `CustomPainter`, Drift raw SQL, SharedPreferences, ARB localisation.

**Spec:** `docs/design/specs/2026-10-10-connections-display-options-design.md` (issue #3223, part of #2321).

## Global Constraints

- Spacing multiplier range: 0.6 to 2.0, default 1.0, slider divisions 14.
- Uniform node radius: 14 px.
- Column wrap: at most 25 nodes per sub-column.
- Morph duration: the existing `kRefocusDuration` (450 ms) and `kRefocusCurve`.
- Display settings persist under the SharedPreferences key `connections_display`, never inside saved maps or presets, never synced.
- Map mode offers `web, circle, columns, clusters, timeline` (default `web`); Around mode offers `radial, circle, columns, clusters, timeline` (default `radial`).
- Mouse, trackpad click and stylus start a drag by pressing on a node; touch keeps long-press.
- New user-facing strings exist in `app_en.arb` and in all ten other locales (ar, de, es, fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` runs LAST, after every translation is in.
- No file under `lib/` above 800 lines; `connections_page.dart` must end smaller than its current 601 lines.
- Dates in the tables use `UnitFormatter(settings).formatDate`.
- No em dashes anywhere (code, comments, ARB, docs, commits).
- After every task: `dart format` on touched files, `flutter analyze` clean.

## Review Focus

1. **Hide unconnected on a map with no edges at all** (every node unconnected): the canvas must not go blank. `ConnectionGraph.withoutUnconnected` returns the graph unchanged when it would remove every node (test in Task 13).
2. **Dragging a node while a layout morph is still running**: the morph finishes at once and the pin lands on the target layout, not on a mid-morph frame that is then overwritten (test in Task 10).
3. **A stored display naming a layout the mode does not offer** (`mapLayout: radial`, `aroundLayout: web`, or a future layout name): restore falls back to that mode's default instead of crashing or showing an Around-only layout in Map mode (test in Task 1).
4. **Timeline with nodes that have no `firstDiveAt`** (label-only focus node in Around mode, which reads zero dives): the node goes in the earliest band; when no node has a date, no year guides are drawn and nothing is NaN (tests in Task 9).
5. **A mouse press on a node followed by no movement** (a plain click or double click): it must still select the node and double click must still centre on it; only movement past the slop starts a drag (test in Task 12).

---

## File structure

Create:

| File | Responsibility |
| --- | --- |
| `lib/features/connections/domain/layout/connections_layout.dart` | `ConnectionsLayout` enum and the per-mode offered lists |
| `lib/features/connections/domain/views/connections_display.dart` | `ConnectionsDisplay` value, its enums, JSON |
| `lib/features/connections/presentation/providers/connections_display_provider.dart` | Notifier persisting `ConnectionsDisplay` |
| `lib/features/connections/domain/layout/layout_guide.dart` | `LayoutGuide`, `YearGuide`, `LaneGuide` |
| `lib/features/connections/domain/layout/pinned_frame.dart` | Applies pin overrides to a static frame |
| `lib/features/connections/domain/layout/node_order.dart` | Shared node ordering comparators |
| `lib/features/connections/domain/layout/circle_layout.dart` | Circle layout |
| `lib/features/connections/domain/layout/columns_layout.dart` | Columns by kind layout |
| `lib/features/connections/domain/layout/cluster_layout.dart` | Clusters layout |
| `lib/features/connections/domain/layout/timeline_layout.dart` | Timeline layout |
| `lib/features/connections/domain/layout/static_layouts.dart` | Dispatch from enum to static layout |
| `lib/features/connections/presentation/pages/connections_graph_stack.dart` | The canvas and its overlays, moved out of the page |
| `lib/features/connections/presentation/panel/display_section.dart` | The View tab's Display section |
| `lib/features/connections/presentation/views/view_mode_button.dart` | App bar view menu |
| `lib/features/connections/presentation/views/table_header_bar.dart` | Count line and Show all above a table or matrix |
| `lib/features/connections/presentation/views/table_rows.dart` | Pure sorting and row building for both tables |
| `lib/features/connections/presentation/views/table_parts.dart` | Sortable header, kind dot label, cell box |
| `lib/features/connections/presentation/views/pairs_table.dart` | Pairs table |
| `lib/features/connections/presentation/views/entities_table.dart` | Entities table |
| `lib/features/connections/presentation/views/matrix_model.dart` | Pure matrix axes, cells and hit testing |
| `lib/features/connections/presentation/views/matrix_painter.dart` | Paints visible matrix cells and frozen headers |
| `lib/features/connections/presentation/views/connections_matrix.dart` | Matrix widget: scroll, tap, semantics |

Modify: `force_layout.dart`, `whole_web_layout.dart`, `radial_layout.dart`, `layout_frame.dart`, `layout_morph.dart`, `connection_node.dart`, `connection_graph.dart`, `connections_node_sql.dart`, `connections_reader.dart`, `connections_layout_controller.dart`, `node_metrics.dart`, `connections_painter.dart`, `connections_canvas.dart`, `connections_share_renderer.dart`, `connections_page.dart`, `view_tab.dart`, the 11 ARB files and their generated Dart, `docs/user/statistics.md`.

Tests live in the mirror paths under `test/features/connections/`.

---

### Task 0: Before screenshots

No code changes. Capture the current Connections page so the PR can show before and after.

**Files:**
- Create (throwaway, never committed): `test/features/connections/zz_capture_test.dart`

- [ ] **Step 1: Write the throwaway capture test**

It pumps `ConnectionsPage` with the same overrides as `connections_page_test.dart` (copy its `_pump` helper and a richer graph: three buddies, two sites, one trip, five edges), loads Roboto and MaterialIcons in `setUpAll` from `$(flutter --version --machine | jq -r .flutterRoot)/bin/cache/artifacts/material_fonts/`, renders the app's real theme via `AppThemeRegistry.resolveTheme(preset, brightness)` with `textTheme.apply(fontFamily: 'Roboto')`, and captures `find.byType(ConnectionsPage)` with `matchesGoldenFile('goldens/<name>.png')` for: desktop light (1280x800), desktop dark, phone light (390x844 at dpr 2, so physicalSize 780x1688). Read font bytes in `setUpAll`, never in the test body.

- [ ] **Step 2: Run and collect**

Run: `flutter test test/features/connections/zz_capture_test.dart --update-goldens`
Copy the PNGs to the scratchpad as `01-connections-desktop-before.png`, `02-connections-desktop-before-dark.png`, `03-connections-before-phone.png`. Keep the capture test file in the scratchpad for reuse in Task 21, then delete it and its `goldens/` folder from `test/`. Check `git status` shows nothing new.

---

### Task 1: `ConnectionsLayout` and `ConnectionsDisplay`

**Files:**
- Create: `lib/features/connections/domain/layout/connections_layout.dart`
- Create: `lib/features/connections/domain/views/connections_display.dart`
- Test: `test/features/connections/domain/views/connections_display_test.dart`

**Interfaces:**
- Produces: `enum ConnectionsLayout { web, radial, circle, columns, clusters, timeline }` with `static const List<ConnectionsLayout> forMap`, `forAround`, `static ConnectionsLayout? fromName(String?)`.
- Produces: `enum ConnectionsViewKind { graph, pairs, entities, matrix }`, `enum LabelMode { auto, all, off }`, `enum NodeSizeMode { byDives, uniform }`, `enum EdgeMode { weighted, thin, selectedOnly }`.
- Produces: `class ConnectionsDisplay` with fields `view, mapLayout, aroundLayout, labels, nodeSize, edges, hideUnconnected, spacing`; `static const initial`, `minSpacing = 0.6`, `maxSpacing = 2.0`; `ConnectionsLayout layoutFor({required bool around})`; `ConnectionsDisplay withLayout(ConnectionsLayout, {required bool around})`; `copyWith(...)` (clamps spacing); `Map<String, Object?> toJson()`; `static ConnectionsDisplay fromJson(Object?)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';

void main() {
  test('defaults: graph view, web and radial, auto labels, spacing 1', () {
    const d = ConnectionsDisplay.initial;
    expect(d.view, ConnectionsViewKind.graph);
    expect(d.layoutFor(around: false), ConnectionsLayout.web);
    expect(d.layoutFor(around: true), ConnectionsLayout.radial);
    expect(d.labels, LabelMode.auto);
    expect(d.nodeSize, NodeSizeMode.byDives);
    expect(d.edges, EdgeMode.weighted);
    expect(d.hideUnconnected, isFalse);
    expect(d.spacing, 1.0);
  });

  test('each mode offers its own layouts, default first', () {
    expect(ConnectionsLayout.forMap.first, ConnectionsLayout.web);
    expect(ConnectionsLayout.forAround.first, ConnectionsLayout.radial);
    expect(ConnectionsLayout.forMap, isNot(contains(ConnectionsLayout.radial)));
    expect(ConnectionsLayout.forAround, isNot(contains(ConnectionsLayout.web)));
  });

  test('withLayout sets one mode and ignores a layout it does not offer', () {
    final d = ConnectionsDisplay.initial
        .withLayout(ConnectionsLayout.columns, around: false)
        .withLayout(ConnectionsLayout.timeline, around: true);
    expect(d.mapLayout, ConnectionsLayout.columns);
    expect(d.aroundLayout, ConnectionsLayout.timeline);
    expect(d.withLayout(ConnectionsLayout.web, around: true), d);
    expect(d.withLayout(ConnectionsLayout.radial, around: false), d);
  });

  test('copyWith clamps spacing', () {
    expect(ConnectionsDisplay.initial.copyWith(spacing: 9).spacing, 2.0);
    expect(ConnectionsDisplay.initial.copyWith(spacing: 0.1).spacing, 0.6);
  });

  test('JSON round trip keeps every field', () {
    final d = ConnectionsDisplay.initial
        .copyWith(
          view: ConnectionsViewKind.matrix,
          labels: LabelMode.off,
          nodeSize: NodeSizeMode.uniform,
          edges: EdgeMode.selectedOnly,
          hideUnconnected: true,
          spacing: 1.4,
        )
        .withLayout(ConnectionsLayout.clusters, around: false)
        .withLayout(ConnectionsLayout.circle, around: true);
    expect(ConnectionsDisplay.fromJson(d.toJson()), d);
  });

  test('anything but a map restores the defaults', () {
    expect(ConnectionsDisplay.fromJson(null), ConnectionsDisplay.initial);
    expect(ConnectionsDisplay.fromJson('x'), ConnectionsDisplay.initial);
    expect(ConnectionsDisplay.fromJson(const [1]), ConnectionsDisplay.initial);
  });

  test('each field falls back on its own', () {
    final d = ConnectionsDisplay.fromJson({
      'view': 'bogus',
      'labels': 7,
      'edges': 'thin',
      'mapLayout': 'radial',
      'aroundLayout': 'web',
      'hideUnconnected': 'yes',
      'spacing': 'wide',
    });
    expect(d.view, ConnectionsViewKind.graph);
    expect(d.labels, LabelMode.auto);
    expect(d.edges, EdgeMode.thin);
    expect(d.mapLayout, ConnectionsLayout.web);
    expect(d.aroundLayout, ConnectionsLayout.radial);
    expect(d.hideUnconnected, isFalse);
    expect(d.spacing, 1.0);
    expect(ConnectionsDisplay.fromJson({'spacing': 5}).spacing, 2.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/domain/views/connections_display_test.dart`
Expected: FAIL, the imports do not exist.

- [ ] **Step 3: Write `connections_layout.dart`**

```dart
/// How the Graph view arranges its nodes. [web] and [radial] are the
/// original layouts (a force simulation, and the Around hub); the rest are
/// static arrangements computed in one pass.
enum ConnectionsLayout {
  web,
  radial,
  circle,
  columns,
  clusters,
  timeline;

  /// The layouts Map mode offers, its default first.
  static const List<ConnectionsLayout> forMap = [
    web,
    circle,
    columns,
    clusters,
    timeline,
  ];

  /// The layouts Around mode offers, its default first.
  static const List<ConnectionsLayout> forAround = [
    radial,
    circle,
    columns,
    clusters,
    timeline,
  ];

  static ConnectionsLayout? fromName(String? value) {
    for (final l in values) {
      if (l.name == value) return l;
    }
    return null;
  }
}
```

- [ ] **Step 4: Write `connections_display.dart`**

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';

/// Which presentation of the map the page shows.
enum ConnectionsViewKind { graph, pairs, entities, matrix }

/// Which node labels the graph draws.
enum LabelMode { auto, all, off }

/// How big each node disc is.
enum NodeSizeMode { byDives, uniform }

/// How the graph draws its edges.
enum EdgeMode { weighted, thin, selectedOnly }

T _named<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

/// How the Connections page presents a map: which view, which layout per
/// mode, and how the graph is drawn. Remembered on this device only and
/// kept apart from [ConnectionsViewState], which says what is shown.
class ConnectionsDisplay extends Equatable {
  const ConnectionsDisplay({
    this.view = ConnectionsViewKind.graph,
    this.mapLayout = ConnectionsLayout.web,
    this.aroundLayout = ConnectionsLayout.radial,
    this.labels = LabelMode.auto,
    this.nodeSize = NodeSizeMode.byDives,
    this.edges = EdgeMode.weighted,
    this.hideUnconnected = false,
    this.spacing = 1.0,
  });

  static const initial = ConnectionsDisplay();
  static const double minSpacing = 0.6;
  static const double maxSpacing = 2.0;

  final ConnectionsViewKind view;
  final ConnectionsLayout mapLayout;
  final ConnectionsLayout aroundLayout;
  final LabelMode labels;
  final NodeSizeMode nodeSize;
  final EdgeMode edges;
  final bool hideUnconnected;

  /// Multiplies every layout's distances; [minSpacing] to [maxSpacing].
  final double spacing;

  ConnectionsLayout layoutFor({required bool around}) =>
      around ? aroundLayout : mapLayout;

  /// Sets [layout] for one mode. A layout that mode does not offer leaves
  /// the display as it is.
  ConnectionsDisplay withLayout(
    ConnectionsLayout layout, {
    required bool around,
  }) {
    final offered = around
        ? ConnectionsLayout.forAround
        : ConnectionsLayout.forMap;
    if (!offered.contains(layout)) return this;
    return around
        ? copyWith(aroundLayout: layout)
        : copyWith(mapLayout: layout);
  }

  ConnectionsDisplay copyWith({
    ConnectionsViewKind? view,
    ConnectionsLayout? mapLayout,
    ConnectionsLayout? aroundLayout,
    LabelMode? labels,
    NodeSizeMode? nodeSize,
    EdgeMode? edges,
    bool? hideUnconnected,
    double? spacing,
  }) {
    return ConnectionsDisplay(
      view: view ?? this.view,
      mapLayout: mapLayout ?? this.mapLayout,
      aroundLayout: aroundLayout ?? this.aroundLayout,
      labels: labels ?? this.labels,
      nodeSize: nodeSize ?? this.nodeSize,
      edges: edges ?? this.edges,
      hideUnconnected: hideUnconnected ?? this.hideUnconnected,
      spacing: (spacing ?? this.spacing)
          .clamp(minSpacing, maxSpacing)
          .toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
    'view': view.name,
    'mapLayout': mapLayout.name,
    'aroundLayout': aroundLayout.name,
    'labels': labels.name,
    'nodeSize': nodeSize.name,
    'edges': edges.name,
    'hideUnconnected': hideUnconnected,
    'spacing': spacing,
  };

  /// Reads a stored display. Each field falls back to its default on its
  /// own, so one unreadable value never resets the rest.
  static ConnectionsDisplay fromJson(Object? json) {
    if (json is! Map) return initial;
    final mapLayout = ConnectionsLayout.fromName(
      json['mapLayout'] is String ? json['mapLayout'] as String : null,
    );
    final aroundLayout = ConnectionsLayout.fromName(
      json['aroundLayout'] is String ? json['aroundLayout'] as String : null,
    );
    final hide = json['hideUnconnected'];
    final spacing = json['spacing'];
    return ConnectionsDisplay(
      view: _named(ConnectionsViewKind.values, json['view'], initial.view),
      mapLayout:
          mapLayout != null && ConnectionsLayout.forMap.contains(mapLayout)
          ? mapLayout
          : initial.mapLayout,
      aroundLayout:
          aroundLayout != null &&
              ConnectionsLayout.forAround.contains(aroundLayout)
          ? aroundLayout
          : initial.aroundLayout,
      labels: _named(LabelMode.values, json['labels'], initial.labels),
      nodeSize: _named(NodeSizeMode.values, json['nodeSize'], initial.nodeSize),
      edges: _named(EdgeMode.values, json['edges'], initial.edges),
      hideUnconnected: hide is bool ? hide : initial.hideUnconnected,
      spacing: spacing is num && spacing.isFinite
          ? spacing.toDouble().clamp(minSpacing, maxSpacing).toDouble()
          : initial.spacing,
    );
  }

  @override
  List<Object?> get props => [
    view,
    mapLayout,
    aroundLayout,
    labels,
    nodeSize,
    edges,
    hideUnconnected,
    spacing,
  ];
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/connections/domain/views/connections_display_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/connections/domain/layout/connections_layout.dart lib/features/connections/domain/views/connections_display.dart test/features/connections/domain/views/connections_display_test.dart
git commit -m "feat(connections): add the display settings value"
```

---

### Task 2: `connectionsDisplayProvider`

**Files:**
- Create: `lib/features/connections/presentation/providers/connections_display_provider.dart`
- Test: `test/features/connections/presentation/providers/connections_display_provider_test.dart`

**Interfaces:**
- Consumes: `ConnectionsDisplay` (Task 1).
- Produces: `const kConnectionsDisplayKey = 'connections_display'`; `class ConnectionsDisplayNotifier extends StateNotifier<ConnectionsDisplay>` with `Future<void> update(ConnectionsDisplay Function(ConnectionsDisplay) change)`; `final connectionsDisplayProvider`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Future<(ProviderContainer, SharedPreferences)> _container(
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );
  addTearDown(c.dispose);
  return (c, sp);
}

void main() {
  test('starts at the defaults with nothing stored', () async {
    final (c, _) = await _container({});
    expect(c.read(connectionsDisplayProvider), ConnectionsDisplay.initial);
  });

  test('restores a stored display', () async {
    final stored = ConnectionsDisplay.initial.copyWith(
      view: ConnectionsViewKind.pairs,
      spacing: 1.5,
    );
    final (c, _) = await _container({
      kConnectionsDisplayKey: jsonEncode(stored.toJson()),
    });
    expect(c.read(connectionsDisplayProvider), stored);
  });

  test('garbage in storage falls back to the defaults', () async {
    final (c, _) = await _container({kConnectionsDisplayKey: '{nope'});
    expect(c.read(connectionsDisplayProvider), ConnectionsDisplay.initial);
  });

  test('update changes state and persists it', () async {
    final (c, sp) = await _container({});
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.copyWith(labels: LabelMode.all));
    expect(c.read(connectionsDisplayProvider).labels, LabelMode.all);
    final saved = ConnectionsDisplay.fromJson(
      jsonDecode(sp.getString(kConnectionsDisplayKey)!),
    );
    expect(saved.labels, LabelMode.all);
  });

  test('a failed write keeps the new state', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final n = ConnectionsDisplayNotifier(
      sp,
      write: (_, _) async => throw Exception('disk full'),
    );
    addTearDown(n.dispose);
    await n.update((d) => d.copyWith(edges: EdgeMode.thin));
    expect(n.state.edges, EdgeMode.thin);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/presentation/providers/connections_display_provider_test.dart`
Expected: FAIL, the provider file does not exist.

- [ ] **Step 3: Write the provider**

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const kConnectionsDisplayKey = 'connections_display';

const _log = LoggerService('ConnectionsDisplay');

/// How the Connections page presents its map, remembered on this device.
class ConnectionsDisplayNotifier extends StateNotifier<ConnectionsDisplay> {
  ConnectionsDisplayNotifier(
    SharedPreferences prefs, {
    Future<bool> Function(String key, String value)? write,
  }) : _write = write ?? prefs.setString,
       super(_restore(prefs));

  final Future<bool> Function(String key, String value) _write;

  static ConnectionsDisplay _restore(SharedPreferences prefs) {
    final raw = prefs.getString(kConnectionsDisplayKey);
    if (raw == null) return ConnectionsDisplay.initial;
    try {
      return ConnectionsDisplay.fromJson(jsonDecode(raw));
    } on FormatException {
      return ConnectionsDisplay.initial;
    }
  }

  /// Applies [change] at once and persists the result. A failed write is
  /// logged and otherwise ignored: the display is a convenience, not data.
  Future<void> update(
    ConnectionsDisplay Function(ConnectionsDisplay) change,
  ) async {
    final next = change(state);
    if (next == state) return;
    state = next;
    try {
      await _write(kConnectionsDisplayKey, jsonEncode(next.toJson()));
    } catch (e, st) {
      _log.warning(
        'Could not remember the connections display',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final connectionsDisplayProvider =
    StateNotifierProvider<ConnectionsDisplayNotifier, ConnectionsDisplay>(
      (ref) => ConnectionsDisplayNotifier(ref.watch(sharedPreferencesProvider)),
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/connections/presentation/providers/connections_display_provider_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/presentation/providers/connections_display_provider.dart test/features/connections/presentation/providers/connections_display_provider_test.dart
git commit -m "feat(connections): remember the display settings on this device"
```

---

### Task 3: Spacing in the existing layouts, and `WholeWebLayout.hasPins`

**Files:**
- Modify: `lib/features/connections/domain/layout/force_layout.dart` (constructor, `_area`)
- Modify: `lib/features/connections/domain/layout/whole_web_layout.dart` (constructor, gaps, `hasPins`)
- Modify: `lib/features/connections/domain/layout/radial_layout.dart` (`compute`)
- Test: `test/features/connections/domain/layout/layout_spacing_test.dart`

**Interfaces:**
- Produces: `ForceLayout({..., double spacing = 1})`, `WholeWebLayout({..., double spacing = 1})`, `bool WholeWebLayout.hasPins`, `RadialLayout.compute({..., double spacing = 1})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/force_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(NodeRef a, NodeRef b) => ConnectionEdge(
  source: a,
  target: b,
  weight: 1,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  test('force spacing scales the settled distance of a linked pair', () {
    double gap(double spacing) {
      final l = ForceLayout(
        nodes: [_b('a'), _b('b')],
        edges: [_e(_b('a'), _b('b'))],
        spacing: spacing,
      );
      while (!l.settled) {
        l.advance(50);
      }
      return l.frame.positions[_b('a')]!.distanceTo(l.frame.positions[_b('b')]!);
    }

    expect(gap(2) / gap(1), inInclusiveRange(1.6, 2.4));
  });

  test('radial spacing scales the ring exactly', () {
    final nodes = [
      ConnectionNode(ref: _b('f'), label: 'F', diveCount: 1),
      ConnectionNode(ref: _b('n'), label: 'N', diveCount: 1),
    ];
    final edges = [_e(_b('f'), _b('n'))];
    double ring(double s) => RadialLayout.compute(
      focus: _b('f'),
      nodes: nodes,
      edges: edges,
      spacing: s,
    ).positions[_b('n')]!.length;
    expect(ring(2), closeTo(ring(1) * 2, 1e-6));
  });

  test('whole web spaces single nodes by the spacing', () {
    double singleGap(double s) {
      final f = WholeWebLayout(
        nodes: [_b('x'), _b('y')],
        edges: const [],
        spacing: s,
      ).frame;
      return f.positions[_b('x')]!.distanceTo(f.positions[_b('y')]!);
    }

    expect(singleGap(1), 90);
    expect(singleGap(1.5), 135);
  });

  test('hasPins follows moveNode and clearPins, singles included', () {
    final web = WholeWebLayout(
      nodes: [_b('a'), _b('b'), _b('lone')],
      edges: [_e(_b('a'), _b('b'))],
    );
    expect(web.hasPins, isFalse);
    web.moveNode(_b('a'), const GraphPoint(5, 5));
    expect(web.hasPins, isTrue);
    web.clearPins();
    expect(web.hasPins, isFalse);
    web.moveNode(_b('lone'), const GraphPoint(9, 9));
    expect(web.hasPins, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/domain/layout/layout_spacing_test.dart`
Expected: FAIL to compile, `spacing` and `hasPins` are not defined.

- [ ] **Step 3: Implement**

In `ForceLayout`, add the parameter and scale the area (the ideal edge length `_k`, the seed ring and the temperature all derive from `_area`, so one change scales everything):

```dart
  ForceLayout({
    required List<NodeRef> nodes,
    required List<ConnectionEdge> edges,
    Map<NodeRef, GraphPoint> initialPositions = const {},
    Set<NodeRef> pinned = const {},
    this.maxIterations = 300,
    this.settleEpsilon = 0.5,
    double spacing = 1,
  }) : _nodes = List.unmodifiable(nodes),
       _pinned = {...pinned} {
    // ...unchanged lines...
    _area = math.max(40000.0, 12000.0 * _nodes.length) * spacing * spacing;
```

In `WholeWebLayout`, add `double spacing = 1` to the constructor, store it in `final double _spacing`, pass `spacing: spacing` to each `ForceLayout`, use `IslandPacker.pack(..., gap: 60 * _spacing)` in `_recompose`, use `final gap = 90.0 * _spacing;` for the single-node grid, and add:

```dart
  /// True while any node, island member or single, is pinned by a drag.
  bool get hasPins =>
      _singlePins.isNotEmpty || _layouts.any((l) => l.pinned.isNotEmpty);
```

In `RadialLayout.compute`, add `double spacing = 1` and scale the three distances at the top of the method:

```dart
    final ringStart = firstRing * spacing;
    final ringStep = ringGap * spacing;
    final arcSpacing = minArcSpacing * spacing;
```

and use `ringStart`, `ringStep`, `arcSpacing` in place of `firstRing`, `ringGap`, `minArcSpacing` in the ring loop.

- [ ] **Step 4: Run the new and the existing layout tests**

Run: `flutter test test/features/connections/domain/layout/`
Expected: PASS, including the unchanged `force_layout_test`, `whole_web_layout_test`, `radial_layout_test` (spacing 1 changes nothing).

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/domain/layout/ test/features/connections/domain/layout/layout_spacing_test.dart
git commit -m "feat(connections): scale the web and radial layouts by a spacing factor"
```

---

### Task 4: Layout guides and pinned frames

**Files:**
- Create: `lib/features/connections/domain/layout/layout_guide.dart`
- Create: `lib/features/connections/domain/layout/pinned_frame.dart`
- Modify: `lib/features/connections/domain/layout/layout_frame.dart`
- Modify: `lib/features/connections/domain/layout/layout_morph.dart`
- Test: `test/features/connections/domain/layout/layout_guides_test.dart`

**Interfaces:**
- Produces: `sealed class LayoutGuide { GraphPoint at; }`, `class YearGuide(int year, GraphPoint at)`, `class LaneGuide(ConnectionKind kind, GraphPoint at)`.
- Produces: `LayoutFrame.guides` (`List<LayoutGuide>`, default empty), `LayoutFrame.fromPositions(..., List<LayoutGuide> guides = const [])`, bounds include guide anchors.
- Produces: `abstract final class PinnedFrame { static LayoutFrame apply(LayoutFrame base, Map<NodeRef, GraphPoint> pins); }`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_guide.dart';
import 'package:submersion/features/connections/domain/layout/layout_morph.dart';
import 'package:submersion/features/connections/domain/layout/pinned_frame.dart';

const _a = NodeRef(ConnectionKind.buddy, 'a');
const _b = NodeRef(ConnectionKind.buddy, 'b');

void main() {
  final guides = [
    const YearGuide(2020, GraphPoint(0, -70)),
    const LaneGuide(ConnectionKind.buddy, GraphPoint(-70, 0)),
  ];
  final base = LayoutFrame.fromPositions(
    {_a: GraphPoint.zero, _b: const GraphPoint(100, 50)},
    settled: true,
    guides: guides,
  );

  test('bounds take in the guide anchors', () {
    expect(base.bounds, const GraphBounds(-70, -70, 100, 50));
  });

  test('a morph carries the target guides', () {
    final from = LayoutFrame.fromPositions({_a: GraphPoint.zero}, settled: true);
    expect(LayoutMorph.at(from: from, to: base, t: 0.5).guides, guides);
  });

  test('no pins returns the base frame itself', () {
    expect(identical(PinnedFrame.apply(base, const {}), base), isTrue);
  });

  test('pins move only nodes on the frame and keep the guides', () {
    final pinned = PinnedFrame.apply(base, {
      _a: const GraphPoint(30, 30),
      const NodeRef(ConnectionKind.site, 'gone'): const GraphPoint(1, 1),
    });
    expect(pinned.positions[_a], const GraphPoint(30, 30));
    expect(pinned.positions[_b], const GraphPoint(100, 50));
    expect(pinned.positions.length, 2);
    expect(pinned.guides, guides);
    expect(pinned.settled, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/domain/layout/layout_guides_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write `layout_guide.dart`**

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

/// A label a layout places in graph space beside its nodes, such as the
/// timeline's year and lane names. The painter draws the text.
sealed class LayoutGuide extends Equatable {
  const LayoutGuide(this.at);

  /// Year guides centre their text here; lane guides end their text here.
  final GraphPoint at;
}

class YearGuide extends LayoutGuide {
  const YearGuide(this.year, super.at);
  final int year;
  @override
  List<Object?> get props => [year, at];
}

class LaneGuide extends LayoutGuide {
  const LaneGuide(this.kind, super.at);
  final ConnectionKind kind;
  @override
  List<Object?> get props => [kind, at];
}
```

- [ ] **Step 4: Extend `LayoutFrame` and `LayoutMorph`**

In `layout_frame.dart` import `layout_guide.dart`, add `this.guides = const []` to the const constructor, the field `final List<LayoutGuide> guides;` with doc `/// Labels drawn in graph space, such as timeline years. Empty for most layouts.`, and change the factory:

```dart
  factory LayoutFrame.fromPositions(
    Map<NodeRef, GraphPoint> positions, {
    required bool settled,
    Map<NodeRef, double> appear = const {},
    List<LayoutGuide> guides = const [],
  }) {
    return LayoutFrame(
      positions: Map.unmodifiable(positions),
      bounds: GraphBounds.of([
        ...positions.values,
        for (final g in guides) g.at,
      ]),
      settled: settled,
      appear: Map.unmodifiable(appear),
      guides: List.unmodifiable(guides),
    );
  }
```

In `layout_morph.dart`, pass `guides: to.guides` to `LayoutFrame.fromPositions`.

- [ ] **Step 5: Write `pinned_frame.dart`**

```dart
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

/// A static layout with the diver's dragged nodes put where they dropped
/// them. Pins for nodes no longer on the frame are ignored.
abstract final class PinnedFrame {
  static LayoutFrame apply(LayoutFrame base, Map<NodeRef, GraphPoint> pins) {
    if (pins.isEmpty) return base;
    return LayoutFrame.fromPositions(
      {
        ...base.positions,
        for (final MapEntry(:key, :value) in pins.entries)
          if (base.positions.containsKey(key)) key: value,
      },
      settled: base.settled,
      appear: base.appear,
      guides: base.guides,
    );
  }
}
```

- [ ] **Step 6: Run the layout tests**

Run: `flutter test test/features/connections/domain/layout/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/connections/domain/layout/ test/features/connections/domain/layout/layout_guides_test.dart
git commit -m "feat(connections): carry layout guides on frames and apply pins to static frames"
```

---

### Task 5: Node ordering and the Circle layout

**Files:**
- Create: `lib/features/connections/domain/layout/node_order.dart`
- Create: `lib/features/connections/domain/layout/circle_layout.dart`
- Test: `test/features/connections/domain/layout/circle_layout_test.dart`

**Interfaces:**
- Produces: `int compareDivesLabel(ConnectionNode a, ConnectionNode b)`, `int compareKindDivesLabel(ConnectionNode a, ConnectionNode b)`.
- Produces: `CircleLayout.compute({required List<ConnectionNode> nodes, NodeRef? focus, double spacing = 1}) -> LayoutFrame`, constants `CircleLayout.slot = 64`, `CircleLayout.minRadius = 160`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/circle_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

ConnectionNode _n(ConnectionKind k, String id, int dives) =>
    ConnectionNode(ref: NodeRef(k, id), label: id, diveCount: dives);

/// Clockwise angle from the top, 0 to 2 pi.
double _angle(GraphPoint p) =>
    (math.atan2(p.y, p.x) + math.pi / 2) % (2 * math.pi);

void main() {
  test('an empty graph lays out nothing', () {
    expect(CircleLayout.compute(nodes: const []).positions, isEmpty);
  });

  test('one node sits on the ring with finite coordinates', () {
    final p = CircleLayout.compute(
      nodes: [_n(ConnectionKind.buddy, 'a', 1)],
    ).positions.values.single;
    expect(p.isFinite, isTrue);
    expect(p.length, closeTo(CircleLayout.minRadius, 1e-6));
  });

  test('kinds form contiguous arcs, busiest first within a kind', () {
    final nodes = [
      _n(ConnectionKind.site, 's1', 1),
      _n(ConnectionKind.buddy, 'b1', 1),
      _n(ConnectionKind.site, 's2', 9),
      _n(ConnectionKind.buddy, 'b2', 5),
    ];
    final f = CircleLayout.compute(nodes: nodes);
    final order = [...nodes]
      ..sort((a, b) =>
          _angle(f.positions[a.ref]!).compareTo(_angle(f.positions[b.ref]!)));
    expect(order.map((n) => n.ref.id), ['b2', 'b1', 's2', 's1']);
  });

  test('neighbours never crowd closer than about one slot', () {
    final nodes = [
      for (var i = 0; i < 40; i++) _n(ConnectionKind.buddy, 'b$i', 40 - i),
    ];
    final f = CircleLayout.compute(nodes: nodes);
    for (var i = 0; i < nodes.length; i++) {
      final a = f.positions[nodes[i].ref]!;
      final b = f.positions[nodes[(i + 1) % nodes.length].ref]!;
      expect(a.distanceTo(b), greaterThan(CircleLayout.slot * 0.95));
    }
  });

  test('the focus sits in the middle of the ring', () {
    final focus = _n(ConnectionKind.buddy, 'me', 1);
    final f = CircleLayout.compute(
      nodes: [focus, _n(ConnectionKind.site, 's', 3)],
      focus: focus.ref,
    );
    expect(f.positions[focus.ref], GraphPoint.zero);
    expect(
      f.positions[NodeRef(ConnectionKind.site, 's')]!.length,
      closeTo(CircleLayout.minRadius, 1e-6),
    );
  });

  test('spacing scales the radius', () {
    final nodes = [_n(ConnectionKind.buddy, 'a', 1), _n(ConnectionKind.buddy, 'b', 1)];
    final r1 = CircleLayout.compute(nodes: nodes).positions.values.first.length;
    final r2 = CircleLayout.compute(nodes: nodes, spacing: 2)
        .positions.values.first.length;
    expect(r2, closeTo(r1 * 2, 1e-6));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/domain/layout/circle_layout_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write `node_order.dart`**

```dart
import 'package:submersion/features/connections/domain/entities/connection_node.dart';

/// Busiest first, then by label, then by id, so equal nodes keep one order
/// on every device.
int compareDivesLabel(ConnectionNode a, ConnectionNode b) {
  final byDives = b.diveCount.compareTo(a.diveCount);
  if (byDives != 0) return byDives;
  final byLabel = a.label.compareTo(b.label);
  return byLabel != 0 ? byLabel : a.ref.id.compareTo(b.ref.id);
}

/// Kind in enum order first, then [compareDivesLabel]: the reading order the
/// static layouts and the matrix share.
int compareKindDivesLabel(ConnectionNode a, ConnectionNode b) {
  final byKind = a.ref.kind.index.compareTo(b.ref.kind.index);
  return byKind != 0 ? byKind : compareDivesLabel(a, b);
}
```

- [ ] **Step 4: Write `circle_layout.dart`**

```dart
import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// Every node evenly on one ring, kinds in contiguous arcs, starting at the
/// top and running clockwise. A focus (Around mode) sits in the middle.
abstract final class CircleLayout {
  /// Arc length per node at spacing 1: two of the largest discs (26 px
  /// radius) side by side with a little air.
  static const double slot = 64;
  static const double minRadius = 160;

  static LayoutFrame compute({
    required List<ConnectionNode> nodes,
    NodeRef? focus,
    double spacing = 1,
  }) {
    final centre = focus != null && nodes.any((n) => n.ref == focus)
        ? focus
        : null;
    final ring = [
      for (final n in nodes)
        if (n.ref != centre) n,
    ]..sort(compareKindDivesLabel);
    final positions = <NodeRef, GraphPoint>{
      if (centre != null) centre: GraphPoint.zero,
    };
    if (ring.isNotEmpty) {
      final radius =
          math.max(minRadius, ring.length * slot / (2 * math.pi)) * spacing;
      for (var i = 0; i < ring.length; i++) {
        final angle = -math.pi / 2 + 2 * math.pi * i / ring.length;
        positions[ring[i].ref] = GraphPoint(
          radius * math.cos(angle),
          radius * math.sin(angle),
        );
      }
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/connections/domain/layout/circle_layout_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/connections/domain/layout/node_order.dart lib/features/connections/domain/layout/circle_layout.dart test/features/connections/domain/layout/circle_layout_test.dart
git commit -m "feat(connections): add the circle layout"
```

---

### Task 6: Columns by kind layout

**Files:**
- Create: `lib/features/connections/domain/layout/columns_layout.dart`
- Test: `test/features/connections/domain/layout/columns_layout_test.dart`

**Interfaces:**
- Consumes: `compareDivesLabel` (Task 5).
- Produces: `ColumnsLayout.compute({required List<ConnectionNode> nodes, NodeRef? focus, double spacing = 1}) -> LayoutFrame`; constants `maxPerColumn = 25`, `columnGap = 240`, `subColumnGap = 160`, `rowGap = 56`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/columns_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

ConnectionNode _n(ConnectionKind k, String id, int dives) =>
    ConnectionNode(ref: NodeRef(k, id), label: id, diveCount: dives);

void main() {
  test('one column per kind in kind order, busiest at the top', () {
    final f = ColumnsLayout.compute(
      nodes: [
        _n(ConnectionKind.site, 's1', 1),
        _n(ConnectionKind.buddy, 'b1', 2),
        _n(ConnectionKind.buddy, 'b2', 7),
      ],
    );
    expect(f.positions[NodeRef(ConnectionKind.buddy, 'b2')], GraphPoint.zero);
    expect(
      f.positions[NodeRef(ConnectionKind.buddy, 'b1')],
      const GraphPoint(0, ColumnsLayout.rowGap),
    );
    expect(
      f.positions[NodeRef(ConnectionKind.site, 's1')],
      const GraphPoint(ColumnsLayout.columnGap, 0),
    );
  });

  test('a tall column wraps into sub-columns and pushes the next kind right', () {
    final sites = [
      for (var i = 0; i < 30; i++) _n(ConnectionKind.site, 's$i', 100 - i),
    ];
    final f = ColumnsLayout.compute(
      nodes: [...sites, _n(ConnectionKind.trip, 't', 1)],
    );
    expect(
      f.positions[sites[25].ref],
      const GraphPoint(ColumnsLayout.subColumnGap, 0),
    );
    expect(
      f.positions[NodeRef(ConnectionKind.trip, 't')],
      const GraphPoint(ColumnsLayout.subColumnGap + ColumnsLayout.columnGap, 0),
    );
  });

  test('around: the focus kind comes first and the focus tops it', () {
    final me = _n(ConnectionKind.site, 'home', 1);
    final f = ColumnsLayout.compute(
      nodes: [_n(ConnectionKind.buddy, 'b', 9), _n(ConnectionKind.site, 'x', 5), me],
      focus: me.ref,
    );
    expect(f.positions[me.ref], GraphPoint.zero);
    expect(f.positions[NodeRef(ConnectionKind.site, 'x')]!.x, 0);
    expect(f.positions[NodeRef(ConnectionKind.buddy, 'b')]!.x, ColumnsLayout.columnGap);
  });

  test('spacing scales every gap', () {
    final f = ColumnsLayout.compute(
      nodes: [_n(ConnectionKind.buddy, 'a', 2), _n(ConnectionKind.buddy, 'b', 1)],
      spacing: 2,
    );
    expect(
      f.positions[NodeRef(ConnectionKind.buddy, 'b')],
      const GraphPoint(0, ColumnsLayout.rowGap * 2),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/domain/layout/columns_layout_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write `columns_layout.dart`**

```dart
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// One column per kind, left to right in kind order, busiest at the top.
/// A column longer than [maxPerColumn] wraps into sub-columns. In Around
/// mode the focus's kind comes first and the focus tops its column.
abstract final class ColumnsLayout {
  static const int maxPerColumn = 25;
  static const double columnGap = 240;
  static const double subColumnGap = 160;
  static const double rowGap = 56;

  static LayoutFrame compute({
    required List<ConnectionNode> nodes,
    NodeRef? focus,
    double spacing = 1,
  }) {
    final byKind = <ConnectionKind, List<ConnectionNode>>{};
    for (final n in nodes) {
      byKind.putIfAbsent(n.ref.kind, () => []).add(n);
    }
    final focusKind = focus != null && nodes.any((n) => n.ref == focus)
        ? focus.kind
        : null;
    final kinds = byKind.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (focusKind != null) {
      kinds
        ..remove(focusKind)
        ..insert(0, focusKind);
    }
    final positions = <NodeRef, GraphPoint>{};
    var x = 0.0;
    for (final kind in kinds) {
      final members = byKind[kind]!..sort(compareDivesLabel);
      if (kind == focusKind) {
        final i = members.indexWhere((n) => n.ref == focus);
        members.insert(0, members.removeAt(i));
      }
      for (var i = 0; i < members.length; i++) {
        positions[members[i].ref] = GraphPoint(
          x + (i ~/ maxPerColumn) * subColumnGap * spacing,
          (i % maxPerColumn) * rowGap * spacing,
        );
      }
      final subColumns = (members.length + maxPerColumn - 1) ~/ maxPerColumn;
      x += ((subColumns - 1) * subColumnGap + columnGap) * spacing;
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/connections/domain/layout/columns_layout_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/domain/layout/columns_layout.dart test/features/connections/domain/layout/columns_layout_test.dart
git commit -m "feat(connections): add the columns by kind layout"
```

---

### Task 7: Clusters layout

**Files:**
- Create: `lib/features/connections/domain/layout/cluster_layout.dart`
- Test: `test/features/connections/domain/layout/cluster_layout_test.dart`

**Interfaces:**
- Consumes: `LabelPropagation.communities` (existing), `ForceLayout(spacing:)` (Task 3), `IslandPacker.pack` (existing), `compareDivesLabel` (Task 5).
- Produces: `ClusterLayout.compute({required ConnectionGraph graph, double spacing = 1}) -> LayoutFrame`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/cluster_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(String a, String b) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: 3,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

final _graph = ConnectionGraph(
  nodes: [
    for (final id in ['a1', 'a2', 'a3', 'z1', 'z2', 'z3', 'lone'])
      ConnectionNode(ref: _b(id), label: id, diveCount: 1),
  ],
  edges: [
    _e('a1', 'a2'), _e('a2', 'a3'), _e('a1', 'a3'),
    _e('z1', 'z2'), _e('z2', 'z3'), _e('z1', 'z3'),
  ],
);

void main() {
  test('each group gets its own island, islands do not overlap', () {
    final f = ClusterLayout.compute(graph: _graph);
    GraphBounds box(List<String> ids) =>
        GraphBounds.of([for (final id in ids) f.positions[_b(id)]!]);
    final a = box(['a1', 'a2', 'a3']);
    final z = box(['z1', 'z2', 'z3']);
    final apart = a.right < z.left || z.right < a.left ||
        a.bottom < z.top || z.bottom < a.top;
    expect(apart, isTrue);
  });

  test('an ungrouped node goes below the islands', () {
    final f = ClusterLayout.compute(graph: _graph);
    final lowest = [
      for (final id in ['a1', 'a2', 'a3', 'z1', 'z2', 'z3']) f.positions[_b(id)]!.y,
    ].reduce((x, y) => x > y ? x : y);
    expect(f.positions[_b('lone')]!.y, greaterThan(lowest));
  });

  test('is deterministic and settled', () {
    final f1 = ClusterLayout.compute(graph: _graph);
    final f2 = ClusterLayout.compute(graph: _graph);
    expect(f1.positions, f2.positions);
    expect(f1.settled, isTrue);
  });

  test('an empty graph lays out nothing', () {
    expect(ClusterLayout.compute(graph: ConnectionGraph.empty).positions, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/domain/layout/cluster_layout_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write `cluster_layout.dart`**

```dart
import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/layout/force_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/island_packer.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// The groups the Groups highlight colours, each laid out on its own and
/// packed side by side, biggest first, with ungrouped nodes in a grid
/// below. Every simulation runs to rest here, so the frame is static.
abstract final class ClusterLayout {
  static const double islandGap = 60;
  static const double singleGap = 90;

  static LayoutFrame compute({
    required ConnectionGraph graph,
    double spacing = 1,
  }) {
    final groups = LabelPropagation.communities(graph);
    final members = <int, List<NodeRef>>{};
    final loose = <ConnectionNode>[];
    for (final n in graph.nodes) {
      final g = groups.groupOf[n.ref];
      if (g == null) {
        loose.add(n);
      } else {
        members.putIfAbsent(g, () => []).add(n.ref);
      }
    }
    final frames = <LayoutFrame>[];
    for (var g = 0; g < groups.count; g++) {
      final refs = members[g] ?? const <NodeRef>[];
      final inGroup = refs.toSet();
      final layout = ForceLayout(
        nodes: refs,
        edges: [
          for (final e in graph.edges)
            if (inGroup.contains(e.source) && inGroup.contains(e.target)) e,
        ],
        spacing: spacing,
      );
      // ForceLayout caps its own iterations, so this always ends.
      while (!layout.settled) {
        layout.advance(50);
      }
      frames.add(layout.frame);
    }
    final offsets = IslandPacker.pack(frames, gap: islandGap * spacing);
    final positions = <NodeRef, GraphPoint>{};
    for (var i = 0; i < frames.length; i++) {
      for (final MapEntry(:key, :value) in frames[i].positions.entries) {
        positions[key] = value + offsets[i];
      }
    }
    if (loose.isNotEmpty) {
      loose.sort(compareDivesLabel);
      final gap = singleGap * spacing;
      final packed = GraphBounds.of(positions.values);
      final cols = math.max(1, (math.sqrt(loose.length) * 1.6).ceil());
      final x0 = positions.isEmpty ? 0.0 : packed.left;
      final y0 = positions.isEmpty ? 0.0 : packed.bottom + gap;
      for (var i = 0; i < loose.length; i++) {
        positions[loose[i].ref] = GraphPoint(
          x0 + (i % cols) * gap,
          y0 + (i ~/ cols) * gap,
        );
      }
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/connections/domain/layout/cluster_layout_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/domain/layout/cluster_layout.dart test/features/connections/domain/layout/cluster_layout_test.dart
git commit -m "feat(connections): add the clusters layout"
```

---

### Task 8: Each node's first dive date

**Files:**
- Modify: `lib/features/connections/domain/entities/connection_node.dart`
- Modify: `lib/features/connections/data/connections_node_sql.dart:80-89`
- Modify: `lib/features/connections/data/connections_reader.dart:86-95`
- Test: `test/features/connections/data/connections_sql_test.dart`, `test/features/connections/data/connections_reader_test.dart`, `test/features/connections/domain/entities/entity_values_test.dart`

**Interfaces:**
- Produces: `ConnectionNode.firstDiveAt` (`DateTime?`, wall-clock UTC like `ConnectionEdge.firstDiveAt`), in the constructor, `copyWith` and `props`.

- [ ] **Step 1: Write the failing tests**

In `connections_sql_test.dart`, inside `group('buildNodeSql', ...)`:

```dart
    test('reads each entity first dive in scope', () {
      final r = buildNodeSql(
        kind: ConnectionKind.site,
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(r.sql, contains('MIN(d.dive_date_time) AS first_ms'));
      expect(r.sql, contains('c.first_ms AS first_ms'));
    });
```

In `connections_reader_test.dart`, after `each kind reads its subtitle` (import `package:submersion/core/util/wall_clock_utc.dart`):

```dart
  test('each node carries its first dive in scope', () async {
    await _seed(DatabaseService.instance.database);
    expect(
      (await single(ConnectionKind.trip)).firstDiveAt,
      wallClockUtcFromMillis(_ms),
    );
  });
```

In `entity_values_test.dart`:

```dart
  test('a node keeps its first dive through copyWith and compares on it', () {
    final n = ConnectionNode(
      ref: const NodeRef(ConnectionKind.site, 's'),
      label: 'S',
      diveCount: 1,
      firstDiveAt: DateTime.utc(2021, 5, 1),
    );
    expect(n.copyWith(label: 'T').firstDiveAt, DateTime.utc(2021, 5, 1));
    expect(n, isNot(n.copyWith(firstDiveAt: DateTime.utc(2022))));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/connections/data/connections_sql_test.dart test/features/connections/data/connections_reader_test.dart test/features/connections/domain/entities/entity_values_test.dart`
Expected: FAIL (compile error on `firstDiveAt`, SQL assertions).

- [ ] **Step 3: Implement**

`connection_node.dart`: add `this.firstDiveAt,` to the constructor, the field

```dart
  /// The earliest dive this entity has within the query's scope and filter,
  /// as wall-clock UTC (read the fields, never convert to local). Null for
  /// a node built without one, such as a focus with no dive in scope.
  final DateTime? firstDiveAt;
```

`DateTime? firstDiveAt` in `copyWith` (`firstDiveAt: firstDiveAt ?? this.firstDiveAt`), and `firstDiveAt` in `props` after `diveCount`.

`connections_node_sql.dart`, the SQL string:

```dart
SELECT t.id AS id, t.${t.labelColumn} AS label$extra, c.dive_count AS dive_count, c.first_ms AS first_ms
FROM (
  SELECT m.entity_id, COUNT(DISTINCT d.id) AS dive_count, MIN(d.dive_date_time) AS first_ms
```

`connections_reader.dart` (import `package:submersion/core/util/wall_clock_utc.dart`), in the node constructor:

```dart
          firstDiveAt: wallClockUtcFromMillis(r.read<int>('first_ms')),
```

Then `grep -rn "buildNodeSql" lib/` and confirm every caller reads rows through `ConnectionsReader.nodes` (adding a column breaks nothing else).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/connections/data/ test/features/connections/domain/entities/ test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/domain/entities/connection_node.dart lib/features/connections/data/connections_node_sql.dart lib/features/connections/data/connections_reader.dart test/features/connections/data/ test/features/connections/domain/entities/entity_values_test.dart
git commit -m "feat(connections): read each node's first dive in scope"
```

---

### Task 9: Timeline layout

**Files:**
- Create: `lib/features/connections/domain/layout/timeline_layout.dart`
- Test: `test/features/connections/domain/layout/timeline_layout_test.dart`

**Interfaces:**
- Consumes: `ConnectionNode.firstDiveAt` (Task 8), `YearGuide`, `LaneGuide`, `LayoutFrame.fromPositions(guides:)` (Task 4), `compareDivesLabel` (Task 5).
- Produces: `TimelineLayout.compute({required List<ConnectionNode> nodes, double spacing = 1}) -> LayoutFrame`; constants `yearWidth = 170`, `rowGap = 52`, `laneGap = 70`, `guideOffset = 70`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_guide.dart';
import 'package:submersion/features/connections/domain/layout/timeline_layout.dart';

ConnectionNode _n(ConnectionKind k, String id, int dives, int? year) =>
    ConnectionNode(
      ref: NodeRef(k, id),
      label: id,
      diveCount: dives,
      firstDiveAt: year == null ? null : DateTime.utc(year, 6, 1),
    );

void main() {
  test('x follows the first dive year, empty years keep their band', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'a', 1, 2020),
        _n(ConnectionKind.buddy, 'b', 1, 2022),
      ],
    );
    expect(f.positions[NodeRef(ConnectionKind.buddy, 'a')]!.x, 0);
    expect(
      f.positions[NodeRef(ConnectionKind.buddy, 'b')]!.x,
      2 * TimelineLayout.yearWidth,
    );
    final years = f.guides.whereType<YearGuide>().map((g) => g.year);
    expect(years, [2020, 2021, 2022]);
  });

  test('kinds get lanes in kind order, each with a lane guide', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.site, 's', 1, 2020),
        _n(ConnectionKind.buddy, 'b', 1, 2020),
      ],
    );
    final buddyY = f.positions[NodeRef(ConnectionKind.buddy, 'b')]!.y;
    final siteY = f.positions[NodeRef(ConnectionKind.site, 's')]!.y;
    expect(buddyY, lessThan(siteY));
    expect(
      f.guides.whereType<LaneGuide>().map((g) => g.kind),
      [ConnectionKind.buddy, ConnectionKind.site],
    );
  });

  test('a cell stacks busiest first', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'quiet', 1, 2020),
        _n(ConnectionKind.buddy, 'busy', 9, 2020),
      ],
    );
    expect(f.positions[NodeRef(ConnectionKind.buddy, 'busy')], GraphPoint.zero);
    expect(
      f.positions[NodeRef(ConnectionKind.buddy, 'quiet')],
      const GraphPoint(0, TimelineLayout.rowGap),
    );
  });

  test('a node without a date joins the earliest band', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'dated', 1, 2019),
        _n(ConnectionKind.buddy, 'undated', 0, null),
      ],
    );
    expect(f.positions[NodeRef(ConnectionKind.buddy, 'undated')]!.x, 0);
  });

  test('no dates at all: one band, no year guides, nothing NaN', () {
    final f = TimelineLayout.compute(
      nodes: [_n(ConnectionKind.buddy, 'x', 0, null)],
    );
    expect(f.guides.whereType<YearGuide>(), isEmpty);
    expect(f.positions.values.every((p) => p.isFinite), isTrue);
  });

  test('spacing scales the year bands', () {
    final f = TimelineLayout.compute(
      nodes: [
        _n(ConnectionKind.buddy, 'a', 1, 2020),
        _n(ConnectionKind.buddy, 'b', 1, 2021),
      ],
      spacing: 2,
    );
    expect(
      f.positions[NodeRef(ConnectionKind.buddy, 'b')]!.x,
      TimelineLayout.yearWidth * 2,
    );
  });

  test('an empty graph lays out nothing', () {
    expect(TimelineLayout.compute(nodes: const []).positions, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/domain/layout/timeline_layout_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write `timeline_layout.dart`**

```dart
import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_guide.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// Nodes left to right by the year of their first dive in scope, one lane
/// per kind top to bottom, busiest first within a year. Every year from the
/// first to the last keeps a band, so distance reads as time. A node with
/// no date joins the earliest band.
abstract final class TimelineLayout {
  static const double yearWidth = 170;
  static const double rowGap = 52;
  static const double laneGap = 70;

  /// How far the year labels sit above the first lane, and the lane labels
  /// left of the first year.
  static const double guideOffset = 70;

  static LayoutFrame compute({
    required List<ConnectionNode> nodes,
    double spacing = 1,
  }) {
    if (nodes.isEmpty) return LayoutFrame.empty;
    final years = [
      for (final n in nodes)
        if (n.firstDiveAt != null) n.firstDiveAt!.year,
    ];
    final first = years.isEmpty ? null : years.reduce(math.min);
    final last = years.isEmpty ? null : years.reduce(math.max);
    final origin = first ?? 0;
    final cells = <ConnectionKind, Map<int, List<ConnectionNode>>>{};
    for (final n in nodes) {
      final year = n.firstDiveAt?.year ?? origin;
      cells
          .putIfAbsent(n.ref.kind, () => {})
          .putIfAbsent(year, () => [])
          .add(n);
    }
    final kinds = cells.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final positions = <NodeRef, GraphPoint>{};
    final guides = <LayoutGuide>[];
    var laneTop = 0.0;
    for (final kind in kinds) {
      var tallest = 0;
      for (final MapEntry(key: year, value: members) in cells[kind]!.entries) {
        members.sort(compareDivesLabel);
        for (var i = 0; i < members.length; i++) {
          positions[members[i].ref] = GraphPoint(
            (year - origin) * yearWidth * spacing,
            laneTop + i * rowGap * spacing,
          );
        }
        tallest = math.max(tallest, members.length);
      }
      guides.add(LaneGuide(kind, GraphPoint(-guideOffset * spacing, laneTop)));
      laneTop += (tallest * rowGap + laneGap) * spacing;
    }
    if (first != null && last != null) {
      for (var y = first; y <= last; y++) {
        guides.add(
          YearGuide(
            y,
            GraphPoint((y - origin) * yearWidth * spacing, -guideOffset * spacing),
          ),
        );
      }
    }
    return LayoutFrame.fromPositions(positions, settled: true, guides: guides);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/connections/domain/layout/timeline_layout_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/domain/layout/timeline_layout.dart test/features/connections/domain/layout/timeline_layout_test.dart
git commit -m "feat(connections): add the timeline layout"
```

---

### Task 10: Static layout dispatch and the layout controller

**Files:**
- Create: `lib/features/connections/domain/layout/static_layouts.dart`
- Modify: `lib/features/connections/presentation/providers/connections_layout_controller.dart` (whole file)
- Modify: `lib/features/connections/presentation/pages/connections_page.dart:170-182` (`_syncLayout` call only)
- Modify: `test/features/connections/presentation/providers/connections_layout_controller_test.dart`, `test/features/connections/presentation/canvas/connections_canvas_test.dart` (rename `mode:` to `layout:`)
- Test: `test/features/connections/presentation/providers/connections_layout_controller_static_test.dart`

**Interfaces:**
- Consumes: every layout from Tasks 3 to 9, `PinnedFrame` (Task 4).
- Produces: `StaticLayouts.compute(ConnectionsLayout layout, {required ConnectionGraph graph, NodeRef? focus, double spacing = 1}) -> LayoutFrame` (throws `ArgumentError` for `web`).
- Produces: `ConnectionsLayoutController.setGraph(ConnectionGraph graph, {required ConnectionsLayout layout, NodeRef? focus, double spacing = 1, bool warmStart = true, bool animate = false})`, `ConnectionsLayout get layout`, `bool get hasPins`, `moveNode` in every layout, `relayout()` in every layout. `GraphLayoutMode` is deleted.

- [ ] **Step 1: Rename the old API in existing callers**

Replace in `connections_layout_controller_test.dart` and `connections_canvas_test.dart`: `mode: GraphLayoutMode.web` with `layout: ConnectionsLayout.web`, `mode: GraphLayoutMode.ego` with `layout: ConnectionsLayout.radial`, and add `import 'package:submersion/features/connections/domain/layout/connections_layout.dart';`. In `connections_page.dart` `_syncLayout`, replace the `mode:` argument with `layout: focus == null ? ConnectionsLayout.web : ConnectionsLayout.radial,` and add the same import. Any test asserting `controller.mode` asserts `controller.layout` instead.

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/circle_layout.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    for (final id in ['a', 'b', 'c'])
      ConnectionNode(ref: _b(id), label: id, diveCount: 1),
  ],
  edges: [
    ConnectionEdge(
      source: _b('a'),
      target: _b('b'),
      weight: 2,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionsLayoutController c;
  setUp(() => c = ConnectionsLayoutController(vsync: const TestVSync()));
  tearDown(() => c.dispose());

  test('a static layout is settled at once and matches its function', () {
    c.setGraph(_graph, layout: ConnectionsLayout.circle);
    expect(c.settled, isTrue);
    expect(c.layout, ConnectionsLayout.circle);
    expect(
      c.frame.positions,
      CircleLayout.compute(nodes: _graph.nodes).positions,
    );
  });

  test('moveNode pins one node in a static layout; relayout releases', () {
    c.setGraph(_graph, layout: ConnectionsLayout.columns);
    final before = c.frame.positions;
    c.moveNode(_b('a'), const GraphPoint(999, 999));
    expect(c.frame.positions[_b('a')], const GraphPoint(999, 999));
    expect(c.frame.positions[_b('b')], before[_b('b')]);
    expect(c.hasPins, isTrue);
    c.relayout();
    expect(c.hasPins, isFalse);
    expect(c.frame.positions, before);
  });

  test('moveNode works in the radial layout', () {
    c.setGraph(_graph, layout: ConnectionsLayout.radial, focus: _b('a'));
    c.moveNode(_b('b'), const GraphPoint(5, 6));
    expect(c.frame.positions[_b('b')], const GraphPoint(5, 6));
  });

  test('a new graph, layout or spacing releases every pin', () {
    c.setGraph(_graph, layout: ConnectionsLayout.circle);
    c.moveNode(_b('a'), const GraphPoint(1, 1));
    c.setGraph(_graph, layout: ConnectionsLayout.circle, spacing: 1.5);
    expect(c.hasPins, isFalse);
  });

  test('switching layout morphs over the refocus duration', () {
    c.setGraph(_graph, layout: ConnectionsLayout.columns);
    c.setGraph(_graph, layout: ConnectionsLayout.circle, animate: true);
    expect(c.settled, isFalse);
    c.stepForTest(null, kRefocusDuration);
    expect(c.settled, isTrue);
    expect(
      c.frame.positions,
      CircleLayout.compute(nodes: _graph.nodes).positions,
    );
  });

  test('dragging during a morph lands on the target layout', () {
    c.setGraph(_graph, layout: ConnectionsLayout.columns);
    c.setGraph(_graph, layout: ConnectionsLayout.circle, animate: true);
    c.moveNode(_b('a'), const GraphPoint(7, 7));
    final target = CircleLayout.compute(nodes: _graph.nodes).positions;
    expect(c.settled, isTrue);
    expect(c.frame.positions[_b('a')], const GraphPoint(7, 7));
    expect(c.frame.positions[_b('b')], target[_b('b')]);
  });

  test('web reports pins through the force layout', () {
    c.setGraph(_graph, layout: ConnectionsLayout.web);
    expect(c.hasPins, isFalse);
    c.moveNode(_b('a'), const GraphPoint(3, 3));
    expect(c.hasPins, isTrue);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/connections/presentation/providers/connections_layout_controller_static_test.dart`
Expected: FAIL to compile.

- [ ] **Step 4: Write `static_layouts.dart`**

```dart
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/circle_layout.dart';
import 'package:submersion/features/connections/domain/layout/cluster_layout.dart';
import 'package:submersion/features/connections/domain/layout/columns_layout.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';
import 'package:submersion/features/connections/domain/layout/timeline_layout.dart';

/// Every layout computed in one pass. [ConnectionsLayout.web] is a live
/// simulation and has no entry here.
abstract final class StaticLayouts {
  static LayoutFrame compute(
    ConnectionsLayout layout, {
    required ConnectionGraph graph,
    NodeRef? focus,
    double spacing = 1,
  }) => switch (layout) {
    // Radial needs a centre; without one it is a ring.
    ConnectionsLayout.radial when focus != null => RadialLayout.compute(
      focus: focus,
      nodes: graph.nodes,
      edges: graph.edges,
      spacing: spacing,
    ),
    ConnectionsLayout.radial || ConnectionsLayout.circle =>
      CircleLayout.compute(nodes: graph.nodes, focus: focus, spacing: spacing),
    ConnectionsLayout.columns => ColumnsLayout.compute(
      nodes: graph.nodes,
      focus: focus,
      spacing: spacing,
    ),
    ConnectionsLayout.clusters => ClusterLayout.compute(
      graph: graph,
      spacing: spacing,
    ),
    ConnectionsLayout.timeline => TimelineLayout.compute(
      nodes: graph.nodes,
      spacing: spacing,
    ),
    ConnectionsLayout.web => throw ArgumentError.value(
      layout,
      'layout',
      'web is a live layout',
    ),
  };
}
```

- [ ] **Step 5: Rewrite `connections_layout_controller.dart`**

```dart
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_morph.dart';
import 'package:submersion/features/connections/domain/layout/pinned_frame.dart';
import 'package:submersion/features/connections/domain/layout/static_layouts.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

/// How long a refocus or layout morph and its camera glide take.
const Duration kRefocusDuration = Duration(milliseconds: 450);
const Curve kRefocusCurve = Curves.easeInOutCubic;

/// Owns the live layout. The web layout advances a bounded number of
/// iterations per frame until it settles; every other layout is computed
/// at once and morphs in from the previous frame. Dragged nodes are pinned
/// until the graph, the layout or the spacing changes, or [relayout].
class ConnectionsLayoutController extends ChangeNotifier {
  ConnectionsLayoutController({
    required TickerProvider vsync,
    this.iterationsPerTick = 12,
  }) {
    _ticker = vsync.createTicker(_onTick);
  }

  final int iterationsPerTick;
  late final Ticker _ticker;

  ConnectionGraph _graph = ConnectionGraph.empty;
  ConnectionsLayout _layout = ConnectionsLayout.web;
  double _spacing = 1;
  WholeWebLayout? _web;

  /// A static layout's computed frame, before pins.
  LayoutFrame? _base;
  Map<NodeRef, GraphPoint> _pins = const {};
  LayoutFrame _frame = LayoutFrame.empty;

  /// The morph in flight, if any.
  LayoutFrame? _morphFrom;
  LayoutFrame? _morphTo;
  GraphPoint? _morphOrigin;
  Duration _morphElapsed = Duration.zero;

  LayoutFrame get frame => _frame;
  ConnectionsLayout get layout => _layout;
  bool get settled => _morphTo == null && (_web?.settled ?? true);

  /// True while any node sits where the diver dropped it.
  bool get hasPins => _web?.hasPins ?? _pins.isNotEmpty;

  /// Replaces the graph, the layout or the spacing, releasing every pin.
  /// The web layout warm-starts from the previous frame when [warmStart]
  /// is true, so existing nodes barely move. Any other layout morphs from
  /// the previous frame over [kRefocusDuration] when [animate] is true, new
  /// nodes growing out of the focus.
  void setGraph(
    ConnectionGraph graph, {
    required ConnectionsLayout layout,
    NodeRef? focus,
    double spacing = 1,
    bool warmStart = true,
    bool animate = false,
  }) {
    final previous = _frame;
    _graph = graph;
    _layout = layout;
    _spacing = spacing;
    _pins = const {};
    _morphTo = null;
    _morphFrom = null;
    if (layout == ConnectionsLayout.web) {
      _base = null;
      _web = WholeWebLayout(
        nodes: _byDives(graph),
        edges: graph.edges,
        initialPositions: warmStart ? previous.positions : const {},
        spacing: spacing,
      );
      _frame = _web!.frame;
      _syncTicker();
      notifyListeners();
      return;
    }
    _web = null;
    final target = StaticLayouts.compute(
      layout,
      graph: graph,
      focus: focus,
      spacing: spacing,
    );
    _base = target;
    if (animate && previous.positions.isNotEmpty) {
      _morphFrom = previous;
      _morphTo = target;
      _morphOrigin = focus == null
          ? null
          : previous.positions[focus] ?? target.positions[focus];
      _morphElapsed = Duration.zero;
      _frame = LayoutMorph.at(
        from: previous,
        to: target,
        t: 0,
        origin: _morphOrigin,
      );
      _stopTicker();
      _ticker.start();
    } else {
      _frame = target;
      _stopTicker();
    }
    notifyListeners();
  }

  /// Puts [ref] at [to] and keeps it there. A morph in flight finishes at
  /// once first, so the pin lands on the layout the diver is heading to.
  void moveNode(NodeRef ref, GraphPoint to) {
    final web = _web;
    if (web != null) {
      web.moveNode(ref, to);
      _frame = web.frame;
      _syncTicker();
      notifyListeners();
      return;
    }
    final base = _base;
    if (base == null) return;
    if (_morphTo != null) {
      _morphTo = null;
      _morphFrom = null;
      _stopTicker();
    }
    _pins = {..._pins, ref: to};
    _frame = PinnedFrame.apply(base, _pins);
    notifyListeners();
  }

  /// Releases every pin: the web lays the graph out again from its seed, a
  /// static layout returns to its computed frame.
  void relayout() {
    if (_layout == ConnectionsLayout.web) {
      _web = WholeWebLayout(
        nodes: _byDives(_graph),
        edges: _graph.edges,
        spacing: _spacing,
      );
      _frame = _web!.frame;
      _syncTicker();
      notifyListeners();
      return;
    }
    final base = _base;
    if (base == null || _pins.isEmpty) return;
    _pins = const {};
    _frame = base;
    notifyListeners();
  }

  /// Brings the layout to rest at once: a morph jumps to its target and a
  /// running force layout iterates until it settles. The share image paints
  /// this, so it never catches nodes mid-move or half grown in.
  LayoutFrame settleNow() {
    if (settled) return _frame;
    final target = _morphTo;
    if (target != null) {
      _frame = target;
      _morphTo = null;
      _morphFrom = null;
    } else {
      final web = _web!;
      // The force layout caps its own iterations, so this always ends.
      while (!web.settled) {
        web.advance(iterationsPerTick);
      }
      _frame = web.frame;
    }
    _stopTicker();
    notifyListeners();
    return _frame;
  }

  /// One tick's worth of work without a ticker, for tests: [iterations] of
  /// the force layout, or [elapsed] of the morph.
  void stepForTest([int? iterations, Duration elapsed = Duration.zero]) {
    if (_morphTo != null) {
      _advanceMorph(_morphElapsed + elapsed);
      return;
    }
    _advance(iterations ?? iterationsPerTick);
  }

  void _onTick(Duration elapsed) {
    if (_morphTo != null) {
      _advanceMorph(elapsed);
      return;
    }
    _advance(iterationsPerTick);
  }

  void _advanceMorph(Duration elapsed) {
    final to = _morphTo!;
    _morphElapsed = elapsed;
    final raw = elapsed.inMicroseconds / kRefocusDuration.inMicroseconds;
    if (raw >= 1) {
      _frame = to;
      _morphTo = null;
      _morphFrom = null;
      _stopTicker();
    } else {
      _frame = LayoutMorph.at(
        from: _morphFrom!,
        to: to,
        t: kRefocusCurve.transform(raw),
        origin: _morphOrigin,
      );
    }
    notifyListeners();
  }

  void _advance(int iterations) {
    final web = _web;
    if (web == null || web.settled) {
      _stopTicker();
      return;
    }
    web.advance(iterations);
    _frame = web.frame;
    if (web.settled) _stopTicker();
    notifyListeners();
  }

  void _syncTicker() {
    if (settled) {
      _stopTicker();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _stopTicker() {
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Busiest first, then by name, so the island grid leads with the
  /// entities the diver knows best.
  static List<NodeRef> _byDives(ConnectionGraph graph) =>
      ([...graph.nodes]..sort((a, b) {
            final byDives = b.diveCount.compareTo(a.diveCount);
            return byDives != 0 ? byDives : a.label.compareTo(b.label);
          }))
          .map((n) => n.ref)
          .toList();
}
```

- [ ] **Step 6: Run the controller, canvas and page tests**

Run: `flutter test test/features/connections/presentation/`
Expected: PASS. The old "ego mode is settled immediately" test still passes (radial is a static layout). If the old test "moveNode pins and relayout releases" asserted that `moveNode` in ego did nothing, change that one expectation to the new behaviour (it now moves) and say so in the commit body.

- [ ] **Step 7: Commit**

```bash
git add lib/features/connections/domain/layout/static_layouts.dart lib/features/connections/presentation/providers/connections_layout_controller.dart lib/features/connections/presentation/pages/connections_page.dart test/features/connections/presentation/
git commit -m "feat(connections): lay out by any layout, morph between them, pin in every layout"
```

---

### Task 11: Painter styling options, node size and timeline guides

**Files:**
- Modify: `lib/features/connections/presentation/canvas/node_metrics.dart`
- Modify: `lib/features/connections/presentation/canvas/connections_painter.dart`
- Modify: `lib/features/connections/presentation/canvas/connections_canvas.dart` (new params passed to the painter and `_radiusOf`)
- Modify: `lib/features/connections/presentation/share/connections_share_renderer.dart` (new params passed through)
- Test: `test/features/connections/presentation/canvas/connections_painter_options_test.dart`, `test/features/connections/presentation/canvas/node_metrics_test.dart`

**Interfaces:**
- Consumes: `LabelMode`, `NodeSizeMode`, `EdgeMode` (Task 1), `LayoutGuide` (Task 4).
- Produces: `NodeMetrics.uniformRadius = 14`, `NodeMetrics.radiusIn(NodeSizeMode mode, int diveCount, int maxDiveCount)`.
- Produces: `ConnectionsPainter({..., LabelMode labels = LabelMode.auto, NodeSizeMode nodeSize = NodeSizeMode.byDives, EdgeMode edges = EdgeMode.weighted, Map<ConnectionKind, String> kindNames = const {}})`.
- Produces: `ConnectionsCanvas({..., LabelMode labels, NodeSizeMode nodeSize, EdgeMode edges, Map<ConnectionKind, String> kindNames, Object? layoutToken})` (layoutToken is used in Task 13).
- Produces: `ConnectionsShareRenderer.render/renderWithAssets({..., LabelMode labels = LabelMode.auto, NodeSizeMode nodeSize = NodeSizeMode.byDives, EdgeMode edges = EdgeMode.weighted, Map<ConnectionKind, String> kindNames = const {}})`.

- [ ] **Step 1: Write the failing tests**

In `node_metrics_test.dart`:

```dart
  test('uniform size ignores dive counts', () {
    expect(NodeMetrics.radiusIn(NodeSizeMode.uniform, 1, 50), 14);
    expect(NodeMetrics.radiusIn(NodeSizeMode.uniform, 50, 50), 14);
    expect(
      NodeMetrics.radiusIn(NodeSizeMode.byDives, 50, 50),
      NodeMetrics.radiusFor(50, 50),
    );
  });
```

New file `connections_painter_options_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_guide.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

/// Records every canvas call by name; a label draws one halo rounded rect.
class _Recording implements Canvas {
  final calls = <Invocation>[];
  int count(Symbol name) => calls.where((c) => c.memberName == name).length;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return null;
  }
}

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  final graph = ConnectionGraph(
    nodes: [
      ConnectionNode(ref: _b('a'), label: 'Ann', diveCount: 5),
      ConnectionNode(ref: _b('b'), label: 'Bob', diveCount: 2),
      ConnectionNode(ref: _b('c'), label: 'Cy', diveCount: 1),
    ],
    edges: [
      ConnectionEdge(
        source: _b('a'),
        target: _b('b'),
        weight: 3,
        firstDiveAt: DateTime.utc(2024),
        lastDiveAt: DateTime.utc(2024),
      ),
    ],
  );
  LayoutFrame frame({List<LayoutGuide> guides = const []}) =>
      LayoutFrame.fromPositions({
        _b('a'): const GraphPoint(0, 0),
        _b('b'): const GraphPoint(300, 0),
        _b('c'): const GraphPoint(0, 300),
      }, settled: true, guides: guides);

  _Recording paint({
    LabelMode labels = LabelMode.auto,
    EdgeMode edges = EdgeMode.weighted,
    NodeSizeMode nodeSize = NodeSizeMode.byDives,
    GraphSelection? selection,
    double scale = 1,
    List<LayoutGuide> guides = const [],
  }) {
    final rec = _Recording();
    ConnectionsPainter(
      graph: graph,
      frame: frame(guides: guides),
      viewport: GraphViewport(scale: scale, offset: const Offset(50, 50)),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
      haloColor: Colors.white,
      selection: selection,
      maxLabelsAtLowZoom: 1,
      labels: labels,
      edges: edges,
      nodeSize: nodeSize,
      kindNames: const {ConnectionKind.buddy: 'Buddies'},
    ).paint(rec, const Size(800, 800));
    return rec;
  }

  test('labels off draws none but the selection and its neighbours', () {
    expect(paint(labels: LabelMode.off).count(#drawRRect), 0);
    expect(
      paint(labels: LabelMode.off, selection: NodeSelection(_b('a')))
          .count(#drawRRect),
      2,
    );
  });

  test('labels all ignores the low-zoom cap', () {
    expect(paint(scale: 0.3).count(#drawRRect), 1);
    expect(paint(scale: 0.3, labels: LabelMode.all).count(#drawRRect), 3);
  });

  test('selected-only edges appear only for the selection', () {
    expect(paint(edges: EdgeMode.selectedOnly).count(#drawLine), 0);
    expect(
      paint(edges: EdgeMode.selectedOnly, selection: NodeSelection(_b('a')))
          .count(#drawLine),
      1,
    );
  });

  test('thin edges are one pixel', () {
    final line = paint(edges: EdgeMode.thin)
        .calls
        .singleWhere((c) => c.memberName == #drawLine);
    expect((line.positionalArguments[2] as Paint).strokeWidth, 1);
  });

  test('uniform node size draws every disc at the same radius', () {
    final radii = paint(nodeSize: NodeSizeMode.uniform)
        .calls
        .where((c) => c.memberName == #drawCircle)
        .map((c) => c.positionalArguments[1] as double)
        .toSet();
    expect(radii, {14.0});
  });

  test('guides are drawn as text', () {
    final without = paint().count(#drawParagraph);
    final withGuides = paint(
      guides: const [
        YearGuide(2020, GraphPoint(0, -70)),
        LaneGuide(ConnectionKind.buddy, GraphPoint(-70, 0)),
      ],
    ).count(#drawParagraph);
    expect(withGuides - without, 2);
  });

  test('shouldRepaint reacts to every display option', () {
    ConnectionsPainter p({
      LabelMode labels = LabelMode.auto,
      EdgeMode edges = EdgeMode.weighted,
      NodeSizeMode nodeSize = NodeSizeMode.byDives,
    }) => ConnectionsPainter(
      graph: graph,
      frame: frame(),
      viewport: const GraphViewport(),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12),
      labels: labels,
      edges: edges,
      nodeSize: nodeSize,
    );
    expect(p().shouldRepaint(p(labels: LabelMode.off)), isTrue);
    expect(p().shouldRepaint(p(edges: EdgeMode.thin)), isTrue);
    expect(p().shouldRepaint(p(nodeSize: NodeSizeMode.uniform)), isTrue);
    expect(p().shouldRepaint(p()), isFalse);
  });

  test('the recording canvas is a real canvas stand-in', () {
    // Guards the harness: a paint into a real recorder must not throw.
    final recorder = ui.PictureRecorder();
    ConnectionsPainter(
      graph: graph,
      frame: frame(guides: const [YearGuide(2020, GraphPoint(0, -70))]),
      viewport: const GraphViewport(),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12),
      labels: LabelMode.all,
      edges: EdgeMode.selectedOnly,
      nodeSize: NodeSizeMode.uniform,
    ).paint(Canvas(recorder), const Size(400, 400));
    recorder.endRecording().dispose();
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/connections/presentation/canvas/connections_painter_options_test.dart test/features/connections/presentation/canvas/node_metrics_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement `NodeMetrics`**

```dart
  /// Every node's radius when the diver picks a uniform size: big enough
  /// for photos and initials to show.
  static const double uniformRadius = 14;

  static double radiusIn(NodeSizeMode mode, int diveCount, int maxDiveCount) =>
      mode == NodeSizeMode.uniform
      ? uniformRadius
      : radiusFor(diveCount, maxDiveCount);
```

(import `connections_display.dart`).

- [ ] **Step 4: Implement the painter options**

Add the four constructor parameters and fields:

```dart
    this.labels = LabelMode.auto,
    this.nodeSize = NodeSizeMode.byDives,
    this.edges = EdgeMode.weighted,
    this.kindNames = const {},
```

```dart
  /// Which labels to draw.
  final LabelMode labels;

  /// How big each disc is.
  final NodeSizeMode nodeSize;

  /// How edges are drawn.
  final EdgeMode edges;

  /// Lane guide text per kind, in the diver's language.
  final Map<ConnectionKind, String> kindNames;
```

`radiusOf` uses `NodeMetrics.radiusIn(nodeSize, n.diveCount, graph.maxDiveCount)`.

In `paint`, before the edge loop, draw guides:

```dart
    _paintGuides(canvas, ink);
```

```dart
  void _paintGuides(Canvas canvas, Color ink) {
    for (final g in frame.guides) {
      final text = switch (g) {
        YearGuide(:final year) => '$year',
        LaneGuide(:final kind) => kindNames[kind] ?? kind.name,
      };
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            color: ink.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final at = viewport.toScreen(g.at);
      final topLeft = switch (g) {
        YearGuide() => at - Offset(tp.width / 2, tp.height / 2),
        LaneGuide() => at - Offset(tp.width, tp.height / 2),
      };
      tp.paint(canvas, topLeft);
      tp.dispose();
    }
  }
```

In the edge loop, after computing `onSelection`:

```dart
      final touchesHover = hovered != null && e.touches(hovered!);
      if (edges == EdgeMode.selectedOnly && !onSelection && !touchesHover) {
        continue;
      }
      final thin = edges == EdgeMode.thin;
```

and use `(thin ? 0.5 : NodeMetrics.edgeOpacityFor(e.weight, graph.maxWeight))` for the base alpha and `(thin ? 1.0 : NodeMetrics.edgeWidthFor(e.weight, graph.maxWeight)) * (onSelection && !thin ? 1.4 : 1)` for the stroke width.

Replace the label selection block (from `final allowed = ...` to `final visible = ...`) with:

```dart
    final forced = {?selectedNode, ...lit, ?hovered};
    final allowed = switch (labels) {
      LabelMode.off => [
        for (final c in labelCandidates)
          if (forced.contains(c.ref)) c,
      ],
      LabelMode.all => labelCandidates,
      LabelMode.auto =>
        viewport.scale < labelZoomThreshold
            ? labelCandidates.take(maxLabelsAtLowZoom).toList()
            : labelCandidates,
    };
    final ranked = [
      ...allowed.where((c) => forced.contains(c.ref)),
      ...allowed.where((c) => !forced.contains(c.ref)),
    ];
    final visible = labels == LabelMode.all
        ? {for (final c in ranked) c.ref}
        : LabelCollision.visible(ranked, obstacles: discs, exempt: forced);
```

Add `old.labels != labels || old.nodeSize != nodeSize || old.edges != edges || !mapEquals(old.kindNames, kindNames)` to `shouldRepaint`.

- [ ] **Step 5: Pass the options through the canvas and the share renderer**

`ConnectionsCanvas`: add constructor parameters `this.labels = LabelMode.auto`, `this.nodeSize = NodeSizeMode.byDives`, `this.edges = EdgeMode.weighted`, `this.kindNames = const {}`, `this.layoutToken` with fields and docs; pass the first four to `ConnectionsPainter`; `_radiusOf` becomes

```dart
    return NodeMetrics.radiusIn(
          widget.nodeSize,
          node.diveCount,
          widget.graph.maxDiveCount,
        ) *
        _viewport.scale.clamp(0.5, 1.5);
```

`ConnectionsShareRenderer.renderWithAssets` and `render`: add the same four named parameters with the same defaults, forward them from `renderWithAssets` to `render`, and pass them to its `ConnectionsPainter`.

- [ ] **Step 6: Run the canvas and share tests**

Run: `flutter test test/features/connections/presentation/canvas/ test/features/connections/presentation/share/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/connections/presentation/canvas/ lib/features/connections/presentation/share/connections_share_renderer.dart test/features/connections/presentation/canvas/
git commit -m "feat(connections): draw labels, node sizes, edges and timeline guides by the display settings"
```

---

### Task 12: Drag a node with a mouse or stylus

**Files:**
- Modify: `lib/features/connections/presentation/canvas/connections_canvas.dart`
- Test: `test/features/connections/presentation/canvas/connections_canvas_drag_test.dart`

**Interfaces:**
- Consumes: `ConnectionsLayoutController.moveNode` in every layout (Task 10).
- Produces: no new public API. Inside the canvas: `_NodeDragGestureRecognizer`, `_beginDrag(Offset)`, `_dragTo(Offset)`, `_endDrag()`; `_TouchScaleGestureRecognizer` declines mouse and stylus pointers that land on a node; the `MouseRegion` shows grab cursors.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

const _me = NodeRef(ConnectionKind.buddy, 'me');

final _graph = ConnectionGraph(
  nodes: [ConnectionNode(ref: _me, label: 'Me', diveCount: 4)],
  edges: const [],
);

class _Host extends StatefulWidget {
  const _Host({required this.onSelect, required this.onFocus});
  final ValueChanged<GraphSelection?> onSelect;
  final ValueChanged<NodeRef> onFocus;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final controller = ConnectionsLayoutController(vsync: this)
    ..setGraph(_graph, layout: ConnectionsLayout.radial, focus: _me);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400,
        child: ConnectionsCanvas(
          graph: _graph,
          controller: controller,
          colors: const ConnectionKindColors({}, Colors.grey),
          onSelect: widget.onSelect,
          onFocus: widget.onFocus,
        ),
      ),
    ),
  );
}

ConnectionsLayoutController _controller(WidgetTester tester) =>
    (tester.state(find.byType(_Host)) as _HostState).controller;

void main() {
  testWidgets('a mouse press-drag on a node moves it and selects it', (
    tester,
  ) async {
    GraphSelection? selected;
    await tester.pumpWidget(_Host(onSelect: (s) => selected = s, onFocus: (_) {}));
    await tester.pumpAndSettle();
    final centre = tester.getCenter(find.byType(ConnectionsCanvas));
    final g = await tester.startGesture(centre, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(30, 0));
    await g.up();
    await tester.pump();
    final p = _controller(tester).frame.positions[_me]!;
    expect(p.x, greaterThan(20));
    expect(selected, const NodeSelection(_me));
  });

  testWidgets('a mouse drag on empty canvas pans and leaves the node', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pumpAndSettle();
    final corner = tester.getTopLeft(find.byType(ConnectionsCanvas)) +
        const Offset(20, 20);
    final g = await tester.startGesture(corner, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pump();
    expect(_controller(tester).frame.positions[_me], GraphPoint.zero);
  });

  testWidgets('a touch long-press then drag still moves the node', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pumpAndSettle();
    final centre = tester.getCenter(find.byType(ConnectionsCanvas));
    final g = await tester.startGesture(centre);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pump();
    expect(_controller(tester).frame.positions[_me]!.x, greaterThan(20));
  });

  testWidgets('a mouse click selects and a double click centres', (
    tester,
  ) async {
    GraphSelection? selected;
    NodeRef? focused;
    await tester.pumpWidget(
      _Host(onSelect: (s) => selected = s, onFocus: (r) => focused = r),
    );
    await tester.pumpAndSettle();
    final centre = tester.getCenter(find.byType(ConnectionsCanvas));
    await tester.tapAt(centre, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(selected, const NodeSelection(_me));
    await tester.tapAt(centre, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(centre, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(focused, _me);
  });

  testWidgets('the cursor is a grab hand over a node', (tester) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(ConnectionsCanvas)));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.grab,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/presentation/canvas/connections_canvas_drag_test.dart`
Expected: the mouse drag test and the cursor test FAIL (a mouse drag on the node pans; no cursor); the touch and click tests pass already.

- [ ] **Step 3: Implement**

In `connections_canvas.dart`, add the drag helpers to the state:

```dart
  void _beginDrag(Offset p) {
    _autoFit = false;
    _userMoved = true;
    _glide.stop();
    final node = _nodeAt(p);
    setState(() => _dragging = node);
    if (node != null) widget.onSelect(NodeSelection(node));
  }

  void _dragTo(Offset p) {
    final node = _dragging;
    if (node == null) return;
    widget.controller.moveNode(node, _viewport.toGraph(p));
  }

  void _endDrag() {
    if (_dragging != null) setState(() => _dragging = null);
  }
```

Rewrite the long-press handlers to call them (`onLongPressStart: (d) => _beginDrag(d.localPosition)`, `onLongPressMoveUpdate: (d) => _dragTo(d.localPosition)`, `onLongPressEnd: (_) => _endDrag()`, `onLongPressCancel: _endDrag`).

Put this entry FIRST in the `gestures` map so its pointer route sees moves before the scale recognizer:

```dart
            _NodeDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _NodeDragGestureRecognizer
                >(
                  () => _NodeDragGestureRecognizer(
                    isOnNode: (p) => _nodeAt(p) != null,
                  ),
                  (r) => r
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = (d) => _beginDrag(d.localPosition)
                    ..onUpdate = (d) => _dragTo(d.localPosition)
                    ..onEnd = (_) => _endDrag()
                    ..onCancel = _endDrag,
                ),
```

Give `_TouchScaleGestureRecognizer` the same `isOnNode` callback and decline precise pointers on a node, so a mouse press on a node never pans:

```dart
/// Refuses trackpad pan-zoom so the Listener above handles it once (same
/// arrangement as dive_3d_interactive_viewport.dart), and refuses a mouse
/// or stylus press on a node, which [_NodeDragGestureRecognizer] owns.
class _TouchScaleGestureRecognizer extends ScaleGestureRecognizer {
  _TouchScaleGestureRecognizer({
    super.supportedDevices,
    required this.isOnNode,
  });

  final bool Function(Offset local) isOnNode;

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) &&
      !(_precise.contains(event.kind) && isOnNode(event.localPosition));
}

const Set<PointerDeviceKind> _precise = {
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

/// A press-drag that starts on a node, for mouse and stylus only. Touch
/// keeps long-press, so a finger landing on a node can still pan the map.
class _NodeDragGestureRecognizer extends PanGestureRecognizer {
  _NodeDragGestureRecognizer({required this.isOnNode})
    : super(supportedDevices: _precise);

  final bool Function(Offset local) isOnNode;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) && isOnNode(event.localPosition);
}
```

and construct the scale recognizer with `isOnNode: (p) => _nodeAt(p) != null`. Keep the `if (_dragging != null) return;` guard in its `onUpdate`.

On the `MouseRegion`, add:

```dart
            cursor: _dragging != null
                ? SystemMouseCursors.grabbing
                : _hovered != null
                ? SystemMouseCursors.grab
                : MouseCursor.defer,
```

- [ ] **Step 4: Run the canvas tests**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: PASS, including the existing pan, tap, double tap and refocus tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/presentation/canvas/connections_canvas.dart test/features/connections/presentation/canvas/connections_canvas_drag_test.dart
git commit -m "feat(connections): drag a node with a mouse or stylus"
```

---

### Task 13: Wire the display into the page; move the graph stack out

**Files:**
- Create: `lib/features/connections/presentation/pages/connections_graph_stack.dart`
- Modify: `lib/features/connections/domain/entities/connection_graph.dart` (`withoutUnconnected`)
- Modify: `lib/features/connections/presentation/canvas/connections_canvas.dart` (`layoutToken` refits the camera)
- Modify: `lib/features/connections/presentation/pages/connections_page.dart`
- Test: `test/features/connections/domain/entities/connection_graph_test.dart`, `test/features/connections/presentation/pages/connections_page_display_test.dart`

**Interfaces:**
- Consumes: `connectionsDisplayProvider` (Task 2), controller API (Task 10), canvas params (Task 11), share params (Task 11).
- Produces: `ConnectionGraph withoutUnconnected({NodeRef? keep})`; `ConnectionsGraphStack` widget (constructor below).

- [ ] **Step 1: Write the failing tests**

In `connection_graph_test.dart`:

```dart
  group('withoutUnconnected', () {
    NodeRef b(String id) => NodeRef(ConnectionKind.buddy, id);
    ConnectionNode n(String id) =>
        ConnectionNode(ref: b(id), label: id, diveCount: 1);
    final edge = ConnectionEdge(
      source: b('a'),
      target: b('b'),
      weight: 1,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    );

    test('drops nodes with no edge, keeps the rest', () {
      final g = ConnectionGraph(nodes: [n('a'), n('b'), n('lone')], edges: [edge]);
      expect(g.withoutUnconnected().nodes.map((x) => x.ref.id), ['a', 'b']);
    });

    test('keeps the focus even with no edge', () {
      final g = ConnectionGraph(nodes: [n('a'), n('b'), n('me')], edges: [edge]);
      expect(
        g.withoutUnconnected(keep: b('me')).nodes.map((x) => x.ref.id),
        ['a', 'b', 'me'],
      );
    });

    test('returns itself when nothing is dropped or everything would be', () {
      final linked = ConnectionGraph(nodes: [n('a'), n('b')], edges: [edge]);
      expect(identical(linked.withoutUnconnected(), linked), isTrue);
      final loose = ConnectionGraph(nodes: [n('x'), n('y')], edges: const []);
      expect(identical(loose.withoutUnconnected(), loose), isTrue);
    });
  });
```

New file `connections_page_display_test.dart`: copy the `_pump` helper and `_graph` from `connections_page_test.dart` (add one unconnected node `ConnectionNode(ref: _b('lone'), label: 'Lone', diveCount: 1)` to `_graph`), plus:

```dart
  testWidgets('the chosen layout and spacing reach the layout controller', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.withLayout(ConnectionsLayout.columns, around: false));
    await tester.pumpAndSettle();
    final canvas = tester.widget<ConnectionsCanvas>(find.byType(ConnectionsCanvas));
    expect(canvas.controller.layout, ConnectionsLayout.columns);
  });

  testWidgets('hide unconnected removes the lone node from the canvas only', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.copyWith(hideUnconnected: true));
    await tester.pumpAndSettle();
    final canvas = tester.widget<ConnectionsCanvas>(find.byType(ConnectionsCanvas));
    expect(canvas.graph.nodes.map((n) => n.ref.id), isNot(contains('lone')));
    expect(canvas.controller.frame.positions.keys.map((r) => r.id),
        isNot(contains('lone')));
  });

  testWidgets('the styling reaches the canvas', (tester) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    await c.read(connectionsDisplayProvider.notifier).update(
      (d) => d.copyWith(
        labels: LabelMode.off,
        nodeSize: NodeSizeMode.uniform,
        edges: EdgeMode.thin,
      ),
    );
    await tester.pumpAndSettle();
    final canvas = tester.widget<ConnectionsCanvas>(find.byType(ConnectionsCanvas));
    expect(canvas.labels, LabelMode.off);
    expect(canvas.nodeSize, NodeSizeMode.uniform);
    expect(canvas.edges, EdgeMode.thin);
  });

  testWidgets('around mode shows Lay out again only while a node is pinned', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      location: '/insights/connections?mode=around&focus=buddy:jane',
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Lay out again'), findsNothing);
    final canvas = tester.widget<ConnectionsCanvas>(find.byType(ConnectionsCanvas));
    canvas.controller.moveNode(_b('ken'), const GraphPoint(1, 1));
    await tester.pump();
    expect(find.byTooltip('Lay out again'), findsOneWidget);
    await tester.tap(find.byTooltip('Lay out again'));
    await tester.pump();
    expect(find.byTooltip('Lay out again'), findsNothing);
    expect(c.read(connectionsDisplayProvider), isNotNull);
  });
```

(Imports: `connections_display_provider.dart`, `connections_display.dart`, `connections_layout.dart`, `connections_canvas.dart`, `graph_point.dart`. `ConnectionsRouteArgs.fromQuery` reads `mode` and `focus`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/connections/domain/entities/connection_graph_test.dart test/features/connections/presentation/pages/connections_page_display_test.dart`
Expected: FAIL.

- [ ] **Step 3: `ConnectionGraph.withoutUnconnected`**

```dart
  /// This graph without nodes that have no edge, keeping [keep] (the focus)
  /// whatever its edges. Returns `this` when nothing would be dropped, or
  /// when everything would be (hiding every node helps nobody).
  ConnectionGraph withoutUnconnected({NodeRef? keep}) {
    final linked = <NodeRef>{?keep};
    for (final e in edges) {
      linked
        ..add(e.source)
        ..add(e.target);
    }
    final kept = [
      for (final n in nodes)
        if (linked.contains(n.ref)) n,
    ];
    if (kept.length == nodes.length || kept.isEmpty) return this;
    return copyWith(nodes: kept);
  }
```

- [ ] **Step 4: Canvas `layoutToken`**

In `_ConnectionsCanvasState.didUpdateWidget`, split the graph-change block so a new `layoutToken` with the same graph refits the camera too:

```dart
    final graphChanged = old.graph != widget.graph;
    if (graphChanged || old.layoutToken != widget.layoutToken) {
      _autoFit = true;
      _userMoved = false;
      if (widget.animate &&
          _everFitted &&
          !MediaQuery.disableAnimationsOf(context)) {
        _glideFrom = _viewport;
        _glide.forward(from: 0);
      }
    }
    if (graphChanged) {
      _clearTextCaches();
      _decodePhotos();
    }
```

Field doc: `/// Changes when the layout or spacing changes; the camera refits as it does for a new graph.`

- [ ] **Step 5: Create `connections_graph_stack.dart`**

Move the `return Stack(children: [...])` body that `canvasArea` builds when `showCanvas` is true (the `ConnectionsCanvas`, the `InsightStrip`, the legend card, the `HiddenNodesChip`, the reload error card, the play pill and the loading bar) into:

```dart
/// The graph view: the canvas with its overlays (insight strip, legend,
/// hidden-node chip, reload error, year play pill, loading bar).
class ConnectionsGraphStack extends StatelessWidget {
  const ConnectionsGraphStack({
    super.key,
    required this.graph,
    required this.canvasGraph,
    required this.controller,
    required this.colors,
    required this.selection,
    required this.semanticsLabel,
    required this.animate,
    required this.bottomInset,
    required this.stripHeight,
    required this.belowStrip,
    required this.highlight,
    required this.groups,
    required this.insights,
    required this.wide,
    required this.display,
    required this.onSelect,
    required this.onFocus,
    required this.onGroups,
    required this.onShowAll,
    required this.reloadFailed,
    required this.onRetry,
    required this.playPill,
    required this.loading,
  });

  /// The whole map: the strip, legend and chip describe it.
  final ConnectionGraph graph;

  /// What the canvas draws: [graph], less unconnected nodes when hidden.
  final ConnectionGraph canvasGraph;
  final ConnectionsLayoutController controller;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final String semanticsLabel;
  final bool animate;
  final double bottomInset;
  final double stripHeight;
  final double belowStrip;
  final HighlightMode highlight;
  final GraphGroups groups;
  final List<InsightTile> insights;
  final bool wide;
  final ConnectionsDisplay display;
  final ValueChanged<GraphSelection?> onSelect;
  final ValueChanged<NodeRef> onFocus;
  final VoidCallback onGroups;
  final VoidCallback? onShowAll;
  final bool reloadFailed;
  final VoidCallback onRetry;
  final Widget playPill;
  final bool loading;
```

`build` returns the moved `Stack` verbatim, with these substitutions: the canvas gets `graph: canvasGraph`, `highlight: highlight`, `groupOf: groups.groupOf`, `labels: display.labels`, `nodeSize: display.nodeSize`, `edges: display.edges`, `kindNames: {for (final k in ConnectionKind.values) k: kindLabel(context.l10n, k)}`, `layoutToken: (controller.layout, display.spacing)`; `_insights` becomes `insights`; `_groups.count` becomes `groups.count`; the strip's `onGroups` becomes `onGroups`; the chip's `onShowAll` becomes `onShowAll`; the retry button calls `onRetry`; the loading bar shows when `loading`. The legend `kinds` are computed from `graph`.

- [ ] **Step 6: Page wiring**

In `connections_page.dart`:

1. Imports: `connections_display_provider.dart`, `connections_display.dart`, `connections_layout.dart`, `connections_graph_stack.dart`.
2. State fields:

```dart
  ConnectionsLayout? _laidOutLayout;
  double? _laidOutSpacing;

  /// The canvas graph for the last source, keyed like [_localize], so the
  /// layout sees the same instance on a rebuild.
  ConnectionGraph? _canvasFrom;
  bool _canvasHide = false;
  NodeRef? _canvasKeep;
  ConnectionGraph? _canvasGraph;

  ConnectionGraph _canvasGraphFor(
    ConnectionGraph graph, {
    required bool hide,
    NodeRef? keep,
  }) {
    if (identical(graph, _canvasFrom) &&
        hide == _canvasHide &&
        keep == _canvasKeep) {
      return _canvasGraph!;
    }
    _canvasFrom = graph;
    _canvasHide = hide;
    _canvasKeep = keep;
    return _canvasGraph = hide ? graph.withoutUnconnected(keep: keep) : graph;
  }
```

3. `_syncLayout`:

```dart
  void _syncLayout(
    ConnectionGraph graph,
    NodeRef? focus, {
    required ConnectionsLayout layout,
    required double spacing,
    required bool animate,
  }) {
    if (identical(_laidOut, graph) &&
        _laidOutFocus == focus &&
        _laidOutLayout == layout &&
        _laidOutSpacing == spacing) {
      return;
    }
    _laidOut = graph;
    _laidOutFocus = focus;
    _laidOutLayout = layout;
    _laidOutSpacing = spacing;
    _layout.setGraph(
      graph,
      layout: layout,
      focus: focus,
      spacing: spacing,
      animate: animate,
    );
    _hadGraph = true;
  }
```

4. In `build`, after `final focus = ...`:

```dart
    final display = ref.watch(connectionsDisplayProvider);
    final around = view.mode == ConnectionsMode.around;
    final layoutChoice = display.layoutFor(around: around);
```

and replace the `if (showCanvas) { _syncLayout(...); _story(...); }` block with:

```dart
    final canvasGraph = _canvasGraphFor(
      graph,
      hide: display.hideUnconnected,
      keep: focus,
    );
    if (showCanvas) {
      if (display.view == ConnectionsViewKind.graph) {
        _syncLayout(
          canvasGraph,
          focus,
          layout: layoutChoice,
          spacing: display.spacing,
          animate: animate,
        );
      }
      _story(graph, focus);
    }
```

5. In `canvasArea`, the `showCanvas` branch returns `ConnectionsGraphStack(...)` with the page's values (`onShowAll` as the chip had it, `onRetry: () => ref.invalidate(connectionGraphProvider(budget))`, `loading: graphAsync.isLoading`).
6. `_share` takes `ConnectionsDisplay display` and passes `labels`, `nodeSize`, `edges` and `kindNames` to `renderWithAssets`; the share button passes `display`.
7. App bar actions: the share button shows only when `display.view == ConnectionsViewKind.graph`. Replace the focus/refresh pair with:

```dart
          if (display.view == ConnectionsViewKind.graph)
            ListenableBuilder(
              listenable: _layout,
              builder: (context, _) => focus == null || _layout.hasPins
                  ? IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: l10n.connections_tooltip_relayout,
                      onPressed: _layout.relayout,
                    )
                  : const SizedBox.shrink(),
            ),
          if (focus != null)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: l10n.connections_tooltip_showWholeWeb,
              onPressed: () {
                ref
                    .read(connectionsViewProvider.notifier)
                    .update((s) => s.withMode(ConnectionsMode.map));
                ref.read(connectionsSelectionProvider.notifier).state = null;
              },
            ),
```

- [ ] **Step 7: Check the page size and run the page tests**

Run: `wc -l lib/features/connections/presentation/pages/connections_page.dart` (expect well under 601)
Run: `flutter test test/features/connections/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/connections/ test/features/connections/
git commit -m "feat(connections): apply the display settings to the graph page"
```

---

### Task 14: The Display section in the View tab

**Files:**
- Create: `lib/features/connections/presentation/panel/display_section.dart`
- Modify: `lib/features/connections/presentation/panel/view_tab.dart`
- Modify: `lib/l10n/arb/app_en.arb` (English keys after `connections_highlight_recency`)
- Test: `test/features/connections/presentation/panel/display_section_test.dart`

**Interfaces:**
- Consumes: `connectionsDisplayProvider` (Task 2), `connectionsViewProvider` (existing).
- Produces: `DisplaySection` (const, no params); `String layoutLabel(AppLocalizations l10n, ConnectionsLayout layout)`.

- [ ] **Step 1: Add the English strings**

Insert after `"connections_highlight_recency"` in `app_en.arb`:

```json
  "connections_display_title": "Display",
  "connections_layout_title": "Layout",
  "connections_layout_web": "Web",
  "connections_layout_radial": "Radial",
  "connections_layout_circle": "Circle",
  "connections_layout_columns": "Columns",
  "connections_layout_clusters": "Clusters",
  "connections_layout_timeline": "Timeline",
  "connections_labels_title": "Labels",
  "connections_labels_auto": "Auto",
  "connections_labels_all": "All",
  "connections_labels_off": "Off",
  "connections_nodeSize_title": "Node size",
  "connections_nodeSize_byDives": "By dives",
  "connections_nodeSize_uniform": "Uniform",
  "connections_edges_title": "Lines",
  "connections_edges_weighted": "Weighted",
  "connections_edges_thin": "Thin",
  "connections_edges_selectedOnly": "Selected only",
  "connections_hideUnconnected": "Hide unconnected",
  "connections_spacing_title": "Spacing",
  "connections_spacing_tight": "Tight",
  "connections_spacing_spread": "Spread",
```

Run `flutter gen-l10n` (English fallbacks for now; Task 19 translates and regenerates last).

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/panel/display_section.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: DisplaySection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('map mode offers web and not radial; a chip sets the layout', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(find.byKey(const ValueKey('layout-web')), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-radial')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('layout-timeline')));
    await tester.pumpAndSettle();
    expect(c.read(connectionsDisplayProvider).mapLayout, ConnectionsLayout.timeline);
    expect(c.read(connectionsDisplayProvider).aroundLayout, ConnectionsLayout.radial);
  });

  testWidgets('around mode offers radial and sets the around layout', (
    tester,
  ) async {
    final c = await _pump(tester);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withMode(ConnectionsMode.around));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('layout-radial')), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-web')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('layout-circle')));
    await tester.pumpAndSettle();
    expect(c.read(connectionsDisplayProvider).aroundLayout, ConnectionsLayout.circle);
  });

  testWidgets('the segments and the switch write the display', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.text('Off'));
    await tester.tap(find.text('Uniform'));
    await tester.tap(find.text('Selected only'));
    await tester.tap(find.text('Hide unconnected'));
    await tester.pumpAndSettle();
    final d = c.read(connectionsDisplayProvider);
    expect(d.labels, LabelMode.off);
    expect(d.nodeSize, NodeSizeMode.uniform);
    expect(d.edges, EdgeMode.selectedOnly);
    expect(d.hideUnconnected, isTrue);
  });

  testWidgets('spacing is written once, when the slider is let go', (
    tester,
  ) async {
    final c = await _pump(tester);
    final slider = find.byKey(const ValueKey('spacing-slider'));
    await tester.drag(slider, const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(c.read(connectionsDisplayProvider).spacing, greaterThan(1.0));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/connections/presentation/panel/display_section_test.dart`
Expected: FAIL to compile.

- [ ] **Step 4: Write `display_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

String layoutLabel(AppLocalizations l10n, ConnectionsLayout layout) =>
    switch (layout) {
      ConnectionsLayout.web => l10n.connections_layout_web,
      ConnectionsLayout.radial => l10n.connections_layout_radial,
      ConnectionsLayout.circle => l10n.connections_layout_circle,
      ConnectionsLayout.columns => l10n.connections_layout_columns,
      ConnectionsLayout.clusters => l10n.connections_layout_clusters,
      ConnectionsLayout.timeline => l10n.connections_layout_timeline,
    };

/// How the graph is drawn: layout, labels, node size, lines, unconnected
/// nodes and spacing. Shown in the View tab while the Graph view is on.
class DisplaySection extends ConsumerStatefulWidget {
  const DisplaySection({super.key});

  @override
  ConsumerState<DisplaySection> createState() => _DisplaySectionState();
}

class _DisplaySectionState extends ConsumerState<DisplaySection> {
  /// The spacing while its slider is being dragged; written on release so
  /// the map lays out once, not on every tick.
  double? _dragSpacing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final display = ref.watch(connectionsDisplayProvider);
    final around = ref.watch(
      connectionsViewProvider.select((v) => v.mode == ConnectionsMode.around),
    );
    final notifier = ref.read(connectionsDisplayProvider.notifier);
    final current = display.layoutFor(around: around);
    final offered = around
        ? ConnectionsLayout.forAround
        : ConnectionsLayout.forMap;
    return Column(
      key: const ValueKey('connections-display'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.connections_display_title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(l10n.connections_layout_title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final layout in offered)
              ChoiceChip(
                key: ValueKey('layout-${layout.name}'),
                label: Text(layoutLabel(l10n, layout)),
                selected: layout == current,
                onSelected: (_) => notifier.update(
                  (d) => d.withLayout(layout, around: around),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Segments<LabelMode>(
          title: l10n.connections_labels_title,
          options: {
            LabelMode.auto: l10n.connections_labels_auto,
            LabelMode.all: l10n.connections_labels_all,
            LabelMode.off: l10n.connections_labels_off,
          },
          selected: display.labels,
          onChanged: (v) => notifier.update((d) => d.copyWith(labels: v)),
        ),
        const SizedBox(height: 12),
        _Segments<NodeSizeMode>(
          title: l10n.connections_nodeSize_title,
          options: {
            NodeSizeMode.byDives: l10n.connections_nodeSize_byDives,
            NodeSizeMode.uniform: l10n.connections_nodeSize_uniform,
          },
          selected: display.nodeSize,
          onChanged: (v) => notifier.update((d) => d.copyWith(nodeSize: v)),
        ),
        const SizedBox(height: 12),
        _Segments<EdgeMode>(
          title: l10n.connections_edges_title,
          options: {
            EdgeMode.weighted: l10n.connections_edges_weighted,
            EdgeMode.thin: l10n.connections_edges_thin,
            EdgeMode.selectedOnly: l10n.connections_edges_selectedOnly,
          },
          selected: display.edges,
          onChanged: (v) => notifier.update((d) => d.copyWith(edges: v)),
        ),
        SwitchListTile(
          key: const ValueKey('hide-unconnected'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.connections_hideUnconnected),
          value: display.hideUnconnected,
          onChanged: (v) =>
              notifier.update((d) => d.copyWith(hideUnconnected: v)),
        ),
        Text(l10n.connections_spacing_title, style: theme.textTheme.labelLarge),
        Row(
          children: [
            Text(l10n.connections_spacing_tight, style: theme.textTheme.bodySmall),
            Expanded(
              child: Slider(
                key: const ValueKey('spacing-slider'),
                min: ConnectionsDisplay.minSpacing,
                max: ConnectionsDisplay.maxSpacing,
                divisions: 14,
                value: _dragSpacing ?? display.spacing,
                onChanged: (v) => setState(() => _dragSpacing = v),
                onChangeEnd: (v) {
                  setState(() => _dragSpacing = null);
                  notifier.update((d) => d.copyWith(spacing: v));
                },
              ),
            ),
            Text(l10n.connections_spacing_spread, style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _Segments<T> extends StatelessWidget {
  const _Segments({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final MapEntry(:key, :value) in options.entries)
              ButtonSegment(value: key, label: Text(value)),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.single),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Mount it in the View tab**

In `view_tab.dart` add the imports and, after the highlight control:

```dart
        HighlightModeControl(groupCount: groupCount),
        if (graphView) ...[const SizedBox(height: 16), const DisplaySection()],
        const SizedBox(height: 12),
```

with `final graphView = ref.watch(connectionsDisplayProvider.select((d) => d.view == ConnectionsViewKind.graph));` at the top of `build`.

- [ ] **Step 6: Run the panel tests**

Run: `flutter test test/features/connections/presentation/panel/`
Expected: PASS. If an existing View tab test counts widgets that now repeat (for example `find.text('Auto')`), narrow that finder with `find.descendant(of: find.byKey(...))` rather than changing the expectation.

- [ ] **Step 7: Commit**

```bash
git add lib/features/connections/presentation/panel/ lib/l10n/arb/ test/features/connections/presentation/panel/display_section_test.dart
git commit -m "feat(connections): add the Display section to the View tab"
```

---

### Task 15: View switch, table header bar and graph-only chrome

**Files:**
- Create: `lib/features/connections/presentation/views/view_mode_button.dart`
- Create: `lib/features/connections/presentation/views/table_header_bar.dart`
- Modify: `lib/features/connections/presentation/pages/connections_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/connections/presentation/views/view_mode_button_test.dart`, `test/features/connections/presentation/pages/connections_page_display_test.dart`

**Interfaces:**
- Consumes: `connectionsDisplayProvider`; `PairsTable`, `EntitiesTable`, `ConnectionsMatrix` are wired here but built in Tasks 16 to 18, so in this task the page shows `const SizedBox.shrink(key: ValueKey('connections-view-<name>'))` placeholders for them, replaced in those tasks.
- Produces: `ViewModeButton` (const, no params), `static IconData ViewModeButton.iconFor(ConnectionsViewKind)`, `static String ViewModeButton.labelFor(AppLocalizations, ConnectionsViewKind)`; `TableHeaderBar({required ConnectionGraph graph, required VoidCallback? onShowAll})`.

- [ ] **Step 1: Add the English strings** (after the Task 14 block)

```json
  "connections_view_tooltip": "Change view",
  "connections_view_graph": "Graph",
  "connections_view_pairs": "Pairs",
  "connections_view_entities": "Entities",
  "connections_view_matrix": "Matrix",
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

`view_mode_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/views/view_mode_button.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('the menu lists four views and writes the choice', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(appBar: AppBar(actions: const [ViewModeButton()])),
        ),
      ),
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    expect(find.byIcon(ViewModeButton.iconFor(ConnectionsViewKind.graph)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('connections-view-button')));
    await tester.pumpAndSettle();
    for (final label in ['Graph', 'Pairs', 'Entities', 'Matrix']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Matrix'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsDisplayProvider).view, ConnectionsViewKind.matrix);
    expect(find.byIcon(ViewModeButton.iconFor(ConnectionsViewKind.matrix)), findsOneWidget);
  });
}
```

Append to `connections_page_display_test.dart`:

```dart
  testWidgets('a table view hides the graph chrome and keeps the play pill', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.copyWith(view: ConnectionsViewKind.pairs));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionsCanvas), findsNothing);
    expect(find.byType(InsightStrip), findsNothing);
    expect(find.byKey(const ValueKey('connections-share')), findsNothing);
    expect(find.byTooltip('Lay out again'), findsNothing);
    expect(find.byType(YearPlayPill), findsOneWidget);
    expect(find.byType(TableHeaderBar), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-display')), findsNothing);
  });
```

(import `year_play_pill.dart`, `insight_strip.dart`, `table_header_bar.dart`.)

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/connections/presentation/views/view_mode_button_test.dart test/features/connections/presentation/pages/connections_page_display_test.dart`
Expected: FAIL.

- [ ] **Step 4: Write `view_mode_button.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App bar menu switching the page between the graph and its tables. Its
/// items look like [ListViewModeToggle]'s: icon and label, the current one
/// in the primary colour.
class ViewModeButton extends ConsumerWidget {
  const ViewModeButton({super.key});

  static IconData iconFor(ConnectionsViewKind view) => switch (view) {
    ConnectionsViewKind.graph => Icons.hub_outlined,
    ConnectionsViewKind.pairs => Icons.compare_arrows,
    ConnectionsViewKind.entities => Icons.format_list_bulleted,
    ConnectionsViewKind.matrix => Icons.grid_on,
  };

  static String labelFor(AppLocalizations l10n, ConnectionsViewKind view) =>
      switch (view) {
        ConnectionsViewKind.graph => l10n.connections_view_graph,
        ConnectionsViewKind.pairs => l10n.connections_view_pairs,
        ConnectionsViewKind.entities => l10n.connections_view_entities,
        ConnectionsViewKind.matrix => l10n.connections_view_matrix,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    final view = ref.watch(connectionsDisplayProvider.select((d) => d.view));
    return PopupMenuButton<ConnectionsViewKind>(
      key: const ValueKey('connections-view-button'),
      icon: Icon(iconFor(view)),
      tooltip: l10n.connections_view_tooltip,
      initialValue: view,
      onSelected: (v) => ref
          .read(connectionsDisplayProvider.notifier)
          .update((d) => d.copyWith(view: v)),
      itemBuilder: (context) => [
        for (final v in ConnectionsViewKind.values)
          PopupMenuItem(
            value: v,
            child: Row(
              children: [
                Icon(iconFor(v), size: 20, color: v == view ? primary : null),
                const SizedBox(width: 12),
                Text(
                  labelFor(l10n, v),
                  style: v == view
                      ? TextStyle(color: primary, fontWeight: FontWeight.w600)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Write `table_header_bar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The line above a table or the matrix: how much is on the map, and how
/// much the node budget left out, with Show all.
class TableHeaderBar extends StatelessWidget {
  const TableHeaderBar({
    super.key,
    required this.graph,
    required this.onShowAll,
  });

  final ConnectionGraph graph;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.connections_semantics_summary(
                graph.nodes.length,
                graph.edges.length,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (graph.hiddenNodeCount > 0)
            HiddenNodesChip(count: graph.hiddenNodeCount, onShowAll: onShowAll),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Page wiring**

1. App bar: put `const ViewModeButton()` first in `actions`. The share `IconButton` (key `connections-share`) is wrapped in `if (display.view == ConnectionsViewKind.graph)`.
2. In `canvasArea`, when `showCanvas` and `display.view != ConnectionsViewKind.graph`, return:

```dart
        Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TableHeaderBar(graph: graph, onShowAll: showAll),
                    const Divider(height: 1),
                    Expanded(child: tableView(display.view)),
                  ],
                ),
              ),
            ),
            playPill,
            if (graphAsync.isLoading)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        )
```

where `showAll` is the same callback the chip gets (`budget >= ConnectionsPage.maxBudget ? null : () => _showAll(graph.nodes.length + graph.hiddenNodeCount)`) and

```dart
    Widget tableView(ConnectionsViewKind kind) => switch (kind) {
      ConnectionsViewKind.pairs =>
        const SizedBox.shrink(key: ValueKey('connections-view-pairs')),
      ConnectionsViewKind.entities =>
        const SizedBox.shrink(key: ValueKey('connections-view-entities')),
      ConnectionsViewKind.matrix =>
        const SizedBox.shrink(key: ValueKey('connections-view-matrix')),
      ConnectionsViewKind.graph => const SizedBox.shrink(),
    };
```

The non-graph views read the full `graph`, never `canvasGraph`.

- [ ] **Step 7: Run tests**

Run: `flutter test test/features/connections/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/connections/ lib/l10n/arb/ test/features/connections/
git commit -m "feat(connections): switch between the graph and table views from the app bar"
```

---

### Task 16: Table rows, table parts and the Pairs table

**Files:**
- Create: `lib/features/connections/presentation/views/table_rows.dart`
- Create: `lib/features/connections/presentation/views/table_parts.dart`
- Create: `lib/features/connections/presentation/views/pairs_table.dart`
- Modify: `lib/features/connections/presentation/pages/connections_page.dart` (`tableView` pairs arm)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/connections/presentation/views/table_rows_test.dart`, `test/features/connections/presentation/views/pairs_table_test.dart`

**Interfaces:**
- Produces: `enum PairsColumn { a, b, shared, last, first }`, `enum EntitiesColumn { name, kind, dives, links, strongest, first }`, `class EntityRow { ConnectionNode node; int links; ConnectionNode? strongest; int strongestWeight; }`, `abstract final class ConnectionsTableRows { static List<ConnectionEdge> pairs(ConnectionGraph, PairsColumn, {required bool ascending}); static List<EntityRow> entities(ConnectionGraph, EntitiesColumn, {required bool ascending}); static bool startsAscending(Enum column); }`.
- Produces: `class TableColumnSpec<T extends Enum>(T id, String label, {int flex = 2, bool numeric = false})`, `SortableHeader<T extends Enum>({columns, sortedBy, ascending, onSort})`, `KindDotLabel({kind, label, colors})`, `ConnectionsTableCell({child, flex, numeric})` (not `TableCell`, which `material.dart` already exports).
- Produces: `PairsTable({required ConnectionGraph graph, required ConnectionKindColors colors, required GraphSelection? selection, required ValueChanged<GraphSelection?> onSelect})`.

- [ ] **Step 1: Add the English strings**

```json
  "connections_table_entity": "Entity",
  "connections_table_linkedWith": "Linked with",
  "connections_table_sharedDives": "Shared dives",
  "connections_table_lastShared": "Last shared",
  "connections_table_firstShared": "First shared",
  "connections_table_name": "Name",
  "connections_table_kind": "Kind",
  "connections_table_dives": "Dives",
  "connections_table_links": "Connections",
  "connections_table_strongest": "Strongest connection",
  "connections_table_firstDive": "First dive",
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

`table_rows_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/views/table_rows.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);

ConnectionEdge _e(NodeRef a, NodeRef b, int w, int lastYear) => ConnectionEdge(
  source: a,
  target: b,
  weight: w,
  firstDiveAt: DateTime.utc(2019),
  lastDiveAt: DateTime.utc(lastYear),
);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('ann'), label: 'Ann', diveCount: 9),
    ConnectionNode(ref: _b('bob'), label: 'Bob', diveCount: 4),
    ConnectionNode(ref: _s('reef'), label: 'Reef', diveCount: 6),
    ConnectionNode(ref: _s('wall'), label: 'Wall', diveCount: 1),
  ],
  edges: [
    _e(_b('ann'), _s('reef'), 5, 2023),
    _e(_b('bob'), _s('reef'), 2, 2024),
    _e(_b('ann'), _s('wall'), 1, 2020),
  ],
);

void main() {
  test('pairs sort by shared dives, then by a ascending as a tie-break', () {
    final rows = ConnectionsTableRows.pairs(
      _graph,
      PairsColumn.shared,
      ascending: false,
    );
    expect(rows.map((e) => e.weight), [5, 2, 1]);
    final up = ConnectionsTableRows.pairs(
      _graph,
      PairsColumn.last,
      ascending: true,
    );
    expect(up.map((e) => e.lastDiveAt.year), [2020, 2023, 2024]);
  });

  test('pairs sort by label', () {
    final rows = ConnectionsTableRows.pairs(_graph, PairsColumn.b, ascending: true);
    expect(rows.map((e) => e.target.id), ['reef', 'reef', 'wall']);
  });

  test('entity rows count connections and find the strongest', () {
    final rows = ConnectionsTableRows.entities(
      _graph,
      EntitiesColumn.dives,
      ascending: false,
    );
    expect(rows.map((r) => r.node.label), ['Ann', 'Reef', 'Bob', 'Wall']);
    final ann = rows.first;
    expect(ann.links, 2);
    expect(ann.strongest?.label, 'Reef');
    expect(ann.strongestWeight, 5);
  });

  test('entities sort by connections then by name', () {
    final rows = ConnectionsTableRows.entities(
      _graph,
      EntitiesColumn.links,
      ascending: false,
    );
    expect(rows.map((r) => r.node.label), ['Ann', 'Reef', 'Bob', 'Wall']);
  });

  test('text columns start ascending, numbers and dates descending', () {
    expect(ConnectionsTableRows.startsAscending(PairsColumn.a), isTrue);
    expect(ConnectionsTableRows.startsAscending(EntitiesColumn.name), isTrue);
    expect(ConnectionsTableRows.startsAscending(PairsColumn.shared), isFalse);
    expect(ConnectionsTableRows.startsAscending(EntitiesColumn.first), isFalse);
  });
}
```

`pairs_table_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/pairs_table.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('ann'), label: 'Ann', diveCount: 9),
    ConnectionNode(ref: _b('bob'), label: 'Bob', diveCount: 4),
    ConnectionNode(ref: _b('cy'), label: 'Cy', diveCount: 2),
  ],
  edges: [
    ConnectionEdge(
      source: _b('ann'),
      target: _b('bob'),
      weight: 2,
      firstDiveAt: DateTime.utc(2020),
      lastDiveAt: DateTime.utc(2021),
    ),
    ConnectionEdge(
      source: _b('ann'),
      target: _b('cy'),
      weight: 7,
      firstDiveAt: DateTime.utc(2020),
      lastDiveAt: DateTime.utc(2024),
    ),
  ],
);

Future<List<GraphSelection?>> _pump(WidgetTester tester, {double width = 400}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <GraphSelection?>[];
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PairsTable(
            graph: _graph,
            colors: const ConnectionKindColors({}, Colors.grey),
            selection: null,
            onSelect: picked.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('rows start by shared dives, strongest first', (tester) async {
    await _pump(tester);
    final first = tester.getTopLeft(find.text('Cy')).dy;
    final second = tester.getTopLeft(find.text('Bob')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('tapping a header sorts by it, again reverses', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sort-b')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Bob')).dy,
      lessThan(tester.getTopLeft(find.text('Cy')).dy),
    );
    await tester.tap(find.byKey(const ValueKey('sort-b')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Cy')).dy,
      lessThan(tester.getTopLeft(find.text('Bob')).dy),
    );
  });

  testWidgets('tapping a row selects that pair', (tester) async {
    final picked = await _pump(tester);
    await tester.tap(find.text('Cy'));
    expect(picked.single, EdgeSelection(_b('ann'), _b('cy')));
  });

  testWidgets('first shared shows only when wide', (tester) async {
    await _pump(tester);
    expect(find.text('First shared'), findsNothing);
    await _pump(tester, width: 900);
    expect(find.text('First shared'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/connections/presentation/views/`
Expected: FAIL to compile.

- [ ] **Step 4: Write `table_rows.dart`**

```dart
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

enum PairsColumn { a, b, shared, last, first }

enum EntitiesColumn { name, kind, dives, links, strongest, first }

/// One Entities table row: the node, how many nodes on the map it links to,
/// and the one it shares the most dives with.
class EntityRow {
  const EntityRow({
    required this.node,
    required this.links,
    this.strongest,
    this.strongestWeight = 0,
  });

  final ConnectionNode node;
  final int links;
  final ConnectionNode? strongest;
  final int strongestWeight;
}

/// Sorting for the Pairs and Entities tables. Ties always fall back to
/// labels ascending, so equal rows keep one order whichever way the column
/// runs.
abstract final class ConnectionsTableRows {
  /// Text columns read A to Z first; numbers and dates biggest or newest
  /// first.
  static bool startsAscending(Enum column) =>
      column == PairsColumn.a ||
      column == PairsColumn.b ||
      column == EntitiesColumn.name ||
      column == EntitiesColumn.kind ||
      column == EntitiesColumn.strongest;

  static List<ConnectionEdge> pairs(
    ConnectionGraph graph,
    PairsColumn by, {
    required bool ascending,
  }) {
    final labels = {for (final n in graph.nodes) n.ref: n.label};
    String label(NodeRef r) => labels[r] ?? r.id;
    int tieBreak(ConnectionEdge x, ConnectionEdge y) {
      final a = label(x.source).compareTo(label(y.source));
      return a != 0 ? a : label(x.target).compareTo(label(y.target));
    }

    final rows = [...graph.edges]
      ..sort((x, y) {
        final primary = switch (by) {
          PairsColumn.a => label(x.source).compareTo(label(y.source)),
          PairsColumn.b => label(x.target).compareTo(label(y.target)),
          PairsColumn.shared => x.weight.compareTo(y.weight),
          PairsColumn.last => x.lastDiveAt.compareTo(y.lastDiveAt),
          PairsColumn.first => x.firstDiveAt.compareTo(y.firstDiveAt),
        };
        final ordered = ascending ? primary : -primary;
        return ordered != 0 ? ordered : tieBreak(x, y);
      });
    return rows;
  }

  static List<EntityRow> entities(
    ConnectionGraph graph,
    EntitiesColumn by, {
    required bool ascending,
  }) {
    final byRef = {for (final n in graph.nodes) n.ref: n};
    final links = <NodeRef, int>{};
    final best = <NodeRef, ConnectionEdge>{};
    for (final e in graph.edges) {
      for (final end in [e.source, e.target]) {
        links[end] = (links[end] ?? 0) + 1;
        final current = best[end];
        if (current == null || e.weight > current.weight) best[end] = e;
      }
    }
    final rows = [
      for (final n in graph.nodes)
        EntityRow(
          node: n,
          links: links[n.ref] ?? 0,
          strongest: best[n.ref] == null
              ? null
              : byRef[best[n.ref]!.otherEnd(n.ref)],
          strongestWeight: best[n.ref]?.weight ?? 0,
        ),
    ];
    int compareDates(DateTime? x, DateTime? y) {
      if (x == null || y == null) return (x == null ? 0 : 1) - (y == null ? 0 : 1);
      return x.compareTo(y);
    }

    rows.sort((x, y) {
      final primary = switch (by) {
        EntitiesColumn.name => x.node.label.compareTo(y.node.label),
        EntitiesColumn.kind => x.node.ref.kind.index.compareTo(y.node.ref.kind.index),
        EntitiesColumn.dives => x.node.diveCount.compareTo(y.node.diveCount),
        EntitiesColumn.links => x.links.compareTo(y.links),
        EntitiesColumn.strongest =>
          (x.strongest?.label ?? '').compareTo(y.strongest?.label ?? ''),
        EntitiesColumn.first => compareDates(x.node.firstDiveAt, y.node.firstDiveAt),
      };
      final ordered = ascending ? primary : -primary;
      return ordered != 0 ? ordered : x.node.label.compareTo(y.node.label);
    });
    return rows;
  }
}
```

- [ ] **Step 5: Write `table_parts.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';

class TableColumnSpec<T extends Enum> {
  const TableColumnSpec(
    this.id,
    this.label, {
    this.flex = 2,
    this.numeric = false,
  });

  final T id;
  final String label;
  final int flex;
  final bool numeric;
}

/// One table cell, sized by [flex] and right-aligned when [numeric].
class ConnectionsTableCell extends StatelessWidget {
  const ConnectionsTableCell({
    super.key,
    required this.child,
    this.flex = 2,
    this.numeric = false,
  });

  final Widget child;
  final int flex;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Align(
      alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
}

/// The header row: tap a column to sort by it, again to reverse.
class SortableHeader<T extends Enum> extends StatelessWidget {
  const SortableHeader({
    super.key,
    required this.columns,
    required this.sortedBy,
    required this.ascending,
    required this.onSort,
  });

  final List<TableColumnSpec<T>> columns;
  final T sortedBy;
  final bool ascending;
  final ValueChanged<T> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Container(
      height: 40,
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: InkWell(
                key: ValueKey('sort-${c.id.name}'),
                onTap: () => onSort(c.id),
                child: Row(
                  mainAxisAlignment: c.numeric
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        c.label,
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (c.id == sortedBy)
                      Icon(
                        ascending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A kind colour dot and a one-line label.
class KindDotLabel extends StatelessWidget {
  const KindDotLabel({
    super.key,
    required this.kind,
    required this.label,
    required this.colors,
  });

  final ConnectionKind kind;
  final String label;
  final ConnectionKindColors colors;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: colors.colorFor(kind),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
```

- [ ] **Step 6: Write `pairs_table.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/table_parts.dart';
import 'package:submersion/features/connections/presentation/views/table_rows.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every connection on the map as a sortable row; tapping one selects it.
class PairsTable extends ConsumerStatefulWidget {
  const PairsTable({
    super.key,
    required this.graph,
    required this.colors,
    required this.selection,
    required this.onSelect,
  });

  final ConnectionGraph graph;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final ValueChanged<GraphSelection?> onSelect;

  @override
  ConsumerState<PairsTable> createState() => _PairsTableState();
}

class _PairsTableState extends ConsumerState<PairsTable> {
  PairsColumn _by = PairsColumn.shared;
  bool _ascending = false;

  void _sort(PairsColumn column) => setState(() {
    if (column == _by) {
      _ascending = !_ascending;
    } else {
      _by = column;
      _ascending = ConnectionsTableRows.startsAscending(column);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final selected = widget.selection;
    final labels = {for (final n in widget.graph.nodes) n.ref: n.label};
    final rows = ConnectionsTableRows.pairs(
      widget.graph,
      _by,
      ascending: _ascending,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final columns = [
          TableColumnSpec(PairsColumn.a, l10n.connections_table_entity, flex: 3),
          TableColumnSpec(PairsColumn.b, l10n.connections_table_linkedWith, flex: 3),
          TableColumnSpec(
            PairsColumn.shared,
            l10n.connections_table_sharedDives,
            numeric: true,
          ),
          TableColumnSpec(PairsColumn.last, l10n.connections_table_lastShared),
          if (wide)
            TableColumnSpec(PairsColumn.first, l10n.connections_table_firstShared),
        ];
        return Column(
          children: [
            SortableHeader<PairsColumn>(
              columns: columns,
              sortedBy: _by,
              ascending: _ascending,
              onSort: _sort,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemExtent: 48,
                itemBuilder: (context, i) {
                  final e = rows[i];
                  final isSelected =
                      selected is EdgeSelection &&
                      e.touches(selected.a) &&
                      e.touches(selected.b);
                  return Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Colors.transparent,
                    child: InkWell(
                      key: ValueKey('pair-row-$i'),
                      onTap: () =>
                          widget.onSelect(EdgeSelection(e.source, e.target)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            ConnectionsTableCell(
                              flex: 3,
                              child: KindDotLabel(
                                kind: e.source.kind,
                                label: labels[e.source] ?? e.source.id,
                                colors: widget.colors,
                              ),
                            ),
                            ConnectionsTableCell(
                              flex: 3,
                              child: KindDotLabel(
                                kind: e.target.kind,
                                label: labels[e.target] ?? e.target.id,
                                colors: widget.colors,
                              ),
                            ),
                            ConnectionsTableCell(
                              numeric: true,
                              child: Text('${e.weight}'),
                            ),
                            ConnectionsTableCell(
                              child: Text(units.formatDate(e.lastDiveAt)),
                            ),
                            if (wide)
                              ConnectionsTableCell(
                                child: Text(units.formatDate(e.firstDiveAt)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
```

Check `formatDate`'s handling of a wall-clock UTC `DateTime` against how `selection_details.dart` formats an edge's dates, and match it.

- [ ] **Step 7: Wire it into the page**

In `connections_page.dart`, the `pairs` arm of `tableView` becomes:

```dart
      ConnectionsViewKind.pairs => PairsTable(
        key: const ValueKey('connections-view-pairs'),
        graph: graph,
        colors: colors,
        selection: selection,
        onSelect: (s) =>
            ref.read(connectionsSelectionProvider.notifier).state = s,
      ),
```

- [ ] **Step 8: Run tests**

Run: `flutter test test/features/connections/presentation/views/ test/features/connections/presentation/pages/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/connections/ lib/l10n/arb/ test/features/connections/presentation/views/
git commit -m "feat(connections): add the pairs table"
```

---

### Task 17: The Entities table

**Files:**
- Create: `lib/features/connections/presentation/views/entities_table.dart`
- Modify: `lib/features/connections/presentation/pages/connections_page.dart` (`tableView` entities arm)
- Test: `test/features/connections/presentation/views/entities_table_test.dart`

**Interfaces:**
- Consumes: `ConnectionsTableRows.entities`, `EntityRow`, `EntitiesColumn`, `SortableHeader`, `KindDotLabel`, `ConnectionsTableCell` (Task 16), `kindNameOne` (existing, `connections_legend.dart`).
- Produces: `EntitiesTable({required ConnectionGraph graph, required ConnectionKindColors colors, required GraphSelection? selection, required ValueChanged<GraphSelection?> onSelect})`.

- [ ] **Step 1: Write the failing test**

Use the `_pump` shape of `pairs_table_test.dart` with `EntitiesTable` and this graph: Ann (9 dives, `firstDiveAt: DateTime.utc(2019)`), Bob (4), Cy (2); edges Ann-Bob (2), Ann-Cy (7).

```dart
  testWidgets('rows start by dives, busiest first', (tester) async {
    await _pump(tester);
    expect(
      tester.getTopLeft(find.text('Ann')).dy,
      lessThan(tester.getTopLeft(find.text('Bob')).dy),
    );
  });

  testWidgets('sorting by connections puts Ann first', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sort-links')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Ann')).dy,
      lessThan(tester.getTopLeft(find.text('Cy')).dy),
    );
  });

  testWidgets('tapping a row selects that entity', (tester) async {
    final picked = await _pump(tester);
    await tester.tap(find.text('Bob'));
    expect(picked.single, NodeSelection(_b('bob')));
  });

  testWidgets('wide adds kind, strongest connection and first dive', (
    tester,
  ) async {
    await _pump(tester, width: 900);
    expect(find.text('Strongest connection'), findsOneWidget);
    expect(find.text('Cy (7)'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/connections/presentation/views/entities_table_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write `entities_table.dart`**

Same structure as `PairsTable` (state `_by = EntitiesColumn.dives`, `_ascending = false`, same `_sort`), with:

```dart
        final columns = [
          TableColumnSpec(EntitiesColumn.name, l10n.connections_table_name, flex: 4),
          if (wide) TableColumnSpec(EntitiesColumn.kind, l10n.connections_table_kind),
          TableColumnSpec(EntitiesColumn.dives, l10n.connections_table_dives, numeric: true),
          TableColumnSpec(EntitiesColumn.links, l10n.connections_table_links, numeric: true),
          if (wide)
            TableColumnSpec(EntitiesColumn.strongest, l10n.connections_table_strongest, flex: 3),
          if (wide)
            TableColumnSpec(EntitiesColumn.first, l10n.connections_table_firstDive),
        ];
```

and each row (`final r = rows[i]`, selected when `selected is NodeSelection && selected.ref == r.node.ref`, tap `widget.onSelect(NodeSelection(r.node.ref))`, key `entity-row-$i`):

```dart
                          children: [
                            ConnectionsTableCell(
                              flex: 4,
                              child: KindDotLabel(
                                kind: r.node.ref.kind,
                                label: r.node.label,
                                colors: widget.colors,
                              ),
                            ),
                            if (wide)
                              ConnectionsTableCell(
                                child: Text(kindNameOne(l10n, r.node.ref.kind)),
                              ),
                            ConnectionsTableCell(
                              numeric: true,
                              child: Text('${r.node.diveCount}'),
                            ),
                            ConnectionsTableCell(
                              numeric: true,
                              child: Text('${r.links}'),
                            ),
                            if (wide)
                              ConnectionsTableCell(
                                flex: 3,
                                child: Text(
                                  r.strongest == null
                                      ? ''
                                      : '${r.strongest!.label} (${r.strongestWeight})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (wide)
                              ConnectionsTableCell(
                                child: Text(
                                  r.node.firstDiveAt == null
                                      ? ''
                                      : units.formatDate(r.node.firstDiveAt),
                                ),
                              ),
                          ],
```

Class doc: `/// Every entity on the map as a sortable row; tapping one selects it.`

- [ ] **Step 4: Wire it into the page** (entities arm of `tableView`, key `connections-view-entities`, same arguments as Pairs).

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/connections/presentation/views/ test/features/connections/presentation/pages/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/connections/ test/features/connections/presentation/views/entities_table_test.dart
git commit -m "feat(connections): add the entities table"
```

---

### Task 18: The Matrix

**Files:**
- Create: `lib/features/connections/presentation/views/matrix_model.dart`
- Create: `lib/features/connections/presentation/views/matrix_painter.dart`
- Create: `lib/features/connections/presentation/views/connections_matrix.dart`
- Modify: `lib/features/connections/presentation/pages/connections_page.dart` (`tableView` matrix arm)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/connections/presentation/views/matrix_model_test.dart`, `test/features/connections/presentation/views/connections_matrix_test.dart`

**Interfaces:**
- Consumes: `compareDivesLabel`, `compareKindDivesLabel` (Task 5).
- Produces: `class MatrixModel { List<ConnectionNode> rows; List<ConnectionNode> columns; int maxWeight; bool symmetric; ConnectionEdge? edgeAt(int row, int column); factory MatrixModel.of(ConnectionGraph); }`; `abstract final class MatrixGeometry { cell = 36, rowHeader = 140, columnHeader = 120; static ({int? row, int? column})? hitAt(Offset p, {required Offset scroll, required int rows, required int columns}); }`.
- Produces: `ConnectionsMatrix({required ConnectionGraph graph, required ConnectionKindColors colors, required GraphSelection? selection, required ValueChanged<GraphSelection?> onSelect})`.

- [ ] **Step 1: Add the English string**

```json
  "connections_matrix_semantics": "Matrix of {rows} rows and {columns} columns, {links} connections",
  "@connections_matrix_semantics": {
    "placeholders": {
      "rows": {"type": "int"},
      "columns": {"type": "int"},
      "links": {"type": "int"}
    }
  },
```

Run `flutter gen-l10n`. The generated method takes the placeholders in map order: `connections_matrix_semantics(rows, columns, links)`; check the generated signature before using it.

- [ ] **Step 2: Write the failing tests**

`matrix_model_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/views/matrix_model.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);
ConnectionNode _n(NodeRef r, int dives) =>
    ConnectionNode(ref: r, label: r.id, diveCount: dives);
ConnectionEdge _e(NodeRef a, NodeRef b, int w) => ConnectionEdge(
  source: a,
  target: b,
  weight: w,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  test('a two-kind map puts the bigger kind on the rows', () {
    final m = MatrixModel.of(
      ConnectionGraph(
        nodes: [_n(_s('reef'), 3), _n(_b('ann'), 5), _n(_b('bob'), 2)],
        edges: [_e(_b('ann'), _s('reef'), 3), _e(_b('bob'), _s('reef'), 1)],
      ),
    );
    expect(m.symmetric, isFalse);
    expect(m.rows.map((n) => n.ref.id), ['ann', 'bob']);
    expect(m.columns.map((n) => n.ref.id), ['reef']);
    expect(m.edgeAt(1, 0)?.weight, 1);
  });

  test('a same-kind link makes it symmetric with an empty diagonal', () {
    final m = MatrixModel.of(
      ConnectionGraph(
        nodes: [_n(_b('ann'), 5), _n(_b('bob'), 2), _n(_s('reef'), 1)],
        edges: [_e(_b('ann'), _b('bob'), 4), _e(_b('ann'), _s('reef'), 1)],
      ),
    );
    expect(m.symmetric, isTrue);
    expect(m.rows, m.columns);
    expect(m.rows.map((n) => n.ref.id), ['ann', 'bob', 'reef']);
    expect(m.edgeAt(0, 0), isNull);
    expect(m.edgeAt(0, 1)?.weight, 4);
    expect(m.edgeAt(1, 0)?.weight, 4);
    expect(m.maxWeight, 4);
  });

  test('hit testing maps points to headers and cells', () {
    const g = MatrixGeometry;
    expect(
      MatrixGeometry.hitAt(
        const Offset(g.rowHeader + 5, g.columnHeader + g.cell + 5),
        scroll: Offset.zero,
        rows: 3,
        columns: 3,
      ),
      (row: 1, column: 0),
    );
    expect(
      MatrixGeometry.hitAt(
        const Offset(10, g.columnHeader + 5),
        scroll: Offset.zero,
        rows: 3,
        columns: 3,
      ),
      (row: 0, column: null),
    );
    expect(
      MatrixGeometry.hitAt(
        const Offset(g.rowHeader + 5, 10),
        scroll: const Offset(g.cell, 0),
        rows: 3,
        columns: 3,
      ),
      (row: null, column: 1),
    );
    expect(
      MatrixGeometry.hitAt(
        const Offset(10, 10),
        scroll: Offset.zero,
        rows: 3,
        columns: 3,
      ),
      isNull,
    );
    expect(
      MatrixGeometry.hitAt(
        const Offset(g.rowHeader + 5 * g.cell, g.columnHeader + 5),
        scroll: Offset.zero,
        rows: 3,
        columns: 3,
      ),
      isNull,
    );
  });
}
```

`connections_matrix_test.dart` (pump like `pairs_table_test.dart`, at 400x600, with the two-kind graph from the first model test):

```dart
  testWidgets('tapping a cell selects the pair, a header the entity', (
    tester,
  ) async {
    final picked = await _pump(tester);
    const g = MatrixGeometry;
    final origin = tester.getTopLeft(find.byType(ConnectionsMatrix));
    await tester.tapAt(origin + const Offset(g.rowHeader + 10, g.columnHeader + 10));
    await tester.tapAt(origin + const Offset(20, g.columnHeader + g.cell + 10));
    await tester.tapAt(origin + const Offset(g.rowHeader + 10, 40));
    expect(picked, [
      EdgeSelection(_b('ann'), _s('reef')),
      NodeSelection(_b('bob')),
      NodeSelection(_s('reef')),
    ]);
  });

  testWidgets('has a summary for screen readers', (tester) async {
    await _pump(tester);
    expect(
      find.bySemanticsLabel('Matrix of 2 rows and 1 columns, 2 connections'),
      findsOneWidget,
    );
  });

  testWidgets('a drag on content smaller than the view does not move it', (
    tester,
  ) async {
    await _pump(tester);
    await tester.drag(find.byType(ConnectionsMatrix), const Offset(-100, -100));
    await tester.pump();
    final painter = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('connections-matrix-paint')))
        .painter! as MatrixPainter;
    expect(painter.scroll, Offset.zero);
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/connections/presentation/views/matrix_model_test.dart test/features/connections/presentation/views/connections_matrix_test.dart`
Expected: FAIL to compile.

- [ ] **Step 4: Write `matrix_model.dart`**

```dart
import 'package:flutter/painting.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// The matrix's axes and cells. A map of exactly two kinds linked only to
/// each other puts one kind on the rows (the bigger one) and the other on
/// the columns; any other map has every node on both axes.
class MatrixModel {
  MatrixModel._(this.rows, this.columns, this._cells, this.maxWeight, this.symmetric);

  factory MatrixModel.of(ConnectionGraph graph) {
    final cells = <(NodeRef, NodeRef), ConnectionEdge>{};
    for (final e in graph.edges) {
      cells[(e.source, e.target)] = e;
      cells[(e.target, e.source)] = e;
    }
    final kinds = {for (final n in graph.nodes) n.ref.kind}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final crossOnly = graph.edges.every((e) => e.source.kind != e.target.kind);
    if (kinds.length == 2 && crossOnly) {
      List<ConnectionNode> of(ConnectionKind k) => [
        for (final n in graph.nodes)
          if (n.ref.kind == k) n,
      ]..sort(compareDivesLabel);
      final a = of(kinds[0]);
      final b = of(kinds[1]);
      final aOnRows = a.length >= b.length;
      return MatrixModel._(
        aOnRows ? a : b,
        aOnRows ? b : a,
        cells,
        graph.maxWeight,
        false,
      );
    }
    final all = [...graph.nodes]..sort(compareKindDivesLabel);
    return MatrixModel._(all, all, cells, graph.maxWeight, true);
  }

  final List<ConnectionNode> rows;
  final List<ConnectionNode> columns;
  final Map<(NodeRef, NodeRef), ConnectionEdge> _cells;
  final int maxWeight;
  final bool symmetric;

  ConnectionEdge? edgeAt(int row, int column) {
    final a = rows[row].ref;
    final b = columns[column].ref;
    return a == b ? null : _cells[(a, b)];
  }
}

/// Sizes and hit testing shared by the matrix widget and its painter.
abstract final class MatrixGeometry {
  static const double cell = 36;
  static const double rowHeader = 140;
  static const double columnHeader = 120;

  /// What sits under [p]: a cell (both set), a row header (column null), a
  /// column header (row null), or null for the corner and anything past the
  /// last row or column.
  static ({int? row, int? column})? hitAt(
    Offset p, {
    required Offset scroll,
    required int rows,
    required int columns,
  }) {
    final inRowHeader = p.dx < rowHeader;
    final inColumnHeader = p.dy < columnHeader;
    if (inRowHeader && inColumnHeader) return null;
    final column = ((p.dx - rowHeader + scroll.dx) / cell).floor();
    final row = ((p.dy - columnHeader + scroll.dy) / cell).floor();
    final columnOk = column >= 0 && column < columns;
    final rowOk = row >= 0 && row < rows;
    if (inColumnHeader) return columnOk ? (row: null, column: column) : null;
    if (inRowHeader) return rowOk ? (row: row, column: null) : null;
    return rowOk && columnOk ? (row: row, column: column) : null;
  }
}
```

- [ ] **Step 5: Write `matrix_painter.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/matrix_model.dart';

/// Paints only the visible cells, with the row and column headers frozen at
/// the left and top.
class MatrixPainter extends CustomPainter {
  MatrixPainter({
    required this.model,
    required this.scroll,
    required this.colors,
    required this.textStyle,
    required this.fill,
    required this.grid,
    required this.tint,
    required this.headerBackground,
    this.selectedNode,
    this.selectedEdge,
  });

  final MatrixModel model;
  final Offset scroll;
  final ConnectionKindColors colors;
  final TextStyle textStyle;
  final Color fill;
  final Color grid;
  final Color tint;
  final Color headerBackground;
  final NodeRef? selectedNode;
  final ConnectionEdge? selectedEdge;

  static const _g = MatrixGeometry;

  @override
  void paint(Canvas canvas, Size size) {
    if (model.rows.isEmpty || model.columns.isEmpty) return;
    final firstCol = (scroll.dx / _g.cell).floor().clamp(0, model.columns.length - 1);
    final lastCol = ((scroll.dx + size.width - _g.rowHeader) / _g.cell)
        .ceil()
        .clamp(0, model.columns.length - 1);
    final firstRow = (scroll.dy / _g.cell).floor().clamp(0, model.rows.length - 1);
    final lastRow = ((scroll.dy + size.height - _g.columnHeader) / _g.cell)
        .ceil()
        .clamp(0, model.rows.length - 1);
    final counts = <int, TextPainter>{};
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_g.rowHeader, _g.columnHeader, size.width, size.height));
    for (var r = firstRow; r <= lastRow; r++) {
      for (var c = firstCol; c <= lastCol; c++) {
        final rect = Rect.fromLTWH(
          _g.rowHeader + c * _g.cell - scroll.dx,
          _g.columnHeader + r * _g.cell - scroll.dy,
          _g.cell,
          _g.cell,
        );
        final rowRef = model.rows[r].ref;
        final colRef = model.columns[c].ref;
        if (selectedNode != null && (rowRef == selectedNode || colRef == selectedNode)) {
          canvas.drawRect(rect, Paint()..color = tint);
        }
        final edge = model.edgeAt(r, c);
        if (edge != null) {
          final t = model.maxWeight <= 0 ? 1.0 : edge.weight / model.maxWeight;
          canvas.drawRect(
            rect.deflate(2),
            Paint()..color = fill.withValues(alpha: 0.15 + 0.75 * t),
          );
          final tp = counts.putIfAbsent(
            edge.weight,
            () => TextPainter(
              text: TextSpan(text: '${edge.weight}', style: textStyle),
              textDirection: TextDirection.ltr,
            )..layout(),
          );
          tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
          if (edge == selectedEdge) {
            canvas.drawRect(
              rect.deflate(1),
              Paint()
                ..color = textStyle.color ?? Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          }
        }
        canvas.drawRect(rect, gridPaint);
      }
    }
    canvas.restore();

    // Row headers.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, _g.columnHeader, _g.rowHeader, size.height));
    canvas.drawRect(Rect.fromLTRB(0, _g.columnHeader, _g.rowHeader, size.height),
        Paint()..color = headerBackground);
    for (var r = firstRow; r <= lastRow; r++) {
      final n = model.rows[r];
      final top = _g.columnHeader + r * _g.cell - scroll.dy;
      _headerLabel(canvas, n.ref, n.label, Offset(8, top + _g.cell / 2), _g.rowHeader - 24);
    }
    canvas.restore();

    // Column headers, rotated to read bottom to top.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_g.rowHeader, 0, size.width, _g.columnHeader));
    canvas.drawRect(Rect.fromLTRB(_g.rowHeader, 0, size.width, _g.columnHeader),
        Paint()..color = headerBackground);
    for (var c = firstCol; c <= lastCol; c++) {
      final n = model.columns[c];
      final cx = _g.rowHeader + c * _g.cell - scroll.dx + _g.cell / 2;
      canvas.save();
      canvas.translate(cx, _g.columnHeader - 8);
      canvas.rotate(-math.pi / 2);
      _headerLabel(canvas, n.ref, n.label, Offset.zero, _g.columnHeader - 28);
      canvas.restore();
    }
    canvas.restore();

    for (final tp in counts.values) {
      tp.dispose();
    }
  }

  /// A kind dot then the label, vertically centred on [at].
  void _headerLabel(Canvas canvas, NodeRef ref, String label, Offset at, double maxWidth) {
    canvas.drawCircle(at + const Offset(4, 0), 4, Paint()..color = colors.colorFor(ref.kind));
    final selected = ref == selectedNode;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: selected ? textStyle.copyWith(fontWeight: FontWeight.w700) : textStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, at + Offset(14, -tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(MatrixPainter old) =>
      old.model != model ||
      old.scroll != scroll ||
      old.selectedNode != selectedNode ||
      old.selectedEdge != selectedEdge ||
      old.textStyle != textStyle ||
      old.fill != fill ||
      old.tint != tint;
}
```

- [ ] **Step 6: Write `connections_matrix.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/matrix_model.dart';
import 'package:submersion/features/connections/presentation/views/matrix_painter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shared dives between every pair on the map as a grid. Drag or scroll to
/// move; tap a cell to select the pair, a header to select the entity.
class ConnectionsMatrix extends StatefulWidget {
  const ConnectionsMatrix({
    super.key,
    required this.graph,
    required this.colors,
    required this.selection,
    required this.onSelect,
  });

  final ConnectionGraph graph;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final ValueChanged<GraphSelection?> onSelect;

  @override
  State<ConnectionsMatrix> createState() => _ConnectionsMatrixState();
}

class _ConnectionsMatrixState extends State<ConnectionsMatrix> {
  Offset _scroll = Offset.zero;
  ConnectionGraph? _modelFor;
  late MatrixModel _model;

  MatrixModel get _current {
    if (!identical(_modelFor, widget.graph)) {
      _modelFor = widget.graph;
      _model = MatrixModel.of(widget.graph);
    }
    return _model;
  }

  Offset _clamped(Offset o, Size size, MatrixModel m) {
    const g = MatrixGeometry;
    final maxX = math.max(0.0, m.columns.length * g.cell - (size.width - g.rowHeader));
    final maxY = math.max(0.0, m.rows.length * g.cell - (size.height - g.columnHeader));
    return Offset(o.dx.clamp(0.0, maxX), o.dy.clamp(0.0, maxY));
  }

  void _tap(Offset p, MatrixModel m) {
    final hit = MatrixGeometry.hitAt(
      p,
      scroll: _scroll,
      rows: m.rows.length,
      columns: m.columns.length,
    );
    if (hit == null) return;
    final (:row, :column) = hit;
    if (row != null && column != null) {
      final e = m.edgeAt(row, column);
      if (e != null) widget.onSelect(EdgeSelection(e.source, e.target));
    } else if (row != null) {
      widget.onSelect(NodeSelection(m.rows[row].ref));
    } else if (column != null) {
      widget.onSelect(NodeSelection(m.columns[column].ref));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = _current;
    final selection = widget.selection;
    final ConnectionEdge? selectedEdge = switch (selection) {
      EdgeSelection(:final a, :final b) => widget.graph.edges
          .where((e) => e.touches(a) && e.touches(b))
          .firstOrNull,
      _ => null,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _scroll = _clamped(_scroll, size, m);
        return Semantics(
          container: true,
          label: context.l10n.connections_matrix_semantics(
            m.rows.length,
            m.columns.length,
            widget.graph.edges.length,
          ),
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                setState(() => _scroll = _clamped(_scroll + e.scrollDelta, size, m));
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) =>
                  setState(() => _scroll = _clamped(_scroll - d.delta, size, m)),
              onTapUp: (d) => _tap(d.localPosition, m),
              child: CustomPaint(
                key: const ValueKey('connections-matrix-paint'),
                size: size,
                painter: MatrixPainter(
                  model: m,
                  scroll: _scroll,
                  colors: widget.colors,
                  textStyle: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  fill: theme.colorScheme.primary,
                  grid: theme.colorScheme.outlineVariant,
                  tint: theme.colorScheme.secondaryContainer,
                  headerBackground: theme.colorScheme.surface,
                  selectedNode: switch (selection) {
                    NodeSelection(:final ref) => ref,
                    _ => null,
                  },
                  selectedEdge: selectedEdge,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

Check the cell count text contrast on the strongest fill in both themes in Task 21's screenshots; if it is unreadable, paint the count in `onPrimary` when `t > 0.5`.

- [ ] **Step 7: Wire it into the page** (matrix arm of `tableView`, key `connections-view-matrix`, same arguments as the tables).

- [ ] **Step 8: Run tests**

Run: `flutter test test/features/connections/presentation/views/ test/features/connections/presentation/pages/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/connections/ lib/l10n/arb/ test/features/connections/presentation/views/
git commit -m "feat(connections): add the matrix view"
```

---

### Task 19: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`, then regenerate `lib/l10n/arb/app_localizations*.dart`

New keys (all added to `app_en.arb` in Tasks 14 to 18): `connections_display_title`, `connections_layout_title`, `connections_layout_web`, `connections_layout_radial`, `connections_layout_circle`, `connections_layout_columns`, `connections_layout_clusters`, `connections_layout_timeline`, `connections_labels_title`, `connections_labels_auto`, `connections_labels_all`, `connections_labels_off`, `connections_nodeSize_title`, `connections_nodeSize_byDives`, `connections_nodeSize_uniform`, `connections_edges_title`, `connections_edges_weighted`, `connections_edges_thin`, `connections_edges_selectedOnly`, `connections_hideUnconnected`, `connections_spacing_title`, `connections_spacing_tight`, `connections_spacing_spread`, `connections_view_tooltip`, `connections_view_graph`, `connections_view_pairs`, `connections_view_entities`, `connections_view_matrix`, `connections_table_entity`, `connections_table_linkedWith`, `connections_table_sharedDives`, `connections_table_lastShared`, `connections_table_firstShared`, `connections_table_name`, `connections_table_kind`, `connections_table_dives`, `connections_table_links`, `connections_table_strongest`, `connections_table_firstDive`, `connections_matrix_semantics` (40 keys).

- [ ] **Step 1: Translate**

For each locale, insert the 40 keys after that file's `"connections_highlight_recency"` line, in the same order as English. Write real translations that reuse each file's own existing terms: read its `connections_*`, `connections_kind_*`, `connections_semantics_summary` and `connections_editor_links` values first so "connections", "dives", "entity" and "links" match what the feature already says in that language (pt uses "elemento" for a node, per the existing ARB). Keep `{rows}`, `{columns}`, `{links}` placeholders unchanged; no `@` metadata in non-English files.

- [ ] **Step 2: Verify every locale has every key, none left in English**

```bash
python3.14 - <<'EOF'
import json, pathlib
arb = pathlib.Path('lib/l10n/arb')
en = json.loads((arb / 'app_en.arb').read_text(encoding='utf-8'))
keys = [k for k in en if k.startswith(('connections_display', 'connections_layout', 'connections_labels', 'connections_nodeSize', 'connections_edges', 'connections_hideUnconnected', 'connections_spacing', 'connections_view_', 'connections_table_', 'connections_matrix_'))]
same_ok = {'connections_view_matrix'}
for loc in ['ar','de','es','fr','he','hu','it','nl','pt','zh']:
    data = json.loads((arb / f'app_{loc}.arb').read_text(encoding='utf-8'))
    missing = [k for k in keys if k not in data]
    english = [k for k in keys if data.get(k) == en[k] and k not in same_ok]
    print(loc, 'missing', missing, 'still english', english)
EOF
```

Expected: every locale prints `missing []`. Review any "still english" entry; a few are legitimately identical (for example "Matrix" in de, "Auto" in de and fr); keep those deliberately.

- [ ] **Step 3: Regenerate LAST and spot-check**

Run: `flutter gen-l10n`
Run: `grep -A1 "get connections_layout_columns" lib/l10n/arb/app_localizations_de.dart`
Expected: the German value, not "Columns". Then `git diff --numstat lib/l10n/arb/` shows the same added-line count in every `app_XX.arb` and every `app_localizations_XX.dart`.

- [ ] **Step 4: Run the l10n guards**

Run: `flutter test test/l10n/ test/architecture/`
Expected: PASS (diacritics, plural and orphan-key guards included).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n(connections): translate the display options and table views"
```

---

### Task 20: User documentation

**Files:**
- Modify: `docs/user/statistics.md` (new section after the dashboards table, before `### Dive focus`)

- [ ] **Step 1: Write the section**

```markdown
### Connections

Connections draws how your buddies, sites, trips, gear, species and dive
centers link through the dives they share. **Map** shows a whole kind-to-kind
map; **Around** centres on one entity and what it links to.

**Views.** The view button in the top bar switches between:

- **Graph**: the map itself.
- **Pairs**: one row per connection, with the dives the two share and the
  last and first shared dive.
- **Entities**: one row per entity, with its dives, how many entities it links
  to and its strongest connection.
- **Matrix**: a grid of shared dives between every pair. On a map of two kinds
  (buddies and sites, for example) one kind runs down the side and the other
  across the top.

Tap a column heading to sort a table, and again to reverse it. Tapping a row,
a cell or a heading selects that entity or pair, just as tapping the graph does.

**Layouts.** In the Graph view, the **Display** section of the **View** tab
chooses how nodes are arranged:

| Layout | Arrangement |
|--------|-------------|
| **Web** | Linked entities pull together (Map only) |
| **Radial** | The centre in the middle, the rest in rings (Around only) |
| **Circle** | Every entity on one ring, grouped by kind |
| **Columns** | One column per kind, busiest at the top |
| **Clusters** | Each group of entities that dive together in its own cluster |
| **Timeline** | Left to right by the year of each entity's first dive, one row per kind |

**Display options.** **Labels** shows names automatically as you zoom, on
every node, or not at all. **Node size** sizes each node by its dives or draws
them all the same. **Lines** draws connections by strength, all thin, or only
for what you select. **Hide unconnected** leaves out entities with no link on
the map. **Spacing** spreads the map out or packs it tighter. Connections
remembers these on this device.

**Moving a node.** With a mouse or trackpad, press on a node and drag it. On a
touch screen, press and hold a node, then drag. A moved node stays where you
put it until the map changes; **Lay out again** puts every node back.
```

- [ ] **Step 2: Check docs links**

Run: `python3.14 scripts/check_docs_links.py`
Expected: OK.

- [ ] **Step 3: Commit**

```bash
git add docs/user/statistics.md
git commit -m "docs(connections): describe the views, layouts, display options and dragging"
```

---

### Task 21: Verification and after screenshots

- [ ] **Step 1: Format and analyze**

Run: `dart format lib/features/connections test/features/connections`
Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 2: Run the affected suites**

Run: `flutter test test/features/connections/ test/architecture/ test/shared/ test/core/database/dive_stats_scope_census_test.dart test/l10n/`
Expected: PASS. Log long runs to the scratchpad.

- [ ] **Step 3: Line counts**

Run: `wc -l lib/features/connections/presentation/pages/connections_page.dart lib/features/connections/presentation/canvas/connections_canvas.dart lib/features/connections/presentation/canvas/connections_painter.dart`
Expected: every file under 800; the page under 601.

- [ ] **Step 4: After screenshots**

Restore the Task 0 capture test from the scratchpad into `test/features/connections/zz_capture_test.dart`, extend it to set the display before capturing, and capture: desktop graph in Columns (light and dark), desktop Timeline, desktop Clusters, the View tab Display section (desktop panel), phone graph in Circle with the sheet raised to show Display, desktop Pairs, desktop Entities, desktop Matrix (light and dark), phone Matrix. Name them `<nn>-<screen>-after[-dark][-phone].png` in the scratchpad. Delete the capture test and its `goldens/` folder; `git status` must show nothing new.

- [ ] **Step 5: Send the screenshots to the user**

One `SendUserFile` call with every before and after PNG, `display: attach`, caption saying they go in the PR's Screenshots section.
