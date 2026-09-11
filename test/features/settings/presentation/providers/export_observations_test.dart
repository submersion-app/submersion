import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/excel/observations_excel_export_service.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The gear check-in CSV export (condition phase 3a).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const reg = EquipmentItem(
    id: 'reg',
    name: 'Apeks XTX',
    type: EquipmentType.regulator,
  );

  EquipmentObservation checkIn(String id, String diverId, {String? diveId}) =>
      EquipmentObservation(
        id: id,
        equipmentId: 'reg',
        diverId: diverId,
        diveId: diveId,
        observedAt: DateTime.utc(2026, 3, 1),
        status: ObservationStatus.ok,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  ({ProviderContainer container, _FakeExportService export, _FakeRepo repo})
  make({
    List<EquipmentObservation>? observations,
    List<Dive>? scopedDives,
    bool cancelSave = false,
    bool throwOnShare = false,
  }) {
    final export = _FakeExportService(
      cancelSave: cancelSave,
      throwOnShare: throwOnShare,
    );
    final repo = _FakeRepo(
      observations ??
          [checkIn('mine', 'me', diveId: 'd1'), checkIn('theirs', 'buddy')],
    );
    final container = ProviderContainer(
      overrides: [
        allEquipmentProvider.overrideWith((ref) async => const [reg]),
        divesProvider.overrideWith(
          (ref) async =>
              scopedDives ??
              [
                Dive(
                  id: 'd1',
                  diveNumber: 42,
                  dateTime: DateTime.utc(2026, 3, 1),
                ),
              ],
        ),
        diveRepositoryProvider.overrideWithValue(_FakeDiveRepo()),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        equipmentObservationRepositoryProvider.overrideWithValue(repo),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, export: export, repo: repo);
  }

  test(
    'shares only the active diver\'s check-ins, with the dive number',
    () async {
      // A shared item can carry another diver's check-in; the export is
      // scoped to the diver whose gear and dives it already carries.
      final t = make();
      await t.container
          .read(exportNotifierProvider.notifier)
          .exportObservationsToCsv();
      expect(t.repo.askedFor, ['me']);
      expect(t.export.shared.map((r) => r.observation.id), ['mine']);
      expect(t.export.shared.single.diveNumber, 42);
      expect(t.export.shared.single.equipmentName, 'Apeks XTX');
      expect(
        t.container.read(exportNotifierProvider).status,
        ExportStatus.success,
      );
    },
  );

  test('a check-in keeps its dive number when the dive list is scoped '
      'to a stale diver id', () async {
    // The dive list follows the raw diver id while the check-ins follow the
    // validated one. A stale raw id empties the list, which used to leave
    // every check-in row without its dive number.
    final t = make(scopedDives: const []);
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportObservationsToCsv();
    expect(t.export.shared.single.diveNumber, 42);
  });

  test('nothing to export says so instead of writing an empty file', () async {
    final t = make(observations: const []);
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportObservationsToCsv();
    expect(t.export.shared, isEmpty);
    expect(t.container.read(exportNotifierProvider).status, ExportStatus.error);
  });

  test('a failing share reports the error', () async {
    final t = make(throwOnShare: true);
    await t.container
        .read(exportNotifierProvider.notifier)
        .exportObservationsToCsv();
    expect(t.container.read(exportNotifierProvider).status, ExportStatus.error);
  });

  test('saving writes the same scoped rows', () async {
    final t = make();
    await t.container
        .read(exportNotifierProvider.notifier)
        .saveObservationsCsvToFile();
    expect(t.repo.askedFor, ['me']);
    expect(t.export.saved.map((r) => r.observation.id), ['mine']);
    expect(t.export.saveTitle, 'Save Gear Check-ins CSV');
    expect(
      t.container.read(exportNotifierProvider).status,
      ExportStatus.success,
    );
  });

  test('a cancelled save goes back to idle', () async {
    final t = make(cancelSave: true);
    await t.container
        .read(exportNotifierProvider.notifier)
        .saveObservationsCsvToFile();
    expect(t.container.read(exportNotifierProvider).status, ExportStatus.idle);
  });

  test('a save with nothing to export says so', () async {
    final t = make(observations: const []);
    await t.container
        .read(exportNotifierProvider.notifier)
        .saveObservationsCsvToFile();
    expect(t.export.saved, isEmpty);
    expect(t.container.read(exportNotifierProvider).status, ExportStatus.error);
  });
}

class _FakeRepo implements EquipmentObservationRepository {
  final List<EquipmentObservation> all;
  final askedFor = <String?>[];

  _FakeRepo(this.all);

  @override
  Future<List<EquipmentObservation>> getAll({String? diverId}) async {
    askedFor.add(diverId);
    return [
      for (final o in all)
        if (diverId == null || o.diverId == diverId) o,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeDiveRepo implements DiveRepository {
  @override
  Future<List<DiveSummary>> getSummariesByIds(List<String> ids) async => [
    for (final id in ids)
      if (id == 'd1')
        DiveSummary(
          id: 'd1',
          diveNumber: 42,
          dateTime: DateTime.utc(2026, 3, 1),
          sortTimestamp: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch,
        ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeExportService implements ExportService {
  final bool cancelSave;
  final bool throwOnShare;
  List<ObservationExportRow> shared = const [];
  List<ObservationExportRow> saved = const [];
  String? saveTitle;

  _FakeExportService({this.cancelSave = false, this.throwOnShare = false});

  @override
  Future<String> exportObservationsToCsv(
    List<ObservationExportRow> rows,
  ) async {
    if (throwOnShare) throw Exception('disk full');
    shared = rows;
    return '/tmp/observations.csv';
  }

  @override
  Future<String?> saveObservationsCsvToFile(
    List<ObservationExportRow> rows, {
    required String dialogTitle,
  }) async {
    saved = rows;
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
