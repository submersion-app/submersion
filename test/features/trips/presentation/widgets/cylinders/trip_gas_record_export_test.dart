import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Records the record exports without touching the file system.
class _FakeExportService implements ExportService {
  String? sharedTrip;
  String? savedTrip;
  CsvExportUnits? units;

  @override
  Future<String> exportTripGasRecordToCsv(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    sharedTrip = tripName;
    this.units = units;
    return 'shared.csv';
  }

  @override
  Future<String?> saveTripGasRecordCsvToFile(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    savedTrip = tripName;
    return 'saved.csv';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const record = TripGasRecord(
    rows: [],
    slots: [],
    fillsLogged: 0,
    costs: [],
    packageFills: 0,
    unlinked: [],
    multipleDivers: false,
  );

  Future<_FakeExportService> pump(WidgetTester tester) async {
    final fake = _FakeExportService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          exportServiceProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TripGasRecordExportButton(
              record: record,
              tripName: 'Bonaire',
              centerNames: {},
            ),
          ),
        ),
      ),
    );
    return fake;
  }

  testWidgets('share sends the record through the facade', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const Key('record-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(fake.sharedTrip, 'Bonaire');
    expect(fake.units, isNotNull);
  });

  testWidgets('save to file goes through the facade', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const Key('record-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();
    expect(fake.savedTrip, 'Bonaire');
  });
}
