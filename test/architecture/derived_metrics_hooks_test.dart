import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The derived metrics and the sensor summaries are both computed from a
/// dive's profile, so every site that refreshes one refreshes the other. A
/// site that forgets leaves the SAC and final-stop fields answering about a
/// profile the diver has since changed, until the next launch sweep.
void main() {
  test('derived metrics are scheduled wherever sensor summaries are', () {
    int count(String text, String call) => call.allMatches(text).length;
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('/sensor_summary_scheduler.dart')) continue;
      if (path.endsWith('/derived_metrics_scheduler.dart')) continue;
      final text = entity.readAsStringSync();
      final refreshes = count(text, 'scheduleSensorSummaryRefresh(');
      final derived = count(text, 'scheduleDerivedMetricsRefresh(');
      final sweeps = count(
        text,
        'SensorSummaryScheduler.instance.scheduleStaleSweep(',
      );
      final derivedSweeps = count(
        text,
        'DerivedMetricsScheduler.instance.scheduleStaleSweep(',
      );
      if (refreshes != derived || sweeps != derivedSweeps) {
        offenders.add(
          '$path: $refreshes sensor vs $derived derived refreshes, '
          '$sweeps sensor vs $derivedSweeps derived sweeps',
        );
      }
    }
    expect(offenders, isEmpty);
  });
}
