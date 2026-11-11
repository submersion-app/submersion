import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/shell_chrome_scope.dart';

import '../../helpers/main_scaffold_stubs.dart';

/// A page on the shell navigator. Every page route paints a modal barrier,
/// and the barrier blocks the semantics of whatever was painted before it.
class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Page body')));
}

Future<void> _pumpShell(WidgetTester tester, {required Size size}) =>
    pumpMainScaffoldShell(tester, size: size, page: const _Page());

SemanticsNode _root(WidgetTester tester) =>
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!;

/// Every node below [node], depth first.
List<SemanticsNode> _descendants(SemanticsNode node) {
  final nodes = <SemanticsNode>[];
  bool visit(SemanticsNode child) {
    nodes.add(child);
    child.visitChildren(visit);
    return true;
  }

  node.visitChildren(visit);
  return nodes;
}

List<String> _labelsOf(Iterable<SemanticsNode> nodes) => [
  for (final node in nodes)
    if (node.label.isNotEmpty) node.label,
];

/// Every label in the live semantics tree: what a screen reader can reach.
List<String> _labels(WidgetTester tester) =>
    _labelsOf(_descendants(_root(tester)));

Matcher _hasLabelStartingWith(String text) =>
    contains(predicate<String>((label) => label.startsWith(text), text));

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('a screen reader reaches the shell chrome (#4166)', () {
    testWidgets('the rail destinations on a wide screen', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpShell(tester, size: const Size(1400, 900));

      final labels = _labels(tester);
      expect(labels, _hasLabelStartingWith(l10n.nav_home));
      expect(labels, _hasLabelStartingWith(l10n.nav_dives));
      expect(labels, contains('Page body'));
      semantics.dispose();
    });

    testWidgets('the bottom bar on a phone', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpShell(tester, size: const Size(390, 844));

      final labels = _labels(tester);
      expect(labels, _hasLabelStartingWith(l10n.nav_home));
      expect(labels, contains('Page body'));
      semantics.dispose();
    });

    testWidgets('the page while it hides the shell chrome', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpShell(tester, size: const Size(390, 844));
      ShellChromeScope.maybeOf(
        tester.element(find.byType(_Page)),
      )!.requestHidden(tester);
      await tester.pumpAndSettle();

      expect(_labels(tester), contains('Page body'));
      semantics.dispose();
    });
  });
}
