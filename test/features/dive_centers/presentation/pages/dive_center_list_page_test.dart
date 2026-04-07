import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_list_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
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

class _MockDiveCenterListNotifier
    extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDiveCenterListNotifier(AsyncValue<List<DiveCenter>> state)
    : super(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const DiveCenterListPage(),
      ),
      GoRoute(
        path: '/dive-centers/new',
        builder: (context, state) => const Scaffold(),
      ),
      GoRoute(
        path: '/dive-centers/:id',
        builder: (context, state) => const Scaffold(),
      ),
    ],
  );
}

Future<List<Override>> _buildOverrides({
  List<DiveCenter> centers = const [],
  bool loading = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    diveCenterListNotifierProvider.overrideWith(
      (ref) => _MockDiveCenterListNotifier(
        loading ? const AsyncValue.loading() : AsyncValue.data(centers),
      ),
    ),
    diveCenterListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
  ];
}

void main() {
  group('DiveCenterListPage', () {
    testWidgets('shows Dive Centers title in app bar', (tester) async {
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
      expect(find.text('Dive Centers'), findsOneWidget);
    });

    testWidgets('shows Add Dive Center FAB', (tester) async {
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
      expect(find.text('Add Dive Center'), findsOneWidget);
    });

    testWidgets('shows empty state when no dive centers', (tester) async {
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
      expect(find.text('No dive centers yet'), findsOneWidget);
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

    testWidgets('shows dive center names when data loaded', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final now = DateTime.now();
      final testCenters = [
        DiveCenter(
          id: '1',
          name: 'Blue Abyss Dive Center',
          createdAt: now,
          updatedAt: now,
        ),
        DiveCenter(
          id: '2',
          name: 'Coral Garden Divers',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final overrides = await _buildOverrides(centers: testCenters);
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
      expect(find.text('Blue Abyss Dive Center'), findsOneWidget);
      expect(find.text('Coral Garden Divers'), findsOneWidget);
    });
  });
}
