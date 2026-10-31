import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/services/export/export_service.dart'
    hide ServiceRecord;
import 'package:submersion/core/services/export/pdf/equipment_report_pdf_parts.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_report_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/features/transfer/presentation/widgets/report_sheet_scaffold.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _inventory = InventoryReport(
  itemCount: 1,
  unpricedCount: 0,
  totals: [],
  groups: [InventoryGroup(rows: [], subtotals: [])],
  fallbackCurrency: 'USD',
);

const _service = ServiceReport(
  fallbackCurrency: 'USD',
  overdue: 1,
  dueSoon: 0,
  upToDate: 0,
  noScheduleCount: 0,
  due: [],
  history: [],
);

class _FakeExport implements ExportService {
  final calls = <String>[];
  InventoryReportOptions? inventoryOptions;

  @override
  Future<String> exportEquipmentInventory(
    InventoryReport report, {
    required InventoryReportOptions options,
    required ReportPrintSettings print,
    Rect? sharePositionOrigin,
  }) async {
    calls.add('inventory');
    inventoryOptions = options;
    return '/x.pdf';
  }

  @override
  Future<String> exportServiceReport(
    ServiceReport report, {
    required ServiceReportOptions options,
    required ReportPrintSettings print,
    Rect? sharePositionOrigin,
  }) async {
    calls.add('service');
    return '/x.pdf';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pumpExportTab(WidgetTester tester, _FakeExport export) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/transfer?selected=export',
      routes: [
        GoRoute(
          path: '/transfer',
          builder: (context, state) => const TransferPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          exportServiceProvider.overrideWithValue(export),
          currentDiverProvider.overrideWith((ref) async => null),
          equipmentLocationsProvider.overrideWith((ref) async => const []),
          allEquipmentProvider.overrideWith((ref) async => const []),
          allTripsProvider.overrideWith((ref) async => const []),
          inventoryReportProvider.overrideWith(
            (ref, options) async => _inventory,
          ),
          serviceReportProvider.overrideWith((ref, options) async => _service),
        ].cast(),
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

  testWidgets('shows both tiles beside the maintenance log', (tester) async {
    await pumpExportTab(tester, _FakeExport());

    await tester.scrollUntilVisible(find.text('Maintenance Log'), 200);
    expect(find.text('Equipment Inventory'), findsOneWidget);
    expect(
      find.text('PDF with serial numbers and what you paid'),
      findsOneWidget,
    );
    expect(find.text('Service Report'), findsOneWidget);
    expect(
      find.text('PDF of what is due, with service history'),
      findsOneWidget,
    );
  });

  testWidgets('inventory goes through its sheet, then share', (tester) async {
    final export = _FakeExport();
    await pumpExportTab(tester, export);

    await tester.scrollUntilVisible(find.text('Equipment Inventory'), 200);
    await tester.tap(find.text('Equipment Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ReportSheetScaffold.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(export.calls, ['inventory']);
    expect(export.inventoryOptions, const InventoryReportOptions());
  });

  testWidgets('service report goes through its sheet, then share', (
    tester,
  ) async {
    final export = _FakeExport();
    await pumpExportTab(tester, export);

    await tester.scrollUntilVisible(find.text('Service Report'), 200);
    await tester.tap(find.text('Service Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ReportSheetScaffold.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(export.calls, ['service']);
  });

  testWidgets('dismissing the sheet exports nothing', (tester) async {
    final export = _FakeExport();
    await pumpExportTab(tester, export);

    await tester.scrollUntilVisible(find.text('Equipment Inventory'), 200);
    await tester.tap(find.text('Equipment Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(export.calls, isEmpty);
    expect(find.text('Share'), findsNothing);
  });
}
