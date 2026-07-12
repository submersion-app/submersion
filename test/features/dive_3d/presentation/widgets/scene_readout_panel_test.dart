import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/scene_readout_panel.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

Dive3dSceneData readoutSceneData() => const Dive3dSceneData(
  diveId: 'd1',
  times: [0, 100],
  depths: [0, 20],
  temperatures: [20, 10],
  ascentRates: [null, null],
  ppO2s: [null, null],
  cnss: [null, null],
  heartRates: [null, null],
  ceilings: [null, null],
  ttss: [null, null],
  tankPressures: {},
  gasSwitches: [],
  bookmarkEvents: [],
  photos: [],
  durationSeconds: 100,
  maxDepthMeters: 20,
);

void main() {
  testWidgets('shows interpolated depth at the scrub position', (tester) async {
    final overrides = await getBaseOverrides();
    final position = ValueNotifier<double>(0.5); // t=50 -> depth 10m
    addTearDown(position.dispose);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: SceneReadoutPanel(data: readoutSceneData(), position: position),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('10.0'), findsOneWidget);
    position.value = 1.0;
    await tester.pump();
    expect(find.textContaining('20.0'), findsOneWidget);
  });
}
