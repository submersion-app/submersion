import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

/// The state every test file starts from.
///
/// `test/flutter_test_config.dart` applies it once per entrypoint, and a
/// generated bundle applies it again before each file it runs, because the
/// files in a bundle share one isolate (issue #2500). A test that changes one
/// of these calls this in its `tearDown`, so the next test starts from the
/// same place whichever file it is in.
///
/// The data-quality scan scheduler is fire-and-forget: import, save,
/// consolidation and repair flows call `scheduleQualityScan(...)`, which runs
/// a real scan against `DatabaseService.instance.database`. In widget and
/// adapter tests that is unwanted work that can leave pending async
/// operations, so it is off unless a test turns it on. The sensor summary
/// scheduler is off for the same reason.
///
/// `canShareFiles` reads the host platform, and it is false on Linux because
/// share_plus cannot put files on the sheet there. Left alone, every test that
/// runs an export would take the save-dialog fallback on Linux and the share
/// sheet everywhere else. It is pinned to the share sheet, which is what those
/// tests assert against.
void applyGlobalTestDefaults() {
  QualityScanScheduler.enabled = false;
  SensorSummaryScheduler.enabled = false;
  debugCanShareFiles = true;
}
