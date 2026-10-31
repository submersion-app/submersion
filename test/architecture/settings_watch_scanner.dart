import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// A `ref.watch(settingsProvider)`, the whole object rather than a `select`.
class SettingsWatch {
  const SettingsWatch({required this.file, required this.line});

  final String file;
  final int line;

  @override
  String toString() => '$file:$line';
}

class SettingsWatchScan {
  const SettingsWatchScan({required this.selected, required this.whole});

  /// How many `settingsProvider.select` calls the scan went past.
  final int selected;

  final List<SettingsWatch> whole;
}

class _WatchVisitor extends RecursiveAstVisitor<void> {
  _WatchVisitor(this.file, this.lineInfo);

  final String file;
  final LineInfo lineInfo;
  final whole = <SettingsWatch>[];
  var selected = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'select' &&
        node.realTarget?.toSource() == 'settingsProvider') {
      selected++;
    }
    final arguments = node.argumentList.arguments;
    if (node.methodName.name == 'watch' &&
        arguments.length == 1 &&
        arguments.single.toSource() == 'settingsProvider') {
      whole.add(
        SettingsWatch(
          file: file,
          line: lineInfo.getLocation(node.offset).lineNumber,
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}

/// Finds every whole-object watch of `settingsProvider` in [source].
SettingsWatchScan scanSourceForSettingsWatches(String source, String file) {
  final parsed = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _WatchVisitor(file, parsed.lineInfo);
  parsed.unit.accept(visitor);
  return SettingsWatchScan(selected: visitor.selected, whole: visitor.whole);
}

/// Runs [scanSourceForSettingsWatches] over [files].
SettingsWatchScan scanForSettingsWatches({
  required Iterable<File> files,
  required String Function(String path) relativize,
}) {
  var selected = 0;
  final whole = <SettingsWatch>[];
  for (final file in files) {
    final source = file.readAsStringSync();
    if (!source.contains('settingsProvider')) continue;
    final scan = scanSourceForSettingsWatches(source, relativize(file.path));
    selected += scan.selected;
    whole.addAll(scan.whole);
  }
  return SettingsWatchScan(selected: selected, whole: whole);
}
