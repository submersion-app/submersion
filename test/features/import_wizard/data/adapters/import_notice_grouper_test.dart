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

ImportWarning _coded(
  ImportWarningCode code, {
  int count = 1,
  List<String> names = const [],
}) => ImportWarning(
  severity: ImportWarningSeverity.info,
  code: code,
  message: 'English text the summary never shows',
  count: count,
  names: names,
);

void main() {
  test('no warnings produces no notices', () {
    expect(groupImportNotices(const [], 5), isEmpty);
  });

  test('one warning becomes one notice for one dive', () {
    final notices = groupImportNotices([_noPressure()], 1);

    expect(notices, hasLength(1));
    expect(notices.single.kind, ImportNoticeKind.noTankPressure);
    expect(notices.single.count, 1);
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
    expect(notices.single.count, 12);
  });

  test('the count never exceeds the dives actually imported', () {
    // Duplicates that were skipped or consolidated still produced a parse
    // warning, so the raw warning count can outrun the imported count.
    final notices = groupImportNotices(
      List.generate(12, (_) => _noPressure()),
      4,
    );

    expect(notices.single.count, 4);
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
      expect(notices.single.count, 3);
      expect(notices.single.rowNumbers, [4, 9, 12]);
    });

    test('are not capped by the number of dives imported', () {
      // These rows are the dives that did NOT import, so the imported count
      // says nothing about how many there are.
      final notices = groupImportNotices(
        List.generate(5, (i) => skippedRow(i + 2)),
        1,
      );

      expect(notices.single.count, 5);
    });

    test('are reported even when nothing was imported', () {
      final notices = groupImportNotices([skippedRow(2)], 0);

      expect(notices.single.kind, ImportNoticeKind.unreadableDates);
    });

    test('are counted even without a row number', () {
      final notices = groupImportNotices([skippedRow(null), skippedRow(3)], 5);

      expect(notices.single.count, 2);
      expect(notices.single.rowNumbers, [3]);
    });

    test('sit alongside the other notices, missing dives first', () {
      final notices = groupImportNotices([_noPressure(), skippedRow(2)], 1);

      expect(notices.map((n) => n.kind), [
        ImportNoticeKind.unreadableDates,
        ImportNoticeKind.noTankPressure,
      ]);
    });
  });

  test('diagnostic warnings are recorded but never shown', () {
    final notices = groupImportNotices([
      _coded(ImportWarningCode.diagnostic),
    ], 3);

    expect(notices, isEmpty);
  });

  test('every shown code maps to its own notice kind', () {
    const expected = {
      ImportWarningCode.noTankPressure: ImportNoticeKind.noTankPressure,
      ImportWarningCode.unreadableDate: ImportNoticeKind.unreadableDates,
      ImportWarningCode.divesSkipped: ImportNoticeKind.divesSkipped,
      ImportWarningCode.profileUnreadable: ImportNoticeKind.profileUnreadable,
      ImportWarningCode.macdiveProfileUndecodable:
          ImportNoticeKind.macdiveProfileUndecodable,
      ImportWarningCode.profileUndecodableOnPlatform:
          ImportNoticeKind.profileUndecodableOnPlatform,
      ImportWarningCode.columnsNotImported: ImportNoticeKind.columnsNotImported,
      ImportWarningCode.valuesNotConverted: ImportNoticeKind.valuesNotConverted,
      ImportWarningCode.photosSkipped: ImportNoticeKind.photosSkipped,
      ImportWarningCode.macdiveXmlOmitsCertsAndService:
          ImportNoticeKind.macdiveXmlOmitsCertsAndService,
      ImportWarningCode.macdiveLogbooksNotImported:
          ImportNoticeKind.macdiveLogbooksNotImported,
      ImportWarningCode.sitesUnresolved: ImportNoticeKind.sitesUnresolved,
    };
    // Every code but diagnostic must be listed, so a new code cannot be added
    // without deciding which notice it becomes.
    expect(
      expected.keys.toSet(),
      ImportWarningCode.values.toSet()..remove(ImportWarningCode.diagnostic),
    );

    for (final entry in expected.entries) {
      final notices = groupImportNotices([_coded(entry.key)], 1);
      expect(notices.single.kind, entry.value, reason: '${entry.key}');
    }
  });

  test('an aggregated warning contributes its own count', () {
    // The MacDive mapper emits one warning for all of a file's undecodable
    // profiles; two files in a batch contribute 3 and 4.
    final notices = groupImportNotices([
      _coded(ImportWarningCode.macdiveProfileUndecodable, count: 3),
      _coded(ImportWarningCode.macdiveProfileUndecodable, count: 4),
    ], 10);

    expect(notices.single.count, 7);
  });

  test('per-dive kinds are clamped to the dives imported', () {
    for (final code in const [
      ImportWarningCode.profileUnreadable,
      ImportWarningCode.macdiveProfileUndecodable,
      ImportWarningCode.profileUndecodableOnPlatform,
    ]) {
      final notices = groupImportNotices([_coded(code, count: 9)], 2);
      expect(notices.single.count, 2, reason: '$code');
    }
  });

  test('skipped dives are reported even when nothing was imported', () {
    // Like rows with an unreadable date, these are dives missing from the
    // import, so a run that imported nothing still has them to report.
    final notices = groupImportNotices([
      _coded(ImportWarningCode.divesSkipped),
      _noPressure(),
    ], 0);

    expect(notices.map((n) => n.kind), [ImportNoticeKind.divesSkipped]);
  });

  test('skipped dives are not clamped: they were never imported', () {
    final notices = groupImportNotices(
      List.generate(5, (_) => _coded(ImportWarningCode.divesSkipped)),
      2,
    );

    expect(notices.single.count, 5);
  });

  test('values and photos count themselves, not dives, so are not clamped', () {
    final notices = groupImportNotices([
      ...List.generate(40, (_) => _coded(ImportWarningCode.valuesNotConverted)),
      ...List.generate(6, (_) => _coded(ImportWarningCode.photosSkipped)),
    ], 2);

    expect(
      {for (final n in notices) n.kind: n.count},
      {
        ImportNoticeKind.valuesNotConverted: 40,
        ImportNoticeKind.photosSkipped: 6,
      },
    );
  });

  test(
    'names from several files merge without repeats, in first-seen order',
    () {
      final notices = groupImportNotices([
        _coded(
          ImportWarningCode.macdiveLogbooksNotImported,
          names: ['Reef', 'Wreck'],
        ),
        _coded(
          ImportWarningCode.macdiveLogbooksNotImported,
          names: ['Wreck', 'Night'],
        ),
      ], 3);

      expect(notices.single.names, ['Reef', 'Wreck', 'Night']);
    },
  );

  test('notices come out data loss first, whatever order the files gave', () {
    final notices = groupImportNotices([
      _coded(ImportWarningCode.macdiveLogbooksNotImported, names: ['Reef']),
      _noPressure(),
      _coded(ImportWarningCode.photosSkipped),
      _coded(ImportWarningCode.divesSkipped),
    ], 3);

    expect(notices.map((n) => n.kind), [
      ImportNoticeKind.divesSkipped,
      ImportNoticeKind.noTankPressure,
      ImportNoticeKind.photosSkipped,
      ImportNoticeKind.macdiveLogbooksNotImported,
    ]);
  });
}
