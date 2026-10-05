import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/manage_currency_rules_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fab_clearance.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Settings > Manage > Certification currency (issue #2267): the built-in
/// catalog, read-only and copy-on-write, and the diver's custom rules.
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late CertificationCurrencyRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 1000, 1000)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('me');
    repo = CertificationCurrencyRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  Widget page() => ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ManageCurrencyRulesPage(),
    ),
  );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<List<CurrencyRule>> custom() async => [
    for (final r in await repo.getRules())
      if (!r.isBuiltIn) r,
  ];

  CurrencyRule club() => CurrencyRule(
    id: 'club',
    diverId: 'me',
    name: 'Club cave check-out',
    clockKind: CurrencyClockKind.activity,
    lapseDays: 200,
    leadDays: 30,
    supersedesRuleId: 'cave_currency',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  testWidgets('built-ins list under Built-in with no row actions', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('Built-in'), findsOneWidget);
    expect(find.text('Your rules'), findsNothing);
    expect(find.text('Cave currency'), findsOneWidget);
    expect(find.text('PADI refresher (ReActivate)'), findsOneWidget);
    expect(
      find.text('Lapses 365 days after the last qualifying dive'),
      findsWidgets,
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('the FAB adds a custom rule under Your rules', (tester) async {
    tall(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New rule'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Spring refresher',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lapses after (days)'),
      '200',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Warn this many days before'),
      '30',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final rules = await custom();
    expect(rules.single.name, 'Spring refresher');
    expect(rules.single.diverId, 'me');
    expect(rules.single.lapseDays, 200);
    expect(rules.single.supersedesRuleId, isNull);
    expect(find.text('Your rules'), findsOneWidget);
    expect(find.text('Spring refresher'), findsOneWidget);
  });

  testWidgets('a name is required', (tester) async {
    tall(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(await custom(), isEmpty);
  });

  testWidgets('editing a built-in creates a custom rule that supersedes it', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cave currency'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Saving creates your own copy that replaces this built-in rule.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lapses after (days)'),
      '200',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final copy = (await custom()).single;
    expect(copy.supersedesRuleId, 'cave_currency');
    expect(copy.diverId, 'me');
    expect(copy.lapseDays, 200);
    expect(copy.countedDiveTypeIds, ['cave', 'cavern']);
    expect(copy.name, 'Cave currency');
    final builtIn = (await repo.getRules()).singleWhere(
      (r) => r.id == 'cave_currency',
    );
    expect(builtIn.lapseDays, 365, reason: 'the built-in row never changes');
    expect(find.text('Replaces Cave currency'), findsOneWidget);
    expect(find.text('Replaced by Cave currency'), findsOneWidget);
  });

  testWidgets('a custom rule edits in place', (tester) async {
    tall(tester);
    await repo.createRule(club());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit rule'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Club check-out',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final rules = await custom();
    expect(rules.single.id, 'club');
    expect(rules.single.name, 'Club check-out');
  });

  testWidgets('deleting a custom rule restores the built-in it replaced', (
    tester,
  ) async {
    tall(tester);
    await repo.createRule(club());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('Replaced by Club cave check-out'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete rule'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await custom(), isEmpty);
    expect(find.textContaining('Replaced by'), findsNothing);
  });

  testWidgets('a lead longer than the lapse is rejected', (tester) async {
    tall(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'X');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lapses after (days)'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Warn this many days before'),
      '60',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('The warning cannot start before the interval does'),
      findsOneWidget,
    );
    expect(await custom(), isEmpty);
  });

  testWidgets('the last row clears the FAB', (tester) async {
    useShortViewport(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await expectLastRowClearOfFab(tester);
  });
}
