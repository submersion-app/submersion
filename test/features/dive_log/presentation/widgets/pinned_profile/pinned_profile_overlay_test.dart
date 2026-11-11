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

/// A synthetic page: a 100 px header, a 300 px "profile card", then a long
/// body with a target box 1500 px down.
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

  /// The card's chart plot: 40 px in, 20 px down, 320 x 200.
  const plotInCard = Rect.fromLTWH(40, 20, 320, 200);
  final plotKey = GlobalKey();
  final plotFrame = ProfilePlotFrame(
    plotKey: plotKey,
    minSeconds: 0,
    maxSeconds: 600,
    minDepthMeters: 0,
    maxDepthMeters: 18,
  );

  Future<void> pump(
    WidgetTester tester, {
    required GlobalKey profileKey,
    GlobalKey? targetKey,
    bool showProfile = true,
    bool withPlotFrame = true,
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
          if (withPlotFrame)
            profilePlotFrameProvider(dive.id).overrideWith((ref) => plotFrame),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: PinnedProfileOverlay(
                dive: dive,
                profileKey: profileKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: profileTop),
                      if (showProfile)
                        SizedBox(
                          key: profileKey,
                          height: profileHeight,
                          child: Stack(
                            children: [
                              Positioned.fromRect(
                                rect: plotInCard,
                                child: SizedBox.expand(key: plotKey),
                              ),
                            ],
                          ),
                        )
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
  }

  final strip = find.byType(PinnedProfileStrip);

  /// Scrolls so the condense is at progress [t]: it runs from the card's
  /// top reaching the viewport top to its bottom reaching the strip's.
  Future<void> condenseTo(WidgetTester tester, double t) =>
      jump(tester, profileTop + t * (profileHeight - kPinnedStripHeight));

  testWidgets('the condense starts as soon as the card top leaves the view', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, profileTop);
    expect(strip, findsNothing);
    await jump(tester, profileTop + 4);
    expect(strip, findsOneWidget);
  });

  testWidgets('the condensing strip covers all of the card left on screen', (
    tester,
  ) async {
    final profileKey = GlobalKey();
    await pump(tester, profileKey: profileKey);
    for (final t in [0.1, 0.4, 0.8]) {
      await condenseTo(tester, t);
      final card = tester.getRect(find.byKey(profileKey));
      final box = tester.getRect(strip);
      final viewportTop = tester
          .getTopLeft(find.byType(PinnedProfileOverlay))
          .dy;
      expect(box.top, closeTo(viewportTop, 0.01), reason: 't=$t');
      expect(box.bottom, greaterThanOrEqualTo(card.bottom - 0.01));
      expect(box.left, lessThanOrEqualTo(card.left + 0.01));
      expect(box.right, greaterThanOrEqualTo(card.right - 0.01));
    }
  });

  PinnedProfileStrip stripWidget(WidgetTester tester) =>
      tester.widget<PinnedProfileStrip>(strip);

  bool ignoresPointer(WidgetTester tester) => tester
      .widget<IgnorePointer>(
        find.ancestor(of: strip, matching: find.byType(IgnorePointer)).first,
      )
      .ignoring;

  testWidgets('nothing is drawn while the profile card is on screen', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    expect(strip, findsNothing);
  });

  testWidgets('the strip shows once the card has scrolled past', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, 800);
    expect(find.byType(PinnedProfileStrip), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(PinnedProfileStrip)),
      tester.getTopLeft(find.byType(PinnedProfileOverlay)),
    );
  });

  testWidgets(
    'first its line sits exactly on the chart plot while its background '
    'fades in and its shape holds still',
    (tester) async {
      await pump(tester, profileKey: GlobalKey());
      await condenseTo(tester, kCondenseFadePortion / 2);
      final s = stripWidget(tester);
      expect(s.backgroundOpacity, closeTo(0.5, 1e-6));
      expect(s.condense, 0);
      // The strip's starting mapping, placed on screen, is the chart plot.
      final stripTopLeft = tester.getTopLeft(strip);
      expect(s.morphFrom, isNotNull);
      final onScreen = s.morphFrom!.rect.shift(stripTopLeft);
      final plot = tester.getRect(find.byKey(plotKey));
      expect(onScreen.left, closeTo(plot.left, 0.01));
      expect(onScreen.top, closeTo(plot.top, 0.01));
      expect(onScreen.width, closeTo(plot.width, 0.01));
      expect(onScreen.height, closeTo(plot.height, 0.01));
      expect(s.morphFrom!.maxSeconds, 600);
      expect(s.morphFrom!.maxDepthMeters, 18);
    },
  );

  testWidgets('then, opaque, its shape morphs, not yet scrubbable', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await condenseTo(tester, 0.6);
    final s = stripWidget(tester);
    expect(s.backgroundOpacity, 1);
    expect(s.condense, closeTo(condenseMorphProgress(0.6), 1e-6));
    expect(s.condense, inExclusiveRange(0, 1));
    expect(tester.getSize(strip).height, greaterThan(kPinnedStripHeight));
    expect(ignoresPointer(tester), isTrue);
  });

  testWidgets('without the chart plot, it has no starting mapping', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey(), withPlotFrame: false);
    await condenseTo(tester, kCondenseFadePortion / 2);
    expect(stripWidget(tester).morphFrom, isNull);
  });

  testWidgets('the morphing strip carries through to pinned without a swap', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    await condenseTo(tester, 0.9);
    final morphing = tester.state(strip);
    await jump(tester, 800);
    expect(identical(tester.state(strip), morphing), isTrue);
    expect(tester.widget<PinnedProfileStrip>(strip).condense, 1);
    expect(ignoresPointer(tester), isFalse);
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

  testWidgets('scrolling back up removes the strip', (tester) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, 800);
    await jump(tester, 0);
    expect(strip, findsNothing);
  });

  testWidgets('no strip when the profile is not on the page', (tester) async {
    await pump(tester, profileKey: GlobalKey(), showProfile: false);
    await jump(tester, 800);
    expect(find.byType(PinnedProfileStrip), findsNothing);
  });

  testWidgets('scrolling to a section leaves it clear of the strip', (
    tester,
  ) async {
    final target = GlobalKey();
    await pump(tester, profileKey: GlobalKey(), targetKey: target);
    await jump(tester, 800);
    expect(find.byType(PinnedProfileStrip), findsOneWidget);

    await ensureVisibleBelowPinnedStrip(target.currentContext!);
    await tester.pumpAndSettle();

    final overlayTop = tester.getTopLeft(find.byType(PinnedProfileOverlay)).dy;
    expect(
      tester.getTopLeft(find.byKey(target)).dy - overlayTop,
      greaterThanOrEqualTo(kPinnedStripHeight - 0.5),
    );
  });

  testWidgets('without the strip, scrolling to a section is unchanged', (
    tester,
  ) async {
    final target = GlobalKey();
    await pump(tester, profileKey: GlobalKey(), targetKey: target);

    await ensureVisibleBelowPinnedStrip(target.currentContext!);
    await tester.pumpAndSettle();

    final overlayTop = tester.getTopLeft(find.byType(PinnedProfileOverlay)).dy;
    expect(tester.getTopLeft(find.byKey(target)).dy - overlayTop, 0);
  });
}
