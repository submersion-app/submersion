import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_selector.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiveModeSelector(selectedMode: DiveMode.oc, onChanged: (_) {}),
        ),
      ),
    );
  }

  testWidgets('renders text-only labels, one line, no per-segment icons', (
    tester,
  ) async {
    await pump(tester);

    for (final label in ['OC', 'CCR', 'SCR', 'GAUGE']) {
      expect(find.text(label), findsOneWidget);
    }

    // Longest label stays on a single line, scaled to fit its segment.
    final gauge = find.text('GAUGE');
    expect(tester.widget<Text>(gauge).maxLines, 1);
    expect(
      find.ancestor(of: gauge, matching: find.byType(FittedBox)),
      findsOneWidget,
    );

    // The segments no longer carry icons (they were what overflowed the row).
    final segmentedButton = tester.widget<SegmentedButton<DiveMode>>(
      find.byType(SegmentedButton<DiveMode>),
    );
    expect(
      segmentedButton.segments.map((segment) => segment.icon),
      everyElement(isNull),
    );
  });
}
