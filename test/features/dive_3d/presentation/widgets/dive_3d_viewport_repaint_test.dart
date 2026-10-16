import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'dive_3d_interactive_viewport_test.dart' show buildScene;

/// The render object that runs [Dive3dScenePainter.paint].
RenderCustomPaint _sceneRenderObject(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(Dive3dInteractiveViewport),
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is Dive3dScenePainter,
    ),
  );
  return tester.renderObject<RenderCustomPaint>(finder);
}

/// The picture layers recorded by the nearest repaint boundary at or above
/// [node]. A boundary that repaints records new ones; one that is only moved
/// keeps the same instances, so identity tells whether `paint` ran.
List<Layer> _picturesAbove(RenderObject node) {
  RenderObject? current = node;
  while (current != null && !current.isRepaintBoundary) {
    current = current.parent;
  }
  final pictures = <Layer>[];
  void collect(Layer? layer) {
    for (var child = layer; child != null; child = child.nextSibling) {
      if (child is PictureLayer) pictures.add(child);
      if (child is ContainerLayer) collect(child.firstChild);
    }
  }

  collect(current!.debugLayer!.firstChild);
  return pictures;
}

void main() {
  // Issue #3393: on Site Details the viewport sits in a SingleChildScrollView,
  // which repaints its whole subtree on every scroll frame. The scene painter
  // projects and depth-sorts every triangle on the CPU, so it must not be
  // re-run when only the page's scroll offset changes.
  group('inside a scrolling page', () {
    Future<ScrollController> pumpInScrollingPage(
      WidgetTester tester, {
      required Scene3d scene,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  SizedBox(
                    height: 400,
                    child: Dive3dInteractiveViewport(
                      scene: scene,
                      scrubPosition: ValueNotifier(0.0),
                      visibleOverlays: SceneOverlay.values.toSet(),
                    ),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return controller;
    }

    testWidgets('scrolling the page does not repaint the scene', (
      tester,
    ) async {
      final controller = await pumpInScrollingPage(tester, scene: buildScene());
      final scene = _sceneRenderObject(tester);
      final before = _picturesAbove(scene);
      expect(before, isNotEmpty);

      for (var i = 1; i <= 5; i++) {
        controller.jumpTo(i * 10.0);
        await tester.pump();
      }

      expect(controller.offset, 50);
      final after = _picturesAbove(scene);
      expect(after, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        expect(identical(after[i], before[i]), isTrue, reason: 'picture $i');
      }
    });
  });

  testWidgets('a scrub tick repaints the cursor, not the scene', (
    tester,
  ) async {
    final scrub = ValueNotifier(0.0);
    addTearDown(scrub.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Dive3dInteractiveViewport(
            scene: buildScene(),
            scrubPosition: scrub,
            visibleOverlays: SceneOverlay.values.toSet(),
          ),
        ),
      ),
    );
    await tester.pump();
    final scene = _sceneRenderObject(tester);
    final before = _picturesAbove(scene);

    for (var i = 1; i <= 5; i++) {
      scrub.value = i / 10;
      await tester.pump();
    }

    final after = _picturesAbove(scene);
    expect(after, hasLength(before.length));
    for (var i = 0; i < before.length; i++) {
      expect(identical(after[i], before[i]), isTrue, reason: 'picture $i');
    }
  });

  testWidgets('inline, a trackpad swipe that leaves the camera reports no '
      'zoom change', (tester) async {
    final settled = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Dive3dInteractiveViewport(
            scene: buildScene(),
            scrubPosition: ValueNotifier(0.0),
            visibleOverlays: SceneOverlay.values.toSet(),
            insideScrollingPage: true,
            onZoomSettled: settled.add,
          ),
        ),
      ),
    );
    await tester.pump();

    final pad = TestPointer(2, PointerDeviceKind.trackpad);
    final at = tester.getCenter(find.byType(Dive3dInteractiveViewport));
    await tester.sendEventToBinding(pad.panZoomStart(at));
    for (var i = 1; i <= 5; i++) {
      await tester.sendEventToBinding(
        pad.panZoomUpdate(at, pan: Offset(0, -12.0 * i)),
      );
    }
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pump(const Duration(milliseconds: 500));

    expect(settled, isEmpty);
  });

  group('Dive3dScenePainter.shouldRepaint', () {
    Dive3dScenePainter painter(Scene3d scene, Set<SceneOverlay> overlays) =>
        Dive3dScenePainter(
          scene: scene,
          yawDegrees: -32,
          pitchDegrees: 22,
          zoom: 1,
          visibleOverlays: overlays,
        );

    test('an equal overlay set built anew does not force a repaint', () {
      final scene = buildScene();
      final a = painter(scene, {SceneOverlay.markers, SceneOverlay.water});
      final b = painter(scene, {SceneOverlay.water, SceneOverlay.markers});

      expect(b.shouldRepaint(a), isFalse);
    });

    test('a changed overlay set repaints', () {
      final scene = buildScene();
      final a = painter(scene, {SceneOverlay.markers, SceneOverlay.water});
      final b = painter(scene, {SceneOverlay.markers});

      expect(b.shouldRepaint(a), isTrue);
    });
  });
}
