import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/application/tissue_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_legend.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_readout_panel.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../widgets/scene_readout_panel_test.dart' show readoutSceneData;

List<DecoStatus> tissueStatuses() {
  final algo = BuhlmannAlgorithm();
  return algo.processProfile(
    depths: const [0, 20, 20, 20, 0],
    timestamps: const [0, 120, 600, 1200, 1400],
  );
}

List<ComparisonProfile> compareProfiles() => const [
  ComparisonProfile(
    id: 'a',
    label: 'Perdix',
    color: Color(0xFF00D4FF),
    times: [0, 60, 120],
    depths: [0, 30, 0],
    maxDepthMeters: 30,
  ),
  ComparisonProfile(
    id: 'b',
    label: 'Teric',
    color: Color(0xFFFF9500),
    times: [0, 60, 120],
    depths: [0, 31, 0],
    maxDepthMeters: 31,
  ),
];

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          dive3dSceneDataProvider(
            'd1',
          ).overrideWith((ref) async => readoutSceneData()),
        ],
        child: const Dive3dPage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows scene chrome once providers resolve', (tester) async {
    await pumpPage(tester);
    expect(find.byType(TimeScrubBar), findsOneWidget);
    // Metric chips render only for metrics present in the data: the
    // fixture has depth and temperature.
    expect(find.byType(ChoiceChip), findsNWidgets(2));
  });

  testWidgets('play toggles to pause and back', (tester) async {
    await pumpPage(tester);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('overlay menu toggles an overlay entry', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byIcon(Icons.layers));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CheckedPopupMenuItem<SceneOverlay>), findsNWidgets(4));
    await tester.tap(find.text('Temperature layers'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Re-open: the entry is now unchecked (state flipped without error).
    await tester.tap(find.byIcon(Icons.layers));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final item = tester.widget<CheckedPopupMenuItem<SceneOverlay>>(
      find.ancestor(
        of: find.text('Temperature layers'),
        matching: find.byType(CheckedPopupMenuItem<SceneOverlay>),
      ),
    );
    expect(item.checked, isFalse);
    await tester.tapAt(const Offset(5, 400)); // dismiss menu
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('switching the coloring metric selects the tapped chip', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byType(ChoiceChip).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .toList();
    expect(chips.last.selected, isTrue);
    expect(chips.first.selected, isFalse);

    // Let chip selection animations and any host-scheduled timers finish,
    // then unmount so nothing is pending at teardown.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('switching to the tissue scene shows the tissue readout', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final statuses = tissueStatuses();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          dive3dSceneDataProvider(
            'd1',
          ).overrideWith((ref) async => readoutSceneData()),
          tissueDecoStatusesProvider(
            'd1',
          ).overrideWith((ref) async => statuses),
          tissue3dSceneProvider('d1').overrideWith(
            (ref) async =>
                SubsurfaceTissueBuilder.build(statuses, colorFn: thermalColor),
          ),
        ],
        child: const Dive3dPage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Tap the "Tissues" segment of the scene switcher.
    await tester.tap(find.text('Tissues'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TissueReadoutPanel), findsOneWidget);
    // The legend that explains how to read the graph is shown.
    expect(find.byType(TissueLegend), findsOneWidget);
    expect(find.text('On-gassing'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Computers segment is hidden for a single-source dive', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          dive3dSceneDataProvider(
            'd1',
          ).overrideWith((ref) async => readoutSceneData()),
          isMultiDataSourceDiveProvider(
            'd1',
          ).overrideWith((ref) async => false),
        ],
        child: const Dive3dPage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Computers'), findsNothing);
  });

  testWidgets('Computers segment opens the compare view for multi-source', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          dive3dSceneDataProvider(
            'd1',
          ).overrideWith((ref) async => readoutSceneData()),
          isMultiDataSourceDiveProvider('d1').overrideWith((ref) async => true),
          computerComparisonProfilesProvider(
            'd1',
          ).overrideWith((ref) async => compareProfiles()),
        ],
        child: const Dive3dPage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Computers'), findsOneWidget);
    await tester.tap(find.text('Computers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CompareProfile3dView), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('initialMode computers starts on the compare view', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          isMultiDataSourceDiveProvider('d1').overrideWith((ref) async => true),
          computerComparisonProfilesProvider(
            'd1',
          ).overrideWith((ref) async => compareProfiles()),
        ],
        child: const Dive3dPage(diveId: 'd1', initialMode: SceneKind.computers),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CompareProfile3dView), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
