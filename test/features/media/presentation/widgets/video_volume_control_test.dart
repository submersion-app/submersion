import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/helpers/viewer_audio.dart';
import 'package:submersion/features/media/presentation/widgets/video_volume_control.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The mute button and hover volume slider on the video controls (issue
/// #4817).
void main() {
  late ViewerAudio audio;

  setUp(() {
    audio = ViewerAudio();
    addTearDown(audio.dispose);
  });

  Future<void> pumpControl(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: VideoVolumeControl(audio: audio)),
      ),
    ),
  );

  final slider = find.byKey(VideoVolumeControl.sliderKey);
  final button = find.byKey(VideoVolumeControl.buttonKey);

  /// A mouse resting on [target], removed when the test ends.
  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pumpAndSettle();
    return mouse;
  }

  testWidgets('shows the muted icon and unmutes on tap', (tester) async {
    await pumpControl(tester);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(audio.muted, isFalse);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('icon follows the level', (tester) async {
    await pumpControl(tester);
    audio.setLevel(0.3);
    await tester.pump();
    expect(find.byIcon(Icons.volume_down), findsOneWidget);
    audio.setLevel(0.8);
    await tester.pump();
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    audio.setLevel(0);
    await tester.pump();
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('no slider without hover or focus', (tester) async {
    await pumpControl(tester);
    expect(slider, findsNothing);
  });

  testWidgets('hover shows the slider and dragging sets the level', (
    tester,
  ) async {
    await pumpControl(tester);
    await hover(tester, button);
    expect(slider, findsOneWidget);

    // Muted, the thumb sits at the track's left end, just inside the
    // slider's 8 px padding; drag it part way right.
    final rect = tester.getRect(slider);
    await tester.dragFrom(
      Offset(rect.left + 10, rect.center.dy),
      Offset(rect.width / 2, 0),
    );
    await tester.pumpAndSettle();
    expect(audio.muted, isFalse);
    expect(audio.level, inExclusiveRange(0.0, 1.0));
    // Still under the mouse after the drag.
    expect(slider, findsOneWidget);
  });

  testWidgets('a drag that leaves the control keeps the slider until '
      'release', (tester) async {
    await pumpControl(tester);
    final mouse = await hover(tester, button);
    final rect = tester.getRect(slider);
    // Press on the thumb (at the left end: muted) and drag right, past the
    // slider's end and off the control, as a drag to full volume does.
    await mouse.down(Offset(rect.left + 10, rect.center.dy));
    await tester.pump();
    await mouse.moveTo(Offset(rect.right + 120, rect.center.dy + 60));
    await tester.pumpAndSettle();
    expect(slider, findsOneWidget);
    expect(audio.level, 1.0);
    expect(audio.muted, isFalse);
    await mouse.up();
    await tester.pumpAndSettle();
    // Released off the control: now it goes.
    expect(slider, findsNothing);
  });

  testWidgets('the slider goes once the mouse leaves', (tester) async {
    await pumpControl(tester);
    final mouse = await hover(tester, button);
    expect(slider, findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(slider, findsNothing);
  });

  testWidgets('focus inside the control keeps the slider', (tester) async {
    await pumpControl(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(slider, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(slider, findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(of: slider, matching: find.byWidget(focused.widget)),
      findsOneWidget,
    );
  });

  testWidgets('semantics name the button and the slider each', (tester) async {
    // Disposed in the body: the handle check runs before tear-downs.
    final handle = tester.ensureSemantics();
    await pumpControl(tester);
    expect(find.bySemanticsLabel('Unmute video'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Mute video'), findsOneWidget);
    await hover(tester, button);
    // The node a screen reader adjusts is the one named, not a group
    // around the button and slider together.
    final sliderNodes = find.semantics
        .byAction(SemanticsAction.increase)
        .evaluate();
    expect(sliderNodes.single.label, 'Video volume');
    expect(
      find.semantics.byLabel('Video volume').evaluate().single,
      sliderNodes.single,
    );
    handle.dispose();
  });
}
