import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

Widget _buildHarness({
  required SharedPreferences prefs,
  required List<Diver> divers,
  required bool shareByDefault,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allDiversProvider.overrideWith((_) async => divers),
      shareByDefaultProvider.overrideWith((_) async => shareByDefault),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SiteEditPage(),
    ),
  );
}

Widget _buildMergeHarness({
  required SharedPreferences prefs,
  required List<Diver> divers,
  required List<String> mergeSiteIds,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allDiversProvider.overrideWith((_) async => divers),
      shareByDefaultProvider.overrideWith((_) async => false),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SiteEditPage(mergeSiteIds: mergeSiteIds),
    ),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('share toggle', () {
    testWidgets('hides the toggle when only one diver exists', (tester) async {
      final oneDiver = [
        Diver(
          id: 'd1',
          name: 'One',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];

      await tester.pumpWidget(
        _buildHarness(prefs: prefs, divers: oneDiver, shareByDefault: false),
      );

      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SwitchListTile &&
              w.title is Text &&
              (w.title as Text).data == 'Share with all dive profiles',
        ),
        findsNothing,
      );
    });

    testWidgets('shows toggle reflecting AppSettings default with 2+ divers', (
      tester,
    ) async {
      final twoDivers = [
        Diver(
          id: 'd1',
          name: 'One',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
        Diver(
          id: 'd2',
          name: 'Two',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];

      await tester.pumpWidget(
        _buildHarness(prefs: prefs, divers: twoDivers, shareByDefault: true),
      );

      await tester.pumpAndSettle();

      // Scroll until the share toggle is visible (it appears near the end of the form).
      await tester.scrollUntilVisible(
        find.text('Share with all dive profiles'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (w) =>
            w is SwitchListTile &&
            w.title is Text &&
            (w.title as Text).data == 'Share with all dive profiles',
      );
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    });
  });

  group('merge mode share toggle', () {
    // Regression test: _initializeFromMerge must restore isShared from the
    // primary (first) site so that merging a shared site does not silently
    // unshare it.
    testWidgets('preserves isShared=true from the primary merged site', (
      tester,
    ) async {
      final twoDivers = [
        Diver(
          id: 'd1',
          name: 'One',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
        Diver(
          id: 'd2',
          name: 'Two',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];

      // Seed two sites into the test database. The first is shared.
      final repo = SiteRepository();
      final primarySite = await repo.createSite(
        const DiveSite(
          id: 'site-primary',
          name: 'Primary Site',
          isShared: true,
        ),
      );
      await repo.createSite(
        const DiveSite(
          id: 'site-secondary',
          name: 'Secondary Site',
          isShared: false,
        ),
      );

      await tester.pumpWidget(
        _buildMergeHarness(
          prefs: prefs,
          divers: twoDivers,
          mergeSiteIds: [primarySite.id, 'site-secondary'],
        ),
      );

      await tester.pumpAndSettle();

      // Scroll until the share toggle is visible.
      await tester.scrollUntilVisible(
        find.text('Share with all dive profiles'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (w) =>
            w is SwitchListTile &&
            w.title is Text &&
            (w.title as Text).data == 'Share with all dive profiles',
      );
      expect(switchFinder, findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(switchFinder).value,
        isTrue,
        reason:
            'Merging a shared primary site must preserve isShared=true; '
            '_initializeFromMerge was not setting _isShared before the fix.',
      );
    });
  });
}
