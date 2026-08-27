import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

import '../../../../helpers/test_app.dart';

TissueSurfaceGrid gridFixture() {
  // 2 columns x 1 compartment; percent 84 at (col1, comp0).
  final positions = Float32List.fromList([0, 0, 0, 10, 2.5, 0]);
  final pct = Float32List.fromList([10, 84]);
  return TissueSurfaceGrid(
    columns: 2,
    compartments: 1,
    positions: positions,
    normalizedTimes: const [0, 1],
    compartmentNumbers: const [6],
    halfTimesN2: const [27],
    saturationPct: pct,
  );
}

void main() {
  testWidgets('renders time, compartment, and saturation', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: TissueHoverTooltip(
          pick: const TissuePick(col: 1, comp: 0, screenPos: Offset.zero),
          grid: gridFixture(),
          runtimeSeconds: 1500, // 25:00 total; col1 (progress 1.0) = 25:00
          colorFn: thermalColor,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Comp 6'), findsOneWidget);
    expect(find.textContaining('Saturation 84%'), findsOneWidget);
    expect(find.textContaining('Off-gassing'), findsOneWidget);
    expect(find.textContaining('25:00'), findsOneWidget);
  });

  testWidgets('renders nothing for an out-of-range (stale) pick', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: TissueHoverTooltip(
          // grid has 2 columns x 1 compartment; this pick is out of range.
          pick: const TissuePick(col: 9, comp: 3, screenPos: Offset.zero),
          grid: gridFixture(),
          runtimeSeconds: 1500,
          colorFn: thermalColor,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Comp'), findsNothing);
    expect(find.textContaining('Saturation'), findsNothing);
  });

  testWidgets('falls back to percent-of-dive when runtime is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: TissueHoverTooltip(
          pick: const TissuePick(col: 0, comp: 0, screenPos: Offset.zero),
          grid: gridFixture(),
          runtimeSeconds: null,
          colorFn: thermalColor,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('% of dive'), findsOneWidget);
  });
}
