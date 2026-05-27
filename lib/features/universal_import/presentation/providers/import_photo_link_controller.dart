import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/local_media_linker.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

/// Outcome counts of a photo-linking run.
class PhotoLinkSummary {
  final int total;
  final int linked;
  final int notFound;
  final int skippedNonImage;

  const PhotoLinkSummary({
    required this.total,
    required this.linked,
    required this.notFound,
    required this.skippedNonImage,
  });
}

/// Immutable state for the post-import photo-linking flow.
class ImportPhotoLinkState {
  final int refCount;
  final bool isRunning;
  final int processed;
  final int total;
  final PhotoLinkSummary? summary;
  final String? errorMessage;

  const ImportPhotoLinkState({
    this.refCount = 0,
    this.isRunning = false,
    this.processed = 0,
    this.total = 0,
    this.summary,
    this.errorMessage,
  });

  ImportPhotoLinkState copyWith({
    int? refCount,
    bool? isRunning,
    int? processed,
    int? total,
    PhotoLinkSummary? summary,
    bool clearSummary = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ImportPhotoLinkState(
      refCount: refCount ?? this.refCount,
      isRunning: isRunning ?? this.isRunning,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      summary: clearSummary ? null : (summary ?? this.summary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Orchestrates the post-import photo-linking flow (Approach B, session-
/// only). Holds the parsed [ImportImageRef]s + the combined
/// sourceUuid -> diveId map; on each folder pick it scans once, resolves,
/// dedupes by (diveId + basename), links via [LocalMediaLinker], isolates
/// per-photo failures, and emits a [PhotoLinkSummary]. Re-picking another
/// folder is safe because linking is idempotent by basename.
class ImportPhotoLinkController extends StateNotifier<ImportPhotoLinkState> {
  ImportPhotoLinkController({
    required DirectoryScanner Function(GrantedFolder folder) scannerFor,
    required LocalMediaLinker linker,
    required Future<MediaSourceMetadata> Function(ScannedFile file) metadataFor,
    required Future<Set<String>> Function(String diveId) alreadyLinkedBasenames,
    required DateTime Function(ImportImageRef ref) fallbackTakenAtFor,
  }) : _scannerFor = scannerFor,
       _linker = linker,
       _metadataFor = metadataFor,
       _alreadyLinkedBasenames = alreadyLinkedBasenames,
       _fallbackTakenAtFor = fallbackTakenAtFor,
       super(const ImportPhotoLinkState());

  final DirectoryScanner Function(GrantedFolder) _scannerFor;
  final LocalMediaLinker _linker;
  final Future<MediaSourceMetadata> Function(ScannedFile) _metadataFor;
  final Future<Set<String>> Function(String diveId) _alreadyLinkedBasenames;
  final DateTime Function(ImportImageRef) _fallbackTakenAtFor;

  final _log = LoggerService.forClass(ImportPhotoLinkController);

  List<ImportImageRef> _imageRefs = const [];
  Map<String, String> _sourceUuidToDiveId = const {};

  /// Seed the session data. Call once after import completes.
  void seed({
    required List<ImportImageRef> imageRefs,
    required Map<String, String> sourceUuidToDiveId,
  }) {
    _imageRefs = imageRefs;
    _sourceUuidToDiveId = sourceUuidToDiveId;
    state = state.copyWith(refCount: imageRefs.length, clearSummary: true);
  }

  /// Run scan -> resolve -> link against [folder]. Best-effort; never throws.
  Future<void> pickedFolder(GrantedFolder folder) async {
    if (_imageRefs.isEmpty) return;
    state = state.copyWith(
      isRunning: true,
      processed: 0,
      total: _imageRefs.length,
      clearSummary: true,
      clearError: true,
    );

    try {
      final scanner = _scannerFor(folder);
      final resolver = PhotoResolver(scanner: scanner, folder: folder);
      final resolved = await resolver.resolveAll(_imageRefs);

      var linked = 0;
      var notFound = 0;
      var skipped = 0;
      // Track basenames linked this run so two refs to the same file under
      // one dive don't double-link within a single pass.
      final linkedThisRun = <String, Set<String>>{};

      for (var i = 0; i < resolved.length; i++) {
        final r = resolved[i];
        switch (r.kind) {
          case PhotoResolutionKind.skippedNonImage:
            skipped++;
            break;
          case PhotoResolutionKind.miss:
            notFound++;
            break;
          case PhotoResolutionKind.rebased:
          case PhotoResolutionKind.filenameMatch:
            final diveId = _sourceUuidToDiveId[r.ref.diveSourceUuid];
            if (diveId == null) {
              notFound++;
              break;
            }
            final basename = r.scannedFile!.basename;
            final already = await _alreadyLinkedBasenames(diveId);
            final run = linkedThisRun.putIfAbsent(diveId, () => <String>{});
            if (already.contains(basename) || run.contains(basename)) {
              // Already linked (persisted or this run) -- count as linked.
              linked++;
              run.add(basename);
              break;
            }
            try {
              final metadata = await _metadataFor(r.scannedFile!);
              await _linker.link(
                diveId: diveId,
                handle: r.scannedFile!.handle,
                basename: basename,
                metadata: metadata,
                fallbackTakenAt: _fallbackTakenAtFor(r.ref),
                caption: r.ref.caption,
              );
              linked++;
              run.add(basename);
            } catch (e, st) {
              _log.error(
                'Failed to link photo: $basename',
                error: e,
                stackTrace: st,
              );
              notFound++;
            }
            break;
        }
        state = state.copyWith(processed: i + 1);
      }

      state = state.copyWith(
        isRunning: false,
        summary: PhotoLinkSummary(
          total: resolved.length,
          linked: linked,
          notFound: notFound,
          skippedNonImage: skipped,
        ),
      );
    } catch (e, st) {
      _log.error('Photo-linking run failed', error: e, stackTrace: st);
      state = state.copyWith(
        isRunning: false,
        processed: 0,
        total: 0,
        errorMessage: 'Could not scan that folder.', // TODO(media): l10n
      );
    }
  }
}
