import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
