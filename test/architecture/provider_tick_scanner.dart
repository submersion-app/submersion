import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// A provider that invokes a method on a repository without subscribing to any
/// change tick, and so serves a stale cache after a write that bypasses the
/// notifiers (a merge, a bulk delete, a sync pull).
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

  /// Stable identity, deliberately excluding the line number so the ratchet
  /// list in `provider_change_tick_test.dart` does not churn when unrelated
  /// edits move a provider down its file.
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

  /// Distinct change-tick method names. Smaller than [tickDeclarationCount]
  /// because several repositories declare a bare `watchChanges()`.
  final Set<String> tickNames;

  /// Total `Stream<void> watchX()` declarations found across all repositories.
  final int tickDeclarationCount;

  final List<TickViolation> violations;

  /// Providers that invoke a method on a repository, violating or not.
  final int repositoryReadingProviders;
}

/// Collects `Stream<void> watchX()` declarations, which are the repositories'
/// change ticks.
///
/// The set is derived rather than matched against a `watch<Noun>Changes`
/// pattern because three repositories declare a bare `watchChanges()`
/// (diver_weight_entry, emergency_chamber, incident) that a name pattern would
/// silently skip.
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
/// codebase uses: `ref.watch(xRepositoryProvider)`, `ref.read(...)`, or a bare
/// `XRepository()` constructor call.
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
      } else if (initializer.target == null && method.endsWith('Repository')) {
        // Unresolved parsing cannot tell a constructor call from a function
        // call, so `DiveRepository()` arrives here as a MethodInvocation
        // rather than an InstanceCreationExpression. Direct construction is
        // rare but load-bearing: trip_providers.dart builds two repositories
        // this way, bypassing any test override.
        ids.add(node.name.lexeme);
      }
    } else if (initializer is InstanceCreationExpression &&
        initializer.constructorName.type.toSource().endsWith('Repository')) {
      // The explicit `new FooRepository()` form, which does parse as an
      // InstanceCreationExpression.
      ids.add(node.name.lexeme);
    }
    super.visitVariableDeclaration(node);
  }
}

/// Every method invocation in a subtree, as (target source, method name).
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

/// Matches an inline `ref.watch(fooRepositoryProvider)` /
/// `ref.read(fooRepositoryProvider)` used directly as a call target, without
/// being bound to a local first.
final _inlineRepositoryTarget = RegExp(
  r'^ref\s*\.\s*(watch|read)\s*\(\s*\w+RepositoryProvider\s*\)$',
);

/// Whether [target] denotes a repository: either a local bound to one, or an
/// inline `ref.watch(fooRepositoryProvider)` expression.
bool _isRepositoryTarget(String? target, Set<String> boundIds) {
  if (target == null) return false;
  if (boundIds.contains(target)) return true;
  return _inlineRepositoryTarget.hasMatch(target.replaceAll('\n', ''));
}

/// Whether the provider's VALUE is a function rather than data.
///
/// Action providers take the shape `Provider((ref) => (args) async { ... })`
/// or return a closure from a block body. Their repository calls run when a
/// caller invokes the callback, not when the provider builds, so there is no
/// cached row that could go stale and no tick to subscribe to. Recognising the
/// shape here keeps roughly ten `// no-tick:` comments out of the codebase,
/// all of which would assert the same fact.
bool _buildsAFunction(MethodInvocation providerInitializer) {
  for (final argument in providerInitializer.argumentList.arguments) {
    if (argument is! FunctionExpression) continue;
    final body = argument.body;
    if (body is ExpressionFunctionBody) {
      if (body.expression is FunctionExpression) return true;
    } else if (body is BlockFunctionBody) {
      final statements = body.block.statements;
      if (statements.length == 1) {
        final only = statements.first;
        if (only is ReturnStatement && only.expression is FunctionExpression) {
          return true;
        }
      }
    }
  }
  return false;
}

class _ParsedFile {
  const _ParsedFile(this.unit, this.lineInfo, this.lines);

  final CompilationUnit unit;
  final LineInfo lineInfo;
  final List<String> lines;
}

_ParsedFile _parse(File file) {
  // Syntactic parsing only. Resolved analysis of a Flutter application this
  // size takes minutes; unresolved parsing takes about half a millisecond per
  // file. The cost is that types cannot be resolved, so "is this a repository"
  // is decided by identifier name.
  final result = parseFile(
    path: file.absolute.path,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  return _ParsedFile(result.unit, result.lineInfo, result.content.split('\n'));
}

/// Scans [providerFiles] for providers that invoke a repository method without
/// referencing any change tick declared in [repositoryFiles].
///
/// [relativize] converts an absolute path into the form used in
/// [TickViolation.file] and therefore in [TickViolation.key].
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
    final functions = _TopLevelFunctions();
    parsed.unit.accept(functions);

    for (final declaration
        in parsed.unit.declarations.whereType<TopLevelVariableDeclaration>()) {
      for (final variable in declaration.variables.variables) {
        if (!variable.name.lexeme.endsWith('Provider')) continue;
        final initializer = variable.initializer;
        if (initializer is! MethodInvocation) continue;
        if (_buildsAFunction(initializer)) continue;

        final bindings = _RepositoryBindings();
        initializer.accept(bindings);

        final invocations = _Invocations();
        initializer.accept(invocations);

        // A provider READS only if a repository is the TARGET of a call. A
        // repository merely passed as an argument -- the shape of every
        // service-constructor provider (exportServiceProvider, syncService
        // Provider, the import-wizard adapters) -- is not a read, so those
        // need no allowlist entry.
        //
        // A `watch`-prefixed repository method is a SUBSCRIPTION, not a read:
        // either a change tick or a live Drift query (watchFindings,
        // watchEntries, watchSummary). Both re-emit on every write, so neither
        // can serve a stale value and neither makes the provider a reader.
        final repositoryCall = invocations.calls
            .where(
              (c) =>
                  _isRepositoryTarget(c.target, bindings.ids) &&
                  !c.method.startsWith('watch'),
            )
            .firstOrNull;
        if (repositoryCall == null) continue;
        readers++;

        if (_hasTick(invocations, functions, ticks.names)) continue;

        final line = parsed.lineInfo.getLocation(variable.offset).lineNumber;
        if (_hasNoTickMarker(parsed.lines, line)) continue;

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

/// Whether the provider subscribes to a tick, directly or through a same-file
/// helper resolved one level deep.
///
/// The indirection is what lets all three legitimate shapes pass: the
/// `ref.invalidateSelfWhen(repo.watchXChanges())` used at most call sites, the
/// raw `.listen()` + `ref.onDispose` that `StateNotifier`s must use because
/// `invalidateSelfWhen` is a `Ref` extension, and a shared helper such as
/// `_keepAliveWithExpiry` in `statistics_providers.dart`.
bool _hasTick(
  _Invocations invocations,
  _TopLevelFunctions functions,
  Set<String> tickNames,
) {
  if (invocations.calls.any((c) => tickNames.contains(c.method))) return true;

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

/// Looks for `// no-tick: <reason>` above the declaration, skipping any doc
/// comment between the marker and the code. An empty reason does not count.
bool _hasNoTickMarker(List<String> lines, int declarationLine) {
  // lines is 0-indexed, declarationLine is 1-indexed: start one line above.
  for (var i = declarationLine - 2; i >= 0 && i >= declarationLine - 12; i--) {
    final text = lines[i].trim();
    if (text.isEmpty) return false;
    final match = _noTickMarker.firstMatch(text);
    if (match != null) return match.group(1)!.trim().isNotEmpty;
    if (text.startsWith('//')) continue;
    return false;
  }
  return false;
}
