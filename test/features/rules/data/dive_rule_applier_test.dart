import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/data/services/dive_rule_applier.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

void main() {
  late AppDatabase db;
  final applier = DiveRuleApplier();

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd20', maxDepth: 20, waterType: 'fresh');
    await seedRuleDive(db, 'd35', maxDepth: 35, notes: 'Wall');
    await seedRuleDive(db, 'd45', maxDepth: 45);
    await db.customStatement(
      "INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at) "
      "VALUES ('x1', 'd45', 'deep', 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('cold', 'Cold', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_tags (id, dive_id, tag_id, created_at) "
      "VALUES ('y1', 'd20', 'cold', 0), ('y2', 'd35', 'cold', 0)",
    );
    await db.customStatement(
      "INSERT INTO buddies (id, name, created_at, updated_at) "
      "VALUES ('ann', 'Ann', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('set water type overwrites and records before and after', () async {
    const a = SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'});
    final r = await applier.apply(ruleOf(RuleSubject.dives, a), a, [
      'd20',
      'd35',
    ]);
    expect(r.changes.map((c) => c.targetId), ['d20', 'd35']);
    final first = r.changes.first;
    expect(first.field, 'waterType');
    expect(first.ruleId, 'r1');
    expect(first.ruleName, 'Rule one');
    expect(first.before, {'water_type': 'fresh'});
    expect(first.after, {'water_type': 'salt'});
    final row = await db
        .customSelect("SELECT water_type FROM dives WHERE id = 'd20'")
        .getSingle();
    expect(row.read<String>('water_type'), 'salt');
  });

  test('setting the value a dive already holds records nothing', () async {
    const a = SetDiveFieldAction(BulkField.waterType, {'waterType': 'fresh'});
    final r = await applier.apply(ruleOf(RuleSubject.dives, a), a, ['d20']);
    expect(r.changes, isEmpty);
  });

  test('add Deep to two dives, one already Deep, records one change', () async {
    const a = DiveMembershipAction(
      DiveCollection.diveTypes,
      MembershipMode.add,
      ['deep'],
    );
    final r = await applier.apply(ruleOf(RuleSubject.dives, a), a, [
      'd35',
      'd45',
    ]);
    expect(r.changes.single.targetId, 'd35');
    // A dive with no type rows holds its representative type; types are
    // recorded in order, the representative first, so undo can keep it.
    expect(r.changes.single.before, ['recreational']);
    expect(r.changes.single.after, ['recreational', 'deep']);
    expect(await ruleDiveTypes(db, 'd35'), ['deep', 'recreational']);
  });

  test('remove a tag records the list without it', () async {
    const a = DiveMembershipAction(DiveCollection.tags, MembershipMode.remove, [
      'cold',
    ]);
    final r = await applier.apply(ruleOf(RuleSubject.dives, a), a, [
      'd20',
      'd45',
    ]);
    expect(r.changes.single.targetId, 'd20');
    expect(r.changes.single.before, ['cold']);
    expect(r.changes.single.after, <String>[]);
  });

  test('append notes uses a blank line only after existing text', () async {
    const a = AppendDiveNotesAction('Boat dive');
    final r = await applier.apply(ruleOf(RuleSubject.dives, a), a, [
      'd20',
      'd35',
    ]);
    final byDive = {for (final c in r.changes) c.targetId: c};
    expect(byDive['d20']!.after, 'Boat dive');
    expect(byDive['d35']!.before, 'Wall');
    expect(byDive['d35']!.after, 'Wall\n\nBoat dive');
    final notes = await db
        .customSelect("SELECT notes FROM dives WHERE id = 'd35'")
        .getSingle();
    expect(notes.read<String>('notes'), 'Wall\n\nBoat dive');
  });

  test('a site-only tag added to dives widens to dives first', () async {
    // A link implies its scope (#1765); see the site applier's twin.
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      "applies_to_dives, applies_to_sites) VALUES ('reefy', 'Reefy', 0, 0, 0, 1)",
    );
    const a = DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
      'reefy',
    ]);
    await applier.apply(ruleOf(RuleSubject.dives, a), a, ['d20']);
    final tag = await db
        .customSelect("SELECT applies_to_dives FROM tags WHERE id = 'reefy'")
        .getSingle();
    expect(tag.read<int>('applies_to_dives'), 1);
  });

  test('adding a deleted tag is skipped and flagged', () async {
    const a = DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
      'gone',
    ]);
    final r = await applier.apply(ruleOf(RuleSubject.dives, a), a, ['d45']);
    expect(r.changes, isEmpty);
    expect(r.skippedMissingRef, isTrue);
  });

  test('a missing dive centre makes a set action skip', () async {
    const a = SetDiveFieldAction(BulkField.diveCenter, {
      'diveCenterId': 'nowhere',
    });
    final r = await applier.apply(ruleOf(RuleSubject.dives, a), a, ['d20']);
    expect(r.changes, isEmpty);
    expect(r.skippedMissingRef, isTrue);
  });

  test('add a buddy carries the role', () async {
    const a = DiveMembershipAction(DiveCollection.buddies, MembershipMode.add, [
      'ann',
    ], buddyRoleId: 'instructor');
    final r = await applier.apply(ruleOf(RuleSubject.dives, a), a, ['d20']);
    // Every role the buddy holds, so undo can put them all back.
    expect(r.changes.single.after, [
      {
        'id': 'ann',
        'roles': ['instructor'],
      },
    ]);
    final link = await db
        .customSelect("SELECT role FROM dive_buddies WHERE dive_id = 'd20'")
        .getSingle();
    expect(link.read<String>('role'), 'instructor');
  });
}
