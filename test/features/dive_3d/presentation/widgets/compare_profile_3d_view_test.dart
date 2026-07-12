import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_legend.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_readout_panel.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/mock_providers.dart';

ComparisonProfile prof(String id, Color color) => ComparisonProfile(
  id: id,
  label: id,
  color: color,
  times: const [0, 60, 120],
  depths: const [0, 30, 0],
  maxDepthMeters: 30,
);

void main() {
  testWidgets('renders the compare scene with legend and readout', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: CompareProfile3dView(
          profiles: AsyncValue.data([
            prof('a', const Color(0xFF00D4FF)),
            prof('b', const Color(0xFFFF9500)),
          ]),
          title: 'Compare',
          initialLayout: CompareLayout.overlay,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    expect(find.byType(CompareLegend), findsOneWidget);
    expect(find.byType(CompareReadoutPanel), findsOneWidget);
    expect(find.text('Overlay'), findsOneWidget);
    expect(find.text('Side by side'), findsOneWidget);

    // Toggle layout without error.
    await tester.tap(find.text('Side by side'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows the empty state with fewer than two profiles', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: CompareProfile3dView(
          profiles: AsyncValue.data([prof('a', const Color(0xFF00D4FF))]),
          title: 'Compare',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Dive3dInteractiveViewport), findsNothing);
    expect(find.textContaining('at least 2'), findsOneWidget);
  });
}
