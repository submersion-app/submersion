import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_condition_refresher.dart';
import 'package:submersion/features/equipment/data/services/equipment_findings_pass.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

import '../../../../helpers/test_database.dart';

/// Refreshes every item but [failing], which throws.
class _Refresher extends EquipmentConditionRefresher {
  final String failing;
  final visited = <String>[];

  _Refresher(this.failing)
    : super(
        equipment: EquipmentRepository(),
        observations: EquipmentObservationRepository(),
        incidents: IncidentRepository(),
        transmitters: TransmitterRepository(),
        summaries: DiveSensorSummaryRepository(),
        findings: EquipmentFindingsRepository(),
      );

  @override
  Future<List<EquipmentFinding>> ensureCurrentItem(
    EquipmentItem item, {
    required ExposureThresholds thresholds,
    required bool engineEnabled,
    DateTime? now,
  }) async {
    visited.add(item.id);
    if (item.id == failing) throw StateError('bad evidence');
    return const [];
  }
}

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  test(
    'an item whose refresh throws is counted and the pass goes on',
    () async {
      // One item's bad evidence must not abort the pass over the rest.
      final refresher = _Refresher('bad');
      final result = await EquipmentFindingsPass(refresher: refresher).run(
        items: const [
          EquipmentItem(id: 'bad', name: 'Bad', type: EquipmentType.regulator),
          EquipmentItem(id: 'good', name: 'Good', type: EquipmentType.bcd),
        ],
        thresholds: ExposureThresholds.defaults,
      );
      expect(refresher.visited, ['bad', 'good']);
      expect(result.items, 2);
      expect(result.failed, 1);
      expect(result.cancelled, isFalse);
    },
  );

  test('the pass reads the active diver\'s settings', () async {
    // No active diver: the defaults the app would show.
    final defaults = await EquipmentFindingsPass.loadActiveDiverInputs();
    expect(defaults.diverId, isNull);
    expect(defaults.engineEnabled, isTrue);
    expect(defaults.thresholds, ExposureThresholds.defaults);

    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'Me',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await DiverRepository().setActiveDiverIdInSettings('me');
    await DiverSettingsRepository().createSettingsForDiver(
      'me',
      settings: const AppSettings(
        conditionEngineEnabled: false,
        coldWaterThresholdC: 12,
      ),
    );
    final inputs = await EquipmentFindingsPass.loadActiveDiverInputs();
    expect(inputs.diverId, 'me');
    expect(inputs.engineEnabled, isFalse);
    expect(inputs.thresholds.coldWaterC, 12);
  });
}
