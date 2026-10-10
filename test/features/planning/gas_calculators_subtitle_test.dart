import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/planning/presentation/planning_tools.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/test_app.dart';

/// The Gas Calculators row on the Planning hub once listed four calculators
/// by name and went stale as MND/END, Gas Density and the Trimix blender
/// joined them (#3092). Its subtitle may describe the hub in general terms or
/// name every calculator, but never a subset of them.
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('Gas Calculators subtitle names none or all calculators '
        '(${locale.toLanguageTag()})', (tester) async {
      late String subtitle;
      late List<String> calculatorTitles;

      await tester.pumpWidget(
        testApp(
          locale: locale,
          child: Builder(
            builder: (context) {
              subtitle = planningToolsOf(
                context,
              ).firstWhere((t) => t.id == kGasCalculatorsToolId).subtitle;
              calculatorTitles = [
                for (final tool in gasCalculatorToolsOf(context)) tool.title,
              ];
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final named = calculatorTitles
          .where((title) => subtitle.contains(title))
          .toList();

      expect(
        named.isEmpty || named.length == calculatorTitles.length,
        isTrue,
        reason:
            'Subtitle "$subtitle" names $named but not the rest of '
            '$calculatorTitles',
      );
    });
  }
}
