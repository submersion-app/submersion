# Provider Change-Tick Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make it impossible to add a Riverpod provider that reads a database table without subscribing to that table's change tick, and fix all 137 existing violations.

**Architecture:** An architecture test parses `lib/` with `package:analyzer`'s syntactic `parseFile` and asserts that every provider invoking a repository method also references a change-tick method. It lands with a `_knownViolations` ratchet list seeded with today's 137 entries, asserted for exact equality so neither a new violation nor an unrecorded fix can slip through. Each subsequent task deletes its entries from that list until it is empty and gets removed.

**Tech Stack:** Dart, Flutter, Riverpod 3.1, Drift, `package:analyzer` 9.0.0, `flutter_test`.

## Global Constraints

- `dart format .` must produce no changes; run it after every task (project rule).
- `flutter analyze` must be clean across the whole project; infos are fatal in CI.
- No emojis in code, comments, or documentation.
- Always use package imports (`always_use_package_imports` lint), never relative.
- `require_trailing_commas` and `prefer_final_locals` are enforced lints.
- `invalidateSelfWhen` comes from `package:submersion/core/providers/provider.dart`, which re-exports `ref_invalidate_on_change.dart`. Importing that one file is sufficient.
- `diveRepositoryProvider` lives in `package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart`, a dependency-only module carved out to avoid import cycles. **Prefer importing that module over `dive_providers.dart`**, which pulls in `trip_providers.dart` and can create a cross-feature cycle.
- Change ticks must be `changeTickDebounce`-debounced (300 ms) via `DiveRepository.changeTickDebounce` and `package:submersion/core/utils/stream_debounce.dart`.
- Never include Claude Code attribution or session URLs in commit messages or PR descriptions.

---

## File Structure

**Created:**

- `test/architecture/provider_tick_scanner.dart` — the reusable scanner. Parses source, returns violations. No `expect` calls, no knowledge of `lib/`. Kept separate from the test so it can be unit-tested against synthetic fixtures.
- `test/architecture/provider_tick_scanner_test.dart` — unit tests for the scanner using synthetic fixture source, covering every accept/reject shape.
- `test/architecture/provider_change_tick_test.dart` — the repository-wide invariant test. Runs the scanner over `lib/` and asserts against the ratchet list.
- `test/features/statistics/statistics_tick_reactivity_test.dart` — behavioral regression test for the statistics mechanism swap.

**Modified:** `pubspec.yaml`, `StatisticsRepository`, 13 other repositories gaining tick streams, and 31 provider files.

---

## Task 1: The scanner and its unit tests

**Files:**
- Modify: `pubspec.yaml` (dev_dependencies)
- Create: `test/architecture/provider_tick_scanner.dart`
- Test: `test/architecture/provider_tick_scanner_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class TickViolation { final String file; final int line; final String provider; final String repositoryCall; }`
  - `class ScanResult { final Set<String> tickNames; final int tickDeclarationCount; final List<TickViolation> violations; final int repositoryReadingProviders; }`
  - `ScanResult scanForTickViolations({required List<File> repositoryFiles, required List<File> providerFiles, required String Function(String) relativize})`

- [ ] **Step 1: Add the analyzer dev dependency**

`analyzer 9.0.0` is already in `pubspec.lock` transitively via `build_runner`/`drift_dev`, so this promotes an existing resolved version rather than introducing one. In `pubspec.yaml`, after the `fake_async` line in `dev_dependencies`:

```yaml
  fake_async: ^1.3.3  # synthetic clock + Timer driving for unit tests
  analyzer: ^9.0.0  # AST parsing for the provider change-tick architecture test
```

Run `flutter pub get`. Expected: `Changed 1 dependency!` and no version downgrades elsewhere.

- [ ] **Step 2: Write the failing scanner unit test**

Create `test/architecture/provider_tick_scanner_test.dart`. It writes synthetic Dart source into a temp directory, so it never depends on the real `lib/` tree.

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'provider_tick_scanner.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('tick_scanner'));
  tearDown(() => temp.deleteSync(recursive: true));

  File write(String name, String source) =>
      File('${temp.path}/$name')..writeAsStringSync(source);

  const repositorySource = '''
class FooRepository {
  Stream<void> watchFooChanges() => const Stream.empty();
}

class BareRepository {
  Stream<void> watchChanges() => const Stream.empty();
}
''';

  ScanResult scan(String providerSource) {
    final repository = write('repo.dart', repositorySource);
    final providers = write('providers.dart', providerSource);
    return scanForTickViolations(
      repositoryFiles: [repository],
      providerFiles: [providers],
      relativize: (path) => path.split('/').last,
    );
  }

  test('collects tick names including the bare watchChanges form', () {
    final result = scan('final unrelatedProvider = Provider<int>((ref) => 1);');
    expect(result.tickNames, {'watchFooChanges', 'watchChanges'});
    expect(result.tickDeclarationCount, 2);
  });

  test('flags a provider that calls a repository method with no tick', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.repositoryReadingProviders, 1);
    expect(result.violations, hasLength(1));
    expect(result.violations.single.provider, 'fooProvider');
    expect(result.violations.single.repositoryCall, 'repository.getFoo()');
  });

  test('accepts a provider that subscribes via invalidateSelfWhen', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchFooChanges());
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('accepts a raw listen subscription, the StateNotifier shape', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  final sub = repository.watchFooChanges().listen((_) {});
  ref.onDispose(sub.cancel);
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('accepts a tick reached through a same-file helper', () {
    final result = scan('''
void _subscribe(Ref ref) {
  ref.invalidateSelfWhen(ref.watch(fooRepositoryProvider).watchFooChanges());
}

final fooProvider = FutureProvider<int>((ref) async {
  _subscribe(ref);
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('ignores a provider that only passes a repository as an argument', () {
    final result = scan('''
final exportServiceProvider = Provider<ExportService>((ref) {
  final repository = ref.watch(fooRepositoryProvider);
  return ExportService(repository);
});
''');
    expect(result.repositoryReadingProviders, 0);
    expect(result.violations, isEmpty);
  });

  test('treats a directly constructed repository as a repository', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = FooRepository();
  return repository.getFoo();
});
''');
    expect(result.violations, hasLength(1));
  });

  test('honours a // no-tick: marker with a reason', () {
    final result = scan('''
// no-tick: read fresh at action time, never renders a cached value
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('rejects a // no-tick: marker with an empty reason', () {
    final result = scan('''
// no-tick:
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, hasLength(1));
  });

  test('reads the repository binding through ref.read as well as ref.watch', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.read(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, hasLength(1));
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/architecture/provider_tick_scanner_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package` / `provider_tick_scanner.dart` does not exist.

- [ ] **Step 4: Write the scanner**

Create `test/architecture/provider_tick_scanner.dart`:

```dart
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// A provider that invokes a repository method without subscribing to any
/// change tick.
class TickViolation {
  const TickViolation({
    required this.file,
    required this.line,
    required this.provider,
    required this.repositoryCall,
  });

  final String file;
  final int line;
  final String provider;
  final String repositoryCall;

  /// Stable key used by the architecture test's ratchet list.
  String get key => '$file::$provider';

  @override
  String toString() => '$file:$line  $provider  -> $repositoryCall';
}

class ScanResult {
  const ScanResult({
    required this.tickNames,
    required this.tickDeclarationCount,
    required this.violations,
    required this.repositoryReadingProviders,
  });

  final Set<String> tickNames;
  final int tickDeclarationCount;
  final List<TickViolation> violations;
  final int repositoryReadingProviders;
}

CompilationUnitAndLines _parse(File file) {
  final result = parseFile(
    path: file.absolute.path,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  return CompilationUnitAndLines(result.unit, result.lineInfo, result.content);
}

class CompilationUnitAndLines {
  CompilationUnitAndLines(this.unit, this.lineInfo, this.content);
  final CompilationUnit unit;
  final LineInfo lineInfo;
  final String content;
}

/// Collects `Stream<void> watchX()` method declarations.
class _TickDeclarations extends RecursiveAstVisitor<void> {
  final names = <String>{};
  var count = 0;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.returnType?.toSource() == 'Stream<void>' &&
        node.name.lexeme.startsWith('watch')) {
      names.add(node.name.lexeme);
      count++;
    }
    super.visitMethodDeclaration(node);
  }
}

/// Local identifiers bound to a repository, by any of the three shapes the
/// codebase uses: ref.watch(xRepositoryProvider), ref.read(...), or a bare
/// XRepository() constructor call.
class _RepositoryBindings extends RecursiveAstVisitor<void> {
  final ids = <String>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer is MethodInvocation) {
      final method = initializer.methodName.name;
      if (method == 'watch' || method == 'read') {
        final args = initializer.argumentList.arguments;
        if (args.length == 1 &&
            args.first.toSource().endsWith('RepositoryProvider')) {
          ids.add(node.name.lexeme);
        }
      }
    } else if (initializer is InstanceCreationExpression &&
        initializer.constructorName.type.toSource().endsWith('Repository')) {
      ids.add(node.name.lexeme);
    }
    super.visitVariableDeclaration(node);
  }
}

/// Every method invocation as (target source, method name).
class _Invocations extends RecursiveAstVisitor<void> {
  final calls = <({String? target, String method})>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    calls.add((target: node.target?.toSource(), method: node.methodName.name));
    super.visitMethodInvocation(node);
  }
}

class _TopLevelFunctions extends RecursiveAstVisitor<void> {
  final bodies = <String, AstNode>{};

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    bodies[node.name.lexeme] = node.functionExpression;
    super.visitFunctionDeclaration(node);
  }
}

final _noTickMarker = RegExp(r'//\s*no-tick:\s*(\S.*)$');

/// Scans [providerFiles] for providers that invoke a repository method without
/// referencing any change tick declared in [repositoryFiles].
ScanResult scanForTickViolations({
  required List<File> repositoryFiles,
  required List<File> providerFiles,
  required String Function(String) relativize,
}) {
  final ticks = _TickDeclarations();
  for (final file in repositoryFiles) {
    _parse(file).unit.accept(ticks);
  }

  final violations = <TickViolation>[];
  var readers = 0;

  for (final file in providerFiles) {
    final parsed = _parse(file);
    final lines = parsed.content.split('\n');
    final functions = _TopLevelFunctions();
    parsed.unit.accept(functions);

    for (final declaration
        in parsed.unit.declarations.whereType<TopLevelVariableDeclaration>()) {
      for (final variable in declaration.variables.variables) {
        if (!variable.name.lexeme.endsWith('Provider')) continue;
        final initializer = variable.initializer;
        if (initializer is! MethodInvocation) continue;

        final bindings = _RepositoryBindings();
        initializer.accept(bindings);
        if (bindings.ids.isEmpty) continue;

        final invocations = _Invocations();
        initializer.accept(invocations);

        // Reads only if a repository is the TARGET of a call. A repository
        // passed as an argument (service-constructor providers) does not count.
        final repositoryCall = invocations.calls
            .where((c) => c.target != null && bindings.ids.contains(c.target))
            .firstOrNull;
        if (repositoryCall == null) continue;
        readers++;

        if (_hasTick(invocations, functions, ticks.names)) continue;

        final line = parsed.lineInfo.getLocation(variable.offset).lineNumber;
        if (_hasNoTickMarker(lines, line)) continue;

        violations.add(
          TickViolation(
            file: relativize(file.path),
            line: line,
            provider: variable.name.lexeme,
            repositoryCall:
                '${repositoryCall.target}.${repositoryCall.method}()',
          ),
        );
      }
    }
  }

  violations.sort((a, b) => a.key.compareTo(b.key));
  return ScanResult(
    tickNames: ticks.names,
    tickDeclarationCount: ticks.count,
    violations: violations,
    repositoryReadingProviders: readers,
  );
}

bool _hasTick(
  _Invocations invocations,
  _TopLevelFunctions functions,
  Set<String> tickNames,
) {
  if (invocations.calls.any((c) => tickNames.contains(c.method))) return true;

  // One level of same-file helper resolution, so a shared helper that wires the
  // tick (statistics_providers.dart) and StateNotifier .listen() shapes pass.
  for (final call in invocations.calls) {
    if (call.target != null) continue;
    final body = functions.bodies[call.method];
    if (body == null) continue;
    final inner = _Invocations();
    body.accept(inner);
    if (inner.calls.any((c) => tickNames.contains(c.method))) return true;
  }
  return false;
}

/// Looks for `// no-tick: <reason>` on the lines immediately above the
/// declaration, skipping any doc comment that sits between marker and code.
bool _hasNoTickMarker(List<String> lines, int declarationLine) {
  for (var i = declarationLine - 2; i >= 0 && i >= declarationLine - 12; i--) {
    final text = lines[i].trim();
    if (text.isEmpty) return false;
    if (text.startsWith('///')) continue;
    final match = _noTickMarker.firstMatch(text);
    if (match != null) return match.group(1)!.trim().isNotEmpty;
    if (text.startsWith('//')) continue;
    return false;
  }
  return false;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/architecture/provider_tick_scanner_test.dart`
Expected: PASS, 10 tests.

If `// no-tick:` with an empty reason still passes, the regex `(\S.*)$` is not matching correctly — verify `_noTickMarker` requires at least one non-space character after the colon.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add pubspec.yaml pubspec.lock test/architecture/
git commit -m "test(architecture): add provider change-tick scanner

Parses Dart source with package:analyzer to find providers that invoke a
repository method without subscribing to a change tick. Distinguishes a
repository used as a method-invocation TARGET from one merely passed as a
constructor ARGUMENT, so service-constructor providers need no allowlist.

Scanner only; no assertion against lib/ yet. Part of #974."
```

---

## Task 2: Wire the scanner to `lib/` with a ratchet list

**Files:**
- Create: `test/architecture/provider_change_tick_test.dart`

**Interfaces:**
- Consumes: `scanForTickViolations`, `ScanResult`, `TickViolation` from Task 1.
- Produces: a `const _knownViolations` set of `'<relative path>::<providerName>'` keys that later tasks delete entries from.

The test asserts the scan result **equals** the known set. That fails in both directions: a new violation fails the build, and a fix that leaves a stale entry also fails, so the list cannot rot.

- [ ] **Step 1: Write the test**

Create `test/architecture/provider_change_tick_test.dart`. Generate `_knownViolations` by running the scanner once and printing keys — do not hand-type 137 entries.

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'provider_tick_scanner.dart';

/// Guards the project rule that a provider reading a table must self-invalidate
/// on that table's change tick (issue #974).
///
/// Writes reach the DB through paths that bypass every notifier --
/// DiveRepository.bulkDeleteDives (dive_merge_service, dive_consolidation_
/// service), sync pulls applying remote deletions, repository-level bulk edits.
/// None of them call ref.invalidate for a provider, so a provider that does not
/// subscribe serves a stale cache.
///
/// The test does NOT check WHICH tick a provider subscribes to. When fixing a
/// failure, do not reach for the nearest tick: a junction read such as
/// BuddyRepository.getDiveIdsForBuddy lives on the buddy repository but goes
/// stale on a DIVES cascade delete, so it needs watchDivesChanges().
///
/// Known limitation: this checks provider DECLARATIONS, not Notifier classes.
/// DiveListNotifier, PaginatedDiveListNotifier, and TripListNotifier subscribe
/// correctly with raw .listen() + ref.onDispose and are skipped here because
/// their provider bodies construct a class rather than calling repository
/// methods.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  final result = scanForTickViolations(
    repositoryFiles: dartFiles
        .where((f) => f.path.contains('/data/repositories/'))
        .toList(),
    providerFiles: dartFiles,
    relativize: (path) =>
        path.replaceFirst('${Directory.current.path}/', ''),
  );

  test('the scan found the repository, so it cannot pass vacuously', () {
    expect(dartFiles.length, greaterThan(1000));
    expect(result.tickDeclarationCount, greaterThanOrEqualTo(27));
    expect(result.repositoryReadingProviders, greaterThanOrEqualTo(200));
  });

  test('no provider reads a repository without subscribing to a tick', () {
    final actual = result.violations.map((v) => v.key).toSet();

    final unexpected = result.violations
        .where((v) => !_knownViolations.contains(v.key))
        .toList();
    expect(
      unexpected,
      isEmpty,
      reason:
          'New change-tick violations. Each provider below calls a repository '
          'method but never subscribes to a change tick, so it will serve a '
          'stale cache after a merge, a bulk delete, or a sync pull.\n\n'
          'Fix by adding, inside the provider body:\n'
          '  ref.invalidateSelfWhen(repository.watchXChanges());\n\n'
          'Pick the tick for the table the query actually READS, which is not '
          'always the tick owned by the repository the method lives on.\n\n'
          'If the provider genuinely cannot go stale (short-lived autoDispose '
          'read fresh at action time), mark it:\n'
          '  // no-tick: <why a stale cache can never render>\n\n'
          '${unexpected.join('\n')}',
    );

    final fixed = _knownViolations.difference(actual);
    expect(
      fixed,
      isEmpty,
      reason:
          'These providers were fixed but are still listed in '
          '_knownViolations. Delete them from that set:\n'
          '${(fixed.toList()..sort()).join('\n')}',
    );
  });
}

/// Violations present when this test was introduced, being burned down under
/// issue #974. Only ever gets smaller. When it reaches zero, delete it and the
/// two `_knownViolations` references above.
const _knownViolations = <String>{
  // GENERATED IN STEP 2 -- see instructions.
};
```

- [ ] **Step 2: Generate the ratchet list**

Temporarily replace the body of the second test with a printer, run it, and paste the output into `_knownViolations`:

```dart
  test('print', () {
    for (final v in result.violations) {
      print("  '${v.key}',");
    }
  });
```

Run: `flutter test test/architecture/provider_change_tick_test.dart --plain-name print`

Paste the 137 printed lines into `_knownViolations`, then restore the real test body. Sort the entries so later deletions produce clean diffs.

- [ ] **Step 3: Run the test to verify it passes**

Run: `flutter test test/architecture/provider_change_tick_test.dart`
Expected: PASS, 2 tests. If the count differs from 137, the tree moved since planning — reconcile before continuing rather than editing the assertion.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add test/architecture/provider_change_tick_test.dart
git commit -m "test(architecture): enforce the change-tick convention across lib

Asserts the violation set EQUALS a seeded ratchet list, so a new violation
fails the build and a fix that leaves a stale entry also fails. The list
starts at 137 and is burned down by the following commits.

Refs #974."
```

---

## Task 3: Statistics -- replace the version counter with a real tick

This is the mechanism swap, not a one-liner. It removes **36** ratchet entries: 33 in `statistics_providers.dart`, 2 in `dashboard_providers.dart`, 1 in `plan_canvas_providers.dart`.

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (add tick)
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart:35-42` (`_keepAliveWithExpiry`)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart:239-243, 743-748` (delete `statisticsVersionProvider`)
- Modify: `lib/features/dashboard/presentation/providers/dashboard_providers.dart:190, 248`
- Modify: `lib/features/planner/presentation/providers/plan_canvas_providers.dart:49`
- Test: `test/features/statistics/statistics_tick_reactivity_test.dart`

**Interfaces:**
- Produces: `Stream<void> StatisticsRepository.watchStatisticsChanges()`.
- Removes: `statisticsVersionProvider` (was `dive_providers.dart:243`) and `PaginatedDiveListNotifier._invalidateStatistics()`'s increment.

**Why a new tick rather than `watchDivesChanges()`:** the statistics SQL reads 15 tables. `dive_tanks` alone appears 11 times — that is all of the SAC math. `watchDivesChanges()` watches only the `dives` table, so a sync applying a tank-pressure-only changeset would leave every SAC chart stale. `watchDiveDetailChanges()` is the opposite error: it fires on media, tide records, and safety findings, which statistics never read.

- [ ] **Step 1: Write the failing regression test**

Create `test/features/statistics/statistics_tick_reactivity_test.dart`. Follow the existing repository-test setup in `test/` for in-memory Drift construction; the assertion is that a write bypassing every notifier still ticks.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  test('watchStatisticsChanges ticks on a dive_tanks write', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final repository = StatisticsRepository();

    final ticks = <void>[];
    final sub = repository.watchStatisticsChanges().listen(ticks.add);
    addTearDown(sub.cancel);

    await insertDiveWithTank(db);
    // changeTickDebounce is 300ms; wait past it.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(ticks, isNotEmpty);
  });

  test('watchStatisticsChanges ticks on a bulk dive delete', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final repository = StatisticsRepository();
    final diveId = await insertDiveWithTank(db);

    final ticks = <void>[];
    final sub = repository.watchStatisticsChanges().listen(ticks.add);
    addTearDown(sub.cancel);

    // The path used by dive_merge_service and dive_consolidation_service,
    // which bypasses every notifier.
    await db.dives.deleteWhere((t) => t.id.equals(diveId));
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(ticks, isNotEmpty);
  });
}
```

Adapt `createTestDatabase` / `insertDiveWithTank` to whatever the existing helpers in `test/helpers/` provide; inspect a neighbouring repository test first and reuse its fixture rather than inventing one.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/statistics_tick_reactivity_test.dart`
Expected: FAIL — `The method 'watchStatisticsChanges' isn't defined for the type 'StatisticsRepository'`.

- [ ] **Step 3: Add the tick to StatisticsRepository**

Add these imports to `lib/features/statistics/data/repositories/statistics_repository.dart`:

```dart
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
```

Add the method next to the `_db` getter at line 60:

```dart
  /// Emits whenever any table the statistics queries read is written, so every
  /// statistics provider refreshes after a merge, a bulk delete, an import, or
  /// a sync pull -- none of which go through a notifier.
  ///
  /// Broader than `watchDivesChanges` because the aggregate SQL joins well
  /// beyond the `dives` table: `dive_tanks` and `tank_pressure_profiles` carry
  /// all of the SAC math, `sightings`/`species` the marine-life stats,
  /// `dive_sites`/`dive_centers`/`trips` the geographic stats. Narrower than
  /// `watchDiveDetailChanges`, which also fires on media, tide records, and
  /// safety findings that no statistic reads.
  ///
  /// Replaces `statisticsVersionProvider`, a counter incremented from exactly
  /// one line in the app, which merge, consolidate, import, and sync never
  /// reached (issue #974).
  Stream<void> watchStatisticsChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveProfiles),
          TableUpdateQuery.onTable(_db.diveTanks),
          TableUpdateQuery.onTable(_db.tankPressureProfiles),
          TableUpdateQuery.onTable(_db.diveEquipment),
          TableUpdateQuery.onTable(_db.equipment),
          TableUpdateQuery.onTable(_db.diveWeights),
          TableUpdateQuery.onTable(_db.diveDiveTypes),
          TableUpdateQuery.onTable(_db.diveBuddies),
          TableUpdateQuery.onTable(_db.buddies),
          TableUpdateQuery.onTable(_db.sightings),
          TableUpdateQuery.onTable(_db.species),
          TableUpdateQuery.onTable(_db.diveSites),
          TableUpdateQuery.onTable(_db.diveCenters),
          TableUpdateQuery.onTable(_db.trips),
        ]),
      )
      .debounce(DiveRepository.changeTickDebounce);
```

Verify each table getter name against `lib/core/database/database.dart` before running; `diveWeights` and `diveDiveTypes` in particular must match the generated Drift accessor names exactly.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/statistics/statistics_tick_reactivity_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Rewire `_keepAliveWithExpiry`**

In `lib/features/statistics/presentation/providers/statistics_providers.dart`, replace lines 32-42:

```dart
/// Adds keepAlive with a 5-minute expiry and subscribes to the statistics
/// change tick, so all stats providers stay cached across navigations but
/// refresh whenever any table they read is written.
///
/// This used to watch `statisticsVersionProvider`, a counter incremented from
/// exactly one line inside PaginatedDiveListNotifier. Merge, consolidate,
/// import, and sync pulls never bumped it, so the cache the doc comment
/// claimed was reactive was in fact stale for up to five minutes (#974).
void _keepAliveWithExpiry(Ref ref) {
  ref.invalidateSelfWhen(
    ref.watch(statisticsRepositoryProvider).watchStatisticsChanges(),
  );
  // Keep alive for 5 minutes after last listener detaches
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
}
```

The scanner resolves same-file helpers one level deep, so all 33 callers become compliant through this single edit.

- [ ] **Step 6: Delete `statisticsVersionProvider`**

In `lib/features/dive_log/presentation/providers/dive_providers.dart`, delete lines 239-243 entirely:

```dart
/// Version counter for statistics cache invalidation.
///
/// All statistics providers watch this. Bumping the version causes all of them
/// to re-fetch, while keepAlive prevents disposal between navigations.
final statisticsVersionProvider = StateProvider<int>((ref) => 0);
```

And at line 743, reduce `_invalidateStatistics` to:

```dart
  /// Invalidate the dive-level stats provider. Every other statistics provider
  /// now self-invalidates on StatisticsRepository.watchStatisticsChanges(), so
  /// there is no version counter to bump.
  void _invalidateStatistics() {
    _ref.invalidate(diveStatisticsProvider);
  }
```

- [ ] **Step 7: Convert the three remaining version-counter readers**

`lib/features/dashboard/presentation/providers/dashboard_providers.dart:190` — replace `ref.watch(statisticsVersionProvider);` with the tick, so `yearInReviewProvider` opens:

```dart
final yearInReviewProvider = FutureProvider<YearInReview?>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchStatisticsChanges());
  final diverId = ref.watch(currentDiverIdProvider);
```

Delete the now-duplicated `final repository = ref.watch(statisticsRepositoryProvider);` line that followed.

Same file at line 248, `dashboardQuickStatsProvider`: replace `ref.watch(statisticsVersionProvider);` the same way, and delete the trailing sentence of its doc comment that reads "[statisticsVersionProvider] is watched explicitly to preserve the dive-mutation reactivity that used to arrive transitively through those three providers." Replace with: "The statistics change tick preserves the dive-mutation reactivity that used to arrive transitively through those three providers."

`lib/features/planner/presentation/providers/plan_canvas_providers.dart:49`, `loggedAverageSacProvider` — a non-autoDispose provider with no invalidation of any kind, cached for the process lifetime:

```dart
final loggedAverageSacProvider = FutureProvider<double?>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchStatisticsChanges());
  final sacByRole = await repository.getSacVolumeByTankRole();
  return sacByRole['backGas'] ??
      (sacByRole.isEmpty ? null : sacByRole.values.first);
});
```

- [ ] **Step 8: Delete the 36 ratchet entries and verify**

Remove from `_knownViolations` every key starting `lib/features/statistics/presentation/providers/statistics_providers.dart::`, plus:

```
lib/features/dashboard/presentation/providers/dashboard_providers.dart::yearInReviewProvider
lib/features/dashboard/presentation/providers/dashboard_providers.dart::dashboardQuickStatsProvider
lib/features/planner/presentation/providers/plan_canvas_providers.dart::loggedAverageSacProvider
```

Run: `flutter test test/architecture/ && flutter analyze`
Expected: architecture tests PASS; analyze reports no unused `statisticsVersionProvider` references. If analyze flags an unused import of `dive_providers.dart` anywhere, remove it.

- [ ] **Step 9: Measure the invalidation cost**

The spec flags this as verify-not-assume. Run the full test suite and time it:

Run: `flutter test test/features/statistics/ test/performance/ 2>&1 | tail -20`

Expected: no timeouts, no test slower than before. The concern is that 33 kept-alive aggregate providers now invalidate on every statistics-table write, and a bulk import fires many. Riverpod should not recompute a provider with no listeners, and `changeTickDebounce` coalesces bursts. **If the suite slows materially or a bulk-import test times out, stop and report** — the statistics fix then needs a different shape (for example, dropping `keepAlive` so invalidation cannot outlive the listener).

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/ test/features/statistics/
git add lib/ test/
git commit -m "fix(statistics): replace the version counter with a real change tick

statisticsVersionProvider was incremented from exactly one line in the app,
inside PaginatedDiveListNotifier. Merge, consolidate, import, and sync pulls
never reached it, so 33 statistics providers, 2 dashboard providers, and the
planner's logged-SAC provider served stale caches while their doc comment
claimed they refreshed on dive mutation.

Adds StatisticsRepository.watchStatisticsChanges() over the 15 tables the
aggregate SQL actually reads, wires it into _keepAliveWithExpiry, and deletes
the counter so no second broken mechanism remains.

Refs #974."
```

---

## Task 4: Add tick streams to the remaining repositories

**Files (create the stream in each):**

| Repository | New tick | Tables to watch | Unblocks |
| --- | --- | --- | --- |
| `dive_log/data/repositories/dive_computer_repository.dart` | `watchComputersChanges()` | `diveComputers` | 5 providers |
| `equipment/data/repositories/service_record_repository.dart` | `watchServiceRecordsChanges()` | `gearServiceRecords` | 5 providers |
| `cylinder_configs/data/repositories/cylinder_config_repository.dart` | `watchConfigsChanges()` | the cylinder-config table + `equipment` | 3 providers |
| `maps/data/repositories/offline_map_repository.dart` | `watchRegionsChanges()` | the cached-region table | 2 providers |
| `trips/data/repositories/liveaboard_details_repository.dart` | `watchLiveaboardChanges()` | liveaboard details table | 1 provider |
| `trips/data/repositories/itinerary_day_repository.dart` | `watchItineraryChanges()` | itinerary day table | 1 provider |
| `dive_log/data/repositories/dive_custom_field_repository.dart` | `watchCustomFieldsChanges()` | custom field table | 1 provider |
| `dive_log/data/repositories/view_config_repository.dart` | `watchPresetsChanges()` | table-preset table | 1 provider |
| `media_store/data/repositories/media_stores_repository.dart` | `watchStoresChanges()` | media stores table | 1 provider |
| `universal_import/data/repositories/csv_preset_repository.dart` | `watchPresetsChanges()` | CSV preset table | 1 provider |
| `settings/data/repositories/app_settings_repository.dart` | `watchSettingsChanges()` | settings table | 1 provider |

Exact file paths and table getter names must be confirmed by opening each repository; the paths above are derived from the provider that binds them and may differ.

**Not given a tick — exempted instead** (handled in Task 5, listed here so the decision is recorded in one place):

| Provider | Reason for `// no-tick:` |
| --- | --- |
| `bathymetry/application/bathymetry_providers.dart::bathymetryGridProvider` | Immutable bathymetry grid cache keyed by region; contents never change in place |
| `gps_log/.../gps_track_map_providers.dart::gpsTrackGeometryProvider` | Derived geometry cache keyed by track id; a track's geometry is written once |

Confirm both by reading the repository before exempting. If either can be written in place after first read, give it a tick instead.

- [ ] **Step 1: Write a tick test for the first repository**

For `DiveComputerRepository`, create or extend its existing test:

```dart
test('watchComputersChanges ticks on a dive_computers write', () async {
  final db = createTestDatabase();
  addTearDown(db.close);
  final repository = DiveComputerRepository();
  final ticks = <void>[];
  final sub = repository.watchComputersChanges().listen(ticks.add);
  addTearDown(sub.cancel);

  await insertDiveComputer(db);
  await Future<void>.delayed(const Duration(milliseconds: 500));

  expect(ticks, isNotEmpty);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/ --plain-name watchComputersChanges`
Expected: FAIL — method not defined.

- [ ] **Step 3: Add the stream**

Pattern for every repository in the table, matching `DiveRepository.watchDivesChanges()`:

```dart
  /// Emits whenever the `dive_computers` table changes, so providers reading it
  /// refresh after a sync or any other write that bypasses the notifiers.
  /// [DiveRepository.changeTickDebounce]-debounced so a multi-changeset sync
  /// coalesces into a single refresh.
  Stream<void> watchComputersChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.diveComputers))
      .debounce(DiveRepository.changeTickDebounce);
```

Required imports in each repository that does not already have them:

```dart
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
```

If importing `dive_repository_impl.dart` for the debounce constant creates a cycle in any repository, inline `const Duration(milliseconds: 300)` with a comment pointing at `DiveRepository.changeTickDebounce` instead.

- [ ] **Step 4: Run to verify it passes, then repeat Steps 1-4 for each remaining repository**

Expected: PASS. Work down the table one repository at a time.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
flutter test test/features/
git add lib/ test/
git commit -m "feat(repositories): add change-tick streams to 11 repositories

None of these repositories exposed a tick, so the providers reading them had
nothing to subscribe to. Each stream watches the tables its repository reads
and is debounced by changeTickDebounce, matching DiveRepository.

No provider changes yet. Refs #974."
```

---

## Task 5: Fix providers -- dive_log, dive computers, statistics-adjacent

Removes 15 ratchet entries.

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart`
- Modify: `lib/features/dive_log/presentation/providers/dive_computer_providers.dart`
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart`
- Modify: `lib/features/dive_log/presentation/providers/view_config_providers.dart`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart`

**Interfaces:**
- Consumes: `watchComputersChanges()`, `watchCustomFieldsChanges()`, `watchPresetsChanges()` from Task 4.

The edit shape, applied to every row below — insert one line into the provider body after the repository binding:

```dart
final diveRecordsProvider = FutureProvider<DiveRecords>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  return repository.getRecords(diverId: currentDiverId);
});
```

| File | Line | Provider | Tick to add |
| --- | --- | --- | --- |
| `dive_providers.dart` | 72 | `orderedDiveIdsProvider` | `repository.watchDivesChanges()` |
| `dive_providers.dart` | 171 | `customFieldKeySuggestionsProvider` | `repository.watchCustomFieldsChanges()` |
| `dive_providers.dart` | 263 | `diveRecordsProvider` | `repository.watchDivesChanges()` |
| `dive_providers.dart` | 270 | `nextDiveNumberProvider` | **`// no-tick:` — short-lived autoDispose read fresh at action time; a stale value never renders** |
| `dive_providers.dart` | 282 | `diveSearchProvider` | `repository.watchDivesChanges()` |
| `dive_providers.dart` | 992 | `diveNumberingInfoProvider` | `repository.watchDivesChanges()` |
| `dive_computer_providers.dart` | 14 | `allDiveComputersProvider` | `repository.watchComputersChanges()` |
| `dive_computer_providers.dart` | 41 | `diveComputerByIdProvider` | `repository.watchComputersChanges()` |
| `dive_computer_providers.dart` | 50 | `favoriteDiveComputerProvider` | `repository.watchComputersChanges()` |
| `dive_computer_providers.dart` | 69 | `primaryComputerIdProvider` | `repository.watchComputersChanges()` |
| `profile_analysis_provider.dart` | 37 | `diveComputerEventsProvider` | `repository.watchDiveDetailChanges()` — reads per-dive events |
| `profile_analysis_provider.dart` | 1346 | `weeklyOtuProvider` | `repository.watchDivesChanges()` — hoist the `ref.watch` + tick above the `try` block |
| `view_config_providers.dart` | 341 | `tablePresetsProvider` | `repo.watchPresetsChanges()` (note the local is named `repo`) |
| `download_providers.dart` | 337 | `computerDiveIdsProvider` | `repository.watchComputersChanges()` |
| `download_providers.dart` | 361 | `firstSyncCutoffDefaultProvider` | **`// no-tick:` — read once at wizard start to seed a default; the user edits it thereafter** |

- [ ] **Step 1: Apply every edit in the table**

- [ ] **Step 2: Delete the 15 corresponding keys from `_knownViolations`**

- [ ] **Step 3: Run the architecture test**

Run: `flutter test test/architecture/provider_change_tick_test.dart`
Expected: PASS. A failure naming a provider you edited means the tick method name is wrong — check it against the repository.

- [ ] **Step 4: Run the affected feature tests**

Run: `flutter test test/features/dive_log/ test/dives/`
Expected: PASS. A newly-reactive provider can break a widget test that assumed a stale value; if one fails, fix the test, not the tick.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/ test/
git commit -m "fix(dive_log): subscribe dive-log providers to their change ticks

orderedDiveIdsProvider feeds prev/next navigation and nothing in the app
invalidated it, so after merging from the detail page 'next' navigated to a
deleted dive. diveRecordsProvider sat directly beneath diveStatisticsProvider,
whose doc comment cites #217 as the reason it has a tick.

Refs #974."
```

---

## Task 6: Fix providers -- buddies, trips, courses (closes #958 and #970)

Removes 21 ratchet entries.

**Files:**
- Modify: `lib/features/buddies/presentation/providers/buddy_providers.dart`
- Modify: `lib/features/trips/presentation/providers/trip_providers.dart`
- Modify: `lib/features/trips/presentation/providers/liveaboard_providers.dart`
- Modify: `lib/features/courses/presentation/providers/course_providers.dart`

Every file here already imports `core/providers/provider.dart` and a dive repository provider module — no new imports needed.

**The junction-read cases.** `getDiveIdsForBuddy`, `getBuddyStats`, `getDiveIdsForTrip`, `getTripWithStats`, and `getDiveCountForCourse` live on the buddy/trip/course repository but query `dive_buddies` / `trips` / junction tables that go stale on a **dives** cascade delete. Those need **both** ticks. The existing correct model is `allBuddiesWithDiveCountProvider` at `buddy_providers.dart:50`:

```dart
      ref.invalidateSelfWhen(repository.watchBuddiesChanges());
      ref.invalidateSelfWhen(
        ref.read(diveRepositoryProvider).watchDivesChanges(),
      );
```

| File | Line | Provider | Ticks to add |
| --- | --- | --- | --- |
| `buddy_providers.dart` | 127 | `buddyByIdProvider` | `watchBuddiesChanges()` |
| `buddy_providers.dart` | 146 | `buddySearchProvider` | `watchBuddiesChanges()` |
| `buddy_providers.dart` | 161 | `buddyStatsProvider` | `watchBuddiesChanges()` **+ dives** |
| `buddy_providers.dart` | 170 | `diveIdsForBuddyProvider` | `watchBuddiesChanges()` **+ dives** |
| `trip_providers.dart` | 67 | `allTripsWithStatsProvider` | `watchTripsChanges()` **+ dives** |
| `trip_providers.dart` | 177 | `tripByIdProvider` | `watchTripsChanges()` |
| `trip_providers.dart` | 186 | `tripWithStatsProvider` | `watchTripsChanges()` **+ dives** |
| `trip_providers.dart` | 199 | `diveIdsForTripProvider` | `watchTripsChanges()` **+ dives** |
| `trip_providers.dart` | 212 | `divesForTripProvider` | `watchTripsChanges()` **+ dives**, and route the repository through the provider (below) |
| `trip_providers.dart` | 228 | `tripSearchProvider` | `watchTripsChanges()` |
| `trip_providers.dart` | 243 | `tripForDateProvider` | `watchTripsChanges()` |
| `liveaboard_providers.dart` | 20 | `liveaboardDetailsProvider` | `watchLiveaboardChanges()` |
| `liveaboard_providers.dart` | 27 | `itineraryDaysProvider` | `watchItineraryChanges()` |
| `course_providers.dart` | 38 | `inProgressCoursesProvider` | `watchCoursesChanges()` |
| `course_providers.dart` | 47 | `completedCoursesProvider` | `watchCoursesChanges()` |
| `course_providers.dart` | 109 | `courseByIdProvider` | `watchCoursesChanges()` |
| `course_providers.dart` | 130 | `courseForCertificationProvider` | `watchCoursesChanges()` |
| `course_providers.dart` | 139 | `courseDivesProvider` | `watchDivesChanges()` — already binds `diveRepositoryProvider` |
| `course_providers.dart` | 148 | `courseDiveCountProvider` | `watchCoursesChanges()` **+ dives** |
| `course_providers.dart` | 157 | `coursesByAgencyProvider` | `watchCoursesChanges()` |
| `course_providers.dart` | 170 | `courseSearchProvider` | `watchCoursesChanges()` |

- [ ] **Step 1: Route `divesForTripProvider` through the repository provider**

`trip_providers.dart:212` constructs `DiveRepository()` inline, which bypasses any test override. Replace:

```dart
final divesForTripProvider = FutureProvider.family<List<domain.Dive>, String>((
  ref,
  tripId,
) async {
  final tripRepository = ref.watch(tripRepositoryProvider);
  final diveRepository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(tripRepository.watchTripsChanges());
  ref.invalidateSelfWhen(diveRepository.watchDivesChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final diveIds = await tripRepository.getDiveIdsForTrip(
    tripId,
    diverId: diverId,
  );
  if (diveIds.isEmpty) return [];
  return diveRepository.getDivesByIds(diveIds);
});
```

- [ ] **Step 2: Route `_equipmentFilteredTripsProvider` through the provider**

`trip_providers.dart:78` constructs `EquipmentRepository()` inline. Replace that line with `final equipmentRepository = ref.watch(equipmentRepositoryProvider);` and add `ref.invalidateSelfWhen(equipmentRepository.watchEquipmentChanges());`. Add the import for `equipment_providers.dart` only if `equipmentRepositoryProvider` is not already reachable; if that creates a cycle, keep the direct construction and instead add the tick via `EquipmentRepository().watchEquipmentChanges()` with a comment explaining why.

- [ ] **Step 3: Apply the remaining table rows**

- [ ] **Step 4: Delete the 21 corresponding keys from `_knownViolations`**

- [ ] **Step 5: Run architecture and feature tests**

Run: `flutter test test/architecture/ test/features/trips/ test/features/courses/ test/features/buddies/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/ test/
git commit -m "fix(trips,courses,buddies): subscribe to change ticks

Closes the symptom in #958 (trips) and #970 (courses): the header dive count
and the dive list below it disagreed after a merge, because the count provider
and the list provider subscribed to different things.

Junction reads take BOTH their own repository's tick and the dives tick, since
getDiveIdsForBuddy and friends go stale on a dives cascade delete without the
buddies table ever being written.

Also routes divesForTripProvider and _equipmentFilteredTripsProvider through
their repository providers instead of constructing repositories inline, which
restores test overridability.

Closes #958. Closes #970. Refs #974."
```

---

## Task 7: Fix providers -- equipment, cylinder configs, tank presets

Removes 19 ratchet entries.

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart`
- Modify: `lib/features/equipment/presentation/providers/equipment_set_providers.dart`
- Modify: `lib/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart`
- Modify: `lib/features/tank_presets/presentation/providers/tank_preset_providers.dart`

`equipment_providers.dart` does **not** import a dive repository provider and has zero `diveRepositoryProvider` references. Add:

```dart
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
```

Use that module, not `dive_providers.dart` — `dive_providers.dart` imports `trip_providers.dart`, which imports `equipment_repository_impl.dart`, so importing it here risks a cycle.

| File | Line | Provider | Ticks to add |
| --- | --- | --- | --- |
| `equipment_providers.dart` | 30 | `activeEquipmentProvider` | `watchEquipmentChanges()` |
| `equipment_providers.dart` | 41 | `retiredEquipmentProvider` | `watchEquipmentChanges()` |
| `equipment_providers.dart` | 161 | `equipmentItemProvider` | `watchEquipmentChanges()` |
| `equipment_providers.dart` | 170 | `equipmentDiveCountProvider` | `watchEquipmentChanges()` **+ dives** |
| `equipment_providers.dart` | 179 | `equipmentTripCountProvider` | `watchEquipmentChanges()` **+ trips** |
| `equipment_providers.dart` | 188 | `equipmentTripIdsProvider` | `watchEquipmentChanges()` **+ trips** |
| `equipment_providers.dart` | 209 | `equipmentSearchProvider` | `watchEquipmentChanges()` |
| `equipment_providers.dart` | 338 | `serviceRecordsForEquipmentProvider` | `watchServiceRecordsChanges()` |
| `equipment_providers.dart` | 348 | `serviceRecordByIdProvider` | `watchServiceRecordsChanges()` |
| `equipment_providers.dart` | 356 | `mostRecentServiceRecordProvider` | `watchServiceRecordsChanges()` |
| `equipment_providers.dart` | 364 | `serviceRecordTotalCostProvider` | `watchServiceRecordsChanges()` |
| `equipment_providers.dart` | 374 | `serviceRecordCountProvider` | `watchServiceRecordsChanges()` |
| `equipment_set_providers.dart` | 68 | `equipmentSetGeofencesProvider` | `watchSetChanges()` |
| `equipment_set_providers.dart` | 89 | `equipmentSetSelectionInputsProvider` | `watchSetChanges()` |
| `cylinder_config_providers.dart` | 19 | `cylinderConfigsProvider` | `watchConfigsChanges()` |
| `cylinder_config_providers.dart` | 33 | `cylinderConfigsForEquipmentProvider` | `watchConfigsChanges()` |
| `cylinder_config_providers.dart` | 43 | `cylinderConfigProvider` | `watchConfigsChanges()` |
| `tank_preset_providers.dart` | 30 | `customTankPresetsProvider` | `watchTankPresetsChanges()` |
| `tank_preset_providers.dart` | 41 | `tankPresetProvider` | `watchTankPresetsChanges()` |

Note the trips tick for `equipmentTripCountProvider` / `equipmentTripIdsProvider` needs `tripRepositoryProvider`, which `equipment_providers.dart` already imports (`trip_providers.dart`, line 19 of its import list).

- [ ] **Step 1: Add the import and apply every table row**

- [ ] **Step 2: Delete the 19 corresponding keys from `_knownViolations`**

- [ ] **Step 3: Run architecture and equipment tests**

Run: `flutter test test/architecture/ test/features/equipment/`
Expected: PASS. Watch for an import-cycle analyze error; if one appears, the wrong dive-repository module was imported.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/
git commit -m "fix(equipment): subscribe equipment providers to their change ticks

equipmentDiveCountProvider backs the 'Used on N dives' figure and had no
invalidation of any kind, so it over-counted after a merge. activeEquipment
and retiredEquipment sat ten lines above allEquipmentProvider, which already
had the tick.

Service-record providers take the new watchServiceRecordsChanges tick; the
dive- and trip-count providers take the dives and trips ticks, since a cascade
delete never writes the equipment table.

Refs #974."
```

---

## Task 8: Fix providers -- sites, species, media, tags, dive types, dive centres, divers, certifications

Removes 39 ratchet entries.

**Files:**
- Modify: `dive_sites/.../site_providers.dart`, `marine_life/.../species_providers.dart`, `media/.../media_providers.dart`, `media_store/.../media_store_providers.dart`, `tags/.../tag_providers.dart`, `dive_types/.../dive_type_providers.dart`, `dive_centers/.../dive_center_providers.dart`, `divers/.../diver_providers.dart`, `certifications/.../certification_providers.dart`

| File | Line | Provider | Ticks to add |
| --- | --- | --- | --- |
| `site_providers.dart` | 273 | `siteProvider` | `watchSitesChanges()` |
| `site_providers.dart` | 282 | `siteSearchProvider` | `watchSitesChanges()` |
| `species_providers.dart` | 21 | `speciesByCategoryProvider` | `watchSpeciesChanges()` |
| `species_providers.dart` | 31 | `speciesSearchProvider` | `watchSpeciesChanges()` |
| `species_providers.dart` | 43 | `speciesProvider` | `watchSpeciesChanges()` |
| `species_providers.dart` | 154 | `seedSpeciesProvider` | **`// no-tick:` — a one-shot seeding action, not a cache; ticking it would re-run the seed** |
| `species_providers.dart` | 253 | `siteSpottedSpeciesProvider` | `watchSpeciesChanges()` **+ dive detail** (derived from sightings) |
| `species_providers.dart` | 263 | `siteExpectedSpeciesProvider` | `watchSpeciesChanges()` |
| `media_providers.dart` | 39 | `mediaByIdProvider` | `watchMediaChanges()` |
| `media_providers.dart` | 48 | `mediaCountForDiveProvider` | `watchMediaChanges()` |
| `media_providers.dart` | 57 | `pendingSuggestionCountProvider` | `watchMediaChanges()` |
| `media_providers.dart` | 66 | `orphanedMediaProvider` | `watchMediaChanges()` |
| `media_providers.dart` | 75 | `divePhotoGpsProvider` | `watchMediaChanges()` |
| `media_providers.dart` | 85 | `allDivePhotoGpsProvider` | `watchMediaChanges()` |
| `media_store_providers.dart` | 131 | `mediaVerifyRunnerProvider` | `watchStoresChanges()` |
| `media_store_providers.dart` | 231 | `mediaBadgeStateProvider` | `watchMediaChanges()` |
| `media_store_providers.dart` | 308 | `mediaStoreRuntimeProvider` | `watchMediaChanges()` |
| `tag_providers.dart` | 29 | `tagProvider` | `watchTagsChanges()` |
| `tag_providers.dart` | 46 | `tagsForDiveProvider` | `watchTagsChanges()` **+ dive detail** |
| `tag_providers.dart` | 55 | `tagSearchProvider` | `watchTagsChanges()` |
| `dive_type_providers.dart` | 29 | `builtInDiveTypesProvider` | `watchDiveTypesChanges()` |
| `dive_type_providers.dart` | 37 | `customDiveTypesProvider` | `watchDiveTypesChanges()` |
| `dive_type_providers.dart` | 48 | `diveTypeProvider` | `watchDiveTypesChanges()` |
| `dive_type_providers.dart` | 57 | `diveTypeStatisticsProvider` | `watchDiveTypesChanges()` **+ dives** |
| `dive_center_providers.dart` | 78 | `diveCenterByIdProvider` | `watchDiveCentersChanges()` |
| `dive_center_providers.dart` | 87 | `diveCentersWithCoordinatesProvider` | `watchDiveCentersChanges()` |
| `dive_center_providers.dart` | 98 | `diveCenterSearchProvider` | `watchDiveCentersChanges()` |
| `dive_center_providers.dart` | 111 | `diveCentersByCountryProvider` | `watchDiveCentersChanges()` |
| `dive_center_providers.dart` | 124 | `diveCenterCountriesProvider` | `watchDiveCentersChanges()` |
| `diver_providers.dart` | 47 | `diverByIdProvider` | `watchDiversChanges()` |
| `diver_providers.dart` | 178 | `currentDiverProvider` | `watchDiversChanges()` |
| `diver_providers.dart` | 194 | `validatedCurrentDiverIdProvider` | `watchDiversChanges()` |
| `diver_providers.dart` | 288 | `diverDiveCountProvider` | `watchDiversChanges()` **+ dives** |
| `diver_providers.dart` | 297 | `diverTotalBottomTimeProvider` | `watchDiversChanges()` **+ dives** |
| `certification_providers.dart` | 109 | `certificationByIdProvider` | `watchCertificationsChanges()` |
| `certification_providers.dart` | 117 | `certificationSearchProvider` | `watchCertificationsChanges()` |
| `certification_providers.dart` | 130 | `expiringCertificationsProvider` | `watchCertificationsChanges()` |
| `certification_providers.dart` | 143 | `expiredCertificationsProvider` | `watchCertificationsChanges()` |
| `certification_providers.dart` | 154 | `certificationsByAgencyProvider` | `watchCertificationsChanges()` |

**Care needed on `validatedCurrentDiverIdProvider`** (`diver_providers.dart:194`). Dozens of providers `await ref.watch(validatedCurrentDiverIdProvider.future)`, so making it reactive cascades widely. Run the full suite after this one, not just the diver tests. If it destabilises widget tests, exempt it with `// no-tick: diver identity is realigned explicitly by realignActiveDiverAfterDataReplace; a tick here re-runs every diver-scoped query in the app` and record the decision in the PR.

- [ ] **Step 1: Apply every table row**

- [ ] **Step 2: Delete the 39 corresponding keys from `_knownViolations`**

- [ ] **Step 3: Run the FULL test suite**

Run: `flutter test`
Expected: PASS. This task makes widely-consumed providers reactive; a failure here is most likely a widget test that pumped once and asserted on a value that now refreshes.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/
git commit -m "fix(providers): subscribe reference-data providers to their ticks

Sites, species, media, tags, dive types, dive centres, divers, and
certifications all had providers reading their tables with no subscription, so
a sync pull left detail pages showing pre-sync values.

Providers over junction reads (diverDiveCount, diveTypeStatistics,
siteSpottedSpecies, tagsForDive) take the dives or dive-detail tick as well as
their own, since a cascade delete never writes their own table.

Refs #974."
```

---

## Task 9: Fix the remaining stragglers

Removes 7 ratchet entries.

**Files:**
- Modify: `bathymetry/application/bathymetry_providers.dart`
- Modify: `gps_log/.../gps_track_map_providers.dart`
- Modify: `maps/.../offline_map_providers.dart`
- Modify: `settings/.../settings_providers.dart`
- Modify: `universal_import/.../csv_preset_providers.dart`
- Modify: `planner/presentation/pages/plan_compare_page.dart`

| File | Line | Provider | Resolution |
| --- | --- | --- | --- |
| `bathymetry_providers.dart` | 48 | `bathymetryGridProvider` | `// no-tick: immutable bathymetry grid cache keyed by region; a grid is written once and never updated in place` |
| `gps_track_map_providers.dart` | 46 | `gpsTrackGeometryProvider` | `// no-tick: derived geometry cache keyed by track id; a track's geometry is written once on import` |
| `offline_map_providers.dart` | 19 | `cachedRegionsProvider` | `watchRegionsChanges()` |
| `offline_map_providers.dart` | 201 | `cachedRegionByIdProvider` | `watchRegionsChanges()` |
| `settings_providers.dart` | 894 | `shareByDefaultProvider` | `watchSettingsChanges()` |
| `csv_preset_providers.dart` | 13 | `userCsvPresetsProvider` | `watchPresetsChanges()` |
| `plan_compare_page.dart` | 31 | `planComparisonProvider` | `watchPlanChanges()` — note this provider lives in a page file, not a providers file |

Before applying either `// no-tick:`, open the repository and confirm the claim. If `BathymetryRepository` or `TrackGeometryCacheRepository` can rewrite an existing row, give it a tick instead and update this table.

- [ ] **Step 1: Verify the two exemption claims against the repositories**

- [ ] **Step 2: Apply every table row**

- [ ] **Step 3: Delete the 7 corresponding keys from `_knownViolations`**

- [ ] **Step 4: Run the architecture test**

Run: `flutter test test/architecture/provider_change_tick_test.dart`
Expected: PASS, and `_knownViolations` should now be empty.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/ test/
git commit -m "fix(providers): tick or exempt the remaining stragglers

Offline map regions, app settings, CSV presets, and plan comparison get their
repositories' ticks. The bathymetry grid and GPS track geometry caches are
exempted with a written reason: both are keyed caches whose rows are written
once and never updated in place, so a stale read is not possible.

Refs #974."
```

---

## Task 10: Remove the ratchet and verify

**Files:**
- Modify: `test/architecture/provider_change_tick_test.dart`
- Modify: `docs/superpowers/specs/2026-08-11-provider-change-tick-enforcement-design.md` (record the final counts)

- [ ] **Step 1: Delete `_knownViolations` and simplify the assertion**

With the set empty, replace the second test with:

```dart
  test('no provider reads a repository without subscribing to a tick', () {
    expect(
      result.violations,
      isEmpty,
      reason:
          'Change-tick violations. Each provider below calls a repository '
          'method but never subscribes to a change tick, so it will serve a '
          'stale cache after a merge, a bulk delete, or a sync pull.\n\n'
          'Fix by adding, inside the provider body:\n'
          '  ref.invalidateSelfWhen(repository.watchXChanges());\n\n'
          'Pick the tick for the table the query actually READS, which is not '
          'always the tick owned by the repository the method lives on. A '
          'junction read such as BuddyRepository.getDiveIdsForBuddy needs the '
          'DIVES tick, because it goes stale on a cascade delete that never '
          'writes the buddies table.\n\n'
          'If the provider genuinely cannot go stale (short-lived autoDispose '
          'read fresh at action time), mark it:\n'
          '  // no-tick: <why a stale cache can never render>\n\n'
          '${result.violations.join('\n')}',
    );
  });
```

- [ ] **Step 2: Run the full suite**

Run: `flutter test`
Expected: PASS, all tests. Record the wall-clock duration and compare against a pre-change run; the architecture test should add well under a second (a full parse of `lib/` measured at ~700 ms).

- [ ] **Step 3: Verify the checker actually catches a regression**

Temporarily delete one `ref.invalidateSelfWhen(...)` line from any fixed provider.

Run: `flutter test test/architecture/provider_change_tick_test.dart`
Expected: FAIL, naming that provider and printing the guidance message. Restore the line and re-run to confirm PASS. **Do not skip this** — a repo-wide invariant test that cannot fail is worse than none.

- [ ] **Step 4: Update the spec with final numbers**

In the design doc, replace the "Verified state" survey counts with the measured outcome: 217 repository-reading providers, 137 violations fixed, 14 new tick streams added, and the final count of `// no-tick:` exemptions with their reasons.

- [ ] **Step 5: Format, analyze, full verification, commit**

```bash
dart format .
flutter analyze
flutter test
git add test/ docs/
git commit -m "test(architecture): remove the change-tick ratchet list

All 137 seeded violations are fixed, so the test now asserts the violation
list is empty outright.

Closes #974."
```

---

## Verification Checklist

Before opening the PR:

- [ ] `dart format .` produces no changes
- [ ] `flutter analyze` is clean project-wide (infos are fatal in CI)
- [ ] `flutter test` passes in full
- [ ] `_knownViolations` is gone, not merely emptied
- [ ] Deleting an `invalidateSelfWhen` line makes the architecture test fail (Task 10 Step 3)
- [ ] Every `// no-tick:` marker carries a reason explaining why a stale cache can never render
- [ ] `statisticsVersionProvider` has no remaining references anywhere
- [ ] PR description contains no Claude Code attribution and no session URL
- [ ] PR closes #974, #958, #970
