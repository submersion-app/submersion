import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/maintenance_excel_export_service.dart';
import 'package:submersion/core/services/export/export_service.dart'
    hide ServiceRecord;
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 3, 14);

  ServiceRecord record({
    required String id,
    required String equipmentId,
    String? kindId,
    ServiceCategory type = ServiceCategory.cleaning,
  }) => ServiceRecord(
    id: id,
    equipmentId: equipmentId,
    serviceCategory: type,
    serviceKindId: kindId,
    serviceDate: t0,
    cost: 45,
    currency: 'EUR',
    createdAt: t0,
    updatedAt: t0,
  );

  ProviderContainer makeContainer({
    required List<EquipmentItem> equipment,
    required Map<String, List<ServiceRecord>> recordsByEquipment,
    List<ServiceKind> kinds = const [],
    _FakeExportService? exportService,
  }) {
    final container = ProviderContainer(
      overrides: [
        allEquipmentProvider.overrideWith((ref) async => equipment),
        serviceKindsProvider.overrideWith((ref) async => kinds),
        serviceRecordRepositoryProvider.overrideWithValue(
          _FakeServiceRecordRepository(recordsByEquipment),
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(
          exportService ?? _FakeExportService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ExportNotifier notifierOf(ProviderContainer c) =>
      c.read(exportNotifierProvider.notifier);

  const jjccr = EquipmentItem(
    id: 'e1',
    name: 'JJ-CCR',
    type: EquipmentType.rebreather,
  );

  group('exportMaintenanceLog (share)', () {
    test(
      'flattens every item\'s history into rows with resolved names',
      () async {
        final fake = _FakeExportService();
        final container = makeContainer(
          equipment: const [jjccr],
          recordsByEquipment: {
            'e1': [
              record(id: 'r1', equipmentId: 'e1', kindId: 'scrubber-repack'),
              record(id: 'r2', equipmentId: 'e1'),
            ],
          },
          kinds: [
            ServiceKind(
              id: 'scrubber-repack',
              name: 'Scrubber repack',
              createdAt: t0,
              updatedAt: t0,
            ),
          ],
          exportService: fake,
        );

        await notifierOf(container).exportMaintenanceLog();

        expect(fake.sharedRows, hasLength(2));
        expect(fake.sharedRows.first.equipmentName, 'JJ-CCR');
        expect(fake.sharedRows.first.equipmentType, 'Rebreather');
        expect(fake.sharedRows.first.serviceTypeName, 'Scrubber repack');
        // An untagged record still exports, with a blank task column.
        expect(fake.sharedRows.last.serviceTypeName, isEmpty);

        final state = container.read(exportNotifierProvider);
        expect(state.status, ExportStatus.success);
        expect(state.filePath, '/tmp/shared.xlsx');
      },
    );

    test(
      'reports an error and exports nothing when there is no history',
      () async {
        final fake = _FakeExportService();
        final container = makeContainer(
          equipment: const [jjccr],
          recordsByEquipment: const {},
          exportService: fake,
        );

        await notifierOf(container).exportMaintenanceLog();

        expect(fake.sharedRows, isEmpty);
        expect(
          container.read(exportNotifierProvider).status,
          ExportStatus.error,
        );
      },
    );

    test('surfaces a failure from the export service', () async {
      final fake = _FakeExportService(throwOnShare: true);
      final container = makeContainer(
        equipment: const [jjccr],
        recordsByEquipment: {
          'e1': [record(id: 'r1', equipmentId: 'e1')],
        },
        exportService: fake,
      );

      await notifierOf(container).exportMaintenanceLog();

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.error);
      expect(state.message, contains('disk full'));
    });
  });

  group('saveMaintenanceLogToFile', () {
    test('reports success with the chosen path', () async {
      final fake = _FakeExportService();
      final container = makeContainer(
        equipment: const [jjccr],
        recordsByEquipment: {
          'e1': [record(id: 'r1', equipmentId: 'e1')],
        },
        exportService: fake,
      );

      await notifierOf(container).saveMaintenanceLogToFile();

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success);
      expect(state.filePath, '/tmp/saved.xlsx');
    });

    test('a cancelled save panel is idle, never success', () async {
      // FilePicker returns null when the diver dismisses the panel. Reporting
      // that as success would claim a file exists that never got written.
      final fake = _FakeExportService(cancelSave: true);
      final container = makeContainer(
        equipment: const [jjccr],
        recordsByEquipment: {
          'e1': [record(id: 'r1', equipmentId: 'e1')],
        },
        exportService: fake,
      );

      await notifierOf(container).saveMaintenanceLogToFile();

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.idle);
      expect(state.filePath, isNull);
    });

    test('reports an error when there is no history', () async {
      final container = makeContainer(
        equipment: const [],
        recordsByEquipment: const {},
      );

      await notifierOf(container).saveMaintenanceLogToFile();

      expect(container.read(exportNotifierProvider).status, ExportStatus.error);
    });

    test('surfaces a failure from the export service', () async {
      final fake = _FakeExportService(throwOnSave: true);
      final container = makeContainer(
        equipment: const [jjccr],
        recordsByEquipment: {
          'e1': [record(id: 'r1', equipmentId: 'e1')],
        },
        exportService: fake,
      );

      await notifierOf(container).saveMaintenanceLogToFile();

      expect(container.read(exportNotifierProvider).status, ExportStatus.error);
    });
  });
}

/// Captures the rows handed to the export facade so the tests can assert on
/// what would have been written, without touching the filesystem.
class _FakeExportService implements ExportService {
  final bool cancelSave;
  final bool throwOnShare;
  final bool throwOnSave;

  List<MaintenanceLogRow> sharedRows = const [];
  List<MaintenanceLogRow> savedRows = const [];

  _FakeExportService({
    this.cancelSave = false,
    this.throwOnShare = false,
    this.throwOnSave = false,
  });

  @override
  Future<String> exportMaintenanceLog({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) async {
    if (throwOnShare) throw Exception('disk full');
    sharedRows = rows;
    return '/tmp/shared.xlsx';
  }

  @override
  Future<String?> saveMaintenanceLogToFile({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) async {
    if (throwOnSave) throw Exception('disk full');
    savedRows = rows;
    return cancelSave ? null : '/tmp/saved.xlsx';
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
