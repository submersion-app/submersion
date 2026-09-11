import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The two full UDDF export paths read the dive list through the validated
/// diver, the same scope as the export's gear and check-ins, so a stale raw
/// diver id neither aborts the export nor strands a check-in's dive link.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String diveId;
  late String regId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        diverId: 'me',
        name: 'Apeks XTX',
        type: EquipmentType.regulator,
      ),
    );
    final dive = await DiveRepository().createDive(
      Dive(id: '', diverId: 'me', diveNumber: 7, dateTime: now),
    );
    diveId = dive.id;
    regId = reg.id;
    await EquipmentObservationRepository().create(
      equipmentId: reg.id,
      diverId: 'me',
      diveId: diveId,
      observedAt: now,
      status: ObservationStatus.ok,
    );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer make(_CapturingExportService export) {
    final container = ProviderContainer(
      overrides: [
        // A raw id naming no diver: the state a restore or a sync that
        // removed the active diver leaves until the notifier heals it.
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'ghost',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sharing exports the validated diver\'s dives and check-ins', () async {
    final export = _CapturingExportService();
    final container = make(export);
    await container.read(exportNotifierProvider.notifier).exportDivesToUddf();

    final state = container.read(exportNotifierProvider);
    expect(state.status, ExportStatus.success, reason: state.message);
    expect(export.dives.map((d) => d.id), [diveId]);
    expect(export.observations.single.diveId, diveId);
  });

  test('saving exports the validated diver\'s dives and check-ins', () async {
    final export = _CapturingExportService();
    final container = make(export);
    await container.read(exportNotifierProvider.notifier).saveUddfToFile();

    final state = container.read(exportNotifierProvider);
    expect(state.status, ExportStatus.success, reason: state.message);
    expect(export.dives.map((d) => d.id), [diveId]);
    expect(export.observations.single.diveId, diveId);
  });

  for (final save in [false, true]) {
    final path = save ? 'saving' : 'sharing';

    test('$path a library with gear and a bench check-in but no dives '
        'exports them', () async {
      // The builder takes an empty dive list; only a library with no dives,
      // sites or gear at all is refused, as the workbook does.
      await DiveRepository().deleteDive(diveId);
      final export = _CapturingExportService();
      final container = make(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      expect(export.dives, isEmpty);
      expect(export.observations.single.diveId, isNull);
    });

    test('$path an empty library is refused', () async {
      await DiveRepository().deleteDive(diveId);
      await EquipmentRepository().deleteEquipment(regId);
      final export = _CapturingExportService();
      final container = make(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.error);
      expect(state.message, 'No data to export');
    });

    test('$path the workbook uses the validated diver\'s dives', () async {
      // Its check-ins sheet is scoped to the validated diver; the dives
      // sheet must be too, or a stale raw id leaves it empty beside them.
      final export = _CapturingExportService();
      final container = make(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save ? notifier.saveExcelToFile() : notifier.exportToExcel());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      expect(export.dives.map((d) => d.id), [diveId]);
    });
  }
}

class _CapturingExportService implements ExportService {
  List<Dive> dives = const [];
  List<EquipmentObservation> observations = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportAllDataToUddf || name == #saveAllDataToUddfFile) {
      dives = invocation.namedArguments[#dives] as List<Dive>;
      observations =
          invocation.namedArguments[#observations]
              as List<EquipmentObservation>;
      // The share path returns a path; the save path may return null.
      return name == #exportAllDataToUddf
          ? Future<String>.value('/tmp/export.uddf')
          : Future<String?>.value('/tmp/export.uddf');
    }
    if (name == #exportToExcel || name == #saveExcelToFile) {
      dives = invocation.namedArguments[#dives] as List<Dive>;
      return name == #exportToExcel
          ? Future<String>.value('/tmp/export.xlsx')
          : Future<String?>.value('/tmp/export.xlsx');
    }
    return null;
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
