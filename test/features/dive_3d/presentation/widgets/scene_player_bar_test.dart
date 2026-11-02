import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/presentation/scene_player.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/scene_player_bar.dart';

import '../../../../helpers/test_app.dart';

void main() {
  ScenePlayer buildPlayer(WidgetTester tester) {
    final position = ValueNotifier<double>(0);
    addTearDown(position.dispose);
    final player = ScenePlayer(
      vsync: tester,
      duration: const Duration(seconds: 10),
      position: position,
    );
    addTearDown(player.dispose);
    return player;
  }

  testWidgets('follows the player without rebuilding its parent', (
    tester,
  ) async {
    final player = buildPlayer(tester);
    var parentBuilds = 0;
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) {
            parentBuilds++;
            return ScenePlayerBar(player: player);
          },
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(parentBuilds, 1);
  });

  testWidgets('scrubbing stops playback', (tester) async {
    final player = buildPlayer(tester);
    await tester.pumpWidget(testApp(child: ScenePlayerBar(player: player)));

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(player.isPlaying, isTrue);

    await tester.drag(find.byType(Slider), const Offset(20, 0));
    await tester.pump();

    expect(player.isPlaying, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
