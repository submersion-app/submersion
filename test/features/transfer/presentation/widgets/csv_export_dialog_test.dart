import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/transfer/presentation/widgets/csv_export_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<ValueGetter<Object?>> _open(
  WidgetTester tester, {
  CsvUnitMode initial = CsvUnitMode.myUnits,
}) async {
  // The sheet lists four data types plus the unit choice; the default test
  // surface is too short to tap the lower rows.
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Object? result = #pending;
  await tester.pumpWidget(
    MaterialApp(
      // Pinned so the English finders hold on a contributor's non-English
      // machine.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await CsvExportDialog.show(
                context,
                initialUnitMode: initial,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('returns the type and the starting unit mode', (tester) async {
    final result = await _open(tester);
    expect(find.text('My units'), findsOneWidget);
    await tester.tap(find.text('Export CSV').last);
    await tester.pumpAndSettle();
    expect(result(), (
      type: CsvExportType.dives,
      unitMode: CsvUnitMode.myUnits,
    ));
  });

  testWidgets('switching to Metric is returned', (tester) async {
    final result = await _open(tester);
    await tester.tap(find.text('Metric'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Metric values and ISO dates, the same format as earlier exports',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Export CSV').last);
    await tester.pumpAndSettle();
    expect(result(), (type: CsvExportType.dives, unitMode: CsvUnitMode.metric));
  });

  testWidgets('opens on the remembered mode', (tester) async {
    await _open(tester, initial: CsvUnitMode.metric);
    final button = tester.widget<SegmentedButton<CsvUnitMode>>(
      find.byKey(const ValueKey('csv-unit-mode-selector')),
    );
    expect(button.selected, {CsvUnitMode.metric});
  });

  testWidgets('the unit choice is hidden for gear check-ins', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Gear check-ins'));
    await tester.pumpAndSettle();
    expect(find.text('My units'), findsNothing);
  });
}
