import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_input.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VisibilityInputMode mode,
    VisibilityBand? band,
    ValueChanged<VisibilityBand?>? onBand,
    ValueChanged<VisibilityInputMode>? onMode,
    String? caption,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              VisibilityInput(
                mode: mode,
                onModeChanged: onMode ?? (_) {},
                controller: TextEditingController(),
                depthSymbol: 'm',
                inputValidator: null,
                onPreciseChanged: (_) {},
                band: band,
                onBandChanged: onBand ?? (_) {},
                caption: caption,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Range shows four band chips and reports a pick', (tester) async {
    VisibilityBand? picked;
    await pump(
      tester,
      mode: VisibilityInputMode.range,
      onBand: (b) => picked = b,
    );
    for (final name in ['Poor', 'Moderate', 'Good', 'Excellent']) {
      expect(find.widgetWithText(ChoiceChip, name), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
    expect(picked, VisibilityBand.good);
  });

  testWidgets('tapping the selected chip clears the pick', (tester) async {
    VisibilityBand? picked = VisibilityBand.good;
    await pump(
      tester,
      mode: VisibilityInputMode.range,
      band: VisibilityBand.good,
      onBand: (b) => picked = b,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
    expect(picked, isNull);
  });

  testWidgets('Precise shows the number field and no chips', (tester) async {
    await pump(tester, mode: VisibilityInputMode.precise);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Visibility'), findsOneWidget);
  });

  testWidgets('the segmented control switches mode', (tester) async {
    VisibilityInputMode? mode;
    await pump(
      tester,
      mode: VisibilityInputMode.precise,
      onMode: (m) => mode = m,
    );
    await tester.tap(find.text('Range'));
    expect(mode, VisibilityInputMode.range);
  });

  testWidgets('the caption shows under the input', (tester) async {
    await pump(tester, mode: VisibilityInputMode.range, caption: '6-12 m');
    expect(find.text('6-12 m'), findsOneWidget);
  });
}
