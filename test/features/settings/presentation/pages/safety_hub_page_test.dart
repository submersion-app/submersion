import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/settings/presentation/pages/safety_hub_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _settings = AppSettings(gfLow: 30, gfHigh: 70);

Widget _plainApp(
  MockSettingsNotifier notifier, {
  void Function(SafetySubPage)? onOpenPage,
}) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => notifier)],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SafetyHubPage(onOpenPage: onOpenPage),
  ),
);

Widget _routedApp(GoRouter router) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier(_settings)),
  ],
  child: MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  ),
);

void main() {
  final reviewTotal = SafetyRuleId.values.length;
  final conditionTotal = ConditionRuleId.values.length;

  group('SafetySubPage', () {
    test('ids and phone routes', () {
      expect(SafetySubPage.review.id, 'review');
      expect(SafetySubPage.decompression.id, 'decompression');
      expect(SafetySubPage.equipmentCondition.id, 'equipment-condition');
      expect(
        SafetySubPage.equipmentCondition.phoneRoute,
        '/settings/safety/equipment-condition',
      );
    });

    test('fromId round-trips and rejects unknown ids', () {
      for (final page in SafetySubPage.values) {
        expect(SafetySubPage.fromId(page.id), page);
      }
      expect(SafetySubPage.fromId('bogus'), isNull);
      expect(SafetySubPage.fromId(null), isNull);
    });
  });

  group('SafetyHubPage', () {
    testWidgets('lists the three sub-pages in order with live subtitles', (
      tester,
    ) async {
      await tester.pumpWidget(_plainApp(MockSettingsNotifier(_settings)));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Safety')),
        findsOneWidget,
      );

      final review = find.byKey(const Key('safety-hub-review'));
      final deco = find.byKey(const Key('safety-hub-decompression'));
      final condition = find.byKey(const Key('safety-hub-equipment-condition'));
      expect(
        tester.getTopLeft(review).dy,
        lessThan(tester.getTopLeft(deco).dy),
      );
      expect(
        tester.getTopLeft(deco).dy,
        lessThan(tester.getTopLeft(condition).dy),
      );

      expect(
        find.descendant(of: review, matching: find.text('Safety review')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: review,
          matching: find.text(
            'On, $reviewTotal of $reviewTotal rules, no-fly Standard',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: deco, matching: find.text('GF 30/70')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: condition,
          matching: find.text('On, $conditionTotal of $conditionTotal rules'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rows read in the active locale', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => MockSettingsNotifier(_settings),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SafetyHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sicherheit'), findsOneWidget);
      expect(find.text('Dekompression'), findsOneWidget);
      expect(find.text('Ausrüstungszustand'), findsOneWidget);
      expect(find.text('Aus, Flugverbot Standard'), findsNothing);
      expect(
        find.text(
          'An, $reviewTotal von $reviewTotal Regeln, Flugverbot Standard',
        ),
        findsOneWidget,
      );
      expect(find.text('Equipment condition'), findsNothing);
    });

    testWidgets('subtitles follow setting changes', (tester) async {
      final notifier = MockSettingsNotifier(_settings);
      await tester.pumpWidget(_plainApp(notifier));
      await tester.pumpAndSettle();

      await notifier.setSafetyReviewEnabled(false);
      await tester.pumpAndSettle();

      expect(find.text('Off, no-fly Standard'), findsOneWidget);
    });

    testWidgets('with onOpenPage each row reports its page', (tester) async {
      final opened = <SafetySubPage>[];
      await tester.pumpWidget(
        _plainApp(MockSettingsNotifier(_settings), onOpenPage: opened.add),
      );
      await tester.pumpAndSettle();

      for (final page in SafetySubPage.values) {
        await tester.tap(find.byKey(Key('safety-hub-${page.id}')));
        await tester.pumpAndSettle();
      }

      expect(opened, SafetySubPage.values);
    });

    testWidgets('without onOpenPage a row pushes its phone route', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/settings/safety',
        routes: [
          GoRoute(
            path: '/settings/safety',
            builder: (context, state) => const SafetyHubPage(),
            routes: [
              GoRoute(
                path: 'decompression',
                builder: (context, state) =>
                    const Scaffold(body: Text('decompression page')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_routedApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('safety-hub-decompression')));
      await tester.pumpAndSettle();
      expect(find.text('decompression page'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-hub-decompression')), findsOneWidget);
    });
  });

  group('SafetySettingsPane', () {
    GoRouter paneRouter(String location) => GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SafetySettingsPane(),
        ),
      ],
    );

    String location(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('shows the hub, opens a sub-page, and comes back', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = paneRouter('/settings?selected=safety');
      addTearDown(router.dispose);

      await tester.pumpWidget(_routedApp(router));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-hub-decompression')), findsOneWidget);

      await tester.tap(find.byKey(const Key('safety-hub-decompression')));
      await tester.pumpAndSettle();
      expect(
        location(router),
        '/settings?selected=safety&safetyPage=decompression',
      );
      expect(find.text('GF 30/70'), findsOneWidget);
      expect(find.byKey(const Key('safety-hub-decompression')), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(location(router), '/settings?selected=safety');
      expect(find.byKey(const Key('safety-hub-decompression')), findsOneWidget);
    });

    testWidgets('opens Safety review from the URL', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = paneRouter('/settings?selected=safety&safetyPage=review');
      addTearDown(router.dispose);

      await tester.pumpWidget(_routedApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Post-dive safety review'), findsOneWidget);
    });

    testWidgets('an unknown safetyPage shows the hub', (tester) async {
      final router = paneRouter('/settings?selected=safety&safetyPage=bogus');
      addTearDown(router.dispose);

      await tester.pumpWidget(_routedApp(router));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('safety-hub-review')), findsOneWidget);
    });
  });
}
