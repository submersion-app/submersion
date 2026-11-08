import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_action_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Equipment sets as a rule action (#4284): offered in the dive picker,
/// named in the rule's summary, and flagged once the set is deleted.
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  String? nameOf(QuerySubject subject, String id) =>
      subject == QuerySubject.equipmentSets && id == 'warm' ? 'Warm' : null;

  test('a dive rule can add or remove equipment sets', () {
    final labels = [
      for (final t in ruleActionTemplates(RuleSubject.dives))
        if (t.diveCollection == DiveCollection.equipmentSets) t.label(l),
    ];

    expect(labels, ['Add equipment sets', 'Remove equipment sets']);
  });

  test('sets name the equipment set subject', () {
    expect(
      diveCollectionSubject(DiveCollection.equipmentSets),
      QuerySubject.equipmentSets,
    );
  });

  test('the summary names the set, and a deleted one breaks it', () {
    const action = DiveMembershipAction(
      DiveCollection.equipmentSets,
      MembershipMode.add,
      ['warm'],
    );
    const gone = DiveMembershipAction(
      DiveCollection.equipmentSets,
      MembershipMode.remove,
      ['gone'],
    );

    expect(
      describeRuleAction(l, units, action, nameOf),
      'Add equipment sets: Warm',
    );
    expect(ruleActionIsBroken(action, nameOf), isFalse);
    expect(ruleActionIsBroken(gone, nameOf), isTrue);
  });
}
