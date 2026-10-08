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

/// Parts owned by Bill: the gauge is shared with Anna, the hose is not.
class _SharedPartsRepository extends EquipmentRepository {
  @override
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async => [
    for (final id in ids)
      EquipmentItem(
        id: id,
        diverId: 'bill',
        name: id,
        type: EquipmentType.other,
      ),
  ];

  @override
  Future<List<String>> usableSetMemberIds(
    List<String> ids,
    String diverId,
  ) async => [
    for (final id in ids)
      if (id == 'gauge') id,
  ];
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
    EquipmentComponent(
      id: 'c2',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'gauge',
      sortOrder: 1,
      createdAt: t0,
      updatedAt: t0,
    ),
  ]);

  Future<GearExpansion?> expand(
    WidgetTester tester, {
    required EquipmentRepository repository,
    required String? diverId,
  }) async {
    GearExpansion? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentComponentsIndexProvider.overrideWith((ref) async => index),
          equipmentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async {
                result = await expandGearOnPage(
                  ref,
                  additions: const [(equipmentId: 'reg', viaSetId: null)],
                  existing: const [],
                  existingItems: const [reg],
                  diverId: diverId,
                );
              },
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a shared assembly attaches only the parts the diver sees', (
    tester,
  ) async {
    // Issue #2046: the hose was never shared with Anna, so adding Bill's
    // shared regulator must not put it on her dive.
    final result = await expand(
      tester,
      repository: _SharedPartsRepository(),
      diverId: 'anna',
    );
    expect(result!.newItems.map((e) => e.id), ['gauge']);
    expect(result.provenance.map((p) => p.equipmentId), ['reg', 'gauge']);
  });

  testWidgets('with no diver every part attaches, as before sharing', (
    tester,
  ) async {
    final result = await expand(
      tester,
      repository: _SharedPartsRepository(),
      diverId: null,
    );
    expect(
      result!.newItems.map((e) => e.id),
      unorderedEquals(['hose', 'gauge']),
    );
  });

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
                    diverId: null,
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
                    diverId: null,
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

  test('isGearActive refuses wishlist gear even if flagged active (#2025)', () {
    const wish = EquipmentItem(
      id: 'w',
      name: 'w',
      type: EquipmentType.hose,
      status: EquipmentStatus.wanted,
    );
    expect(isGearActive(wish), isFalse);
  });
}
