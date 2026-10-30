import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// A `SnackBar` with an `action` that does not say whether it persists.
class PersistViolation {
  const PersistViolation({required this.file, required this.line});

  final String file;
  final int line;

  @override
  String toString() => '$file:$line';
}

class PersistScanResult {
  const PersistScanResult({
    required this.snackBarsWithAction,
    required this.violations,
  });

  /// Every `SnackBar` that passes an `action` argument, flagged or not.
  final int snackBarsWithAction;

  final List<PersistViolation> violations;
}

class _SnackBarVisitor extends RecursiveAstVisitor<void> {
  _SnackBarVisitor(this.file, this.lineInfo);

  final String file;
  final LineInfo lineInfo;
  final violations = <PersistViolation>[];
  var snackBarsWithAction = 0;

  bool _hasNamed(ArgumentList arguments, String name) => arguments.arguments
      .any((a) => a is NamedArgument && a.name.lexeme == name);

  void _check(int offset, ArgumentList arguments) {
    if (!_hasNamed(arguments, 'action')) return;
    snackBarsWithAction++;
    if (_hasNamed(arguments, 'persist')) return;
    violations.add(
      PersistViolation(
        file: file,
        line: lineInfo.getLocation(offset).lineNumber,
      ),
    );
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructor = node.constructorName;
    if (constructor.type.name.lexeme == 'SnackBar' &&
        constructor.name == null) {
      _check(node.offset, node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  /// Unresolved parsing cannot tell a constructor call from a function call,
  /// so `SnackBar(...)` without `const`/`new` arrives as a [MethodInvocation].
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'SnackBar') {
      _check(node.offset, node.argumentList);
    }
    super.visitMethodInvocation(node);
  }
}

/// Scans [files] for `SnackBar`s with an `action` and no `persist` argument.
///
/// Syntactic parsing only, as in `provider_tick_scanner.dart`: resolved
/// analysis of the whole app takes minutes, so the widget is recognised by
/// constructor name.
///
/// [relativize] converts an absolute path into the form reported in
/// [PersistViolation.file].
PersistScanResult scanForActionWithoutPersist({
  required List<File> files,
  required String Function(String) relativize,
}) {
  final violations = <PersistViolation>[];
  var snackBarsWithAction = 0;
  for (final file in files) {
    final parsed = parseFile(
      path: file.absolute.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    final visitor = _SnackBarVisitor(relativize(file.path), parsed.lineInfo);
    parsed.unit.accept(visitor);
    snackBarsWithAction += visitor.snackBarsWithAction;
    violations.addAll(visitor.violations);
  }
  violations.sort(
    (a, b) =>
        a.file != b.file ? a.file.compareTo(b.file) : a.line.compareTo(b.line),
  );
  return PersistScanResult(
    snackBarsWithAction: snackBarsWithAction,
    violations: violations,
  );
}
