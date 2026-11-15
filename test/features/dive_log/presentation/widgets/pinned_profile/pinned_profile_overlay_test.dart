import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_host.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_card_marker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Stands in for the profile card's chart: fills its box, shows a 600 s,
/// 18 m dive through the window it is given and, like the real chart,
/// reports where its plot is after each layout.
class _FakeChart extends StatefulWidget {
  const _FakeChart({required this.onPlotFrame, required this.viewport});

  final ValueChanged<ProfilePlotFrame>? onPlotFrame;
  final ChartViewport viewport;

  @override
  State<_FakeChart> createState() => _FakeChartState();
}

class _FakeChartState extends State<_FakeChart> {
  static final plotKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = _fakeFrame(
          plotKey,
          Offset.zero & constraints.biggest,
          widget.viewport,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPlotFrame?.call(frame);
        });
        return SizedBox.expand(key: plotKey);
      },
    );
  }
}

/// What the fake chart shows of its 600 s, 18 m dive through [viewport].
ProfilePlotFrame _fakeFrame(
  GlobalKey plotKey,
  Rect plotRect,
  ChartViewport viewport,
) {
  final minSeconds = 600 * viewport.offsetX;
  final minDepth = 18 * viewport.offsetY;
  return ProfilePlotFrame(
    plotKey: plotKey,
    plotRect: plotRect,
    minSeconds: minSeconds,
    maxSeconds: minSeconds + 600 / viewport.zoom,
    minDepthMeters: minDepth,
    maxDepthMeters: minDepth + 18 / viewport.zoom,
    viewport: viewport,
  );
}

/// A synthetic page: a 100 px header, a 300 px "profile card", then a long
/// body with a target box 1500 px down. The card copy the overlay pins is a
/// 40 px header, a chart that takes the rest, and a 20 px footer.
void main() {
  final dive = createTestDiveWithBottomTime().copyWith(
    profile: [
      for (var t = 0; t <= 600; t += 10)
        DiveProfilePoint(
          timestamp: t,
          depth: t < 300 ? t / 20 : (600 - t) / 20,
          // A temperature, so the environment card has a line to add.
          temperature: 24 - t / 100,
        ),
    ],
  );
  const profileTop = 100.0;
  const profileHeight = 300.0;

  /// The copy's footer: the real card has its time axis and point count
  /// under the plot, so the hand-over has some height to cover.
  const footer = 100.0;

  /// The copy's chart rests at 300 - 40 - 100 = 160 px; the squash takes it
  /// down to kMinPlotHeight.
  const range = profileHeight - 40 - footer - kMinPlotHeight;
  final copyKey = find.byKey(const ValueKey('pinnedSquashedCard'));

  /// Taps on the copy header's button.
  final headerTaps = ValueNotifier(0);
  setUp(() => headerTaps.value = 0);

  /// The window the copy's chart was last handed.
  ChartViewport? copyViewport;
  setUp(() => copyViewport = null);

  Future<void> pump(
    WidgetTester tester, {
    required GlobalKey profileKey,
    GlobalKey? targetKey,
    bool showProfile = true,
    bool reportsPlot = true,
    ValueNotifier<double>? width,
    ValueNotifier<ChartViewport>? chartViewport,
    double footerHeight = footer,
    double pagePadding = 0,
    bool markTarget = false,
    bool enabled = true,
    double targetGap = 1100,
    Dive? shownDive,
    double plotInset = 0,
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
          )).overrideWith((ref) async => ProfileAnalysis.empty()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ValueListenableBuilder<double>(
                valueListenable: width ?? ValueNotifier(400),
                builder: (context, w, child) =>
                    SizedBox(width: w, height: 600, child: child),
                child: PinnedProfileOverlay(
                  dive: shownDive ?? dive,
                  enabled: enabled,
                  profileKey: profileKey,
                  chartViewport: chartViewport,
                  squashedCard: (context, onPlotFrame, viewport) => Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: Center(
                          child: TextButton(
                            onPressed: () => headerTaps.value++,
                            child: const Text('Header action'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            copyViewport = viewport;
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: plotInset,
                              ),
                              child: _FakeChart(
                                onPlotFrame: reportsPlot ? onPlotFrame : null,
                                viewport: viewport,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: footerHeight),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: pagePadding),
                    child: Column(
                      children: [
                        const SizedBox(height: profileTop),
                        if (showProfile)
                          SizedBox(
                            key: profileKey,
                            width: double.infinity,
                            height: profileHeight,
                          )
                        else
                          const SizedBox(height: profileHeight),
                        SizedBox(height: targetGap),
                        if (markTarget)
                          PinnedStripCardMarker(
                            id: DiveDetailSectionId.environment,
                            child: SizedBox(key: targetKey, height: 100),
                          )
                        else
                          SizedBox(key: targetKey, height: 100),
                        const SizedBox(height: 2000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  Future<void> jump(WidgetTester tester, double pixels) async {
    position(tester).jumpTo(pixels);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  final strip = find.byType(PinnedProfileStrip);
  double overlayTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(PinnedProfileOverlay)).dy;

  /// The copy's plot sits under its 40 px header. Squash and slide share the
  /// scroll, finishing together 112 + 40 = 152 px in, as the plot reaches the
  /// top; the strip starts to fade in kHandOverOverlap of the way through and
  /// has settled by then (issue #4579).
  const together = range + 40;
  const start = together * kHandOverOverlap;
  const handOver = together - start;

  /// The share of the hand-over the fade takes; the morph takes the rest.
  const fadeEnd = kCondenseFadeEnd;

  /// The squash and slide [scrolled] px past the card's top.
  double squashAt(double scrolled) =>
      range * (scrolled / together).clamp(0.0, 1.0);

  /// Scrolls so the hand-over to the strip is at progress [t].
  Future<void> condenseTo(WidgetTester tester, double t) =>
      jump(tester, profileTop + start + t * handOver);

  testWidgets(
    'the card squashes and slides up in one motion, with no strip at first',
    (tester) async {
      await pump(tester, profileKey: GlobalKey());
      const scrolled = 25.0;
      await jump(tester, profileTop + scrolled);
      final squash = squashAt(scrolled);
      // Both are under way at once: the chart is shorter and the card has
      // moved up by the rest of the scroll.
      expect(
        tester.getSize(find.byType(_FakeChart)).height,
        closeTo(160 - squash, 0.01),
      );
      expect(
        tester.getTopLeft(copyKey).dy,
        closeTo(overlayTop(tester) - (scrolled - squash), 0.01),
      );
      expect(squash, inExclusiveRange(0, scrolled));
      expect(strip, findsNothing);
    },
  );

  PinnedProfileStrip stripWidget(WidgetTester tester) =>
      tester.widget<PinnedProfileStrip>(strip);

  bool stripIgnoresPointer(WidgetTester tester) => tester
      .widget<IgnorePointer>(
        find.ancestor(of: strip, matching: find.byType(IgnorePointer)).first,
      )
      .ignoring;

  testWidgets('nothing is drawn while the profile card is on screen', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    expect(copyKey, findsNothing);
    expect(strip, findsNothing);
  });

  testWidgets('the squash starts as soon as the card top leaves the view', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, profileTop);
    expect(copyKey, findsNothing);
    await jump(tester, profileTop + 4);
    expect(copyKey, findsOneWidget);
  });

  testWidgets(
    'squashing, a live copy of the card pins to the top, filling exactly '
    'what is left of the card, its chart shrinking',
    (tester) async {
      final profileKey = GlobalKey();
      await pump(tester, profileKey: profileKey);
      await jump(tester, profileTop + 25);
      final copy = tester.getRect(copyKey);
      final card = tester.getRect(find.byKey(profileKey));
      expect(copy.bottom, closeTo(card.bottom, 0.01));
      expect(copy.left, closeTo(card.left, 0.01));
      expect(copy.right, closeTo(card.right, 0.01));
      // 300 - 40 - 100 = 160 at rest, less its share of the 25 px scrolled.
      expect(
        tester.getSize(find.byType(_FakeChart)).height,
        closeTo(160 - squashAt(25), 0.01),
      );
      expect(strip, findsNothing);
    },
  );

  testWidgets(
    'at the hand-over the strip fades in with its line on the copy\'s plot',
    (tester) async {
      await pump(tester, profileKey: GlobalKey());
      await condenseTo(tester, fadeEnd / 2);
      final s = stripWidget(tester);
      expect(s.backgroundOpacity, closeTo(0.5, 1e-6));
      expect(s.condense, 0);
      expect(s.morphFrom, isNotNull);
      final onScreen = s.morphFrom!.rect.shift(tester.getTopLeft(strip));
      final plot = tester.getRect(find.byType(_FakeChart));
      expect(onScreen.left, closeTo(plot.left, 0.01));
      expect(onScreen.top, closeTo(plot.top, 0.01));
      expect(onScreen.width, closeTo(plot.width, 0.01));
      expect(onScreen.height, closeTo(plot.height, 0.01));
      expect(s.morphFrom!.maxSeconds, 600);
      expect(s.morphFrom!.maxDepthMeters, 18);
    },
  );

  // A fast scroll back up skips frames: from pinned, where the copy is not
  // built, it lands in one frame where the copy shows. That first frame must
  // already be right, or a half-faded strip and a wrongly squashed chart
  // flash for a frame.
  testWidgets('a fast scroll back up is right on its first frame', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    // Down through the squash, as a reader does, to pinned.
    await jump(tester, profileTop + 60);
    await jump(tester, profileTop + profileHeight + 40);
    expect(copyKey, findsNothing);

    position(tester).jumpTo(profileTop + 25);
    await tester.pump();

    expect(strip, findsNothing);
    expect(
      tester.getSize(find.byType(_FakeChart)).height,
      closeTo(160 - squashAt(25), 0.01),
    );
  });

  // The strip shrinks towards its final height while the copy's plot slides
  // up beneath it; it never shrinks faster, or the full chart would show
  // below it.
  testWidgets('while it condenses, the strip never uncovers the copy\'s plot', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    for (final t in [0.3, 0.5, 0.7, 0.9, 1.0]) {
      await condenseTo(tester, t);
      expect(
        tester.getRect(strip).bottom,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(_FakeChart)).bottom - 0.01,
        ),
        reason: 't=$t',
      );
    }
  });

  // Issue #4579: the strip used to cover the card below its plot (its axis
  // and legend) down to the card's bottom, a long, mostly empty box. Only
  // the plot becomes the strip; the rest of the card stays in view.
  testWidgets('the card below its plot is never under the strip', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey);
    for (final t in [0.3, 0.5, 0.7, 0.9, 1.0]) {
      await condenseTo(tester, t);
      final card = tester.getRect(find.byKey(profileKey));
      expect(
        tester.getRect(strip).bottom,
        lessThanOrEqualTo(card.bottom - footer + 0.01),
        reason: 't=$t',
      );
    }
  });

  // Issue #4579: the hand-over ran on until the card's bottom reached the
  // strip, so the cards below came into view under a strip that could not
  // be scrubbed and showed none of their layers.
  testWidgets('it settles as the plot reaches the top, the card left below', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey);
    await jump(tester, profileTop + together);
    final s = stripWidget(tester);
    expect(s.condense, 1);
    expect(s.morphFrom, isNull);
    expect(stripIgnoresPointer(tester), isFalse);
    expect(
      tester
          .widget<PinnedStripLayerHost>(find.byType(PinnedStripLayerHost))
          .settled,
      isTrue,
    );
    // The rest of the card is still on screen, drawn by the copy below the
    // strip.
    expect(copyKey, findsOneWidget);
    final card = tester.getRect(find.byKey(profileKey));
    expect(card.bottom, greaterThan(tester.getRect(strip).bottom + 90));
  });

  // Before the copy had reported its plot, the plot's top was taken as the
  // card's, so a first jump into the hand-over drew the strip settled, and
  // marked it so, for a frame.
  testWidgets('a first jump into the hand-over does not settle the strip', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    position(tester).jumpTo(profileTop + together - 20);
    await tester.pump();
    expect(stripWidget(tester).condense, lessThan(1));
    expect(
      tester
          .widget<PinnedStripLayerHost>(find.byType(PinnedStripLayerHost))
          .settled,
      isFalse,
    );
    await tester.pump();
    await tester.pump();
    expect(stripWidget(tester).condense, lessThan(1));
  });

  // The squashed plot bottomed out 4 px taller than the strip, and the
  // strip never rises above the plot, so it settled 4 px tall and shrank as
  // the plot slid under it (review of #4579). The plot squashes to the
  // strip's own height, so the two meet as it settles.
  testWidgets('it settles at its pinned height and keeps it', (tester) async {
    await pump(tester, profileKey: GlobalKey());
    for (final past in [0.0, 2.0, 4.0, 20.0]) {
      await jump(tester, profileTop + together + past);
      expect(
        tester.getSize(strip).height,
        kPinnedStripHeight,
        reason: '$past px past settling',
      );
    }
  });

  testWidgets('the rest of the card slides up under the settled strip', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey);
    await jump(tester, profileTop + together + 30);
    final card = tester.getRect(find.byKey(profileKey));
    expect(tester.getRect(copyKey).bottom, closeTo(card.bottom, 0.01));
    final pinned = tester.getRect(strip);
    expect(pinned.top, closeTo(overlayTop(tester), 0.01));
    expect(pinned.height, kPinnedStripHeight);
    expect(stripWidget(tester).condense, 1);
  });

  // A see-through surface over the whole card washed everything grey; the
  // fade is confined to the plot, the part that becomes the strip, and the
  // header and legend stay clear above it.
  testWidgets('the fade covers only the plot and below, not the header', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey);
    await condenseTo(tester, fadeEnd / 2);
    final stripBox = tester.getRect(strip);
    final plot = tester.getRect(find.byType(_FakeChart));
    final card = tester.getRect(find.byKey(profileKey));
    expect(stripBox.top, closeTo(plot.top, 0.01));
    // Inside the card's 4 px margin, so its edges sit on the card's surface
    // rather than drawing a second outline around it.
    expect(stripBox.left, closeTo(card.left + 4, 0.01));
    expect(stripBox.right, closeTo(card.right - 4, 0.01));
    // The header button above the plot is not under the strip.
    final header = tester.getRect(
      find.descendant(of: copyKey, matching: find.text('Header action')),
    );
    expect(header.bottom, lessThanOrEqualTo(stripBox.top + 0.01));
  });

  testWidgets('then, opaque, the strip morphs, not yet scrubbable', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    // Halfway through the morph, after the fade.
    const t = (1 + fadeEnd) / 2;
    await condenseTo(tester, t);
    final s = stripWidget(tester);
    expect(s.backgroundOpacity, 1);
    expect(
      s.condense,
      closeTo(condenseMorphProgress(t, fadeEnd: fadeEnd), 1e-6),
    );
    expect(s.condense, inExclusiveRange(0, 1));
    expect(tester.getSize(strip).height, greaterThan(kPinnedStripHeight));
    expect(stripIgnoresPointer(tester), isTrue);
  });

  // Past the moment its plot reaches the top, the card slides the plot out
  // of view, so the full chart is gone by then: no data on it leaves the
  // view while it can still be seen.
  testWidgets('the full chart is covered before its plot reaches the top', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, profileTop + together * 0.5);
    expect(stripWidget(tester).backgroundOpacity, lessThan(1));
    for (final scrolled in [together * 0.5, together - 10, together - 1]) {
      await jump(tester, profileTop + scrolled);
      expect(
        tester.getTopLeft(find.byType(_FakeChart)).dy,
        greaterThanOrEqualTo(overlayTop(tester) - 0.01),
        reason: '$scrolled',
      );
    }
    await jump(tester, profileTop + together - 10);
    expect(stripWidget(tester).backgroundOpacity, 1);
  });

  // The strip's line started on the copy's plot even after that slid above
  // the top, so the line went up out of view and came back down.
  testWidgets('the strip line never goes above the top', (tester) async {
    await pump(tester, profileKey: GlobalKey());
    for (var scrolled = start + 1; scrolled < profileHeight; scrolled += 7) {
      await jump(tester, profileTop + scrolled);
      final s = stripWidget(tester);
      // Settled, the strip draws its own curve and has no line to follow.
      if (s.morphFrom == null) {
        expect(s.condense, 1, reason: '$scrolled');
        continue;
      }
      final from = s.morphFrom!.rect.shift(tester.getTopLeft(strip));
      expect(
        from.top,
        greaterThanOrEqualTo(overlayTop(tester) - 0.01),
        reason: '$scrolled',
      );
    }
  });

  // Zoomed in on the full card, the copy took over at the whole dive in one
  // frame. It starts at the card's own window and zooms out as the page
  // scrolls, reaching the whole dive as its plot reaches the top, where the
  // strip has taken over.
  group('zoomed in on the card', () {
    const zoomed = ChartViewport(zoom: 3, offsetX: 0.3, offsetY: 0.2);

    testWidgets('the copy zooms out from the card\'s window as it pins', (
      tester,
    ) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        chartViewport: ValueNotifier(zoomed),
      );
      await jump(tester, profileTop + 1);
      expect(copyViewport!.zoom, greaterThan(2.9));
      expect(copyViewport!.windowStart, closeTo(0.3, 0.01));

      await jump(tester, profileTop + together / 2);
      final half = ChartViewport.lerp(zoomed, ChartViewport.reset, 0.5);
      expect(copyViewport!.windowStart, closeTo(half.windowStart, 1e-6));
      expect(copyViewport!.windowEnd, closeTo(half.windowEnd, 1e-6));
      expect(copyViewport!.offsetY, closeTo(half.offsetY, 1e-6));

      await jump(tester, profileTop + together);
      expect(copyViewport!.sameWindowAs(ChartViewport.reset), isTrue);
    });

    // On the frame the copy is handed a new window, the strip's line has to
    // be on what the copy now shows, not what it showed a frame ago.
    testWidgets(
      'the strip line keeps to the copy\'s window on the same frame',
      (tester) async {
        await pump(
          tester,
          profileKey: GlobalKey(),
          chartViewport: ValueNotifier(zoomed),
        );
        await jump(tester, profileTop + together * 0.5);
        position(tester).jumpTo(profileTop + together * 0.7);
        await tester.pump();
        final shown = _fakeFrame(GlobalKey(), Rect.zero, copyViewport!);
        final from = stripWidget(tester).morphFrom!;
        expect(from.minSeconds, closeTo(shown.minSeconds, 1e-6));
        expect(from.maxSeconds, closeTo(shown.maxSeconds, 1e-6));
        expect(from.minDepthMeters, closeTo(shown.minDepthMeters, 1e-6));
        expect(from.maxDepthMeters, closeTo(shown.maxDepthMeters, 1e-6));
      },
    );

    testWidgets('without a window from the card, the copy shows it all', (
      tester,
    ) async {
      await pump(tester, profileKey: GlobalKey());
      await jump(tester, profileTop + 10);
      expect(copyViewport!.sameWindowAs(ChartViewport.reset), isTrue);
    });
  });

  // A plot already shorter than kMinPlotHeight has no squash range; its
  // height was rebuilt from that clamped range as kMinPlotHeight, so the
  // strip's line started below the chart's (review).
  testWidgets('a short plot still starts the strip line on its own', (
    tester,
  ) async {
    // 300 - 40 - 230 = 30 px of plot.
    await pump(tester, profileKey: GlobalKey(), footerHeight: 230);
    await jump(tester, profileTop + 20);
    final s = stripWidget(tester);
    final onScreen = s.morphFrom!.rect.shift(tester.getTopLeft(strip));
    final plot = tester.getRect(find.byType(_FakeChart));
    expect(plot.height, closeTo(30, 0.01));
    expect(onScreen.top, closeTo(plot.top, 0.01));
    expect(onScreen.height, closeTo(plot.height, 0.01));
  });

  testWidgets('without a plot from the copy, the strip has no start line', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey(), reportsPlot: false);
    await condenseTo(tester, fadeEnd / 2);
    expect(stripWidget(tester).morphFrom, isNull);
  });

  testWidgets('what is drawn always covers the card left on screen', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey);
    for (final pixels in [
      profileTop + 30,
      profileTop + range - 10,
      profileTop + together - 20,
      profileTop + start + handOver * 0.4,
      profileTop + start + handOver * 0.8,
    ]) {
      await jump(tester, pixels);
      final card = tester.getRect(find.byKey(profileKey));
      final box = tester.getRect(
        find.byKey(const ValueKey('pinnedProfileBox')),
      );
      expect(box.top, closeTo(overlayTop(tester), 0.01), reason: '$pixels');
      expect(box.bottom, greaterThanOrEqualTo(card.bottom - 0.01));
      expect(box.left, lessThanOrEqualTo(card.left + 0.01));
      expect(box.right, greaterThanOrEqualTo(card.right - 0.01));
    }
  });

  // Once settled, nothing drawn depends on the scroll, so scrolling on does
  // not rebuild the strip on every frame (review).
  testWidgets('a settled strip is not rebuilt as the page scrolls on', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, 800);
    final settled = stripWidget(tester);
    expect(settled.condense, 1);
    expect(settled.morphFrom, isNull);
    await jump(tester, 900);
    expect(identical(stripWidget(tester), settled), isTrue);
  });

  testWidgets('the strip carries through to pinned without a swap', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await condenseTo(tester, 0.9);
    final morphing = tester.state(strip);
    await jump(tester, 800);
    expect(identical(tester.state(strip), morphing), isTrue);
    expect(stripWidget(tester).condense, 1);
    expect(stripIgnoresPointer(tester), isFalse);
    expect(copyKey, findsNothing);
    expect(
      tester.getTopLeft(strip),
      tester.getTopLeft(find.byType(PinnedProfileOverlay)) + const Offset(4, 0),
    );
  });

  // The box around what is pinned is the strip's own size once settled, so
  // clipping to it cut off the strip's whole shadow, which falls below it
  // onto the page (#4488).
  testWidgets('the pinned strip casts its shadow onto the page', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    for (final pixels in [profileTop + start + handOver * 0.9, 800.0]) {
      await jump(tester, pixels);
      final box = find.byKey(const ValueKey('pinnedProfileBox'));
      final stack = tester.widget<Stack>(
        find.descendant(of: box, matching: find.byType(Stack)).first,
      );
      expect(stack.clipBehavior, Clip.none, reason: '$pixels');
      // The only clip over it is the page's own, well below its shadow.
      final clips = find.ancestor(of: strip, matching: find.byType(ClipRect));
      for (final clip in clips.evaluate()) {
        expect(
          tester.getRect(find.byWidget(clip.widget)),
          tester.getRect(find.byType(PinnedProfileOverlay)),
          reason: '$pixels',
        );
      }
    }
    // Settled, the strip reaches the bottom of the box, where its shadow
    // falls: any clip there takes all of it.
    expect(
      tester.getRect(strip).bottom,
      tester.getRect(find.byKey(const ValueKey('pinnedProfileBox'))).bottom,
    );
  });

  // The copy slides up past the page's top as it pins. With the box around
  // it unclipped (for the strip's shadow), only a clip on the overlay
  // itself keeps that part off whatever is above the page, the dive's
  // header, where it showed the full chart beside the strip (#4488).
  testWidgets('the sliding copy never draws above the page', (tester) async {
    await pump(tester, profileKey: GlobalKey());
    await condenseTo(tester, fadeEnd / 2);
    expect(
      tester.getTopLeft(copyKey).dy,
      lessThan(overlayTop(tester)),
      reason: 'the copy has slid above the page',
    );
    final overlay = tester.getRect(find.byType(PinnedProfileOverlay));
    final pageClips = find
        .ancestor(of: copyKey, matching: find.byType(ClipRect))
        .evaluate()
        .where((clip) => tester.getRect(find.byWidget(clip.widget)) == overlay);
    expect(pageClips, isNotEmpty);
  });

  // It pins over the other cards, so it is only as wide as they are: inside
  // the profile card's margin from the first frame of the fade to pinned,
  // never widening out to the page's edges (#4488). With a plot as wide as
  // the card, as here, that is the card's width throughout; a narrower plot
  // starts it narrower (the test above).
  testWidgets('the strip stays within the card margin, condensing and pinned', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey, pagePadding: 16);
    final card = tester.getRect(find.byKey(profileKey));
    expect(card.left, closeTo(16, 0.01));
    for (final t in [fadeEnd / 2, (1 + fadeEnd) / 2, 0.9]) {
      await condenseTo(tester, t);
      final box = tester.getRect(strip);
      expect(box.left, closeTo(card.left + 4, 0.01), reason: 't=$t');
      expect(box.right, closeTo(card.right - 4, 0.01), reason: 't=$t');
    }
    await jump(tester, 800);
    final pinned = tester.getRect(strip);
    expect(pinned.left, closeTo(card.left + 4, 0.01));
    expect(pinned.right, closeTo(card.right - 4, 0.01));
    expect(pinned.top, closeTo(overlayTop(tester), 0.01));
    expect(pinned.height, kPinnedStripHeight);
  });

  // The strip's surface spanned the card's width from its first frame, so
  // beside the narrower plot (inside the chart's axes) it showed as blank
  // bands while the curve widened. It starts on the plot alone and widens
  // with the curve, reaching the card's width as it settles.
  testWidgets('the strip widens from the plot to the card as it condenses', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey, plotInset: 40);
    final card = tester.getRect(find.byKey(profileKey));

    await condenseTo(tester, fadeEnd / 2);
    final plot = tester.getRect(find.byType(_FakeChart));
    expect(plot.left, closeTo(card.left + 40, 0.01));
    var box = tester.getRect(strip);
    expect(box.left, closeTo(plot.left, 0.01));
    expect(box.right, closeTo(plot.right, 0.01));

    await condenseTo(tester, (1 + fadeEnd) / 2);
    box = tester.getRect(strip);
    expect(box.left, inExclusiveRange(card.left + 4, card.left + 40));
    expect(box.right, inExclusiveRange(card.right - 40, card.right - 4));

    await jump(tester, profileTop + together);
    box = tester.getRect(strip);
    expect(box.left, closeTo(card.left + 4, 0.01));
    expect(box.right, closeTo(card.right - 4, 0.01));
  });

  // The line was blended inside a box already widening on the same morph,
  // so it lagged the box's edges: a blank border around it (#4579).
  testWidgets('the condensing strip\'s line spans its box', (tester) async {
    await pump(tester, profileKey: GlobalKey(), plotInset: 40);
    for (final t in [(1 + fadeEnd) / 2, 0.9]) {
      await condenseTo(tester, t);
      final s = stripWidget(tester);
      final size = tester.getSize(strip);
      final drawn = Rect.lerp(
        s.morphFrom!.rect,
        pinnedStripCurveRect(size, curveHeight: kPinnedStripHeight),
        s.condense,
      )!;
      expect(drawn.left, closeTo(0, 0.01), reason: 't=$t');
      expect(drawn.right, closeTo(size.width, 0.01), reason: 't=$t');
    }
  });

  testWidgets('after a resize the strip line still starts on the copy plot', (
    tester,
  ) async {
    final width = ValueNotifier(400.0);
    await pump(tester, profileKey: GlobalKey(), width: width);
    await condenseTo(tester, fadeEnd / 2);
    width.value = 520;
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final s = stripWidget(tester);
    final onScreen = s.morphFrom!.rect.shift(tester.getTopLeft(strip));
    final plot = tester.getRect(find.byType(_FakeChart));
    expect(onScreen.width, closeTo(plot.width, 0.01));
    expect(onScreen.left, closeTo(plot.left, 0.01));
  });

  testWidgets('scrolling back up removes everything', (tester) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, 800);
    await jump(tester, 0);
    expect(strip, findsNothing);
    expect(copyKey, findsNothing);
  });

  testWidgets('nothing is drawn when the profile is not on the page', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey(), showProfile: false);
    await jump(tester, 800);
    expect(strip, findsNothing);
    expect(copyKey, findsNothing);
  });

  // The strip lies over the page, not inside its scroll view, so it hands
  // vertical scrolling on to the page itself (review C1).
  // The pinned copy is the card the reader sees, so it is the card they use:
  // its controls work, and taps never fall through to whatever part of the
  // real card happens to lie beneath.
  testWidgets('a tap on the squashed card reaches its own control', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, profileTop + 20);
    await tester.tap(
      find.descendant(of: copyKey, matching: find.text('Header action')),
    );
    await tester.pump();
    expect(headerTaps.value, 1);
  });

  testWidgets('a vertical drag on the squashed card scrolls the page', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, profileTop + 60);
    final before = position(tester).pixels;
    await tester.dragFrom(tester.getCenter(copyKey), const Offset(0, -150));
    await tester.pump();
    expect(position(tester).pixels, greaterThan(before + 80));
  });

  testWidgets('a mouse wheel over the squashed card scrolls the page', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, profileTop + 60);
    final before = position(tester).pixels;
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(copyKey),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    expect(position(tester).pixels, greaterThan(before + 60));
  });

  testWidgets('a vertical drag on the pinned strip scrolls the page', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, 800);
    final before = position(tester).pixels;
    await tester.dragFrom(tester.getCenter(strip), const Offset(0, -200));
    await tester.pump();
    expect(position(tester).pixels, greaterThan(before + 100));
  });

  // Dragging the strip back down unpins the card part way through the
  // gesture; the drag used to be cancelled with its recognizer, so the page
  // stopped dead at the card's top (review).
  testWidgets('a drag that unpins the card keeps scrolling the page', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, profileTop + profileHeight - 40);
    expect(stripWidget(tester).condense, 1);
    final gesture = await tester.startGesture(tester.getCenter(strip));
    for (var i = 0; i < 14; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(strip, findsNothing);
    expect(position(tester).pixels, lessThan(profileTop - 40));
  });

  testWidgets('a mouse wheel over the pinned strip scrolls the page', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, 800);
    final before = position(tester).pixels;
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(strip),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    expect(position(tester).pixels, greaterThan(before + 60));
  });

  // Issue #4562: the marked cards below the pinned strip reach its layers.
  group('cards in view', () {
    PinnedStripLayerHost host(WidgetTester tester) =>
        tester.widget<PinnedStripLayerHost>(find.byType(PinnedStripLayerHost));

    testWidgets('a marked card below the settled strip reaches the host', (
      tester,
    ) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        targetKey: GlobalKey(),
        markTarget: true,
      );
      // The card (1500 to 1600 in the content) shows from 200 to 300.
      await jump(tester, 1300);
      expect(host(tester).shown, isTrue);
      expect(host(tester).settled, isTrue);
      expect(host(tester).cardsInView, {DiveDetailSectionId.environment});
    });

    testWidgets('a card scrolled up under the 72 px edge leaves', (
      tester,
    ) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        targetKey: GlobalKey(),
        markTarget: true,
      );
      await jump(tester, 1300);
      // Now it shows from 0 to 100: 28 px below the edge.
      await jump(tester, 1500);
      expect(host(tester).cardsInView, isEmpty);
    });

    testWidgets('a card below the viewport is not in view', (tester) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        targetKey: GlobalKey(),
        markTarget: true,
      );
      await jump(tester, 800);
      expect(host(tester).cardsInView, isEmpty);
    });

    testWidgets('the strip is not settled while it condenses', (tester) async {
      await pump(tester, profileKey: GlobalKey());
      await condenseTo(tester, 0.5);
      expect(host(tester).shown, isTrue);
      expect(host(tester).settled, isFalse);
    });

    testWidgets('with the strip off, no card is tracked', (tester) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        targetKey: GlobalKey(),
        markTarget: true,
        enabled: false,
      );
      await jump(tester, 1300);
      expect(host(tester).cardsInView, isEmpty);
      expect(host(tester).shown, isFalse);
    });

    testWidgets('the page keeps its place as the strip comes and goes', (
      tester,
    ) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        targetKey: GlobalKey(),
        markTarget: true,
      );
      final page = position(tester);
      await jump(tester, 1300);
      await tester.pump(const Duration(milliseconds: 300));
      expect(identical(position(tester), page), isTrue);
      expect(position(tester).pixels, 1300);
      await jump(tester, 0);
      expect(identical(position(tester), page), isTrue);
      expect(position(tester).pixels, 0);
    });

    testWidgets('scrolling back, the grown strip shrinks as it condenses', (
      tester,
    ) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        targetKey: GlobalKey(),
        markTarget: true,
      );
      // A line layer would grow it; settle with the marked card in view.
      await jump(tester, 1300);
      await tester.pump(const Duration(milliseconds: 300));
      expect(host(tester).settled, isTrue);
      expect(stripWidget(tester).layers.grow, 1);
      expect(tester.getSize(strip).height, kPinnedStripGrownHeight);
      await condenseTo(tester, 0.5);
      expect(host(tester).settled, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(stripWidget(tester).layers.grow, 0);
      expect(stripWidget(tester).layers.strengths, isEmpty);
    });

    // Issue #4579: with a card that adds a line in view right below the
    // profile, the strip condensed to its normal height, settled, then grew:
    // a bounce. It condenses straight to the grown height instead.
    testWidgets('with a line layer card in view, it condenses straight to the '
        'grown height', (tester) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        markTarget: true,
        targetGap: 0,
      );
      // The marked card (400 to 500 in the content) is in view below the
      // strip while the hand-over is under way.
      await condenseTo(tester, 0.6);
      await tester.pump(const Duration(milliseconds: 300));
      expect(host(tester).settled, isFalse);
      expect(host(tester).cardsInView, {DiveDetailSectionId.environment});
      expect(stripWidget(tester).layers.grow, 1);
      // Its layer waits for the strip to settle.
      expect(stripWidget(tester).layers.strengths, isEmpty);

      await jump(tester, profileTop + together);
      expect(host(tester).settled, isTrue);
      // Already at its final height as it settles: nothing left to grow.
      expect(tester.getSize(strip).height, kPinnedStripGrownHeight);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(strip).height, kPinnedStripGrownHeight);
      expect(stripWidget(tester).layers.strengths, isNotEmpty);
      // The card is clear below the strip as its layer comes in.
      expect(
        tester.getTopLeft(find.byType(PinnedStripCardMarker)).dy,
        greaterThan(tester.getRect(strip).bottom),
      );
    });

    // Carrying the growth with the hand-over must not reach a strip that
    // has settled: there a card coming into view eases it taller over
    // 250 ms, as it fades its layer in, rather than snapping it.
    testWidgets('a settled strip eases its growth as a card comes into view', (
      tester,
    ) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        targetGap: 1100,
        markTarget: true,
      );
      await jump(tester, 800);
      expect(host(tester).settled, isTrue);
      expect(tester.getSize(strip).height, kPinnedStripHeight);
      await jump(tester, 1300);
      await tester.pump(const Duration(milliseconds: 125));
      expect(
        tester.getSize(strip).height,
        inExclusiveRange(kPinnedStripHeight, kPinnedStripGrownHeight),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getSize(strip).height, kPinnedStripGrownHeight);
    });

    // A scroll faster than the 250 ms growth settled the strip part grown,
    // and it went on growing after settling (review of #4579).
    testWidgets('a fast scroll to settled reaches the grown height at once', (
      tester,
    ) async {
      await pump(
        tester,
        profileKey: GlobalKey(),
        markTarget: true,
        targetGap: 0,
      );
      // No time passes between these frames: the growth has not ticked.
      await condenseTo(tester, 0.6);
      await jump(tester, profileTop + together);
      expect(host(tester).settled, isTrue);
      expect(tester.getSize(strip).height, kPinnedStripGrownHeight);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(strip).height, kPinnedStripGrownHeight);
    });

    // Data built on an earlier pass served the whole hand-over, so a line
    // the dive had gained since was only found at settling, and the strip
    // grew then: the same bounce (#4579).
    testWidgets('data changed since the last pass sets the condensing height', (
      tester,
    ) async {
      final noTemperature = dive.copyWith(
        profile: [
          for (final p in dive.profile)
            DiveProfilePoint(timestamp: p.timestamp, depth: p.depth),
        ],
      );
      await pump(
        tester,
        profileKey: GlobalKey(),
        markTarget: true,
        targetGap: 0,
        shownDive: noTemperature,
      );
      // A first pass builds the data, with no temperature line to grow for.
      await condenseTo(tester, 0.6);
      await tester.pump(const Duration(milliseconds: 300));
      expect(stripWidget(tester).layers.grow, 0);
      await jump(tester, 0);

      // The dive gains its temperatures; the next pass condenses grown.
      await pump(
        tester,
        profileKey: GlobalKey(),
        markTarget: true,
        targetGap: 0,
      );
      await condenseTo(tester, 0.6);
      await tester.pump(const Duration(milliseconds: 300));
      expect(host(tester).settled, isFalse);
      expect(stripWidget(tester).layers.grow, 1);
    });

    testWidgets('nothing is shown while the card is on screen', (tester) async {
      await pump(tester, profileKey: GlobalKey());
      expect(host(tester).shown, isFalse);
    });
  });

  testWidgets('scrolling to a section leaves it clear of the strip', (
    tester,
  ) async {
    final target = GlobalKey();
    await pump(tester, profileKey: GlobalKey(), targetKey: target);
    await jump(tester, 800);
    expect(strip, findsOneWidget);

    await ensureVisibleBelowPinnedStrip(target.currentContext!);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(target)).dy - overlayTop(tester),
      greaterThanOrEqualTo(kPinnedStripGrownHeight - 0.5),
    );
  });

  // The callers ("Open in notes", "Safety finding details") sit on the
  // profile card, where the strip is not yet showing; it pins on the way to
  // the section, so the room is decided by where the page ends up (review I1).
  testWidgets(
    'jumping from the top leaves the section clear of the strip it pins',
    (tester) async {
      final target = GlobalKey();
      await pump(tester, profileKey: GlobalKey(), targetKey: target);
      expect(strip, findsNothing);

      await ensureVisibleBelowPinnedStrip(target.currentContext!);
      await tester.pumpAndSettle();

      expect(strip, findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(target)).dy - overlayTop(tester),
        greaterThanOrEqualTo(kPinnedStripGrownHeight - 0.5),
      );
    },
  );

  testWidgets('jumping to the profile card itself is not offset', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey);
    await jump(tester, 50);

    await ensureVisibleBelowPinnedStrip(profileKey.currentContext!);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(profileKey)).dy - overlayTop(tester),
      0,
    );
  });

  // Called for a section on a page with no pinned profile around it, it is
  // the plain jump.
  testWidgets('outside the overlay, the jump is a plain ensureVisible', (
    tester,
  ) async {
    final target = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 1500),
                SizedBox(key: target, height: 100),
                const SizedBox(height: 1500),
              ],
            ),
          ),
        ),
      ),
    );
    await ensureVisibleBelowPinnedStrip(target.currentContext!);
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(target)).dy,
      closeTo(tester.getTopLeft(find.byType(Scrollable)).dy, 0.5),
    );
  });
}
