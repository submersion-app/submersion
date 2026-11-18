import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'media_info_panel_harness.dart';

const _item = infoPanelItem;

/// The info panel's Serving block, its time in the dive (issue #1090), and
/// what a browser may do with it (#4121). Split from media_info_panel_test
/// to keep each file under the size cap.
void main() {
  late String? previousDefaultLocale;
  late MediaServingRecorder recorder;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    recorder = MediaServingRecorder();
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  Future<void> pump(
    WidgetTester tester,
    MediaItem item, {
    List<dynamic> extra = const [],
  }) => pumpInfoPanel(tester, item, recorder: recorder, extra: extra);

  group('Serving block', () {
    testWidgets('an unobserved item says not loaded yet', (tester) async {
      await pump(tester, _item());

      expect(find.text('Not loaded yet'), findsOneWidget);
    });

    testWidgets('a store-cache serving reads as local cache', (tester) async {
      recorder.record(
        'm1',
        thumbnail: false,
        servedFrom: ServedFrom.storeCache,
      );
      await pump(tester, _item());

      expect(find.text('Local cache, from the cloud store'), findsOneWidget);
    });

    testWidgets('a non-original tier is named alongside the source', (
      tester,
    ) async {
      recorder.record(
        'm1',
        thumbnail: false,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: ServedTier.rendition,
      );
      await pump(tester, _item());

      expect(
        find.text('Downloaded from the cloud store (Compressed version)'),
        findsOneWidget,
      );
    });

    testWidgets('a store fallback adds the fallback note', (tester) async {
      recorder.record(
        'm1',
        thumbnail: false,
        servedFrom: ServedFrom.storeNetwork,
        storeFallbackUsed: true,
      );
      await pump(tester, _item());

      expect(
        find.textContaining('original source could not be reached'),
        findsOneWidget,
      );
    });

    testWidgets('a failed resolution reads as could not be loaded', (
      tester,
    ) async {
      recorder.record(
        'm1',
        thumbnail: false,
        failure: UnavailableKind.notFound,
        storeFallbackUsed: true,
      );
      await pump(tester, _item());

      expect(find.text('Could not be loaded'), findsOneWidget);
      // The fallback note explains where bytes CAME from, so it must not
      // appear when nothing was served.
      expect(
        find.textContaining('original source could not be reached'),
        findsNothing,
      );
    });

    // The whole point of the ListenableBuilder: a tile that resolves while
    // the panel is open must update it.
    testWidgets('refreshes when the recorder records', (tester) async {
      await pump(tester, _item());
      expect(find.text('Not loaded yet'), findsOneWidget);

      recorder.record('m1', thumbnail: false, servedFrom: ServedFrom.localDisk);
      await tester.pumpAndSettle();

      expect(find.text('Not loaded yet'), findsNothing);
      expect(find.text('Local file on this device'), findsOneWidget);
    });
  });

  group('Time in dive (issue #1090)', () {
    const linked = infoPanelLinked;
    const enrichmentAt = infoPanelEnrichmentAt;
    final diveOverride = infoPanelDiveOverride();

    testWidgets('renders the automatic position as mm:ss', (tester) async {
      await pump(
        tester,
        linked(enrichment: enrichmentAt(750)),
        extra: [diveOverride],
      );

      expect(find.text('Time in dive'), findsOneWidget);
      expect(find.text('12:30'), findsOneWidget);
    });

    testWidgets('marks a manual position as set by the diver', (tester) async {
      await pump(
        tester,
        linked(
          enrichment: enrichmentAt(750, confidence: MatchConfidence.manual),
        ),
        extra: [diveOverride],
      );

      expect(find.text('12:30 (set manually)'), findsOneWidget);
    });

    testWidgets('renders Unknown for a position outside the dive window', (
      tester,
    ) async {
      await pump(
        tester,
        linked(
          enrichment: enrichmentAt(
            1879 * 60,
            confidence: MatchConfidence.estimated,
          ),
        ),
        extra: [diveOverride],
      );

      expect(find.text('Time in dive'), findsOneWidget);
      expect(find.text('1879:00'), findsNothing);
    });

    testWidgets('offers no row or action for an item with no dive', (
      tester,
    ) async {
      await pump(tester, _item());

      expect(find.text('Time in dive'), findsNothing);
      expect(find.text('Set time in dive'), findsNothing);
    });
  });

  group('in a browser (#4121)', () {
    testWidgets('natively the origin can be checked', (tester) async {
      await pump(tester, _item());
      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.media_info_actionCheckNow), findsOneWidget);
    });

    testWidgets('a browser only reads: no check, locate or back up', (
      tester,
    ) async {
      await pump(
        tester,
        _item(),
        extra: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
      );
      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text('reef.jpg'), findsOneWidget);
      expect(find.text(en.media_info_actionCheckNow), findsNothing);
      expect(find.text(en.media_info_actionLocate), findsNothing);
      expect(find.text(en.media_info_actionCopyNow), findsNothing);
      expect(find.text(en.media_info_actionRetryUpload), findsNothing);
    });
  });
}
