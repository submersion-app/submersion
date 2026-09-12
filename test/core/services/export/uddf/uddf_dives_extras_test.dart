import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

final _epoch = DateTime(2024, 1, 1);
final _row = BuddyWithRole(
  buddy: Buddy(id: 'b1', name: 'Joe', createdAt: _epoch, updatedAt: _epoch),
  role: DiveRole(
    id: DiveRole.buddyId,
    name: 'Buddy',
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
);
final _component = EquipmentComponent(
  id: 'c1',
  parentEquipmentId: 'reg',
  componentEquipmentId: 'first',
  createdAt: _epoch,
  updatedAt: _epoch,
);

class _Buddies extends Fake implements BuddyRepository {
  final calls = <List<String>>[];

  @override
  Future<Map<String, List<BuddyWithRole>>> getBuddiesForDives(
    List<String> diveIds,
  ) async {
    calls.add(diveIds);
    return {
      'd1': [_row],
    };
  }
}

class _Components extends Fake implements EquipmentComponentRepository {
  var calls = 0;

  @override
  Future<List<EquipmentComponent>> getAllComponents() async {
    calls++;
    return [_component];
  }
}

void main() {
  test('fetches participants and components by default', () async {
    final buddies = _Buddies();
    final components = _Components();
    final extras = await resolveDivesExtras(buddies, components, [
      'd1',
    ], const UddfExportOptions());
    expect(buddies.calls, [
      ['d1'],
    ]);
    expect(components.calls, 1);
    expect(extras.diveBuddies['d1'], [_row]);
    expect(extras.components, [_component]);
  });

  test('queries nothing a checkbox left out', () async {
    final buddies = _Buddies();
    final components = _Components();
    final extras = await resolveDivesExtras(buddies, components, [
      'd1',
    ], const UddfExportOptions(includeParticipants: false, includeGear: false));
    expect(buddies.calls, isEmpty);
    expect(components.calls, 0);
    expect(extras.diveBuddies, isEmpty);
    expect(extras.components, isEmpty);
  });

  test('the provider reads both repositories', () async {
    final container = ProviderContainer(
      overrides: [
        buddyRepositoryProvider.overrideWithValue(_Buddies()),
        equipmentComponentRepositoryProvider.overrideWithValue(_Components()),
      ],
    );
    addTearDown(container.dispose);
    final extras = await container.read(uddfDivesExtrasFetchProvider)([
      'd1',
    ], const UddfExportOptions());
    expect(extras.diveBuddies['d1'], [_row]);
    expect(extras.components, [_component]);
  });

  test('empty holds nothing', () {
    const extras = UddfDivesExtras.empty();
    expect(extras.diveBuddies, isEmpty);
    expect(extras.components, isEmpty);
  });
}
