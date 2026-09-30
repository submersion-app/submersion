import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
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

/// The cylinder fills CSV export from the Transfer page (cylinder passports
/// phase 5).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tank = EquipmentItem(
    id: 'tank-1',
    name: 'Faber 12',
    type: EquipmentType.tank,
  );

  final fill = CylinderFill(
    id: 'f1',
    diverId: 'me',
    passportId: 'pp-1',
    equipmentId: 'tank-1',
    filledAt: DateTime.utc(2026, 9, 28),
    o2Percent: 32,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  ({ProviderContainer container, _FakeExportService export, _FakeFills repo})
  make({
    List<CylinderFill>? fills,
    String? diverId = 'me',
    bool cancelSave = false,
    bool fail = false,
  }) {
    final export = _FakeExportService(cancelSave: cancelSave, fail: fail);
    final repo = _FakeFills(fills ?? [fill]);
    final container = ProviderContainer(
      overrides: [
        allEquipmentProvider.overrideWith((ref) async => const [tank]),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
        cylinderFillRepositoryProvider.overrideWithValue(repo),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, export: export, repo: repo);
  }

  ExportState stateOf(ProviderContainer c) => c.read(exportNotifierProvider);

  test('shares the fills the validated diver can see, with their '
      'cylinders', () async {
    final t = make();
    await t.container.read(exportNotifierProvider.notifier).exportFillsToCsv();
    expect(t.repo.askedFor, ['me']);
    expect(t.export.shared.map((f) => f.id), ['f1']);
    expect(t.export.equipmentById, {'tank-1': tank});
    expect(t.export.units, same(CsvExportUnits.metric));
    expect(stateOf(t.container).status, ExportStatus.success);
    expect(stateOf(t.container).filePath, '/tmp/fills.csv');
  });

  test('no fills to share says so instead of writing an empty file', () async {
    final t = make(fills: const []);
    await t.container.read(exportNotifierProvider.notifier).exportFillsToCsv();
    expect(t.export.shared, isEmpty);
    expect(stateOf(t.container).status, ExportStatus.error);
    expect(stateOf(t.container).message, 'No cylinder fills to export');
  });

  test('no validated diver reads no fills at all', () async {
    final t = make(diverId: null);
    await t.container.read(exportNotifierProvider.notifier).exportFillsToCsv();
    expect(t.repo.askedFor, isEmpty);
    expect(stateOf(t.container).status, ExportStatus.error);
  });

  test('a failing share reports the error', () async {
    final t = make(fail: true);
    await t.container.read(exportNotifierProvider.notifier).exportFillsToCsv();
    expect(stateOf(t.container).status, ExportStatus.error);
    expect(stateOf(t.container).message, contains('disk full'));
  });

  test('saving writes the same rows under the fills dialog title', () async {
    final t = make();
    await t.container
        .read(exportNotifierProvider.notifier)
        .saveFillsCsvToFile();
    expect(t.repo.askedFor, ['me']);
    expect(t.export.saved.map((f) => f.id), ['f1']);
    expect(t.export.equipmentById, {'tank-1': tank});
    expect(t.export.saveTitle, 'Save Cylinder Fills CSV');
    expect(stateOf(t.container).status, ExportStatus.success);
    expect(stateOf(t.container).filePath, '/tmp/saved.csv');
  });

  test('a cancelled save goes back to idle', () async {
    final t = make(cancelSave: true);
    await t.container
        .read(exportNotifierProvider.notifier)
        .saveFillsCsvToFile();
    expect(stateOf(t.container).status, ExportStatus.idle);
  });

  test('a save with nothing to export says so', () async {
    final t = make(fills: const []);
    await t.container
        .read(exportNotifierProvider.notifier)
        .saveFillsCsvToFile();
    expect(t.export.saved, isEmpty);
    expect(stateOf(t.container).status, ExportStatus.error);
  });

  test('a failing save reports the error', () async {
    final t = make(fail: true);
    await t.container
        .read(exportNotifierProvider.notifier)
        .saveFillsCsvToFile();
    expect(stateOf(t.container).status, ExportStatus.error);
    expect(stateOf(t.container).message, contains('disk full'));
  });
}

class _FakeFills extends CylinderFillRepository {
  _FakeFills(this.all);

  final List<CylinderFill> all;
  final askedFor = <String>[];

  @override
  Future<List<CylinderFill>> getAllVisibleTo(String diverId) async {
    askedFor.add(diverId);
    return all;
  }
}

class _FakeExportService implements ExportService {
  _FakeExportService({this.cancelSave = false, this.fail = false});

  final bool cancelSave;
  final bool fail;
  List<CylinderFill> shared = const [];
  List<CylinderFill> saved = const [];
  Map<String, EquipmentItem>? equipmentById;
  CsvExportUnits? units;
  String? saveTitle;

  @override
  Future<String> exportFillsToCsv(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    if (fail) throw Exception('disk full');
    shared = fills;
    this.equipmentById = equipmentById;
    this.units = units;
    return '/tmp/fills.csv';
  }

  @override
  Future<String?> saveFillsCsvToFile(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    if (fail) throw Exception('disk full');
    saved = fills;
    this.equipmentById = equipmentById;
    this.units = units;
    saveTitle = dialogTitle;
    return cancelSave ? null : '/tmp/saved.csv';
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
