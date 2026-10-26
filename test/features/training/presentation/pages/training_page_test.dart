import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/training_locations.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/training/presentation/pages/training_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/subtitle_text.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';

import '../../../../helpers/mock_providers.dart';

const _count = SubtitleText('3 entries');

/// A plain focusable spot in each stub tab. A text field would not do: on
/// phones a tap outside one, such as on the switch, unfocuses it first.
final Map<TrainingTab, FocusNode> _stubFocus = {};

/// A tab body with a long list, a text field and the header the host hands
/// it, standing in for the real list pages.
Widget _stubBody(
  BuildContext context,
  TrainingTab tab,
  SectionHeaderTitle header,
  Map<String, String> _,
) {
  final desktop = ResponsiveBreakpoints.isMasterDetail(context);
  return Scaffold(
    // The default hero tag, as both real list pages' add buttons have.
    floatingActionButton: FloatingActionButton(
      onPressed: () {},
      child: const Icon(Icons.add),
    ),
    appBar: desktop
        ? null
        : header.pinAppBar(
            AppBar(
              toolbarHeight: header.appBarHeight(context, _count),
              title: header.build(context, SectionHeaderSlot.appBar, _count),
            ),
          ),
    body: Column(
      children: [
        if (desktop) header.build(context, SectionHeaderSlot.pane, _count),
        Text('built-${tab.name}'),
        Focus(
          focusNode: _stubFocus.putIfAbsent(tab, FocusNode.new),
          child: const SizedBox(height: 1),
        ),
        TextField(key: ValueKey('field-${tab.name}')),
        Expanded(
          child: ListView.builder(
            key: ValueKey('list-${tab.name}'),
            itemCount: 100,
            itemExtent: 50,
            itemBuilder: (_, i) => Text('${tab.name} item $i'),
          ),
        ),
      ],
    ),
  );
}

GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/certifications',
          pageBuilder: (_, _) => trainingHostPage(
            const TrainingPage(
              tab: TrainingTab.certifications,
              tabBodyBuilder: _stubBody,
            ),
          ),
          routes: [
            GoRoute(
              path: 'detail',
              builder: (_, _) => const Scaffold(body: Text('detail')),
            ),
          ],
        ),
        GoRoute(
          path: '/courses',
          pageBuilder: (_, _) => trainingHostPage(
            const TrainingPage(
              tab: TrainingTab.courses,
              tabBodyBuilder: _stubBody,
            ),
          ),
        ),
      ],
    ),
  ],
);

Future<GoRouter> _pump(
  WidgetTester tester, {
  String initialLocation = '/certifications',
  Size size = const Size(400, 800),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final router = _router(initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// The tab bar of the switch in the visible tab's header.
TabController _controller(WidgetTester tester) => tester
    .widget<TabBar>(find.byKey(const ValueKey('training_section_toggle')).first)
    .controller!;

void main() {
  testWidgets('opens on Certifications and builds Courses only when shown', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('built-certifications'), findsOneWidget);
    expect(find.text('built-courses'), findsNothing);
    expect(find.text('Certifications'), findsWidgets);
    expect(find.text('Courses'), findsWidgets);
  });

  testWidgets('tapping a tab moves the address there and back', (tester) async {
    final router = await _pump(tester);

    await tester.tap(find.text('Courses').first);
    await tester.pumpAndSettle();
    expect(_location(router), '/courses');
    expect(find.text('built-courses'), findsOneWidget);

    await tester.tap(find.text('Certifications').last);
    await tester.pumpAndSettle();
    expect(_location(router), '/certifications');
  });

  testWidgets('phone: a swipe switches tabs and the address follows', (
    tester,
  ) async {
    final router = await _pump(tester);

    await tester.fling(
      find.byKey(const ValueKey('list-certifications')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(_location(router), '/courses');
    expect(_controller(tester).index, TrainingTab.courses.index);
  });

  testWidgets('desktop: a swipe does not switch tabs', (tester) async {
    final router = await _pump(tester, size: const Size(1200, 800));

    await tester.fling(
      find.byKey(const ValueKey('list-certifications')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(_location(router), '/certifications');
  });

  testWidgets('desktop: a tap shows the other tab in place, no slide', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1200, 800));

    await tester.tap(find.text('Courses').first);
    await tester.pump();

    // On the very next frame, not after a slide: Courses fills the page and
    // Certifications is gone from it.
    expect(tester.getTopLeft(find.byKey(const ValueKey('list-courses'))).dx, 0);
    expect(
      find.byKey(const ValueKey('list-certifications')).hitTestable(),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('phone: the header holds still while the list slides', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Courses').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-switch: the list is on its way out...
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('list-certifications'))).dx,
      lessThan(0),
    );
    // ...with Courses sliding in, not a blank page on its first visit...
    expect(find.text('built-courses'), findsOneWidget);
    // ...while both tabs' app bars stay where the header always sits.
    final bars = find.byType(AppBar).evaluate().toList();
    expect(bars, hasLength(2));
    for (final bar in bars) {
      final box = bar.renderObject! as RenderBox;
      expect(box.localToGlobal(Offset.zero).dx, 0);
    }
    await tester.pumpAndSettle();
  });

  testWidgets('each tab keeps its scroll and text across a switch', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field-certifications')),
      'abc',
    );
    await tester.scrollUntilVisible(
      find.text('certifications item 60'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('list-certifications')),
        matching: find.byType(Scrollable),
      ),
    );

    await tester.tap(find.text('Courses').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Certifications').last);
    await tester.pumpAndSettle();

    expect(find.text('certifications item 60'), findsOneWidget);
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('a tab keeps its text across a resize past the breakpoint', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1200, 800));
    await tester.enterText(
      find.byKey(const ValueKey('field-certifications')),
      'abc',
    );

    // Desktop's in-place stack to the phone's sliding pages and back.
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(find.text('abc'), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('an address change from outside selects its tab', (tester) async {
    final router = await _pump(tester);

    router.go('/courses');
    await tester.pumpAndSettle();

    expect(find.text('built-courses'), findsOneWidget);
    expect(_controller(tester).index, TrainingTab.courses.index);
  });

  testWidgets('desktop: each tab gets its own query back on return', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      initialLocation: '/certifications?selected=1',
      size: const Size(1200, 800),
    );

    await tester.tap(find.text('Courses').first);
    await tester.pumpAndSettle();
    expect(_location(router), '/courses');
    router.go('/courses?selected=9');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Certifications').last);
    await tester.pumpAndSettle();
    expect(_location(router), '/certifications?selected=1');

    await tester.tap(find.text('Courses').first);
    await tester.pumpAndSettle();
    expect(_location(router), '/courses?selected=9');
  });

  testWidgets('back after a switch returns where Training was opened from', (
    tester,
  ) async {
    // Wider than the other phone tests: the pushed page's back button moves
    // the switch right, and the test font draws every glyph a full em wide.
    final router = await _pump(
      tester,
      initialLocation: '/home',
      size: const Size(700, 800),
    );

    router.push('/certifications');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courses').first);
    await tester.pumpAndSettle();
    // A pushed page leaves currentConfiguration.uri at the page under it, so
    // read the top page's own location.
    expect(router.state.uri.toString(), '/courses');
    expect(find.text('built-courses'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(_location(router), '/home');
  });

  testWidgets('phone at large text: the toolbar grows to keep the count', (
    tester,
  ) async {
    await _pump(tester, size: const Size(360, 800), textScale: 1.5);

    expect(tester.takeException(), isNull);
    final count = tester.getRect(find.text('3 entries'));
    final bar = tester.getRect(find.byType(AppBar));
    expect(count.bottom, lessThanOrEqualTo(bar.bottom));
    // Grown by exactly the switch, the gap and the count: no dead space
    // under the count, and none of it cut off (#3663).
    final toolbar = tester.getRect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(NavigationToolbar),
      ),
    );
    expect(count.bottom, closeTo(toolbar.bottom, 0.5));
    // A name too long for the bar scrolls into reach rather than clipping.
    final tabBar = tester.widget<TabBar>(
      find.byKey(const ValueKey('training_section_toggle')),
    );
    expect(tabBar.isScrollable, isTrue);
  });

  // The count is its own line, not pressed against the selected name's
  // underline (#3663).
  for (final (label, size) in <(String, Size)>[
    ('phone', const Size(400, 800)),
    ('desktop', const Size(1400, 900)),
  ]) {
    testWidgets('$label: the count sits a gap under the underline', (
      tester,
    ) async {
      await _pump(tester, size: size);

      final underline = tester
          .getRect(find.byKey(const ValueKey('training_section_toggle')).first)
          .bottom;
      final count = tester.getRect(find.text('3 entries').first).top;
      expect(count - underline, closeTo(SectionTitleToggle.subtitleGap, 0.5));
    });
  }

  testWidgets('phone: the switch, gap and count fill the standard bar', (
    tester,
  ) async {
    await _pump(tester);

    final toolbar = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(NavigationToolbar),
    );
    expect(tester.getSize(toolbar).height, kToolbarHeight);
    final count = tester.getRect(find.text('3 entries'));
    expect(count.bottom, lessThanOrEqualTo(tester.getRect(toolbar).bottom));
  });

  testWidgets('focus leaves a tab when it is hidden and comes back with it', (
    tester,
  ) async {
    addTearDown(() {
      for (final node in _stubFocus.values) {
        node.dispose();
      }
      _stubFocus.clear();
    });
    await _pump(tester);
    final certFocus = _stubFocus[TrainingTab.certifications]!;
    certFocus.requestFocus();
    await tester.pump();
    expect(certFocus.hasFocus, isTrue);

    await tester.tap(find.text('Courses').first);
    await tester.pumpAndSettle();
    expect(certFocus.hasFocus, isFalse);

    await tester.tap(find.text('Certifications').last);
    await tester.pumpAndSettle();
    expect(certFocus.hasFocus, isTrue);
  });

  testWidgets('both tabs visited, a push and pop raises no hero clash', (
    tester,
  ) async {
    final router = await _pump(tester);
    await tester.tap(find.text('Courses').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Certifications').last);
    await tester.pumpAndSettle();

    router.push('/certifications/detail');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
