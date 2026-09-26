import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';

const _log = LoggerService('SyncTempSweep');

/// How recently a sync temp file must have been touched to be spared as
/// "probably still being written" rather than swept as a leftover. Mirrors
/// `ResumableBasePublishStore._orphanGrace`, for the same reason.
const Duration syncTempFileGrace = Duration(minutes: 5);

/// Best-effort sweep of leftover streaming-sync temp files (base exports
/// `ssv1_base_*.json`, assembled peer bases `ssv1_<peer>_*` and adopt parts
/// `ssv1_adopt_*`) from the app temp dir. Every sync temp file is prefixed
/// `ssv1_`, so the sweep matches ONLY that prefix -- never an unrelated app
/// temp file (the dir is a shared, general-purpose temp location). Failure is
/// logged and ignored; a stale temp file is harmless.
///
/// Each normal sync path deletes its own file, so a leftover is what an
/// interrupted sync (app terminated, background work suspended, crash) leaves
/// behind: a full copy of the library's data. Runs at every launch from the
/// startup page and again from Repair sync (issue #1931). It needs no sync
/// service or provider, because a device that has since signed out of sync can
/// still hold leftovers.
///
/// Skips anything touched within [syncTempFileGrace]. The prefix keeps the
/// sweep off files this app did not write, but NOT off files another sync is
/// writing right now: a background-isolate sync can be mid-export while the
/// foreground app launches, and under `flutter test` [resolveSyncTempDir]
/// falls back to the machine-wide `Directory.systemTemp`, so every concurrent
/// test process shares one directory and a base export in flight in one of
/// them sits next to this sweep running in another. Deleting it fails that
/// publish, which surfaces as a sync returning non-success in a test file that
/// touched no sync code at all. The uuid in each name prevents collisions but
/// cannot help here, because the sweep matches on prefix rather than on a name
/// it chose. A leftover worth reaping is by definition from a run that already
/// ended, so it is old; a true orphan younger than the grace is simply
/// reclaimed by the next sweep.
///
/// [tempDir] is injectable so tests can sweep a private directory instead of
/// the shared one -- otherwise a test would be the very hazard it covers.
Future<void> sweepLeftoverSyncTempFiles({
  @visibleForTesting Future<Directory> Function()? tempDir,
}) async {
  try {
    final dir = await (tempDir?.call() ?? resolveSyncTempDir());
    final cutoff = DateTime.now().subtract(syncTempFileGrace);
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!p.basename(entity.path).startsWith('ssv1_')) continue;
      try {
        // Inside the try: the file can vanish between the listing and the
        // stat, which is exactly what a concurrent sweep looks like.
        if ((await entity.lastModified()).isAfter(cutoff)) continue;
        await entity.delete();
      } catch (_) {
        // best effort
      }
    }
  } catch (e) {
    _log.warning('Could not sweep leftover sync temp files: $e');
  }
}
