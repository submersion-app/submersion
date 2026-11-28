import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/scratch/scratch_session.dart';
import 'package:submersion/features/media/presentation/camera/identify_camera_page.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_file_handle_factory.dart';
import 'package:submersion/features/media/data/services/scratch_keeper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/pages/viewer_scratch.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/keep_sheet.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/scratch/scratch_scope.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_download_prompt.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(IdentifyViewerPage);

/// The diver refused the app access to add a camera capture to the photo
/// library, where a kept capture lives.
class _PhotoAccessDenied implements Exception {
  const _PhotoAccessDenied();
}

/// A file picked for identifying, as the session shows it (issue #5122).
/// [metadata] is what the file says of itself; [modified] stands in for a
/// capture time it does not have.
MediaItem scratchItemFromFile(
  String path,
  MediaSourceMetadata metadata, {
  required DateTime modified,
}) {
  final now = DateTime.now();
  return MediaItem(
    id: ScratchSession.newId(),
    mediaType: _isVideo(path, metadata.mimeType)
        ? MediaType.video
        : MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: path,
    localPath: path,
    originalFilename: p.basename(path),
    takenAt: metadata.takenAt ?? modified,
    latitude: metadata.latitude,
    longitude: metadata.longitude,
    width: metadata.width,
    height: metadata.height,
    durationSeconds: metadata.durationSeconds,
    createdAt: now,
    updatedAt: now,
  );
}

/// Whether the file at [path] is a video: by its type, or by its extension
/// when the extractor could not read the type.
bool _isVideo(String path, String mimeType) {
  if (mimeType.startsWith('video/')) return true;
  if (mimeType.startsWith('image/')) return false;
  const videos = {'.mp4', '.mov', '.m4v', '.avi', '.mkv', '.3gp', '.mts'};
  return videos.contains(p.extension(path).toLowerCase());
}

/// Picks photos and videos to identify, with what each file says of when
/// and where it was taken. Empty when the diver backs out.
Future<List<MediaItem>> pickIdentifyItems(WidgetRef ref) async {
  // coverage:ignore-start
  // The OS picker cannot run in a test; what follows it is
  // [scratchItemFromFile], tested on its own.
  final picked = await FilePicker.pickFiles(type: FileType.media);
  final extractor = ref.read(exifExtractorProvider);
  return [
    for (final file in picked)
      if (file.path case final path?)
        await identifyItemFromPick(extractor, path),
  ];
  // coverage:ignore-end
}

/// The file at [path] as a scratch item. A file whose metadata or date
/// cannot be read opens without them, rather than stopping the whole pick.
Future<MediaItem> identifyItemFromPick(
  ExifExtractor extractor,
  String path,
) async {
  const unread = MediaSourceMetadata(mimeType: 'application/octet-stream');
  MediaSourceMetadata metadata;
  try {
    metadata = await extractor.extract(File(path)) ?? unread;
  } on Object catch (error) {
    _log.warning('Could not read the metadata of a picked file', error: error);
    metadata = unread;
  }
  DateTime modified;
  try {
    modified = await File(path).lastModified();
  } on Object {
    modified = DateTime.now();
  }
  return scratchItemFromFile(path, metadata, modified: modified);
}

/// The Media section's Identify (issue #5122): with no species pack
/// installed, the offer to download one; otherwise files picked from disk,
/// in the Identify viewer.
Future<void> launchIdentify(BuildContext context, WidgetRef ref) async {
  // Keeping a file is an import, which demo mode seals.
  if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) return;
  final installed = await ref.read(installedSpeciesPackProvider.future);
  if (!context.mounted) return;
  if (installed == null) {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: SpeciesDownloadPrompt(),
      ),
    );
    return;
  }
  // Phones and tablets open the camera, which can pick files too.
  if (identifyOpensCamera()) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const IdentifyCameraPage()));
    return;
  }
  final items = await pickIdentifyItems(ref);
  if (!context.mounted) return;
  await openIdentifyViewer(context, items);
}

/// Whether Identify opens the camera here: on phones and tablets.
bool identifyOpensCamera() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Opens the Identify viewer on [items] (issue #5122). [captures] are the
/// ids of camera captures: kept ones go to the photo library first.
/// Returns the ids kept, so a caller showing the same files again does not
/// offer to keep them twice.
Future<Set<String>> openIdentifyViewer(
  BuildContext context,
  List<MediaItem> items, {
  Set<String> captures = const {},
}) async {
  if (items.isEmpty) return const {};
  final session = await ScratchSession.open(
    items: items,
    source: DatabaseService.instance.database,
  );
  if (!context.mounted) {
    await session.dispose();
    return const {};
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => IdentifyViewerPage(session: session, captures: captures),
    ),
  );
  return session.keptIds;
}

/// The media viewer over a [ScratchSession]: species identification runs
/// on the session, and Keep copies a file into the logbook. Closes the
/// session when it goes.
class IdentifyViewerPage extends ConsumerStatefulWidget {
  const IdentifyViewerPage({
    super.key,
    required this.session,
    this.captures = const {},
  });

  final ScratchSession session;
  final Set<String> captures;

  @override
  ConsumerState<IdentifyViewerPage> createState() => _IdentifyViewerPageState();
}

class _IdentifyViewerPageState extends ConsumerState<IdentifyViewerPage> {
  /// Each capture saved to the photo library, as linked there: a keep
  /// retried after a later step failed links it again, never saves twice.
  Map<String, MediaItem> _savedCaptures = const {};

  /// The overrides over the session, built once: its service shares the
  /// logbook service's loaded pack rather than load a second copy.
  late final _overrides = scratchOverrides(
    widget.session,
    sharedPack: ref.read(mediaIdentificationServiceProvider).loadedPack,
  );

  @override
  void dispose() {
    // The viewer below, and the scope over the session, are gone first.
    unawaited(widget.session.dispose());
    super.dispose();
  }

  /// The keeper over the diver's logbook. This page's `ref` is outside the
  /// session's scope, so every provider here is the logbook's.
  ScratchKeeper _keeper() => ScratchKeeper(
    session: widget.session,
    media: ref.read(mediaRepositoryProvider),
    identifications: ref.read(mediaIdentificationRepositoryProvider),
    embeddings: ref.read(identificationEmbeddingRepositoryProvider),
    crops: ref.read(identificationCropStoreProvider),
    species: ref.read(speciesRepositoryProvider),
    tagging: ref.read(speciesTaggingServiceProvider),
    linkFile: _linkFile,
    // Uploaded to the media store as any imported file is.
    onMediaCreated: ref.read(mediaStoreEnqueueProvider),
    // As an import would: confident names are tagged if the diver has
    // that on.
    afterKeep: (kept) => ref
        .read(autoApplierProvider)
        .applyInScope(
          kept.id,
          isVideo: kept.isVideo,
          generation: DatabaseService.instance.generation,
        )
        .then((_) {}),
  );

  /// The file as the logbook keeps it: a camera capture saved to the photo
  /// library and linked there (the app never keeps media itself), a file
  /// on disk linked by path or bookmark.
  Future<MediaItem> _linkFile(MediaItem item) async {
    final path = item.localPath;
    if (item.platformAssetId != null) return item;
    if (path == null || !File(path).existsSync()) {
      throw ScratchFileGone(item.originalFilename ?? item.id);
    }
    if (widget.captures.contains(item.id)) {
      if (_savedCaptures[item.id] case final saved?) return saved;
      // coverage:ignore-start
      // Saving to the photo library needs a device.
      await _ensureCanSaveCaptures();
      final asset = item.isVideo
          ? await PhotoManager.editor.saveVideo(File(path))
          : await PhotoManager.editor.saveImageWithPath(path);
      final saved = item.copyWith(
        platformAssetId: asset.id,
        sourceType: MediaSourceType.platformGallery,
        localPath: null,
        filePath: '',
      );
      _savedCaptures = {..._savedCaptures, item.id: saved};
      return saved;
      // coverage:ignore-end
    }
    final handle = await LocalFileHandleFactory(
      platform: ref.read(localMediaPlatformProvider),
      bookmarkStorage: ref.read(localBookmarkStorageProvider),
    ).create(path);
    return item.copyWith(
      localPath: handle.localPath,
      bookmarkRef: handle.bookmarkRef,
    );
  }

  /// Access to add to the photo library, asked for where the system needs
  /// it to save: iOS. Android saves without asking from Android 10.
  // coverage:ignore-start
  Future<void> _ensureCanSaveCaptures() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.addOnly,
      ),
    );
    if (!state.hasAccess) throw const _PhotoAccessDenied();
  }
  // coverage:ignore-end

  Future<Set<String>> _keep(
    BuildContext context,
    MediaItem current,
    ScratchTags tags,
  ) async {
    final session = widget.session;
    final unkept = [
      for (final item in session.items)
        if (!session.isKept(item.id)) item.id,
    ];
    final choice = await showKeepSheet(context, unkeptCount: unkept.length);
    if (choice == null || !context.mounted) return const {};
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await _keeper().keep(
      choice.all ? unkept : [current.id],
      choice.target,
      tags,
    );
    // Refused photo access is said once, with where to allow it.
    if (result.failures.values.any((e) => e is _PhotoAccessDenied)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.media_photoPicker_permissionDeniedMessage)),
      );
    }
    for (final MapEntry(key: id, value: error) in result.failures.entries) {
      if (error is _PhotoAccessDenied) continue;
      final name = session.items
          .where((i) => i.id == id)
          .map((i) => i.originalFilename ?? '')
          .firstOrNull;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.media_identify_keepFailed(name ?? ''))),
      );
    }
    return result.keptIds.keys.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.session.items;
    return ProviderScope(
      overrides: _overrides,
      child: MediaViewerPage(
        mediaList: items,
        initialMediaId: items.first.id,
        scratch: ViewerScratch(onKeep: _keep),
      ),
    );
  }
}
