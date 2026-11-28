import 'package:uuid/uuid.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/services/dive_media_clock.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_file_handle_factory.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';

/// State for the Files tab in the photo picker.
///
/// Holds the picked + EXIF-extracted files, the matcher's assignment of
/// each to a dive (or unmatched), the auto-match toggle preference, and
/// extraction progress for the UI's progress indicator.
class FilesTabState extends Equatable {
  final List<ExtractedFile> files;
  final bool autoMatchByDate;
  final bool isExtracting;
  final int extractedCount;
  final int totalToExtract;
  final MatchedSelection match;

  /// A correction added to every staged file's capture time before matching
  /// and before persisting.
  ///
  /// Scoped to one picking session. Cleared by [FilesTabNotifier.clearStagedFiles]
  /// along with the files themselves: the notifier is not autoDispose, so an
  /// offset left set would silently follow the user into their next import.
  final Duration captureTimeOffset;

  /// The staged paths a folder scan found, rather than the user picking or
  /// dropping each one.
  ///
  /// Picked on a dive, a file the matcher could not place is that dive's
  /// (issue #5063). A folder scan chose no file for the dive, so what it
  /// could not place stays out unless the user assigns it. Kept per path,
  /// since one drop can hold a folder and loose files.
  final Set<String> folderPaths;

  /// Where the files the matcher found no dive for go, in a session with no
  /// owner (issue #5122): all on one site ([SiteAttachTarget]), or kept with
  /// no place ([UnplacedAttachTarget]). Null skips them, as before.
  final MediaAttachTarget? unmatchedTarget;

  const FilesTabState({
    required this.files,
    required this.autoMatchByDate,
    required this.isExtracting,
    required this.extractedCount,
    required this.totalToExtract,
    required this.match,
    required this.captureTimeOffset,
    this.unmatchedTarget,
    this.folderPaths = const {},
  });

  factory FilesTabState.initial() => FilesTabState(
    files: const [],
    autoMatchByDate: true,
    isExtracting: false,
    extractedCount: 0,
    totalToExtract: 0,
    match: MatchedSelection.empty(),
    captureTimeOffset: Duration.zero,
  );

  FilesTabState copyWith({
    List<ExtractedFile>? files,
    bool? autoMatchByDate,
    bool? isExtracting,
    int? extractedCount,
    int? totalToExtract,
    MatchedSelection? match,
    Duration? captureTimeOffset,
    Object? unmatchedTarget = _keepUnmatchedTarget,
    Set<String>? folderPaths,
  }) => FilesTabState(
    files: files ?? this.files,
    autoMatchByDate: autoMatchByDate ?? this.autoMatchByDate,
    isExtracting: isExtracting ?? this.isExtracting,
    extractedCount: extractedCount ?? this.extractedCount,
    totalToExtract: totalToExtract ?? this.totalToExtract,
    match: match ?? this.match,
    captureTimeOffset: captureTimeOffset ?? this.captureTimeOffset,
    folderPaths: folderPaths ?? this.folderPaths,
    unmatchedTarget: identical(unmatchedTarget, _keepUnmatchedTarget)
        ? this.unmatchedTarget
        : unmatchedTarget as MediaAttachTarget?,
  );

  static const Object _keepUnmatchedTarget = Object();

  /// The unmatched files a commit on a dive takes to that dive: every one
  /// the user picked rather than a folder scan found.
  List<ExtractedFile> get unmatchedForTarget => [
    for (final file in match.unmatched)
      if (!folderPaths.contains(file.sourcePath)) file,
  ];

  @override
  List<Object?> get props => [
    files,
    autoMatchByDate,
    isExtracting,
    extractedCount,
    totalToExtract,
    match,
    captureTimeOffset,
    unmatchedTarget,
    folderPaths,
  ];
}

/// Notifier for the Files tab.
///
/// Phase 2 actions: [toggleAutoMatch], [clear], [setFiles],
/// [setExtractionProgress], [removeFile], [commit], [undoCommit].
///
/// [commit] persists each staged [ExtractedFile] as a [MediaItem] row via
/// [MediaRepository.createMedia]: walking the matcher's per-dive assignment
/// for a dive session, or the flat file list for a site one (see [commit]).
/// The row's pointer to the file (`localPath` and, on iOS / macOS, a
/// security-scoped `bookmarkRef`) comes from [LocalFileHandleFactory],
/// which the import wizard's photo attachment shares so both paths store a
/// file exactly the same way.
///
/// In a dive session, hand-picked files the matcher could not place go to the
/// session's dive (issue #5063); a folder scan's, and any with no target, are
/// skipped, and the review pane's assign actions are what move them into a
/// dive group. A site session has no unmatched bucket to skip; every staged
/// file belongs to the site.
///
/// [undoCommit] takes the list of IDs returned by [commit] and deletes
/// each row. The keychain bookmark blob (if any) is intentionally left
/// orphaned per the Phase 2 spec — without it nothing references the
/// blob, and a future maintenance pass can sweep them.
class FilesTabNotifier extends StateNotifier<FilesTabState> {
  FilesTabNotifier({
    required this.mediaRepository,
    required this.bookmarkStorage,
    required this.platform,
    this.onMediaCreated,
    this.deletionCoordinator,
  }) : super(FilesTabState.initial());

  final MediaRepository mediaRepository;

  /// Routes undo deletions through the orphan-prevention fast path when
  /// wired (production); direct-construction tests fall back to the
  /// repository.
  final MediaDeletionCoordinator? deletionCoordinator;
  final LocalBookmarkStorage bookmarkStorage;
  final LocalMediaPlatform platform;

  /// Shared by every file this notifier persists: the factory holds only
  /// its dependencies and the platform's handle policy, so one instance
  /// keeps that policy in a single place.
  late final LocalFileHandleFactory _handles = LocalFileHandleFactory(
    platform: platform,
    bookmarkStorage: bookmarkStorage,
  );

  /// Invoked after every successful createMedia so the media store can
  /// enqueue an upload. Null when no store is configured. Mirrors
  /// [MediaImportService.onMediaCreated]; without it, Files-tab imports
  /// never reach the transfer queue and silently stay local-only.
  final void Function(String mediaId)? onMediaCreated;

  void toggleAutoMatch() {
    state = state.copyWith(autoMatchByDate: !state.autoMatchByDate);
  }

  void clear() {
    state = FilesTabState.initial();
  }

  /// Drops the staged files and their grouping while keeping the user's
  /// auto-match preference.
  ///
  /// Called when the picker opens. The notifier is not autoDispose, so files
  /// picked and then abandoned (backing out without committing) outlive the
  /// session that picked them, and the next session may attach to a
  /// different dive, or to a site. Offering yesterday's leftovers as
  /// "attach these to this site" is wrong regardless of what the user then
  /// taps, so the staged set starts empty every time.
  void clearStagedFiles() {
    state = state.copyWith(
      files: const [],
      match: MatchedSelection.empty(),
      isExtracting: false,
      extractedCount: 0,
      totalToExtract: 0,
      captureTimeOffset: Duration.zero,
      folderPaths: const {},
    );
  }

  /// Stages [files] with their [match]; [folderPaths] names those a folder
  /// scan found (see [FilesTabState.folderPaths]).
  void setFiles(
    List<ExtractedFile> files, {
    required MatchedSelection match,
    Set<String> folderPaths = const {},
  }) {
    state = state.copyWith(
      files: files,
      match: match,
      folderPaths: folderPaths,
    );
  }

  /// Applies a new capture-time [offset] together with the [match] it produced.
  ///
  /// Both move in one state update so the review pane's summary count and the
  /// rendered groups can never disagree: a caller that set the offset first and
  /// the match second would publish an intermediate state showing the new
  /// offset against the old grouping.
  void setCaptureTimeOffset(
    Duration offset, {
    required MatchedSelection match,
  }) {
    state = state.copyWith(captureTimeOffset: offset, match: match);
  }

  void setExtractionProgress({required int done, required int total}) {
    state = state.copyWith(
      isExtracting: total > 0 && done < total,
      extractedCount: done,
      totalToExtract: total,
    );
  }

  void removeFile(String sourcePath) {
    final remainingFiles = state.files
        .where((f) => f.sourcePath != sourcePath)
        .toList();
    final newMatched = <String, List<ExtractedFile>>{};
    for (final entry in state.match.matched.entries) {
      final filtered = entry.value
          .where((f) => f.sourcePath != sourcePath)
          .toList();
      if (filtered.isNotEmpty) {
        newMatched[entry.key] = filtered;
      }
    }
    final newUnmatched = state.match.unmatched
        .where((f) => f.sourcePath != sourcePath)
        .toList();
    state = state.copyWith(
      files: remainingFiles,
      match: state.match.copyWith(matched: newMatched, unmatched: newUnmatched),
    );
  }

  /// Routes the staged file at [sourcePath] to [diveId], removing it from
  /// whichever bucket currently holds it (unmatched, or another dive).
  ///
  /// With no target, [commit] only persists files sitting in
  /// [MatchedSelection.matched], so without this a file the date matcher
  /// rejected had no route into the database at all. It also moves a file
  /// between dives. Unknown paths are ignored.
  void assignToDive(String sourcePath, String diveId) {
    final file = state.files
        .where((f) => f.sourcePath == sourcePath)
        .firstOrNull;
    if (file == null) return;

    final newMatched = <String, List<ExtractedFile>>{};
    for (final entry in state.match.matched.entries) {
      final kept = entry.value
          .where((f) => f.sourcePath != sourcePath)
          .toList();
      // Drop emptied groups, mirroring [removeFile].
      if (kept.isNotEmpty) newMatched[entry.key] = kept;
    }
    newMatched.update(
      diveId,
      (existing) => [...existing, file],
      ifAbsent: () => [file],
    );

    state = state.copyWith(
      match: state.match.copyWith(
        matched: newMatched,
        unmatched: state.match.unmatched
            .where((f) => f.sourcePath != sourcePath)
            .toList(),
      ),
    );
  }

  /// Sends the unmatched files to [target] on commit, in a session with no
  /// owner (issue #5122): one site, or no place. Null skips them again.
  void setUnmatchedTarget(MediaAttachTarget? target) {
    state = state.copyWith(unmatchedTarget: target);
  }

  /// Routes every currently-unmatched file to [diveId]. Backs the review
  /// pane's bulk "add all to this dive" action.
  void assignAllUnmatched(String diveId) {
    final unmatched = state.match.unmatched;
    if (unmatched.isEmpty) return;

    final newMatched = {
      for (final entry in state.match.matched.entries)
        entry.key: [...entry.value],
    };
    newMatched.update(
      diveId,
      (existing) => [...existing, ...unmatched],
      ifAbsent: () => [...unmatched],
    );

    state = state.copyWith(
      match: state.match.copyWith(matched: newMatched, unmatched: const []),
    );
  }

  /// Persists the staged files as [MediaItem] rows and returns the list of
  /// created IDs. Pass the list back to [undoCommit] to roll back. State is
  /// reset via [clear] before returning.
  ///
  /// What gets persisted depends on [target]:
  ///
  /// - [SiteAttachTarget]: every file in [FilesTabState.files], each stamped
  ///   with the site id. The dive matcher's grouping is ignored outright:
  ///   `matched` is keyed by dive id and a site session has no dives to key
  ///   on, so honouring it would either persist nothing (the issue #1098
  ///   symptom) or scatter the user's photos across whatever dives their
  ///   timestamps happened to fall inside.
  /// - [DiveAttachTarget]: the matcher's per-dive assignment, which the
  ///   review pane lets the user correct first, and every unmatched file on
  ///   the target dive: the user picked it on that dive (issue #5063). A
  ///   folder scan's unmatched files are skipped (see
  ///   [FilesTabState.folderPaths]).
  /// - No target at all: the matcher's per-dive assignment. Unmatched files
  ///   are skipped, unless the pane sends them all to one site or keeps them
  ///   with no place ([FilesTabState.unmatchedTarget], issue #5122); the
  ///   pane's assign actions are the other way out of that bucket.
  /// - [UnplacedAttachTarget]: every file kept with no place.
  ///
  /// Both photos and videos are persisted; [_persistOne] tags each row with
  /// the right [MediaType] from its MIME. On desktop a local-file video
  /// resolves by localPath and plays via `VideoPlayerController.file`
  /// (see [FilesTab] class doc for the iOS caveat).
  Future<List<String>> commit({MediaAttachTarget? target}) async {
    final created = <String>[];
    switch (target) {
      case SiteAttachTarget(:final siteId):
        for (final file in state.files) {
          created.add(await _persistOne(file, siteId: siteId));
        }
      // Gear photos (issue #3355): owned outright, like a site's.
      case EquipmentAttachTarget(:final equipmentId, :final observationId):
        for (final file in state.files) {
          created.add(
            await _persistOne(
              file,
              equipmentId: equipmentId,
              observationId: observationId,
            ),
          );
        }
      case UnplacedAttachTarget():
        for (final file in state.files) {
          created.add(await _persistOne(file, unplaced: true));
        }
      case DiveAttachTarget(:final diveId):
        for (final entry in state.match.matched.entries) {
          for (final file in entry.value) {
            created.add(await _persistOne(file, diveId: entry.key));
          }
        }
        for (final file in state.unmatchedForTarget) {
          created.add(await _persistOne(file, diveId: diveId));
        }
      case null:
        for (final entry in state.match.matched.entries) {
          for (final file in entry.value) {
            created.add(await _persistOne(file, diveId: entry.key));
          }
        }
        // With no owner, the diver may send the unmatched files to one site
        // or keep them with no place (issue #5122).
        if (target == null) {
          for (final file in state.match.unmatched) {
            switch (state.unmatchedTarget) {
              case SiteAttachTarget(:final siteId):
                created.add(await _persistOne(file, siteId: siteId));
              case UnplacedAttachTarget():
                created.add(await _persistOne(file, unplaced: true));
              case DiveAttachTarget() || EquipmentAttachTarget() || null:
                break;
            }
          }
        }
    }
    clear();
    return created;
  }

  /// The rows [commit] would write for [diveId], each under a fresh id,
  /// built and not written, and how many staged files matched another dive
  /// and were left out: a sitting on [diveId] holds its own photos until
  /// Save, and changes no other dive (issue #4527). The files the matcher
  /// could not place are [diveId]'s too, since the user picked them on it
  /// (issue #5063), unless a folder scan found them. Clears the staged files.
  Future<({List<MediaItem> rows, int leftOut})> heldRows(String diveId) async {
    final rows = <MediaItem>[];
    var leftOut = 0;
    for (final entry in state.match.matched.entries) {
      if (entry.key != diveId) {
        leftOut += entry.value.length;
        continue;
      }
      for (final file in entry.value) {
        rows.add(await _itemFor(file, id: const Uuid().v4(), diveId: diveId));
      }
    }
    for (final file in state.unmatchedForTarget) {
      rows.add(await _itemFor(file, id: const Uuid().v4(), diveId: diveId));
    }
    clear();
    return (rows: rows, leftOut: leftOut);
  }

  /// The rows [commit] would write for the site [siteId]: every staged
  /// file, each under a fresh id, built and not written, for a sitting on
  /// the site that holds them until Save (issue #4527, phase 2). Clears the
  /// staged files.
  Future<List<MediaItem>> heldSiteRows(String siteId) async {
    final rows = <MediaItem>[
      for (final file in state.files)
        await _itemFor(file, id: const Uuid().v4(), siteId: siteId),
    ];
    clear();
    return rows;
  }

  /// The staged files as rows for gear item [equipmentId], and its check-in
  /// [observationId] when given, for a sitting on the item that holds them
  /// until Save (issue #4527, phase 3, plan 6): each under a fresh id of its
  /// own, none written. Clears the staging, as [commit] does.
  Future<List<MediaItem>> heldEquipmentRows(
    String equipmentId, {
    String? observationId,
  }) async {
    final rows = <MediaItem>[
      for (final file in state.files)
        await _itemFor(
          file,
          id: const Uuid().v4(),
          equipmentId: equipmentId,
          observationId: observationId,
        ),
    ];
    clear();
    return rows;
  }

  /// Reverses a prior [commit] by deleting each row by id. Bookmark blobs
  /// in the keychain are intentionally not cleaned up — see class doc.
  Future<void> undoCommit(List<String> ids) async {
    final coordinator = deletionCoordinator;
    if (coordinator != null) {
      await coordinator.deleteMultipleMedia(ids);
      return;
    }
    for (final id in ids) {
      await mediaRepository.deleteMedia(id);
    }
  }

  /// Writes one row. Exactly one of [diveId] / [siteId] is supplied by
  /// [commit]; the other stays null so the row belongs to one owner and does
  /// not surface in both a dive's grid and a site's. [unplaced] instead keeps
  /// the row with no owner at all, marked `retain_in_library` (issue #5122).
  Future<MediaItem> _itemFor(
    ExtractedFile file, {
    String id = '',
    String? diveId,
    String? siteId,
    String? equipmentId,
    String? observationId,
    bool unplaced = false,
  }) async {
    // Asserted, not just documented: neither mistake announces itself. Both
    // set puts the photo in a dive's grid and a site's; neither set writes an
    // ownerless row that shows up in no grid at all, which reads to the user
    // exactly like the import having silently failed.
    assert(
      [diveId, siteId, equipmentId].where((id) => id != null).length ==
          (unplaced ? 0 : 1),
      'a Files-tab row belongs to exactly one owner, or none when kept with '
      'no place, got diveId=$diveId siteId=$siteId equipmentId=$equipmentId '
      'unplaced=$unplaced',
    );
    // [ExtractedFile.file] is a dart:io File, so its path is always a
    // filesystem path; the factory decides per platform whether that path
    // is kept as-is or backed by a security-scoped bookmark.
    final handle = await _handles.create(file.file.path);

    final now = DateTime.now();
    return MediaItem(
      // Empty id triggers UUID generation in MediaRepository.createMedia.
      id: id,
      diveId: diveId,
      siteId: siteId,
      equipmentId: equipmentId,
      observationId: observationId,
      retainInLibrary: unplaced,
      mediaType: file.metadata.mimeType.startsWith('video/')
          ? MediaType.video
          : MediaType.photo,
      sourceType: MediaSourceType.localFile,
      // Recorded from the picker path, which is what "original" means here.
      // Without it StoreKeys.extensionFor falls back to 'bin', and a linked
      // video then uploads and caches under a name that tells AVFoundation
      // nothing about its container -- unplayable on every device except the
      // one holding the local file.
      originalFilename: p.basename(file.sourcePath),
      localPath: handle.localPath,
      bookmarkRef: handle.bookmarkRef,
      // The session offset is baked into the stored value, not merely used
      // for matching. EnrichmentService derives elapsed-since-entry from this
      // column to place the photo on the profile chart and derive its depth
      // badge; persisting an unshifted time for a file that only matched
      // because of the shift would give every such photo a large negative
      // elapsed, which resolves to the first profile sample's depth.
      takenAt: file.metadata.takenAt?.add(state.captureTimeOffset) ?? now,
      latitude: file.metadata.latitude,
      longitude: file.metadata.longitude,
      width: file.metadata.width,
      height: file.metadata.height,
      durationSeconds: file.metadata.durationSeconds,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Writes one row. Exactly one of [diveId] / [siteId] / [equipmentId] is
  /// supplied by [commit].
  Future<String> _persistOne(
    ExtractedFile file, {
    String? diveId,
    String? siteId,
    String? equipmentId,
    String? observationId,
    bool unplaced = false,
  }) async {
    final item = await _itemFor(
      file,
      diveId: diveId,
      siteId: siteId,
      equipmentId: equipmentId,
      observationId: observationId,
      unplaced: unplaced,
    );
    final saved = await mediaRepository.createMedia(item);
    onMediaCreated?.call(saved.id);
    return saved.id;
  }
}

/// The dive time windows the Files tab matches picked media against.
///
/// Kept separate from [filesTabNotifierProvider] so the review pane can re-run
/// [DivePhotoMatcher] with a new capture-time offset without sending the user
/// back through the OS file picker.
///
/// A dive with no recorded exit time gets one synthesised from its runtime, and
/// a dive with neither gets a one-hour window. That is deliberately generous:
/// [DivePhotoMatcher] adds a 30-minute pre-buffer and a 60-minute post-buffer
/// on top, and a window that is slightly too wide costs a correctable
/// mis-assignment, while one that is too narrow silently drops photos into the
/// unmatched bucket with nothing to explain it.
final diveBoundsProvider = FutureProvider<List<DiveBounds>>((ref) async {
  final dives = await ref.watch(divesProvider.future);
  return [
    for (final d in dives)
      // Each window is the dive's as its camera reads it, so a file is
      // matched on the clock it is later placed by (issue #4539).
      DiveBounds(
        diveId: d.id,
        entryTime: DiveMediaClock.onCameraClock(d, d.effectiveEntryTime),
        exitTime: DiveMediaClock.onCameraClock(
          d,
          d.exitTime ??
              d.effectiveEntryTime.add(
                d.effectiveRuntime ?? const Duration(hours: 1),
              ),
        ),
      ),
  ];
});

final filesTabNotifierProvider =
    StateNotifierProvider<FilesTabNotifier, FilesTabState>(
      (ref) => FilesTabNotifier(
        mediaRepository: ref.read(mediaRepositoryProvider),
        bookmarkStorage: ref.read(localBookmarkStorageProvider),
        platform: ref.read(localMediaPlatformProvider),
        onMediaCreated: ref.read(mediaStoreEnqueueProvider),
        deletionCoordinator: ref.read(mediaDeletionCoordinatorProvider),
      ),
    );
