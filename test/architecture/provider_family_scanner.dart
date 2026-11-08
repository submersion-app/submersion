import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// One top-level `final xProvider = SomeProvider(.autoDispose).family(...)`.
class ProviderFamilyDeclaration {
  const ProviderFamilyDeclaration({
    required this.file,
    required this.line,
    required this.name,
    required this.isAutoDispose,
    required this.retains,
    required this.watched,
  });

  final String file;
  final int line;
  final String name;

  /// Declared through `.autoDispose` or with `isAutoDispose: true`.
  final bool isAutoDispose;

  /// Its build calls `retainDiveData` or `retainUntilIdle`.
  final bool retains;

  /// Providers its build subscribes to through `ref.watch` or `ref.listen`,
  /// by the name the call starts with (`diveProvider` for
  /// `ref.watch(diveProvider(id).future)`).
  final Set<String> watched;

  @override
  String toString() => '$file:$line  $name';
}

const _retainCalls = {'retainDiveData', 'retainUntilIdle'};
const _subscribeCalls = {'watch', 'listen'};
// An import prefix (`lab.plannedColumnProvider(id)`) is dropped.
final _leadingName = RegExp(r'^(?:\w+\s*\.\s*)?(\w+)\s*\(');

/// The provider families declared in [content], the source of [file].
///
/// Syntactic parsing only, as in `provider_tick_scanner.dart`: resolving the
/// app would take minutes, and a family is recognisable by shape alone. The
/// cost is that a subscription made in a helper the build calls, or in a
/// Notifier class, is not seen.
List<ProviderFamilyDeclaration> scanProviderFamilies(
  String file,
  String content,
) {
  final result = parseString(
    content: content,
    path: file,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final families = <ProviderFamilyDeclaration>[];
  for (final declaration
      in result.unit.declarations.whereType<TopLevelVariableDeclaration>()) {
    for (final variable in declaration.variables.variables) {
      final initializer = variable.initializer;
      if (initializer is! MethodInvocation) continue;
      if (initializer.methodName.name != 'family') continue;
      final target = initializer.target?.toSource() ?? '';
      if (!target.endsWith('Provider') &&
          !target.endsWith('Provider.autoDispose')) {
        continue;
      }

      final calls = _Calls();
      initializer.argumentList.accept(calls);
      families.add(
        ProviderFamilyDeclaration(
          file: file,
          line: result.lineInfo.getLocation(variable.offset).lineNumber,
          name: variable.name.lexeme,
          isAutoDispose:
              target.endsWith('.autoDispose') ||
              _hasAutoDisposeArgument(initializer),
          retains: calls.retains,
          watched: calls.watched,
        ),
      );
    }
  }
  return families;
}

bool _hasAutoDisposeArgument(MethodInvocation initializer) =>
    initializer.argumentList.arguments.whereType<NamedArgument>().any(
      (argument) =>
          argument.name.lexeme == 'isAutoDispose' &&
          argument.argumentExpression.toSource() == 'true',
    );

class _Calls extends RecursiveAstVisitor<void> {
  var retains = false;
  final watched = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.name;
    if (node.target == null && _retainCalls.contains(method)) {
      retains = true;
    }
    final arguments = node.argumentList.arguments;
    if (node.target?.toSource() == 'ref' &&
        _subscribeCalls.contains(method) &&
        arguments.isNotEmpty) {
      final name = _leadingName.firstMatch(arguments.first.toSource());
      if (name != null) watched.add(name.group(1)!);
    }
    super.visitMethodInvocation(node);
  }
}
