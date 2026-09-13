import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
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
final _role = DiveRole(
  id: 'role-photo',
  diverId: 'diver-1',
  name: 'Photographer',
  createdAt: _epoch,
  updatedAt: _epoch,
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
  Future<Map<String, List<BuddyWithRole>>> getBuddiesForDivesWithCertifications(
    List<String> diveIds,
  ) async {
    calls.add(diveIds);
    return {
      'd1': [_row],
    };
  }
}

class _Components extends Fake implements EquipmentComponentRepository {
  final calls = <List<String>>[];

  @override
  Future<List<EquipmentComponent>> getComponentsForDives(
    List<String> diveIds,
  ) async {
    calls.add(diveIds);
    return [_component];
  }
}

class _Roles extends Fake implements DiveRoleRepository {
  final calls = <String?>[];

  @override
  Future<List<DiveRole>> getAllDiveRoles({String? diverId}) async {
    calls.add(diverId);
    return [_role];
  }
}

void main() {
  test('fetches participants and components by default', () async {
    final buddies = _Buddies();
    final components = _Components();
    final extras = await resolveDivesExtras(
      buddies,
      components,
      _Roles(),
      'diver-1',
      ['d1'],
      const UddfExportOptions(),
    );
    expect(buddies.calls, [
      ['d1'],
    ]);
    expect(components.calls, [
      ['d1'],
    ]);
    expect(extras.diveBuddies['d1'], [_row]);
    expect(extras.components, [_component]);
  });

  test('queries nothing a checkbox left out', () async {
    final buddies = _Buddies();
    final components = _Components();
    final extras = await resolveDivesExtras(
      buddies,
      components,
      _Roles(),
      'diver-1',
      ['d1'],
      const UddfExportOptions(includeParticipants: false, includeGear: false),
    );
    expect(buddies.calls, isEmpty);
    expect(components.calls, isEmpty);
    expect(extras.diveBuddies, isEmpty);
    expect(extras.components, isEmpty);
  });

  test('fetches the diver\'s own roles whatever the checkboxes', () async {
    // Every dive writes its diver's role, participants or not, so the file
    // must be able to define a custom one either way.
    final roles = _Roles();
    final extras = await resolveDivesExtras(
      _Buddies(),
      _Components(),
      roles,
      'diver-1',
      ['d1'],
      const UddfExportOptions(includeParticipants: false, includeGear: false),
    );
    expect(roles.calls, ['diver-1']);
    expect(extras.diveRoles, [_role]);
  });

  test('the provider reads every repository for the active diver', () async {
    final roles = _Roles();
    final container = ProviderContainer(
      overrides: [
        buddyRepositoryProvider.overrideWithValue(_Buddies()),
        equipmentComponentRepositoryProvider.overrideWithValue(_Components()),
        diveRoleRepositoryProvider.overrideWithValue(roles),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      ],
    );
    addTearDown(container.dispose);
    final extras = await container.read(uddfDivesExtrasFetchProvider)([
      'd1',
    ], const UddfExportOptions());
    expect(extras.diveBuddies['d1'], [_row]);
    expect(extras.components, [_component]);
    expect(roles.calls, ['diver-1']);
    expect(extras.diveRoles, [_role]);
  });

  test('empty holds nothing', () {
    const extras = UddfDivesExtras.empty();
    expect(extras.diveBuddies, isEmpty);
    expect(extras.components, isEmpty);
    expect(extras.diveRoles, isEmpty);
  });
}
