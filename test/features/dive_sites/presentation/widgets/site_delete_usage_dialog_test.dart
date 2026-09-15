import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A site delete keeps the dives logged and plans set at the site, with the
/// site cleared (issue #1952). Every delete confirmation says so when the
/// site is in use, so nobody finds their dives unlinked by surprise.
void main() {
  const divesLine = '2 dives will be left without a site.';
  const planLine = '1 saved plan will be left without a site.';
  late SiteRepository siteRepository;
  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    database = DatabaseService.instance.database;
    siteRepository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  void setPhoneSize(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> seedDive(String id, String siteId) => database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(1000),
          siteId: Value(siteId),
          createdAt: const Value(1000),
          updatedAt: const Value(1000),
        ),
      );

  Future<void> seedPlan(String id, String siteId) =>
      DivePlanRepository().savePlan(
        DivePlan(
          id: id,
          name: id,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          gfLow: 30,
          gfHigh: 70,
          siteId: siteId,
        ),
      );

  /// A site two dives and a plan use, and one nothing uses.
  Future<void> seedSites() async {
    await siteRepository.createSite(
      const DiveSite(id: 'used', name: 'Used Site'),
    );
    await siteRepository.createSite(
      const DiveSite(id: 'unused', name: 'Unused Site'),
    );
    await seedDive('dive-1', 'used');
    await seedDive('dive-2', 'used');
    await seedPlan('plan-1', 'used');
  }

  Future<String?> diveSiteId(String diveId) async => (await (database.select(
    database.dives,
  )..where((t) => t.id.equals(diveId))).getSingle()).siteId;

  group('SiteDetailPage', () {
    Future<void> openDeleteDialog(WidgetTester tester, String siteId) async {
      setPhoneSize(tester);
      final site = await siteRepository.getSiteById(siteId);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(siteId).overrideWith((_) async => site),
            siteDiveCountProvider(siteId).overrideWith((_) async => 0),
            allDiversProvider.overrideWith((_) async => <Diver>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: SiteDetailPage(siteId: siteId, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    testWidgets('the delete dialog says how many dives and plans keep going '
        'without the site', (tester) async {
      await seedSites();

      await openDeleteDialog(tester, 'used');

      expect(find.textContaining(divesLine), findsOneWidget);
      expect(find.textContaining(planLine), findsOneWidget);
    });

    testWidgets('the delete dialog of a site nothing uses says nothing more', (
      tester,
    ) async {
      await seedSites();

      await openDeleteDialog(tester, 'unused');

      expect(find.textContaining('without a site'), findsNothing);
    });
  });

  testWidgets('SiteEditPage delete dialog says how many dives and plans keep '
      'going without the site', (tester) async {
    setPhoneSize(tester);
    await seedSites();
    final site = await siteRepository.getSiteById('used');
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => const <Diver>[]),
          shareByDefaultProvider.overrideWith((_) async => false),
          siteProvider('used').overrideWith((_) async => site),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: SiteEditPage(siteId: 'used'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.textContaining(divesLine), findsOneWidget);
    expect(find.textContaining(planLine), findsOneWidget);
  });

  testWidgets('SiteListContent bulk delete says how many dives and plans keep '
      'going without their site, and Undo links them back', (tester) async {
    setPhoneSize(tester);
    await seedSites();
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          siteRepositoryProvider.overrideWithValue(siteRepository),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: SiteListContent(showAppBar: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Used Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_delete')));
    await tester.pumpAndSettle();

    expect(find.textContaining(divesLine), findsOneWidget);
    expect(find.textContaining(planLine), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await diveSiteId('dive-1'), isNull);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await diveSiteId('dive-1'), 'used');
    expect(await diveSiteId('dive-2'), 'used');
  });
  testWidgets('SiteListContent bulk delete removes the sites its dialog '
      'described, even when the selection changes while it counts', (
    tester,
  ) async {
    setPhoneSize(tester);
    await seedSites();
    final gated = _GatedSiteRepository();
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          siteRepositoryProvider.overrideWithValue(gated),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: SiteListContent(showAppBar: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Used Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_delete')));
    await tester.pumpAndSettle();
    // The count is still being read: check a second site meanwhile.
    await tester.tap(find.text('Unused Site'));
    await tester.pumpAndSettle();
    gated.gate.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('delete 1 site?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await siteRepository.getSiteById('used'), isNull);
    expect(await siteRepository.getSiteById('unused'), isNotNull);
  });
}

/// Holds the delete's usage read until [gate] completes, so a test can
/// change the selection while the confirmation is still being prepared.
class _GatedSiteRepository extends SiteRepository {
  final gate = Completer<void>();

  @override
  Future<SiteUsage> getSiteUsage(List<String> siteIds) async {
    await gate.future;
    return super.getSiteUsage(siteIds);
  }
}
