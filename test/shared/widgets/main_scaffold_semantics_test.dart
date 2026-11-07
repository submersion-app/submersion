import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';
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

Future<void> _pumpShell(WidgetTester tester, {required Size size}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const _Page(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        updateServiceProvider.overrideWith((ref) async => null),
        updateStatusProvider.overrideWith((ref) => StubUpdateStatusNotifier()),
        downloadNotifierProvider.overrideWith((ref) => StubDownloadNotifier()),
        settingsProvider.overrideWith(
          (ref) => StubSettingsNotifier(const AppSettings()),
        ),
        demoModeActiveProvider.overrideWithValue(true),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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

/// The labels under the node [label] names, which must be one node.
List<String> _labelsUnder(WidgetTester tester, String label) {
  final found = [
    for (final node in _descendants(_root(tester)))
      if (node.label == label) node,
  ];
  expect(found, hasLength(1), reason: 'one node named "$label"');
  return _labelsOf(_descendants(found.single));
}

Matcher _hasLabelStartingWith(String text) =>
    contains(predicate<String>((label) => label.startsWith(text), text));

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('a screen reader reaches the shell chrome (#4166)', () {
    testWidgets('the rail destinations and the demo strip on a wide screen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpShell(tester, size: const Size(1400, 900));

      final labels = _labels(tester);
      expect(labels, _hasLabelStartingWith(l10n.nav_home));
      expect(labels, _hasLabelStartingWith(l10n.nav_dives));
      expect(labels, contains(l10n.demo_strip_label));
      expect(labels, contains(l10n.demo_strip_exit));
      expect(labels, contains('Page body'));
      // The strip's words name the strip, not the whole shell around it.
      expect(_labelsUnder(tester, l10n.demo_strip_label), [
        l10n.demo_strip_exit,
      ]);
      semantics.dispose();
    });

    testWidgets('the demo strip on a phone', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpShell(tester, size: const Size(390, 844));

      final labels = _labels(tester);
      expect(labels, contains(l10n.demo_strip_label));
      expect(labels, contains(l10n.demo_strip_exit));
      expect(labels, contains('Page body'));
      // The strip's words name the strip, not the whole shell around it.
      expect(_labelsUnder(tester, l10n.demo_strip_label), [
        l10n.demo_strip_exit,
      ]);
      semantics.dispose();
    });

    testWidgets('the demo strip while a page hides the shell chrome', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpShell(tester, size: const Size(390, 844));
      ShellChromeScope.maybeOf(
        tester.element(find.byType(_Page)),
      )!.requestHidden(tester);
      await tester.pumpAndSettle();

      final labels = _labels(tester);
      expect(labels, contains(l10n.demo_strip_label));
      expect(labels, contains('Page body'));
      expect(_labelsUnder(tester, l10n.demo_strip_label), [
        l10n.demo_strip_exit,
      ]);
      semantics.dispose();
    });
  });
}
