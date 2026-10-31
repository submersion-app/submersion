import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _KeyReads extends RecursiveAstVisitor<void> {
  final fields = <String>{};

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 's') fields.add(node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }
}

/// `unitFormatterProvider` keeps one formatter until
/// `unitFormatterSettingsKey` changes (issue #3818). A member missing from the
/// key compiles, then serves its old value to every widget that reads it
/// through a formatter, until something else changes the key.
void main() {
  final unit = parseString(
    content: File(
      p.join('lib', 'core', 'utils', 'unit_formatter_settings.dart'),
    ).readAsStringSync(),
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;

  test('the key reads every member of UnitFormatterSettings', () {
    final interface = unit.declarations
        .whereType<ClassDeclaration>()
        .singleWhere(
          (c) => c.namePart.typeName.lexeme == 'UnitFormatterSettings',
        );
    final members = (interface.body as BlockClassBody).members
        .whereType<MethodDeclaration>()
        .where((m) => m.isGetter)
        .map((m) => m.name.lexeme)
        .toSet();

    final reads = _KeyReads();
    unit.declarations
        .whereType<FunctionDeclaration>()
        .singleWhere((f) => f.name.lexeme == 'unitFormatterSettingsKey')
        .accept(reads);

    expect(members, hasLength(greaterThanOrEqualTo(20)));
    expect(reads.fields, members);
  });
}
