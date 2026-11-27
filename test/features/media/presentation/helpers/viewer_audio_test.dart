import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/helpers/viewer_audio.dart';

import '../widgets/video_controls_bar_test_harness.dart';

void main() {
  test('starts muted at full level', () {
    final audio = ViewerAudio();
    addTearDown(audio.dispose);
    expect(audio.muted, isTrue);
    expect(audio.level, 1.0);
    expect(audio.effectiveVolume, 0.0);
  });

  test('toggleMute unmutes to the level and notifies', () {
    final audio = ViewerAudio();
    addTearDown(audio.dispose);
    var notified = 0;
    audio.addListener(() => notified++);
    audio.toggleMute();
    expect(audio.muted, isFalse);
    expect(audio.effectiveVolume, 1.0);
    expect(notified, 1);
  });

  test('setLevel above 0 while muted unmutes', () {
    final audio = ViewerAudio();
    addTearDown(audio.dispose);
    audio.setLevel(0.4);
    expect(audio.muted, isFalse);
    expect(audio.effectiveVolume, 0.4);
  });

  test('setLevel 0 reads as muted', () {
    final audio = ViewerAudio()..toggleMute();
    addTearDown(audio.dispose);
    audio.setLevel(0);
    expect(audio.muted, isTrue);
    expect(audio.effectiveVolume, 0.0);
  });

  test('setLevel clamps to the 0 to 1 range', () {
    final audio = ViewerAudio();
    addTearDown(audio.dispose);
    audio.setLevel(1.7);
    expect(audio.level, 1.0);
    audio.setLevel(-0.2);
    expect(audio.level, 0.0);
  });

  test('unmute from level 0 restores the last level', () {
    final audio = ViewerAudio();
    addTearDown(audio.dispose);
    audio
      ..setLevel(0.6)
      ..setLevel(0)
      ..toggleMute();
    expect(audio.muted, isFalse);
    expect(audio.effectiveVolume, 0.6);

    final fresh = ViewerAudio();
    addTearDown(fresh.dispose);
    fresh
      ..setLevel(0)
      ..toggleMute();
    expect(fresh.effectiveVolume, 1.0);
  });

  test('muting keeps the level', () {
    final audio = ViewerAudio();
    addTearDown(audio.dispose);
    audio
      ..setLevel(0.3)
      ..toggleMute();
    expect(audio.muted, isTrue);
    expect(audio.level, 0.3);
    expect(audio.effectiveVolume, 0.0);
  });

  test('no change, no notification', () {
    final audio = ViewerAudio();
    addTearDown(audio.dispose);
    audio.setLevel(1.0);
    var notified = 0;
    audio.addListener(() => notified++);
    audio.setLevel(1.0);
    expect(notified, 0);
  });

  testWidgets('applyTo sets the player volume', (tester) async {
    useBarPlatform();
    final controller = (await tester.runAsync(readyController))!;
    final audio = ViewerAudio();
    addTearDown(audio.dispose);
    await tester.runAsync(() => controller.setVolume(1.0));
    await tester.runAsync(() => audio.applyTo(controller));
    expect(controller.value.volume, 0.0);
    audio.toggleMute();
    await tester.runAsync(() => audio.applyTo(controller));
    expect(controller.value.volume, 1.0);
    await tester.runAsync(controller.dispose);
  });
}
