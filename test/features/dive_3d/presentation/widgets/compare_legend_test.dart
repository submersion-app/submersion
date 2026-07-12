import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/divergence_builder.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_legend.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/mock_providers.dart';

ComparisonProfile prof(String id, String label, Color color) =>
    ComparisonProfile(
      id: id,
      label: label,
      color: color,
      times: const [0, 60],
      depths: const [0, 30],
      maxDepthMeters: 30,
    );

void main() {
  testWidgets('rows, focus tap, reference star, and max-delta text', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    int? focused;
    int? refSet;
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: CompareLegend(
          profiles: [
            prof('a', 'Perdix', const Color(0xFF00D4FF)),
            prof('b', 'Teric', const Color(0xFFFF9500)),
          ],
          referenceIndex: 0,
          onFocus: (i) => focused = i,
          onSetReference: (i) => refSet = i,
          maxGaps: const [
            DivergenceMark(profileId: 'b', atTimeSeconds: 60, gapMeters: 1.0),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Perdix'), findsOneWidget);
    expect(find.text('Teric'), findsOneWidget);
    // Reference row (index 0) is a filled star; the other is an outline.
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    // Non-reference profile 'b' shows a signed delta.
    expect(find.textContaining('+'), findsOneWidget);

    await tester.tap(find.text('Teric'));
    await tester.pump();
    expect(focused, 1);

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();
    expect(refSet, 1);
  });
}
