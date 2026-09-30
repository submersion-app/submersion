import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/csv_unit_mode_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Records the record exports without touching the file system.
class _FakeExportService implements ExportService {
  String? sharedTrip;
  Rect? shareAnchor;
  String? savedTrip;
  CsvExportUnits? units;
  bool fail = false;
  String? saveResult = 'saved.csv';

  @override
  Future<String> exportTripGasRecordToCsv(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
    Rect? sharePositionOrigin,
  }) async {
    if (fail) throw StateError('disk full');
    sharedTrip = tripName;
    shareAnchor = sharePositionOrigin;
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
    return saveResult;
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

  Future<_FakeExportService> pump(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    _FakeExportService? service,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();
    final fake = service ?? _FakeExportService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          exportServiceProvider.overrideWithValue(fake),
          sharedPreferencesProvider.overrideWithValue(preferences),
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

  testWidgets('share points the iPad popover at the button', (tester) async {
    final fake = await pump(tester);
    final button = tester.getRect(find.byKey(const Key('record-export')));
    await tester.tap(find.byKey(const Key('record-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(fake.shareAnchor, button);
  });

  testWidgets('save to file goes through the facade', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const Key('record-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();
    expect(fake.savedTrip, 'Bonaire');
  });

  Future<void> export(WidgetTester tester, String destination) async {
    await tester.tap(find.byKey(const Key('record-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(destination));
    await tester.pumpAndSettle();
  }

  testWidgets('a failed share says so', (tester) async {
    await pump(tester, service: _FakeExportService()..fail = true);
    await export(tester, 'Share');
    expect(find.textContaining('Export failed'), findsOneWidget);
  });

  testWidgets('a finished save says so', (tester) async {
    await pump(tester);
    await export(tester, 'Save to File');
    expect(find.text('Gas record exported'), findsOneWidget);
  });

  testWidgets('a cancelled save says nothing', (tester) async {
    await pump(tester, service: _FakeExportService()..saveResult = null);
    await export(tester, 'Save to File');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the remembered units are the default, and a choice is kept', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      prefs: {'csv_export_unit_mode': CsvUnitMode.metric.name},
    );
    await export(tester, 'Share');
    expect(fake.units!.isMetric, isTrue);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TripGasRecordExportButton)),
    );
    expect(container.read(csvUnitModeProvider), CsvUnitMode.metric);
  });
}
