import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/maintenance_excel_export_service.dart';
import 'package:submersion/core/services/export/export_service.dart'
    hide ServiceRecord;
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2026, 3, 14);

  const jjccr = EquipmentItem(
    id: 'e1',
    name: 'JJ-CCR',
    type: EquipmentType.rebreather,
  );

  ServiceRecord record() => ServiceRecord(
    id: 'r1',
    equipmentId: 'e1',
    serviceCategory: ServiceCategory.cleaning,
    serviceKindId: null,
    serviceDate: t0,
    cost: 45,
    currency: 'EUR',
    createdAt: t0,
    updatedAt: t0,
  );

  Future<void> pumpExportTab(
    WidgetTester tester, {
    required _FakeExportService exportService,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
          allEquipmentProvider.overrideWith((ref) async => [jjccr]),
          serviceKindsProvider.overrideWith((ref) async => []),
          serviceRecordRepositoryProvider.overrideWithValue(
            _FakeServiceRecordRepository({
              'e1': [record()],
            }),
          ),
          settingsProvider.overrideWith((ref) => _FixedSettings()),
          exportServiceProvider.overrideWithValue(exportService),
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
  }

  testWidgets('the export list offers a Maintenance Log tile', (tester) async {
    await pumpExportTab(tester, exportService: _FakeExportService());

    await tester.scrollUntilVisible(find.text('Maintenance Log'), 200);
    expect(find.text('Maintenance Log'), findsOneWidget);
    expect(
      find.text('Service history for all equipment as a spreadsheet'),
      findsOneWidget,
    );
  });

  testWidgets('the tile offers both share and save', (tester) async {
    await pumpExportTab(tester, exportService: _FakeExportService());

    await tester.scrollUntilVisible(find.text('Maintenance Log'), 200);
    await tester.tap(find.text('Maintenance Log'));
    await tester.pumpAndSettle();

    // Share and save are a deliberate pair, not a fallback chain.
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Save to File'), findsOneWidget);
  });

  testWidgets('sharing routes through the maintenance export', (tester) async {
    final fake = _FakeExportService();
    await pumpExportTab(tester, exportService: fake);

    await tester.scrollUntilVisible(find.text('Maintenance Log'), 200);
    await tester.tap(find.text('Maintenance Log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(fake.sharedRows, hasLength(1));
    expect(fake.sharedRows.single.equipmentName, 'JJ-CCR');
  });
}

class _FakeExportService implements ExportService {
  List<MaintenanceLogRow> sharedRows = const [];
  List<MaintenanceLogRow> savedRows = const [];

  @override
  Future<String> exportMaintenanceLog({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) async {
    sharedRows = rows;
    return '/tmp/shared.xlsx';
  }

  @override
  Future<String?> saveMaintenanceLogToFile({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) async {
    savedRows = rows;
    return '/tmp/saved.xlsx';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeServiceRecordRepository implements ServiceRecordRepository {
  final Map<String, List<ServiceRecord>> byEquipment;

  _FakeServiceRecordRepository(this.byEquipment);

  @override
  Future<List<ServiceRecord>> getRecordsForEquipment(
    String equipmentId,
  ) async => byEquipment[equipmentId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
