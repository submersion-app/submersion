import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_hover_tooltip.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_readout_rows.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import 'scene_readout_panel_test.dart' show readoutSceneData;

void main() {
  testWidgets('tooltip shows the readout rows at the timestamp', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: DiveHoverTooltip(
          lookups: DiveReadoutLookups(readoutSceneData()),
          timestampSeconds: 50,
          emphasize: SceneMetric.temperature,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0:50'), findsOneWidget);
    expect(find.textContaining('10.0'), findsOneWidget);
    expect(find.textContaining('15'), findsOneWidget);
  });
}
