import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// The rollup answers "is anything in this rig due", naming the part
/// (issue #1487). It derives from the all-items evaluation that keeps ok
/// clocks, so it can also answer "when is this rig next due".
void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 7, 1);

  ServiceKind kind(String id) => ServiceKind(
    id: id,
    name: id,
    defaultIntervalDays: 365,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  ServiceClockStatus clock(
    String equipmentId,
    String kindId,
    ServiceClockSeverity severity, {
    DateTime? due,
  }) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's-$equipmentId-$kindId',
      equipmentId: equipmentId,
      serviceKindId: kindId,
      createdAt: t0,
      updatedAt: t0,
    ),
    kind: kind(kindId),
    anchor: t0,
    dueDate: due,
    severity: severity,
    now: now,
  );

  EquipmentItem item(String id) =>
      EquipmentItem(id: id, name: 'Name $id', type: EquipmentType.regulator);

  var seq = 0;
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: 'c${seq++}',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  ProviderContainer container({
    required List<EquipmentClocks> clocks,
    required List<EquipmentComponent> edges,
  }) {
    final c = ProviderContainer(
      overrides: [
        activeEquipmentClocksProvider.overrideWith((ref) async => clocks),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.fromRows(edges),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('an item with its own clocks rolls up to its own worst', () async {
    final c = container(
      clocks: [
        (
          item: item('reg'),
          statuses: [
            clock(
              'reg',
              'svc',
              ServiceClockSeverity.dueSoon,
              due: DateTime(2026, 8, 1),
            ),
            clock(
              'reg',
              'other',
              ServiceClockSeverity.ok,
              due: DateTime(2027, 1, 1),
            ),
          ],
        ),
      ],
      edges: const [],
    );
    final rollup = await c.read(equipmentRollupClockProvider.future);
    expect(rollup['reg']!.ownerId, 'reg');
    expect(rollup['reg']!.status.severity, ServiceClockSeverity.dueSoon);
  });

  test(
    'a descendant overdue clock beats the parent and names the part',
    () async {
      final c = container(
        clocks: [
          (
            item: item('reg'),
            statuses: [
              clock(
                'reg',
                'svc',
                ServiceClockSeverity.ok,
                due: DateTime(2027, 1, 1),
              ),
            ],
          ),
          (
            item: item('hose'),
            statuses: [
              clock(
                'hose',
                'hose-swap',
                ServiceClockSeverity.overdue,
                due: DateTime(2026, 1, 1),
              ),
            ],
          ),
        ],
        edges: [edge('reg', 'hose')],
      );
      final rollup = await c.read(equipmentRollupClockProvider.future);
      expect(rollup['reg']!.ownerId, 'hose');
      expect(rollup['reg']!.ownerName, 'Name hose');
      expect(rollup['reg']!.status.kind.id, 'hose-swap');
      // The part's own entry is itself.
      expect(rollup['hose']!.ownerId, 'hose');
    },
  );

  test(
    'a nested descendant is reached and the earliest date breaks ties',
    () async {
      final c = container(
        clocks: [
          (item: item('kit'), statuses: const []),
          (
            item: item('reg'),
            statuses: [
              clock(
                'reg',
                'a',
                ServiceClockSeverity.dueSoon,
                due: DateTime(2026, 9, 1),
              ),
            ],
          ),
          (
            item: item('hose'),
            statuses: [
              clock(
                'hose',
                'b',
                ServiceClockSeverity.dueSoon,
                due: DateTime(2026, 8, 1),
              ),
            ],
          ),
        ],
        edges: [edge('kit', 'reg'), edge('reg', 'hose')],
      );
      final rollup = await c.read(equipmentRollupClockProvider.future);
      expect(rollup['kit']!.ownerId, 'hose');
      expect(rollup['kit']!.status.dueDate, DateTime(2026, 8, 1));
    },
  );

  test('an assembly with no clocks anywhere has no entry', () async {
    final c = container(
      clocks: [
        (item: item('reg'), statuses: const []),
        (item: item('hose'), statuses: const []),
      ],
      edges: [edge('reg', 'hose')],
    );
    final rollup = await c.read(equipmentRollupClockProvider.future);
    expect(rollup, isEmpty);
  });

  test(
    'a retired descendant is not in the active evaluation and is skipped',
    () async {
      final c = container(
        clocks: [(item: item('reg'), statuses: const [])],
        edges: [edge('reg', 'old-hose')],
      );
      final rollup = await c.read(equipmentRollupClockProvider.future);
      expect(rollup.containsKey('reg'), isFalse);
    },
  );

  test(
    'a diamond counts a shared part once and rolls up through a retired node',
    () async {
      // kit > reg > hose and kit > hose: the hose is reachable twice. The
      // middle node "old" is retired (absent from the active evaluation) but
      // its active child still reaches the root through it.
      final c = container(
        clocks: [
          (item: item('kit'), statuses: const []),
          (item: item('reg'), statuses: const []),
          (
            item: item('hose'),
            statuses: [
              clock(
                'hose',
                'swap',
                ServiceClockSeverity.dueSoon,
                due: DateTime(2026, 8, 1),
              ),
            ],
          ),
          (
            item: item('cell'),
            statuses: [
              clock(
                'cell',
                'cal',
                ServiceClockSeverity.overdue,
                due: DateTime(2026, 1, 1),
              ),
            ],
          ),
        ],
        edges: [
          edge('kit', 'reg'),
          edge('reg', 'hose'),
          edge('kit', 'hose'),
          edge('kit', 'old'),
          edge('old', 'cell'),
        ],
      );
      final rollup = await c.read(equipmentRollupClockProvider.future);
      expect(rollup['kit']!.ownerId, 'cell');
      expect(rollup['reg']!.ownerId, 'hose');
      expect(rollup.containsKey('old'), isFalse);
    },
  );

  test('isMoreUrgentClock orders by severity then date, null date last', () {
    final overdue = clock('x', 'a', ServiceClockSeverity.overdue);
    final soonEarly = clock(
      'x',
      'b',
      ServiceClockSeverity.dueSoon,
      due: DateTime(2026, 8, 1),
    );
    final soonLate = clock(
      'x',
      'c',
      ServiceClockSeverity.dueSoon,
      due: DateTime(2026, 9, 1),
    );
    final soonNoDate = clock('x', 'd', ServiceClockSeverity.dueSoon);
    expect(isMoreUrgentClock(overdue, soonEarly), isTrue);
    expect(isMoreUrgentClock(soonEarly, soonLate), isTrue);
    expect(isMoreUrgentClock(soonLate, soonEarly), isFalse);
    expect(isMoreUrgentClock(soonEarly, soonNoDate), isTrue);
    expect(isMoreUrgentClock(soonNoDate, soonEarly), isFalse);
  });
}
