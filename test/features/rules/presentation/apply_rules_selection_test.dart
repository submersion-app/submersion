import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/select_items_menu.dart';
import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

class _Dives extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _Dives(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// "Apply rules" on a selection runs the rules on the selected items only
/// (#3513).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd1', maxDepth: 35, number: 1);
    await seedRuleDive(db, 'd2', maxDepth: 40, number: 2);
    await seedRuleSite(db, 'a', name: 'Alpha');
    await seedRuleSite(db, 'lib', name: 'Library', libraryId: 'L');
    final rules = RuleRepository();
    await rules.create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Deep',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: const [
        DiveMembershipAction(DiveCollection.diveTypes, MembershipMode.add, [
          'deep',
        ]),
      ],
    );
    await rules.create(
      diverId: 'me',
      subject: RuleSubject.sites,
      name: 'Describe',
      triggers: const {RuleTrigger.afterImport},
      condition: null,
      actions: const [AppendSiteDescriptionAction('Checked')],
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> tapAction(WidgetTester tester) async {
    final inline = find.byKey(const ValueKey('selection_action_apply_rules'));
    if (inline.evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('selection_menu_apply_rules')),
      );
    } else {
      await tester.tap(inline);
    }
    await settleRuleWork(tester);
  }

  testWidgets('dive selection previews the selected dives only', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);
    final summaries = [
      for (final id in ['d1', 'd2'])
        DiveSummary.fromDive(
          Dive(
            id: id,
            dateTime: DateTime(2026, 1, id == 'd1' ? 1 : 2),
            site: DiveSite(id: 's$id', name: 'Site $id'),
          ),
        ),
    ];
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
            queryNameIndexProvider.overrideWith(
              (ref) async => NameIndex(const []),
            ),
            diveListViewModeProvider.overrideWith(
              (ref) => ListViewMode.detailed,
            ),
            paginatedDiveListProvider.overrideWith((ref) => _Dives(summaries)),
          ].cast(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveListContent()),
          ),
        ),
      );
    });
    await tester.pumpAndSettle();
    await enterSelectionViaMenu(tester);
    await tester.tap(
      find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == 'd1'),
    );
    await tester.pumpAndSettle();
    await tapAction(tester);
    expect(find.text('Apply rules to 1 dive?'), findsOneWidget);
    expect(find.text('1 dive will change.'), findsOneWidget);
  });

  testWidgets('a library site in the selection is left out and counted', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1200);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: SiteListContent(showAppBar: false)),
        ),
      ],
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs!),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
            queryNameIndexProvider.overrideWith(
              (ref) async => NameIndex(const []),
            ),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
    });
    await settleRuleWork(tester);
    await enterSelectionViaMenu(tester);
    for (final name in ['Alpha', 'Library']) {
      if (find.text(name).evaluate().isEmpty) continue;
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    await tapAction(tester);
    expect(find.text('1 site will change.'), findsOneWidget);
    expect(
      find.textContaining('1 selected item is not yours to change'),
      findsOneWidget,
    );
  });
}
