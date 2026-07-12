import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/dead_reckoning_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

ReckonedPath reckoned() {
  const n = 30;
  return const DeadReckoningService().reckon(
    times: [for (var i = 0; i < n; i++) (i * 20).toDouble()],
    depths: [for (var i = 0; i < n; i++) (i < 15 ? i * 2.0 : (30 - i) * 2.0)],
    headings: [for (var i = 0; i < n; i++) (i * 6).toDouble()],
    swimSpeedMps: 0.4,
  );
}

void main() {
  testWidgets('renders the seascape and the honesty captions', (tester) async {
    final overrides = await getBaseOverrides();
    final path = reckoned();
    final scene = const SpatialGeometryService().build(path, siteMaxDepth: 30);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          spatialReckonedPathProvider('d1').overrideWith((ref) async => path),
          spatialGeometryProvider('d1').overrideWith((ref) async => scene),
        ],
        child: const SpatialSitePage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    // The reconstruction captions are always shown.
    expect(find.text('Synthesized seafloor'), findsOneWidget);
    expect(find.text('Estimated path (dead reckoning)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows a message when the path cannot be reconstructed', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          spatialReckonedPathProvider('d1').overrideWith((ref) async => null),
          spatialGeometryProvider('d1').overrideWith((ref) async => null),
        ],
        child: const SpatialSitePage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('Not enough data to reconstruct the dive path'),
      findsOneWidget,
    );
  });
}
