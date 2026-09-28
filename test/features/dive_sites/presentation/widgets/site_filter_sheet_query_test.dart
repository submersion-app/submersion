import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_filter_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The site filter sheet hosts the query editor and the Saved row (#2365
/// PR 3).
class _SheetLauncher extends ConsumerWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SiteFilterSheet(ref: ref),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  const now = 1735689600000;
  final difficult = ConditionNode(
    FieldPath(['difficulty']),
    QueryOp.eq,
    const EnumValue('advanced'),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> container({
    SiteFilterState filter = const SiteFilterState(),
  }) async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        siteFilterProvider.overrideWith((ref) => filter),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> open(WidgetTester tester, ProviderContainer c) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _SheetLauncher(),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
  }

  testWidgets('Save query works after the launching list is gone', (
    tester,
  ) async {
    // The sheet outlives the list that opened it (a layout change, a
    // navigation): the save must use the sheet's own ref, not the dead one
    // it was handed.
    final c = await container(filter: SiteFilterState(query: difficult));
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WidgetRef? launcherRef;
    final sheetKey = GlobalKey();
    Widget app({required bool launcher, required bool sheet}) =>
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  if (launcher)
                    Consumer(
                      builder: (context, ref, _) {
                        launcherRef = ref;
                        return const SizedBox();
                      },
                    ),
                  if (sheet)
                    Expanded(
                      child: SiteFilterSheet(key: sheetKey, ref: launcherRef!),
                    ),
                ],
              ),
            ),
          ),
        );
    // The launcher opens the sheet while alive...
    await tester.pumpWidget(app(launcher: true, sheet: false));
    await tester.pumpWidget(app(launcher: true, sheet: true));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    // ...then goes away; the keyed sheet keeps its state.
    await tester.pumpWidget(app(launcher: false, sheet: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save query'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a save message shows inside the sheet, not behind it', (
    tester,
  ) async {
    // The page's ScaffoldMessenger renders under the modal sheet, where the
    // diver never sees it; the sheet carries its own.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        siteFilterProvider.overrideWith(
          (ref) => SiteFilterState(query: difficult),
        ),
        // No diver profile: the save flow answers with a snackbar.
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    await open(tester, c);

    await tester.tap(find.text('Save query'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SiteFilterSheet),
        matching: find.byType(SnackBar),
      ),
      findsOneWidget,
    );
    // Above the footer, so Apply Filters stays reachable while it shows.
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Apply Filters')).top),
    );
  });

  testWidgets('a typed query is applied with the other axes', (tester) async {
    final c = await container(filter: const SiteFilterState(minRating: 3));
    await open(tester, c);
    await tester.enterText(
      // The query section leads the sheet, so its field is the first.
      find.byType(TextField).first,
      'difficulty = advanced',
    );
    await tester.pump();
    await apply(tester);
    final state = c.read(siteFilterProvider);
    expect(state.query, difficult);
    expect(state.minRating, 3);
  });

  testWidgets('a saved site query applies on tap', (tester) async {
    await tester.runAsync(
      () => SavedQueryRepository().create(
        subject: QuerySubject.sites,
        name: 'Hard sites',
        node: difficult,
        diverId: 'me',
      ),
    );
    final c = await container();
    await open(tester, c);
    await tester.tap(find.widgetWithText(ActionChip, 'Hard sites'));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(c.read(siteFilterProvider).query, difficult);
  });

  testWidgets('Apply keeps the query the sheet opened with', (tester) async {
    final c = await container(filter: SiteFilterState(query: difficult));
    await open(tester, c);
    await apply(tester);
    expect(c.read(siteFilterProvider).query, difficult);
  });

  testWidgets('Clear all clears the query', (tester) async {
    final c = await container(filter: SiteFilterState(query: difficult));
    await open(tester, c);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(c.read(siteFilterProvider).query, isNull);
  });
}
