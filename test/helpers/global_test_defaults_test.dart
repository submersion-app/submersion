import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

import 'global_test_defaults.dart';

void main() {
  tearDown(applyGlobalTestDefaults);

  test('the harness applies the defaults before any test runs', () {
    expect(QualityScanScheduler.enabled, isFalse);
    expect(SensorSummaryScheduler.enabled, isFalse);
    expect(canShareFiles, isTrue);
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });

  test('puts every harness default back', () {
    QualityScanScheduler.enabled = true;
    SensorSummaryScheduler.enabled = true;
    debugCanShareFiles = false;
    GoogleFonts.config.allowRuntimeFetching = true;

    applyGlobalTestDefaults();

    expect(QualityScanScheduler.enabled, isFalse);
    expect(SensorSummaryScheduler.enabled, isFalse);
    expect(canShareFiles, isTrue);
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });
}
