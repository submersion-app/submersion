import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_playback_context.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';

import 'site_terrain_pane_test_support.dart';

const _diveRequest = (
  siteId: 'site-1',
  pathId: 'd1',
  source: PathOverlaySource.dive,
  isolatePaths: true,
);

void main() {
  Widget divePane({
    SeascapePlaybackContext? context = const DivePlaybackContext('d1'),
  }) => page(
    readyState(),
    playbackContext: context,
    extraOverrides: [
      siteActivePathOverlayProvider(_diveRequest).overrideWith(
        (ref) async =>
            (overlay: testActivePathOverlay(), hasLinkedRoute: false),
      ),
    ],
  );

  Future<void> pumpDivePane(WidgetTester tester) async {
    await tester.pumpWidget(divePane());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
    'dive playback with a linked route shows the timeline, caption and route toggle',
    (tester) async {
      await tester.pumpWidget(
        page(
          readyState(),
          playbackContext: const DivePlaybackContext('d1'),
          extraOverrides: [
            siteActivePathOverlayProvider(_diveRequest).overrideWith(
              (ref) async => (
                overlay: testActivePathOverlay(sourceLabel: 'Seacraft ENC'),
                hasLinkedRoute: true,
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(TimeScrubBar), findsOneWidget);
      expect(find.text('Recorded track (Seacraft ENC)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('spatial-site-show-route-toggle')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('scrubbing while playing stops playback', (tester) async {
    await pumpDivePane(tester);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(
      tester.widget<TimeScrubBar>(find.byType(TimeScrubBar)).playing,
      isTrue,
    );

    // Dragging the scrub bar mid-playback must stop it, not fight the drag
    // (see TimeScrubBar.onScrubStart's doc).
    await tester.drag(find.byType(Slider), const Offset(20, 0));
    await tester.pump();

    expect(
      tester.widget<TimeScrubBar>(find.byType(TimeScrubBar)).playing,
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('playback can leave and return on the same pane', (tester) async {
    await pumpDivePane(tester);
    await tester.pumpWidget(divePane(context: null));
    await tester.pump(const Duration(milliseconds: 50));
    await pumpDivePane(tester);

    expect(find.byType(TimeScrubBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('losing the active path stops playback', (tester) async {
    var hasPath = true;
    await tester.pumpWidget(
      page(
        readyState(),
        playbackContext: const DivePlaybackContext('d1'),
        extraOverrides: [
          siteActivePathOverlayProvider(_diveRequest).overrideWith(
            (ref) async => hasPath
                ? (overlay: testActivePathOverlay(), hasLinkedRoute: false)
                : null,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimeScrubBar)),
    );

    hasPath = false;
    container.invalidate(siteActivePathOverlayProvider(_diveRequest));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TimeScrubBar), findsNothing);

    hasPath = true;
    container.invalidate(siteActivePathOverlayProvider(_diveRequest));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.widget<TimeScrubBar>(find.byType(TimeScrubBar)).playing,
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('dive playback with no linked route hides the route toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        readyState(),
        playbackContext: const DivePlaybackContext('d1'),
        extraOverrides: [
          siteActivePathOverlayProvider(_diveRequest).overrideWith(
            (ref) async => (
              overlay: testActivePathOverlay(
                provenance: PathProvenance.deadReckoned,
              ),
              hasLinkedRoute: false,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Estimated path (dead reckoning)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spatial-site-show-route-toggle')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'nav-track playback shows the timeline but no provenance caption or route toggle',
    (tester) async {
      await tester.pumpWidget(
        page(
          readyState(),
          playbackContext: const NavTrackPlaybackContext('t1'),
          extraOverrides: [
            siteActivePathOverlayProvider((
              siteId: 'site-1',
              pathId: 't1',
              source: PathOverlaySource.navTrack,
              isolatePaths: true,
            )).overrideWith(
              (ref) async =>
                  (overlay: testActivePathOverlay(), hasLinkedRoute: false),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(TimeScrubBar), findsOneWidget);
      expect(find.text('Recorded track'), findsNothing);
      expect(
        find.byKey(const ValueKey('spatial-site-show-route-toggle')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('a dive with no resolved path hides the timeline and says so', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        readyState(),
        playbackContext: const DivePlaybackContext('d1'),
        extraOverrides: [
          siteActivePathOverlayProvider(
            _diveRequest,
          ).overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(TimeScrubBar), findsNothing);
    // The standalone view says the path could not be reconstructed; the
    // site-hosted view must too, not silently show only the site.
    expect(
      find.text('Not enough data to reconstruct the dive path'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping play toggles the timeline playback state', (
    tester,
  ) async {
    await pumpDivePane(tester);

    expect(
      tester.widget<TimeScrubBar>(find.byType(TimeScrubBar)).playing,
      isFalse,
    );

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(
      tester.widget<TimeScrubBar>(find.byType(TimeScrubBar)).playing,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'the pause icon reverts to play once the timeline finishes on its own',
    (tester) async {
      await pumpDivePane(tester);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(
        tester.widget<TimeScrubBar>(find.byType(TimeScrubBar)).playing,
        isTrue,
      );

      // The timeline runs for 45 seconds; letting it run past that (with no
      // further taps) must update the bar on its own once it completes, or
      // the pause icon stays up forever.
      await tester.pump(const Duration(seconds: 46));

      expect(
        tester.widget<TimeScrubBar>(find.byType(TimeScrubBar)).playing,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
