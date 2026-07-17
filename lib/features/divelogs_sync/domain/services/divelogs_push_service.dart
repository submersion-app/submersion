import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divelogs_sync/data/mappers/divelogs_export_mapper.dart';

class DivelogsPushResult {
  final int pushed;
  final int skippedUnmappable;
  final String? error;

  const DivelogsPushResult({
    required this.pushed,
    required this.skippedUnmappable,
    this.error,
  });

  bool get failed => error != null;
}

/// Create-only bulk push. A failure stops the run and reports partial
/// progress; no rollback is needed because the next compare simply matches
/// whatever was already created (stateless model, spec: push path).
class DivelogsPushService {
  DivelogsPushService({
    required DivelogsApiClient api,
    this.mapper = const DivelogsExportMapper(),
    this.chunkSize = 50,
    Future<void> Function(Duration)? delay,
  }) : _api = api,
       _delay = delay ?? Future.delayed;

  final DivelogsApiClient _api;
  final DivelogsExportMapper mapper;
  final int chunkSize;
  final Future<void> Function(Duration) _delay;

  static const Duration _interChunkDelay = Duration(milliseconds: 200);

  Future<DivelogsPushResult> push(
    List<Dive> dives, {
    void Function(int done, int total)? onProgress,
    Map<String, String> remoteGearIdByName = const {},
  }) async {
    final mapped = <Map<String, dynamic>>[];
    var skipped = 0;
    for (final dive in dives) {
      final json = mapper.mapDive(dive, remoteGearIdByName: remoteGearIdByName);
      if (json == null) {
        skipped++;
      } else {
        mapped.add(json);
      }
    }

    var pushed = 0;
    for (var start = 0; start < mapped.length; start += chunkSize) {
      if (start > 0) await _delay(_interChunkDelay);
      final chunk = mapped.sublist(
        start,
        start + chunkSize > mapped.length ? mapped.length : start + chunkSize,
      );
      try {
        await _api.postDives(chunk);
      } on DivelogsApiException catch (e) {
        return DivelogsPushResult(
          pushed: pushed,
          skippedUnmappable: skipped,
          error: e.message,
        );
      }
      pushed += chunk.length;
      onProgress?.call(pushed, mapped.length);
    }
    return DivelogsPushResult(pushed: pushed, skippedUnmappable: skipped);
  }
}
