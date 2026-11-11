import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Stands in for the profile card's chart: fills its box and, like the real
/// chart, reports where its plot is after each layout.
class _FakeChart extends StatefulWidget {
  const _FakeChart({required this.onPlotFrame});

  final ValueChanged<ProfilePlotFrame>? onPlotFrame;

  @override
  State<_FakeChart> createState() => _FakeChartState();
}

class _FakeChartState extends State<_FakeChart> {
  static final plotKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = ProfilePlotFrame(
          plotKey: plotKey,
          plotRect: Offset.zero & constraints.biggest,
          minSeconds: 0,
          maxSeconds: 600,
          minDepthMeters: 0,
          maxDepthMeters: 18,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPlotFrame?.call(frame);
        });
        return SizedBox.expand(key: plotKey);
      },
    );
  }
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

  Future<void> pump(
    WidgetTester tester, {
    required GlobalKey profileKey,
    GlobalKey? targetKey,
    bool showProfile = true,
    bool reportsPlot = true,
    ValueNotifier<double>? width,
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
                  dive: dive,
                  profileKey: profileKey,
                  squashedCard: (context, onPlotFrame) => Column(
                    children: [
                      const SizedBox(height: 40),
                      Expanded(
                        child: _FakeChart(
                          onPlotFrame: reportsPlot ? onPlotFrame : null,
                        ),
                      ),
                      const SizedBox(height: footer),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: profileTop),
                        if (showProfile)
                          SizedBox(key: profileKey, height: profileHeight)
                        else
                          const SizedBox(height: profileHeight),
                        const SizedBox(height: 1100),
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

  /// The copy's plot sits under its 40 px header: after the squash the card
  /// slides up 40 px to bring the plot to the top, then hands over.
  const start = range + 40;
  const handOver = profileHeight - start - kPinnedStripHeight;

  /// Scrolls so the hand-over to the strip is at progress [t].
  Future<void> condenseTo(WidgetTester tester, double t) =>
      jump(tester, profileTop + start + t * handOver);

  testWidgets(
    'after the squash the copy slides up, header first, with no strip yet',
    (tester) async {
      await pump(tester, profileKey: GlobalKey());
      await jump(tester, profileTop + range + 20);
      expect(
        tester.getTopLeft(copyKey).dy,
        closeTo(overlayTop(tester) - 20, 0.01),
      );
      // The chart stays at its squashed height while it slides.
      expect(
        tester.getSize(find.byType(_FakeChart)).height,
        closeTo(kMinPlotHeight, 0.01),
      );
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
      await jump(tester, profileTop + 60);
      final copy = tester.getRect(copyKey);
      final card = tester.getRect(find.byKey(profileKey));
      expect(copy.top, closeTo(overlayTop(tester), 0.01));
      expect(copy.bottom, closeTo(card.bottom, 0.01));
      expect(copy.left, closeTo(card.left, 0.01));
      expect(copy.right, closeTo(card.right, 0.01));
      // 300 - 40 - 100 = 160 at rest; 60 px squashed out of the chart.
      expect(
        tester.getSize(find.byType(_FakeChart)).height,
        closeTo(100, 0.01),
      );
      expect(strip, findsNothing);
    },
  );

  testWidgets(
    'at the hand-over the strip fades in with its line on the copy\'s plot',
    (tester) async {
      await pump(tester, profileKey: GlobalKey());
      await condenseTo(tester, kCondenseFadePortion / 2);
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

  testWidgets('then, opaque, the strip morphs, not yet scrubbable', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await condenseTo(tester, 0.6);
    final s = stripWidget(tester);
    expect(s.backgroundOpacity, 1);
    expect(s.condense, closeTo(condenseMorphProgress(0.6), 1e-6));
    expect(s.condense, inExclusiveRange(0, 1));
    expect(tester.getSize(strip).height, greaterThan(kPinnedStripHeight));
    expect(stripIgnoresPointer(tester), isTrue);
  });

  testWidgets('without a plot from the copy, the strip has no start line', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey(), reportsPlot: false);
    await condenseTo(tester, kCondenseFadePortion / 2);
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
      profileTop + range + 20,
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
      tester.getTopLeft(find.byType(PinnedProfileOverlay)),
    );
  });

  testWidgets('after a resize the strip line still starts on the copy plot', (
    tester,
  ) async {
    final width = ValueNotifier(400.0);
    await pump(tester, profileKey: GlobalKey(), width: width);
    await condenseTo(tester, kCondenseFadePortion / 2);
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
      greaterThanOrEqualTo(kPinnedStripHeight - 0.5),
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
        greaterThanOrEqualTo(kPinnedStripHeight - 0.5),
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
}
