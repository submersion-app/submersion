import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Both full UDDF export paths pass the diver's visible fills, custom
/// service kinds and clocks (#2651).
///
/// The round trips prove writer and parser agree; this proves the app
/// reaches them. Without it the export could pass no fills forever while
/// every round-trip test stayed green.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CylinderFill fill(String id, String diverId) => CylinderFill(
    id: id,
    diverId: diverId,
    passportId: 'pp-$id',
    filledAt: DateTime(2026, 9, 28),
    o2Percent: 32,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    for (final id in ['me', 'other']) {
      await DiverRepository().createDiver(
        Diver(
          id: id,
          name: id,
          isDefault: id == 'me',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    // The full export refuses a library with no dives, sites or gear.
    await SiteRepository().createSite(
      const DiveSite(id: '', name: 'House reef', diverId: 'me'),
    );
    // Unlinked fills are visible only to the diver who logged them.
    await CylinderFillRepository().create(fill('mine', 'me'));
    await CylinderFillRepository().create(fill('theirs', 'other'));
    // A tank whose clock uses another diver's custom kind, as a shared
    // item's clocks can: that kind must travel with the clock.
    final tank = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        name: 'AL80',
        type: EquipmentType.tank,
        diverId: 'me',
      ),
    );
    await ServiceKindRepository().createKind(
      ServiceKind(
        id: 'k-theirs',
        diverId: 'other',
        name: 'Valve rebuild',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: 'c-theirs',
        equipmentId: tank.id,
        serviceKindId: 'k-theirs',
        createdAt: now,
        updatedAt: now,
      ),
    );
    // A custom service kind (issue #2651); the built-ins are seeded.
    await ServiceKindRepository().createKind(
      ServiceKind(
        id: 'k-mine',
        diverId: 'me',
        name: 'Burst disc',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer make(_CapturingExportService export) {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final save in [false, true]) {
    test(
      "${save ? 'saving' : 'sharing'} passes only the diver's fills",
      () async {
        final export = _CapturingExportService();
        final container = make(export);
        final notifier = container.read(exportNotifierProvider.notifier);
        await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

        final state = container.read(exportNotifierProvider);
        expect(state.status, ExportStatus.success, reason: state.message);
        expect(export.fills?.map((f) => f.id), ['mine']);
        // Custom kinds only (built-ins are fixed in every database): the
        // diver's own, and any an exported clock or record refers to.
        expect(
          export.serviceKinds?.map((k) => k.id),
          unorderedEquals(['k-mine', 'k-theirs']),
        );
        expect(export.serviceSchedulesByItem, isNotNull);
      },
    );
  }
}

class _CapturingExportService implements ExportService {
  List<CylinderFill>? fills;
  List<ServiceKind>? serviceKinds;
  Map<String, List<ServiceSchedule>>? serviceSchedulesByItem;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportAllDataToUddf || name == #saveAllDataToUddfFile) {
      fills = invocation.namedArguments[#fills] as List<CylinderFill>?;
      serviceKinds =
          invocation.namedArguments[#serviceKinds] as List<ServiceKind>?;
      serviceSchedulesByItem =
          invocation.namedArguments[#serviceSchedulesByItem]
              as Map<String, List<ServiceSchedule>>?;
      return name == #exportAllDataToUddf
          ? Future<String>.value('/tmp/export.uddf')
          : Future<String?>.value('/tmp/export.uddf');
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
