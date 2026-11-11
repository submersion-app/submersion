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

  testWidgets('shows the hover hint with no cursor on a pointer platform', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Hover to scrub'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('shows the drag hint on a touch platform', (tester) async {
    await pump(tester);
    expect(find.text('Drag to scrub'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('switches to the drag hint after a touch on a pointer platform', (
    tester,
  ) async {
    await pump(tester);
    await tester.tapAt(at(tester, 0.5));
    await tester.pump();
    expect(find.text('Drag to scrub'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('shows four values when the cursor is set', (tester) async {
    final c = await pump(tester);
    c.read(profileTrackingIndexProvider(dive.id).notifier).state = 75;
    await tester.pump();
    expect(find.text('12:30'), findsOneWidget);
    expect(find.text('30.0m'), findsOneWidget);
    expect(find.text('ppO2 1.12'), findsOneWidget);
    expect(find.text('NDL 14 min'), findsOneWidget);
    expect(find.text('Drag to scrub'), findsNothing);
    expect(find.text('Hover to scrub'), findsNothing);
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

  testWidgets('mid-condense the curve fills the height and the row fades in', (
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
    final row = tester.widget<Opacity>(
      find.ancestor(
        of: find.textContaining('to scrub'),
        matching: find.byType(Opacity),
      ),
    );
    expect(row.opacity, closeTo(0.5, 1e-6));
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
    expect(surface().elevation, closeTo(1, 1e-6));
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
}
