import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_actions_json.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';

void main() {
  const all = <RuleAction>[
    SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    DiveMembershipAction(DiveCollection.diveTypes, MembershipMode.add, [
      'deep',
    ]),
    DiveMembershipAction(DiveCollection.buddies, MembershipMode.add, [
      'b1',
    ], buddyRoleId: 'buddy'),
    DiveMembershipAction(DiveCollection.tags, MembershipMode.remove, ['t1']),
    AppendDiveNotesAction('Boat dive'),
    SetSiteFieldAction(SiteRuleField.country, 'Egypt'),
    SiteMembershipAction(SiteCollection.tags, MembershipMode.add, ['red-sea']),
    SiteMembershipAction(SiteCollection.siteTypes, MembershipMode.remove, [
      'reef',
    ]),
    AppendSiteDescriptionAction('Strong currents'),
  ];

  test('round-trips every action kind', () {
    final back = ruleActionsFromJson(ruleActionsToJson(all));
    expect(back, all);
  });

  test('writes the current version', () {
    expect(ruleActionsToJson(all)['version'], kRuleActionsJsonVersion);
    expect(kRuleActionsJsonVersion, 1);
  });

  test('refuses a newer version', () {
    expect(
      () => ruleActionsFromJson({'version': 2, 'actions': <Object?>[]}),
      throwsA(
        isA<RuleJsonException>().having(
          (e) => e.newerVersion,
          'newerVersion',
          isTrue,
        ),
      ),
    );
    expect(
      () => ruleActionsFromJson({'version': 1, 'actions': 'nope'}),
      throwsA(
        isA<RuleJsonException>().having(
          (e) => e.newerVersion,
          'newerVersion',
          isFalse,
        ),
      ),
    );
  });

  test('refuses a missing version or malformed list', () {
    expect(
      () => ruleActionsFromJson({'actions': <Object?>[]}),
      throwsA(isA<RuleJsonException>()),
    );
    expect(
      () => ruleActionsFromJson({'version': 1, 'actions': 'nope'}),
      throwsA(isA<RuleJsonException>()),
    );
    expect(
      () => ruleActionsFromJson({
        'version': 1,
        'actions': [
          {'kind': 'setDiveField', 'field': 42, 'values': {}},
        ],
      }),
      throwsA(isA<RuleJsonException>()),
    );
  });

  test('keeps an action naming a value a newer version added', () {
    // A field, collection or mode this version lacks: the action is kept
    // as it was stored (never run, saved back unchanged), and the rest of
    // the list still reads.
    final raws = [
      {
        'kind': 'setDiveField',
        'field': 'futureField',
        'values': {'futureField': 1},
      },
      {
        'kind': 'diveMembership',
        'collection': 'sightings',
        'mode': 'add',
        'ids': ['s1'],
      },
      {
        'kind': 'siteMembership',
        'collection': 'tags',
        'mode': 'replace',
        'ids': ['t1'],
      },
      {'kind': 'setSiteField', 'field': 'visibility', 'value': 10},
    ];
    final known = (ruleActionsToJson(all)['actions']! as List).first;
    final back = ruleActionsFromJson({
      'version': 1,
      'actions': [...raws, known],
    });
    expect(back.take(4), everyElement(isA<UnknownRuleAction>()));
    expect(back.last, all.first);
    expect((ruleActionsToJson(back)['actions']! as List).take(4), raws);
  });

  test('keeps an unknown kind', () {
    final raw = {'kind': 'addTank', 'volume': 12};
    final back = ruleActionsFromJson({
      'version': 1,
      'actions': [raw],
    });
    expect(back.single, isA<UnknownRuleAction>());
    expect((back.single as UnknownRuleAction).raw, raw);
  });
}
