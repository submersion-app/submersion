import 'dart:async';

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
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  QualityScanScheduler.enabled = false;
  await testMain();
}
