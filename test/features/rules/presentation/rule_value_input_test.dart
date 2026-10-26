import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/domain/rule_value_kind.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_value_input.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late String? previousLocale;

  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('a number is seeded with the locale\'s decimal separator', (
    tester,
  ) async {
    // As the other number fields seed theirs (#1091), so what the diver
    // reads and what they type back agree.
    Intl.defaultLocale = 'de';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RuleValueInput(
            kind: RuleValueKind.number,
            unit: RuleUnit.none,
            units: const UnitFormatter(AppSettings()),
            fieldName: 'setpointHigh',
            value: 1.3,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1,3'), findsOneWidget);
  });
}
