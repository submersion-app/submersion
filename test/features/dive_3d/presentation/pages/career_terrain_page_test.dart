import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/career_providers.dart';
import 'package:submersion/features/dive_3d/domain/career/career_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/career/career_scene_data.dart';
import 'package:submersion/features/dive_3d/presentation/pages/career_terrain_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

CareerSceneData twoDives() {
  CareerDiveInput d(int i) => CareerDiveInput(
    index: i,
    date: DateTime.utc(2026, 1, 1 + i),
    maxDepthMeters: 20,
    times: [for (var m = 0; m <= 20; m++) (m * 60).toDouble()],
    depths: [for (var m = 0; m <= 20; m++) 20.0],
  );
  return CareerSceneData(dives: [d(0), d(1)]);
}

void main() {
  final query = careerSiteQuery('s1');

  testWidgets('renders the terrain viewport for a built scene', (tester) async {
    final overrides = await getBaseOverrides();
    final scene = const CareerGeometryService().build(twoDives());
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          careerGeometryProvider((
            query: query,
            colorMode: CareerColorMode.recency,
          )).overrideWith((ref) async => scene),
        ],
        child: CareerTerrainPage(query: query),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    expect(find.text('Recency'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows an empty message when there is no scene', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          careerGeometryProvider((
            query: query,
            colorMode: CareerColorMode.recency,
          )).overrideWith((ref) async => null),
        ],
        child: CareerTerrainPage(query: query),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No dives with profiles to show'), findsOneWidget);
  });
}
