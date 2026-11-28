import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_usage_history.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';

ProviderContainer _container(ExposureInputs? inputs) {
  final container = ProviderContainer(
    overrides: [
      equipmentExposureInputsProvider(
        'reg',
      ).overrideWith((ref) async => inputs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('builds from the exposure inputs with today from the clock', () async {
    final container = _container((
      item: const EquipmentItem(
        id: 'reg',
        name: 'Regulator',
        type: EquipmentType.regulator,
      ),
      parent: null,
      children: const <EquipmentItem>[],
      samples: [
        EquipmentExposureSample(
          date: DateTime.utc(2026, 11, 27, 22),
          durationSeconds: 3600,
        ),
        EquipmentExposureSample(
          date: DateTime.utc(2026, 1, 3),
          durationSeconds: 1800,
        ),
      ],
      classifier: const ExposureClassifier(),
    ));

    // Local 23:30 on Nov 27: today is the device's local date, so the
    // evening dive reads as today and the window ends with November.
    final history = await withClock(
      Clock.fixed(DateTime(2026, 11, 27, 23, 30)),
      () => container.read(equipmentUsageHistoryProvider('reg').future),
    );

    expect(history.monthly.last.start, DateTime.utc(2026, 11));
    expect(history.divesLast12Months, 2);
    expect(history.lastDivedAgo, (unit: LastDivedUnit.today, count: 0));
  });

  test('an unknown item reads as the empty history', () async {
    final container = _container(null);

    final history = await container.read(
      equipmentUsageHistoryProvider('reg').future,
    );

    expect(history, EquipmentUsageHistory.empty);
  });
}
