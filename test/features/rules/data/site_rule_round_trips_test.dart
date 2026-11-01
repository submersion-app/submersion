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

  const request = RuleRunRequest(
    diverId: 'me',
    trigger: RuleRunTrigger.onDemandAll,
    targets: {RuleSubject.sites: null},
  );

  RuleEngine newEngine() => RuleEngine(
    names: (_) async => NameIndex(const []),
    deviceLabel: () async => 'Test device',
  );

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

  group('a whole pass stays governed by chunks', () {
    for (final n in const [100, 500, 1000]) {
      test('Preview and Apply on $n sites', () async {
        await seedSites(n);
        await statementsOf(
          () => RuleRepository().create(
            diverId: 'me',
            subject: RuleSubject.sites,
            name: 'Add',
            triggers: const {RuleTrigger.afterImport},
            condition: null,
            actions: const [
              SiteMembershipAction(SiteCollection.tags, MembershipMode.add, [
                'site',
              ]),
            ],
          ),
        );
        final engine = newEngine();

        final previewed = await statementsOf(() => engine.preview(request));
        final applied = await statementsOf(() => engine.run(request));

        final chunks = (n / kRuleIdChunk).ceil();
        printOnFailure('preview ${previewed.length}, apply ${applied.length}');
        expect(previewed.length, lessThanOrEqualTo(15 + 5 * chunks));
        expect(applied.length, lessThanOrEqualTo(30 + 6 * chunks));
        expect(
          await count(
            "SELECT COUNT(*) AS n FROM sync_records "
            "WHERE entity_type = 'ruleRunChanges'",
          ),
          n,
        );
      });
    }
  });

  test('field and description writes reach every site past a chunk', () async {
    const sites = kRuleIdChunk + 1;
    await seedSites(sites);
    const setCountry = SetSiteFieldAction(SiteRuleField.country, 'Egypt');
    const append = AppendSiteDescriptionAction('Strong currents');

    await statementsOf(() async {
      final applier = SiteRuleApplier();
      for (final action in const <RuleAction>[setCountry, append]) {
        await applier.apply(
          ruleOf(RuleSubject.sites, action),
          action,
          siteIds(sites),
        );
      }
    });

    expect(
      await count(
        "SELECT COUNT(*) AS n FROM dive_sites WHERE country = 'Egypt' "
        "AND description = 'Strong currents' AND hlc IS NOT NULL",
      ),
      sites,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'diveSites' AND sync_status = 'pending'",
      ),
      sites,
    );
  });

  test('links past one chunk keep each site\'s order and go pending', () async {
    await seedSites(300);
    const action = SiteMembershipAction(
      SiteCollection.tags,
      MembershipMode.add,
      ['site', 'dive'],
    );

    await statementsOf(
      () => SiteRuleApplier().apply(
        ruleOf(RuleSubject.sites, action),
        action,
        siteIds(300),
      ),
    );

    expect(
      await count(
        "SELECT COUNT(*) AS n FROM site_tags first "
        "JOIN site_tags second ON second.site_id = first.site_id "
        "WHERE first.tag_id = 'site' AND second.tag_id = 'dive' "
        'AND first.created_at < second.created_at',
      ),
      300,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = 'siteTags'",
      ),
      600,
    );
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

    Future<void> ruleOver(String name, RuleAction action) => rules.create(
      diverId: 'me',
      subject: RuleSubject.sites,
      name: name,
      triggers: const {RuleTrigger.afterImport},
      condition: null,
      actions: [action],
    );

    setUp(() async {
      engine = newEngine();
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

    test('Undo puts a site\'s types back', () async {
      await statementsOf(() async {
        await db.customStatement(
          "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
          "VALUES ('held', 's0', 'wreck', 0)",
        );
        await ruleOver(
          'Add a type',
          const SiteMembershipAction(
            SiteCollection.siteTypes,
            MembershipMode.add,
            ['reef'],
          ),
        );
        await ruleOver(
          'Remove a type',
          const SiteMembershipAction(
            SiteCollection.siteTypes,
            MembershipMode.remove,
            ['wreck'],
          ),
        );
      });
      Future<int> types(String type) => count(
        "SELECT COUNT(*) AS n FROM site_site_types "
        "WHERE site_type_id = '$type'",
      );

      final applied = await engine.run(request);
      expect(await types('reef'), 3);
      expect(await types('wreck'), 0);

      await RuleUndoService().undo(applied.runId!);

      expect(await types('reef'), 0);
      expect(await types('wreck'), 1);
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
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'siteTags'",
        ),
        4,
        reason: "the removed link, then Undo's three",
      );
    });
  });
}
