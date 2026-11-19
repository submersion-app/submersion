import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/avelo_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/avelo_summary_block.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4664: a signed buoyancy keeps its sign beside its number in
/// right-to-left text, as the chart's buoyancy readout does.
void main() {
  testWidgets('signed weights are isolated in right-to-left text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AveloSummaryBlock(
            summary: AveloSummary(
              minBuoyancyKg: -0.4,
              maxBuoyancyKg: 1.2,
              meanBuoyancyKg: 0.4,
            ),
            units: UnitFormatter(AppSettings()),
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Avelo buoyancy \u2066-0.4 kg\u2069 to \u2066+1.2 kg\u2069, '
        'average \u2066+0.4 kg\u2069',
      ),
      findsOneWidget,
    );
  });
}
