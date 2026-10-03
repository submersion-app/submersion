import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Drift calls that turn a select into a QUERY stream. Each delivers the
/// current result as soon as it is listened to.
const _queryStreamCalls = {'watch', 'watchSingle', 'watchSingleOrNull'};

/// Change ticks (`Stream<void> watchX()`) whose body builds a Drift query
/// stream, as `name` entries.
///
/// Every caller feeds a tick to `Ref.invalidateSelfWhen`. A tick that emits
/// on subscribe invalidates the provider that just subscribed, the rebuild
/// subscribes again, and the provider spins for as long as anything watches
/// it: #1175 (the media library) and #2835 (smart albums, a freeze each time
/// the Filter media sheet closed). A tick must be built on `tableUpdates`.
List<String> queryStreamTicks(String source) {
  final unit = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final finder = _QueryStreamTicks();
  unit.accept(finder);
  return finder.hits;
}

class _QueryStreamTicks extends RecursiveAstVisitor<void> {
  final hits = <String>[];

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _check(node.returnType, node.name.lexeme, node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _check(node.returnType, node.name.lexeme, node.functionExpression.body);
    super.visitFunctionDeclaration(node);
  }

  void _check(TypeAnnotation? returnType, String name, FunctionBody body) {
    if (returnType?.toSource() != 'Stream<void>') return;
    if (!name.startsWith('watch')) return;
    final calls = _Invocations();
    body.accept(calls);
    if (calls.names.any(_queryStreamCalls.contains)) hits.add(name);
  }
}

class _Invocations extends RecursiveAstVisitor<void> {
  final names = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `ref.watch(...)` is Riverpod, not Drift: a provider-side helper that
    // reads a repository through ref is not a query stream.
    if (node.target?.toSource() != 'ref') names.add(node.methodName.name);
    super.visitMethodInvocation(node);
  }
}

void main() {
  group('queryStreamTicks', () {
    test('flags a tick built on watchSingle', () {
      const source = '''
class R {
  Stream<void> watchChanges() {
    final count = countAll();
    return (_db.selectOnly(_db.t)..addColumns([count]))
        .watchSingle()
        .map((_) {});
  }
}
''';
      expect(queryStreamTicks(source), ['watchChanges']);
    });

    test('flags an expression-bodied tick built on watch', () {
      const source = '''
class R {
  Stream<void> watchThingsChanges() => _db.select(_db.t).watch().map((_) {});
}
''';
      expect(queryStreamTicks(source), ['watchThingsChanges']);
    });

    test('passes a tick built on tableUpdates', () {
      const source = '''
class R {
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.t));
}
''';
      expect(queryStreamTicks(source), isEmpty);
    });

    test('ignores ref.watch, which is Riverpod rather than Drift', () {
      const source = '''
Stream<void> watchScope(Ref ref) {
  final repo = ref.watch(repoProvider);
  return repo.watchChanges();
}
''';
      expect(queryStreamTicks(source), isEmpty);
    });

    test('ignores a data stream, which is meant to deliver rows', () {
      const source = '''
class R {
  Stream<List<Row>> watchAll() => _db.select(_db.t).watch();
}
''';
      expect(queryStreamTicks(source), isEmpty);
    });
  });

  test('no change tick in lib/ is built on a query stream', () {
    final violations = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final file in files) {
      for (final name in queryStreamTicks(file.readAsStringSync())) {
        violations.add('${p.relative(file.path)}::$name');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'These change ticks are built on a Drift query stream, which emits '
          'on subscribe. Fed to Ref.invalidateSelfWhen, that rebuilds the '
          'provider forever (#1175, #2835). Build the tick on '
          'tableUpdates(TableUpdateQuery.onTable(...)) instead.',
    );
  });
}
