import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/media_documents_locations.dart';
import 'package:submersion/features/media_documents/presentation/pages/media_documents_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/subtitle_text.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';

import '../../../../helpers/mock_providers.dart';

const _count = SubtitleText('3 entries');

/// A plain focusable spot in each stub tab. A text field would not do: on
/// phones a tap outside one, such as on the switch, unfocuses it first.
final Map<MediaDocumentsTab, FocusNode> _stubFocus = {};

/// A tab body with a long list, a text field and the header the host hands
/// it, standing in for the real Media/Documents pages.
Widget _stubBody(
  BuildContext context,
  MediaDocumentsTab tab,
  SectionHeaderTitle header,
) {
  final desktop = ResponsiveBreakpoints.isMasterDetail(context);
  return Scaffold(
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
          path: '/media',
          pageBuilder: (_, _) => mediaDocumentsHostPage(
            const MediaDocumentsPage(
              tab: MediaDocumentsTab.media,
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
          path: '/documents',
          pageBuilder: (_, _) => mediaDocumentsHostPage(
            const MediaDocumentsPage(
              tab: MediaDocumentsTab.documents,
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
  String initialLocation = '/media',
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
    .widget<TabBar>(
      find.byKey(const ValueKey('media_documents_section_toggle')).first,
    )
    .controller!;

void main() {
  testWidgets('opens on Media and builds Documents only when shown', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('built-media'), findsOneWidget);
    expect(find.text('built-documents'), findsNothing);
    expect(find.text('Media'), findsWidgets);
    expect(find.text('Documents'), findsWidgets);
  });

  testWidgets('tapping a tab moves the address there and back', (tester) async {
    final router = await _pump(tester);

    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();
    expect(_location(router), '/documents');
    expect(find.text('built-documents'), findsOneWidget);

    await tester.tap(find.text('Media').last);
    await tester.pumpAndSettle();
    expect(_location(router), '/media');
  });

  testWidgets('phone: a swipe switches tabs and the address follows', (
    tester,
  ) async {
    final router = await _pump(tester);

    await tester.fling(
      find.byKey(const ValueKey('list-media')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(_location(router), '/documents');
    expect(_controller(tester).index, MediaDocumentsTab.documents.index);
  });

  testWidgets('desktop: a swipe does not switch tabs', (tester) async {
    final router = await _pump(tester, size: const Size(1200, 800));

    await tester.fling(
      find.byKey(const ValueKey('list-media')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(_location(router), '/media');
  });

  testWidgets('desktop: a tap shows the other tab in place, no slide', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1200, 800));

    await tester.tap(find.text('Documents').first);
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('list-documents'))).dx,
      0,
    );
    expect(
      find.byKey(const ValueKey('list-media')).hitTestable(),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('each tab keeps its scroll and text across a switch', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const ValueKey('field-media')), 'abc');
    await tester.scrollUntilVisible(
      find.text('media item 60'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('list-media')),
        matching: find.byType(Scrollable),
      ),
    );

    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media').last);
    await tester.pumpAndSettle();

    expect(find.text('media item 60'), findsOneWidget);
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('an address change from outside selects its tab', (tester) async {
    final router = await _pump(tester);

    router.go('/documents');
    await tester.pumpAndSettle();

    expect(find.text('built-documents'), findsOneWidget);
    expect(_controller(tester).index, MediaDocumentsTab.documents.index);
  });

  testWidgets('desktop: each tab gets its own query back on return', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      initialLocation: '/media?selected=1',
      size: const Size(1200, 800),
    );

    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();
    expect(_location(router), '/documents');
    router.go('/documents?selected=9');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Media').last);
    await tester.pumpAndSettle();
    expect(_location(router), '/media?selected=1');

    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();
    expect(_location(router), '/documents?selected=9');
  });

  testWidgets(
    'back after a switch returns where Media and Documents was opened from',
    (tester) async {
      final router = await _pump(
        tester,
        initialLocation: '/home',
        size: const Size(700, 800),
      );

      router.push('/media');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents').first);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/documents');
      expect(find.text('built-documents'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), '/home');
    },
  );

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
    final mediaFocus = _stubFocus[MediaDocumentsTab.media]!;
    mediaFocus.requestFocus();
    await tester.pump();
    expect(mediaFocus.hasFocus, isTrue);

    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();
    expect(mediaFocus.hasFocus, isFalse);

    await tester.tap(find.text('Media').last);
    await tester.pumpAndSettle();
    expect(mediaFocus.hasFocus, isTrue);
  });

  testWidgets('both tabs visited, a push and pop raises no hero clash', (
    tester,
  ) async {
    final router = await _pump(tester);
    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media').last);
    await tester.pumpAndSettle();

    router.push('/media/detail');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
