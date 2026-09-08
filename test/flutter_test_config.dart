import 'dart:async';

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';

/// Global test harness config (run once per test file by `flutter test`).
///
/// The Dives data-quality scan scheduler is fire-and-forget: import, save,
/// consolidation and repair flows call `scheduleQualityScan(...)`, which runs
/// a real scan against `DatabaseService.instance.database`. In widget/adapter
/// tests that is unwanted work that can leave pending async operations. Disable
/// it by default here; tests that specifically exercise the scheduler
/// (e.g. quality_scan_service_test) opt back in with
/// `QualityScanScheduler.enabled = true`.
///
/// `canShareFiles` reads the host platform, and it is false on Linux because
/// share_plus cannot put files on the sheet there. Left alone, every test that
/// runs an export would take the save-dialog fallback on a Linux machine and
/// the share sheet everywhere else -- the same suite passing or failing on the
/// developer's OS. Pin it to the share sheet, which is what those tests assert
/// against, and let share_file_fallback_test opt out for the other branch.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  QualityScanScheduler.enabled = false;
  debugCanShareFiles = true;
  await testMain();
}
