# Underwater Route Entry Points Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Link and import underwater routes from the Dive Edit page (staged until Save), show the Dive Details route card only when a route is linked, reach the routes area from Settings > Manage, and drop the dashboard quick action.

**Architecture:** A pure, immutable `DiveRouteLinkDraft` holds the edit form's pending links; a small applier writes its diff through the existing `NavTrackRepository.link`/`unlink` after the dive row is saved, the same way buddies and sightings are written. A new `RouteRow` plus `showRouteLinkSheet` UI lives in its own files under `edit_sections/`, and the import review page gains a "return to caller" mode that saves the route unlinked and pops with its id instead of navigating. The detail card, the Manage tile, the router transition and the quick action are small edits to existing files.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), Drift (via `NavTrackRepository`), go_router, `flutter gen-l10n` ARB localisation (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-02-underwater-route-entry-points-design.md`

**Issues:** the PR description must contain, outside any code span: `Closes #2796, closes #2396, closes #2397`, and `Refs #2398` (its page-UI refinement stays open).

## Global Constraints

- The name stays "Underwater Route" / "Underwater Routes" everywhere users see it. Do not rename any existing string.
- Internal identifiers do not change: `navTrack*` keys and classes, `/nav-routes` paths.
- No schema, sync, or `NavTrackRepository` / `NavTrackImportService` API changes.
- Never use the em-dash character in code, comments, docs, commit messages or PR text. No emojis.
- No mention of Claude, Claude Code or Anthropic in commits, PR text, or code. No `Co-Authored-By` trailers.
- Immutability: never mutate a list or object passed in; return new instances.
- Every user-visible distance uses `UnitFormatter(ref.watch(settingsProvider))`.
- All 11 ARB locales (`ar de en es fr he hu it nl pt zh`) get every new key. Only `app_en.arb` carries `@key` metadata. In non-English files insert new keys directly after the named anchor key (those files are grouped by feature, not sorted).
- Generated placeholder methods take arguments in ALPHABETICAL placeholder order. Always assert the RENDERED text in tests.
- Run `dart format .` before every commit.
- If `flutter test` fails with "temp directory ... does not exist" on back-to-back runs, rerun with `FLUTTER_SHIM_OFF=1 TMPDIR=<session scratchpad dir>` prefixed.
- Do not type the bare word `build` as a token in a shell command (the harness refuses it); use `./scripts/setup.sh` for codegen.

## Review Focus

1. **Linked a route, then switched the dive to Planned before saving.** The row hides and Save must write no links (a planned dive has no recording). Pinned in Task 6.
2. **Imported a re-export with "replace duplicate" ticked, where the duplicate is the route already linked to this dive.** The review page deletes the old row immediately; the draft must drop the deleted id (never `unlink` it) and link the new one on Save. Pinned in Task 2 (draft) and Task 5 (sheet end to end).
3. **A route gets linked to some dive between choosing it and Save** (another device via sync, or `addDive`'s overlap auto-link from issue #2394). `link()` returns false; Save must complete normally, log, and show no error. Pinned in Task 2 (applier).
4. **Tapping the Route row before the dive's existing links have loaded.** With no seeded draft, the sheet must not open; otherwise Save could unlink every existing route. Pinned in Task 5 (row) and by the null-draft guard in Task 6.
5. **Entry time changed on the form before opening the sheet.** Link candidates must be ordered by the form's current entry time, not the stored one. Pinned in Task 5 (sheet ordering test passes the time explicitly; Task 6 passes `_currentEntryTime()`).

---

### Task 0: Initialise the worktree and capture "before" screenshots

**Files:** none changed.

- [ ] **Step 1: Initialise the worktree**

Run: `git submodule update --init --recursive && ./scripts/setup.sh`
Expected: completes without error; `flutter analyze lib/features/nav_track` reports no errors.

- [ ] **Step 2: Capture "before" screenshots**

Use the `run` skill to launch the macOS app from this worktree. Save PNGs to the session scratchpad (not the repo) named:
`before-dashboard.png` (Quick Actions card showing "Underwater Routes"), `before-dive-detail-no-route.png` (a dive with no linked route, showing the empty "Underwater Route" card), `before-dive-edit.png` (The Dive group of the edit form), `before-settings-manage.png` (Settings > Manage list). Capture each at desktop width, and the dive detail and dive edit ones also at phone width (resize the window to about 390 pt wide).

No commit.

---

### Task 1: Route display name and proximity ordering

**Files:**
- Modify: `lib/features/nav_track/domain/entities/nav_track.dart` (add a getter after the constructor)
- Create: `lib/features/nav_track/domain/nav_track_proximity.dart`
- Create: `test/helpers/nav_track_fixtures.dart`
- Test: `test/features/nav_track/domain/nav_track_proximity_test.dart`

**Interfaces:**
- Produces: `String get displayName` on `NavTrack` (`name ?? sourceRef ?? id`).
- Produces: `List<NavTrack> sortByProximityTo(Iterable<NavTrack> routes, DateTime entryTime)` (new list; nearest start first; ties by earlier `startTime`, then lower `id`).
- Produces (tests): `NavTrack testNavTrack(String id, {String? name, String? diveId, bool isPrimary = true, int? startTime, double? totalDistance})`, `const int kTestRouteStartMs`, `const List<NavTrackPoint> kTestNavTrackPoints`.

- [ ] **Step 1: Write the test fixtures**

Create `test/helpers/nav_track_fixtures.dart`:

```dart
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

/// 2025-08-22 10:00 UTC, the recording start every fixture route shares
/// unless a test overrides it.
const int kTestRouteStartMs = 1755856800000;

/// Two samples ten minutes apart: the fewest `insertImportedRoute` accepts.
const List<NavTrackPoint> kTestNavTrackPoints = [
  NavTrackPoint(
    timestamp: 1755856800,
    north: 0,
    east: 0,
    depth: 5,
    distance: 0,
    speed: 0.3,
  ),
  NavTrackPoint(
    timestamp: 1755857400,
    north: 40,
    east: 0,
    depth: 5,
    distance: 40,
    speed: 0.3,
  ),
];

NavTrack testNavTrack(
  String id, {
  String? name,
  String? diveId,
  bool isPrimary = true,
  int? startTime,
  double? totalDistance,
}) {
  final start = startTime ?? kTestRouteStartMs;
  return NavTrack(
    id: id,
    name: name,
    diveId: diveId,
    isPrimary: isPrimary,
    source: NavTrackSource.seacraftEnc,
    sourceRef: '$id.csv',
    startTime: start,
    endTime: start + 3600000,
    pointCount: 0,
    totalDistance: totalDistance,
    createdAt: DateTime(2025, 8, 22),
    updatedAt: DateTime(2025, 8, 22),
  );
}
```

- [ ] **Step 2: Write the failing tests**

Create `test/features/nav_track/domain/nav_track_proximity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_proximity.dart';

import '../../../helpers/nav_track_fixtures.dart';

void main() {
  final entry = DateTime.fromMillisecondsSinceEpoch(
    kTestRouteStartMs,
    isUtc: true,
  );
  const hour = 3600000;

  group('NavTrack.displayName', () {
    test('prefers the name, then the source file, then the id', () {
      expect(testNavTrack('r1', name: 'Wreck tour').displayName, 'Wreck tour');
      expect(testNavTrack('r1').displayName, 'r1.csv');
      final bare = NavTrack(
        id: 'r9',
        source: NavTrackSource.seacraftEnc,
        startTime: 0,
        endTime: 1,
        pointCount: 0,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(bare.displayName, 'r9');
    });
  });

  group('sortByProximityTo', () {
    test('orders by distance from the entry time, nearest first', () {
      final far = testNavTrack('far', startTime: kTestRouteStartMs + 5 * hour);
      final near = testNavTrack('near', startTime: kTestRouteStartMs - hour);
      final exact = testNavTrack('exact');

      final sorted = sortByProximityTo([far, near, exact], entry);

      expect(sorted.map((r) => r.id), ['exact', 'near', 'far']);
    });

    test('breaks a tie by the earlier recording, then by id', () {
      // Fed in the reverse of tie-break order, so the test fails without it.
      final laterB = testNavTrack('b', startTime: kTestRouteStartMs + hour);
      final laterA = testNavTrack('a', startTime: kTestRouteStartMs + hour);
      final earlier = testNavTrack('z', startTime: kTestRouteStartMs - hour);

      final sorted = sortByProximityTo([laterB, laterA, earlier], entry);

      expect(sorted.map((r) => r.id), ['z', 'a', 'b']);
    });

    test('returns an empty list for no routes', () {
      expect(sortByProximityTo(const [], entry), isEmpty);
    });

    test('never reorders the list it was given', () {
      final input = [
        testNavTrack('far', startTime: kTestRouteStartMs + hour),
        testNavTrack('exact'),
      ];

      sortByProximityTo(input, entry);

      expect(input.map((r) => r.id), ['far', 'exact']);
    });
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/nav_track/domain/nav_track_proximity_test.dart`
Expected: FAIL to compile: `nav_track_proximity.dart` not found and `displayName` not defined.

- [ ] **Step 4: Implement**

In `lib/features/nav_track/domain/entities/nav_track.dart`, directly after the closing `});` of the `const NavTrack({...})` constructor, add:

```dart
  /// What a list row or picker calls this route: its own name, else the
  /// file it was imported from, else its id.
  String get displayName => name ?? sourceRef ?? id;
```

Create `lib/features/nav_track/domain/nav_track_proximity.dart`:

```dart
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// [routes] ordered by how close each recording started to [entryTime],
/// nearest first, as a new list. Ties go to the earlier recording, then to
/// the lower id, so every device shows the same order.
///
/// [entryTime] is a dive time as the app stores it and is compared with
/// [NavTrack.startTime] exactly as the dive detail section's link picker
/// always compared them.
List<NavTrack> sortByProximityTo(Iterable<NavTrack> routes, DateTime entryTime) {
  final entryMs = entryTime.millisecondsSinceEpoch;
  int gap(NavTrack route) => (route.startTime - entryMs).abs();
  return [...routes]..sort((a, b) {
    final byGap = gap(a).compareTo(gap(b));
    if (byGap != 0) return byGap;
    final byStart = a.startTime.compareTo(b.startTime);
    if (byStart != 0) return byStart;
    return a.id.compareTo(b.id);
  });
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/nav_track/domain/nav_track_proximity_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/nav_track test/helpers/nav_track_fixtures.dart test/features/nav_track/domain
git add lib/features/nav_track/domain/entities/nav_track.dart lib/features/nav_track/domain/nav_track_proximity.dart test/helpers/nav_track_fixtures.dart test/features/nav_track/domain/nav_track_proximity_test.dart
git commit -m "feat(nav-track): add a route display name and proximity ordering helper"
```

---

### Task 2: The link draft and its applier

**Files:**
- Create: `lib/features/nav_track/domain/dive_route_link_draft.dart`
- Create: `lib/features/nav_track/application/dive_route_link_applier.dart`
- Test: `test/features/nav_track/domain/dive_route_link_draft_test.dart`
- Test: `test/features/nav_track/application/dive_route_link_applier_test.dart`

**Interfaces:**
- Consumes: `NavTrack` (Task 1 fixtures in tests).
- Produces: `class DiveRouteLinkDraft` with `factory DiveRouteLinkDraft.initial(List<NavTrack> linked)`, getters `List<NavTrack> original`, `List<NavTrack> current`, `List<NavTrack> removed`, `List<String> toLink`, `List<String> toUnlink`, `bool hasChanges`, methods `bool contains(String routeId)`, `bool wasLinkedOnOpen(String routeId)`, `DiveRouteLinkDraft add(NavTrack route)`, `DiveRouteLinkDraft remove(String routeId)`, `DiveRouteLinkDraft replaced(String replacedRouteId, NavTrack replacement)`.
- Produces: `Future<List<String>> applyDiveRouteLinkDraft(NavTrackRepository repository, {required String diveId, required DiveRouteLinkDraft draft})` returning ids that `link()` skipped (already linked elsewhere). Repository exceptions propagate.

- [ ] **Step 1: Write the failing draft tests**

Create `test/features/nav_track/domain/dive_route_link_draft_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

import '../../../helpers/nav_track_fixtures.dart';

void main() {
  final a = testNavTrack('a', diveId: 'd1');
  final b = testNavTrack('b');
  final c = testNavTrack('c');

  test('a fresh draft has no changes', () {
    final draft = DiveRouteLinkDraft.initial([a]);
    expect(draft.current.map((r) => r.id), ['a']);
    expect(draft.toLink, isEmpty);
    expect(draft.toUnlink, isEmpty);
    expect(draft.hasChanges, isFalse);
  });

  test('add links a new route and ignores one already present', () {
    final draft = DiveRouteLinkDraft.initial([a]).add(b).add(b).add(a);
    expect(draft.current.map((r) => r.id), ['a', 'b']);
    expect(draft.toLink, ['b']);
    expect(draft.toUnlink, isEmpty);
  });

  test('remove unlinks an original route and lists it as removed', () {
    final draft = DiveRouteLinkDraft.initial([a]).remove('a');
    expect(draft.current, isEmpty);
    expect(draft.toUnlink, ['a']);
    expect(draft.removed.map((r) => r.id), ['a']);
  });

  test('re-adding a removed route is no net change', () {
    final draft = DiveRouteLinkDraft.initial([a]).remove('a').add(a);
    expect(draft.hasChanges, isFalse);
    expect(draft.removed, isEmpty);
  });

  test('removing a just-added route is no net change', () {
    final draft = DiveRouteLinkDraft.initial([a]).add(b).remove('b');
    expect(draft.hasChanges, isFalse);
  });

  test('replaced drops a deleted original without unlinking it', () {
    // The review page already deleted "a" in favour of its re-import "c".
    final draft = DiveRouteLinkDraft.initial([a]).replaced('a', c);
    expect(draft.current.map((r) => r.id), ['c']);
    expect(draft.toLink, ['c']);
    expect(draft.toUnlink, isEmpty);
    expect(draft.removed, isEmpty);
  });

  test('replaced drops a deleted just-added route as well', () {
    final draft = DiveRouteLinkDraft.initial(const []).add(b).replaced('b', c);
    expect(draft.current.map((r) => r.id), ['c']);
    expect(draft.toLink, ['c']);
  });

  test('wasLinkedOnOpen tells original routes from added ones', () {
    final draft = DiveRouteLinkDraft.initial([a]).add(b);
    expect(draft.wasLinkedOnOpen('a'), isTrue);
    expect(draft.wasLinkedOnOpen('b'), isFalse);
  });

  test('never changes when the list it was built from changes', () {
    final linked = <NavTrack>[a];
    final draft = DiveRouteLinkDraft.initial(linked);
    linked.add(b);
    expect(draft.current.map((r) => r.id), ['a']);
    expect(() => draft.current.add(c), throwsUnsupportedError);
  });

  test('each change returns a new draft and leaves the old one alone', () {
    final first = DiveRouteLinkDraft.initial([a]);
    final second = first.add(b);
    expect(identical(first, second), isFalse);
    expect(first.current.map((r) => r.id), ['a']);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/nav_track/domain/dive_route_link_draft_test.dart`
Expected: FAIL to compile, `dive_route_link_draft.dart` not found.

- [ ] **Step 3: Implement the draft**

Create `lib/features/nav_track/domain/dive_route_link_draft.dart`:

```dart
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// The Dive Edit page's pending underwater route links (spec
/// 2026-10-02-underwater-route-entry-points-design.md, section 1): the
/// routes linked when the form opened, and the ones the diver has linked or
/// removed since. Nothing is written until the dive is saved, when
/// [toUnlink] and [toLink] are applied. Immutable: every change returns a
/// new draft.
class DiveRouteLinkDraft {
  const DiveRouteLinkDraft._(this.original, this.current);

  /// A draft for a dive whose routes are [linked] right now (empty for a
  /// new dive).
  factory DiveRouteLinkDraft.initial(List<NavTrack> linked) {
    final copy = List<NavTrack>.unmodifiable(linked);
    return DiveRouteLinkDraft._(copy, copy);
  }

  /// The routes linked when the form opened.
  final List<NavTrack> original;

  /// The routes the dive will have once saved, in the order shown.
  final List<NavTrack> current;

  Set<String> get _originalIds => {for (final r in original) r.id};
  Set<String> get _currentIds => {for (final r in current) r.id};

  bool contains(String routeId) => _currentIds.contains(routeId);

  bool wasLinkedOnOpen(String routeId) => _originalIds.contains(routeId);

  /// Routes linked when the form opened that the diver has since removed.
  /// They stay linked in the database until Save, so the link picker offers
  /// them again alongside the unlinked routes.
  List<NavTrack> get removed => List.unmodifiable([
    for (final r in original)
      if (!_currentIds.contains(r.id)) r,
  ]);

  List<String> get toLink => List.unmodifiable([
    for (final r in current)
      if (!_originalIds.contains(r.id)) r.id,
  ]);

  List<String> get toUnlink =>
      List.unmodifiable([for (final r in removed) r.id]);

  bool get hasChanges => toLink.isNotEmpty || toUnlink.isNotEmpty;

  DiveRouteLinkDraft add(NavTrack route) => contains(route.id)
      ? this
      : DiveRouteLinkDraft._(original, List.unmodifiable([...current, route]));

  DiveRouteLinkDraft remove(String routeId) => DiveRouteLinkDraft._(
    original,
    List.unmodifiable(current.where((r) => r.id != routeId)),
  );

  /// [replacement] took the place of [replacedRouteId], a duplicate the
  /// import review page has already deleted. The deleted route leaves the
  /// draft entirely (there is no row left to unlink) and [replacement] is
  /// added.
  DiveRouteLinkDraft replaced(String replacedRouteId, NavTrack replacement) =>
      DiveRouteLinkDraft._(
        List.unmodifiable(original.where((r) => r.id != replacedRouteId)),
        List.unmodifiable([
          ...current.where(
            (r) => r.id != replacedRouteId && r.id != replacement.id,
          ),
          replacement,
        ]),
      );
}
```

- [ ] **Step 4: Run the draft tests**

Run: `flutter test test/features/nav_track/domain/dive_route_link_draft_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 5: Write the failing applier tests**

Create `test/features/nav_track/application/dive_route_link_applier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/application/dive_route_link_applier.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

import '../../../helpers/nav_track_fixtures.dart';

/// Records the order of calls instead of touching a database.
class _RecordingRepository extends NavTrackRepository {
  _RecordingRepository({this.alreadyLinked = const {}});

  /// Ids whose `link` reports "already linked elsewhere" (returns false).
  final Set<String> alreadyLinked;
  final calls = <String>[];

  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    calls.add('link $routeId $diveId ${linkMode.name}');
    return !alreadyLinked.contains(routeId);
  }

  @override
  Future<void> unlink(String routeId) async => calls.add('unlink $routeId');
}

void main() {
  final a = testNavTrack('a', diveId: 'd1');
  final b = testNavTrack('b');

  test('unlinks removals before linking additions, as manual links', () async {
    final repository = _RecordingRepository();
    final draft = DiveRouteLinkDraft.initial([a]).remove('a').add(b);

    final skipped = await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: draft,
    );

    expect(repository.calls, ['unlink a', 'link b d1 manual']);
    expect(skipped, isEmpty);
  });

  test('writes nothing for a draft without changes', () async {
    final repository = _RecordingRepository();

    await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: DiveRouteLinkDraft.initial([a]),
    );

    expect(repository.calls, isEmpty);
  });

  test('reports a route something else linked first, without throwing', () async {
    final repository = _RecordingRepository(alreadyLinked: {'b'});

    final skipped = await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: DiveRouteLinkDraft.initial(const []).add(b),
    );

    expect(skipped, ['b']);
  });
}
```

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/nav_track/application/dive_route_link_applier_test.dart`
Expected: FAIL to compile, `dive_route_link_applier.dart` not found.

- [ ] **Step 7: Implement the applier**

Create `lib/features/nav_track/application/dive_route_link_applier.dart`:

```dart
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// Writes [draft] for [diveId] once the dive row exists. Removals are
/// unlinked before additions are linked, so `link` re-decides the dive's
/// primary route against what is actually left.
///
/// Returns the ids `link` skipped because the route was already linked by
/// the time this ran (synced from another device, or auto-linked when a new
/// dive was created). Repository errors propagate to the caller.
Future<List<String>> applyDiveRouteLinkDraft(
  NavTrackRepository repository, {
  required String diveId,
  required DiveRouteLinkDraft draft,
}) async {
  for (final routeId in draft.toUnlink) {
    await repository.unlink(routeId);
  }
  final skipped = <String>[];
  for (final routeId in draft.toLink) {
    final linked = await repository.link(
      routeId,
      diveId,
      linkMode: NavTrackLinkMode.manual,
    );
    if (!linked) skipped.add(routeId);
  }
  return List.unmodifiable(skipped);
}
```

- [ ] **Step 8: Run both test files**

Run: `flutter test test/features/nav_track/domain/dive_route_link_draft_test.dart test/features/nav_track/application/dive_route_link_applier_test.dart`
Expected: PASS (13 tests).

- [ ] **Step 9: Commit**

```bash
dart format lib/features/nav_track test/features/nav_track
git add lib/features/nav_track/domain/dive_route_link_draft.dart lib/features/nav_track/application/dive_route_link_applier.dart test/features/nav_track/domain/dive_route_link_draft_test.dart test/features/nav_track/application/dive_route_link_applier_test.dart
git commit -m "feat(nav-track): stage a dive's route links in a draft and apply them on save"
```

---

### Task 3: New localisation strings

**Files:**
- Modify: all 11 files `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` (generated, committed)

**Interfaces:**
- Produces generated getters/methods: `navTrack_editRow_none`, `navTrack_editRow_more(...)` (placeholders `count` int and `name` String; check the generated argument order), `navTrack_editSheet_removeTooltip`, `navTrack_editRow_saveFailed(String error)`, `settings_manage_navRoutes_subtitle`.
- Reused existing keys (no change): `navTrack_section_title` ("Underwater Route"), `navTrack_list_title` ("Underwater Routes"), `navTrack_section_noRouteLinked`, `navTrack_section_linkButton`, `navTrack_section_importButton`, `navTrack_section_primaryTag`.

- [ ] **Step 1: Add the English keys**

In `lib/l10n/arb/app_en.arb`, directly after the line `"navTrack_section_menuMakePrimary": "Make primary",` insert:

```json
  "navTrack_editRow_none": "None",
  "navTrack_editRow_more": "{name} +{count}",
  "@navTrack_editRow_more": {
    "description": "Dive Edit route row value when several routes are linked: the first route's name and how many more there are",
    "placeholders": {
      "count": {
        "type": "int"
      },
      "name": {
        "type": "String"
      }
    }
  },
  "navTrack_editSheet_removeTooltip": "Remove route",
  "navTrack_editRow_saveFailed": "Could not update this dive's underwater routes: {error}",
  "@navTrack_editRow_saveFailed": {
    "placeholders": {
      "error": {
        "type": "String"
      }
    }
  },
```

Directly after the line `"settings_manage_savedQueries_subtitle": ...,` insert:

```json
  "settings_manage_navRoutes_subtitle": "Import, align and link recorded routes",
```

- [ ] **Step 2: Add the translations**

In each non-English file, insert the first four keys directly after its `"navTrack_section_menuMakePrimary"` line, and `settings_manage_navRoutes_subtitle` directly after its `"settings_manage_savedQueries_subtitle"` line. Values (the `{name} +{count}` value is identical in every locale):

| Locale | `navTrack_editRow_none` | `navTrack_editSheet_removeTooltip` | `navTrack_editRow_saveFailed` | `settings_manage_navRoutes_subtitle` |
|---|---|---|---|---|
| ar | لا يوجد | إزالة المسار | تعذر تحديث مسارات هذه الغوصة تحت الماء: {error} | استيراد المسارات المسجلة ومحاذاتها وربطها |
| de | Keine | Route entfernen | Unterwasser-Routen dieses Tauchgangs konnten nicht aktualisiert werden: {error} | Aufgezeichnete Routen importieren, ausrichten und verknüpfen |
| es | Ninguna | Quitar ruta | No se pudieron actualizar las rutas submarinas de esta inmersión: {error} | Importar, alinear y vincular rutas grabadas |
| fr | Aucun | Retirer le trajet | Impossible de mettre à jour les trajets sous-marins de cette plongée : {error} | Importer, aligner et lier les trajets enregistrés |
| he | אין | הסרת מסלול | לא ניתן לעדכן את המסלולים התת-ימיים של צלילה זו: {error} | ייבוא, יישור וקישור של מסלולים מוקלטים |
| hu | Nincs | Útvonal eltávolítása | Nem sikerült frissíteni a merülés vízalatti útvonalait: {error} | Rögzített útvonalak importálása, igazítása és összekapcsolása |
| it | Nessuno | Rimuovi percorso | Impossibile aggiornare i percorsi subacquei di questa immersione: {error} | Importa, allinea e collega i percorsi registrati |
| nl | Geen | Route verwijderen | Kan de onderwaterroutes van deze duik niet bijwerken: {error} | Opgenomen routes importeren, uitlijnen en koppelen |
| pt | Nenhuma | Remover rota | Não foi possível atualizar as rotas subaquáticas deste mergulho: {error} | Importar, alinhar e associar rotas gravadas |
| zh | 无 | 移除路线 | 无法更新此潜水的水下路线：{error} | 导入、对齐并关联已记录的路线 |

Non-English files take no `@` metadata entries.

- [ ] **Step 3: Regenerate and check**

Run: `flutter gen-l10n`
Expected: completes with no "untranslated message" warnings for the five new keys.

Run: `grep -n "navTrack_editRow_more(" lib/l10n/arb/app_localizations.dart`
Expected: a signature such as `String navTrack_editRow_more(int count, String name);`. Note the argument order for Tasks 5 and 6.

Run: `flutter analyze lib/l10n`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(l10n): add strings for the dive edit route row and the routes Manage tile"
```

---

### Task 4: Import review page return mode

**Files:**
- Modify: `lib/features/nav_track/presentation/pages/nav_track_import_review_page.dart` (navigation helpers near lines 28-58, widget fields near 73-92, state init near 116-155, `_save` near 292-352, the "Link to dive" block near 470-485)
- Test: `test/features/nav_track/presentation/pages/nav_track_import_review_page_test.dart`

**Interfaces:**
- Produces: `typedef NavTrackImportResult = ({String routeId, String? replacedRouteId});`
- Produces: `Future<NavTrackImportResult?> navigateToNavTrackReviewForResult(BuildContext context, Uint8List bytes, {required String fileName, NavTrackImportPreview? preview, DiveSite? initialSite})`. Null when the diver leaves without saving.
- Produces: `NavTrackImportReviewPage` fields `final bool returnResult` (default false) and `final DiveSite? initialSite`.
- Existing `navigateToNavTrackReview` behaviour is unchanged.

- [ ] **Step 1: Write the failing tests**

In `test/features/nav_track/presentation/pages/nav_track_import_review_page_test.dart`:

(a) Add the import `import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';` if it is not already present.

(b) In the existing `_RecordingImportService` class (the one with `lastEquipmentId`, around line 270), add fields and record them in `commit`:

```dart
  Dive? lastDive;
  String? lastSiteId;
```

and inside its `commit` body, before `commitCount++;`:

```dart
    lastDive = dive;
    lastSiteId = siteId;
```

(c) Add this helper after the existing `_pump` function:

```dart
/// Opens the review page in return mode from a host page, the way the Dive
/// Edit page's route sheet does, and collects what it pops with.
Future<List<NavTrackImportResult?>> _pumpReturnMode(
  WidgetTester tester, {
  required NavTrackImportPreview preview,
  required NavTrackImportService service,
  DiveSite? initialSite,
}) async {
  tester.platformDispatcher.localesTestValue = const [
    Locale('de'),
    Locale('en'),
  ];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  final results = <NavTrackImportResult?>[];
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        navTrackImportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await navigateToNavTrackReviewForResult(
                  context,
                  Uint8List(0),
                  fileName: '005.DAT.csv',
                  preview: preview,
                  initialSite: initialSite,
                ),
              ),
              child: const Text('HOST'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('HOST'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('nav-track-import-save')));
  await tester.pumpAndSettle();
}
```

(d) Add a group at the end of `main()`:

```dart
  group('return mode (Dive Edit import)', () {
    final overlapping = _dive('d-overlap', DateTime.utc(2023, 11, 14, 22));

    testWidgets('hides the dive picker and saves the route unlinked, even '
        'when exactly one dive overlaps', (tester) async {
      final service = _RecordingImportService();
      final results = await _pumpReturnMode(
        tester,
        preview: _preview(candidateDives: [overlapping]),
        service: service,
      );

      expect(find.text('Link to dive'), findsNothing);
      await _tapSave(tester);

      expect(service.commitCount, 1);
      expect(service.lastDive, isNull);
      expect(results, [(routeId: 'new-route-id', replacedRouteId: null)]);
      // Back on the host page: nothing navigated past it.
      expect(find.text('HOST'), findsOneWidget);
    });

    testWidgets('reports the duplicate it replaced', (tester) async {
      final service = _RecordingImportService();
      final results = await _pumpReturnMode(
        tester,
        preview: _preview(duplicateOfRouteId: 'existing-route'),
        service: service,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await _tapSave(tester);

      expect(results, [
        (routeId: 'new-route-id', replacedRouteId: 'existing-route'),
      ]);
    });

    testWidgets('pre-fills the site the edit form already chose', (
      tester,
    ) async {
      final service = _RecordingImportService();
      await _pumpReturnMode(
        tester,
        preview: _preview(),
        service: service,
        initialSite: const DiveSite(id: 'site-1', name: 'Blue Hole'),
      );

      expect(find.text('Blue Hole'), findsOneWidget);
      await _tapSave(tester);

      expect(service.lastSiteId, 'site-1');
    });

    testWidgets('pops null when the diver backs out', (tester) async {
      final results = await _pumpReturnMode(
        tester,
        preview: _preview(),
        service: _RecordingImportService(),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(results, [null]);
    });
  });
```

The `_dive` entry time `DateTime.utc(2023, 11, 14, 22)` sits inside the fixture recording window (`_points()` start 1700000000 s, 2023-11-14 22:13 UTC). The test only needs the dive to be offered as a candidate, which `_preview(candidateDives: ...)` does directly.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/nav_track/presentation/pages/nav_track_import_review_page_test.dart`
Expected: FAIL to compile (`navigateToNavTrackReviewForResult`, `NavTrackImportResult` undefined).

- [ ] **Step 3: Implement**

In `nav_track_import_review_page.dart`:

(a) Add the import `import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';` if absent.

(b) Directly after the existing `navigateToNavTrackReview` function, add:

```dart
/// What the review page pops with in return mode: the saved route, and the
/// duplicate it replaced (already deleted) when the diver ticked "replace".
typedef NavTrackImportResult = ({String routeId, String? replacedRouteId});

/// Opens the review page in return mode, for a caller that links the route
/// itself later (the Dive Edit page's route sheet, which stages links until
/// the dive is saved). The page hides its dive picker, saves the route
/// unlinked, and pops with the result instead of opening the route.
/// [initialSite] pre-fills the site picker. Null when the diver leaves
/// without saving.
Future<NavTrackImportResult?> navigateToNavTrackReviewForResult(
  BuildContext context,
  Uint8List bytes, {
  required String fileName,
  NavTrackImportPreview? preview,
  DiveSite? initialSite,
}) {
  return Navigator.of(context).push<NavTrackImportResult>(
    MaterialPageRoute(
      builder: (_) => NavTrackImportReviewPage(
        bytes: bytes,
        fileName: fileName,
        preview: preview,
        returnResult: true,
        initialSite: initialSite,
      ),
    ),
  );
}
```

(c) Update the entry-point list in the doc comment above `navigateToNavTrackReview`: replace "the dive detail section's import button" with "the Dive Edit page's route sheet (through [navigateToNavTrackReviewForResult])", and in the `[preselectedDive]` paragraph replace the example "(e.g. importing from a dive's own "Underwater Route" section, where the dive is already known)" with "(when the caller already knows the dive)". In the doc comment above the class, replace "the routes area's and the dive section's import buttons do this" with "the routes area's import button and the Dive Edit route sheet do this".

(d) In the `NavTrackImportReviewPage` constructor add `this.returnResult = false, this.initialSite,` and the fields:

```dart
  /// Return mode (see [navigateToNavTrackReviewForResult]): no dive picker,
  /// the route is saved unlinked, and the page pops with a
  /// [NavTrackImportResult] instead of opening the route.
  final bool returnResult;

  /// The site to pre-fill, as if the diver had picked it. Return mode only.
  final DiveSite? initialSite;
```

(e) In `initState`, after `super.initState();`, add:

```dart
    final site = widget.initialSite;
    if (site != null) {
      _siteId = site.id;
      _siteName = site.name;
      // Treated as the diver's own pick, so no dive selection replaces it.
      _siteChosenManually = true;
    }
```

(f) In `_initializeDiveChoice`, directly after `_diveChoiceInitialized = true;`, add:

```dart
    // The caller links the route itself, so nothing is pre-selected here.
    if (widget.returnResult) return;
```

(g) In `build`, wrap the "Link to dive" heading and picker in a collection-if. Replace:

```dart
        const SizedBox(height: 24),
        Text(
          l10n.navTrack_review_linkToDive,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _DiveLinkPicker(
          candidates: preview.candidateDives,
          nearby: preview.nearbyDives,
          selected: _selectedDive,
          recordingStartSeconds: points.first.timestamp,
          units: units,
          onChanged: _selectDive,
          onChooseAnother: () => _chooseAnotherDive(preview),
        ),
```

with:

```dart
        if (!widget.returnResult) ...[
          const SizedBox(height: 24),
          Text(
            l10n.navTrack_review_linkToDive,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _DiveLinkPicker(
            candidates: preview.candidateDives,
            nearby: preview.nearbyDives,
            selected: _selectedDive,
            recordingStartSeconds: points.first.timestamp,
            units: units,
            onChanged: _selectDive,
            onChooseAnother: () => _chooseAnotherDive(preview),
          ),
        ],
```

(h) In `_save`, directly after the existing `if (!mounted) return;` that follows the try/catch, and before the comment block starting "Outside the try", add:

```dart
    if (widget.returnResult) {
      Navigator.of(context).pop<NavTrackImportResult>((
        routeId: id,
        replacedRouteId: _replaceDuplicate ? preview.duplicateOfRouteId : null,
      ));
      return;
    }
```

- [ ] **Step 4: Run the whole review page test file**

Run: `flutter test test/features/nav_track/presentation/pages/nav_track_import_review_page_test.dart`
Expected: PASS, including every pre-existing test (default mode unchanged).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/nav_track test/features/nav_track
git add lib/features/nav_track/presentation/pages/nav_track_import_review_page.dart test/features/nav_track/presentation/pages/nav_track_import_review_page_test.dart
git commit -m "feat(nav-track): let the import review page return the saved route to its caller"
```

---

### Task 5: The Route row and the route sheet

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/route_row.dart`
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/route_link_sheet.dart`
- Test: `test/features/dive_log/presentation/widgets/edit_sections/route_row_test.dart`
- Test: `test/features/dive_log/presentation/widgets/edit_sections/route_link_sheet_test.dart`

**Interfaces:**
- Consumes: `DiveRouteLinkDraft` (Task 2), `sortByProximityTo` and `NavTrack.displayName` (Task 1), `navigateToNavTrackReviewForResult` / `NavTrackImportResult` (Task 4), Task 3 strings, existing `unlinkedNavTracksProvider`, `navTrackRepositoryProvider`, `navTrackImportServiceProvider`, `navTrackParseErrorText`.
- Produces: `class RouteRow extends StatelessWidget` with `const RouteRow({super.key, required DiveRouteLinkDraft? draft, required VoidCallback onTap})`; row key `ValueKey('dive-edit-route-row')`; a null draft means "still loading" and taps do nothing.
- Produces: `Future<void> showRouteLinkSheet(BuildContext context, {required DiveRouteLinkDraft draft, required DateTime entryTime, DiveSite? site, required ValueChanged<DiveRouteLinkDraft> onChanged})`. Keys: `route-sheet-row-<id>`, `route-sheet-remove-<id>`, `route-sheet-link-button`, `route-sheet-import-button`, `route-sheet-candidate-<id>`.

- [ ] **Step 1: Write the failing row tests**

Create `test/features/dive_log/presentation/widgets/edit_sections/route_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_row.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/nav_track_fixtures.dart';

Future<int Function()> _pump(
  WidgetTester tester,
  DiveRouteLinkDraft? draft,
) async {
  tester.platformDispatcher.localesTestValue = const [
    Locale('de'),
    Locale('en'),
  ];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  var taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RouteRow(draft: draft, onTap: () => taps++),
      ),
    ),
  );
  return () => taps;
}

void main() {
  testWidgets('labels the row and shows None without routes', (tester) async {
    await _pump(tester, DiveRouteLinkDraft.initial(const []));
    expect(find.text('Underwater Route'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('shows the single linked route by name', (tester) async {
    await _pump(
      tester,
      DiveRouteLinkDraft.initial([testNavTrack('a', name: 'Wreck tour')]),
    );
    expect(find.text('Wreck tour'), findsOneWidget);
  });

  testWidgets('shows the first name and how many more', (tester) async {
    await _pump(
      tester,
      DiveRouteLinkDraft.initial([
        testNavTrack('a', name: 'Wreck tour'),
        testNavTrack('b'),
        testNavTrack('c'),
      ]),
    );
    expect(find.text('Wreck tour +2'), findsOneWidget);
  });

  testWidgets('tapping calls onTap once the draft is loaded', (tester) async {
    final taps = await _pump(tester, DiveRouteLinkDraft.initial(const []));
    await tester.tap(find.byKey(const ValueKey('dive-edit-route-row')));
    expect(taps(), 1);
  });

  testWidgets('tapping does nothing while the links are still loading', (
    tester,
  ) async {
    final taps = await _pump(tester, null);
    await tester.tap(find.byKey(const ValueKey('dive-edit-route-row')));
    expect(taps(), 0);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/route_row_test.dart`
Expected: FAIL to compile, `route_row.dart` not found.

- [ ] **Step 3: Implement the row**

Create `lib/features/dive_log/presentation/widgets/edit_sections/route_row.dart` (use the argument order you noted in Task 3 Step 3 for `navTrack_editRow_more`; the version below assumes `(int count, String name)`):

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

/// The Dive Edit page's "Underwater Route" row, under Site (spec
/// 2026-10-02-underwater-route-entry-points-design.md, section 1). Shows
/// the routes the dive will have once saved; tapping opens the route sheet.
///
/// A null [draft] means the dive's current links are still loading. Taps
/// are ignored until then, so a Save can never treat "not loaded yet" as
/// "every route removed".
class RouteRow extends StatelessWidget {
  const RouteRow({super.key, required this.draft, required this.onTap});

  final DiveRouteLinkDraft? draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final routes = draft?.current ?? const [];
    final value = switch (routes) {
      [] => null,
      [final only] => only.displayName,
      [final first, ...] => l10n.navTrack_editRow_more(
        routes.length - 1,
        first.displayName,
      ),
    };
    return FormRow.picker(
      key: const ValueKey('dive-edit-route-row'),
      label: l10n.navTrack_section_title,
      value: value,
      placeholder: l10n.navTrack_editRow_none,
      onTap: () {
        if (draft != null) onTap();
      },
    );
  }
}
```

- [ ] **Step 4: Run the row tests**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/route_row_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Write the failing sheet tests**

Create `test/features/dive_log/presentation/widgets/edit_sections/route_link_sheet_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_link_sheet.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_file_picker_platform.dart';
import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/nav_track_fixtures.dart';

/// Hands back routes by id, as the sheet reads a freshly imported one.
class _FakeRouteRepository extends NavTrackRepository {
  _FakeRouteRepository([this.byId = const {}]);

  final Map<String, NavTrack> byId;

  @override
  Future<NavTrack?> getById(String id, {bool includePoints = true}) async =>
      byId[id];
}

/// A fixed preview, and a commit that "saves" as `new-route`.
class _FakeImportService implements NavTrackImportService {
  _FakeImportService({this.duplicateOfRouteId});

  final String? duplicateOfRouteId;

  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async => NavTrackImportPreview(
    parsed: const ParsedNavTrack(points: kTestNavTrackPoints),
    stats: NavTrackStats.of(kTestNavTrackPoints),
    segmentation: NavTrackSegmenter.classify(kTestNavTrackPoints),
    candidateDives: const [],
    nearbyDives: const [],
    duplicateOfRouteId: duplicateOfRouteId,
    sourceRef: fileName ?? '',
  );

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    required String? diverId,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
    String? replacingRouteId,
  }) async => 'new-route';
}

Future<List<DiveRouteLinkDraft>> _openSheet(
  WidgetTester tester, {
  required DiveRouteLinkDraft draft,
  List<NavTrack> unlinked = const [],
  DateTime? entryTime,
  NavTrackRepository? repository,
  NavTrackImportService? service,
}) async {
  tester.platformDispatcher.localesTestValue = const [
    Locale('de'),
    Locale('en'),
  ];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final changes = <DiveRouteLinkDraft>[];
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        unlinkedNavTracksProvider.overrideWith((ref) async => unlinked),
        navTrackRepositoryProvider.overrideWithValue(
          repository ?? _FakeRouteRepository(),
        ),
        if (service != null)
          navTrackImportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRouteLinkSheet(
                context,
                draft: draft,
                entryTime:
                    entryTime ??
                    DateTime.fromMillisecondsSinceEpoch(
                      kTestRouteStartMs,
                      isUtc: true,
                    ),
                onChanged: changes.add,
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return changes;
}

void _mockPickedFile() {
  final original = FilePickerPlatform.instance;
  addTearDown(() => FilePickerPlatform.instance = original);
  FilePickerPlatform.instance = MockFilePickerPlatform()
    ..pickFilesResult = [
      FakePlatformFile.contentUri(
        Uri.parse('content://picked/005.DAT.csv'),
        name: '005.DAT.csv',
        bytes: Uint8List.fromList([1]),
      ),
    ];
}

Future<void> _saveReviewPage(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).last, const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('nav-track-import-save')));
  await tester.pumpAndSettle();
}

void main() {
  const hour = 3600000;

  testWidgets('lists the draft routes with their distance', (
    tester,
  ) async {
    await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial([
        testNavTrack('a', name: 'Wreck tour', totalDistance: 1050),
      ]),
    );
    expect(find.byKey(const ValueKey('route-sheet-row-a')), findsOneWidget);
    expect(find.text('Wreck tour'), findsOneWidget);
    expect(find.textContaining('1050'), findsOneWidget);
  });

  testWidgets('shows "No route linked" for an empty draft', (tester) async {
    await _openSheet(tester, draft: DiveRouteLinkDraft.initial(const []));
    expect(find.text('No route linked'), findsOneWidget);
  });

  testWidgets('removing a route reports a draft without it', (tester) async {
    final changes = await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial([testNavTrack('a')]),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-remove-a')));
    await tester.pumpAndSettle();

    expect(changes.last.current, isEmpty);
    expect(changes.last.toUnlink, ['a']);
    expect(find.byKey(const ValueKey('route-sheet-row-a')), findsNothing);
  });

  testWidgets('hides "Link route" when there is nothing to link', (
    tester,
  ) async {
    await _openSheet(tester, draft: DiveRouteLinkDraft.initial(const []));
    expect(
      find.byKey(const ValueKey('route-sheet-link-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('route-sheet-import-button')),
      findsOneWidget,
    );
  });

  testWidgets('offers unlinked routes nearest the form\'s entry time first, '
      'and linking one reports it', (tester) async {
    final morning = testNavTrack('early', name: 'Early');
    final afternoon = testNavTrack(
      'late',
      name: 'Late',
      startTime: kTestRouteStartMs + 5 * hour,
    );
    final changes = await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial(const []),
      unlinked: [morning, afternoon],
      // The diver moved the entry time to the afternoon on the form.
      entryTime: DateTime.fromMillisecondsSinceEpoch(
        kTestRouteStartMs + 5 * hour,
        isUtc: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-link-button')));
    await tester.pumpAndSettle();

    final lateTop = tester.getTopLeft(
      find.byKey(const ValueKey('route-sheet-candidate-late')),
    );
    final earlyTop = tester.getTopLeft(
      find.byKey(const ValueKey('route-sheet-candidate-early')),
    );
    expect(lateTop.dy, lessThan(earlyTop.dy));

    await tester.tap(find.byKey(const ValueKey('route-sheet-candidate-late')));
    await tester.pumpAndSettle();

    expect(changes.last.toLink, ['late']);
  });

  testWidgets('offers a removed original route again, but never one already '
      'in the draft', (tester) async {
    final a = testNavTrack('a', diveId: 'd1');
    final b = testNavTrack('b', diveId: 'd1');
    await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial([a, b]),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-remove-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-sheet-link-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-sheet-candidate-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('route-sheet-candidate-b')),
      findsNothing,
    );
  });

  testWidgets('importing a file adds the saved route to the draft', (
    tester,
  ) async {
    _mockPickedFile();
    final saved = testNavTrack('new-route', name: 'Imported');
    final changes = await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial(const []),
      repository: _FakeRouteRepository({'new-route': saved}),
      service: _FakeImportService(),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-import-button')));
    await tester.pumpAndSettle();
    // The review page opened in return mode: no dive picker.
    expect(find.text('Link to dive'), findsNothing);
    await _saveReviewPage(tester);

    expect(changes.last.toLink, ['new-route']);
    expect(
      find.byKey(const ValueKey('route-sheet-row-new-route')),
      findsOneWidget,
    );
  });

  testWidgets('importing a re-export that replaces this dive\'s route swaps '
      'it in the draft without unlinking the deleted one', (tester) async {
    _mockPickedFile();
    final old = testNavTrack('old', diveId: 'd1');
    final saved = testNavTrack('new-route');
    final changes = await _openSheet(
      tester,
      draft: DiveRouteLinkDraft.initial([old]),
      repository: _FakeRouteRepository({'new-route': saved}),
      service: _FakeImportService(duplicateOfRouteId: 'old'),
    );

    await tester.tap(find.byKey(const ValueKey('route-sheet-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await _saveReviewPage(tester);

    expect(changes.last.current.map((r) => r.id), ['new-route']);
    expect(changes.last.toUnlink, isEmpty);
    expect(changes.last.toLink, ['new-route']);
  });
}
```

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/route_link_sheet_test.dart`
Expected: FAIL to compile, `route_link_sheet.dart` not found.

- [ ] **Step 7: Implement the sheet**

Create `lib/features/dive_log/presentation/widgets/edit_sections/route_link_sheet.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_proximity.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the Dive Edit page's route sheet (spec
/// 2026-10-02-underwater-route-entry-points-design.md, section 1). Every
/// change is reported through [onChanged] as a new draft; nothing is
/// written to the database here except a route the diver imports, which
/// the review page saves unlinked.
///
/// [entryTime] is the form's current entry time, which orders the link
/// candidates. [site] pre-fills an imported route's site.
Future<void> showRouteLinkSheet(
  BuildContext context, {
  required DiveRouteLinkDraft draft,
  required DateTime entryTime,
  DiveSite? site,
  required ValueChanged<DiveRouteLinkDraft> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RouteLinkSheet(
      draft: draft,
      entryTime: entryTime,
      site: site,
      onChanged: onChanged,
    ),
  );
}

class _RouteLinkSheet extends ConsumerStatefulWidget {
  const _RouteLinkSheet({
    required this.draft,
    required this.entryTime,
    required this.site,
    required this.onChanged,
  });

  final DiveRouteLinkDraft draft;
  final DateTime entryTime;
  final DiveSite? site;
  final ValueChanged<DiveRouteLinkDraft> onChanged;

  @override
  ConsumerState<_RouteLinkSheet> createState() => _RouteLinkSheetState();
}

class _RouteLinkSheetState extends ConsumerState<_RouteLinkSheet> {
  static final _log = LoggerService.forClass(_RouteLinkSheet);
  late DiveRouteLinkDraft _draft = widget.draft;

  void _update(DiveRouteLinkDraft next) {
    setState(() => _draft = next);
    widget.onChanged(next);
  }

  /// Unlinked routes, plus originals the diver removed (still linked until
  /// Save), minus anything already in the draft, nearest the entry first.
  List<NavTrack> _candidates(List<NavTrack> unlinked) {
    final byId = {
      for (final route in [...unlinked, ..._draft.removed]) route.id: route,
    };
    return sortByProximityTo(
      byId.values.where((route) => !_draft.contains(route.id)),
      widget.entryTime,
    );
  }

  Future<void> _link(List<NavTrack> candidates) async {
    final chosen = await showModalBottomSheet<NavTrack>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final route in candidates)
            ListTile(
              key: ValueKey('route-sheet-candidate-${route.id}'),
              title: Text(route.displayName),
              onTap: () => Navigator.of(context).pop(route),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    _update(_draft.add(chosen));
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final NavTrackImportPreview preview;
    try {
      preview = await ref
          .read(navTrackImportServiceProvider)
          .prepare(bytes, fileName: file.name);
    } on NavTrackParseException catch (e) {
      _log.warning('Route import rejected: ${e.message}');
      messenger.showSnackBar(
        SnackBar(content: Text(navTrackParseErrorText(l10n, e))),
      );
      return;
    } catch (e, stackTrace) {
      _log.error('Route import failed', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.navTrack_list_importFailed(e.toString()))),
      );
      return;
    }
    if (!mounted) return;

    final result = await navigateToNavTrackReviewForResult(
      context,
      bytes,
      fileName: file.name,
      preview: preview,
      initialSite: widget.site,
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(navTrackRepositoryProvider)
        .getById(result.routeId, includePoints: false);
    if (saved == null || !mounted) return;
    final replaced = result.replacedRouteId;
    _update(
      replaced == null ? _draft.add(saved) : _draft.replaced(replaced, saved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final unlinked = ref.watch(unlinkedNavTracksProvider).value ?? const [];
    final candidates = _candidates(unlinked);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.navTrack_section_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_draft.current.isEmpty)
              Text(l10n.navTrack_section_noRouteLinked),
            for (final route in _draft.current)
              ListTile(
                key: ValueKey('route-sheet-row-${route.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.route),
                title: Text(route.displayName),
                subtitle: Text(
                  [
                    if (route.totalDistance != null)
                      units.formatDistance(route.totalDistance!),
                    // Only a route linked when the form opened can be this
                    // dive's primary yet; link() decides the rest on Save.
                    if (route.isPrimary && _draft.wasLinkedOnOpen(route.id))
                      l10n.navTrack_section_primaryTag,
                  ].join(' · '),
                ),
                trailing: IconButton(
                  key: ValueKey('route-sheet-remove-${route.id}'),
                  tooltip: l10n.navTrack_editSheet_removeTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => _update(_draft.remove(route.id)),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (candidates.isNotEmpty)
                  OutlinedButton(
                    key: const ValueKey('route-sheet-link-button'),
                    onPressed: () => _link(candidates),
                    child: Text(l10n.navTrack_section_linkButton),
                  ),
                OutlinedButton(
                  key: const ValueKey('route-sheet-import-button'),
                  onPressed: _import,
                  child: Text(l10n.navTrack_section_importButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

`NavTrackImportPreview` comes from `nav_track_import_service.dart` and `NavTrackParseException` from `parsed_nav_track.dart`, the same two imports `nav_track_section.dart` uses today.

- [ ] **Step 8: Run both test files**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/route_row_test.dart test/features/dive_log/presentation/widgets/edit_sections/route_link_sheet_test.dart`
Expected: PASS (5 + 9 tests).

- [ ] **Step 9: Run the architecture guards**

Run: `flutter test test/architecture/`
Expected: PASS. If the ListTile-trailing guard (#2719) flags the sheet's `IconButton`, follow that guard's message (it names the allowed widget) rather than suppressing it.

- [ ] **Step 10: Commit**

```bash
dart format lib/features/dive_log/presentation/widgets/edit_sections test/features/dive_log/presentation/widgets/edit_sections
git add lib/features/dive_log/presentation/widgets/edit_sections/route_row.dart lib/features/dive_log/presentation/widgets/edit_sections/route_link_sheet.dart test/features/dive_log/presentation/widgets/edit_sections/route_row_test.dart test/features/dive_log/presentation/widgets/edit_sections/route_link_sheet_test.dart
git commit -m "feat(dive-log): add the dive edit underwater route row and its link sheet"
```

---

### Task 6: Wire the Route row into Dive Edit and save its links

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart` (constructor, fields, `build` children after `?siteExtras`)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state field near line 318, `initState` near 520-570, `_loadExistingDive`'s `Future.wait` at line 978, a new `_loadRouteLinks` next to `_loadBuddies` at line 1022, `_buildTheDiveSection` at 2376, `_saveDive` after the "Save buddies" block near 5916)
- Test: `test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart`
- Test: `test/features/dive_log/presentation/pages/dive_edit_route_links_test.dart` (create)

**Interfaces:**
- Consumes: `RouteRow`, `showRouteLinkSheet` (Task 5), `DiveRouteLinkDraft` (Task 2), `applyDiveRouteLinkDraft` (Task 2), `navTracksForDiveProvider`, `navTrackRepositoryProvider`, `navTrack_editRow_saveFailed` (Task 3).
- Produces: `TheDiveSection({..., Widget? routeRow})`, rendered directly after `siteExtras`.

- [ ] **Step 1: Write the failing section test**

Append inside `main()` of `test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart`:

```dart
  testWidgets('renders the route row after the site and its extras', (
    tester,
  ) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    for (final c in controllers) {
      addTearDown(c.dispose);
    }
    await tester.pumpWidget(
      _wrap(
        TheDiveSection(
          depthSymbol: 'm',
          nameController: controllers[0],
          maxDepthController: controllers[1],
          avgDepthController: controllers[2],
          bottomTimeController: controllers[3],
          runtimeController: controllers[4],
          diveNumberController: controllers[5],
          entryText: 'ENTRY_TS',
          onEditEntry: () {},
          exitText: null,
          onEditExit: () {},
          siteName: 'Blue Hole',
          onPickSite: () {},
          siteExtras: const Text('SITE_EXTRAS'),
          routeRow: const Text('ROUTE_ROW'),
        ),
      ),
    );

    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(find.text('Blue Hole')), lessThan(top(find.text('ROUTE_ROW'))));
    expect(
      top(find.text('SITE_EXTRAS')),
      lessThan(top(find.text('ROUTE_ROW'))),
    );
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart`
Expected: FAIL to compile, no named parameter `routeRow`.

- [ ] **Step 3: Add the slot**

In `the_dive_section.dart`: add `this.routeRow,` to the constructor after `this.siteExtras,`; add the field after `final Widget? siteExtras;`:

```dart
  /// The underwater route row; null hides it (planned dives).
  final Widget? routeRow;
```

In `build`, change `?siteExtras,` to:

```dart
        ?siteExtras,
        ?routeRow,
```

Update the class doc comment's row list to read "... site, then site extras, the underwater route, dive types and the profile block."

- [ ] **Step 4: Run the section tests**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing edit-page tests**

Create `test/features/dive_log/presentation/pages/dive_edit_route_links_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/nav_track_fixtures.dart';
import '../../../../helpers/test_database.dart';

/// The Dive Edit page stages underwater route links and writes them only on
/// Save (spec 2026-10-02-underwater-route-entry-points-design.md, section
/// 1). Driven against a real database so the assertions are on stored rows.
void main() {
  late DiveRepository dives;
  late NavTrackRepository routes;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    routes = NavTrackRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final routeRow = find.byKey(const ValueKey('dive-edit-route-row'));
  final plannedSwitch = find.byKey(const Key('dive_edit_planned_switch'));

  Future<String> insertRoute({String? diveId}) =>
      routes.insertImportedRoute(
        points: kTestNavTrackPoints,
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'wreck.csv',
        name: 'Wreck tour',
        diveId: diveId,
      );

  Future<Dive> insertDive({bool isPlanned = false}) => dives.createDive(
    Dive(
      id: 'dive-route',
      dateTime: DateTime.utc(2025, 8, 22, 10),
      maxDepth: 20.0,
      isPlanned: isPlanned,
    ),
  );

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? diveId,
    List<String>? bulkDiveIds,
    VoidCallback? onCancel,
  }) async {
    tester.platformDispatcher.localesTestValue = const [
      Locale('fr'),
      Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(dives),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(dives, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              bulkDiveIds: bulkDiveIds,
              embedded: true,
              onCancel: onCancel,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  // Bounded pumps: the new-dive path starts a GPS capture and the save path
  // shows a snackbar, so pumpAndSettle never returns (see
  // dive_edit_planned_switch_test.dart).
  Future<void> pumpSteps(WidgetTester tester, [int steps = 20]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> linkWreckTour(WidgetTester tester) async {
    await tester.ensureVisible(routeRow);
    await tester.tap(routeRow);
    await pumpSteps(tester);
    await tester.tap(find.byKey(const ValueKey('route-sheet-link-button')));
    await pumpSteps(tester);
    await tester.tap(find.text('Wreck tour').last);
    await pumpSteps(tester);
    // Close the route sheet by tapping its barrier.
    await tester.tapAt(const Offset(5, 5));
    await pumpSteps(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await pumpSteps(tester, 40);
  }

  testWidgets('linking in the sheet writes nothing until Save, then links', (
    tester,
  ) async {
    final dive = await insertDive();
    final routeId = await insertRoute();
    await pumpEditor(tester, diveId: dive.id);

    await linkWreckTour(tester);
    expect(find.text('Wreck tour'), findsOneWidget);
    expect(await routes.getForDive(dive.id), isEmpty);

    await save(tester);

    final linked = await routes.getForDive(dive.id);
    expect(linked.map((r) => r.id), [routeId]);
    expect(linked.single.linkMode, NavTrackLinkMode.manual);
  });

  testWidgets('removing a linked route unlinks it on Save', (tester) async {
    final dive = await insertDive();
    final routeId = await insertRoute(diveId: dive.id);
    await pumpEditor(tester, diveId: dive.id);
    expect(find.text('Wreck tour'), findsOneWidget);

    await tester.ensureVisible(routeRow);
    await tester.tap(routeRow);
    await pumpSteps(tester);
    await tester.tap(find.byKey(ValueKey('route-sheet-remove-$routeId')));
    await pumpSteps(tester);
    await tester.tapAt(const Offset(5, 5));
    await pumpSteps(tester);
    await save(tester);

    expect(await routes.getForDive(dive.id), isEmpty);
  });

  testWidgets('a new dive gets its staged route once it has an id', (
    tester,
  ) async {
    final routeId = await insertRoute();
    await pumpEditor(tester);

    await linkWreckTour(tester);
    await save(tester);

    final saved = (await dives.getAllDives()).single;
    expect((await routes.getForDive(saved.id)).map((r) => r.id), [routeId]);
  });

  testWidgets('a staged link marks the form unsaved', (tester) async {
    final dive = await insertDive();
    await insertRoute();
    var cancelled = 0;
    await pumpEditor(tester, diveId: dive.id, onCancel: () => cancelled++);

    await linkWreckTour(tester);
    await tester.tap(find.text('Cancel'));
    await pumpSteps(tester);

    // The discard guard asks first instead of cancelling straight away.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(cancelled, 0);
  });

  testWidgets('a planned dive has no route row', (tester) async {
    final dive = await insertDive(isPlanned: true);
    await pumpEditor(tester, diveId: dive.id);

    expect(routeRow, findsNothing);
  });

  testWidgets('switching to planned after linking saves no link', (
    tester,
  ) async {
    final routeId = await insertRoute();
    await pumpEditor(tester);

    await linkWreckTour(tester);
    await tester.ensureVisible(plannedSwitch);
    await tester.tap(plannedSwitch);
    await pumpSteps(tester);
    expect(routeRow, findsNothing);
    await save(tester);

    final route = await routes.getById(routeId, includePoints: false);
    expect(route!.diveId, isNull);
  });

  testWidgets('bulk edit has no route row', (tester) async {
    final first = await insertDive();
    final second = await dives.createDive(
      Dive(id: 'dive-route-2', dateTime: DateTime.utc(2025, 8, 23, 10)),
    );
    await pumpEditor(tester, bulkDiveIds: [first.id, second.id]);

    expect(routeRow, findsNothing);
  });
}
```

Define `settle` at the top of `main()` too (used by `pumpEditor`):

```dart
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
```

- [ ] **Step 6: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_route_links_test.dart`
Expected: FAIL: `dive-edit-route-row` not found (the row is not wired yet). The planned and bulk tests may already pass; that is expected.

- [ ] **Step 7: Wire the edit page**

In `dive_edit_page.dart`:

(a) Add imports in the package group, keeping alphabetical order with their neighbours:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_link_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_row.dart';
import 'package:submersion/features/nav_track/application/dive_route_link_applier.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
```

(b) After `List<BuddyWithRole> _selectedBuddies = [];` (line 318) add:

```dart
  /// The dive's staged underwater route links, applied on Save. Null until
  /// an existing dive's current links have loaded, so the row stays inert
  /// and a Save can never read "not loaded" as "every route removed".
  DiveRouteLinkDraft? _routeDraft;
```

(c) In `initState`, the chain is `if (widget.isBulk) { ... } else if (widget.isEditing) { ... } else { /* new dive */ ... }`. Inside the final `else` (the new-dive branch, which starts with `// For new dives, capture GPS in the background ...`), add as its first statement:

```dart
      // A new dive has no links yet, so its draft is ready immediately.
      _routeDraft = DiveRouteLinkDraft.initial(const []);
```

(d) In `_loadExistingDive`, change `await Future.wait([_loadSightings(), _loadBuddies()]);` to:

```dart
        await Future.wait([_loadSightings(), _loadBuddies(), _loadRouteLinks()]);
```

(e) Directly after the `_loadBuddies` method add:

```dart
  Future<void> _loadRouteLinks() async {
    final diveId = widget.diveId;
    if (diveId == null) return;
    final linked = await ref.read(navTracksForDiveProvider(diveId).future);
    if (mounted) {
      setState(() => _routeDraft = DiveRouteLinkDraft.initial(linked));
    }
  }

  Future<void> _openRouteSheet() async {
    final draft = _routeDraft;
    if (draft == null) return;
    await showRouteLinkSheet(
      context,
      draft: draft,
      entryTime: _currentEntryTime(),
      site: _selectedSite,
      onChanged: (next) {
        setState(() => _routeDraft = next);
        _markDirty();
      },
    );
  }
```

(f) In `_buildTheDiveSection`, add a named argument to the `TheDiveSection(...)` call, after `onClearSite: ...`:

```dart
      // A planned dive has no recording to link (spec 2026-10-02, section 1).
      routeRow: _isPlanned
          ? null
          : RouteRow(draft: _routeDraft, onTap: _openRouteSheet),
```

(g) In `_saveDive`, directly after the closing brace of the "Save buddies" `if (savedDiveId != null) { ... }` block, add:

```dart
      // Apply the staged underwater route links. A planned dive has no
      // recording, so a draft left from before the switch was turned on is
      // dropped. A failure is reported but never undoes the dive save.
      final routeDraft = _routeDraft;
      if (savedDiveId != null &&
          !_isPlanned &&
          routeDraft != null &&
          routeDraft.hasChanges) {
        try {
          final skipped = await applyDiveRouteLinkDraft(
            ref.read(navTrackRepositoryProvider),
            diveId: savedDiveId,
            draft: routeDraft,
          );
          if (skipped.isNotEmpty) {
            _log.warning('Routes already linked elsewhere, left as is: $skipped');
          }
        } catch (e, stackTrace) {
          _log.error(
            'Failed to apply route links for dive $savedDiveId',
            error: e,
            stackTrace: stackTrace,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.navTrack_editRow_saveFailed(e.toString()),
                ),
              ),
            );
          }
        }
        ref.invalidate(navTracksForDiveProvider(savedDiveId));
      }
```

If `context.l10n` is not imported in this file, it already uses `context.l10n` elsewhere; no new import is needed. If `_log.warning` has a different signature, match the call in `nav_track_section.dart` (`log.warning('...')`).

- [ ] **Step 8: Run the edit-page tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_route_links_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 9: Run the existing dive edit tests for regressions**

Run: `flutter test test/features/dive_log/presentation/pages/ test/features/dive_log/presentation/widgets/edit_sections/`
Expected: PASS. A test that counts FormRows in The Dive group, or asserts on the row right after Site, may need its expectation updated to include the new row; update only such an expectation, and say so in the commit body.

- [ ] **Step 10: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart test/features/dive_log/presentation/pages/dive_edit_route_links_test.dart
git commit -m "feat(dive-log): link and import underwater routes from the dive edit page"
```

---

### Task 7: Show the Dive Details card only when a route is linked

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:507-512`
- Modify: `lib/features/nav_track/presentation/widgets/nav_track_section.dart`
- Modify: `test/features/nav_track/presentation/widgets/nav_track_section_test.dart`
- Test: `test/features/dive_log/presentation/pages/dive_nav_track_section_visibility_test.dart` (create)

**Interfaces:**
- Consumes: `navTracksForDiveProvider`.
- Produces: `NavTrackSection` keeps its constructor `NavTrackSection({required Dive dive})`; it no longer has an empty state, a link picker, or an import button.

- [ ] **Step 1: Write the failing visibility tests**

Create `test/features/dive_log/presentation/pages/dive_nav_track_section_visibility_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/nav_track_fixtures.dart';

final _dive = Dive(
  id: 'nav-vis',
  diveNumber: 1,
  dateTime: DateTime(2025, 8, 22, 10),
  maxDepth: 20.0,
);

/// [routes] is read on every build of the overridden provider, so a test
/// can change it and invalidate the provider to simulate an unlink.
Future<void> _pump(
  WidgetTester tester,
  Future<List<NavTrack>> Function() routes,
) async {
  final overrides = await getBaseOverrides();
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveProvider(_dive.id).overrideWith((ref) async => _dive),
        diveDataSourcesProvider(_dive.id).overrideWith((ref) async => const []),
        navTracksForDiveProvider(_dive.id).overrideWith((ref) => routes()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: _dive.id, embedded: true),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
}

void main() {
  testWidgets('no Underwater Route card when no route is linked', (
    tester,
  ) async {
    await _pump(tester, () async => const []);
    expect(find.text('Underwater Route'), findsNothing);
    expect(find.text('No route linked'), findsNothing);
  });

  testWidgets('no card while the dive\'s routes are still loading', (
    tester,
  ) async {
    final never = Completer<List<NavTrack>>();
    await _pump(tester, () => never.future);
    expect(find.text('Underwater Route'), findsNothing);
  });

  testWidgets('shows the card once a route is linked, and hides it again '
      'when the last route goes', (tester) async {
    var linked = [testNavTrack('r1', diveId: _dive.id)];
    await _pump(tester, () async => linked);
    expect(find.text('Underwater Route'), findsOneWidget);

    linked = const [];
    ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).invalidate(navTracksForDiveProvider(_dive.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Underwater Route'), findsNothing);
  });
}
```

If the "Underwater Route" title sits below the first screen of the detail page, set `tester.view.physicalSize = const Size(950, 8000); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset);` at the top of `_pump`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/pages/dive_nav_track_section_visibility_test.dart`
Expected: the first two tests FAIL (the card renders its empty state today); the third passes its first expectation.

- [ ] **Step 3: Hide the card without routes**

In `dive_detail_page.dart`, add `import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';` next to the existing `nav_track_section.dart` import, and replace:

```dart
      DiveDetailSectionId.navTrack: (_) {
        // Unlike surfaceGps this section always renders: an empty state
        // ("No route linked", with "Link route"/"Import file") is itself
        // useful, whereas the GPS section has nothing to show without a fix.
        return [NavTrackSection(dive: dive)];
      },
```

with:

```dart
      DiveDetailSectionId.navTrack: (_) {
        // Like surfaceGps, only when there is something to show: routes are
        // linked and imported from the Dive Edit page (spec 2026-10-02,
        // section 3). Nothing while loading, so no empty card flashes.
        final routes = ref.watch(navTracksForDiveProvider(dive.id)).value;
        if (routes == null || routes.isEmpty) return [];
        return [NavTrackSection(dive: dive)];
      },
```

- [ ] **Step 4: Slim `NavTrackSection`**

In `nav_track_section.dart`:
- Delete `_linkRoute` and `_importFile`.
- Delete the now-unused imports: `file_picker`, `logger_service.dart`, `nav_track_import_service.dart`, `parsed_nav_track.dart`, `nav_track_parse_error_text.dart`, `nav_track_import_review_page.dart`, `nav_track_import_flow_providers.dart`.
- In `build`, delete `final unlinkedAsync = ref.watch(unlinkedNavTracksProvider);` and replace the subtitle and the whole `contentBuilder` with:

```dart
    return CollapsibleCardSection(
      title: l10n.navTrack_section_title,
      icon: Icons.route,
      collapsedSubtitle: l10n.navTrack_section_routeCount(routes.length),
      isExpanded: isExpanded,
      onToggle: (expanded) =>
          ref.read(navTrackSectionExpandedProvider.notifier).state = expanded,
      contentBuilder: (context) {
        if (!isExpanded || routes.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              for (final route in routes) _RouteRow(route: route),
            ],
          ),
        );
      },
    );
```

- Replace the class doc comment with:

```dart
/// The dive detail "Underwater Route" section (spec
/// 2026-09-10-underwater-nav-track-design.md, "Dive detail section"): the
/// routes linked to this dive. The detail page only shows it when at least
/// one route is linked; linking and importing happen on the Dive Edit page
/// (spec 2026-10-02-underwater-route-entry-points-design.md).
```

- [ ] **Step 5: Update the section's own tests**

In `test/features/nav_track/presentation/widgets/nav_track_section_test.dart`, delete these five tests (their behaviour moved to the edit sheet, covered in Task 5):
- `'empty state offers Link route and Import file'`
- `'importing from a dive\'s section pre-selects that dive on the review page, even when the recording overlaps no dive (issue #2691)'`
- `'empty state hides Link route when nothing is unlinked'`
- `'tapping "Link route" and choosing one links it to the dive'`
- `'importing a file opens the review page with the preview it already parsed and this dive pre-selected'`

Then delete what only those used: the `_PreparedImportService` class, the `unlinkedRoutes` parameter of `_pump` and its `unlinkedNavTracksProvider` override, the `linkedRouteId`/`linkedDiveId`/`linkMode` fields and the `link` override of `_RecordingNavTrackRepository`, and any import the analyzer then reports unused (`dart:typed_data`, `mock_file_picker_platform.dart`, the import-service, parser, segmenter, stats, point, review page and import-flow imports).

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_nav_track_section_visibility_test.dart test/features/nav_track/presentation/widgets/nav_track_section_test.dart test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart`
Expected: PASS.

Run: `flutter analyze lib/features/nav_track lib/features/dive_log test/features/nav_track test/features/dive_log`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
dart format lib/features test/features
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/nav_track/presentation/widgets/nav_track_section.dart test/features/nav_track/presentation/widgets/nav_track_section_test.dart test/features/dive_log/presentation/pages/dive_nav_track_section_visibility_test.dart
git commit -m "feat(dive-log): show the underwater route card only when a route is linked"
```

---

### Task 8: Settings > Manage tile, router transition, quick action removal

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (`_ManageSectionContent`, after the Incidents tile near line 2550)
- Modify: `lib/core/router/app_router.dart:1052-1064`
- Modify: `lib/features/dashboard/presentation/widgets/quick_actions_card.dart:78-87`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (delete one key) and regenerate
- Test: `test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart` (create)
- Test: `test/features/dashboard/presentation/quick_actions_card_test.dart`

**Interfaces:**
- Consumes: `settings_manage_navRoutes_subtitle` (Task 3), existing `navTrack_list_title`.
- Produces: Manage tile with key `ValueKey('settings-manage-nav-routes')` pushing `/nav-routes`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('Manage lists Underwater Routes and opens the routes area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const SettingsSectionDetailPage(sectionId: 'manage'),
        ),
        GoRoute(
          path: '/nav-routes',
          builder: (context, state) =>
              const Scaffold(body: Text('NAV-ROUTES-PAGE')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('settings-manage-nav-routes'));
    await tester.scrollUntilVisible(
      tile,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Underwater Routes')),
      findsOneWidget,
    );
    expect(find.text('Import, align and link recorded routes'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('NAV-ROUTES-PAGE'), findsOneWidget);
  });
}
```

In `test/features/dashboard/presentation/quick_actions_card_test.dart`, add inside `main()`:

```dart
  testWidgets('offers no Underwater Routes quick action', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Underwater Routes'), findsNothing);
    expect(find.byIcon(Icons.route), findsNothing);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart test/features/dashboard/presentation/quick_actions_card_test.dart`
Expected: FAIL (tile not found; the quick action is still present).

- [ ] **Step 3: Add the Manage tile**

In `settings_page.dart`, in `_ManageSectionContent`, directly after the Incidents `ListTile` (the one with `onTap: () => context.push('/incidents')`), add:

```dart
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('settings-manage-nav-routes'),
                  leading: const Icon(Icons.route),
                  title: Text(context.l10n.navTrack_list_title),
                  subtitle: Text(
                    context.l10n.settings_manage_navRoutes_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/nav-routes'),
                ),
```

- [ ] **Step 4: Use the normal page transition**

In `app_router.dart`, replace:

```dart
          // Underwater navigation routes (spec
          // 2026-09-10-underwater-nav-track-design.md, "The routes area"):
          // siblings of /gps-log for the same reason -- pushing a route from
          // the dive detail's "Underwater Route" section must not stack a
          // list page underneath it.
          GoRoute(
            path: '/nav-routes',
            name: 'navRoutes',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const NavTrackListPage(),
            ),
          ),
```

with:

```dart
          // Underwater navigation routes (spec
          // 2026-09-10-underwater-nav-track-design.md, "The routes area"):
          // siblings of /gps-log so that pushing a route from the dive
          // detail's "Underwater Route" section does not stack a list page
          // underneath it. Opened from Settings > Manage, so it slides in
          // like the other Manage pages.
          GoRoute(
            path: '/nav-routes',
            name: 'navRoutes',
            builder: (context, state) => const NavTrackListPage(),
          ),
```

- [ ] **Step 5: Remove the quick action**

In `quick_actions_card.dart`, delete this block (the `SizedBox` spacer before it stays, since the emergency button still follows):

```dart
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/nav-routes'),
                icon: const Icon(Icons.route),
                label: Text(context.l10n.dashboard_quickActions_navRoutes),
              ),
            ),
            const SizedBox(height: 8),
```

- [ ] **Step 6: Delete the orphaned string**

Delete the `"dashboard_quickActions_navRoutes": ...` line from all 11 `lib/l10n/arb/app_*.arb` files (no `@` entry exists for it; check with `grep -n "dashboard_quickActions_navRoutes" lib/l10n/arb/app_en.arb`). Then:

Run: `flutter gen-l10n`
Run: `grep -rn "dashboard_quickActions_navRoutes" lib test`
Expected: no output.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart test/features/dashboard/ test/features/settings/presentation/pages/settings_page_test.dart test/features/nav_track/presentation/pages/nav_track_list_page_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib/features/settings/presentation/pages/settings_page.dart lib/core/router/app_router.dart lib/features/dashboard/presentation/widgets/quick_actions_card.dart lib/l10n/arb test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart test/features/dashboard/presentation/quick_actions_card_test.dart
git commit -m "feat(settings): open underwater routes from Settings > Manage instead of the dashboard"
```

---

### Task 9: Whole-branch verification, screenshots, PR

**Files:** none new (fixes only if a check fails).

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && git status --short`
Expected: no files listed (everything already formatted and committed). If files are listed, commit them as `style: format`.

Run: `flutter analyze`
Expected: No issues found (infos count as failures in CI).

- [ ] **Step 2: Architecture guards and the touched areas**

Run: `flutter test test/architecture/`
Expected: PASS.

Run: `flutter test test/features/nav_track test/features/dive_log test/features/settings test/features/dashboard test/l10n`
Expected: PASS. Report the pass and fail counts.

- [ ] **Step 3: Check for stray em-dashes and attribution in new text**

Run: `git diff main...HEAD | grep -n "$(printf '\342\200\224')" ; git log main..HEAD --format=%B | grep -in "claude\|anthropic\|co-authored"`
Expected: no output from either.

- [ ] **Step 4: Capture "after" screenshots**

Using the `run` skill, launch the macOS app from this worktree and save to the scratchpad, matching Task 0's names with an `after-` prefix: dashboard (no Underwater Routes button), dive detail of a dive with no linked route (no card) and one with a linked route (card shown), dive edit The Dive group (Underwater Route row under Site) plus the open route sheet, and Settings > Manage (Underwater Routes tile). Desktop width for all; phone width (about 390 pt) for dive detail, dive edit and the sheet.

- [ ] **Step 5: Ask before pushing**

Show the maintainer the commit list (`git log --oneline main..HEAD`) and the screenshot paths, and ask whether to push and open the PR. Do not push until they say yes.

- [ ] **Step 6: Open the PR (after approval)**

Push the branch, then open the PR with `gh pr create` using the repository's PR template. Title: `feat(nav-track): link underwater routes from dive edit, reach routes from Settings > Manage`. The description's issue section contains:

```text
Closes #2796, closes #2396, closes #2397
Refs #2398
```

(Written as plain text in the PR body, not inside a code block, so GitHub and the PR Issue Link check see it.) The Screenshots section lists each before/after image by name; the maintainer drags the files in on github.com. No attribution lines.
