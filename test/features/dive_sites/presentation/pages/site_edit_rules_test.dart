import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import '../../../rules/rules_fixture.dart';

/// Logbook rules run on the first save of a site created by hand, never on
/// a later edit (#3513).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleSite(db, 'old', name: 'Old Reef');
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, applies_to_sites) "
      "VALUES ('new', 'New', 0, 0, 1)",
    );
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.sites,
      name: 'Tag new sites',
      triggers: const {RuleTrigger.afterManualCreate},
      condition: null,
      actions: const [
        SiteMembershipAction(SiteCollection.tags, MembershipMode.add, ['new']),
      ],
    );
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> tagsOf(String siteId) async => [
    for (final r
        in await db
            .customSelect(
              "SELECT tag_id FROM site_tags WHERE site_id = '$siteId'",
            )
            .get())
      r.read<String>('tag_id'),
  ];

  Future<void> pumpEdit(
    WidgetTester tester, {
    String? siteId,
    required void Function(String) onSaved,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => const <Diver>[]),
          shareByDefaultProvider.overrideWith((_) async => false),
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'me'),
          queryNameIndexProvider.overrideWith((_) async => NameIndex(const [])),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              siteId: siteId,
              embedded: true,
              onSaved: onSaved,
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a new site saved by hand gets the rule\'s tag', (tester) async {
    String? savedId;
    await pumpEdit(tester, onSaved: (id) => savedId = id);
    await tester.enterText(find.byType(TextFormField).first, 'Blue Hole');
    await tester.tap(find.text('Save').first);
    await settleRuleWork(
      tester,
      rounds: 8,
      step: const Duration(milliseconds: 100),
      andSettle: false,
    );
    expect(savedId, isNotNull);
    expect(await tester.runAsync(() => tagsOf(savedId!)), ['new']);
  });

  testWidgets('editing an existing site runs no rules', (tester) async {
    String? savedId;
    await pumpEdit(tester, siteId: 'old', onSaved: (id) => savedId = id);
    await tester.tap(find.text('Save').first);
    await settleRuleWork(
      tester,
      rounds: 8,
      step: const Duration(milliseconds: 100),
      andSettle: false,
    );
    expect(savedId, 'old');
    expect(await tester.runAsync(() => tagsOf('old')), isEmpty);
  });
}
