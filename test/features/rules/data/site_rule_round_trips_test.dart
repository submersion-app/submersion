import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/data/services/rule_target_scope.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/data/services/site_rule_applier.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

/// A site rule's cost (#4012): each action's statements are counted in id
/// chunks, never one or more per site, and running it over many sites keeps
/// what the site-by-site writes did.
void main() {
  late AppDatabase db;

  /// The statements [body] sends. A long argument list reaches the print
  /// hook as two calls, so only lines naming a statement count.
  Future<List<String>> statementsOf(Future<void> Function() body) async {
    final sent = <String>[];
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (line.startsWith('Drift: ')) sent.add(line);
        },
      ),
    );
    return sent;
  }

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('n');

  Future<void> seedSites(int n) => statementsOf(
    () => db.batch(
      (b) => b.insertAll(db.diveSites, [
        for (var i = 0; i < n; i++)
          DiveSitesCompanion.insert(
            id: 's$i',
            name: 'Site $i',
            diverId: const Value('me'),
            createdAt: kRuleTs,
            updatedAt: kRuleTs,
          ),
      ]),
    ),
  );

  List<String> siteIds(int n) => [for (var i = 0; i < n; i++) 's$i'];

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        logStatements: true,
        setup: registerAppSqlFunctions,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
    await statementsOf(() async {
      await seedRuleDivers(db, ['me']);
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_dives, applies_to_sites) VALUES "
        "('site', 'Site tag', 0, 0, 0, 1), "
        "('dive', 'Dive tag', 0, 0, 1, 0)",
      );
    });
  });
  tearDown(tearDownTestDatabase);

  group('statements stay governed by chunks', () {
    const actions = <String, RuleAction>{
      'add a tag': SiteMembershipAction(
        SiteCollection.tags,
        MembershipMode.add,
        ['site'],
      ),
      'add a dive-only tag': SiteMembershipAction(
        SiteCollection.tags,
        MembershipMode.add,
        ['dive'],
      ),
      'remove a tag': SiteMembershipAction(
        SiteCollection.tags,
        MembershipMode.remove,
        ['held'],
      ),
      'add a type': SiteMembershipAction(
        SiteCollection.siteTypes,
        MembershipMode.add,
        ['reef'],
      ),
      'remove a type': SiteMembershipAction(
        SiteCollection.siteTypes,
        MembershipMode.remove,
        ['reef'],
      ),
      'set a field': SetSiteFieldAction(SiteRuleField.country, 'Egypt'),
      'append text': AppendSiteDescriptionAction('Strong currents'),
    };

    for (final MapEntry(key: name, value: action) in actions.entries) {
      for (final n in const [100, 500, 1000]) {
        test('$name on $n sites', () async {
          await seedSites(n);
          final ids = siteIds(n);
          await statementsOf(() async {
            await db.customStatement(
              "INSERT INTO tags (id, name, created_at, updated_at, "
              "applies_to_sites) VALUES ('held', 'Held', 0, 0, 1)",
            );
            await db.batch((b) {
              b.insertAll(db.siteTags, [
                for (final id in ids)
                  SiteTagsCompanion.insert(
                    id: 'l$id',
                    siteId: id,
                    tagId: 'held',
                    createdAt: 0,
                  ),
              ]);
              if (name == 'remove a type') {
                b.insertAll(db.siteSiteTypes, [
                  for (final id in ids)
                    SiteSiteTypesCompanion.insert(
                      id: 't$id',
                      siteId: id,
                      siteTypeId: 'reef',
                      createdAt: 0,
                    ),
                ]);
              }
            });
          });

          late int changed;
          final sent = await statementsOf(() async {
            final applied = await SiteRuleApplier().apply(
              ruleOf(RuleSubject.sites, action),
              action,
              ids,
            );
            changed = applied.changes.length;
          });

          expect(changed, n);
          final chunks = (n / kRuleIdChunk).ceil();
          expect(sent.length, lessThanOrEqualTo(10 + 6 * chunks));
        });
      }
    }
  });

  test('a tag is read and widened once however many sites gain it', () async {
    await seedSites(50);
    const action = SiteMembershipAction(
      SiteCollection.tags,
      MembershipMode.add,
      ['dive'],
    );

    final sent = await statementsOf(
      () => SiteRuleApplier().apply(
        ruleOf(RuleSubject.sites, action),
        action,
        siteIds(50),
      ),
    );

    expect(sent.where((s) => s.contains('SELECT * FROM "tags"')), hasLength(1));
    expect(
      sent.where((s) => s.contains('UPDATE "tags" SET "applies_to')),
      hasLength(1),
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'tags' AND record_id = 'dive'",
      ),
      1,
    );
  });

  group('through the engine', () {
    late RuleEngine engine;
    final rules = RuleRepository();

    const addDiveTag = SiteMembershipAction(
      SiteCollection.tags,
      MembershipMode.add,
      ['dive'],
    );
    const removeHeld = SiteMembershipAction(
      SiteCollection.tags,
      MembershipMode.remove,
      ['held'],
    );
    const request = RuleRunRequest(
      diverId: 'me',
      trigger: RuleRunTrigger.onDemandAll,
      targets: {RuleSubject.sites: null},
    );

    Future<void> ruleOver(String name, RuleAction action) => rules.create(
      diverId: 'me',
      subject: RuleSubject.sites,
      name: name,
      triggers: const {RuleTrigger.afterImport},
      condition: null,
      actions: [action],
    );

    setUp(() async {
      engine = RuleEngine(
        names: (_) async => NameIndex(const []),
        deviceLabel: () async => 'Test device',
      );
      await seedSites(3);
      await statementsOf(() async {
        await db.customStatement(
          "INSERT INTO tags (id, name, created_at, updated_at, "
          "applies_to_sites) VALUES ('held', 'Held', 0, 0, 1)",
        );
        await db.customStatement(
          "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
          "VALUES ('link', 's1', 'held', 0)",
        );
        await ruleOver('Add', addDiveTag);
        await ruleOver('Remove', removeHeld);
        await db.customStatement('DELETE FROM sync_records');
      });
    });

    test('a site that is not the diver\'s own is left alone', () async {
      await statementsOf(() async {
        await seedRuleDivers(db, ['them']);
        await seedRuleSite(db, 'theirs', owner: 'them');
        await seedRuleSite(db, 'lib', libraryId: 'club');
      });

      await engine.run(request);

      expect(
        await count(
          "SELECT COUNT(*) AS n FROM site_tags WHERE site_id IN "
          "('theirs', 'lib')",
        ),
        0,
      );
    });

    test('a preview leaves no link, scope or sync record behind', () async {
      final preview = await engine.preview(request);

      expect(preview.changedTargetCount, 3);
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM site_tags WHERE tag_id = 'dive'",
        ),
        0,
      );
      expect(
        await count("SELECT COUNT(*) AS n FROM site_tags WHERE id = 'link'"),
        1,
      );
      expect(
        await count("SELECT applies_to_sites AS n FROM tags WHERE id = 'dive'"),
        0,
      );
      expect(await count('SELECT COUNT(*) AS n FROM sync_records'), 0);
      expect(await count('SELECT COUNT(*) AS n FROM deletion_log'), 0);
    });

    test('Apply matches its preview, and Undo puts it back', () async {
      final preview = await engine.preview(request);
      final applied = await engine.run(request);

      String shape(RuleChange c) =>
          '${c.ruleName}:${c.targetId}:${c.before}:${c.after}';
      expect(applied.changes.map(shape), preview.changes.map(shape));
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM site_tags WHERE tag_id = 'dive'",
        ),
        3,
      );
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'siteTags' AND record_id = 'link'",
        ),
        1,
      );

      await RuleUndoService().undo(applied.runId!);

      expect(
        await count(
          "SELECT COUNT(*) AS n FROM site_tags WHERE tag_id = 'dive'",
        ),
        0,
      );
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM site_tags "
          "WHERE site_id = 's1' AND tag_id = 'held'",
        ),
        1,
      );
      expect(
        await count("SELECT applies_to_sites AS n FROM tags WHERE id = 'dive'"),
        1,
      );
    });
  });
}
