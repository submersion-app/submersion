import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/presentation/widgets/video_volume_control.dart';

import '../../../../helpers/test_database.dart';
import 'video_viewer_test_harness.dart';

/// A player that takes its opening volume, then refuses every later change
/// once [refuse] is set, as a platform call that fails would.
class _VolumeRefusingPlatform extends FakeVideoPlatform {
  bool refuse = false;

  @override
  Future<void> setVolume(int playerId, double volume) async {
    if (refuse) throw StateError('volume refused');
    return super.setVolume(playerId, volume);
  }
}

/// The viewer's sound (issue #4817): videos open muted, M toggles it, and an
/// unmute lasts until the viewer closes.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  Finder playPause() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Play or pause video',
  );

  Future<void> pressM(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
  }

  testWidgets('a video opens muted', (tester) async {
    final platform = await pumpVideoViewer(tester, prefs);
    expect(platform.volume, 0.0);
  });

  testWidgets('M toggles mute on the live player', (tester) async {
    final platform = await pumpVideoViewer(tester, prefs);
    await pressM(tester);
    expect(platform.volume, 1.0);
    await pressM(tester);
    expect(platform.volume, 0.0);
  });

  testWidgets('M with a modifier is left for other shortcuts', (tester) async {
    final platform = await pumpVideoViewer(tester, prefs);
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.altLeft,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      expect(platform.volume, 0.0, reason: '$modifier+M');
    }
  });

  testWidgets('a volume change the player refuses is logged, not thrown', (
    tester,
  ) async {
    final logged = <LogEntry>[];
    final subscription = LoggerService.logStream.listen(logged.add);
    addTearDown(subscription.cancel);
    final platform = _VolumeRefusingPlatform();
    await pumpVideoViewer(tester, prefs, platform: platform);
    expect(platform.volume, 0.0);

    platform.refuse = true;
    await pressM(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      logged.map((e) => e.message),
      contains(startsWith('Video v1 volume change failed')),
    );
  });

  testWidgets('toggling mute reaches a playing video without a replay', (
    tester,
  ) async {
    final platform = await pumpVideoViewer(tester, prefs);
    // Held for the photo pager's double-tap window before it lands.
    await tester.tap(playPause());
    await tester.pump(const Duration(milliseconds: 500));
    expect(platform.playing, isTrue);
    await pressM(tester);
    expect(platform.volume, 1.0);
    expect(platform.playing, isTrue);
    // Pause before the test ends: a playing controller polls on a timer.
    await tester.tap(playPause());
    await tester.pump(const Duration(milliseconds: 500));
    expect(platform.playing, isFalse);
  });

  testWidgets('an unmute carries to the next video', (tester) async {
    final platform = await pumpVideoViewer(
      tester,
      prefs,
      mediaList: [video('v1'), video('v2')],
    );
    // A level of its own, not the players' default 1.0: only a carried
    // sound gives the next player this.
    tester
        .widget<VideoVolumeControl>(find.byType(VideoVolumeControl))
        .audio
        .setLevel(0.4);
    await tester.pump();
    expect(platform.volume, 0.4);
    final createdBefore = platform.created;

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Next media'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      platform.completeInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
    });
    expect(platform.created, createdBefore + 1);
    // Reset to muted, the second player would open at 0; left to its own
    // default, at 1.0.
    expect(platform.volume, 0.4);
  });

  testWidgets('a new viewer opens muted again', (tester) async {
    final first = await pumpVideoViewer(tester, prefs);
    await pressM(tester);
    expect(first.volume, 1.0);

    // Close the viewer, then open another.
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    final second = await pumpVideoViewer(tester, prefs);
    expect(second.volume, 0.0);
  });
}
