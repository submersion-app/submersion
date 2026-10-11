import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

// On a multi-source dive the provenance (serial, format, times, import date,
// file) lives in the comparison table, one column per source, instead of a
// label/value list repeated on every card (issue #3281).

const _units = UnitFormatter(AppSettings());

// The glyph a missing cell shows, built from its code point.
final _placeholder = String.fromCharCode(0x2014);

final _entry = DateTime(2026, 3, 20, 9, 12);
final _exit = DateTime(2026, 3, 20, 10, 4);

DiveDataSource _source({
  required String id,
  bool isPrimary = false,
  String? computerModel,
  String? computerSerial,
  String? sourceFormat,
  String? sourceFileName,
  DateTime? entryTime,
  DateTime? exitTime,
  DateTime? importedAt,
}) {
  return DiveDataSource(
    id: id,
    diveId: 'dive-1',
    computerId: 'comp-$id',
    isPrimary: isPrimary,
    computerModel: computerModel,
    computerSerial: computerSerial,
    sourceFormat: sourceFormat,
    sourceFileName: sourceFileName,
    maxDepth: 30.0,
    duration: 3000,
    entryTime: entryTime,
    exitTime: exitTime,
    importedAt: importedAt ?? DateTime(2026, 3, 21, 8),
    createdAt: _entry,
  );
}

DiveDataSource _perdix({String? fileName = 'perdix_dive14.xml'}) => _source(
  id: 'src-1',
  isPrimary: true,
  computerModel: 'Shearwater Perdix',
  computerSerial: 'SN-PERDIX',
  sourceFormat: 'Shearwater Cloud',
  sourceFileName: fileName,
  entryTime: _entry,
  exitTime: _exit,
  importedAt: DateTime(2026, 3, 21, 8),
);

DiveDataSource _teric({
  String? fileName = 'teric_dive14.fit',
  bool keepExit = true,
}) => _source(
  id: 'src-2',
  computerModel: 'Shearwater Teric',
  computerSerial: 'SN-TERIC',
  sourceFormat: 'FIT',
  sourceFileName: fileName,
  entryTime: _entry,
  exitTime: keepExit ? _exit.add(const Duration(minutes: 1)) : null,
  importedAt: DateTime(2026, 3, 22, 8),
);

Future<void> _pump(WidgetTester tester, List<DiveDataSource> sources) async {
  await tester.pumpWidget(
    testApp(
      // The assertions read English labels, so the language is pinned
      // rather than left to the host platform's locale.
      locale: const Locale('en'),
      child: SingleChildScrollView(
        child: DataSourcesSection(
          dataSources: sources,
          diveCreatedAt: _entry,
          diveId: 'dive-1',
          units: _units,
          onSetPrimary: (_) {},
          onSplit: (_) {},
          onTapSource: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inGrid(Finder matching) => find.descendant(
  of: find.byKey(DataSourcesSection.comparisonGridKey),
  matching: matching,
);

Finder _inCard(String id, Finder matching) => find.descendant(
  of: find.byKey(DataSourcesSection.cardKey(id)),
  matching: matching,
);

void main() {
  group('Multi-source provenance in the comparison table', () {
    testWidgets('each provenance label appears once, inside the table', (
      tester,
    ) async {
      await _pump(tester, [_perdix(), _teric()]);

      for (final label in ['Serial', 'Format', 'Times', 'Imported', 'File']) {
        expect(find.text(label), findsOneWidget, reason: label);
        expect(_inGrid(find.text(label)), findsOneWidget, reason: label);
      }
    });

    testWidgets("each source's provenance sits in the table", (tester) async {
      await _pump(tester, [_perdix(), _teric()]);

      for (final value in [
        'SN-PERDIX',
        'SN-TERIC',
        'Shearwater Cloud',
        'FIT',
        'perdix_dive14.xml',
        'teric_dive14.fit',
        _units.formatDate(DateTime(2026, 3, 21, 8)),
        _units.formatDate(DateTime(2026, 3, 22, 8)),
      ]) {
        expect(find.text(value), findsOneWidget, reason: value);
        expect(_inGrid(find.text(value)), findsOneWidget, reason: value);
      }
    });

    testWidgets('provenance values follow their source column', (tester) async {
      await _pump(tester, [_perdix(), _teric()]);

      double leftX(String text) =>
          tester.getRect(_inGrid(find.text(text))).left;

      // Column alignment: every value of a source starts at the same x as
      // that source's header.
      final perdixX = leftX('Shearwater Perdix');
      final tericX = leftX('Shearwater Teric');
      expect(leftX('SN-PERDIX'), perdixX);
      expect(leftX('perdix_dive14.xml'), perdixX);
      expect(leftX('SN-TERIC'), tericX);
      expect(leftX('teric_dive14.fit'), tericX);
    });

    testWidgets('cards carry identity only, no provenance list', (
      tester,
    ) async {
      await _pump(tester, [_perdix(), _teric()]);

      for (final id in ['src-1', 'src-2']) {
        expect(_inCard(id, find.byType(Table)), findsNothing, reason: id);
        expect(_inCard(id, find.text('Serial')), findsNothing, reason: id);
      }
      // The card still names its source and keeps its chips and menu.
      expect(_inCard('src-1', find.text('Shearwater Perdix')), findsOneWidget);
      expect(_inCard('src-1', find.text('Primary')), findsOneWidget);
      expect(_inCard('src-2', find.byIcon(Icons.more_vert)), findsOneWidget);
    });

    testWidgets('a row no source has is left out', (tester) async {
      await _pump(tester, [_perdix(fileName: null), _teric(fileName: null)]);

      expect(find.text('File'), findsNothing);
      // The other provenance rows are still in the table.
      expect(_inGrid(find.text('Serial')), findsOneWidget);
    });

    testWidgets('a row one source lacks shows a placeholder for it', (
      tester,
    ) async {
      await _pump(tester, [_perdix(), _teric(fileName: null)]);

      expect(_inGrid(find.text('File')), findsOneWidget);
      expect(_inGrid(find.text('perdix_dive14.xml')), findsOneWidget);
      expect(_inGrid(find.text(_placeholder)), findsWidgets);
    });

    testWidgets('one Times row with a range per source when all are known', (
      tester,
    ) async {
      await _pump(tester, [_perdix(), _teric()]);

      expect(_inGrid(find.text('Times')), findsOneWidget);
      expect(_inGrid(find.text('Entry')), findsNothing);
      expect(_inGrid(find.text('Exit')), findsNothing);
      expect(
        _inGrid(
          find.text('${_units.formatTime(_entry)}–${_units.formatTime(_exit)}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a source missing one end splits Times into Entry and Exit', (
      tester,
    ) async {
      await _pump(tester, [_perdix(), _teric(keepExit: false)]);

      expect(find.text('Times'), findsNothing);
      expect(_inGrid(find.text('Entry')), findsOneWidget);
      expect(_inGrid(find.text('Exit')), findsOneWidget);
      // Both sources share the entry time; only the Perdix has an exit.
      expect(_inGrid(find.text(_units.formatTime(_entry))), findsNWidgets(2));
      expect(_inGrid(find.text(_units.formatTime(_exit))), findsOneWidget);
    });

    testWidgets('the top-left header cell has no "Metric" label', (
      tester,
    ) async {
      await _pump(tester, [_perdix(), _teric()]);

      expect(find.text('Metric'), findsNothing);
    });

    testWidgets('with three sources a long value cannot widen its column', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const longName =
          'an_extremely_long_exported_dive_file_name_from_a_desktop_tool.uddf';
      await _pump(tester, [
        _perdix(fileName: longName),
        _teric(),
        _source(
          id: 'src-3',
          computerModel: 'Suunto EON Core',
          computerSerial: 'SN-EON',
          entryTime: _entry,
          exitTime: _exit,
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(_inGrid(find.text(longName))).width,
        lessThanOrEqualTo(DataSourcesSection.maxScrollingCellWidth),
      );
    });
  });

  group('Single-source dive', () {
    testWidgets('keeps the provenance list on the card, with no table', (
      tester,
    ) async {
      await _pump(tester, [_perdix()]);

      expect(find.byKey(DataSourcesSection.comparisonGridKey), findsNothing);
      expect(_inCard('src-1', find.text('Serial')), findsOneWidget);
      expect(_inCard('src-1', find.text('SN-PERDIX')), findsOneWidget);
      expect(_inCard('src-1', find.text('Times')), findsOneWidget);
    });
  });
}
