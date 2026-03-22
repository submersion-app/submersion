import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(500, 844);

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  late SharedPreferences prefs;
  late SiteRepository siteRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    siteRepository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets(
    'merge completion exits multi-select mode and selects the merged survivor',
    (tester) async {
      _setMobileTestSurfaceSize(tester);

      await siteRepository.createSite(
        const DiveSite(id: 'site-1', name: 'Alpha Site'),
      );
      await siteRepository.createSite(
        const DiveSite(id: 'site-2', name: 'Bravo Site'),
      );
      await siteRepository.createSite(
        const DiveSite(id: 'site-3', name: 'Charlie Site'),
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _SiteListSelectionHarness(),
          ),
          GoRoute(
            path: '/sites/merge',
            builder: (context, state) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      context.pop(const SiteMergeResult(survivorId: 'site-1')),
                  child: const Text('Complete Merge'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            siteRepositoryProvider.overrideWithValue(siteRepository),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.longPress(find.text('Alpha Site'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Bravo Site'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Charlie Site'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.merge_type));
      await tester.pumpAndSettle();
      expect(find.text('Complete Merge'), findsOneWidget);

      await tester.tap(find.text('Complete Merge'));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsNothing);
      expect(find.text('2 selected'), findsNothing);
      expect(find.text('1 selected'), findsNothing);
      expect(find.text('selected:site-1'), findsOneWidget);
      expect(find.text('Dive Sites'), findsOneWidget);
    },
  );
}

class _SiteListSelectionHarness extends StatefulWidget {
  const _SiteListSelectionHarness();

  @override
  State<_SiteListSelectionHarness> createState() =>
      _SiteListSelectionHarnessState();
}

class _SiteListSelectionHarnessState extends State<_SiteListSelectionHarness> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text("selected:${_selectedId ?? 'none'}"),
          Expanded(
            child: SiteListContent(
              showAppBar: false,
              selectedId: _selectedId,
              onItemSelected: (id) {
                setState(() {
                  _selectedId = id;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
