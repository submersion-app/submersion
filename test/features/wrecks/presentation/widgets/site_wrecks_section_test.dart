import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';
import 'package:submersion/features/wrecks/presentation/providers/wreck_providers.dart';
import 'package:submersion/features/wrecks/presentation/widgets/site_wrecks_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _hilma = Wreck(
  id: 'w-1',
  siteId: 'site-1',
  name: 'Hilma Hooker',
  vesselTypeName: 'ship',
  depthToDeckMeters: 18,
);

/// Pumps the section and returns a getter for the router's current
/// location, so navigation assertions read the value after the tap.
Future<String? Function()> _pumpSection(
  WidgetTester tester, {
  List<Wreck> wrecks = const [_hilma],
  AppSettings settings = const AppSettings(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  String? location;

  final router = GoRouter(
    initialLocation: '/test',
    redirect: (context, state) {
      location = state.uri.toString();
      return null;
    },
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) =>
            const Scaffold(body: SiteWrecksSection(siteId: 'site-1')),
      ),
      GoRoute(
        path: '/wrecks/new',
        builder: (context, state) =>
            const Scaffold(body: Text('WRECK_NEW_PAGE')),
      ),
      GoRoute(
        path: '/wrecks/:id',
        builder: (context, state) =>
            const Scaffold(body: Text('WRECK_DETAIL_PAGE')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
        wrecksForSiteProvider('site-1').overrideWith((ref) async => wrecks),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return () => location;
}

void main() {
  testWidgets('the section lists linked wrecks and opens one', (tester) async {
    final location = await _pumpSection(tester);

    expect(find.text('Wrecks here'), findsOneWidget);
    expect(find.text('Hilma Hooker'), findsOneWidget);
    expect(find.textContaining('18 m'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('siteWreckRow-w-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WRECK_DETAIL_PAGE'), findsOneWidget);
    expect(location(), '/wrecks/w-1');
  });

  testWidgets('no linked wrecks renders nothing', (tester) async {
    await _pumpSection(tester, wrecks: const []);
    // An empty section must not occupy space on site detail.
    expect(find.text('Wrecks here'), findsNothing);
    expect(find.byKey(const ValueKey('siteWreckLinkButton')), findsNothing);
  });

  testWidgets('a feet diver reads the depth in feet', (tester) async {
    await _pumpSection(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    expect(find.textContaining('59.1 ft'), findsOneWidget);
  });

  testWidgets('a bare wreck row carries no empty subtitle line', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      wrecks: const [
        // No vessel type and no depth: there is nothing to subtitle.
        Wreck(id: 'w-9', siteId: 'site-1', name: 'Unknown hull'),
      ],
    );

    final tile = tester.widget<ListTile>(
      find.byKey(const ValueKey('siteWreckRow-w-9')),
    );
    expect(tile.subtitle, isNull);
  });

  testWidgets('the link action opens the create page', (tester) async {
    await _pumpSection(tester);
    await tester.tap(find.byKey(const ValueKey('siteWreckLinkButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WRECK_NEW_PAGE'), findsOneWidget);
  });
}
