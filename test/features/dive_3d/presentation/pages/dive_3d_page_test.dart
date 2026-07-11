import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../widgets/scene_readout_panel_test.dart' show readoutSceneData;

void main() {
  testWidgets('shows scene chrome once providers resolve', (tester) async {
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
    // The three_js host schedules frames continuously, so pumpAndSettle
    // would never settle; bounded pumps let the providers resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TimeScrubBar), findsOneWidget);
  });
}
