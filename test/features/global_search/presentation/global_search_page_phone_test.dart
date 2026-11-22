import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/pages/global_search_page.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';

import '../helpers/global_search_page_harness.dart';

late SharedPreferences _prefs;

GlobalSearchSection _section(GlobalSearchKind kind, int count, {int? total}) =>
    globalSearchSection(kind, count, total: total);

Widget _app(
  Future<List<GlobalSearchSection>> Function(String text) answer, {
  List<dynamic> overrides = const [],
  String initialLocation = '/search',
  bool appShortcuts = false,
}) => globalSearchPageApp(
  answer,
  prefs: _prefs,
  overrides: overrides,
  initialLocation: initialLocation,
  appShortcuts: appShortcuts,
);

Future<void> _search(WidgetTester tester, String text) =>
    searchGlobally(tester, text);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  // The keyboard covers the bottom bar there, and Search, a nav destination,
  // has no back arrow: nothing may bring the keyboard up unasked, and a tap
  // off the field must put it away (#4813).
  group('on a phone', () {
    void usePhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    TextField field(WidgetTester tester) => tester.widget<TextField>(
      find.byKey(const ValueKey('global-search-field')),
    );

    testWidgets('arrives with the keyboard down', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(_app((_) async => const []));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Find dives, sites, trips, gear, buddies, documents and more',
        ),
        findsOneWidget,
      );
      expect(field(tester).focusNode!.hasFocus, isFalse);
    });

    testWidgets('a request made while the page is up leaves it down', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(_app((_) async => const []));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      container.read(globalSearchRequestProvider.notifier).state =
          GlobalSearchRequest('wreck');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(field(tester).controller!.text, 'wreck');
      expect(field(tester).focusNode!.hasFocus, isFalse);
    });

    testWidgets('a tap off the field puts the keyboard away', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(_app((_) async => const []));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('global-search-field')));
      await tester.pumpAndSettle();
      expect(field(tester).focusNode!.hasFocus, isTrue);

      await tester.tap(
        find.text(
          'Find dives, sites, trips, gear, buddies, documents and more',
        ),
      );
      await tester.pumpAndSettle();

      expect(field(tester).focusNode!.hasFocus, isFalse);
    });

    testWidgets('a focus request, from Ctrl+K, still brings the keyboard up', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(_app((_) async => const []));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      container.read(globalSearchFocusPendingProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(field(tester).focusNode!.hasFocus, isTrue);
    });

    testWidgets('a focus request made before the page opens is taken', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        _app(
          (_) async => const [],
          overrides: [
            globalSearchFocusPendingProvider.overrideWith((ref) => true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(field(tester).focusNode!.hasFocus, isTrue);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      expect(container.read(globalSearchFocusPendingProvider), isFalse);
    });

    testWidgets('Ctrl+K from another page opens Search with the caret in', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        _app(
          (_) async => const [],
          initialLocation: '/sites',
          appShortcuts: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('page /sites'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(GlobalSearchPage), findsOneWidget);
      expect(field(tester).focusNode!.hasFocus, isTrue);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      expect(container.read(globalSearchFocusPendingProvider), isFalse);
    });

    testWidgets('a focus request made under an open result is kept for Back', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        _app((_) async => [_section(GlobalSearchKind.buddies, 1)]),
      );
      await _search(tester, 'reef');
      await tester.tap(find.text('Hit 0'));
      await tester.pumpAndSettle();
      expect(find.text('page /buddies/id0'), findsOneWidget);

      // Ctrl+K over the record: the request is made, then the app walks back.
      final container = ProviderScope.containerOf(
        tester.element(find.text('page /buddies/id0')),
      );
      container.read(globalSearchFocusPendingProvider.notifier).state = true;
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(find.text('Hit 0'), findsOneWidget);
      expect(field(tester).focusNode!.hasFocus, isTrue);
      expect(container.read(globalSearchFocusPendingProvider), isFalse);
    });

    testWidgets(
      'a narrow desktop window has no on-screen keyboard, so keeps the focus',
      (tester) async {
        usePhone(tester);
        await tester.pumpWidget(_app((_) async => const []));
        await tester.pumpAndSettle();

        expect(field(tester).focusNode!.hasFocus, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('a tap on a completion keeps the keyboard up', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(_app((_) async => const []));
      await _search(tester, 'expir');

      await tester.tap(find.widgetWithText(ActionChip, 'expiryDate'));
      await tester.pumpAndSettle();

      expect(field(tester).controller!.text, 'expiryDate');
      expect(field(tester).focusNode!.hasFocus, isTrue);
    });
  });
}
