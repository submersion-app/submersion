import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'global_state_scanner.dart';

/// A test that replaces process-wide state has to put it back.
///
/// CI runs many test files in one isolate (issue #2500). A platform singleton,
/// a harness default or a channel mock that one file leaves behind is what the
/// next file starts with, so the failure shows up in a different file from the
/// one that caused it, often in an unrelated change. This scan catches the
/// leak where it is written.
///
/// What to write instead:
///
/// * A `*Platform.instance` or `HttpOverrides.global`: read the previous value
///   into a variable first, and assign it back in `tearDown` or `addTearDown`.
/// * `QualityScanScheduler.enabled`, `SensorSummaryScheduler.enabled` or
///   `debugCanShareFiles`: call `applyGlobalTestDefaults()` from
///   `test/helpers/global_test_defaults.dart` in `tearDown`.
/// * A mock on the path provider or share channel: call
///   `clearPathAndShareChannelMocks()` from `test/helpers/mock_channels.dart`
///   in `tearDownAll`.
void main() {
  /// Written by `scripts/bundle_tests.py` and never checked in.
  bool isGenerated(String path) => path.startsWith('test/.bundles/');

  /// Files that replace a global on purpose, each with the reason. The
  /// entries marked pending are repaired by the change that adds this test.
  const allowed = <String, String>{
    'test/core/services/background_service_backup_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/export_service_dive_types_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/export_service_pdf_units_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/pdf/pdf_course_export_service_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export/pdf/pdf_trip_export_test.dart':
        'pending repair, issue #2500',
    'test/core/services/export_service_test.dart':
        'pending repair, issue #2500',
    'test/core/services/sync/base_export_blob_paging_test.dart':
        'pending repair, issue #2500',
    'test/core/services/sync/base_export_fact_clock_watermark_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_encryption_backup_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_database_copy_restore_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_encryption_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_newer_schema_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_premigration_restore_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_replace_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_saf_io_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_saf_refs_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_service_test.dart':
        'pending repair, issue #2500',
    'test/features/backup/data/services/backup_target_lease_test.dart':
        'pending repair, issue #2500',
    'test/features/courses/presentation/pages/course_detail_export_units_test.dart':
        'pending repair, issue #2500',
    'test/features/settings/presentation/providers/export_pdf_logbook_test.dart':
        'pending repair, issue #2500',
    'test/features/settings/presentation/providers/export_uddf_profiles_test.dart':
        'pending repair, issue #2500',
    'test/integration/uddf_round_trip_test.dart': 'pending repair, issue #2500',
  };

  Map<String, List<GlobalStateOffence>> scan() {
    final found = <String, List<GlobalStateOffence>>{};
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (isGenerated(path)) continue;
      final offences = scanForUnrestoredGlobals(
        path,
        entity.readAsStringSync(),
      );
      if (offences.isNotEmpty) found[path] = offences;
    }
    return found;
  }

  test('no test leaves a replaced global behind', () {
    final offenders = [
      for (final entry in scan().entries)
        if (!allowed.containsKey(entry.key)) ...entry.value,
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'These assignments replace process-wide state that nothing in the '
          'same file restores. The comment at the top of this test says what '
          'to write instead:\n${offenders.join('\n')}',
    );
  });

  test('every allowlisted file still exists', () {
    for (final path in allowed.keys) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('every allowlisted file still needs its entry', () {
    final found = scan();
    final stale = [
      for (final path in allowed.keys)
        if (!found.containsKey(path)) path,
    ];
    expect(
      stale,
      isEmpty,
      reason:
          'These files no longer replace a global without restoring it. '
          'Remove their entries from the allowlist:\n${stale.join('\n')}',
    );
  });
}
