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

  group('rows skipped for an unreadable date', () {
    ImportWarning skippedRow(int? row) => ImportWarning(
      severity: ImportWarningSeverity.warning,
      code: ImportWarningCode.unreadableDate,
      entityType: ImportEntityType.dives,
      message: 'Row $row: could not resolve dateTime, skipping',
      sourceRow: row,
    );

    test('collapse into one notice that lists the rows in order', () {
      final notices = groupImportNotices([
        skippedRow(12),
        skippedRow(4),
        skippedRow(9),
      ], 20);

      expect(notices, hasLength(1));
      expect(notices.single.kind, ImportNoticeKind.unreadableDates);
      expect(notices.single.affectedDives, 3);
      expect(notices.single.rowNumbers, [4, 9, 12]);
    });

    test('are not capped by the number of dives imported', () {
      // These rows are the dives that did NOT import, so the imported count
      // says nothing about how many there are.
      final notices = groupImportNotices(
        List.generate(5, (i) => skippedRow(i + 2)),
        1,
      );

      expect(notices.single.affectedDives, 5);
    });

    test('are reported even when nothing was imported', () {
      final notices = groupImportNotices([skippedRow(2)], 0);

      expect(notices.single.kind, ImportNoticeKind.unreadableDates);
    });

    test('are counted even without a row number', () {
      final notices = groupImportNotices([skippedRow(null), skippedRow(3)], 5);

      expect(notices.single.affectedDives, 2);
      expect(notices.single.rowNumbers, [3]);
    });

    test('sit alongside the other notices', () {
      final notices = groupImportNotices([_noPressure(), skippedRow(2)], 1);

      expect(notices.map((n) => n.kind), [
        ImportNoticeKind.noTankPressure,
        ImportNoticeKind.unreadableDates,
      ]);
    });
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
