import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view_gallery.dart';
// flutter_riverpod 3 no longer re-exports Override; the repo's test helpers
// reach for it through the framework library directly.
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../support/media_widget_harness.dart';

void main() {
  testWidgets('shows empty message when site has no photos', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaForSiteProvider(
            'site-1',
          ).overrideWith((ref) async => const <MediaItem>[]),
        ],
        child: const MaterialApp(
          // flutter_test forwards the HOST locale list; without this pin the
          // English assertions below fail on a non-English dev machine.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteMediaViewerPage(
            siteId: 'site-1',
            initialMediaId: 'x',
            scope: SiteViewerScope.attachments,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No photos available'), findsOneWidget);
  });

  testWidgets('documents are filtered out of the pager list', (tester) async {
    final doc = MediaItem(
      id: 'doc-1',
      siteId: 'site-1',
      mediaType: MediaType.document,
      originalFilename: 'map.pdf',
      takenAt: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaForSiteProvider('site-1').overrideWith((ref) async => [doc]),
        ],
        child: const MaterialApp(
          // flutter_test forwards the HOST locale list; without this pin the
          // English assertions below fail on a non-English dev machine.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteMediaViewerPage(
            siteId: 'site-1',
            initialMediaId: 'doc-1',
            scope: SiteViewerScope.attachments,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // A document-only attachment list leaves the pager empty.
    expect(find.text('No photos available'), findsOneWidget);
  });

  // ---------------------------------------------------------------------
  // Populated pager
  // ---------------------------------------------------------------------

  final first = testMediaItem(
    id: 'm1',
    siteId: 'site-1',
    caption: 'Mooring line',
    takenAt: DateTime(2026, 3, 1, 10, 30),
  );
  final second = testMediaItem(
    id: 'm2',
    siteId: 'site-1',
    originalFilename: 'wall.png',
    takenAt: DateTime(2026, 3, 2, 14, 15),
  );

  /// The viewer under an attachments-scoped site with [first] and [second].
  Future<void> pumpViewer(
    WidgetTester tester, {
    String initialMediaId = 'm1',
    List<MediaItem>? items,
    SiteViewerScope scope = SiteViewerScope.attachments,
    List<riverpod.Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          mediaForSiteProvider(
            'site-1',
          ).overrideWith((ref) async => items ?? [first, second]),
          ...extraOverrides,
        ],
        home: SiteMediaViewerPage(
          siteId: 'site-1',
          initialMediaId: initialMediaId,
          scope: scope,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the gallery pager and the 1-based page indicator', (
    tester,
  ) async {
    await pumpViewer(tester);

    expect(find.byType(PhotoViewGallery), findsOneWidget);
    expect(find.text('No photos available'), findsNothing);
    // First of two photos.
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('initialMediaId selects that item rather than the first', (
    tester,
  ) async {
    await pumpViewer(tester, initialMediaId: 'm2');

    expect(find.text('2 / 2'), findsOneWidget);
    // The metadata overlay follows the selected index, so the second item's
    // date - not the first's - is on screen.
    expect(
      find.text(_metadataLine(second.takenAt)),
      findsOneWidget,
      reason: 'bottom overlay should describe the initially selected item',
    );
    expect(find.text(_metadataLine(first.takenAt)), findsNothing);
  });

  testWidgets('an unknown initialMediaId falls back to the first item', (
    tester,
  ) async {
    await pumpViewer(tester, initialMediaId: 'not-in-list');

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text(_metadataLine(first.takenAt)), findsOneWidget);
  });

  testWidgets('swiping the pager advances the indicator and the metadata', (
    tester,
  ) async {
    await pumpViewer(tester);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.drag(find.byType(PhotoViewGallery), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    // The overlay tracks the page the pager settled on.
    expect(find.text('Mooring line'), findsNothing);
    expect(find.text(_metadataLine(second.takenAt)), findsOneWidget);
  });

  testWidgets('arrow buttons page forward and back', (tester) async {
    await pumpViewer(tester);
    expect(find.text('1 / 2'), findsOneWidget);
    // Nothing to go back to on the first item.
    expect(find.byTooltip('Previous media'), findsNothing);

    await tester.tap(find.byTooltip('Next media'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text(_metadataLine(second.takenAt)), findsOneWidget);
    expect(find.byTooltip('Next media'), findsNothing);

    await tester.tap(find.byTooltip('Previous media'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Mooring line'), findsOneWidget);
  });

  testWidgets('a single item gets no arrows', (tester) async {
    await pumpViewer(tester, items: [first]);

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byTooltip('Previous media'), findsNothing);
    expect(find.byTooltip('Next media'), findsNothing);
  });

  testWidgets('left/right arrow keys page through the gallery', (tester) async {
    await pumpViewer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('Escape closes the viewer', (tester) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          mediaForSiteProvider(
            'site-1',
          ).overrideWith((ref) async => [first, second]),
        ],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SiteMediaViewerPage(
                  siteId: 'site-1',
                  initialMediaId: 'm1',
                  scope: SiteViewerScope.attachments,
                ),
              ),
            ),
            child: const Text('Open viewer'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
    expect(find.byType(SiteMediaViewerPage), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(SiteMediaViewerPage), findsNothing);
    expect(find.text('Open viewer'), findsOneWidget);
  });

  /// The viewer over a list the test can shrink underneath it.
  ///
  /// Re-pumping with a different override does NOT do this: the FutureProvider
  /// keeps its cached value, so the pager never sees the shorter list. The
  /// live path is the provider recomputing, so drive that instead.
  Future<void Function(List<MediaItem>)> pumpShrinkableViewer(
    WidgetTester tester,
    List<MediaItem> initialItems, {
    required String initialMediaId,
  }) async {
    var items = initialItems;
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          mediaForSiteProvider('site-1').overrideWith((ref) async => items),
        ],
        home: SiteMediaViewerPage(
          siteId: 'site-1',
          initialMediaId: initialMediaId,
          scope: SiteViewerScope.attachments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SiteMediaViewerPage)),
    );
    return (next) {
      items = next;
      container.invalidate(mediaForSiteProvider('site-1'));
    };
  }

  testWidgets('a site list that shrinks under the viewer keeps working', (
    tester,
  ) async {
    final third = testMediaItem(
      id: 'm3',
      siteId: 'site-1',
      originalFilename: 'kelp.png',
      takenAt: DateTime(2026, 3, 3, 9),
    );
    final shrinkTo = await pumpShrinkableViewer(tester, [
      first,
      second,
      third,
    ], initialMediaId: 'm3');
    expect(find.text('3 / 3'), findsOneWidget);

    // A delete or a sync pull can shrink the list while the viewer is open.
    // Indexing it with the stale page would throw a RangeError out of build.
    shrinkTo([first]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('navigation recovers after the site list shrinks', (
    tester,
  ) async {
    final third = testMediaItem(id: 'm3', siteId: 'site-1');
    final shrinkTo = await pumpShrinkableViewer(tester, [
      first,
      second,
      third,
    ], initialMediaId: 'm3');
    expect(find.text('3 / 3'), findsOneWidget);

    shrinkTo([first, second]);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    // The nav target is still on the departed third item; stepping from it
    // unclamped would put every press out of range and freeze navigation.
    await tester.tap(find.byTooltip('Previous media'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('arrows hide with the rest of the chrome', (tester) async {
    await pumpViewer(tester);
    expect(find.byTooltip('Next media'), findsOneWidget);

    // The tap lands between the arrows: they cover the viewer so they can pin
    // themselves to its edges, and must not swallow the chrome toggle.
    await tester.tapAt(tester.getCenter(find.byType(PhotoViewGallery)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Next media'), findsNothing);
  });

  testWidgets('tapping the photo toggles the overlays off and back on', (
    tester,
  ) async {
    await pumpViewer(tester);

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byTooltip('Close photo viewer'), findsOneWidget);
    expect(find.text('Mooring line'), findsOneWidget);

    // Centre of the screen is the transparent toggle target: it sits above
    // the pager and between the two gradient overlays. The extra elapsed
    // time lets PhotoView's double-tap recognizer time out and release the
    // gesture arena.
    await tester.tapAt(tester.getCenter(find.byType(PhotoViewGallery)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsNothing);
    expect(find.byTooltip('Close photo viewer'), findsNothing);
    expect(find.byTooltip('Share photo'), findsNothing);
    expect(find.text('Mooring line'), findsNothing);
    // The photo itself stays put.
    expect(find.byType(PhotoViewGallery), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(PhotoViewGallery)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byTooltip('Close photo viewer'), findsOneWidget);
    expect(find.text('Mooring line'), findsOneWidget);
  });

  group('bottom metadata overlay', () {
    testWidgets('shows the caption when the item has one', (tester) async {
      await pumpViewer(tester);
      expect(find.text('Mooring line'), findsOneWidget);
      expect(find.text(_metadataLine(first.takenAt)), findsOneWidget);
    });

    testWidgets('omits the caption line when absent but keeps the date', (
      tester,
    ) async {
      await pumpViewer(tester, initialMediaId: 'm2');
      expect(find.text('Mooring line'), findsNothing);
      expect(find.text(_metadataLine(second.takenAt)), findsOneWidget);
    });

    testWidgets('treats an empty caption as no caption', (tester) async {
      final blank = testMediaItem(id: 'm3', siteId: 'site-1', caption: '');
      await pumpViewer(tester, initialMediaId: 'm3', items: [blank]);

      // Only the date/time line renders inside the overlay column.
      expect(find.text(''), findsNothing);
      expect(find.text(_metadataLine(blank.takenAt)), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
    });
  });

  group('scope', () {
    testWidgets('divePhotos reads the dive-derived list, not attachments', (
      tester,
    ) async {
      final divePhoto = testMediaItem(
        id: 'dive-photo',
        diveId: 'd1',
        caption: 'From a dive',
      );
      await tester.pumpWidget(
        await mediaTestApp(
          overrides: [
            // Deliberately different content on each provider so the
            // assertion can only pass if the right one was read.
            mediaForSiteProvider(
              'site-1',
            ).overrideWith((ref) async => [first, second]),
            flatMediaFromDivesAtSiteProvider(
              'site-1',
            ).overrideWith((ref) async => [divePhoto]),
          ],
          home: const SiteMediaViewerPage(
            siteId: 'site-1',
            initialMediaId: 'dive-photo',
            scope: SiteViewerScope.divePhotos,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('From a dive'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('Mooring line'), findsNothing);
    });

    testWidgets('attachments ignores the dive-derived list', (tester) async {
      await pumpViewer(
        tester,
        extraOverrides: [
          flatMediaFromDivesAtSiteProvider(
            'site-1',
          ).overrideWith((ref) async => const <MediaItem>[]),
        ],
      );

      // Empty dive photos must not blank out an attachments-scoped viewer.
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('No photos available'), findsNothing);
    });
  });

  group('async states', () {
    testWidgets('shows a spinner while the media list is still loading', (
      tester,
    ) async {
      final pending = Completer<List<MediaItem>>();
      addTearDown(() => pending.complete(const <MediaItem>[]));

      await tester.pumpWidget(
        await mediaTestApp(
          overrides: [
            mediaForSiteProvider(
              'site-1',
            ).overrideWith((ref) => pending.future),
          ],
          home: const SiteMediaViewerPage(
            siteId: 'site-1',
            initialMediaId: 'm1',
            scope: SiteViewerScope.attachments,
          ),
        ),
      );
      // No settle: the progress indicator animates forever.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PhotoViewGallery), findsNothing);
      expect(find.text('No photos available'), findsNothing);
    });

    testWidgets('surfaces the failure text when the media query throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        await mediaTestApp(
          overrides: [
            mediaForSiteProvider(
              'site-1',
            ).overrideWith((ref) async => throw Exception('disk unreadable')),
          ],
          home: const SiteMediaViewerPage(
            siteId: 'site-1',
            initialMediaId: 'm1',
            scope: SiteViewerScope.attachments,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Error loading photos: Exception: disk unreadable'),
        findsOneWidget,
      );
      expect(find.byType(PhotoViewGallery), findsNothing);
    });
  });

  group('dismissal', () {
    /// Pushes the viewer from a host page so a pop can be observed.
    Future<void> pushViewer(WidgetTester tester) async {
      await tester.pumpWidget(
        await mediaTestApp(
          overrides: [
            mediaForSiteProvider(
              'site-1',
            ).overrideWith((ref) async => [first, second]),
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SiteMediaViewerPage(
                        siteId: 'site-1',
                        initialMediaId: 'm1',
                        scope: SiteViewerScope.attachments,
                      ),
                    ),
                  ),
                  child: const Text('open viewer'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open viewer'));
      await tester.pumpAndSettle();
      expect(find.byType(SiteMediaViewerPage), findsOneWidget);
    }

    testWidgets('the close button pops the viewer route', (tester) async {
      await pushViewer(tester);

      await tester.tap(find.byTooltip('Close photo viewer'));
      await tester.pumpAndSettle();

      expect(find.byType(SiteMediaViewerPage), findsNothing);
      expect(find.text('open viewer'), findsOneWidget);
    });

    testWidgets('a fast downward swipe pops the viewer route', (tester) async {
      await pushViewer(tester);

      final gesture = tester.widget<GestureDetector>(
        find
            .descendant(
              of: find.byType(SiteMediaViewerPage),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      gesture.onVerticalDragEnd!(_dragDown(900));
      await tester.pumpAndSettle();

      expect(find.byType(SiteMediaViewerPage), findsNothing);
    });

    testWidgets('a slow downward drag leaves the viewer open', (tester) async {
      await pushViewer(tester);

      final gesture = tester.widget<GestureDetector>(
        find
            .descendant(
              of: find.byType(SiteMediaViewerPage),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      // Below the 300 px/s threshold, an upward fling, and a drag whose
      // velocity was never resolved are all no-ops.
      gesture.onVerticalDragEnd!(_dragDown(120));
      gesture.onVerticalDragEnd!(_dragDown(-900));
      gesture.onVerticalDragEnd!(DragEndDetails());
      await tester.pumpAndSettle();

      expect(find.byType(SiteMediaViewerPage), findsOneWidget);
    });
  });

  group('share', () {
    /// Taps share against a resolution that is still in flight, so the
    /// blocking dialog gets a frame to itself before [gate] decides the
    /// outcome. Resolving synchronously would let the handler pop before
    /// the dialog was ever pushed.
    Future<void> tapShare(
      WidgetTester tester,
      Completer<ResolvedAssetResult> gate,
    ) async {
      await pumpViewer(
        tester,
        extraOverrides: [
          resolvedFullResolutionProvider(
            first,
          ).overrideWith((ref) => gate.future),
        ],
      );

      await tester.tap(find.byTooltip('Share photo'));
      // No settle: the blocking dialog holds a looping progress indicator.
      await tester.pump();
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'share should block behind a progress dialog while resolving',
      );
    }

    /// Lets the snack bar run its full auto-dismiss so no timer outlives
    /// the test.
    Future<void> drainSnackBar(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('an unresolvable item reports that it cannot be shared', (
      tester,
    ) async {
      final gate = Completer<ResolvedAssetResult>();
      await tapShare(tester, gate);

      gate.complete(
        const ResolvedAssetResult(status: ResolutionStatus.unavailable),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog dismissed, failure announced, viewer still open behind it.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cannot share this photo'), findsOneWidget);
      expect(find.byType(PhotoViewGallery), findsOneWidget);

      await drainSnackBar(tester);
    });

    testWidgets('a failure after resolution is reported, not swallowed', (
      tester,
    ) async {
      final gate = Completer<ResolvedAssetResult>();
      await tapShare(tester, gate);

      // Bytes resolve, so the handler proceeds to the temp-file write --
      // which fails here because path_provider has no platform
      // implementation under `flutter test`. That is the catch branch.
      gate.complete(
        ResolvedAssetResult(
          bytes: onePixelPng(),
          status: ResolutionStatus.resolved,
        ),
      );
      // The temp-file write is real async I/O, so the fake clock has to step
      // aside for it to fail.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Failed to share:'), findsOneWidget);
      expect(find.byType(PhotoViewGallery), findsOneWidget);

      await drainSnackBar(tester);
    });
  });
}

/// A downward flick whose [DragEndDetails.primaryVelocity] and velocity
/// vector agree, as the framework asserts they must.
DragEndDetails _dragDown(double pixelsPerSecond) => DragEndDetails(
  velocity: Velocity(pixelsPerSecond: Offset(0, pixelsPerSecond)),
  primaryVelocity: pixelsPerSecond,
);

/// Mirrors the overlay's own formatting so the assertion survives locale
/// data changes (intl has moved the space inside `jm` before now).
String _metadataLine(DateTime takenAt) =>
    '${DateFormat.yMMMd().format(takenAt)} at ${DateFormat.jm().format(takenAt)}';
