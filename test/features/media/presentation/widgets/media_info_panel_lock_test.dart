import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/helpers/media_link_replacer.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import 'media_info_panel_harness.dart';

/// A repair service that must not be used: a held relink is applied only
/// at Save.
class _NeverApplied implements MediaRepairService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('applied before Save: ${invocation.memberName}');
}

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

    testWidgets('in a sitting: the held time is shown, and Set time starts '
        'from it', (tester) async {
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
          mediaTimePinnerProvider.overrideWithValue(CapturingPinner([])),
        ],
        sitting: sitting,
      );
      expect(find.text('12:30'), findsOneWidget);

      sitting.set(photoPinField, 300);
      await tester.pumpAndSettle();

      expect(find.text('5:00 (set manually)'), findsOneWidget);
      expect(find.text('12:30'), findsNothing);
      await tester.tap(find.text('Set time in dive'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '5:00');
    });

    MediaItem missingFile() => infoPanelItem(
      sourceType: MediaSourceType.localFile,
      platformAssetId: null,
      localPath: '/gone/reef.jpg',
      isOrphaned: true,
    );

    /// Locate's picker answering [path] (when it completes), with the
    /// row's own bytes, so no confirmation is asked.
    Override pickerAnswering(Future<String?> path) =>
        mediaLinkFileSourceProvider.overrideWithValue(
          MediaLinkFileSource(
            pick: () => path,
            hash: (_) async => (hash: 'same', sizeBytes: 9),
          ),
        );

    testWidgets('in a sitting: Locate holds the relink; nothing is applied, '
        'and the sheet shows the held file', (tester) async {
      final item = missingFile();
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      addTearDown(sitting.dispose);
      await pump(
        tester,
        item,
        extra: [
          pickerAnswering(Future.value('/found/reef.jpg')),
          mediaRepairServiceProvider.overrideWithValue(_NeverApplied()),
        ],
        sitting: sitting,
      );

      await tester.tap(find.text('Locate file...'));
      await tester.pumpAndSettle();

      expect(sitting.isHeld(photoRelinkKey), isTrue);
      expect(sitting.changedCardIds, {photoFileCardId});
      expect(heldRelink(sitting)?.candidate?.path, '/found/reef.jpg');
      // The sheet reads the held file: found, so nothing left to locate.
      expect(find.text('/found/reef.jpg'), findsOneWidget);
      expect(find.text('/gone/reef.jpg'), findsNothing);
      expect(find.text('Locate file...'), findsNothing);
    });

    testWidgets('a pick that answers after the sitting ended holds nothing', (
      tester,
    ) async {
      final item = missingFile();
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      final picked = Completer<String?>();
      await pump(
        tester,
        item,
        extra: [
          pickerAnswering(picked.future),
          mediaRepairServiceProvider.overrideWithValue(_NeverApplied()),
        ],
        sitting: sitting,
      );

      await tester.tap(find.text('Locate file...'));
      await tester.pump();
      sitting.dispose();
      picked.complete('/found/reef.jpg');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('locked: Locate is not offered', (tester) async {
      final item = missingFile();
      await pump(tester, item, readOnly: true);

      expect(find.text('Locate file...'), findsNothing);
    });
  });
}
