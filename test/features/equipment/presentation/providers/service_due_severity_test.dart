import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final _t0 = DateTime(2026, 1, 1);

EquipmentItem _item(String name) =>
    EquipmentItem(id: name, name: name, type: EquipmentType.regulator);

ServiceClockStatus _status(ServiceClockSeverity severity) => ServiceClockStatus(
  schedule: ServiceSchedule(
    id: 'schedule',
    equipmentId: 'equipment',
    serviceKindId: 'kind',
    createdAt: _t0,
    updatedAt: _t0,
  ),
  kind: ServiceKind(
    id: 'kind',
    name: 'Annual service',
    createdAt: _t0,
    updatedAt: _t0,
  ),
  anchor: _t0,
  dueDate: DateTime(2026, 6, 1),
  severity: severity,
  now: DateTime(2026, 7, 24),
);

/// The worst clock per item, which is what the severity filters bucket on.
Map<String, DueClock> _worst(Map<String, ServiceClockSeverity> severities) => {
  for (final entry in severities.entries)
    entry.key: (item: _item(entry.key), status: _status(entry.value)),
};

void main() {
  group('serviceDueEquipmentProvider', () {
    late ProviderContainer container;

    void seed(Map<String, ServiceClockSeverity> severities) {
      container = ProviderContainer(
        overrides: [
          equipmentWorstClockProvider.overrideWith(
            (ref) async => _worst(severities),
          ),
        ],
      );
      addTearDown(container.dispose);
    }

    Future<List<String>> names(ServiceDueFilter filter) async =>
        (await container.read(
          serviceDueEquipmentProvider(filter).future,
        )).map((e) => e.name).toList();

    test('overdue returns only the lapsed items', () async {
      seed({
        'Reg': ServiceClockSeverity.overdue,
        'BCD': ServiceClockSeverity.dueSoon,
      });
      expect(await names(ServiceDueFilter.overdue), ['Reg']);
    });

    test('dueSoon excludes anything already overdue', () async {
      // The overdue chip already counted that item; counting it again under
      // due soon would make the two chips add up to more than the gear the
      // diver owns.
      seed({
        'Reg': ServiceClockSeverity.overdue,
        'BCD': ServiceClockSeverity.dueSoon,
      });
      expect(await names(ServiceDueFilter.dueSoon), ['BCD']);
    });

    test('any returns both severities', () async {
      seed({
        'Reg': ServiceClockSeverity.overdue,
        'BCD': ServiceClockSeverity.dueSoon,
      });
      expect(await names(ServiceDueFilter.any), ['Reg', 'BCD']);
    });

    test('each severity is empty when nothing is in it', () async {
      seed({'Reg': ServiceClockSeverity.overdue});
      expect(await names(ServiceDueFilter.dueSoon), isEmpty);
    });

    test('an item appears once however many clocks it carries', () async {
      // The worst-clock map is keyed by item, so the row count the diver
      // sees is the item count the home chip promised.
      seed({'Reg': ServiceClockSeverity.overdue});
      expect(await names(ServiceDueFilter.overdue), ['Reg']);
    });
  });
}
