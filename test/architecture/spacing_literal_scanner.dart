import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// A spacing or radius value written as a bare number where the scales in
/// `lib/core/theme/spacing.dart` (or a named constant) belong (issue #4971).
class SpacingLiteral {
  const SpacingLiteral({
    required this.file,
    required this.line,
    required this.offset,
    required this.length,
    required this.call,
    required this.value,
  });

  final String file;

  /// 1-based line of the literal itself, not of the call around it.
  final int line;

  /// Source span of the literal, including a leading `-` when negated, so a
  /// rewrite can replace exactly this text.
  final int offset;
  final int length;

  /// What the literal sizes: the constructor (`EdgeInsets.all`,
  /// `Radius.circular`) or the constructor and argument (`SizedBox.width`,
  /// `Wrap.spacing`).
  final String call;

  /// The number as written, negative when negated.
  final num value;

  @override
  String toString() => '$file:$line  $call  $value';
}

/// Constructors whose every numeric argument is a spacing or radius value.
const _measureCalls = {
  'EdgeInsets.all',
  'EdgeInsets.symmetric',
  'EdgeInsets.only',
  'EdgeInsets.fromLTRB',
  'EdgeInsetsDirectional.all',
  'EdgeInsetsDirectional.symmetric',
  'EdgeInsetsDirectional.only',
  'EdgeInsetsDirectional.fromSTEB',
  'BorderRadius.circular',
  'BorderRadiusDirectional.circular',
  'Radius.circular',
  'Radius.elliptical',
};

/// Named arguments that are gaps on any call: `Row` / `Column` / `Flex` /
/// `Wrap` spacing, grid delegate spacing, and `Divider` insets.
const _spacingArguments = {
  'spacing',
  'runSpacing',
  'mainAxisSpacing',
  'crossAxisSpacing',
  'indent',
  'endIndent',
};

/// The constructor name of a call: `EdgeInsets.all`, `SizedBox`.
///
/// Unresolved parsing cannot tell a constructor from a function, so a call
/// without `const` or `new` arrives as a [MethodInvocation]: `SizedBox(...)`
/// with no target, `EdgeInsets.all(...)` with the class as its target. An
/// import prefix is dropped: a lower-case target (`w.SizedBox(...)`) or a
/// prefixed one (`w.EdgeInsets.all(...)`) names the library, not the class.
///
/// With `const`, a two-part name is just as ambiguous: `const
/// EdgeInsets.all(...)` parses as type `all` under import prefix
/// `EdgeInsets`, so an upper-case "prefix" is read back as the class.
String? _callName(Expression expression) {
  if (expression is InstanceCreationExpression) {
    final type = expression.constructorName.type;
    final typeName = type.name.lexeme;
    final named = expression.constructorName.name?.name;
    if (named != null) return '$typeName.$named';
    final prefix = type.importPrefix?.name.lexeme;
    if (prefix == null || _isLibraryPrefix(prefix)) return typeName;
    return '$prefix.$typeName';
  }
  if (expression is MethodInvocation) {
    final method = expression.methodName.name;
    final target = expression.target;
    if (target is SimpleIdentifier && !_isLibraryPrefix(target.name)) {
      return '${target.name}.$method';
    }
    if (target is PrefixedIdentifier) {
      return '${target.identifier.name}.$method';
    }
    return method;
  }
  return null;
}

bool _isLibraryPrefix(String name) =>
    name.isNotEmpty && name[0] == name[0].toLowerCase() && name[0] != '_';

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

class _SpacingVisitor extends RecursiveAstVisitor<void> {
  _SpacingVisitor(this.file, this.lineInfo);

  final String file;
  final LineInfo lineInfo;
  final found = <SpacingLiteral>[];

  /// Depth of top-level variable, static field and enum constant declarations
  /// around the node. A literal there is the value of a named constant, which
  /// is the exemption. An instance field is widget state, not a named constant, and
  /// a closure's body is code, so neither is exempt.
  int _namedConstantDepth = 0;

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _namedConstantDepth++;
    super.visitTopLevelVariableDeclaration(node);
    _namedConstantDepth--;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!node.isStatic) return super.visitFieldDeclaration(node);
    _namedConstantDepth++;
    super.visitFieldDeclaration(node);
    _namedConstantDepth--;
  }

  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    _namedConstantDepth++;
    super.visitEnumConstantDeclaration(node);
    _namedConstantDepth--;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final outer = _namedConstantDepth;
    _namedConstantDepth = 0;
    super.visitFunctionExpression(node);
    _namedConstantDepth = outer;
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

  void _check(Expression call) {
    if (_namedConstantDepth > 0) return;
    final name = _callName(call);
    final arguments = _arguments(call);
    if (name == null || arguments == null) return;

    if (_measureCalls.contains(name)) {
      for (final argument in arguments.arguments) {
        _collect(argument.argumentExpression, name);
      }
    }

    if (name == 'SizedBox' && _named(arguments, 'child') == null) {
      final width = _named(arguments, 'width');
      final height = _named(arguments, 'height');
      if ((width == null) != (height == null)) {
        _collect(
          width ?? height!,
          width != null ? 'SizedBox.width' : 'SizedBox.height',
        );
      }
    }

    for (final argument in arguments.arguments) {
      if (argument is NamedArgument &&
          _spacingArguments.contains(argument.name.lexeme)) {
        _collect(argument.argumentExpression, '$name.${argument.name.lexeme}');
      }
    }
  }

  /// Records [expression] when it is a non-zero number, looking through
  /// parentheses, both branches of a conditional, each arm of a switch
  /// expression and the fallback of `??`.
  /// An operand of arithmetic is a multiplier or an offset, not a size.
  void _collect(Expression expression, String call) {
    switch (expression) {
      case ParenthesizedExpression(:final expression):
        _collect(expression, call);
      case ConditionalExpression(:final thenExpression, :final elseExpression):
        _collect(thenExpression, call);
        _collect(elseExpression, call);
      case SwitchExpression(:final cases):
        for (final arm in cases) {
          _collect(arm.expression, call);
        }
      case BinaryExpression(:final operator, :final rightOperand)
          when operator.type == TokenType.QUESTION_QUESTION:
        _collect(rightOperand, call);
      case PrefixExpression(:final operator, :final operand)
          when operator.type == TokenType.MINUS:
        final magnitude = _number(operand);
        if (magnitude != null) _record(expression, call, -magnitude);
      default:
        final value = _number(expression);
        if (value != null) _record(expression, call, value);
    }
  }

  num? _number(Expression expression) => switch (expression) {
    IntegerLiteral(:final value?) when value != 0 => value,
    DoubleLiteral(:final value) when value != 0 => value,
    _ => null,
  };

  void _record(Expression literal, String call, num value) {
    found.add(
      SpacingLiteral(
        file: file,
        line: lineInfo.getLocation(literal.offset).lineNumber,
        offset: literal.offset,
        length: literal.length,
        call: call,
        value: value,
      ),
    );
  }
}

/// Scans [files] for spacing and radius values written as bare numbers.
///
/// Syntactic parsing only, as in `list_tile_trailing_scanner.dart`: calls are
/// recognised by constructor name, so a custom widget that forwards a
/// `padding` number is not seen. Generated `.g.dart` files are skipped.
///
/// [relativize] converts a path into the form reported in
/// [SpacingLiteral.file].
List<SpacingLiteral> scanForSpacingLiterals({
  required List<File> files,
  required String Function(String path) relativize,
}) {
  final found = <SpacingLiteral>[];
  for (final file in files) {
    if (file.path.endsWith('.g.dart')) continue;
    final parsed = parseFile(
      path: file.absolute.path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    final visitor = _SpacingVisitor(relativize(file.path), parsed.lineInfo);
    parsed.unit.accept(visitor);
    found.addAll(visitor.found);
  }
  found.sort(
    (a, b) => a.file != b.file
        ? a.file.compareTo(b.file)
        : a.offset.compareTo(b.offset),
  );
  return found;
}
