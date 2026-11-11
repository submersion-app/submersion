import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The members of `SettingsNotifier` allowed to assign `state` directly.
///
/// Every setter goes through `_update`, which waits for the diver's settings
/// to load before it applies a change (issue #4449): the load replaces the
/// whole state when it lands, so a change assigned before then is lost. The
/// others here are the load and the reload themselves, and the threshold
/// rollback, which puts back what `_update` applied.
const _allowed = {
  '_initializeAndLoad',
  '_loadSettings',
  '_reloadFromStorage',
  '_update',
  '_commitThreshold',
};

class _StateAssignments extends RecursiveAstVisitor<void> {
  _StateAssignments(this.lineOf);

  final int Function(int offset) lineOf;
  final offenders = <String>[];

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final target = node.leftHandSide;
    if (target is SimpleIdentifier && target.name == 'state') {
      final member = _enclosingMember(node);
      if (!_allowed.contains(member)) {
        offenders.add('$member (line ${lineOf(node.offset)})');
      }
    }
    super.visitAssignmentExpression(node);
  }

  /// A public member (a setter) reading `state` outside a change closure
  /// would build its change on the defaults before the load lands.
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final parent = node.parent;
    final isMemberName =
        (parent is PropertyAccess && parent.propertyName == node) ||
        (parent is PrefixedIdentifier && parent.identifier == node) ||
        parent is Label ||
        node.thisOrAncestorOfType<CommentReference>() != null;
    if (node.name == 'state' && !isMemberName) {
      final member = _enclosingMember(node);
      if (!member.startsWith('_') && !member.startsWith('SettingsNotifier.')) {
        offenders.add('$member reads state (line ${lineOf(node.offset)})');
      }
    }
    super.visitSimpleIdentifier(node);
  }

  static String _enclosingMember(AstNode node) {
    for (AstNode? n = node; n != null; n = n.parent) {
      if (n is MethodDeclaration) return n.name.lexeme;
      if (n is ConstructorDeclaration) {
        return 'SettingsNotifier.${n.name?.lexeme ?? ''}';
      }
    }
    return '<unknown>';
  }
}

void main() {
  test('SettingsNotifier setters change state only through _update', () {
    final path = p.join(
      'lib',
      'features',
      'settings',
      'presentation',
      'providers',
      'settings_providers.dart',
    );
    final result = parseString(
      content: File(path).readAsStringSync(),
      path: path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    final notifier = result.unit.declarations
        .whereType<ClassDeclaration>()
        .singleWhere((c) => c.namePart.typeName.lexeme == 'SettingsNotifier');
    final visitor = _StateAssignments(
      (offset) => result.lineInfo.getLocation(offset).lineNumber,
    );
    notifier.accept(visitor);

    expect(
      visitor.offenders,
      isEmpty,
      reason:
          'These assign SettingsNotifier.state directly. A change made '
          'before the diver settings load lands is overwritten by it '
          '(issue #4449): apply it with _update instead.',
    );
  });
}
