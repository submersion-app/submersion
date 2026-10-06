# Connections Explorer Story (Phase 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the insight strip, highlight modes (kind, groups, recency), year play, and a share image to the Connections explorer.

**Architecture:** Two pure-Dart domain units (`GraphInsights`, `LabelPropagation`) compute the story from the `ConnectionGraph` in view. A `HighlightMode` field on `ConnectionsViewState` drives new painter inputs. Year play is an autoDispose Riverpod `Notifier` that writes the connections filter one year per beat and waits for each load. The share image paints the current layout frame offscreen with `ConnectionsPainter` into a 1080 x 1350 PNG delivered through the existing share/save sheet.

**Tech Stack:** Flutter, Riverpod 3 (`package:submersion/core/providers/provider.dart`, which also exports the legacy `StateProvider`/`StateNotifier`), `dart:ui` `PictureRecorder`, `flutter_test` with `fakeAsync` (from `package:fake_async`, already a transitive test dependency through flutter_test), ARB localisation via `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-05-connections-explorer-story-design.md`

## Global Constraints

- Dates shown to the diver format through `UnitFormatter` (`UnitFormatter(ref.watch(settingsProvider))`), never a bare `DateFormat`.
- Every new user-facing string is an ARB key `connections_*` present in all 11 ARB files (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`). Run `flutter gen-l10n` only after every locale has the translation.
- ARB plural `=1{...}` branches interpolate `{count}` (fr and pt put zero in `one`); ar and he keep their word forms.
- Insert ARB lines textually after an anchor key of the same feature group; never json round-trip an ARB file.
- No em-dashes, en-dashes as punctuation, or `--` as punctuation anywhere (code, comments, ARB values, commits).
- Imports: dart, flutter, packages, then local, all as `package:submersion/...` (the repo lints relative imports).
- Immutability: never mutate a value passed in; build new maps and lists.
- Share image: 360 x 450 logical, pixel ratio 3, background `Color(0xFF0F1E37)`, kind colours from `FeatureAccentColors.dark`.
- Year play beat: 1200 ms, and the next beat waits for the load as well.
- Recency edge factor: 1.0 for the newest `lastDiveAt` in view down to 0.15 for the oldest, linear in time.
- Group palette: 8 colours; groups 8 and later and nodes in no group draw `Color(0xFF9E9E9E)`.
- Label propagation: asynchronous, nodes in `ref.wire` order, ties to the smallest label, at most 20 rounds.
- Commit after each task with `feat(connections): ...` or `test(connections): ...`. No attribution trailers of any kind.

## Deliberate deviations from the spec

- The painter derives the newest and oldest `lastDiveAt` from its graph instead of taking a `newestEdgeAt` input (one less value to keep in sync).
- The share image decodes buddy photos itself at render time instead of borrowing the canvas's private photo cache (the cache stays private to the canvas; decoding a few 96 px photos once per share is cheap).
- Year play's state is `int?` (the year on screen, null when idle) rather than a two-case class; the meaning is the same.

## Review Focus

1. **Year play on a log whose filter already has a start year after the first year:** play must keep that start date and only move the end; at the end it must leave `endDate` at Dec 31 of the last year rather than clearing both dates. Test pinned in Task 8.
2. **The diver drags the year slider or edits a filter while play runs:** play must stop at once and never overwrite the diver's change on the next beat. Test pinned in Task 8.
3. **A graph whose edges all share one `lastDiveAt` in Recency mode:** every edge draws at full strength (no divide by zero, no invisible map). Test pinned in Task 5.
4. **Around mode where the focus has only weight-1 edges:** no Drifting apart tile, and the focus never appears as Most connected. Test pinned in Task 3.
5. **Share when a buddy photo fails to decode or the app icon asset is missing:** the image still renders, with initials and no icon. Test pinned in Task 11.

---

## File map

Create:
- `lib/features/connections/domain/views/highlight_mode.dart`: the enum.
- `lib/features/connections/domain/insights/label_propagation.dart`: `GraphGroups`, `LabelPropagation`.
- `lib/features/connections/domain/insights/graph_insights.dart`: `InsightKind`, `InsightTile`, `GraphInsights`.
- `lib/features/connections/presentation/canvas/connection_group_colors.dart`: palette constants.
- `lib/features/connections/presentation/widgets/highlight_key.dart`: the groups swatches and recency gradient key.
- `lib/features/connections/presentation/panel/highlight_mode_control.dart`: segmented button plus key.
- `lib/features/connections/presentation/widgets/insight_strip.dart`: the tiles row.
- `lib/features/connections/presentation/providers/year_play_provider.dart`: `YearPlayNotifier`, `yearPlayProvider`.
- `lib/features/connections/presentation/widgets/year_play_pill.dart`: `YearPlayButton`, `YearPlayPill`.
- `lib/features/connections/presentation/share/connections_share_caption.dart`: caption strings.
- `lib/features/connections/presentation/share/connections_share_renderer.dart`: PNG rendering.
- `lib/features/connections/presentation/share/connections_share_action.dart`: sheet, share, save, errors.

Modify:
- `lib/l10n/arb/app_*.arb` (11 files) and the generated `lib/l10n/arb/app_localizations*.dart`.
- `lib/features/connections/domain/views/connections_view_state.dart`: `highlight` field.
- `lib/features/connections/domain/views/graph_summary.dart`: drop standout fields.
- `lib/features/connections/presentation/panel/summary_block.dart`: counts only.
- `lib/features/connections/presentation/canvas/connection_kind_colors.dart`: `fromPalette`.
- `lib/features/connections/presentation/canvas/connections_painter.dart`: highlight inputs.
- `lib/features/connections/presentation/canvas/connections_canvas.dart`: pass highlight inputs.
- `lib/features/connections/presentation/widgets/connections_legend.dart`: follows the mode.
- `lib/features/connections/presentation/panel/view_tab.dart`: add the control.
- `lib/features/connections/presentation/widgets/year_range_slider.dart`: play button.
- `lib/features/connections/presentation/pages/connections_page.dart`: strip, pill, groups, share, load signal.

---

### Task 1: Localisation keys

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces these getters/methods on `AppLocalizations` (placeholder order is the order listed, which must match each `@meta` placeholders map order in `app_en.arb`):
  - `connections_insight_newest`, `connections_insight_drifting`, `connections_insight_groups`
  - `connections_insight_groupsValue(int count)`
  - `connections_insight_pair(String a, String b)`
  - `connections_insight_since(String label, String date)`
  - `connections_insight_last(String label, String date)`
  - `connections_highlight_title`, `connections_highlight_byKind`, `connections_highlight_groups`, `connections_highlight_recency`
  - `connections_legend_group`, `connections_legend_recent`, `connections_legend_old`
  - `connections_yearPlay_play`, `connections_yearPlay_pause`
  - `connections_share_tooltip`, `connections_share_sheetTitle`, `connections_share_failed`
  - `connections_share_aroundName(String label)`
  - `connections_share_allDives(int first, int last)`
  - `connections_share_details(String range, String counts)`
- Existing keys reused (do not add): `connections_summary_mostConnected`, `connections_summary_strongestPair`, `connections_summary_closest`, `connections_summary_pairValue(count, a, b)`, `connections_selection_divesTogether(count)`, `connections_semantics_summary(nodes, edges)`, `connections_editor_title` ("Custom map"), `connections_yearRange_label(first, last)`.

- [ ] **Step 1: Write the English keys**

Insert after the line holding `"connections_summary_strongestPair"` in `lib/l10n/arb/app_en.arb` (one line per key; `@meta` lines stay compact on one line like their neighbours):

```json
  "connections_insight_newest": "Newest connection",
  "connections_insight_drifting": "Drifting apart",
  "connections_insight_groups": "Groups",
  "connections_insight_groupsValue": "{count, plural, =1{{count} group} other{{count} groups}}",
  "@connections_insight_groupsValue": {"placeholders": {"count": {"type": "int"}}},
  "connections_insight_pair": "{a} and {b}",
  "@connections_insight_pair": {"placeholders": {"a": {"type": "String"}, "b": {"type": "String"}}},
  "connections_insight_since": "{label}, since {date}",
  "@connections_insight_since": {"placeholders": {"label": {"type": "String"}, "date": {"type": "String"}}},
  "connections_insight_last": "{label}, last {date}",
  "@connections_insight_last": {"placeholders": {"label": {"type": "String"}, "date": {"type": "String"}}},
  "connections_highlight_title": "Colour by",
  "connections_highlight_byKind": "Kind",
  "connections_highlight_groups": "Groups",
  "connections_highlight_recency": "Recency",
  "connections_legend_group": "Colour: group",
  "connections_legend_recent": "Recent",
  "connections_legend_old": "Old",
  "connections_yearPlay_play": "Play years",
  "connections_yearPlay_pause": "Pause",
  "connections_share_tooltip": "Share image",
  "connections_share_sheetTitle": "Share map image",
  "connections_share_failed": "Couldn't create the image",
  "connections_share_aroundName": "Around {label}",
  "@connections_share_aroundName": {"placeholders": {"label": {"type": "String"}}},
  "connections_share_allDives": "All dives, {first} to {last}",
  "@connections_share_allDives": {"placeholders": {"first": {"type": "int"}, "last": {"type": "int"}}},
  "connections_share_details": "{range}. {counts}",
  "@connections_share_details": {"placeholders": {"range": {"type": "String"}, "counts": {"type": "String"}}},
```

Before writing, check whether `app_en.arb` spells "Colour" or "Color" in neighbouring `connections_` keys and match it.

- [ ] **Step 2: Translate into the ten locales**

For each of ar, de, es, fr, he, hu, it, nl, pt, zh: insert the same keys (no `@meta` lines; gen-l10n reads placeholders from the template) after that locale's `"connections_summary_strongestPair"` line. Translate naturally, matching each locale's existing `connections_` terms (read the neighbouring `connections_summary_*` and `connections_kind_*` values first). Keep `{placeholders}` verbatim. fr and pt `=1` branches use `{count}`; ar and he may use their word forms. Use a python3.14 script that inserts by anchor line and then `json.loads` each file to prove it still parses:

```python
import json, pathlib
ANCHOR = '"connections_summary_strongestPair"'
def insert(path, entries):  # entries: list of (key, value)
    src = pathlib.Path(path).read_text(encoding='utf-8')
    lines = src.split('\n')
    i = next(n for n, l in enumerate(lines) if l.strip().startswith(ANCHOR))
    new = ['  "%s": %s,' % (k, json.dumps(v, ensure_ascii=False)) for k, v in entries]
    out = '\n'.join(lines[:i + 1] + new + lines[i + 1:])
    json.loads(out)
    pathlib.Path(path).write_text(out, encoding='utf-8')
```

Watch for CRLF files: if `src` contains `\r\n`, split and join on `\r\n` instead.

- [ ] **Step 3: Generate and verify**

Run: `flutter gen-l10n`
Expected: no "untranslated message" lines naming any `connections_insight_`, `connections_highlight_`, `connections_legend_`, `connections_yearPlay_` or `connections_share_` key.
Run: `grep -A1 "get connections_insight_newest" lib/l10n/arb/app_localizations_de.dart`
Expected: a German string, not "Newest connection".
Run: `git diff --numstat lib/l10n/arb/*.arb`
Expected: every locale row the same size (+22/-0); en larger (+29/-0) for its seven `@meta` lines.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(connections): strings for insights, highlight modes, year play and share"
```

---

### Task 2: HighlightMode on the view state

**Files:**
- Create: `lib/features/connections/domain/views/highlight_mode.dart`
- Modify: `lib/features/connections/domain/views/connections_view_state.dart`
- Test: `test/features/connections/domain/views/connections_view_state_test.dart`

**Interfaces:**
- Produces: `enum HighlightMode { byKind, groups, recency }`; `ConnectionsViewState.highlight` (default `HighlightMode.byKind`); `ConnectionsViewState withHighlight(HighlightMode m)`; `copyWith({..., HighlightMode? highlight})`; JSON key `highlight`.

- [ ] **Step 1: Write the failing tests** (append inside `main()`)

```dart
  group('highlight', () {
    test('defaults to by kind and round-trips through JSON', () {
      expect(ConnectionsViewState.initial.highlight, HighlightMode.byKind);
      final v = ConnectionsViewState.initial.withHighlight(
        HighlightMode.recency,
      );
      expect(v.toJson()['highlight'], 'recency');
      expect(ConnectionsViewState.fromJson(v.toJson())!.highlight,
          HighlightMode.recency);
    });

    test('JSON stored before the field reads as by kind', () {
      final json = ConnectionsViewState.initial.toJson()..remove('highlight');
      expect(ConnectionsViewState.fromJson(json)!.highlight,
          HighlightMode.byKind);
      json['highlight'] = 'sparkles';
      expect(ConnectionsViewState.fromJson(json)!.highlight,
          HighlightMode.byKind);
    });

    test('every transition keeps the highlight', () {
      const ref = NodeRef(ConnectionKind.buddy, 'a');
      final v = ConnectionsViewState.initial.withHighlight(
        HighlightMode.groups,
      );
      final preset = ConnectionPresets.byId('where')!;
      final spec = MapSpec.of({ConnectionKind.site}, const {});
      for (final next in [
        v.applyPreset(preset),
        v.applySavedMap('m1', spec),
        v.showMap(spec),
        v.editMap(spec),
        v.centreOn(ref),
        v.withMode(ConnectionsMode.around),
        v.withAroundKinds({ConnectionKind.site}),
        v.withHops(2),
        v.copyWith(clearFocus: true),
        v.withSavedMaps(const {}),
      ]) {
        expect(next.highlight, HighlightMode.groups);
      }
    });
  });
```

Add imports for `highlight_mode.dart`, `node_ref.dart`, `connection_kind.dart`, `connection_presets.dart`, `map_spec.dart` if the file lacks them. `withSavedMaps` only reconciles when `savedMapId` is set, so build that case as `v.applySavedMap('m1', spec).withSavedMaps(const {})` and check it too.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/domain/views/connections_view_state_test.dart`
Expected: compile error, `HighlightMode` undefined.

- [ ] **Step 3: Implement**

`highlight_mode.dart`:

```dart
/// How the map's nodes and edges are coloured: by entity kind, by the group
/// label propagation finds, or with edges fading by their last shared dive.
enum HighlightMode { byKind, groups, recency }
```

In `connections_view_state.dart`: add `this.highlight = HighlightMode.byKind` to the constructor and `final HighlightMode highlight;`. Pass `highlight: highlight` in every constructor call inside `applyPreset`, `applySavedMap`, `showMap`, `withSavedMaps`, `editMap` and `copyWith`. Add:

```dart
  ConnectionsViewState withHighlight(HighlightMode m) =>
      copyWith(highlight: m);
```

`copyWith` gains `HighlightMode? highlight` and passes `highlight: highlight ?? this.highlight`. `toJson` adds `'highlight': highlight.name`. `fromJson` passes:

```dart
      highlight:
          HighlightMode.values
              .where((m) => m.name == json['highlight'])
              .firstOrNull ??
          HighlightMode.byKind,
```

Add `highlight` to `props`. `fromLegacyLens` needs no change (it builds from `initial`).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/connections/domain/views/ test/features/connections/presentation/providers/connections_view_provider_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/domain/views/ test/features/connections/domain/views/connections_view_state_test.dart
git commit -m "feat(connections): remember a highlight mode with the view"
```

---

### Task 3: Label propagation and graph insights

**Files:**
- Create: `lib/features/connections/domain/insights/label_propagation.dart`
- Create: `lib/features/connections/domain/insights/graph_insights.dart`
- Test: `test/features/connections/domain/insights/label_propagation_test.dart`
- Test: `test/features/connections/domain/insights/graph_insights_test.dart`

**Interfaces:**
- Consumes: `ConnectionGraph`, `ConnectionEdge`, `ConnectionNode`, `NodeRef` (`.wire`), `GraphSummary.strongestFirst(a, b)`, `NodeSelection`, `EdgeSelection`.
- Produces:
  - `class GraphGroups { const GraphGroups({required Map<NodeRef, int> groupOf, required int count}); static const empty; }`
  - `LabelPropagation.communities(ConnectionGraph graph, {int maxRounds = 20}) -> GraphGroups`
  - `enum InsightKind { mostConnected, strongestPair, closest, newest, driftingApart, groups }`
  - `class InsightTile { InsightKind kind; ConnectionNode? node; ConnectionEdge? edge; int value; GraphSelection? get target; }`
  - `GraphInsights.of(ConnectionGraph graph, {NodeRef? focus, required GraphGroups groups}) -> List<InsightTile>`

- [ ] **Step 1: Write the failing label propagation tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);

ConnectionNode _n(NodeRef r) => ConnectionNode(ref: r, label: r.id, diveCount: 1);

ConnectionEdge _e(NodeRef a, NodeRef b, int w) => ConnectionEdge(
  source: a,
  target: b,
  weight: w,
  firstDiveAt: DateTime.utc(2020),
  lastDiveAt: DateTime.utc(2024),
);

void main() {
  test('two triangles joined by a weak bridge are two groups', () {
    final refs = [for (final id in 'abcdef'.split('')) _b(id)];
    final g = ConnectionGraph(
      nodes: [for (final r in refs) _n(r)],
      edges: [
        _e(refs[0], refs[1], 3), _e(refs[0], refs[2], 3), _e(refs[1], refs[2], 3),
        _e(refs[3], refs[4], 3), _e(refs[3], refs[5], 3), _e(refs[4], refs[5], 3),
        _e(refs[2], refs[3], 1),
      ],
    );
    final groups = LabelPropagation.communities(g);
    expect(groups.count, 2);
    expect(groups.groupOf[refs[0]], groups.groupOf[refs[2]]);
    expect(groups.groupOf[refs[3]], groups.groupOf[refs[5]]);
    expect(groups.groupOf[refs[0]], isNot(groups.groupOf[refs[3]]));
  });

  test('a buddy-site map converges to one group', () {
    final g = ConnectionGraph(
      nodes: [_n(_b('b1')), _n(_b('b2')), _n(_s('s1')), _n(_s('s2'))],
      edges: [
        _e(_b('b1'), _s('s1'), 2),
        _e(_b('b2'), _s('s1'), 2),
        _e(_b('b1'), _s('s2'), 1),
      ],
    );
    final groups = LabelPropagation.communities(g);
    expect(groups.count, 1);
    expect(groups.groupOf.length, 4);
    expect(groups.groupOf.values.toSet(), {0});
  });

  test('isolated nodes get no group', () {
    final g = ConnectionGraph(
      nodes: [_n(_b('a')), _n(_b('b')), _n(_b('lonely'))],
      edges: [_e(_b('a'), _b('b'), 1)],
    );
    final groups = LabelPropagation.communities(g);
    expect(groups.count, 1);
    expect(groups.groupOf.containsKey(_b('lonely')), isFalse);
  });

  test('larger groups rank first and the result ignores input order', () {
    final big = [for (final id in ['p', 'q', 'r']) _b(id)];
    final small = [_b('x'), _b('y')];
    final nodes = [for (final r in [...small, ...big]) _n(r)];
    final edges = [
      _e(small[0], small[1], 5),
      _e(big[0], big[1], 1),
      _e(big[1], big[2], 1),
      _e(big[0], big[2], 1),
    ];
    final a = LabelPropagation.communities(
      ConnectionGraph(nodes: nodes, edges: edges),
    );
    final b = LabelPropagation.communities(
      ConnectionGraph(
        nodes: nodes.reversed.toList(),
        edges: edges.reversed.toList(),
      ),
    );
    expect(a.groupOf, b.groupOf);
    expect(a.groupOf[big[0]], 0);
    expect(a.groupOf[small[0]], 1);
  });

  test('an empty graph has no groups', () {
    expect(LabelPropagation.communities(ConnectionGraph.empty).count, 0);
  });
}
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/domain/insights/label_propagation_test.dart`
Expected: compile error, `LabelPropagation` undefined.

- [ ] **Step 3: Implement `label_propagation.dart`**

```dart
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// The communities in a graph: each node in a group of two or more mapped to
/// its group number, numbered largest group first.
class GraphGroups {
  const GraphGroups({required this.groupOf, required this.count});

  static const empty = GraphGroups(groupOf: {}, count: 0);

  final Map<NodeRef, int> groupOf;
  final int count;
}

/// Deterministic asynchronous label propagation. Each node starts with its
/// own wire id as its label; each round visits nodes in wire order and gives
/// each the label with the largest summed edge weight among its neighbours,
/// ties to the smallest label. Updating in place (asynchronously) converges
/// on two-kind graphs, where the synchronous form oscillates.
abstract final class LabelPropagation {
  static GraphGroups communities(
    ConnectionGraph graph, {
    int maxRounds = 20,
  }) {
    final order = [for (final n in graph.nodes) n.ref]
      ..sort((a, b) => a.wire.compareTo(b.wire));
    final label = {for (final r in order) r: r.wire};
    final neighbours = <NodeRef, List<(NodeRef, int)>>{};
    for (final e in graph.edges) {
      if (e.source == e.target ||
          !label.containsKey(e.source) ||
          !label.containsKey(e.target)) {
        continue;
      }
      (neighbours[e.source] ??= []).add((e.target, e.weight));
      (neighbours[e.target] ??= []).add((e.source, e.weight));
    }
    for (var round = 0; round < maxRounds; round++) {
      var changed = false;
      for (final r in order) {
        final around = neighbours[r];
        if (around == null) continue;
        final score = <String, int>{};
        for (final (n, w) in around) {
          final l = label[n]!;
          score[l] = (score[l] ?? 0) + w;
        }
        String? best;
        var bestScore = -1;
        for (final MapEntry(:key, :value) in score.entries) {
          if (value > bestScore ||
              (value == bestScore && key.compareTo(best!) < 0)) {
            best = key;
            bestScore = value;
          }
        }
        if (best != null && best != label[r]) {
          label[r] = best;
          changed = true;
        }
      }
      if (!changed) break;
    }
    final members = <String, List<NodeRef>>{};
    for (final r in order) {
      (members[label[r]!] ??= []).add(r);
    }
    final groups = members.values.where((m) => m.length >= 2).toList()
      ..sort((a, b) {
        final bySize = b.length.compareTo(a.length);
        return bySize != 0 ? bySize : a.first.wire.compareTo(b.first.wire);
      });
    return GraphGroups(
      groupOf: Map.unmodifiable({
        for (var i = 0; i < groups.length; i++)
          for (final r in groups[i]) r: i,
      }),
      count: groups.length,
    );
  }
}
```

(`members` lists are in wire order because `order` is, so `m.first` is the smallest member.)

- [ ] **Step 4: Run the label propagation tests**

Run: `flutter test test/features/connections/domain/insights/label_propagation_test.dart`
Expected: PASS. If the triangles test fails, trace round 1 by hand against the algorithm before changing the test: the expected labels are `{a,b,c} -> buddy:b` and `{d,e,f} -> buddy:e`.

- [ ] **Step 5: Write the failing insights tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/graph_insights.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

ConnectionEdge _e(String a, String b, int w, int firstYear, int lastYear) =>
    ConnectionEdge(
      source: _b(a),
      target: _b(b),
      weight: w,
      firstDiveAt: DateTime.utc(firstYear),
      lastDiveAt: DateTime.utc(lastYear),
    );

ConnectionGraph _graph(List<ConnectionEdge> edges, {Map<String, int> dives = const {}}) {
  final ids = {for (final e in edges) ...[e.source.id, e.target.id]};
  return ConnectionGraph(
    nodes: [
      for (final id in ids)
        ConnectionNode(ref: _b(id), label: id.toUpperCase(), diveCount: dives[id] ?? 1),
    ],
    edges: edges,
  );
}

List<InsightTile> _of(ConnectionGraph g, {NodeRef? focus}) =>
    GraphInsights.of(g, focus: focus, groups: LabelPropagation.communities(g));

InsightTile? _tile(List<InsightTile> tiles, InsightKind k) =>
    tiles.where((t) => t.kind == k).firstOrNull;

void main() {
  final g = _graph([
    _e('ana', 'bo', 9, 2015, 2025), // strongest
    _e('ana', 'cy', 3, 2012, 2014), // drifting: weight 3, last 2014
    _e('bo', 'cy', 1, 2010, 2011), // weight 1: never drifting
    _e('cy', 'dee', 2, 2024, 2025), // newest first dive
  ]);

  test('map mode: five tiles in order', () {
    final tiles = _of(g);
    expect(tiles.map((t) => t.kind), [
      InsightKind.mostConnected,
      InsightKind.strongestPair,
      InsightKind.newest,
      InsightKind.driftingApart,
      InsightKind.groups,
    ]);
    expect(_tile(tiles, InsightKind.mostConnected)!.node!.ref, _b('ana'));
    expect(_tile(tiles, InsightKind.mostConnected)!.value, 12);
    expect(_tile(tiles, InsightKind.strongestPair)!.edge!.weight, 9);
    expect(_tile(tiles, InsightKind.newest)!.edge!.target, _b('dee'));
    expect(_tile(tiles, InsightKind.driftingApart)!.edge!.target, _b('cy'));
    expect(_tile(tiles, InsightKind.groups)!.value, 1);
  });

  test('tiles target what they name', () {
    final tiles = _of(g);
    expect(
      _tile(tiles, InsightKind.mostConnected)!.target,
      NodeSelection(_b('ana')),
    );
    expect(
      _tile(tiles, InsightKind.strongestPair)!.target,
      EdgeSelection(_b('ana'), _b('bo')),
    );
    expect(_tile(tiles, InsightKind.groups)!.target, isNull);
  });

  test('drifting apart needs weight two or more', () {
    final tiles = _of(_graph([_e('a', 'b', 1, 2000, 2001)]));
    expect(_tile(tiles, InsightKind.driftingApart), isNull);
  });

  test('drifting apart ties go to the heavier edge', () {
    final tiles = _of(_graph([
      _e('a', 'b', 2, 2000, 2010),
      _e('c', 'd', 5, 2000, 2010),
    ]));
    expect(_tile(tiles, InsightKind.driftingApart)!.edge!.weight, 5);
  });

  test('an empty graph has no tiles', () {
    expect(_of(ConnectionGraph.empty), isEmpty);
  });

  test('around mode: centre-relative tiles, the centre never most connected',
      () {
    final tiles = _of(g, focus: _b('ana'));
    expect(tiles.map((t) => t.kind), [
      InsightKind.closest,
      InsightKind.newest,
      InsightKind.driftingApart,
      InsightKind.mostConnected,
      InsightKind.groups,
    ]);
    final closest = _tile(tiles, InsightKind.closest)!;
    expect(closest.node!.ref, _b('bo'));
    expect(closest.value, 9);
    expect(closest.target, EdgeSelection(_b('ana'), _b('bo')));
    expect(_tile(tiles, InsightKind.newest)!.node!.ref, _b('bo'));
    expect(_tile(tiles, InsightKind.driftingApart)!.node!.ref, _b('cy'));
    expect(_tile(tiles, InsightKind.mostConnected)!.node!.ref, isNot(_b('ana')));
  });

  test('around mode with only weight-one centre edges has no drifting tile',
      () {
    final tiles = _of(
      _graph([_e('ana', 'bo', 1, 2000, 2001), _e('bo', 'cy', 4, 2000, 2001)]),
      focus: _b('ana'),
    );
    expect(_tile(tiles, InsightKind.driftingApart), isNull);
    expect(_tile(tiles, InsightKind.mostConnected)!.node!.ref, _b('bo'));
  });
}
```

Check the most connected arithmetic before running: ana has 9 + 3 = 12; bo 9 + 1 = 10; cy 3 + 1 + 2 = 6; dee 2.

- [ ] **Step 6: Run to see it fail**

Run: `flutter test test/features/connections/domain/insights/graph_insights_test.dart`
Expected: compile error, `GraphInsights` undefined.

- [ ] **Step 7: Implement `graph_insights.dart`**

```dart
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';

enum InsightKind {
  mostConnected,
  strongestPair,
  closest,
  newest,
  driftingApart,
  groups,
}

/// One standout fact about the map in view. [node] is the entity a tile
/// names (in Around mode, the far end of a centre edge); [edge] is the pair
/// behind it; [value] is a weighted degree, an edge weight or a group count.
class InsightTile {
  const InsightTile({
    required this.kind,
    this.node,
    this.edge,
    this.value = 0,
  });

  final InsightKind kind;
  final ConnectionNode? node;
  final ConnectionEdge? edge;
  final int value;

  /// What tapping the tile selects; null for groups, which switches the
  /// highlight mode instead.
  GraphSelection? get target {
    final e = edge;
    if (e != null) return EdgeSelection(e.source, e.target);
    final n = node;
    return n == null ? null : NodeSelection(n.ref);
  }
}

abstract final class GraphInsights {
  static List<InsightTile> of(
    ConnectionGraph graph, {
    NodeRef? focus,
    required GraphGroups groups,
  }) {
    if (graph.isEmpty) return const [];
    final most = _mostConnected(graph, focus);
    final groupsTile = groups.count == 0
        ? null
        : InsightTile(kind: InsightKind.groups, value: groups.count);
    if (focus == null) {
      final strongest = _first(graph.edges, GraphSummary.strongestFirst);
      return [
        ?most,
        if (strongest != null)
          InsightTile(
            kind: InsightKind.strongestPair,
            edge: strongest,
            value: strongest.weight,
          ),
        ?_edgeTile(graph, InsightKind.newest, _newest(graph.edges), null),
        ?_edgeTile(graph, InsightKind.driftingApart, _drifting(graph.edges), null),
        ?groupsTile,
      ];
    }
    final mine = graph.edges.where((e) => e.touches(focus)).toList();
    return [
      ?_edgeTile(
        graph,
        InsightKind.closest,
        _first(mine, GraphSummary.strongestFirst),
        focus,
      ),
      ?_edgeTile(graph, InsightKind.newest, _newest(mine), focus),
      ?_edgeTile(graph, InsightKind.driftingApart, _drifting(mine), focus),
      ?most,
      ?groupsTile,
    ];
  }

  static InsightTile? _mostConnected(ConnectionGraph graph, NodeRef? focus) {
    final degree = <NodeRef, int>{};
    for (final e in graph.edges) {
      degree[e.source] = (degree[e.source] ?? 0) + e.weight;
      degree[e.target] = (degree[e.target] ?? 0) + e.weight;
    }
    ConnectionNode? best;
    for (final n in graph.nodes) {
      if (n.ref == focus) continue;
      if (best == null) {
        best = n;
        continue;
      }
      final byDegree = (degree[n.ref] ?? 0).compareTo(degree[best.ref] ?? 0);
      if (byDegree > 0 ||
          (byDegree == 0 &&
              (n.diveCount > best.diveCount ||
                  (n.diveCount == best.diveCount &&
                      n.label.compareTo(best.label) < 0)))) {
        best = n;
      }
    }
    final d = degree[best?.ref] ?? 0;
    if (best == null || d == 0) return null;
    return InsightTile(kind: InsightKind.mostConnected, node: best, value: d);
  }

  static ConnectionEdge? _newest(List<ConnectionEdge> edges) =>
      _first(edges, (a, b) {
        final c = b.firstDiveAt.compareTo(a.firstDiveAt);
        return c != 0 ? c : GraphSummary.strongestFirst(a, b);
      });

  static ConnectionEdge? _drifting(List<ConnectionEdge> edges) => _first(
    edges.where((e) => e.weight >= 2).toList(),
    (a, b) {
      final c = a.lastDiveAt.compareTo(b.lastDiveAt);
      if (c != 0) return c;
      final w = b.weight.compareTo(a.weight);
      return w != 0 ? w : GraphSummary.strongestFirst(a, b);
    },
  );

  static ConnectionEdge? _first(
    List<ConnectionEdge> edges,
    int Function(ConnectionEdge, ConnectionEdge) compare,
  ) {
    ConnectionEdge? best;
    for (final e in edges) {
      if (best == null || compare(e, best) < 0) best = e;
    }
    return best;
  }

  static InsightTile? _edgeTile(
    ConnectionGraph graph,
    InsightKind kind,
    ConnectionEdge? edge,
    NodeRef? focus,
  ) {
    if (edge == null) return null;
    final other = focus == null ? null : edge.otherEnd(focus);
    return InsightTile(
      kind: kind,
      edge: edge,
      node: other == null ? null : graph.nodeFor(other),
      value: edge.weight,
    );
  }
}
```

The `?element` null-aware list element syntax is already used in this feature (`{?selectedNode, ...lit, ?hovered}` in the painter), so the SDK supports it.

- [ ] **Step 8: Run tests**

Run: `flutter test test/features/connections/domain/insights/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/connections/domain/insights/ test/features/connections/domain/insights/
git commit -m "feat(connections): find groups and standout facts in the map"
```

---

### Task 4: Summary block shows counts only

**Files:**
- Modify: `lib/features/connections/domain/views/graph_summary.dart`
- Modify: `lib/features/connections/presentation/panel/summary_block.dart`
- Test: `test/features/connections/domain/views/graph_summary_test.dart`
- Test: `test/features/connections/presentation/panel/around_and_summary_test.dart`

**Interfaces:**
- Produces: `GraphSummary` with only `countsByKind`, `connectionCount`, `entitiesAround`, and the static `strongestFirst` (kept; Task 3 uses it).

- [ ] **Step 1: Update the tests first**

In `graph_summary_test.dart`, delete every test or `expect` that reads `mostConnected`, `mostConnectedDegree`, `strongest`, `closest` or `closestWeight` (those facts are now covered by `graph_insights_test.dart`); keep the counts and `strongestFirst` tests. In `around_and_summary_test.dart`, change the first test's last two expectations to:

```dart
    expect(find.text('Kiyan Griffin'), findsNothing,
        reason: 'standouts moved to the insight strip');
    expect(
      find.text('Kiyan Griffin and Sharon Patterson, 12 dives'),
      findsNothing,
    );
    expect(find.text('2 connections'), findsOneWidget);
```

(Confirm the exact text of `connections_filterBar_edges(2)` in `app_en.arb` and use it.)

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/presentation/panel/around_and_summary_test.dart`
Expected: FAIL, the pair text is still found.

- [ ] **Step 3: Implement**

In `graph_summary.dart`, reduce the class to:

```dart
/// What the map in view counts, for the panel's Summary block. The standout
/// facts live in `GraphInsights`.
class GraphSummary {
  const GraphSummary._({
    required this.countsByKind,
    required this.connectionCount,
    required this.entitiesAround,
  });

  factory GraphSummary.of(ConnectionGraph graph, {NodeRef? focus}) {
    final others = graph.nodes.where((n) => n.ref != focus).toList();
    final counts = <ConnectionKind, int>{};
    for (final n in others) {
      counts[n.ref.kind] = (counts[n.ref.kind] ?? 0) + 1;
    }
    return GraphSummary._(
      countsByKind: Map.unmodifiable(counts),
      connectionCount: graph.edges.length,
      entitiesAround: others.length,
    );
  }

  // strongestFirst stays exactly as it is today, doc comment included.

  final Map<ConnectionKind, int> countsByKind;
  final int connectionCount;
  final int entitiesAround;
}
```

Remove now-unused imports (`connection_node.dart`). In `summary_block.dart`, delete the `closest`, `mostConnected` and `strongest` rows and the unused `label` helper, keeping the title, the "entities around" row, the kind rows and the connections row.

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/features/connections/domain/views/ test/features/connections/presentation/panel/`
Expected: PASS.
Run: `flutter analyze lib/features/connections`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/domain/views/graph_summary.dart lib/features/connections/presentation/panel/summary_block.dart test/features/connections/
git commit -m "feat(connections): keep the summary to counts"
```

---

### Task 5: Painter highlight modes

**Files:**
- Create: `lib/features/connections/presentation/canvas/connection_group_colors.dart`
- Modify: `lib/features/connections/presentation/canvas/connection_kind_colors.dart`
- Modify: `lib/features/connections/presentation/canvas/connections_painter.dart`
- Test: `test/features/connections/presentation/canvas/connections_painter_test.dart`

**Interfaces:**
- Consumes: `HighlightMode` (Task 2).
- Produces:
  - `const List<Color> kConnectionGroupColors` (8), `const Color kConnectionUngroupedColor`.
  - `ConnectionKindColors.fromPalette(FeatureAccentColors palette, Color fallback)`.
  - `ConnectionsPainter` named params `HighlightMode highlight = HighlightMode.byKind`, `Map<NodeRef, int> groupOf = const {}`.
  - `Color ConnectionsPainter.fillFor(ConnectionNode n)`; `static double ConnectionsPainter.recencyFactor(DateTime last, DateTime newest, DateTime oldest)`.

- [ ] **Step 1: Write the failing tests** (append to `connections_painter_test.dart`; extend its local `painter(...)` helper with `HighlightMode highlight = HighlightMode.byKind, Map<NodeRef, int> groupOf = const {}` and pass them through)

```dart
  group('highlight modes', () {
    test('by kind fills with the kind colour', () {
      expect(painter().fillFor(graph.nodes.first), Colors.pink);
    });

    test('groups fill with the group colour, later groups and loners grey',
        () {
      final p = painter(
        highlight: HighlightMode.groups,
        groupOf: {_b('a'): 0, _b('b'): 8},
      );
      expect(p.fillFor(graph.nodes[0]), kConnectionGroupColors[0]);
      expect(p.fillFor(graph.nodes[1]), kConnectionUngroupedColor);
      expect(p.fillFor(graph.nodes[2]), kConnectionUngroupedColor);
    });

    test('recency scales from 1 for the newest to 0.15 for the oldest', () {
      final newest = DateTime.utc(2024);
      final oldest = DateTime.utc(2014);
      expect(ConnectionsPainter.recencyFactor(newest, newest, oldest), 1);
      expect(
        ConnectionsPainter.recencyFactor(oldest, newest, oldest),
        closeTo(0.15, 1e-9),
      );
      expect(
        ConnectionsPainter.recencyFactor(DateTime.utc(2019), newest, oldest),
        closeTo(0.575, 0.01),
      );
    });

    test('recency with one distinct date keeps every edge at full strength',
        () {
      final d = DateTime.utc(2024);
      expect(ConnectionsPainter.recencyFactor(d, d, d), 1);
    });

    test('groups mode paints the group colour', () {
      final single = ConnectionGraph(
        nodes: [ConnectionNode(ref: _b('a'), label: 'Ann', diveCount: 5)],
        edges: const [],
      );
      final p = ConnectionsPainter(
        graph: single,
        frame: frame,
        viewport: const GraphViewport(scale: 1, offset: Offset(50, 50)),
        colors: colors,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
        highlight: HighlightMode.groups,
        groupOf: {_b('a'): 2},
      );
      expect(
        (Canvas c) => p.paint(c, const Size(300, 300)),
        paints..circle(color: kConnectionGroupColors[2]),
      );
    });

    test('a highlight change repaints', () {
      expect(
        painter(highlight: HighlightMode.recency).shouldRepaint(painter()),
        isTrue,
      );
      expect(
        painter(groupOf: {_b('a'): 1}).shouldRepaint(painter()),
        isTrue,
      );
    });
  });
```

Imports to add: `highlight_mode.dart`, `connection_group_colors.dart`.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/presentation/canvas/connections_painter_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

`connection_group_colors.dart`:

```dart
import 'package:flutter/painting.dart';

/// Group fills for the Groups highlight mode, largest group first. Mid tones
/// that carry the white node glyphs and read on light, dark and the share
/// image's navy.
const List<Color> kConnectionGroupColors = [
  Color(0xFFEF6C00),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFFE53935),
  Color(0xFF00ACC1),
  Color(0xFFC0CA33),
  Color(0xFFD81B60),
];

/// Nodes in no group, or in a group past the palette.
const Color kConnectionUngroupedColor = Color(0xFF9E9E9E);
```

`connection_kind_colors.dart`: move the body of `of` into

```dart
  /// The kind colours [palette] gives, for a surface that is not the current
  /// theme (the share image always uses the dark palette).
  factory ConnectionKindColors.fromPalette(
    FeatureAccentColors palette,
    Color fallback,
  ) => ConnectionKindColors({
    for (final kind in ConnectionKind.values)
      if (kind.accentFeatureId != null &&
          palette.of(kind.accentFeatureId!) != null)
        kind: palette.of(kind.accentFeatureId!)!,
  }, fallback);
```

and make `of` call `ConnectionKindColors.fromPalette(palette, fallback)`.

`connections_painter.dart`:
- Add constructor params `this.highlight = HighlightMode.byKind, this.groupOf = const {}` and fields with doc comments.
- Add:

```dart
  /// A node's fill before any selection dimming.
  Color fillFor(ConnectionNode n) {
    if (highlight != HighlightMode.groups) return colors.colorFor(n.ref.kind);
    final g = groupOf[n.ref];
    return g != null && g < kConnectionGroupColors.length
        ? kConnectionGroupColors[g]
        : kConnectionUngroupedColor;
  }

  /// An edge's opacity multiplier in Recency mode: 1 for the newest last
  /// dive in view down to 0.15 for the oldest, linear in time.
  static double recencyFactor(DateTime last, DateTime newest, DateTime oldest) {
    final span = newest.difference(oldest).inMilliseconds;
    if (span <= 0) return 1;
    final age = newest.difference(last).inMilliseconds;
    return 1 - 0.85 * (age / span).clamp(0.0, 1.0);
  }
```

- In `paint`, before the edge loop, when `highlight == HighlightMode.recency` and edges exist, compute `newest` and `oldest` as the max and min `lastDiveAt` over `graph.edges`. Multiply each edge's `alpha` by `recencyFactor(e.lastDiveAt, newest, oldest)` in that mode.
- Replace `colors.colorFor(n.ref.kind).withValues(...)` with `fillFor(n).withValues(...)`.
- `shouldRepaint` adds `old.highlight != highlight || !mapEquals(old.groupOf, groupOf)`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: PASS (benchmark tests included).

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/presentation/canvas/ test/features/connections/presentation/canvas/connections_painter_test.dart
git commit -m "feat(connections): paint nodes by group and edges by recency"
```

---

### Task 6: Canvas plumbing, highlight control and legend key

**Files:**
- Create: `lib/features/connections/presentation/widgets/highlight_key.dart`
- Create: `lib/features/connections/presentation/panel/highlight_mode_control.dart`
- Modify: `lib/features/connections/presentation/canvas/connections_canvas.dart`
- Modify: `lib/features/connections/presentation/widgets/connections_legend.dart`
- Modify: `lib/features/connections/presentation/panel/view_tab.dart`
- Test: `test/features/connections/presentation/panel/highlight_mode_control_test.dart`
- Test: `test/features/connections/presentation/canvas/connections_canvas_test.dart`

**Interfaces:**
- Consumes: `HighlightMode`, `ConnectionsViewState.withHighlight`, `kConnectionGroupColors`, painter params from Task 5.
- Produces:
  - `ConnectionsCanvas` params `HighlightMode highlight = HighlightMode.byKind`, `Map<NodeRef, int> groupOf = const {}`.
  - `HighlightKey({required HighlightMode mode, int groupCount = 0})`: renders nothing for byKind.
  - `HighlightModeControl()`: a `ConsumerWidget`, key `ValueKey('highlight-mode')`.
  - `ConnectionsLegend` params `HighlightMode highlight = HighlightMode.byKind`, `int groupCount = 0`.
  - `ViewTab` param `int groupCount = 0`, passed to `HighlightModeControl(groupCount:)`.

- [ ] **Step 1: Write the failing widget test** (`highlight_mode_control_test.dart`; harness copied from `around_and_summary_test.dart`'s `_pump`, pumping `const Scaffold(body: HighlightModeControl(groupCount: 3))`)

```dart
  testWidgets('the segments write the mode and show its key', (tester) async {
    final c = await _pump(tester);
    expect(find.text('Colour by'), findsOneWidget);
    expect(find.byKey(const ValueKey('highlight-key-groups')), findsNothing);

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).highlight, HighlightMode.groups);
    expect(find.byKey(const ValueKey('highlight-key-groups')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-swatch-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-swatch-3')), findsNothing);

    await tester.tap(find.text('Recency'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).highlight, HighlightMode.recency);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
  });
```

Also add a legend test in the same file:

```dart
  testWidgets('the legend follows the mode', (tester) async {
    Future<void> show(HighlightMode m) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ConnectionsLegend(
            kinds: const {ConnectionKind.buddy},
            colors: const ConnectionKindColors({}, Colors.teal),
            highlight: m,
            groupCount: 2,
          ),
        ),
      ),
    );
    await show(HighlightMode.byKind);
    expect(find.text('Buddies'), findsOneWidget);
    await show(HighlightMode.groups);
    expect(find.text('Buddies'), findsNothing);
    expect(find.text('Colour: group'), findsOneWidget);
    await show(HighlightMode.recency);
    expect(find.text('Buddies'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });
```

In `connections_canvas_test.dart`, add a test that pumps `ConnectionsCanvas(..., highlight: HighlightMode.groups, groupOf: {...})` with the file's existing harness and asserts the `CustomPaint` under `ValueKey('connections-canvas-paint')` holds a `ConnectionsPainter` whose `highlight` is `HighlightMode.groups` and whose `groupOf` equals the map passed.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/presentation/panel/highlight_mode_control_test.dart test/features/connections/presentation/canvas/connections_canvas_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement**

`highlight_key.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_group_colors.dart';
import 'package:submersion/features/connections/presentation/widgets/kind_dot.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the colours mean outside By kind: one swatch per group (up to the
/// palette), or the recent-to-old edge fade.
class HighlightKey extends StatelessWidget {
  const HighlightKey({super.key, required this.mode, this.groupCount = 0});

  final HighlightMode mode;
  final int groupCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    switch (mode) {
      case HighlightMode.byKind:
        return const SizedBox.shrink();
      case HighlightMode.groups:
        final shown = groupCount.clamp(0, kConnectionGroupColors.length);
        return Row(
          key: const ValueKey('highlight-key-groups'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.connections_legend_group, style: style),
            const SizedBox(width: 6),
            for (var i = 0; i < shown; i++)
              Padding(
                key: ValueKey('group-swatch-$i'),
                padding: const EdgeInsets.only(right: 3),
                child: KindDot(color: kConnectionGroupColors[i], size: 10),
              ),
          ],
        );
      case HighlightMode.recency:
        final ink = theme.colorScheme.onSurface;
        return Row(
          key: const ValueKey('highlight-key-recency'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.connections_legend_recent, style: style),
            const SizedBox(width: 6),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [ink, ink.withValues(alpha: 0.15)],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(l10n.connections_legend_old, style: style),
          ],
        );
    }
  }
}
```

`highlight_mode_control.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/highlight_key.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Colour by kind, group or recency, with the key for the chosen mode.
class HighlightModeControl extends ConsumerWidget {
  const HighlightModeControl({super.key, this.groupCount = 0});

  final int groupCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(connectionsViewProvider.select((v) => v.highlight));
    return Column(
      key: const ValueKey('highlight-mode'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.connections_highlight_title,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SegmentedButton<HighlightMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: HighlightMode.byKind,
              label: Text(l10n.connections_highlight_byKind),
            ),
            ButtonSegment(
              value: HighlightMode.groups,
              label: Text(l10n.connections_highlight_groups),
            ),
            ButtonSegment(
              value: HighlightMode.recency,
              label: Text(l10n.connections_highlight_recency),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => ref
              .read(connectionsViewProvider.notifier)
              .update((v) => v.withHighlight(s.single)),
        ),
        if (mode != HighlightMode.byKind) ...[
          const SizedBox(height: 6),
          HighlightKey(mode: mode, groupCount: groupCount),
        ],
      ],
    );
  }
}
```

`ConnectionsLegend`: add the two params. In `build`, when `highlight == HighlightMode.groups`, return `HighlightKey(mode: highlight, groupCount: groupCount)` (with the title above it when `showTitle`). Otherwise, render as today, and for recency append `HighlightKey(mode: highlight)` after the kind rows.

`ViewTab`: add `this.groupCount = 0` and insert `const SizedBox(height: 12), HighlightModeControl(groupCount: groupCount),` right after `const ModeSwitch()`.

`ConnectionsCanvas`: add both params with doc comments and pass `highlight: widget.highlight, groupOf: widget.groupOf` into the `ConnectionsPainter(...)` call in `build`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/connections/presentation/`
Expected: PASS. If an existing View tab test finds two widgets with text "Groups", scope it with `find.descendant` of the control's key.

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/presentation/ test/features/connections/presentation/
git commit -m "feat(connections): choose how the map is coloured"
```

---

### Task 7: Insight strip widget

**Files:**
- Create: `lib/features/connections/presentation/widgets/insight_strip.dart`
- Test: `test/features/connections/presentation/widgets/insight_strip_test.dart`

**Interfaces:**
- Consumes: `InsightTile`, `InsightKind` (Task 3); `UnitFormatter(ref.watch(settingsProvider))`; `AppLocalizations` keys from Task 1.
- Produces: `InsightStrip({required ConnectionGraph graph, required List<InsightTile> tiles, required ValueChanged<GraphSelection> onSelect, required VoidCallback onGroups})`. Each tile keyed `ValueKey('insight-${kind.name}')`. Renders `SizedBox.shrink()` when `tiles` is empty.

- [ ] **Step 1: Write the failing test**

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
import 'package:submersion/features/connections/domain/insights/graph_insights.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/presentation/widgets/insight_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('ana'), label: 'Ana', diveCount: 9),
    ConnectionNode(ref: _b('bo'), label: 'Bo', diveCount: 7),
  ],
  edges: [
    ConnectionEdge(
      source: _b('ana'),
      target: _b('bo'),
      weight: 7,
      firstDiveAt: DateTime(2016, 3, 4),
      lastDiveAt: DateTime(2018, 6, 1),
    ),
  ],
);

void main() {
  testWidgets('tiles name their facts, select, and switch to groups', (
    tester,
  ) async {
    final selected = <GraphSelection>[];
    var groups = 0;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InsightStrip(
              graph: _graph,
              tiles: GraphInsights.of(
                _graph,
                groups: LabelPropagation.communities(_graph),
              ),
              onSelect: selected.add,
              onGroups: () => groups++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Most connected'), findsOneWidget);
    expect(find.text('Ana and Bo, 7 dives'), findsOneWidget);
    expect(find.textContaining('Ana and Bo, since'), findsOneWidget);
    expect(find.textContaining('Ana and Bo, last'), findsOneWidget);
    expect(find.text('1 group'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('insight-strongestPair')));
    expect(selected.single, EdgeSelection(_b('ana'), _b('bo')));

    await tester.ensureVisible(find.byKey(const ValueKey('insight-groups')));
    await tester.tap(find.byKey(const ValueKey('insight-groups')));
    expect(groups, 1);
  });

  testWidgets('no tiles, no strip', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InsightStrip(
              graph: ConnectionGraph.empty,
              tiles: const [],
              onSelect: (_) {},
              onGroups: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Card), findsNothing);
  });
}
```

Also add a test that the "since" date is the `UnitFormatter.formatMonthYear` output for the base settings: compute `UnitFormatter(container.read(settingsProvider)).formatMonthYear(DateTime(2016, 3, 4))` and expect `'Ana and Bo, since $that'`.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/presentation/widgets/insight_strip_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement `insight_strip.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/insights/graph_insights.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The standout facts of the map in view, as a scrolling row of tiles over
/// the canvas. A tile selects what it names; the Groups tile colours the map
/// by group instead.
class InsightStrip extends ConsumerWidget {
  const InsightStrip({
    super.key,
    required this.graph,
    required this.tiles,
    required this.onSelect,
    required this.onGroups,
  });

  final ConnectionGraph graph;
  final List<InsightTile> tiles;
  final ValueChanged<GraphSelection> onSelect;
  final VoidCallback onGroups;

  static const double height = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = tiles[i];
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Card(
              key: ValueKey('insight-${t.kind.name}'),
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  final target = t.target;
                  if (t.kind == InsightKind.groups) {
                    onGroups();
                  } else if (target != null) {
                    onSelect(target);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _title(l10n, t.kind),
                        style: theme.textTheme.labelSmall,
                      ),
                      Text(
                        _value(l10n, units, t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _title(AppLocalizations l10n, InsightKind k) => switch (k) {
    InsightKind.mostConnected => l10n.connections_summary_mostConnected,
    InsightKind.strongestPair => l10n.connections_summary_strongestPair,
    InsightKind.closest => l10n.connections_summary_closest,
    InsightKind.newest => l10n.connections_insight_newest,
    InsightKind.driftingApart => l10n.connections_insight_drifting,
    InsightKind.groups => l10n.connections_insight_groups,
  };

  String _pair(AppLocalizations l10n, ConnectionEdge e) =>
      l10n.connections_insight_pair(_name(e.source), _name(e.target));

  String _name(ref) => graph.nodeFor(ref)?.label ?? ref.id;

  String _value(AppLocalizations l10n, UnitFormatter units, InsightTile t) {
    final e = t.edge;
    final who = t.node?.label ?? (e == null ? '' : _pair(l10n, e));
    return switch (t.kind) {
      InsightKind.mostConnected => who,
      InsightKind.strongestPair => l10n.connections_summary_pairValue(
        e!.weight,
        _name(e.source),
        _name(e.target),
      ),
      InsightKind.closest =>
        '$who, ${l10n.connections_selection_divesTogether(e!.weight)}',
      InsightKind.newest => l10n.connections_insight_since(
        who,
        units.formatMonthYear(e!.firstDiveAt),
      ),
      InsightKind.driftingApart => l10n.connections_insight_last(
        who,
        units.formatMonthYear(e!.lastDiveAt),
      ),
      InsightKind.groups => l10n.connections_insight_groupsValue(t.value),
    };
  }
}
```

Type `_name`'s parameter as `NodeRef` (import `node_ref.dart`); it is shown untyped above only for brevity, and an untyped parameter fails the repo's lints. Check the placeholder order of `connections_summary_pairValue` in the generated `app_localizations.dart` (the existing Summary block calls it as `(count, a, b)`) and of the Task 1 methods.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/connections/presentation/widgets/insight_strip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/presentation/widgets/insight_strip.dart test/features/connections/presentation/widgets/insight_strip_test.dart
git commit -m "feat(connections): an insight strip of standout facts"
```

---

### Task 8: Year play notifier

**Files:**
- Create: `lib/features/connections/presentation/providers/year_play_provider.dart`
- Test: `test/features/connections/presentation/providers/year_play_provider_test.dart`

**Interfaces:**
- Consumes: `connectionsFilterProvider` (`StateProvider<DiveFilterState>`), `connectionsViewProvider`, `connectionsYearSpanProvider` (`FutureProvider.autoDispose<({int first, int last})?>`), `DiveFilterState.copyWith(endDate:, clearStartDate:, clearEndDate:)`.
- Produces:
  - `final yearPlayProvider = NotifierProvider.autoDispose<YearPlayNotifier, int?>(YearPlayNotifier.new);` state is the year on screen while playing, null when idle.
  - `YearPlayNotifier.play()`, `pause()`, `loadSettled({required bool failed})`, `static const Duration beat = Duration(milliseconds: 1200)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/year_play_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  late List<Override> base;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    base = await getBaseOverrides();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        ...base,
        connectionsYearSpanProvider.overrideWith(
          (ref) async => (first: 2019, last: 2022),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(yearPlayProvider, (_, _) {});
    c.listen(connectionsYearSpanProvider, (_, _) {});
    return c;
  }

  DiveFilterState filter(ProviderContainer c) =>
      c.read(connectionsFilterProvider);

  test('from the full span, play restarts at the first year', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      c.read(yearPlayProvider.notifier).play();
      expect(c.read(yearPlayProvider), 2019);
      expect(filter(c).endDate, DateTime(2019, 12, 31));
      expect(filter(c).startDate, isNull);
    });
  });

  test('a beat waits for both the delay and the load', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      async.elapse(YearPlayNotifier.beat);
      expect(c.read(yearPlayProvider), 2019, reason: 'load not settled');
      n.loadSettled(failed: false);
      expect(c.read(yearPlayProvider), 2020);

      n.loadSettled(failed: false);
      async.elapse(const Duration(milliseconds: 600));
      expect(c.read(yearPlayProvider), 2020, reason: 'beat not elapsed');
      async.elapse(const Duration(milliseconds: 600));
      expect(c.read(yearPlayProvider), 2021);
    });
  });

  test('reaching the last year stops and clears the whole span', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      for (var i = 0; i < 3; i++) {
        n.loadSettled(failed: false);
        async.elapse(YearPlayNotifier.beat);
      }
      expect(c.read(yearPlayProvider), isNull);
      expect(filter(c).startDate, isNull);
      expect(filter(c).endDate, isNull);
    });
  });

  test('a later start year is kept, and the end stays at the last year', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 12, 31),
      );
      final n = c.read(yearPlayProvider.notifier)..play();
      expect(c.read(yearPlayProvider), 2021, reason: 'continues past 2020');
      expect(filter(c).startDate, DateTime(2020, 1, 1));
      n.loadSettled(failed: false);
      async.elapse(YearPlayNotifier.beat);
      expect(c.read(yearPlayProvider), isNull);
      expect(filter(c).startDate, DateTime(2020, 1, 1));
      expect(filter(c).endDate, DateTime(2022, 12, 31));
    });
  });

  test('an outside filter change stops play and is never overwritten', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      final mine = DiveFilterState(endDate: DateTime(2021, 6, 1));
      c.read(connectionsFilterProvider.notifier).state = mine;
      expect(c.read(yearPlayProvider), isNull);
      n.loadSettled(failed: false);
      async.elapse(YearPlayNotifier.beat * 3);
      expect(filter(c), mine);
    });
  });

  test('a view change, a failed load and pause each stop play', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = c.read(yearPlayProvider.notifier)..play();
      c
          .read(connectionsViewProvider.notifier)
          .update((v) => v.withMode(ConnectionsMode.around));
      async.flushMicrotasks();
      expect(c.read(yearPlayProvider), isNull);

      n.play();
      n.loadSettled(failed: true);
      expect(c.read(yearPlayProvider), isNull);

      n.play();
      n.pause();
      expect(c.read(yearPlayProvider), isNull);
      async.elapse(YearPlayNotifier.beat * 2);
      expect(c.read(yearPlayProvider), isNull);
    });
  });

  test('a one-year log does not play', () {
    fakeAsync((async) {
      final c = ProviderContainer(
        overrides: [
          ...base,
          connectionsYearSpanProvider.overrideWith(
            (ref) async => (first: 2022, last: 2022),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(yearPlayProvider, (_, _) {});
      c.listen(connectionsYearSpanProvider, (_, _) {});
      async.flushMicrotasks();
      c.read(yearPlayProvider.notifier).play();
      expect(c.read(yearPlayProvider), isNull);
    });
  });
}
```

If `getBaseOverrides()` needs a widget binding, keep `TestWidgetsFlutterBinding.ensureInitialized()` in `setUp`; if it still fails outside `testWidgets`, convert these to `testWidgets` and use `tester.pump(duration)` in place of `async.elapse`.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/presentation/providers/year_play_provider_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement `year_play_provider.dart`**

```dart
import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Grows the map one year at a time by moving the connections filter's end
/// date. The state is the year on screen while playing, null when idle.
///
/// A beat moves to the next year only once [beat] has passed and the page
/// has reported the year's graph loaded, so a slow log never piles up
/// steps. Any filter or view change it did not make itself stops play.
class YearPlayNotifier extends Notifier<int?> {
  static const Duration beat = Duration(milliseconds: 1200);

  Timer? _timer;
  bool _beatDone = false;
  bool _loaded = false;
  DiveFilterState? _written;
  int _first = 0;
  int _last = 0;

  @override
  int? build() {
    ref.onDispose(_cancel);
    ref.listen<DiveFilterState>(connectionsFilterProvider, (_, next) {
      if (state != null && next != _written) stop();
    });
    ref.listen<ConnectionsViewState>(connectionsViewProvider, (prev, next) {
      if (state != null && prev != next) stop();
    });
    return null;
  }

  void play() {
    final span = ref.read(connectionsYearSpanProvider).value;
    if (span == null || span.first >= span.last) return;
    final filter = ref.read(connectionsFilterProvider);
    final lower = (filter.startDate?.year ?? span.first).clamp(
      span.first,
      span.last,
    );
    final upper = (filter.endDate?.year ?? span.last).clamp(
      span.first,
      span.last,
    );
    _first = span.first;
    _last = span.last;
    _show(upper >= span.last ? lower : upper + 1, lower: lower);
  }

  void pause() => stop();

  void stop() {
    _cancel();
    state = null;
  }

  /// The page reports each settled load of the graph.
  void loadSettled({required bool failed}) {
    if (state == null) return;
    if (failed) {
      stop();
      return;
    }
    _loaded = true;
    _advance();
  }

  int _lower = 0;

  void _show(int year, {int? lower}) {
    if (lower != null) _lower = lower;
    final filter = ref.read(connectionsFilterProvider);
    final atEnd = year >= _last;
    // The whole span is no filter at all, as the year slider has it.
    final next = atEnd && _lower <= _first
        ? filter.copyWith(clearStartDate: true, clearEndDate: true)
        : filter.copyWith(endDate: DateTime(year, 12, 31));
    _cancel();
    state = atEnd ? null : year;
    _written = next;
    ref.read(connectionsFilterProvider.notifier).state = next;
    if (atEnd) return;
    _beatDone = false;
    _loaded = false;
    _timer = Timer(beat, () {
      _beatDone = true;
      _advance();
    });
  }

  void _advance() {
    final year = state;
    if (year == null || !_beatDone || !_loaded) return;
    _show(year + 1);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

final yearPlayProvider = NotifierProvider.autoDispose<YearPlayNotifier, int?>(
  YearPlayNotifier.new,
);
```

Move the `_lower` field up with the other fields when writing it. Note `play()` on a full span with `lower == span.last` cannot happen (that needs a one-year span, rejected above).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/connections/presentation/providers/year_play_provider_test.dart`
Expected: PASS. If the "outside filter change" test fails because the filter listener fires before `_written` is set, check that `_written` is assigned before the `state =` write to `connectionsFilterProvider` (it is in the code above).

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/presentation/providers/year_play_provider.dart test/features/connections/presentation/providers/year_play_provider_test.dart
git commit -m "feat(connections): play the map year by year"
```

---

### Task 9: Play pill and slider button

**Files:**
- Create: `lib/features/connections/presentation/widgets/year_play_pill.dart`
- Modify: `lib/features/connections/presentation/widgets/year_range_slider.dart`
- Test: `test/features/connections/presentation/widgets/year_play_pill_test.dart`
- Test: `test/features/connections/presentation/widgets/year_range_slider_test.dart`

**Interfaces:**
- Consumes: `yearPlayProvider` (Task 8), `connectionsYearSpanProvider`, `connectionsFilterProvider`, `connections_yearRange_label(first, last)`, `connections_yearPlay_play`, `connections_yearPlay_pause`.
- Produces: `YearPlayButton()` (an `IconButton` keyed `ValueKey('year-play-button')`, play arrow when idle, pause while playing); `YearPlayPill()` (keyed `ValueKey('year-play-pill')`, hidden when the span is null or one year).

- [ ] **Step 1: Write the failing test** (`year_play_pill_test.dart`, harness copied from `year_range_slider_test.dart`'s `_pump`)

```dart
  testWidgets('the pill plays, shows the growing range, and pauses', (
    tester,
  ) async {
    final c = await _pump(tester, const YearPlayPill());
    expect(find.text('Years 2019 to 2024'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    expect(c.read(yearPlayProvider), 2019);
    expect(find.text('Years 2019 to 2019'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    expect(c.read(yearPlayProvider), isNull);
    expect(find.byTooltip('Play years'), findsOneWidget);
  });

  testWidgets('the pill hides on a one-year log', (tester) async {
    await _pump(
      tester,
      const YearPlayPill(),
      span: (first: 2024, last: 2024),
    );
    expect(find.byKey(const ValueKey('year-play-pill')), findsNothing);
  });
```

In `year_range_slider_test.dart` add:

```dart
  testWidgets('the slider has a play button that moves the thumbs', (
    tester,
  ) async {
    final c = await _pump(tester, const YearRangeSlider());
    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.values, const RangeValues(2019, 2019));
    c.read(yearPlayProvider.notifier).pause();
  });
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/presentation/widgets/year_play_pill_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement `year_play_pill.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/year_play_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Play or pause the year-by-year growth of the map.
class YearPlayButton extends ConsumerWidget {
  const YearPlayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playing = ref.watch(yearPlayProvider) != null;
    final notifier = ref.read(yearPlayProvider.notifier);
    return IconButton(
      key: const ValueKey('year-play-button'),
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      tooltip: playing
          ? l10n.connections_yearPlay_pause
          : l10n.connections_yearPlay_play,
      onPressed: playing ? notifier.pause : notifier.play,
    );
  }
}

/// The play control over the canvas, with the years on screen.
class YearPlayPill extends ConsumerWidget {
  const YearPlayPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final span = ref.watch(connectionsYearSpanProvider).value;
    if (span == null || span.first >= span.last) {
      return const SizedBox.shrink();
    }
    final filter = ref.watch(connectionsFilterProvider);
    final lo = (filter.startDate?.year ?? span.first).clamp(
      span.first,
      span.last,
    );
    final hi = (filter.endDate?.year ?? span.last).clamp(span.first, span.last);
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('year-play-pill'),
      shape: const StadiumBorder(),
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const YearPlayButton(),
            Text(
              context.l10n.connections_yearRange_label(lo, hi),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

The pill reads the range from the filter, which play writes each beat, so it needs no separate playing text. In `year_range_slider.dart`, replace the label `Text(...)` with a `Row` holding `Expanded(child: Text(...))` and `const YearPlayButton()`. The thumbs already follow the filter.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/connections/presentation/widgets/`
Expected: PASS. The play tests leave a pending 1200 ms timer; `pause()` at the end (or the container disposing the autoDispose provider) cancels it. If the framework reports a pending timer, add `addTearDown(() => c.read(yearPlayProvider.notifier).pause())`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/presentation/widgets/ test/features/connections/presentation/widgets/
git commit -m "feat(connections): a play control for the year range"
```

---

### Task 10: Page wiring

**Files:**
- Modify: `lib/features/connections/presentation/pages/connections_page.dart`
- Test: `test/features/connections/presentation/pages/connections_page_test.dart`

**Interfaces:**
- Consumes: `LabelPropagation`, `GraphInsights`, `InsightStrip`, `YearPlayPill`, `yearPlayProvider`, `ConnectionsCanvas(highlight:, groupOf:)`, `ConnectionsLegend(highlight:, groupCount:)`, `ViewTab(groupCount:)`, `ConnectionsViewState.withHighlight`.
- Produces: page keys `ValueKey('connections-insights')` (the strip's Positioned child) and the pill from Task 9.

- [ ] **Step 1: Write the failing tests** (append to `connections_page_test.dart`)

```dart
  testWidgets('the insight strip selects and switches to groups', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(find.byKey(const ValueKey('connections-insights')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('insight-strongestPair')));
    await tester.pump();
    expect(
      c.read(connectionsSelectionProvider),
      EdgeSelection(_b('jane'), _b('ken')),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('insight-groups')));
    await tester.tap(find.byKey(const ValueKey('insight-groups')));
    await tester.pump();
    expect(c.read(connectionsViewProvider).highlight, HighlightMode.groups);
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('connections-canvas-paint')),
    );
    final painter = paint.painter! as ConnectionsPainter;
    expect(painter.highlight, HighlightMode.groups);
    expect(painter.groupOf.length, 2);
  });

  testWidgets('the play pill sits on the canvas and a load moves play on', (
    tester,
  ) async {
    final c = await _pump(tester, size: _phone);
    expect(find.byKey(const ValueKey('year-play-pill')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    expect(c.read(yearPlayProvider), 2019);
    await tester.pump(YearPlayNotifier.beat);
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(yearPlayProvider), 2020,
        reason: 'the reload settled and the beat passed');
    c.read(yearPlayProvider.notifier).pause();
  });
```

Check `_pump`'s structure: the graph override returns immediately, so each filter write reloads and settles within a frame. If `find.byKey(ValueKey('connections-canvas-paint'))` sits on a different widget than `CustomPaint` in this codebase, follow how the existing "canvas semantics" test reaches the painter.

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/presentation/pages/connections_page_test.dart`
Expected: the two new tests FAIL (keys not found).

- [ ] **Step 3: Implement**

In `_ConnectionsPageState`:

```dart
  /// Groups and insights for the last graph and focus, so a rebuild reuses
  /// them (label propagation runs once per laid-out graph).
  ConnectionGraph? _storyFrom;
  NodeRef? _storyFocus;
  GraphGroups _groups = GraphGroups.empty;
  List<InsightTile> _insights = const [];

  void _story(ConnectionGraph graph, NodeRef? focus) {
    if (identical(graph, _storyFrom) && focus == _storyFocus) return;
    _storyFrom = graph;
    _storyFocus = focus;
    _groups = LabelPropagation.communities(graph);
    _insights = GraphInsights.of(graph, focus: focus, groups: _groups);
  }
```

In `build`:
- After `if (showCanvas) _syncLayout(...)`, add `if (showCanvas) _story(graph, focus);`.
- In the existing `ref.listen(connectionGraphProvider(budget), ...)` callback, add at the end:

```dart
      if (!next.isLoading) {
        ref.read(yearPlayProvider.notifier).loadSettled(failed: next.hasError);
      }
```

- Pass `highlight: view.highlight, groupOf: _groups.groupOf` to `ConnectionsCanvas`.
- In the canvas `Stack`, add after the canvas:

```dart
          Positioned(
            key: const ValueKey('connections-insights'),
            left: 0,
            right: 0,
            top: 8,
            child: InsightStrip(
              graph: graph,
              tiles: _insights,
              onSelect: (s) =>
                  ref.read(connectionsSelectionProvider.notifier).state = s,
              onGroups: () => ref
                  .read(connectionsViewProvider.notifier)
                  .update((s) => s.withHighlight(HighlightMode.groups)),
            ),
          ),
```

- Move the phone legend and the hidden-nodes chip from `top: 12` to `top: InsightStrip.height + 16`, and the reload error card from `top: 56` to `top: InsightStrip.height + 60`. Pass `highlight: view.highlight, groupCount: _groups.count` to the phone `ConnectionsLegend`.
- Add the pill:

```dart
          Positioned(
            left: 12,
            bottom: bottomInset + 12,
            child: const YearPlayPill(),
          ),
```

- `panel(...)` builds `ViewTab(graph: graph, groupCount: _groups.count)`.

Add imports for the new files. Keep the file under 800 lines (`wc -l`); it starts near 520.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/connections/`
Expected: PASS. Existing tests that tapped at fixed points near the top of the canvas may now hit the strip: re-point them below `InsightStrip.height` rather than removing the strip.

- [ ] **Step 5: Commit**

```bash
git add lib/features/connections/presentation/pages/connections_page.dart test/features/connections/presentation/pages/connections_page_test.dart
git commit -m "feat(connections): show insights, groups and year play on the page"
```

---

### Task 11: Share caption and renderer

**Files:**
- Create: `lib/features/connections/presentation/share/connections_share_caption.dart`
- Create: `lib/features/connections/presentation/share/connections_share_renderer.dart`
- Test: `test/features/connections/presentation/share/connections_share_caption_test.dart`
- Test: `test/features/connections/presentation/share/connections_share_renderer_test.dart`

**Interfaces:**
- Consumes: `ConnectionsPainter` (Task 5 params), `ConnectionKindColors.fromPalette`, `FeatureAccentColors.dark`, `GraphViewport.fittedWithOverhang`, `LayoutFrame` (`positions`, `bounds`), `decodeNodePhoto`, `presetLabel(l10n, id)` from `panel/preset_grid.dart`, `UnitFormatter.formatDateRange(start, end, l10n:)`.
- Produces:
  - `class ConnectionsShareCaption { final String title; final String details; static ConnectionsShareCaption of({required AppLocalizations l10n, required UnitFormatter units, required ConnectionsViewState view, required ConnectionGraph graph, required DiveFilterState filter, required ({int first, int last})? span, required Map<String, String> savedMapNames}); }`
  - `abstract final class ConnectionsShareRenderer { static const Size logicalSize; static const double pixelRatio; static const Color background; static Future<Uint8List> render({required ConnectionGraph graph, required LayoutFrame frame, required HighlightMode highlight, required GraphGroups groups, required ConnectionsShareCaption caption, Map<NodeRef, ui.Image> photos, ui.Image? appIcon}); static Future<Uint8List> renderWithAssets({...same minus photos and appIcon}); }`

- [ ] **Step 1: Write the failing caption tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_caption.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final units = UnitFormatter(const AppSettings());
  const ana = NodeRef(ConnectionKind.buddy, 'ana');
  final graph = ConnectionGraph(
    nodes: const [ConnectionNode(ref: ana, label: 'Ana', diveCount: 3)],
    edges: const [],
  );

  ConnectionsShareCaption caption(
    ConnectionsViewState view, {
    DiveFilterState filter = const DiveFilterState(),
    Map<String, String> saved = const {},
  }) => ConnectionsShareCaption.of(
    l10n: l10n,
    units: units,
    view: view,
    graph: graph,
    filter: filter,
    span: (first: 2009, last: 2026),
    savedMapNames: saved,
  );

  test('a preset map is named by its preset, over all dives', () {
    final c = caption(ConnectionsViewState.initial);
    expect(c.title, 'Dive circle');
    expect(c.details, 'All dives, 2009 to 2026. 1 nodes and 0 connections');
  });

  test('around mode names the centre', () {
    final c = caption(ConnectionsViewState.initial.centreOn(ana));
    expect(c.title, 'Around Ana');
  });

  test('a saved map uses its name, a custom map says so', () {
    final spec = ConnectionPresets.byId('where')!.spec;
    expect(
      caption(
        ConnectionsViewState.initial.applySavedMap('m1', spec),
        saved: {'m1': 'Bonaire crew'},
      ).title,
      'Bonaire crew',
    );
    expect(
      caption(ConnectionsViewState.initial.showMap(spec)).title,
      'Custom map',
    );
  });

  test('a date filter shows its range through the unit formatter', () {
    final filter = DiveFilterState(
      startDate: DateTime(2014, 1, 1),
      endDate: DateTime(2019, 12, 31),
    );
    final c = caption(ConnectionsViewState.initial, filter: filter);
    final range = units.formatDateRange(
      filter.startDate,
      filter.endDate,
      l10n: l10n,
    );
    expect(c.details, '$range. 1 nodes and 0 connections');
  });
}
```

Replace `'Dive circle'` and `'1 nodes and 0 connections'` with the exact English values of `connections_preset_circle` and `connections_semantics_summary(1, 0)` from `app_en.arb`, and check where `AppSettings` is defined (`grep -rn "class AppSettings" lib`) and fix that import.

- [ ] **Step 2: Write the failing renderer tests**

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_caption.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_renderer.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

int _u32(Uint8List b, int at) =>
    (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

void main() {
  final graph = ConnectionGraph(
    nodes: [
      ConnectionNode(ref: _b('a'), label: 'Ann', diveCount: 5),
      ConnectionNode(
        ref: _b('b'),
        label: 'Bob',
        diveCount: 2,
        photo: Uint8List.fromList([1, 2, 3]), // not an image
      ),
    ],
    edges: [
      ConnectionEdge(
        source: _b('a'),
        target: _b('b'),
        weight: 3,
        firstDiveAt: DateTime.utc(2020),
        lastDiveAt: DateTime.utc(2024),
      ),
    ],
  );
  final frame = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(0, 0),
    _b('b'): const GraphPoint(120, 40),
  }, settled: true);
  const caption = ConnectionsShareCaption(
    title: 'Dive circle',
    details: 'All dives, 2009 to 2026. 2 nodes and 1 connections',
  );

  testWidgets('renders a 1080 x 1350 PNG', (tester) async {
    final png = await tester.runAsync(
      () => ConnectionsShareRenderer.render(
        graph: graph,
        frame: frame,
        highlight: HighlightMode.groups,
        groups: LabelPropagation.communities(graph),
        caption: caption,
      ),
    );
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
    expect(_u32(png, 16), 1080);
    expect(_u32(png, 20), 1350);
  });

  testWidgets('a photo that will not decode still renders', (tester) async {
    final png = await tester.runAsync(
      () => ConnectionsShareRenderer.renderWithAssets(
        graph: graph,
        frame: frame,
        highlight: HighlightMode.byKind,
        groups: GraphGroups.empty,
        caption: caption,
        appIconAsset: 'assets/icon/missing.png',
      ),
    );
    expect(_u32(png!, 16), 1080);
  });
}
```

`renderWithAssets` takes an `appIconAsset` parameter (default `'assets/icon/icon.png'`) so the missing-asset path is testable. That makes `ConnectionsShareCaption` need a public `const` constructor too, which the interface above allows.

- [ ] **Step 3: Run to see them fail**

Run: `flutter test test/features/connections/presentation/share/`
Expected: compile errors.

- [ ] **Step 4: Implement `connections_share_caption.dart`**

```dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/panel/preset_grid.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The two caption lines under a shared map image: what the map is, then
/// when and how much.
class ConnectionsShareCaption {
  const ConnectionsShareCaption({required this.title, required this.details});

  final String title;
  final String details;

  static ConnectionsShareCaption of({
    required AppLocalizations l10n,
    required UnitFormatter units,
    required ConnectionsViewState view,
    required ConnectionGraph graph,
    required DiveFilterState filter,
    required ({int first, int last})? span,
    required Map<String, String> savedMapNames,
  }) {
    final focus = view.focus;
    final savedName = savedMapNames[view.savedMapId];
    final title = view.mode == ConnectionsMode.around && focus != null
        ? l10n.connections_share_aroundName(
            graph.nodeFor(focus)?.label ?? focus.id,
          )
        : savedName ??
              (view.presetId != null
                  ? presetLabel(l10n, view.presetId!)
                  : l10n.connections_editor_title);
    final range = filter.startDate != null || filter.endDate != null
        ? units.formatDateRange(filter.startDate, filter.endDate, l10n: l10n)
        : span == null
        ? ''
        : l10n.connections_share_allDives(span.first, span.last);
    final counts = l10n.connections_semantics_summary(
      graph.nodes.length,
      graph.edges.length,
    );
    return ConnectionsShareCaption(
      title: title,
      details: range.isEmpty
          ? counts
          : l10n.connections_share_details(range, counts),
    );
  }
}
```

- [ ] **Step 5: Implement `connections_share_renderer.dart`**

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';
import 'package:submersion/features/connections/presentation/canvas/node_metrics.dart';
import 'package:submersion/features/connections/presentation/canvas/node_photo_decoder.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_caption.dart';

const _log = LoggerService('ConnectionsShare');

/// Paints the whole map, offscreen, into a portrait PNG for sharing: the
/// current layout on a fixed deep-water background in every theme, with a
/// caption and the app mark. No selection, zoom or pan.
abstract final class ConnectionsShareRenderer {
  static const Size logicalSize = Size(360, 450);
  static const double pixelRatio = 3;
  static const Color background = Color(0xFF0F1E37);
  static const Color ink = Color(0xFFE6EDF7);
  static const double _captionHeight = 60;

  /// [render] after decoding the graph's buddy photos and the app icon; any
  /// that fail to load are left out (initials, no icon), never an error.
  static Future<Uint8List> renderWithAssets({
    required ConnectionGraph graph,
    required LayoutFrame frame,
    required HighlightMode highlight,
    required GraphGroups groups,
    required ConnectionsShareCaption caption,
    String appIconAsset = 'assets/icon/icon.png',
  }) async {
    final photos = <NodeRef, ui.Image>{};
    ui.Image? icon;
    try {
      for (final n in graph.nodes) {
        final bytes = n.photo;
        if (bytes == null) continue;
        try {
          photos[n.ref] = await decodeNodePhoto(bytes);
        } catch (e) {
          _log.warning('Skipping a buddy photo that did not decode', error: e);
        }
      }
      try {
        final data = await rootBundle.load(appIconAsset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 60,
        );
        icon = (await codec.getNextFrame()).image;
        codec.dispose();
      } catch (e) {
        _log.warning('Share image without the app icon', error: e);
      }
      return await render(
        graph: graph,
        frame: frame,
        highlight: highlight,
        groups: groups,
        caption: caption,
        photos: photos,
        appIcon: icon,
      );
    } finally {
      for (final img in photos.values) {
        img.dispose();
      }
      icon?.dispose();
    }
  }

  static Future<Uint8List> render({
    required ConnectionGraph graph,
    required LayoutFrame frame,
    required HighlightMode highlight,
    required GraphGroups groups,
    required ConnectionsShareCaption caption,
    Map<NodeRef, ui.Image> photos = const {},
    ui.Image? appIcon,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    final size = logicalSize;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final mapSize = Size(size.width, size.height - _captionHeight);
    const r = NodeMetrics.maxRadius;
    final viewport = const GraphViewport().fittedWithOverhang(
      frame.bounds,
      mapSize,
      left: 50,
      top: r,
      right: 50,
      bottom: r + 16,
      margin: 12,
    );
    final palette = FeatureAccentColors.dark;
    canvas.save();
    canvas.clipRect(Offset.zero & mapSize);
    ConnectionsPainter(
      graph: graph,
      frame: frame,
      viewport: viewport,
      colors: ConnectionKindColors.fromPalette(
        palette,
        palette.of('connections') ?? ink,
      ),
      labelStyle: const TextStyle(fontSize: 9, color: ink),
      photos: photos,
      labelZoomThreshold: 0,
      haloColor: background,
      highlight: highlight,
      groupOf: groups.groupOf,
    ).paint(canvas, mapSize);
    canvas.restore();

    _paintCaption(canvas, size, caption, appIcon);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static void _paintCaption(
    Canvas canvas,
    Size size,
    ConnectionsShareCaption caption,
    ui.Image? icon,
  ) {
    final top = size.height - _captionHeight + 10;
    const markWidth = 110.0;
    final textWidth = size.width - 32 - markWidth;
    TextPainter text(String s, TextStyle style) => TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: textWidth);
    final title = text(
      caption.title,
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
    );
    final details = text(
      caption.details,
      TextStyle(fontSize: 10, color: ink.withValues(alpha: 0.75)),
    );
    title.paint(canvas, Offset(16, top));
    details.paint(canvas, Offset(16, top + title.height + 2));

    final name = TextPainter(
      text: const TextSpan(
        text: 'Submersion',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ink),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final right = size.width - 16;
    final nameLeft = right - name.width;
    final markTop = top + 6;
    name.paint(canvas, Offset(nameLeft, markTop + (20 - name.height) / 2));
    if (icon != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(nameLeft - 24, markTop, 20, 20),
        image: icon,
        fit: BoxFit.contain,
      );
    }
    for (final tp in [title, details, name]) {
      tp.dispose();
    }
  }
}
```

The ellipsis `'…'` matches the existing painter's label ellipsis character (U+2026), not a dash. `NodeMetrics.maxRadius` is the constant the canvas's `_fitTarget` already uses. Confirm `LoggerService.warning` takes `error:` as a named parameter (`connections_view_provider.dart` uses it that way).

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/connections/presentation/share/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/connections/presentation/share/ test/features/connections/presentation/share/
git commit -m "feat(connections): render the map as a share image"
```

---

### Task 12: Share action and app bar button

**Files:**
- Create: `lib/features/connections/presentation/share/connections_share_action.dart`
- Modify: `lib/features/connections/presentation/pages/connections_page.dart`
- Test: `test/features/connections/presentation/share/connections_share_action_test.dart`
- Test: `test/features/connections/presentation/pages/connections_page_test.dart`

**Interfaces:**
- Consumes: `showExportDestinationSheet`, `ExportDestination`, `saveAndShareFileBytes`, `saveImageToFile`, `shareAnchorFrom` (`lib/core/utils/share_anchor.dart`), Task 11's renderer and caption, `savedConnectionMapsProvider`, `connectionsYearSpanProvider`, `settingsProvider`.
- Produces:
  - `typedef ConnectionsShareImage = Future<void> Function(List<int> bytes, String fileName, Rect? origin);`
  - `typedef ConnectionsSaveImage = Future<String?> Function(List<int> bytes, String fileName);`
  - `Future<void> shareConnectionsImage(BuildContext context, {required Future<Uint8List> Function() render, ConnectionsShareImage? share, ConnectionsSaveImage? save, DateTime? now})`
  - `String connectionsShareFileName(DateTime now)` returning `submersion-connections-yyyyMMdd.png`.
  - App bar `IconButton` keyed `ValueKey('connections-share')`.

- [ ] **Step 1: Write the failing action tests**

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_action.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> run(
    WidgetTester tester, {
    required String choice,
    required Future<Uint8List> Function() render,
    List<String>? shared,
    List<String>? saved,
    String? saveResult = 'x',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => shareConnectionsImage(
                context,
                render: render,
                now: DateTime(2026, 10, 5),
                share: (bytes, name, origin) async => shared?.add(name),
                save: (bytes, name) async {
                  saved?.add(name);
                  return saveResult;
                },
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    if (choice.isNotEmpty) {
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('share hands the PNG to the share sheet with a dated name', (
    tester,
  ) async {
    final shared = <String>[];
    await run(
      tester,
      choice: 'Share',
      render: () async => Uint8List(4),
      shared: shared,
    );
    expect(shared, ['submersion-connections-20261005.png']);
  });

  testWidgets('save writes the file; a cancelled save says nothing', (
    tester,
  ) async {
    final saved = <String>[];
    await run(
      tester,
      choice: 'Save to File',
      render: () async => Uint8List(4),
      saved: saved,
      saveResult: null,
    );
    expect(saved, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('dismissing the sheet renders nothing', (tester) async {
    var rendered = 0;
    await run(
      tester,
      choice: '',
      render: () async {
        rendered++;
        return Uint8List(4);
      },
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(rendered, 0);
  });

  testWidgets('a render failure shows a snackbar', (tester) async {
    await run(
      tester,
      choice: 'Share',
      render: () async => throw StateError('boom'),
    );
    expect(find.text("Couldn't create the image"), findsOneWidget);
  });
}
```

Confirm the sheet's option labels (`transfer_export_optionShareTitle` is "Share", `transfer_export_optionSaveTitle` is "Save to File") and that the title text from Task 1 does not also read "Share" (it reads "Share map image", so `find.text('Share')` stays unique).

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/connections/presentation/share/connections_share_action_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement `connections_share_action.dart`**

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

const _log = LoggerService('ConnectionsShare');

typedef ConnectionsShareImage =
    Future<void> Function(List<int> bytes, String fileName, Rect? origin);
typedef ConnectionsSaveImage =
    Future<String?> Function(List<int> bytes, String fileName);

/// The share image's file name, dated so repeated shares do not collide.
String connectionsShareFileName(DateTime now) =>
    'submersion-connections-${DateFormat('yyyyMMdd').format(now)}.png';

/// Asks share or save, renders the map image, and delivers it. Nothing is
/// uploaded. A dismissed sheet renders nothing; a cancelled save is a no-op;
/// a failure is logged and shown in a snackbar.
Future<void> shareConnectionsImage(
  BuildContext context, {
  required Future<Uint8List> Function() render,
  ConnectionsShareImage? share,
  ConnectionsSaveImage? save,
  DateTime? now,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final origin = shareAnchorFrom(context);
  final destination = await showExportDestinationSheet(
    context,
    title: l10n.connections_share_sheetTitle,
  );
  if (destination == null) return;
  try {
    final bytes = await render();
    final name = connectionsShareFileName(now ?? DateTime.now());
    switch (destination) {
      case ExportDestination.share:
        await (share ?? _share)(bytes, name, origin);
      case ExportDestination.saveToFile:
        await (save ?? saveImageToFile)(bytes, name);
    }
  } catch (e, st) {
    _log.error('Could not create the connections image', error: e, stackTrace: st);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.connections_share_failed)),
    );
  }
}

Future<void> _share(List<int> bytes, String name, Rect? origin) =>
    saveAndShareFileBytes(bytes, name, 'image/png', sharePositionOrigin: origin);
```

Check `LoggerService` has an `error(...)` method with `error:` and `stackTrace:` named parameters (`grep -n "void error" lib/core/services/logger_service.dart`); use `warning` if `error` differs. Check `DateFormat` here: it builds a file name, not a date shown to the diver, so `UnitFormatter` does not apply.

- [ ] **Step 4: Run the action tests**

Run: `flutter test test/features/connections/presentation/share/connections_share_action_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the page button test** (append to `connections_page_test.dart`)

```dart
  testWidgets('the share button opens the share sheet, and waits for a map', (
    tester,
  ) async {
    await _pump(tester);
    final button = find.byKey(const ValueKey('connections-share'));
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Share map image'), findsOneWidget);
    expect(find.text('Save to File'), findsOneWidget);
  });

  testWidgets('no map, no share', (tester) async {
    await _pump(tester, graph: (ref, budget) => ConnectionGraph.empty);
    final button = find.byKey(const ValueKey('connections-share'));
    expect(tester.widget<IconButton>(button).onPressed, isNull);
  });
```

- [ ] **Step 6: Implement the button**

In `connections_page.dart` add:

```dart
  Future<void> _share(ConnectionGraph graph, ConnectionsViewState view) {
    final l10n = context.l10n;
    final caption = ConnectionsShareCaption.of(
      l10n: l10n,
      units: UnitFormatter(ref.read(settingsProvider)),
      view: view,
      graph: graph,
      filter: ref.read(connectionsFilterProvider),
      span: ref.read(connectionsYearSpanProvider).value,
      savedMapNames: {
        for (final m in ref.read(savedConnectionMapsProvider).value ?? const [])
          m.id: m.name,
      },
    );
    final frame = _layout.frame;
    final groups = _groups;
    return shareConnectionsImage(
      context,
      render: () => ConnectionsShareRenderer.renderWithAssets(
        graph: graph,
        frame: frame,
        highlight: view.highlight,
        groups: groups,
        caption: caption,
      ),
    );
  }
```

and as the first app bar action:

```dart
          IconButton(
            key: const ValueKey('connections-share'),
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.connections_share_tooltip,
            onPressed: showCanvas ? () => _share(graph, view) : null,
          ),
```

`showCanvas`, `graph` and `view` are already locals in `build`; the `actions:` list is built after them.

- [ ] **Step 7: Run tests**

Run: `flutter test test/features/connections/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/connections/ test/features/connections/
git commit -m "feat(connections): share or save the map as an image"
```

---

### Task 13: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: only files this branch touched change, if any; commit them with the step 5 commit.

- [ ] **Step 2: Analyze**

Run: `flutter analyze > "$SCRATCH/analyze.log" 2>&1; echo EXIT $?` (with `SCRATCH` set to the session scratchpad)
Expected: `EXIT 0`, "No issues found!".

- [ ] **Step 3: Guards and feature tests**

Run: `flutter test test/architecture/ test/features/connections/ test/l10n/`
Expected: all pass. The architecture guards scan all of `lib/` and catch new files that break repo rules (for example a test that leaves global state behind). The l10n guards catch orphaned or untranslated keys and the `=1` digit rule.

- [ ] **Step 4: Line count check**

Run: `wc -l lib/features/connections/presentation/pages/connections_page.dart lib/features/connections/presentation/canvas/connections_painter.dart`
Expected: both under 800.

- [ ] **Step 5: Commit any format changes**

```bash
git status --porcelain
git add <only files this branch changed>
git commit -m "style(connections): format"
```

Skip the commit when `git status` is clean.
