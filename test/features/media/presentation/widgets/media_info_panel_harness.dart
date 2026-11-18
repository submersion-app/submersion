import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_pinner.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_panel.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

/// Shared by the info panel's tests: the photo they show, a pinner that
/// records what it was asked to apply, and the panel pumped with the store
/// and serving providers answered.

MediaItem infoPanelItem({
  MediaSourceType sourceType = MediaSourceType.platformGallery,
  String? platformAssetId = 'asset-1',
  String? localPath,
  String? originalFilename = 'reef.jpg',
  int? width = 4032,
  int? height = 3024,
  int? contentSizeBytes = 3 * 1024 * 1024,
  String? originDeviceId,
  bool isOrphaned = false,
  DateTime? lastVerifiedAt,
  DateTime? remoteUploadedAt,
  DateTime? remoteThumbUploadedAt,
}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: sourceType,
  platformAssetId: platformAssetId,
  localPath: localPath,
  originalFilename: originalFilename,
  width: width,
  height: height,
  contentSizeBytes: contentSizeBytes,
  originDeviceId: originDeviceId,
  isOrphaned: isOrphaned,
  lastVerifiedAt: lastVerifiedAt,
  remoteUploadedAt: remoteUploadedAt,
  remoteThumbUploadedAt: remoteThumbUploadedAt,
  takenAt: DateTime(2026, 3, 12, 9, 14),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

/// The dive `d1` the time-in-dive tests place the photo in.
final infoPanelDive = domain.Dive(
  id: 'd1',
  dateTime: DateTime.utc(2026, 3, 12, 9),
  profile: const [
    domain.DiveProfilePoint(timestamp: 0, depth: 0),
    domain.DiveProfilePoint(timestamp: 600, depth: 20),
    domain.DiveProfilePoint(timestamp: 1800, depth: 0),
  ],
);

/// [infoPanelDive] for `diveProvider('d1')`.
Override infoPanelDiveOverride() =>
    diveProvider('d1').overrideWith((ref) async => infoPanelDive);

/// The photo on dive `d1`, placed by [enrichment].
MediaItem infoPanelLinked({MediaEnrichment? enrichment}) => MediaItem(
  id: 'm1',
  diveId: 'd1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: 'asset-1',
  takenAt: DateTime(2026, 3, 12, 9, 14),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
  enrichment: enrichment,
);

/// The photo placed [elapsedSeconds] into dive `d1`.
MediaEnrichment infoPanelEnrichmentAt(
  int elapsedSeconds, {
  MatchConfidence confidence = MatchConfidence.exact,
}) => MediaEnrichment(
  id: 'e1',
  mediaId: 'm1',
  diveId: 'd1',
  elapsedSeconds: elapsedSeconds,
  depthMeters: 12,
  matchConfidence: confidence,
  createdAt: DateTime(2026, 3, 12),
);

/// A pinner that offers no dive-wide shift, so Set time needs no dive.
class NoShiftPinner implements MediaTimePinner {
  const NoShiftPinner();

  @override
  Future<MediaAutomaticTime?> automaticTimeFor(MediaItem item) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

/// Pumps [MediaInfoPanel] for [item].
Future<void> pumpInfoPanel(
  WidgetTester tester,
  MediaItem item, {
  required MediaServingRecorder recorder,
  bool attached = true,
  QueueFacts? queue,
  MediaStoreIdentity? identity,
  String thisDevice = 'device-here',
  Stream<Map<String, String>>? peerNames,
  List<dynamic> extra = const [],

  /// Single-element holder so a test can swap the stored row mid-flight,
  /// which is what a persisted action really does.
  List<MediaItem>? liveRow,
  bool readOnly = false,
  EditSession<PhotoRecord>? sitting,

  /// How the stored row is read, in place of answering [item] (or
  /// [liveRow]): a read that has not answered, or a row that is not there.
  Future<MediaItem?> Function()? readRow,
}) async {
  // Four stacked sections overflow a default 800x600 surface, and a
  // ListView does not build what is below the fold, so the Serving block
  // would simply not exist for the finders. A taller viewport is cheaper
  // and less brittle than scrolling to each assertion.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaStoreAttachedProvider.overrideWith((ref) async => attached),
        mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(queue)),
        mediaStoreIdentityProvider.overrideWith((ref) async => identity),
        currentDeviceIdProvider.overrideWith((ref) async => thisDevice),
        peerDeviceNamesProvider.overrideWith(
          (ref) => peerNames ?? Stream.value(const {}),
        ),
        mediaServingRecorderProvider.overrideWithValue(recorder),
        // UnitFormatter reads the diver's date and time preferences, and
        // the real notifier wants SharedPreferences.
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        // The panel re-reads the row so persisted actions show up; without
        // an override this would reach for an uninitialised database.
        mediaByIdProvider.overrideWith(
          (ref, id) =>
              readRow?.call() ??
              Future.value(liveRow == null ? item : liveRow.first),
        ),
        ...extra.cast(),
      ],
      child: localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: MediaInfoPanel(
            item: item,
            readOnly: readOnly,
            sitting: sitting,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
