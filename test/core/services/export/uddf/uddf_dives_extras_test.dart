import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
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

/// Site classification with nothing classified (issue #1765).
class _Classification extends Fake implements SiteClassificationRepository {
  final siteQueries = <List<String>>[];

  @override
  Future<List<String>> getSiteIdsForDives(List<String> diveIds) async {
    siteQueries.add(diveIds);
    return const [];
  }

  @override
  Future<Map<String, List<String>>> getTypeIdsBySite(
    List<String> siteIds,
  ) async => const {};

  @override
  Future<Map<String, List<String>>> getTagIdsBySite(
    List<String> siteIds,
  ) async => const {};

  @override
  Future<Map<String, List<Tag>>> getTagsBySite() async => const {};
}

class _SiteTypes extends Fake implements SiteTypeRepository {}

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
    expect(components.calls, [
      ['d1'],
    ]);
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
    expect(components.calls, isEmpty);
    expect(extras.diveBuddies, isEmpty);
    expect(extras.components, isEmpty);
  });

  test('the provider reads every repository', () async {
    final classification = _Classification();
    final container = ProviderContainer(
      overrides: [
        buddyRepositoryProvider.overrideWithValue(_Buddies()),
        equipmentComponentRepositoryProvider.overrideWithValue(_Components()),
        siteClassificationRepositoryProvider.overrideWithValue(classification),
        siteTypeRepositoryProvider.overrideWithValue(_SiteTypes()),
      ],
    );
    addTearDown(container.dispose);
    final extras = await container.read(uddfDivesExtrasFetchProvider)([
      'd1',
    ], const UddfExportOptions());
    expect(extras.diveBuddies['d1'], [_row]);
    expect(extras.components, [_component]);
    expect(classification.siteQueries, [
      ['d1'],
    ]);
  });

  test('empty holds nothing', () {
    const extras = UddfDivesExtras.empty();
    expect(extras.diveBuddies, isEmpty);
    expect(extras.components, isEmpty);
  });
}
