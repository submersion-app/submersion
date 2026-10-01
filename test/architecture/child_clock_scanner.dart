import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// An UPDATE of an existing parent-gated child row that leaves the row's
/// clock where it was.
///
/// Since #2644 a peer's copy of a child with a strictly newer clock writes
/// its explicit nulls, so a value set here without a fresh clock can be
/// cleared by the next such copy, and a null set here never reaches a peer
/// at all (every copy of the row ties).
class ChildWriteViolation {
  const ChildWriteViolation({
    required this.file,
    required this.line,
    required this.member,
    required this.entityType,
  });

  final String file;
  final int line;
  final String member;
  final String entityType;

  /// Stable identity, deliberately excluding the line number so a ratchet
  /// does not churn when unrelated edits move the write down its file.
  String get key => '$file::$member::$entityType';

  @override
  String toString() => '$file:$line  $member  -> $entityType';
}

class ChildWriteScan {
  const ChildWriteScan({required this.childWrites, required this.violations});

  /// Every UPDATE of a parent-gated child found, stamped or not.
  final int childWrites;

  final List<ChildWriteViolation> violations;
}

final _marker = RegExp(r'//\s*child-clock:\s*(\S.*)$');
final _sqlUpdate = RegExp(
  r'\bUPDATE\s+(?:OR\s+\w+\s+)?"?(\w+)"?\s',
  caseSensitive: false,
);
final _sqlSetsHlc = RegExp(r'\bhlc\s*=', caseSensitive: false);

/// Scans [files] for UPDATEs of the tables in [tables] (entity type, which is
/// also the Drift getter, to SQL table name) that do not restamp the row.
///
/// A write restamps its row when the companion it writes sets `hlc`, when its
/// raw SQL assigns `hlc`, or when the same entity type is marked pending
/// (`markRecordPending(entityType: '<type>', ...)`, which stamps the clock)
/// by a statement of its own in a block around the write, in the same member
/// (the mark right after the write, or after the branch holding it). A mark
/// nested in a loop or a branch never counts: syntax cannot tell whether it
/// is for these rows, and the consolidation marks the tanks it inserts in
/// one branch while updating others in another.
/// Anything else needs `// child-clock: <reason>` above the statement, for a
/// row stamped somewhere the scan cannot see.
///
/// Parsing is syntactic, as in the other guards here: tables are recognized
/// by the getter name inside `update(...)` and by the table name after SQL
/// `UPDATE`. Inserts (including `insertOrReplace` and upserts) are not
/// UPDATEs and are not checked.
ChildWriteScan scanChildWrites({
  required List<File> files,
  required Map<String, String> tables,
  required String Function(String path) relativize,
}) {
  final byTable = {for (final e in tables.entries) e.value: e.key};
  var childWrites = 0;
  final violations = <ChildWriteViolation>[];
  for (final file in files) {
    final result = parseFile(
      path: file.absolute.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    final lines = result.content.split('\n');
    final finder = _ChildWriteFinder(tables.keys.toSet(), byTable);
    result.unit.accept(finder);
    for (final write in finder.writes) {
      childWrites += 1;
      if (write.stamped) continue;
      final member = _enclosingMember(write.node);
      if (_markedNearby(write.node, write.entityType)) continue;
      final statement = _statementStart(write.node);
      final line = result.lineInfo.getLocation(statement).lineNumber;
      if (_hasMarker(lines, line)) continue;
      violations.add(
        ChildWriteViolation(
          file: relativize(file.absolute.path),
          line: line,
          member: member == null ? '<unit>' : _memberName(member),
          entityType: write.entityType,
        ),
      );
    }
  }
  return ChildWriteScan(childWrites: childWrites, violations: violations);
}

class _ChildWrite {
  const _ChildWrite(this.node, this.entityType, {required this.stamped});

  final AstNode node;
  final String entityType;
  final bool stamped;
}

class _ChildWriteFinder extends RecursiveAstVisitor<void> {
  _ChildWriteFinder(this.entityTypes, this.byTable);

  final Set<String> entityTypes;
  final Map<String, String> byTable;
  final writes = <_ChildWrite>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    // Positional arguments are expressions; named ones are NamedArgument.
    final args = node.argumentList.arguments.whereType<Expression>().toList();
    if ((name == 'write' || name == 'replace') && args.isNotEmpty) {
      // (db.update(db.table)..where(...)).write(companion), or the same
      // without the cascade.
      final update = _unwrap(node.target);
      if (update is MethodInvocation &&
          update.methodName.name == 'update' &&
          update.argumentList.arguments.whereType<Expression>().length == 1) {
        final type = _lastIdentifier(
          update.argumentList.arguments.whereType<Expression>().single,
        );
        if (type != null && entityTypes.contains(type)) {
          writes.add(_ChildWrite(node, type, stamped: _setsHlc(args.first)));
        }
      }
    } else if (name == 'update' && args.length >= 2) {
      // Batch.update(table, companion, where: ...).
      final type = _lastIdentifier(args.first);
      if (type != null && entityTypes.contains(type)) {
        writes.add(_ChildWrite(node, type, stamped: _setsHlc(args[1])));
      }
    } else if ((name == 'customStatement' || name == 'customUpdate') &&
        args.isNotEmpty) {
      final sql = _sqlText(args.first);
      final table = sql == null ? null : _sqlUpdate.firstMatch(sql)?.group(1);
      final type = table == null ? null : byTable[table];
      if (type != null) {
        writes.add(
          _ChildWrite(node, type, stamped: _sqlSetsHlc.hasMatch(sql!)),
        );
      }
    }
    super.visitMethodInvocation(node);
  }
}

Expression? _unwrap(Expression? expression) {
  var e = expression;
  while (true) {
    if (e is ParenthesizedExpression) {
      e = e.expression;
    } else if (e is CascadeExpression) {
      e = e.target;
    } else {
      return e;
    }
  }
}

String? _lastIdentifier(Expression expression) => switch (expression) {
  PrefixedIdentifier(:final identifier) => identifier.name,
  PropertyAccess(:final propertyName) => propertyName.name,
  SimpleIdentifier(:final name) => name,
  _ => null,
};

/// Whether [companion] is a constructor or method call with an `hlc:`
/// argument (`DiveTanksCompanion(..., hlc: ...)`, `row.copyWith(hlc: ...)`).
/// A companion held in a variable cannot be seen into, so it does not count.
bool _setsHlc(Expression companion) {
  final ArgumentList arguments;
  if (companion is MethodInvocation) {
    arguments = companion.argumentList;
  } else if (companion is InstanceCreationExpression) {
    arguments = companion.argumentList;
  } else {
    return false;
  }
  return arguments.arguments.any(
    (a) => a is NamedArgument && a.name.lexeme == 'hlc',
  );
}

/// The SQL text of a string argument; interpolations become `?` so the
/// table and assignments around them still read.
String? _sqlText(Expression expression) => switch (expression) {
  SimpleStringLiteral(:final value) => value,
  AdjacentStrings(:final strings) => strings.map(_sqlText).join(),
  StringInterpolation(:final elements) =>
    elements.map((e) => e is InterpolationString ? e.value : '?').join(),
  _ => null,
};

/// The method, or the top-level function, the write sits in. A local
/// function belongs to the member that declares it.
Declaration? _enclosingMember(AstNode node) {
  FunctionDeclaration? topLevel;
  for (AstNode? n = node.parent; n != null; n = n.parent) {
    if (n is MethodDeclaration) return n;
    if (n is FunctionDeclaration && n.parent is CompilationUnit) topLevel = n;
  }
  return topLevel;
}

String _memberName(Declaration member) => switch (member) {
  MethodDeclaration(:final name) => name.lexeme,
  FunctionDeclaration(:final name) => name.lexeme,
  _ => '<unit>',
};

/// Whether [entityType] is marked pending by a statement of its own in a
/// block around [node], within the same member. A mark nested in a loop or a
/// branch never counts, at any level: it may be for other rows.
bool _markedNearby(AstNode node, String entityType) {
  for (AstNode? n = node.parent; n != null; n = n.parent) {
    if (n is Declaration) return false;
    if (n is Block && n.statements.any((s) => _isPendingMark(s, entityType))) {
      return true;
    }
  }
  return false;
}

/// Only the statement's own call: a statement that merely contains a mark
/// (`await db.transaction(() async { ... })`) must not vouch for writes
/// elsewhere in it.
bool _isPendingMark(Statement statement, String entityType) {
  if (statement is! ExpressionStatement) return false;
  var e = statement.expression;
  if (e is AwaitExpression) e = e.expression;
  return e is MethodInvocation && _marksEntity(e) == entityType;
}

/// The literal entity type a `markRecordPending(entityType: '<type>')` call
/// names, or null for any other call.
String? _marksEntity(MethodInvocation node) {
  if (node.methodName.name != 'markRecordPending') return null;
  for (final a in node.argumentList.arguments) {
    if (a is NamedArgument &&
        a.name.lexeme == 'entityType' &&
        a.argumentExpression is SimpleStringLiteral) {
      return (a.argumentExpression as SimpleStringLiteral).value;
    }
  }
  return null;
}

/// The offset of the statement holding [node], where a marker goes above.
int _statementStart(AstNode node) {
  for (AstNode? n = node; n != null; n = n.parent) {
    if (n is Statement) return n.offset;
    if (n is FunctionBody) break;
  }
  return node.offset;
}

/// Looks for `// child-clock: <reason>` above the statement, skipping other
/// comment lines between them. An empty reason does not count.
bool _hasMarker(List<String> lines, int statementLine) {
  // lines is 0-indexed, statementLine is 1-indexed: start one line above.
  for (var i = statementLine - 2; i >= 0 && i >= statementLine - 12; i--) {
    final text = lines[i].trim();
    final match = _marker.firstMatch(text);
    if (match != null) return match.group(1)!.trim().isNotEmpty;
    if (text.startsWith('//')) continue;
    return false;
  }
  return false;
}
