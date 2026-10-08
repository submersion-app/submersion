import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_transfer_gate.dart';

/// Who sees "Transfer to..." on the item page (issue #2852).
void main() {
  const item = EquipmentItem(
    id: 'light',
    diverId: 'bill',
    name: 'Light',
    type: EquipmentType.light,
  );

  bool gate(AsyncValue<String?> active, {bool multipleDivers = true}) =>
      canTransferEquipmentOnceKnown(
        active,
        item,
        multipleDivers: multipleDivers,
      );

  test('the owner with two or more profiles may transfer', () {
    expect(gate(const AsyncValue.data('bill')), isTrue);
  });

  test('another profile may not', () {
    expect(gate(const AsyncValue.data('anna')), isFalse);
  });

  test('nobody may with one profile', () {
    expect(gate(const AsyncValue.data('bill'), multipleDivers: false), isFalse);
  });

  // A reload (a profile switch, a divers-table change) keeps the previous
  // profile's id while it runs; deciding on it would offer the profile the
  // diver just left its Transfer action.
  test('a reload that still carries the previous profile is unknown', () async {
    final reload = Completer<String?>();
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith(
          (_) => reads++ == 0 ? Future.value('bill') : reload.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(validatedCurrentDiverIdProvider, (_, _) {});
    await container.read(validatedCurrentDiverIdProvider.future);
    expect(gate(container.read(validatedCurrentDiverIdProvider)), isTrue);

    container.invalidate(validatedCurrentDiverIdProvider);
    final reloading = container.read(validatedCurrentDiverIdProvider);
    expect(reloading.isLoading, isTrue);
    expect(reloading.value, 'bill', reason: 'the trap: a value is still there');
    expect(gate(reloading), isFalse);

    reload.complete('anna');
    await container.read(validatedCurrentDiverIdProvider.future);
    expect(gate(container.read(validatedCurrentDiverIdProvider)), isFalse);
  });

  test('a failed read is unknown', () {
    expect(
      gate(const AsyncValue<String?>.error('boom', StackTrace.empty)),
      isFalse,
    );
  });
}
