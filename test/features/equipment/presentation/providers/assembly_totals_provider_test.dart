import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_totals_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

class _FakeEquipmentRepository extends EquipmentRepository {
  final Map<String, EquipmentItem> items;
  final requested = <List<String>>[];

  _FakeEquipmentRepository(this.items);

  @override
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async {
    requested.add(List.of(ids)..sort());
    return [for (final id in ids) ?items[id]];
  }

  @override
  Stream<void> watchEquipmentChanges() => const Stream.empty();

  @override
  Stream<void> watchAttributeChanges() => const Stream.empty();
}

void main() {
  final t0 = DateTime(2026, 1, 1);

  EquipmentItem pocket(
    String id,
    double lead, {
    EquipmentStatus status = EquipmentStatus.active,
  }) => EquipmentItem(
    id: id,
    name: id,
    type: EquipmentType.weightPocket,
    status: status,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.buoyancyKg,
        valueNum: -lead,
      ),
    ],
  );

  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: '$parent>$child',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  ProviderContainer container(
    _FakeEquipmentRepository repository,
    List<EquipmentComponent> edges,
  ) {
    final c = ProviderContainer(
      overrides: [
        equipmentRepositoryProvider.overrideWithValue(repository),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.fromRows(edges),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('sums the active parts, as attaching the assembly would', () async {
    // A lost pocket still marked active stays off a dive, so it stays out
    // of the total too (isGearActive).
    final repository = _FakeEquipmentRepository({
      'left': pocket('left', 4),
      'right': pocket('right', 3),
      'lost': pocket('lost', 2, status: EquipmentStatus.lost),
    });
    final c = container(repository, [
      edge('harness', 'left'),
      edge('harness', 'right'),
      edge('harness', 'lost'),
    ]);

    final totals = await c.read(assemblyTotalsProvider('harness').future);

    expect(totals.partCount, 2);
    expect(totals.buoyancy!.kg, closeTo(-7.0, 1e-9));
    expect(repository.requested, [
      ['left', 'lost', 'right'],
    ]);
  });

  test('an item with no parts reads nothing', () async {
    final repository = _FakeEquipmentRepository(const {});
    final c = container(repository, const []);

    final totals = await c.read(assemblyTotalsProvider('harness').future);

    expect(totals.hasAny, isFalse);
    expect(repository.requested, isEmpty);
  });
}
