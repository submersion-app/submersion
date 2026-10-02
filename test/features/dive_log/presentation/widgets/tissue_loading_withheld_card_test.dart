import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_loading_withheld_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #2593: the notice that stands in for the deco and tissue cards when
/// a rebreather loop cannot be modelled. A CCR can be fixed by entering its
/// setpoint; a semi-closed loop only by a measured ppO2, so the two say
/// different things.
void main() {
  Future<AppLocalizations> pump(WidgetTester tester, DiveMode mode) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TissueLoadingWithheldCard(title: 'Deco Status', diveMode: mode),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(TissueLoadingWithheldCard)),
    );
  }

  testWidgets('a CCR is told to add its setpoint', (tester) async {
    final l10n = await pump(tester, DiveMode.ccr);

    expect(find.text('Deco Status'), findsOneWidget);
    expect(find.text(l10n.diveLog_deco_withheld_ccr), findsOneWidget);
    expect(find.text(l10n.diveLog_deco_withheld_scr), findsNothing);
  });

  testWidgets('a semi-closed loop is told it lacks a measured ppO2', (
    tester,
  ) async {
    final l10n = await pump(tester, DiveMode.scr);

    expect(find.text(l10n.diveLog_deco_withheld_scr), findsOneWidget);
    expect(find.text(l10n.diveLog_deco_withheld_ccr), findsNothing);
  });
}
