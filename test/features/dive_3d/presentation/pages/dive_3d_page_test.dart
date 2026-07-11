import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/application/tissue_providers.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_chain.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_replay_result.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_replay_service.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_readout_panel.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../widgets/scene_readout_panel_test.dart' show readoutSceneData;

TissueReplayResult tissueResult() {
  final times = [for (var m = 0; m <= 15; m++) (m * 60).toDouble()];
  final depths = [for (var m = 0; m <= 15; m++) 30.0];
  return const TissueReplayService().replay(
    TissueChainInput(
      dives: [TissueDiveInput(times: times, depths: depths, gasLegs: [])],
      surfaceIntervalSeconds: [],
      gfLow: 0.30,
      gfHigh: 0.70,
      environment: DiveEnvironment.standard,
    ),
  );
}

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
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          dive3dSceneDataProvider(
            'd1',
          ).overrideWith((ref) async => readoutSceneData()),
          tissueReplayProvider(
            'd1',
          ).overrideWith((ref) async => tissueResult()),
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
    // Tissue color-mode control is present.
    expect(find.text('% M-value'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
