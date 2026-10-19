import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/rules/data/services/site_rule_applier.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

Rule _rule(RuleAction a) => Rule(
  id: 'r1',
  diverId: 'me',
  subject: RuleSubject.sites,
  name: 'Red Sea',
  enabled: true,
  triggers: const {RuleTrigger.afterImport},
  condition: null,
  conditionJson: '',
  actions: [a],
  actionsJson: '',
  sortOrder: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

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
    final r = await applier.apply(_rule(a), a, ['a', 'b']);
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
    final r = await applier.apply(_rule(a), a, ['a']);
    expect(r.changes.single.before, <String>[]);
    expect(r.changes.single.after, ['red']);
  });

  test('remove a site type', () async {
    const a = SiteMembershipAction(
      SiteCollection.siteTypes,
      MembershipMode.remove,
      ['reef'],
    );
    final r = await applier.apply(_rule(a), a, ['a', 'b']);
    expect(r.changes.single.targetId, 'b');
    expect(r.changes.single.after, <String>[]);
  });

  test('append to the description', () async {
    const a = AppendSiteDescriptionAction('Strong currents');
    final r = await applier.apply(_rule(a), a, ['a', 'b']);
    final byId = {for (final c in r.changes) c.targetId: c};
    expect(byId['a']!.after, 'Strong currents');
    expect(byId['b']!.after, 'Wall\nStrong currents');
  });

  test('a deleted site tag is skipped and flagged', () async {
    const a = SiteMembershipAction(SiteCollection.tags, MembershipMode.add, [
      'gone',
    ]);
    final r = await applier.apply(_rule(a), a, ['a']);
    expect(r.changes, isEmpty);
    expect(r.skippedMissingRef, isTrue);
  });
}
