import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher.dart';

final _log = LoggerService.forClass(BasePartHasher);

/// [openBasePartHasher] for production callers, which log the fallback. Lives
/// apart from it to keep the hasher itself free of Flutter imports.
Future<BasePartHasher> openLoggedBasePartHasher(int firstPartBytes) =>
    openBasePartHasher(
      firstPartBytes,
      onWorkerUnavailable: (error) => _log.warning(
        'Base checksum worker unavailable; hashing on this isolate',
        error: error,
      ),
    );
