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
