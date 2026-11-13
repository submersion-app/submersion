import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_analysis_progress.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';

import '../../../../helpers/test_app.dart';

/// A deco filter on a library nothing has analyzed waits for the first
/// analysis (#4461); the list says how far it has got instead of spinning.
void main() {
  testWidgets('spins when no analysis is running', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const DecoAnalysisProgress(),
        overrides: [diveDecoStatusProgressProvider.overrideWith((ref) => null)],
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('shows how many dives the analysis has done', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const DecoAnalysisProgress(),
        overrides: [
          diveDecoStatusProgressProvider.overrideWith(
            (ref) => (analyzed: 3, total: 10),
          ),
        ],
      ),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.3, 1e-9));
    expect(find.text('Analyzing dives: 3 of 10'), findsOneWidget);
  });
}
