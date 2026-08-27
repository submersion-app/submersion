# Multi-Source Attribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ambiguous multi-computer overlay on the dive detail page with an active-source model: one data source drives every chart line and page card (always labeled), other sources overlay color-coded, with set-primary / unlink / split management per source.

**Architecture:** Attribution is re-keyed from raw `computerId` map keys to `dive_data_sources` row IDs, with one shared name resolver. A session-only active-source provider drives the chart profile, per-source analysis, stat chips, and deco/tissue cards. The chart gains an `overlays` prop (dashed color-coded renditions of enabled metrics) and loses the old `computerProfiles` branching. A new `DiveSplitService` inverts `DiveConsolidationService`.

**Tech Stack:** Flutter 3.x, Riverpod, Drift (SQLite), fl_chart.

**Spec:** `docs/superpowers/specs/2026-07-04-multi-source-attribution-design.md`

## Global Constraints

- Work in the worktree at `.claude/worktrees/multi-source-attribution` (branch `worktree-multi-source-attribution`). All paths below are relative to the worktree root. Never touch the main checkout.
- Run `dart format .` (whole repo) after each task, before committing.
- After the final task run `flutter analyze` on the whole project (never pipe through `tail` for the pass/fail decision).
- Run specific test files, not broad directories (Bash timeouts).
- Database tests must run with foreign keys ON (`PRAGMA foreign_keys = ON`) where the schema allows; the split-service tests explicitly assert FK integrity.
- No emojis anywhere. No hardcoded user-facing strings: every new string goes through l10n and must be translated into all 10 non-en locales (Task 9).
- Anything displaying units must use `UnitFormatter` from active settings.
- Do not use bare `git stash` (shared stash stack across worktrees).
- Commit after each task (plan-approved execution pre-authorizes these commits). No Co-Authored-By lines.

---

### Task 1: Shared source-name resolver

**Files:**
- Create: `lib/features/dive_log/domain/services/source_name_resolver.dart`
- Modify: `lib/features/dive_log/domain/services/field_attribution_service.dart`
- Test: `test/features/dive_log/domain/services/source_name_resolver_test.dart`

**Interfaces:**
- Consumes: `DiveDataSource` (`lib/features/dive_log/domain/entities/dive_data_source.dart`) — fields `computerName`, `computerModel`, `computerSerial`, `sourceFormat`, `sourceFileName`, `isPrimary`.
- Produces:
  - `class SourceNameLabels { const SourceNameLabels({required this.unknownComputer, required this.manualEntry, required this.importedFile, required this.editedSuffix}); final String unknownComputer; final String manualEntry; final String importedFile; final String editedSuffix; }`
  - `String resolveSourceName(DiveDataSource source, SourceNameLabels labels, {bool edited = false})`
  - `FieldAttributionService.computeAttribution(List<DiveDataSource> sources, {String? viewedSourceId, required String Function(DiveDataSource) nameOf})`

Later tasks build `SourceNameLabels` from l10n in widgets and pass `nameOf: (s) => resolveSourceName(s, labels)`. This is the ONLY name path; `DiveDataSource.displayName` and `computerLabel` get `@Deprecated` markers here and are deleted in Task 10.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/domain/services/source_name_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';

DiveDataSource _source({
  String? computerName,
  String? computerModel,
  String? computerSerial,
  String? computerId,
  String? sourceFormat,
  String? sourceFileName,
}) {
  return DiveDataSource(
    id: 'src-1',
    diveId: 'dive-1',
    computerId: computerId,
    isPrimary: true,
    computerName: computerName,
    computerModel: computerModel,
    computerSerial: computerSerial,
    sourceFormat: sourceFormat,
    sourceFileName: sourceFileName,
    importedAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

const labels = SourceNameLabels(
  unknownComputer: 'Unknown Computer',
  manualEntry: 'Manual Entry',
  importedFile: 'Imported File',
  editedSuffix: '(edited)',
);

void main() {
  test('prefers friendly name over model and serial', () {
    final s = _source(
      computerName: 'Kiyans Teric',
      computerModel: 'Teric',
      computerSerial: '1234',
      computerId: 'dc-1',
    );
    expect(resolveSourceName(s, labels), 'Kiyans Teric');
  });

  test('falls back name -> model -> serial', () {
    expect(
      resolveSourceName(
        _source(computerModel: 'Teric', computerSerial: '1234',
            computerId: 'dc-1'),
        labels,
      ),
      'Teric',
    );
    expect(
      resolveSourceName(_source(computerSerial: '1234', computerId: 'dc-1'),
          labels),
      '1234',
    );
  });

  test('computer-less manual source resolves to Manual Entry', () {
    expect(resolveSourceName(_source(sourceFormat: 'manual'), labels),
        'Manual Entry');
  });

  test('computer-less file import resolves to Imported File', () {
    expect(
      resolveSourceName(_source(sourceFileName: 'log.uddf'), labels),
      'Imported File',
    );
  });

  test('download with no identifying data resolves to Unknown Computer', () {
    expect(resolveSourceName(_source(computerId: 'dc-1'), labels),
        'Unknown Computer');
  });

  test('edited variant appends suffix', () {
    final s = _source(computerName: 'Kiyans Teric', computerId: 'dc-1');
    expect(resolveSourceName(s, labels, edited: true),
        'Kiyans Teric (edited)');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/source_name_resolver_test.dart`
Expected: FAIL — `source_name_resolver.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dive_log/domain/services/source_name_resolver.dart
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

/// Localized fallback labels for [resolveSourceName]. Built from l10n at the
/// widget layer so the resolver stays a pure domain function.
class SourceNameLabels {
  const SourceNameLabels({
    required this.unknownComputer,
    required this.manualEntry,
    required this.importedFile,
    required this.editedSuffix,
  });

  final String unknownComputer;
  final String manualEntry;
  final String importedFile;
  final String editedSuffix;
}

/// The single name-resolution path for a dive data source, shared by the
/// stat chips, chart legend, sources bar, and data sources section:
/// friendly name -> model -> serial -> source-type label, with
/// "Unknown Computer" reserved for downloads carrying no identifying data.
String resolveSourceName(
  DiveDataSource source,
  SourceNameLabels labels, {
  bool edited = false,
}) {
  final base =
      source.computerName ??
      source.computerModel ??
      source.computerSerial ??
      _typeLabel(source, labels);
  return edited ? '$base ${labels.editedSuffix}' : base;
}

String _typeLabel(DiveDataSource source, SourceNameLabels labels) {
  if (source.computerId != null) return labels.unknownComputer;
  if (source.sourceFileName != null || source.sourceFileFormat != null) {
    return labels.importedFile;
  }
  return labels.manualEntry;
}
```

In `field_attribution_service.dart`, change the signature and replace every `activeSource.displayName` / `hrSource.displayName` with `nameOf(activeSource)` / `nameOf(hrSource)`:

```dart
static Map<String, String> computeAttribution(
  List<DiveDataSource> sources, {
  String? viewedSourceId,
  required String Function(DiveDataSource) nameOf,
}) {
```

Update the existing callers of `computeAttribution` (find them with `grep -rn "computeAttribution" lib test`) to pass `nameOf: (s) => resolveSourceName(s, labels)` where `labels` is built from l10n (temporary literals are NOT allowed; use the existing `context.l10n.diveLog_sources_unknownComputer` plus the three new l10n keys added in this task for en only — full locale sweep happens in Task 9):

New en l10n keys (add to `lib/l10n/arb/app_en.arb`, then run `flutter gen-l10n` or the project's codegen):
- `diveLog_sources_manualEntry`: "Manual Entry"
- `diveLog_sources_importedFile`: "Imported File"
- `diveLog_sources_editedSuffix`: "(edited)"

Add `@Deprecated('Use resolveSourceName')` to `DiveDataSource.displayName` and `computerLabel`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/source_name_resolver_test.dart`
Expected: PASS. Also run the existing attribution tests: `flutter test test/features/dive_log/domain/services/field_attribution_service_test.dart` (update them for the new `nameOf` parameter if they exist).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: shared source name resolver with source-type fallbacks"
```

---

### Task 2: Repository — profiles keyed by data-source ID

**Files:**
- Create: `lib/features/dive_log/domain/entities/source_profile.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (near `getProfilesBySource`, line ~499)
- Test: `test/features/dive_log/data/repositories/profiles_by_data_source_test.dart`

**Interfaces:**
- Consumes: existing `getProfilesBySource` keying rules (`dive_repository_impl.dart:499-561`), `DiveDataSource`, Drift tables `diveProfiles`, `diveDataSources`.
- Produces:
  - `class SourceProfile { const SourceProfile({required this.sourceId, required this.computerId, required this.isEdited, required this.points}); final String sourceId; final String? computerId; final bool isEdited; final List<DiveProfilePoint> points; }`
  - `Future<Map<String, SourceProfile>> getProfilesByDataSource(String diveId)` on the dive repository — keyed by `dive_data_sources.id`, insertion-ordered primary first.

Attribution rules (the core bug fix):
1. Load the dive's `dive_data_sources` rows. If none exist, call the existing `backfillPrimaryDataSource(diveId)` pattern is NOT invoked here (read-only path); instead return a single synthetic entry keyed `'__unattributed__'`? No — return `{}` and let callers fall back to single-profile rendering. Callers only use this map when it has 2+ entries.
2. Build `computerId -> sourceId` from the source rows.
3. A profile row with non-null `computerId` maps to the source with that `computerId`; if no source matches, attribute it to the primary source (never drop data, never invent an "unknown" bucket).
4. A profile row with null `computerId` maps to the primary source (schema convention: null means primary/manual).
5. When both `isPrimary=true` and `isPrimary=false` rows exist for the primary source's rows (an edited profile exists), the primary source's `SourceProfile` contains ONLY the edited (`isPrimary=true`) rows with `isEdited: true`; the pre-edit originals are excluded (spec: out of scope to overlay them). Secondary sources are unaffected: an edited profile only ever replaces primary-attributed rows.
6. The old `getProfilesBySource` stays untouched until Task 10 deletes it (after all callers migrate in Task 6).

- [ ] **Step 1: Write the failing test**

Follow the existing repository-test setup pattern — find it with `grep -rn "AppDatabase(" test/features/dive_log/data | head -5` and copy the in-memory DB + repository construction from the nearest existing test (e.g. the consolidation service tests reference the same setup). The test file:

```dart
// test/features/dive_log/data/repositories/profiles_by_data_source_test.dart
// Setup: in-memory AppDatabase with PRAGMA foreign_keys ON, a dive row
// 'dive-1', two dive_computers rows 'dc-a' (name "Kiyans Teric") and 'dc-b'
// (name "Erics Teric"), and two dive_data_sources rows:
//   'src-a' (diveId: 'dive-1', computerId: 'dc-a', isPrimary: true)
//   'src-b' (diveId: 'dive-1', computerId: 'dc-b', isPrimary: false)
void main() {
  // ... setUp building the above ...

  test('null-computerId rows attribute to the primary source', () async {
    // Insert primary rows the pre-consolidation way: computerId NULL.
    await insertProfileRow(diveId: 'dive-1', timestamp: 0, depth: 10.0,
        computerId: null, isPrimary: true);
    await insertProfileRow(diveId: 'dive-1', timestamp: 10, depth: 12.0,
        computerId: 'dc-b', isPrimary: false);

    final result = await repository.getProfilesByDataSource('dive-1');

    expect(result.keys.toList(), ['src-a', 'src-b']);
    expect(result['src-a']!.points.single.depth, 10.0);
    expect(result['src-a']!.isEdited, false);
    expect(result['src-b']!.points.single.depth, 12.0);
  });

  test('rows with a computerId matching no source fall back to primary',
      () async {
    await insertProfileRow(diveId: 'dive-1', timestamp: 0, depth: 10.0,
        computerId: 'dc-a', isPrimary: true);
    await insertProfileRow(diveId: 'dive-1', timestamp: 5, depth: 11.0,
        computerId: 'dc-orphan', isPrimary: false);

    final result = await repository.getProfilesByDataSource('dive-1');

    expect(result['src-a']!.points.length, 2);
  });

  test('edited profile replaces primary rows and sets isEdited', () async {
    // Original primary rows demoted to isPrimary=false, edited rows
    // isPrimary=true with computerId NULL (the edit-flow convention).
    await insertProfileRow(diveId: 'dive-1', timestamp: 0, depth: 10.0,
        computerId: 'dc-a', isPrimary: false);
    await insertProfileRow(diveId: 'dive-1', timestamp: 0, depth: 9.5,
        computerId: null, isPrimary: true);
    await insertProfileRow(diveId: 'dive-1', timestamp: 0, depth: 12.0,
        computerId: 'dc-b', isPrimary: false);

    final result = await repository.getProfilesByDataSource('dive-1');

    expect(result['src-a']!.isEdited, true);
    expect(result['src-a']!.points.single.depth, 9.5);
    expect(result['src-b']!.points.single.depth, 12.0);
    expect(result['src-b']!.isEdited, false);
  });

  test('returns empty map when the dive has no data source rows', () async {
    // dive-2 has profile rows but no dive_data_sources rows.
    final result = await repository.getProfilesByDataSource('dive-2');
    expect(result, isEmpty);
  });
}
```

Write real `insertProfileRow` helpers with Drift companions (copy the column set from `DiveProfiles`, `database.dart:361-400`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/profiles_by_data_source_test.dart`
Expected: FAIL — `getProfilesByDataSource` not defined.

- [ ] **Step 3: Implement**

Create the entity:

```dart
// lib/features/dive_log/domain/entities/source_profile.dart
import 'package:submersion/features/dive_log/domain/entities/dive_profile_point.dart';

/// One data source's profile samples for a dive, keyed by the
/// dive_data_sources row that owns them.
class SourceProfile {
  const SourceProfile({
    required this.sourceId,
    required this.computerId,
    required this.isEdited,
    required this.points,
  });

  final String sourceId;
  final String? computerId;

  /// True when these are user-edited rows replacing the primary source's
  /// original samples.
  final bool isEdited;
  final List<DiveProfilePoint> points;
}
```

(Adjust the `DiveProfilePoint` import path to the actual location — find it with `grep -rn "class DiveProfilePoint" lib`.)

Add to `dive_repository_impl.dart`, directly below `getProfilesBySource` (reuse its row-to-point mapping by extracting it into a private `domain.DiveProfilePoint _profilePointFromRow(DiveProfileRow row)` helper used by both methods):

```dart
/// Get profile samples grouped by owning data source (spec 2026-07-04).
///
/// Keys are dive_data_sources ids, primary source first. Rows with a null
/// computerId belong to the primary source (schema convention). Rows whose
/// computerId matches no source also fall back to the primary source so no
/// data is ever dropped or bucketed under an invented key. When an edited
/// profile exists, the primary source carries only the edited rows
/// (isEdited: true).
Future<Map<String, domain.SourceProfile>> getProfilesByDataSource(
  String diveId,
) async {
  try {
    final sourceRows =
        await (_db.select(_db.diveDataSources)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.isPrimary),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get();
    if (sourceRows.isEmpty) return {};

    final primary = sourceRows.first;
    final sourceIdByComputer = <String, String>{
      for (final s in sourceRows)
        if (s.computerId != null) s.computerId!: s.id,
    };

    final rows =
        await (_db.select(_db.diveProfiles)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();

    final hasEditedProfile =
        rows.any((r) => r.isPrimary) && rows.any((r) => !r.isPrimary);

    final grouped = <String, List<domain.DiveProfilePoint>>{
      for (final s in sourceRows) s.id: [],
    };
    var primaryIsEdited = false;

    for (final row in rows) {
      final owner = row.computerId == null
          ? primary.id
          : (sourceIdByComputer[row.computerId!] ?? primary.id);
      if (owner == primary.id && hasEditedProfile) {
        // Edited rows (isPrimary=true) replace the primary source's
        // originals; skip the demoted originals entirely.
        if (!row.isPrimary) continue;
        primaryIsEdited = true;
      }
      grouped[owner]!.add(_profilePointFromRow(row));
    }

    return {
      for (final s in sourceRows)
        if (grouped[s.id]!.isNotEmpty || s.id == primary.id)
          s.id: domain.SourceProfile(
            sourceId: s.id,
            computerId: s.computerId,
            isEdited: s.id == primary.id && primaryIsEdited,
            points: grouped[s.id]!,
          ),
    };
  } catch (e, stackTrace) {
    _log.error(
      'Failed to get profiles by data source for dive: $diveId',
      error: e,
      stackTrace: stackTrace,
    );
    return {};
  }
}
```

Note the edited-row ownership subtlety: edited rows have `computerId = null` so they resolve to `primary.id` via the null branch, and demoted originals from the primary computer (either `computerId = null` pre-consolidation or the primary's `computerId` post-consolidation) are skipped by the `!row.isPrimary` guard. A secondary source's rows are always `isPrimary = false` AND owned by a non-primary source, so the guard never touches them.

Also add the method to the repository's abstract interface if one exists (`grep -rn "abstract class DiveRepository" lib`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/profiles_by_data_source_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: group dive profiles by data source id, fixing unknown-computer attribution"
```

---

### Task 3: Active-source and per-source analysis providers

**Files:**
- Create: `lib/features/dive_log/presentation/providers/active_source_provider.dart`
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (add `sourceProfilesProvider`)
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` (extract computation, add per-source family)
- Test: `test/features/dive_log/presentation/providers/active_source_provider_test.dart`

**Interfaces:**
- Consumes: `getProfilesByDataSource` (Task 2), existing `profileAnalysisProvider = FutureProvider.family<ProfileAnalysis?, String>` (`profile_analysis_provider.dart:630`), `diveDataSourcesProvider` (`dive_providers.dart:953`).
- Produces:
  - `final activeDiveSourceProvider = StateProvider.family<String?, String>((ref, diveId) => null);` — null means "the primary source"; holds a `dive_data_sources.id` otherwise. Session-only by construction (StateProvider resets when unlistened; use `.autoDispose` OFF to survive tab switches within a session — match whatever the sibling per-dive state providers like `playbackProvider` use).
  - `final overlaySourcesProvider = StateProvider.family<Set<String>, String>((ref, diveId) => const {});` — overlaid source IDs.
  - `final sourceProfilesProvider = FutureProvider.family<Map<String, SourceProfile>, String>` — thin wrapper over `getProfilesByDataSource`.
  - `typedef DiveSourceKey = ({String diveId, String? sourceId});`
  - `final sourceProfileAnalysisProvider = FutureProvider.family<ProfileAnalysis?, DiveSourceKey>` — delegates to `profileAnalysisProvider(diveId)` when `sourceId` is null or resolves to the primary source (preserving the residual-CNS recursion and its cache); otherwise computes analysis over that source's points.

Implementation approach for the per-source branch: extract the body of `profileAnalysisProvider` (everything after the dive null-check, `profile_analysis_provider.dart:653` onward) into a top-level `Future<ProfileAnalysis?> computeAnalysisForProfile(Ref ref, Dive dive, List<DiveProfilePoint> profile, {String? computerId})` where `profile` replaces every `dive.profile` read and `computerId` filters the tank-pressure lookup (only tanks/pressures whose `computerId` matches; pass null to keep current behavior). `profileAnalysisProvider` becomes a two-line body calling it with `dive.profile`. The non-primary branch of `sourceProfileAnalysisProvider` calls it with the source's points and the source's `computerId`, and skips the residual-CNS previous-dive chain only if that chain is entangled with `dive.profile` (it is not — it keys off dive IDs, keep it).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/presentation/providers/active_source_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';

void main() {
  test('defaults to null (primary) and is settable per dive', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(activeDiveSourceProvider('dive-1')), isNull);
    container.read(activeDiveSourceProvider('dive-1').notifier).state =
        'src-b';
    expect(container.read(activeDiveSourceProvider('dive-1')), 'src-b');
    expect(container.read(activeDiveSourceProvider('dive-2')), isNull);
  });

  test('overlay set defaults empty and toggles per dive', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(overlaySourcesProvider('dive-1')), isEmpty);
    container.read(overlaySourcesProvider('dive-1').notifier).state = {
      'src-b',
    };
    expect(container.read(overlaySourcesProvider('dive-1')), {'src-b'});
    expect(container.read(overlaySourcesProvider('dive-2')), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/active_source_provider_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_log/presentation/providers/active_source_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The data source whose data drives the dive detail page (chart, stat
/// chips, deco and tissue cards). Null means "the primary source" so the
/// page needs no async initialization. View state only: switching never
/// writes isPrimary.
final activeDiveSourceProvider = StateProvider.family<String?, String>(
  (ref, diveId) => null,
);

/// Source IDs currently overlaid on the profile chart for comparison.
final overlaySourcesProvider = StateProvider.family<Set<String>, String>(
  (ref, diveId) => const {},
);
```

Add to `dive_providers.dart` next to `profilesBySourceProvider` (line ~173):

```dart
/// Profiles grouped by owning data source (active-source model).
final sourceProfilesProvider =
    FutureProvider.family<Map<String, SourceProfile>, String>((ref, diveId) {
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDiveDetailChanges(diveId));
      return repository.getProfilesByDataSource(diveId);
    });
```

Match the invalidation idiom actually used by `profilesBySourceProvider` — copy its body shape exactly (Riverpod 3: use the `invalidateSelfWhen` helper if that is what the sibling uses; do NOT introduce raw `.listen` self-invalidation).

In `profile_analysis_provider.dart`: perform the extraction described in Interfaces, then add:

```dart
/// Key for per-source analysis. sourceId null = primary source.
typedef DiveSourceKey = ({String diveId, String? sourceId});

/// Analysis computed from one data source's own samples. Delegates to
/// [profileAnalysisProvider] for the primary source so its cache and
/// residual-CNS chain are shared.
final sourceProfileAnalysisProvider =
    FutureProvider.family<ProfileAnalysis?, DiveSourceKey>((ref, key) async {
      final sources = await ref.watch(
        diveDataSourcesProvider(key.diveId).future,
      );
      final primaryId = sources
          .where((s) => s.isPrimary)
          .map((s) => s.id)
          .firstOrNull;
      if (key.sourceId == null || key.sourceId == primaryId) {
        return ref.watch(profileAnalysisProvider(key.diveId).future);
      }
      final dive = await ref.watch(diveProvider(key.diveId).future);
      if (dive == null) return null;
      final profiles = await ref.watch(
        sourceProfilesProvider(key.diveId).future,
      );
      final sourceProfile = profiles[key.sourceId];
      if (sourceProfile == null || sourceProfile.points.isEmpty) return null;
      return computeAnalysisForProfile(
        ref,
        dive,
        sourceProfile.points,
        computerId: sourceProfile.computerId,
      );
    });
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/providers/active_source_provider_test.dart`
Expected: PASS. Then run the existing analysis tests to prove the extraction is behavior-preserving: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` (locate the actual file with `ls test/features/dive_log/presentation/providers/`).
Expected: PASS with no test edits.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: active-source, overlay, and per-source analysis providers"
```

---

### Task 4: SourceBar widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/source_bar.dart`
- Test: `test/features/dive_log/presentation/widgets/source_bar_test.dart`

**Interfaces:**
- Consumes: `computerColors` / `computerColorAt` — MOVE these two declarations verbatim from `computer_toggle_bar.dart:4-19` into `source_bar.dart` (Task 10 deletes the old file; until then `computer_toggle_bar.dart` imports them back from `source_bar.dart` to avoid duplication).
- Produces:

```dart
enum SourceMenuAction { setPrimary, unlink, split }

class SourceBarItem {
  const SourceBarItem({
    required this.sourceId,
    required this.label,
    required this.color,
    required this.isActive,
    required this.isPrimary,
    required this.isOverlaid,
    required this.hasProfile,
  });
  final String sourceId;
  final String label;
  final Color color;
  final bool isActive;
  final bool isPrimary;
  final bool isOverlaid;
  final bool hasProfile; // false disables the overlay eye
}

class SourceBar extends StatelessWidget {
  const SourceBar({
    super.key,
    required this.sources,
    required this.onActivate,
    required this.onToggleOverlay,
    required this.onMenuAction,
  });
  final List<SourceBarItem> sources;
  final void Function(String sourceId) onActivate;
  final void Function(String sourceId, bool overlaid) onToggleOverlay;
  final void Function(String sourceId, SourceMenuAction action) onMenuAction;
}
```

Rendering rules:
- Returns `SizedBox.shrink()` when `sources.length <= 1` (same rule as `ComputerToggleBar`, `computer_toggle_bar.dart:53`).
- Row layout mirroring `ComputerToggleBar` (`computer_toggle_bar.dart:59-87`): a leading label using the new l10n key `diveLog_sources_barLabel` ("SOURCES", en only for now), then a `Wrap` of chips.
- Each chip: a `FilterChip`-style container. Selected (active) = filled with `item.color` at 0.15 alpha and a `item.color` border; inactive = outlined. Contents: an 8x8 circle in `item.color`, the label text, a star icon (`Icons.star`, size 12) when `isPrimary`, an eye `IconButton` (`Icons.visibility` / `Icons.visibility_off_outlined`, size 16) on NON-active chips only (disabled when `!hasProfile`), and a `PopupMenuButton<SourceMenuAction>` (icon `Icons.more_vert`, size 16) with items Set as primary (hidden when `isPrimary`), Unlink, Split into separate dive (hidden when `sources.length < 2` — the whole bar already hides then, so always shown). Menu item labels come from l10n keys `diveLog_sources_menu_setPrimary`, `diveLog_sources_menu_unlink`, `diveLog_sources_menu_split` (reuse existing keys for the first two if `grep -rn "Set as primary" lib/l10n` finds them; the current `data_sources_section.dart:416,425` uses raw literals — add keys and switch that file too in Task 8).
- Tapping the chip body (not the eye or menu) calls `onActivate(sourceId)`; tapping an active chip is a no-op.
- Tapping the eye calls `onToggleOverlay(sourceId, !item.isOverlaid)`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/dive_log/presentation/widgets/source_bar_test.dart
// Pump SourceBar inside MaterialApp with localization delegates (copy the
// harness from test/features/dive_log/presentation/widgets/ existing tests).
// Cases:
// 1. one source -> renders nothing (find.byType(SizedBox) shrink / no chips)
// 2. two sources -> two chips with their labels; active chip shows no eye;
//    non-active chip shows an eye
// 3. tapping non-active chip body calls onActivate with its sourceId
// 4. tapping the eye calls onToggleOverlay('src-b', true)
// 5. primary chip shows the star icon
// 6. menu on non-primary chip contains Set as primary, Unlink, and
//    Split into separate dive; selecting split calls
//    onMenuAction('src-b', SourceMenuAction.split)
// 7. hasProfile:false -> eye IconButton onPressed is null
```

Write these as real `testWidgets` bodies with `expect`/`tester.tap`/callback capture (record calls into local lists).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/source_bar_test.dart`
Expected: FAIL — `source_bar.dart` does not exist.

- [ ] **Step 3: Implement `source_bar.dart`** per the interface and rendering rules above. Keep it under 250 lines; extract `_SourceChip` as a private widget.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/source_bar_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: SourceBar widget with activate, overlay, and management menu"
```

---

### Task 5: Chart — active-source rendering with typed overlays

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- Test: extend the chart's existing test file (locate with `ls test/features/dive_log/presentation/widgets/ | grep -i profile`)

**Interfaces:**
- Consumes: `SourceProfile` points (already `DiveProfilePoint`), colors from `source_bar.dart`.
- Produces (new widget props, replacing the multi-computer ones):

```dart
class ChartSourceOverlay {
  const ChartSourceOverlay({
    required this.sourceId,
    required this.name,
    required this.color,
    required this.computerId,
    required this.points,
  });
  final String sourceId;
  final String name;
  final Color color;
  final String? computerId;
  final List<DiveProfilePoint> points;
}
```

- New prop: `final List<ChartSourceOverlay>? overlays;`
- DELETED props: `computerProfiles`, `visibleComputers`, `computerLineColors`, `primaryComputers` (`dive_profile_chart.dart:197-208`). KEEP `computerNames` (`:213`) — it still labels tank-pressure tooltip rows by computer.

The active source is simply `widget.profile` — callers pass the active source's points there (Task 6). The chart no longer knows about "primary": single-source rendering paths become the only paths for the main series.

Changes, in order:

1. `_buildGasColoredDepthLines` (`:3119`): delete the `computerProfiles` branch (`:3123-3126`). Velocity coloring and the single solid segment become unconditional behavior for `widget.profile`.
2. Delete `_buildMultiComputerDepthLines` (`:3250-3319`), `_buildMultiComputerTemperatureLines` (`:3483-3531`), `_isMultiComputer` (`:3180-3183`), and the multi-computer branches in `_depthBarCount` (`:3192-3201`) and `_depthBarStartIndices` (`:3211-3226`).
3. `_buildTemperatureLines` (`:3419`): delete the `computerProfiles` branch; always return the single active-source temp line.
4. Replace `_isComputerVisible` (find at `:554-563`): it currently gates tank-pressure and event rendering by computer visibility. New semantics: a computerId is visible when it belongs to the ACTIVE source (null computerId is always active-owned) or to an overlaid source:

```dart
bool _isComputerVisible(String? computerId) {
  if (computerId == null) return true;
  if (computerId == widget.activeComputerId) return true;
  final overlays = widget.overlays;
  if (overlays == null) return false;
  return overlays.any((o) => o.computerId == computerId);
}
```

  This needs one more small prop: `final String? activeComputerId;` (the active source's computerId; null for manual/edited-primary rows). Add it alongside `overlays`.
5. New builder `List<LineChartBarData> _buildOverlayLines(UnitFormatter units, ColorScheme colorScheme, double chartMaxDepth, double minTemp, double maxTemp)` appended to the chart's bar assembly (find the assembly where depth + temperature + tank lines are concatenated, `:2031-2148` region). For each overlay in `widget.overlays ?? const []`:
   - Depth: dashed line, exactly the secondary style from the deleted `_buildMultiComputerDepthLines` else-branch (`dashArray: const [6, 4]`, `barWidth: 2`, no fill, `overlay.color`).
   - Temperature (only when the temp legend metric is enabled — reuse the same `_show`/legend condition that gates the active temp line): the dimmed dashed style from the deleted multi-computer temp builder (`overlay.color.withValues(alpha: 0.6)`, `dashArray: const [5, 3]`), points filtered to `temperature != null`, mapped with the SAME `_mapTempToDepth(chartMaxDepth, minTemp, maxTemp)` scaling as the active line so both curves share one temp scale. IMPORTANT: `minTemp`/`maxTemp` must be computed over active + overlaid points together — find where they are derived from `widget.profile` and widen the scan over overlay points too.
   - Computer-reported ceiling and NDL (each only when its legend metric is enabled AND the overlay's points carry non-null values for it): dashed lines in `overlay.color.withValues(alpha: 0.45)`, mapped exactly like the active source's ceiling/NDL curves (ceiling on the depth axis; NDL on whatever axis the active NDL line uses — locate its builder first).
   - Events and tank pressures need no new code: they already render per-computer and are now gated by the new `_isComputerVisible`.
6. Depth-axis and time-axis extents: widen the existing min/max scans (search for where `maxDepth`/duration extents are computed from `widget.profile`) to include overlay points so an overlaid deeper/longer trace is never clipped.
7. Tooltip: in the touch handler that builds tooltip rows for the active profile, append one row per overlay with a depth value at the touched timestamp (nearest sample within 10s; skip the overlay otherwise): label = `overlay.name`, colored with `overlay.color`. Follow the existing timestamp-matching idiom (`depthSpotProfileIndex` remap machinery) rather than array indices.
8. Overlay bars and the depth-bar indexing: append overlay bars AFTER all existing bars so `_depthBarCount`/`_depthBarStartIndices` (which assume depth bars come first) stay valid. Overlay bars must not be touch-targets for the main tooltip flow — check how gas-switch marker bars are excluded from touch and use the same mechanism.

- [ ] **Step 1: Write failing tests** in the chart test file: (a) constructing the chart with `overlays` renders one additional dashed `LineChartBarData` per overlay for depth (probe via the widget's build products if the file has that pattern, else via `tester.widget<LineChart>` bar count comparisons between zero and one overlay); (b) `_isComputerVisible` semantics via a rendering assertion: a tank-pressure line for a computer NOT in {active, overlays} is absent, present once overlaid. Follow the file's existing test style for multi-computer rendering (there are existing tests referencing `computerProfiles` — rewrite those to the new props as part of this task, preserving their intent).

- [ ] **Step 2: Run to verify new tests fail**

Run: `flutter test test/features/dive_log/presentation/widgets/<chart test file>`
Expected: new tests FAIL (missing props); old multi-computer tests fail to compile — that is expected mid-task.

- [ ] **Step 3: Implement** changes 1-8. `dive_profile_chart.dart` and the fullscreen page will not compile until Task 6 updates call sites; to keep this task self-contained, update ALL `DiveProfileChart(` call sites mechanically in this task: `grep -rn "DiveProfileChart(" lib` — pass `overlays: null, activeComputerId: null` and delete the removed args at each site; Task 6 wires real values on the detail page and fullscreen page.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/<chart test file>`
Expected: PASS. Also `flutter analyze lib/features/dive_log` must report no errors.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: chart renders active source with typed color-coded overlays"
```

---

### Task 6: Detail page and fullscreen wiring

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (profile section `:1061-1437`, stat chips `:860-900` region, deco/tissue cards `:1546-1560` region)
- Modify: the fullscreen profile page (find with `grep -rln "computerProfiles" lib` — PR #469's page)
- Test: `test/features/dive_log/presentation/pages/dive_detail_multi_source_test.dart` (new)

**Interfaces:**
- Consumes: `activeDiveSourceProvider`, `overlaySourcesProvider`, `sourceProfilesProvider`, `sourceProfileAnalysisProvider` (Task 3), `SourceBar`/`SourceBarItem`/`SourceMenuAction` (Task 4), chart `overlays`/`activeComputerId` (Task 5), `resolveSourceName` (Task 1).
- Produces: the assembled page behavior later tasks and tests rely on:

```dart
// Inside _buildProfileSection (replacing lines ~1123-1188):
final dataSources =
    ref.watch(diveDataSourcesProvider(dive.id)).valueOrNull ?? const [];
final sourceProfiles =
    ref.watch(sourceProfilesProvider(dive.id)).valueOrNull ?? const {};
final activeSourceId = ref.watch(activeDiveSourceProvider(dive.id));
final overlayIds = ref.watch(overlaySourcesProvider(dive.id));

final labels = SourceNameLabels(
  unknownComputer: context.l10n.diveLog_sources_unknownComputer,
  manualEntry: context.l10n.diveLog_sources_manualEntry,
  importedFile: context.l10n.diveLog_sources_importedFile,
  editedSuffix: context.l10n.diveLog_sources_editedSuffix,
);

final primarySource =
    dataSources.where((s) => s.isPrimary).firstOrNull ??
    dataSources.firstOrNull;
final activeSource = activeSourceId == null
    ? primarySource
    : dataSources.where((s) => s.id == activeSourceId).firstOrNull ??
          primarySource;

final activeProfile = activeSource == null
    ? null
    : sourceProfiles[activeSource.id];
// The chart's main series: the active source's points when the dive is
// multi-source; dive.profile otherwise (identical for the primary).
final chartProfile =
    (dataSources.length >= 2 && activeProfile != null &&
        activeProfile.points.isNotEmpty)
    ? activeProfile.points
    : dive.profile;
```

- Analysis: replace `ref.watch(profileAnalysisProvider(dive.id))` at `:1063` with `ref.watch(sourceProfileAnalysisProvider((diveId: dive.id, sourceId: activeSource?.id)))`. Same substitution wherever the deco/tissue cards read analysis in this page.
- Chart call (`:1309-1387`): `profile: chartProfile`, `activeComputerId: activeSource?.computerId`, and

```dart
overlays: [
  for (final id in overlayIds)
    if (id != activeSource?.id && sourceProfiles[id] != null)
      ChartSourceOverlay(
        sourceId: id,
        name: resolveSourceName(
          dataSources.firstWhere((s) => s.id == id),
          labels,
          edited: sourceProfiles[id]!.isEdited,
        ),
        color: sourceColors[id]!,
        computerId: sourceProfiles[id]!.computerId,
        points: sourceProfiles[id]!.points,
      ),
],
```

  where `sourceColors` assigns `computerColorAt(index)` by `dataSources` order (stable regardless of toggling). Keep passing `computerNames` (still keyed by computerId, built via `resolveSourceName` now — rewrite `_computerDisplayNames` `:1048-1059` to use it).
- Delete `_visibleComputers` state (`:127`), the toggle assembly (`:1138-1188`), and the `ComputerToggleBar` block (`:1418-1437`). Replace with:

```dart
if (dataSources.length >= 2)
  SourceBar(
    sources: [
      for (final (index, s) in dataSources.indexed)
        SourceBarItem(
          sourceId: s.id,
          label: resolveSourceName(
            s,
            labels,
            edited: sourceProfiles[s.id]?.isEdited ?? false,
          ),
          color: computerColorAt(index),
          isActive: s.id == activeSource?.id,
          isPrimary: s.isPrimary,
          isOverlaid: overlayIds.contains(s.id),
          hasProfile: (sourceProfiles[s.id]?.points.isNotEmpty) ?? false,
        ),
    ],
    onActivate: (id) {
      ref.read(activeDiveSourceProvider(dive.id).notifier).state = id;
      ref.read(overlaySourcesProvider(dive.id).notifier).state = {
        ...ref.read(overlaySourcesProvider(dive.id)),
      }..remove(id);
    },
    onToggleOverlay: (id, overlaid) {
      final current = ref.read(overlaySourcesProvider(dive.id));
      ref.read(overlaySourcesProvider(dive.id).notifier).state = overlaid
          ? {...current, id}
          : ({...current}..remove(id));
    },
    onMenuAction: (id, action) => _handleSourceMenuAction(dive, id, action),
  ),
```

  `_handleSourceMenuAction` for setPrimary/unlink delegates to the same handlers `DataSourcesSection` uses (find them via `grep -n "onSetPrimary\|onUnlink" lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/widgets/data_sources_section.dart` and call the underlying repository/provider methods directly). The split case calls `_confirmAndSplit(dive, id)` (defined in Task 8, implemented as part of this task's page edit) wired to `DiveSplitService` from Task 7 — no stubs, no placeholder menu items. **Task 7 (split service) must therefore be executed BEFORE Task 6.** Execution order: 1, 2, 3, 4, 5, 7, 6 (includes Task 8's UI), 8 (review gate), 9, 10.
- Stat chips: where `_buildStatItem` calls pass values (max depth `:868`, bottom time `:875/884`, water temp `:891` per the earlier exploration; confirm with grep), display the active source's value when the dive is multi-source and the active source has one: `activeSource?.maxDepth ?? dive.maxDepth` (convert with `UnitFormatter` exactly as the current code does). Attribution names now come from `FieldAttributionService.computeAttribution(dataSources, viewedSourceId: activeSource?.id, nameOf: (s) => resolveSourceName(s, labels))`.
- Fullscreen page: same substitution pattern (active profile, overlays, analysis key). It shares providers, so this is mechanical.

- [ ] **Step 1: Write the failing widget test** (`dive_detail_multi_source_test.dart`): seed a fake/in-memory repository with one dive, two sources (named "Kiyans Teric" primary, "Erics Teric" secondary) with distinct profiles; pump the detail page. Assert: (a) SourceBar shows both names and NEVER the string "Unknown Computer"; (b) initially the max-depth stat chip's `FieldAttributionBadge` shows "Kiyans Teric"; (c) after tapping the "Erics Teric" chip, the badge shows "Erics Teric" and the chart's main profile length equals the secondary profile's point count. Reuse the page-level test harness from the existing detail page tests (`ls test/features/dive_log/presentation/pages/`).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_multi_source_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the wiring above in both pages. Migrate any remaining `profilesBySourceProvider` consumers found by `grep -rn "profilesBySourceProvider" lib` to `sourceProfilesProvider` (leave the restore-original-profile repository logic alone — it uses the repo directly, not this provider).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_multi_source_test.dart` then the page's existing test files.
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: dive detail page follows active source with SourceBar"
```

---

### Task 7: DiveSplitService (EXECUTE BEFORE TASK 6)

**Files:**
- Create: `lib/features/dive_log/data/services/dive_split_service.dart`
- Test: `test/features/dive_log/data/services/dive_split_service_test.dart`

**Interfaces:**
- Consumes: `DiveConsolidationService` (`lib/features/dive_log/data/services/dive_consolidation_service.dart`) as the structural template — same `SyncRepository` tombstone API, same `SyncEventBus` notify, same transaction shape. Study `apply()` (`:48-104`) and its tombstoning of moved rows before writing any code.
- Produces:

```dart
class DiveSplitService {
  DiveSplitService(this._diveRepo);
  final DiveRepository _diveRepo;

  /// Splits [sourceId]'s data out of [diveId] into a new dive.
  /// Returns the new dive's id. Throws ArgumentError when the source does
  /// not exist on the dive or is the dive's only source. All-or-nothing:
  /// one transaction, full rollback on any failure.
  Future<String> split({required String diveId, required String sourceId});
}
```

Behavior (all inside one `_db.transaction`):
1. Load the dive row, its `dive_data_sources` rows, and the target source row. Guards: source must belong to the dive; `sources.length >= 2`.
2. New dive row: new UUID; copy the original dive row's fields; override `computerId` with the source's `computerId`; override the summary fields the source row carries when non-null (`maxDepth`, `avgDepth`, duration -> the dive's duration/runtime column, `waterTemp`, entry/exit times and GPS). Dive number: leave null (do not renumber the log). Site, notes, buddies, tags, equipment: stay on the original dive only (splitting recovers the computer's data, not the logbook entry).
3. Move child rows whose `computerId` equals the source's `computerId` from tables `dive_profiles`, `dive_profile_events`, `tank_pressure_profiles`, `dive_tanks`: insert copies (new UUIDs, `diveId` = new dive, `isPrimary` = true for profile rows, `computerId` preserved) then delete the originals WITH per-row tombstones via the same `SyncRepository` calls consolidation uses for its deletes. If the source's `computerId` is null (manual primary being split out), the moved rows are the `computerId IS NULL` rows.
4. Delete the source row from the original dive (tombstoned) and insert a fresh `dive_data_sources` row on the new dive (`isPrimary: true`, copying the source's snapshot columns).
5. If the split source was the original dive's primary: promote the remaining source with the earliest `createdAt` (`isPrimary = true` on its source row) and set the promoted source's profile rows to `isPrimary = true` so `getDiveProfile` (which filters `isPrimary`) still returns a profile. Also null-out or update the original dive row's `computerId` to the promoted source's `computerId`, and recompute the original dive's summary columns from the promoted source row's snapshot values where present.
6. Fire the same `SyncEventBus` notification consolidation fires, once, after the transaction.

- [ ] **Step 1: Write the failing tests** — in-memory DB with `PRAGMA foreign_keys = ON` asserted in `setUp` (verify with `SELECT foreign_keys` pragma; skip-on-unsupported is not acceptable here). Reuse the consolidation service's test fixtures if present (`ls test/features/dive_log/data/services/`). Cases:

```dart
// 1. split of secondary source: new dive exists with the secondary's
//    profile rows (isPrimary=true on new dive), original dive no longer
//    has them; original keeps its primary profile; both source tables
//    consistent; PRAGMA foreign_key_check returns no rows.
// 2. split of PRIMARY source: remaining source promoted (isPrimary=true,
//    its profile rows isPrimary=true), original dive computerId updated.
// 3. splitting the only source throws ArgumentError and writes nothing.
// 4. tombstones: deletion log contains entries for every moved row id
//    (query the same table SyncRepository writes; mirror how the
//    consolidation tests assert tombstones).
// 5. round-trip: consolidate two dives (DiveConsolidationService.apply),
//    then split the secondary back out; the new dive's profile point
//    count and max depth equal the pre-consolidation secondary's.
```

Write these as full test bodies against the real services.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/data/services/dive_split_service_test.dart`
Expected: FAIL — service does not exist.

- [ ] **Step 3: Implement** per the behavior list, mirroring `DiveConsolidationService`'s structure and its exact tombstone/SyncEventBus idioms.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/data/services/dive_split_service_test.dart`
Expected: PASS (5 tests). Also run the consolidation tests to confirm nothing regressed: `flutter test test/features/dive_log/data/services/dive_consolidation_service_test.dart` (actual filename via `ls`).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: DiveSplitService splits a data source into a separate dive"
```

---

### Task 8: Split confirmation UI (folded into Task 6's page wiring)

This task's content executes as part of Task 6 (see the resolution note there); it is kept as a separate checklist so the reviewer gates it independently.

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_confirmAndSplit`)
- Modify: `lib/features/dive_log/presentation/widgets/data_sources_section.dart` (add split to `_SourceMenuAction` enum `:610` and menu `:410-429`; replace the raw 'Set as primary'/'Unlink' literals with the l10n keys from Task 4)

**Interfaces:**
- Consumes: `DiveSplitService.split` (Task 7), `SourceMenuAction.split` (Task 4).
- Produces: `Future<void> _confirmAndSplit(Dive dive, String sourceId)` on the detail page state.

- [ ] **Step 1: Write the failing widget test** (extend `dive_detail_multi_source_test.dart`): choosing Split from a source chip's menu shows an `AlertDialog` whose confirm button triggers the split (inject a recording fake of `DiveSplitService` via its provider) and then shows a `SnackBar`. Cancel performs no call.

- [ ] **Step 2: Run to verify it fails.** `flutter test test/features/dive_log/presentation/pages/dive_detail_multi_source_test.dart`

- [ ] **Step 3: Implement**

```dart
Future<void> _confirmAndSplit(Dive dive, String sourceId) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.diveLog_sources_splitDialog_title),
      content: Text(l10n.diveLog_sources_splitDialog_body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.diveLog_sources_splitDialog_confirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !mounted) return;
  try {
    await ref.read(diveSplitServiceProvider).split(
          diveId: dive.id,
          sourceId: sourceId,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.diveLog_sources_splitDone),
        persist: false,
        showCloseIcon: true,
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.diveLog_sources_splitFailed)),
    );
  }
}
```

(Adapt the SnackBar persist/closeIcon parameters to the project's actual SnackBar conventions — see the #406 pattern: `persist: false` + `showCloseIcon: true` if the project uses a custom helper; otherwise plain `SnackBar` with default duration. Check `grep -rn "showCloseIcon" lib | head -3`.) Add `diveSplitServiceProvider` next to where the consolidation service's provider is declared (`grep -rn "DiveConsolidationService(" lib/features --include=*providers*` to find the idiom). New en l10n keys: `diveLog_sources_splitDialog_title` ("Split into separate dive?"), `diveLog_sources_splitDialog_body` ("This source's profile, events, and tanks will move to a new dive. The logbook entry stays on this dive."), `diveLog_sources_splitDialog_confirm` ("Split"), `diveLog_sources_splitDone` ("Dive split"), `diveLog_sources_splitFailed` ("Split failed"), plus `diveLog_sources_menu_split` ("Split into separate dive").

- [ ] **Step 4: Run tests.** Same file. Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: split-into-separate-dive action with confirmation"
```

---

### Task 9: Localization sweep

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (verify all keys from Tasks 1, 4, 8 are present) and all 10 non-en locale arb files in `lib/l10n/arb/`
- Regenerate: localizations codegen

- [ ] **Step 1: Enumerate the new keys** — `git diff main -- lib/l10n/arb/app_en.arb` lists every key added by this branch: `diveLog_sources_manualEntry`, `diveLog_sources_importedFile`, `diveLog_sources_editedSuffix`, `diveLog_sources_barLabel`, `diveLog_sources_menu_setPrimary`, `diveLog_sources_menu_unlink`, `diveLog_sources_menu_split`, `diveLog_sources_splitDialog_title`, `diveLog_sources_splitDialog_body`, `diveLog_sources_splitDialog_confirm`, `diveLog_sources_splitDone`, `diveLog_sources_splitFailed`.

- [ ] **Step 2: Translate into all 10 non-en locales** (the same set every prior string sweep used — list them with `ls lib/l10n/arb/`). Match each locale file's existing tone and diving terminology (check how `diveLog_sources_unknownComputer` was translated for consistency).

- [ ] **Step 3: Regenerate** with the project's l10n codegen (`flutter gen-l10n` or `dart run build_runner build --delete-conflicting-outputs` — whichever regenerated `app_localizations_en.dart` previously; check `git log --oneline -3 -- lib/l10n`).

- [ ] **Step 4: Verify** — `flutter analyze lib/l10n` clean; `flutter test test/features/dive_log/presentation/widgets/source_bar_test.dart` still passes.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat: localize multi-source attribution strings in all locales"
```

---

### Task 10: Cleanup, dead-code removal, full verification

**Files:**
- Delete: `lib/features/dive_log/presentation/widgets/computer_toggle_bar.dart` (after confirming zero remaining imports: `grep -rn "computer_toggle_bar" lib test`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — delete `getProfilesBySource` (`:499-561`) if `grep -rn "getProfilesBySource\b" lib test` shows no remaining callers; also delete `profilesBySourceProvider` from `dive_providers.dart:173` under the same check. If callers remain (e.g. restore-original-profile), leave the method and delete only the provider if unused.
- Modify: `lib/features/dive_log/domain/entities/dive_data_source.dart` — delete the deprecated `displayName` and `computerLabel` if `grep -rn "displayName\|computerLabel" lib test --include=*.dart | grep -i "source"` shows no remaining callers; otherwise migrate the stragglers to `resolveSourceName` first.

- [ ] **Step 1: Delete dead code** per the greps above, migrating any stragglers.

- [ ] **Step 2: Whole-project verification**

```bash
dart format .
flutter analyze
```

Expected: analyze reports no issues (do not pipe through tail; read the full output).

- [ ] **Step 3: Run the touched test files** (specific files, not directories):

```bash
flutter test \
  test/features/dive_log/domain/services/source_name_resolver_test.dart \
  test/features/dive_log/data/repositories/profiles_by_data_source_test.dart \
  test/features/dive_log/presentation/providers/active_source_provider_test.dart \
  test/features/dive_log/presentation/widgets/source_bar_test.dart \
  test/features/dive_log/data/services/dive_split_service_test.dart \
  test/features/dive_log/presentation/pages/dive_detail_multi_source_test.dart
```

Then the pre-existing suites most likely to regress: the chart widget tests, detail page tests, consolidation service tests, and field attribution tests (exact filenames from `ls`).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove superseded multi-computer toggle path"
```

---

## Execution order

1 -> 2 -> 3 -> 4 -> 5 -> **7** -> 6 (includes 8's UI) -> 8 (review gate) -> 9 -> 10

## Out of scope (from the spec)

- Persisting active-source or overlay selection across sessions.
- Overlaying the pre-edit original of an edited profile.
- Changes to consolidation matching heuristics.
