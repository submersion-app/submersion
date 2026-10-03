import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/cloud_import_dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const settings = AppSettings();

  DownloadedDive diveAt(DateTime startTime) => DownloadedDive(
    startTime: startTime,
    durationSeconds: 4680,
    maxDepth: 25.0,
    profile: const [],
  );

  // Downloaded dive times are the dive's wall clock flagged UTC, the same
  // convention every stored dive time follows. Converting one to the device's
  // zone shifts the listed time by the device's UTC offset; these fail on any
  // machine outside UTC when that conversion comes back.
  test('lists the dive at its own wall-clock time', () {
    final summary = formatCloudDiveSummary(
      diveAt(DateTime.utc(2026, 9, 14, 9, 1, 46)),
      settings,
    );

    expect(summary.title, 'Sep 14, 2026 — 9:01 AM');
  });

  test('keeps the dive on its own date just after midnight', () {
    final summary = formatCloudDiveSummary(
      diveAt(DateTime.utc(2026, 9, 14, 0, 30)),
      settings,
    );

    expect(summary.title, 'Sep 14, 2026 — 12:30 AM');
  });
}
