import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/helpers/media_link_replacer.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_panel.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import 'media_info_panel_harness.dart';

/// A repair service that must not be used: a held relink is applied only
/// at Save.
class _NeverApplied implements MediaRepairService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('applied before Save: ${invocation.memberName}');
}

/// Records which file each Check now was asked about.
class _RecordingVerifier implements MediaItemVerifier {
  final List<String?> checked = [];

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    checked.add(item.localPath);
    return VerifyResult.available;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
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

    // Each change is held in the photo's sitting: with none there is
    // nowhere to hold it, and writing at once would change the photo
    // outside its lock.
    testWidgets('with no sitting: no Set time, Locate or Edit tags', (
      tester,
    ) async {
      await pump(
        tester,
        infoPanelLinked(
          enrichment: infoPanelEnrichmentAt(750),
        ).copyWith(isOrphaned: true),
        extra: [infoPanelDiveOverride()],
      );

      expect(find.text('Time in dive'), findsOneWidget);
      expect(find.text('Set time in dive'), findsNothing);
      expect(find.text('Locate file...'), findsNothing);
      expect(find.byKey(const ValueKey('media_info_editTags')), findsNothing);
    });

    testWidgets('in a sitting: Set time holds the pin', (tester) async {
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
          mediaTimePinnerProvider.overrideWithValue(const NoShiftPinner()),
        ],
        sitting: sitting,
      );

      await tester.tap(find.text('Set time in dive'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5:00');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

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
          mediaTimePinnerProvider.overrideWithValue(const NoShiftPinner()),
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

    testWidgets('in a sitting with a relink held, Check now checks the '
        'stored file, not the one found', (tester) async {
      final item = missingFile();
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      addTearDown(sitting.dispose);
      final verifier = _RecordingVerifier();
      await pump(
        tester,
        item,
        extra: [
          pickerAnswering(Future.value('/found/reef.jpg')),
          mediaRepairServiceProvider.overrideWithValue(_NeverApplied()),
          mediaItemVerifierProvider.overrideWithValue(verifier),
        ],
        sitting: sitting,
      );
      await tester.tap(find.text('Locate file...'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();

      expect(verifier.checked, ['/gone/reef.jpg']);
    });

    testWidgets('Locate is not offered over a photo whose link the dive\'s '
        'sitting already replaces', (tester) async {
      final item = missingFile().copyWith(diveId: 'd1');
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      addTearDown(sitting.dispose);
      final dive = EditSession<Dive>(
        Dive(id: 'd1', dateTime: DateTime.utc(2026)),
      );
      addTearDown(dive.dispose);
      holdSittingMedia(
        dive,
        SittingMediaWriters(
          writeRows: (_) async => const [],
          insertNetwork: (_) async => const [],
          unlink: (_) async {},
          replace: (_, _, _) async {},
          drainDeletes: () async {},
          enqueueUpload: (_) {},
        ),
        cardId: 'media',
      );
      replaceLinkInSitting(
        dive,
        item.id,
        RepairProposal(
          item: item,
          confidence: RepairConfidence.exact,
          candidate: const RepairCandidate.file(
            path: '/card/reef.jpg',
            sizeBytes: 9,
          ),
        ),
      );
      await pump(
        tester,
        item,
        extra: [
          openDiveSittingProvider.overrideWith(
            (ref) => OpenDiveSitting(
              diveId: 'd1',
              session: dive,
              showMediaCard: () {},
            ),
          ),
        ],
        sitting: sitting,
      );

      expect(find.text('Locate file...'), findsNothing);
    });

    testWidgets('while the stored row is still being read, no store action '
        'is offered', (tester) async {
      final item = missingFile();
      final never = Completer<MediaItem?>();
      await pumpInfoPanel(
        tester,
        item,
        recorder: recorder,
        readRow: () => never.future,
      );

      expect(find.text('Check now'), findsNothing);
      expect(find.text('Locate file...'), findsNothing);
    });

    testWidgets('while a relink is held, the upload is not offered: Save '
        'queues it', (tester) async {
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
      expect(find.text('Copy now'), findsOneWidget);

      await tester.tap(find.text('Locate file...'));
      await tester.pumpAndSettle();

      expect(find.text('Copy now'), findsNothing);
    });

    testWidgets('a photo with no stored row offers no upload', (tester) async {
      await pumpInfoPanel(
        tester,
        missingFile(),
        recorder: recorder,
        readRow: () async => null,
      );

      expect(find.text('Copy now'), findsNothing);
      expect(find.text('Check now'), findsNothing);
    });

    testWidgets('when the sitting ends under the sheet, the sheet keeps its '
        'place', (tester) async {
      final item = missingFile();
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      await pump(tester, item, sitting: sitting);
      final scrollable = tester.state(find.byType(Scrollable).first);

      sitting.dispose();
      ProviderScope.containerOf(
        tester.element(find.byType(MediaInfoPanel)),
      ).invalidate(mediaByIdProvider(item.id));
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(Scrollable).first), same(scrollable));
    });

    testWidgets('locked: Locate is not offered', (tester) async {
      final item = missingFile();
      await pump(tester, item, readOnly: true);

      expect(find.text('Locate file...'), findsNothing);
    });
  });
}
