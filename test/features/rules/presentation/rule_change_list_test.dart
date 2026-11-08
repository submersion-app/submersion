import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_change_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

RuleChange _change(String ruleId, String targetId, String text) => RuleChange(
  subject: RuleSubject.dives,
  targetId: targetId,
  ruleId: ruleId,
  ruleName: 'Wall',
  field: 'notes',
  before: '',
  after: text,
);

void main() {
  testWidgets('grouped by rule, two rules sharing a name stay apart', (
    tester,
  ) async {
    // A copy renamed back to its original's name is still another rule.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RuleChangeList(
            changes: [
              _change('r1', 'd1', 'Wall dive'),
              _change('r2', 'd2', 'Drift'),
            ],
            targets: const {},
            units: const UnitFormatter(AppSettings()),
            nameOf: (_, _) => null,
            grouping: RuleChangeGrouping.rule,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wall'), findsNWidgets(2));
  });

  group('gear a set only tagged (#4284)', () {
    final l = lookupAppLocalizations(const Locale('en'));
    const u = UnitFormatter(AppSettings());
    String? nameOf(QuerySubject subject, String id) => switch ((subject, id)) {
      (QuerySubject.equipment, 'bcd') => 'BCD',
      (QuerySubject.equipment, 'reg') => 'Reg',
      (QuerySubject.equipmentSets, 'warm') => 'Warm',
      _ => null,
    };
    RuleChange gear(List<Object> before, List<Object> after) => RuleChange(
      subject: RuleSubject.dives,
      targetId: 'd1',
      ruleId: 'r1',
      ruleName: 'Warm water',
      field: 'equipment',
      before: before,
      after: after,
    );

    test('names the set on the rows whose set changed', () {
      final d = describeRuleChange(
        l,
        u,
        gear(
          [
            {'id': 'bcd'},
            {'id': 'reg', 'set': 'warm'},
          ],
          [
            {'id': 'bcd', 'set': 'warm'},
            {'id': 'reg', 'set': 'warm'},
          ],
        ),
        nameOf,
      );

      expect(d.before, 'BCD, Reg');
      expect(d.after, 'BCD (Warm), Reg');
    });

    test('a plain add or remove reads by name alone', () {
      final d = describeRuleChange(
        l,
        u,
        gear(
          [
            {'id': 'bcd', 'set': 'warm'},
          ],
          [
            {'id': 'bcd', 'set': 'warm'},
            {'id': 'reg', 'set': 'warm'},
          ],
        ),
        nameOf,
      );

      expect(d.before, 'BCD');
      expect(d.after, 'BCD, Reg');
    });
  });
}
