import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_list_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SiteListPage(),
      ),
      GoRoute(
        path: '/sites/new',
        builder: (context, state) => const Scaffold(),
      ),
      GoRoute(
        path: '/sites/:id',
        builder: (context, state) => const Scaffold(),
      ),
    ],
  );
}

Future<List<Override>> _buildOverrides({
  List<SiteWithDiveCount> sites = const [],
  bool loading = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    sortedSitesWithCountsProvider.overrideWith(
      (ref) => loading
          ? const AsyncValue.loading()
          : AsyncValue.data(sites),
    ),
    siteListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
  ];
}

void main() {
  group('SiteListPage', () {
    testWidgets('shows Dive Sites title in app bar', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      final router = _buildRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dive Sites'), findsOneWidget);
    });

    testWidgets('shows Add Site FAB', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      final router = _buildRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Site'), findsOneWidget);
    });

    testWidgets('shows empty state when no sites', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      final router = _buildRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No dive sites yet'), findsOneWidget);
    });

    testWidgets('shows loading indicator while loading', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides(loading: true);
      final router = _buildRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
