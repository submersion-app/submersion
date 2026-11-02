import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/presentation/scene_player.dart';

void main() {
  late ValueNotifier<double> position;

  setUp(() => position = ValueNotifier(0));
  tearDown(() => position.dispose());

  ScenePlayer build(WidgetTester tester) {
    final player = ScenePlayer(
      vsync: tester,
      duration: const Duration(seconds: 10),
      position: position,
    );
    addTearDown(player.dispose);
    return player;
  }

  testWidgets('plays on from a scrubbed position', (tester) async {
    final player = build(tester);
    position.value = 0.5;

    player.togglePlay();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(player.isPlaying, isTrue);
    expect(position.value, closeTo(0.6, 0.001));
    player.stop();
  });

  testWidgets('rewinds to the start when played from the end', (tester) async {
    final player = build(tester);
    position.value = 1.0;

    player.togglePlay();

    expect(position.value, 0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(position.value, closeTo(0.1, 0.001));
    player.stop();
  });

  testWidgets('toggling while playing pauses in place', (tester) async {
    final player = build(tester);

    player.togglePlay();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    player.togglePlay();
    await tester.pump(const Duration(seconds: 2));

    expect(player.isPlaying, isFalse);
    expect(position.value, closeTo(0.2, 0.001));
  });

  testWidgets('notifies when toggled and when stopped', (tester) async {
    final player = build(tester);
    final notified = <bool>[];
    player.addListener(() => notified.add(player.isPlaying));

    player.togglePlay();
    player.stop();

    expect(notified, [true, false]);
  });

  testWidgets('stop does not notify when already stopped', (tester) async {
    final player = build(tester);
    var notifications = 0;
    player.addListener(() => notifications++);

    player.stop();

    expect(notifications, 0);
  });

  testWidgets('notifies when the timeline reaches the end on its own', (
    tester,
  ) async {
    final player = build(tester);
    player.togglePlay();
    await tester.pump();
    final notified = <bool>[];
    player.addListener(() => notified.add(player.isPlaying));

    await tester.pump(const Duration(seconds: 11));

    expect(notified, [false]);
    expect(position.value, 1.0);
  });

  testWidgets('keeps real time when the platform disables animations', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final player = build(tester);

    player.togglePlay();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(position.value, closeTo(0.1, 0.001));
    player.stop();
  });
}
