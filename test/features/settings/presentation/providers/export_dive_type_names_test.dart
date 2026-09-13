import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The dives CSV from the Transfer page names each dive type as the diver
/// did, which needs the diver's dive types handed to the export (#1834).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final custom = DiveTypeEntity(
    id: 'search_recovery_1a2b3c4d',
    diverId: 'diver-1',
    name: 'Search & Recovery',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  ProviderContainer makeContainer(_RecordingExportService exportService) {
    final container = ProviderContainer(
      overrides: [
        // The dives CSV reads the logbook fresh through the validated diver id
        // (#1861), not through the cached divesProvider.
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
        diveRepositoryProvider.overrideWithValue(
          _FixedDivesRepository([
            Dive(
              id: 'd1',
              dateTime: DateTime(2026, 1, 1),
              diveTypeIds: [custom.id],
            ),
          ]),
        ),
        diveTypesProvider.overrideWith((ref) async => [custom]),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(exportService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sharing the dives CSV passes the diver\'s dive types', () async {
    final exportService = _RecordingExportService();
    final container = makeContainer(exportService);

    await container.read(exportNotifierProvider.notifier).exportDivesToCsv();

    expect(exportService.diveTypesById, {custom.id: custom});
  });

  test('saving the dives CSV passes the diver\'s dive types', () async {
    final exportService = _RecordingExportService();
    final container = makeContainer(exportService);

    await container.read(exportNotifierProvider.notifier).saveDivesCsvToFile();

    expect(exportService.diveTypesById, {custom.id: custom});
  });
}

/// Serves a fixed dive list as the diver's logbook.
class _FixedDivesRepository implements DiveRepository {
  _FixedDivesRepository(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getAllDives({String? diverId}) async => dives;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingExportService implements ExportService {
  Map<String, DiveTypeEntity>? diveTypesById;

  @override
  Future<String> exportDivesToCsv(
    List<Dive> dives, {
    Map<String, DiveTypeEntity> diveTypesById = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.diveTypesById = diveTypesById;
    return '/tmp/dives.csv';
  }

  @override
  Future<String?> saveDivesCsvToFile(
    List<Dive> dives, {
    required String dialogTitle,
    Map<String, DiveTypeEntity> diveTypesById = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.diveTypesById = diveTypesById;
    return '/tmp/dives.csv';
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
