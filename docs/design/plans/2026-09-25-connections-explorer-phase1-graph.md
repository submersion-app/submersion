# Connections Explorer Phase 1 (The Graph) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Connections destination with a working buddy graph: the co-occurrence engine for every kind, force and radial layouts, an interactive canvas, the page with the *Dive circle* and *Who dives where* lenses, filters plus a year slider, and the buddy detail deep link.

**Architecture:** Two entities are connected when they share a dive, so one SQL shape parameterised by kind produces every edge list. A pure-Dart layout layer (force for the whole web, radial for ego mode) emits immutable frames that a `CustomPainter` draws inside a pan-and-zoom viewport. Riverpod providers own the lens, filter, focus and selection; the repository applies `DiveStatsScope` unconditionally and the diver's own filter state conditionally.

**Tech Stack:** Flutter 3.x, Drift (raw `customSelect`), Riverpod 3 (`package:submersion/core/providers/provider.dart`), go_router, shared_preferences, equatable, flutter_test with an in-memory Drift database.

**Spec:** `docs/design/specs/2026-09-25-connections-explorer-design.md`

**Issue:** #2322 (phase 1). PR body: `Closes #2322` and `Refs #2321`.

## Global Constraints

- No em-dashes anywhere (code, comments, docs, commit messages); no emojis; no mention of Claude, Claude Code or Anthropic in any commit, PR or file.
- Files stay under 800 lines; 200 to 400 is typical. Domain and layout files import nothing from Flutter (`dart:math`, `dart:typed_data` and `package:equatable` only).
- Every entity has `copyWith`. Immutability throughout.
- `DiveStatsScope.predicate(alias: 'd')` is applied to every aggregate over `dives`; the view filter is applied only when `filter.hasActiveFilters` via `buildFilteredDiveIdSubquery`.
- Every provider that calls a repository subscribes with `ref.invalidateSelfWhen(repository.watchConnectionsChanges())` and gets a case in `test/architecture/provider_tick_build_smoke_test.dart`.
- Dates and date ranges are formatted only through `UnitFormatter` (`formatDate`, `formatDateRange(start, end, l10n: context.l10n)`). No `DateFormat` constructors in presentation code.
- All strings go through `context.l10n`; every new key exists in all eleven ARB files (`ar de en es fr he hu it nl pt zh`); French and Portuguese plurals interpolate the count in the `=1` branch (`=1{{count} plongée}`), Arabic and Hebrew keep word forms.
- Only `app_en.arb` is alphabetical; in the other ten files insert each block next to the anchor key named in Task 14.
- Paths in tests use `p.join`; temporary space via `Directory.systemTemp`.
- Run `dart format .` before every commit and `flutter analyze` before the final commit. Run the whole `test/architecture/` folder after adding any file under `lib/`.
- `dive_date_time` is epoch milliseconds read back with `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)`, matching `dive_repository_impl.dart:2853`.
- Commit after every task with a plain `feat(connections): ...` or `test(connections): ...` message, no trailers.

## Review Focus

1. **Duplicate junction rows.** A buddy linked twice to one dive (an import artefact) must count that dive once; pinned in Task 4 by `COUNT(DISTINCT d.id)` and a test that inserts two `dive_buddies` rows for one dive.
2. **Coincident seeds.** Two nodes starting at the same point make the repulsion term divide by zero; Task 7 tests a layout whose initial positions are all identical and asserts every coordinate stays finite.
3. **Focus kind outside the lens.** A deep link `lens=circle&focus=site:x` must not crash or query nonsense; Task 1 makes `focusIsValid` false and Task 18 tests that the page opens unfocused with a snackbar.
4. **Tiny nodes at low zoom.** A node drawn at 3 px must still be tappable; Task 11 tests that the hit tester uses a minimum touch radius.
5. **Show dives with an empty id list.** `DiveFilterState(diveIds: [])` means *no filter* and would show the whole log; Task 16 disables the action when the selection has no dives and tests it.

## File Structure

```
lib/features/connections/
  domain/entities/connection_kind.dart        enum, accent id, detail route
  domain/entities/node_ref.dart               NodeRef (kind + id), wire form
  domain/entities/connection_node.dart        ConnectionNode, NodeSubtitle
  domain/entities/connection_edge.dart
  domain/entities/connection_graph.dart       graph + trimmed()
  domain/entities/connection_query.dart
  domain/entities/graph_selection.dart        NodeSelection / EdgeSelection
  domain/lenses/connection_lens.dart          ConnectionLens, LensSelection
  domain/layout/graph_point.dart              GraphPoint, GraphBounds
  domain/layout/layout_frame.dart
  domain/layout/layout_seed.dart
  domain/layout/force_layout.dart
  domain/layout/island_packer.dart
  domain/layout/whole_web_layout.dart         one ForceLayout per island + packing
  domain/layout/radial_layout.dart
  data/connections_scope_sql.dart             diver + scope + filter WHERE builder
  data/connections_membership_sql.dart        per-kind (dive_id, entity_id) fragments
  data/connections_edge_sql.dart
  data/connections_node_sql.dart
  data/repositories/connections_repository.dart
  presentation/providers/connections_filter_provider.dart
  presentation/providers/connections_lens_provider.dart
  presentation/providers/connections_providers.dart
  presentation/providers/connections_selection_provider.dart
  presentation/providers/connections_layout_controller.dart
  presentation/canvas/graph_viewport.dart
  presentation/canvas/connections_hit_tester.dart
  presentation/canvas/label_collision.dart
  presentation/canvas/node_metrics.dart
  presentation/canvas/connection_kind_colors.dart
  presentation/canvas/connections_painter.dart
  presentation/canvas/connections_canvas.dart
  presentation/widgets/lens_chip_row.dart
  presentation/widgets/connections_filter_action.dart
  presentation/widgets/connections_filter_bar.dart
  presentation/widgets/year_range_slider.dart
  presentation/widgets/selection_details.dart
  presentation/widgets/selection_card.dart
  presentation/widgets/selection_panel.dart
  presentation/widgets/connections_legend.dart
  presentation/widgets/hidden_nodes_chip.dart
  presentation/widgets/connections_empty_state.dart
  presentation/pages/connections_page.dart
```

Modified: `lib/shared/widgets/nav/nav_destinations.dart`, `lib/core/theme/feature_accent_colors.dart`, `lib/core/router/app_router.dart`, `lib/features/buddies/presentation/pages/buddy_detail_page.dart`, the eleven `lib/l10n/arb/app_*.arb`, `test/core/database/dive_stats_scope_census_test.dart`, `test/shared/widgets/nav/nav_destinations_test.dart`, `test/architecture/provider_tick_build_smoke_test.dart`, `test/core/router/app_router_test.dart`.

Tests mirror the `lib/` tree under `test/features/connections/`.

---

### Task 1: Domain entities

**Files:**
- Create: `lib/features/connections/domain/entities/connection_kind.dart`
- Create: `lib/features/connections/domain/entities/node_ref.dart`
- Create: `lib/features/connections/domain/entities/connection_node.dart`
- Create: `lib/features/connections/domain/entities/connection_edge.dart`
- Create: `lib/features/connections/domain/entities/connection_graph.dart`
- Create: `lib/features/connections/domain/entities/connection_query.dart`
- Create: `lib/features/connections/domain/entities/graph_selection.dart`
- Test: `test/features/connections/domain/entities/node_ref_test.dart`
- Test: `test/features/connections/domain/entities/connection_graph_test.dart`
- Test: `test/features/connections/domain/entities/connection_query_test.dart`

**Interfaces:**
- Produces: `ConnectionKind` (enum with `fromName`, `accentFeatureId`, `detailRoute(id)`), `NodeRef(kind, id)` with `wire` and `parse`, `NodeSubtitle` (`TextSubtitle`, `DateRangeSubtitle`, `RoleSubtitle`), `ConnectionNode`, `ConnectionEdge` (`touches`, `otherEnd`), `ConnectionGraph` (`trimmed`, `weightedDegree`, `edgesOf`, `nodeFor`, `maxDiveCount`, `maxWeight`), `ConnectionQuery` (`isSelfJoin`, `neighbourKind`, `focusIsValid`), `GraphSelection` (`NodeSelection`, `EdgeSelection`).

- [ ] **Step 1: Write the failing tests**

`test/features/connections/domain/entities/node_ref_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

void main() {
  test('wire form round-trips through parse', () {
    const ref = NodeRef(ConnectionKind.diveCenter, 'abc:with:colons');
    expect(ref.wire, 'diveCenter:abc:with:colons');
    expect(NodeRef.parse(ref.wire), ref);
  });

  test('parse rejects malformed values', () {
    expect(NodeRef.parse(null), isNull);
    expect(NodeRef.parse(''), isNull);
    expect(NodeRef.parse('buddy'), isNull);
    expect(NodeRef.parse('buddy:'), isNull);
    expect(NodeRef.parse(':abc'), isNull);
    expect(NodeRef.parse('unicorn:abc'), isNull);
  });

  test('kinds without a detail page return null routes', () {
    expect(ConnectionKind.buddy.detailRoute('b1'), '/buddies/b1');
    expect(ConnectionKind.site.detailRoute('s1'), '/sites/s1');
    expect(ConnectionKind.tag.detailRoute('t1'), isNull);
    expect(ConnectionKind.diveComputer.detailRoute('c1'), isNull);
  });

  test('every kind but tag borrows a destination accent', () {
    for (final kind in ConnectionKind.values) {
      expect(kind.accentFeatureId, kind == ConnectionKind.tag ? isNull : isNotNull);
    }
  });
}
```

`test/features/connections/domain/entities/connection_graph_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionNode _node(String id, int dives) =>
    ConnectionNode(ref: _b(id), label: id, diveCount: dives);

ConnectionEdge _edge(String a, String b, int w) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: w,
  firstDiveAt: DateTime.utc(2024, 1, 1),
  lastDiveAt: DateTime.utc(2024, 6, 1),
);

void main() {
  final graph = ConnectionGraph(
    nodes: [_node('a', 5), _node('b', 5), _node('c', 2), _node('d', 9)],
    edges: [_edge('a', 'b', 3), _edge('b', 'c', 1), _edge('a', 'c', 1)],
  );

  test('weightedDegree sums the weights of touching edges', () {
    expect(graph.weightedDegree(_b('a')), 4);
    expect(graph.weightedDegree(_b('b')), 4);
    expect(graph.weightedDegree(_b('d')), 0);
  });

  test('trimmed keeps top nodes by dive count, then degree, then id', () {
    final t = graph.trimmed(2);
    expect(t.nodes.map((n) => n.ref.id), ['d', 'a']);
    expect(t.hiddenNodeCount, 2);
    expect(t.edges, isEmpty, reason: 'edges to trimmed nodes are dropped');
  });

  test('trimmed keeps the focus even when it ranks below the budget', () {
    final t = graph.trimmed(2, keep: _b('c'));
    expect(t.nodes.map((n) => n.ref.id).toSet(), {'d', 'c'});
    expect(t.hiddenNodeCount, 2);
  });

  test('trimmed is the identity when the budget is not exceeded', () {
    expect(identical(graph.trimmed(4), graph), isTrue);
    expect(graph.trimmed(4).hiddenNodeCount, 0);
  });

  test('maxDiveCount and maxWeight are zero on an empty graph', () {
    expect(ConnectionGraph.empty.maxDiveCount, 0);
    expect(ConnectionGraph.empty.maxWeight, 0);
    expect(ConnectionGraph.empty.isEmpty, isTrue);
  });

  test('edge helpers know both ends', () {
    final e = _edge('a', 'b', 1);
    expect(e.touches(_b('a')), isTrue);
    expect(e.otherEnd(_b('a')), _b('b'));
    expect(e.otherEnd(_b('b')), _b('a'));
    expect(e.otherEnd(_b('z')), isNull);
  });
}
```

`test/features/connections/domain/entities/connection_query_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_query.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

void main() {
  test('self-join is detected', () {
    const q = ConnectionQuery(kindA: ConnectionKind.buddy, kindB: ConnectionKind.buddy);
    expect(q.isSelfJoin, isTrue);
    expect(q.focusIsValid, isTrue);
  });

  test('neighbourKind is the far end of the focus', () {
    const q = ConnectionQuery(
      kindA: ConnectionKind.buddy,
      kindB: ConnectionKind.site,
      focus: NodeRef(ConnectionKind.site, 's1'),
    );
    expect(q.neighbourKind, ConnectionKind.buddy);
    expect(q.focusIsValid, isTrue);
  });

  test('a focus whose kind is not in the query is invalid', () {
    const q = ConnectionQuery(
      kindA: ConnectionKind.buddy,
      kindB: ConnectionKind.buddy,
      focus: NodeRef(ConnectionKind.site, 's1'),
    );
    expect(q.neighbourKind, isNull);
    expect(q.focusIsValid, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/domain/entities/`
Expected: FAIL, the imports do not resolve.

- [ ] **Step 3: Write the entities**

`lib/features/connections/domain/entities/connection_kind.dart`:

```dart
/// The kinds of entity that can sit at either end of a connection.
///
/// Every kind is linked to dives, so any two kinds (or one kind with itself)
/// can be related by counting the dives they share.
enum ConnectionKind {
  buddy,
  site,
  trip,
  diveCenter,
  equipment,
  species,
  tag,
  diveType,
  diveComputer,
  course;

  /// Parses the enum name as written in routes and [NodeRef] wire strings.
  static ConnectionKind? fromName(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  /// The nav destination whose accent colour this kind borrows for node
  /// fills and the legend. Null for tags, which carry their own colour.
  String? get accentFeatureId => switch (this) {
    ConnectionKind.buddy => 'buddies',
    ConnectionKind.site => 'sites',
    ConnectionKind.trip => 'trips',
    ConnectionKind.diveCenter => 'dive-centers',
    ConnectionKind.equipment => 'equipment',
    ConnectionKind.species => 'species',
    ConnectionKind.course => 'courses',
    ConnectionKind.diveType => 'dives',
    ConnectionKind.diveComputer => 'transfer',
    ConnectionKind.tag => null,
  };

  /// The detail route for an entity of this kind, or null when the kind has
  /// no detail page (tags, dive types and computers live in Settings).
  String? detailRoute(String id) => switch (this) {
    ConnectionKind.buddy => '/buddies/$id',
    ConnectionKind.site => '/sites/$id',
    ConnectionKind.trip => '/trips/$id',
    ConnectionKind.diveCenter => '/dive-centers/$id',
    ConnectionKind.equipment => '/equipment/$id',
    ConnectionKind.species => '/species/$id',
    ConnectionKind.course => '/courses/$id',
    ConnectionKind.tag ||
    ConnectionKind.diveType ||
    ConnectionKind.diveComputer => null,
  };
}
```

`lib/features/connections/domain/entities/node_ref.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'connection_kind.dart';

/// Identity of a node: the kind plus the entity's own table id.
///
/// Ids from different tables can collide, so nothing in the feature keys on
/// a bare id. Layout, selection, focus and deep links all use this type.
class NodeRef extends Equatable {
  const NodeRef(this.kind, this.id);

  final ConnectionKind kind;
  final String id;

  /// `kind:id`, the form used in route query parameters.
  String get wire => '${kind.name}:$id';

  /// Parses [wire]; null for anything malformed or an unknown kind.
  static NodeRef? parse(String? value) {
    if (value == null) return null;
    final split = value.indexOf(':');
    if (split <= 0 || split == value.length - 1) return null;
    final kind = ConnectionKind.fromName(value.substring(0, split));
    if (kind == null) return null;
    return NodeRef(kind, value.substring(split + 1));
  }

  @override
  List<Object?> get props => [kind, id];

  @override
  String toString() => wire;
}
```

`lib/features/connections/domain/entities/connection_node.dart`:

```dart
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'node_ref.dart';

/// A node's second line. Formatting that needs localisation or the diver's
/// unit settings (a date range, a role name) is deferred to presentation, so
/// the repository never produces display text for those.
sealed class NodeSubtitle extends Equatable {
  const NodeSubtitle();
}

/// Plain text already fit to show (a country, a scientific name).
class TextSubtitle extends NodeSubtitle {
  const TextSubtitle(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

/// A trip's span, formatted with UnitFormatter.formatDateRange.
class DateRangeSubtitle extends NodeSubtitle {
  const DateRangeSubtitle(this.start, this.end);
  final DateTime start;
  final DateTime end;
  @override
  List<Object?> get props => [start, end];
}

/// A buddy's unanimous dive role id, resolved through diveRoleMapProvider.
class RoleSubtitle extends NodeSubtitle {
  const RoleSubtitle(this.roleId);
  final String roleId;
  @override
  List<Object?> get props => [roleId];
}

class ConnectionNode extends Equatable {
  const ConnectionNode({
    required this.ref,
    required this.label,
    required this.diveCount,
    this.subtitle,
    this.photo,
  });

  final NodeRef ref;
  final String label;

  /// Distinct dives this entity has within the query's scope and filter.
  final int diveCount;
  final NodeSubtitle? subtitle;

  /// Buddy photo bytes when the buddy has one; null for every other kind.
  final Uint8List? photo;

  ConnectionNode copyWith({
    NodeRef? ref,
    String? label,
    int? diveCount,
    NodeSubtitle? subtitle,
    Uint8List? photo,
  }) {
    return ConnectionNode(
      ref: ref ?? this.ref,
      label: label ?? this.label,
      diveCount: diveCount ?? this.diveCount,
      subtitle: subtitle ?? this.subtitle,
      photo: photo ?? this.photo,
    );
  }

  @override
  List<Object?> get props => [ref, label, diveCount, subtitle, photo];
}
```

`lib/features/connections/domain/entities/connection_edge.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'node_ref.dart';

/// Two entities that shared [weight] dives.
///
/// Self-join lenses produce undirected edges with `source.id < target.id`;
/// mixed lenses keep the query's kind A as source and kind B as target.
class ConnectionEdge extends Equatable {
  const ConnectionEdge({
    required this.source,
    required this.target,
    required this.weight,
    required this.firstDiveAt,
    required this.lastDiveAt,
  });

  final NodeRef source;
  final NodeRef target;
  final int weight;
  final DateTime firstDiveAt;
  final DateTime lastDiveAt;

  bool touches(NodeRef ref) => source == ref || target == ref;

  /// The end that is not [ref], or null when [ref] is not on this edge.
  NodeRef? otherEnd(NodeRef ref) {
    if (source == ref) return target;
    if (target == ref) return source;
    return null;
  }

  ConnectionEdge copyWith({
    NodeRef? source,
    NodeRef? target,
    int? weight,
    DateTime? firstDiveAt,
    DateTime? lastDiveAt,
  }) {
    return ConnectionEdge(
      source: source ?? this.source,
      target: target ?? this.target,
      weight: weight ?? this.weight,
      firstDiveAt: firstDiveAt ?? this.firstDiveAt,
      lastDiveAt: lastDiveAt ?? this.lastDiveAt,
    );
  }

  @override
  List<Object?> get props => [source, target, weight, firstDiveAt, lastDiveAt];
}
```

`lib/features/connections/domain/entities/connection_graph.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'connection_edge.dart';
import 'connection_node.dart';
import 'node_ref.dart';

class ConnectionGraph extends Equatable {
  const ConnectionGraph({
    required this.nodes,
    required this.edges,
    this.hiddenNodeCount = 0,
  });

  static const empty = ConnectionGraph(nodes: [], edges: []);

  final List<ConnectionNode> nodes;
  final List<ConnectionEdge> edges;

  /// Nodes removed by [trimmed]; shown as "N more not shown".
  final int hiddenNodeCount;

  bool get isEmpty => nodes.isEmpty;

  int get maxDiveCount =>
      nodes.fold(0, (m, n) => n.diveCount > m ? n.diveCount : m);

  int get maxWeight => edges.fold(0, (m, e) => e.weight > m ? e.weight : m);

  ConnectionNode? nodeFor(NodeRef ref) {
    for (final n in nodes) {
      if (n.ref == ref) return n;
    }
    return null;
  }

  List<ConnectionEdge> edgesOf(NodeRef ref) =>
      edges.where((e) => e.touches(ref)).toList();

  int weightedDegree(NodeRef ref) =>
      edgesOf(ref).fold(0, (sum, e) => sum + e.weight);

  /// Keeps the top [budget] nodes by dive count, then weighted degree, then
  /// id, plus [keep] (the focus) if it would otherwise fall out. Edges that
  /// touch a removed node are dropped. Returns `this` when nothing is cut.
  ConnectionGraph trimmed(int budget, {NodeRef? keep}) {
    if (nodes.length <= budget) return this;
    final degree = <NodeRef, int>{};
    for (final e in edges) {
      degree[e.source] = (degree[e.source] ?? 0) + e.weight;
      degree[e.target] = (degree[e.target] ?? 0) + e.weight;
    }
    final ranked = [...nodes]
      ..sort((a, b) {
        final byDives = b.diveCount.compareTo(a.diveCount);
        if (byDives != 0) return byDives;
        final byDegree = (degree[b.ref] ?? 0).compareTo(degree[a.ref] ?? 0);
        if (byDegree != 0) return byDegree;
        return a.ref.wire.compareTo(b.ref.wire);
      });
    final kept = ranked.take(budget).toList();
    if (keep != null && !kept.any((n) => n.ref == keep)) {
      final focus = nodeFor(keep);
      if (focus != null) {
        kept.removeLast();
        kept.add(focus);
      }
    }
    final keptRefs = kept.map((n) => n.ref).toSet();
    return ConnectionGraph(
      nodes: kept,
      edges: edges
          .where((e) => keptRefs.contains(e.source) && keptRefs.contains(e.target))
          .toList(),
      hiddenNodeCount: nodes.length - kept.length,
    );
  }

  ConnectionGraph copyWith({
    List<ConnectionNode>? nodes,
    List<ConnectionEdge>? edges,
    int? hiddenNodeCount,
  }) {
    return ConnectionGraph(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      hiddenNodeCount: hiddenNodeCount ?? this.hiddenNodeCount,
    );
  }

  @override
  List<Object?> get props => [nodes, edges, hiddenNodeCount];
}
```

`lib/features/connections/domain/entities/connection_query.dart`:

```dart
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import 'connection_kind.dart';
import 'node_ref.dart';

/// What to load: a pair of kinds, the diver's filter, an optional focus for
/// ego mode, and the node budget.
///
/// Not Equatable on purpose: [DiveFilterState] has no value equality, so this
/// type is never used as a provider family key. Providers watch the lens,
/// filter and focus providers separately and build a query per build.
class ConnectionQuery {
  const ConnectionQuery({
    required this.kindA,
    required this.kindB,
    this.filter = const DiveFilterState(),
    this.focus,
    this.nodeBudget = 80,
  });

  final ConnectionKind kindA;
  final ConnectionKind kindB;
  final DiveFilterState filter;
  final NodeRef? focus;
  final int nodeBudget;

  bool get isSelfJoin => kindA == kindB;

  /// The kind at the far end of [focus]; null without a focus or when the
  /// focus kind is not part of this query.
  ConnectionKind? get neighbourKind {
    final f = focus;
    if (f == null) return null;
    if (f.kind == kindA) return kindB;
    if (f.kind == kindB) return kindA;
    return null;
  }

  bool get focusIsValid => focus == null || neighbourKind != null;

  ConnectionQuery copyWith({
    ConnectionKind? kindA,
    ConnectionKind? kindB,
    DiveFilterState? filter,
    NodeRef? focus,
    bool clearFocus = false,
    int? nodeBudget,
  }) {
    return ConnectionQuery(
      kindA: kindA ?? this.kindA,
      kindB: kindB ?? this.kindB,
      filter: filter ?? this.filter,
      focus: clearFocus ? null : (focus ?? this.focus),
      nodeBudget: nodeBudget ?? this.nodeBudget,
    );
  }
}
```

`lib/features/connections/domain/entities/graph_selection.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'node_ref.dart';

/// What the diver tapped on the canvas.
sealed class GraphSelection extends Equatable {
  const GraphSelection();
}

class NodeSelection extends GraphSelection {
  const NodeSelection(this.ref);
  final NodeRef ref;
  @override
  List<Object?> get props => [ref];
}

class EdgeSelection extends GraphSelection {
  const EdgeSelection(this.a, this.b);
  final NodeRef a;
  final NodeRef b;
  @override
  List<Object?> get props => [a, b];
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/connections/domain/entities/`
Expected: PASS (13 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/entities test/features/connections/domain/entities
git commit -m "feat(connections): domain entities for the connections graph"
```

---

### Task 2: Lenses and lens selection

**Files:**
- Create: `lib/features/connections/domain/lenses/connection_lens.dart`
- Test: `test/features/connections/domain/lenses/connection_lens_test.dart`

**Interfaces:**
- Consumes: `ConnectionKind` (Task 1).
- Produces: `ConnectionLens(id, kindA, kindB)` with `ConnectionLens.circle`, `ConnectionLens.where`, `ConnectionLens.phase1`, `ConnectionLens.byId`; `LensSelection` with `.lens(...)`, `.custom(kindA:, kindB:)`, `persisted`, `parse`, `fallback`, `lensId`, `kindA`, `kindB`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';

void main() {
  test('built-in lenses resolve by id', () {
    expect(ConnectionLens.byId('circle'), ConnectionLens.circle);
    expect(ConnectionLens.byId('where'), ConnectionLens.where);
    expect(ConnectionLens.byId('nope'), isNull);
    expect(ConnectionLens.byId(null), isNull);
  });

  test('a lens selection persists as its id', () {
    const sel = LensSelection.lens(ConnectionLens.where);
    expect(sel.persisted, 'where');
    expect(LensSelection.parse('where'), sel);
    expect(sel.kindA, ConnectionKind.buddy);
    expect(sel.kindB, ConnectionKind.site);
  });

  test('a custom pair persists as custom:a:b and parses back', () {
    const sel = LensSelection.custom(
      kindA: ConnectionKind.equipment,
      kindB: ConnectionKind.trip,
    );
    expect(sel.persisted, 'custom:equipment:trip');
    expect(LensSelection.parse(sel.persisted), sel);
    expect(sel.lensId, isNull);
  });

  test('parse falls back to null on garbage', () {
    expect(LensSelection.parse(null), isNull);
    expect(LensSelection.parse('custom:equipment'), isNull);
    expect(LensSelection.parse('custom:unicorn:trip'), isNull);
    expect(LensSelection.fallback, const LensSelection.lens(ConnectionLens.circle));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/domain/lenses/`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the lens file**

```dart
import 'package:equatable/equatable.dart';

import '../entities/connection_kind.dart';

/// A named pair of kinds. Phase 1 ships two; phase 2 adds four more and the
/// free pair picker, which produces a [LensSelection.custom] instead.
class ConnectionLens extends Equatable {
  const ConnectionLens({
    required this.id,
    required this.kindA,
    required this.kindB,
  });

  final String id;
  final ConnectionKind kindA;
  final ConnectionKind kindB;

  static const circle = ConnectionLens(
    id: 'circle',
    kindA: ConnectionKind.buddy,
    kindB: ConnectionKind.buddy,
  );

  static const where = ConnectionLens(
    id: 'where',
    kindA: ConnectionKind.buddy,
    kindB: ConnectionKind.site,
  );

  /// The lenses offered in the chip row, in display order.
  static const phase1 = [circle, where];

  static ConnectionLens? byId(String? id) {
    for (final lens in phase1) {
      if (lens.id == id) return lens;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, kindA, kindB];
}

/// The active pair: a built-in lens or a custom pair. Persisted device-local
/// under the SharedPreferences key `connections_last_lens`.
class LensSelection extends Equatable {
  const LensSelection.lens(ConnectionLens lens)
    : lensId = lens.id,
      kindA = lens.kindA,
      kindB = lens.kindB;

  const LensSelection.custom({required this.kindA, required this.kindB})
    : lensId = null;

  static const fallback = LensSelection.lens(ConnectionLens.circle);

  final String? lensId;
  final ConnectionKind kindA;
  final ConnectionKind kindB;

  bool get isSelfJoin => kindA == kindB;

  String get persisted => lensId ?? 'custom:${kindA.name}:${kindB.name}';

  static LensSelection? parse(String? value) {
    if (value == null) return null;
    final lens = ConnectionLens.byId(value);
    if (lens != null) return LensSelection.lens(lens);
    final parts = value.split(':');
    if (parts.length != 3 || parts[0] != 'custom') return null;
    final a = ConnectionKind.fromName(parts[1]);
    final b = ConnectionKind.fromName(parts[2]);
    if (a == null || b == null) return null;
    return LensSelection.custom(kindA: a, kindB: b);
  }

  @override
  List<Object?> get props => [lensId, kindA, kindB];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/connections/domain/lenses/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/lenses test/features/connections/domain/lenses
git commit -m "feat(connections): lenses and persisted lens selection"
```

---

### Task 3: SQL builders (scope, membership, edges, nodes)

**Files:**
- Create: `lib/features/connections/data/connections_scope_sql.dart`
- Create: `lib/features/connections/data/connections_membership_sql.dart`
- Create: `lib/features/connections/data/connections_edge_sql.dart`
- Create: `lib/features/connections/data/connections_node_sql.dart`
- Test: `test/features/connections/data/connections_sql_test.dart`

**Interfaces:**
- Consumes: `ConnectionKind`, `NodeRef` (Task 1); `DiveStatsScope` from `lib/core/database/dive_stats_scope.dart`; `buildFilteredDiveIdSubquery` from `lib/features/statistics/data/dive_filter_sql.dart`; `DiveFilterState`.
- Produces: `diveScopeSql({diverId, filter})` returning `({List<String> clauses, List<Object?> params})`; `membershipSql(kind)`; `buildEdgeSql({kindA, kindB, diverId, filter, focus, restrictTo})` and `buildNodeSql({kind, diverId, filter, onlyIds})` and `buildBuddyRoleSql({diverId, filter, buddyIds})`, each returning `({String sql, List<Object?> params})`; `kindTable(kind)` returning `KindTable(table, labelColumn, extraColumns)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/data/connections_edge_sql.dart';
import 'package:submersion/features/connections/data/connections_membership_sql.dart';
import 'package:submersion/features/connections/data/connections_node_sql.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

void main() {
  group('membershipSql', () {
    test('every kind yields dive_id and entity_id columns', () {
      for (final kind in ConnectionKind.values) {
        final sql = membershipSql(kind);
        expect(sql, contains('dive_id'));
        expect(sql, contains('AS entity_id'));
        expect(sql.trim(), startsWith('SELECT'));
      }
    });

    test('column kinds exclude null links', () {
      expect(membershipSql(ConnectionKind.site), contains('site_id IS NOT NULL'));
      expect(membershipSql(ConnectionKind.course), contains('course_id IS NOT NULL'));
    });
  });

  group('buildEdgeSql', () {
    test('self-join dedupes unordered pairs and scopes to the diver', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(r.sql, contains('a.entity_id < b.entity_id'));
      expect(r.sql, contains('d.diver_id = ?'));
      expect(r.sql, contains('d.excluded_from_stats = 0'));
      expect(r.sql, contains('d.is_planned = 0'));
      expect(r.sql, contains('COUNT(DISTINCT d.id) AS weight'));
      expect(r.params, ['me']);
    });

    test('mixed kinds do not dedupe and a null diver adds no clause', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.site,
        diverId: null,
        filter: const DiveFilterState(),
      );
      expect(r.sql, isNot(contains('a.entity_id < b.entity_id')));
      expect(r.sql, isNot(contains('diver_id')));
      expect(r.params, isEmpty);
    });

    test('a focus pins side a and excludes the focus from side b', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: 'me',
        filter: const DiveFilterState(),
        focus: const NodeRef(ConnectionKind.buddy, 'jane'),
      );
      expect(r.sql, contains('a.entity_id = ?'));
      expect(r.sql, contains('b.entity_id <> a.entity_id'));
      expect(r.sql, isNot(contains('a.entity_id < b.entity_id')));
      expect(r.params, ['me', 'jane']);
    });

    test('an active filter appends the id subquery and its params after the diver', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: 'me',
        filter: const DiveFilterState(siteId: 's1'),
      );
      expect(r.sql, contains('d.id IN (SELECT id FROM dives WHERE'));
      expect(r.params, ['me', 's1']);
    });

    test('restrictTo limits both ends', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: null,
        filter: const DiveFilterState(),
        restrictTo: ['x', 'y'],
      );
      expect(r.sql, contains('a.entity_id IN (?, ?)'));
      expect(r.sql, contains('b.entity_id IN (?, ?)'));
      expect(r.params, ['x', 'y', 'x', 'y']);
    });
  });

  group('buildNodeSql', () {
    test('joins counts to the label table and selects extra columns', () {
      final r = buildNodeSql(
        kind: ConnectionKind.site,
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(r.sql, contains('JOIN dive_sites t ON t.id = c.entity_id'));
      expect(r.sql, contains('t.name AS label'));
      expect(r.sql, contains('t.region AS region'));
      expect(r.sql, contains('t.country AS country'));
      expect(r.sql, contains('COUNT(DISTINCT d.id) AS dive_count'));
      expect(r.params, ['me']);
    });

    test('onlyIds narrows the entity set', () {
      final r = buildNodeSql(
        kind: ConnectionKind.buddy,
        diverId: null,
        filter: const DiveFilterState(),
        onlyIds: ['a', 'b'],
      );
      expect(r.sql, contains('m.entity_id IN (?, ?)'));
      expect(r.params, ['a', 'b']);
    });

    test('the buddy role query keeps only unanimous roles', () {
      final r = buildBuddyRoleSql(
        diverId: 'me',
        filter: const DiveFilterState(),
        buddyIds: ['a'],
      );
      expect(r.sql, contains('HAVING COUNT(DISTINCT db.role) = 1'));
      expect(r.params, ['me', 'a']);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/data/connections_sql_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the builders**

`lib/features/connections/data/connections_scope_sql.dart`:

```dart
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

/// The WHERE terms every connections query shares, for a `dives` table
/// aliased `d`: the owning diver (when known), the always-on statistics
/// scope, and the diver's view filter when any axis is active.
///
/// Params are returned in clause order, so callers append their own clauses
/// and params after these.
({List<String> clauses, List<Object?> params}) diveScopeSql({
  required String? diverId,
  required DiveFilterState filter,
}) {
  final clauses = <String>[];
  final params = <Object?>[];
  if (diverId != null) {
    clauses.add('d.diver_id = ?');
    params.add(diverId);
  }
  clauses.add(DiveStatsScope.predicate(alias: 'd'));
  final f = buildFilteredDiveIdSubquery(filter);
  if (f.subquery.isNotEmpty) {
    clauses.add('d.id IN (${f.subquery})');
    params.addAll(f.params);
  }
  return (clauses: clauses, params: params);
}

String placeholders(int count) => List.filled(count, '?').join(', ');
```

`lib/features/connections/data/connections_membership_sql.dart`:

```dart
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// `(dive_id, entity_id)` rows for [kind]. Each fragment is a complete
/// SELECT so it can be embedded as `JOIN (...) alias`.
///
/// Column kinds (site, trip, center, course) read the link straight off
/// `dives`; junction kinds read their many-to-many table.
// stats-scope-exempt: a bare membership fragment carries no aggregate; the
// edge and node builders that embed it apply DiveStatsScope on `dives d`.
String membershipSql(ConnectionKind kind) => switch (kind) {
  ConnectionKind.buddy =>
    'SELECT dive_id, buddy_id AS entity_id FROM dive_buddies',
  ConnectionKind.site =>
    'SELECT id AS dive_id, site_id AS entity_id FROM dives '
        'WHERE site_id IS NOT NULL',
  ConnectionKind.trip =>
    'SELECT id AS dive_id, trip_id AS entity_id FROM dives '
        'WHERE trip_id IS NOT NULL',
  ConnectionKind.diveCenter =>
    'SELECT id AS dive_id, dive_center_id AS entity_id FROM dives '
        'WHERE dive_center_id IS NOT NULL',
  ConnectionKind.equipment =>
    'SELECT dive_id, equipment_id AS entity_id FROM dive_equipment',
  ConnectionKind.species =>
    'SELECT dive_id, species_id AS entity_id FROM sightings',
  ConnectionKind.tag => 'SELECT dive_id, tag_id AS entity_id FROM dive_tags',
  ConnectionKind.diveType =>
    'SELECT dive_id, dive_type_id AS entity_id FROM dive_dive_types',
  ConnectionKind.diveComputer =>
    'SELECT dive_id, computer_id AS entity_id FROM dive_data_sources',
  ConnectionKind.course =>
    'SELECT id AS dive_id, course_id AS entity_id FROM dives '
        'WHERE course_id IS NOT NULL',
};
```

`lib/features/connections/data/connections_edge_sql.dart`:

```dart
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import 'connections_membership_sql.dart';
import 'connections_scope_sql.dart';

/// The co-occurrence query: one row per pair of entities that share at least
/// one dive in scope, with the distinct dive count and the first and last
/// shared dive time (epoch ms).
///
/// - `kindA == kindB` without a focus: undirected, `a.entity_id < b.entity_id`.
/// - With [focus]: side a is pinned to the focus id and, for a self-join,
///   side b excludes it, so the rows are the focus node's spokes.
/// - [restrictTo]: both ends limited to these ids (the chords among a focus
///   node's neighbours). An empty list yields a query that matches nothing.
({String sql, List<Object?> params}) buildEdgeSql({
  required ConnectionKind kindA,
  required ConnectionKind kindB,
  required String? diverId,
  required DiveFilterState filter,
  NodeRef? focus,
  Iterable<String>? restrictTo,
}) {
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final where = [...scope.clauses];
  final params = [...scope.params];
  if (focus != null) {
    where.add('a.entity_id = ?');
    params.add(focus.id);
    if (kindA == kindB) where.add('b.entity_id <> a.entity_id');
  } else if (kindA == kindB) {
    where.add('a.entity_id < b.entity_id');
  }
  if (restrictTo != null) {
    final ids = restrictTo.toList();
    if (ids.isEmpty) {
      where.add('0 = 1');
    } else {
      final ph = placeholders(ids.length);
      where.add('a.entity_id IN ($ph)');
      params.addAll(ids);
      where.add('b.entity_id IN ($ph)');
      params.addAll(ids);
    }
  }
  final sql =
      '''
SELECT a.entity_id AS source, b.entity_id AS target,
       COUNT(DISTINCT d.id) AS weight,
       MIN(d.dive_date_time) AS first_ms,
       MAX(d.dive_date_time) AS last_ms
FROM dives d
JOIN (${membershipSql(kindA)}) a ON a.dive_id = d.id
JOIN (${membershipSql(kindB)}) b ON b.dive_id = d.id
WHERE ${where.join(' AND ')}
GROUP BY a.entity_id, b.entity_id
ORDER BY weight DESC, source ASC, target ASC''';
  return (sql: sql, params: params);
}
```

`lib/features/connections/data/connections_node_sql.dart`:

```dart
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import 'connections_membership_sql.dart';
import 'connections_scope_sql.dart';

/// Where a kind's label and subtitle columns live.
class KindTable {
  const KindTable(this.table, this.labelColumn, [this.extraColumns = const []]);
  final String table;
  final String labelColumn;
  final List<String> extraColumns;
}

KindTable kindTable(ConnectionKind kind) => switch (kind) {
  ConnectionKind.buddy => const KindTable('buddies', 'name', ['photo']),
  ConnectionKind.site =>
    const KindTable('dive_sites', 'name', ['region', 'country']),
  ConnectionKind.trip =>
    const KindTable('trips', 'name', ['start_date', 'end_date']),
  ConnectionKind.diveCenter =>
    const KindTable('dive_centers', 'name', ['country']),
  ConnectionKind.equipment => const KindTable('equipment', 'name', ['type']),
  ConnectionKind.species =>
    const KindTable('species', 'common_name', ['scientific_name']),
  ConnectionKind.tag => const KindTable('tags', 'name', ['color']),
  ConnectionKind.diveType => const KindTable('dive_types', 'name'),
  ConnectionKind.diveComputer =>
    const KindTable('dive_computers', 'name', ['manufacturer', 'model']),
  ConnectionKind.course => const KindTable('courses', 'name'),
};

/// Every entity of [kind] with at least one dive in scope, with its own
/// distinct dive count and the columns its subtitle needs.
({String sql, List<Object?> params}) buildNodeSql({
  required ConnectionKind kind,
  required String? diverId,
  required DiveFilterState filter,
  Iterable<String>? onlyIds,
}) {
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final where = [...scope.clauses];
  final params = [...scope.params];
  if (onlyIds != null) {
    final ids = onlyIds.toList();
    if (ids.isEmpty) {
      where.add('0 = 1');
    } else {
      where.add('m.entity_id IN (${placeholders(ids.length)})');
      params.addAll(ids);
    }
  }
  final t = kindTable(kind);
  final extra = t.extraColumns.map((c) => ', t.$c AS $c').join();
  final sql =
      '''
SELECT t.id AS id, t.${t.labelColumn} AS label$extra, c.dive_count AS dive_count
FROM (
  SELECT m.entity_id, COUNT(DISTINCT d.id) AS dive_count
  FROM (${membershipSql(kind)}) m
  JOIN dives d ON d.id = m.dive_id
  WHERE ${where.join(' AND ')}
  GROUP BY m.entity_id
) c
JOIN ${t.table} t ON t.id = c.entity_id
ORDER BY c.dive_count DESC, label ASC''';
  return (sql: sql, params: params);
}

/// One row per buddy in [buddyIds] whose dives in scope all carry the same
/// role: `id`, `role`.
({String sql, List<Object?> params}) buildBuddyRoleSql({
  required String? diverId,
  required DiveFilterState filter,
  required Iterable<String> buddyIds,
}) {
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final ids = buddyIds.toList();
  final where = [...scope.clauses, 'db.buddy_id IN (${placeholders(ids.length)})'];
  final sql =
      '''
SELECT db.buddy_id AS id, MIN(db.role) AS role
FROM dive_buddies db
JOIN dives d ON d.id = db.dive_id
WHERE ${where.join(' AND ')}
GROUP BY db.buddy_id
HAVING COUNT(DISTINCT db.role) = 1''';
  return (sql: sql, params: [...scope.params, ...ids]);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/connections/data/connections_sql_test.dart`
Expected: PASS. If the `d.id IN (SELECT id FROM dives WHERE` assertion fails, read the exact prefix `buildFilteredDiveIdSubquery` emits (`lib/features/statistics/data/dive_filter_sql.dart`, the return at the end of the function) and assert on that prefix instead; the intent is only that the subquery is embedded.

- [ ] **Step 5: Add the four data files to the stats-scope census**

Modify `test/core/database/dive_stats_scope_census_test.dart`: in `_censusFiles`, after the `course_requirement_repository.dart` line, add:

```dart
  'lib/features/connections/data/connections_scope_sql.dart',
  'lib/features/connections/data/connections_membership_sql.dart',
  'lib/features/connections/data/connections_edge_sql.dart',
  'lib/features/connections/data/connections_node_sql.dart',
  'lib/features/connections/data/repositories/connections_repository.dart',
```

The repository file does not exist until Task 4; the census reads files by path, so run this test only after Task 4 lands (Task 4 Step 5 runs it).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/data test/features/connections/data test/core/database/dive_stats_scope_census_test.dart
git commit -m "feat(connections): co-occurrence SQL builders"
```

---

### Task 4: ConnectionsRepository

**Files:**
- Create: `lib/features/connections/data/repositories/connections_repository.dart`
- Test: `test/features/connections/data/repositories/connections_repository_test.dart`

**Interfaces:**
- Consumes: builders from Task 3; entities from Task 1; `DatabaseService.instance.database`; `DiveRepository.changeTickDebounce` from `lib/features/dive_log/data/repositories/dive_repository_impl.dart`; the `debounce` extension the statistics repository uses (same import as `statistics_repository.dart`, check its import block for the stream extension package and copy it).
- Produces:
  - `class FocusNotFoundException implements Exception { final NodeRef ref; }`
  - `Future<ConnectionGraph> loadGraph(ConnectionQuery query, {required String? diverId})` (trimmed to `query.nodeBudget`, throws `ArgumentError` when `!query.focusIsValid`, throws `FocusNotFoundException` when the focus entity has no row)
  - `Future<({int first, int last})?> diveYearSpan({required String? diverId})`
  - `Future<List<String>> diveIdsFor(GraphSelection selection, {required String? diverId, required DiveFilterState filter})`
  - `Stream<void> watchConnectionsChanges()`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/connection_query.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);

Future<void> _diver(db.AppDatabase d, String id) async {
  final ms = DateTime(2024, 1, 1).millisecondsSinceEpoch;
  await d
      .into(d.divers)
      .insert(
        db.DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _buddy(db.AppDatabase d, String id) async {
  final ms = DateTime(2024, 1, 1).millisecondsSinceEpoch;
  await d
      .into(d.buddies)
      .insert(
        db.BuddiesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _site(db.AppDatabase d, String id, {String? country}) async {
  final ms = DateTime(2024, 1, 1).millisecondsSinceEpoch;
  await d
      .into(d.diveSites)
      .insert(
        db.DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          country: Value(country),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _dive(
  db.AppDatabase d, {
  required String id,
  required DateTime at,
  String? diverId = 'me',
  String? siteId,
  bool planned = false,
  bool excluded = false,
}) async {
  final ms = at.millisecondsSinceEpoch;
  await d
      .into(d.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          siteId: Value(siteId),
          diveDateTime: Value(ms),
          isPlanned: Value(planned),
          excludedFromStats: Value(excluded),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _link(
  db.AppDatabase d,
  String diveId,
  String buddyId, {
  String role = 'buddy',
  String? rowId,
}) async {
  await d
      .into(d.diveBuddies)
      .insert(
        db.DiveBuddiesCompanion(
          id: Value(rowId ?? '$diveId-$buddyId'),
          diveId: Value(diveId),
          buddyId: Value(buddyId),
          role: Value(role),
          createdAt: Value(DateTime(2024, 1, 1).millisecondsSinceEpoch),
        ),
      );
}

const _circle = ConnectionQuery(
  kindA: ConnectionKind.buddy,
  kindB: ConnectionKind.buddy,
);
const _where = ConnectionQuery(
  kindA: ConnectionKind.buddy,
  kindB: ConnectionKind.site,
);

void main() {
  late ConnectionsRepository repo;
  late db.AppDatabase d;

  setUp(() async {
    await setUpTestDatabase();
    d = DatabaseService.instance.database;
    repo = ConnectionsRepository();
    await _diver(d, 'me');
    await _diver(d, 'other');
    for (final b in ['jane', 'ken', 'lou']) {
      await _buddy(d, b);
    }
    await _site(d, 's1', country: 'Bonaire');
    await _site(d, 's2');
    // d1: jane + ken at s1. d2: jane + ken at s1. d3: jane + lou at s2.
    await _dive(d, id: 'd1', at: DateTime.utc(2024, 1, 10), siteId: 's1');
    await _dive(d, id: 'd2', at: DateTime.utc(2024, 3, 5), siteId: 's1');
    await _dive(d, id: 'd3', at: DateTime.utc(2024, 6, 1), siteId: 's2');
    await _link(d, 'd1', 'jane');
    await _link(d, 'd1', 'ken');
    await _link(d, 'd2', 'jane');
    await _link(d, 'd2', 'ken');
    await _link(d, 'd3', 'jane');
    await _link(d, 'd3', 'lou', role: 'instructor');
  });

  tearDown(() async => tearDownTestDatabase());

  group('whole web', () {
    test('buddy to buddy edges carry distinct dive counts and dates', () async {
      final g = await repo.loadGraph(_circle, diverId: 'me');
      final janeKen = g.edges.singleWhere(
        (e) => e.source == _b('jane') && e.target == _b('ken'),
      );
      expect(janeKen.weight, 2);
      expect(janeKen.firstDiveAt, DateTime.utc(2024, 1, 10));
      expect(janeKen.lastDiveAt, DateTime.utc(2024, 3, 5));
      final janeLou = g.edges.singleWhere(
        (e) => e.source == _b('jane') && e.target == _b('lou'),
      );
      expect(janeLou.weight, 1);
      expect(g.edges.length, 2, reason: 'ken and lou never dived together');
    });

    test('nodes come from membership with their own dive counts', () async {
      final g = await repo.loadGraph(_circle, diverId: 'me');
      final counts = {for (final n in g.nodes) n.ref.id: n.diveCount};
      expect(counts, {'jane': 3, 'ken': 2, 'lou': 1});
      expect(g.hiddenNodeCount, 0);
    });

    test('a buddy with one role gets a RoleSubtitle, mixed roles none', () async {
      await _link(d, 'd1', 'lou', role: 'buddy', rowId: 'extra-lou');
      final g = await repo.loadGraph(_circle, diverId: 'me');
      final jane = g.nodeFor(_b('jane'))!;
      final lou = g.nodeFor(_b('lou'))!;
      expect(jane.subtitle, const RoleSubtitle('buddy'));
      expect(lou.subtitle, isNull);
    });

    test('duplicate junction rows count a dive once', () async {
      await _link(d, 'd1', 'jane', rowId: 'dup');
      final g = await repo.loadGraph(_circle, diverId: 'me');
      final janeKen = g.edges.singleWhere((e) => e.touches(_b('ken')));
      expect(janeKen.weight, 2);
      expect(g.nodeFor(_b('jane'))!.diveCount, 3);
    });

    test('planned and excluded dives form no edge and add to no count', () async {
      await _dive(d, id: 'p1', at: DateTime.utc(2025, 1, 1), planned: true);
      await _dive(d, id: 'x1', at: DateTime.utc(2025, 1, 2), excluded: true);
      await _link(d, 'p1', 'ken');
      await _link(d, 'p1', 'lou');
      await _link(d, 'x1', 'ken');
      await _link(d, 'x1', 'lou');
      final g = await repo.loadGraph(_circle, diverId: 'me');
      expect(g.edges.any((e) => e.touches(_b('ken')) && e.touches(_b('lou'))), isFalse);
      expect(g.nodeFor(_b('ken'))!.diveCount, 2);
    });

    test('another diver\'s dives are ignored, a null diver sees them all', () async {
      await _dive(d, id: 'o1', at: DateTime.utc(2025, 2, 1), diverId: 'other');
      await _link(d, 'o1', 'ken');
      await _link(d, 'o1', 'lou');
      final mine = await repo.loadGraph(_circle, diverId: 'me');
      expect(mine.edges.any((e) => e.touches(_b('lou')) && e.touches(_b('ken'))), isFalse);
      final all = await repo.loadGraph(_circle, diverId: null);
      expect(all.edges.any((e) => e.touches(_b('lou')) && e.touches(_b('ken'))), isTrue);
    });

    test('the view filter narrows edges and counts', () async {
      final q = ConnectionQuery(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        filter: const DiveFilterState(siteId: 's2'),
      );
      final g = await repo.loadGraph(q, diverId: 'me');
      expect(g.edges.length, 1);
      expect(g.edges.single.touches(_b('lou')), isTrue);
      expect(g.nodeFor(_b('jane'))!.diveCount, 1);
      expect(g.nodeFor(_b('ken')), isNull, reason: 'no dives at s2');
    });

    test('mixed lens keeps kind A as source and includes isolated sites', () async {
      await _site(d, 's3');
      await _dive(d, id: 'd4', at: DateTime.utc(2024, 7, 1), siteId: 's3');
      final g = await repo.loadGraph(_where, diverId: 'me');
      for (final e in g.edges) {
        expect(e.source.kind, ConnectionKind.buddy);
        expect(e.target.kind, ConnectionKind.site);
      }
      final janeS1 = g.edges.singleWhere(
        (e) => e.source == _b('jane') && e.target == _s('s1'),
      );
      expect(janeS1.weight, 2);
      final s3 = g.nodeFor(_s('s3'))!;
      expect(s3.diveCount, 1, reason: 'a site dived alone is an island');
      expect(g.nodeFor(_s('s1'))!.subtitle, const TextSubtitle('Bonaire'));
      expect(g.nodeFor(_s('s2'))!.subtitle, isNull);
    });

    test('the budget trims and reports hidden nodes', () async {
      final g = await repo.loadGraph(_circle.copyWith(nodeBudget: 2), diverId: 'me');
      expect(g.nodes.map((n) => n.ref.id).toSet(), {'jane', 'ken'});
      expect(g.hiddenNodeCount, 1);
    });
  });

  group('ego', () {
    test('spokes, neighbours and chords around the focus', () async {
      // ken and lou share d5 so a chord exists between two of jane's neighbours.
      await _dive(d, id: 'd5', at: DateTime.utc(2024, 8, 1));
      await _link(d, 'd5', 'ken');
      await _link(d, 'd5', 'lou');
      final g = await repo.loadGraph(_circle.copyWith(focus: _b('jane')), diverId: 'me');
      expect(g.nodes.map((n) => n.ref.id).toSet(), {'jane', 'ken', 'lou'});
      final spokes = g.edges.where((e) => e.touches(_b('jane'))).toList();
      expect(spokes.length, 2);
      expect(spokes.every((e) => e.source == _b('jane')), isTrue);
      final chord = g.edges.singleWhere((e) => !e.touches(_b('jane')));
      expect({chord.source.id, chord.target.id}, {'ken', 'lou'});
    });

    test('a mixed-lens focus on kind B swaps sides', () async {
      final g = await repo.loadGraph(_where.copyWith(focus: _s('s1')), diverId: 'me');
      expect(g.nodes.map((n) => n.ref).toSet(), {_s('s1'), _b('jane'), _b('ken')});
      expect(g.edges.every((e) => e.source == _s('s1')), isTrue);
    });

    test('a focus with no row throws FocusNotFoundException', () async {
      expect(
        () => repo.loadGraph(_circle.copyWith(focus: _b('ghost')), diverId: 'me'),
        throwsA(isA<FocusNotFoundException>()),
      );
    });

    test('a focus with no dives in scope is still returned alone', () async {
      await _buddy(d, 'newbie');
      final g = await repo.loadGraph(_circle.copyWith(focus: _b('newbie')), diverId: 'me');
      expect(g.nodes.single.ref, _b('newbie'));
      expect(g.nodes.single.diveCount, 0);
      expect(g.edges, isEmpty);
    });

    test('an invalid focus kind is an ArgumentError', () async {
      expect(
        () => repo.loadGraph(_circle.copyWith(focus: _s('s1')), diverId: 'me'),
        throwsArgumentError,
      );
    });
  });

  group('helpers', () {
    test('diveYearSpan spans the scoped dives', () async {
      await _dive(d, id: 'old', at: DateTime.utc(2019, 5, 5));
      await _dive(d, id: 'planned', at: DateTime.utc(2031, 1, 1), planned: true);
      final span = await repo.diveYearSpan(diverId: 'me');
      expect(span, (first: 2019, last: 2024));
      expect(await repo.diveYearSpan(diverId: 'nobody'), isNull);
    });

    test('diveIdsFor a node and an edge', () async {
      final jane = await repo.diveIdsFor(
        const NodeSelection(NodeRef(ConnectionKind.buddy, 'jane')),
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(jane.toSet(), {'d1', 'd2', 'd3'});
      final pair = await repo.diveIdsFor(
        EdgeSelection(_b('jane'), _b('ken')),
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(pair.toSet(), {'d1', 'd2'});
    });

    test('watchConnectionsChanges fires on a junction write', () async {
      final events = <void>[];
      final sub = repo.watchConnectionsChanges().listen(events.add);
      await _link(d, 'd3', 'ken');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await sub.cancel();
      expect(events, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/data/repositories/`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the repository**

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/connections_edge_sql.dart';
import 'package:submersion/features/connections/data/connections_membership_sql.dart';
import 'package:submersion/features/connections/data/connections_node_sql.dart';
import 'package:submersion/features/connections/data/connections_scope_sql.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/connection_query.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// The focus of an ego query has no row in its label table.
class FocusNotFoundException implements Exception {
  const FocusNotFoundException(this.ref);
  final NodeRef ref;
  @override
  String toString() => 'FocusNotFoundException($ref)';
}

/// Reads connection graphs. Every aggregate over `dives` goes through
/// [DiveStatsScope] via [diveScopeSql]; the diver's view filter is applied
/// only when an axis is active.
class ConnectionsRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  Future<ConnectionGraph> loadGraph(
    ConnectionQuery query, {
    required String? diverId,
  }) async {
    if (!query.focusIsValid) {
      throw ArgumentError.value(
        query.focus,
        'focus',
        'focus kind is not part of this query',
      );
    }
    final focus = query.focus;
    final graph = focus == null
        ? await _wholeWeb(query, diverId)
        : await _ego(query, focus, diverId);
    return graph.trimmed(query.nodeBudget, keep: focus);
  }

  Future<ConnectionGraph> _wholeWeb(ConnectionQuery q, String? diverId) async {
    final edges = await _edges(q.kindA, q.kindB, diverId, q.filter);
    final nodes = <ConnectionNode>[
      for (final kind in {q.kindA, q.kindB})
        ...await _nodes(kind, diverId, q.filter),
    ];
    return ConnectionGraph(nodes: nodes, edges: edges);
  }

  Future<ConnectionGraph> _ego(
    ConnectionQuery q,
    NodeRef focus,
    String? diverId,
  ) async {
    final other = q.neighbourKind!;
    final spokes = await _edges(
      focus.kind,
      other,
      diverId,
      q.filter,
      focus: focus,
    );
    final neighbourIds = spokes.map((e) => e.target.id).toSet();
    var focusNodes = await _nodes(
      focus.kind,
      diverId,
      q.filter,
      onlyIds: {focus.id},
    );
    if (focusNodes.isEmpty) {
      focusNodes = [await _labelOnly(focus)];
    }
    final neighbours = neighbourIds.isEmpty
        ? const <ConnectionNode>[]
        : await _nodes(other, diverId, q.filter, onlyIds: neighbourIds);
    var edges = spokes;
    if (q.isSelfJoin && neighbourIds.length > 1) {
      final chords = await _edges(
        other,
        other,
        diverId,
        q.filter,
        restrictTo: neighbourIds,
      );
      edges = [...spokes, ...chords];
    }
    return ConnectionGraph(nodes: [...focusNodes, ...neighbours], edges: edges);
  }

  Future<List<ConnectionEdge>> _edges(
    ConnectionKind kindA,
    ConnectionKind kindB,
    String? diverId,
    DiveFilterState filter, {
    NodeRef? focus,
    Iterable<String>? restrictTo,
  }) async {
    final q = buildEdgeSql(
      kindA: kindA,
      kindB: kindB,
      diverId: diverId,
      filter: filter,
      focus: focus,
      restrictTo: restrictTo,
    );
    final rows = await _db
        .customSelect(q.sql, variables: q.params.map(Variable.new).toList())
        .get();
    return [
      for (final r in rows)
        ConnectionEdge(
          source: NodeRef(kindA, r.read<String>('source')),
          target: NodeRef(kindB, r.read<String>('target')),
          weight: r.read<int>('weight'),
          firstDiveAt: _ms(r.read<int>('first_ms')),
          lastDiveAt: _ms(r.read<int>('last_ms')),
        ),
    ];
  }

  Future<List<ConnectionNode>> _nodes(
    ConnectionKind kind,
    String? diverId,
    DiveFilterState filter, {
    Iterable<String>? onlyIds,
  }) async {
    final q = buildNodeSql(
      kind: kind,
      diverId: diverId,
      filter: filter,
      onlyIds: onlyIds,
    );
    final rows = await _db
        .customSelect(q.sql, variables: q.params.map(Variable.new).toList())
        .get();
    final nodes = [
      for (final r in rows)
        ConnectionNode(
          ref: NodeRef(kind, r.read<String>('id')),
          label: r.read<String>('label'),
          diveCount: r.read<int>('dive_count'),
          subtitle: _subtitle(kind, r),
          photo: kind == ConnectionKind.buddy
              ? r.readNullable<Uint8List>('photo')
              : null,
        ),
    ];
    if (kind != ConnectionKind.buddy || nodes.isEmpty) return nodes;
    final roles = await _unanimousRoles(
      diverId,
      filter,
      nodes.map((n) => n.ref.id),
    );
    return [
      for (final n in nodes)
        roles.containsKey(n.ref.id)
            ? n.copyWith(subtitle: RoleSubtitle(roles[n.ref.id]!))
            : n,
    ];
  }

  Future<Map<String, String>> _unanimousRoles(
    String? diverId,
    DiveFilterState filter,
    Iterable<String> buddyIds,
  ) async {
    final q = buildBuddyRoleSql(
      diverId: diverId,
      filter: filter,
      buddyIds: buddyIds,
    );
    final rows = await _db
        .customSelect(q.sql, variables: q.params.map(Variable.new).toList())
        .get();
    return {for (final r in rows) r.read<String>('id'): r.read<String>('role')};
  }

  NodeSubtitle? _subtitle(ConnectionKind kind, QueryRow r) {
    String? text(String column) {
      final v = r.readNullable<String>(column);
      return (v == null || v.trim().isEmpty) ? null : v.trim();
    }
    switch (kind) {
      case ConnectionKind.site:
        final parts = [text('region'), text('country')].nonNulls.toList();
        return parts.isEmpty ? null : TextSubtitle(parts.join(', '));
      case ConnectionKind.trip:
        return DateRangeSubtitle(
          _ms(r.read<int>('start_date')),
          _ms(r.read<int>('end_date')),
        );
      case ConnectionKind.diveCenter:
        final c = text('country');
        return c == null ? null : TextSubtitle(c);
      case ConnectionKind.equipment:
        final t = text('type');
        return t == null ? null : TextSubtitle(t);
      case ConnectionKind.species:
        final s = text('scientific_name');
        return s == null ? null : TextSubtitle(s);
      case ConnectionKind.diveComputer:
        final parts = [text('manufacturer'), text('model')].nonNulls.toList();
        return parts.isEmpty ? null : TextSubtitle(parts.join(' '));
      case ConnectionKind.buddy:
      case ConnectionKind.tag:
      case ConnectionKind.diveType:
      case ConnectionKind.course:
        return null;
    }
  }

  /// The focus node when it has no dive in scope: label only, zero dives.
  Future<ConnectionNode> _labelOnly(NodeRef ref) async {
    final t = kindTable(ref.kind);
    final rows = await _db
        .customSelect(
          'SELECT ${t.labelColumn} AS label FROM ${t.table} WHERE id = ?',
          variables: [Variable(ref.id)],
        )
        .get();
    if (rows.isEmpty) throw FocusNotFoundException(ref);
    return ConnectionNode(
      ref: ref,
      label: rows.single.read<String>('label'),
      diveCount: 0,
    );
  }

  /// First and last calendar year of the dives in scope, or null when there
  /// are none. Drives the year slider.
  Future<({int first, int last})?> diveYearSpan({
    required String? diverId,
  }) async {
    final scope = diveScopeSql(
      diverId: diverId,
      filter: const DiveFilterState(),
    );
    final rows = await _db
        .customSelect(
          'SELECT MIN(d.dive_date_time) AS first_ms, '
          'MAX(d.dive_date_time) AS last_ms FROM dives d '
          'WHERE ${scope.clauses.join(' AND ')}',
          variables: scope.params.map(Variable.new).toList(),
        )
        .get();
    final first = rows.single.readNullable<int>('first_ms');
    final last = rows.single.readNullable<int>('last_ms');
    if (first == null || last == null) return null;
    return (first: _ms(first).year, last: _ms(last).year);
  }

  /// The dive ids behind a selected node or edge, newest first, under the
  /// same scope and filter as the graph.
  Future<List<String>> diveIdsFor(
    GraphSelection selection, {
    required String? diverId,
    required DiveFilterState filter,
  }) async {
    final scope = diveScopeSql(diverId: diverId, filter: filter);
    final String sql;
    final List<Object?> params;
    switch (selection) {
      case NodeSelection(:final ref):
        sql =
            'SELECT DISTINCT d.id AS id FROM dives d '
            'JOIN (${membershipSql(ref.kind)}) m ON m.dive_id = d.id '
            'WHERE ${[...scope.clauses, 'm.entity_id = ?'].join(' AND ')} '
            'ORDER BY d.dive_date_time DESC';
        params = [...scope.params, ref.id];
      case EdgeSelection(:final a, :final b):
        sql =
            'SELECT DISTINCT d.id AS id FROM dives d '
            'JOIN (${membershipSql(a.kind)}) ma ON ma.dive_id = d.id '
            'JOIN (${membershipSql(b.kind)}) mb ON mb.dive_id = d.id '
            'WHERE ${[...scope.clauses, 'ma.entity_id = ?', 'mb.entity_id = ?'].join(' AND ')} '
            'ORDER BY d.dive_date_time DESC';
        params = [...scope.params, a.id, b.id];
    }
    final rows = await _db
        .customSelect(sql, variables: params.map(Variable.new).toList())
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// Debounced tick over every table a graph reads: dives, each junction
  /// table, and each label table.
  Stream<void> watchConnectionsChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveBuddies),
          TableUpdateQuery.onTable(_db.buddies),
          TableUpdateQuery.onTable(_db.diveEquipment),
          TableUpdateQuery.onTable(_db.equipment),
          TableUpdateQuery.onTable(_db.sightings),
          TableUpdateQuery.onTable(_db.species),
          TableUpdateQuery.onTable(_db.diveTags),
          TableUpdateQuery.onTable(_db.tags),
          TableUpdateQuery.onTable(_db.diveDiveTypes),
          TableUpdateQuery.onTable(_db.diveTypes),
          TableUpdateQuery.onTable(_db.diveDataSources),
          TableUpdateQuery.onTable(_db.diveComputers),
          TableUpdateQuery.onTable(_db.diveSites),
          TableUpdateQuery.onTable(_db.trips),
          TableUpdateQuery.onTable(_db.diveCenters),
          TableUpdateQuery.onTable(_db.courses),
        ]),
      )
      .debounce(DiveRepository.changeTickDebounce);

  static DateTime _ms(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
```

`debounce` comes from the same stream-extension import that `statistics_repository.dart` uses for `watchStatisticsChanges`; copy that import line. `DiveRepository.changeTickDebounce` is referenced from `dive_repository_impl.dart` exactly as the statistics repository does. `.nonNulls` needs Dart 3; if the analyzer rejects it, use `.whereType<String>()`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/connections/data/repositories/`
Expected: PASS (17 tests). If `DiveBuddiesCompanion` or `DivesCompanion` rejects a column name, open `lib/core/database/database.dart` at the `Dives` (line 743) or `DiveBuddies` (line 2398) table and use the getter name shown there.

- [ ] **Step 5: Run the census and the tick stream guard**

Run: `flutter test test/core/database/dive_stats_scope_census_test.dart test/architecture/repository_tick_stream_test.dart`
Expected: PASS. If the census flags `_labelOnly` or `diveIdsFor`, they read `dives` with the scope already interpolated; the census works per method chunk, so make sure the `diveScopeSql` call sits inside the same method as the SQL (it does in the code above).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/data test/features/connections/data test/core/database/dive_stats_scope_census_test.dart
git commit -m "feat(connections): repository loading whole-web and ego graphs"
```

---

### Task 5: Providers (filter, lens, focus, selection, graph, year span, dive ids)

**Files:**
- Create: `lib/features/connections/presentation/providers/connections_filter_provider.dart`
- Create: `lib/features/connections/presentation/providers/connections_lens_provider.dart`
- Create: `lib/features/connections/presentation/providers/connections_selection_provider.dart`
- Create: `lib/features/connections/presentation/providers/connections_providers.dart`
- Modify: `test/architecture/provider_tick_build_smoke_test.dart` (add three cases)
- Test: `test/features/connections/presentation/providers/connections_lens_provider_test.dart`
- Test: `test/features/connections/presentation/providers/connections_providers_test.dart`

**Interfaces:**
- Consumes: `ConnectionsRepository` (Task 4), `LensSelection` (Task 2), `currentDiverIdProvider` from `lib/features/divers/presentation/providers/diver_providers.dart`, `sharedPreferencesProvider` from `lib/features/settings/presentation/providers/settings_providers.dart`.
- Produces:
  - `connectionsFilterProvider`: `StateProvider<DiveFilterState>`
  - `connectionsLensProvider`: `StateNotifierProvider<ConnectionsLensNotifier, LensSelection>` with `select(LensSelection)`; key `connections_last_lens`
  - `connectionsFocusProvider`: `StateProvider<NodeRef?>`
  - `connectionsSelectionProvider`: `StateProvider<GraphSelection?>`
  - `connectionsRepositoryProvider`: `Provider<ConnectionsRepository>`
  - `connectionGraphProvider`: `FutureProvider.autoDispose.family<ConnectionGraph, int>` (family key is the node budget)
  - `connectionsYearSpanProvider`: `FutureProvider.autoDispose<({int first, int last})?>`
  - `connectionsSelectionDiveIdsProvider`: `FutureProvider.autoDispose.family<List<String>, GraphSelection>`

- [ ] **Step 1: Write the failing tests**

`connections_lens_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('defaults to Dive circle when nothing is stored', () async {
    final c = await containerWith({});
    expect(c.read(connectionsLensProvider), LensSelection.fallback);
  });

  test('restores a stored lens id and a stored custom pair', () async {
    final c1 = await containerWith({'connections_last_lens': 'where'});
    expect(c1.read(connectionsLensProvider).lensId, 'where');
    final c2 = await containerWith({
      'connections_last_lens': 'custom:equipment:trip',
    });
    expect(c2.read(connectionsLensProvider).kindA, ConnectionKind.equipment);
    expect(c2.read(connectionsLensProvider).kindB, ConnectionKind.trip);
  });

  test('garbage in storage falls back', () async {
    final c = await containerWith({'connections_last_lens': 'custom:x'});
    expect(c.read(connectionsLensProvider), LensSelection.fallback);
  });

  test('select persists and notifies', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
    );
    addTearDown(c.dispose);
    c.read(connectionsLensProvider.notifier).select(
      const LensSelection.lens(ConnectionLens.where),
    );
    expect(c.read(connectionsLensProvider).lensId, 'where');
    expect(sp.getString('connections_last_lens'), 'where');
  });
}
```

`connections_providers_test.dart` (real in-memory database, following the repository test's seed helpers; copy `_diver`, `_buddy`, `_dive`, `_link` from Task 4's test verbatim):

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

// _diver, _buddy, _dive, _link: copy from connections_repository_test.dart.

void main() {
  late db.AppDatabase d;
  late ProviderContainer c;

  setUp(() async {
    await setUpTestDatabase();
    d = DatabaseService.instance.database;
    await _diver(d, 'me');
    await _buddy(d, 'jane');
    await _buddy(d, 'ken');
    await _dive(d, id: 'd1', at: DateTime.utc(2024, 1, 10));
    await _link(d, 'd1', 'jane');
    await _link(d, 'd1', 'ken');
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(initialId: 'me'),
        ),
      ],
    );
    addTearDown(c.dispose);
  });

  tearDown(() async => tearDownTestDatabase());

  test('the graph provider loads the active lens for the current diver', () async {
    final sub = c.listen(connectionGraphProvider(80), (_, _) {});
    addTearDown(sub.close);
    final g = await c.read(connectionGraphProvider(80).future);
    expect(g.nodes.length, 2);
    expect(g.edges.single.weight, 1);
  });

  test('changing the filter or lens reloads', () async {
    final sub = c.listen(connectionGraphProvider(80), (_, _) {});
    addTearDown(sub.close);
    await c.read(connectionGraphProvider(80).future);
    c.read(connectionsFilterProvider.notifier).state =
        const DiveFilterState(siteId: 'nowhere');
    final filtered = await c.read(connectionGraphProvider(80).future);
    expect(filtered.isEmpty, isTrue);
    c.read(connectionsFilterProvider.notifier).state = const DiveFilterState();
    c.read(connectionsLensProvider.notifier).select(
      const LensSelection.lens(ConnectionLens.where),
    );
    final where = await c.read(connectionGraphProvider(80).future);
    expect(where.nodes.every((n) => n.ref.kind == ConnectionKind.buddy), isTrue);
    expect(where.edges, isEmpty, reason: 'no dive has a site');
  });

  test('a focus switches to the ego graph', () async {
    c.read(connectionsFocusProvider.notifier).state =
        const NodeRef(ConnectionKind.buddy, 'jane');
    final sub = c.listen(connectionGraphProvider(80), (_, _) {});
    addTearDown(sub.close);
    final g = await c.read(connectionGraphProvider(80).future);
    expect(g.edges.single.source.id, 'jane');
  });

  test('the graph reloads after a junction write', () async {
    final sub = c.listen(connectionGraphProvider(80), (_, _) {});
    addTearDown(sub.close);
    final before = await c.read(connectionGraphProvider(80).future);
    expect(before.edges.single.weight, 1);
    await _dive(d, id: 'd2', at: DateTime.utc(2024, 2, 1));
    await _link(d, 'd2', 'jane');
    await _link(d, 'd2', 'ken');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final after = await c.read(connectionGraphProvider(80).future);
    expect(after.edges.single.weight, 2);
  });

  test('year span and selection dive ids', () async {
    final sub1 = c.listen(connectionsYearSpanProvider, (_, _) {});
    addTearDown(sub1.close);
    expect(await c.read(connectionsYearSpanProvider.future), (first: 2024, last: 2024));
    const sel = NodeSelection(NodeRef(ConnectionKind.buddy, 'jane'));
    final sub2 = c.listen(connectionsSelectionDiveIdsProvider(sel), (_, _) {});
    addTearDown(sub2.close);
    expect(await c.read(connectionsSelectionDiveIdsProvider(sel).future), ['d1']);
    expect(c.read(connectionsSelectionProvider), isNull);
  });
}
```

`MockCurrentDiverIdNotifier` lives in `test/helpers/mock_providers.dart`; read its constructor there and pass the id the way it expects (if it takes no arguments and defaults to a fixed id, insert that diver id in `setUp` instead of `'me'`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/presentation/providers/`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the providers**

`connections_filter_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// The Connections page's own view filter.
///
/// Deliberately separate from `diveFilterProvider` (the dive list) and
/// `statisticsFilterProvider`: scoping the graph must never scope the list
/// or the charts, and vice versa.
final connectionsFilterProvider = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);
```

`connections_lens_provider.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const kConnectionsLastLensKey = 'connections_last_lens';

/// The active lens or custom pair, remembered on this device only.
class ConnectionsLensNotifier extends StateNotifier<LensSelection> {
  ConnectionsLensNotifier(this._prefs)
    : super(
        LensSelection.parse(_prefs.getString(kConnectionsLastLensKey)) ??
            LensSelection.fallback,
      );

  final SharedPreferences _prefs;

  void select(LensSelection selection) {
    if (selection == state) return;
    state = selection;
    _prefs.setString(kConnectionsLastLensKey, selection.persisted);
  }
}

final connectionsLensProvider =
    StateNotifierProvider<ConnectionsLensNotifier, LensSelection>(
      (ref) => ConnectionsLensNotifier(ref.watch(sharedPreferencesProvider)),
    );
```

`connections_selection_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// The node the graph is centred on (ego mode), or null for the whole web.
final connectionsFocusProvider = StateProvider<NodeRef?>((ref) => null);

/// The tapped node or edge, or null.
final connectionsSelectionProvider = StateProvider<GraphSelection?>(
  (ref) => null,
);
```

`connections_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_query.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import 'connections_filter_provider.dart';
import 'connections_lens_provider.dart';
import 'connections_selection_provider.dart';

final connectionsRepositoryProvider = Provider<ConnectionsRepository>(
  (ref) => ConnectionsRepository(),
);

/// The graph for the active lens, filter and focus, trimmed to the node
/// budget given as the family key (the page picks 80 or 160 by width).
///
/// Not keyed by [ConnectionQuery]: `DiveFilterState` has no value equality,
/// so the query is rebuilt here from the individual providers instead.
final connectionGraphProvider = FutureProvider.autoDispose
    .family<ConnectionGraph, int>((ref, nodeBudget) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final lens = ref.watch(connectionsLensProvider);
      final filter = ref.watch(connectionsFilterProvider);
      final focus = ref.watch(connectionsFocusProvider);
      final query = ConnectionQuery(
        kindA: lens.kindA,
        kindB: lens.kindB,
        filter: filter,
        focus: focus,
        nodeBudget: nodeBudget,
      );
      return repository.loadGraph(query, diverId: diverId);
    });

/// First and last dive year for the current diver, for the year slider.
final connectionsYearSpanProvider =
    FutureProvider.autoDispose<({int first, int last})?>((ref) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      return repository.diveYearSpan(diverId: diverId);
    });

/// The dive ids behind the selection, under the page's filter.
final connectionsSelectionDiveIdsProvider = FutureProvider.autoDispose
    .family<List<String>, GraphSelection>((ref, selection) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(connectionsFilterProvider);
      return repository.diveIdsFor(
        selection,
        diverId: diverId,
        filter: filter,
      );
    });
```

- [ ] **Step 4: Add the smoke-test cases**

In `test/architecture/provider_tick_build_smoke_test.dart`, next to the buddy cases (around line 186), add, with the matching imports at the top of the file:

```dart
    (
      name: 'connectionGraphProvider',
      read: (c) => c.read(connectionGraphProvider(80).future),
    ),
    (
      name: 'connectionsYearSpanProvider',
      read: (c) => c.read(connectionsYearSpanProvider.future),
    ),
    (
      name: 'connectionsSelectionDiveIdsProvider',
      read: (c) => c.read(
        connectionsSelectionDiveIdsProvider(
          const NodeSelection(NodeRef(ConnectionKind.buddy, _id)),
        ).future,
      ),
    ),
```

The smoke test's container already overrides `sharedPreferencesProvider` (it imports `shared_preferences`); confirm by reading how the container is built near line 150, and add the override there if it is missing.

- [ ] **Step 5: Run the tests and the two guards**

Run:
```bash
flutter test test/features/connections/presentation/providers/ test/architecture/provider_change_tick_test.dart test/architecture/provider_tick_build_smoke_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/connections test/features/connections test/architecture
git add lib/features/connections/presentation/providers test/features/connections/presentation/providers test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(connections): lens, filter, focus, selection and graph providers"
```

---

### Task 6: Layout primitives and deterministic seeding

**Files:**
- Create: `lib/features/connections/domain/layout/graph_point.dart`
- Create: `lib/features/connections/domain/layout/layout_frame.dart`
- Create: `lib/features/connections/domain/layout/layout_seed.dart`
- Test: `test/features/connections/domain/layout/graph_point_test.dart`
- Test: `test/features/connections/domain/layout/layout_seed_test.dart`

**Interfaces:**
- Produces: `GraphPoint(x, y)` with `+`, `-`, `scaled(f)`, `length`, `distanceTo`, `isFinite`, `GraphPoint.zero`; `GraphBounds(left, top, right, bottom)` with `width`, `height`, `center`, `isEmpty`, `GraphBounds.of(points)`, `inflate(pad)`, `translate(dx, dy)`, `GraphBounds.zero`; `LayoutFrame(positions, bounds, settled)` with `LayoutFrame.empty`, `LayoutFrame.fromPositions(positions, {settled})`; `LayoutSeed.seedFor(refs)`, `LayoutSeed.circle(refs, {radius})`.

- [ ] **Step 1: Write the failing tests**

`graph_point_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

void main() {
  test('arithmetic and distance', () {
    const a = GraphPoint(1, 2);
    const b = GraphPoint(4, 6);
    expect(a + b, const GraphPoint(5, 8));
    expect(b - a, const GraphPoint(3, 4));
    expect(a.distanceTo(b), 5);
    expect(a.scaled(2), const GraphPoint(2, 4));
    expect(const GraphPoint(double.nan, 0).isFinite, isFalse);
  });

  test('bounds of points, inflate and translate', () {
    final b = GraphBounds.of(const [GraphPoint(-1, 2), GraphPoint(3, -4)]);
    expect(b.left, -1);
    expect(b.top, -4);
    expect(b.right, 3);
    expect(b.bottom, 2);
    expect(b.width, 4);
    expect(b.height, 6);
    expect(b.center, const GraphPoint(1, -1));
    expect(b.inflate(1).width, 6);
    expect(b.translate(10, 0).left, 9);
    expect(GraphBounds.of(const []), GraphBounds.zero);
    expect(GraphBounds.zero.isEmpty, isTrue);
  });
}
```

`layout_seed_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/layout_seed.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  test('the seed ignores input order', () {
    expect(
      LayoutSeed.seedFor([_b('a'), _b('b'), _b('c')]),
      LayoutSeed.seedFor([_b('c'), _b('a'), _b('b')]),
    );
    expect(
      LayoutSeed.seedFor([_b('a'), _b('b')]),
      isNot(LayoutSeed.seedFor([_b('a'), _b('x')])),
    );
  });

  test('circle positions are deterministic, finite and distinct', () {
    final refs = [for (var i = 0; i < 12; i++) _b('n$i')];
    final p1 = LayoutSeed.circle(refs);
    final p2 = LayoutSeed.circle(refs.reversed.toList());
    expect(p1, p2);
    expect(p1.length, 12);
    expect(p1.values.every((p) => p.isFinite), isTrue);
    expect(p1.values.toSet().length, 12);
  });

  test('an empty ref list yields no positions', () {
    expect(LayoutSeed.circle(const []), isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/domain/layout/`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the primitives**

`graph_point.dart`:

```dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A position in graph space. Deliberately not `dart:ui` Offset so the layout
/// layer stays free of Flutter.
class GraphPoint extends Equatable {
  const GraphPoint(this.x, this.y);

  static const zero = GraphPoint(0, 0);

  final double x;
  final double y;

  GraphPoint operator +(GraphPoint o) => GraphPoint(x + o.x, y + o.y);
  GraphPoint operator -(GraphPoint o) => GraphPoint(x - o.x, y - o.y);
  GraphPoint scaled(double f) => GraphPoint(x * f, y * f);

  double get length => math.sqrt(x * x + y * y);
  double distanceTo(GraphPoint o) => (this - o).length;
  bool get isFinite => x.isFinite && y.isFinite;

  @override
  List<Object?> get props => [x, y];
}

class GraphBounds extends Equatable {
  const GraphBounds(this.left, this.top, this.right, this.bottom);

  static const zero = GraphBounds(0, 0, 0, 0);

  final double left;
  final double top;
  final double right;
  final double bottom;

  factory GraphBounds.of(Iterable<GraphPoint> points) {
    var first = true;
    var l = 0.0, t = 0.0, r = 0.0, b = 0.0;
    for (final p in points) {
      if (first) {
        l = r = p.x;
        t = b = p.y;
        first = false;
        continue;
      }
      if (p.x < l) l = p.x;
      if (p.x > r) r = p.x;
      if (p.y < t) t = p.y;
      if (p.y > b) b = p.y;
    }
    return first ? zero : GraphBounds(l, t, r, b);
  }

  double get width => right - left;
  double get height => bottom - top;
  bool get isEmpty => width == 0 && height == 0;
  GraphPoint get center => GraphPoint((left + right) / 2, (top + bottom) / 2);

  GraphBounds inflate(double pad) =>
      GraphBounds(left - pad, top - pad, right + pad, bottom + pad);

  GraphBounds translate(double dx, double dy) =>
      GraphBounds(left + dx, top + dy, right + dx, bottom + dy);

  @override
  List<Object?> get props => [left, top, right, bottom];
}
```

`layout_frame.dart`:

```dart
import '../entities/node_ref.dart';
import 'graph_point.dart';

/// One immutable snapshot of a layout. The painter reads frames and never
/// touches layout state.
class LayoutFrame {
  const LayoutFrame({
    required this.positions,
    required this.bounds,
    required this.settled,
  });

  static const empty = LayoutFrame(
    positions: {},
    bounds: GraphBounds.zero,
    settled: true,
  );

  factory LayoutFrame.fromPositions(
    Map<NodeRef, GraphPoint> positions, {
    required bool settled,
  }) {
    return LayoutFrame(
      positions: Map.unmodifiable(positions),
      bounds: GraphBounds.of(positions.values),
      settled: settled,
    );
  }

  final Map<NodeRef, GraphPoint> positions;
  final GraphBounds bounds;
  final bool settled;
}
```

`layout_seed.dart`:

```dart
import 'dart:math' as math;

import '../entities/node_ref.dart';
import 'graph_point.dart';

/// Deterministic starting positions: the same node set lays out the same way
/// on every device and in every test run.
class LayoutSeed {
  const LayoutSeed._();

  /// FNV-1a over the sorted wire names. Not `String.hashCode`, which is not
  /// guaranteed stable across platforms.
  static int seedFor(Iterable<NodeRef> refs) {
    final wires = refs.map((r) => r.wire).toList()..sort();
    var hash = 0x811C9DC5;
    for (final w in wires) {
      for (final unit in w.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0x7FFFFFFF;
      }
      hash ^= 0x2C;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Nodes on a jittered ring, in sorted order.
  static Map<NodeRef, GraphPoint> circle(
    Iterable<NodeRef> refs, {
    double radius = 200,
  }) {
    final sorted = refs.toList()..sort((a, b) => a.wire.compareTo(b.wire));
    if (sorted.isEmpty) return const {};
    final rng = math.Random(seedFor(sorted));
    final n = sorted.length;
    final out = <NodeRef, GraphPoint>{};
    for (var i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n + (rng.nextDouble() - 0.5) * 0.2;
      final r = radius * (0.8 + 0.4 * rng.nextDouble());
      out[sorted[i]] = GraphPoint(r * math.cos(angle), r * math.sin(angle));
    }
    return out;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/connections/domain/layout/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/layout test/features/connections/domain/layout
git commit -m "feat(connections): layout primitives and deterministic seeding"
```

---

### Task 7: ForceLayout

**Files:**
- Create: `lib/features/connections/domain/layout/force_layout.dart`
- Test: `test/features/connections/domain/layout/force_layout_test.dart`

**Interfaces:**
- Consumes: `NodeRef`, `ConnectionEdge`, `GraphPoint`, `GraphBounds`, `LayoutFrame`, `LayoutSeed`.
- Produces: `ForceLayout({nodes, edges, initialPositions, pinned, maxIterations = 300, settleEpsilon = 0.5})` with `frame`, `settled`, `iteration`, `advance(int)`, `pin(ref, at)`, `unpin(ref)`, `clearPins()`, `pinned`, `moveNode(ref, at)` (alias of pin).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/force_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(String a, String b, [int w = 1]) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: w,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  final nodes = [_b('a'), _b('b'), _b('c'), _b('d')];
  final edges = [_e('a', 'b', 4), _e('b', 'c'), _e('a', 'c')];

  ForceLayout build() => ForceLayout(nodes: nodes, edges: edges);

  test('two runs from the same input give identical positions', () {
    final l1 = build()..advance(300);
    final l2 = build()..advance(300);
    expect(l1.frame.positions, l2.frame.positions);
  });

  test('settles within the iteration bound and stays finite', () {
    final l = build();
    expect(l.settled, isFalse);
    l.advance(300);
    expect(l.settled, isTrue);
    expect(l.iteration, lessThanOrEqualTo(300));
    expect(l.frame.positions.values.every((p) => p.isFinite), isTrue);
    expect(l.frame.positions.length, 4);
  });

  test('connected nodes end closer than an unconnected one', () {
    final l = build()..advance(300);
    final p = l.frame.positions;
    final ab = p[_b('a')]!.distanceTo(p[_b('b')]!);
    final ad = p[_b('a')]!.distanceTo(p[_b('d')]!);
    final bd = p[_b('b')]!.distanceTo(p[_b('d')]!);
    expect(ab, lessThan(ad));
    expect(ab, lessThan(bd));
  });

  test('a heavier edge is shorter than a lighter one', () {
    final l = build()..advance(300);
    final p = l.frame.positions;
    final ab = p[_b('a')]!.distanceTo(p[_b('b')]!);
    final bc = p[_b('b')]!.distanceTo(p[_b('c')]!);
    expect(ab, lessThan(bc));
  });

  test('pinned nodes do not move and clearPins releases them', () {
    final l = build();
    l.pin(_b('a'), const GraphPoint(500, 500));
    l.advance(50);
    expect(l.frame.positions[_b('a')], const GraphPoint(500, 500));
    expect(l.pinned, {_b('a')});
    l.clearPins();
    l.advance(50);
    expect(l.frame.positions[_b('a')], isNot(const GraphPoint(500, 500)));
  });

  test('coincident seeds never produce a non-finite coordinate', () {
    final l = ForceLayout(
      nodes: nodes,
      edges: edges,
      initialPositions: {for (final n in nodes) n: GraphPoint.zero},
    );
    l.advance(300);
    expect(l.frame.positions.values.every((p) => p.isFinite), isTrue);
    expect(l.frame.positions.values.toSet().length, 4);
  });

  test('a warm start keeps known nodes near their previous positions', () {
    final cold = build()..advance(300);
    final warm = ForceLayout(
      nodes: [...nodes, _b('e')],
      edges: [...edges, _e('c', 'e')],
      initialPositions: cold.frame.positions,
    );
    final before = warm.frame.positions[_b('a')]!;
    warm.advance(30);
    expect(warm.frame.positions[_b('a')]!.distanceTo(before), lessThan(60));
    expect(warm.frame.positions.containsKey(_b('e')), isTrue);
  });

  test('empty and single-node graphs are settled immediately', () {
    final empty = ForceLayout(nodes: const [], edges: const []);
    expect(empty.settled, isTrue);
    expect(empty.frame.positions, isEmpty);
    final one = ForceLayout(nodes: [_b('a')], edges: const []);
    expect(one.settled, isTrue);
    expect(one.frame.positions.length, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/domain/layout/force_layout_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the simulation**

```dart
import 'dart:math' as math;

import '../entities/connection_edge.dart';
import '../entities/node_ref.dart';
import 'graph_point.dart';
import 'layout_frame.dart';
import 'layout_seed.dart';

/// Fruchterman-Reingold style force layout, stepped by the caller.
///
/// Pairwise repulsion, spring attraction along edges (ideal length shrinks
/// with the logarithm of the weight), a weak pull to the origin, and a
/// temperature that cools linearly to zero over [maxIterations]. Deterministic
/// for a given node set and initial positions.
class ForceLayout {
  ForceLayout({
    required List<NodeRef> nodes,
    required List<ConnectionEdge> edges,
    Map<NodeRef, GraphPoint> initialPositions = const {},
    Set<NodeRef> pinned = const {},
    this.maxIterations = 300,
    this.settleEpsilon = 0.5,
  }) : _nodes = List.unmodifiable(nodes),
       _pinned = {...pinned} {
    final nodeSet = _nodes.toSet();
    _edges = edges
        .where((e) => nodeSet.contains(e.source) && nodeSet.contains(e.target))
        .toList();
    _index = {for (var i = 0; i < _nodes.length; i++) _nodes[i]: i};
    _area = math.max(40000.0, 12000.0 * _nodes.length);
    _k = math.sqrt(_area / math.max(1, _nodes.length));
    _temperature = math.sqrt(_area) / 10;
    _positions = _seed(initialPositions);
    _seedPositions = List.of(_positions);
    _frame = _snapshot();
  }

  final int maxIterations;
  final double settleEpsilon;

  final List<NodeRef> _nodes;
  late final List<ConnectionEdge> _edges;
  late final Map<NodeRef, int> _index;
  late final double _area;
  late final double _k;
  late final List<GraphPoint> _seedPositions;
  late List<GraphPoint> _positions;
  final Set<NodeRef> _pinned;
  double _temperature;
  int _iteration = 0;
  double _lastMaxDisplacement = double.infinity;
  late LayoutFrame _frame;

  LayoutFrame get frame => _frame;
  int get iteration => _iteration;
  Set<NodeRef> get pinned => Set.unmodifiable(_pinned);

  bool get settled =>
      _nodes.length <= 1 ||
      _iteration >= maxIterations ||
      (_iteration > 0 && _lastMaxDisplacement < settleEpsilon);

  /// Known positions are kept; new nodes start at the centroid of their
  /// already-placed neighbours, or on the seed ring when they have none.
  List<GraphPoint> _seed(Map<NodeRef, GraphPoint> initial) {
    final missing = _nodes.where((n) => !initial.containsKey(n)).toList();
    final ring = LayoutSeed.circle(missing, radius: _k * 2);
    final out = List<GraphPoint>.filled(_nodes.length, GraphPoint.zero);
    for (var i = 0; i < _nodes.length; i++) {
      final n = _nodes[i];
      final known = initial[n];
      if (known != null && known.isFinite) {
        out[i] = known;
        continue;
      }
      var sum = GraphPoint.zero;
      var count = 0;
      for (final e in _edges) {
        final other = e.otherEnd(n);
        final p = other == null ? null : initial[other];
        if (p != null && p.isFinite) {
          sum = sum + p;
          count++;
        }
      }
      out[i] = count > 0
          ? sum.scaled(1 / count) + (ring[n] ?? GraphPoint.zero).scaled(0.15)
          : ring[n] ?? GraphPoint.zero;
    }
    return out;
  }

  void advance(int iterations) {
    for (var s = 0; s < iterations && !settled; s++) {
      _step();
    }
    _frame = _snapshot();
  }

  void _step() {
    final n = _nodes.length;
    final disp = List<GraphPoint>.filled(n, GraphPoint.zero);
    final k2 = _k * _k;

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var delta = _positions[i] - _positions[j];
        var d = delta.length;
        if (d < 0.01) {
          // Coincident nodes: nudge apart deterministically by index.
          final angle = (i * 7 + j * 13) % 360 * math.pi / 180;
          delta = GraphPoint(math.cos(angle), math.sin(angle));
          d = 1.0;
        }
        final force = k2 / d;
        final push = delta.scaled(force / d);
        disp[i] = disp[i] + push;
        disp[j] = disp[j] - push;
      }
    }

    for (final e in _edges) {
      final i = _index[e.source]!;
      final j = _index[e.target]!;
      final delta = _positions[i] - _positions[j];
      final d = math.max(delta.length, 0.01);
      final ideal = _k / (1 + math.log(e.weight.toDouble()));
      final force = d * d / ideal;
      final pull = delta.scaled(force / d);
      disp[i] = disp[i] - pull;
      disp[j] = disp[j] + pull;
    }

    var maxMove = 0.0;
    for (var i = 0; i < n; i++) {
      if (_pinned.contains(_nodes[i])) continue;
      final gravity = _positions[i].scaled(-0.02);
      final total = disp[i] + gravity;
      final len = total.length;
      if (len == 0) continue;
      final step = math.min(len, _temperature);
      var next = _positions[i] + total.scaled(step / len);
      if (!next.isFinite) next = _seedPositions[i];
      final moved = next.distanceTo(_positions[i]);
      if (moved > maxMove) maxMove = moved;
      _positions[i] = next;
    }

    _iteration++;
    _lastMaxDisplacement = maxMove;
    _temperature = math.sqrt(_area) / 10 * (1 - _iteration / maxIterations);
  }

  void pin(NodeRef ref, GraphPoint at) {
    final i = _index[ref];
    if (i == null) return;
    _positions[i] = at;
    _pinned.add(ref);
    _lastMaxDisplacement = double.infinity;
    _temperature = math.max(_temperature, _k / 4);
    if (_iteration >= maxIterations) _iteration = maxIterations ~/ 2;
    _frame = _snapshot();
  }

  /// Alias for [pin]: a dragged node stays where it was dropped.
  void moveNode(NodeRef ref, GraphPoint at) => pin(ref, at);

  void unpin(NodeRef ref) => _pinned.remove(ref);

  void clearPins() {
    _pinned.clear();
    _lastMaxDisplacement = double.infinity;
    _temperature = math.max(_temperature, _k / 4);
    if (_iteration >= maxIterations) _iteration = maxIterations ~/ 2;
  }

  LayoutFrame _snapshot() => LayoutFrame.fromPositions(
    {for (var i = 0; i < _nodes.length; i++) _nodes[i]: _positions[i]},
    settled: settled,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/connections/domain/layout/force_layout_test.dart`
Expected: PASS. If "a heavier edge is shorter" is marginal, the ideal-length formula is the knob: `_k / (1 + log(weight))` gives weight 4 an ideal 42% of weight 1. Do not weaken the assertion; adjust the constant `1 +` toward `0.5 +` only if the test fails reproducibly.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/layout/force_layout.dart test/features/connections/domain/layout/force_layout_test.dart
git commit -m "feat(connections): deterministic force-directed layout"
```

---

### Task 8: Islands and the whole-web layout

**Files:**
- Create: `lib/features/connections/domain/layout/island_packer.dart`
- Create: `lib/features/connections/domain/layout/whole_web_layout.dart`
- Test: `test/features/connections/domain/layout/island_packer_test.dart`
- Test: `test/features/connections/domain/layout/whole_web_layout_test.dart`

**Interfaces:**
- Consumes: `ForceLayout` (Task 7), primitives (Task 6).
- Produces: `IslandPacker.components(nodes, edges)` returning `List<List<NodeRef>>` (largest first, deterministic); `IslandPacker.pack(List<LayoutFrame> frames, {gap = 60})` returning `List<GraphPoint>` offsets, one per frame; `WholeWebLayout({nodes, edges, initialPositions, maxIterations})` with `frame`, `settled`, `advance(int)`, `moveNode(ref, worldPoint)`, `clearPins()`.

- [ ] **Step 1: Write the failing tests**

`island_packer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/island_packer.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
ConnectionEdge _e(String a, String b) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: 1,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  test('components are found and ordered largest first', () {
    final nodes = [_b('a'), _b('b'), _b('c'), _b('x'), _b('y'), _b('solo')];
    final comps = IslandPacker.components(nodes, [_e('a', 'b'), _e('b', 'c'), _e('x', 'y')]);
    expect(comps.length, 3);
    expect(comps[0].toSet(), {_b('a'), _b('b'), _b('c')});
    expect(comps[1].toSet(), {_b('x'), _b('y')});
    expect(comps[2], [_b('solo')]);
  });

  test('component order is deterministic for equal sizes', () {
    final nodes = [_b('y'), _b('x'), _b('b'), _b('a')];
    final comps = IslandPacker.components(nodes, [_e('x', 'y'), _e('a', 'b')]);
    expect(comps[0].map((r) => r.id).toSet(), {'a', 'b'});
  });

  test('packed frames do not overlap', () {
    LayoutFrame square(double size) => LayoutFrame.fromPositions({
      _b('p$size'): GraphPoint.zero,
      _b('q$size'): GraphPoint(size, size),
    }, settled: true);
    final frames = [square(100), square(300), square(50)];
    final offsets = IslandPacker.pack(frames, gap: 20);
    expect(offsets.length, 3);
    final rects = [
      for (var i = 0; i < 3; i++)
        frames[i].bounds.translate(offsets[i].x, offsets[i].y),
    ];
    for (var i = 0; i < 3; i++) {
      for (var j = i + 1; j < 3; j++) {
        final a = rects[i];
        final b = rects[j];
        final overlap = a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;
        expect(overlap, isFalse, reason: 'islands $i and $j overlap');
      }
    }
  });
}
```

`whole_web_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
ConnectionEdge _e(String a, String b) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: 1,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  final nodes = [_b('a'), _b('b'), _b('c'), _b('x'), _b('y'), _b('solo')];
  final edges = [_e('a', 'b'), _e('b', 'c'), _e('x', 'y')];

  test('every node is placed and islands stay apart', () {
    final l = WholeWebLayout(nodes: nodes, edges: edges)..advance(400);
    expect(l.settled, isTrue);
    final p = l.frame.positions;
    expect(p.length, 6);
    final abc = [p[_b('a')]!, p[_b('b')]!, p[_b('c')]!];
    final xy = [p[_b('x')]!, p[_b('y')]!];
    for (final u in abc) {
      for (final v in xy) {
        expect(u.distanceTo(v), greaterThan(40));
      }
    }
    expect(p[_b('solo')]!.isFinite, isTrue);
  });

  test('deterministic across runs', () {
    final l1 = WholeWebLayout(nodes: nodes, edges: edges)..advance(400);
    final l2 = WholeWebLayout(nodes: nodes, edges: edges)..advance(400);
    expect(l1.frame.positions, l2.frame.positions);
  });

  test('moveNode pins in world space after settling', () {
    final l = WholeWebLayout(nodes: nodes, edges: edges)..advance(400);
    l.moveNode(_b('a'), const GraphPoint(1000, 1000));
    l.advance(20);
    final a = l.frame.positions[_b('a')]!;
    expect(a.distanceTo(const GraphPoint(1000, 1000)), lessThan(0.001));
    l.clearPins();
    l.advance(50);
    expect(l.frame.positions[_b('a')]!.distanceTo(const GraphPoint(1000, 1000)), greaterThan(1));
  });

  test('an empty graph is settled and empty', () {
    final l = WholeWebLayout(nodes: const [], edges: const []);
    expect(l.settled, isTrue);
    expect(l.frame.positions, isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/domain/layout/island_packer_test.dart test/features/connections/domain/layout/whole_web_layout_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the packer**

`island_packer.dart`:

```dart
import 'dart:math' as math;

import '../entities/connection_edge.dart';
import '../entities/node_ref.dart';
import 'graph_point.dart';
import 'layout_frame.dart';

/// Connected components and shelf packing of their bounding boxes.
class IslandPacker {
  const IslandPacker._();

  /// Components ordered by size descending, then by their smallest wire name,
  /// so the order is stable for equal sizes. Members keep [nodes] order.
  static List<List<NodeRef>> components(
    List<NodeRef> nodes,
    List<ConnectionEdge> edges,
  ) {
    final adjacency = <NodeRef, List<NodeRef>>{for (final n in nodes) n: []};
    for (final e in edges) {
      if (!adjacency.containsKey(e.source) || !adjacency.containsKey(e.target)) {
        continue;
      }
      adjacency[e.source]!.add(e.target);
      adjacency[e.target]!.add(e.source);
    }
    final seen = <NodeRef>{};
    final out = <List<NodeRef>>[];
    for (final start in nodes) {
      if (!seen.add(start)) continue;
      final comp = <NodeRef>[start];
      final queue = [start];
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        for (final next in adjacency[cur]!) {
          if (seen.add(next)) {
            comp.add(next);
            queue.add(next);
          }
        }
      }
      final order = {for (var i = 0; i < nodes.length; i++) nodes[i]: i};
      comp.sort((a, b) => order[a]!.compareTo(order[b]!));
      out.add(comp);
    }
    String key(List<NodeRef> c) =>
        c.map((r) => r.wire).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    out.sort((a, b) {
      final bySize = b.length.compareTo(a.length);
      return bySize != 0 ? bySize : key(a).compareTo(key(b));
    });
    return out;
  }

  /// Offsets that place each frame's bounds on shelves without overlap,
  /// largest area first. The row width grows with the total area so the
  /// result is roughly square.
  static List<GraphPoint> pack(List<LayoutFrame> frames, {double gap = 60}) {
    if (frames.isEmpty) return const [];
    final order = List<int>.generate(frames.length, (i) => i)
      ..sort((i, j) {
        final a = frames[i].bounds.inflate(gap / 2);
        final b = frames[j].bounds.inflate(gap / 2);
        final byArea = (b.width * b.height).compareTo(a.width * a.height);
        return byArea != 0 ? byArea : i.compareTo(j);
      });
    var totalArea = 0.0;
    var widest = 0.0;
    for (final f in frames) {
      final b = f.bounds.inflate(gap / 2);
      totalArea += b.width * b.height;
      widest = math.max(widest, b.width);
    }
    final rowLimit = math.max(widest, math.sqrt(totalArea) * 1.4);
    final offsets = List<GraphPoint>.filled(frames.length, GraphPoint.zero);
    var x = 0.0, y = 0.0, rowHeight = 0.0;
    for (final i in order) {
      final b = frames[i].bounds.inflate(gap / 2);
      if (x > 0 && x + b.width > rowLimit) {
        x = 0;
        y += rowHeight;
        rowHeight = 0;
      }
      offsets[i] = GraphPoint(x - b.left, y - b.top);
      x += b.width;
      rowHeight = math.max(rowHeight, b.height);
    }
    return offsets;
  }
}
```

`whole_web_layout.dart`:

```dart
import '../entities/connection_edge.dart';
import '../entities/node_ref.dart';
import 'force_layout.dart';
import 'graph_point.dart';
import 'island_packer.dart';
import 'layout_frame.dart';

/// One [ForceLayout] per connected component, packed side by side.
///
/// Packing offsets are recomputed on every frame until every island has
/// settled, then frozen, so a node the user drags afterwards stays where it
/// was dropped instead of being re-shelved.
class WholeWebLayout {
  WholeWebLayout({
    required List<NodeRef> nodes,
    required List<ConnectionEdge> edges,
    Map<NodeRef, GraphPoint> initialPositions = const {},
    int maxIterations = 300,
  }) {
    final comps = IslandPacker.components(nodes, edges);
    for (final comp in comps) {
      final members = comp.toSet();
      _layouts.add(
        ForceLayout(
          nodes: comp,
          edges: edges
              .where((e) => members.contains(e.source) && members.contains(e.target))
              .toList(),
          initialPositions: {
            for (final n in comp)
              if (initialPositions[n] != null) n: initialPositions[n]!,
          },
          maxIterations: maxIterations,
        ),
      );
    }
    _offsets = List.filled(_layouts.length, GraphPoint.zero);
    _recompose();
  }

  final List<ForceLayout> _layouts = [];
  late List<GraphPoint> _offsets;
  bool _frozen = false;
  LayoutFrame _frame = LayoutFrame.empty;

  LayoutFrame get frame => _frame;
  bool get settled => _layouts.every((l) => l.settled);

  void advance(int iterations) {
    for (final l in _layouts) {
      l.advance(iterations);
    }
    _recompose();
  }

  /// Pins [ref] at a world-space point.
  void moveNode(NodeRef ref, GraphPoint world) {
    for (var i = 0; i < _layouts.length; i++) {
      if (_layouts[i].frame.positions.containsKey(ref)) {
        _layouts[i].moveNode(ref, world - _offsets[i]);
        _recompose();
        return;
      }
    }
  }

  void clearPins() {
    for (final l in _layouts) {
      l.clearPins();
    }
    _frozen = false;
    _recompose();
  }

  void _recompose() {
    if (!_frozen) {
      _offsets = IslandPacker.pack(_layouts.map((l) => l.frame).toList());
      if (settled) _frozen = true;
    }
    final positions = <NodeRef, GraphPoint>{};
    for (var i = 0; i < _layouts.length; i++) {
      for (final entry in _layouts[i].frame.positions.entries) {
        positions[entry.key] = entry.value + _offsets[i];
      }
    }
    _frame = LayoutFrame.fromPositions(positions, settled: settled);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/connections/domain/layout/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/layout test/features/connections/domain/layout
git commit -m "feat(connections): island packing and whole-web layout"
```

---

### Task 9: RadialLayout for ego mode

**Files:**
- Create: `lib/features/connections/domain/layout/radial_layout.dart`
- Test: `test/features/connections/domain/layout/radial_layout_test.dart`

**Interfaces:**
- Consumes: `ConnectionNode`, `ConnectionEdge`, `NodeRef`, primitives.
- Produces: `RadialLayout.compute({focus, nodes, edges, firstRing = 170, ringGap = 120, minArcSpacing = 36})` returning a settled `LayoutFrame` with the focus at the origin.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';

const _focus = NodeRef(ConnectionKind.buddy, 'me');

ConnectionNode _n(ConnectionKind k, String id) =>
    ConnectionNode(ref: NodeRef(k, id), label: id, diveCount: 1);

ConnectionEdge _spoke(NodeRef to, int w) => ConnectionEdge(
  source: _focus,
  target: to,
  weight: w,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

double _angle(GraphPoint p) => math.atan2(p.y, p.x);

void main() {
  test('focus at origin, neighbours on the first ring', () {
    final b1 = _n(ConnectionKind.buddy, 'b1');
    final b2 = _n(ConnectionKind.buddy, 'b2');
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me'), b1, b2],
      edges: [_spoke(b1.ref, 3), _spoke(b2.ref, 1)],
    );
    expect(f.settled, isTrue);
    expect(f.positions[_focus], GraphPoint.zero);
    expect(f.positions[b1.ref]!.length, closeTo(170, 0.01));
    expect(f.positions[b2.ref]!.length, closeTo(170, 0.01));
  });

  test('kinds occupy contiguous arcs and heavier neighbours come first', () {
    final sites = [for (var i = 0; i < 4; i++) _n(ConnectionKind.site, 's$i')];
    final buddies = [for (var i = 0; i < 4; i++) _n(ConnectionKind.buddy, 'b$i')];
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me'), ...sites, ...buddies],
      edges: [
        for (var i = 0; i < 4; i++) _spoke(sites[i].ref, 4 - i),
        for (var i = 0; i < 4; i++) _spoke(buddies[i].ref, i + 1),
      ],
    );
    final siteAngles = sites.map((s) => _angle(f.positions[s.ref]!)).toList();
    final buddyAngles = buddies.map((b) => _angle(f.positions[b.ref]!)).toList();
    // Buddies (kind index 0) start at angle 0 and fill the first half turn.
    expect(buddyAngles.every((a) => a >= -0.01 && a <= math.pi + 0.01), isTrue);
    expect(siteAngles.every((a) => a >= math.pi - 0.01 || a <= 0.01), isTrue);
    // Heavier first within the buddy arc: b3 (weight 4) has the smallest angle.
    final heaviest = buddies.reduce((a, b) =>
        _angle(f.positions[a.ref]!) <= _angle(f.positions[b.ref]!) ? a : b);
    expect(heaviest.ref.id, 'b3');
  });

  test('spills to a second ring when an arc is full', () {
    final many = [for (var i = 0; i < 40; i++) _n(ConnectionKind.buddy, 'b$i')];
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me'), ...many],
      edges: [for (final m in many) _spoke(m.ref, 1)],
    );
    final radii = many.map((m) => f.positions[m.ref]!.length.round()).toSet();
    expect(radii, containsAll([170, 290]));
  });

  test('a lone focus is a single point', () {
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me')],
      edges: const [],
    );
    expect(f.positions, {_focus: GraphPoint.zero});
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/domain/layout/radial_layout_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the radial layout**

```dart
import 'dart:math' as math;

import '../entities/connection_edge.dart';
import '../entities/connection_kind.dart';
import '../entities/connection_node.dart';
import '../entities/node_ref.dart';
import 'graph_point.dart';
import 'layout_frame.dart';

/// Hub-and-spokes placement for ego mode.
///
/// The focus sits at the origin. Neighbours are grouped by kind (in
/// [ConnectionKind] order) into contiguous arcs sized by count, sorted by
/// spoke weight within the arc, and spill to outer rings when an arc cannot
/// hold them at [minArcSpacing]. Neighbours that are not connected to the
/// focus (none in practice) are dropped.
class RadialLayout {
  const RadialLayout._();

  static LayoutFrame compute({
    required NodeRef focus,
    required List<ConnectionNode> nodes,
    required List<ConnectionEdge> edges,
    double firstRing = 170,
    double ringGap = 120,
    double minArcSpacing = 36,
  }) {
    final weightTo = <NodeRef, int>{};
    for (final e in edges) {
      final other = e.otherEnd(focus);
      if (other != null) weightTo[other] = (weightTo[other] ?? 0) + e.weight;
    }
    final neighbours = nodes
        .where((n) => n.ref != focus && weightTo.containsKey(n.ref))
        .toList();
    final positions = <NodeRef, GraphPoint>{focus: GraphPoint.zero};
    if (neighbours.isEmpty) {
      return LayoutFrame.fromPositions(positions, settled: true);
    }

    final groups = <ConnectionKind, List<ConnectionNode>>{};
    for (final n in neighbours) {
      groups.putIfAbsent(n.ref.kind, () => []).add(n);
    }
    final kinds = groups.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
    for (final k in kinds) {
      groups[k]!.sort((a, b) {
        final byWeight = weightTo[b.ref]!.compareTo(weightTo[a.ref]!);
        return byWeight != 0 ? byWeight : a.label.compareTo(b.label);
      });
    }

    final total = neighbours.length;
    var arcStart = 0.0;
    for (final k in kinds) {
      final members = groups[k]!;
      final arc = 2 * math.pi * members.length / total;
      var placed = 0;
      var ring = 0;
      while (placed < members.length) {
        final radius = firstRing + ring * ringGap;
        final capacity = math.max(1, (arc * radius / minArcSpacing).floor());
        final count = math.min(capacity, members.length - placed);
        for (var i = 0; i < count; i++) {
          final t = count == 1 ? 0.5 : (i + 0.5) / count;
          final angle = arcStart + arc * t;
          positions[members[placed + i].ref] = GraphPoint(
            radius * math.cos(angle),
            radius * math.sin(angle),
          );
        }
        placed += count;
        ring++;
      }
      arcStart += arc;
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/connections/domain/layout/radial_layout_test.dart`
Expected: PASS. Angles are measured from the positive x axis; the buddy group (kind index 0) fills `[0, pi]` because it holds half the neighbours in the second test.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/layout/radial_layout.dart test/features/connections/domain/layout/radial_layout_test.dart
git commit -m "feat(connections): radial ego layout"
```

---

### Task 10: Layout controller (ticker-driven)

**Files:**
- Create: `lib/features/connections/presentation/providers/connections_layout_controller.dart`
- Test: `test/features/connections/presentation/providers/connections_layout_controller_test.dart`

**Interfaces:**
- Consumes: `WholeWebLayout`, `RadialLayout`, `ConnectionGraph`, `LayoutFrame`, `GraphPoint`.
- Produces: `enum GraphLayoutMode { web, ego }`; `ConnectionsLayoutController extends ChangeNotifier` with `ConnectionsLayoutController({required TickerProvider vsync, iterationsPerTick = 12})`, `frame`, `settled`, `mode`, `setGraph(graph, {required mode, focus, warmStart = true})`, `moveNode(ref, GraphPoint)`, `relayout()`, `stepForTest([iterations])`, `dispose()`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
ConnectionNode _n(String id) => ConnectionNode(ref: _b(id), label: id, diveCount: 1);
ConnectionEdge _e(String a, String b) => ConnectionEdge(
  source: _b(a),
  target: _b(b),
  weight: 1,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

final _graph = ConnectionGraph(
  nodes: [_n('a'), _n('b'), _n('c')],
  edges: [_e('a', 'b'), _e('b', 'c')],
);

void main() {
  test('web mode steps toward a settled frame and notifies', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    var notified = 0;
    c.addListener(() => notified++);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    expect(c.frame.positions.length, 3);
    expect(c.settled, isFalse);
    while (!c.settled) {
      c.stepForTest();
    }
    expect(notified, greaterThan(1));
  });

  test('ego mode is settled immediately with the focus at the origin', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('b'));
    expect(c.settled, isTrue);
    expect(c.frame.positions[_b('b')], GraphPoint.zero);
    expect(c.mode, GraphLayoutMode.ego);
  });

  test('moveNode pins and relayout releases', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    while (!c.settled) {
      c.stepForTest();
    }
    c.moveNode(_b('a'), const GraphPoint(900, 900));
    c.stepForTest(5);
    expect(c.frame.positions[_b('a')]!.distanceTo(const GraphPoint(900, 900)), lessThan(0.001));
    c.relayout();
    while (!c.settled) {
      c.stepForTest();
    }
    expect(c.frame.positions[_b('a')]!.distanceTo(const GraphPoint(900, 900)), greaterThan(1));
  });

  test('a warm start keeps a node near its previous place', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    while (!c.settled) {
      c.stepForTest();
    }
    final before = c.frame.positions[_b('a')]!;
    c.setGraph(
      _graph.copyWith(nodes: [..._graph.nodes, _n('d')], edges: [..._graph.edges, _e('c', 'd')]),
      mode: GraphLayoutMode.web,
    );
    c.stepForTest(3);
    expect(c.frame.positions[_b('a')]!.distanceTo(before), lessThan(80));
  });

  test('an empty graph yields an empty settled frame', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(ConnectionGraph.empty, mode: GraphLayoutMode.web);
    expect(c.settled, isTrue);
    expect(c.frame.positions, isEmpty);
  });
}
```

`TestVSync` is exported by `package:flutter/scheduler.dart` (it lives in `scheduler/ticker.dart`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/providers/connections_layout_controller_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the controller**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

enum GraphLayoutMode { web, ego }

/// Owns the live layout and advances it a bounded number of iterations per
/// frame until it settles. Listeners repaint on every notification.
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
  GraphLayoutMode _mode = GraphLayoutMode.web;
  WholeWebLayout? _web;
  LayoutFrame _frame = LayoutFrame.empty;

  LayoutFrame get frame => _frame;
  GraphLayoutMode get mode => _mode;
  bool get settled => _web?.settled ?? true;

  /// Replaces the graph. In web mode the previous frame seeds the new layout
  /// when [warmStart] is true, so existing nodes barely move.
  void setGraph(
    ConnectionGraph graph, {
    required GraphLayoutMode mode,
    NodeRef? focus,
    bool warmStart = true,
  }) {
    final previous = _frame.positions;
    _graph = graph;
    _mode = mode;
    if (mode == GraphLayoutMode.ego && focus != null) {
      _web = null;
      _frame = RadialLayout.compute(
        focus: focus,
        nodes: graph.nodes,
        edges: graph.edges,
      );
      _stopTicker();
      notifyListeners();
      return;
    }
    _web = WholeWebLayout(
      nodes: graph.nodes.map((n) => n.ref).toList(),
      edges: graph.edges,
      initialPositions: warmStart ? previous : const {},
    );
    _frame = _web!.frame;
    _syncTicker();
    notifyListeners();
  }

  void moveNode(NodeRef ref, GraphPoint to) {
    final web = _web;
    if (web == null) return;
    web.moveNode(ref, to);
    _frame = web.frame;
    _syncTicker();
    notifyListeners();
  }

  /// Clears pins and lays the current graph out again from its seed.
  void relayout() {
    if (_mode == GraphLayoutMode.ego) return;
    _web = WholeWebLayout(
      nodes: _graph.nodes.map((n) => n.ref).toList(),
      edges: _graph.edges,
    );
    _frame = _web!.frame;
    _syncTicker();
    notifyListeners();
  }

  /// One tick's worth of work without a ticker, for tests.
  void stepForTest([int? iterations]) =>
      _advance(iterations ?? iterationsPerTick);

  void _onTick(Duration _) => _advance(iterationsPerTick);

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
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/connections/presentation/providers/connections_layout_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/providers/connections_layout_controller.dart test/features/connections/presentation/providers/connections_layout_controller_test.dart
git commit -m "feat(connections): ticker-driven layout controller"
```

---

### Task 11: Viewport transform and hit testing

**Files:**
- Create: `lib/features/connections/presentation/canvas/graph_viewport.dart`
- Create: `lib/features/connections/presentation/canvas/connections_hit_tester.dart`
- Test: `test/features/connections/presentation/canvas/graph_viewport_test.dart`
- Test: `test/features/connections/presentation/canvas/connections_hit_tester_test.dart`

**Interfaces:**
- Produces: `GraphViewport({scale = 1, offset = Offset.zero})` immutable with `minScale = 0.15`, `maxScale = 6`, `toScreen(GraphPoint)`, `toGraph(Offset)`, `fitted(GraphBounds, Size, {padding = 48})`, `zoomedAt(factor, focal)`, `panned(delta)`, `clampedTo(GraphBounds, Size, {minVisible = 48})`; `ConnectionsHitTester.hitNode(point, {frame, viewport, radiusOf, slop = 12, minRadius = 18})`, `ConnectionsHitTester.hitEdge(point, {frame, viewport, edges, tolerance = 10})`, `ConnectionsHitTester.distanceToSegment(p, a, b)`.

- [ ] **Step 1: Write the failing tests**

`graph_viewport_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

void main() {
  test('toScreen and toGraph invert each other', () {
    final v = GraphViewport(scale: 2, offset: const Offset(10, 20));
    expect(v.toScreen(const GraphPoint(5, 5)), const Offset(20, 30));
    final back = v.toGraph(const Offset(20, 30));
    expect(back.x, closeTo(5, 1e-9));
    expect(back.y, closeTo(5, 1e-9));
  });

  test('fitted centres the bounds and clamps the scale', () {
    const bounds = GraphBounds(-100, -50, 100, 50);
    final v = GraphViewport().fitted(bounds, const Size(400, 400), padding: 0);
    expect(v.scale, closeTo(2, 1e-9));
    expect(v.toScreen(bounds.center), const Offset(200, 200));
    final huge = GraphViewport().fitted(const GraphBounds(0, 0, 1, 1), const Size(400, 400));
    expect(huge.scale, GraphViewport.maxScale);
    final empty = GraphViewport().fitted(GraphBounds.zero, const Size(400, 400));
    expect(empty.scale, 1);
    expect(empty.toScreen(GraphPoint.zero), const Offset(200, 200));
  });

  test('zoomedAt keeps the focal point fixed', () {
    final v = GraphViewport(scale: 1, offset: const Offset(50, 50));
    const focal = Offset(120, 80);
    final under = v.toGraph(focal);
    final z = v.zoomedAt(1.5, focal);
    expect(z.scale, closeTo(1.5, 1e-9));
    final after = z.toScreen(under);
    expect(after.dx, closeTo(focal.dx, 1e-6));
    expect(after.dy, closeTo(focal.dy, 1e-6));
  });

  test('clampedTo keeps part of the graph on screen', () {
    const bounds = GraphBounds(0, 0, 100, 100);
    final gone = GraphViewport(scale: 1, offset: const Offset(-5000, -5000));
    final v = gone.clampedTo(bounds, const Size(400, 400));
    final right = v.toScreen(const GraphPoint(100, 100));
    expect(right.dx, greaterThanOrEqualTo(48));
    expect(right.dy, greaterThanOrEqualTo(48));
  });
}
```

`connections_hit_tester_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_hit_tester.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  final frame = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(0, 0),
    _b('b'): const GraphPoint(200, 0),
  }, settled: true);
  final viewport = GraphViewport(scale: 1, offset: const Offset(100, 100));
  double radius(NodeRef _) => 10;

  test('picks the nearest node within radius plus slop', () {
    expect(
      ConnectionsHitTester.hitNode(const Offset(105, 104), frame: frame, viewport: viewport, radiusOf: radius),
      _b('a'),
    );
    expect(
      ConnectionsHitTester.hitNode(const Offset(295, 100), frame: frame, viewport: viewport, radiusOf: radius),
      _b('b'),
    );
    expect(
      ConnectionsHitTester.hitNode(const Offset(200, 100), frame: frame, viewport: viewport, radiusOf: radius),
      isNull,
    );
  });

  test('a tiny node is still hittable within the minimum touch radius', () {
    double tiny(NodeRef _) => 2;
    expect(
      ConnectionsHitTester.hitNode(const Offset(120, 100), frame: frame, viewport: viewport, radiusOf: tiny),
      _b('a'),
      reason: '20 px away, inside minRadius 18 + slop 12',
    );
  });

  test('hits an edge near its midpoint and nothing far away', () {
    final edge = ConnectionEdge(
      source: _b('a'),
      target: _b('b'),
      weight: 1,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    );
    expect(
      ConnectionsHitTester.hitEdge(const Offset(200, 106), frame: frame, viewport: viewport, edges: [edge]),
      edge,
    );
    expect(
      ConnectionsHitTester.hitEdge(const Offset(200, 140), frame: frame, viewport: viewport, edges: [edge]),
      isNull,
    );
  });

  test('distanceToSegment handles the ends', () {
    const a = Offset(0, 0);
    const b = Offset(10, 0);
    expect(ConnectionsHitTester.distanceToSegment(const Offset(5, 3), a, b), 3);
    expect(ConnectionsHitTester.distanceToSegment(const Offset(-4, 0), a, b), 4);
    expect(ConnectionsHitTester.distanceToSegment(const Offset(13, 4), a, b), 5);
    expect(ConnectionsHitTester.distanceToSegment(const Offset(2, 2), a, a), closeTo(2.828, 0.001));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the viewport and hit tester**

`graph_viewport.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/connections/domain/layout/graph_point.dart';

/// Graph-space to screen-space transform: `screen = graph * scale + offset`.
class GraphViewport {
  const GraphViewport({this.scale = 1, this.offset = Offset.zero});

  static const double minScale = 0.15;
  static const double maxScale = 6;

  final double scale;
  final Offset offset;

  Offset toScreen(GraphPoint p) =>
      Offset(p.x * scale + offset.dx, p.y * scale + offset.dy);

  GraphPoint toGraph(Offset s) =>
      GraphPoint((s.dx - offset.dx) / scale, (s.dy - offset.dy) / scale);

  /// Scale so [bounds] fits inside [size] less [padding], centred.
  GraphViewport fitted(GraphBounds bounds, Size size, {double padding = 48}) {
    final w = math.max(1.0, bounds.width);
    final h = math.max(1.0, bounds.height);
    final raw = bounds.isEmpty
        ? 1.0
        : math.min((size.width - 2 * padding) / w, (size.height - 2 * padding) / h);
    final s = raw.clamp(minScale, maxScale);
    final c = bounds.center;
    return GraphViewport(
      scale: s,
      offset: Offset(size.width / 2 - c.x * s, size.height / 2 - c.y * s),
    );
  }

  /// Multiplies the scale by [factor] keeping the graph point under [focal]
  /// fixed on screen.
  GraphViewport zoomedAt(double factor, Offset focal) {
    final next = (scale * factor).clamp(minScale, maxScale);
    final ratio = next / scale;
    return GraphViewport(
      scale: next,
      offset: focal - (focal - offset) * ratio,
    );
  }

  GraphViewport panned(Offset delta) =>
      GraphViewport(scale: scale, offset: offset + delta);

  /// Keeps at least [minVisible] px of the graph inside [size] on each axis.
  GraphViewport clampedTo(GraphBounds bounds, Size size, {double minVisible = 48}) {
    if (bounds.isEmpty) return this;
    final left = bounds.left * scale + offset.dx;
    final right = bounds.right * scale + offset.dx;
    final top = bounds.top * scale + offset.dy;
    final bottom = bounds.bottom * scale + offset.dy;
    var dx = 0.0;
    var dy = 0.0;
    if (right < minVisible) dx = minVisible - right;
    if (left > size.width - minVisible) dx = size.width - minVisible - left;
    if (bottom < minVisible) dy = minVisible - bottom;
    if (top > size.height - minVisible) dy = size.height - minVisible - top;
    if (dx == 0 && dy == 0) return this;
    return GraphViewport(scale: scale, offset: offset + Offset(dx, dy));
  }
}
```

`connections_hit_tester.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

import 'graph_viewport.dart';

class ConnectionsHitTester {
  const ConnectionsHitTester._();

  /// The nearest node whose drawn radius (never below [minRadius]) plus
  /// [slop] contains [point], in screen space.
  static NodeRef? hitNode(
    Offset point, {
    required LayoutFrame frame,
    required GraphViewport viewport,
    required double Function(NodeRef ref) radiusOf,
    double slop = 12,
    double minRadius = 18,
  }) {
    NodeRef? best;
    var bestDistance = double.infinity;
    for (final entry in frame.positions.entries) {
      final d = (viewport.toScreen(entry.value) - point).distance;
      final reach = math.max(radiusOf(entry.key), minRadius) + slop;
      if (d <= reach && d < bestDistance) {
        best = entry.key;
        bestDistance = d;
      }
    }
    return best;
  }

  /// The nearest edge whose segment passes within [tolerance] of [point].
  static ConnectionEdge? hitEdge(
    Offset point, {
    required LayoutFrame frame,
    required GraphViewport viewport,
    required List<ConnectionEdge> edges,
    double tolerance = 10,
  }) {
    ConnectionEdge? best;
    var bestDistance = double.infinity;
    for (final e in edges) {
      final a = frame.positions[e.source];
      final b = frame.positions[e.target];
      if (a == null || b == null) continue;
      final d = distanceToSegment(point, viewport.toScreen(a), viewport.toScreen(b));
      if (d <= tolerance && d < bestDistance) {
        best = e;
        bestDistance = d;
      }
    }
    return best;
  }

  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    final proj = a + ab * t;
    return (p - proj).distance;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/canvas test/features/connections/presentation/canvas
git commit -m "feat(connections): viewport transform and hit testing"
```

---

### Task 12: Kind colours, node metrics, label collision and the painter

**Files:**
- Create: `lib/features/connections/presentation/canvas/connection_kind_colors.dart`
- Create: `lib/features/connections/presentation/canvas/node_metrics.dart`
- Create: `lib/features/connections/presentation/canvas/label_collision.dart`
- Create: `lib/features/connections/presentation/canvas/connections_painter.dart`
- Test: `test/features/connections/presentation/canvas/node_metrics_test.dart`
- Test: `test/features/connections/presentation/canvas/label_collision_test.dart`
- Test: `test/features/connections/presentation/canvas/connections_painter_test.dart`

**Interfaces:**
- Consumes: `FeatureAccentColors` from `lib/core/theme/feature_accent_colors.dart` (`Theme.of(context).extension<FeatureAccentColors>()`, falling back to `FeatureAccentColors.light` or `.dark` by brightness); everything from Tasks 1, 6, 11.
- Produces:
  - `ConnectionKindColors.of(BuildContext)` and `ConnectionKindColors(Map<ConnectionKind, Color>, Color fallback)`; `colorFor(kind)`.
  - `NodeMetrics.radiusFor(diveCount, maxDiveCount)`, `edgeWidthFor(weight, maxWeight)`, `edgeOpacityFor(weight, maxWeight)`, `initialsFor(label)`.
  - `LabelCollision.visible(List<({NodeRef ref, Rect rect})> ranked)` returning `Set<NodeRef>`.
  - `ConnectionsPainter({graph, frame, viewport, colors, selection, hovered, labelStyle, photos})` and `ConnectionsPainter.neighboursOf(graph, selection)`.

- [ ] **Step 1: Write the failing tests**

`node_metrics_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/presentation/canvas/node_metrics.dart';

void main() {
  test('radius grows with the square root and is clamped', () {
    expect(NodeMetrics.radiusFor(0, 100), NodeMetrics.minRadius);
    expect(NodeMetrics.radiusFor(100, 100), NodeMetrics.maxRadius);
    final quarter = NodeMetrics.radiusFor(25, 100);
    final half = NodeMetrics.radiusFor(50, 100);
    expect(quarter, lessThan(half));
    expect(quarter - NodeMetrics.minRadius, closeTo((NodeMetrics.maxRadius - NodeMetrics.minRadius) / 2, 1e-9));
    expect(NodeMetrics.radiusFor(3, 0), NodeMetrics.maxRadius, reason: 'a zero max never divides');
  });

  test('edge width and opacity scale with weight', () {
    expect(NodeMetrics.edgeWidthFor(1, 10), lessThan(NodeMetrics.edgeWidthFor(10, 10)));
    expect(NodeMetrics.edgeOpacityFor(10, 10), lessThanOrEqualTo(1));
    expect(NodeMetrics.edgeOpacityFor(1, 10), greaterThan(0));
  });

  test('initials take the first letters of up to two words', () {
    expect(NodeMetrics.initialsFor('Jane Doe'), 'JD');
    expect(NodeMetrics.initialsFor('  cher '), 'C');
    expect(NodeMetrics.initialsFor('Salt Pier North'), 'SP');
    expect(NodeMetrics.initialsFor(''), '');
  });
}
```

`label_collision_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/label_collision.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  test('a lower-ranked overlapping label is hidden, disjoint ones survive', () {
    final visible = LabelCollision.visible([
      (ref: _b('first'), rect: const Rect.fromLTWH(0, 0, 50, 10)),
      (ref: _b('overlaps'), rect: const Rect.fromLTWH(40, 5, 50, 10)),
      (ref: _b('clear'), rect: const Rect.fromLTWH(200, 0, 50, 10)),
    ]);
    expect(visible, {_b('first'), _b('clear')});
  });

  test('touching edges do not count as overlap', () {
    final visible = LabelCollision.visible([
      (ref: _b('a'), rect: const Rect.fromLTWH(0, 0, 50, 10)),
      (ref: _b('b'), rect: const Rect.fromLTWH(50, 0, 50, 10)),
    ]);
    expect(visible.length, 2);
  });
}
```

`connections_painter_test.dart`:

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
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  final graph = ConnectionGraph(
    nodes: [
      ConnectionNode(ref: _b('a'), label: 'Ann', diveCount: 5),
      ConnectionNode(ref: _b('b'), label: 'Bob', diveCount: 2),
      ConnectionNode(ref: _b('c'), label: 'Cy', diveCount: 1),
    ],
    edges: [
      ConnectionEdge(source: _b('a'), target: _b('b'), weight: 3, firstDiveAt: DateTime.utc(2024), lastDiveAt: DateTime.utc(2024)),
    ],
  );
  final frame = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(0, 0),
    _b('b'): const GraphPoint(100, 0),
    _b('c'): const GraphPoint(0, 100),
  }, settled: true);
  const colors = ConnectionKindColors({ConnectionKind.buddy: Colors.pink}, Colors.grey);

  ConnectionsPainter painter({GraphSelection? selection}) => ConnectionsPainter(
    graph: graph,
    frame: frame,
    viewport: const GraphViewport(scale: 1, offset: Offset(50, 50)),
    colors: colors,
    selection: selection,
    labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
  );

  test('paints without throwing, with and without a selection', () {
    for (final sel in [null, NodeSelection(_b('a')), EdgeSelection(_b('a'), _b('b'))]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter(selection: sel).paint(canvas, const Size(300, 300));
      recorder.endRecording().dispose();
    }
  });

  test('neighboursOf lists the far ends of the selected node', () {
    expect(ConnectionsPainter.neighboursOf(graph, NodeSelection(_b('a'))), {_b('b')});
    expect(ConnectionsPainter.neighboursOf(graph, EdgeSelection(_b('a'), _b('b'))), {_b('a'), _b('b')});
    expect(ConnectionsPainter.neighboursOf(graph, null), isEmpty);
  });

  test('shouldRepaint reacts to a different frame or selection', () {
    final p1 = painter();
    expect(p1.shouldRepaint(painter()), isFalse);
    expect(p1.shouldRepaint(painter(selection: NodeSelection(_b('a')))), isTrue);
  });

  testWidgets('ConnectionKindColors.of falls back to the palette', (tester) async {
    late ConnectionKindColors c;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        c = ConnectionKindColors.of(context);
        return const SizedBox();
      }),
    ));
    expect(c.colorFor(ConnectionKind.buddy), isNotNull);
    expect(c.colorFor(ConnectionKind.tag), c.fallback);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the helpers and the painter**

`connection_kind_colors.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// One colour per kind, taken from the destination accents so every theme
/// preset and both brightnesses are covered. Kind colour is data encoding,
/// not chrome, so the diver's accent toggles do not apply here.
class ConnectionKindColors {
  const ConnectionKindColors(this._colors, this.fallback);

  final Map<ConnectionKind, Color> _colors;
  final Color fallback;

  factory ConnectionKindColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<FeatureAccentColors>() ??
        (theme.brightness == Brightness.dark
            ? FeatureAccentColors.dark
            : FeatureAccentColors.light);
    final fallback = palette.of('connections') ?? theme.colorScheme.primary;
    return ConnectionKindColors({
      for (final kind in ConnectionKind.values)
        if (kind.accentFeatureId != null &&
            palette.of(kind.accentFeatureId!) != null)
          kind: palette.of(kind.accentFeatureId!)!,
    }, fallback);
  }

  Color colorFor(ConnectionKind kind) => _colors[kind] ?? fallback;
}
```

`node_metrics.dart`:

```dart
import 'dart:math' as math;

/// Size and stroke rules shared by the painter, the hit tester and the
/// selection UI, so a node is drawn and picked at the same radius.
class NodeMetrics {
  const NodeMetrics._();

  static const double minRadius = 7;
  static const double maxRadius = 26;

  static double radiusFor(int diveCount, int maxDiveCount) {
    if (maxDiveCount <= 0) return maxRadius;
    final t = math.sqrt((diveCount / maxDiveCount).clamp(0.0, 1.0));
    return minRadius + (maxRadius - minRadius) * t;
  }

  static double edgeWidthFor(int weight, int maxWeight) {
    if (maxWeight <= 0) return 1;
    return 1 + 5 * (weight / maxWeight).clamp(0.0, 1.0);
  }

  static double edgeOpacityFor(int weight, int maxWeight) {
    if (maxWeight <= 0) return 0.5;
    return 0.25 + 0.55 * (weight / maxWeight).clamp(0.0, 1.0);
  }

  /// First letter of up to two words, upper-cased.
  static String initialsFor(String label) {
    final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}
```

`label_collision.dart`:

```dart
import 'dart:ui';

import 'package:submersion/features/connections/domain/entities/node_ref.dart';

class LabelCollision {
  const LabelCollision._();

  /// Keeps each label whose rect does not overlap an already-kept,
  /// higher-ranked label. [ranked] is in priority order.
  static Set<NodeRef> visible(List<({NodeRef ref, Rect rect})> ranked) {
    final kept = <Rect>[];
    final out = <NodeRef>{};
    for (final c in ranked) {
      final clashes = kept.any((k) => _strictlyOverlaps(k, c.rect));
      if (clashes) continue;
      kept.add(c.rect);
      out.add(c.ref);
    }
    return out;
  }

  static bool _strictlyOverlaps(Rect a, Rect b) =>
      a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;
}
```

`connections_painter.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

import 'connection_kind_colors.dart';
import 'graph_viewport.dart';
import 'label_collision.dart';
import 'node_metrics.dart';

/// Draws edges, nodes and labels for one frame. Pure function of its inputs;
/// the canvas widget owns gesture state and decoded photos.
class ConnectionsPainter extends CustomPainter {
  ConnectionsPainter({
    required this.graph,
    required this.frame,
    required this.viewport,
    required this.colors,
    required this.labelStyle,
    this.selection,
    this.hovered,
    this.photos = const {},
    this.labelZoomThreshold = 0.6,
    this.maxLabelsAtLowZoom = 12,
  });

  final ConnectionGraph graph;
  final LayoutFrame frame;
  final GraphViewport viewport;
  final ConnectionKindColors colors;
  final TextStyle labelStyle;
  final GraphSelection? selection;
  final NodeRef? hovered;

  /// Decoded buddy photos, keyed by node.
  final Map<NodeRef, ui.Image> photos;
  final double labelZoomThreshold;
  final int maxLabelsAtLowZoom;

  /// The nodes lit up by [selection]: a node's far ends, or both ends of an
  /// edge. Empty without a selection.
  static Set<NodeRef> neighboursOf(ConnectionGraph graph, GraphSelection? selection) {
    switch (selection) {
      case null:
        return const {};
      case NodeSelection(:final ref):
        return {for (final e in graph.edgesOf(ref)) e.otherEnd(ref)!};
      case EdgeSelection(:final a, :final b):
        return {a, b};
    }
  }

  double radiusOf(ConnectionNode n) =>
      NodeMetrics.radiusFor(n.diveCount, graph.maxDiveCount) * viewport.scale.clamp(0.5, 1.5);

  @override
  void paint(Canvas canvas, Size size) {
    final lit = neighboursOf(graph, selection);
    final selectedNode = switch (selection) {
      NodeSelection(:final ref) => ref,
      _ => null,
    };
    final dim = selection != null;

    for (final e in graph.edges) {
      final a = frame.positions[e.source];
      final b = frame.positions[e.target];
      if (a == null || b == null) continue;
      final onSelection = switch (selection) {
        NodeSelection(:final ref) => e.touches(ref),
        EdgeSelection(:final a, :final b) => e.touches(a) && e.touches(b),
        null => false,
      };
      final alpha = NodeMetrics.edgeOpacityFor(e.weight, graph.maxWeight) *
          (dim && !onSelection ? 0.25 : 1);
      final paint = Paint()
        ..color = labelStyle.color!.withValues(alpha: alpha)
        ..strokeWidth = NodeMetrics.edgeWidthFor(e.weight, graph.maxWeight) *
            (onSelection ? 1.4 : 1)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(viewport.toScreen(a), viewport.toScreen(b), paint);
    }

    final nodesByDives = [...graph.nodes]
      ..sort((x, y) => y.diveCount.compareTo(x.diveCount));
    final labelCandidates = <({NodeRef ref, Rect rect})>[];
    final painters = <NodeRef, TextPainter>{};

    for (final n in nodesByDives) {
      final p = frame.positions[n.ref];
      if (p == null) continue;
      final centre = viewport.toScreen(p);
      final r = radiusOf(n);
      final isSelected = n.ref == selectedNode;
      final isLit = isSelected || lit.contains(n.ref) || n.ref == hovered;
      final fill = colors.colorFor(n.ref.kind).withValues(alpha: dim && !isLit ? 0.35 : 1);
      canvas.drawCircle(centre, r, Paint()..color = fill);
      final photo = photos[n.ref];
      if (photo != null && r >= 14) {
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r - 1.5)));
        paintImage(
          canvas: canvas,
          rect: Rect.fromCircle(center: centre, radius: r),
          image: photo,
          fit: BoxFit.cover,
          opacity: dim && !isLit ? 0.35 : 1,
        );
        canvas.restore();
      } else if (r >= 12) {
        final tp = TextPainter(
          text: TextSpan(
            text: NodeMetrics.initialsFor(n.label),
            style: labelStyle.copyWith(
              color: Colors.white,
              fontSize: r * 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
      }
      if (isSelected || isLit) {
        canvas.drawCircle(
          centre,
          r + 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 3 : 1.5
            ..color = labelStyle.color!,
        );
      }
      final tp = TextPainter(
        text: TextSpan(text: n.label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 140);
      painters[n.ref] = tp;
      labelCandidates.add((
        ref: n.ref,
        rect: Rect.fromLTWH(centre.dx - tp.width / 2, centre.dy + r + 2, tp.width, tp.height),
      ));
    }

    final allowed = viewport.scale < labelZoomThreshold
        ? labelCandidates.take(maxLabelsAtLowZoom).toList()
        : labelCandidates;
    final forced = {if (selectedNode != null) selectedNode, ...lit, if (hovered != null) hovered!};
    final ranked = [
      ...allowed.where((c) => forced.contains(c.ref)),
      ...allowed.where((c) => !forced.contains(c.ref)),
    ];
    final visible = LabelCollision.visible(ranked);
    for (final c in ranked) {
      if (!visible.contains(c.ref)) continue;
      final tp = painters[c.ref]!;
      final alpha = dim && !forced.contains(c.ref) ? 0.4 : 1.0;
      if (alpha < 1) {
        tp.text = TextSpan(text: (tp.text as TextSpan).text, style: labelStyle.copyWith(color: labelStyle.color!.withValues(alpha: alpha)));
        tp.layout(maxWidth: 140);
      }
      tp.paint(canvas, c.rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(ConnectionsPainter old) =>
      old.frame != frame ||
      old.graph != graph ||
      old.viewport.scale != viewport.scale ||
      old.viewport.offset != viewport.offset ||
      old.selection != selection ||
      old.hovered != hovered ||
      old.photos.length != photos.length ||
      old.labelStyle != labelStyle;
}
```

`LayoutFrame` has no value equality, so `old.frame != frame` compares identity, which is what we want: the controller emits a new frame object only when positions changed. `shouldRepaint` for identical inputs returns false because the test builds two painters sharing the same `frame`, `graph` and `viewport` constants.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: PASS. `GraphViewport` needs `==` for the `shouldRepaint` test: the painter compares `scale` and `offset` separately, so no operator is needed.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/canvas test/features/connections/presentation/canvas
git commit -m "feat(connections): kind colours, node metrics, label collision and painter"
```

---

### Task 13: ConnectionsCanvas widget (gestures, viewport, photos, tooltip)

**Files:**
- Create: `lib/features/connections/presentation/canvas/connections_canvas.dart`
- Test: `test/features/connections/presentation/canvas/connections_canvas_test.dart`

**Interfaces:**
- Consumes: `ConnectionsLayoutController` (Task 10), `GraphViewport`, `ConnectionsHitTester`, `ConnectionsPainter`, `ConnectionKindColors`, `NodeMetrics`.
- Produces: `ConnectionsCanvas({required graph, required controller, required colors, selection, required onSelect(GraphSelection?), required onFocus(NodeRef), semanticsLabel})`. Handles: one-finger drag pans, two-finger pinch zooms about the focal point, wheel and trackpad zoom, tap selects node then edge then clears, double-tap focuses a node, long-press drag moves and pins a node, hover shows a tooltip. Fits to content on the first settled frame and whenever the graph object changes.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('me'), label: 'Me', diveCount: 9),
    ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 3),
  ],
  edges: [
    ConnectionEdge(source: _b('me'), target: _b('jane'), weight: 3, firstDiveAt: DateTime.utc(2024), lastDiveAt: DateTime.utc(2024)),
  ],
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
    ..setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('me'));
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
          colors: const ConnectionKindColors({ConnectionKind.buddy: Colors.pink}, Colors.grey),
          onSelect: widget.onSelect,
          onFocus: widget.onFocus,
          semanticsLabel: '2 nodes',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tap on the centre selects the focus node, tap on empty clears', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final selections = <GraphSelection?>[];
    await tester.pumpWidget(_Host(onSelect: selections.add, onFocus: (_) {}));
    await tester.pump();
    // Ego layout puts the focus at graph origin; fit-to-content centres the
    // bounds, and with one neighbour at (170, 0) the origin sits left of
    // centre: read the actual screen position from the painter instead.
    final canvas = tester.widget<CustomPaint>(find.byKey(const ValueKey('connections-canvas-paint')));
    final painter = canvas.painter! as dynamic;
    final centre = painter.viewport.toScreen(painter.frame.positions[_b('me')]!) as Offset;
    final origin = tester.getTopLeft(find.byType(ConnectionsCanvas));
    await tester.tapAt(origin + centre);
    await tester.pump();
    expect(selections.last, NodeSelection(_b('me')));
    await tester.tapAt(origin + const Offset(5, 395));
    await tester.pump();
    expect(selections.last, isNull);
  });

  testWidgets('double tap on a node asks for focus', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final focused = <NodeRef>[];
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: focused.add));
    await tester.pump();
    final canvas = tester.widget<CustomPaint>(find.byKey(const ValueKey('connections-canvas-paint')));
    final painter = canvas.painter! as dynamic;
    final jane = painter.viewport.toScreen(painter.frame.positions[_b('jane')]!) as Offset;
    final origin = tester.getTopLeft(find.byType(ConnectionsCanvas));
    await tester.tapAt(origin + jane);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(origin + jane);
    await tester.pump(const Duration(milliseconds: 400));
    expect(focused, [_b('jane')]);
  });

  testWidgets('exposes a semantics label', (tester) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pump();
    expect(find.bySemanticsLabel('2 nodes'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/canvas/connections_canvas_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the canvas widget**

```dart
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

import 'connection_kind_colors.dart';
import 'connections_hit_tester.dart';
import 'connections_painter.dart';
import 'graph_viewport.dart';
import 'node_metrics.dart';

/// The interactive graph surface. Owns the viewport, decoded photos, hover
/// and drag state; the layout lives in [controller] and the selection in the
/// caller.
class ConnectionsCanvas extends StatefulWidget {
  const ConnectionsCanvas({
    super.key,
    required this.graph,
    required this.controller,
    required this.colors,
    required this.onSelect,
    required this.onFocus,
    this.selection,
    this.semanticsLabel,
  });

  final ConnectionGraph graph;
  final ConnectionsLayoutController controller;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final ValueChanged<GraphSelection?> onSelect;
  final ValueChanged<NodeRef> onFocus;
  final String? semanticsLabel;

  @override
  State<ConnectionsCanvas> createState() => _ConnectionsCanvasState();
}

class _ConnectionsCanvasState extends State<ConnectionsCanvas> {
  GraphViewport _viewport = const GraphViewport();
  bool _fitted = false;
  Size _size = Size.zero;
  NodeRef? _hovered;
  Offset? _hoverPosition;
  NodeRef? _dragging;
  double _scaleBase = 1;
  double _panZoomBase = 1;
  Offset? _doubleTapPosition;
  final Map<NodeRef, ui.Image> _photos = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFrame);
    _decodePhotos();
  }

  @override
  void didUpdateWidget(ConnectionsCanvas old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onFrame);
      widget.controller.addListener(_onFrame);
    }
    if (old.graph != widget.graph) {
      _fitted = false;
      _decodePhotos();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFrame);
    for (final img in _photos.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _onFrame() {
    if (!mounted) return;
    setState(() {
      if (!_fitted && _size != Size.zero &&
          (widget.controller.settled || widget.controller.frame.positions.isNotEmpty)) {
        _viewport = _viewport.fitted(widget.controller.frame.bounds, _size);
        _fitted = widget.controller.settled;
      }
    });
  }

  Future<void> _decodePhotos() async {
    final wanted = {for (final n in widget.graph.nodes) if (n.photo != null) n.ref: n.photo!};
    for (final ref in _photos.keys.where((r) => !wanted.containsKey(r)).toList()) {
      _photos.remove(ref)?.dispose();
    }
    for (final entry in wanted.entries) {
      if (_photos.containsKey(entry.key)) continue;
      try {
        final img = await decodeImageFromList(entry.value);
        if (!mounted) {
          img.dispose();
          return;
        }
        setState(() => _photos[entry.key] = img);
      } catch (_) {
        // A corrupt photo falls back to initials.
      }
    }
  }

  double _radiusOf(NodeRef ref) {
    final node = widget.graph.nodeFor(ref);
    if (node == null) return NodeMetrics.minRadius;
    return NodeMetrics.radiusFor(node.diveCount, widget.graph.maxDiveCount) *
        _viewport.scale.clamp(0.5, 1.5);
  }

  NodeRef? _nodeAt(Offset p) => ConnectionsHitTester.hitNode(
    p,
    frame: widget.controller.frame,
    viewport: _viewport,
    radiusOf: _radiusOf,
  );

  void _tap(Offset p) {
    final node = _nodeAt(p);
    if (node != null) {
      widget.onSelect(NodeSelection(node));
      return;
    }
    final edge = ConnectionsHitTester.hitEdge(
      p,
      frame: widget.controller.frame,
      viewport: _viewport,
      edges: widget.graph.edges,
    );
    widget.onSelect(edge == null ? null : EdgeSelection(edge.source, edge.target));
  }

  void _zoomAt(double factor, Offset focal) {
    setState(() {
      _viewport = _viewport
          .zoomedAt(factor, focal)
          .clampedTo(widget.controller.frame.bounds, _size);
    });
  }

  void _pan(Offset delta) {
    setState(() {
      _viewport = _viewport
          .panned(delta)
          .clampedTo(widget.controller.frame.bounds, _size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurface,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _size) {
          _size = size;
          if (!_fitted) {
            _viewport = _viewport.fitted(widget.controller.frame.bounds, size);
          }
        }
        final painter = ConnectionsPainter(
          graph: widget.graph,
          frame: widget.controller.frame,
          viewport: _viewport,
          colors: widget.colors,
          labelStyle: labelStyle,
          selection: widget.selection,
          hovered: _hovered,
          photos: Map.unmodifiable(_photos),
        );
        final gestures = RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _TouchScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_TouchScaleGestureRecognizer>(
                  () => _TouchScaleGestureRecognizer(
                    supportedDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.invertedStylus,
                      PointerDeviceKind.unknown,
                    },
                  ),
                  (r) => r
                    ..onStart = (_) => _scaleBase = _viewport.scale
                    ..onUpdate = (d) {
                      if (_dragging != null) return;
                      if (d.pointerCount < 2) {
                        _pan(d.focalPointDelta);
                      } else {
                        final target = (_scaleBase * d.scale)
                            .clamp(GraphViewport.minScale, GraphViewport.maxScale);
                        _zoomAt(target / _viewport.scale, d.localFocalPoint);
                        _pan(d.focalPointDelta);
                      }
                    },
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (r) => r.onTapUp = (d) => _tap(d.localPosition),
                ),
            DoubleTapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
                  () => DoubleTapGestureRecognizer(),
                  (r) => r
                    ..onDoubleTapDown = (d) => _doubleTapPosition = d.localPosition
                    ..onDoubleTap = () {
                      final p = _doubleTapPosition;
                      if (p == null) return;
                      final node = _nodeAt(p);
                      if (node != null) widget.onFocus(node);
                    },
                ),
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(),
                  (r) => r
                    ..onLongPressStart = (d) {
                      _dragging = _nodeAt(d.localPosition);
                      if (_dragging != null) widget.onSelect(NodeSelection(_dragging!));
                    }
                    ..onLongPressMoveUpdate = (d) {
                      final node = _dragging;
                      if (node == null) return;
                      widget.controller.moveNode(node, _viewport.toGraph(d.localPosition));
                    }
                    ..onLongPressEnd = (_) => _dragging = null
                    ..onLongPressCancel = () => _dragging = null,
                ),
          },
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('connections-canvas-paint'),
              painter: painter,
              size: size,
            ),
          ),
        );
        final interactive = Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _zoomAt(signal.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1, signal.localPosition);
            }
          },
          onPointerPanZoomStart: (_) => _panZoomBase = _viewport.scale,
          onPointerPanZoomUpdate: (e) {
            final target = (_panZoomBase * e.scale)
                .clamp(GraphViewport.minScale, GraphViewport.maxScale);
            _zoomAt(target / _viewport.scale, e.localPosition);
            _pan(e.panDelta);
          },
          child: MouseRegion(
            onHover: (e) {
              final node = _nodeAt(e.localPosition);
              if (node != _hovered || node != null) {
                setState(() {
                  _hovered = node;
                  _hoverPosition = node == null ? null : e.localPosition;
                });
              }
            },
            onExit: (_) => setState(() {
              _hovered = null;
              _hoverPosition = null;
            }),
            child: gestures,
          ),
        );
        return Semantics(
          label: widget.semanticsLabel,
          container: true,
          child: Stack(
            children: [
              Positioned.fill(child: interactive),
              if (_hovered != null && _hoverPosition != null)
                Positioned(
                  left: (_hoverPosition!.dx + 12).clamp(0.0, size.width - 160),
                  top: (_hoverPosition!.dy + 12).clamp(0.0, size.height - 48),
                  child: IgnorePointer(
                    child: _HoverTooltip(
                      label: widget.graph.nodeFor(_hovered!)?.label ?? '',
                      count: widget.graph.nodeFor(_hovered!)?.diveCount ?? 0,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Refuses trackpad pan-zoom so the Listener above handles it once. Same
/// arrangement as the 3D viewport (dive_3d_interactive_viewport.dart).
class _TouchScaleGestureRecognizer extends ScaleGestureRecognizer {
  _TouchScaleGestureRecognizer({super.supportedDevices});

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;
}

class _HoverTooltip extends StatelessWidget {
  const _HoverTooltip({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      color: theme.colorScheme.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '$label ($count)',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onInverseSurface),
        ),
      ),
    );
  }
}
```

The hover tooltip shows `label (count)`; that count is a number without a unit, so it needs no formatter. Task 18 passes the localized semantics summary in.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/connections/presentation/canvas/connections_canvas_test.dart`
Expected: PASS. If the tap test finds the wrong selection, print `painter.viewport.scale` and the two screen positions in the test; the ego frame is settled at construction, so `_fitted` becomes true on the first `LayoutBuilder` pass and the positions are stable.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/canvas test/features/connections/presentation/canvas
git commit -m "feat(connections): interactive canvas with pan, zoom, tap, drag and hover"
```

---

### Task 14: Localisation keys in all eleven locales

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`

**Interfaces:**
- Produces the `AppLocalizations` getters and methods listed below, used by Tasks 15 to 19.

- [ ] **Step 1: Add the English keys**

In `app_en.arb` insert the `nav_connections` line after `"nav_certifications": "Certifications",` (alphabetical), and insert the `connections_*` block alphabetically (after the last `common_*` key and before the first `courses_*` key). Values:

```json
  "connections_title": "Connections",
  "connections_lens_circle": "Dive circle",
  "connections_lens_where": "Who dives where",
  "connections_tooltip_filter": "Filter connections",
  "connections_tooltip_relayout": "Lay out again",
  "connections_filterBar_nodes": "{count, plural, =1{1 node} other{{count} nodes}}",
  "@connections_filterBar_nodes": {"placeholders": {"count": {"type": "int"}}},
  "connections_filterBar_edges": "{count, plural, =1{1 connection} other{{count} connections}}",
  "@connections_filterBar_edges": {"placeholders": {"count": {"type": "int"}}},
  "connections_filterBar_clear": "Clear filter",
  "connections_hiddenNodes": "{count, plural, =1{1 more not shown} other{{count} more not shown}}",
  "@connections_hiddenNodes": {"placeholders": {"count": {"type": "int"}}},
  "connections_showAll": "Show all",
  "connections_showAll_confirmTitle": "Show every node?",
  "connections_showAll_confirmBody": "{count} nodes may take a moment to lay out on this device.",
  "@connections_showAll_confirmBody": {"placeholders": {"count": {"type": "int"}}},
  "connections_action_open": "Open",
  "connections_action_focus": "Focus",
  "connections_action_showDives": "Show dives",
  "connections_action_openInConnections": "Open in Connections",
  "connections_selection_divesTogether": "{count, plural, =1{1 dive together} other{{count} dives together}}",
  "@connections_selection_divesTogether": {"placeholders": {"count": {"type": "int"}}},
  "connections_selection_dives": "{count, plural, =1{1 dive} other{{count} dives}}",
  "@connections_selection_dives": {"placeholders": {"count": {"type": "int"}}},
  "connections_selection_topConnections": "Top connections",
  "connections_selection_firstLast": "First {first}, last {last}",
  "@connections_selection_firstLast": {"placeholders": {"first": {"type": "String"}, "last": {"type": "String"}}},
  "connections_selection_hint": "Tap a node or a line to see details.",
  "connections_empty_noDives": "No dives yet. Connections appear once your log has dives in it.",
  "connections_empty_buddies": "No buddies are linked to dives yet. Add buddies to your dives, or convert legacy buddy names in Settings, Data Tools.",
  "connections_empty_sites": "No dives have a site yet.",
  "connections_focusMissing": "That item is no longer in the log.",
  "connections_error_load": "Could not load connections.",
  "connections_legend_title": "Legend",
  "connections_yearRange_label": "Years {first} to {last}",
  "@connections_yearRange_label": {"placeholders": {"first": {"type": "int"}, "last": {"type": "int"}}},
  "connections_semantics_summary": "{nodes} nodes and {edges} connections",
  "@connections_semantics_summary": {"placeholders": {"nodes": {"type": "int"}, "edges": {"type": "int"}}},
  "connections_kind_buddy": "Buddies",
  "connections_kind_site": "Sites",
  "connections_kind_trip": "Trips",
  "connections_kind_diveCenter": "Dive centers",
  "connections_kind_equipment": "Equipment",
  "connections_kind_species": "Species",
  "connections_kind_tag": "Tags",
  "connections_kind_diveType": "Dive types",
  "connections_kind_diveComputer": "Dive computers",
  "connections_kind_course": "Courses",
```

and, in the `nav_*` block:

```json
  "nav_connections": "Connections",
```

`common_action_retry` already exists and is reused for the error view.

- [ ] **Step 2: Add the other ten locales**

In each non-English file, insert `nav_connections` directly after the `"nav_buddies"` entry, and the `connections_*` block directly after the `"common_action_delete"` entry. The `@` metadata entries are copied verbatim from English (metadata is not translated). Values per locale (plural keys shown in full; every other key is a plain string):

**de**
```json
  "nav_connections": "Verbindungen",
  "connections_title": "Verbindungen",
  "connections_lens_circle": "Tauchkreis",
  "connections_lens_where": "Wer taucht wo",
  "connections_tooltip_filter": "Verbindungen filtern",
  "connections_tooltip_relayout": "Neu anordnen",
  "connections_filterBar_nodes": "{count, plural, =1{1 Knoten} other{{count} Knoten}}",
  "connections_filterBar_edges": "{count, plural, =1{1 Verbindung} other{{count} Verbindungen}}",
  "connections_filterBar_clear": "Filter löschen",
  "connections_hiddenNodes": "{count, plural, =1{1 weiterer nicht angezeigt} other{{count} weitere nicht angezeigt}}",
  "connections_showAll": "Alle anzeigen",
  "connections_showAll_confirmTitle": "Alle Knoten anzeigen?",
  "connections_showAll_confirmBody": "{count} Knoten brauchen auf diesem Gerät eventuell einen Moment zum Anordnen.",
  "connections_action_open": "Öffnen",
  "connections_action_focus": "Fokussieren",
  "connections_action_showDives": "Tauchgänge anzeigen",
  "connections_action_openInConnections": "In Verbindungen öffnen",
  "connections_selection_divesTogether": "{count, plural, =1{1 gemeinsamer Tauchgang} other{{count} gemeinsame Tauchgänge}}",
  "connections_selection_dives": "{count, plural, =1{1 Tauchgang} other{{count} Tauchgänge}}",
  "connections_selection_topConnections": "Stärkste Verbindungen",
  "connections_selection_firstLast": "Erster {first}, letzter {last}",
  "connections_selection_hint": "Tippe auf einen Knoten oder eine Linie, um Details zu sehen.",
  "connections_empty_noDives": "Noch keine Tauchgänge. Verbindungen erscheinen, sobald dein Logbuch Tauchgänge enthält.",
  "connections_empty_buddies": "Noch keine Buddys mit Tauchgängen verknüpft. Füge Buddys zu deinen Tauchgängen hinzu oder wandle alte Buddy-Namen unter Einstellungen, Datenwerkzeuge um.",
  "connections_empty_sites": "Noch kein Tauchgang hat einen Tauchplatz.",
  "connections_focusMissing": "Dieser Eintrag ist nicht mehr im Logbuch.",
  "connections_error_load": "Verbindungen konnten nicht geladen werden.",
  "connections_legend_title": "Legende",
  "connections_yearRange_label": "Jahre {first} bis {last}",
  "connections_semantics_summary": "{nodes} Knoten und {edges} Verbindungen",
  "connections_kind_buddy": "Buddys",
  "connections_kind_site": "Tauchplätze",
  "connections_kind_trip": "Reisen",
  "connections_kind_diveCenter": "Tauchbasen",
  "connections_kind_equipment": "Ausrüstung",
  "connections_kind_species": "Arten",
  "connections_kind_tag": "Tags",
  "connections_kind_diveType": "Tauchgangsarten",
  "connections_kind_diveComputer": "Tauchcomputer",
  "connections_kind_course": "Kurse",
```

**es**
```json
  "nav_connections": "Conexiones",
  "connections_title": "Conexiones",
  "connections_lens_circle": "Círculo de buceo",
  "connections_lens_where": "Quién bucea dónde",
  "connections_tooltip_filter": "Filtrar conexiones",
  "connections_tooltip_relayout": "Reorganizar",
  "connections_filterBar_nodes": "{count, plural, =1{1 nodo} other{{count} nodos}}",
  "connections_filterBar_edges": "{count, plural, =1{1 conexión} other{{count} conexiones}}",
  "connections_filterBar_clear": "Quitar filtro",
  "connections_hiddenNodes": "{count, plural, =1{1 más sin mostrar} other{{count} más sin mostrar}}",
  "connections_showAll": "Mostrar todo",
  "connections_showAll_confirmTitle": "¿Mostrar todos los nodos?",
  "connections_showAll_confirmBody": "{count} nodos pueden tardar un momento en organizarse en este dispositivo.",
  "connections_action_open": "Abrir",
  "connections_action_focus": "Enfocar",
  "connections_action_showDives": "Ver inmersiones",
  "connections_action_openInConnections": "Abrir en Conexiones",
  "connections_selection_divesTogether": "{count, plural, =1{1 inmersión juntos} other{{count} inmersiones juntos}}",
  "connections_selection_dives": "{count, plural, =1{1 inmersión} other{{count} inmersiones}}",
  "connections_selection_topConnections": "Conexiones principales",
  "connections_selection_firstLast": "Primera {first}, última {last}",
  "connections_selection_hint": "Toca un nodo o una línea para ver los detalles.",
  "connections_empty_noDives": "Aún no hay inmersiones. Las conexiones aparecen cuando el diario tiene inmersiones.",
  "connections_empty_buddies": "Aún no hay compañeros vinculados a inmersiones. Añade compañeros a tus inmersiones o convierte los nombres antiguos en Ajustes, Herramientas de datos.",
  "connections_empty_sites": "Ninguna inmersión tiene punto de buceo todavía.",
  "connections_focusMissing": "Ese elemento ya no está en el diario.",
  "connections_error_load": "No se pudieron cargar las conexiones.",
  "connections_legend_title": "Leyenda",
  "connections_yearRange_label": "Años {first} a {last}",
  "connections_semantics_summary": "{nodes} nodos y {edges} conexiones",
  "connections_kind_buddy": "Compañeros",
  "connections_kind_site": "Puntos de buceo",
  "connections_kind_trip": "Viajes",
  "connections_kind_diveCenter": "Centros de buceo",
  "connections_kind_equipment": "Equipo",
  "connections_kind_species": "Especies",
  "connections_kind_tag": "Etiquetas",
  "connections_kind_diveType": "Tipos de inmersión",
  "connections_kind_diveComputer": "Ordenadores de buceo",
  "connections_kind_course": "Cursos",
```

**fr** (count interpolated in the `=1` branch, per the plural guard)
```json
  "nav_connections": "Connexions",
  "connections_title": "Connexions",
  "connections_lens_circle": "Cercle de plongée",
  "connections_lens_where": "Qui plonge où",
  "connections_tooltip_filter": "Filtrer les connexions",
  "connections_tooltip_relayout": "Réorganiser",
  "connections_filterBar_nodes": "{count, plural, =1{{count} nœud} other{{count} nœuds}}",
  "connections_filterBar_edges": "{count, plural, =1{{count} connexion} other{{count} connexions}}",
  "connections_filterBar_clear": "Effacer le filtre",
  "connections_hiddenNodes": "{count, plural, =1{{count} de plus non affiché} other{{count} de plus non affichés}}",
  "connections_showAll": "Tout afficher",
  "connections_showAll_confirmTitle": "Afficher tous les nœuds ?",
  "connections_showAll_confirmBody": "{count} nœuds peuvent prendre un moment à s'organiser sur cet appareil.",
  "connections_action_open": "Ouvrir",
  "connections_action_focus": "Centrer",
  "connections_action_showDives": "Voir les plongées",
  "connections_action_openInConnections": "Ouvrir dans Connexions",
  "connections_selection_divesTogether": "{count, plural, =1{{count} plongée ensemble} other{{count} plongées ensemble}}",
  "connections_selection_dives": "{count, plural, =1{{count} plongée} other{{count} plongées}}",
  "connections_selection_topConnections": "Connexions principales",
  "connections_selection_firstLast": "Première {first}, dernière {last}",
  "connections_selection_hint": "Touchez un nœud ou une ligne pour voir les détails.",
  "connections_empty_noDives": "Aucune plongée pour l'instant. Les connexions apparaissent dès que le carnet contient des plongées.",
  "connections_empty_buddies": "Aucun binôme n'est encore lié à une plongée. Ajoutez des binômes à vos plongées ou convertissez les anciens noms dans Réglages, Outils de données.",
  "connections_empty_sites": "Aucune plongée n'a encore de site.",
  "connections_focusMissing": "Cet élément n'est plus dans le carnet.",
  "connections_error_load": "Impossible de charger les connexions.",
  "connections_legend_title": "Légende",
  "connections_yearRange_label": "Années {first} à {last}",
  "connections_semantics_summary": "{nodes} nœuds et {edges} connexions",
  "connections_kind_buddy": "Binômes",
  "connections_kind_site": "Sites",
  "connections_kind_trip": "Voyages",
  "connections_kind_diveCenter": "Centres de plongée",
  "connections_kind_equipment": "Équipement",
  "connections_kind_species": "Espèces",
  "connections_kind_tag": "Étiquettes",
  "connections_kind_diveType": "Types de plongée",
  "connections_kind_diveComputer": "Ordinateurs de plongée",
  "connections_kind_course": "Cours",
```

**it**
```json
  "nav_connections": "Connessioni",
  "connections_title": "Connessioni",
  "connections_lens_circle": "Cerchia di immersione",
  "connections_lens_where": "Chi si immerge dove",
  "connections_tooltip_filter": "Filtra connessioni",
  "connections_tooltip_relayout": "Ridisponi",
  "connections_filterBar_nodes": "{count, plural, =1{1 nodo} other{{count} nodi}}",
  "connections_filterBar_edges": "{count, plural, =1{1 connessione} other{{count} connessioni}}",
  "connections_filterBar_clear": "Rimuovi filtro",
  "connections_hiddenNodes": "{count, plural, =1{1 altro non mostrato} other{{count} altri non mostrati}}",
  "connections_showAll": "Mostra tutto",
  "connections_showAll_confirmTitle": "Mostrare tutti i nodi?",
  "connections_showAll_confirmBody": "{count} nodi potrebbero richiedere un momento per disporsi su questo dispositivo.",
  "connections_action_open": "Apri",
  "connections_action_focus": "Metti al centro",
  "connections_action_showDives": "Mostra immersioni",
  "connections_action_openInConnections": "Apri in Connessioni",
  "connections_selection_divesTogether": "{count, plural, =1{1 immersione insieme} other{{count} immersioni insieme}}",
  "connections_selection_dives": "{count, plural, =1{1 immersione} other{{count} immersioni}}",
  "connections_selection_topConnections": "Connessioni principali",
  "connections_selection_firstLast": "Prima {first}, ultima {last}",
  "connections_selection_hint": "Tocca un nodo o una linea per vedere i dettagli.",
  "connections_empty_noDives": "Nessuna immersione ancora. Le connessioni compaiono quando il diario contiene immersioni.",
  "connections_empty_buddies": "Nessun compagno è ancora collegato alle immersioni. Aggiungi compagni alle tue immersioni o converti i vecchi nomi in Impostazioni, Strumenti dati.",
  "connections_empty_sites": "Nessuna immersione ha ancora un sito.",
  "connections_focusMissing": "Quell'elemento non è più nel diario.",
  "connections_error_load": "Impossibile caricare le connessioni.",
  "connections_legend_title": "Legenda",
  "connections_yearRange_label": "Anni dal {first} al {last}",
  "connections_semantics_summary": "{nodes} nodi e {edges} connessioni",
  "connections_kind_buddy": "Compagni",
  "connections_kind_site": "Siti",
  "connections_kind_trip": "Viaggi",
  "connections_kind_diveCenter": "Diving center",
  "connections_kind_equipment": "Attrezzatura",
  "connections_kind_species": "Specie",
  "connections_kind_tag": "Tag",
  "connections_kind_diveType": "Tipi di immersione",
  "connections_kind_diveComputer": "Computer da immersione",
  "connections_kind_course": "Corsi",
```

**nl**
```json
  "nav_connections": "Verbindingen",
  "connections_title": "Verbindingen",
  "connections_lens_circle": "Duikkring",
  "connections_lens_where": "Wie duikt waar",
  "connections_tooltip_filter": "Verbindingen filteren",
  "connections_tooltip_relayout": "Opnieuw schikken",
  "connections_filterBar_nodes": "{count, plural, =1{1 knooppunt} other{{count} knooppunten}}",
  "connections_filterBar_edges": "{count, plural, =1{1 verbinding} other{{count} verbindingen}}",
  "connections_filterBar_clear": "Filter wissen",
  "connections_hiddenNodes": "{count, plural, =1{1 meer niet getoond} other{{count} meer niet getoond}}",
  "connections_showAll": "Alles tonen",
  "connections_showAll_confirmTitle": "Alle knooppunten tonen?",
  "connections_showAll_confirmBody": "{count} knooppunten kunnen op dit apparaat even duren om te schikken.",
  "connections_action_open": "Openen",
  "connections_action_focus": "Centreren",
  "connections_action_showDives": "Duiken tonen",
  "connections_action_openInConnections": "Openen in Verbindingen",
  "connections_selection_divesTogether": "{count, plural, =1{1 duik samen} other{{count} duiken samen}}",
  "connections_selection_dives": "{count, plural, =1{1 duik} other{{count} duiken}}",
  "connections_selection_topConnections": "Sterkste verbindingen",
  "connections_selection_firstLast": "Eerste {first}, laatste {last}",
  "connections_selection_hint": "Tik op een knooppunt of lijn voor details.",
  "connections_empty_noDives": "Nog geen duiken. Verbindingen verschijnen zodra je logboek duiken bevat.",
  "connections_empty_buddies": "Nog geen buddy's gekoppeld aan duiken. Voeg buddy's toe aan je duiken of zet oude buddynamen om via Instellingen, Gegevenshulpmiddelen.",
  "connections_empty_sites": "Nog geen duik heeft een duikplek.",
  "connections_focusMissing": "Dat item staat niet meer in het logboek.",
  "connections_error_load": "Verbindingen konden niet worden geladen.",
  "connections_legend_title": "Legenda",
  "connections_yearRange_label": "Jaren {first} tot {last}",
  "connections_semantics_summary": "{nodes} knooppunten en {edges} verbindingen",
  "connections_kind_buddy": "Buddy's",
  "connections_kind_site": "Duikplekken",
  "connections_kind_trip": "Reizen",
  "connections_kind_diveCenter": "Duikcentra",
  "connections_kind_equipment": "Uitrusting",
  "connections_kind_species": "Soorten",
  "connections_kind_tag": "Labels",
  "connections_kind_diveType": "Duiktypen",
  "connections_kind_diveComputer": "Duikcomputers",
  "connections_kind_course": "Cursussen",
```

**pt** (count interpolated in the `=1` branch)
```json
  "nav_connections": "Ligações",
  "connections_title": "Ligações",
  "connections_lens_circle": "Círculo de mergulho",
  "connections_lens_where": "Quem mergulha onde",
  "connections_tooltip_filter": "Filtrar ligações",
  "connections_tooltip_relayout": "Reorganizar",
  "connections_filterBar_nodes": "{count, plural, =1{{count} nó} other{{count} nós}}",
  "connections_filterBar_edges": "{count, plural, =1{{count} ligação} other{{count} ligações}}",
  "connections_filterBar_clear": "Limpar filtro",
  "connections_hiddenNodes": "{count, plural, =1{{count} mais não mostrado} other{{count} mais não mostrados}}",
  "connections_showAll": "Mostrar tudo",
  "connections_showAll_confirmTitle": "Mostrar todos os nós?",
  "connections_showAll_confirmBody": "{count} nós podem demorar um momento a organizar neste dispositivo.",
  "connections_action_open": "Abrir",
  "connections_action_focus": "Centrar",
  "connections_action_showDives": "Ver mergulhos",
  "connections_action_openInConnections": "Abrir em Ligações",
  "connections_selection_divesTogether": "{count, plural, =1{{count} mergulho juntos} other{{count} mergulhos juntos}}",
  "connections_selection_dives": "{count, plural, =1{{count} mergulho} other{{count} mergulhos}}",
  "connections_selection_topConnections": "Ligações principais",
  "connections_selection_firstLast": "Primeiro {first}, último {last}",
  "connections_selection_hint": "Toque num nó ou numa linha para ver os detalhes.",
  "connections_empty_noDives": "Ainda não há mergulhos. As ligações aparecem quando o diário tiver mergulhos.",
  "connections_empty_buddies": "Ainda não há parceiros ligados a mergulhos. Adicione parceiros aos seus mergulhos ou converta nomes antigos em Definições, Ferramentas de dados.",
  "connections_empty_sites": "Nenhum mergulho tem ainda um local.",
  "connections_focusMissing": "Esse item já não está no diário.",
  "connections_error_load": "Não foi possível carregar as ligações.",
  "connections_legend_title": "Legenda",
  "connections_yearRange_label": "Anos {first} a {last}",
  "connections_semantics_summary": "{nodes} nós e {edges} ligações",
  "connections_kind_buddy": "Parceiros",
  "connections_kind_site": "Locais",
  "connections_kind_trip": "Viagens",
  "connections_kind_diveCenter": "Centros de mergulho",
  "connections_kind_equipment": "Equipamento",
  "connections_kind_species": "Espécies",
  "connections_kind_tag": "Etiquetas",
  "connections_kind_diveType": "Tipos de mergulho",
  "connections_kind_diveComputer": "Computadores de mergulho",
  "connections_kind_course": "Cursos",
```

**hu**
```json
  "nav_connections": "Kapcsolatok",
  "connections_title": "Kapcsolatok",
  "connections_lens_circle": "Búvárkör",
  "connections_lens_where": "Ki hol merül",
  "connections_tooltip_filter": "Kapcsolatok szűrése",
  "connections_tooltip_relayout": "Újrarendezés",
  "connections_filterBar_nodes": "{count, plural, =1{1 csomópont} other{{count} csomópont}}",
  "connections_filterBar_edges": "{count, plural, =1{1 kapcsolat} other{{count} kapcsolat}}",
  "connections_filterBar_clear": "Szűrő törlése",
  "connections_hiddenNodes": "{count, plural, =1{1 további nincs megjelenítve} other{{count} további nincs megjelenítve}}",
  "connections_showAll": "Összes megjelenítése",
  "connections_showAll_confirmTitle": "Minden csomópont megjelenítése?",
  "connections_showAll_confirmBody": "{count} csomópont elrendezése eltarthat egy pillanatig ezen az eszközön.",
  "connections_action_open": "Megnyitás",
  "connections_action_focus": "Középre",
  "connections_action_showDives": "Merülések megjelenítése",
  "connections_action_openInConnections": "Megnyitás a Kapcsolatokban",
  "connections_selection_divesTogether": "{count, plural, =1{1 közös merülés} other{{count} közös merülés}}",
  "connections_selection_dives": "{count, plural, =1{1 merülés} other{{count} merülés}}",
  "connections_selection_topConnections": "Legerősebb kapcsolatok",
  "connections_selection_firstLast": "Első {first}, utolsó {last}",
  "connections_selection_hint": "Koppints egy csomópontra vagy vonalra a részletekhez.",
  "connections_empty_noDives": "Még nincsenek merülések. A kapcsolatok akkor jelennek meg, ha a napló merüléseket tartalmaz.",
  "connections_empty_buddies": "Még nincs merüléshez kapcsolt búvártárs. Adj búvártársakat a merüléseidhez, vagy alakítsd át a régi neveket a Beállítások, Adateszközök menüben.",
  "connections_empty_sites": "Még egyik merülésnek sincs merülőhelye.",
  "connections_focusMissing": "Ez az elem már nincs a naplóban.",
  "connections_error_load": "A kapcsolatok betöltése nem sikerült.",
  "connections_legend_title": "Jelmagyarázat",
  "connections_yearRange_label": "{first} és {last} közötti évek",
  "connections_semantics_summary": "{nodes} csomópont és {edges} kapcsolat",
  "connections_kind_buddy": "Búvártársak",
  "connections_kind_site": "Merülőhelyek",
  "connections_kind_trip": "Utak",
  "connections_kind_diveCenter": "Búvárközpontok",
  "connections_kind_equipment": "Felszerelés",
  "connections_kind_species": "Fajok",
  "connections_kind_tag": "Címkék",
  "connections_kind_diveType": "Merüléstípusok",
  "connections_kind_diveComputer": "Búvárcomputerek",
  "connections_kind_course": "Tanfolyamok",
```

**zh**
```json
  "nav_connections": "关联",
  "connections_title": "关联",
  "connections_lens_circle": "潜伴圈",
  "connections_lens_where": "谁在哪里潜水",
  "connections_tooltip_filter": "筛选关联",
  "connections_tooltip_relayout": "重新排列",
  "connections_filterBar_nodes": "{count, plural, =1{1 个节点} other{{count} 个节点}}",
  "connections_filterBar_edges": "{count, plural, =1{1 条关联} other{{count} 条关联}}",
  "connections_filterBar_clear": "清除筛选",
  "connections_hiddenNodes": "{count, plural, =1{另有 1 个未显示} other{另有 {count} 个未显示}}",
  "connections_showAll": "全部显示",
  "connections_showAll_confirmTitle": "显示所有节点？",
  "connections_showAll_confirmBody": "{count} 个节点在此设备上可能需要片刻才能排列完成。",
  "connections_action_open": "打开",
  "connections_action_focus": "聚焦",
  "connections_action_showDives": "显示潜水",
  "connections_action_openInConnections": "在关联中打开",
  "connections_selection_divesTogether": "{count, plural, =1{共同潜水 1 次} other{共同潜水 {count} 次}}",
  "connections_selection_dives": "{count, plural, =1{1 次潜水} other{{count} 次潜水}}",
  "connections_selection_topConnections": "主要关联",
  "connections_selection_firstLast": "首次 {first}，最近 {last}",
  "connections_selection_hint": "点击节点或连线查看详情。",
  "connections_empty_noDives": "还没有潜水记录。日志中有潜水后会显示关联。",
  "connections_empty_buddies": "还没有潜伴与潜水关联。请为潜水添加潜伴，或在“设置”的“数据工具”中转换旧的潜伴名称。",
  "connections_empty_sites": "还没有潜水记录了潜点。",
  "connections_focusMissing": "该项目已不在日志中。",
  "connections_error_load": "无法加载关联。",
  "connections_legend_title": "图例",
  "connections_yearRange_label": "{first} 至 {last} 年",
  "connections_semantics_summary": "{nodes} 个节点和 {edges} 条关联",
  "connections_kind_buddy": "潜伴",
  "connections_kind_site": "潜点",
  "connections_kind_trip": "行程",
  "connections_kind_diveCenter": "潜店",
  "connections_kind_equipment": "装备",
  "connections_kind_species": "物种",
  "connections_kind_tag": "标签",
  "connections_kind_diveType": "潜水类型",
  "connections_kind_diveComputer": "潜水电脑",
  "connections_kind_course": "课程",
```

**ar** (word forms in `=1`, no interpolation)
```json
  "nav_connections": "الروابط",
  "connections_title": "الروابط",
  "connections_lens_circle": "دائرة الغوص",
  "connections_lens_where": "من يغوص أين",
  "connections_tooltip_filter": "تصفية الروابط",
  "connections_tooltip_relayout": "إعادة الترتيب",
  "connections_filterBar_nodes": "{count, plural, =1{عقدة واحدة} other{{count} عقدة}}",
  "connections_filterBar_edges": "{count, plural, =1{رابط واحد} other{{count} رابطًا}}",
  "connections_filterBar_clear": "مسح التصفية",
  "connections_hiddenNodes": "{count, plural, =1{عقدة أخرى غير معروضة} other{{count} عقدة أخرى غير معروضة}}",
  "connections_showAll": "عرض الكل",
  "connections_showAll_confirmTitle": "عرض كل العقد؟",
  "connections_showAll_confirmBody": "قد يستغرق ترتيب {count} عقدة لحظة على هذا الجهاز.",
  "connections_action_open": "فتح",
  "connections_action_focus": "تركيز",
  "connections_action_showDives": "عرض الغوصات",
  "connections_action_openInConnections": "فتح في الروابط",
  "connections_selection_divesTogether": "{count, plural, =1{غوصة واحدة معًا} other{{count} غوصة معًا}}",
  "connections_selection_dives": "{count, plural, =1{غوصة واحدة} other{{count} غوصة}}",
  "connections_selection_topConnections": "أقوى الروابط",
  "connections_selection_firstLast": "الأولى {first}، الأخيرة {last}",
  "connections_selection_hint": "انقر على عقدة أو خط لعرض التفاصيل.",
  "connections_empty_noDives": "لا توجد غوصات بعد. تظهر الروابط عندما يحتوي السجل على غوصات.",
  "connections_empty_buddies": "لا يوجد رفقاء مرتبطون بالغوصات بعد. أضف رفقاء إلى غوصاتك أو حوّل أسماء الرفقاء القديمة من الإعدادات، أدوات البيانات.",
  "connections_empty_sites": "لا توجد غوصة لها موقع بعد.",
  "connections_focusMissing": "هذا العنصر لم يعد موجودًا في السجل.",
  "connections_error_load": "تعذر تحميل الروابط.",
  "connections_legend_title": "مفتاح الرسم",
  "connections_yearRange_label": "الأعوام من {first} إلى {last}",
  "connections_semantics_summary": "{nodes} عقدة و{edges} رابطًا",
  "connections_kind_buddy": "الرفقاء",
  "connections_kind_site": "المواقع",
  "connections_kind_trip": "الرحلات",
  "connections_kind_diveCenter": "مراكز الغوص",
  "connections_kind_equipment": "المعدات",
  "connections_kind_species": "الأنواع",
  "connections_kind_tag": "الوسوم",
  "connections_kind_diveType": "أنواع الغوص",
  "connections_kind_diveComputer": "كمبيوترات الغوص",
  "connections_kind_course": "الدورات",
```

**he** (word forms in `=1`, no interpolation)
```json
  "nav_connections": "קשרים",
  "connections_title": "קשרים",
  "connections_lens_circle": "מעגל הצלילה",
  "connections_lens_where": "מי צולל איפה",
  "connections_tooltip_filter": "סינון קשרים",
  "connections_tooltip_relayout": "סידור מחדש",
  "connections_filterBar_nodes": "{count, plural, =1{צומת אחד} other{{count} צמתים}}",
  "connections_filterBar_edges": "{count, plural, =1{קשר אחד} other{{count} קשרים}}",
  "connections_filterBar_clear": "ניקוי סינון",
  "connections_hiddenNodes": "{count, plural, =1{אחד נוסף לא מוצג} other{{count} נוספים לא מוצגים}}",
  "connections_showAll": "הצגת הכול",
  "connections_showAll_confirmTitle": "להציג את כל הצמתים?",
  "connections_showAll_confirmBody": "סידור {count} צמתים עשוי להימשך רגע במכשיר זה.",
  "connections_action_open": "פתיחה",
  "connections_action_focus": "מיקוד",
  "connections_action_showDives": "הצגת צלילות",
  "connections_action_openInConnections": "פתיחה בקשרים",
  "connections_selection_divesTogether": "{count, plural, =1{צלילה אחת יחד} other{{count} צלילות יחד}}",
  "connections_selection_dives": "{count, plural, =1{צלילה אחת} other{{count} צלילות}}",
  "connections_selection_topConnections": "קשרים מובילים",
  "connections_selection_firstLast": "ראשונה {first}, אחרונה {last}",
  "connections_selection_hint": "הקישו על צומת או על קו לפרטים.",
  "connections_empty_noDives": "אין עדיין צלילות. הקשרים יופיעו כשביומן יהיו צלילות.",
  "connections_empty_buddies": "אין עדיין שותפים המקושרים לצלילות. הוסיפו שותפים לצלילות או המירו שמות שותפים ישנים בהגדרות, כלי נתונים.",
  "connections_empty_sites": "לאף צלילה אין עדיין אתר.",
  "connections_focusMissing": "הפריט הזה כבר אינו ביומן.",
  "connections_error_load": "לא ניתן לטעון את הקשרים.",
  "connections_legend_title": "מקרא",
  "connections_yearRange_label": "השנים {first} עד {last}",
  "connections_semantics_summary": "{nodes} צמתים ו-{edges} קשרים",
  "connections_kind_buddy": "שותפים",
  "connections_kind_site": "אתרים",
  "connections_kind_trip": "טיולים",
  "connections_kind_diveCenter": "מרכזי צלילה",
  "connections_kind_equipment": "ציוד",
  "connections_kind_species": "מינים",
  "connections_kind_tag": "תגיות",
  "connections_kind_diveType": "סוגי צלילה",
  "connections_kind_diveComputer": "מחשבי צלילה",
  "connections_kind_course": "קורסים",
```

Each locale block also carries the same `@connections_*` metadata entries as English (copy them verbatim beneath each plural or placeholder key).

- [ ] **Step 3: Regenerate and run the l10n guards**

```bash
flutter gen-l10n
flutter test test/l10n/
```

Expected: PASS, including `arb_parity_test`, `plural_zero_count_test` and `plural_singular_interpolates_argument_test`. If a JSON error appears, the usual cause is a missing comma at the insertion boundary.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(connections): localisation keys for the Connections page"
```

---

### Task 15: Destination, accent colour and route

**Files:**
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (insert after the `statistics` entry)
- Modify: `lib/core/theme/feature_accent_colors.dart` (both palettes)
- Modify: `lib/core/router/app_router.dart` (new section root after the `/statistics` route)
- Create: `lib/features/connections/presentation/pages/connections_page.dart` (a placeholder `Scaffold` in this task; Task 18 fills it)
- Modify: `test/shared/widgets/nav/nav_destinations_test.dart` (17 to 18, 15 to 16)
- Modify: `test/core/router/app_router_test.dart` (route exists, resolves with query parameters)

**Interfaces:**
- Produces: nav id `connections`, route `/connections` named `connections`, `ConnectionsPage({lensId, kindAName, kindBName, focusWire})` constructed from `state.uri.queryParameters['lens']`, `['a']`, `['b']`, `['focus']`; accent key `connections`.

- [ ] **Step 1: Update the tests first**

In `test/shared/widgets/nav/nav_destinations_test.dart` change `'has exactly 17 entries (16 routable + more sentinel)'` to 18 and 17, and `expect(kNavDestinations.length, 17)` to 18; change `'has exactly 15 entries'` to 16 and `expect(movableNavIds.length, 15)` to 16. Add:

```dart
    test('connections is routable and movable', () {
      final d = kNavDestinations.singleWhere((d) => d.id == 'connections');
      expect(d.route, '/connections');
      expect(d.isPinned, isFalse);
      expect(movableNavIds, contains('connections'));
    });
```

In `test/core/router/app_router_test.dart` add, inside the existing `group` that inspects routes (use the same `router` or `routes` variable the neighbouring tests use):

```dart
    test('connections is a named section root that accepts query params', () {
      expect(_findRouteByName(routes, 'connections'), isNotNull);
      expect(_locationOfRoute(routes, 'connections'), '/connections');
      final match = router.configuration.findMatch(
        Uri.parse('/connections?lens=circle&focus=buddy:abc'),
      );
      expect(match.matches, isNotEmpty);
    });
```

Run: `flutter test test/shared/widgets/nav/nav_destinations_test.dart test/core/router/app_router_test.dart test/core/theme/feature_accent_colors_test.dart`
Expected: FAIL on the new assertions.

- [ ] **Step 2: Add the destination**

In `nav_destinations.dart`, after the `statistics` entry:

```dart
  NavDestination(
    id: 'connections',
    route: '/connections',
    icon: Icons.hub_outlined,
    selectedIcon: Icons.hub,
    label: (l10n) => l10n.nav_connections,
  ),
```

- [ ] **Step 3: Add the accent colours**

In `feature_accent_colors.dart`, in the light map after `'statistics'`: `'connections': Color(0xFF00838F),` and in the dark map after its `'statistics'` entry: `'connections': Color(0xFF4DD0E1),`. Both clear the 3:1 contrast checks in `feature_accent_colors_test.dart`; if the dark check fails, use `0xFF26C6DA`.

- [ ] **Step 4: Add the route and a placeholder page**

`connections_page.dart` (placeholder, replaced in Task 18):

```dart
import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({
    super.key,
    this.lensId,
    this.kindAName,
    this.kindBName,
    this.focusWire,
  });

  final String? lensId;
  final String? kindAName;
  final String? kindBName;
  final String? focusWire;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.connections_title)),
      body: const SizedBox.shrink(),
    );
  }
}
```

In `app_router.dart`, after the `/statistics` `GoRoute` closes (line 914 area), inside the same `ShellRoute` route list:

```dart
          // Connections
          GoRoute(
            path: '/connections',
            name: 'connections',
            pageBuilder: (context, state) {
              final q = state.uri.queryParameters;
              return NoTransitionPage(
                key: state.pageKey,
                child: ConnectionsPage(
                  lensId: q['lens'],
                  kindAName: q['a'],
                  kindBName: q['b'],
                  focusWire: q['focus'],
                ),
              );
            },
          ),
```

with the import `package:submersion/features/connections/presentation/pages/connections_page.dart`.

- [ ] **Step 5: Run the tests**

```bash
flutter test test/shared/widgets/nav/ test/core/router/app_router_test.dart test/core/theme/ test/features/settings/presentation/pages/nav_customization_page_test.dart test/shared/widgets/main_scaffold_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/shared/widgets/nav/nav_destinations.dart lib/core/theme/feature_accent_colors.dart lib/core/router/app_router.dart lib/features/connections/presentation/pages/connections_page.dart test/shared/widgets/nav/nav_destinations_test.dart test/core/router/app_router_test.dart
git commit -m "feat(connections): Connections destination, accent colour and route"
```

---

### Task 16: Selection details, bottom card and side panel

**Files:**
- Create: `lib/features/connections/presentation/widgets/selection_details.dart`
- Create: `lib/features/connections/presentation/widgets/selection_card.dart`
- Create: `lib/features/connections/presentation/widgets/selection_panel.dart`
- Test: `test/features/connections/presentation/widgets/selection_details_test.dart`

**Interfaces:**
- Consumes: `ConnectionGraph`, `GraphSelection`, `NodeSubtitle`, `connectionsSelectionDiveIdsProvider`, `connectionsFocusProvider`, `connectionsSelectionProvider`, `diveFilterProvider` (dive list), `diveRoleMapProvider` from `lib/features/dive_roles/presentation/providers/dive_role_providers.dart`, `UnitFormatter` + `settingsProvider`.
- Produces: `SelectionDetails({required graph, required selection})` (a `ConsumerWidget` with the three actions wired); `SelectionCard({required graph, required selection, required onClose})` for compact width; `SelectionPanel({required graph, selection, required children})` for wide width (`children` are the lens row, filter bar, year slider and legend the page passes in; the selection details or the hint text render underneath).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_details.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 3, subtitle: const RoleSubtitle('instructor')),
    ConnectionNode(ref: _b('ken'), label: 'Ken', diveCount: 2),
    ConnectionNode(ref: _b('newbie'), label: 'Newbie', diveCount: 0),
  ],
  edges: [
    ConnectionEdge(source: _b('jane'), target: _b('ken'), weight: 2, firstDiveAt: DateTime.utc(2024, 1, 10), lastDiveAt: DateTime.utc(2024, 3, 5)),
  ],
);

Future<(ProviderContainer, GoRouter)> _pump(
  WidgetTester tester,
  GraphSelection selection, {
  List<String> diveIds = const ['d1', 'd2'],
}) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    initialLocation: '/connections',
    routes: [
      GoRoute(
        path: '/connections',
        builder: (_, _) => Scaffold(body: SelectionDetails(graph: _graph, selection: selection)),
      ),
      GoRoute(path: '/dives', builder: (_, _) => const Scaffold(body: Text('DIVE_LIST'))),
      GoRoute(path: '/buddies/:id', builder: (_, s) => Scaffold(body: Text('BUDDY_${s.pathParameters['id']}'))),
    ],
  );
  final scope = ProviderScope(
    overrides: [
      ...overrides,
      connectionsSelectionDiveIdsProvider(selection).overrideWith((ref) async => diveIds),
      diveRoleMapProvider.overrideWith((ref) async => {
        'instructor': const DiveRole(id: 'instructor', name: 'Instructor', isBuiltIn: true),
      }),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pumpWidget(scope);
  await tester.pumpAndSettle();
  final element = tester.element(find.byType(SelectionDetails));
  return (ProviderScope.containerOf(element), router);
}

void main() {
  testWidgets('a node shows label, role subtitle, dive count and top connections', (tester) async {
    await _pump(tester, NodeSelection(_b('jane')));
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('Instructor'), findsOneWidget);
    expect(find.text('3 dives'), findsOneWidget);
    expect(find.text('Top connections'), findsOneWidget);
    expect(find.textContaining('Ken'), findsOneWidget);
  });

  testWidgets('Show dives sets the dive list filter and navigates', (tester) async {
    final (container, _) = await _pump(tester, NodeSelection(_b('jane')));
    await tester.tap(find.text('Show dives'));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider).diveIds, ['d1', 'd2']);
    expect(find.text('DIVE_LIST'), findsOneWidget);
  });

  testWidgets('Show dives is disabled when the selection has no dives', (tester) async {
    await _pump(tester, NodeSelection(_b('newbie')), diveIds: const []);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Show dives'));
    expect(button.onPressed, isNull);
  });

  testWidgets('Open pushes the detail route and Focus sets the focus', (tester) async {
    final (container, _) = await _pump(tester, NodeSelection(_b('jane')));
    await tester.tap(find.text('Focus'));
    await tester.pump();
    expect(container.read(connectionsFocusProvider), _b('jane'));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('BUDDY_jane'), findsOneWidget);
  });

  testWidgets('an edge shows both names, dives together and first/last dates', (tester) async {
    await _pump(tester, EdgeSelection(_b('jane'), _b('ken')));
    expect(find.textContaining('Jane'), findsWidgets);
    expect(find.textContaining('Ken'), findsWidgets);
    expect(find.text('2 dives together'), findsOneWidget);
    expect(find.textContaining('First '), findsOneWidget);
    expect(find.text('Focus'), findsNothing);
  });
}
```

`DiveRole`'s constructor: check `lib/features/dive_roles/domain/entities/dive_role.dart` line 15 onward for the exact required parameters and adjust the override literal to match (id, name and isBuiltIn are the fields seen at lines 9 to 19).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/widgets/selection_details_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the widgets**

`selection_details.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Body shared by the compact bottom card and the wide side panel.
class SelectionDetails extends ConsumerWidget {
  const SelectionDetails({super.key, required this.graph, required this.selection});

  final ConnectionGraph graph;
  final GraphSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final roles = ref.watch(diveRoleMapProvider).value;
    final ids = ref.watch(connectionsSelectionDiveIdsProvider(selection)).value ?? const <String>[];

    String? subtitleOf(NodeSubtitle? s) => switch (s) {
      null => null,
      TextSubtitle(:final text) => text,
      DateRangeSubtitle(:final start, :final end) => units.formatDateRange(start, end, l10n: l10n),
      RoleSubtitle(:final roleId) => roles?[roleId]?.name,
    };

    final String title;
    final String? subtitle;
    final String countText;
    final NodeRef? focusRef;
    final String? openRoute;
    final List<Widget> connections;

    switch (selection) {
      case NodeSelection(:final ref):
        final node = graph.nodeFor(ref);
        title = node?.label ?? ref.id;
        subtitle = subtitleOf(node?.subtitle);
        countText = l10n.connections_selection_dives(node?.diveCount ?? 0);
        focusRef = ref;
        openRoute = ref.kind.detailRoute(ref.id);
        final top = graph.edgesOf(ref)..sort((a, b) => b.weight.compareTo(a.weight));
        connections = [
          for (final e in top.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(graph.nodeFor(e.otherEnd(ref)!)?.label ?? e.otherEnd(ref)!.id),
              trailing: Text(l10n.connections_selection_divesTogether(e.weight)),
            ),
        ];
      case EdgeSelection(:final a, :final b):
        final edge = graph.edges.where((e) => e.touches(a) && e.touches(b)).firstOrNull;
        title = '${graph.nodeFor(a)?.label ?? a.id}  &  ${graph.nodeFor(b)?.label ?? b.id}';
        subtitle = edge == null
            ? null
            : l10n.connections_selection_firstLast(
                units.formatDate(edge.firstDiveAt),
                units.formatDate(edge.lastDiveAt),
              );
        countText = l10n.connections_selection_divesTogether(edge?.weight ?? 0);
        focusRef = null;
        openRoute = null;
        connections = const [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null)
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(countText, style: theme.textTheme.bodyMedium),
        if (connections.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l10n.connections_selection_topConnections, style: theme.textTheme.labelLarge),
          ...connections,
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (openRoute != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.connections_action_open),
                onPressed: () => context.push(openRoute!),
              ),
            if (focusRef != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.center_focus_strong),
                label: Text(l10n.connections_action_focus),
                onPressed: () {
                  ref.read(connectionsFocusProvider.notifier).state = focusRef;
                  ref.read(connectionsSelectionProvider.notifier).state = NodeSelection(focusRef!);
                },
              ),
            FilledButton.icon(
              icon: const Icon(Icons.list),
              label: Text(l10n.connections_action_showDives),
              onPressed: ids.isEmpty
                  ? null
                  : () {
                      ref.read(diveFilterProvider.notifier).state = DiveFilterState(diveIds: ids);
                      context.go('/dives');
                    },
            ),
          ],
        ),
      ],
    );
  }
}
```

The import block at the top of the file is the one shown above the class. `firstOrNull` comes from `package:collection` (already a dependency) or Dart 3's `Iterable` extension; import `package:collection/collection.dart` if the analyzer asks.

`selection_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'selection_details.dart';

/// Compact-width selection surface: a bottom-anchored card capped at 40% of
/// the height, scrolling inside. Not a DraggableScrollableSheet, which a
/// mouse cannot resize.
class SelectionCard extends StatelessWidget {
  const SelectionCard({super.key, required this.graph, required this.selection, required this.onClose});

  final ConnectionGraph graph;
  final GraphSelection selection;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.4;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        key: const ValueKey('connections-selection-card'),
        margin: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.common_action_close,
                    onPressed: onClose,
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectionDetails(graph: graph, selection: selection),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`selection_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'selection_details.dart';

/// Wide-width side panel: lens, filter, year range and legend above, the
/// selection (or a hint) below.
class SelectionPanel extends StatelessWidget {
  const SelectionPanel({super.key, required this.graph, required this.children, this.selection});

  static const double width = 320;

  final ConnectionGraph graph;
  final GraphSelection? selection;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('connections-selection-panel'),
      width: width,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...children,
          const Divider(height: 32),
          if (selection != null)
            SelectionDetails(graph: graph, selection: selection!)
          else
            Text(
              context.l10n.connections_selection_hint,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/connections/presentation/widgets/selection_details_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/widgets test/features/connections/presentation/widgets
git commit -m "feat(connections): selection details, bottom card and side panel"
```

---

### Task 17: Lens chips, filter action and bar, year range slider

**Files:**
- Create: `lib/features/connections/presentation/widgets/lens_chip_row.dart`
- Create: `lib/features/connections/presentation/widgets/connections_filter_action.dart`
- Create: `lib/features/connections/presentation/widgets/connections_filter_bar.dart`
- Create: `lib/features/connections/presentation/widgets/year_range_slider.dart`
- Test: `test/features/connections/presentation/widgets/lens_and_filter_widgets_test.dart`

**Interfaces:**
- Consumes: `connectionsLensProvider`, `connectionsFilterProvider`, `connectionsFocusProvider`, `connectionsSelectionProvider`, `connectionsYearSpanProvider`, `DiveFilterSheet` from `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart`.
- Produces: `LensChipRow()`; `ConnectionsFilterAction()`; `ConnectionsFilterBar({required AsyncValue<ConnectionGraph> graph})`; `YearRangeSlider()`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_filter_bar.dart';
import 'package:submersion/features/connections/presentation/widgets/lens_chip_row.dart';
import 'package:submersion/features/connections/presentation/widgets/year_range_slider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  ({int first, int last})? span = (first: 2019, last: 2024),
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionsYearSpanProvider.overrideWith((ref) async => span),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('lens chips switch the lens and clear focus and selection', (tester) async {
    final c = await _pump(tester, const LensChipRow());
    c.read(connectionsFocusProvider.notifier).state = const NodeRef(ConnectionKind.buddy, 'x');
    c.read(connectionsSelectionProvider.notifier).state = const NodeSelection(NodeRef(ConnectionKind.buddy, 'x'));
    expect(find.text('Dive circle'), findsOneWidget);
    await tester.tap(find.text('Who dives where'));
    await tester.pump();
    expect(c.read(connectionsLensProvider).lensId, 'where');
    expect(c.read(connectionsFocusProvider), isNull);
    expect(c.read(connectionsSelectionProvider), isNull);
  });

  testWidgets('the filter bar is hidden without a filter and clears with one', (tester) async {
    final c = await _pump(
      tester,
      Consumer(builder: (context, ref, _) {
        ref.watch(connectionsFilterProvider);
        return ConnectionsFilterBar(
          graph: AsyncValue.data(ConnectionGraph.empty.copyWith(hiddenNodeCount: 0)),
        );
      }),
    );
    expect(find.byKey(const ValueKey('connections-filter-bar')), findsNothing);
    c.read(connectionsFilterProvider.notifier).state = const DiveFilterState(siteId: 's1');
    await tester.pump();
    expect(find.byKey(const ValueKey('connections-filter-bar')), findsOneWidget);
    expect(find.text('0 nodes, 0 connections'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear filter'));
    await tester.pump();
    expect(c.read(connectionsFilterProvider).hasActiveFilters, isFalse);
  });

  testWidgets('the year slider writes the date range into the filter', (tester) async {
    final c = await _pump(tester, const YearRangeSlider());
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Years 2019 to 2024'), findsOneWidget);
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    slider.onChangeEnd!(const RangeValues(2021, 2023));
    await tester.pump();
    final f = c.read(connectionsFilterProvider);
    expect(f.startDate, DateTime(2021, 1, 1));
    expect(f.endDate, DateTime(2023, 12, 31));
    expect(find.text('Years 2021 to 2023'), findsOneWidget);
  });

  testWidgets('the year slider hides on a one-year log or no dives', (tester) async {
    await _pump(tester, const YearRangeSlider(), span: (first: 2024, last: 2024));
    expect(find.byType(RangeSlider), findsNothing);
    await _pump(tester, const YearRangeSlider(), span: null);
    expect(find.byType(RangeSlider), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/widgets/lens_and_filter_widgets_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the widgets**

`lens_chip_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

String lensLabel(AppLocalizations l10n, ConnectionLens lens) => switch (lens.id) {
  'circle' => l10n.connections_lens_circle,
  'where' => l10n.connections_lens_where,
  _ => lens.id,
};

class LensChipRow extends ConsumerWidget {
  const LensChipRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(connectionsLensProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          for (final lens in ConnectionLens.phase1)
            ChoiceChip(
              label: Text(lensLabel(context.l10n, lens)),
              selected: active.lensId == lens.id,
              onSelected: (_) {
                ref.read(connectionsFocusProvider.notifier).state = null;
                ref.read(connectionsSelectionProvider.notifier).state = null;
                ref.read(connectionsLensProvider.notifier).select(LensSelection.lens(lens));
              },
            ),
        ],
      ),
    );
  }
}
```

`connections_filter_action.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App bar action opening the shared filter sheet bound to the connections
/// filter, badged while a filter is set. Mirrors StatisticsFilterAction.
class ConnectionsFilterAction extends ConsumerWidget {
  const ConnectionsFilterAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('connections-filter-action'),
      icon: Badge(
        isLabelVisible: ref.watch(connectionsFilterProvider).hasActiveFilters,
        child: const Icon(Icons.filter_list),
      ),
      tooltip: context.l10n.connections_tooltip_filter,
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DiveFilterSheet(ref: ref, filterProvider: connectionsFilterProvider),
      ),
    );
  }
}
```

`connections_filter_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown only while a filter is active: what is in view, and a clear button.
class ConnectionsFilterBar extends ConsumerWidget {
  const ConnectionsFilterBar({super.key, required this.graph});

  final AsyncValue<ConnectionGraph> graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(connectionsFilterProvider);
    if (!filter.hasActiveFilters) return const SizedBox.shrink();
    final l10n = context.l10n;
    final g = graph.value;
    final summary = g == null
        ? ''
        : '${l10n.connections_filterBar_nodes(g.nodes.length)}, '
            '${l10n.connections_filterBar_edges(g.edges.length)}';
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('connections-filter-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(summary, style: theme.textTheme.bodyMedium)),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.connections_filterBar_clear,
            onPressed: () => ref.read(connectionsFilterProvider.notifier).state = const DiveFilterState(),
          ),
        ],
      ),
    );
  }
}
```

`year_range_slider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// First-to-last dive year of the log; dragging writes a whole-year date
/// range into the connections filter, so it shows and clears like any axis.
class YearRangeSlider extends ConsumerWidget {
  const YearRangeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final span = ref.watch(connectionsYearSpanProvider).value;
    if (span == null || span.first >= span.last) return const SizedBox.shrink();
    final filter = ref.watch(connectionsFilterProvider);
    final lo = (filter.startDate?.year ?? span.first).clamp(span.first, span.last);
    final hi = (filter.endDate?.year ?? span.last).clamp(span.first, span.last);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.connections_yearRange_label(lo, hi), style: Theme.of(context).textTheme.labelMedium),
          RangeSlider(
            min: span.first.toDouble(),
            max: span.last.toDouble(),
            divisions: span.last - span.first,
            values: RangeValues(lo.toDouble(), hi.toDouble()),
            labels: RangeLabels('$lo', '$hi'),
            onChanged: (_) {},
            onChangeEnd: (v) {
              final start = DateTime(v.start.round(), 1, 1);
              final end = DateTime(v.end.round(), 12, 31);
              ref.read(connectionsFilterProvider.notifier).state = filter.copyWith(startDate: start, endDate: end);
            },
          ),
        ],
      ),
    );
  }
}
```

`RangeSlider` needs a non-null `onChanged` to be enabled; the value is driven from the provider, so `onChanged` only keeps it interactive and `onChangeEnd` commits. If the slider feels stuck while dragging on a device, hold the in-progress values in a small `StatefulWidget` wrapper; the test only exercises `onChangeEnd`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/connections/presentation/widgets/lens_and_filter_widgets_test.dart`
Expected: PASS. `copyWith(startDate:, endDate:)` exists on `DiveFilterState` (line 189).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/widgets test/features/connections/presentation/widgets
git commit -m "feat(connections): lens chips, filter action and bar, year range slider"
```

---

### Task 18: Legend, hidden-count chip, empty state and the page

**Files:**
- Create: `lib/features/connections/presentation/widgets/connections_legend.dart`
- Create: `lib/features/connections/presentation/widgets/hidden_nodes_chip.dart`
- Create: `lib/features/connections/presentation/widgets/connections_empty_state.dart`
- Modify: `lib/features/connections/presentation/pages/connections_page.dart` (replace the Task 15 placeholder)
- Test: `test/features/connections/presentation/pages/connections_page_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 5, 10, 12, 13, 16, 17; `ResponsiveBreakpoints.masterDetail` (1100) from `lib/shared/widgets/master_detail/responsive_breakpoints.dart`; `common_action_retry`.
- Produces: `ConnectionsLegend({required kinds, required colors})`; `HiddenNodesChip({required count, required onShowAll})`; `ConnectionsEmptyState({required lens})`; `ConnectionsPage` with the constructor from Task 15, `kindLabel(l10n, kind)`.
- Behaviour: on first build, apply `lensId` (or a custom `a`/`b` pair) to `connectionsLensProvider` and `focusWire` to `connectionsFocusProvider` when the focus kind belongs to the lens; otherwise leave the focus null and show `connections_focusMissing` in a snackbar after the first frame. A `FocusNotFoundException` from the graph provider clears the focus and shows the same snackbar. Budget is 80 below `ResponsiveBreakpoints.masterDetail`, 160 at or above; "show all" raises it to 400 after a confirmation dialog.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 3),
    ConnectionNode(ref: _b('ken'), label: 'Ken', diveCount: 2),
  ],
  edges: [
    ConnectionEdge(source: _b('jane'), target: _b('ken'), weight: 2, firstDiveAt: DateTime.utc(2024), lastDiveAt: DateTime.utc(2024)),
  ],
  hiddenNodeCount: 3,
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  ConnectionGraph? graph,
  Object? error,
  String location = '/connections',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/connections',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return ConnectionsPage(lensId: q['lens'], kindAName: q['a'], kindBName: q['b'], focusWire: q['focus']);
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionGraphProvider.overrideWith((ref, budget) async {
          if (error != null) throw error;
          return graph ?? _graph;
        }),
        connectionsYearSpanProvider.overrideWith((ref) async => (first: 2019, last: 2024)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ProviderScope.containerOf(tester.element(find.byType(ConnectionsPage)));
}

void main() {
  testWidgets('phone layout: chips, canvas, legend, hidden chip; no side panel', (tester) async {
    await _pump(tester, size: const Size(732, 1000));
    expect(find.text('Dive circle'), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-canvas-paint')), findsOneWidget);
    expect(find.text('Legend'), findsNothing, reason: 'compact legend is icon-only');
    expect(find.text('3 more not shown'), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-selection-panel')), findsNothing);
  });

  testWidgets('wide layout shows the side panel with the hint', (tester) async {
    await _pump(tester, size: const Size(1200, 800));
    expect(find.byKey(const ValueKey('connections-selection-panel')), findsOneWidget);
    expect(find.text('Tap a node or a line to see details.'), findsOneWidget);
  });

  testWidgets('a deep link applies the lens and focus', (tester) async {
    final c = await _pump(tester, size: const Size(732, 1000), location: '/connections?lens=where&focus=buddy:jane');
    expect(c.read(connectionsLensProvider).lensId, 'where');
    expect(c.read(connectionsFocusProvider), _b('jane'));
    expect(c.read(connectionsSelectionProvider)?.toString(), contains('jane'));
  });

  testWidgets('a focus outside the lens opens unfocused with a snackbar', (tester) async {
    final c = await _pump(tester, size: const Size(732, 1000), location: '/connections?lens=circle&focus=site:s1');
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsFocusProvider), isNull);
    expect(find.text('That item is no longer in the log.'), findsOneWidget);
  });

  testWidgets('a missing focus clears and warns', (tester) async {
    final c = await _pump(
      tester,
      size: const Size(732, 1000),
      location: '/connections?lens=circle&focus=buddy:ghost',
      error: const FocusNotFoundException(NodeRef(ConnectionKind.buddy, 'ghost')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsFocusProvider), isNull);
    expect(find.text('That item is no longer in the log.'), findsOneWidget);
  });

  testWidgets('an empty buddy lens points at Data Tools', (tester) async {
    await _pump(tester, size: const Size(732, 1000), graph: ConnectionGraph.empty);
    expect(find.textContaining('Data Tools'), findsOneWidget);
  });

  testWidgets('a load error shows retry', (tester) async {
    await _pump(tester, size: const Size(732, 1000), error: StateError('boom'));
    expect(find.text('Could not load connections.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/pages/connections_page_test.dart`
Expected: FAIL (placeholder page has none of this).

- [ ] **Step 3: Write the small widgets**

`connections_legend.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

String kindLabel(AppLocalizations l10n, ConnectionKind kind) => switch (kind) {
  ConnectionKind.buddy => l10n.connections_kind_buddy,
  ConnectionKind.site => l10n.connections_kind_site,
  ConnectionKind.trip => l10n.connections_kind_trip,
  ConnectionKind.diveCenter => l10n.connections_kind_diveCenter,
  ConnectionKind.equipment => l10n.connections_kind_equipment,
  ConnectionKind.species => l10n.connections_kind_species,
  ConnectionKind.tag => l10n.connections_kind_tag,
  ConnectionKind.diveType => l10n.connections_kind_diveType,
  ConnectionKind.diveComputer => l10n.connections_kind_diveComputer,
  ConnectionKind.course => l10n.connections_kind_course,
};

/// One swatch per kind in view. [showTitle] is false on the compact overlay.
class ConnectionsLegend extends StatelessWidget {
  const ConnectionsLegend({super.key, required this.kinds, required this.colors, this.showTitle = true});

  final Set<ConnectionKind> kinds;
  final ConnectionKindColors colors;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle) Text(context.l10n.connections_legend_title, style: theme.textTheme.labelLarge),
        for (final k in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: colors.colorFor(k), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(kindLabel(context.l10n, k), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}
```

`hidden_nodes_chip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "N more not shown", tapping offers to raise the budget.
class HiddenNodesChip extends StatelessWidget {
  const HiddenNodesChip({super.key, required this.count, required this.onShowAll});

  final int count;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return ActionChip(
      key: const ValueKey('connections-hidden-chip'),
      avatar: const Icon(Icons.more_horiz, size: 18),
      label: Text(context.l10n.connections_hiddenNodes(count)),
      onPressed: onShowAll,
    );
  }
}
```

`connections_empty_state.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Names the data that feeds the lens, so an empty canvas is never a mystery.
class ConnectionsEmptyState extends StatelessWidget {
  const ConnectionsEmptyState({super.key, required this.lens, required this.hasAnyDives});

  final LensSelection lens;
  final bool hasAnyDives;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = !hasAnyDives
        ? l10n.connections_empty_noDives
        : (lens.kindA == ConnectionKind.buddy || lens.kindB == ConnectionKind.buddy)
            ? l10n.connections_empty_buddies
            : l10n.connections_empty_sites;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write the page**

Replace `connections_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_empty_state.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_filter_action.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_filter_bar.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/features/connections/presentation/widgets/lens_chip_row.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_card.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_panel.dart';
import 'package:submersion/features/connections/presentation/widgets/year_range_slider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key, this.lensId, this.kindAName, this.kindBName, this.focusWire});

  final String? lensId;
  final String? kindAName;
  final String? kindBName;
  final String? focusWire;

  static const compactBudget = 80;
  static const wideBudget = 160;
  static const maxBudget = 400;

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> with SingleTickerProviderStateMixin {
  late final ConnectionsLayoutController _layout = ConnectionsLayoutController(vsync: this);
  int? _budgetOverride;
  ConnectionGraph? _laidOut;
  bool _focusWarned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyDeepLink());
  }

  void _applyDeepLink() {
    if (!mounted) return;
    final lensNotifier = ref.read(connectionsLensProvider.notifier);
    final lens = ConnectionLens.byId(widget.lensId);
    final a = ConnectionKind.fromName(widget.kindAName);
    final b = ConnectionKind.fromName(widget.kindBName);
    if (lens != null) {
      lensNotifier.select(LensSelection.lens(lens));
    } else if (a != null && b != null) {
      lensNotifier.select(LensSelection.custom(kindA: a, kindB: b));
    }
    final focus = NodeRef.parse(widget.focusWire);
    if (focus == null) return;
    final active = ref.read(connectionsLensProvider);
    if (focus.kind == active.kindA || focus.kind == active.kindB) {
      ref.read(connectionsFocusProvider.notifier).state = focus;
      ref.read(connectionsSelectionProvider.notifier).state = NodeSelection(focus);
    } else {
      _warnFocusMissing();
    }
  }

  void _warnFocusMissing() {
    if (_focusWarned || !mounted) return;
    _focusWarned = true;
    ref.read(connectionsFocusProvider.notifier).state = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.connections_focusMissing)));
  }

  @override
  void dispose() {
    _layout.dispose();
    super.dispose();
  }

  void _syncLayout(ConnectionGraph graph, NodeRef? focus) {
    if (identical(_laidOut, graph)) return;
    _laidOut = graph;
    _layout.setGraph(
      graph,
      mode: focus == null ? GraphLayoutMode.web : GraphLayoutMode.ego,
      focus: focus,
    );
  }

  Future<void> _showAll(int total) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.connections_showAll_confirmTitle),
        content: Text(l10n.connections_showAll_confirmBody(total)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.common_action_cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.connections_showAll)),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _budgetOverride = ConnectionsPage.maxBudget);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= ResponsiveBreakpoints.masterDetail;
    final budget = _budgetOverride ?? (wide ? ConnectionsPage.wideBudget : ConnectionsPage.compactBudget);
    final graphAsync = ref.watch(connectionGraphProvider(budget));
    final focus = ref.watch(connectionsFocusProvider);
    final selection = ref.watch(connectionsSelectionProvider);
    final lens = ref.watch(connectionsLensProvider);
    final colors = ConnectionKindColors.of(context);

    ref.listen(connectionGraphProvider(budget), (_, next) {
      if (next.hasError && next.error is FocusNotFoundException) _warnFocusMissing();
    });

    final body = graphAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => e is FocusNotFoundException
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.connections_error_load),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => ref.invalidate(connectionGraphProvider(budget)),
                    child: Text(l10n.common_action_retry),
                  ),
                ],
              ),
            ),
      data: (graph) {
        _syncLayout(graph, focus);
        if (graph.isEmpty) {
          final span = ref.watch(connectionsYearSpanProvider).value;
          return ConnectionsEmptyState(lens: lens, hasAnyDives: span != null);
        }
        final kinds = graph.nodes.map((n) => n.ref.kind).toSet();
        final canvas = ConnectionsCanvas(
          graph: graph,
          controller: _layout,
          colors: colors,
          selection: selection,
          semanticsLabel: l10n.connections_semantics_summary(graph.nodes.length, graph.edges.length),
          onSelect: (s) => ref.read(connectionsSelectionProvider.notifier).state = s,
          onFocus: (node) {
            ref.read(connectionsFocusProvider.notifier).state = node;
            ref.read(connectionsSelectionProvider.notifier).state = NodeSelection(node);
          },
        );
        final overlay = Stack(
          children: [
            Positioned.fill(child: canvas),
            Positioned(
              left: 12,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ConnectionsLegend(kinds: kinds, colors: colors, showTitle: false),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: HiddenNodesChip(
                count: graph.hiddenNodeCount,
                onShowAll: () => _showAll(graph.nodes.length + graph.hiddenNodeCount),
              ),
            ),
            if (!wide && selection != null)
              SelectionCard(
                graph: graph,
                selection: selection,
                onClose: () => ref.read(connectionsSelectionProvider.notifier).state = null,
              ),
          ],
        );
        if (wide) {
          return Row(
            children: [
              Expanded(child: overlay),
              SelectionPanel(
                graph: graph,
                selection: selection,
                children: [
                  const LensChipRow(),
                  ConnectionsFilterBar(graph: graphAsync),
                  const YearRangeSlider(),
                  const SizedBox(height: 12),
                  ConnectionsLegend(kinds: kinds, colors: colors),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            const LensChipRow(),
            ConnectionsFilterBar(graph: graphAsync),
            const YearRangeSlider(),
            Expanded(child: overlay),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connections_title),
        actions: [
          if (focus != null)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: l10n.connections_tooltip_relayout,
              onPressed: () {
                ref.read(connectionsFocusProvider.notifier).state = null;
                ref.read(connectionsSelectionProvider.notifier).state = null;
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.connections_tooltip_relayout,
              onPressed: _layout.relayout,
            ),
          const ConnectionsFilterAction(),
        ],
      ),
      body: body,
    );
  }
}
```

Notes for the implementer:
- The chip row and year slider render in the body on compact width and inside the panel on wide width, never both.
- `_syncLayout` is called inside `data:` so the controller only sees loaded graphs; `identical` avoids re-laying out on every rebuild.
- The filter bar is passed `graphAsync` so its counts follow the loaded graph.
- When the focus is set, the re-layout button becomes "back to the whole web"; both use the same tooltip key to keep the string count down.
- The empty-state test in Step 1 passes `ConnectionGraph.empty` with a year span present, so the buddy lens message shows.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/connections/`
Expected: PASS across the feature. If the page test's deep-link expectation runs before the post-frame callback, add one more `await tester.pump()` in `_pump`.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections test/features/connections
git commit -m "feat(connections): Connections page with lenses, filters, legend and deep links"
```

---

### Task 19: "Open in Connections" on the buddy detail page

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart:183-215` (the `PopupMenuButton` in the app bar; the second copy around line 283 is the embedded variant and gets the same item)
- Test: `test/features/buddies/presentation/pages/buddy_detail_page_test.dart` (add one test)

**Interfaces:**
- Consumes: route `/connections` (Task 15), `connections_action_openInConnections` (Task 14).

- [ ] **Step 1: Write the failing test**

Add to `buddy_detail_page_test.dart`, following the harness the existing tests use (a `GoRouter` with `/buddies/:id` and `getBaseOverrides()`; add a `/connections` route that renders `Text('CONNECTIONS ${state.uri.query}')`):

```dart
    testWidgets('Open in Connections pushes the ego deep link', (tester) async {
      // Build the router and overrides exactly as 'does not redirect on desktop in table mode' does,
      // adding: GoRoute(path: '/connections', builder: (_, s) => Scaffold(body: Text('CONNECTIONS ${s.uri.query}'))).
      // ...pump with initialLocation '/buddies/${buddy.id}'...
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in Connections'));
      await tester.pumpAndSettle();
      expect(find.text('CONNECTIONS lens=circle&focus=buddy:${buddy.id}'), findsOneWidget);
    });
```

Copy the router and override setup from the neighbouring desktop test verbatim rather than paraphrasing it, so the page renders with the same providers.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/buddies/presentation/pages/buddy_detail_page_test.dart`
Expected: FAIL, no such menu item.

- [ ] **Step 3: Add the menu item**

In both `PopupMenuButton<String>` blocks of `buddy_detail_page.dart`, add before the `share` item:

```dart
              PopupMenuItem(
                value: 'connections',
                child: Row(
                  children: [
                    const Icon(Icons.hub_outlined),
                    const SizedBox(width: 8),
                    Text(context.l10n.connections_action_openInConnections),
                  ],
                ),
              ),
```

and in both `onSelected` handlers:

```dart
              if (value == 'connections') {
                context.push('/connections?lens=circle&focus=buddy:${buddy.id}');
              } else if (value == 'share') {
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/buddies/presentation/pages/buddy_detail_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/buddies test/features/buddies
git add lib/features/buddies/presentation/pages/buddy_detail_page.dart test/features/buddies/presentation/pages/buddy_detail_page_test.dart
git commit -m "feat(connections): open a buddy's ego graph from the buddy detail page"
```

---

### Task 20: Benchmark, guards, format, analyze, full feature run

**Files:**
- Create: `test/features/connections/domain/layout/force_layout_benchmark_test.dart`

- [ ] **Step 1: Write the benchmark test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

void main() {
  test('160 nodes and 600 edges settle in well under a second of CPU', () {
    final nodes = [for (var i = 0; i < 160; i++) NodeRef(ConnectionKind.buddy, 'n$i')];
    final edges = <ConnectionEdge>[];
    for (var i = 0; i < 600; i++) {
      final a = nodes[(i * 7) % 160];
      final b = nodes[(i * 13 + 1) % 160];
      if (a == b) continue;
      edges.add(ConnectionEdge(
        source: a,
        target: b,
        weight: 1 + i % 5,
        firstDiveAt: DateTime.utc(2024),
        lastDiveAt: DateTime.utc(2024),
      ));
    }
    final sw = Stopwatch()..start();
    final layout = WholeWebLayout(nodes: nodes, edges: edges)..advance(300);
    sw.stop();
    expect(layout.settled, isTrue);
    // Loose on purpose: CI machines vary. A regression that doubles the work
    // still shows; a slow shard does not flake.
    expect(sw.elapsedMilliseconds, lessThan(4000), reason: 'layout took ${sw.elapsedMilliseconds} ms');
  });
}
```

Run: `flutter test test/features/connections/domain/layout/force_layout_benchmark_test.dart`
Expected: PASS, typically a few hundred milliseconds.

- [ ] **Step 2: Run every guard the feature touches**

```bash
flutter test test/architecture/ test/core/database/dive_stats_scope_census_test.dart test/shared/widgets/nav/ test/core/theme/ test/core/router/ test/l10n/ test/shared/widgets/app_bar_text_action_adoption_test.dart
```
Expected: PASS. A `provider_change_tick_test` failure names the provider; add the missing `invalidateSelfWhen`. A census failure names the method chunk; make sure `diveScopeSql` is called inside it.

- [ ] **Step 3: Format, analyze, feature suite**

```bash
dart format .
flutter analyze
flutter test test/features/connections/ test/features/buddies/presentation/pages/buddy_detail_page_test.dart
```
Expected: `dart format` changes nothing new, `flutter analyze` reports no issues (infos count as failures in CI), all tests pass.

- [ ] **Step 4: Commit and open the PR**

```bash
git add -A lib/features/connections test/features/connections
git commit -m "test(connections): layout benchmark"
```

PR title: `Connections explorer phase 1: the graph`. Body: a short summary of what the page does, then

```
Closes #2322
Refs #2321
```

plus a manual checklist (open Connections on a phone-width window and a wide window, switch lenses, filter, drag the year slider, tap a node, Show dives, Open, Focus, double-tap, long-press drag, wheel zoom on desktop, Open in Connections from a buddy).

---

## Self-review notes

- **Spec coverage.** Data engine (Tasks 3, 4), domain model and budget (1), repository tick and census (4), providers and filter state (5), force and radial layouts with seeding, pinning, islands, warm start (6 to 9), canvas painting, viewport, hit testing, selection, photos, labels, hover (10 to 13), route and destination and accent (15), lenses and chips (2, 17), filters and year slider (17), selection card and panel with Open, Focus, Show dives (16), legend, hidden count, empty states, deep links, error handling (18), buddy detail deep link (19), l10n (14), benchmark (20). The trimmed-entities sheet behind the hidden chip is phase 2 per the spec; phase 1's chip offers "show all" instead.
- **Deviations from the spec, deliberate.** `StatisticsFilterBar` is not parameterised: it is bound to `filteredDiveStatisticsProvider` for its dive count, so a ten-line `ConnectionsFilterBar` reporting nodes and connections replaces the reuse. Layout positions use `GraphPoint` rather than `dart:ui` `Offset` so the layout layer has no Flutter import; the viewport converts at the boundary.
- **Type consistency.** `NodeRef.wire` / `NodeRef.parse`, `ConnectionGraph.trimmed(budget, keep:)`, `ConnectionsRepository.loadGraph(query, diverId:)`, `connectionGraphProvider(int budget)`, `ConnectionsLayoutController.setGraph(graph, mode:, focus:)`, `GraphViewport.toScreen/toGraph/fitted/zoomedAt/panned/clampedTo`, `ConnectionsHitTester.hitNode/hitEdge`, `ConnectionsPainter(graph:, frame:, viewport:, colors:, labelStyle:, selection:, hovered:, photos:)`, `ConnectionsCanvas(graph:, controller:, colors:, onSelect:, onFocus:, selection:, semanticsLabel:)`, `SelectionDetails(graph:, selection:)`, `SelectionCard(graph:, selection:, onClose:)`, `SelectionPanel(graph:, selection:, children:)`, `ConnectionsFilterBar(graph:)`, `ConnectionsEmptyState(lens:, hasAnyDives:)`, `HiddenNodesChip(count:, onShowAll:)`, `ConnectionsLegend(kinds:, colors:, showTitle:)` are used with these exact names throughout.
