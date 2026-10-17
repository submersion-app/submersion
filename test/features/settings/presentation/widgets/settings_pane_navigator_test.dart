// Issue #3467: on a master-detail window, every page reached from a settings
// section opens inside the detail pane, with the URL recording the open pages
// so Back walks up one page at a time and a deep link reopens them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';

/// A page with one button per entry of [links], each opening that location
/// through the helper the real pages use.
class _Stub extends StatelessWidget {
  final String name;
  final Map<String, String> links;
  final Map<String, String> replacements;

  const _Stub(this.name, {this.links = const {}, this.replacements = const {}});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Page $name')),
    body: Column(
      children: [
        for (final MapEntry(:key, :value) in links.entries)
          TextButton(
            onPressed: () => context.pushSettingsPage(value),
            child: Text(key),
          ),
        for (final MapEntry(:key, :value) in replacements.entries)
          TextButton(
            onPressed: () => context.replaceSettingsPage(value),
            child: Text(key),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('close'),
        ),
      ],
    ),
  );
}

class _Hub extends StatefulWidget {
  const _Hub();

  @override
  State<_Hub> createState() => _HubState();
}

class _HubState extends State<_Hub> {
  int returns = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('Hub'),
      Text('returns $returns'),
      TextButton(
        onPressed: () => context.pushSettingsPage('/settings/a'),
        child: const Text('open a'),
      ),
      TextButton(
        onPressed: () async {
          await context.pushSettingsPage('/settings/c');
          if (mounted) setState(() => returns++);
        },
        child: const Text('await c'),
      ),
      TextButton(
        onPressed: () => context.pushSettingsPage('/other'),
        child: const Text('open other'),
      ),
    ],
  );
}

Widget? _pageFor(Uri location) => switch (location.pathSegments) {
  ['settings', 'a'] => const _Stub(
    'A',
    links: {'open b': '/settings/a/b', 'open other': '/other'},
    replacements: {'replace with c': '/settings/c'},
  ),
  ['settings', 'a', 'b'] => const _Stub(
    'B',
    links: {'open a again': '/settings/a', 'open c': '/settings/c'},
  ),
  ['settings', 'c'] => _Stub('C ${location.queryParameters['q'] ?? ''}'),
  _ => null,
};

GoRouter _router(String location) => GoRouter(
  initialLocation: location,
  routes: [
    GoRoute(
      path: '/settings',
      builder: (context, state) => const Scaffold(
        body: SettingsPaneNavigator(
          sectionId: 'data',
          queryParam: 'dataPage',
          hub: _Hub(),
          pageFor: _pageFor,
        ),
      ),
      routes: [
        GoRoute(
          path: 'c',
          builder: (context, state) => const _Stub('C pushed'),
        ),
      ],
    ),
    GoRoute(path: '/other', builder: (context, state) => const _Stub('Other')),
  ],
);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

List<String> _stack(GoRouter router) =>
    Uri.parse(_location(router)).queryParametersAll['dataPage'] ?? const [];

Future<GoRouter> _pump(WidgetTester tester, String location) async {
  final router = _router(location);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('opens a page in the pane and Back returns to the hub', (
    tester,
  ) async {
    final router = await _pump(tester, '/settings?selected=data');
    expect(find.text('Hub'), findsOneWidget);

    await tester.tap(find.text('open a'));
    await tester.pumpAndSettle();

    expect(_location(router), '/settings?selected=data&dataPage=a');
    expect(find.text('Page A'), findsOneWidget);
    expect(find.text('Hub'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(_location(router), '/settings?selected=data');
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('pages opened from a pane page stack up in the pane', (
    tester,
  ) async {
    final router = await _pump(tester, '/settings?selected=data');

    await tester.tap(find.text('open a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open b'));
    await tester.pumpAndSettle();

    expect(_stack(router), ['a', 'a/b']);
    expect(find.text('Page B'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(_stack(router), ['a']);
    expect(find.text('Page A'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(_stack(router), isEmpty);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('the URL reopens the whole stack', (tester) async {
    final router = await _pump(
      tester,
      '/settings?selected=data&dataPage=a&dataPage=a%2Fb',
    );

    expect(find.text('Page B'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Page A'), findsOneWidget);
    expect(_stack(router), ['a']);
  });

  testWidgets('a page carries its own query parameters', (tester) async {
    await _pump(tester, '/settings?selected=data&dataPage=c%3Fq%3Dhello');

    expect(find.text('Page C hello'), findsOneWidget);
  });

  testWidgets('a location the pane cannot show is dropped from the stack', (
    tester,
  ) async {
    await _pump(
      tester,
      '/settings?selected=data&dataPage=bogus&dataPage=a&dataPage=nope%2Fx',
    );

    expect(find.text('Page A'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('a location outside the pane is pushed as a route', (
    tester,
  ) async {
    final router = await _pump(tester, '/settings?selected=data&dataPage=a');

    await tester.tap(find.text('open other'));
    await tester.pumpAndSettle();

    // A pushed route covers the whole window, pane included.
    expect(find.text('Page Other'), findsOneWidget);
    expect(find.text('Page A'), findsNothing);
    expect(_stack(router), ['a']);
  });

  testWidgets('opening a page already on the stack returns to it', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      '/settings?selected=data&dataPage=a&dataPage=a%2Fb',
    );

    await tester.tap(find.text('open a again'));
    await tester.pumpAndSettle();

    expect(_stack(router), ['a']);
    expect(find.text('Page A'), findsOneWidget);
  });

  testWidgets('replaceSettingsPage swaps the top page', (tester) async {
    final router = await _pump(tester, '/settings?selected=data&dataPage=a');

    await tester.tap(find.text('replace with c'));
    await tester.pumpAndSettle();

    expect(_stack(router), ['c']);
    expect(find.text('Page C '), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('Navigator.pop from a pane page closes it in the pane', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      '/settings?selected=data&dataPage=a&dataPage=a%2Fb',
    );

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(_stack(router), ['a']);
    expect(find.text('Page A'), findsOneWidget);
  });

  testWidgets('a system back closes the top pane page', (tester) async {
    final router = await _pump(
      tester,
      '/settings?selected=data&dataPage=a&dataPage=a%2Fb',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(_stack(router), ['a']);
    expect(find.text('Page A'), findsOneWidget);
  });

  testWidgets('two opens in one frame both complete', (tester) async {
    await _pump(tester, '/settings?selected=data');

    // A double tap lands both taps before the URL rebuilds the pane.
    final button = find.text('await c');
    await tester.tap(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Page C '), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('returns 2'), findsOneWidget);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('an open of the page already on top waits for it to close', (
    tester,
  ) async {
    await _pump(tester, '/settings?selected=data');

    final button = find.text('await c');
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();

    // Neither await has returned while the page is open.
    expect(find.text('returns 0', skipOffstage: false), findsOneWidget);
  });

  testWidgets('an awaited open completes when its page closes', (tester) async {
    await _pump(tester, '/settings?selected=data');

    await tester.tap(find.text('await c'));
    await tester.pumpAndSettle();
    expect(find.text('Page C '), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('returns 1'), findsOneWidget);
  });

  testWidgets('an awaited open completes when a page under it closes', (
    tester,
  ) async {
    await _pump(tester, '/settings?selected=data');

    await tester.tap(find.text('await c'));
    await tester.pumpAndSettle();

    // Leave the section entirely: the pane state goes away with it.
    await tester.pumpWidget(const MaterialApp(home: Text('elsewhere')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('outside a pane the helper pushes the route', (tester) async {
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) =>
              const _Stub('Start', links: {'open c': '/settings/c'}),
        ),
        GoRoute(
          path: '/settings/c',
          builder: (context, state) => const _Stub('C pushed'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open c'));
    await tester.pumpAndSettle();

    expect(find.text('Page C pushed'), findsOneWidget);
    expect(find.text('Page Start'), findsNothing);
    expect(router.canPop(), isTrue);
  });
}
