import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show NearbyPeer;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final _t0 = DateTime(2026, 1, 1);
final _now = DateTime(2026, 7, 24);

EquipmentItem _item(String name, EquipmentType type) =>
    EquipmentItem(id: name, name: name, type: type);

ServiceClockStatus _status(
  ServiceClockSeverity severity, {
  DateTime? dueDate,
}) => ServiceClockStatus(
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
  dueDate: dueDate,
  severity: severity,
  now: _now,
);

EquipmentClocks _clocks(
  EquipmentItem item,
  List<ServiceClockStatus> statuses,
) => (item: item, statuses: statuses);

void main() {
  group('nearbyAttentionOf (issue #3731)', () {
    NearbyPeer peer(String name, {String? error, int pairedAt = 0}) =>
        NearbyPeer(
          peerDeviceId: name,
          displayName: name,
          pairedAt: pairedAt,
          lastError: error,
        );

    test('names the first lasting error and counts the rest', () {
      expect(
        nearbyAttentionOf([
          peer('Mac'),
          peer('Old iPad', error: 'newerApp'),
          peer('Phone', error: 'differentLibrary'),
          peer('Tablet', error: 'notPaired'),
        ]),
        (name: 'Old iPad', more: 2),
      );
    });

    test('is null when every error is transient', () {
      expect(
        nearbyAttentionOf([
          peer('Mac', error: 'bluetoothOff'),
          peer('Phone', error: 'unreachable'),
          peer('Tablet'),
        ]),
        isNull,
      );
    });

    test('is null with no paired devices', () {
      expect(nearbyAttentionOf(const []), isNull);
    });

    test('a peer row write that leaves the attention as it was does not '
        'notify the dashboard', () async {
      final rows = StreamController<List<NearbyPeer>>();
      addTearDown(rows.close);
      final container = ProviderContainer(
        overrides: [nearbyPeersProvider.overrideWith((ref) => rows.stream)],
      );
      addTearDown(container.dispose);
      final seen = <NearbyAttention?>[];
      container.listen(
        nearbyAttentionProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      final failing = peer('Old iPad', error: 'newerApp');
      for (var part = 0; part < 5; part++) {
        // A transfer writes the row once per part.
        rows.add([peer('Mac', pairedAt: part), failing]);
        await Future<void>.delayed(Duration.zero);
      }
      expect(seen, [null, (name: 'Old iPad', more: 0)]);
    });

    test('the chip stays while the paired devices reload for a changed '
        'dependency', () async {
      Future<void> settle() async {
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      final loads = <Completer<void>>[];
      var store = 0;
      final storeProvider = Provider<int>((ref) => store);
      final container = ProviderContainer(
        overrides: [
          nearbyPeersProvider.overrideWith((ref) async* {
            ref.watch(storeProvider);
            final load = Completer<void>();
            loads.add(load);
            await load.future;
            yield [peer('Old iPad', error: 'newerApp')];
          }),
        ],
      );
      addTearDown(container.dispose);
      final seen = <NearbyAttention?>[];
      container.listen(
        nearbyAttentionProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      await settle();
      loads.last.complete();
      await settle();
      store++;
      container.invalidate(storeProvider);
      await settle();
      expect(loads, hasLength(2), reason: 'reloading');
      loads.last.complete();
      await settle();
      expect(seen, [null, (name: 'Old iPad', more: 0)]);
    });
  });

  group('gearSeverityGroups', () {
    test('empty input yields no groups', () {
      final result = gearSeverityGroups([]);
      expect(result.overdue, isNull);
      expect(result.dueSoon, isNull);
    });

    test('all-ok gear yields no groups', () {
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.ok),
        ]),
      ]);
      expect(result.overdue, isNull);
      expect(result.dueSoon, isNull);
    });

    test('counts every overdue item, not one per type', () {
      // Four lapsed regulators are four things the diver has to service, and
      // the equipment list the chip opens shows four rows.
      final result = gearSeverityGroups([
        for (var i = 0; i < 4; i++)
          _clocks(_item('Reg $i', EquipmentType.regulator), [
            _status(
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1 + i),
            ),
          ]),
      ]);
      expect(result.overdue?.count, 4);
      expect(result.dueSoon, isNull);
    });

    test('counts every due-soon item, not one per type', () {
      // The count has to match the row count of the filtered list the chip
      // opens, and that list is per item.
      final result = gearSeverityGroups([
        _clocks(_item('Reg early', EquipmentType.regulator), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
        _clocks(_item('Reg late', EquipmentType.regulator), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 9)),
        ]),
      ]);
      expect(result.dueSoon?.count, 2);
    });

    test('an item is counted once however many clocks it has', () {
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 5, 1)),
        ]),
      ]);
      expect(result.overdue?.count, 1);
    });

    test('an overdue item does not also count as due soon', () {
      // Its worst clock is what the diver has to act on, and the overdue
      // list it lands in already carries the item.
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.overdue?.count, 1);
      expect(result.dueSoon, isNull);
    });

    test('separates the two severities into their own groups', () {
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
        ]),
        _clocks(_item('BCD', EquipmentType.bcd), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.overdue?.count, 1);
      expect(result.overdue?.worst.itemName, 'Reg');
      expect(result.dueSoon?.count, 1);
      expect(result.dueSoon?.worst.itemName, 'BCD');
    });

    test('the worst of a group is its earliest due date', () {
      final result = gearSeverityGroups([
        _clocks(_item('Later', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 9)),
        ]),
        _clocks(_item('Earlier', EquipmentType.bcd), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
        ]),
      ]);
      expect(result.overdue?.worst.itemName, 'Earlier');
      expect(result.overdue?.worst.status.dueDate, DateTime(2026, 6, 1));
    });

    test('an undated clock loses to a dated one however it is ordered', () {
      for (final dated in [false, true]) {
        final entries = [
          _clocks(_item('Undated', EquipmentType.regulator), [
            _status(ServiceClockSeverity.dueSoon),
          ]),
          _clocks(_item('Dated', EquipmentType.bcd), [
            _status(
              ServiceClockSeverity.dueSoon,
              dueDate: DateTime(2026, 8, 1),
            ),
          ]),
        ];
        final result = gearSeverityGroups(
          dated ? entries.reversed.toList() : entries,
        );
        expect(result.dueSoon?.worst.itemName, 'Dated');
      }
    });

    test('the worst of an item is its own earliest clock', () {
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 5, 1)),
        ]),
      ]);
      expect(result.overdue?.worst.status.dueDate, DateTime(2026, 5, 1));
    });

    test('carries the worst item id so a lone chip can deep-link', () {
      // Id and name deliberately differ: the chip labels with the name but
      // must route with the id.
      final result = gearSeverityGroups([
        _clocks(
          const EquipmentItem(
            id: 'reg-b-id',
            name: 'Reg B',
            type: EquipmentType.regulator,
          ),
          [
            _status(
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1),
            ),
          ],
        ),
      ]);
      expect(result.overdue?.worst.itemId, 'reg-b-id');
      expect(result.overdue?.worst.itemName, 'Reg B');
    });

    test('an item with no clocks at all is ignored', () {
      final result = gearSeverityGroups([
        _clocks(_item('Untracked', EquipmentType.regulator), const []),
      ]);
      expect(result.overdue, isNull);
      expect(result.dueSoon, isNull);
    });
  });
}
