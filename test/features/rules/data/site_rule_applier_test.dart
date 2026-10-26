import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/rules/data/services/site_rule_applier.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

void main() {
  late AppDatabase db;
  final applier = SiteRuleApplier();

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleSite(db, 'a', country: 'Egypt');
    await seedRuleSite(db, 'b', description: 'Wall');
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, applies_to_sites) "
      "VALUES ('red', 'Red Sea', 0, 0, 1)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('st1', 'b', 'reef', 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('set country records before and after per site', () async {
    const a = SetSiteFieldAction(SiteRuleField.country, 'Egypt');
    final r = await applier.apply(
      ruleOf(RuleSubject.sites, a, name: 'Red Sea'),
      a,
      ['a', 'b'],
    );
    expect(r.changes.single.targetId, 'b');
    expect(r.changes.single.subject, RuleSubject.sites);
    expect(r.changes.single.field, 'country');
    expect(r.changes.single.before, {'country': null});
    expect(r.changes.single.after, {'country': 'Egypt'});
    final row = await db
        .customSelect("SELECT country FROM dive_sites WHERE id = 'b'")
        .getSingle();
    expect(row.read<String>('country'), 'Egypt');
  });

  test('add a site tag', () async {
    const a = SiteMembershipAction(SiteCollection.tags, MembershipMode.add, [
      'red',
    ]);
    final r = await applier.apply(
      ruleOf(RuleSubject.sites, a, name: 'Red Sea'),
      a,
      ['a'],
    );
    expect(r.changes.single.before, <String>[]);
    expect(r.changes.single.after, ['red']);
  });

  test('a dive-only tag added to sites widens to sites first', () async {
    // A link implies its scope (#1765): an out-of-scope link is filtered
    // out of the Sites filter, refused by peers on sync, and swept away
    // the next time the tag row syncs.
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('deep', 'Deep', 0, 0)",
    );
    const a = SiteMembershipAction(SiteCollection.tags, MembershipMode.add, [
      'deep',
    ]);
    await applier.apply(ruleOf(RuleSubject.sites, a, name: 'Red Sea'), a, [
      'a',
    ]);
    final tag = await db
        .customSelect(
          "SELECT applies_to_sites, applies_to_dives FROM tags WHERE id = 'deep'",
        )
        .getSingle();
    expect(tag.read<int>('applies_to_sites'), 1);
    expect(tag.read<int>('applies_to_dives'), 1);
  });

  test('remove a site type', () async {
    const a = SiteMembershipAction(
      SiteCollection.siteTypes,
      MembershipMode.remove,
      ['reef'],
    );
    final r = await applier.apply(
      ruleOf(RuleSubject.sites, a, name: 'Red Sea'),
      a,
      ['a', 'b'],
    );
    expect(r.changes.single.targetId, 'b');
    expect(r.changes.single.after, <String>[]);
  });

  test('append to the description', () async {
    const a = AppendSiteDescriptionAction('Strong currents');
    final r = await applier.apply(
      ruleOf(RuleSubject.sites, a, name: 'Red Sea'),
      a,
      ['a', 'b'],
    );
    final byId = {for (final c in r.changes) c.targetId: c};
    expect(byId['a']!.after, 'Strong currents');
    expect(byId['b']!.after, 'Wall\nStrong currents');
  });

  test('a deleted site tag is skipped and flagged', () async {
    const a = SiteMembershipAction(SiteCollection.tags, MembershipMode.add, [
      'gone',
    ]);
    final r = await applier.apply(
      ruleOf(RuleSubject.sites, a, name: 'Red Sea'),
      a,
      ['a'],
    );
    expect(r.changes, isEmpty);
    expect(r.skippedMissingRef, isTrue);
  });
}
