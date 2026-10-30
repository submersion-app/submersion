import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../rules/rules_fixture.dart';

/// Logbook rules run on the first save of a dive logged by hand, never on a
/// later edit (#3513).
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    await seedRuleDivers(db, ['me']);
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('logged', 'Logged', 0, 0)",
    );
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Tag it',
      triggers: const {RuleTrigger.afterManualCreate},
      condition: null,
      actions: const [
        DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
          'logged',
        ]),
      ],
    );
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> tagsOf(String id) async => [
    for (final r
        in await db
            .customSelect(
              'SELECT tag_id FROM dive_tags WHERE dive_id = ?',
              variables: [Variable.withString(id)],
            )
            .get())
      r.read<String>('tag_id'),
  ];

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? diveId,
    required void Function(String) onSaved,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          queryNameIndexProvider.overrideWith(
            (ref) async => NameIndex(const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
  }

  /// A new dive form keeps an indicator spinning, so frames are pumped a
  /// fixed number of times with real time between them for the database.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save').first);
    await settleRuleWork(
      tester,
      rounds: 8,
      step: const Duration(milliseconds: 100),
      andSettle: false,
    );
  }

  testWidgets('a new dive saved by hand gets the rule\'s tag', (tester) async {
    String? savedId;
    await pumpEditor(tester, onSaved: (id) => savedId = id);
    // The dive list assigns a new dive to the current diver.
    await ProviderScope.containerOf(
      tester.element(find.byType(DiveEditPage)),
    ).read(currentDiverIdProvider.notifier).setCurrentDiver('me');
    await settleRuleWork(
      tester,
      rounds: 8,
      step: const Duration(milliseconds: 100),
      andSettle: false,
    );
    await save(tester);
    expect(savedId, isNotNull);
    expect(await tester.runAsync(() => tagsOf(savedId!)), ['logged']);
    expect(find.text('Rules changed this dive: Tag it'), findsOneWidget);
  });

  testWidgets('editing an existing dive runs no rules', (tester) async {
    late String id;
    await tester.runAsync(() async {
      await seedRuleDive(db, 'old', maxDepth: 20);
      id = 'old';
    });
    String? savedId;
    await pumpEditor(tester, diveId: id, onSaved: (s) => savedId = s);
    await settleRuleWork(
      tester,
      rounds: 8,
      step: const Duration(milliseconds: 100),
      andSettle: false,
    );
    await save(tester);
    expect(savedId, id);
    expect(await tester.runAsync(() => tagsOf(id)), isEmpty);
  });
}
