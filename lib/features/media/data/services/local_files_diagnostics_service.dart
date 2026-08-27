import 'dart:io';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/media_verification_sweep.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

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
/// subsection. Cheap read-only counts, and nothing else.
///
/// [diagnose] reads the persisted [MediaItem.isOrphaned] flag and never
/// touches the filesystem. Re-verification deliberately does NOT live here:
/// it is [MediaVerificationSweep], which the Settings page calls directly.
///
/// That separation is load-bearing. Injecting the sweep here would put the
/// whole resolver registry on the dependency path of a page that only wants
/// two integers, so merely rendering the counts would construct every
/// resolver in the app.
class LocalFilesDiagnosticsService {
  final MediaRepository _repository;
  final LocalMediaPlatform _platform;

  LocalFilesDiagnosticsService({
    required MediaRepository repository,
    required LocalMediaPlatform platform,
  }) : _repository = repository,
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

  /// Returns the number of persistable URI permissions Android currently
  /// holds for this app. Android caps this at 128 per app — the Settings
  /// page surfaces this as a budget gauge.
  ///
  /// Returns 0 on every non-Android platform: the platform-channel call is
  /// a no-op there, so this short-circuit avoids a meaningless mock-stub
  /// trip in tests.
  Future<int> androidUriUsage() async {
    if (!Platform.isAndroid) return 0;
    // coverage:ignore-start
    // Android-only branch; test suite runs on macOS where the early-return
    // above prevents the platform mock from being consulted regardless of
    // stub setup.
    final uris = await _platform.listPersistedUris();
    return uris.length;
    // coverage:ignore-end
  }
}
