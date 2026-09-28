# Connections Explorer Revision 2 Implementation Plan

> **Renumbered at merge (2026-09-26):** the saved-maps rung this plan calls 232 shipped as **235**, because `main` took 232 (trip cylinders, #2331), 233 (MacDive source diver key, #1921) and 234 (equipment sharing, #2046) first. The test file is `migration_v235_connection_maps_test.dart`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the pair-of-kinds Connections page into a two-mode explorer (Around one entity across every kind, up to 3 hops; Whole map over any set of kinds and links) with nine presets, synced saved maps, a tabbed desktop panel and phone sheet, a canvas that no longer clips, and an animated refocus.

**Architecture:** The co-occurrence engine stays: every edge is still `buildEdgeSql` over two kinds' dive membership. A map is the union of one edge query per chosen link; an around view discovers nodes breadth-first from the focus and then loads every edge among the discovered nodes. A new immutable `ConnectionsViewState` (mode, map spec, around settings, focus) replaces the lens and focus providers and persists device-locally as JSON. Saved maps are a new synced diver-owned table at schema rung 232. The page becomes canvas plus a 340 px `ConnectionsPanel` (View, Filter, Details tabs) on wide screens and the same tabs in a draggable sheet on phones.

**Tech Stack:** Flutter, Drift (raw `customSelect` plus one new table), Riverpod 3 (`package:submersion/core/providers/provider.dart`), go_router, shared_preferences, equatable, flutter_test with an in-memory Drift database.

**Spec:** `docs/superpowers/specs/2026-09-25-connections-explorer-design.md`, section "Revision 2" (binding). Phase 1 (the sections before it) is implemented on this branch; Revision 2 wins wherever they conflict.

**Already done, not in this plan:** the nine phase 1 review fixes the spec lists under "Carried-in fixes" landed in `20bfaf3dc77`.

**Branch:** `ericgriffin/data-connectivity-viz-8aec39`, merged with `main` at `6ea393a1760` (schema 231; the Statistics feature is now `lib/features/insights/`). PR body when it opens: `Closes #2322`, `Refs #2321`.

## Global Constraints

- No em-dashes or en-dashes as punctuation anywhere (code, comments, docs, commit messages, ARB values); no emojis; no mention of Claude, Claude Code or Anthropic in any commit, PR or file.
- Files stay under 800 lines; aim for 200 to 400. Domain and layout files import nothing from Flutter.
- Every entity and value type has `copyWith` where it has fields a caller changes; immutability throughout.
- Every aggregate over `dives` goes through `diveScopeSql` (which applies `DiveStatsScope`) inside the same method as the SQL, so `test/core/database/dive_stats_scope_census_test.dart` sees both in one chunk.
- Every provider that calls a repository subscribes with `ref.invalidateSelfWhen(<tick>)` and gets a case in `test/architecture/provider_tick_build_smoke_test.dart`.
- Dates only through `UnitFormatter`; strings only through `context.l10n`; every new key in all eleven ARB files (`ar de en es fr he hu it nl pt zh`); French and Portuguese plurals interpolate the count in the `=1` branch; Arabic and Hebrew keep word forms; Portuguese avoids the accent twins the diacritics guard flags (use "elemento", never "nó").
- `lib/` imports use `package:submersion/...` (the repo lints `always_use_package_imports`).
- Schema rung for this plan: **232**. If `main` has moved past 231 when Task 5 starts, take the next free rung and renumber everywhere this plan says 232.
- Presets, exactly (Revision 2 table): circle, where, trips, life, gear, centers, travel, reef, gearRoad.
- Around default kinds: buddy, site, trip, species, equipment, diveCenter on; tag, diveType, diveComputer, course off. Hops 1 to 3, default 1.
- Minimum shared dives: 1 to 10, default 1, map mode only.
- Animation: 450 ms, `Curves.easeInOutCubic`; `MediaQuery.disableAnimationsOf(context)` snaps; the page's first load snaps.
- Run `dart format .` before every commit; `flutter analyze` must report no issues (infos included) before the last commit; run `test/architecture/` after adding any file under `lib/`.
- Run tests with `TMPDIR=/tmp` if `/Volumes/fltmp` is over 80% full (`df -h /Volumes/fltmp`).
- Commit after every task with a plain `feat(connections): ...`, `refactor(...)` or `test(...)` message, no trailers.

## Review Focus

1. **Around mode on a large log at 3 hops with every kind on.** Discovery can reach the whole log; the page must stay responsive and trim to the budget ranked by hop. Task 4 adds a test that hop-3 entities never displace hop-1 ones, and Task 22's benchmark bounds the load time.
2. **A saved map written by a newer build with a kind this build does not know.** It must be skipped, never deleted or crash the grid. Task 7 pins `SavedConnectionMap.tryParse` returning null and the repository keeping the row.
3. **Around mode with no centre chosen.** A diver who switches modes before searching must see a prompt, not an empty canvas or a spinner. Task 15's page test covers the prompt.
4. **Editing a preset then saving it.** The saved map must store the edited spec, and the preset card must show "edited" until another card is chosen. Task 13 tests both.
5. **A deep link to an entity that has no dives in scope.** Around mode must centre on it alone with zero connections rather than an error. Task 4 keeps the phase 1 `labelOnly` fallback and tests it for the new loader.

## File Structure

```
lib/features/connections/
  domain/views/kind_link.dart              KindLink (unordered pair of kinds)
  domain/views/map_spec.dart               MapSpec: kinds, links, minimum; edit ops; JSON
  domain/views/connection_presets.dart     ConnectionPreset and the nine presets
  domain/views/connections_view_state.dart ConnectionsMode, ConnectionsViewState, JSON
  domain/views/graph_summary.dart          MapSummary / AroundSummary from a graph
  domain/entities/saved_connection_map.dart
  domain/layout/layout_morph.dart          frame interpolation with appear factors
  data/connections_reader.dart             edge, node, label and search reads
  data/connections_map_loader.dart         MapSpec -> graph
  data/connections_around_loader.dart      breadth-first around load
  data/repositories/connection_map_repository.dart
  presentation/connections_links.dart      deep-link location builders + route args
  presentation/providers/connections_view_provider.dart
  presentation/providers/saved_connection_maps_provider.dart
  presentation/canvas/camera_tween.dart
  presentation/canvas/connection_kind_icons.dart
  presentation/panel/connections_panel.dart     tab host (wide) + sheet body (compact)
  presentation/panel/view_tab.dart
  presentation/panel/mode_switch.dart
  presentation/panel/preset_grid.dart
  presentation/panel/map_editor.dart
  presentation/panel/save_map_dialog.dart
  presentation/panel/around_controls.dart
  presentation/panel/entity_search_field.dart
  presentation/panel/summary_block.dart
  presentation/panel/filter_tab.dart
  presentation/panel/details_tab.dart
lib/features/dive_log/presentation/widgets/active_filter_chips.dart  (extracted)
```

Deleted by the end: `domain/lenses/connection_lens.dart`, `domain/entities/connection_query.dart`, `presentation/providers/connections_lens_provider.dart`, `presentation/widgets/lens_chip_row.dart`, `presentation/widgets/connections_filter_bar.dart`, `presentation/widgets/selection_panel.dart`, `presentation/widgets/selection_card.dart`, and their tests.

Modified: `data/connections_edge_sql.dart`, `data/connections_node_sql.dart`, `data/repositories/connections_repository.dart`, `domain/entities/connection_node.dart`, `domain/entities/connection_graph.dart`, `domain/layout/{layout_frame,layout_seed,whole_web_layout,radial_layout}.dart`, `presentation/providers/{connections_providers,connections_selection_provider,connections_layout_controller}.dart`, `presentation/canvas/{graph_viewport,label_collision,connections_painter,connections_canvas}.dart`, `presentation/pages/connections_page.dart`, `presentation/widgets/selection_details.dart`, `lib/core/database/database.dart`, sync registration files (Task 6), `lib/core/router/app_router.dart`, six detail pages (Task 21), `lib/features/dive_log/presentation/widgets/dive_list_content.dart`, eleven ARB files.

---

### Task 1: View domain: KindLink, MapSpec, presets, view state

**Files:**
- Create: `lib/features/connections/domain/views/kind_link.dart`
- Create: `lib/features/connections/domain/views/map_spec.dart`
- Create: `lib/features/connections/domain/views/connection_presets.dart`
- Create: `lib/features/connections/domain/views/connections_view_state.dart`
- Test: `test/features/connections/domain/views/map_spec_test.dart`
- Test: `test/features/connections/domain/views/connections_view_state_test.dart`

**Interfaces:**
- Consumes: `ConnectionKind` (`fromName`, enum `index`), `NodeRef` (`wire`, `parse`).
- Produces:
  - `KindLink(ConnectionKind a, ConnectionKind b)`, unordered (canonical: lower `index` first), `isSameKind`, `touches(kind)`, `wire` (`"buddy-site"`), `KindLink.parse(String?)`.
  - `MapSpec({required Set<ConnectionKind> kinds, required Set<KindLink> links, int minSharedDives = 1})`, `MapSpec.of(kinds, links)`, `withKind(k)`, `withoutKind(k)`, `toggleLink(link)`, `withMinimum(n)`, `possibleLinks` (every pair among `kinds` incl. same-kind, canonical order), `toJson()`, `static MapSpec? fromJson(Object?)`.
  - `ConnectionPreset({required String id, required MapSpec spec})`, `ConnectionPresets.all` (nine, in table order), `ConnectionPresets.byId(String?)`.
  - `enum ConnectionsMode { around, map }`
  - `ConnectionsViewState({mode, mapSpec, presetId, editedFromPresetId, savedMapId, focus, aroundKinds, hops})`, `ConnectionsViewState.initial`, `kDefaultAroundKinds`, `isAroundWithoutFocus`, `applyPreset(preset)`, `applySavedMap(id, spec)`, `editMap(MapSpec)`, `centreOn(NodeRef)`, `withMode(mode)`, `withAroundKinds(set)`, `withHops(n)`, `toJson()`, `static ConnectionsViewState? fromJson(Object?)`, `static ConnectionsViewState fromLegacyLens(String?)`, `copyWith`.

- [ ] **Step 1: Write the failing tests**

`test/features/connections/domain/views/map_spec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

const _b = ConnectionKind.buddy;
const _s = ConnectionKind.site;
const _sp = ConnectionKind.species;
const _t = ConnectionKind.trip;

void main() {
  group('KindLink', () {
    test('is unordered and canonical', () {
      expect(KindLink(_s, _b), KindLink(_b, _s));
      expect(KindLink(_s, _b).a, _b);
      expect(KindLink(_s, _b).wire, 'buddy-site');
      expect(KindLink.parse('site-buddy'), KindLink(_b, _s));
      expect(KindLink.parse('buddy-unicorn'), isNull);
      expect(KindLink.parse(null), isNull);
      expect(KindLink(_b, _b).isSameKind, isTrue);
      expect(KindLink(_b, _s).touches(_s), isTrue);
      expect(KindLink(_b, _s).touches(_t), isFalse);
    });
  });

  group('MapSpec', () {
    test('ticking a kind links it to the kinds already on, not to itself', () {
      final spec = MapSpec.of({_b, _s}, {KindLink(_b, _s)}).withKind(_sp);
      expect(spec.kinds, {_b, _s, _sp});
      expect(spec.links, {
        KindLink(_b, _s),
        KindLink(_b, _sp),
        KindLink(_s, _sp),
      });
    });

    test('the first kind ticked gets no links', () {
      final spec = MapSpec.of(const {}, const {}).withKind(_b);
      expect(spec.kinds, {_b});
      expect(spec.links, isEmpty);
    });

    test('unticking a kind drops every link that touches it', () {
      final spec = MapSpec.of(
        {_b, _s, _sp},
        {KindLink(_b, _s), KindLink(_s, _sp), KindLink(_sp, _sp)},
      ).withoutKind(_sp);
      expect(spec.kinds, {_b, _s});
      expect(spec.links, {KindLink(_b, _s)});
    });

    test('toggleLink adds and removes, ignoring kinds that are off', () {
      final spec = MapSpec.of({_b, _s}, const {});
      final on = spec.toggleLink(KindLink(_b, _b));
      expect(on.links, {KindLink(_b, _b)});
      expect(on.toggleLink(KindLink(_b, _b)).links, isEmpty);
      expect(identical(spec.toggleLink(KindLink(_b, _t)), spec), isTrue);
    });

    test('withMinimum clamps to 1..10', () {
      final spec = MapSpec.of({_b}, const {});
      expect(spec.withMinimum(0).minSharedDives, 1);
      expect(spec.withMinimum(4).minSharedDives, 4);
      expect(spec.withMinimum(99).minSharedDives, 10);
    });

    test('possibleLinks lists every pair including same-kind, stably', () {
      final spec = MapSpec.of({_s, _b}, const {});
      expect(spec.possibleLinks, [
        KindLink(_b, _b),
        KindLink(_b, _s),
        KindLink(_s, _s),
      ]);
    });

    test('JSON round-trips and rejects unknown kinds', () {
      final spec = MapSpec.of(
        {_b, _s},
        {KindLink(_b, _s)},
      ).withMinimum(3);
      expect(MapSpec.fromJson(spec.toJson()), spec);
      expect(
        MapSpec.fromJson({
          'kinds': ['buddy', 'unicorn'],
          'links': <String>[],
          'min': 1,
        }),
        isNull,
      );
      expect(MapSpec.fromJson('garbage'), isNull);
      expect(MapSpec.fromJson(null), isNull);
    });

    test('a link whose kinds are not on is dropped on construction', () {
      final spec = MapSpec(kinds: {_b}, links: {KindLink(_b, _s)});
      expect(spec.links, isEmpty);
    });
  });

  group('presets', () {
    test('nine presets in table order with the table kinds and links', () {
      expect(ConnectionPresets.all.map((p) => p.id), [
        'circle',
        'where',
        'trips',
        'life',
        'gear',
        'centers',
        'travel',
        'reef',
        'gearRoad',
      ]);
      final reef = ConnectionPresets.byId('reef')!;
      expect(reef.spec.kinds, {_s, _sp, ConnectionKind.diveType});
      expect(reef.spec.links, {
        KindLink(_s, _sp),
        KindLink(_sp, ConnectionKind.diveType),
        KindLink(_s, ConnectionKind.diveType),
      });
      expect(ConnectionPresets.byId('circle')!.spec.links, {
        KindLink(_b, _b),
      });
      expect(ConnectionPresets.byId('nope'), isNull);
      for (final p in ConnectionPresets.all) {
        expect(p.spec.minSharedDives, 1);
      }
    });
  });
}
```

`test/features/connections/domain/views/connections_view_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';

const _jane = NodeRef(ConnectionKind.buddy, 'jane');

void main() {
  test('initial is the Dive circle preset in map mode', () {
    final s = ConnectionsViewState.initial;
    expect(s.mode, ConnectionsMode.map);
    expect(s.presetId, 'circle');
    expect(s.mapSpec, ConnectionPresets.byId('circle')!.spec);
    expect(s.aroundKinds, kDefaultAroundKinds);
    expect(s.hops, 1);
    expect(s.focus, isNull);
  });

  test('default around kinds are the six common ones', () {
    expect(kDefaultAroundKinds, {
      ConnectionKind.buddy,
      ConnectionKind.site,
      ConnectionKind.trip,
      ConnectionKind.species,
      ConnectionKind.equipment,
      ConnectionKind.diveCenter,
    });
  });

  test('editing a preset clears it and remembers where it came from', () {
    final edited = ConnectionsViewState.initial
        .applyPreset(ConnectionPresets.byId('travel')!)
        .editMap(
          ConnectionPresets.byId('travel')!.spec.toggleLink(
            KindLink(ConnectionKind.buddy, ConnectionKind.site),
          ),
        );
    expect(edited.presetId, isNull);
    expect(edited.editedFromPresetId, 'travel');
    final again = edited.applyPreset(ConnectionPresets.byId('reef')!);
    expect(again.presetId, 'reef');
    expect(again.editedFromPresetId, isNull);
  });

  test('applying a saved map selects it and clears preset marks', () {
    final s = ConnectionsViewState.initial.applySavedMap(
      'm1',
      ConnectionPresets.byId('where')!.spec,
    );
    expect(s.savedMapId, 'm1');
    expect(s.presetId, isNull);
    expect(s.editedFromPresetId, isNull);
    expect(s.mode, ConnectionsMode.map);
  });

  test('centreOn switches to around mode', () {
    final s = ConnectionsViewState.initial.centreOn(_jane);
    expect(s.mode, ConnectionsMode.around);
    expect(s.focus, _jane);
    expect(s.isAroundWithoutFocus, isFalse);
    expect(
      ConnectionsViewState.initial
          .withMode(ConnectionsMode.around)
          .isAroundWithoutFocus,
      isTrue,
    );
  });

  test('hops clamp to 1..3', () {
    expect(ConnectionsViewState.initial.withHops(0).hops, 1);
    expect(ConnectionsViewState.initial.withHops(3).hops, 3);
    expect(ConnectionsViewState.initial.withHops(7).hops, 3);
  });

  test('JSON round-trips; garbage parses to null', () {
    final s = ConnectionsViewState.initial
        .centreOn(_jane)
        .withHops(2)
        .withAroundKinds({ConnectionKind.buddy, ConnectionKind.tag});
    expect(ConnectionsViewState.fromJson(s.toJson()), s);
    expect(ConnectionsViewState.fromJson('nope'), isNull);
    expect(ConnectionsViewState.fromJson({'mode': 'sideways'}), isNull);
  });

  test('legacy lens values migrate', () {
    expect(ConnectionsViewState.fromLegacyLens('where').presetId, 'where');
    final custom = ConnectionsViewState.fromLegacyLens('custom:equipment:trip');
    expect(custom.presetId, isNull);
    expect(custom.mapSpec.kinds, {
      ConnectionKind.equipment,
      ConnectionKind.trip,
    });
    expect(custom.mapSpec.links, {
      KindLink(ConnectionKind.equipment, ConnectionKind.trip),
    });
    expect(
      ConnectionsViewState.fromLegacyLens('custom:equipment:equipment')
          .mapSpec
          .links,
      {KindLink(ConnectionKind.equipment, ConnectionKind.equipment)},
    );
    expect(ConnectionsViewState.fromLegacyLens(null), ConnectionsViewState.initial);
    expect(ConnectionsViewState.fromLegacyLens('x:y'), ConnectionsViewState.initial);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/domain/views/`
Expected: FAIL, the imports do not resolve.

- [ ] **Step 3: Write the four files**

`lib/features/connections/domain/views/kind_link.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// An unordered pair of kinds whose entities are joined when they share a
/// dive. Stored canonically (lower enum index first) so `KindLink(a, b)` and
/// `KindLink(b, a)` are the same link.
class KindLink extends Equatable {
  factory KindLink(ConnectionKind x, ConnectionKind y) =>
      x.index <= y.index ? KindLink._(x, y) : KindLink._(y, x);

  const KindLink._(this.a, this.b);

  final ConnectionKind a;
  final ConnectionKind b;

  bool get isSameKind => a == b;

  bool touches(ConnectionKind kind) => a == kind || b == kind;

  /// `a-b` with enum names, for JSON.
  String get wire => '${a.name}-${b.name}';

  static KindLink? parse(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 2) return null;
    final x = ConnectionKind.fromName(parts[0]);
    final y = ConnectionKind.fromName(parts[1]);
    if (x == null || y == null) return null;
    return KindLink(x, y);
  }

  @override
  List<Object?> get props => [a, b];

  @override
  String toString() => wire;
}
```

`lib/features/connections/domain/views/map_spec.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';

/// What the whole map shows: which kinds are nodes, which pairs of kinds are
/// joined by lines, and the fewest shared dives a line needs.
///
/// Invariant: every link's kinds are in [kinds]; the constructor drops any
/// link that breaks it.
class MapSpec extends Equatable {
  MapSpec({
    required Set<ConnectionKind> kinds,
    required Set<KindLink> links,
    int minSharedDives = 1,
  }) : kinds = Set.unmodifiable(kinds),
       links = Set.unmodifiable(
         links.where((l) => kinds.contains(l.a) && kinds.contains(l.b)),
       ),
       minSharedDives = minSharedDives.clamp(minMinimum, maxMinimum);

  factory MapSpec.of(Set<ConnectionKind> kinds, Set<KindLink> links) =>
      MapSpec(kinds: kinds, links: links);

  static const int minMinimum = 1;
  static const int maxMinimum = 10;

  final Set<ConnectionKind> kinds;
  final Set<KindLink> links;
  final int minSharedDives;

  /// Adds [kind] and links it to every kind already on. A same-kind link
  /// is never added automatically.
  MapSpec withKind(ConnectionKind kind) {
    if (kinds.contains(kind)) return this;
    return MapSpec(
      kinds: {...kinds, kind},
      links: {...links, for (final k in kinds) KindLink(k, kind)},
      minSharedDives: minSharedDives,
    );
  }

  MapSpec withoutKind(ConnectionKind kind) {
    if (!kinds.contains(kind)) return this;
    return MapSpec(
      kinds: {...kinds}..remove(kind),
      links: links.where((l) => !l.touches(kind)).toSet(),
      minSharedDives: minSharedDives,
    );
  }

  /// Adds or removes [link]; a link whose kinds are not both on is ignored.
  MapSpec toggleLink(KindLink link) {
    if (!kinds.contains(link.a) || !kinds.contains(link.b)) return this;
    final next = {...links};
    if (!next.remove(link)) next.add(link);
    return MapSpec(kinds: kinds, links: next, minSharedDives: minSharedDives);
  }

  MapSpec withMinimum(int n) =>
      MapSpec(kinds: kinds, links: links, minSharedDives: n);

  /// Every pair among [kinds], same-kind included, in enum order.
  List<KindLink> get possibleLinks {
    final sorted = kinds.toList()..sort((x, y) => x.index.compareTo(y.index));
    return [
      for (var i = 0; i < sorted.length; i++)
        for (var j = i; j < sorted.length; j++) KindLink(sorted[i], sorted[j]),
    ];
  }

  Map<String, Object?> toJson() {
    final sortedKinds = kinds.toList()
      ..sort((x, y) => x.index.compareTo(y.index));
    final sortedLinks = links.map((l) => l.wire).toList()..sort();
    return {
      'kinds': [for (final k in sortedKinds) k.name],
      'links': sortedLinks,
      'min': minSharedDives,
    };
  }

  /// Null for anything malformed or naming a kind this build does not know.
  static MapSpec? fromJson(Object? json) {
    if (json is! Map) return null;
    final rawKinds = json['kinds'];
    final rawLinks = json['links'];
    final rawMin = json['min'];
    if (rawKinds is! List || rawLinks is! List) return null;
    final kinds = <ConnectionKind>{};
    for (final raw in rawKinds) {
      final k = raw is String ? ConnectionKind.fromName(raw) : null;
      if (k == null) return null;
      kinds.add(k);
    }
    final links = <KindLink>{};
    for (final raw in rawLinks) {
      final l = raw is String ? KindLink.parse(raw) : null;
      if (l == null) return null;
      links.add(l);
    }
    return MapSpec(
      kinds: kinds,
      links: links,
      minSharedDives: rawMin is int ? rawMin : 1,
    );
  }

  @override
  List<Object?> get props => [kinds, links, minSharedDives];
}
```

`lib/features/connections/domain/views/connection_presets.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

class ConnectionPreset extends Equatable {
  const ConnectionPreset({required this.id, required this.spec});

  final String id;
  final MapSpec spec;

  @override
  List<Object?> get props => [id, spec];
}

/// The nine built-in maps, in display order (spec Revision 2, Presets).
class ConnectionPresets {
  const ConnectionPresets._();

  static const _b = ConnectionKind.buddy;
  static const _s = ConnectionKind.site;
  static const _t = ConnectionKind.trip;
  static const _c = ConnectionKind.diveCenter;
  static const _e = ConnectionKind.equipment;
  static const _sp = ConnectionKind.species;
  static const _dt = ConnectionKind.diveType;

  static ConnectionPreset _p(String id, Set<ConnectionKind> kinds, List<KindLink> links) =>
      ConnectionPreset(id: id, spec: MapSpec.of(kinds, links.toSet()));

  static final List<ConnectionPreset> all = List.unmodifiable([
    _p('circle', {_b}, [KindLink(_b, _b)]),
    _p('where', {_b, _s}, [KindLink(_b, _s)]),
    _p('trips', {_b, _t}, [KindLink(_b, _t)]),
    _p('life', {_s, _sp}, [KindLink(_s, _sp)]),
    _p('gear', {_e}, [KindLink(_e, _e)]),
    _p('centers', {_c, _b}, [KindLink(_c, _b)]),
    _p('travel', {_b, _t, _s}, [KindLink(_b, _t), KindLink(_t, _s), KindLink(_b, _s)]),
    _p('reef', {_s, _sp, _dt}, [KindLink(_s, _sp), KindLink(_sp, _dt), KindLink(_s, _dt)]),
    _p('gearRoad', {_e, _t, _c}, [KindLink(_e, _t), KindLink(_t, _c), KindLink(_e, _c)]),
  ]);

  static ConnectionPreset? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
```

`lib/features/connections/domain/views/connections_view_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

enum ConnectionsMode { around, map }

const Set<ConnectionKind> kDefaultAroundKinds = {
  ConnectionKind.buddy,
  ConnectionKind.site,
  ConnectionKind.trip,
  ConnectionKind.species,
  ConnectionKind.equipment,
  ConnectionKind.diveCenter,
};

/// Everything the Connections page shows, in one immutable value. Both
/// modes' settings live here at once, so switching modes restores each side.
class ConnectionsViewState extends Equatable {
  const ConnectionsViewState({
    required this.mode,
    required this.mapSpec,
    this.presetId,
    this.editedFromPresetId,
    this.savedMapId,
    this.focus,
    this.aroundKinds = kDefaultAroundKinds,
    this.hops = 1,
  });

  static final ConnectionsViewState initial = ConnectionsViewState(
    mode: ConnectionsMode.map,
    mapSpec: ConnectionPresets.byId('circle')!.spec,
    presetId: 'circle',
  );

  final ConnectionsMode mode;
  final MapSpec mapSpec;

  /// The preset card currently applied unedited, or null.
  final String? presetId;

  /// The preset the current custom map was edited from; its card shows an
  /// "edited" mark until another card is chosen.
  final String? editedFromPresetId;

  /// The saved map currently applied, or null.
  final String? savedMapId;

  final NodeRef? focus;
  final Set<ConnectionKind> aroundKinds;
  final int hops;

  bool get isAroundWithoutFocus =>
      mode == ConnectionsMode.around && focus == null;

  ConnectionsViewState applyPreset(ConnectionPreset preset) => ConnectionsViewState(
    mode: ConnectionsMode.map,
    mapSpec: preset.spec,
    presetId: preset.id,
    focus: focus,
    aroundKinds: aroundKinds,
    hops: hops,
  );

  ConnectionsViewState applySavedMap(String id, MapSpec spec) => ConnectionsViewState(
    mode: ConnectionsMode.map,
    mapSpec: spec,
    savedMapId: id,
    focus: focus,
    aroundKinds: aroundKinds,
    hops: hops,
  );

  /// Any edit to the map makes it a custom map.
  ConnectionsViewState editMap(MapSpec spec) => ConnectionsViewState(
    mode: ConnectionsMode.map,
    mapSpec: spec,
    editedFromPresetId: presetId ?? editedFromPresetId,
    focus: focus,
    aroundKinds: aroundKinds,
    hops: hops,
  );

  ConnectionsViewState centreOn(NodeRef ref) =>
      copyWith(mode: ConnectionsMode.around, focus: ref);

  ConnectionsViewState withMode(ConnectionsMode m) => copyWith(mode: m);

  ConnectionsViewState withAroundKinds(Set<ConnectionKind> kinds) =>
      copyWith(aroundKinds: Set.unmodifiable(kinds));

  ConnectionsViewState withHops(int n) => copyWith(hops: n.clamp(1, 3));

  ConnectionsViewState copyWith({
    ConnectionsMode? mode,
    MapSpec? mapSpec,
    NodeRef? focus,
    bool clearFocus = false,
    Set<ConnectionKind>? aroundKinds,
    int? hops,
  }) {
    return ConnectionsViewState(
      mode: mode ?? this.mode,
      mapSpec: mapSpec ?? this.mapSpec,
      presetId: presetId,
      editedFromPresetId: editedFromPresetId,
      savedMapId: savedMapId,
      focus: clearFocus ? null : (focus ?? this.focus),
      aroundKinds: aroundKinds ?? this.aroundKinds,
      hops: hops ?? this.hops,
    );
  }

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'map': mapSpec.toJson(),
    'preset': presetId,
    'editedFrom': editedFromPresetId,
    'saved': savedMapId,
    'focus': focus?.wire,
    'aroundKinds': [
      for (final k in (aroundKinds.toList()..sort((a, b) => a.index.compareTo(b.index))))
        k.name,
    ],
    'hops': hops,
  };

  static ConnectionsViewState? fromJson(Object? json) {
    if (json is! Map) return null;
    final mode = ConnectionsMode.values
        .where((m) => m.name == json['mode'])
        .firstOrNull;
    final spec = MapSpec.fromJson(json['map']);
    if (mode == null || spec == null) return null;
    final rawKinds = json['aroundKinds'];
    final kinds = <ConnectionKind>{};
    if (rawKinds is List) {
      for (final r in rawKinds) {
        final k = r is String ? ConnectionKind.fromName(r) : null;
        if (k != null) kinds.add(k);
      }
    }
    final hops = json['hops'];
    return ConnectionsViewState(
      mode: mode,
      mapSpec: spec,
      presetId: json['preset'] is String ? json['preset'] as String : null,
      editedFromPresetId:
          json['editedFrom'] is String ? json['editedFrom'] as String : null,
      savedMapId: json['saved'] is String ? json['saved'] as String : null,
      focus: NodeRef.parse(json['focus'] is String ? json['focus'] as String : null),
      aroundKinds: kinds.isEmpty ? kDefaultAroundKinds : Set.unmodifiable(kinds),
      hops: hops is int ? hops.clamp(1, 3) : 1,
    );
  }

  /// Phase 1 stored a lens id or `custom:<a>:<b>` under
  /// `connections_last_lens`; this turns either into a view.
  static ConnectionsViewState fromLegacyLens(String? value) {
    final preset = ConnectionPresets.byId(value);
    if (preset != null) return initial.applyPreset(preset);
    final parts = value?.split(':');
    if (parts != null && parts.length == 3 && parts[0] == 'custom') {
      final a = ConnectionKind.fromName(parts[1]);
      final b = ConnectionKind.fromName(parts[2]);
      if (a != null && b != null) {
        // Not editMap: a legacy pair must not mark Dive circle as edited.
        return ConnectionsViewState(
          mode: ConnectionsMode.map,
          mapSpec: MapSpec.of({a, b}, {KindLink(a, b)}),
        );
      }
    }
    return initial;
  }

  @override
  List<Object?> get props => [
    mode,
    mapSpec,
    presetId,
    editedFromPresetId,
    savedMapId,
    focus,
    aroundKinds,
    hops,
  ];
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/connections/domain/views/`
Expected: PASS (all tests in both files).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/views test/features/connections/domain/views
git commit -m "feat(connections): view domain with map specs, presets and view state"
```

---

### Task 2: Generalise the edge and node SQL builders

**Files:**
- Modify: `lib/features/connections/data/connections_scope_sql.dart` (add `escapeLike`)
- Modify: `lib/features/connections/data/connections_edge_sql.dart` (replace the file body)
- Modify: `lib/features/connections/data/connections_node_sql.dart` (`buildNodeSql` gains `labelLike`, `limit`)
- Modify: `lib/features/connections/data/repositories/connections_repository.dart` (`_edges` call site only)
- Test: `test/features/connections/data/connections_sql_test.dart`

**Interfaces:**
- Produces:
  - `buildEdgeSql({required ConnectionKind kindA, required ConnectionKind kindB, required String? diverId, required DiveFilterState filter, Iterable<String>? restrictA, Iterable<String>? restrictB, Iterable<String>? excludeB, int minShared = 1})`. Same-kind pairs dedupe with `a.entity_id < b.entity_id` unless only side A is restricted, in which case `b.entity_id <> a.entity_id`. An empty `restrictA` or `restrictB` matches nothing; an empty `excludeB` adds nothing. `minShared > 1` adds `HAVING COUNT(DISTINCT d.id) >= ?`. Params: scope, restrictA, restrictB, excludeB, minShared.
  - `buildNodeSql({..., Iterable<String>? onlyIds, String? labelLike, int? limit})`: `labelLike` is a raw LIKE pattern (already escaped) matched against the label column with `ESCAPE '\'`; `limit` appends `LIMIT ?`. Params: scope, onlyIds, labelLike, limit.
  - `String escapeLike(String text)` escapes `\`, `%` and `_` with a backslash.

- [ ] **Step 1: Update the tests first**

In `test/features/connections/data/connections_sql_test.dart`, replace the test `'a focus pins side a and excludes the focus from side b'` and the test `'restrictTo limits both ends'` with the tests below, and add the `buildNodeSql` and `escapeLike` tests to the `buildNodeSql` group. Add `import 'package:submersion/features/connections/data/connections_scope_sql.dart';` and remove the now-unused `node_ref.dart` import if nothing else uses it.

```dart
    test('restricting only side A spokes out without self pairs', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: 'me',
        filter: const DiveFilterState(),
        restrictA: ['jane'],
      );
      expect(r.sql, contains('a.entity_id IN (?)'));
      expect(r.sql, contains('b.entity_id <> a.entity_id'));
      expect(r.sql, isNot(contains('a.entity_id < b.entity_id')));
      expect(r.params, ['me', 'jane']);
    });

    test('restricting both sides of a same-kind pair dedupes', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: null,
        filter: const DiveFilterState(),
        restrictA: ['x', 'y'],
        restrictB: ['x', 'y'],
      );
      expect(r.sql, contains('a.entity_id IN (?, ?)'));
      expect(r.sql, contains('b.entity_id IN (?, ?)'));
      expect(r.sql, contains('a.entity_id < b.entity_id'));
      expect(r.params, ['x', 'y', 'x', 'y']);
    });

    test('excludeB and minShared bind after the restrictions', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.site,
        diverId: 'me',
        filter: const DiveFilterState(),
        restrictA: ['jane'],
        excludeB: ['s1', 's2'],
        minShared: 3,
      );
      expect(r.sql, contains('b.entity_id NOT IN (?, ?)'));
      expect(r.sql, contains('HAVING COUNT(DISTINCT d.id) >= ?'));
      expect(r.params, ['me', 'jane', 's1', 's2', 3]);
    });

    test('empty restrictions match nothing; empty exclusions add nothing', () {
      final nothing = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.site,
        diverId: null,
        filter: const DiveFilterState(),
        restrictB: const [],
      );
      expect(nothing.sql, contains('0 = 1'));
      final open = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.site,
        diverId: null,
        filter: const DiveFilterState(),
        excludeB: const [],
      );
      expect(open.sql, isNot(contains('NOT IN')));
      expect(open.sql, isNot(contains('HAVING')));
    });
```

Add to the `buildNodeSql` group:

```dart
    test('labelLike and limit bind after onlyIds', () {
      final r = buildNodeSql(
        kind: ConnectionKind.species,
        diverId: 'me',
        filter: const DiveFilterState(),
        onlyIds: ['sp1'],
        labelLike: '%tur%',
        limit: 5,
      );
      expect(r.sql, contains("t.common_name LIKE ? ESCAPE '\\'"));
      expect(r.sql, contains('LIMIT ?'));
      expect(r.params, ['me', 'sp1', '%tur%', 5]);
    });

    test('escapeLike escapes the LIKE metacharacters', () {
      expect(escapeLike(r'50%_off\'), r'50\%\_off\\');
      expect(escapeLike('plain'), 'plain');
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/data/connections_sql_test.dart`
Expected: FAIL to compile, `restrictA`, `labelLike` and `escapeLike` are not defined.

- [ ] **Step 3: Implement the builders**

Append to `lib/features/connections/data/connections_scope_sql.dart`:

```dart
/// Escapes `\`, `%` and `_` so user text matches literally inside a LIKE
/// pattern written with `ESCAPE '\'`.
String escapeLike(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');
```

Replace everything below the imports in `lib/features/connections/data/connections_edge_sql.dart` with:

```dart
/// The co-occurrence query: one row per pair of entities that share at least
/// [minShared] dives in scope, with the distinct dive count and the first and
/// last shared dive time (epoch ms).
///
/// - [restrictA] / [restrictB] limit either side to these ids; an empty list
///   matches nothing.
/// - [excludeB] drops these ids from side B (entities already placed).
/// - A same-kind pair is undirected (`a < b`) unless only side A is
///   restricted: then the rows are spokes from side A, and only self pairs
///   are dropped (`b <> a`).
({String sql, List<Object?> params}) buildEdgeSql({
  required ConnectionKind kindA,
  required ConnectionKind kindB,
  required String? diverId,
  required DiveFilterState filter,
  Iterable<String>? restrictA,
  Iterable<String>? restrictB,
  Iterable<String>? excludeB,
  int minShared = 1,
}) {
  final extraWhere = <String>[];
  final extraParams = <Object?>[];
  void restrict(String column, Iterable<String>? ids) {
    if (ids == null) return;
    final list = ids.toList();
    if (list.isEmpty) {
      extraWhere.add('0 = 1');
      return;
    }
    extraWhere.add('$column IN (${placeholders(list.length)})');
    extraParams.addAll(list);
  }

  restrict('a.entity_id', restrictA);
  restrict('b.entity_id', restrictB);
  final excluded = excludeB?.toList() ?? const <String>[];
  if (excluded.isNotEmpty) {
    extraWhere.add('b.entity_id NOT IN (${placeholders(excluded.length)})');
    extraParams.addAll(excluded);
  }
  if (kindA == kindB) {
    final spokes = restrictA != null && restrictB == null;
    extraWhere.add(
      spokes ? 'b.entity_id <> a.entity_id' : 'a.entity_id < b.entity_id',
    );
  }
  final having = minShared > 1 ? '\nHAVING COUNT(DISTINCT d.id) >= ?' : '';
  // The scope is built beside the SQL that embeds it, so the census sees
  // both in one chunk.
  final scope = diveScopeSql(diverId: diverId, filter: filter);
  final where = [...scope.clauses, ...extraWhere];
  final params = [
    ...scope.params,
    ...extraParams,
    if (minShared > 1) minShared,
  ];
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
GROUP BY a.entity_id, b.entity_id$having
ORDER BY weight DESC, source ASC, target ASC''';
  return (sql: sql, params: params);
}
```

Drop the `node_ref.dart` import from that file if it is now unused.

In `lib/features/connections/data/connections_node_sql.dart`, change `buildNodeSql`'s signature and tail:

```dart
({String sql, List<Object?> params}) buildNodeSql({
  required ConnectionKind kind,
  required String? diverId,
  required DiveFilterState filter,
  Iterable<String>? onlyIds,
  String? labelLike,
  int? limit,
}) {
```

and, after the existing `final extra = ...` line, build the SQL as:

```dart
  final outerWhere = labelLike == null
      ? ''
      : "\nWHERE t.${t.labelColumn} LIKE ? ESCAPE '\\'";
  final limitClause = limit == null ? '' : '\nLIMIT ?';
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
JOIN ${t.table} t ON t.id = c.entity_id$outerWhere
ORDER BY c.dive_count DESC, label ASC$limitClause''';
  return (
    sql: sql,
    params: [...params, ?labelLike, ?limit],
  );
```

In `connections_repository.dart`, change `_edges`'s call into the builder (its own signature stays until Task 4 replaces the file):

```dart
    final q = buildEdgeSql(
      kindA: kindA,
      kindB: kindB,
      diverId: diverId,
      filter: filter,
      restrictA: focus != null ? [focus.id] : restrictTo,
      restrictB: focus != null ? null : restrictTo,
    );
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/connections/data/ test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS, including the unchanged repository tests (the phase 1 ego and whole-web behaviour is preserved by the call-site mapping).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/data test/features/connections/data
git commit -m "feat(connections): edge builder restrictions, exclusions and minimum; node label search"
```

---

### Task 3: Hop distance on nodes and hop-ranked trimming

**Files:**
- Modify: `lib/features/connections/domain/entities/connection_node.dart`
- Modify: `lib/features/connections/domain/entities/connection_graph.dart`
- Test: `test/features/connections/domain/entities/connection_graph_test.dart`

**Interfaces:**
- Produces: `ConnectionNode.hop` (`int?`; 0 for the focus, 1 to 3 for others, null in map mode), in the constructor, `copyWith` and `props`. `ConnectionGraph.trimmed(budget, keep:)` ranks by hop ascending first (null counts as 0), then dive count, weighted degree and wire id, as before.

- [ ] **Step 1: Write the failing test**

Append to `connection_graph_test.dart`:

```dart
  test('trimming never lets a far hop displace a nearer one', () {
    final g = ConnectionGraph(
      nodes: [
        ConnectionNode(ref: _b('focus'), label: 'F', diveCount: 1, hop: 0),
        ConnectionNode(ref: _b('near'), label: 'N', diveCount: 1, hop: 1),
        ConnectionNode(ref: _b('far'), label: 'X', diveCount: 99, hop: 3),
      ],
      edges: const [],
    );
    final t = g.trimmed(2, keep: _b('focus'));
    expect(t.nodes.map((n) => n.ref.id).toSet(), {'focus', 'near'});
    expect(t.hiddenNodeCount, 1);
  });

  test('hop takes part in equality and copyWith', () {
    final n = ConnectionNode(ref: _b('a'), label: 'A', diveCount: 1, hop: 2);
    expect(n.copyWith(hop: 1).hop, 1);
    expect(n == n.copyWith(hop: 1), isFalse);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/domain/entities/connection_graph_test.dart`
Expected: FAIL to compile, `hop` is not a named parameter.

- [ ] **Step 3: Implement**

In `ConnectionNode`: add `this.hop,` to the constructor, the field with its doc comment:

```dart
  /// Shared-dive steps from the focus in an around view: 0 for the focus
  /// itself, 1 to 3 for the rest. Null in a whole map.
  final int? hop;
```

`int? hop,` in `copyWith` with `hop: hop ?? this.hop,`, and `hop,` in `props` after `diveCount`.

In `ConnectionGraph.trimmed`, make the comparator rank by hop first:

```dart
    final ranked = [...nodes]
      ..sort((a, b) {
        final byHop = (a.hop ?? 0).compareTo(b.hop ?? 0);
        if (byHop != 0) return byHop;
        final byDives = b.diveCount.compareTo(a.diveCount);
        if (byDives != 0) return byDives;
        final byDegree = (degree[b.ref] ?? 0).compareTo(degree[a.ref] ?? 0);
        if (byDegree != 0) return byDegree;
        return a.ref.wire.compareTo(b.ref.wire);
      });
```

Update the method's doc comment: "Keeps the top [budget] nodes by hop, then dive count, then weighted degree, then id, ...".

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/connections/domain/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/entities test/features/connections/domain/entities
git commit -m "feat(connections): hop distance on nodes and hop-ranked trimming"
```

---

### Task 4: Map and around loaders, entity search, repository API

**Files:**
- Create: `lib/features/connections/data/connections_reader.dart`
- Create: `lib/features/connections/data/connections_map_loader.dart`
- Create: `lib/features/connections/data/connections_around_loader.dart`
- Modify: `lib/features/connections/data/repositories/connections_repository.dart` (rewrite)
- Test: `test/features/connections/data/repositories/connections_repository_test.dart` (rewrite)

**Interfaces:**
- Consumes: Task 2 builders; Task 3 `hop`; Task 1 `MapSpec`, `KindLink`.
- Produces:
  - `ConnectionsReader(AppDatabase db)`: `edges(kindA, kindB, {diverId, filter, restrictA, restrictB, excludeB, minShared})`, `nodes(kind, {diverId, filter, onlyIds, labelLike, limit})` (buddy nodes get their unanimous `RoleSubtitle`), `labelOnly(NodeRef)` (throws `FocusNotFoundException`).
  - `MapLoader(ConnectionsReader).load(MapSpec, {diverId, filter})` → untrimmed `ConnectionGraph` (nodes of every kind, `hop` null; one edge query per link).
  - `AroundLoader(ConnectionsReader).load({focus, kinds, hops, diverId, filter})` → untrimmed graph with `hop` on every node.
  - `ConnectionsRepository`:
    - `Future<ConnectionGraph> loadMap(MapSpec spec, {required String? diverId, DiveFilterState filter = const DiveFilterState(), int nodeBudget = 80})`
    - `Future<ConnectionGraph> loadAround({required NodeRef focus, required Set<ConnectionKind> kinds, required int hops, required String? diverId, DiveFilterState filter = const DiveFilterState(), int nodeBudget = 80})`
    - `Future<List<ConnectionNode>> searchEntities(String text, {required String? diverId, int perKind = 5, int limit = 20})`
    - unchanged: `diveYearSpan`, `diveIdsFor`, `watchConnectionsChanges`, `FocusNotFoundException`.
    - temporary: `loadGraph(ConnectionQuery, {diverId})` delegating to the two new loaders, kept only until Task 8 deletes `ConnectionQuery`.
  - Both loads run inside one `_db.transaction`.

- [ ] **Step 1: Rewrite the repository test**

Replace `test/features/connections/data/repositories/connections_repository_test.dart`. Keep the phase 1 seed helpers `_diver`, `_buddy`, `_site`, `_dive`, `_link` exactly as they are in the current file (copy them from `git show HEAD:test/features/connections/data/repositories/connections_repository_test.dart`), and use this `main`:

```dart
NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);
const _bs = {ConnectionKind.buddy, ConnectionKind.site};

void main() {
  late ConnectionsRepository repo;
  late db.AppDatabase d;

  setUp(() async {
    await setUpTestDatabase();
    d = DatabaseService.instance.database;
    repo = ConnectionsRepository();
    await _diver(d, 'me');
    await _diver(d, 'other');
    for (final b in ['jane', 'ken', 'lou', 'mo']) {
      await _buddy(d, b);
    }
    await _site(d, 's1', country: 'Bonaire');
    await _site(d, 's2');
    await _site(d, 's9');
    // d1, d2: jane + ken at s1. d3: jane + lou at s2.
    // d6: ken + mo at s9 (reachable from jane only through ken).
    // d7..d9: mo alone at s9, so mo out-dives every hop-1 entity.
    await _dive(d, id: 'd1', at: DateTime.utc(2024, 1, 10), siteId: 's1');
    await _dive(d, id: 'd2', at: DateTime.utc(2024, 3, 5), siteId: 's1');
    await _dive(d, id: 'd3', at: DateTime.utc(2024, 6, 1), siteId: 's2');
    await _dive(d, id: 'd6', at: DateTime.utc(2024, 7, 1), siteId: 's9');
    for (final id in ['d7', 'd8', 'd9']) {
      await _dive(d, id: id, at: DateTime.utc(2024, 8, 1), siteId: 's9');
      await _link(d, id, 'mo');
    }
    await _link(d, 'd1', 'jane');
    await _link(d, 'd1', 'ken');
    await _link(d, 'd2', 'jane');
    await _link(d, 'd2', 'ken');
    await _link(d, 'd3', 'jane');
    await _link(d, 'd3', 'lou', role: 'instructor');
    await _link(d, 'd6', 'ken');
    await _link(d, 'd6', 'mo');
  });

  tearDown(() async => tearDownTestDatabase());

  group('loadMap', () {
    test('one kind, same-kind link: the dive circle', () async {
      final g = await repo.loadMap(
        MapSpec.of({ConnectionKind.buddy}, {
          KindLink(ConnectionKind.buddy, ConnectionKind.buddy),
        }),
        diverId: 'me',
      );
      final janeKen = g.edges.singleWhere(
        (e) => e.touches(_b('jane')) && e.touches(_b('ken')),
      );
      expect(janeKen.weight, 2);
      expect(janeKen.firstDiveAt, DateTime.utc(2024, 1, 10));
      expect(g.nodes.every((n) => n.hop == null), isTrue);
    });

    test('two kinds, both links, and the minimum thins weak lines', () async {
      final spec = MapSpec.of(_bs, {
        KindLink(ConnectionKind.buddy, ConnectionKind.site),
        KindLink(ConnectionKind.buddy, ConnectionKind.buddy),
      });
      final all = await repo.loadMap(spec, diverId: 'me');
      expect(all.edges.any((e) => e.touches(_s('s2'))), isTrue);
      final strong = await repo.loadMap(spec.withMinimum(2), diverId: 'me');
      expect(strong.edges.every((e) => e.weight >= 2), isTrue);
      expect(strong.edges.any((e) => e.touches(_s('s2'))), isFalse);
      expect(
        strong.nodeFor(_s('s2')),
        isNotNull,
        reason: 'an entity with no surviving line stays as an island',
      );
    });

    test('a kind with no link contributes nodes only', () async {
      final g = await repo.loadMap(
        MapSpec.of(_bs, {KindLink(ConnectionKind.buddy, ConnectionKind.buddy)}),
        diverId: 'me',
      );
      expect(g.nodeFor(_s('s1')), isNotNull);
      expect(g.edges.any((e) => e.touches(_s('s1'))), isFalse);
    });

    test('planned dives and other divers are out of scope', () async {
      await _dive(d, id: 'p1', at: DateTime.utc(2025), planned: true);
      await _link(d, 'p1', 'lou');
      await _link(d, 'p1', 'ken');
      await _dive(d, id: 'o1', at: DateTime.utc(2025), diverId: 'other');
      await _link(d, 'o1', 'lou');
      await _link(d, 'o1', 'ken');
      final g = await repo.loadMap(
        MapSpec.of({ConnectionKind.buddy}, {
          KindLink(ConnectionKind.buddy, ConnectionKind.buddy),
        }),
        diverId: 'me',
      );
      expect(
        g.edges.any((e) => e.touches(_b('lou')) && e.touches(_b('ken'))),
        isFalse,
      );
    });
  });

  group('loadAround', () {
    test('one hop: every enabled kind, spokes and chords, hop 0 and 1', () async {
      final g = await repo.loadAround(
        focus: _b('jane'),
        kinds: _bs,
        hops: 1,
        diverId: 'me',
      );
      expect(g.nodes.map((n) => n.ref).toSet(), {
        _b('jane'),
        _b('ken'),
        _b('lou'),
        _s('s1'),
        _s('s2'),
      });
      expect(g.nodeFor(_b('jane'))!.hop, 0);
      expect(g.nodeFor(_s('s1'))!.hop, 1);
      expect(
        g.edges.any((e) => e.touches(_b('ken')) && e.touches(_s('s1'))),
        isTrue,
        reason: 'lines among neighbours are drawn too',
      );
      expect(g.nodeFor(_b('mo')), isNull);
    });

    test('two hops reach entities only a neighbour shares dives with', () async {
      final g = await repo.loadAround(
        focus: _b('jane'),
        kinds: _bs,
        hops: 2,
        diverId: 'me',
      );
      expect(g.nodeFor(_b('mo'))!.hop, 2);
      expect(g.nodeFor(_s('s9'))!.hop, 2);
      expect(g.nodeFor(_b('ken'))!.hop, 1);
    });

    test('disabled kinds are left out', () async {
      final g = await repo.loadAround(
        focus: _b('jane'),
        kinds: {ConnectionKind.buddy},
        hops: 1,
        diverId: 'me',
      );
      expect(g.nodes.every((n) => n.ref.kind == ConnectionKind.buddy), isTrue);
    });

    test('the budget keeps nearer hops over busier far ones', () async {
      final g = await repo.loadAround(
        focus: _b('jane'),
        kinds: _bs,
        hops: 2,
        diverId: 'me',
        nodeBudget: 3,
      );
      expect(g.nodes.map((n) => n.ref).toSet(), {
        _b('jane'),
        _b('ken'),
        _s('s1'),
      });
      expect(g.hiddenNodeCount, greaterThan(0));
    });

    test('a focus with no dives in scope stands alone', () async {
      await _buddy(d, 'newbie');
      final g = await repo.loadAround(
        focus: _b('newbie'),
        kinds: _bs,
        hops: 2,
        diverId: 'me',
      );
      expect(g.nodes.single.ref, _b('newbie'));
      expect(g.nodes.single.diveCount, 0);
      expect(g.nodes.single.hop, 0);
      expect(g.edges, isEmpty);
    });

    test('a focus with no row throws FocusNotFoundException', () async {
      expect(
        () => repo.loadAround(
          focus: _b('ghost'),
          kinds: _bs,
          hops: 1,
          diverId: 'me',
        ),
        throwsA(isA<FocusNotFoundException>()),
      );
    });

    test('the focus kind is included even when its chip is off', () async {
      final g = await repo.loadAround(
        focus: _s('s1'),
        kinds: {ConnectionKind.buddy},
        hops: 1,
        diverId: 'me',
      );
      expect(g.nodeFor(_s('s1'))!.hop, 0);
      expect(g.nodes.where((n) => n.ref.kind == ConnectionKind.site).length, 1);
      expect(g.nodeFor(_b('jane'))!.hop, 1);
    });
  });

  group('searchEntities', () {
    test('matches labels across kinds, busiest first', () async {
      final hits = await repo.searchEntities('s', diverId: 'me');
      expect(hits.map((n) => n.ref), containsAll([_s('s1'), _s('s9')]));
      final jan = await repo.searchEntities('JAN', diverId: 'me');
      expect(jan.map((n) => n.ref), [_b('jane')]);
    });

    test('blank text finds nothing and LIKE characters are literal', () async {
      expect(await repo.searchEntities('   ', diverId: 'me'), isEmpty);
      expect(await repo.searchEntities('%', diverId: 'me'), isEmpty);
      expect(await repo.searchEntities('_', diverId: 'me'), isEmpty);
    });
  });

  group('unchanged helpers', () {
    test('diveYearSpan and diveIdsFor', () async {
      expect(await repo.diveYearSpan(diverId: 'me'), (first: 2024, last: 2024));
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

Imports for the new file: those of the phase 1 test plus `package:submersion/features/connections/domain/views/kind_link.dart` and `.../views/map_spec.dart`; drop `connection_query.dart` and `connection_node.dart` if unused.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/data/repositories/connections_repository_test.dart`
Expected: FAIL to compile, `loadMap`, `loadAround` and `searchEntities` are not defined.

- [ ] **Step 3: Write the reader**

`lib/features/connections/data/connections_reader.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/connections/data/connections_edge_sql.dart';
import 'package:submersion/features/connections/data/connections_node_sql.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// The focus of an around view has no row in its label table.
class FocusNotFoundException implements Exception {
  const FocusNotFoundException(this.ref);
  final NodeRef ref;
  @override
  String toString() => 'FocusNotFoundException($ref)';
}

/// Row-level reads shared by the map and around loaders. Every query comes
/// from the scoped builders, so this file writes no SQL over `dives`.
class ConnectionsReader {
  const ConnectionsReader(this._db);

  final DatabaseConnectionUser _db;

  Future<List<ConnectionEdge>> edges(
    ConnectionKind kindA,
    ConnectionKind kindB, {
    required String? diverId,
    required DiveFilterState filter,
    Iterable<String>? restrictA,
    Iterable<String>? restrictB,
    Iterable<String>? excludeB,
    int minShared = 1,
  }) async {
    final q = buildEdgeSql(
      kindA: kindA,
      kindB: kindB,
      diverId: diverId,
      filter: filter,
      restrictA: restrictA,
      restrictB: restrictB,
      excludeB: excludeB,
      minShared: minShared,
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

  Future<List<ConnectionNode>> nodes(
    ConnectionKind kind, {
    required String? diverId,
    required DiveFilterState filter,
    Iterable<String>? onlyIds,
    String? labelLike,
    int? limit,
  }) async {
    final q = buildNodeSql(
      kind: kind,
      diverId: diverId,
      filter: filter,
      onlyIds: onlyIds,
      labelLike: labelLike,
      limit: limit,
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

  /// The focus when it has no dive in scope: label only, zero dives.
  Future<ConnectionNode> labelOnly(NodeRef ref) async {
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
    return {
      for (final r in rows) r.read<String>('id'): r.read<String>('role'),
    };
  }
}
```

Move `_subtitle(ConnectionKind kind, QueryRow r)` and `static DateTime _ms(int ms)` verbatim from the current `connections_repository.dart` into this file as top-level private functions `NodeSubtitle? _subtitle(ConnectionKind kind, QueryRow r)` and `DateTime _ms(int ms)`.

- [ ] **Step 4: Write the two loaders**

`lib/features/connections/data/connections_map_loader.dart`:

```dart
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// A whole map: every entity of each chosen kind, and one edge query per
/// chosen link. Entities without a surviving line stay, as islands.
class MapLoader {
  const MapLoader(this._reader);

  final ConnectionsReader _reader;

  Future<ConnectionGraph> load(
    MapSpec spec, {
    required String? diverId,
    required DiveFilterState filter,
  }) async {
    final kinds = spec.kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
    final nodes = <ConnectionNode>[
      for (final k in kinds)
        ...await _reader.nodes(k, diverId: diverId, filter: filter),
    ];
    final links = spec.links.toList()..sort((a, b) => a.wire.compareTo(b.wire));
    final edges = <ConnectionEdge>[
      for (final l in links)
        ...await _reader.edges(
          l.a,
          l.b,
          diverId: diverId,
          filter: filter,
          minShared: spec.minSharedDives,
        ),
    ];
    return ConnectionGraph(nodes: nodes, edges: edges);
  }
}
```

`lib/features/connections/data/connections_around_loader.dart`:

```dart
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Everything within [hops] shared-dive steps of a focus, limited to the
/// enabled kinds (the focus's own kind is always present).
///
/// Discovery is breadth-first: each hop joins the previous hop's frontier to
/// every enabled kind, excluding what is already placed. Edges are then one
/// pass over every pair of kinds among the placed entities, so lines between
/// neighbours are drawn as well as the spokes.
class AroundLoader {
  const AroundLoader(this._reader);

  final ConnectionsReader _reader;

  Future<ConnectionGraph> load({
    required NodeRef focus,
    required Set<ConnectionKind> kinds,
    required int hops,
    required String? diverId,
    required DiveFilterState filter,
  }) async {
    final enabled = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
    final placed = <ConnectionKind, Set<String>>{
      focus.kind: {focus.id},
    };
    final hopOf = <NodeRef, int>{focus: 0};
    var frontier = <ConnectionKind, Set<String>>{
      focus.kind: {focus.id},
    };

    for (var hop = 1; hop <= hops && frontier.isNotEmpty; hop++) {
      final next = <ConnectionKind, Set<String>>{};
      for (final entry in frontier.entries) {
        for (final kind in enabled) {
          final found = await _reader.edges(
            entry.key,
            kind,
            diverId: diverId,
            filter: filter,
            restrictA: entry.value,
            excludeB: placed[kind] ?? const <String>{},
          );
          for (final e in found) {
            if (hopOf.containsKey(e.target)) continue;
            hopOf[e.target] = hop;
            placed.putIfAbsent(kind, () => {}).add(e.target.id);
            next.putIfAbsent(kind, () => {}).add(e.target.id);
          }
        }
      }
      frontier = next;
    }

    final nodes = <ConnectionNode>[];
    final placedKinds = placed.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final kind in placedKinds) {
      final rows = await _reader.nodes(
        kind,
        diverId: diverId,
        filter: filter,
        onlyIds: placed[kind],
      );
      nodes.addAll(rows.map((n) => n.copyWith(hop: hopOf[n.ref])));
    }
    if (!nodes.any((n) => n.ref == focus)) {
      nodes.insert(0, (await _reader.labelOnly(focus)).copyWith(hop: 0));
    }

    final edges = <ConnectionEdge>[];
    for (var i = 0; i < placedKinds.length; i++) {
      for (var j = i; j < placedKinds.length; j++) {
        edges.addAll(
          await _reader.edges(
            placedKinds[i],
            placedKinds[j],
            diverId: diverId,
            filter: filter,
            restrictA: placed[placedKinds[i]],
            restrictB: placed[placedKinds[j]],
          ),
        );
      }
    }
    return ConnectionGraph(nodes: nodes, edges: edges);
  }
}
```

- [ ] **Step 5: Rewrite the repository**

`lib/features/connections/data/repositories/connections_repository.dart` keeps `diveYearSpan`, `diveIdsFor`, `watchConnectionsChanges` exactly as they are. `FocusNotFoundException` now lives in `connections_reader.dart`; re-export it so importers of the repository keep compiling: add `export 'package:submersion/features/connections/data/connections_reader.dart' show FocusNotFoundException;` after the imports. Replace `loadGraph`, `_wholeWeb`, `_ego`, `_edges`, `_nodes`, `_unanimousRoles`, `_subtitle` and `_labelOnly` with:

```dart
  Future<ConnectionGraph> loadMap(
    MapSpec spec, {
    required String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    int nodeBudget = 80,
  }) {
    return _db.transaction(() async {
      final graph = await MapLoader(
        ConnectionsReader(_db),
      ).load(spec, diverId: diverId, filter: filter);
      return graph.trimmed(nodeBudget);
    });
  }

  Future<ConnectionGraph> loadAround({
    required NodeRef focus,
    required Set<ConnectionKind> kinds,
    required int hops,
    required String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    int nodeBudget = 80,
  }) {
    return _db.transaction(() async {
      final graph = await AroundLoader(ConnectionsReader(_db)).load(
        focus: focus,
        kinds: kinds,
        hops: hops.clamp(1, 3),
        diverId: diverId,
        filter: filter,
      );
      return graph.trimmed(nodeBudget, keep: focus);
    });
  }

  /// Entities of every kind whose label contains [text], limited to those
  /// with at least one dive in scope for [diverId], busiest first.
  Future<List<ConnectionNode>> searchEntities(
    String text, {
    required String? diverId,
    int perKind = 5,
    int limit = 20,
  }) async {
    final needle = text.trim();
    if (needle.isEmpty) return const [];
    final reader = ConnectionsReader(_db);
    final pattern = '%${escapeLike(needle)}%';
    final hits = <ConnectionNode>[
      for (final kind in ConnectionKind.values)
        ...await reader.nodes(
          kind,
          diverId: diverId,
          filter: const DiveFilterState(),
          labelLike: pattern,
          limit: perKind,
        ),
    ];
    hits.sort((a, b) {
      final byDives = b.diveCount.compareTo(a.diveCount);
      return byDives != 0 ? byDives : a.label.compareTo(b.label);
    });
    return hits.take(limit).toList();
  }

  /// Phase 1 entry point, kept only until Task 8 removes ConnectionQuery.
  Future<ConnectionGraph> loadGraph(
    ConnectionQuery query, {
    required String? diverId,
  }) {
    if (!query.focusIsValid) {
      throw ArgumentError.value(query.focus, 'focus', 'not in this query');
    }
    final focus = query.focus;
    if (focus == null) {
      return loadMap(
        MapSpec.of({query.kindA, query.kindB}, {
          KindLink(query.kindA, query.kindB),
        }),
        diverId: diverId,
        filter: query.filter,
        nodeBudget: query.nodeBudget,
      );
    }
    return loadAround(
      focus: focus,
      kinds: {query.neighbourKind!},
      hops: 1,
      diverId: diverId,
      filter: query.filter,
      nodeBudget: query.nodeBudget,
    );
  }
```

Imports to add: `connections_reader.dart`, `connections_map_loader.dart`, `connections_around_loader.dart`, `connections_scope_sql.dart` (for `escapeLike`), `views/kind_link.dart`, `views/map_spec.dart`. Remove imports the file no longer uses (`dart:typed_data`, `connections_node_sql.dart` if unused). `diveIdsFor` still uses `membershipSql` and `diveScopeSql`; keep those imports.

- [ ] **Step 6: Run the tests**

Run:
```bash
flutter test test/features/connections/ test/core/database/dive_stats_scope_census_test.dart test/architecture/repository_tick_stream_test.dart
```
Expected: PASS. If a provider or page test that went through `loadGraph` now fails because an ego view gained lines among neighbours of a mixed pair, update that test's expectation to the new behaviour (Revision 2 draws chords among all placed kinds) and ledger it.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections test/features/connections
git commit -m "feat(connections): map and around loaders, entity search, transactional loads"
```

---

### Task 5: Schema rung 232: `connection_maps` and the sightings index

**Files:**
- Modify: `lib/core/database/database.dart` (table class, `@DriftDatabase` list, `currentSchemaVersion`, `migrationVersions`, helper, `onUpgrade` rung, `beforeOpen` backstop)
- Modify: `lib/core/database/performance_indexes.dart` (two entries)
- Modify: `test/core/database/migration_v231_ccr_ppo2_limits_test.dart` (relax the exact version)
- Test: `test/core/database/migration_v232_connection_maps_test.dart` (new)

**Interfaces:**
- Produces: Drift table `ConnectionMaps` (`@DataClassName('ConnectionMapRow')`, getter `_db.connectionMaps`, SQL name `connection_maps`) with columns `id` (text PK), `diver_id` (text, not null, `REFERENCES divers (id) ON DELETE CASCADE`), `name` (text), `spec` (text, JSON), `sort_order` (int, default 0), `created_at`, `updated_at` (int), `hlc` (text, nullable). Indexes `idx_connection_maps_diver` on `connection_maps(diver_id, sort_order)` and `idx_sightings_dive_id` on `sightings(dive_id)`.

- [ ] **Step 1: Write the failing migration test**

`test/core/database/migration_v232_connection_maps_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v232: saved connection maps and the sightings dive index
/// (issue #2322, spec Revision 2).
void main() {
  /// A v231 database with the stub parents earlier backstops look for, a
  /// sightings table without the index, and no connection_maps.
  NativeDatabase setupDb({int userVersion = 231, bool withDivers = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        if (withDivers) {
          rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        }
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE sightings (id TEXT NOT NULL PRIMARY KEY, '
          'dive_id TEXT NOT NULL, species_id TEXT NOT NULL)',
        );
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<String?> ddlOf(AppDatabase db, String type, String name) async {
    final rows = await db
        .customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable<String>(type), Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String?>('sql');
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v232 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 232);
    expect(AppDatabase.migrationVersions, contains(232));
    expect(AppDatabase.migrationStepCount(231), 1);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('adds the connection_maps table', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'connection_maps'),
      containsAll(<String>[
        'id',
        'diver_id',
        'name',
        'spec',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('a deleted diver takes their maps with them', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(
      await ddlOf(db, 'table', 'connection_maps'),
      contains('REFERENCES divers (id) ON DELETE CASCADE'),
    );
  });

  test('creates the maps index and the sightings dive index', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(
      await indexNames(db),
      containsAll(<String>['idx_connection_maps_diver', 'idx_sightings_dive_id']),
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(
      await tableInfo(upgraded, 'connection_maps'),
      await tableInfo(fresh, 'connection_maps'),
    );
    expect(
      await ddlOf(upgraded, 'table', 'connection_maps'),
      await ddlOf(fresh, 'table', 'connection_maps'),
    );
    await fresh.customSelect('SELECT 1').get();
    expect(await indexNames(fresh), contains('idx_sightings_dive_id'));
  });

  test('a database stamped v232 without the table heals in beforeOpen', () async {
    final db = AppDatabase(setupDb(userVersion: 232));
    addTearDown(db.close);
    expect(await columnsOf(db, 'connection_maps'), contains('spec'));
  });

  test('a fixture without divers skips the table', () async {
    final db = AppDatabase(setupDb(withDivers: false));
    addTearDown(db.close);
    expect(await columnsOf(db, 'connection_maps'), isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v232_connection_maps_test.dart`
Expected: FAIL, the version is 231 and the table does not exist.

- [ ] **Step 3: Add the table, rung, helper and backstop**

In `lib/core/database/database.dart`:

1. Next to `FieldPresets` (around line 4296), add:

```dart
/// Saved Connections maps (issue #2322, spec Revision 2): a named MapSpec
/// per diver, synced like field presets. `spec` is the MapSpec JSON; a spec
/// naming a kind the reading build does not know is skipped, never deleted.
@DataClassName('ConnectionMapRow')
class ConnectionMaps extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get spec => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

2. In `@DriftDatabase(tables: [...])`, after `CylinderFills,`:

```dart
    // Saved Connections maps (v232, issue #2322)
    ConnectionMaps,
```

3. `static const int currentSchemaVersion = 232;` (was 231). Do not touch `minimumCompatibleSchemaVersion`.

4. Append to `migrationVersions`, after `231,`:

```dart
    // v232: connection_maps, saved Connections maps per diver, plus the
    // idx_sightings_dive_id index the species maps join on (issue #2322).
    // Table-and-index rung, no backfill, floor stays at 224.
    232,
```

5. Next to `_assertCylinderFillsSchema()`, add:

```dart
  /// v232: the saved-maps table and the sightings dive index. Idempotent,
  /// so the beforeOpen backstop can run it on every open.
  Future<void> _assertConnectionMapsSchema() async {
    final divers = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'divers'",
    ).get();
    if (divers.isNotEmpty) {
      await createMigrator().createTable(connectionMaps);
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_connection_maps_diver '
        'ON connection_maps(diver_id, sort_order)',
      );
    }
    final sightings = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'sightings'",
    ).get();
    if (sightings.isNotEmpty) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sightings_dive_id '
        'ON sightings(dive_id)',
      );
    }
  }
```

6. In `onUpgrade`, after the v231 rung and before the closing `},`:

```dart
        // v232: saved Connections maps and the sightings dive index (issue
        // #2322). Table-and-index rung, no backfill.
        if (from < 232) {
          await _assertConnectionMapsSchema();
        }
        if (from < 232) await reportProgress();
```

7. In `beforeOpen`, after the v231 backstop:

```dart
        // v232 backstop: connection_maps and idx_sightings_dive_id
        // (parallel-branch version-collision self-heal; idempotent).
        await _assertConnectionMapsSchema();
```

In `lib/core/database/performance_indexes.dart`, append to `kPerformanceIndexes`:

```dart
  // Saved Connections maps and the sightings dive join (v232, issue #2322).
  (
    name: 'idx_connection_maps_diver',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_connection_maps_diver '
        'ON connection_maps(diver_id, sort_order)',
  ),
  (
    name: 'idx_sightings_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_sightings_dive_id '
        'ON sightings(dive_id)',
  ),
```

In `test/core/database/migration_v231_ccr_ppo2_limits_test.dart`, relax the exact assertion:

```dart
  test('v231 is at or below the current schema version and in the ladder', () {
    // Relaxed once v232 (connection_maps) landed on top; the newest rung
    // owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(231));
    expect(AppDatabase.migrationVersions, contains(231));
    expect(AppDatabase.migrationStepCount(230), greaterThanOrEqualTo(1));
  });
```

- [ ] **Step 4: Regenerate Drift code and run the tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/
```
Expected: PASS, including `performance_indexes_test.dart` (a fresh database now has both indexes) and every older migration test.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/database test/core/database
git add lib/core/database test/core/database
git commit -m "feat(connections): schema rung 232 with connection_maps and the sightings dive index"
```

---

### Task 6: Register `connection_maps` for sync

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncData field, constructor, `toJson`, `fromJson`, `_baseTables`, `_buildSyncData`, `fetchRecord`, `fetchRecords`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, `_syncTableFor`, `deleteRecord`, `_exportConnectionMaps`)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder`, `entityHasUpdatedAt`)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables`)
- Modify: `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart` (`targets`)
- Test: `test/core/services/sync/connection_maps_sync_round_trip_test.dart` (new)

**Interfaces:**
- Produces: sync entity type string `'connectionMaps'` (JSON key and record type), used by Task 7's repository.

Every edit sits directly after the matching `cylinderFills` line in the same list or switch, so `toJson` order and `_baseTables` order stay equal (the parity tests compare them).

- [ ] **Step 1: Write the failing round-trip test**

`test/core/services/sync/connection_maps_sync_round_trip_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// A saved Connections map travels through every per-record sync arm
/// unchanged (issue #2322).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    final d = DatabaseService.instance.database;
    await d
        .into(d.divers)
        .insert(
          const db.DiversCompanion(
            id: Value('me'),
            name: Value('Me'),
            createdAt: Value(1),
            updatedAt: Value(1),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> row(String id, {String name = 'Bonaire 2025'}) => {
    'id': id,
    'diverId': 'me',
    'name': name,
    'spec': '{"kinds":["buddy","site"],"links":["buddy-site"],"min":1}',
    'sortOrder': 0,
    'createdAt': 1790000000000,
    'updatedAt': 1790000000000,
    'hlc': null,
  };

  test('upsert, fetch, update and delete one map', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('connectionMaps', row('m1'));
    final fetched = await s.fetchRecord('connectionMaps', 'm1');
    expect(fetched, isNotNull);
    expect(fetched!['name'], 'Bonaire 2025');
    expect(fetched['spec'], contains('buddy-site'));

    await s.upsertRecord('connectionMaps', row('m1', name: 'Renamed'));
    expect((await s.fetchRecord('connectionMaps', 'm1'))!['name'], 'Renamed');

    await s.deleteRecord('connectionMaps', 'm1');
    expect(await s.fetchRecord('connectionMaps', 'm1'), isNull);
  });

  test('batch upsert and fetch', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('connectionMaps', [row('a'), row('b')]);
    final all = await s.fetchRecords('connectionMaps', ['a', 'b']);
    expect(all.keys.toSet(), {'a', 'b'});
  });

  test('is a last-writer-wins entity with updatedAt', () {
    expect(SyncService.entityHasUpdatedAt['connectionMaps'], isTrue);
    expect(const SyncData().toJson().keys, contains('connectionMaps'));
  });
}
```

Check the exact names while writing: `upsertRecords` and `fetchRecords` take the arguments shown in `cylinder_fills_sync_round_trip_test.dart` (open it and match its calls), and `entityHasUpdatedAt` is the static map at `sync_service.dart:2350`; if it is an instance member there, read it the way `test/core/services/sync/dive_center_gear_notes_sync_test.dart` does.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/connection_maps_sync_round_trip_test.dart`
Expected: FAIL (the serializer does not know `connectionMaps`).

- [ ] **Step 3: Register the entity**

`sync_repository.dart`, in `hlcTargets` after `'cylinderFills': ...`:

```dart
    'connectionMaps': (table: 'connection_maps', pk: 'id'),
```

`sync_data_serializer.dart`, each directly after the `cylinderFills` line:

```dart
  // class SyncData, fields
  final List<Map<String, dynamic>> connectionMaps;
  // constructor
    this.connectionMaps = const [],
  // toJson()
    'connectionMaps': connectionMaps,
  // fromJson
    connectionMaps: _parseList(json['connectionMaps']),
  // _baseTables
    (key: 'connectionMaps', table: _db.connectionMaps, blob: false, full: null),
  // _buildSyncData
    connectionMaps: await _safeExport(
      'connectionMaps',
      () => _exportConnectionMaps(hlcSince),
    ),
```

Switch cases, each after the `case 'cylinderFills':` arm of the same switch:

```dart
      // fetchRecord
      case 'connectionMaps':
        final row = await (_db.select(
          _db.connectionMaps,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

For `fetchRecords`, `upsertRecords` and `recordIdsFor`, copy the `cylinderFills` arm verbatim and replace `cylinderFills` with `connectionMaps` and `CylinderFillRow` with `ConnectionMapRow`. The three other arms:

```dart
      // upsertRecord
      case 'connectionMaps':
        await _db
            .into(_db.connectionMaps)
            .insertOnConflictUpdate(
              ConnectionMapRow.fromJson(data).toCompanion(false),
            );
      // _syncTableFor
      case 'connectionMaps':
        return _db.connectionMaps;
      // deleteRecord
      case 'connectionMaps':
        await (_db.delete(
          _db.connectionMaps,
        )..where((t) => t.id.equals(recordId))).go();
```

(Keep each arm's `return`/`break` style the same as the `cylinderFills` arm it sits beside.)

The exporter, next to `_exportCylinderFills`:

```dart
  Future<List<Map<String, dynamic>>> _exportConnectionMaps(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.connectionMaps);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

`sync_service.dart`, in `mergeOrder` after the `cylinderFills` record:

```dart
          (
            type: 'connectionMaps',
            records: data.connectionMaps,
            hasUpdatedAt: true,
          ),
```

and in `entityHasUpdatedAt` after `'cylinderFills': true,`:

```dart
    'connectionMaps': true,
```

No `parentRefs` entry: divers are deliberately not a deletable parent, and the FK cascades locally.

Tests: in `sync_parent_refs_completeness_test.dart` add `'connection_maps': 'connectionMaps',` to `syncedTables` next to `'cylinder_fills'`; in `sync_data_serializer_batch_coverage_test.dart` add `(type: 'connectionMaps', table: db.connectionMaps.actualTableName),` to `targets` next to cylinder fills. If that batch test seeds rows with placeholder values and the NOT NULL `diver_id` foreign key rejects `'x'`, seed a `divers` row with id `'x'` in that test's `setUp` the way other FK-bearing targets do (read how it handles `field_presets`).

- [ ] **Step 4: Run the sync tests**

```bash
flutter test test/core/services/sync/ test/features/divers/
```
Expected: PASS, including `sync_hlc_target_registration_test`, `sync_base_streaming_parity_test`, `base_publish_streaming_parity_test`, `sync_parent_refs_completeness_test`, the batch coverage test, `diver_delete_owned_tables_test` and `diver_merge_repository_test`.

- [ ] **Step 5: Commit**

```bash
dart format lib/core test/core
git add lib/core test/core
git commit -m "feat(connections): sync saved connection maps"
```

---

### Task 7: Saved maps: entity, repository and provider

**Files:**
- Create: `lib/features/connections/domain/entities/saved_connection_map.dart`
- Create: `lib/features/connections/data/repositories/connection_map_repository.dart`
- Create: `lib/features/connections/presentation/providers/saved_connection_maps_provider.dart`
- Modify: `test/architecture/repository_tick_stream_test.dart` (tick entries)
- Modify: `test/architecture/provider_tick_build_smoke_test.dart` (one case)
- Test: `test/features/connections/data/repositories/connection_map_repository_test.dart`
- Test: `test/features/connections/domain/entities/saved_connection_map_test.dart`

**Interfaces:**
- Consumes: Task 5 table, Task 6 sync entity, Task 1 `MapSpec`.
- Produces:
  - `SavedConnectionMap({required String id, required String diverId, required String name, required MapSpec spec, int sortOrder = 0, required DateTime createdAt, required DateTime updatedAt})` with `copyWith`; `static SavedConnectionMap? tryParse({id, diverId, name, specJson, sortOrder, createdAt, updatedAt})` (null when the spec does not parse).
  - `ConnectionMapRepository`: `static const entity = 'connectionMaps'`, `watchConnectionMapsChanges()` (debounced `tableUpdates` on `connection_maps`), `Future<List<SavedConnectionMap>> getAll(String diverId)` (sorted by `sortOrder` then `name`, unparsable rows skipped), `Future<SavedConnectionMap> create({required String diverId, required String name, required MapSpec spec})`, `Future<void> rename(String id, String name)`, `Future<void> updateSpec(String id, MapSpec spec)`, `Future<void> delete(String id)`, `Future<void> restore(SavedConnectionMap map)` (re-inserts a deleted map with its id, for undo).
  - `connectionMapRepositoryProvider`, `savedConnectionMapsProvider` (`FutureProvider.autoDispose<List<SavedConnectionMap>>`, watches `validatedCurrentDiverIdProvider`, empty list without a diver).

- [ ] **Step 1: Write the failing tests**

`test/features/connections/domain/entities/saved_connection_map_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';

void main() {
  test('parses a known spec and rejects an unknown kind', () {
    final t = DateTime.utc(2026);
    final ok = SavedConnectionMap.tryParse(
      id: 'm1',
      diverId: 'me',
      name: 'Trip',
      specJson: '{"kinds":["buddy","trip"],"links":["buddy-trip"],"min":2}',
      sortOrder: 0,
      createdAt: t,
      updatedAt: t,
    );
    expect(ok!.spec.minSharedDives, 2);
    expect(
      SavedConnectionMap.tryParse(
        id: 'm2',
        diverId: 'me',
        name: 'Future',
        specJson: '{"kinds":["hologram"],"links":[],"min":1}',
        sortOrder: 0,
        createdAt: t,
        updatedAt: t,
      ),
      isNull,
    );
    expect(
      SavedConnectionMap.tryParse(
        id: 'm3',
        diverId: 'me',
        name: 'Broken',
        specJson: 'not json',
        sortOrder: 0,
        createdAt: t,
        updatedAt: t,
      ),
      isNull,
    );
  });
}
```

`test/features/connections/data/repositories/connection_map_repository_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/repositories/connection_map_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late db.AppDatabase d;
  late ConnectionMapRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    d = DatabaseService.instance.database;
    repo = ConnectionMapRepository();
    for (final id in ['me', 'other']) {
      await d
          .into(d.divers)
          .insert(
            db.DiversCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: const Value(1),
              updatedAt: const Value(1),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('create, list per diver, rename, update, delete', () async {
    final travel = ConnectionPresets.byId('travel')!.spec;
    final a = await repo.create(diverId: 'me', name: 'Bonaire', spec: travel);
    await repo.create(diverId: 'other', name: 'Theirs', spec: travel);
    expect((await repo.getAll('me')).map((m) => m.name), ['Bonaire']);

    await repo.rename(a.id, 'Bonaire 2025');
    final edited = travel.toggleLink(
      KindLink(ConnectionKind.buddy, ConnectionKind.site),
    );
    await repo.updateSpec(a.id, edited);
    final got = (await repo.getAll('me')).single;
    expect(got.name, 'Bonaire 2025');
    expect(got.spec, edited);

    await repo.delete(a.id);
    expect(await repo.getAll('me'), isEmpty);
    await repo.restore(got);
    expect((await repo.getAll('me')).single.id, a.id);
  });

  test('a row with an unknown kind is skipped but kept', () async {
    await d
        .into(d.connectionMaps)
        .insert(
          const db.ConnectionMapsCompanion(
            id: Value('future'),
            diverId: Value('me'),
            name: Value('From a newer build'),
            spec: Value('{"kinds":["hologram"],"links":[],"min":1}'),
            createdAt: Value(1),
            updatedAt: Value(1),
          ),
        );
    expect(await repo.getAll('me'), isEmpty);
    final rows = await d.select(d.connectionMaps).get();
    expect(rows.map((r) => r.id), ['future']);
  });

  test('writes mark the row pending for sync', () async {
    final m = await repo.create(
      diverId: 'me',
      name: 'X',
      spec: ConnectionPresets.byId('where')!.spec,
    );
    final row = await (d.select(
      d.connectionMaps,
    )..where((t) => t.id.equals(m.id))).getSingle();
    expect(row.hlc, isNotNull, reason: 'markRecordPending stamps the hlc');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/domain/entities/saved_connection_map_test.dart test/features/connections/data/repositories/connection_map_repository_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Implement**

`lib/features/connections/domain/entities/saved_connection_map.dart`:

```dart
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

class SavedConnectionMap extends Equatable {
  const SavedConnectionMap({
    required this.id,
    required this.diverId,
    required this.name,
    required this.spec,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String diverId;
  final String name;
  final MapSpec spec;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null when [specJson] is not a spec this build understands, so a map
  /// saved by a newer build is hidden rather than dropped.
  static SavedConnectionMap? tryParse({
    required String id,
    required String diverId,
    required String name,
    required String specJson,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(specJson);
    } on FormatException {
      return null;
    }
    final spec = MapSpec.fromJson(decoded);
    if (spec == null) return null;
    return SavedConnectionMap(
      id: id,
      diverId: diverId,
      name: name,
      spec: spec,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SavedConnectionMap copyWith({String? name, MapSpec? spec, int? sortOrder}) {
    return SavedConnectionMap(
      id: id,
      diverId: diverId,
      name: name ?? this.name,
      spec: spec ?? this.spec,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    spec,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
```

`lib/features/connections/data/repositories/connection_map_repository.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

/// Saved Connections maps, per diver, synced: every write marks the row
/// pending, every delete logs a tombstone.
class ConnectionMapRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String entity = 'connectionMaps';

  Stream<void> watchConnectionMapsChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.connectionMaps))
      .debounce(DiveRepository.changeTickDebounce);

  Future<List<SavedConnectionMap>> getAll(String diverId) async {
    final rows =
        await (_db.select(_db.connectionMaps)
              ..where((t) => t.diverId.equals(diverId))
              ..orderBy([
                (t) => OrderingTerm(expression: t.sortOrder),
                (t) => OrderingTerm(expression: t.name),
              ]))
            .get();
    return [
      for (final r in rows)
        if (_fromRow(r) case final map?) map,
    ];
  }

  Future<SavedConnectionMap> create({
    required String diverId,
    required String name,
    required MapSpec spec,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db
        .into(_db.connectionMaps)
        .insert(
          ConnectionMapsCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            spec: Value(jsonEncode(spec.toJson())),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _markPending(id, now);
    final at = DateTime.fromMillisecondsSinceEpoch(now);
    return SavedConnectionMap(
      id: id,
      diverId: diverId,
      name: name,
      spec: spec,
      createdAt: at,
      updatedAt: at,
    );
  }

  Future<void> rename(String id, String name) =>
      _write(id, ConnectionMapsCompanion(name: Value(name)));

  Future<void> updateSpec(String id, MapSpec spec) => _write(
    id,
    ConnectionMapsCompanion(spec: Value(jsonEncode(spec.toJson()))),
  );

  Future<void> delete(String id) async {
    await (_db.delete(_db.connectionMaps)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: entity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  /// Puts a just-deleted map back with its id (the undo snackbar).
  Future<void> restore(SavedConnectionMap map) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.connectionMaps)
        .insertOnConflictUpdate(
          ConnectionMapsCompanion(
            id: Value(map.id),
            diverId: Value(map.diverId),
            name: Value(map.name),
            spec: Value(jsonEncode(map.spec.toJson())),
            sortOrder: Value(map.sortOrder),
            createdAt: Value(map.createdAt.millisecondsSinceEpoch),
            updatedAt: Value(now),
          ),
        );
    await _markPending(map.id, now);
  }

  Future<void> _write(String id, ConnectionMapsCompanion changes) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.connectionMaps)..where((t) => t.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value(now)));
    await _markPending(id, now);
  }

  Future<void> _markPending(String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  SavedConnectionMap? _fromRow(ConnectionMapRow r) => SavedConnectionMap.tryParse(
    id: r.id,
    diverId: r.diverId,
    name: r.name,
    specJson: r.spec,
    sortOrder: r.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );
}
```

`lib/features/connections/presentation/providers/saved_connection_maps_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connection_map_repository.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final connectionMapRepositoryProvider = Provider<ConnectionMapRepository>(
  (ref) => ConnectionMapRepository(),
);

/// The current diver's saved maps, sorted for the preset grid.
final savedConnectionMapsProvider =
    FutureProvider.autoDispose<List<SavedConnectionMap>>((ref) async {
      final repository = ref.watch(connectionMapRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionMapsChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return const [];
      return repository.getAll(diverId);
    });
```

In `test/architecture/repository_tick_stream_test.dart`, add the tick to the "silence before a write" `ticks` map beside the cylinder fills entry, and a "fires on a write" group beside the cylinder fills group, following those two entries exactly (insert a divers row, then a `connection_maps` row, and expect the tick). In `test/architecture/provider_tick_build_smoke_test.dart`, add inside the `connections` group:

```dart
    (
      name: 'savedConnectionMapsProvider',
      read: (c) => c.read(savedConnectionMapsProvider.future),
    ),
```

with the matching import.

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/connections/ test/architecture/
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections test/architecture
git add lib/features/connections test/features/connections test/architecture
git commit -m "feat(connections): saved connection maps repository and provider"
```

---

### Task 8: Localisation keys for Revision 2

**Files:**
- Create (scratch, not committed): `$SCRATCH/l10n_rev2.py` (any scratch path outside the repo)
- Modify: the eleven `lib/l10n/arb/app_*.arb`, regenerated `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces these `AppLocalizations` members, used by Tasks 9 to 21:
  `connections_mode_around`, `connections_mode_map`, `connections_tab_view`, `connections_tab_filter`, `connections_tab_filterCount(int count)`, `connections_tab_details`, `connections_presets_title`, `connections_preset_circle`, `connections_preset_where`, `connections_preset_trips`, `connections_preset_life`, `connections_preset_gear`, `connections_preset_centers`, `connections_preset_travel`, `connections_preset_reef`, `connections_preset_gearRoad`, `connections_preset_edited`, `connections_editor_title`, `connections_editor_kinds`, `connections_editor_links`, `connections_editor_link(String a, String b)`, `connections_editor_minShared(int count)`, `connections_editor_saveAsMap`, `connections_savedMap_saveTitle`, `connections_savedMap_nameLabel`, `connections_savedMap_rename`, `connections_savedMap_update`, `connections_savedMap_deleted(String name)`, `connections_savedMap_undo`, `connections_savedMap_badge`, `connections_around_searchHint`, `connections_around_centredOn`, `connections_around_hops`, `connections_around_show`, `connections_around_kindChip(String kind, int count)`, `connections_around_prompt`, `connections_around_noResults`, `connections_action_centreHere`, `connections_summary_title`, `connections_summary_mostConnected`, `connections_summary_strongestPair`, `connections_summary_pairValue(int count, String a, String b)`, `connections_summary_closest`, `connections_summary_entitiesAround(int count)`, `connections_filter_allFilters`, `connections_filter_clear`, `connections_filter_none`, `connections_loading`.
- Keys that become unused are deleted in Task 21, not here.

- [ ] **Step 1: Write the insertion script**

The script inserts every key directly after `"connections_title"` in each file (the connections block already sits in each locale's own position), with `@` metadata after keys that take placeholders, and validates the JSON before writing. Save it as `$SCRATCH/l10n_rev2.py`:

```python
import json
from pathlib import Path

KEYS = [
 "connections_mode_around", "connections_mode_map", "connections_tab_view",
 "connections_tab_filter", "connections_tab_filterCount", "connections_tab_details",
 "connections_presets_title", "connections_preset_circle", "connections_preset_where",
 "connections_preset_trips", "connections_preset_life", "connections_preset_gear",
 "connections_preset_centers", "connections_preset_travel", "connections_preset_reef",
 "connections_preset_gearRoad", "connections_preset_edited", "connections_editor_title",
 "connections_editor_kinds", "connections_editor_links", "connections_editor_link",
 "connections_editor_minShared", "connections_editor_saveAsMap",
 "connections_savedMap_saveTitle", "connections_savedMap_nameLabel",
 "connections_savedMap_rename", "connections_savedMap_update",
 "connections_savedMap_deleted", "connections_savedMap_undo", "connections_savedMap_badge",
 "connections_around_searchHint", "connections_around_centredOn", "connections_around_hops",
 "connections_around_show", "connections_around_kindChip", "connections_around_prompt",
 "connections_around_noResults", "connections_action_centreHere", "connections_summary_title",
 "connections_summary_mostConnected", "connections_summary_strongestPair",
 "connections_summary_pairValue", "connections_summary_closest",
 "connections_summary_entitiesAround", "connections_filter_allFilters",
 "connections_filter_clear", "connections_filter_none", "connections_loading",
]

META = {
 "connections_tab_filterCount": {"placeholders": {"count": {"type": "int"}}},
 "connections_editor_link": {"placeholders": {"a": {"type": "String"}, "b": {"type": "String"}}},
 "connections_editor_minShared": {"placeholders": {"count": {"type": "int"}}},
 "connections_savedMap_deleted": {"placeholders": {"name": {"type": "String"}}},
 "connections_around_kindChip": {"placeholders": {"kind": {"type": "String"}, "count": {"type": "int"}}},
 "connections_summary_pairValue": {"placeholders": {"count": {"type": "int"}, "a": {"type": "String"}, "b": {"type": "String"}}},
 "connections_summary_entitiesAround": {"placeholders": {"count": {"type": "int"}}},
}

V = {}
V["en"] = [
 "Around one entity", "Whole map", "View", "Filter", "Filter ({count})", "Details",
 "Presets", "Dive circle", "Who dives where", "Trips and people", "Sites by marine life",
 "Gear together", "Centers and people", "Travel story", "Reef life", "Gear on the road",
 "edited", "Custom map", "Kinds", "Links", "{a} with {b}",
 "{count, plural, =1{At least 1 shared dive} other{At least {count} shared dives}}",
 "Save as map", "Save map", "Name", "Rename", "Update from current",
 "Deleted \"{name}\"", "Undo", "Saved map",
 "Search buddies, sites, trips and more", "Centred on", "Hops", "Show",
 "{kind} ({count})",
 "Search for a buddy, site, trip or anything else to centre the map on it.",
 "No matches", "Centre here", "Summary", "Most connected", "Strongest pair",
 "{count, plural, =1{{a} and {b}, 1 dive} other{{a} and {b}, {count} dives}}",
 "Closest", "{count, plural, =1{1 entity} other{{count} entities}}",
 "All filters", "Clear", "No filters are active.", "Loading connections",
]
V["de"] = [
 "Rund um einen Eintrag", "Gesamte Karte", "Ansicht", "Filter", "Filter ({count})", "Details",
 "Vorlagen", "Tauchkreis", "Wer taucht wo", "Reisen und Personen", "Plätze nach Meeresleben",
 "Ausrüstung zusammen", "Basen und Personen", "Reisegeschichte", "Riffleben", "Ausrüstung unterwegs",
 "bearbeitet", "Eigene Karte", "Arten", "Verbindungen", "{a} mit {b}",
 "{count, plural, =1{Mindestens 1 gemeinsamer Tauchgang} other{Mindestens {count} gemeinsame Tauchgänge}}",
 "Als Karte speichern", "Karte speichern", "Name", "Umbenennen", "Mit aktueller Ansicht aktualisieren",
 "\"{name}\" gelöscht", "Rückgängig", "Gespeicherte Karte",
 "Buddys, Plätze, Reisen und mehr suchen", "Zentriert auf", "Schritte", "Anzeigen",
 "{kind} ({count})",
 "Suche einen Buddy, einen Platz, eine Reise oder etwas anderes, um die Karte darauf zu zentrieren.",
 "Keine Treffer", "Hier zentrieren", "Übersicht", "Am stärksten verbunden", "Stärkstes Paar",
 "{count, plural, =1{{a} und {b}, 1 Tauchgang} other{{a} und {b}, {count} Tauchgänge}}",
 "Am nächsten", "{count, plural, =1{1 Eintrag} other{{count} Einträge}}",
 "Alle Filter", "Zurücksetzen", "Keine Filter aktiv.", "Verbindungen werden geladen",
]
V["es"] = [
 "Alrededor de un elemento", "Mapa completo", "Vista", "Filtro", "Filtro ({count})", "Detalles",
 "Predefinidos", "Círculo de buceo", "Quién bucea dónde", "Viajes y personas", "Puntos por vida marina",
 "Equipo en conjunto", "Centros y personas", "Historia de viaje", "Vida del arrecife", "Equipo de viaje",
 "editado", "Mapa personalizado", "Tipos", "Enlaces", "{a} con {b}",
 "{count, plural, =1{Al menos 1 inmersión compartida} other{Al menos {count} inmersiones compartidas}}",
 "Guardar como mapa", "Guardar mapa", "Nombre", "Renombrar", "Actualizar con la vista actual",
 "\"{name}\" eliminado", "Deshacer", "Mapa guardado",
 "Buscar compañeros, puntos, viajes y otros", "Centrado en", "Saltos", "Mostrar",
 "{kind} ({count})",
 "Busca un compañero, un punto, un viaje u otra cosa para centrar el mapa en ello.",
 "Sin resultados", "Centrar aquí", "Resumen", "Con más conexiones", "Pareja más fuerte",
 "{count, plural, =1{{a} y {b}, 1 inmersión} other{{a} y {b}, {count} inmersiones}}",
 "Más cercano", "{count, plural, =1{1 elemento} other{{count} elementos}}",
 "Todos los filtros", "Borrar", "No hay filtros activos.", "Cargando conexiones",
]
V["fr"] = [
 "Autour d'un élément", "Carte complète", "Vue", "Filtre", "Filtre ({count})", "Détails",
 "Préréglages", "Cercle de plongée", "Qui plonge où", "Voyages et personnes", "Sites par vie marine",
 "Équipement ensemble", "Centres et personnes", "Récit de voyage", "Vie du récif", "Équipement en voyage",
 "modifié", "Carte personnalisée", "Types", "Liens", "{a} avec {b}",
 "{count, plural, =1{Au moins {count} plongée commune} other{Au moins {count} plongées communes}}",
 "Enregistrer comme carte", "Enregistrer la carte", "Nom", "Renommer", "Mettre à jour avec la vue actuelle",
 "« {name} » supprimée", "Annuler", "Carte enregistrée",
 "Rechercher binômes, sites, voyages et plus", "Centré sur", "Sauts", "Afficher",
 "{kind} ({count})",
 "Recherchez un binôme, un site, un voyage ou autre chose pour y centrer la carte.",
 "Aucun résultat", "Centrer ici", "Résumé", "Le plus connecté", "Paire la plus forte",
 "{count, plural, =1{{a} et {b}, {count} plongée} other{{a} et {b}, {count} plongées}}",
 "Le plus proche", "{count, plural, =1{{count} élément} other{{count} éléments}}",
 "Tous les filtres", "Effacer", "Aucun filtre actif.", "Chargement des connexions",
]
V["it"] = [
 "Attorno a un elemento", "Mappa completa", "Vista", "Filtro", "Filtro ({count})", "Dettagli",
 "Predefiniti", "Cerchia di immersione", "Chi si immerge dove", "Viaggi e persone", "Siti per vita marina",
 "Attrezzatura insieme", "Centri e persone", "Storia di viaggio", "Vita della barriera", "Attrezzatura in viaggio",
 "modificato", "Mappa personalizzata", "Tipi", "Collegamenti", "{a} con {b}",
 "{count, plural, =1{Almeno 1 immersione in comune} other{Almeno {count} immersioni in comune}}",
 "Salva come mappa", "Salva mappa", "Nome", "Rinomina", "Aggiorna con la vista attuale",
 "\"{name}\" eliminata", "Annulla", "Mappa salvata",
 "Cerca compagni, siti, viaggi e altro", "Centrata su", "Passi", "Mostra",
 "{kind} ({count})",
 "Cerca un compagno, un sito, un viaggio o altro per centrarvi la mappa.",
 "Nessun risultato", "Centra qui", "Riepilogo", "Il più collegato", "Coppia più forte",
 "{count, plural, =1{{a} e {b}, 1 immersione} other{{a} e {b}, {count} immersioni}}",
 "Il più vicino", "{count, plural, =1{1 elemento} other{{count} elementi}}",
 "Tutti i filtri", "Cancella", "Nessun filtro attivo.", "Caricamento delle connessioni",
]
V["nl"] = [
 "Rond één item", "Volledige kaart", "Weergave", "Filter", "Filter ({count})", "Details",
 "Voorinstellingen", "Duikkring", "Wie duikt waar", "Reizen en mensen", "Duikplekken naar zeeleven",
 "Uitrusting samen", "Duikcentra en mensen", "Reisverhaal", "Rifleven", "Uitrusting onderweg",
 "bewerkt", "Eigen kaart", "Soorten", "Koppelingen", "{a} met {b}",
 "{count, plural, =1{Minstens 1 gedeelde duik} other{Minstens {count} gedeelde duiken}}",
 "Opslaan als kaart", "Kaart opslaan", "Naam", "Hernoemen", "Bijwerken met huidige weergave",
 "\"{name}\" verwijderd", "Ongedaan maken", "Opgeslagen kaart",
 "Zoek buddy's, duikplekken, reizen en meer", "Gecentreerd op", "Stappen", "Tonen",
 "{kind} ({count})",
 "Zoek een buddy, duikplek, reis of iets anders om de kaart erop te centreren.",
 "Geen resultaten", "Hier centreren", "Samenvatting", "Meest verbonden", "Sterkste paar",
 "{count, plural, =1{{a} en {b}, 1 duik} other{{a} en {b}, {count} duiken}}",
 "Dichtstbij", "{count, plural, =1{1 item} other{{count} items}}",
 "Alle filters", "Wissen", "Geen filters actief.", "Verbindingen laden",
]
V["pt"] = [
 "À volta de um elemento", "Mapa completo", "Vista", "Filtro", "Filtro ({count})", "Detalhes",
 "Predefinições", "Círculo de mergulho", "Quem mergulha onde", "Viagens e pessoas", "Locais por vida marinha",
 "Equipamento em conjunto", "Centros e pessoas", "História de viagem", "Vida do recife", "Equipamento em viagem",
 "editado", "Mapa personalizado", "Tipos", "Ligações", "{a} com {b}",
 "{count, plural, =1{Pelo menos {count} mergulho em comum} other{Pelo menos {count} mergulhos em comum}}",
 "Guardar como mapa", "Guardar mapa", "Nome", "Mudar o nome", "Atualizar com a vista atual",
 "\"{name}\" eliminado", "Anular", "Mapa guardado",
 "Pesquisar parceiros, locais, viagens e outros", "Centrado em", "Passos", "Mostrar",
 "{kind} ({count})",
 "Pesquise um parceiro, local, viagem ou outra coisa para centrar o mapa.",
 "Sem resultados", "Centrar aqui", "Resumo", "Mais ligado", "Par mais forte",
 "{count, plural, =1{{a} e {b}, {count} mergulho} other{{a} e {b}, {count} mergulhos}}",
 "Mais próximo", "{count, plural, =1{{count} elemento} other{{count} elementos}}",
 "Todos os filtros", "Limpar", "Nenhum filtro ativo.", "A carregar ligações",
]
V["hu"] = [
 "Egy elem körül", "Teljes térkép", "Nézet", "Szűrő", "Szűrő ({count})", "Részletek",
 "Előbeállítások", "Búvárkör", "Ki hol merül", "Utak és emberek", "Merülőhelyek élővilág szerint",
 "Együtt használt felszerelés", "Központok és emberek", "Úti történet", "Zátonyélet", "Felszerelés úton",
 "módosítva", "Egyéni térkép", "Típusok", "Kapcsolatok", "{a} és {b}",
 "{count, plural, =1{Legalább 1 közös merülés} other{Legalább {count} közös merülés}}",
 "Mentés térképként", "Térkép mentése", "Név", "Átnevezés", "Frissítés a jelenlegi nézettel",
 "\"{name}\" törölve", "Visszavonás", "Mentett térkép",
 "Búvártársak, helyek, utak és más keresése", "Középpontban", "Lépések", "Megjelenítés",
 "{kind} ({count})",
 "Keress egy búvártársat, helyet, utat vagy bármi mást, hogy a térképet köré igazítsd.",
 "Nincs találat", "Középre ide", "Összegzés", "Legtöbb kapcsolat", "Legerősebb pár",
 "{count, plural, =1{{a} és {b}, 1 merülés} other{{a} és {b}, {count} merülés}}",
 "Legközelebbi", "{count, plural, =1{1 elem} other{{count} elem}}",
 "Összes szűrő", "Törlés", "Nincs aktív szűrő.", "Kapcsolatok betöltése",
]
V["zh"] = [
 "围绕单个条目", "完整图谱", "视图", "筛选", "筛选（{count}）", "详情",
 "预设", "潜伴圈", "谁在哪里潜水", "行程与人", "按海洋生物看潜点",
 "一起使用的装备", "潜店与人", "旅行故事", "珊瑚礁生物", "旅途中的装备",
 "已编辑", "自定义图谱", "类型", "连线", "{a} 与 {b}",
 "{count, plural, =1{至少 1 次共同潜水} other{至少 {count} 次共同潜水}}",
 "另存为图谱", "保存图谱", "名称", "重命名", "用当前视图更新",
 "已删除“{name}”", "撤销", "已保存的图谱",
 "搜索潜伴、潜点、行程等", "中心", "跳数", "显示",
 "{kind}（{count}）",
 "搜索潜伴、潜点、行程或其他内容，以其为中心显示图谱。",
 "无匹配结果", "以此为中心", "摘要", "关联最多", "最紧密的一对",
 "{count, plural, =1{{a} 与 {b}，1 次潜水} other{{a} 与 {b}，{count} 次潜水}}",
 "最接近", "{count, plural, =1{1 个条目} other{{count} 个条目}}",
 "全部筛选", "清除", "没有启用的筛选。", "正在加载关联",
]
V["ar"] = [
 "حول عنصر واحد", "الخريطة الكاملة", "العرض", "التصفية", "التصفية ({count})", "التفاصيل",
 "الإعدادات المسبقة", "دائرة الغوص", "من يغوص أين", "الرحلات والأشخاص", "المواقع حسب الحياة البحرية",
 "المعدات معًا", "المراكز والأشخاص", "قصة الرحلة", "حياة الشعاب", "المعدات في السفر",
 "معدّل", "خريطة مخصصة", "الأنواع", "الروابط", "{a} مع {b}",
 "{count, plural, =1{غوصة مشتركة واحدة على الأقل} other{{count} غوصة مشتركة على الأقل}}",
 "حفظ كخريطة", "حفظ الخريطة", "الاسم", "إعادة التسمية", "التحديث من العرض الحالي",
 "تم حذف \"{name}\"", "تراجع", "خريطة محفوظة",
 "ابحث عن الرفقاء والمواقع والرحلات والمزيد", "المركز", "الخطوات", "إظهار",
 "{kind} ({count})",
 "ابحث عن رفيق أو موقع أو رحلة أو أي شيء آخر لتوسيط الخريطة عليه.",
 "لا توجد نتائج", "التوسيط هنا", "الملخص", "الأكثر ارتباطًا", "أقوى ثنائي",
 "{count, plural, =1{{a} و{b}، غوصة واحدة} other{{a} و{b}، {count} غوصة}}",
 "الأقرب", "{count, plural, =1{عنصر واحد} other{{count} عنصرًا}}",
 "كل عوامل التصفية", "مسح", "لا توجد عوامل تصفية نشطة.", "جارٍ تحميل الروابط",
]
V["he"] = [
 "סביב פריט אחד", "מפה מלאה", "תצוגה", "סינון", "סינון ({count})", "פרטים",
 "הגדרות מוכנות", "מעגל הצלילה", "מי צולל איפה", "טיולים ואנשים", "אתרים לפי חיים ימיים",
 "ציוד יחד", "מרכזים ואנשים", "סיפור מסע", "חיי השונית", "ציוד בדרכים",
 "נערך", "מפה מותאמת", "סוגים", "קישורים", "{a} עם {b}",
 "{count, plural, =1{לפחות צלילה משותפת אחת} other{לפחות {count} צלילות משותפות}}",
 "שמירה כמפה", "שמירת מפה", "שם", "שינוי שם", "עדכון מהתצוגה הנוכחית",
 "\"{name}\" נמחקה", "ביטול", "מפה שמורה",
 "חיפוש שותפים, אתרים, טיולים ועוד", "במרכז", "צעדים", "הצגה",
 "{kind} ({count})",
 "חפשו שותף, אתר, טיול או כל דבר אחר כדי למרכז עליו את המפה.",
 "אין תוצאות", "מרכוז כאן", "סיכום", "המקושר ביותר", "הזוג החזק ביותר",
 "{count, plural, =1{{a} ו-{b}, צלילה אחת} other{{a} ו-{b}, {count} צלילות}}",
 "הקרוב ביותר", "{count, plural, =1{פריט אחד} other{{count} פריטים}}",
 "כל המסננים", "ניקוי", "אין מסננים פעילים.", "טוען קשרים",
]

for loc, vals in V.items():
    assert len(vals) == len(KEYS), (loc, len(vals))
    f = Path(f"lib/l10n/arb/app_{loc}.arb")
    lines = f.read_text().split("\n")
    if any(l.startswith('  "connections_mode_around"') for l in lines):
        print(loc, "already has the keys"); continue
    def entry(key, val):
        out = [f'  "{key}": {json.dumps(val, ensure_ascii=False)},']
        if key in META:
            out.append(f'  "@{key}": {json.dumps(META[key])},')
        return out
    if loc == "en":
        # app_en.arb is kept alphabetical: insert each key before the first
        # top-level key that sorts after it.
        for key, val in zip(KEYS, vals):
            idx = next(
                i for i, l in enumerate(lines)
                if l.startswith('  "') and not l.startswith('  "@')
                and l[3:].split('"', 1)[0] > key
            )
            lines[idx:idx] = entry(key, val)
    else:
        idx = next(i for i, l in enumerate(lines) if l.startswith('  "connections_title":'))
        ins = [x for key, val in zip(KEYS, vals) for x in entry(key, val)]
        lines[idx + 1:idx + 1] = ins
    text = "\n".join(lines)
    json.loads(text)
    f.write_text(text)
    print(loc, "ok")
```

Run it from the repository root: `python3.14 "$SCRATCH/l10n_rev2.py"`. Expected output: eleven lines `<locale> ok`.

- [ ] **Step 2: Regenerate and run the l10n guards**

```bash
flutter gen-l10n
flutter test test/l10n/
```
Expected: PASS. `arb_parity_test` confirms every key in every locale; the plural guards confirm French and Portuguese interpolate `{count}` in `=1`. If `spanish_portuguese_diacritics_test` or `arb_diacritics_test` flags a word (an accent twin), reword that locale's value without the flagged word, rerun, and ledger the wording change.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(connections): localisation keys for modes, presets, maps and the panel"
```

---

### Task 9: View-state provider, graph provider, route arguments

**Files:**
- Create: `lib/features/connections/presentation/providers/connections_view_provider.dart`
- Create: `lib/features/connections/presentation/connections_links.dart`
- Modify: `lib/features/connections/presentation/providers/connections_providers.dart`
- Modify: `lib/features/connections/presentation/providers/connections_selection_provider.dart` (remove `connectionsFocusProvider`)
- Modify: `lib/features/connections/presentation/pages/connections_page.dart` (switch to the view provider; interim)
- Modify: `lib/features/connections/presentation/widgets/connections_empty_state.dart`
- Modify: `lib/features/connections/presentation/widgets/selection_details.dart` (Centre here)
- Modify: `lib/features/connections/data/repositories/connections_repository.dart` (drop `loadGraph`)
- Modify: `lib/core/router/app_router.dart` (`/connections` builder)
- Modify: `test/architecture/provider_tick_build_smoke_test.dart`
- Delete: `lib/features/connections/domain/lenses/connection_lens.dart`, `lib/features/connections/domain/entities/connection_query.dart`, `lib/features/connections/presentation/providers/connections_lens_provider.dart`, `lib/features/connections/presentation/widgets/lens_chip_row.dart`, `test/features/connections/domain/lenses/connection_lens_test.dart`, `test/features/connections/domain/entities/connection_query_test.dart`, `test/features/connections/presentation/providers/connections_lens_provider_test.dart`
- Test: `test/features/connections/presentation/providers/connections_view_provider_test.dart` (new)
- Test: `test/features/connections/presentation/connections_links_test.dart` (new)
- Modify tests: `connections_providers_test.dart`, `connections_page_test.dart`, `selection_details_test.dart`, `lens_and_filter_widgets_test.dart`

**Interfaces:**
- Consumes: Task 1 view state, Task 4 repository API.
- Produces:
  - `connectionsViewProvider`: `StateNotifierProvider<ConnectionsViewNotifier, ConnectionsViewState>`; `ConnectionsViewNotifier(SharedPreferences prefs, {Future<bool> Function(String, String)? write})`; `Future<void> update(ConnectionsViewState Function(ConnectionsViewState) change)`; keys `kConnectionsViewKey = 'connections_view_v2'`, `kConnectionsLegacyLensKey = 'connections_last_lens'`.
  - `connectionGraphProvider(int budget)` now reads the view: around without focus returns `ConnectionGraph.empty`; around loads `loadAround`; map loads `loadMap`.
  - `connectionsSearchProvider`: `FutureProvider.autoDispose.family<List<ConnectionNode>, String>`.
  - `connectionsSelectionProvider` unchanged; `connectionsFocusProvider` removed (focus lives in the view state).
  - `String connectionsAroundLocation(NodeRef ref)` → `/connections?mode=around&focus=<wire>`.
  - `ConnectionsRouteArgs({mode, preset, focus, hops, lens, a, b})` (all `String?`), `ConnectionsRouteArgs.fromQuery(Map<String, String>)`, `bool get isEmpty`, `ConnectionsViewState apply(ConnectionsViewState s)`.
  - `ConnectionsPage({Key? key, ConnectionsRouteArgs args = const ConnectionsRouteArgs()})`.
  - `ConnectionsEmptyState({required ConnectionsViewState view, required bool hasAnyDives, bool hasActiveFilter = false})`.

- [ ] **Step 1: Write the failing tests**

`test/features/connections/presentation/providers/connections_view_provider_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _jane = NodeRef(ConnectionKind.buddy, 'jane');

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
  test('starts at the Dive circle preset with nothing stored', () async {
    final (c, _) = await _container({});
    expect(c.read(connectionsViewProvider), ConnectionsViewState.initial);
  });

  test('restores a stored view and prefers it over the legacy lens', () async {
    final stored = ConnectionsViewState.initial.centreOn(_jane).withHops(2);
    final (c, _) = await _container({
      kConnectionsViewKey: jsonEncode(stored.toJson()),
      kConnectionsLegacyLensKey: 'where',
    });
    expect(c.read(connectionsViewProvider), stored);
  });

  test('migrates a phase 1 lens when no view is stored', () async {
    final (c, _) = await _container({kConnectionsLegacyLensKey: 'where'});
    expect(c.read(connectionsViewProvider).presetId, 'where');
  });

  test('garbage in storage falls back to the initial view', () async {
    final (c, _) = await _container({kConnectionsViewKey: '{not json'});
    expect(c.read(connectionsViewProvider), ConnectionsViewState.initial);
  });

  test('update changes state and persists it', () async {
    final (c, sp) = await _container({});
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('reef')!));
    expect(c.read(connectionsViewProvider).presetId, 'reef');
    final saved = ConnectionsViewState.fromJson(
      jsonDecode(sp.getString(kConnectionsViewKey)!),
    );
    expect(saved!.presetId, 'reef');
  });

  test('a failing write keeps the new state and does not throw', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final notifier = ConnectionsViewNotifier(
      sp,
      write: (key, value) => Future.error(StateError('disk full')),
    );
    addTearDown(notifier.dispose);
    await notifier.update((s) => s.centreOn(_jane));
    expect(notifier.state.focus, _jane);
  });
}
```

`test/features/connections/presentation/connections_links_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';

void main() {
  final base = ConnectionsViewState.initial;

  test('the around location carries the mode and the focus', () {
    expect(
      connectionsAroundLocation(const NodeRef(ConnectionKind.site, 's1')),
      '/connections?mode=around&focus=site:s1',
    );
  });

  test('empty args change nothing', () {
    final args = ConnectionsRouteArgs.fromQuery(const {});
    expect(args.isEmpty, isTrue);
    expect(args.apply(base), base);
  });

  test('mode=around&focus centres the view', () {
    final s = ConnectionsRouteArgs.fromQuery(const {
      'mode': 'around',
      'focus': 'diveCenter:c1',
      'hops': '2',
    }).apply(base);
    expect(s.mode, ConnectionsMode.around);
    expect(s.focus, const NodeRef(ConnectionKind.diveCenter, 'c1'));
    expect(s.hops, 2);
  });

  test('a preset applies a map', () {
    final s = ConnectionsRouteArgs.fromQuery(const {
      'mode': 'map',
      'preset': 'travel',
    }).apply(base.centreOn(const NodeRef(ConnectionKind.buddy, 'x')));
    expect(s.mode, ConnectionsMode.map);
    expect(s.presetId, 'travel');
  });

  test('phase 1 links keep working', () {
    final lens = ConnectionsRouteArgs.fromQuery(const {
      'lens': 'where',
      'focus': 'buddy:jane',
    }).apply(base);
    expect(lens.presetId, 'where');
    expect(lens.focus, const NodeRef(ConnectionKind.buddy, 'jane'));
    expect(lens.mode, ConnectionsMode.around);
    final pair = ConnectionsRouteArgs.fromQuery(const {
      'a': 'equipment',
      'b': 'trip',
    }).apply(base);
    expect(pair.mapSpec.links, {
      KindLink(ConnectionKind.equipment, ConnectionKind.trip),
    });
  });

  test('garbage values are ignored', () {
    final s = ConnectionsRouteArgs.fromQuery(const {
      'mode': 'sideways',
      'preset': 'nope',
      'focus': 'unicorn:1',
      'hops': 'many',
    }).apply(base);
    expect(s, base);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/presentation/providers/connections_view_provider_test.dart test/features/connections/presentation/connections_links_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Write the provider and the links file**

`lib/features/connections/presentation/providers/connections_view_provider.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const kConnectionsViewKey = 'connections_view_v2';

/// Phase 1 stored only the lens here; read once to migrate.
const kConnectionsLegacyLensKey = 'connections_last_lens';

const _log = LoggerService('ConnectionsView');

/// The whole Connections view, remembered on this device only.
class ConnectionsViewNotifier extends StateNotifier<ConnectionsViewState> {
  ConnectionsViewNotifier(
    SharedPreferences prefs, {
    Future<bool> Function(String key, String value)? write,
  }) : _write = write ?? prefs.setString,
       super(_restore(prefs));

  final Future<bool> Function(String key, String value) _write;

  static ConnectionsViewState _restore(SharedPreferences prefs) {
    final raw = prefs.getString(kConnectionsViewKey);
    if (raw != null) {
      try {
        final parsed = ConnectionsViewState.fromJson(jsonDecode(raw));
        if (parsed != null) return parsed;
      } on FormatException {
        // Fall through to the legacy key and then the initial view.
      }
    }
    return ConnectionsViewState.fromLegacyLens(
      prefs.getString(kConnectionsLegacyLensKey),
    );
  }

  /// Applies [change] at once and persists the result. A failed write is
  /// logged and otherwise ignored: the view is a convenience, not data.
  Future<void> update(
    ConnectionsViewState Function(ConnectionsViewState) change,
  ) async {
    final next = change(state);
    if (next == state) return;
    state = next;
    try {
      await _write(kConnectionsViewKey, jsonEncode(next.toJson()));
    } catch (e, st) {
      _log.warning(
        'Could not remember the connections view',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final connectionsViewProvider =
    StateNotifierProvider<ConnectionsViewNotifier, ConnectionsViewState>(
      (ref) => ConnectionsViewNotifier(ref.watch(sharedPreferencesProvider)),
    );
```

`lib/features/connections/presentation/connections_links.dart`:

```dart
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

/// The deep link every detail page's "Open in Connections" pushes.
String connectionsAroundLocation(NodeRef ref) =>
    '/connections?mode=around&focus=${ref.wire}';

/// `/connections` query parameters. Revision 2 uses `mode`, `preset`,
/// `focus` and `hops`; phase 1's `lens`, `a` and `b` stay accepted.
class ConnectionsRouteArgs {
  const ConnectionsRouteArgs({
    this.mode,
    this.preset,
    this.focus,
    this.hops,
    this.lens,
    this.a,
    this.b,
  });

  factory ConnectionsRouteArgs.fromQuery(Map<String, String> q) =>
      ConnectionsRouteArgs(
        mode: q['mode'],
        preset: q['preset'],
        focus: q['focus'],
        hops: q['hops'],
        lens: q['lens'],
        a: q['a'],
        b: q['b'],
      );

  final String? mode;
  final String? preset;
  final String? focus;
  final String? hops;
  final String? lens;
  final String? a;
  final String? b;

  bool get isEmpty => [mode, preset, focus, hops, lens, a, b].every((v) => v == null);

  /// Applies the recognised parameters to [s]; anything unrecognised is
  /// ignored.
  ConnectionsViewState apply(ConnectionsViewState s) {
    var next = s;
    final preset = ConnectionPresets.byId(this.preset ?? lens);
    final kindA = ConnectionKind.fromName(a);
    final kindB = ConnectionKind.fromName(b);
    if (preset != null) {
      next = next.applyPreset(preset);
    } else if (kindA != null && kindB != null) {
      next = next.editMap(MapSpec.of({kindA, kindB}, {KindLink(kindA, kindB)}));
    }
    final ref = NodeRef.parse(focus);
    if (ref != null && mode != 'map') next = next.centreOn(ref);
    final n = int.tryParse(hops ?? '');
    if (n != null) next = next.withHops(n);
    if (mode == 'map') next = next.withMode(ConnectionsMode.map);
    if (mode == 'around' && ref == null) {
      next = next.withMode(ConnectionsMode.around);
    }
    return next;
  }
}
```

- [ ] **Step 4: Switch the providers over**

Replace the body of `connections_providers.dart` below `connectionsRepositoryProvider` with:

```dart
/// The graph for the current view and filter, trimmed to the node budget
/// given as the family key (the page picks 80 or 160 by width).
final connectionGraphProvider = FutureProvider.autoDispose
    .family<ConnectionGraph, int>((ref, nodeBudget) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final view = ref.watch(connectionsViewProvider);
      final filter = ref.watch(connectionsFilterProvider);
      if (view.isAroundWithoutFocus) return ConnectionGraph.empty;
      if (view.mode == ConnectionsMode.around) {
        return repository.loadAround(
          focus: view.focus!,
          kinds: view.aroundKinds,
          hops: view.hops,
          diverId: diverId,
          filter: filter,
          nodeBudget: nodeBudget,
        );
      }
      return repository.loadMap(
        view.mapSpec,
        diverId: diverId,
        filter: filter,
        nodeBudget: nodeBudget,
      );
    });

/// Entities of any kind whose name contains the text, for the Around
/// search field.
final connectionsSearchProvider = FutureProvider.autoDispose
    .family<List<ConnectionNode>, String>((ref, text) async {
      final repository = ref.watch(connectionsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionsChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      return repository.searchEntities(text, diverId: diverId);
    });
```

Keep `connectionsYearSpanProvider` and `connectionsSelectionDiveIdsProvider` as they are. Imports: add `connection_node.dart`, `views/connections_view_state.dart`, `connections_view_provider.dart`; remove `connection_query.dart`, `connections_lens_provider.dart`, and `connections_selection_provider.dart` if it is no longer used there.

In `connections_selection_provider.dart`, delete `connectionsFocusProvider` and the `node_ref.dart` import.

In `connections_repository.dart`, delete `loadGraph` and the `connection_query.dart` import. Delete the four source files and three test files listed under **Delete**.

Add to the `connections` group of `provider_tick_build_smoke_test.dart`:

```dart
    (
      name: 'connectionsSearchProvider',
      read: (c) => c.read(connectionsSearchProvider('a').future),
    ),
```

- [ ] **Step 5: Move the page, empty state, details and router onto the view**

`connections_empty_state.dart`: replace the `lens` field with `required this.view` of type `ConnectionsViewState`, and compute:

```dart
    final kinds = view.mode == ConnectionsMode.map
        ? view.mapSpec.kinds
        : view.aroundKinds;
    final involvesBuddies = kinds.contains(ConnectionKind.buddy);
    final text = view.isAroundWithoutFocus
        ? l10n.connections_around_prompt
        : !hasAnyDives
        ? l10n.connections_empty_noDives
        : hasActiveFilter
        ? l10n.connections_empty_filtered
        : involvesBuddies
        ? l10n.connections_empty_buddies
        : l10n.connections_empty_sites;
```

`selection_details.dart`: the Focus button becomes

```dart
            if (focusRef != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.center_focus_strong),
                label: Text(l10n.connections_action_centreHere),
                onPressed: () {
                  ref
                      .read(connectionsViewProvider.notifier)
                      .update((s) => s.centreOn(focusRef));
                  ref.read(connectionsSelectionProvider.notifier).state =
                      NodeSelection(focusRef);
                },
              ),
```

`connections_page.dart` (interim; Task 15 rebuilds the page):

- Constructor: replace the four string fields with `this.args = const ConnectionsRouteArgs()` and `final ConnectionsRouteArgs args;`.
- `_deepLinkPending` becomes `late bool _deepLinkPending = !widget.args.isEmpty;`.
- `_applyDeepLink` becomes:

```dart
  void _applyDeepLink() {
    if (!mounted) return;
    ref.read(connectionsViewProvider.notifier).update(widget.args.apply);
    final focus = NodeRef.parse(widget.args.focus);
    if (focus != null) {
      ref.read(connectionsSelectionProvider.notifier).state = NodeSelection(
        focus,
      );
    }
  }
```

- In `_warnFocusMissing`, replace the focus reset with `ref.read(connectionsViewProvider.notifier).update((s) => s.copyWith(clearFocus: true));`.
- In `build`: `final view = ref.watch(connectionsViewProvider);` and `final focus = view.mode == ConnectionsMode.around ? view.focus : null;` replace the lens and focus watches; the canvas `onFocus` becomes `ref.read(connectionsViewProvider.notifier).update((s) => s.centreOn(node))` followed by the selection write; `ConnectionsEmptyState(view: view, ...)`; the exit-focus button calls `ref.read(connectionsViewProvider.notifier).update((s) => s.withMode(ConnectionsMode.map))` and clears the selection; remove both `const LensChipRow(),` entries.
- Fix imports: drop lens, lens provider and lens chip row imports; add `connections_links.dart`, `connections_view_provider.dart`, `views/connections_view_state.dart`.

`app_router.dart`, the `/connections` route:

```dart
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: ConnectionsPage(
                args: ConnectionsRouteArgs.fromQuery(state.uri.queryParameters),
              ),
            ),
```

with `import 'package:submersion/features/connections/presentation/connections_links.dart';`.

- [ ] **Step 6: Update the existing tests**

Mechanical replacements across `connections_providers_test.dart`, `connections_page_test.dart`, `selection_details_test.dart`:

| Old | New |
| --- | --- |
| `c.read(connectionsFocusProvider)` | `c.read(connectionsViewProvider).focus` |
| `c.read(connectionsFocusProvider.notifier).state = X;` (X a `NodeRef`) | `await c.read(connectionsViewProvider.notifier).update((s) => s.centreOn(X));` |
| `c.read(connectionsLensProvider).lensId, 'where'` | `c.read(connectionsViewProvider).presetId, 'where'` |
| `.read(connectionsLensProvider.notifier).select(const LensSelection.lens(ConnectionLens.where))` | `await c.read(connectionsViewProvider.notifier).update((s) => s.applyPreset(ConnectionPresets.byId('where')!))` |
| `ref.read(connectionsFocusProvider)` / `ref.watch(connectionsFocusProvider)` inside overrides | `ref.read(connectionsViewProvider).focus` / `ref.watch(connectionsViewProvider).focus` |
| `ConnectionsPage(lensId: q['lens'], kindAName: q['a'], kindBName: q['b'], focusWire: q['focus'])` | `ConnectionsPage(args: ConnectionsRouteArgs.fromQuery(q))` |
| `find.text('Focus')` | `find.text('Centre here')` |

Behaviour changes to reflect in expectations:
- `connections_page_test.dart` `'phone layout: ...'`: remove `expect(find.text('Dive circle'), findsOneWidget);` (chips return inside the panel in Task 13).
- `connections_page_test.dart` `'a focus outside the lens opens unfocused with a snackbar'`: Around mode covers every kind, so rename it `'a site focus from a buddy lens centres on the site'` and expect `c.read(connectionsViewProvider).focus == NodeRef(ConnectionKind.site, 's1')` and no snackbar.
- `connections_page_test.dart` `'a missing focus clears and warns'` and `'a focus that vanishes twice is reset both times'`: the focus reset leaves Around mode with no centre; the assertions on `focus` being null stay as they are.
- `connections_providers_test.dart` `'changing the filter or lens reloads'`: after `applyPreset(where)` the buddy-only nodes assertion becomes "every node is a buddy or a site"; with no site on the seeded dives, keep `expect(where.edges, isEmpty)`.
- `lens_and_filter_widgets_test.dart`: delete the `'lens chips switch the lens ...'` test and the `lens_chip_row.dart` import; the filter bar and year slider tests stay (the filter bar is removed in Task 21).

- [ ] **Step 7: Run the tests**

```bash
flutter test test/features/connections/ test/architecture/ test/core/router/app_router_test.dart
```
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add -A lib/features/connections test/features/connections lib/core/router/app_router.dart test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(connections): view-state provider, map and around graph loads, route arguments"
```

---

### Task 10: Graph summary

**Files:**
- Create: `lib/features/connections/domain/views/graph_summary.dart`
- Test: `test/features/connections/domain/views/graph_summary_test.dart`

**Interfaces:**
- Consumes: `ConnectionGraph`, `ConnectionNode`, `ConnectionEdge`, `NodeRef`.
- Produces: `GraphSummary.of(ConnectionGraph graph, {NodeRef? focus})` with fields `Map<ConnectionKind, int> countsByKind` (focus excluded when given), `int connectionCount`, `ConnectionNode? mostConnected` (highest weighted degree; focus excluded; ties by dive count then label), `int mostConnectedDegree`, `ConnectionEdge? strongest` (heaviest edge; ties by later `lastDiveAt`, then source wire), `int entitiesAround` (node count minus the focus; equals node count without a focus), `ConnectionNode? closest` (other end of the heaviest edge touching the focus; null without a focus), `int closestWeight`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);
ConnectionNode _n(NodeRef r, int dives) =>
    ConnectionNode(ref: r, label: r.id, diveCount: dives);
ConnectionEdge _e(NodeRef a, NodeRef b, int w, {int year = 2024}) =>
    ConnectionEdge(
      source: a,
      target: b,
      weight: w,
      firstDiveAt: DateTime.utc(2020),
      lastDiveAt: DateTime.utc(year),
    );

void main() {
  final graph = ConnectionGraph(
    nodes: [
      _n(_b('kiyan'), 34),
      _n(_b('sharon'), 20),
      _n(_b('lou'), 3),
      _n(_s('pier'), 14),
    ],
    edges: [
      _e(_b('kiyan'), _b('sharon'), 12),
      _e(_b('kiyan'), _s('pier'), 9),
      _e(_b('sharon'), _s('pier'), 4),
      _e(_b('kiyan'), _b('lou'), 2),
    ],
  );

  test('map summary: counts, connections, most connected, strongest', () {
    final s = GraphSummary.of(graph);
    expect(s.countsByKind, {ConnectionKind.buddy: 3, ConnectionKind.site: 1});
    expect(s.connectionCount, 4);
    expect(s.mostConnected!.ref, _b('kiyan'));
    expect(s.mostConnectedDegree, 23);
    expect(s.strongest!.weight, 12);
    expect(s.entitiesAround, 4);
    expect(s.closest, isNull);
  });

  test('around summary excludes the focus and finds the closest', () {
    final s = GraphSummary.of(graph, focus: _b('kiyan'));
    expect(s.entitiesAround, 3);
    expect(s.countsByKind, {ConnectionKind.buddy: 2, ConnectionKind.site: 1});
    expect(s.closest!.ref, _b('sharon'));
    expect(s.closestWeight, 12);
    expect(s.mostConnected!.ref, _b('sharon'));
  });

  test('ties in strength go to the more recent pair', () {
    final g = ConnectionGraph(
      nodes: [_n(_b('a'), 1), _n(_b('b'), 1), _n(_b('c'), 1)],
      edges: [
        _e(_b('a'), _b('b'), 5, year: 2020),
        _e(_b('a'), _b('c'), 5, year: 2025),
      ],
    );
    expect(GraphSummary.of(g).strongest!.target, _b('c'));
  });

  test('an empty graph summarises to nothing', () {
    final s = GraphSummary.of(ConnectionGraph.empty);
    expect(s.countsByKind, isEmpty);
    expect(s.connectionCount, 0);
    expect(s.mostConnected, isNull);
    expect(s.strongest, isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/domain/views/graph_summary_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// What the map in view says, for the panel's Summary block.
class GraphSummary {
  const GraphSummary._({
    required this.countsByKind,
    required this.connectionCount,
    required this.mostConnected,
    required this.mostConnectedDegree,
    required this.strongest,
    required this.entitiesAround,
    required this.closest,
    required this.closestWeight,
  });

  factory GraphSummary.of(ConnectionGraph graph, {NodeRef? focus}) {
    final others = graph.nodes.where((n) => n.ref != focus).toList();
    final counts = <ConnectionKind, int>{};
    for (final n in others) {
      counts[n.ref.kind] = (counts[n.ref.kind] ?? 0) + 1;
    }
    final degree = <NodeRef, int>{};
    for (final e in graph.edges) {
      degree[e.source] = (degree[e.source] ?? 0) + e.weight;
      degree[e.target] = (degree[e.target] ?? 0) + e.weight;
    }
    ConnectionNode? most;
    for (final n in others) {
      if (most == null) {
        most = n;
        continue;
      }
      final byDegree = (degree[n.ref] ?? 0).compareTo(degree[most.ref] ?? 0);
      if (byDegree > 0 ||
          (byDegree == 0 &&
              (n.diveCount > most.diveCount ||
                  (n.diveCount == most.diveCount &&
                      n.label.compareTo(most.label) < 0)))) {
        most = n;
      }
    }
    ConnectionEdge? strongest;
    for (final e in graph.edges) {
      if (strongest == null || _stronger(e, strongest)) strongest = e;
    }
    ConnectionEdge? closestEdge;
    if (focus != null) {
      for (final e in graph.edges.where((e) => e.touches(focus))) {
        if (closestEdge == null || _stronger(e, closestEdge)) closestEdge = e;
      }
    }
    final closestRef = closestEdge?.otherEnd(focus!);
    return GraphSummary._(
      countsByKind: Map.unmodifiable(counts),
      connectionCount: graph.edges.length,
      mostConnected: (degree[most?.ref] ?? 0) > 0 ? most : null,
      mostConnectedDegree: degree[most?.ref] ?? 0,
      strongest: strongest,
      entitiesAround: others.length,
      closest: closestRef == null ? null : graph.nodeFor(closestRef),
      closestWeight: closestEdge?.weight ?? 0,
    );
  }

  static bool _stronger(ConnectionEdge a, ConnectionEdge b) {
    if (a.weight != b.weight) return a.weight > b.weight;
    if (a.lastDiveAt != b.lastDiveAt) return a.lastDiveAt.isAfter(b.lastDiveAt);
    return a.source.wire.compareTo(b.source.wire) < 0;
  }

  final Map<ConnectionKind, int> countsByKind;
  final int connectionCount;
  final ConnectionNode? mostConnected;
  final int mostConnectedDegree;
  final ConnectionEdge? strongest;
  final int entitiesAround;
  final ConnectionNode? closest;
  final int closestWeight;
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/connections/domain/views/graph_summary_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/domain/views/graph_summary.dart test/features/connections/domain/views/graph_summary_test.dart
git commit -m "feat(connections): graph summary for the panel"
```

---

### Task 11: Extract the active-filter chips into a shared widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/active_filter_chips.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildActiveFiltersBar` at line 2088, `_buildFilterChip` at line 2293)
- Test: `test/features/dive_log/presentation/widgets/active_filter_chips_test.dart`

**Interfaces:**
- Produces: `List<Widget> activeDiveFilterChips(BuildContext context, WidgetRef ref, StateProvider<DiveFilterState> filterProvider)`: one removable chip per active axis the dive list shows today (date range, dive type, site, trip, dive center, equipment, depth, favorites, no buddy, tags, buddy name), each deleting its axis on **the given provider**.

This is a behaviour-preserving move: the dive list keeps its bar layout and its existing tests (`dive_list_content_test.dart`, `dive_list_content_dive_type_chip_test.dart`, `dive_list_content_no_buddy_chip_test.dart`) are the regression net.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chips.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _otherFilterProvider = StateProvider<DiveFilterState>(
  (ref) => DiveFilterState(
    startDate: DateTime(2021),
    endDate: DateTime(2024, 12, 31),
    favoritesOnly: true,
  ),
);

void main() {
  testWidgets('chips edit the provider they are given, not the dive list', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Wrap(
                children: activeDiveFilterChips(
                  context,
                  ref,
                  _otherFilterProvider,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Chip), findsNWidgets(2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    final after = container.read(_otherFilterProvider);
    expect(after.startDate, isNull);
    expect(after.endDate, isNull);
    expect(after.favoritesOnly, isTrue);
    expect(container.read(diveFilterProvider).hasActiveFilters, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/active_filter_chips_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Move the code**

Create `active_filter_chips.dart` containing:

```dart
/// One removable chip per active axis of the filter in [filterProvider].
/// Shared by the dive list's filter bar and the Connections Filter tab, so
/// both describe a filter the same way.
List<Widget> activeDiveFilterChips(
  BuildContext context,
  WidgetRef ref,
  StateProvider<DiveFilterState> filterProvider,
) {
  final filter = ref.watch(filterProvider);
  final settings = ref.watch(settingsProvider);
  final units = UnitFormatter(settings);
  final chips = <Widget>[];
  // Moved verbatim from DiveListContent._buildActiveFiltersBar: every
  // `if (filter.<axis> ...) { ... chips.add(...) }` block, in the same order.
  return chips;
}

Widget _chip(BuildContext context, String label, VoidCallback onRemove) {
  // Moved verbatim from DiveListContent._buildFilterChip.
}
```

Fill both bodies by moving, unchanged except for these substitutions, the code between `final chips = <Widget>[];` and `return Container(` in `_buildActiveFiltersBar` (dive_list_content.dart lines 2092 to 2273) and the whole body of `_buildFilterChip` (lines 2293 to 2308):

- `ref.read(diveFilterProvider.notifier)` → `ref.read(filterProvider.notifier)`
- `_buildFilterChip(` → `_chip(`

Move the imports those blocks use (`UnitFormatter`, `settingsProvider`, `diveTypeProvider`, `builtInDiveTypeName`, `siteProvider`, `tripByIdProvider`, `diveCenterByIdProvider`, `equipmentItemProvider`, `l10n_extension`, `DiveFilterState`, `provider.dart`, `material.dart`); the analyzer names any that are missing.

In `dive_list_content.dart`, `_buildActiveFiltersBar` keeps its first line `final filter = ...` only if still used; its chip section becomes:

```dart
    final chips = activeDiveFilterChips(context, ref, diveFilterProvider);
```

followed by the unchanged `return Container(...)`. Delete `_buildFilterChip` and any import that is now unused.

- [ ] **Step 4: Run the dive list and new tests**

```bash
flutter test test/features/dive_log/presentation/widgets/
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/widgets test/features/dive_log/presentation/widgets/active_filter_chips_test.dart
git commit -m "refactor(dive-log): share the active filter chips"
```

---

### Task 12: Panel host with the Filter and Details tabs

**Files:**
- Create: `lib/features/connections/presentation/panel/connections_panel.dart`
- Create: `lib/features/connections/presentation/panel/filter_tab.dart`
- Create: `lib/features/connections/presentation/panel/details_tab.dart`
- Test: `test/features/connections/presentation/panel/connections_panel_test.dart`

**Interfaces:**
- Consumes: `activeDiveFilterChips` (Task 11), `YearRangeSlider`, `GraphSelectionDetails`, `DiveFilterSheet(ref:, filterProvider:)`, `connectionsFilterProvider`, `connectionsSelectionProvider`, Task 8 strings.
- Produces:
  - `ConnectionsPanel({required Widget viewTab, required ConnectionGraph graph, ScrollController? scrollController, bool compact = false})`. Three tabs (View, Filter, Details); the tab content renders inside one `ListView` (attached to `scrollController` when given, so the phone sheet can drag it). Selecting a node or edge switches to Details; clearing the selection returns to the tab open before. The Filter tab label reads `connections_tab_filterCount(n)` when `n` filter axes are active.
  - `FilterTab()`, `DetailsTab({required ConnectionGraph graph})`.
  - Keys: `ValueKey('connections-panel')`, `ValueKey('connections-tab-view')`, `...-tab-filter`, `...-tab-details`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/panel/connections_panel.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _jane = NodeRef(ConnectionKind.buddy, 'jane');
final _graph = ConnectionGraph(
  nodes: [ConnectionNode(ref: _jane, label: 'Jane', diveCount: 3)],
  edges: const [],
);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionsYearSpanProvider.overrideWith(
          (ref) async => (first: 2019, last: 2024),
        ),
        connectionsSelectionDiveIdsProvider.overrideWith(
          (ref, s) async => ['d1'],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 340,
                child: ConnectionsPanel(
                  viewTab: const Text('VIEW_TAB'),
                  graph: _graph,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('opens on the View tab', (tester) async {
    await _pump(tester);
    expect(find.text('VIEW_TAB'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('the Filter tab shows the slider, chips and actions', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('connections-tab-filter')));
    await tester.pumpAndSettle();
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('No filters are active.'), findsOneWidget);

    c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
      startDate: DateTime(2021),
      endDate: DateTime(2023, 12, 31),
      favoritesOnly: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Filter (2)'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(2));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsFilterProvider).hasActiveFilters, isFalse);

    await tester.tap(find.text('All filters'));
    await tester.pumpAndSettle();
    expect(find.byType(DiveFilterSheet), findsOneWidget);
  });

  testWidgets('a selection opens Details and clearing it goes back', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('connections-tab-filter')));
    await tester.pumpAndSettle();

    c.read(connectionsSelectionProvider.notifier).state = const NodeSelection(
      _jane,
    );
    await tester.pumpAndSettle();
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('Centre here'), findsOneWidget);

    c.read(connectionsSelectionProvider.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.byType(RangeSlider), findsOneWidget);
  });

  testWidgets('Details without a selection shows the hint', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('connections-tab-details')));
    await tester.pumpAndSettle();
    expect(find.text('Tap a node or a line to see details.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/panel/connections_panel_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Implement the three files**

`lib/features/connections/presentation/panel/filter_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/year_range_slider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chips.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Years, the active filter axes as removable chips, the full filter sheet
/// and Clear. Everything here writes `connectionsFilterProvider`.
class FilterTab extends ConsumerWidget {
  const FilterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chips = activeDiveFilterChips(context, ref, connectionsFilterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const YearRangeSlider(),
        const SizedBox(height: 8),
        if (chips.isEmpty)
          Text(
            l10n.connections_filter_none,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Wrap(runSpacing: 4, children: chips),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.tune),
              label: Text(l10n.connections_filter_allFilters),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => DiveFilterSheet(
                  ref: ref,
                  filterProvider: connectionsFilterProvider,
                ),
              ),
            ),
            if (chips.isNotEmpty)
              TextButton(
                onPressed: () => ref
                    .read(connectionsFilterProvider.notifier)
                    .state = const DiveFilterState(),
                child: Text(l10n.connections_filter_clear),
              ),
          ],
        ),
      ],
    );
  }
}
```

`lib/features/connections/presentation/panel/details_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_details.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DetailsTab extends ConsumerWidget {
  const DetailsTab({super.key, required this.graph});

  final ConnectionGraph graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(connectionsSelectionProvider);
    if (selection == null) {
      final theme = Theme.of(context);
      return Text(
        context.l10n.connections_selection_hint,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return GraphSelectionDetails(graph: graph, selection: selection);
  }
}
```

`lib/features/connections/presentation/panel/connections_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/presentation/panel/details_tab.dart';
import 'package:submersion/features/connections/presentation/panel/filter_tab.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The View, Filter and Details tabs: the fixed right panel on wide
/// layouts, the draggable sheet's body on phones.
class ConnectionsPanel extends ConsumerStatefulWidget {
  const ConnectionsPanel({
    super.key,
    required this.viewTab,
    required this.graph,
    this.scrollController,
    this.compact = false,
  });

  final Widget viewTab;
  final ConnectionGraph graph;

  /// The sheet's controller on phones, so dragging the content drags the
  /// sheet. Null on wide layouts.
  final ScrollController? scrollController;
  final bool compact;

  static const int viewIndex = 0;
  static const int filterIndex = 1;
  static const int detailsIndex = 2;

  @override
  ConsumerState<ConnectionsPanel> createState() => _ConnectionsPanelState();
}

class _ConnectionsPanelState extends ConsumerState<ConnectionsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  /// The tab to return to when the selection clears.
  int _beforeDetails = ConnectionsPanel.viewIndex;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onSelection(GraphSelection? previous, GraphSelection? next) {
    if (next != null && previous == null) {
      if (_tabs.index != ConnectionsPanel.detailsIndex) {
        _beforeDetails = _tabs.index;
      }
      _tabs.animateTo(ConnectionsPanel.detailsIndex);
    } else if (next == null && previous != null) {
      _tabs.animateTo(_beforeDetails);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectionsSelectionProvider, _onSelection);
    ref.watch(connectionsFilterProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filterCount = activeDiveFilterChips(
      context,
      ref,
      connectionsFilterProvider,
    ).length;
    final content = switch (_tabs.index) {
      ConnectionsPanel.filterIndex => const FilterTab(),
      ConnectionsPanel.detailsIndex => DetailsTab(graph: widget.graph),
      _ => widget.viewTab,
    };
    return Material(
      key: const ValueKey('connections-panel'),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        children: [
          if (widget.compact)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(
                key: const ValueKey('connections-tab-view'),
                text: l10n.connections_tab_view,
              ),
              Tab(
                key: const ValueKey('connections-tab-filter'),
                text: filterCount == 0
                    ? l10n.connections_tab_filter
                    : l10n.connections_tab_filterCount(filterCount),
              ),
              Tab(
                key: const ValueKey('connections-tab-details'),
                text: l10n.connections_tab_details,
              ),
            ],
          ),
          Padding(padding: const EdgeInsets.all(16), child: content),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/connections/presentation/panel/connections_panel_test.dart`
Expected: PASS. If the Details assertion finds `'Jane'` twice (the tab and the list), narrow it with `find.descendant(of: find.byType(GraphSelectionDetails), matching: find.text('Jane'))`.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/panel test/features/connections/presentation/panel
git commit -m "feat(connections): tabbed panel with Filter and Details tabs"
```

---

### Task 13: Mode switch, preset grid, map editor, save dialog

**Files:**
- Create: `lib/features/connections/presentation/panel/mode_switch.dart`
- Create: `lib/features/connections/presentation/panel/preset_grid.dart`
- Create: `lib/features/connections/presentation/panel/map_editor.dart`
- Create: `lib/features/connections/presentation/panel/save_map_dialog.dart`
- Test: `test/features/connections/presentation/panel/view_controls_test.dart`

**Interfaces:**
- Consumes: `connectionsViewProvider` (Task 9), `ConnectionPresets`, `MapSpec`, `KindLink` (Task 1), `savedConnectionMapsProvider`, `connectionMapRepositoryProvider`, `SavedConnectionMap` (Task 7), `validatedCurrentDiverIdProvider`, `kindLabel` (`presentation/widgets/connections_legend.dart`), `ConnectionKindColors`.
- Produces:
  - `ModeSwitch()` (a `SegmentedButton<ConnectionsMode>`).
  - `String presetLabel(AppLocalizations l10n, String id)`.
  - `PresetGrid()`: nine preset cards then one card per saved map, two columns, each with a dot per kind; selected card outlined; the card a custom map came from shows `connections_preset_edited`; saved cards carry a bookmark icon and an overflow menu (Rename, Update from current, Delete with an undo snackbar).
  - `MapEditor()`: an `ExpansionTile` titled `connections_editor_title`, initially expanded only when the view is a custom map; kind `FilterChip`s for all ten kinds; one `CheckboxListTile` per `possibleLinks` entry; the minimum slider; a *Save as map* button.
  - `Future<String?> showSaveMapDialog(BuildContext context, {required String title, String initialName = ''})`: returns the trimmed name, or null on cancel or an empty name.
  - Keys: `ValueKey('preset-<id>')` on preset cards, `ValueKey('saved-map-<id>')` on saved cards, `ValueKey('kind-chip-<kind.name>')`, `ValueKey('link-<link.wire>')`, `ValueKey('min-shared-slider')`, `ValueKey('save-as-map')`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connection_map_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/connections/presentation/panel/map_editor.dart';
import 'package:submersion/features/connections/presentation/panel/mode_switch.dart';
import 'package:submersion/features/connections/presentation/panel/preset_grid.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeMaps implements ConnectionMapRepository {
  final List<SavedConnectionMap> maps = [];
  final List<String> calls = [];

  @override
  Stream<void> watchConnectionMapsChanges() => const Stream.empty();

  @override
  Future<List<SavedConnectionMap>> getAll(String diverId) async => [...maps];

  @override
  Future<SavedConnectionMap> create({
    required String diverId,
    required String name,
    required MapSpec spec,
  }) async {
    final m = SavedConnectionMap(
      id: 'new-${maps.length}',
      diverId: diverId,
      name: name,
      spec: spec,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    maps.add(m);
    calls.add('create:$name');
    return m;
  }

  @override
  Future<void> rename(String id, String name) async => calls.add('rename:$id:$name');

  @override
  Future<void> updateSpec(String id, MapSpec spec) async => calls.add('update:$id');

  @override
  Future<void> delete(String id) async {
    maps.removeWhere((m) => m.id == id);
    calls.add('delete:$id');
  }

  @override
  Future<void> restore(SavedConnectionMap map) async {
    maps.add(map);
    calls.add('restore:${map.id}');
  }
}

final _saved = SavedConnectionMap(
  id: 'bon',
  diverId: 'me',
  name: 'Bonaire 2025',
  spec: ConnectionPresets.byId('travel')!.spec,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<(ProviderContainer, _FakeMaps)> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeMaps()..maps.add(_saved);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionMapRepositoryProvider.overrideWithValue(fake),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (ProviderScope.containerOf(tester.element(find.byType(Scaffold))), fake);
}

void main() {
  testWidgets('the mode switch changes the view mode', (tester) async {
    final (c, _) = await _pump(tester, const ModeSwitch());
    await tester.tap(find.text('Around one entity'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).mode, ConnectionsMode.around);
  });

  testWidgets('nine presets and the saved map; tapping applies', (tester) async {
    final (c, _) = await _pump(tester, const PresetGrid());
    for (final p in ConnectionPresets.all) {
      expect(find.byKey(ValueKey('preset-${p.id}')), findsOneWidget);
    }
    expect(find.text('Bonaire 2025'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preset-reef')));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).presetId, 'reef');
    await tester.tap(find.byKey(const ValueKey('saved-map-bon')));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).savedMapId, 'bon');
  });

  testWidgets('an edited preset shows its mark until another is chosen', (
    tester,
  ) async {
    final (c, _) = await _pump(
      tester,
      const Column(children: [PresetGrid(), MapEditor()]),
    );
    await tester.tap(find.byKey(const ValueKey('preset-travel')));
    await tester.pumpAndSettle();
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.editMap(s.mapSpec.withMinimum(2)));
    await tester.pumpAndSettle();
    expect(find.text('edited'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preset-reef')));
    await tester.pumpAndSettle();
    expect(find.text('edited'), findsNothing);
  });

  testWidgets('the editor ticks kinds, links and the minimum', (tester) async {
    final (c, _) = await _pump(tester, const MapEditor());
    await tester.tap(find.text('Custom map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kind-chip-site')));
    await tester.pumpAndSettle();
    var spec = c.read(connectionsViewProvider).mapSpec;
    expect(spec.kinds, {ConnectionKind.buddy, ConnectionKind.site});
    expect(spec.links, contains(KindLink(ConnectionKind.buddy, ConnectionKind.site)));
    expect(c.read(connectionsViewProvider).editedFromPresetId, 'circle');

    await tester.tap(find.byKey(const ValueKey('link-buddy-buddy')));
    await tester.pumpAndSettle();
    spec = c.read(connectionsViewProvider).mapSpec;
    expect(spec.links, isNot(contains(KindLink(ConnectionKind.buddy, ConnectionKind.buddy))));

    final slider = tester.widget<Slider>(find.byKey(const ValueKey('min-shared-slider')));
    slider.onChangeEnd!(4);
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).mapSpec.minSharedDives, 4);
    expect(find.text('At least 4 shared dives'), findsOneWidget);
  });

  testWidgets('Save as map stores the edited spec and selects it', (tester) async {
    final (c, fake) = await _pump(tester, const MapEditor());
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.editMap(s.mapSpec.withKind(ConnectionKind.trip)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-as-map')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Liveaboard  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['create:Liveaboard']);
    expect(fake.maps.last.spec.kinds, contains(ConnectionKind.trip));
    expect(c.read(connectionsViewProvider).savedMapId, fake.maps.last.id);
  });

  testWidgets('deleting a saved map offers undo', (tester) async {
    final (_, fake) = await _pump(tester, const PresetGrid());
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('saved-map-bon')),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['delete:bon']);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['delete:bon', 'restore:bon']);
  });
}
```

The save dialog's confirm button uses `common_action_save` ("Save").

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/panel/view_controls_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Implement the four files**

`mode_switch.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class ModeSwitch extends ConsumerWidget {
  const ModeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(connectionsViewProvider.select((s) => s.mode));
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ConnectionsMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: ConnectionsMode.around,
            label: Text(l10n.connections_mode_around, softWrap: true),
          ),
          ButtonSegment(
            value: ConnectionsMode.map,
            label: Text(l10n.connections_mode_map, softWrap: true),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => ref
            .read(connectionsViewProvider.notifier)
            .update((v) => v.withMode(s.single)),
      ),
    );
  }
}
```

`save_map_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for a map name. Returns the trimmed name, or null when cancelled or
/// left empty.
Future<String?> showSaveMapDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
}) async {
  final controller = TextEditingController(text: initialName);
  final l10n = context.l10n;
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.connections_savedMap_nameLabel),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(l10n.common_action_save),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = name?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
```

`preset_grid.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/panel/save_map_dialog.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

String presetLabel(AppLocalizations l10n, String id) => switch (id) {
  'circle' => l10n.connections_preset_circle,
  'where' => l10n.connections_preset_where,
  'trips' => l10n.connections_preset_trips,
  'life' => l10n.connections_preset_life,
  'gear' => l10n.connections_preset_gear,
  'centers' => l10n.connections_preset_centers,
  'travel' => l10n.connections_preset_travel,
  'reef' => l10n.connections_preset_reef,
  'gearRoad' => l10n.connections_preset_gearRoad,
  _ => id,
};

class PresetGrid extends ConsumerWidget {
  const PresetGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(connectionsViewProvider);
    final saved = ref.watch(savedConnectionMapsProvider).value ?? const [];
    final notifier = ref.read(connectionsViewProvider.notifier);
    final cards = <Widget>[
      for (final p in ConnectionPresets.all)
        _MapCard(
          key: ValueKey('preset-${p.id}'),
          label: presetLabel(l10n, p.id),
          kinds: p.spec.kinds,
          selected: view.presetId == p.id,
          edited: view.editedFromPresetId == p.id,
          onTap: () => notifier.update((s) => s.applyPreset(p)),
        ),
      for (final m in saved)
        _MapCard(
          key: ValueKey('saved-map-${m.id}'),
          label: m.name,
          kinds: m.spec.kinds,
          selected: view.savedMapId == m.id,
          edited: false,
          saved: true,
          onTap: () => notifier.update((s) => s.applySavedMap(m.id, m.spec)),
          menu: _SavedMapMenu(map: m),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.connections_presets_title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 6) / 2;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in cards) SizedBox(width: width, child: c)],
            );
          },
        ),
      ],
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    super.key,
    required this.label,
    required this.kinds,
    required this.selected,
    required this.edited,
    required this.onTap,
    this.saved = false,
    this.menu,
  });

  final String label;
  final Set<ConnectionKind> kinds;
  final bool selected;
  final bool edited;
  final bool saved;
  final VoidCallback onTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final sorted = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final k in sorted)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsetsDirectional.only(end: 3),
                            decoration: BoxDecoration(
                              color: colors.colorFor(k),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (saved)
                          Icon(
                            Icons.bookmark,
                            size: 12,
                            semanticLabel: context.l10n.connections_savedMap_badge,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (edited)
                      Text(
                        context.l10n.connections_preset_edited,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              ?menu,
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedMapMenu extends ConsumerWidget {
  const _SavedMapMenu({required this.map});

  final SavedConnectionMap map;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 18,
      onSelected: (value) async {
        final repo = ref.read(connectionMapRepositoryProvider);
        switch (value) {
          case 'rename':
            final name = await showSaveMapDialog(
              context,
              title: l10n.connections_savedMap_rename,
              initialName: map.name,
            );
            if (name != null) await repo.rename(map.id, name);
          case 'update':
            await repo.updateSpec(map.id, ref.read(connectionsViewProvider).mapSpec);
          case 'delete':
            await repo.delete(map.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.connections_savedMap_deleted(map.name)),
                action: SnackBarAction(
                  label: l10n.connections_savedMap_undo,
                  onPressed: () => repo.restore(map),
                ),
              ),
            );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'rename', child: Text(l10n.connections_savedMap_rename)),
        PopupMenuItem(value: 'update', child: Text(l10n.connections_savedMap_update)),
        PopupMenuItem(value: 'delete', child: Text(l10n.common_action_delete)),
      ],
    );
  }
}
```

`map_editor.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/panel/save_map_dialog.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Kinds, links and the minimum for a custom whole map, and Save as map.
class MapEditor extends ConsumerStatefulWidget {
  const MapEditor({super.key});

  @override
  ConsumerState<MapEditor> createState() => _MapEditorState();
}

class _MapEditorState extends ConsumerState<MapEditor> {
  /// The minimum while its slider is being dragged.
  double? _dragMinimum;

  void _edit(MapSpec Function(MapSpec) change) => ref
      .read(connectionsViewProvider.notifier)
      .update((s) => s.editMap(change(s.mapSpec)));

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = await showSaveMapDialog(
      context,
      title: l10n.connections_savedMap_saveTitle,
    );
    if (name == null) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;
    final spec = ref.read(connectionsViewProvider).mapSpec;
    final created = await ref
        .read(connectionMapRepositoryProvider)
        .create(diverId: diverId, name: name, spec: spec);
    await ref
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applySavedMap(created.id, spec));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final view = ref.watch(connectionsViewProvider);
    final spec = view.mapSpec;
    final colors = ConnectionKindColors.of(context);
    final minimum = _dragMinimum ?? spec.minSharedDives.toDouble();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: view.presetId == null && view.savedMapId == null,
      title: Text(l10n.connections_editor_title, style: theme.textTheme.labelLarge),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.connections_editor_kinds, style: theme.textTheme.labelMedium),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final k in ConnectionKind.values)
              FilterChip(
                key: ValueKey('kind-chip-${k.name}'),
                avatar: CircleAvatar(backgroundColor: colors.colorFor(k), radius: 5),
                label: Text(kindLabel(l10n, k)),
                selected: spec.kinds.contains(k),
                onSelected: (on) =>
                    _edit((s) => on ? s.withKind(k) : s.withoutKind(k)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.connections_editor_links, style: theme.textTheme.labelMedium),
        for (final link in spec.possibleLinks)
          CheckboxListTile(
            key: ValueKey('link-${link.wire}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: spec.links.contains(link),
            title: Text(
              l10n.connections_editor_link(
                kindLabel(l10n, link.a),
                kindLabel(l10n, link.b),
              ),
            ),
            onChanged: (_) => _edit((s) => s.toggleLink(link)),
          ),
        const SizedBox(height: 8),
        Text(l10n.connections_editor_minShared(minimum.round())),
        Slider(
          key: const ValueKey('min-shared-slider'),
          min: MapSpec.minMinimum.toDouble(),
          max: MapSpec.maxMinimum.toDouble(),
          divisions: MapSpec.maxMinimum - MapSpec.minMinimum,
          value: minimum,
          label: '${minimum.round()}',
          onChanged: (v) => setState(() => _dragMinimum = v),
          onChangeEnd: (v) {
            setState(() => _dragMinimum = null);
            _edit((s) => s.withMinimum(v.round()));
          },
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('save-as-map'),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(l10n.connections_editor_saveAsMap),
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/connections/presentation/panel/view_controls_test.dart`
Expected: PASS. The editor test taps the tile title first because the default view (Dive circle) keeps the editor collapsed.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/panel test/features/connections/presentation/panel
git commit -m "feat(connections): mode switch, preset grid with saved maps, map editor"
```

---

### Task 14: Around controls, search, summary, and the View tab

**Files:**
- Create: `lib/features/connections/presentation/panel/entity_search_field.dart`
- Create: `lib/features/connections/presentation/panel/around_controls.dart`
- Create: `lib/features/connections/presentation/panel/summary_block.dart`
- Create: `lib/features/connections/presentation/panel/view_tab.dart`
- Test: `test/features/connections/presentation/panel/around_and_summary_test.dart`

**Interfaces:**
- Consumes: `connectionsSearchProvider` (Task 9), `GraphSummary` (Task 10), Task 13 widgets, `kindLabel`, `ConnectionKindColors`.
- Produces:
  - `EntitySearchField()`: debounced (250 ms) search across kinds; each result shows its kind dot, label, kind and dive count; tapping centres the view on it and clears the field; no hits shows `connections_around_noResults`. Keys `ValueKey('entity-search')`, results `ValueKey('search-hit-<wire>')`.
  - `AroundControls({required ConnectionGraph graph})`: search, "Centred on" row, hop stepper (`ValueKey('hops')`, a `SegmentedButton<int>` with 1, 2, 3), kind chips (`ValueKey('around-kind-<name>')`) labelled `connections_around_kindChip(kindLabel, count)`.
  - `SummaryBlock({required ConnectionGraph graph, NodeRef? focus})`.
  - `ViewTab({required ConnectionGraph graph})`: mode switch, then map controls (`PresetGrid`, `MapEditor`) or `AroundControls`, then `SummaryBlock` (hidden while Around mode has no centre).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/panel/view_tab.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _kiyan = NodeRef(ConnectionKind.buddy, 'kiyan');
const _sharon = NodeRef(ConnectionKind.buddy, 'sharon');
const _pier = NodeRef(ConnectionKind.site, 'pier');

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _kiyan, label: 'Kiyan Griffin', diveCount: 34, hop: 0),
    ConnectionNode(ref: _sharon, label: 'Sharon Patterson', diveCount: 20, hop: 1),
    ConnectionNode(ref: _pier, label: 'Salt Pier', diveCount: 14, hop: 1),
  ],
  edges: [
    ConnectionEdge(
      source: _kiyan,
      target: _sharon,
      weight: 12,
      firstDiveAt: DateTime.utc(2021),
      lastDiveAt: DateTime.utc(2025),
    ),
    ConnectionEdge(
      source: _kiyan,
      target: _pier,
      weight: 9,
      firstDiveAt: DateTime.utc(2021),
      lastDiveAt: DateTime.utc(2025),
    ),
  ],
);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        savedConnectionMapsProvider.overrideWith((ref) async => const []),
        connectionsSearchProvider.overrideWith(
          (ref, text) async => text.toLowerCase().startsWith('sal')
              ? [ConnectionNode(ref: _pier, label: 'Salt Pier', diveCount: 14)]
              : const [],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ViewTab(graph: _graph)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('map mode shows presets, editor and the map summary', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('preset-circle')), findsOneWidget);
    expect(find.text('Custom map'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Kiyan Griffin'), findsOneWidget);
    expect(find.text('Kiyan Griffin and Sharon Patterson, 12 dives'), findsOneWidget);
  });

  testWidgets('around mode: search, centre, hops and kind chips', (tester) async {
    final c = await _pump(tester);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.centreOn(_kiyan));
    await tester.pumpAndSettle();

    expect(find.text('Centred on'), findsOneWidget);
    expect(find.text('Buddies (1)'), findsOneWidget);
    expect(find.text('Sites (1)'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('entity-search')), 'Sal');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-hit-site:pier')));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).focus, _pier);

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).hops, 2);

    await tester.tap(find.byKey(const ValueKey('around-kind-species')));
    await tester.pumpAndSettle();
    expect(
      c.read(connectionsViewProvider).aroundKinds,
      isNot(contains(ConnectionKind.species)),
    );
  });

  testWidgets('a search with no hits says so', (tester) async {
    final c = await _pump(tester);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withMode(ConnectionsMode.around));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('entity-search')), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('Summary'), findsNothing, reason: 'no centre, no summary');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/panel/around_and_summary_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Implement the four files**

`entity_search_field.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Finds an entity of any kind by name and centres the view on it.
class EntitySearchField extends ConsumerStatefulWidget {
  const EntitySearchField({super.key});

  @override
  ConsumerState<EntitySearchField> createState() => _EntitySearchFieldState();
}

class _EntitySearchFieldState extends ConsumerState<EntitySearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final hits = _query.isEmpty
        ? null
        : ref.watch(connectionsSearchProvider(_query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('entity-search'),
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.connections_around_searchHint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        if (hits != null)
          hits.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (nodes) => nodes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(l10n.connections_around_noResults),
                  )
                : Column(
                    children: [
                      for (final n in nodes)
                        ListTile(
                          key: ValueKey('search-hit-${n.ref.wire}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 6,
                            backgroundColor: colors.colorFor(n.ref.kind),
                          ),
                          title: Text(n.label),
                          subtitle: Text(
                            '${kindLabel(l10n, n.ref.kind)}, '
                            '${l10n.connections_selection_dives(n.diveCount)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () {
                            ref
                                .read(connectionsViewProvider.notifier)
                                .update((s) => s.centreOn(n.ref));
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}
```

`around_controls.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/panel/entity_search_field.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class AroundControls extends ConsumerWidget {
  const AroundControls({super.key, required this.graph});

  final ConnectionGraph graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final view = ref.watch(connectionsViewProvider);
    final notifier = ref.read(connectionsViewProvider.notifier);
    final focus = view.focus;
    final counts = GraphSummary.of(graph, focus: focus).countsByKind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EntitySearchField(),
        if (focus != null) ...[
          const SizedBox(height: 12),
          Text(l10n.connections_around_centredOn, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: colors.colorFor(focus.kind)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  graph.nodeFor(focus)?.label ?? focus.id,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(l10n.connections_around_hops, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          key: const ValueKey('hops'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 1, label: Text('1')),
            ButtonSegment(value: 2, label: Text('2')),
            ButtonSegment(value: 3, label: Text('3')),
          ],
          selected: {view.hops},
          onSelectionChanged: (s) => notifier.update((v) => v.withHops(s.single)),
        ),
        const SizedBox(height: 12),
        Text(l10n.connections_around_show, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final k in ConnectionKind.values)
              FilterChip(
                key: ValueKey('around-kind-${k.name}'),
                avatar: CircleAvatar(radius: 5, backgroundColor: colors.colorFor(k)),
                label: Text(
                  l10n.connections_around_kindChip(kindLabel(l10n, k), counts[k] ?? 0),
                ),
                selected: view.aroundKinds.contains(k),
                onSelected: (on) => notifier.update(
                  (v) => v.withAroundKinds(
                    on ? {...v.aroundKinds, k} : ({...v.aroundKinds}..remove(k)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
```

`summary_block.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/graph_summary.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Counts per kind (with their colour, so it doubles as the legend), the
/// number of connections, and the standouts of the map in view.
class SummaryBlock extends StatelessWidget {
  const SummaryBlock({super.key, required this.graph, this.focus});

  final ConnectionGraph graph;
  final NodeRef? focus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final s = GraphSummary.of(graph, focus: focus);
    final kinds = s.countsByKind.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    String label(NodeRef r) => graph.nodeFor(r)?.label ?? r.id;
    Widget row(String left, String right, {Color? dot}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (dot != null) ...[
            CircleAvatar(radius: 5, backgroundColor: dot),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(left, style: theme.textTheme.bodySmall)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              right,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.connections_summary_title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (focus != null)
          row(
            l10n.connections_summary_entitiesAround(s.entitiesAround),
            '',
          ),
        for (final ConnectionKind k in kinds)
          row(kindLabel(l10n, k), '${s.countsByKind[k]}', dot: colors.colorFor(k)),
        row(l10n.connections_filterBar_edges(s.connectionCount), ''),
        if (focus != null && s.closest != null)
          row(
            l10n.connections_summary_closest,
            '${s.closest!.label}, '
            '${l10n.connections_selection_divesTogether(s.closestWeight)}',
          ),
        if (focus == null && s.mostConnected != null)
          row(l10n.connections_summary_mostConnected, s.mostConnected!.label),
        if (focus == null && s.strongest != null)
          row(
            l10n.connections_summary_strongestPair,
            l10n.connections_summary_pairValue(
              s.strongest!.weight,
              label(s.strongest!.source),
              label(s.strongest!.target),
            ),
          ),
      ],
    );
  }
}
```

`view_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/panel/around_controls.dart';
import 'package:submersion/features/connections/presentation/panel/map_editor.dart';
import 'package:submersion/features/connections/presentation/panel/mode_switch.dart';
import 'package:submersion/features/connections/presentation/panel/preset_grid.dart';
import 'package:submersion/features/connections/presentation/panel/summary_block.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';

class ViewTab extends ConsumerWidget {
  const ViewTab({super.key, required this.graph});

  final ConnectionGraph graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(connectionsViewProvider);
    final around = view.mode == ConnectionsMode.around;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ModeSwitch(),
        const SizedBox(height: 12),
        if (around) AroundControls(graph: graph) else ...const [
          PresetGrid(),
          SizedBox(height: 8),
          MapEditor(),
        ],
        if (!view.isAroundWithoutFocus && !graph.isEmpty) ...[
          const Divider(height: 24),
          SummaryBlock(graph: graph, focus: around ? view.focus : null),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/connections/presentation/panel/`
Expected: PASS. If `find.text('2')` is ambiguous (a count chip reading `2`), use `find.descendant(of: find.byKey(const ValueKey('hops')), matching: find.text('2'))`.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/panel test/features/connections/presentation/panel
git commit -m "feat(connections): around controls with cross-kind search, summary and view tab"
```

---

### Task 15: Rebuild the page around the panel and the phone sheet

**Files:**
- Modify: `lib/features/connections/presentation/pages/connections_page.dart` (rewrite)
- Test: `test/features/connections/presentation/pages/connections_page_test.dart` (rewrite)

**Interfaces:**
- Consumes: `ConnectionsPanel` (Task 12), `ViewTab` (Task 14), `ConnectionsRouteArgs` and `connectionsViewProvider` (Task 9), `ConnectionsEmptyState`, `ConnectionsCanvas`, `ConnectionsLayoutController`, `HiddenNodesChip`, `ConnectionsLegend`.
- Produces: `ConnectionsPage({Key? key, ConnectionsRouteArgs args = const ConnectionsRouteArgs()})` with `compactBudget = 80`, `wideBudget = 160`, `maxBudget = 400`, `panelWidth = 340`. Keys: `ValueKey('connections-sheet')` on the phone sheet, `ValueKey('connections-reload-progress')` on the reload bar.
- Behaviour: wide (at least `ResponsiveBreakpoints.masterDetail`) is canvas plus the 340 px panel; compact is a full-height canvas plus a `DraggableScrollableSheet` holding the panel, which expands to half height when something is selected. The graph is read with its previous value kept during a reload: the canvas stays mounted and a thin progress bar shows over it. The app bar's filter action is gone (filters live in the Filter tab).

- [ ] **Step 1: Rewrite the page test**

Replace `test/features/connections/presentation/pages/connections_page_test.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 3),
    ConnectionNode(ref: _b('ken'), label: 'Ken', diveCount: 2),
  ],
  edges: [
    ConnectionEdge(
      source: _b('jane'),
      target: _b('ken'),
      weight: 2,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    ),
  ],
  hiddenNodeCount: 3,
);

const _phone = Size(732, 1000);
const _desktop = Size(1280, 800);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Size size = _desktop,
  String location = '/connections',
  FutureOr<ConnectionGraph> Function(Ref ref, int budget)? graph,
  List<Override> extra = const [],
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
        builder: (_, state) => ConnectionsPage(
          args: ConnectionsRouteArgs.fromQuery(state.uri.queryParameters),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionGraphProvider.overrideWith(
          (ref, budget) async => graph == null ? _graph : graph(ref, budget),
        ),
        connectionsYearSpanProvider.overrideWith(
          (ref) async => (first: 2019, last: 2024),
        ),
        savedConnectionMapsProvider.overrideWith((ref) async => const []),
        connectionsSelectionDiveIdsProvider.overrideWith((ref, s) async => ['d1']),
        ...extra,
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
  testWidgets('desktop: canvas and the tabbed panel', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('connections-canvas-paint')), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-panel')), findsOneWidget);
    expect(find.text('Whole map'), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-sheet')), findsNothing);
  });

  testWidgets('phone: canvas and the panel in a sheet', (tester) async {
    await _pump(tester, size: _phone);
    expect(find.byKey(const ValueKey('connections-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-panel')), findsOneWidget);
    expect(find.text('3 more not shown'), findsOneWidget);
  });

  testWidgets('a deep link centres the view and selects the entity', (tester) async {
    final c = await _pump(tester, location: '/connections?mode=around&focus=buddy:jane');
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(connectionsViewProvider).mode, ConnectionsMode.around);
    expect(c.read(connectionsViewProvider).focus, _b('jane'));
    expect(c.read(connectionsSelectionProvider), NodeSelection(_b('jane')));
  });

  testWidgets('a phase 1 link still works', (tester) async {
    final c = await _pump(tester, location: '/connections?lens=where');
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(connectionsViewProvider).presetId, 'where');
  });

  testWidgets('around mode without a centre prompts and keeps the search', (
    tester,
  ) async {
    final c = await _pump(tester);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withMode(ConnectionsMode.around));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('centre the map on it'), findsOneWidget);
    expect(find.byKey(const ValueKey('entity-search')), findsOneWidget);
  });

  testWidgets('an empty buddy map keeps the panel and points at Data Tools', (
    tester,
  ) async {
    await _pump(tester, graph: (ref, budget) => ConnectionGraph.empty);
    expect(find.byKey(const ValueKey('connections-panel')), findsOneWidget);
    expect(find.textContaining('Data Tools'), findsOneWidget);
  });

  testWidgets('an empty result under a filter blames the filter', (tester) async {
    await _pump(
      tester,
      graph: (ref, budget) => ConnectionGraph.empty,
      extra: [
        connectionsFilterProvider.overrideWith(
          (ref) => const DiveFilterState(siteId: 's1'),
        ),
      ],
    );
    expect(find.text('Nothing matches the current filter.'), findsOneWidget);
  });

  testWidgets('a load error shows retry', (tester) async {
    await _pump(tester, graph: (ref, budget) => throw StateError('boom'));
    expect(find.text('Could not load connections.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a vanished centre resets, warns once, and resets again', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      location: '/connections?mode=around&focus=buddy:ghost',
      graph: (ref, budget) {
        final focus = ref.watch(connectionsViewProvider).focus;
        if (focus != null) throw FocusNotFoundException(focus);
        return _graph;
      },
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsViewProvider).focus, isNull);
    expect(find.text('That item is no longer in the log.'), findsOneWidget);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.centreOn(_b('ghost2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsViewProvider).focus, isNull);
  });

  testWidgets('show all raises the budget without asking when it fits', (
    tester,
  ) async {
    final budgets = <int>[];
    await _pump(
      tester,
      size: _phone,
      graph: (ref, budget) {
        budgets.add(budget);
        return _graph;
      },
    );
    await tester.tap(find.text('3 more not shown'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AlertDialog), findsNothing);
    expect(budgets.last, ConnectionsPage.maxBudget);
  });

  testWidgets('show all asks above the ceiling, then offers no action', (
    tester,
  ) async {
    await _pump(
      tester,
      size: _phone,
      graph: (ref, budget) => _graph.copyWith(hiddenNodeCount: 500),
    );
    await tester.tap(find.text('500 more not shown'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Show all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('leaving around mode has its own tooltip', (tester) async {
    await _pump(tester, location: '/connections?mode=around&focus=buddy:jane');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Back to the whole map'), findsOneWidget);
  });

  testWidgets('the canvas semantics name the selection', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _pump(tester);
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(_b('jane'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Selected: Jane')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a reload keeps the canvas mounted and shows progress', (
    tester,
  ) async {
    final pending = Completer<ConnectionGraph>();
    var calls = 0;
    final c = await _pump(
      tester,
      graph: (ref, budget) {
        ref.watch(connectionsViewProvider);
        calls++;
        return calls == 1 ? _graph : pending.future;
      },
    );
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withHops(2).centreOn(_b('jane')));
    await tester.pump();
    expect(find.byKey(const ValueKey('connections-canvas-paint')), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-reload-progress')), findsOneWidget);
    pending.complete(_graph);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('connections-reload-progress')), findsNothing);
  });

  testWidgets('on a phone a selection opens Details in the sheet', (tester) async {
    final c = await _pump(tester, size: _phone);
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(_b('jane'));
    await tester.pumpAndSettle();
    expect(find.text('Centre here'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/connections/presentation/pages/connections_page_test.dart`
Expected: FAIL (no panel, no sheet, no progress bar yet).

- [ ] **Step 3: Rewrite the page**

`lib/features/connections/presentation/pages/connections_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/panel/connections_panel.dart';
import 'package:submersion/features/connections/presentation/panel/view_tab.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_empty_state.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key, this.args = const ConnectionsRouteArgs()});

  final ConnectionsRouteArgs args;

  static const compactBudget = 80;
  static const wideBudget = 160;
  static const maxBudget = 400;
  static const double panelWidth = 340;

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage>
    with SingleTickerProviderStateMixin {
  late final ConnectionsLayoutController _layout = ConnectionsLayoutController(
    vsync: this,
  );
  final DraggableScrollableController _sheet = DraggableScrollableController();
  int? _budgetOverride;
  ConnectionGraph? _laidOut;
  NodeRef? _laidOutFocus;
  bool _focusWarned = false;

  /// True until a deep link has been written to the view. Riverpod forbids
  /// provider writes inside initState, so the write waits for the first
  /// frame, and the first graph watch waits with it (no wasted load).
  late bool _deepLinkPending = !widget.args.isEmpty;

  @override
  void initState() {
    super.initState();
    if (!_deepLinkPending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyDeepLink();
      if (mounted) setState(() => _deepLinkPending = false);
    });
  }

  void _applyDeepLink() {
    if (!mounted) return;
    ref.read(connectionsViewProvider.notifier).update(widget.args.apply);
    final focus = NodeRef.parse(widget.args.focus);
    if (focus != null) {
      ref.read(connectionsSelectionProvider.notifier).state = NodeSelection(
        focus,
      );
    }
  }

  void _warnFocusMissing() {
    if (!mounted) return;
    // The reset always runs: a centre can vanish more than once in one page
    // lifetime (a deep link, then an entity deleted while the page is open).
    ref
        .read(connectionsViewProvider.notifier)
        .update((s) => s.copyWith(clearFocus: true));
    ref.read(connectionsSelectionProvider.notifier).state = null;
    if (_focusWarned) return;
    _focusWarned = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.connections_focusMissing)),
      );
    });
  }

  @override
  void dispose() {
    _layout.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _syncLayout(ConnectionGraph graph, NodeRef? focus) {
    if (identical(_laidOut, graph) && _laidOutFocus == focus) return;
    _laidOut = graph;
    _laidOutFocus = focus;
    _layout.setGraph(
      graph,
      mode: focus == null ? GraphLayoutMode.web : GraphLayoutMode.ego,
      focus: focus,
    );
  }

  /// Raises the node budget to [ConnectionsPage.maxBudget]. Only a graph
  /// larger than the ceiling asks first, because only then can the layout
  /// get slow.
  Future<void> _showAll(int total) async {
    if (total > ConnectionsPage.maxBudget) {
      final l10n = context.l10n;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.connections_showAll_confirmTitle),
          content: Text(l10n.connections_showAll_confirmBody(total)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.connections_showAll),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (mounted) {
      setState(() => _budgetOverride = ConnectionsPage.maxBudget);
    }
  }

  /// The canvas's accessible summary: counts, then the selection by name.
  String _semanticsLabel(ConnectionGraph graph, GraphSelection? selection) {
    final l10n = context.l10n;
    final summary = l10n.connections_semantics_summary(
      graph.nodes.length,
      graph.edges.length,
    );
    final String? selected = switch (selection) {
      null => null,
      NodeSelection(:final ref) => graph.nodeFor(ref)?.label,
      EdgeSelection(:final a, :final b) =>
        '${graph.nodeFor(a)?.label ?? a.id}, ${graph.nodeFor(b)?.label ?? b.id}',
    };
    if (selected == null) return summary;
    return '$summary. ${l10n.connections_semantics_selected(selected)}';
  }


  void _onSelection(GraphSelection? previous, GraphSelection? next) {
    if (next == null || previous != null || !_sheet.isAttached) return;
    if (_sheet.size < 0.5) {
      _sheet.animateTo(
        0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_deepLinkPending) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.connections_title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final wide =
        MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.masterDetail;
    final budget =
        _budgetOverride ??
        (wide ? ConnectionsPage.wideBudget : ConnectionsPage.compactBudget);
    final graphAsync = ref.watch(connectionGraphProvider(budget));
    final view = ref.watch(connectionsViewProvider);
    final selection = ref.watch(connectionsSelectionProvider);
    final hasActiveFilter = ref.watch(connectionsFilterProvider).hasActiveFilters;
    final colors = ConnectionKindColors.of(context);
    final focus = view.mode == ConnectionsMode.around ? view.focus : null;

    ref.listen(connectionGraphProvider(budget), (_, next) {
      if (next.hasError && next.error is FocusNotFoundException) {
        _warnFocusMissing();
      }
    });
    ref.listen(connectionsSelectionProvider, _onSelection);

    final graph = graphAsync.value ?? ConnectionGraph.empty;
    final Widget canvasArea;
    if (!graphAsync.hasValue && graphAsync.hasError) {
      canvasArea = graphAsync.error is FocusNotFoundException
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.connections_error_load),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(connectionGraphProvider(budget)),
                    child: Text(l10n.common_action_retry),
                  ),
                ],
              ),
            );
    } else if (!graphAsync.hasValue) {
      canvasArea = const Center(child: CircularProgressIndicator());
    } else if (graph.isEmpty) {
      canvasArea = ConnectionsEmptyState(
        view: view,
        hasAnyDives: ref.watch(connectionsYearSpanProvider).value != null,
        hasActiveFilter: hasActiveFilter,
      );
    } else {
      _syncLayout(graph, focus);
      final kinds = graph.nodes.map((n) => n.ref.kind).toSet();
      canvasArea = Stack(
        children: [
          Positioned.fill(
            child: ConnectionsCanvas(
              graph: graph,
              controller: _layout,
              colors: colors,
              selection: selection,
              semanticsLabel: _semanticsLabel(graph, selection),
              onSelect: (s) =>
                  ref.read(connectionsSelectionProvider.notifier).state = s,
              onFocus: (node) {
                ref
                    .read(connectionsViewProvider.notifier)
                    .update((s) => s.centreOn(node));
                ref.read(connectionsSelectionProvider.notifier).state =
                    NodeSelection(node);
              },
            ),
          ),
          if (!wide)
            Positioned(
              left: 12,
              top: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ConnectionsLegend(
                    kinds: kinds,
                    colors: colors,
                    showTitle: false,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: HiddenNodesChip(
              count: graph.hiddenNodeCount,
              onShowAll: budget >= ConnectionsPage.maxBudget
                  ? null
                  : () => _showAll(graph.nodes.length + graph.hiddenNodeCount),
            ),
          ),
          if (graphAsync.isLoading)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Semantics(
                label: l10n.connections_loading,
                child: const LinearProgressIndicator(
                  key: ValueKey('connections-reload-progress'),
                  minHeight: 2,
                ),
              ),
            ),
        ],
      );
    }

    Widget panel({ScrollController? scrollController, bool compact = false}) =>
        ConnectionsPanel(
          viewTab: ViewTab(graph: graph),
          graph: graph,
          scrollController: scrollController,
          compact: compact,
        );

    final body = wide
        ? Row(
            children: [
              Expanded(child: canvasArea),
              SizedBox(width: ConnectionsPage.panelWidth, child: panel()),
            ],
          )
        : Stack(
            children: [
              Positioned.fill(child: canvasArea),
              DraggableScrollableSheet(
                key: const ValueKey('connections-sheet'),
                controller: _sheet,
                initialChildSize: 0.22,
                minChildSize: 0.12,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: const [0.22, 0.5],
                builder: (context, scrollController) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: panel(scrollController: scrollController, compact: true),
                ),
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connections_title),
        actions: [
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
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.connections_tooltip_relayout,
              onPressed: _layout.relayout,
            ),
        ],
      ),
      body: body,
    );
  }
}
```

`_showAll` and `_semanticsLabel` are carried over unchanged from the phase 1 page.

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/connections/
```
Expected: PASS. If the reload test sees no progress bar, the provider has lost its previous value on reload: check that `connectionGraphProvider` is a `FutureProvider` (Riverpod keeps `value` across a rebuild triggered by a watched dependency), and that the page reads `graphAsync.value`, not `graphAsync.when(...)`.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/pages test/features/connections/presentation/pages
git commit -m "feat(connections): page with the tabbed panel, phone sheet and reload progress"
```

---

### Task 16: Label-aware fit that follows the settling layout

**Files:**
- Create: `lib/features/connections/presentation/canvas/camera_tween.dart`
- Modify: `lib/features/connections/presentation/canvas/graph_viewport.dart` (add `fittedWithOverhang`, `isCloseTo`)
- Modify: `lib/features/connections/presentation/canvas/connections_canvas.dart` (auto-fit state)
- Test: `test/features/connections/presentation/canvas/camera_tween_test.dart`
- Test: `test/features/connections/presentation/canvas/graph_viewport_test.dart` (add cases)
- Test: `test/features/connections/presentation/canvas/connections_canvas_test.dart` (add cases)

**Interfaces:**
- Produces:
  - `GraphViewport.fittedWithOverhang(GraphBounds bounds, Size size, {required double left, required double top, required double right, required double bottom, double margin = 24})`: the scale that fits the graph box plus screen-space overhangs (node radii and labels) inside `size` less `margin`, centred.
  - `bool GraphViewport.isCloseTo(GraphViewport other)`: scale within 1 % and offset within 1 px.
  - `CameraTween(GraphViewport from, GraphViewport to, Size size)` with `GraphViewport at(double t)`: scale blended in log space; the graph point under the screen centre moves linearly from its start to its end position.
  - Canvas behaviour: auto-fit is on after the first frame and after every graph change; while the layout settles the camera eases a quarter of the way to the current fit per frame; once settled it lands on the fit and auto-fit stops; any pan, pinch, wheel, trackpad or drag gesture turns auto-fit off until the next graph change.

- [ ] **Step 1: Write the failing tests**

`test/features/connections/presentation/canvas/camera_tween_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/presentation/canvas/camera_tween.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

void main() {
  const size = Size(400, 300);
  const from = GraphViewport(scale: 0.5, offset: Offset(10, 20));
  const to = GraphViewport(scale: 2, offset: Offset(-300, -100));

  test('the endpoints are the two viewports', () {
    final tween = CameraTween(from, to, size);
    expect(tween.at(0).scale, closeTo(0.5, 1e-9));
    expect(tween.at(0).offset.dx, closeTo(10, 1e-6));
    expect(tween.at(1).scale, closeTo(2, 1e-9));
    expect(tween.at(1).offset.dy, closeTo(-100, 1e-6));
  });

  test('scale blends in log space', () {
    expect(CameraTween(from, to, size).at(0.5).scale, closeTo(math.sqrt(1), 1e-9));
  });

  test('the centre point travels linearly', () {
    final tween = CameraTween(from, to, size);
    const centre = Offset(200, 150);
    final a = from.toGraph(centre);
    final b = to.toGraph(centre);
    final mid = tween.at(0.5).toGraph(centre);
    expect(mid.x, closeTo((a.x + b.x) / 2, 1e-6));
    expect(mid.y, closeTo((a.y + b.y) / 2, 1e-6));
  });
}
```

Add to `graph_viewport_test.dart`:

```dart
  test('fittedWithOverhang leaves room for labels at the edges', () {
    const bounds = GraphBounds(0, 0, 200, 100);
    final v = const GraphViewport().fittedWithOverhang(
      bounds,
      const Size(600, 400),
      left: 70,
      top: 39,
      right: 70,
      bottom: 60,
    );
    final left = v.toScreen(const GraphPoint(0, 50));
    final right = v.toScreen(const GraphPoint(200, 50));
    final bottom = v.toScreen(const GraphPoint(100, 100));
    expect(left.dx - 70, greaterThanOrEqualTo(24 - 1e-6));
    expect(right.dx + 70, lessThanOrEqualTo(600 - 24 + 1e-6));
    expect(bottom.dy + 60, lessThanOrEqualTo(400 - 24 + 1e-6));
  });

  test('isCloseTo tolerates rounding only', () {
    const a = GraphViewport(scale: 1, offset: Offset(10, 10));
    expect(a.isCloseTo(const GraphViewport(scale: 1.005, offset: Offset(10.5, 10))), isTrue);
    expect(a.isCloseTo(const GraphViewport(scale: 1.2, offset: Offset(10, 10))), isFalse);
    expect(a.isCloseTo(const GraphViewport(scale: 1, offset: Offset(14, 10))), isFalse);
  });
```

Add to `connections_canvas_test.dart` (it already defines `_Host`, `_painter` and `_graph`; the new tests use a wide two-node web graph):

```dart
  testWidgets('a long label at the edge of the fit stays inside the canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pump();
    final painter = _painter(tester);
    for (final p in painter.frame.positions.values) {
      final s = painter.viewport.toScreen(p);
      expect(s.dx, inInclusiveRange(70.0, 330.0));
    }
  });

  testWidgets('a pan stops the auto-fit from pulling the view back', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _ReloadHost()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.drag(find.byType(ConnectionsCanvas), const Offset(80, 0));
    await tester.pump();
    final afterDrag = _painter(tester).viewport.offset;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_painter(tester).viewport.offset, afterDrag);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: FAIL (missing `camera_tween.dart`, `fittedWithOverhang`, `isCloseTo`; the pan test fails because every settling frame refits).

- [ ] **Step 3: Implement**

`camera_tween.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

/// Interpolates the camera between two viewports: scale in log space, so a
/// zoom in and a zoom out feel equally paced, and the graph point under the
/// screen centre moves in a straight line, so the camera travels rather than
/// swinging about a corner.
class CameraTween {
  CameraTween(this.from, this.to, this.size)
    : _centre = Offset(size.width / 2, size.height / 2);

  final GraphViewport from;
  final GraphViewport to;
  final Size size;
  final Offset _centre;

  GraphViewport at(double t) {
    final scale = math.exp(
      math.log(from.scale) + (math.log(to.scale) - math.log(from.scale)) * t,
    );
    final a = from.toGraph(_centre);
    final b = to.toGraph(_centre);
    final c = GraphPoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
    return GraphViewport(
      scale: scale,
      offset: Offset(_centre.dx - c.x * scale, _centre.dy - c.y * scale),
    );
  }
}
```

Add to `GraphViewport`:

```dart
  /// Fits [bounds] plus screen-space overhangs (node radii and labels that
  /// extend past the node centres) inside [size] less [margin], centred.
  GraphViewport fittedWithOverhang(
    GraphBounds bounds,
    Size size, {
    required double left,
    required double top,
    required double right,
    required double bottom,
    double margin = 24,
  }) {
    final availW = math.max(1.0, size.width - 2 * margin - left - right);
    final availH = math.max(1.0, size.height - 2 * margin - top - bottom);
    final w = math.max(1.0, bounds.width);
    final h = math.max(1.0, bounds.height);
    final s = bounds.isEmpty
        ? 1.0
        : math.min(availW / w, availH / h).clamp(minScale, maxScale);
    final boxW = bounds.width * s;
    final boxH = bounds.height * s;
    final x0 = margin + left + (availW - boxW) / 2;
    final y0 = margin + top + (availH - boxH) / 2;
    return GraphViewport(
      scale: s,
      offset: Offset(x0 - bounds.left * s, y0 - bounds.top * s),
    );
  }

  bool isCloseTo(GraphViewport other) =>
      (scale / other.scale - 1).abs() < 0.01 &&
      (offset - other.offset).distance < 1;
```

In `connections_canvas.dart`:

1. Replace `bool _fitted = false;` with:

```dart
  /// The camera follows the layout until the diver moves it.
  bool _autoFit = true;

  /// False until the first fit, which snaps; later fits ease.
  bool _everFitted = false;
```

2. Add a fit-target helper next to `_radiusOf`:

```dart
  /// Where the camera should be for the current frame, leaving room for the
  /// largest node and a full label on every side.
  GraphViewport _fitTarget(Size size) {
    final r = NodeMetrics.maxRadius * 1.5;
    final labelHeight = (_cachedLabelStyle?.fontSize ?? 11) * 1.5;
    return _viewport.fittedWithOverhang(
      widget.controller.frame.bounds,
      size,
      left: math.max(r, 70),
      top: r,
      right: math.max(r, 70),
      bottom: r + 2 + labelHeight,
    );
  }
```

(70 px is half the 140 px maximum label width the painter lays out.)

3. Replace `_onFrame`'s body:

```dart
  void _onFrame() {
    if (!mounted) return;
    setState(() {
      final frame = widget.controller.frame;
      if (!_autoFit || _size == Size.zero || frame.positions.isEmpty) return;
      final target = _fitTarget(_size);
      if (!_everFitted || widget.controller.settled) {
        _viewport = target;
        _everFitted = true;
        if (widget.controller.settled) _autoFit = false;
        return;
      }
      _viewport = CameraTween(_viewport, target, _size).at(0.25);
    });
  }
```

4. In `didUpdateWidget`, replace `_fitted = false;` with `_autoFit = true;`.

5. In the `LayoutBuilder`, replace the `if (!_fitted) { ... }` block with:

```dart
          if (_autoFit && widget.controller.frame.positions.isNotEmpty) {
            _viewport = _fitTarget(size);
            _everFitted = true;
            if (widget.controller.settled) _autoFit = false;
          }
```

6. In `_zoomAt`, `_pan` and the long-press `onLongPressStart` handler, set `_autoFit = false;` as the first statement (inside `setState` for the first two).

7. Add `import 'dart:math' as math;` if not present, and `camera_tween.dart`.

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/connections/presentation/canvas/ test/features/connections/presentation/pages/
```
Expected: PASS. If an older canvas test that computed positions from the painter now sees different screen coordinates, it still passes, because those tests read positions back through `painter.viewport` rather than hard-coding them.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/canvas test/features/connections/presentation/canvas
git commit -m "feat(connections): label-aware fit that follows the settling layout"
```

---

### Task 17: Label halos, labels that avoid nodes, kind icons

**Files:**
- Create: `lib/features/connections/presentation/canvas/connection_kind_icons.dart`
- Modify: `lib/features/connections/presentation/canvas/node_metrics.dart` (add `NodeGlyph`, `glyphFor`)
- Modify: `lib/features/connections/presentation/canvas/label_collision.dart` (obstacles)
- Modify: `lib/features/connections/presentation/canvas/connections_painter.dart` (halos, obstacles, icons)
- Modify: `lib/features/connections/presentation/canvas/connections_canvas.dart` (pass `haloColor`)
- Test: `test/features/connections/presentation/canvas/node_metrics_test.dart`, `label_collision_test.dart`, `connections_painter_test.dart` (add cases)

**Interfaces:**
- Produces:
  - `IconData connectionKindIcon(ConnectionKind kind)`: buddy `Icons.people`, site `Icons.location_on`, trip `Icons.flight`, diveCenter `Icons.store`, equipment `Icons.backpack`, species `MdiIcons.fish`, course `Icons.school`, tag `Icons.label`, diveType `Icons.category`, diveComputer `Icons.watch`.
  - `enum NodeGlyph { none, initials, icon, photo }` and `NodeGlyph NodeMetrics.glyphFor({required ConnectionKind kind, required bool hasPhoto, required double radius})`: photo when there is one and radius is at least 14; icon for a non-buddy at radius 18 or more; initials at radius 12 or more; otherwise none.
  - `LabelCollision.visible(ranked, {List<Rect> obstacles = const []})`: a label overlapping any obstacle is hidden.
  - `ConnectionsPainter(..., Color? haloColor)`: every visible label is painted over a rounded rectangle in `haloColor` at 85 % opacity (no halo when null); node discs are collision obstacles.

- [ ] **Step 1: Write the failing tests**

Add to `node_metrics_test.dart`:

```dart
  test('glyphFor picks photo, icon, initials or nothing', () {
    expect(
      NodeMetrics.glyphFor(kind: ConnectionKind.buddy, hasPhoto: true, radius: 20),
      NodeGlyph.photo,
    );
    expect(
      NodeMetrics.glyphFor(kind: ConnectionKind.buddy, hasPhoto: true, radius: 10),
      NodeGlyph.none,
    );
    expect(
      NodeMetrics.glyphFor(kind: ConnectionKind.buddy, hasPhoto: false, radius: 20),
      NodeGlyph.initials,
    );
    expect(
      NodeMetrics.glyphFor(kind: ConnectionKind.site, hasPhoto: false, radius: 18),
      NodeGlyph.icon,
    );
    expect(
      NodeMetrics.glyphFor(kind: ConnectionKind.site, hasPhoto: false, radius: 15),
      NodeGlyph.initials,
    );
    expect(
      NodeMetrics.glyphFor(kind: ConnectionKind.site, hasPhoto: false, radius: 8),
      NodeGlyph.none,
    );
  });
```

(add `import 'package:submersion/features/connections/domain/entities/connection_kind.dart';`)

Add to `label_collision_test.dart`:

```dart
  test('a label over another node is hidden', () {
    final visible = LabelCollision.visible(
      [(ref: _b('a'), rect: const Rect.fromLTWH(0, 0, 60, 12))],
      obstacles: [Rect.fromCircle(center: const Offset(30, 6), radius: 10)],
    );
    expect(visible, isEmpty);
  });
```

Add to `connections_painter_test.dart`:

```dart
  test('visible labels sit on a halo in the given colour', () {
    final p = ConnectionsPainter(
      graph: graph,
      frame: frame,
      viewport: const GraphViewport(scale: 1, offset: Offset(50, 50)),
      colors: colors,
      labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
      haloColor: Colors.white,
    );
    expect(
      p,
      paints..rrect(color: Colors.white.withValues(alpha: 0.85)),
    );
  });

  test('every kind has an icon', () {
    for (final k in ConnectionKind.values) {
      expect(connectionKindIcon(k), isA<IconData>());
    }
  });
```

(add `import 'package:submersion/features/connections/presentation/canvas/connection_kind_icons.dart';`)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: FAIL to compile (`glyphFor`, `obstacles`, `haloColor`, `connectionKindIcon`).

- [ ] **Step 3: Implement**

`connection_kind_icons.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// The glyph for a kind, matching its home destination where it has one.
IconData connectionKindIcon(ConnectionKind kind) => switch (kind) {
  ConnectionKind.buddy => Icons.people,
  ConnectionKind.site => Icons.location_on,
  ConnectionKind.trip => Icons.flight,
  ConnectionKind.diveCenter => Icons.store,
  ConnectionKind.equipment => Icons.backpack,
  ConnectionKind.species => MdiIcons.fish,
  ConnectionKind.course => Icons.school,
  ConnectionKind.tag => Icons.label,
  ConnectionKind.diveType => Icons.category,
  ConnectionKind.diveComputer => Icons.watch,
};
```

In `node_metrics.dart` (import `connection_kind.dart`), add:

```dart
enum NodeGlyph { none, initials, icon, photo }
```

and inside `NodeMetrics`:

```dart
  /// What to draw inside a node disc of [radius] screen pixels.
  static NodeGlyph glyphFor({
    required ConnectionKind kind,
    required bool hasPhoto,
    required double radius,
  }) {
    if (hasPhoto && radius >= 14) return NodeGlyph.photo;
    if (kind != ConnectionKind.buddy && radius >= 18) return NodeGlyph.icon;
    if (radius >= 12) return NodeGlyph.initials;
    return NodeGlyph.none;
  }
```

`label_collision.dart`:

```dart
  /// Keeps each label whose rect overlaps neither an already-kept,
  /// higher-ranked label nor any of [obstacles] (the node discs).
  static Set<NodeRef> visible(
    List<({NodeRef ref, Rect rect})> ranked, {
    List<Rect> obstacles = const [],
  }) {
    final kept = <Rect>[];
    final out = <NodeRef>{};
    for (final c in ranked) {
      if (obstacles.any((o) => _strictlyOverlaps(o, c.rect))) continue;
      if (kept.any((k) => _strictlyOverlaps(k, c.rect))) continue;
      kept.add(c.rect);
      out.add(c.ref);
    }
    return out;
  }
```

`connections_painter.dart`:

1. Constructor and field: `this.haloColor,` and `final Color? haloColor;` (add `old.haloColor != haloColor` to `shouldRepaint`).
2. In the node loop, collect `final discs = <Rect>[];` before it and `discs.add(Rect.fromCircle(center: centre, radius: r));` for every drawn node.
3. Replace the photo/initials branch with:

```dart
      final glyph = NodeMetrics.glyphFor(
        kind: n.ref.kind,
        hasPhoto: photo != null,
        radius: r,
      );
      switch (glyph) {
        case NodeGlyph.photo:
          canvas.save();
          canvas.clipPath(
            Path()..addOval(Rect.fromCircle(center: centre, radius: r - 1.5)),
          );
          paintImage(
            canvas: canvas,
            rect: Rect.fromCircle(center: centre, radius: r),
            image: photo!,
            fit: BoxFit.cover,
            opacity: dim && !isLit ? 0.35 : 1,
          );
          canvas.restore();
        case NodeGlyph.icon:
          final size = (r * 1.1).round();
          final icon = connectionKindIcon(n.ref.kind);
          final tp = initialsCache.putIfAbsent(
            (n.ref, -size),
            () => TextPainter(
              text: TextSpan(
                text: String.fromCharCode(icon.codePoint),
                style: TextStyle(
                  fontFamily: icon.fontFamily,
                  package: icon.fontPackage,
                  fontSize: size.toDouble(),
                  color: Colors.white,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(),
          );
          tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
        case NodeGlyph.initials:
          // the existing initials block, unchanged (initialsCache keyed by
          // (n.ref, fontSize) with a positive fontSize)
        case NodeGlyph.none:
          break;
      }
```

The `NodeGlyph.initials` arm holds the body of today's `else if (r >= 12) { ... }` block unchanged (the `initialsCache.putIfAbsent((n.ref, fontSize), ...)` call and `tp.paint(...)`). Icon entries use a negative size in the cache key so they never collide with initials.

4. Pass the discs to the collision pass: `final visible = LabelCollision.visible(ranked, obstacles: discs);`.
5. Before `tp.paint(canvas, c.rect.topLeft);` in the label loop:

```dart
      final halo = haloColor;
      if (halo != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(c.rect.inflate(2), const Radius.circular(4)),
          Paint()..color = halo.withValues(alpha: 0.85),
        );
      }
```

In `connections_canvas.dart`, pass `haloColor: theme.colorScheme.surface,` to `ConnectionsPainter`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/connections/presentation/canvas/`
Expected: PASS. If the `paints..rrect(color:)` matcher does not match because `Colors.white.withValues(alpha: 0.85)` differs in the last bit from the painted colour, compare with `paints..rrect()` and assert the colour through a `PaintPattern` callback, `paints..something((m, a) => ...)`, checking `alpha` within 0.01.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/canvas test/features/connections/presentation/canvas
git commit -m "feat(connections): label halos, labels that avoid nodes, kind icons"
```

---

### Task 18: Kind sectors, the island grid, rings by hop

**Files:**
- Modify: `lib/features/connections/domain/layout/layout_seed.dart`
- Modify: `lib/features/connections/domain/layout/whole_web_layout.dart`
- Modify: `lib/features/connections/domain/layout/radial_layout.dart`
- Modify: `lib/features/connections/presentation/providers/connections_layout_controller.dart` (node order)
- Test: `test/features/connections/domain/layout/layout_seed_test.dart`, `whole_web_layout_test.dart`, `radial_layout_test.dart` (add cases)

**Interfaces:**
- Produces:
  - `LayoutSeed.circle(refs, {radius})` places each kind in its own contiguous angular sector (kinds in enum order, sector size proportional to the kind's count, members in wire order). Still deterministic and order-independent.
  - `WholeWebLayout` lays out only components of two or more nodes with forces; single nodes are placed in a grid below the packed components, in the order they appear in `nodes`, 90 units apart, about 1.6 times as many columns as rows. `moveNode` pins a single node too.
  - `RadialLayout.compute` puts hop 1 (and nodes without a hop) on the inner rings, hop 2 outside all of hop 1, hop 3 outside hop 2; within one hop, kinds keep contiguous arcs.
  - The controller passes nodes to `WholeWebLayout` sorted by dive count descending, then label, so the busiest islands come first.

- [ ] **Step 1: Write the failing tests**

Add to `layout_seed_test.dart`:

```dart
  test('each kind starts in one contiguous sector', () {
    final refs = [
      for (var i = 0; i < 4; i++) NodeRef(ConnectionKind.buddy, 'b$i'),
      for (var i = 0; i < 4; i++) NodeRef(ConnectionKind.site, 's$i'),
    ];
    final p = LayoutSeed.circle(refs);
    double angle(NodeRef r) {
      final a = math.atan2(p[r]!.y, p[r]!.x);
      return a < 0 ? a + 2 * math.pi : a;
    }
    final sorted = [...refs]..sort((x, y) => angle(x).compareTo(angle(y)));
    final kinds = sorted.map((r) => r.kind).toList();
    var switches = 0;
    for (var i = 1; i < kinds.length; i++) {
      if (kinds[i] != kinds[i - 1]) switches++;
    }
    expect(switches, lessThanOrEqualTo(2), reason: 'two sectors, at most two boundaries around the circle');
  });
```

(add `import 'dart:math' as math;`)

Add to `whole_web_layout_test.dart`:

```dart
  test('single nodes sit in a grid below the linked components, in order', () {
    final l = WholeWebLayout(
      nodes: [_b('solo2'), _b('a'), _b('b'), _b('solo1')],
      edges: [_e('a', 'b')],
    )..advance(400);
    final p = l.frame.positions;
    final linkedBottom = math.max(p[_b('a')]!.y, p[_b('b')]!.y);
    expect(p[_b('solo2')]!.y, greaterThan(linkedBottom));
    expect(p[_b('solo1')]!.y, greaterThan(linkedBottom));
    expect(p[_b('solo2')]!.x, lessThan(p[_b('solo1')]!.x), reason: 'input order');
    l.moveNode(_b('solo1'), const GraphPoint(-500, -500));
    expect(l.frame.positions[_b('solo1')], const GraphPoint(-500, -500));
  });
```

(add `import 'dart:math' as math;`)

Add to `radial_layout_test.dart`:

```dart
  test('farther hops sit on outer rings', () {
    ConnectionNode hop(ConnectionKind k, String id, int h) =>
        ConnectionNode(ref: NodeRef(k, id), label: id, diveCount: 1, hop: h);
    final near = [for (var i = 0; i < 30; i++) hop(ConnectionKind.buddy, 'n$i', 1)];
    final far = [for (var i = 0; i < 5; i++) hop(ConnectionKind.site, 'f$i', 2)];
    final f = RadialLayout.compute(
      focus: _focus,
      nodes: [_n(ConnectionKind.buddy, 'me'), ...near, ...far],
      edges: [for (final n in [...near, ...far]) _spoke(n.ref, 1)],
    );
    final nearMax = near.map((n) => f.positions[n.ref]!.length).reduce(math.max);
    final farMin = far.map((n) => f.positions[n.ref]!.length).reduce(math.min);
    expect(farMin, greaterThan(nearMax));
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/domain/layout/`
Expected: the three new tests FAIL (seeds interleave kinds, singles are packed as islands, hop is ignored).

- [ ] **Step 3: Implement**

`layout_seed.dart`, replace the body of `circle`:

```dart
  static Map<NodeRef, GraphPoint> circle(
    Iterable<NodeRef> refs, {
    double radius = 200,
  }) {
    final sorted = refs.toList()..sort((a, b) => a.wire.compareTo(b.wire));
    if (sorted.isEmpty) return const {};
    final rng = math.Random(seedFor(sorted));
    final byKind = <ConnectionKind, List<NodeRef>>{};
    for (final r in sorted) {
      byKind.putIfAbsent(r.kind, () => []).add(r);
    }
    final kinds = byKind.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
    final n = sorted.length;
    final out = <NodeRef, GraphPoint>{};
    var start = 0.0;
    for (final k in kinds) {
      final members = byKind[k]!;
      final span = 2 * math.pi * members.length / n;
      for (var i = 0; i < members.length; i++) {
        final angle =
            start + span * (i + 0.5) / members.length +
            (rng.nextDouble() - 0.5) * 0.2 * span / members.length;
        final r = radius * (0.8 + 0.4 * rng.nextDouble());
        out[members[i]] = GraphPoint(r * math.cos(angle), r * math.sin(angle));
      }
      start += span;
    }
    return out;
  }
```

(import `../entities/connection_kind.dart`.)

`whole_web_layout.dart`: in the constructor, split components:

```dart
    final order = {for (var i = 0; i < nodes.length; i++) nodes[i]: i};
    final comps = IslandPacker.components(nodes, edges);
    _singles = [
      for (final c in comps)
        if (c.length == 1) c.single,
    ]..sort((a, b) => order[a]!.compareTo(order[b]!));
    for (final comp in comps.where((c) => c.length > 1)) {
      // the existing ForceLayout construction, unchanged
    }
```

with fields `late final List<NodeRef> _singles;` and `final Map<NodeRef, GraphPoint> _singlePins = {};`. In `_recompose`, after computing `positions` for the packed components:

```dart
    if (_singles.isNotEmpty) {
      const gap = 90.0;
      final packed = GraphBounds.of(positions.values);
      final cols = math.max(1, (math.sqrt(_singles.length) * 1.6).ceil());
      final x0 = positions.isEmpty ? 0.0 : packed.left;
      final y0 = positions.isEmpty ? 0.0 : packed.bottom + gap;
      for (var i = 0; i < _singles.length; i++) {
        final ref = _singles[i];
        positions[ref] =
            _singlePins[ref] ??
            GraphPoint(x0 + (i % cols) * gap, y0 + (i ~/ cols) * gap);
      }
    }
```

and at the top of `moveNode`:

```dart
    if (_singles.contains(ref)) {
      _singlePins[ref] = world;
      _recompose();
      return;
    }
```

`clearPins` also clears `_singlePins`. `settled` is unchanged (single nodes need no simulation). Import `dart:math` and `graph_point.dart` if missing.

`radial_layout.dart`, replace the placement loop (from `final total = neighbours.length;` to the `return`) with:

```dart
    final hops = <int, List<ConnectionNode>>{};
    for (final n in neighbours) {
      hops.putIfAbsent(n.hop ?? 1, () => []).add(n);
    }
    var ringBase = 0;
    for (final h in hops.keys.toList()..sort()) {
      final members = hops[h]!;
      final byKind = <ConnectionKind, List<ConnectionNode>>{};
      for (final n in members) {
        byKind.putIfAbsent(n.ref.kind, () => []).add(n);
      }
      final kinds = byKind.keys.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      var arcStart = 0.0;
      var ringsUsed = 1;
      for (final k in kinds) {
        final group = byKind[k]!
          ..sort((a, b) {
            final byWeight = weightTo[b.ref]!.compareTo(weightTo[a.ref]!);
            return byWeight != 0 ? byWeight : a.label.compareTo(b.label);
          });
        final arc = 2 * math.pi * group.length / members.length;
        var placed = 0;
        var ring = 0;
        while (placed < group.length) {
          final radius = firstRing + (ringBase + ring) * ringGap;
          final capacity = math.max(1, (arc * radius / minArcSpacing).floor());
          final count = math.min(capacity, group.length - placed);
          for (var i = 0; i < count; i++) {
            final t = count == 1 ? 0.5 : (i + 0.5) / count;
            final angle = arcStart + arc * t;
            positions[group[placed + i].ref] = GraphPoint(
              radius * math.cos(angle),
              radius * math.sin(angle),
            );
          }
          placed += count;
          ring++;
        }
        ringsUsed = math.max(ringsUsed, ring);
        arcStart += arc;
      }
      ringBase += ringsUsed;
    }
    return LayoutFrame.fromPositions(positions, settled: true);
```

Neighbours reached only through a chord (no spoke to the focus) still need a weight for sorting: change the `weightTo` fill so every neighbour gets at least 0, i.e. after the spoke loop add `for (final n in nodes) { if (n.ref != focus) weightTo.putIfAbsent(n.ref, () => 0); }`, and change the `neighbours` filter to `nodes.where((n) => n.ref != focus)`; hop 2 and 3 nodes have no spoke to the focus by construction.

In `connections_layout_controller.dart`, both `WholeWebLayout(nodes: ...)` calls take the nodes in this order:

```dart
      nodes: ([...graph.nodes]
            ..sort((a, b) {
              final byDives = b.diveCount.compareTo(a.diveCount);
              return byDives != 0 ? byDives : a.label.compareTo(b.label);
            }))
          .map((n) => n.ref)
          .toList(),
```

(`_graph.nodes` in `relayout`.)

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/connections/`
Expected: PASS. The phase 1 radial test `'a lone focus is a single point'` still passes (no neighbours), and `'spills to a second ring when an arc is full'` still sees radii 170 and 290 (one hop).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections test/features/connections
git commit -m "feat(connections): kind sectors, island grid and rings by hop"
```

---

### Task 19: The refocus animation

**Files:**
- Create: `lib/features/connections/domain/layout/layout_morph.dart`
- Modify: `lib/features/connections/domain/layout/layout_frame.dart` (`appear`)
- Modify: `lib/features/connections/presentation/providers/connections_layout_controller.dart` (ego morph)
- Modify: `lib/features/connections/presentation/canvas/connections_painter.dart` (apply `appear`)
- Modify: `lib/features/connections/presentation/canvas/connections_canvas.dart` (camera glide, `animate` flag)
- Modify: `lib/features/connections/presentation/pages/connections_page.dart` (pass `animate`)
- Test: `test/features/connections/domain/layout/layout_morph_test.dart` (new)
- Test: `test/features/connections/presentation/providers/connections_layout_controller_test.dart`, `test/features/connections/presentation/canvas/connections_canvas_test.dart` (add cases)

**Interfaces:**
- Produces:
  - `LayoutFrame.appear` (`Map<NodeRef, double>`, default empty) and `double appearOf(NodeRef ref)` (1 when absent). `LayoutFrame.fromPositions(positions, {required settled, Map<NodeRef, double> appear = const {}})`.
  - `LayoutMorph.at({required LayoutFrame from, required LayoutFrame to, required double t, GraphPoint? origin})`: nodes in both slide from `from` to `to`; nodes only in `to` start at `origin` (or their own `to` position when null) with `appear == t`; `settled` is `t >= 1`.
  - `kRefocusDuration = Duration(milliseconds: 450)` and `kRefocusCurve = Curves.easeInOutCubic` (in `connections_layout_controller.dart`).
  - `ConnectionsLayoutController.setGraph(..., {bool animate = false})`: in ego mode with `animate` and a non-empty previous frame, the frame morphs over `kRefocusDuration` from the previous positions to the radial target, new nodes growing out of the focus's previous position; `settled` is false until the morph ends. `stepForTest([int? iterations, Duration elapsed = Duration.zero])` advances the morph clock by `elapsed`.
  - `ConnectionsCanvas(..., bool animate = false)`: when the graph changes with `animate` true and reduce motion off, the camera glides from the current viewport to the new fit over `kRefocusDuration`; any gesture stops the glide. The painter multiplies node radius and label opacity by `appearOf`.
  - The page passes `animate: !MediaQuery.disableAnimationsOf(context) && <not the first graph>` to both the controller and the canvas.

- [ ] **Step 1: Write the failing tests**

`test/features/connections/domain/layout/layout_morph_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_morph.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  final from = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(0, 0),
    _b('gone'): const GraphPoint(50, 50),
  }, settled: true);
  final to = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(100, 0),
    _b('new'): const GraphPoint(0, 100),
  }, settled: true);

  test('the endpoints', () {
    final start = LayoutMorph.at(from: from, to: to, t: 0, origin: GraphPoint.zero);
    expect(start.positions[_b('a')], const GraphPoint(0, 0));
    expect(start.positions[_b('new')], GraphPoint.zero);
    expect(start.appearOf(_b('new')), 0);
    expect(start.positions.containsKey(_b('gone')), isFalse);
    expect(start.settled, isFalse);
    final end = LayoutMorph.at(from: from, to: to, t: 1, origin: GraphPoint.zero);
    expect(end.positions, to.positions);
    expect(end.appearOf(_b('new')), 1);
    expect(end.settled, isTrue);
  });

  test('halfway slides and grows', () {
    final mid = LayoutMorph.at(from: from, to: to, t: 0.5, origin: GraphPoint.zero);
    expect(mid.positions[_b('a')], const GraphPoint(50, 0));
    expect(mid.positions[_b('new')], const GraphPoint(0, 50));
    expect(mid.appearOf(_b('new')), 0.5);
    expect(mid.appearOf(_b('a')), 1);
  });
}
```

Add to `connections_layout_controller_test.dart`:

```dart
  test('an animated refocus morphs over 450 ms, then settles', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    while (!c.settled) {
      c.stepForTest();
    }
    final before = c.frame.positions[_b('a')]!;
    c.setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('b'), animate: true);
    expect(c.settled, isFalse);
    expect(c.frame.positions[_b('a')], before);
    c.stepForTest(0, const Duration(milliseconds: 225));
    final mid = c.frame.positions[_b('a')]!;
    expect(mid, isNot(before));
    expect(c.settled, isFalse);
    c.stepForTest(0, const Duration(milliseconds: 250));
    expect(c.settled, isTrue);
    expect(c.frame.positions[_b('b')], GraphPoint.zero);
  });

  test('without animate the ego layout is immediate', () {
    final c = ConnectionsLayoutController(vsync: const TestVSync());
    addTearDown(c.dispose);
    c.setGraph(_graph, mode: GraphLayoutMode.web);
    c.setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('b'));
    expect(c.settled, isTrue);
  });
```

Add to `connections_canvas_test.dart`:

```dart
  testWidgets('a refocus glides the camera, and a pan stops it', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: _GlideHost()));
    await tester.pump();
    final start = _painter(tester).viewport.scale;
    tester.state<_GlideHostState>(find.byType(_GlideHost)).spread();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 225));
    final mid = _painter(tester).viewport.scale;
    await tester.pump(const Duration(milliseconds: 300));
    final end = _painter(tester).viewport.scale;
    expect(end, lessThan(start), reason: 'the wider graph needs a smaller scale');
    expect(mid, lessThan(start));
    expect(mid, greaterThan(end));

    tester.state<_GlideHostState>(find.byType(_GlideHost)).spread(wider: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(find.byType(ConnectionsCanvas), const Offset(40, 0));
    await tester.pump();
    final afterPan = _painter(tester).viewport;
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).viewport.scale, afterPan.scale);
  });

  testWidgets('reduce motion snaps the camera', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: _GlideHost(),
        ),
      ),
    );
    await tester.pump();
    tester.state<_GlideHostState>(find.byType(_GlideHost)).spread();
    await tester.pump();
    final first = _painter(tester).viewport.scale;
    await tester.pump(const Duration(milliseconds: 225));
    expect(_painter(tester).viewport.scale, first);
  });
```

and the host, at the end of the file:

```dart
/// An ego view that re-centres on a wider graph, the way Centre here does.
class _GlideHost extends StatefulWidget {
  const _GlideHost();
  @override
  State<_GlideHost> createState() => _GlideHostState();
}

class _GlideHostState extends State<_GlideHost>
    with SingleTickerProviderStateMixin {
  late final controller = ConnectionsLayoutController(vsync: this)
    ..setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('me'));
  ConnectionGraph graph = _graph;

  void spread({bool wider = false}) {
    final count = wider ? 60 : 30;
    setState(() {
      graph = _graph.copyWith(
        nodes: [
          ..._graph.nodes,
          for (var i = 0; i < count; i++)
            ConnectionNode(ref: _b('n$i'), label: 'N$i', diveCount: 1, hop: 2),
        ],
        edges: [
          ..._graph.edges,
          for (var i = 0; i < count; i++)
            ConnectionEdge(
              source: _b('jane'),
              target: _b('n$i'),
              weight: 1,
              firstDiveAt: DateTime.utc(2024),
              lastDiveAt: DateTime.utc(2024),
            ),
        ],
      );
      controller.setGraph(
        graph,
        mode: GraphLayoutMode.ego,
        focus: _b('me'),
        animate: !MediaQuery.disableAnimationsOf(context),
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SizedBox(
      width: 400,
      height: 400,
      child: ConnectionsCanvas(
        graph: graph,
        controller: controller,
        colors: const ConnectionKindColors({}, Colors.grey),
        onSelect: (_) {},
        onFocus: (_) {},
        animate: true,
      ),
    ),
  );
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/connections/domain/layout/layout_morph_test.dart test/features/connections/presentation/providers/connections_layout_controller_test.dart test/features/connections/presentation/canvas/connections_canvas_test.dart`
Expected: FAIL to compile (`LayoutMorph`, `animate`, `stepForTest` elapsed).

- [ ] **Step 3: Implement**

`layout_frame.dart`: add the field and accessor, and thread `appear` through `fromPositions`:

```dart
  const LayoutFrame({
    required this.positions,
    required this.bounds,
    required this.settled,
    this.appear = const {},
  });
  // ...
  factory LayoutFrame.fromPositions(
    Map<NodeRef, GraphPoint> positions, {
    required bool settled,
    Map<NodeRef, double> appear = const {},
  }) {
    return LayoutFrame(
      positions: Map.unmodifiable(positions),
      bounds: GraphBounds.of(positions.values),
      settled: settled,
      appear: Map.unmodifiable(appear),
    );
  }

  /// 0 to 1 per node while it grows in during a refocus; absent means 1.
  final Map<NodeRef, double> appear;

  double appearOf(NodeRef ref) => appear[ref] ?? 1;
```

`layout_morph.dart`:

```dart
import '../entities/node_ref.dart';
import 'graph_point.dart';
import 'layout_frame.dart';

/// Interpolates between two layout frames for the refocus animation.
class LayoutMorph {
  const LayoutMorph._();

  static LayoutFrame at({
    required LayoutFrame from,
    required LayoutFrame to,
    required double t,
    GraphPoint? origin,
  }) {
    final clamped = t.clamp(0.0, 1.0);
    final positions = <NodeRef, GraphPoint>{};
    final appear = <NodeRef, double>{};
    for (final entry in to.positions.entries) {
      final start = from.positions[entry.key];
      final a = start ?? origin ?? entry.value;
      final b = entry.value;
      positions[entry.key] = GraphPoint(
        a.x + (b.x - a.x) * clamped,
        a.y + (b.y - a.y) * clamped,
      );
      if (start == null && clamped < 1) appear[entry.key] = clamped;
    }
    return LayoutFrame.fromPositions(
      positions,
      settled: clamped >= 1,
      appear: appear,
    );
  }
}
```

`connections_layout_controller.dart`:

```dart
const Duration kRefocusDuration = Duration(milliseconds: 450);
const Curve kRefocusCurve = Curves.easeInOutCubic;
```

(import `package:flutter/animation.dart` for `Curve`/`Curves`, and `layout_morph.dart`.) Add fields:

```dart
  LayoutFrame? _morphFrom;
  LayoutFrame? _morphTo;
  GraphPoint? _morphOrigin;
  Duration _morphElapsed = Duration.zero;
```

`settled` becomes `_morphTo == null && (_web?.settled ?? true)`.

In `setGraph`, add `bool animate = false,` to the parameters and replace the ego branch with:

```dart
    if (mode == GraphLayoutMode.ego && focus != null) {
      final previousFrame = _frame;
      _web = null;
      final target = RadialLayout.compute(
        focus: focus,
        nodes: graph.nodes,
        edges: graph.edges,
      );
      if (animate && previousFrame.positions.isNotEmpty) {
        _morphFrom = previousFrame;
        _morphTo = target;
        _morphOrigin = previousFrame.positions[focus] ?? target.positions[focus];
        _morphElapsed = Duration.zero;
        _frame = LayoutMorph.at(
          from: previousFrame,
          to: target,
          t: 0,
          origin: _morphOrigin,
        );
        _stopTicker();
        _ticker.start();
      } else {
        _morphTo = null;
        _frame = target;
        _stopTicker();
      }
      notifyListeners();
      return;
    }
    _morphTo = null;
```

(the web-mode code follows unchanged). Replace the tick plumbing:

```dart
  /// One tick's worth of work without a ticker, for tests: [iterations] of
  /// the force layout, or [elapsed] of the refocus morph.
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
```

`connections_painter.dart`: in `radiusOf`, multiply by the appear factor, and in the label loop wrap a label whose node is still appearing in a layer:

```dart
  double radiusOf(ConnectionNode n) =>
      NodeMetrics.radiusFor(n.diveCount, graph.maxDiveCount) *
      viewport.scale.clamp(0.5, 1.5) *
      frame.appearOf(n.ref);
```

```dart
      final appear = frame.appearOf(c.ref);
      if (appear < 1) {
        canvas.saveLayer(
          c.rect.inflate(4),
          Paint()..color = Color.fromRGBO(0, 0, 0, appear),
        );
      }
      // halo and tp.paint(...) as before
      if (appear < 1) canvas.restore();
```

Skip a node entirely when its radius is below 0.5 (the first frame of a grow).

`connections_canvas.dart`:

1. Add `this.animate = false` and `final bool animate;` to the widget; mix `SingleTickerProviderStateMixin` into the state.
2. Fields and setup:

```dart
  late final AnimationController _glide =
      AnimationController(vsync: this, duration: kRefocusDuration)
        ..addListener(_onGlide);
  GraphViewport? _glideFrom;

  void _onGlide() {
    final from = _glideFrom;
    if (from == null || _size == Size.zero) return;
    setState(() {
      _viewport = CameraTween(
        from,
        _fitTarget(_size),
        _size,
      ).at(kRefocusCurve.transform(_glide.value));
    });
  }
```

dispose `_glide` in `dispose`.
3. In `didUpdateWidget`, when the graph changed:

```dart
    if (old.graph != widget.graph) {
      _autoFit = true;
      if (widget.animate &&
          _everFitted &&
          !MediaQuery.disableAnimationsOf(context)) {
        _glideFrom = _viewport;
        _glide.forward(from: 0);
      }
      _clearTextCaches();
      _decodePhotos();
    }
```

4. In `_onFrame`, return early from the camera update while `_glide.isAnimating` (the glide owns the camera then).
5. In `_zoomAt`, `_pan` and `onLongPressStart`, also call `_glide.stop();` next to `_autoFit = false;`.

`connections_page.dart`: add a field `bool _hadGraph = false;`; compute `final animate = _hadGraph && !MediaQuery.disableAnimationsOf(context);` in `build`, pass it to `_syncLayout` (new parameter forwarded to `_layout.setGraph(..., animate: animate)`) and to `ConnectionsCanvas(animate: animate)`; set `_hadGraph = true` after the first `_syncLayout` call.

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/connections/
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections test/features/connections
git commit -m "feat(connections): animated refocus with a node morph and camera glide"
```

---

### Task 20: "Open in Connections" on every detail page

**Files:**
- Create: `lib/features/connections/presentation/widgets/open_in_connections.dart`
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (both menus at lines ~237-258 and ~448-468; handler `_handleMenuAction` at ~475)
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (`_buildMoreMenu` at ~440-535)
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (`_buildMoreMenu` at ~219-285)
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (`_buildMenuItems` at ~365, `_handleMenuAction` at ~891)
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page.dart` (actions at ~40-66)
- Modify: `lib/features/courses/presentation/pages/course_detail_page.dart` (two duplicated menus at ~277-307 and ~571-604)
- Tests: add one test to each of `test/features/buddies/presentation/pages/buddy_detail_page_test.dart`, `test/features/dive_sites/presentation/pages/site_detail_page_test.dart`, `test/features/trips/presentation/pages/trip_detail_page_test.dart`, `test/features/dive_centers/presentation/pages/dive_center_detail_page_test.dart`, `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`, `test/features/marine_life/presentation/pages/species_detail_page_suggest_test.dart`; create `test/features/courses/presentation/pages/course_detail_page_connections_test.dart`.

**Interfaces:**
- Consumes: `connectionsAroundLocation` (Task 9).
- Produces: `const kOpenInConnectionsAction = 'connections'`; `PopupMenuItem<String> openInConnectionsMenuItem(BuildContext context)`; `void openInConnections(BuildContext context, NodeRef ref)` (pushes `connectionsAroundLocation(ref)`).

- [ ] **Step 1: Write the shared helper and the buddy test change first**

`lib/features/connections/presentation/widgets/open_in_connections.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Overflow-menu value shared by every detail page.
const kOpenInConnectionsAction = 'connections';

/// The "Open in Connections" menu row. The label sits in an Expanded so a
/// long translation wraps instead of overflowing the menu.
PopupMenuItem<String> openInConnectionsMenuItem(BuildContext context) {
  return PopupMenuItem<String>(
    value: kOpenInConnectionsAction,
    child: Row(
      children: [
        const Icon(Icons.hub_outlined),
        const SizedBox(width: 8),
        Expanded(child: Text(context.l10n.connections_action_openInConnections)),
      ],
    ),
  );
}

/// Opens the Connections page centred on [ref], on top of the current page.
void openInConnections(BuildContext context, NodeRef ref) =>
    context.push(connectionsAroundLocation(ref));
```

In `buddy_detail_page_test.dart`, change the existing expectation of the "Open in Connections pushes the ego deep link" test to:

```dart
      expect(
        find.text('CONNECTIONS mode=around&focus=buddy:buddy-1'),
        findsOneWidget,
      );
```

Run: `flutter test test/features/buddies/presentation/pages/buddy_detail_page_test.dart`
Expected: FAIL (the page still pushes the phase 1 link).

- [ ] **Step 2: Wire the buddy page**

In both `PopupMenuButton<String>` blocks of `buddy_detail_page.dart`, replace the inline `'connections'` `PopupMenuItem` with `openInConnectionsMenuItem(context),` and the `if (value == 'connections') { context.push(...) }` branch with:

```dart
              if (value == kOpenInConnectionsAction) {
                openInConnections(context, NodeRef(ConnectionKind.buddy, buddy.id));
              } else if (value == 'share') {
```

Run the buddy test again. Expected: PASS.

- [ ] **Step 3: Add the failing test to each other page**

Each test follows the buddy test's shape: a `GoRouter` whose routes are the page's existing test routes plus

```dart
          GoRoute(
            path: '/connections',
            builder: (context, state) =>
                Scaffold(body: Text('CONNECTIONS ${state.uri.query}')),
          ),
```

then open the page's overflow menu, tap `'Open in Connections'`, `pumpAndSettle`, and expect the text. Per page:

| Test file | Harness to copy | Menu finder | Expected text |
| --- | --- | --- | --- |
| `site_detail_page_test.dart` | the "does not redirect on desktop in table mode" test (router at lines ~106-135, `siteListViewModeProvider` table) | `find.byType(PopupMenuButton<String>).first` | `CONNECTIONS mode=around&focus=site:<site.id>` |
| `dive_center_detail_page_test.dart` | the desktop table-mode test (lines ~80-125) | `find.byType(PopupMenuButton<String>).first` | `CONNECTIONS mode=around&focus=diveCenter:<center.id>` |
| `equipment_detail_page_test.dart` | the desktop table-mode test (overrides at lines ~84-128) | `find.byType(PopupMenuButton<String>).first` | `CONNECTIONS mode=around&focus=equipment:<id>` |
| `trip_detail_page_test.dart` | the mobile test's `ProviderScope` overrides (lines ~60-85), wrapped in `MaterialApp.router` with a `GoRouter(initialLocation: '/trips/${testTrip.id}', routes: [GoRoute(path: '/trips/:id', builder: (_, s) => TripDetailPage(tripId: s.pathParameters['id']!)), <connections stub>])` | `find.byTooltip(<trips_detail_tooltip_moreOptions in English>)` | `CONNECTIONS mode=around&focus=trip:<testTrip.id>` |
| `species_detail_page_suggest_test.dart` | `_pump`'s overrides (lines ~31-63) under `testAppRouter` (`test/helpers/test_app.dart:72`) with a `/species/:id` route and the stub | `find.byKey(const ValueKey('species_detail_menu'))` | `CONNECTIONS mode=around&focus=species:<id>`, for a **built-in** species (the menu now shows for every species) |
| `course_detail_page_connections_test.dart` (new) | the `setUp` and `testApp` overrides from `course_detail_export_units_test.dart` (lines ~83-110) under `testAppRouter` with a `/courses/:id` route and the stub; use `pump(const Duration(milliseconds: 500))` instead of `pumpAndSettle` (the page has an endless animation) | `find.byTooltip(<courses_action_moreOptions in English>)` | `CONNECTIONS mode=around&focus=course:<course.id>` |

Read the English tooltip strings from `lib/l10n/arb/app_en.arb` when writing the finders.

Run: `flutter test` on those seven files.
Expected: the six new tests FAIL (no menu item yet); every existing test passes.

- [ ] **Step 4: Add the item and the branch to each page**

For each page, add `openInConnectionsMenuItem(context),` as the **first** item of every overflow menu, and a branch for `kOpenInConnectionsAction` in the matching handler that calls `openInConnections(context, NodeRef(<kind>, <id>))`:

- site: kind `ConnectionKind.site`, id `site.id`; add the item to both item lists; in `_handleMenuAction` add `if (action == kOpenInConnectionsAction) { openInConnections(context, NodeRef(ConnectionKind.site, site.id)); return; }` before the other branches.
- trip: `ConnectionKind.trip`, `trip.id`, in `_buildMoreMenu`'s item list and `onSelected` chain.
- dive center: `ConnectionKind.diveCenter`, `center.id`, in `_buildMoreMenu`.
- equipment: `ConnectionKind.equipment`, `equipmentId`, as a new first entry of `_buildMenuItems` and a `case kOpenInConnectionsAction:` in `_handleMenuAction`'s switch.
- species: `ConnectionKind.species`, `species.id`. Render the `PopupMenuButton` whenever the species has loaded (`if (speciesAsync.value case final species?)`), keep the `'suggest'` item conditional on `!species.isBuiltIn`, and add the connections item and branch. If an existing suggest test asserted the menu is absent for a built-in species, change it to assert the `'suggest'` item is absent instead.
- course: extract the two identical menus into one `Widget _buildMoreMenu(BuildContext context, WidgetRef ref, Course course)` returning the `PopupMenuButton<String>` (same tooltip, handler and items), use it in both places, and add the connections item and branch (`ConnectionKind.course`, `course.id`).

Imports for each page: `open_in_connections.dart`, `connection_kind.dart`, `node_ref.dart` from the connections feature.

- [ ] **Step 5: Run the page tests and the guards**

```bash
flutter test test/features/buddies/presentation/pages/ test/features/dive_sites/presentation/pages/ test/features/trips/presentation/pages/ test/features/dive_centers/presentation/pages/ test/features/equipment/presentation/pages/ test/features/marine_life/presentation/pages/ test/features/courses/presentation/pages/ test/shared/widgets/app_bar_text_action_adoption_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/connections/presentation/widgets/open_in_connections.dart lib/features/buddies lib/features/dive_sites lib/features/trips lib/features/dive_centers lib/features/equipment lib/features/marine_life lib/features/courses test/features/buddies test/features/dive_sites test/features/trips test/features/dive_centers test/features/equipment test/features/marine_life test/features/courses
git commit -m "feat(connections): open any entity's connections from its detail page"
```

---

### Task 21: Remove the phase 1 widgets and orphaned strings

**Files:**
- Delete: `lib/features/connections/presentation/widgets/selection_panel.dart`, `selection_card.dart`, `connections_filter_bar.dart`, `connections_filter_action.dart`
- Modify: `test/features/connections/presentation/widgets/lens_and_filter_widgets_test.dart` → rename to `year_range_slider_test.dart`, keeping only the year slider tests
- Modify: the eleven ARB files (orphaned `connections_*` keys), regenerated l10n

- [ ] **Step 1: Confirm nothing uses the four widgets**

Run: `grep -rn "SelectionPanel\|SelectionCard\|ConnectionsFilterBar\|ConnectionsFilterAction" lib test`
Expected: only their own files and the old widget test. If anything else matches, move it to the panel equivalent first.

- [ ] **Step 2: Delete them and trim the widget test**

```bash
git rm lib/features/connections/presentation/widgets/selection_panel.dart lib/features/connections/presentation/widgets/selection_card.dart lib/features/connections/presentation/widgets/connections_filter_bar.dart lib/features/connections/presentation/widgets/connections_filter_action.dart
git mv test/features/connections/presentation/widgets/lens_and_filter_widgets_test.dart test/features/connections/presentation/widgets/year_range_slider_test.dart
```

In `year_range_slider_test.dart`, delete the filter-bar test and any import only it used.

- [ ] **Step 3: Delete orphaned `connections_` keys**

Save as `$SCRATCH/orphans.py` and run it from the repository root:

```python
import json, re, subprocess
from pathlib import Path

en = json.loads(Path("lib/l10n/arb/app_en.arb").read_text())
keys = [k for k in en if k.startswith("connections_")]
dart = subprocess.run(
    ["grep", "-rhoE", r"\bconnections_[A-Za-z]+", "lib", "--include=*.dart",
     "--exclude=app_localizations*.dart"],
    capture_output=True, text=True,
).stdout.split()
used = set(dart)
orphans = [k for k in keys if k not in used]
print("orphans:", orphans)
for f in sorted(Path("lib/l10n/arb").glob("app_*.arb")):
    lines = f.read_text().split("\n")
    out = [
        l for l in lines
        if not any(
            l.startswith(f'  "{k}":') or l.startswith(f'  "@{k}":')
            for k in orphans
        )
    ]
    text = "\n".join(out)
    json.loads(text)
    f.write_text(text)
```

Expected: it prints the keys only the deleted widgets used (typically `connections_filterBar_clear`, `connections_tooltip_filter`, `connections_action_focus`, `connections_lens_circle`, `connections_lens_where`, `connections_legend_title`; check the list, never delete a key a remaining widget uses). Multi-line `@` metadata blocks are not matched by the one-line filter: if `json.loads` fails for a file, remove that key's metadata block by hand.

```bash
flutter gen-l10n
flutter analyze lib/features/connections lib/l10n
flutter test test/features/connections/ test/l10n/
```
Expected: no analyzer issues; tests PASS.

- [ ] **Step 4: Commit**

```bash
git add -A lib/features/connections test/features/connections lib/l10n/arb
git commit -m "refactor(connections): remove the phase 1 panel widgets and their strings"
```

---

### Task 22: Around-load benchmark, guards, analyze

**Files:**
- Test: `test/features/connections/data/repositories/around_load_benchmark_test.dart` (new)

- [ ] **Step 1: Write the benchmark**

```dart
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

import '../../../../helpers/test_database.dart';

/// A log of 400 dives, 60 buddies and 40 sites: Around at three hops with
/// both kinds on reaches most of it. Loose bound on purpose: CI varies.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('three hops over a 400-dive log loads well inside a second or two', () async {
    final d = DatabaseService.instance.database;
    const ms = 1700000000000;
    await d.into(d.divers).insert(
      const db.DiversCompanion(
        id: Value('me'),
        name: Value('me'),
        createdAt: Value(ms),
        updatedAt: Value(ms),
      ),
    );
    await d.batch((b) {
      for (var i = 0; i < 60; i++) {
        b.insert(
          d.buddies,
          db.BuddiesCompanion(
            id: Value('b$i'),
            name: Value('Buddy $i'),
            createdAt: const Value(ms),
            updatedAt: const Value(ms),
          ),
        );
      }
      for (var i = 0; i < 40; i++) {
        b.insert(
          d.diveSites,
          db.DiveSitesCompanion(
            id: Value('s$i'),
            name: Value('Site $i'),
            createdAt: const Value(ms),
            updatedAt: const Value(ms),
          ),
        );
      }
    });
    final rng = math.Random(7);
    await d.batch((b) {
      for (var i = 0; i < 400; i++) {
        b.insert(
          d.dives,
          db.DivesCompanion(
            id: Value('d$i'),
            diverId: const Value('me'),
            siteId: Value('s${rng.nextInt(40)}'),
            diveDateTime: Value(ms + i * 86400000),
            createdAt: const Value(ms),
            updatedAt: const Value(ms),
          ),
        );
        final buddies = {for (var k = 0; k < 1 + rng.nextInt(3); k++) rng.nextInt(60)};
        for (final bi in buddies) {
          b.insert(
            d.diveBuddies,
            db.DiveBuddiesCompanion(
              id: Value('d$i-b$bi'),
              diveId: Value('d$i'),
              buddyId: Value('b$bi'),
              role: const Value('buddy'),
              createdAt: const Value(ms),
            ),
          );
        }
      }
    });

    final sw = Stopwatch()..start();
    final g = await ConnectionsRepository().loadAround(
      focus: const NodeRef(ConnectionKind.buddy, 'b0'),
      kinds: {ConnectionKind.buddy, ConnectionKind.site},
      hops: 3,
      diverId: 'me',
      nodeBudget: 160,
    );
    sw.stop();
    expect(g.nodes, isNotEmpty);
    expect(g.nodes.length, lessThanOrEqualTo(160));
    expect(sw.elapsedMilliseconds, lessThan(3000), reason: 'took ${sw.elapsedMilliseconds} ms');
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/features/connections/data/repositories/around_load_benchmark_test.dart`
Expected: PASS, typically well under a second.

- [ ] **Step 3: Guards, format, analyze, feature suites**

```bash
dart format .
flutter analyze
flutter test test/architecture/ test/core/database/ test/core/services/sync/ test/features/divers/ test/l10n/ test/shared/widgets/ test/core/router/ test/core/theme/
flutter test test/features/connections/ test/features/dive_log/presentation/widgets/ test/features/buddies/ test/features/dive_sites/presentation/pages/ test/features/trips/presentation/pages/ test/features/dive_centers/presentation/pages/ test/features/equipment/presentation/pages/ test/features/marine_life/presentation/pages/ test/features/courses/presentation/pages/
```
Expected: `dart format` changes nothing, `flutter analyze` reports no issues, every test passes. Then run the full suite once (`flutter test`, with `TMPDIR=/tmp` if the RAM disk is filling); a lone failure in a file this branch never touched is rerun alone before it is called a flake.

- [ ] **Step 4: Commit**

```bash
git add test/features/connections/data/repositories/around_load_benchmark_test.dart
git commit -m "test(connections): around-load benchmark"
```


---

## Self-review notes

- **Spec coverage.** Views and presets (Task 1), builder changes including the minimum and exclusions (2), hop-ranked trimming (3), map and around loads, one transaction per load and cross-kind search (4), rung 232 with the table and the sightings index (5), sync (6), saved maps with tolerant parsing (7), strings (8), the view state, graph provider and route arguments with phase 1 links still accepted (9), the summary (10), shared filter chips (11), the panel's Filter and Details tabs (12), mode switch, presets, saved-map cards and the editor (13), Around controls and the View tab (14), the page with the phone sheet and reload progress (15), the label-aware fit (16), halos, node-avoiding labels and kind icons (17), sectors, the island grid and rings by hop (18), the refocus animation with reduce motion (19), deep links from seven detail pages (20), cleanup (21), benchmark and guards (22). The carried-in review fixes are already on the branch (`20bfaf3dc77`).
- **Deliberate gaps.** "One transaction per load" is implemented (Task 4 wraps both loads in `_db.transaction`) but has no test: a Drift read transaction is not observable from outside without racing a write, and such a test would be flaky. The page's legend moves into the Summary block on wide screens (each kind row carries its colour), which is how the spec's "legend removed on wide layouts" is met.
- **Type consistency.** `ConnectionsViewState` (`applyPreset`, `applySavedMap`, `editMap`, `centreOn`, `withMode`, `withAroundKinds`, `withHops`, `copyWith(clearFocus:)`), `ConnectionsViewNotifier.update`, `ConnectionsRepository.loadMap`/`loadAround`/`searchEntities`, `ConnectionsReader.edges(restrictA:, restrictB:, excludeB:, minShared:)`, `ConnectionNode.hop`, `ConnectionMapRepository.create/rename/updateSpec/delete/restore`, `ConnectionsPanel(viewTab:, graph:, scrollController:, compact:)`, `ConnectionsPage(args:)`, `GraphViewport.fittedWithOverhang`, `CameraTween.at`, `LayoutMorph.at`, `ConnectionsLayoutController.setGraph(..., animate:)` and `stepForTest([iterations, elapsed])`, `NodeMetrics.glyphFor`, `openInConnectionsMenuItem`/`openInConnections` are used with these names throughout.
