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
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// A synthetic page: a 100 px header, a 300 px "profile card", then a long
/// body with a target box 1500 px down.
void main() {
  final dive = createTestDiveWithBottomTime().copyWith(
    profile: [
      for (var t = 0; t <= 600; t += 10)
        DiveProfilePoint(timestamp: t, depth: t < 300 ? t / 20 : (600 - t) / 20),
    ],
  );
  const profileTop = 100.0;
  const profileHeight = 300.0;

  Future<void> pump(
    WidgetTester tester, {
    required GlobalKey profileKey,
    GlobalKey? targetKey,
    bool showProfile = true,
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

  final proxy = find.byKey(const ValueKey('pinnedProfileProxy'));

  testWidgets('nothing is drawn while the profile card is on screen', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    expect(find.byType(PinnedProfileStrip), findsNothing);
    expect(proxy, findsNothing);
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

  testWidgets('the proxy shows mid-condense, without the strip', (
    tester,
  ) async {
    await pump(tester, profileKey: GlobalKey());
    // Card bottom (400) sits halfway through the window above the strip.
    await jump(tester, 400 - (kPinnedStripHeight + kCondenseWindow / 2));
    expect(proxy, findsOneWidget);
    expect(find.byType(PinnedProfileStrip), findsNothing);
  });

  testWidgets('scrolling back up removes the strip', (tester) async {
    await pump(tester, profileKey: GlobalKey());
    await jump(tester, 800);
    await jump(tester, 0);
    expect(find.byType(PinnedProfileStrip), findsNothing);
    expect(proxy, findsNothing);
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
