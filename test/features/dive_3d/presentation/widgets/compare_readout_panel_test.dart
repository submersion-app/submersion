import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_readout_panel.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/mock_providers.dart';

ComparisonProfile prof(String id, String label, Color color, List<double> d) =>
    ComparisonProfile(
      id: id,
      label: label,
      color: color,
      times: const [0, 120],
      depths: d,
      maxDepthMeters: d.reduce((a, b) => a > b ? a : b),
    );

void main() {
  testWidgets('shows per-profile depth and a signed delta vs reference', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final position = ValueNotifier<double>(0.5); // t = 60 s
    addTearDown(position.dispose);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: CompareReadoutPanel(
          profiles: [
            prof('a', 'Perdix', const Color(0xFF00D4FF), const [0, 30]),
            prof('b', 'Teric', const Color(0xFFFF9500), const [0, 32]),
          ],
          referenceIndex: 0,
          position: position,
          durationSeconds: 120,
        ),
      ),
    );
    await tester.pump();

    // At t=60: Perdix 15 m (reference, no delta), Teric 16 m (+1 delta).
    expect(find.textContaining('Perdix'), findsOneWidget);
    expect(find.textContaining('Teric'), findsOneWidget);
    expect(find.textContaining('+'), findsOneWidget);
  });
}
