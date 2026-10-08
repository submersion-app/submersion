import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Transfer page's CSV export reaches the cylinder fills export
/// (cylinder passports phase 5).
void main() {
  final fill = CylinderFill(
    id: 'f1',
    diverId: 'me',
    passportId: 'pp-1',
    filledAt: DateTime.utc(2026, 9, 28),
    o2Percent: 32,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  Future<void> openFillsSheet(
    WidgetTester tester,
    _FakeExportService fake,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/transfer?selected=export',
      routes: [
        GoRoute(
          path: '/transfer',
          builder: (context, state) => const TransferPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allEquipmentProvider.overrideWith((ref) async => const []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          cylinderFillRepositoryProvider.overrideWithValue(_FakeFills([fill])),
          settingsProvider.overrideWith((ref) => _FixedSettings()),
          exportServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('CSV Export'), 200);
    await tester.tap(find.text('CSV Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cylinder fills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export CSV').last);
    await tester.pumpAndSettle();
  }

  testWidgets('choosing Cylinder fills opens its share and save sheet', (
    tester,
  ) async {
    await openFillsSheet(tester, _FakeExportService());

    expect(find.text('Cylinder fills CSV'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Save to File'), findsOneWidget);
  });

  testWidgets('sharing routes through the fills export', (tester) async {
    final fake = _FakeExportService();
    await openFillsSheet(tester, fake);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(fake.shared.map((f) => f.id), ['f1']);
  });

  testWidgets('saving routes through the fills save', (tester) async {
    final fake = _FakeExportService();
    await openFillsSheet(tester, fake);

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(fake.saved.map((f) => f.id), ['f1']);
  });
}

class _FakeFills extends CylinderFillRepository {
  _FakeFills(this.all);

  final List<CylinderFill> all;

  @override
  Future<List<CylinderFill>> getAllVisibleTo(String diverId) async => all;
}

class _FakeExportService implements ExportService {
  List<CylinderFill> shared = const [];
  List<CylinderFill> saved = const [];

  @override
  Future<String> exportFillsToCsv(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    shared = fills;
    return '/tmp/fills.csv';
  }

  @override
  Future<String?> saveFillsCsvToFile(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    saved = fills;
    return '/tmp/saved.csv';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
