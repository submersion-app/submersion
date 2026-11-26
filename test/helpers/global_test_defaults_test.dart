import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';

import 'blocked_network.dart';
import 'global_test_defaults.dart';

class _OtherHttp extends HttpOverrides {}

final class _OtherIo extends IOOverrides {}

void main() {
  tearDown(applyGlobalTestDefaults);

  test('the harness applies the defaults before any test runs', () {
    expect(QualityScanScheduler.enabled, isFalse);
    expect(SensorSummaryScheduler.enabled, isFalse);
    expect(canShareFiles, isTrue);
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    expect(OnnxVisionEngine.debugLibraryLoadsOverride, isFalse);
    expect(HttpOverrides.current, same(blockedNetworkHttpOverrides));
    expect(IOOverrides.current, same(blockedNetworkIOOverrides));
  });

  // `flutter test` builds ONNX Runtime in for a Linux host (CI) and not for
  // a Mac. Left to the host, a viewer test on Linux analysed each photo it
  // opened, and the labels ring spun under a pumpAndSettle until it timed
  // out; on a Mac nothing ran.
  test('a vision engine finds no ONNX Runtime, on any host', () async {
    expect(
      await OnnxVisionEngine(platform: TargetPlatform.android).availability(),
      VisionAvailability.unsupportedPlatform,
    );
  });

  test('puts every harness default back', () {
    final previousHttp = HttpOverrides.current;
    final previousIo = IOOverrides.current;
    addTearDown(() {
      HttpOverrides.global = previousHttp;
      IOOverrides.global = previousIo;
    });
    HttpOverrides.global = _OtherHttp();
    IOOverrides.global = _OtherIo();
    QualityScanScheduler.enabled = true;
    SensorSummaryScheduler.enabled = true;
    debugCanShareFiles = false;
    GoogleFonts.config.allowRuntimeFetching = true;
    OnnxVisionEngine.debugLibraryLoadsOverride = true;

    applyGlobalTestDefaults();

    expect(QualityScanScheduler.enabled, isFalse);
    expect(SensorSummaryScheduler.enabled, isFalse);
    expect(canShareFiles, isTrue);
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    expect(OnnxVisionEngine.debugLibraryLoadsOverride, isFalse);
    expect(HttpOverrides.current, same(blockedNetworkHttpOverrides));
    expect(IOOverrides.current, same(blockedNetworkIOOverrides));
  });
}
