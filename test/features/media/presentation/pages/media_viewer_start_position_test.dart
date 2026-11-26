import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';
import 'video_viewer_test_harness.dart';

/// Records every seek, so a test can tell where the viewer started a clip.
class _SeekRecorder extends FakeVideoPlatform {
  final seeks = <Duration>[];

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      seeks.add(position);
}

/// A species crop from a video opens the clip at the animal's moment
/// (issue #5027).
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(tearDownTestDatabase);

  testWidgets('seeks the first video to the start position once', (
    tester,
  ) async {
    final player = _SeekRecorder();
    await pumpVideoViewer(
      tester,
      prefs,
      platform: player,
      initialVideoPosition: const Duration(milliseconds: 4200),
    );

    expect(player.seeks, [const Duration(milliseconds: 4200)]);
  });

  testWidgets('without a start position it does not seek', (tester) async {
    final player = _SeekRecorder();
    await pumpVideoViewer(tester, prefs, platform: player);

    expect(player.seeks, isEmpty);
  });
}
