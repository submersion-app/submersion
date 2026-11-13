import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_tooltip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// 0 to 1500 s in 10 s steps: index i is at i * 10 seconds.
final _profile = [
  for (var t = 0; t <= 1500; t += 10)
    DiveProfilePoint(timestamp: t, depth: t < 750 ? t / 25 : (1500 - t) / 25),
];

DecoStatus _ndl(int seconds) => DecoStatus(
  compartments: const [],
  ndlSeconds: seconds,
  ceilingMeters: 0,
  ttsSeconds: 0,
  gfLow: 0.3,
  gfHigh: 0.7,
  decoStops: const [],
  currentDepthMeters: 10,
  ambientPressureBar: 2,
);

void main() {
  final dive = createTestDiveWithBottomTime().copyWith(profile: _profile);
  final analysis = ProfileAnalysis.empty().copyWith(
    ppO2Curve: [for (final _ in _profile) 1.12],
    decoStatuses: [for (final _ in _profile) _ndl(840)],
  );
  const stripWidth = 400.0;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool insideScrollView = false,
  }) async {
    final base = await getBaseOverrides();
    const strip = SizedBox(width: stripWidth);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          activeSourceProfileProvider(dive.id).overrideWith((ref) => null),
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => analysis),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: insideScrollView
                  ? SizedBox(
                      width: stripWidth,
                      height: 600,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            PinnedProfileStrip(dive: dive),
                            const SizedBox(height: 2000, child: strip),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      width: stripWidth,
                      child: PinnedProfileStrip(dive: dive),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return ProviderScope.containerOf(
      tester.element(find.byType(PinnedProfileStrip)),
    );
  }

  int? cursor(ProviderContainer c) =>
      c.read(profileTrackingIndexProvider(dive.id));

  Offset at(WidgetTester tester, double fraction) {
    final box = tester.getRect(find.byType(PinnedProfileStrip));
    return Offset(box.left + box.width * fraction, box.top + 20);
  }

  Finder tooltip() => find.byType(PinnedStripTooltip);

  Future<void> setCursor(
    ProviderContainer c,
    WidgetTester tester,
    int? i,
  ) async {
    c.read(profileTrackingIndexProvider(dive.id).notifier).state = i;
    await tester.pump();
    await tester.pump();
  }

  testWidgets('no tooltip and no hint with no cursor', (tester) async {
    await pump(tester);
    expect(tooltip(), findsNothing);
    expect(find.text('Drag to scrub'), findsNothing);
    expect(find.text('Hover to scrub'), findsNothing);
  });

  testWidgets('shows the tooltip below the strip when the cursor is set', (
    tester,
  ) async {
    final c = await pump(tester);
    await setCursor(c, tester, 75);
    expect(tooltip(), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.text('30.0m'), findsOneWidget);
    expect(find.text('1.12 bar'), findsOneWidget);
    expect(find.text('14 min'), findsOneWidget);
    final strip = tester.getRect(find.byType(PinnedProfileStrip));
    expect(tester.getRect(tooltip()).top, strip.bottom + 4);
  });

  testWidgets('the tooltip is not clipped by the strip', (tester) async {
    final c = await pump(tester);
    await setCursor(c, tester, 75);
    final strip = tester.getRect(find.byType(PinnedProfileStrip));
    final box = tester.getRect(tooltip());
    expect(box.top, greaterThan(strip.bottom));
    // Laid out in the app's overlay, so no render object of the strip (its
    // clipped surface above all) is an ancestor of the tooltip's.
    final stripRender = tester.renderObject(find.byType(PinnedProfileStrip));
    RenderObject? node = tester.renderObject(tooltip());
    var underStrip = false;
    while (node != null) {
      if (identical(node, stripRender)) underStrip = true;
      node = node.parent;
    }
    expect(underStrip, isFalse);
    // Left of the box is 10 px right of the cursor at 12:30 of 25:00.
    expect(box.left, closeTo(stripWidth * 0.5 + 10, 1));
  });

  testWidgets('the tooltip goes when the cursor clears', (tester) async {
    final c = await pump(tester);
    await setCursor(c, tester, 75);
    expect(tooltip(), findsOneWidget);
    await setCursor(c, tester, null);
    expect(tooltip(), findsNothing);
  });

  testWidgets('semantics value reads the tooltip rows while scrubbing', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final c = await pump(tester);
    await setCursor(c, tester, 75);
    final node = tester.getSemantics(
      find
          .descendant(
            of: find.byType(PinnedProfileStrip),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(node.value, contains('Time 12:30'));
    expect(node.value, contains('NDL 14 min'));
    handle.dispose();
  });

  // The strip's semantics value already reads the rows; the tooltip's own
  // text must not be announced a second time (review round 2).
  testWidgets('the tooltip text is not in the semantics tree', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await pump(tester);
    await setCursor(c, tester, 75);
    expect(tooltip(), findsOneWidget);
    expect(find.bySemanticsLabel('12:30'), findsNothing);
    expect(find.bySemanticsLabel('Depth'), findsNothing);
    handle.dispose();
  });

  testWidgets('passes the analysis curves to the painter', (tester) async {
    await pump(tester);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is PinnedStripPainter,
                  ),
                )
                .painter!
            as PinnedStripPainter;
    expect(identical(painter.ndlCurve, analysis.ndlCurve), isTrue);
    expect(identical(painter.ceilingCurve, analysis.ceilingCurve), isTrue);
    expect(identical(painter.decoStopCurve, analysis.decoStopCurve), isTrue);
    expect(painter.maxDepthLabel, '30.0m');
  });

  // A raw TextPainter has no theme: without the app's label style the
  // max-depth label fell back to the engine's default font.
  testWidgets('labels the max depth in the theme\'s label style', (
    tester,
  ) async {
    await pump(tester);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is PinnedStripPainter,
                  ),
                )
                .painter!
            as PinnedStripPainter;
    final labelSmall = Theme.of(
      tester.element(find.byType(PinnedProfileStrip)),
    ).textTheme.labelSmall;
    expect(painter.maxDepthLabelStyle, isNotNull);
    expect(painter.maxDepthLabelStyle!.fontFamily, labelSmall!.fontFamily);
  });

  testWidgets('a horizontal drag writes the cursor index', (tester) async {
    final c = await pump(tester);
    final gesture = await tester.startGesture(at(tester, 0.1));
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(at(tester, 0.1 + 0.05 * i));
      await tester.pump();
    }
    expect(cursor(c), closeTo(75, 1));
    await gesture.up();
  });

  testWidgets('lifting the finger clears the cursor', (tester) async {
    final c = await pump(tester);
    final gesture = await tester.startGesture(at(tester, 0.2));
    await gesture.moveTo(at(tester, 0.6));
    await tester.pump();
    expect(cursor(c), isNotNull);
    await gesture.up();
    await tester.pump();
    expect(cursor(c), isNull);
  });

  testWidgets('hover writes the cursor and mouse exit clears it', (
    tester,
  ) async {
    final c = await pump(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero + const Offset(1, 500));
    await mouse.moveTo(at(tester, 0.5));
    await tester.pump();
    expect(cursor(c), closeTo(75, 1));
    await mouse.moveTo(const Offset(1, 500));
    await tester.pump();
    expect(cursor(c), isNull);
  });

  // The mouse is still over the strip after a click, so clearing the cursor
  // on the release left the strip blank under it until it moved (review).
  testWidgets('a mouse click leaves the cursor where it clicked', (
    tester,
  ) async {
    final c = await pump(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(1, 500));
    await mouse.moveTo(at(tester, 0.5));
    await tester.pump();
    await mouse.down(at(tester, 0.5));
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.up();
    await tester.pump();
    expect(cursor(c), closeTo(75, 1));
  });

  testWidgets('a vertical drag scrolls the page and leaves the cursor', (
    tester,
  ) async {
    final c = await pump(tester, insideScrollView: true);
    await tester.dragFrom(at(tester, 0.5), const Offset(0, -300));
    await tester.pump();
    expect(cursor(c), isNull);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('mid-condense the curve fills the height and shows no tooltip', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          activeSourceProfileProvider(dive.id).overrideWith((ref) => null),
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => analysis),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: stripWidth,
                height: 200,
                child: PinnedProfileStrip(dive: dive, condense: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(PinnedProfileStrip)).height, 200);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(PinnedProfileStrip)),
    );
    await setCursor(c, tester, 75);
    expect(tooltip(), findsNothing);
  });

  // A shadow under a see-through surface greyed the whole card; the strip
  // takes the card's own colour and casts no shadow until it is opaque.
  testWidgets('a see-through strip casts no shadow and is card-coloured', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          activeSourceProfileProvider(dive.id).overrideWith((ref) => null),
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => analysis),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: stripWidth,
                height: 200,
                child: PinnedProfileStrip(
                  dive: dive,
                  condense: 0,
                  backgroundOpacity: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PinnedProfileStrip),
            matching: find.byType(Material),
          )
          .first,
    );
    final card = Theme.of(
      tester.element(find.byType(PinnedProfileStrip)),
    ).colorScheme.surfaceContainerLow;
    expect(material.elevation, 0);
    expect(material.color!.r, closeTo(card.r, 1e-6));
    expect(material.color!.g, closeTo(card.g, 1e-6));
    expect(material.color!.b, closeTo(card.b, 1e-6));
    expect(material.color!.a, closeTo(card.a * 0.5, 1e-6));
  });

  Future<void> pumpMorphing(
    WidgetTester tester, {
    required double condense,
    required double background,
    ThemeData? theme,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          activeSourceProfileProvider(dive.id).overrideWith((ref) => null),
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => analysis),
        ],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: stripWidth,
                height: 200,
                child: PinnedProfileStrip(
                  dive: dive,
                  condense: condense,
                  backgroundOpacity: background,
                  morphFrom: const PlotMapping(
                    rect: Rect.fromLTWH(30, 40, 340, 120),
                    minSeconds: 0,
                    maxSeconds: 1500,
                    minDepthMeters: 0,
                    maxDepthMeters: 33,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The strip's shading is drawn over the chart's own while it fades in; at
  // full strength the two stacked into a darker blue. It cross-fades instead.
  testWidgets('its curve fades in with its surface, even on the chart line', (
    tester,
  ) async {
    await pumpMorphing(tester, condense: 0, background: 0.4);
    final curveLayer = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is PinnedStripPainter,
            ),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(curveLayer.opacity, closeTo(0.4, 1e-6));
  });

  // Its colour and shadow already follow the scroll frame by frame; the
  // surface's own 200 ms ease would lag a fast scroll and flash.
  testWidgets('its surface does not animate on its own', (tester) async {
    await pumpMorphing(tester, condense: 0.5, background: 1);
    final surface = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PinnedProfileStrip),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(surface.animationDuration, Duration.zero);
  });

  // A shadow switching on the moment the surface turned opaque flashed grey
  // in both directions; it grows with the condense instead.
  testWidgets('its shadow grows with the condense', (tester) async {
    Material surface() => tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PinnedProfileStrip),
            matching: find.byType(Material),
          )
          .first,
    );
    await pumpMorphing(tester, condense: 0, background: 1);
    expect(surface().elevation, 0);
    await pumpMorphing(tester, condense: 0.5, background: 1);
    expect(surface().elevation, closeTo(1.5, 1e-6));
    // Settled, it lifts off the page like an app bar with content scrolled
    // under it (Material 3's level 2, elevation 3).
    await pumpMorphing(tester, condense: 1, background: 1);
    expect(surface().elevation, 3);
  });

  RoundedRectangleBorder surfaceShape(WidgetTester tester) =>
      tester
              .widget<Material>(
                find
                    .descendant(
                      of: find.byType(PinnedProfileStrip),
                      matching: find.byType(Material),
                    )
                    .first,
              )
              .shape!
          as RoundedRectangleBorder;

  PinnedStripOutlinePainter outline(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byWidgetPredicate(
                  (w) =>
                      w is CustomPaint &&
                      w.foregroundPainter is PinnedStripOutlinePainter,
                ),
              )
              .foregroundPainter!
          as PinnedStripOutlinePainter;

  // The outline is open at the top: a stroke down both sides, round the
  // bottom corners and along the bottom.
  test('the outline is drawn on the sides and bottom only', () async {
    const side = BorderSide(color: Color(0xFF000000), width: 2);
    const corners = BorderRadius.only(
      bottomLeft: Radius.circular(12),
      bottomRight: Radius.circular(12),
    );
    final recorder = ui.PictureRecorder();
    const PinnedStripOutlinePainter(
      side: side,
      corners: corners,
    ).paint(Canvas(recorder), const Size(200, 56));
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 56);
    final bytes = (await image.toByteData())!;
    int alphaAt(int x, int y) => bytes.getUint8((y * 200 + x) * 4 + 3);
    expect(alphaAt(1, 28), greaterThan(0), reason: 'left side');
    expect(alphaAt(198, 28), greaterThan(0), reason: 'right side');
    expect(alphaAt(100, 55), greaterThan(0), reason: 'bottom');
    expect(alphaAt(100, 1), 0, reason: 'no top edge');
    // The bottom corners round: the very corner pixel is left clear.
    expect(alphaAt(0, 55), 0, reason: 'rounded corner');
    image.dispose();
    picture.dispose();
    expect(
      const PinnedStripOutlinePainter(
        side: side,
        corners: corners,
      ).shouldRepaint(
        const PinnedStripOutlinePainter(side: side, corners: BorderRadius.zero),
      ),
      isTrue,
    );
  });

  // Card-width under the header, it reads as the card tucked up there: its
  // bottom corners keep the card's rounding all the way to pinned (#4488).
  testWidgets('its bottom corners stay round as it condenses', (tester) async {
    for (final condense in [0.0, 0.5, 1.0]) {
      await pumpMorphing(tester, condense: condense, background: 1);
      expect(
        surfaceShape(tester).borderRadius,
        const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        reason: 'condense=$condense',
      );
    }
  });

  // Pinned among the other cards, it matches them in every theme preset:
  // their corners, outline and fill, a translucent fill made opaque over
  // the page as the cards are, so content scrolling beneath never shows.
  testWidgets('it takes its corners, outline and fill from the card theme', (
    tester,
  ) async {
    const side = BorderSide(color: Color(0xFF336699), width: 1.5);
    final base = ThemeData(useMaterial3: true);
    final theme = base.copyWith(
      cardTheme: CardThemeData(
        color: const Color(0x80FF0000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: side,
        ),
      ),
    );
    await pumpMorphing(tester, condense: 1, background: 1, theme: theme);
    final shape = surfaceShape(tester);
    expect(
      shape.borderRadius,
      const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
    );
    // The outline runs down its sides and along its bottom, never across
    // its top, where it meets the card's header or the page's.
    expect(shape.side, BorderSide.none);
    expect(outline(tester).side, side);
    expect(outline(tester).corners, shape.borderRadius);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PinnedProfileStrip),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      material.color,
      Color.alphaBlend(const Color(0x80FF0000), base.colorScheme.surface),
    );
    expect(material.color!.a, 1);

    // While the surface fades in, so does the outline.
    await pumpMorphing(tester, condense: 0, background: 0.5, theme: theme);
    expect(outline(tester).side.color.a, closeTo(0.5, 1e-6));
  });

  testWidgets('the strip has a semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(
      find.bySemanticsLabel(RegExp('Dive profile, scrub to move the cursor')),
      findsOneWidget,
    );
    handle.dispose();
  });

  // A held touch sets the cursor; once the finger moves off into a scroll,
  // the tap is cancelled and the cursor goes with it.
  testWidgets('a held touch that turns into a scroll clears the cursor', (
    tester,
  ) async {
    final c = await pump(tester, insideScrollView: true);
    final gesture = await tester.startGesture(at(tester, 0.5));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cursor(c), isNotNull);
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(cursor(c), isNull);
    await gesture.up();
  });
}
