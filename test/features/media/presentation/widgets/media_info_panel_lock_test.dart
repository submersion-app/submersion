import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import 'media_info_panel_harness.dart';

/// The info panel under the photo viewer's lock (issue #4527): read only
/// while the photo is locked, and holding its changes in the sitting while
/// it is unlocked.
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
    bool readOnly = false,
    EditSession<PhotoRecord>? sitting,
  }) => pumpInfoPanel(
    tester,
    item,
    recorder: recorder,
    extra: extra,
    readOnly: readOnly,
    sitting: sitting,
  );

  group('the photo\'s lock (issue #4527)', () {
    testWidgets('read only: no Set time', (tester) async {
      await pump(
        tester,
        infoPanelLinked(enrichment: infoPanelEnrichmentAt(750)),
        extra: [infoPanelDiveOverride()],
        readOnly: true,
      );

      expect(find.text('Time in dive'), findsOneWidget);
      expect(find.text('Set time in dive'), findsNothing);
    });

    testWidgets('read only: no Locate', (tester) async {
      await pump(
        tester,
        infoPanelItem(
          sourceType: MediaSourceType.localFile,
          platformAssetId: null,
          localPath: '/gone/reef.jpg',
          isOrphaned: true,
        ),
        readOnly: true,
      );

      expect(find.text('Locate file...'), findsNothing);
    });

    testWidgets('in a sitting: Set time holds the pin; nothing applied', (
      tester,
    ) async {
      final applied = <MediaTimeChoice>[];
      final item = infoPanelLinked(enrichment: infoPanelEnrichmentAt(750));
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      addTearDown(sitting.dispose);
      await pump(
        tester,
        item,
        extra: [
          infoPanelDiveOverride(),
          mediaTimePinnerProvider.overrideWithValue(CapturingPinner(applied)),
        ],
        sitting: sitting,
      );

      await tester.tap(find.text('Set time in dive'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5:00');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(applied, isEmpty);
      expect(sitting.valueOf(photoPinField), 300);
    });

    testWidgets('in a sitting: Locate is not offered until it can be held', (
      tester,
    ) async {
      final item = infoPanelItem(
        sourceType: MediaSourceType.localFile,
        platformAssetId: null,
        localPath: '/gone/reef.jpg',
        isOrphaned: true,
      );
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      addTearDown(sitting.dispose);
      await pump(tester, item, sitting: sitting);

      expect(find.text('Locate file...'), findsNothing);
    });
  });
}
