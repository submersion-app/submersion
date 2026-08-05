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
