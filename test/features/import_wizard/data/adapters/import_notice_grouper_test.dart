import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/data/adapters/import_notice_grouper.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

ImportWarning _noPressure() => const ImportWarning(
  severity: ImportWarningSeverity.info,
  code: ImportWarningCode.noTankPressure,
  entityType: ImportEntityType.dives,
  message: 'This file contains no tank pressure.',
);

void main() {
  test('no warnings produces no notices', () {
    expect(groupImportNotices(const [], 5), isEmpty);
  });

  test('one warning becomes one notice for one dive', () {
    final notices = groupImportNotices([_noPressure()], 1);

    expect(notices, hasLength(1));
    expect(notices.single.kind, ImportNoticeKind.noTankPressure);
    expect(notices.single.affectedDives, 1);
  });

  test('identical warnings from a batch collapse into a single row', () {
    // PayloadMerger concatenates per-file warnings, so a 12-file batch of
    // pressureless dives arrives as 12 copies. The diver should see one row
    // saying it affects 12 dives, not twelve rows.
    final notices = groupImportNotices(
      List.generate(12, (_) => _noPressure()),
      12,
    );

    expect(notices, hasLength(1));
    expect(notices.single.affectedDives, 12);
  });

  test('the count never exceeds the dives actually imported', () {
    // Duplicates that were skipped or consolidated still produced a parse
    // warning, so the raw warning count can outrun the imported count.
    final notices = groupImportNotices(
      List.generate(12, (_) => _noPressure()),
      4,
    );

    expect(notices.single.affectedDives, 4);
  });

  test('a run that imported nothing reports no notices', () {
    final notices = groupImportNotices(
      List.generate(3, (_) => _noPressure()),
      0,
    );

    expect(notices, isEmpty);
  });

  test('errors are not turned into notices', () {
    final notices = groupImportNotices(const [
      ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Could not parse FIT file.',
      ),
    ], 3);

    expect(notices, isEmpty);
  });

  test('uncoded warnings are skipped', () {
    // These carry English-only messages with no localized summary wording.
    final notices = groupImportNotices(const [
      ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Column "buddy" was not mapped.',
      ),
    ], 3);

    expect(notices, isEmpty);
  });
}
