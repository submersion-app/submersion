import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// The page helper is best-effort on the template: a failure reading the
/// parts must attach the addition flat, never crash the add flow.
class _ThrowingEquipmentRepository extends EquipmentRepository {
  @override
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async =>
      throw StateError('database unavailable');
}

void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  final t0 = DateTime(2026, 1, 1);
  final index = ComponentsIndex.fromRows([
    EquipmentComponent(
      id: 'c1',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'hose',
      sortOrder: 0,
      createdAt: t0,
      updatedAt: t0,
    ),
  ]);

  testWidgets('a failed parts fetch attaches the addition flat', (
    tester,
  ) async {
    GearExpansion? result;
    Object? error;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentComponentsIndexProvider.overrideWith((ref) async => index),
          equipmentRepositoryProvider.overrideWithValue(
            _ThrowingEquipmentRepository(),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async {
                try {
                  result = await expandGearOnPage(
                    ref,
                    additions: const [(equipmentId: 'reg', viaSetId: null)],
                    existing: const [],
                    existingItems: const [reg],
                  );
                } catch (e) {
                  error = e;
                }
              },
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    expect(error, isNull);
    expect(result!.provenance.map((p) => p.equipmentId), ['reg']);
    expect(result!.newItems, isEmpty);
  });

  testWidgets('a failed template read attaches the addition flat', (
    tester,
  ) async {
    GearExpansion? result;
    Object? error;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => throw StateError('database unavailable'),
          ),
          equipmentRepositoryProvider.overrideWithValue(
            _ThrowingEquipmentRepository(),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async {
                try {
                  result = await expandGearOnPage(
                    ref,
                    additions: const [(equipmentId: 'reg', viaSetId: 'w')],
                    existing: const [],
                    existingItems: const [reg],
                  );
                } catch (e) {
                  error = e;
                }
              },
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    expect(error, isNull);
    expect(result!.provenance.single.equipmentId, 'reg');
    expect(result!.provenance.single.viaSetId, 'w');
    expect(result!.newItems, isEmpty);
  });
}
