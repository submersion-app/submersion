import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

DiveProfilePoint p(int t, double depth) =>
    DiveProfilePoint(timestamp: t, depth: depth);

Widget host(Widget overlay) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SizedBox.expand(child: Stack(children: [overlay])),
  ),
);

void main() {
  // Depths chosen so current depth differs from running max at the times the
  // tests sample (otherwise DEPTH and MAX cells render identical strings).
  final resolver = PerdixFaceResolver(
    profile: [p(0, 0.0), p(60, 10.0), p(120, 20.0), p(180, 15.0), p(240, 5.0)],
  );
  const settings = AppSettings();

  testWidgets('static photo mode renders the sample at baseElapsedSeconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 180,
          settings: settings,
        ),
      ),
    );
    expect(find.text('15.0m'), findsOneWidget); // depth at t=180
    expect(find.text('20.0m'), findsOneWidget); // running max
    expect(find.text('3:00'), findsOneWidget);
  });

  testWidgets('video mode advances with the playback listenable', (
    tester,
  ) async {
    final position = ValueNotifier<Duration>(Duration.zero);
    addTearDown(position.dispose);
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 180,
          settings: settings,
          playback: position,
          positionGetter: () => position.value,
        ),
      ),
    );
    expect(find.text('15.0m'), findsOneWidget); // t = 180
    position.value = const Duration(seconds: 60);
    await tester.pump();
    expect(find.text('5.0m'), findsOneWidget); // t = 240
    expect(find.text('15.0m'), findsNothing);
  });

  testWidgets('drag moves the card and reports final fraction', (tester) async {
    Offset? reported;
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 0,
          settings: settings,
          initialFraction: const Offset(0, 0),
          onDragEnd: (f) => reported = f,
        ),
      ),
    );
    final before = tester.getTopLeft(find.byType(PerdixFace));
    await tester.drag(find.byType(PerdixFace), const Offset(120, 80));
    await tester.pumpAndSettle();
    expect(reported, isNotNull);
    expect(reported!.dx, greaterThan(0));
    expect(reported!.dy, greaterThan(0));
    expect(reported!.dx, lessThanOrEqualTo(1.0));
    expect(reported!.dy, lessThanOrEqualTo(1.0));
    final after = tester.getTopLeft(find.byType(PerdixFace));
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
  });

  testWidgets('the whole panel is a grab target, not just its text', (
    tester,
  ) async {
    Offset? reported;
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 0,
          settings: settings,
          initialFraction: const Offset(0, 0),
          onDragEnd: (f) => reported = f,
        ),
      ),
    );
    final before = tester.getTopLeft(find.byType(PerdixFace));
    // The panel's own padding: inside the decorated background but outside
    // every Text. RenderDecoratedBox.hitTestSelf defers to the decoration's
    // shape, so the rounded rect absorbs this; a face rebuilt without a
    // decoration (or with a transparent one) would silently lose most of its
    // drag surface.
    final padding = tester.getRect(find.byType(PerdixFace)).topLeft;
    await tester.dragFrom(padding + const Offset(5, 5), const Offset(120, 80));
    await tester.pumpAndSettle();

    expect(reported, isNotNull);
    final after = tester.getTopLeft(find.byType(PerdixFace));
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
  });

  testWidgets('a tap on the face does not persist a position', (tester) async {
    var writes = 0;
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 0,
          settings: settings,
          onDragEnd: (_) => writes++,
        ),
      ),
    );
    // The recognizer claims the pointer on contact, so a tap still produces a
    // drag start/end pair; only real movement should reach settings.
    await tester.tap(find.byType(PerdixFace));
    await tester.pumpAndSettle();
    expect(writes, 0);

    await tester.drag(find.byType(PerdixFace), const Offset(-40, 40));
    await tester.pumpAndSettle();
    expect(writes, 1);
  });

  testWidgets('a drag that only pushes past an edge persists nothing', (
    tester,
  ) async {
    var writes = 0;
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 0,
          settings: settings,
          initialFraction: const Offset(1, 0),
          onDragEnd: (_) => writes++,
        ),
      ),
    );
    final before = tester.getRect(find.byType(PerdixFace));

    // Already pinned to the top-right, so up-and-right is clamped away
    // entirely: the gesture moves the pointer but not the face.
    await tester.drag(find.byType(PerdixFace), const Offset(200, -200));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(PerdixFace)), before);
    expect(writes, 0);
  });

  testWidgets('dragging up cannot push the face into the reserved band', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 0,
          settings: settings,
          topReserve: 64,
        ),
      ),
    );
    await tester.drag(find.byType(PerdixFace), const Offset(0, -4000));
    await tester.pumpAndSettle();

    // The face is clamped out of the band the page reserves for the top
    // toolbar, so it can never sit under the toolbar's IconButtons.
    expect(
      tester.getRect(find.byType(PerdixFace)).top,
      greaterThanOrEqualTo(64),
    );
  });

  testWidgets('the face carries a drag handle and a grab cursor', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 0,
          settings: settings,
        ),
      ),
    );
    expect(find.byKey(PerdixFace.dragHandleKey), findsOneWidget);

    final region = tester.widget<MouseRegion>(
      find
          .ancestor(
            of: find.byType(PerdixFace),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.grab);
  });

  testWidgets('video mode carries the drag handle too', (tester) async {
    final position = ValueNotifier<Duration>(Duration.zero);
    addTearDown(position.dispose);
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 180,
          settings: settings,
          playback: position,
          positionGetter: () => position.value,
        ),
      ),
    );
    // The face is equally draggable in video mode, and video is where this
    // overlay is mostly used, so the affordance has to survive the separate
    // AnimatedBuilder build path.
    expect(find.byKey(PerdixFace.dragHandleKey), findsOneWidget);

    position.value = const Duration(seconds: 60);
    await tester.pump();
    expect(find.byKey(PerdixFace.dragHandleKey), findsOneWidget);
  });

  testWidgets('topReserve keeps the default corner below the top chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 0,
          settings: settings,
          topReserve: 64,
        ),
      ),
    );
    final stackSize = tester.getSize(find.byType(Stack).first);
    final faceRect = tester.getRect(find.byType(PerdixFace));
    expect(faceRect.right, closeTo(stackSize.width - 12, 1.0));
    expect(faceRect.top, closeTo(12 + 64, 1.0));
  });

  testWidgets('non-finite initial fraction sanitizes to default corner', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DraggablePerdixOverlay(
          resolver: resolver,
          baseElapsedSeconds: 0,
          settings: settings,
          initialFraction: const Offset(double.nan, double.infinity),
        ),
      ),
    );
    // Default corner is top-right: the face's right edge sits near the
    // stack's right edge (inside the 12 px inset).
    final stackSize = tester.getSize(find.byType(Stack).first);
    final faceRect = tester.getRect(find.byType(PerdixFace));
    expect(faceRect.right, closeTo(stackSize.width - 12, 1.0));
    expect(faceRect.top, closeTo(12, 1.0));
  });
}
