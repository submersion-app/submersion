import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/dive_participants.dart';

/// Issue #1861: the CSV export read only the legacy `buddy` / `diveMaster`
/// scalars, so a dive whose team was linked through the buddy picker exported
/// with an empty Buddy and Dive Master.
void main() {
  /// The Buddy and Dive Master cells of the first data row.
  ({String buddy, String diveMaster}) teamCells(Dive dive) {
    final csv = CsvExportService().generateDivesCsvContent([dive]);
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csv);
    final headers = rows.first.cast<String>();
    return (
      buddy: rows[1][headers.indexOf('Buddy')] as String,
      diveMaster: rows[1][headers.indexOf('Dive Master')] as String,
    );
  }

  test('linked participants fill the Buddy and Dive Master columns', () {
    final cells = teamCells(diveWithLinkedTeam());

    expect(cells.buddy, 'Ana');
    expect(cells.diveMaster, 'Gil, Mia');
  });

  test('a linked team is authoritative over the stale legacy scalars', () {
    final csv = CsvExportService().generateDivesCsvContent([
      diveWithLinkedTeam(),
    ]);

    expect(csv, isNot(contains('Stalebuddy')));
    expect(csv, isNot(contains('Staledm')));
  });

  test('a dive with no linked team falls back to the legacy scalars', () {
    final cells = teamCells(diveWithLegacyScalarsOnly());

    expect(cells.buddy, 'Oldbuddy');
    expect(cells.diveMaster, 'Olddm');
  });
}
