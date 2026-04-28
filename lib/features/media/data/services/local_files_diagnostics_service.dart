import 'dart:io';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Aggregated counts shown in Settings → Media Sources → Local files.
///
/// Counts are derived from the persisted [MediaItem.isOrphaned] flag, which
/// is updated either at link time or by [LocalFilesDiagnosticsService.reverifyAll].
class LocalFilesDiagnostics extends Equatable {
  final int total;
  final int available;
  final int unavailable;

  const LocalFilesDiagnostics({
    required this.total,
    required this.available,
    required this.unavailable,
  });

  @override
  List<Object?> get props => [total, available, unavailable];
}

/// Diagnostics service backing the Settings → Media Sources → Local files
/// subsection. Provides cheap read-only counts and an explicit re-verify
/// action.
///
/// Read path ([diagnose]) reads the persisted [MediaItem.isOrphaned] flag
/// and never touches the filesystem. Write path ([reverifyAll]) walks every
/// local-file row, calls the resolver, updates the orphan flag, and bumps
/// `lastVerifiedAt` for every row.
class LocalFilesDiagnosticsService {
  final MediaRepository _repository;
  final LocalFileResolver _resolver;
  final LocalMediaPlatform _platform;
  final _log = LoggerService.forClass(LocalFilesDiagnosticsService);

  LocalFilesDiagnosticsService({
    required MediaRepository repository,
    required LocalFileResolver resolver,
    required LocalMediaPlatform platform,
  }) : _repository = repository,
       _resolver = resolver,
       _platform = platform;

  /// Returns aggregated counts of local-file media items.
  ///
  /// Counts are based on the persisted `isOrphaned` flag — last set during
  /// link or by [reverifyAll]. Cheap to call repeatedly. To force a fresh
  /// check, the user invokes [reverifyAll] from the Settings UI, which
  /// updates the flag and bumps `lastVerifiedAt`.
  Future<LocalFilesDiagnostics> diagnose() async {
    final all = await _repository.getAllBySourceType(MediaSourceType.localFile);
    int available = 0;
    int unavailable = 0;
    for (final item in all) {
      if (item.isOrphaned) {
        unavailable++;
      } else {
        available++;
      }
    }
    return LocalFilesDiagnostics(
      total: all.length,
      available: available,
      unavailable: unavailable,
    );
  }

  /// Re-runs [LocalFileResolver.verify] against every local-file media item
  /// and updates the orphan flag plus `lastVerifiedAt`.
  ///
  /// Always writes `lastVerifiedAt` for every row so the displayed timestamps
  /// reflect a fresh check. Returns the number of items whose orphan status
  /// changed (used for the snackbar count). The N-write cost (1 UPDATE per
  /// item even when nothing changed) is acceptable for libraries up to a
  /// few thousand items; can be optimized in a follow-up if it ever
  /// becomes a perf concern.
  Future<int> reverifyAll() async {
    _log.info('Starting Re-verify all (local files)');
    final all = await _repository.getAllBySourceType(MediaSourceType.localFile);
    final now = DateTime.now();
    int flipped = 0;
    for (final item in all) {
      final result = await _resolver.verify(item);
      final isOrphan = result != VerifyResult.available;
      if (item.isOrphaned != isOrphan) flipped++;
      await _repository.updateMedia(
        item.copyWith(isOrphaned: isOrphan, lastVerifiedAt: now),
      );
    }
    _log.info(
      'Re-verify all complete: ${all.length} verified, $flipped flipped',
    );
    return flipped;
  }

  /// Returns the number of persistable URI permissions Android currently
  /// holds for this app. Android caps this at 128 per app — the Settings
  /// page surfaces this as a budget gauge.
  ///
  /// Returns 0 on every non-Android platform: the platform-channel call is
  /// a no-op there, so this short-circuit avoids a meaningless mock-stub
  /// trip in tests.
  Future<int> androidUriUsage() async {
    if (!Platform.isAndroid) return 0;
    final uris = await _platform.listPersistedUris();
    return uris.length;
  }
}
