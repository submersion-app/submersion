import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// A tile whose `trailing` argument holds a text-bearing widget.
class TrailingViolation {
  const TrailingViolation({
    required this.file,
    required this.line,
    required this.tile,
    required this.widgets,
  });

  final String file;
  final int line;

  /// `ListTile` or `ExpansionTile`.
  final String tile;

  /// The flagged widgets found inside `trailing`, by constructor name
  /// (`Chip`, `FilledButton.tonal`), in source order.
  final List<String> widgets;

  @override
  String toString() => '$file:$line  $tile.trailing  ${widgets.join(', ')}';
}

class TrailingScanResult {
  const TrailingScanResult({
    required this.tilesWithTrailing,
    required this.violations,
  });

  /// Every tile that passes a `trailing` argument, flagged or not.
  final int tilesWithTrailing;

  final List<TrailingViolation> violations;
}

/// Tiles that lay `trailing` out at its natural width before the title.
const _tiles = {'ListTile', 'ExpansionTile'};

/// List tiles with a built-in control. Their `secondary` takes the trailing
/// slot, with the same natural-width layout, when the control is placed
/// leading; see [_trailingSlot].
const _controlTiles = {'CheckboxListTile', 'SwitchListTile', 'RadioListTile'};

/// The argument a tile lays out in its trailing slot, if any.
Expression? _trailingSlot(String tile, ArgumentList arguments) {
  if (_tiles.contains(tile)) return _named(arguments, 'trailing');
  if (!_controlTiles.contains(tile)) return null;
  final affinity = _named(arguments, 'controlAffinity');
  if (affinity == null || !affinity.toSource().endsWith('.leading')) {
    return null;
  }
  return _named(arguments, 'secondary');
}

/// Widgets that exist to carry a label, so their width follows the label's
/// translation. A trailing `Text` is deliberately absent: it is usually a
/// short value ('12', '40 m') that a syntactic scan cannot size.
const _textBearing = {
  'Chip',
  'ActionChip',
  'FilterChip',
  'InputChip',
  'ChoiceChip',
  'TextButton',
  'OutlinedButton',
  'FilledButton',
  'ElevatedButton',
};

/// Wrappers that pass their child's width through, so a text-bearing widget
/// inside them is still unconstrained.
const _passThrough = {
  'Row',
  'Wrap',
  'Column',
  'Padding',
  'Align',
  'Center',
  'Flexible',
  'Expanded',
  'Opacity',
  'Tooltip',
  'Semantics',
};

/// Wrappers that fix the width only when given one; see [_fixesWidth].
const _sizing = {'SizedBox', 'ConstrainedBox'};

/// The constructor name of a widget expression: `Chip`, `FilledButton.tonal`.
///
/// Unresolved parsing cannot tell a constructor call from a function call, so
/// `Chip(...)` without `const`/`new` arrives as a [MethodInvocation] and
/// `FilledButton.tonal(...)` as one whose target is the class name.
String? _constructorName(Expression expression) {
  if (expression is InstanceCreationExpression) {
    final type = expression.constructorName.type.name.lexeme;
    final named = expression.constructorName.name?.name;
    return named == null ? type : '$type.$named';
  }
  if (expression is MethodInvocation) {
    final target = expression.target;
    if (target == null) return expression.methodName.name;
    if (target is SimpleIdentifier) {
      return '${target.name}.${expression.methodName.name}';
    }
  }
  return null;
}

ArgumentList? _arguments(Expression expression) => switch (expression) {
  InstanceCreationExpression(:final argumentList) => argumentList,
  MethodInvocation(:final argumentList) => argumentList,
  _ => null,
};

Expression? _named(ArgumentList arguments, String name) {
  for (final argument in arguments.arguments) {
    if (argument is NamedArgument && argument.name.lexeme == name) {
      return argument.argumentExpression;
    }
  }
  return null;
}

/// Collects the text-bearing widgets reachable from a `trailing` expression
/// without passing through anything that fixes the width.
///
/// [locals] maps the enclosing function's local variables to their
/// initializers, so `trailing: action` is followed into
/// `final action = TextButton(...)`. A followed name is removed from the map
/// before recursing, so a self-referencing initializer cannot loop.
void _collect(
  Expression expression,
  List<String> out, [
  Map<String, Expression> locals = const {},
]) {
  switch (expression) {
    case SimpleIdentifier(:final name) when locals.containsKey(name):
      _collect(locals[name]!, out, {...locals}..remove(name));
      return;
    case ParenthesizedExpression(:final expression):
      _collect(expression, out, locals);
      return;
    case ConditionalExpression(:final thenExpression, :final elseExpression):
      _collect(thenExpression, out, locals);
      _collect(elseExpression, out, locals);
      return;
    default:
  }

  final name = _constructorName(expression);
  if (name == null) return;
  final type = name.split('.').first;
  if (_textBearing.contains(type)) {
    out.add(name);
    return;
  }

  final arguments = _arguments(expression);
  if (arguments == null) return;
  if (_sizing.contains(type)) {
    if (_fixesWidth(type, arguments)) return;
  } else if (!_passThrough.contains(type)) {
    return;
  }

  final child = _named(arguments, 'child');
  if (child != null) _collect(child, out, locals);
  final children = _named(arguments, 'children');
  if (children is ListLiteral) {
    for (final element in children.elements) {
      _collectElement(element, out, locals);
    }
  }
}

/// Whether a `SizedBox` or `ConstrainedBox` pins its child to one width.
///
/// Only a TIGHT width counts. A max-only `BoxConstraints(maxWidth: 96)` still
/// lets a short label take its natural width and a long translation grow to
/// the cap, so the title keeps losing space to it.
bool _fixesWidth(String type, ArgumentList arguments) {
  if (type == 'SizedBox') {
    // SizedBox(width:), SizedBox.square(dimension:), SizedBox.fromSize(size:).
    return _named(arguments, 'width') != null ||
        _named(arguments, 'dimension') != null ||
        _named(arguments, 'size') != null;
  }
  final constraints = _named(arguments, 'constraints');
  if (constraints == null) return false;
  final name = _constructorName(constraints);
  final constraintArguments = _arguments(constraints);
  if (name == null || constraintArguments == null) return false;
  switch (name) {
    case 'BoxConstraints.tight':
      return true;
    case 'BoxConstraints.tightFor':
    case 'BoxConstraints.expand':
      return _named(constraintArguments, 'width') != null;
    case 'BoxConstraints':
      final min = _named(constraintArguments, 'minWidth');
      final max = _named(constraintArguments, 'maxWidth');
      return min != null && max != null && min.toSource() == max.toSource();
  }
  return false;
}

void _collectElement(
  CollectionElement element,
  List<String> out,
  Map<String, Expression> locals,
) {
  switch (element) {
    case Expression():
      _collect(element, out, locals);
    case IfElement(:final thenElement, :final elseElement):
      _collectElement(thenElement, out, locals);
      if (elseElement != null) _collectElement(elseElement, out, locals);
    default:
  }
}

/// The initializers of the local variables declared in the function body
/// that encloses [node], by name.
Map<String, Expression> _localsAround(AstNode node) {
  AstNode? body = node.parent;
  while (body != null && body is! FunctionBody) {
    body = body.parent;
  }
  if (body == null) return const {};
  final collector = _LocalInitializers();
  body.accept(collector);
  return collector.initializers;
}

class _LocalInitializers extends RecursiveAstVisitor<void> {
  final initializers = <String, Expression>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer != null) {
      initializers.putIfAbsent(node.name.lexeme, () => initializer);
    }
    super.visitVariableDeclaration(node);
  }
}

class _TileVisitor extends RecursiveAstVisitor<void> {
  _TileVisitor(this.file, this.lineInfo);

  final String file;
  final LineInfo lineInfo;
  final violations = <TrailingViolation>[];
  var tilesWithTrailing = 0;

  void _check(Expression node) {
    final name = _constructorName(node);
    if (name == null) return;
    final tile = name.split('.').first;
    final arguments = _arguments(node);
    if (arguments == null) return;
    final trailing = _trailingSlot(tile, arguments);
    if (trailing == null) return;
    tilesWithTrailing++;

    final widgets = <String>[];
    _collect(trailing, widgets, _localsAround(node));
    if (widgets.isEmpty) return;
    violations.add(
      TrailingViolation(
        file: file,
        line: lineInfo.getLocation(trailing.offset).lineNumber,
        tile: tile,
        widgets: widgets,
      ),
    );
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _check(node);
    super.visitMethodInvocation(node);
  }
}

/// Scans [files] for `ListTile`/`ExpansionTile`s with a chip or a text button
/// in `trailing`.
///
/// Syntactic parsing only, as in `provider_tick_scanner.dart`: resolved
/// analysis of the whole app takes minutes, so widgets are recognised by
/// constructor name, and a custom widget that wraps a chip is not seen.
///
/// [relativize] converts an absolute path into the form reported in
/// [TrailingViolation.file].
TrailingScanResult scanForTextBearingTrailing({
  required List<File> files,
  required String Function(String) relativize,
}) {
  final violations = <TrailingViolation>[];
  var tilesWithTrailing = 0;
  for (final file in files) {
    final parsed = parseFile(
      path: file.absolute.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    final visitor = _TileVisitor(relativize(file.path), parsed.lineInfo);
    parsed.unit.accept(visitor);
    tilesWithTrailing += visitor.tilesWithTrailing;
    violations.addAll(visitor.violations);
  }
  violations.sort(
    (a, b) =>
        a.file != b.file ? a.file.compareTo(b.file) : a.line.compareTo(b.line),
  );
  return TrailingScanResult(
    tilesWithTrailing: tilesWithTrailing,
    violations: violations,
  );
}
