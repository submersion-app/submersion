import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/pdf/equipment_report_pdf_parts.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_report_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';

import '../../../../helpers/mock_providers.dart';

const _emptyInventory = InventoryReport(
  itemCount: 0,
  unpricedCount: 0,
  totals: [],
  groups: [],
  fallbackCurrency: 'USD',
);

final _inventory = buildInventoryReport(
  items: const [
    EquipmentItem(id: 'a', name: 'a', type: EquipmentType.regulator),
  ],
  locations: const {},
  options: const InventoryReportOptions(),
  diverId: null,
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

const _emptyService = ServiceReport(
  fallbackCurrency: 'USD',
  overdue: 0,
  dueSoon: 0,
  upToDate: 0,
  noScheduleCount: 0,
  due: [],
  history: [],
);

class _FakeExport implements ExportService {
  _FakeExport({this.fail = false, this.cancel = false});

  final bool fail;
  final bool cancel;
  final calls = <String>[];
  String? diverName;

  @override
  Future<String> exportEquipmentInventory(
    InventoryReport report, {
    required InventoryReportOptions options,
    required ReportPrintSettings settings,
    Rect? sharePositionOrigin,
  }) async {
    if (fail) throw StateError('disk full');
    calls.add('share-inventory');
    diverName = settings.diverName;
    return '/shared.pdf';
  }

  @override
  Future<String?> saveEquipmentInventoryToFile(
    InventoryReport report, {
    required InventoryReportOptions options,
    required ReportPrintSettings settings,
  }) async {
    if (fail) throw StateError('disk full');
    calls.add('save-inventory');
    return cancel ? null : '/saved.pdf';
  }

  @override
  Future<String> exportServiceReport(
    ServiceReport report, {
    required ServiceReportOptions options,
    required ReportPrintSettings settings,
    Rect? sharePositionOrigin,
  }) async {
    calls.add('share-service');
    return '/shared.pdf';
  }

  @override
  Future<String?> saveServiceReportToFile(
    ServiceReport report, {
    required ServiceReportOptions options,
    required ReportPrintSettings settings,
  }) async {
    calls.add('save-service');
    return cancel ? null : '/saved.pdf';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<({ProviderContainer container, _FakeExport export})> make({
    InventoryReport? inventory,
    ServiceReport service = _service,
    bool fail = false,
    bool cancel = false,
  }) async {
    final export = _FakeExport(fail: fail, cancel: cancel);
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(
      overrides: [
        ...overrides,
        exportServiceProvider.overrideWithValue(export),
        currentDiverProvider.overrideWith(
          (ref) async => Diver(
            id: 'me',
            name: 'Sam Diver',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
        inventoryReportProvider.overrideWith(
          (ref, options) async => inventory ?? _inventory,
        ),
        serviceReportProvider.overrideWith((ref, options) async => service),
      ].cast(),
    );
    addTearDown(container.dispose);
    return (container: container, export: export);
  }

  const options = InventoryReportOptions();
  const serviceOptions = ServiceReportOptions();

  test('shares the inventory with the diver name', () async {
    final t = await make();
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportEquipmentInventory(options, save: false);

    final state = t.container.read(exportNotifierProvider);
    expect(t.export.calls, ['share-inventory']);
    expect(t.export.diverName, 'Sam Diver');
    expect(state.status, ExportStatus.success);
    expect(state.message, 'Inventory exported');
    expect(state.filePath, '/shared.pdf');
  });

  test('saves the inventory where the diver chose', () async {
    final t = await make();
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportEquipmentInventory(options, save: true);

    final state = t.container.read(exportNotifierProvider);
    expect(t.export.calls, ['save-inventory']);
    expect(state.message, 'Inventory saved');
    expect(state.filePath, '/saved.pdf');
  });

  test('an empty inventory reports the error, not a blank PDF', () async {
    final t = await make(inventory: _emptyInventory);
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportEquipmentInventory(options, save: false);

    expect(t.export.calls, isEmpty);
    expect(t.container.read(exportNotifierProvider).status, ExportStatus.error);
  });

  test('a cancelled save returns to idle, not success', () async {
    final t = await make(cancel: true);
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportEquipmentInventory(options, save: true);

    expect(t.container.read(exportNotifierProvider).status, ExportStatus.idle);
  });

  test('a failure reports the export failed message', () async {
    final t = await make(fail: true);
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportEquipmentInventory(options, save: false);

    final state = t.container.read(exportNotifierProvider);
    expect(state.status, ExportStatus.error);
    expect(state.message, contains('disk full'));
  });

  test('shares and saves the service report', () async {
    final t = await make();
    final notifier = t.container.read(exportNotifierProvider.notifier);

    await notifier.exportServiceReport(serviceOptions, save: false);
    expect(
      t.container.read(exportNotifierProvider).message,
      'Service report exported',
    );

    await notifier.exportServiceReport(serviceOptions, save: true);
    expect(
      t.container.read(exportNotifierProvider).message,
      'Service report saved',
    );
    expect(t.export.calls, ['share-service', 'save-service']);
  });

  test('an empty service report reports the error', () async {
    final t = await make(service: _emptyService);
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportServiceReport(serviceOptions, save: false);

    expect(t.export.calls, isEmpty);
    expect(t.container.read(exportNotifierProvider).status, ExportStatus.error);
  });
}
